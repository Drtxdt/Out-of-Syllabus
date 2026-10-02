extends SceneTree
## Domain regression: fixture writes are deliberate unit setup, never input walkthrough.
var checks: int = 0
var failures: Array[String] = []
var content: GameContent

func check(value: bool, label: String) -> bool:
 checks += 1
 if not value:
  failures.append(label)
  push_error(label)
 return value

func canonical(value: Variant) -> String:
 return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func denied(session: Variant, kind: String, target: String, payload: Dictionary = {}) -> void:
 var before: String = canonical(session.snapshot())
 check(not session.command(kind,target,payload).ok,"reject " + kind + "/" + target)
 check(canonical(session.snapshot()) == before,"denial is atomic " + kind + "/" + target)

func fixture() -> Variant:
 var session: Variant = GameSession.new(content)
 session.room_id = "lab"
 session.player_position = Vector2(304,152)
 session.inventory.append("kit")
 session.world.lab_gate = true
 return session

func measure(session: Variant, experiment: String = "mass", medium: String = "air", shape: String = "flat") -> String:
 var count: int = session.evidence.size()
 var result: Dictionary = session.command("experiment","lab_drop",{"experiment":experiment,"medium":medium,"shape":shape})
 if not check(result.ok,"release " + experiment + "/" + medium): return ""
 check(session.evidence.size() == count,"release does not manufacture immediate evidence")
 session.advance(600)
 if not check(session.evidence.size() == count + 1,"physical measurement creates one record"): return ""
 var record: Dictionary = session.evidence.back()
 check(not record.observed_by_player,"instrument output not automatically read")
 check(session.command("read_evidence",record.id).ok,"read measured output")
 return record.id

func play_proof(session: Variant, ids: Array, repeat: bool = false) -> void:
 for card: String in ["observe","control","repeat" if repeat else "measurement","gravity"]:
  check(session.play_card(card,ids).ok,"play " + card)

func test_evidence() -> void:
 var s: Variant = fixture()
 denied(s,"experiment","lab_drop",{"experiment":"mass","medium":"water","shape":"flat"})
 denied(s,"resolve","mass")
 check(not s.start_battle("mass"),"no empty proof encounter at initial phase")
 var id: String = measure(s)
 if id.is_empty(): return
 var record: Dictionary = s.evidence[0]
 check(record.has_all(["id","source_event_id","source_cycle","cycle","tick","room_id","experiment_id","setup","observations","origin_actor","observed_by_player","simulator_version"]),"complete evidence provenance")
 check(record.observations.has_all(["arrival_times_s","comparison","tolerance_s"]),"measurement carries uncertainty")
 check(record.setup.height_m == 2.0 and record.setup.initial_velocity_m_s == 0.0,"controlled drop setup")
 check(record.source_event_id.begins_with("c1:e"),"stable source event identity")
 var first: String = canonical(record)
 var second: String = measure(s)
 check(id != second and s.evidence[0].source_event_id != s.evidence[1].source_event_id,"independent releases distinct")
 check(canonical(s.evidence[0]) == first,"later experiment does not alter previous evidence")
 s.cycle = 2
 if check(s.start_battle("mass"),"mass encounter with records"):
  play_proof(s,[id])
  check(s.battle.state.won,"measurement proof wins")
  check(s.finish_battle(),"valid proof settles")
  check(s.world.mass,"mass reward awarded")
 var repeat_session: Variant = fixture()
 var a: String = measure(repeat_session)
 var b: String = measure(repeat_session)
 repeat_session.cycle = 2
 if check(repeat_session.start_battle("mass"),"repeat encounter"):
  play_proof(repeat_session,[a,b],true)
  check(repeat_session.battle.state.won,"independent repeated proof wins")
 var duplicate: Variant = fixture()
 var only: String = measure(duplicate)
 duplicate.cycle = 2
 if duplicate.start_battle("mass"):
  duplicate.play_card("observe",[only]);duplicate.play_card("control",[only])
  duplicate.play_card("repeat",[only,only]);duplicate.play_card("gravity",[only])
  check(not duplicate.battle.state.won,"duplicate citation cannot count as repeated experiment")
  duplicate.battle.state.won = true
  check(not duplicate.finish_battle() and not duplicate.world.mass,"tampered won cannot grant reward")
 var unread: Variant = fixture()
 var unread_id: String = measure(unread)
 unread.evidence[0].observed_by_player = false
 unread.cycle = 2
 if unread.start_battle("mass"):
  unread.play_card("observe",[unread_id]);unread.play_card("control",[unread_id])
  unread.play_card("measurement",[unread_id]);unread.play_card("gravity",[unread_id])
  check(not unread.battle.state.won,"unread instrument result cannot prove model")
 else:
  check(true,"unread-only encounter denied")

