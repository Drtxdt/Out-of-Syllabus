extends SceneTree
## Actual-input runner. The app/session/state are queried, never mutated by this harness.
var app: Node
var natural: bool=false
var route: String="accept"
var failures: Array[String]=[]
var focus_log: Array[String]=[]
var screenshots: Array[String]=[]
var steps: int=0
var started: int=0
var process_samples: Array[float]=[]
var physics_samples: Array[float]=[]
var wall_samples: Array[float]=[]
var wall_previous: int=0
var auto_dodge: bool=false
var root_path: String=""

func _initialize() -> void:
 var profile: String=OS.get_environment("OOS_QA_PROFILE")
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--route="):route=arg.trim_prefix("--route=")
  if arg.begins_with("--qa-profile="):profile=arg.trim_prefix("--qa-profile=")
 if profile.is_empty():push_error("Unique QA profile required");quit(2);return
 natural=route=="natural-keyboard"
 var paths: Script=load("res://core/v03/runtime_paths.gd")
 if paths==null:push_error("v0.3 runtime missing");quit(2);return
 root_path=paths.report_root()
 DirAccess.make_dir_recursive_absolute(root_path)
 process_frame.connect(_wall_frame)
 call_deferred("run")
func _wall_frame() -> void:
 var now: int=Time.get_ticks_usec()
 if wall_previous>0:wall_samples.append((now-wall_previous)/1000.0)
 wall_previous=now
func fail(message: String) -> void:
 failures.append(message);push_error(message)
func frames(count: int=1) -> void:
 for _i: int in range(count):
  await physics_frame
  process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
  physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
func key(code: int,pressed: bool) -> void:
 var event: InputEventKey=InputEventKey.new()
 event.keycode=code;event.physical_keycode=code;event.pressed=pressed
 Input.parse_input_event(event)
func tap_key(code: int) -> void:
 key(code,true);await frames(2);key(code,false);await frames(2)
func action(name: String,pressed: bool) -> void:
 if natural:
  var mapped: Array[InputEvent]=InputMap.action_get_events(name)
  for entry: InputEvent in mapped:
   if entry is InputEventKey:
    key(entry.physical_keycode if entry.physical_keycode!=0 else entry.keycode,pressed);return
  fail("No physical keyboard binding: "+name);return
 var event: InputEventAction=InputEventAction.new()
 event.action=name;event.pressed=pressed;Input.parse_input_event(event)
func tap(name: String) -> void:
 action(name,true);await frames(2);action(name,false);await frames(2)
func release_motion() -> void:
 for name: String in ["move_up","move_down","move_left","move_right","dodge"]:action(name,false)
func buttons(node: Node,result: Array[Button]) -> void:
 if node is Button and node.is_visible_in_tree():result.append(node)
 for child: Node in node.get_children():buttons(child,result)
func button_find(label: String) -> Button:
 var list: Array[Button]=[];buttons(app,list)
 for item: Button in list:
  if not item.disabled and (str(item.name)==label or item.text==label):return item
 for item: Button in list:
  if not item.disabled and item.text.contains(label):return item
 return null
func activate(label: String) -> bool:
 var selected: Button=button_find(label)
 if selected==null:fail("No visible enabled button: "+label);return false
 if natural:
  # Traverse from the actual current focus. Never grab_focus in natural mode.
  for _i: int in range(150):
   var owner: Control=root.gui_get_focus_owner()
   focus_log.append(str(owner.get_path()) if owner!=null else "none")
   if owner==selected:break
   await tap_key(KEY_TAB)
  if root.gui_get_focus_owner()!=selected:fail("Tab traversal cannot reach "+label);return false
 else:selected.grab_focus();await frames(2)
 await tap_key(KEY_ENTER)
 await frames(2)
 return true
func state_value(path: String) -> Variant:
 var value: Variant=app.session.state
 for part: String in path.split("."):
  if not value is Dictionary:return null
  value=value.get(part)
 return value
func move_to(target: Vector2) -> bool:
 var last: Vector2=Vector2(app.session.state.position[0],app.session.state.position[1])
 var stagnant: int=0
 for _i: int in range(2400):
  var position: Vector2=Vector2(app.session.state.position[0],app.session.state.position[1])
  var delta: Vector2=target-position
  if delta.length()<=4.0:release_motion();await frames();return true
  if app.session.state.mode!="world":release_motion();fail("Movement blocked by mode "+str(app.session.state.mode)+" at "+str(position));return false
  action("move_left",delta.x< -2.5);action("move_right",delta.x>2.5)
  action("move_up",delta.y< -2.5);action("move_down",delta.y>2.5)
  if auto_dodge:action("dodge",int(app.session.state.tick)>=int(app.session.state.finale.dodge_ready) and position.distance_to(Vector2(app.session.state.finale.examiner_position[0],app.session.state.finale.examiner_position[1]))<45.0)
  await frames()
  var current: Vector2=Vector2(app.session.state.position[0],app.session.state.position[1])
  stagnant=stagnant+1 if current.distance_to(last)<0.01 else 0;last=current
  if stagnant>180:release_motion();fail("Movement made no progress toward "+str(target)+" from "+str(current));return false
 release_motion();fail("Movement deadline exceeded");return false
