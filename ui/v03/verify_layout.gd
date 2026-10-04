extends SceneTree
const UI=preload("res://ui/v03/controls.gd")
const Combat=preload("res://core/v03/combat_session.gd")
var failures: int=0
var battle: Dictionary=Combat.initial("bellows")
var owned: Array=["crumple","unfold","raise","release_pair","fix","pump","future"]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error(message)
func settle() -> void:
 for frame: int in range(4):await process_frame
func preview(action: String,target: String) -> Dictionary:
 var result: Dictionary=Combat.apply(battle,action,target,owned)
 result["can_predict"]=false;result["revision"]=int(battle.revision)
 return result
func run() -> void:
 for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1920,1080)]:
  var viewport: SubViewport=SubViewport.new();viewport.size=size;root.add_child(viewport)
  var panel: PanelContainer=PanelContainer.new();panel.theme=UI.theme();panel.position=Vector2(size)*Vector2(0.025,0.035);panel.size=Vector2(size)*Vector2(0.95,0.93);viewport.add_child(panel)
  var view: VBoxContainer=VBoxContainer.new();view.set_script(preload("res://ui/v03/combat_view.gd"));panel.add_child(view)
  view.preview=preview;view.render(battle,owned)
  await settle()
  print("V03_COMBAT_LAYOUT ",size," panel=",panel.get_global_rect()," min=",view.get_combined_minimum_size())
  if size.x==960:
   for child: Control in view.get_children():print("  ",child.name," ",child.size," min=",child.get_combined_minimum_size())
  check(panel.get_global_rect().end.y<=size.y,"combat fits height "+str(size))
  check(panel.get_global_rect().end.x<=size.x,"combat fits width "+str(size))
  view.call("_select_action","crumple")
  await settle()
  check(viewport.gui_get_focus_owner().name=="Target_paper","action moves to legal target")
  view.call("_select_target","paper")
  await settle()
  check(viewport.gui_get_focus_owner().name=="ConfirmAction","target moves to confirm")
  check(view.get_node("Preview").text.contains("不足以可靠预测"),"unknown model preview stays qualitative")
  var outcomes: Array=[]
  view.command_requested.connect(func(kind: String,target: String,payload: Dictionary) -> void:outcomes.append([kind,target,payload]))
  view.call("_confirm")
  check(outcomes.size()==1 and outcomes[0][2].target=="paper","confirmed action emits target")
  view.cancel_selection();await settle()
  check(viewport.gui_get_focus_owner()!=null,"cancel returns to actionable control")
  battle.ap=0;battle.pending_release=true;battle.defending=true;battle.revision+=1
  view.render(battle,owned);await settle()
  print("V03_NO_AP_LAYOUT ",size," min=",view.get_combined_minimum_size())
  check(panel.get_global_rect().end.y<=size.y,"disabled action reasons fit height "+str(size))
  battle.ap=2;battle.pending_release=false;battle.defending=false;battle.revision+=1
  viewport.queue_free();await settle()
 print("V03_UI_CHECKS failures=",failures)
 quit(1 if failures else 0)
