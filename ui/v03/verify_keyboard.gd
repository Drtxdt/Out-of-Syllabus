extends SceneTree
## Natural input: traverses from current focus; never teleports or grabs focus.
var scene: Control
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error(message)
func key(code: int,pressed: bool) -> void:
 var event: InputEventKey=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func tap(code: int) -> void:
 key(code,true);await process_frame;key(code,false)
 for frame: int in range(3):await process_frame
func activate(name: String) -> bool:
 for tries: int in range(50):
  var focused: Control=root.gui_get_focus_owner()
  if focused!=null and str(focused.name)==name:
   await tap(KEY_ENTER);return true
  await tap(KEY_TAB)
 check(false,"keyboard cannot reach "+name);return false
func walk(code: int,target: String,max_frames: int=240) -> bool:
 key(code,true)
 for frame: int in range(max_frames):
  await physics_frame
  var near: Dictionary=scene.session.call("nearby")
  if str(near.get("id",""))==target:
   key(code,false);await physics_frame;return true
 key(code,false);check(false,"walking failed to find "+target);return false
func run() -> void:
 root.size=Vector2i(960,540)
 scene=load("res://app/v03/main.tscn").instantiate();root.add_child(scene)
 for frame: int in range(5):await process_frame
 if not await activate("NewGame"):quit(1);return
 if not await walk(KEY_W,"paper"):quit(1);return
 await tap(KEY_E)
 if not await activate("PaperFlat"):quit(1);return
 if not await activate("PaperRelease"):quit(1);return
 for frame: int in range(220):
  await physics_frame
  if scene.state().observations.size()>0:break
 check(scene.state().opening.phase=="landed","paper animation completes")
 check(scene.state().observations.size()==1,"visible landed result automatically observed")
 if not await activate("ClosePaper"):quit(1);return
 if not await walk(KEY_S,"to_corridor_1"):quit(1);return
 await tap(KEY_E)
 check(scene.state().room=="corridor","walked through paper gate")
 if not await walk(KEY_W,"patrol"):quit(1);return
 await tap(KEY_E)
 for turn: int in range(5):
  if scene.state().mode!="combat":break
  for action: int in range(2):
   if scene.state().mode!="combat":break
   if not await activate("Action_attack"):quit(1);return
   if not await activate("Target_default"):quit(1);return
   if not await activate("ConfirmAction"):quit(1);return
  if scene.state().mode=="combat":
   if not await activate("EndTurn"):quit(1);return
 check(bool(scene.state().flags.patrol),"first normal battle won through real UI")
 if not await walk(KEY_W,"to_lab"):quit(1);return
 await tap(KEY_E)
 if not await walk(KEY_A,"rig_demo"):quit(1);return
 await tap(KEY_E)
 check(scene.rig_data.get("traces",[]).size()==2,"native rig shows two physical traces")
 if not await activate("CloseRig"):quit(1);return
 if not await walk(KEY_W,"hammer"):quit(1);return
 await tap(KEY_E)
 if not await activate("Action_raise"):quit(1);return
 if not await activate("Target_right"):quit(1);return
 if not await activate("ConfirmAction"):quit(1);return
 if not await activate("Action_release_pair"):quit(1);return
 if not await activate("Target_default"):quit(1);return
 if not await activate("ConfirmAction"):quit(1);return
 if not await activate("EndTurn"):quit(1);return
 for action: int in range(2):
  if not await activate("Action_attack"):quit(1);return
  if not await activate("Target_default"):quit(1);return
  if not await activate("ConfirmAction"):quit(1);return
 check(bool(scene.state().flags.hammer),"first shadow battle won through real UI")
 print("V03_KEYBOARD_CHECKS failures=",failures," stage=",scene.state().stage)
 scene.queue_free();await process_frame;quit(1 if failures else 0)
