extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error(message)
func settle() -> void:
 for frame: int in range(5):await process_frame
func run() -> void:
 for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1920,1080)]:
  var viewport: SubViewport=SubViewport.new();viewport.size=dimensions;root.add_child(viewport)
  var scene: Control=load("res://app/v03/main.tscn").instantiate();scene.suppress_intro=true;viewport.add_child(scene)
  await settle()
  check(scene.session!=null,"scene core initialized")
  for method: String in ["show_paper","show_rig","show_settings","show_archive","show_cycle","show_notebook","show_ending"]:
   scene.call(method);await settle()
   var panel: PanelContainer=scene.panel
   print("V03_SCENE_LAYOUT ",dimensions," ",method," ",panel.get_global_rect())
   check(panel.get_global_rect().end.y<=dimensions.y+1,method+" fits vertical "+str(dimensions))
   check(panel.get_global_rect().end.x<=dimensions.x+1,method+" fits horizontal "+str(dimensions))
   for node: Node in scene.modal_body.find_children("*","Button",true,false):
    var button: Button=node as Button
    check(button.get_global_rect().end.y<=dimensions.y+1,method+" button accessible "+str(button.name))
  viewport.queue_free();await settle()
 print("V03_SCENE_CHECKS failures=",failures)
 quit(1 if failures else 0)
