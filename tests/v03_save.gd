extends "res://tests/v03_test_base.gd"
const Store=preload("res://core/v03/save_store.gd")
func payload(s: Variant) -> Dictionary:
 return {"schema":4,"content_version":3,"chapter":"fall_v03","state":s.snapshot(),"checkpoint":s.checkpoint.duplicate(true)}
func run_cases() -> void:
 suite="v03-save"
 var s: Variant=session_new()
 var path: String=report_root.path_join("progress.json")
 var store: RefCounted=Store.new(path)
 check(store.save_session(s),"initial save")
 s.advance(60);check(store.save_session(s),"valid main creates backup")
 write_text(path,"corrupt")
 var recovered: Variant=session_new()
 check(store.load_session(recovered),"corrupt main recovers backup")
 check(recovered.state.tick==0,"backup is original valid state")
 check(store.save_session(recovered),"save recovered session")
 write_text(path,"corrupt again")
 check(store.load_session(recovered),"second corruption still recovers")
 check(store.save_session(recovered),"restore valid baseline")
 for fault: String in ["open","write","copy","rename"]:
  var before: String=FileAccess.get_file_as_string(path)
  store.fail_step=fault
  check(not store.save_session(s),"simulated "+fault+" failure")
  check(FileAccess.get_file_as_string(path)==before,"failure preserves valid main "+fault)
 store.fail_step=""
 var future: Dictionary=payload(s);future.schema=5
 envelope(path,future)
 var before_state: String=canonical(recovered.snapshot())
 check(not store.load_session(recovered),"future main refuses old backup fallback")
 check(canonical(recovered.snapshot())==before_state,"future failure leaves active session")
 check(not store.save_session(s),"cannot overwrite future main")
 write_text(path,"broken");envelope(path+".bak",future)
 check(not store.load_session(recovered),"future backup refused")
 var old: Dictionary=payload(s);old.schema=3
 envelope(path,old);envelope(path+".bak",payload(s))
 check(not store.load_session(recovered),"legacy format explicitly refused")
 for malformed: String in ["mode","position","events","samples","observations","checkpoint","finale","owned"]:
  var bad: Dictionary=payload(s)
  match malformed:
   "mode":bad.state.mode="won"
   "position":bad.state.position=[-1,INF]
   "events":bad.state.events=[{"id":"forged"}]
   "samples":bad.state.samples=[{"tick":-99}]
   "observations":bad.state.observations=[{"observed":true,"trace":{}}]
   "checkpoint":bad.checkpoint={"cycle":3}
   "finale":bad.state.finale.violations=-1
   "owned":bad.state.owned=["not_an_action"]
  envelope(path,bad);write_text(path+".bak","broken")
  check(not store.load_session(recovered),"nested malformed "+malformed)
  check(canonical(recovered.snapshot())==before_state,"nested malformed atomic "+malformed)
 var blocker: String=report_root.path_join("not_a_directory")
 write_text(blocker,"real filesystem obstruction")
 var filesystem: RefCounted=Store.new(blocker.path_join("progress.json"))
 check(not filesystem.save_session(s),"real filesystem ENOTDIR write fails")
 check(FileAccess.get_file_as_string(blocker)=="real filesystem obstruction","real filesystem obstruction remains unchanged")
 notes.append("Simulated faults: open/write/copy/rename. Real filesystem fault: child path below regular file. No disk-full/physical-loss simulation.")
 var measured: Variant=session_new()
 measured.state.position=[320.0,152.0]
 measured.command("paper_shape","paper",{"shape":"flat"});measured.command("release","paper");measured.advance(120)
 var fabricated: Dictionary=measured.snapshot()
 fabricated.observations.append({"id":"observation_"+fabricated.opening.source_id,"source_id":fabricated.opening.source_id,"cycle":1,"tick":120,"trace":fabricated.opening.trace.duplicate(true),"observed":true,"summary":"forged without player observe"})
 restore_rejected(measured,fabricated,"read observation without observe event")
 check(measured.command("observe","paper").ok,"real observe command")
 var good: Dictionary=measured.snapshot()
 fabricated=good.duplicate(true)
 fabricated.observations[0].trace=preload("res://core/v03/physics.gd").trace(preload("res://core/v03/physics.gd").setup("paper","flat",2.0,0.0,"vacuum"))
 restore_rejected(measured,fabricated,"legitimate simulator trace in wrong original medium")
 fabricated=good.duplicate(true);fabricated.observations[0].tick=int(fabricated.opening.release_tick)+1
 restore_rejected(measured,fabricated,"measurement timestamp precedes physical arrival")
 fabricated=good.duplicate(true);fabricated.observations.append(fabricated.observations[0].duplicate(true))
 restore_rejected(measured,fabricated,"repeated observation source")
 fabricated=good.duplicate(true);fabricated.observations[0].source_id="c1:e999"
 restore_rejected(measured,fabricated,"nonexistent observation source")
 var unearned: Variant=session_new()
 for action_id: String in ["future","pump","fix","raise","release_pair"]:
  var forged_unlock: Dictionary=unearned.snapshot();forged_unlock.owned=[action_id]
  restore_rejected(unearned,forged_unlock,"unearned action "+action_id)

