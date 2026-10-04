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
