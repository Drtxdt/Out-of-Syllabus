extends SceneTree
## Virtual 30-minute domain archive. Does not claim 30-minute real-player timing.
func _initialize() -> void:
 if RuntimePaths.profile_id().is_empty():
  push_error("Unique --qa-profile required");quit(2);return
 var session: GameSession = GameSession.new()
 var started: int = Time.get_ticks_usec()
 session.advance(30*60*60)
 var simulation_ms: float = (Time.get_ticks_usec()-started)/1000.0
 var store: SaveStore = SaveStore.new(RuntimePaths.data_root()+"/archive-30m.json")
 started = Time.get_ticks_usec()
 var saved: bool = store.save_session(session)
 var save_ms: float = (Time.get_ticks_usec()-started)/1000.0
 var size_bytes: int = FileAccess.get_file_as_bytes(store.path).size() if saved else 0
 var restored: GameSession = GameSession.new()
 started = Time.get_ticks_usec()
 var loaded: bool = store.load_session(restored)
 var load_ms: float = (Time.get_ticks_usec()-started)/1000.0
 var equivalent: bool = loaded and JSON.stringify(JSON.parse_string(JSON.stringify(session.snapshot())))==JSON.stringify(JSON.parse_string(JSON.stringify(restored.snapshot())))
 var report: Dictionary = {"suite":"virtual-archive-performance","engine":Engine.get_version_info().string,"ticks":session.tick,"virtual_minutes":30,"simulation_ms":simulation_ms,"save_ms":save_ms,"load_ms":load_ms,"bytes":size_bytes,"samples":session.track.samples.size(),"saved":saved,"loaded":loaded,"equivalent":equivalent,"limitations":["Synthetic idle archive; no actual rendering frame-time measurement","No human playtime claim"]}
 var output: FileAccess = FileAccess.open(RuntimePaths.report_path("archive-performance.json"),FileAccess.WRITE)
 if output == null:
  push_error("Report write failed");quit(1);return
 output.store_string(JSON.stringify(report,"  "));output.close()
 print("ARCHIVE PERFORMANCE: ",JSON.stringify(report))
 quit(0 if saved and loaded and equivalent and session.tick == 108000 else 1)
