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
  for id: String in ["Hint","Notebook","Menu"]:
   var button: Button=scene.find_child(id,true,false)
   check(button.size.x>=76,"HUD readable button width "+id)
  scene.joint_panel.show();scene.joint_panel.render({"arrival_s":0.639,"points":[],"setup":{"height":2.0}},1.0,true)
  await settle();scene.call("_place_joint_panel");await settle()
  var joint_rect: Rect2=scene.joint_panel.get_global_rect()
  var footer_rect: Rect2=scene.get_node("Footer").get_global_rect()
  check(joint_rect.end.x<=dimensions.x and joint_rect.end.y<footer_rect.position.y,"joint UI avoids footer "+str(dimensions))
  check(scene.joint_panel.scale==Vector2.ONE,"joint text independent of world scaling")
  var frame: Control=scene.get_node("WorldFrame")
  for at: Vector2 in [Vector2(144,144),Vector2(464,144),Vector2(304,152)]:
   var center: Vector2=frame.position+at*frame.scale
   var actor_rect: Rect2=Rect2(center-Vector2(20,40)*frame.scale,Vector2(40,70)*frame.scale)
   check(not joint_rect.intersects(actor_rect),"joint UI avoids A/B/C actors "+str(dimensions))
  scene.joint_panel.hide()
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
