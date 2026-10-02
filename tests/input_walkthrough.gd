extends SceneTree
## Input-only harness. The route reads state, but ALL normal gameplay uses Input events.
## --route=res://tests/routes/xxx.json supplies a sequence of semantic input steps.
var app: Node
var failures: Array[String] = []
var steps_completed: int = 0
var started_ms: int = 0
var route_name: String = "smoke"

func _initialize() -> void:
 if RuntimePaths.profile_id().is_empty():
  push_error("--qa-profile must be set before scene startup")
  quit(2);return
 call_deferred("run")

func fail(message: String) -> void:
 failures.append(message)
 push_error(message)

func frame(count: int = 1) -> void:
 for _i: int in range(count): await physics_frame

func action(name: String, pressed: bool) -> void:
 var event: InputEventAction = InputEventAction.new()
 event.action = name;event.pressed = pressed
 Input.parse_input_event(event)

func tap(name: String) -> void:
 action(name,true);await frame(2);action(name,false);await frame(2)

func buttons(node: Node, result: Array[Button]) -> void:
 if node is Button and node.is_visible_in_tree(): result.append(node)
 for child: Node in node.get_children(): buttons(child,result)

func click(label: String) -> bool:
 var candidates: Array[Button] = []
 buttons(app,candidates)
 var selected: Button
 for button: Button in candidates:
  if (button.name == label or button.text == label) and not button.disabled:
   selected = button;break
 if selected == null:
  for button: Button in candidates:
   if button.text.contains(label) and not button.disabled:
    selected = button;break
 if selected == null:
  fail("No enabled visible button: " + label);return false
 # Focus is UI navigation only. Activation is a genuine key event, never emit_signal.
 selected.grab_focus()
 await frame(2)
 var down: InputEventKey = InputEventKey.new()
 down.keycode = KEY_ENTER;down.physical_keycode = KEY_ENTER;down.pressed = true
 Input.parse_input_event(down)
 await frame(2)
 var up: InputEventKey = InputEventKey.new()
 up.keycode = KEY_ENTER;up.physical_keycode = KEY_ENTER;up.pressed = false
 Input.parse_input_event(up)
 await frame(3)
 return true

func move_to(target: Vector2, limit: int = 1800) -> bool:
 var previous: Vector2 = app.session.player_position
 var stagnant: int = 0
 for _i: int in range(limit):
  var delta: Vector2 = target - Vector2(app.session.player_position)
  if delta.length() <= 4.0:
   release_motion();await frame();return true
  if app.session.mode != "world":
   release_motion();fail("Movement attempted while modal: " + str(app.session.mode));return false
  action("move_right",delta.x > 2.5)
  action("move_left",delta.x < -2.5)
  action("move_down",delta.y > 2.5)
  action("move_up",delta.y < -2.5)
  await frame()
  var current: Vector2 = app.session.player_position
  stagnant = stagnant + 1 if current.distance_to(previous) < 0.01 else 0
  previous = current
  if stagnant > 90:
   release_motion();fail("Collision/no progress at " + str(current) + " toward " + str(target));return false
 release_motion();fail("Movement timed out toward " + str(target));return false

func release_motion() -> void:
 for name: String in ["move_right","move_left","move_down","move_up"]: action(name,false)

func interact(id: String) -> bool:
 var object: Dictionary = app.content.object(id)
 if object.is_empty(): fail("Missing object: " + id);return false
 var target: Vector2 = (Vector2(float(object.x),float(object.y)) + Vector2(0,28)).clamp(Vector2(44,60),Vector2(596,300))
 if not await move_to(target): return false
 await frame(2)
 if app.nearest.get("id","") != id:
  fail("Wrong nearby object, wanted " + id + ", got " + str(app.nearest));return false
 await tap("interact")
 return true

func read_state(path: String) -> Variant:
 var value: Variant = app.session
 for key: String in path.split("."):
  if value is Dictionary: value = value.get(key)
  elif value is Object: value = value.get(key)
  else: return null
 return value

func step(data: Dictionary) -> bool:
 match str(data.get("kind","")):
  "click": return await click(str(data.label))
  "action": await tap(str(data.action))
  "move": return await move_to(Vector2(float(data.x),float(data.y)))
  "interact": return await interact(str(data.id))
  "wait": await frame(int(data.get("frames",60)))
  "until":
   for _i: int in range(int(data.get("timeout_frames",1800))):
    if read_state(str(data.path)) == data.value: return true
    await frame()
   fail("Timed out: " + str(data.path) + " == " + str(data.value));return false
  "assert":
   if read_state(str(data.path)) != data.value:
    fail("Assertion: " + str(data.path) + " expected " + str(data.value) + " got " + str(read_state(str(data.path))));return false
  _:
   fail("Unknown route step " + str(data));return false
 return true

func run() -> void:
 started_ms = Time.get_ticks_msec()
 var packed: PackedScene = load("res://app/main.tscn")
 app = packed.instantiate();root.add_child(app)
 await frame(5)
 var route: Array = [
  {"kind":"click","label":"开始新的记录"},
  {"kind":"assert","path":"room_id","value":"classroom"},
  {"kind":"interact","id":"switch_a"},
  {"kind":"assert","path":"world.switch_a","value":true},
  {"kind":"move","x":320,"y":250},
  {"kind":"interact","id":"to_corridor_1"},
  {"kind":"assert","path":"room_id","value":"corridor"}]
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--route="):
   route_name = argument.trim_prefix("--route=")
   var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_name))
   if not parsed is Array:
    fail("Route must be a JSON array");finish();return
   route = parsed
 for entry: Variant in route:
  if not entry is Dictionary:
   fail("Route step must be object");break
  if not await step(entry): break
  steps_completed += 1
 finish()

func finish() -> void:
 release_motion()
 var report: Dictionary = {"suite":"input-only","route":route_name,"steps_completed":steps_completed,"failures":failures,"engine":Engine.get_version_info().string,"elapsed_ms":Time.get_ticks_msec()-started_ms,"completion":app.session.profile.completed if app != null else false,"limitations":["Headless input validation is not visual screenshot acceptance","Default route is movement smoke only; both endings require explicit routes"]}
 var file: FileAccess = FileAccess.open(RuntimePaths.report_path("input-walkthrough.json"),FileAccess.WRITE)
 if file == null:
  fail("Could not write input report")
 else:
  file.store_string(JSON.stringify(report,"  "));file.close()
 print("INPUT WALKTHROUGH: ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)

