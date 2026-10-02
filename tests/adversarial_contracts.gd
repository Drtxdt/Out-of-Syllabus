extends "res://tests/v02_regression.gd"
## Adversarial contract tests. Failures describe production gaps, not test allowances.
func reject_restore(source: Dictionary, label: String) -> void:
 var target: GameSession=GameSession.new(content)
 var before: String=canonical(target.snapshot())
 check(not target.restore(source),"reject malformed " + label)
 check(canonical(target.snapshot())==before,"restore atomic " + label)

func test_malformed() -> void:
 var s: Variant=fixture()
 var id: String=measure(s)
 var valid: Dictionary=s.snapshot()
 var bad: Dictionary=valid.duplicate(true)
 bad.evidence[0].observations.arrival_times_s[0]=999.0
 reject_restore(bad,"forged observation")
 bad=valid.duplicate(true);bad.evidence[0].source_event_id="c1:e999999"
 reject_restore(bad,"nonexistent evidence source")
 bad=valid.duplicate(true);bad.evidence[0].origin_actor=[]
 reject_restore(bad,"evidence actor wrong type")
 bad=valid.duplicate(true);bad.evidence[0].source_cycle=3
 reject_restore(bad,"source cycle disagrees with source identity")
 bad=valid.duplicate(true);bad.evidence[0].tick=-1
 reject_restore(bad,"negative evidence time")
 bad=valid.duplicate(true);bad.evidence[0].tick=999999
 reject_restore(bad,"future evidence time")
 bad=valid.duplicate(true);bad.track.events[0].payload.medium=[]
 reject_restore(bad,"experiment payload medium array")
 bad=valid.duplicate(true);bad.mode="invalid"
 reject_restore(bad,"unknown mode")
 bad=valid.duplicate(true);bad.mode="model"
 reject_restore(bad,"model mode without active argument")
 bad=valid.duplicate(true);bad.cycle=1.5
 reject_restore(bad,"fractional cycle")
 bad=valid.duplicate(true);bad.track.events[0].seq=0.5
 reject_restore(bad,"fractional event sequence")
 s.cycle=2;check(s.start_battle("mass"),"active model fixture")
 s.play_card("observe",[id])
 valid=s.snapshot()
 bad=valid.duplicate(true);bad.battle.cited_ids="fake"
 reject_restore(bad,"cited IDs not array")
 bad=valid.duplicate(true);bad.battle.cited_ids=["prediction_fake"]
 reject_restore(bad,"prediction citation instead of evidence")
 bad=valid.duplicate(true);bad.mode="world"
 reject_restore(bad,"world mode with active argument")
 var fresh: GameSession=GameSession.new(content)
 valid=fresh.snapshot()
 bad=valid.duplicate(true)
 bad.track.events=[{"seq":1,"cycle":1,"tick":0,"actor":"player","room":"classroom","kind":"switch","target":"switch_a","payload":{"value":[]}}]
 bad.events=bad.track.events.duplicate(true);bad.seq=1
 reject_restore(bad,"historical switch payload value array")
 bad=valid.duplicate(true)
 bad.finale.phase="ready";bad.finale.prediction={"time_s":"not-a-number","origin":"measurement"}
 reject_restore(bad,"gate prediction numeric type")
 bad=valid.duplicate(true)
 bad.finale.phase="complete";bad.profile.completed=false
 reject_restore(bad,"completed phase disagrees with profile")
 var store: SaveStore=SaveStore.new(RuntimePaths.data_root()+"/malformed-envelope.json")
 var payload: Dictionary={"schema":3,"content_version":2,"chapter":"fall","state":valid,"checkpoint":{},"cycle_checkpoint":{}}
 payload.checkpoint={"world":"broken"}
 envelope(store.path,payload)
 check(not store.load_session(fresh),"malformed checkpoint rejects full envelope")
 check(canonical(fresh.snapshot())==canonical(valid),"checkpoint failure leaves active session intact")
 payload.checkpoint={};payload.schema=999
 envelope(store.path+".bak",payload);write_text(store.path,"broken main")
 check(not store.load_session(fresh),"future schema in backup rejected")
 payload.schema=3;payload.content_version=999;envelope(store.path+".bak",payload)
 check(not store.load_session(fresh),"future content in backup rejected")

func test_source_spoof() -> void:
 var s: Variant=rig_fixture(1)
 s.advance(2)
 var before: String=canonical(s.snapshot())
 var result: Dictionary=s.command("switch","rig_power",{"value":false},"echo_1",{"source_cycle":1,"source_event_id":"c1:e999","source_room":"archive"})
 check(not result.ok and canonical(s.snapshot())==before,"arbitrary echo source cannot fabricate replay command")
 # Provide a valid historical pose beside the switch but no corresponding historical switch event.
 s.histories[0].track.samples.insert(1,{"tick":s.tick,"room":"lab","x":560.0,"y":240.0,"direction":"up","moving":false})
 before=canonical(s.snapshot())
 result=s.command("switch","rig_power",{"value":false},"echo_1",{"source_cycle":1,"source_event_id":"c1:e999","source_room":"archive"})
 check(not result.ok,"echo context must identify a real matching sealed event")
 check(canonical(s.snapshot())==before,"fake source denial leaves world and log unchanged")

func _initialize() -> void:
 if RuntimePaths.profile_id().is_empty(): quit(2);return
 content=GameContent.new()
 test_malformed();test_source_spoof();test_caught_resume()
 var report: Dictionary={"suite":"adversarial-contracts","checks":checks,"failures":failures,"engine":Engine.get_version_info().string}
 write_text(RuntimePaths.report_path("adversarial-contracts.json"),JSON.stringify(report,"  "))
 print("ADVERSARIAL: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)


func test_caught_resume() -> void:
 var caught: Variant=prepare_finale(true)
 caught.advance(240)
 check(caught.finale.phase=="caught" and caught.mode=="menu","caught setup pauses input")
 var restored: GameSession=GameSession.new(content)
 check(restored.restore(caught.snapshot()),"caught state restores")
 check(restored.mode=="menu","restored caught state remains paused until retry")
 var before: int=restored.tick
 restored.advance(30)
 check(restored.tick==before,"caught reload cannot resume world simulation")

