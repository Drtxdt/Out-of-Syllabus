extends Node
## Input-only harness. The route reads state, but ALL normal gameplay uses Input events.
## --route=res://tests/routes/xxx.json supplies a sequence of semantic input steps.
var app: Node
var failures: Array[String] = []
var steps_completed: int = 0
var started_ms: int = 0
var route_name: String = "smoke"
var auto_dodge: bool = false
var screenshots: Array[String] = []
var wall_frame_ms: Array[float] = []
var previous_frame_usec: int = 0

func _process(_delta: float) -> void:
 var now: int=Time.get_ticks_usec()
 if previous_frame_usec>0: wall_frame_ms.append((now-previous_frame_usec)/1000.0)
 previous_frame_usec=now
var process_ms: Array[float] = []
var physics_ms: Array[float] = []

func _ready() -> void:
 if RuntimePaths.profile_id().is_empty():
  push_error("--qa-profile must be set before scene startup")
  get_tree().quit(2);return
 call_deferred("run")

func fail(message: String) -> void:
 failures.append(message)
 push_error(message)

func frame(count: int = 1) -> void:
 for _i: int in range(count):
  await get_tree().physics_frame
  process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
  physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)

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
   release_motion();fail("Movement attempted while modal: " + str(app.session.mode) + " position=" + str(app.session.player_position) + " examiner=" + str(app.session.finale.examiner_position));return false
  action("move_right",delta.x > 2.5)
  action("move_left",delta.x < -2.5)
  action("move_down",delta.y > 2.5)
  action("move_up",delta.y < -2.5)
  if auto_dodge:
   action("dodge",app.session.dodge_cooldown_ticks == 0)
  await frame()
  var current: Vector2 = app.session.player_position
  stagnant = stagnant + 1 if current.distance_to(previous) < 0.01 else 0
  previous = current
  if stagnant > 90:
   release_motion();fail("Collision/no progress at " + str(current) + " toward " + str(target));return false
 release_motion();fail("Movement timed out toward " + str(target));return false

func release_motion() -> void:
 action("dodge",false)
 for name: String in ["move_right","move_left","move_down","move_up"]: action(name,false)

func interact(id: String) -> bool:
 var object: Dictionary = app.content.object(id)
 if object.is_empty(): fail("Missing object: " + id);return false
 var target: Vector2 = (Vector2(float(object.x),float(object.y)) + Vector2(0,-24 if id=="fall_gate" else 24)).clamp(Vector2(44,60),Vector2(596,300))
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
  "assert_saved":
   if not app.saves.last_error.is_empty():
    fail("Save error: " + app.saves.last_error);return false
   var envelope: Variant=JSON.parse_string(FileAccess.get_file_as_string(app.saves.path))
   if not envelope is Dictionary or not envelope.get("payload") is String or envelope.payload.sha256_text()!=envelope.get("sha256"):
    fail("Saved envelope missing or invalid");return false
   var payload: Variant=JSON.parse_string(envelope.payload)
   if not payload is Dictionary or not payload.get("state") is Dictionary or not payload.state.profile.completed or payload.state.profile.violation!=app.session.profile.violation:
    fail("Completion and violation are not persisted");return false
  "assert_pursuer":
   if app.session.finale.phase!="chase" or app.session.finale.examiner_room!=app.session.room_id:
    fail("Active chase has no pursuer in player room");return false
   if not app.session.events.any(func(event: Dictionary) -> bool: return event.kind=="dodge" and event.actor=="player"):
    fail("Pursuit route has no real player dodge event");return false
  "read_all":
   for _i: int in range(30):
    var candidates: Array[Button]=[]
    buttons(app,candidates)
    var found: String=""
    for button: Button in candidates:
     if str(button.name).begins_with("Read_") and not button.disabled:
      found=str(button.name);break
    if found.is_empty(): return true
    if not await click(found): return false
   fail("Too many instrument reads");return false
  "select_all":
   for _i: int in range(30):
    var candidates: Array[Button]=[]
    buttons(app,candidates)
    var found: String=""
    for button: Button in candidates:
     if button is CheckBox and str(button.name).begins_with("Evidence_") and not button.button_pressed:
      found=str(button.name);break
    if found.is_empty(): return true
    if not await click(found): return false
   fail("Too many evidence selections");return false
  "auto_dodge": auto_dodge=bool(data.enabled)
  "screenshot":
   if DisplayServer.get_name()=="headless":
    print("SCREENSHOT SKIPPED: headless renderer")
   else:
    await RenderingServer.frame_post_draw
    var image: Image=get_viewport().get_texture().get_image()
    var path: String=RuntimePaths.report_path(str(data.get("name","frame"))+".png")
    if image.save_png(path)!=OK: fail("Screenshot write failed");return false
    screenshots.append(path)
  "action": await tap(str(data.action))
  "move": return await move_to(Vector2(float(data.x),float(data.y)))
  "interact": return await interact(str(data.id))
  "interact_near":
   if app.nearest.get("id","")!=str(data.id):
    fail("Near interaction expected " + str(data.id) + ", got " + str(app.nearest));return false
   await tap("interact")
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
 app=get_parent()
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
  var progress: FileAccess=FileAccess.open(RuntimePaths.report_path("input-progress.json"),FileAccess.WRITE)
  if progress!=null: progress.store_string(JSON.stringify({"step":steps_completed,"action":entry,"cycle":app.session.cycle,"tick":app.session.tick,"room":app.session.room_id}));progress.close()
  print("INPUT STEP ",steps_completed," ",JSON.stringify(entry)," cycle=",app.session.cycle," tick=",app.session.tick," room=",app.session.room_id)
  if not await step(entry): break
  steps_completed += 1
 finish()

func timing(values: Array[float]) -> Dictionary:
 if values.is_empty(): return {"samples":0}
 var ordered: Array[float]=values.duplicate()
 ordered.sort()
 var total: float=0.0
 for value: float in ordered: total+=value
 return {"samples":ordered.size(),"mean_ms":total/ordered.size(),"p95_ms":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)],"max_ms":ordered.back()}

func finish() -> void:
 release_motion()
 var report: Dictionary = {"suite":"input-only","route":route_name,"steps_completed":steps_completed,"failures":failures,"engine":Engine.get_version_info().string,"elapsed_ms":Time.get_ticks_msec()-started_ms,"screenshots":screenshots,"timing":{"wall_frame":timing(wall_frame_ms),"process":timing(process_ms),"physics":timing(physics_ms),"renderer":DisplayServer.get_name(),"note":"wall_frame measures consecutive rendered process callbacks with the monotonic clock; other CPU monitors retain samples. Fixed-fps controls simulated time, not human playtime."},"completion":app.session.profile.completed if app != null else false,"limitations":["Headless input validation is not visual screenshot acceptance","Default route is movement smoke only; both endings require explicit routes"]}
 var file: FileAccess = FileAccess.open(RuntimePaths.report_path("input-walkthrough.json"),FileAccess.WRITE)
 if file == null:
  fail("Could not write input report")
 else:
  file.store_string(JSON.stringify(report,"  "));file.close()
 print("INPUT WALKTHROUGH: ",JSON.stringify(report))
 if is_instance_valid(app):
  app.feedback_sound.stop();app.feedback_sound.stream=null
  OS.delay_msec(100) # Let the audio mixing thread release its last playback before test shutdown.
 reparent(get_tree().root)
 if is_instance_valid(app): app.queue_free()
 app=null
 await get_tree().process_frame
 await get_tree().process_frame
 get_tree().create_timer(0.05).timeout.connect(get_tree().quit.bind(0 if failures.is_empty() else 1))
 queue_free()