func test_holds() -> void:
 var s: Variant = fixture()
 s.player_position = Vector2(144,144)
 denied(s,"hold_begin","assist_a")
 s.tick = 7200
 check(s.command("hold_begin","assist_a").ok,"first cycle A is reachable after preparation")
 check(s.holds.has("assist_a"),"A held")
 denied(s,"hold_begin","assist_b")
 s.player_position = Vector2(304,152)
 s.advance()
 check(s.holds.is_empty(),"leaving automatically releases station")
 s.player_position = Vector2(144,144)
 check(s.command("hold_begin","assist_a").ok,"restart released station")
 s.advance(721)
 check(s.holds.is_empty(),"hold expires after twelve seconds")
 check(s.track.events.filter(func(e: Dictionary) -> bool: return e.kind == "hold_end").size() >= 1,"hold end recorded semantically")
 var vacuum: Variant = fixture()
 vacuum.cycle = 3;vacuum.world.pump = true
 denied(vacuum,"experiment","lab_drop",{"experiment":"initial","medium":"vacuum","shape":"flat"})
 # Injecting apparent station ownership is not a substitute for valid historical actors.
 vacuum.holds = {"assist_a":{"actor":"player","begin":0,"end":720},"assist_b":{"actor":"player","begin":0,"end":720}}
 denied(vacuum,"experiment","lab_drop",{"experiment":"initial","medium":"vacuum","shape":"flat"})

func test_checkpoint() -> void:
 var s: Variant = fixture()
 measure(s)
 s.set_checkpoint()
 var original: String = canonical(s.snapshot())
 var sealed: String = canonical(s.histories)
 measure(s,"shape","air","crumpled")
 check(s.rewind(),"rewind available")
 check(canonical(s.snapshot()) == original,"checkpoint rolls back new measurement and clock")
 check(canonical(s.histories) == sealed,"checkpoint cannot rewrite sealed history")
 var continuous: Variant = fixture()
 var resumed: Variant = fixture()
 check(resumed.restore(continuous.snapshot()),"snapshot restores before simulation")
 continuous.advance(600)
 resumed.advance(200)
 var middle: Dictionary = resumed.snapshot()
 check(resumed.restore(middle),"midpoint restore")
 resumed.advance(400)
 check(canonical(continuous.snapshot()) == canonical(resumed.snapshot()),"continuous and restored simulation identical")

func write_text(path: String, value: String) -> void:
 var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
 if not check(file != null,"open fixture " + path): return
 file.store_string(value);file.close()

func envelope(path: String, payload: Dictionary) -> void:
 var raw: String = JSON.stringify(payload)
 write_text(path,JSON.stringify({"payload":raw,"sha256":raw.sha256_text()}))

func test_storage() -> void:
 var s: Variant = GameSession.new(content)
 var store: SaveStore = SaveStore.new(RuntimePaths.data_root() + "/v02-domain.json")
 var restored: Variant = GameSession.new(content)
 check(store.save_session(s),"initial save")
 check(store.save_session(s),"backup established")
 write_text(store.path,"broken")
 check(store.load_session(restored),"first backup recovery")
 check(store.save_session(restored),"save after recovery")
 write_text(store.path,"broken again")
 check(store.load_session(restored),"second backup recovery retains last valid data")
 var stable: String = canonical(restored.snapshot())
 for fault: String in ["open","write","copy","rename"]:
  store.fail_step = "";check(store.save_session(s),"reset before fault " + fault)
  store.fail_step = fault
  check(not store.save_session(s),"simulated fault detected " + fault)
  store.fail_step = ""
  check(store.load_session(restored),"fault leaves recoverable data " + fault)
  check(canonical(restored.snapshot()) == stable,"fault recovery data intact " + fault)
 for key: String in ["world","profile","track","histories","echo_cursors","position","battle"]:
  var malformed: Dictionary = s.snapshot()
  malformed[key] = "malformed"
  check(not restored.restore(malformed),"malformed snapshot rejects " + key)
  check(canonical(restored.snapshot()) == stable,"malformed restore atomic " + key)
 var bad: Dictionary = s.snapshot()
 bad.track.events = [{"seq":1,"cycle":1,"tick":0,"actor":"player","room":"classroom","kind":"switch","target":"switch_a","payload":[]}]
 check(not restored.restore(bad),"nested payload array rejected")
 check(canonical(restored.snapshot()) == stable,"nested failure atomic")
 var future: Dictionary = {"schema":999,"content_version":2,"chapter":"fall","state":s.snapshot(),"checkpoint":{}}
 envelope(store.path,future)
 check(not store.load_session(restored),"future schema cannot fall back to older backup")
 future.schema = 3;future.content_version = 999;envelope(store.path,future)
 check(not store.load_session(restored),"future content cannot fall back")
 # Real filesystem failure, separate from fail_step simulation: parent is a regular file.
 var blocker: String = RuntimePaths.data_root()+"/not-a-directory"
 write_text(blocker,"blocking file")
 var physical_failure: SaveStore = SaveStore.new(blocker+"/progress.json")
 check(not physical_failure.save_session(s),"real invalid filesystem parent reports write failure")
 check(canonical(s.snapshot()) == stable,"real write failure leaves session intact")

