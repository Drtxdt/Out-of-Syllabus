extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var content: GameContent
func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition: failures.append(label);push_error(label)
func solve(session: GameSession, id: String, repeat: bool = false) -> void:
 check(session.start_battle(id),"start "+id)
 var cards: Array = ["observe","control","repeat" if repeat else "measurement","gravity"]
 if id == "drag": cards += ["shape","vacuum","drag"]
 for card: String in cards: check(session.battle.play(content.cards[card]).ok,"play "+card)
 check(session.battle.state.won,"won "+id)
 check(session.finish_battle(),"settle "+id)
func envelope(path: String, payload: Dictionary) -> void:
 var raw: String = JSON.stringify(payload)
 var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"payload":raw,"sha256":raw.sha256_text()}));file.close()
func _initialize() -> void:
 content = GameContent.new()
 check(content.chapter.rooms.size()==6,"six rooms")
 check(content.cards.size()==13,"twelve cards and future card")
 for room: Dictionary in content.chapter.rooms: check(ResourceLoader.exists("res://world/rooms/"+room.id+".tscn"),"scene "+room.id)
 var a: float = ExperimentModel.fall_time(2,0.01,0.006,0)
 var b: float = ExperimentModel.fall_time(2,10,0.001,0)
 check(is_equal_approx(a,b),"vacuum mass independent")
 check(absf(a-sqrt(4.0/9.81))<0.0001,"vacuum analytic")
 check(ExperimentModel.fall_time(2,0.002,0.006)>ExperimentModel.fall_time(2,0.002,0.00025),"area changes drag")
 check(ExperimentModel.fall_time(-1,1,1)<0,"invalid experiment")
 var battle: ModelBattle = ModelBattle.new(content.encounters.drag)
 check(not battle.play(content.cards.measurement).ok,"measurement needs controlled conditions")
 for card: String in ["observe","control","measurement","gravity","vacuum"]: battle.play(content.cards[card])
 check(not battle.state.won,"vacuum cannot erase air counterexample")
 var count: int = battle.state.evidence.size()
 battle.play(content.cards.measurement)
 check(battle.state.evidence.size()==count,"duplicate evidence unique")
 check(not battle.play(content.cards.future).ok,"future card cannot bypass domain")
 battle.play(content.cards.shape);battle.play(content.cards.drag)
 check(battle.state.won,"drag complete explanation")
 var wrong: ModelBattle=ModelBattle.new(content.encounters.mass)
 for card: String in ["observe","control","measurement","weight"]: wrong.play(content.cards[card])
 check(not wrong.state.won,"heavy faster is not a law")
 check(not wrong.play(content.cards.domain).ok,"domain cannot rescue contradiction")
 var budget: ModelBattle=ModelBattle.new(content.encounters.mass)
 for i: int in range(16): budget.play(content.cards.observe)
 check(budget.state.failed,"finite experiment budget")
 var s: GameSession=GameSession.new(content)
 s.command("switch","switch_a",{"expected":false,"value":true});s.advance(6)
 s.command("visit","storage");s.command("switch","switch_b",{"expected":false,"value":true})
 s.command("pickup","kit");s.command("talk","lin",{"text":"history"});s.command("experiment","lab_drop")
 s.command("push","crate",{"expected":0})
 check(s.next_cycle(),"cycle two")
 var immutable: String=JSON.stringify(s.histories)
 s.command("push","crate",{"expected":0});s.advance(10)
 check(s.world.lab_gate,"unloaded room echo opens gate")
 check(s.inventory.is_empty(),"echo does not award inventory")
 check(s.deviations.size()==1,"altered crate reports deviation")
 check(s.track.events.size()==1,"echo not recursively recorded")
 check(JSON.stringify(s.histories)==immutable,"history remains immutable")
 var event_count: int=s.events.size();s.advance(10)
 check(s.events.size()==event_count,"echo cursor prevents duplicate commands")
 s.mode="menu";var old_tick: int=s.tick;s.advance(300)
 check(s.tick==old_tick,"menu pauses simulation");s.mode="world"
 s.set_checkpoint();s.advance(100);check(s.rewind() and s.tick==old_tick,"checkpoint restores clock")
 solve(s,"mass",true)
 check(s.next_cycle(),"cycle three")
 s.command("switch","pump",{"value":true});solve(s,"drag")
 check(s.command("ending","chapter_fall",{"accept":true}).ok,"accept ending")
 s.command("ending","chapter_fall",{"accept":true})
 check(s.profile.violation==1,"ending idempotent")
 var store: SaveStore=SaveStore.new("user://regression.json")
 check(store.save_session(s),"atomic initial save")
 var restored: GameSession=GameSession.new(content)
 check(store.load_session(restored),"save reload")
 check(restored.profile.completed and restored.histories.size()==2,"three cycles persist")
 check(store.save_session(s),"atomic overwrite on Windows")
 var bad: FileAccess=FileAccess.open(store.path,FileAccess.WRITE);bad.store_string("broken");bad.close()
 check(store.load_session(restored) and not store.last_error.is_empty(),"corrupt main recovers backup")
 var future: Dictionary={"schema":999,"content_version":1,"chapter":"fall","state":s.snapshot()}
 envelope(store.path,future)
 check(not store.load_session(restored),"newer version refuses downgrade")
 future.schema=1;future.state.erase("echo_sample_cursors");envelope(store.path,future)
 check(store.load_session(restored),"schema one migration")
 var mid: GameSession=GameSession.new(content);mid.start_battle("drag");mid.battle.play(content.cards.observe)
 store.save_session(mid);check(store.load_session(restored) and restored.mode=="model" and restored.battle.state.observed,"mid encounter restores")
 var declined: GameSession=GameSession.new(content);declined.world.drag=true
 declined.command("ending","chapter_fall",{"accept":false})
 check(declined.profile.completed and declined.profile.violation==0,"refuse ending")
 var compress: GameSession=GameSession.new(content);compress.profile.knowledge.append("gravity")
 compress.histories=[{"cycle":1,"track":{"samples":[],"events":[{"tick":30,"kind":"switch","target":"pump","payload":{"value":true}}]}}];compress.echo_cursors=[0];compress.echo_sample_cursors=[0]
 check(not compress.compress_lab().ok and compress.tick==30,"compression stops at causal change")
 check(not restored.restore({}),"invalid snapshot rejected")
 var ids: Dictionary={}
 for room: Dictionary in content.chapter.rooms:
  for item: Dictionary in room.objects:
   check(not ids.has(item.id),"unique object "+item.id);ids[item.id]=true
 var broken: Dictionary=s.snapshot();broken.world="bad"
 check(not restored.restore(broken),"invalid world type refused")
 broken=s.snapshot();broken.echo_sample_cursors=[]
 check(not restored.restore(broken),"invalid replay cursor count refused")
 var replay_a: GameSession=GameSession.new(content)
 replay_a.histories=compress.histories.duplicate(true);replay_a.echo_cursors=[0];replay_a.echo_sample_cursors=[0]
 var replay_b: GameSession=GameSession.new(content)
 check(replay_b.restore(replay_a.snapshot()),"restore before replay")
 replay_a.advance(100);replay_b.advance(20)
 store.save_session(replay_b);store.load_session(replay_b);replay_b.advance(80)
 check(JSON.stringify(JSON.parse_string(JSON.stringify(replay_a.snapshot())))==JSON.stringify(JSON.parse_string(JSON.stringify(replay_b.snapshot()))),"continuous and resumed replay deterministic")
 check(not replay_a.command("switch","drag",{"value":true}).ok,"switch cannot forge encounter success")
 check(ExperimentModel.fall_time(2,1,1,1,-1)<0,"invalid drag coefficient")
 var report: Dictionary={"checks":checks,"failures":failures,"engine":Engine.get_version_info().string}
 var output: FileAccess=FileAccess.open("res://reports/regression.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
 print("REGRESSION: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
