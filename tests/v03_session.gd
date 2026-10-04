extends "res://tests/v03_test_base.gd"
func at(session: Variant,room: String,id: String) -> void:
 # Explicit domain fixture: only positioning bypasses the input/UI test layer.
 session.state.room=room
 for object: Dictionary in session.objects():
  if object.id==id:session.state.position=[float(object.x),float(object.y)];return
 check(false,"fixture object exists "+id)
func session_battle(id: String) -> Variant:
 var session: Variant=session_new()
 if session==null:return null
 session.state.flags.paper_door=true;session.state.flags.patrol=id!="patrol";session.state.flags.rig_demo=true;session.state.flags.joint=true
 session.state.owned=["crumple","unfold","raise","release_pair","fix","pump","future"]
 at(session,"corridor" if id=="patrol" else "lab",id)
 check(session.command("begin_battle",id).ok,"formal begin battle "+id)
 return session
func play(session: Variant,action: String,target: String="") -> void:
 var result: Dictionary=session.command("end_turn" if action=="end_turn" else "combat_action", "" if action=="end_turn" else action,{"target":target})
 check(result.ok,"formal action "+action+" / "+target)
func run_cases() -> void:
 suite="v03-session"
 var s: Variant=session_new()
 if s==null:return
 denied(s,"submit","cycle_console")
 denied(s,"begin_battle","hammer")
 denied(s,"combat_action","attack",{"target":""})
 denied(s,"seal","cycle_console")
 denied(s,"move","enemy",{"x":320.0,"y":224.0})
 denied(s,"move","player",{"x":100.0,"y":224.0})
 denied(s,"move","player",{"x":NAN,"y":224.0})
 denied(s,"interact","missing")
 denied(s,"choose_future","archive_terminal",{"accept":true})
 var point: Array=s.state.position.duplicate()
 check(s.command("move","player",{"x":float(point[0])+1.0,"y":point[1]}).ok,"one legal per-tick movement")
 denied(s,"move","player",{"x":float(point[0])+2.0,"y":point[1]})
 var b: Variant=session_battle("hammer")
 if b==null:return
 var before: String=canonical(b.snapshot())
 var point_before: String=canonical(b.checkpoint)
 for _i: int in range(100):check(b.combat_preview("raise","right").ok,"session preview valid")
 check(canonical(b.snapshot())==before and canonical(b.checkpoint)==point_before,"session previews preserve all causal state")
 var preview: Dictionary=b.combat_preview("raise","right")
 check(b.command("combat_action","raise",{"target":"right","revision":preview.revision,"request_id":"raise-once"}).ok,"preview commits against original revision")
 check(canonical(b.state.battle)==canonical(preview.state),"preview and committed resolver state match")
 var committed: String=canonical(b.snapshot())
 b.command("combat_action","raise",{"target":"right","revision":preview.revision,"request_id":"raise-once"})
 check(canonical(b.snapshot())==committed,"duplicate request cannot spend twice")
 denied(b,"combat_action","raise",{"target":"left","revision":preview.revision})
 denied(b,"move","player",{"x":b.state.position[0],"y":b.state.position[1]})
 play(b,"release_pair");play(b,"end_turn");play(b,"attack");play(b,"attack")
 check(b.state.flags.hammer and b.state.mode=="world" and "fix" in b.state.owned,"formal victory changes stage and grants actual action")
 denied(b,"combat_action","attack",{"target":""})
 denied(b,"begin_battle","hammer")
 var retreat: Variant=session_battle("hammer")
 var owned_before: String=canonical(retreat.state.owned)
 check(retreat.command("retreat").ok,"retreat is available")
 check(not retreat.state.flags.hammer and canonical(retreat.state.owned)==owned_before,"retreat does not mark victory")
 var opening: Variant=session_new()
 at(opening,"classroom","paper")
 check(opening.command("paper_shape","paper",{"shape":"flat"}).ok,"opening unfold")
 check(opening.command("release","paper").ok,"opening release")
 denied(opening,"observe","paper")
 opening.advance(120)
 check(opening.state.opening.phase=="landed" and opening.state.observations.is_empty(),"completed but undisplayed observation remains unread")
 check(opening.command("observe","paper").ok,"actual result observed at paper")
 var count: int=opening.state.observations.size()
 check(opening.command("observe","paper").ok and opening.state.observations.size()==count,"same observation source deduplicates")

