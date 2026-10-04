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
 if repeat:
  session.loadout.erase("measurement")
  if not "repeat" in session.loadout: session.loadout.append("repeat")
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
  test_evidence();test_holds();test_replay_rig();test_checkpoint();test_storage();test_legacy_invariants();test_drag_paths();test_finale_routes();test_recorded_three_cycles();test_input_settings_contract()
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


func test_legacy_invariants() -> void:
 check(content.chapter.rooms.size()==6,"six authored rooms retained")
 check(content.cards.size()==13,"thirteen cards including future retained")
 var object_ids: Dictionary={}
 for room: Dictionary in content.chapter.rooms:
  check(ResourceLoader.exists("res://world/rooms/"+room.id+".tscn"),"room scene " + room.id)
  for object: Dictionary in room.objects:
   check(not object_ids.has(object.id),"stable unique object " + object.id)
   object_ids[object.id]=true
 var free_a: float=ExperimentModel.fall_time(2,0.01,0.006,0)
 var free_b: float=ExperimentModel.fall_time(2,10,0.001,0)
 check(is_equal_approx(free_a,free_b),"vacuum mass independent")
 check(absf(free_a-sqrt(4.0/9.81))<0.0001,"vacuum analytic limit")
 check(ExperimentModel.fall_time(2,0.002,0.006)>ExperimentModel.fall_time(2,0.002,0.00025),"shape alters drag with same mass")
 check(ExperimentModel.fall_time(-1,1,1)<0,"invalid height rejects")
 check(ExperimentModel.fall_time(2,1,1,1,-1)<0,"invalid drag coefficient rejects")
 var s: Variant=fixture()
 var id: String=measure(s)
 var model: ModelBattle=ModelBattle.new(content.encounters.mass,s.evidence)
 check(not model.play(content.cards.measurement,[id]).ok,"measurement first requires controlled conditions")
 check(not model.play(content.cards.experiment,[id]).ok,"design first requires observation")
 check(not model.play(content.cards.future,[id]).ok,"future card cannot bypass model domain")
 for card: String in ["observe","control","measurement","weight"]: model.play(content.cards[card],[id])
 check(not model.state.won,"heavier-faster model conflicts with record")
 check(model.conditions().any(func(c: Dictionary) -> bool: return c.status=="contradicted"),"wrong model explains contradiction explicitly")
 check(not model.play(content.cards.domain,[id]).ok,"domain restriction cannot rescue wrong model")
 model.play(content.cards.rebuttal,[id])
 check(model.state.model=="none","counterexample withdraws mass hypothesis")
 var budget: ModelBattle=ModelBattle.new(content.encounters.mass,s.evidence)
 for _i: int in range(16): budget.play(content.cards.observe,[id])
 check(budget.state.failed,"finite round budget fails unfinished argument")
 var previous: String=canonical(budget.state)
 check(not budget.play(content.cards.gravity,[id]).ok and canonical(budget.state)==previous,"failed battle does not accept more cards")
 var p: Variant=GameSession.new(content)
 var before: int=p.tick
 p.mode="menu";p.advance(300)
 check(p.tick==before,"modal stops world and echo time")
 p.mode="world"
 denied(p,"visit","archive")
 denied(p,"switch","drag",{"value":true})
 denied(p,"pickup","kit")
 p.player_position=Vector2(432,136)
 check(p.command("switch","switch_a",{"value":true}).ok,"switch near correct room")
 denied(p,"switch","switch_a",{"expected":false,"value":false})
 denied(p,"switch","switch_a",{"value":"true"})
 # Echo switch attribution and replay cursor progression do not depend on rendering.
 var replay: Variant=GameSession.new(content)
 replay.cycle=2
 replay.histories=[{"cycle":1,"track":{"samples":[{"tick":0,"room":"storage","x":448,"y":128,"direction":"up","moving":false}],"events":[{"seq":1,"cycle":1,"tick":1,"actor":"player","room":"storage","kind":"switch","target":"switch_b","payload":{"value":true}}]}}]
 replay.echo_cursors=[0];replay.echo_sample_cursors=[0]
 var sealed: String=canonical(replay.histories)
 replay.advance(2)
 check(replay.world.switch_b,"offscreen historical switch acts")
 check(replay.events.size()==1 and replay.events[0].room=="storage" and replay.events[0].source_event_id=="c1:e1","echo preserves original room and source")
 check(replay.track.events.is_empty(),"echo does not recursively enter player track")
 replay.advance(20)
 check(replay.events.size()==1,"replay cursor avoids duplicate application")
 check(canonical(replay.histories)==sealed,"replay leaves sealed source unchanged")

func full_drag_fixture(repeat: bool=false) -> Variant:
 var s: Variant=fixture()
 measure(s,"mass")
 if repeat: measure(s,"mass")
 measure(s,"initial")
 measure(s,"shape")
 s.cycle=3;s.tick=7198;s.world.pump=true
 s.histories=[replay_track(1,"assist_a",Vector2(144,144)),replay_track(2,"assist_b",Vector2(464,144))]
 s.echo_cursors=[0,0];s.echo_sample_cursors=[0,0]
 s.advance(2)
 measure(s,"initial","vacuum")
 return s