func _initialize() -> void:
 if RuntimePaths.profile_id().is_empty():
  push_error("A unique --qa-profile is mandatory; refusing live userdata.")
  quit(2);return
 content = GameContent.new()
 check(SaveStore.SCHEMA == 3,"schema 3")
 var probe: Variant = GameSession.new(content)
 if probe.get("evidence") == null:
  check(false,"v0.2 core required")
 else:
  test_evidence();test_holds();test_replay_rig();test_checkpoint();test_storage()
 var report: Dictionary = {"suite":"v02-domain","kind":"unit fixtures, not input walkthrough","checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"profile":RuntimePaths.profile_id(),"limitations":["No GUI screenshot or human playtime claim","Certificate-store errors must be reported from process log separately"]}
 write_text(RuntimePaths.report_path("v02-regression.json"),JSON.stringify(report,"  "))
 print("V02 REGRESSION: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)

func replay_track(cycle_number: int, station: String, position: Vector2, leave_tick: int = 7921) -> Dictionary:
 return {"cycle":cycle_number,"track":{"samples":[
  {"tick":7199,"room":"lab","x":position.x,"y":position.y,"direction":"up","moving":false},
  {"tick":leave_tick,"room":"lab","x":304.0,"y":240.0,"direction":"down","moving":true}],
  "events":[{"seq":1,"cycle":cycle_number,"tick":7200,"actor":"player","room":"lab","kind":"hold_begin","target":station,"payload":{}},
  {"seq":2,"cycle":cycle_number,"tick":7920,"actor":"player","room":"lab","kind":"hold_end","target":station,"payload":{}}]}}

func rig_fixture(echo_count: int = 2, leave_tick: int = 7921) -> Variant:
 var s: Variant = fixture()
 s.cycle = 3;s.tick = 7198;s.world.pump = true
 if echo_count >= 1:
  s.histories.append(replay_track(1,"assist_a",Vector2(144,144),leave_tick))
  s.echo_cursors.append(0);s.echo_sample_cursors.append(0)
 if echo_count >= 2:
  s.histories.append(replay_track(2,"assist_b",Vector2(464,144)))
  s.echo_cursors.append(0);s.echo_sample_cursors.append(0)
 return s

func test_replay_rig() -> void:
 for count: int in [0,1]:
  var incomplete: Variant = rig_fixture(count)
  incomplete.advance(2)
  denied(incomplete,"experiment","lab_drop",{"experiment":"initial","medium":"vacuum","shape":"flat"})
 var s: Variant = rig_fixture()
 var sealed: String = canonical(s.histories)
 s.advance(2)
 check(s.holds.size() == 2,"two historical roles hold A and B simultaneously")
 check(s.holds.get("assist_a",{}).get("actor","") != s.holds.get("assist_b",{}).get("actor",""),"historical station actors distinct")
 measure(s,"initial","vacuum")
 check(canonical(s.histories) == sealed,"replaying measurement preserves sealed history")
 var left: Variant = rig_fixture(2,7201)
 left.advance(3)
 check(not left.holds.has("assist_a"),"historical pose leaving releases A without rendering")
 denied(left,"experiment","lab_drop",{"experiment":"initial","medium":"vacuum","shape":"flat"})
 var power: Variant = rig_fixture()
 power.player_position = Vector2(560,240)
 check(power.command("switch","rig_power",{"value":false}).ok,"player may cut rig power")
 power.advance(2)
 check(power.holds.is_empty(),"power loss prevents historical hold")
 check(not power.deviations.is_empty(),"failed history has actionable causal deviation")
 check(canonical(power.histories) == sealed,"causal failure cannot rewrite history")
 var late: Variant = rig_fixture()
 late.advance(723)
 check(late.holds.is_empty(),"missed window does not silently shift history")
 denied(late,"experiment","lab_drop",{"experiment":"initial","medium":"vacuum","shape":"flat"})
 var regular: Variant = rig_fixture()
 var fast: Variant = rig_fixture()
 regular.advance(2)
 fast.wait_next()
 check(fast.tick == regular.tick,"wait stops at actual next historical action")
 check(canonical(fast.world) == canonical(regular.world) and canonical(fast.holds) == canonical(regular.holds),"wait settles same rig actions as ticks")