func interact(id: String) -> bool:
 var target: Dictionary={}
 for object: Dictionary in app.session.objects():
  if object.id==id:target=object;break
 if target.is_empty():fail("No current-room object "+id);return false
 var approach: Vector2=(Vector2(float(target.x),float(target.y))+Vector2(0,22)).clamp(Vector2(44,60),Vector2(596,300))
 if not await move_to(approach):return false
 await frames(2)
 if app.session.nearby().get("id","")!=id:fail("Nearby object does not match "+id);return false
 await tap("interact");return true
func step(entry: Dictionary) -> bool:
 match str(entry.get("kind","")):
  "button":return await activate(str(entry.id))
  "key":await tap_key(int(entry.code))
  "action":await tap(str(entry.id))
  "move":return await move_to(Vector2(float(entry.x),float(entry.y)))
  "interact":return await interact(str(entry.id))
  "wait":await frames(int(entry.frames))
  "assert_chase":
   if app.session.state.finale.phase!="chase" or app.session.state.finale.examiner_room!=app.session.state.room:fail("No same-room live pursuer");return false
  "assert_dodge":
   if not app.session.state.events.any(func(e: Dictionary) -> bool:return e.kind=="dodge"):fail("No real dodge input event");return false
  "auto_dodge":auto_dodge=entry.enabled
  "until":
   for _i: int in range(int(entry.get("timeout",1200))):
    if state_value(entry.path)==entry.value:return true
    await frames()
   fail("Timed out waiting for "+str(entry.path));return false
  "assert":
   if state_value(entry.path)!=entry.value:fail("State mismatch "+str(entry.path)+": "+str(state_value(entry.path)));return false
  "screenshot":
   if DisplayServer.get_name()=="headless":print("SCREENSHOT SKIPPED: headless")
   else:
    await RenderingServer.frame_post_draw
    var path: String=root_path.path_join(str(entry.name)+".png")
    if root.get_texture().get_image().save_png(path)!=OK:fail("Screenshot write failure");return false
    screenshots.append(path)
  _:
   fail("Unknown route action "+str(entry));return false
 return true
func run() -> void:
 started=Time.get_ticks_msec()
 var packed: PackedScene=load("res://app/v03/main.tscn")
 if packed==null:fail("Missing v0.3 main scene");finish();return
 app=packed.instantiate();root.add_child(app);await frames(5)
 var source: String="res://qa/v03_routes/"+route+".json"
 var entries: Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
 if not entries is Array:fail("Missing/invalid route "+source);finish();return
 for entry: Variant in entries:
  if not entry is Dictionary:fail("Invalid route step");break
  print("V03 INPUT STEP ",steps," ",JSON.stringify(entry)," state=",app.session.state.stage," tick=",app.session.state.tick)
  if not await step(entry):break
  steps+=1
 finish()
func timing(samples: Array[float]) -> Dictionary:
 if samples.is_empty():return {"samples":0}
 var sorted: Array[float]=samples.duplicate();sorted.sort();var total: float=0.0
 for sample: float in sorted:total+=sample
 return {"samples":sorted.size(),"max_ms":sorted.back(),"mean_ms":total/sorted.size(),"p95_ms":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)]}
func finish() -> void:
 if app!=null:release_motion()
 var report: Dictionary={"suite":"v03-input","route":route,"natural_focus_navigation":natural,"focus_log":focus_log,"steps":steps,"failures":failures,"screenshots":screenshots,"completed":app.session.state.completed if app!=null else false,"engine":Engine.get_version_info().string,"elapsed_ms":Time.get_ticks_msec()-started,"timing":{"process":timing(process_samples),"physics":timing(physics_samples),"wall_process_frame_intervals":timing(wall_samples),"wall_note":"Real process_frame intervals include screenshots, synchronous saves, fast-forward and all pauses. Fixed-fps scripted execution is not stable display FPS or human playtime.","note":"Retained Performance monitor samples, not independent frame stopwatch or human playtime"}}
 var output: FileAccess=FileAccess.open(root_path.path_join("input.json"),FileAccess.WRITE)
 if output==null:fail("Could not write input report")
 else:output.store_string(JSON.stringify(report,"  "));output.close()
 print("V03 INPUT: ",JSON.stringify(report))
 if app!=null:app.queue_free();app=null
 await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)





