extends "res://tests/v03_test_base.gd"
const Store=preload("res://core/v03/save_store.gd")
func run_cases() -> void:
 suite="v03-performance"
 var s: Variant=session_new()
 var begin: int=Time.get_ticks_usec()
 s.advance(108000)
 var advance_ms: float=(Time.get_ticks_usec()-begin)/1000.0
 check(s.state.tick==108000,"30 minutes at60 ticks per second")
 var path: String=report_root.path_join("archive.json")
 var store: RefCounted=Store.new(path)
 begin=Time.get_ticks_usec()
 check(store.save_session(s),"30-minute archive saves")
 var save_ms: float=(Time.get_ticks_usec()-begin)/1000.0
 var bytes: int=FileAccess.get_file_as_bytes(path).size()
 var restored: Variant=session_new()
 begin=Time.get_ticks_usec()
 check(store.load_session(restored),"30-minute archive reloads")
 var load_ms: float=(Time.get_ticks_usec()-begin)/1000.0
 check(canonical(s.snapshot())==canonical(restored.snapshot()),"archive semantic roundtrip")
 notes.append(JSON.stringify({"virtual_seconds":1800,"advance_wall_ms":advance_ms,"save_wall_ms":save_ms,"load_wall_ms":load_ms,"file_bytes":bytes,"samples":s.state.samples.size(),"note":"Stationary 30-minute actual tick archive; not human playtime or rendered FPS"}))