func test_drag_paths() -> void:
 for repeat: bool in [false,true]:
  var s: Variant=full_drag_fixture(repeat)
  var ids: Array=[]
  for record: Dictionary in s.evidence: ids.append(record.id)
  if not check(s.start_battle("drag"),"start full drag proof"): continue
  play_proof(s,ids,repeat)
  check(not s.battle.state.won,"gravity alone cannot erase air difference")
  check(s.play_card("vacuum",ids).ok,"vacuum citation")
  check(not s.battle.state.won,"vacuum alone cannot erase air counterexample")
  check(s.play_card("shape",ids).ok,"shape citation")
  check(s.play_card("drag",ids).ok,"drag model revision")
  check(s.battle.state.won,"complete drag path " + ("repeat" if repeat else "measurement"))
  check(s.finish_battle() and s.world.drag,"drag settlement " + str(repeat))
  check("drag" in s.profile.knowledge,"drag knowledge granted")
  check(s.knowledge_access.drag.understood and s.knowledge_access.drag.authorized,"understanding and authorization represented independently")

func prepare_finale(accepted: bool) -> Variant:
 var s: Variant=fixture()
 var calibration: String=measure(s,"initial")
 s.cycle=3;s.world.drag=true;s.room_id="archive";s.player_position=Vector2(320,160)
 check(s.command("choose_future","future_terminal",{"accept":accepted}).ok,"choose final route " + str(accepted))
 check(not s.profile.completed and s.profile.violation==0,"choice alone does not finish or violate")
 if accepted:
  denied(s,"predict_gate","future_terminal",{"model":"gravity","medium":"air","shape":"flat"})
  denied(s,"predict_gate","future_terminal",{"model":"drag","medium":"air","shape":"flat","height_m":1.0})
  denied(s,"predict_gate","future_terminal",{"model":"drag","medium":"vacuum","shape":"flat"})
  check(s.command("predict_gate","future_terminal",{"model":"drag","medium":"air","shape":"flat"}).ok,"valid numerical prediction")
  check(s.profile.violation==1 and s.finale.used,"actual future use records one violation")
  denied(s,"predict_gate","future_terminal",{"model":"drag","medium":"air","shape":"flat"})
  check(s.profile.violation==1,"duplicate prediction cannot double violation")
 else:
  denied(s,"calibrate_gate","future_terminal",{"evidence_id":"fake-prediction"})
  check(s.command("calibrate_gate","future_terminal",{"evidence_id":calibration}).ok,"existing measurement calibrates refuse route")
  check(s.profile.violation==0,"measurement route has no violation")
 return s

func complete_finale(s: Variant) -> void:
 s.room_id="corridor";s.player_position=Vector2(224,256)
 denied(s,"visit","tower")
 check(s.command("gate_release","fall_gate").ok,"manual falling-gate release")
 var opening: int=int(s.finale.open_tick)
 s.advance(opening-s.tick-1)
 denied(s,"visit","tower")
 s.advance(1)
 check(s.command("visit","tower").ok,"tower entry during measured/predicted window")
 check(not s.profile.completed and s.finale.phase=="escaped","arrival does not auto-submit")
 s.player_position=Vector2(320,144)
 check(s.command("ending","cycle_console").ok,"tower terminal submits record")
 var violation: int=s.profile.violation
 var event_count: int=s.events.size()
 check(s.command("ending","cycle_console").ok,"repeat ending safely acknowledged")
 check(s.events.size()==event_count and s.profile.violation==violation,"ending idempotent")
 check(s.profile.completed and s.finale.phase=="complete","finale complete persisted")
 var restored: Variant=GameSession.new(content)
 check(restored.restore(s.snapshot()),"completed finale snapshot valid")
 check(restored.profile.completed and restored.profile.violation==violation,"completion survives restore")

func test_finale_routes() -> void:
 var accepted: Variant=prepare_finale(true)
 accepted.advance(120)
 check(accepted.finale.phase=="chase","warning transitions to chase on clock")
 accepted.advance(120)
 check(accepted.finale.phase=="caught" and accepted.mode=="menu","examiner contact creates retry state")
 check(accepted.rewind(),"caught can restore local checkpoint")
 check(accepted.finale.phase=="warning" and accepted.profile.violation==1,"rewind preserves once-only ability use")
 complete_finale(accepted)
 var refused: Variant=prepare_finale(false)
 complete_finale(refused)
 var late: Variant=prepare_finale(false)
 late.room_id="corridor";late.player_position=Vector2(224,256)
 late.command("gate_release","fall_gate")
 late.advance(int(late.finale.close_tick)-late.tick+1)
 denied(late,"visit","tower")
 check(late.command("gate_release","fall_gate").ok,"missed falling-gate window can be released again")
 var dodging: Variant=prepare_finale(true)
 dodging.finale.phase="chase";dodging.finale.examiner_position=[320.0,160.0]
 check(dodging.command("dodge","").ok,"dodge begins")
 dodging.advance()
 check(dodging.finale.phase=="chase","dodge avoids contact")
 denied(dodging,"dodge","")
 dodging.advance(10)
 check(dodging.finale.phase=="caught","expired dodge no longer avoids contact")


func test_recorded_three_cycles() -> void:
 # Domain fixture positions bypass navigation only; all recordings and settlements are real commands.
 var s: Variant=fixture()
 measure(s,"initial")
 s.player_position=Vector2(144,144)
 check(s.wait_next().ok and s.tick==7200,"first preparation advances to actual A start")
 check(s.command("hold_begin","assist_a").ok,"record first A action")
 s.advance(720)
 check(s.can_cycle(),"first recording meets sealing requirements")
 s.room_id="tower";s.player_position=Vector2(320,144)
 check(s.next_cycle(),"seal real first timeline")
 var first: String=canonical(s.histories[0])
 s.room_id="lab";s.player_position=Vector2(304,152);s.inventory.append("kit")
 var mass: String=measure(s,"mass")
 check(s.start_battle("mass"),"second cycle mass argument")
 play_proof(s,[mass]);check(s.finish_battle(),"second cycle mass complete")
 s.player_position=Vector2(464,144)
 check(s.wait_next().ok and s.tick==7200,"wait locates recorded A time")
 check(s.command("hold_begin","assist_b").ok,"record B beside playing A")
 s.advance(720)
 check(s.can_cycle(),"real A/B overlap allows second seal")
 s.room_id="tower";s.player_position=Vector2(320,144)
 check(s.next_cycle(),"seal real second timeline")
 check(canonical(s.histories[0])==first,"second seal preserves first timeline")
 var sealed: String=canonical(s.histories)
 s.room_id="lab";s.player_position=Vector2(304,152);s.inventory.append("kit")
 measure(s,"shape")
 s.room_id="storage";s.player_position=Vector2(432,232)
 check(s.command("switch","pump",{"value":true}).ok,"third cycle pump physically operated")
 s.room_id="lab";s.player_position=Vector2(304,152)
 check(s.wait_next().ok and s.tick==7200,"third cycle aligns to real historical participants")
 measure(s,"initial","vacuum")
 check(canonical(s.histories)==sealed,"joint measurement never mutates either recording")
 var ids: Array=[]
 for record: Dictionary in s.evidence: ids.append(record.id)
 check(s.start_battle("drag"),"real three-loop drag argument")
 play_proof(s,ids)
 for card: String in ["shape","vacuum","drag"]: check(s.play_card(card,ids).ok,"three-loop proof " + card)
 check(s.finish_battle(),"three-loop valid settlement")
 s.set_checkpoint()
 var store: SaveStore=SaveStore.new(RuntimePaths.data_root()+"/real-three-tracks.json")
 var did_save: bool=store.save_session(s)
 if not did_save: print("THREE TRACK SAVE: ",store.last_error," state=",SaveValidator.validate(s.snapshot(),content)," checkpoint=",SaveValidator.validate(s.checkpoint,content)," cycle=",SaveValidator.validate(s.cycle_checkpoint,content)," temp=",SaveValidator.validate(store._read(store.path+".tmp").get("state"),content))
 check(did_save,"real three-loop provenance saves")
 var restored: GameSession=GameSession.new(content)
 check(store.load_session(restored),"real three-loop provenance reloads")
 check(canonical(restored.snapshot())==canonical(s.snapshot()),"full evidence and histories round trip")
 check(restored.restart_cycle(),"cycle-start retry restores preserved two histories")
 check(restored.cycle==3 and restored.tick==0 and canonical(restored.histories)==sealed,"cycle retry starts current loop without editing past")



func test_input_settings_contract() -> void:
 var settings: InputSettings=InputSettings.new()
 check(settings.path.begins_with(RuntimePaths.data_root()),"settings use isolated QA profile")
 var old_up: int=settings.keys.move_up
 var old_left: int=settings.keys.move_left
 settings.bind_key("move_up",old_left)
 check(settings.keys.move_up==old_left and settings.keys.move_left==old_up,"conflicting key binding swaps instead of losing an action")
 var loaded: InputSettings=InputSettings.new()
 check(loaded.keys.move_up==old_left and loaded.keys.move_left==old_up,"remapping persists inside QA profile")
 var seen: Dictionary={}
 for action_name: String in loaded.keys:
  check(not seen.has(loaded.keys[action_name]),"key binding unique " + action_name)
  seen[loaded.keys[action_name]]=true
  check(InputMap.has_action(action_name) and not InputMap.action_get_events(action_name).is_empty(),"configured action has input event " + action_name)
 loaded.bind_key("move_up",old_up)

