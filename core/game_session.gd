class_name GameSession
extends RefCounted
signal changed
signal notice(text: String)
const SAMPLE_INTERVAL: int = 6
var content: GameContent
var cycle: int = 1
var tick: int = 0
var room_id: String = "classroom"
var player_position: Vector2 = Vector2(320, 224)
var direction: String = "down"
var mode: String = "world"
var profile: Dictionary = {"knowledge": [], "choices": {}, "violation": 0, "hints": 0, "completed": false}
var world: Dictionary = {}
var inventory: Array = []
var visited: Array = []
var histories: Array = []
var track: Dictionary = {"samples": [], "events": []}
var events: Array = []
var echo_cursors: Array = []
var echo_sample_cursors: Array = []
var deviations: Array = []
var settled: Array = []
var checkpoint: Dictionary = {}
var battle: ModelBattle
var loadout: Array = ["gravity", "control", "measurement", "shape", "vacuum", "drag"]
var _seq: int = 0
var _replay_source: Dictionary = {}
var evidence: Array = []
var pending_experiment: Dictionary = {}
var holds: Dictionary = {}
var finale: Dictionary = {"phase":"none","choice":false,"used":false,"prediction":{},"release_tick":-1,"open_tick":-1,"close_tick":-1,"warning_end":0,"examiner_room":"archive","examiner_position":[320.0,280.0],"arrival_tick":0}
var knowledge_access: Dictionary = {}
var cycle_checkpoint: Dictionary = {}
var checkpoint_locked: bool = false
var dodge_ticks: int = 0
var dodge_cooldown_ticks: int = 0
func _init(data: GameContent = null) -> void:
 content = data if data != null else GameContent.new()
 reset_world()
func reset_world() -> void:
 world = {"switch_a": false, "switch_b": false, "crate": 0, "lab_gate": false, "pump": false, "experiment": false, "mass": false, "drag": false, "coil_disabled": false, "rig_power": true}
 inventory = []
 visited = ["classroom"]
func sample(moving: bool = false, force: bool = false) -> void:
 if force or tick % SAMPLE_INTERVAL == 0 or track.samples.is_empty():
  track.samples.append({"tick": tick, "room": room_id, "x": player_position.x, "y": player_position.y, "direction": direction, "moving": moving})
func advance(steps: int = 1, moving: bool = false) -> void:
 if mode != "world": return
 for _i: int in range(steps):
  tick += 1
  dodge_ticks=maxi(0,dodge_ticks-1);dodge_cooldown_ticks=maxi(0,dodge_cooldown_ticks-1)
  for h: int in range(histories.size()):
   var actions: Array = histories[h].track.events
   var cursor: int = int(echo_cursors[h])
   while cursor < actions.size() and int(actions[cursor].tick) <= tick:
    var ev: Dictionary = actions[cursor]
    _replay_source={"actor":"echo_%d" % int(histories[h].cycle),"event":ev}
    var result: Dictionary = command(ev.kind,ev.target,ev.payload,"echo_%d" % int(histories[h].cycle),{"source_cycle":histories[h].cycle,"source_event_id":"c%d:e%d" % [histories[h].cycle,ev.seq],"source_room":ev.room})
    _replay_source={}
    if not result.ok: _deviation(ev,result.message)
    cursor+=1
   echo_cursors[h]=cursor
  _advance_holds()
  _advance_experiment()
  _advance_finale()
  sample(moving)
  if mode!="world": break

func _deviation(event: Dictionary, reason: String) -> void:
 var message: String="历史 %s · %s：%s" % [event.get("cycle","?"),event.target,reason]
 deviations.append({"tick":tick,"message":message,"source_event_id":"c%d:e%d" % [event.get("cycle",1),event.get("seq",0)],"expected":event.payload.duplicate(true),"actual":world.duplicate(true)})
 notice.emit(message)

func actor_pose(actor: String) -> Dictionary:
 if actor=="player": return {"room":room_id,"position":player_position}
 for h: Dictionary in histories:
  if actor!="echo_%d" % h.cycle: continue
  var samples: Array=h.track.samples
  var left: int=0
  var right: int=samples.size()
  while left<right:
   var middle: int=(left+right)/2
   if int(samples[middle].tick)<=tick: left=middle+1
   else: right=middle
  if left==0: return {}
  var point: Dictionary=samples[left-1]
  return {"room":point.room,"position":Vector2(point.x,point.y)}
 return {}

func _near(actor: String, object_id: String, distance: float=48.0) -> bool:
 var pose: Dictionary=actor_pose(actor)
 if pose.is_empty(): return false
 for room: Dictionary in content.chapter.rooms:
  for item: Dictionary in room.objects:
   if item.id==object_id: return room.id==pose.room and pose.position.distance_to(Vector2(item.x,item.y))<=distance
 return false

func _record(kind: String,target: String,payload: Dictionary,actor: String,context: Dictionary) -> Dictionary:
 _seq+=1
 var event: Dictionary={"seq":_seq,"cycle":cycle,"tick":tick,"actor":actor,"room":context.get("source_room",room_id),"kind":kind,"target":target,"payload":payload.duplicate(true)}
 event.merge(context)
 events.append(event)
 if actor=="player":
  sample(false,true);track.events.append(event.duplicate(true))
 changed.emit()
 return event

func _no(reason: String) -> Dictionary:
 return {"ok":false,"message":reason}

func echo_poses() -> Array:
 var poses: Array = []
 for h: int in range(histories.size()):
  var samples: Array = histories[h].track.samples
  if samples.is_empty(): continue
  var cursor: int = int(echo_sample_cursors[h])
  while cursor+1 < samples.size() and int(samples[cursor+1].tick) <= tick:
   cursor += 1
  echo_sample_cursors[h] = cursor
  if int(samples[cursor].tick) > tick: continue
  var pose: Dictionary = samples[cursor].duplicate()
  pose["cycle"] = histories[h].cycle
  if pose.room == room_id: poses.append(pose)
 return poses
func command(kind: String,target: String,payload: Dictionary={},actor: String="player",context: Dictionary={}) -> Dictionary:
 var echo: bool=actor!="player"
 if echo:
  if _replay_source.is_empty() or _replay_source.actor!=actor: return _no("回声缺少真实历史来源。")
  var source: Dictionary=_replay_source.event
  if source.kind!=kind or source.target!=target or source.payload!=payload or context.get("source_event_id")!="c%d:e%d" % [source.cycle,source.seq] or context.get("source_room")!=source.room: return _no("回声来源与封存操作不符。")
 if not echo and mode!="world" and kind in ["switch","push","pickup","talk","visit","hold_begin","hold_end","dodge","gate_release"]: return _no("请先返回现象界。")
 if not echo and finale.phase=="caught": return _no("请先恢复追逐检查点。")
 if echo and not kind in ["switch","push","experiment","hold_begin","hold_end"]: return {"ok":true,"message":"历史重现，不重复奖励。"}
 if kind in ["switch","push","pickup","talk","experiment","hold_begin","hold_end"] and not _near(actor,target,36.0 if kind.begins_with("hold") else 48.0): return _no("角色不在该装置的可操作位置。")
 var message: String="操作已记录。"
 match kind:
  "switch":
   if not target in ["switch_a","switch_b","pump","rig_power"] or not payload.get("value") is bool: return _no("机关或操作参数无效。")
   if payload.has("expected") and world[target]!=payload.expected: return _no("原计划机关状态与当前不同。")
   world[target]=payload.value;world.lab_gate=world.switch_a and world.switch_b
  "push":
   if target!="crate" or world.crate!=0 or payload.get("expected",0)!=0: return _no("箱子已移动，原路线条件不同。")
   world.crate=1
  "pickup":
   if content.object(target).get("kind")!="pickup": return _no("未知物品。")
   if not target in inventory: inventory.append(target)
  "talk":
   if content.object(target).get("kind")!="npc": return _no("未知人物。")
  "visit":
   var exit_item: Dictionary={}
   for item: Dictionary in content.room(room_id).objects:
    if item.kind=="exit" and item.target==target and _near(actor,item.id): exit_item=item;break
   if exit_item.is_empty(): return _no("请走到相邻区域的入口。")
   var requirement: String=exit_item.get("requires","")
   if not requirement.is_empty() and not world.get(requirement,false): return _no("门禁条件尚未满足。")
   if target=="tower" and finale.phase in ["warning","chase","ready"]:
    if tick<int(finale.open_tick) or tick>int(finale.close_tick): return _no("落体闸门尚未进入安全窗口，靠近闸门释放并等待。")
    finale.phase="escaped"
   room_id=target;player_position=Vector2(320,224)
   if not target in visited: visited.append(target)
   if finale.phase in ["warning","chase"]: finale.examiner_room=target;finale.examiner_position=[320.0,288.0];finale.arrival_tick=tick+60
  "experiment":
   if target!="lab_drop" or not pending_experiment.is_empty(): return _no("释放架正在工作。")
   var setup: Dictionary=ExperimentModel.setup(payload)
   if setup.is_empty(): return _no("请选择有效的实验、介质和形状；不能提交预测数值。")
   if not "kit" in inventory and not echo: return _no("需要本轮实验包。")
   if setup.medium=="vacuum" and (not world.pump or not world.rig_power): return _no("真空泵或实验供电未启动。")
   if setup.medium=="vacuum" and (cycle!=3 or not _rig_ready() or actor!="player"): return _no("最终真空实验需要回声 1 稳压 A、回声 2 安全锁 B，以及当前玩家在 C。")
   var observations: Dictionary=ExperimentModel.measure(setup)
   var source: String=str(context.get("source_event_id","c%d:e%d" % [cycle,_seq+1]))
   pending_experiment={"id":"record_"+source,"source_event_id":source,"source_cycle":context.get("source_cycle",cycle),"cycle":cycle,"tick":tick,"room_id":"lab","experiment_id":setup.experiment,"setup":setup,"observations":observations,"origin_actor":actor,"observed_by_player":false,"simulator_version":1,"finish_tick":tick+int(ceil(maxf(observations.arrival_times_s[0],observations.arrival_times_s[1])*60.0))+1,"joint":setup.medium=="vacuum"}
   mode="world"
   message="释放开始；请观察实际下落，完成后读取记录。"
  "read_evidence":
   if not _near(actor,"lab_drop"): return _no("请在实验台读取仪器。")
   var index: int=-1
   for i: int in range(evidence.size()):
    if evidence[i].id==target: index=i;break
   if index<0: return _no("仪器尚无这份测量记录。")
   if evidence[index].observed_by_player: return {"ok":true,"message":"此记录已读取。"}
   evidence[index].observed_by_player=true;_learn("observation")
  "hold_begin":
   if not target in ["assist_a","assist_b"] or not world.rig_power: return _no("稳压装置未供电，原计划要求供电正常。")
   if cycle==1 and target=="assist_a" and tick<7200: return _no("校准预约在 02:00，可在工位等待至预约。")
   for held: Dictionary in holds.values():
    if held.actor==actor: return _no("一个角色不能维持两个工位。")
   if holds.has(target): return _no("工位已被占用。")
   holds[target]={"actor":actor,"begin":tick,"end":tick+720,"overlap":0,"context":context.duplicate(true)}
   mode="world"
  "hold_end":
   if not holds.has(target) or holds[target].actor!=actor: return _no("该角色没有维持此工位。")
   var held: Dictionary=holds[target]
   payload={"duration":tick-int(held.begin),"overlap_ticks":held.overlap,"valid":world.rig_power}
   holds.erase(target)
  "resolve":
   if target in settled: return {"ok":true,"message":"结果已经结算。"}
   if mode!="model" or not _near(actor,"lab_drop") or battle==null or battle.definition.id!=target: return _no("没有可提交的论证。")
   var candidate: ModelBattle=ModelBattle.new(battle.definition,evidence)
   candidate.state=battle.state.duplicate(true);candidate.evaluate()
   if not candidate.state.won: return _no("当前模型没有解释全部真实记录。")
   settled.append(target);world[target]=true;_learn("gravity" if target=="mass" else "drag")
  "choose_future":
   if target!="future_terminal" or not world.drag or not _near(actor,"future_terminal") or not payload.get("accept") is bool: return _no("请完成论证并在档案终端选择。")
   if finale.phase!="none": return {"ok":true,"message":"本轮选择已记录。"}
   knowledge_access["future"]={"discovered":true,"understood":false,"authorized":false}
   finale.choice=payload.accept;finale.phase="chosen";profile.choices.future_card=payload.accept
  "predict_gate","calibrate_gate":
   if target!="future_terminal" or finale.phase!="chosen" or not _near(actor,"future_terminal"): return _no("请先在档案终端选择路线。")
   if kind=="predict_gate":
    if not finale.choice or payload.get("model")!="drag" or payload.get("medium")!="air" or payload.get("shape")!="flat": return _no("数值方法不能选择模型：需要适用于空气中展开纸片的阻力模型。")
    var setup: Dictionary=ExperimentModel.setup({"experiment":"initial","medium":"air","shape":"flat"})
    finale.prediction={"model":"drag","time_s":ExperimentModel.measure(setup).arrival_times_s[1],"origin":"prediction"}
    _learn("future")
    if not finale.used: profile.violation+=1;finale.used=true
    finale.phase="warning";finale.warning_end=tick+120
    finale.examiner_position=[320.0,288.0];finale.examiner_room="archive"
   else:
    if finale.choice: return _no("此路线选择了数值预测。")
    var observed: Dictionary={}
    for record: Dictionary in evidence:
     if record.id==payload.get("evidence_id") and record.observed_by_player and record.setup.experiment=="initial" and record.setup.medium=="air" and record.setup.shape=="flat": observed=record;break
    if observed.is_empty(): return _no("请引用空气中展开纸片的真实记录。")
    finale.prediction={"time_s":observed.observations.arrival_times_s[1],"origin":"measurement","evidence_id":observed.id};finale.phase="ready"
   mode="world"
  "gate_release":
   if not _near(actor,"fall_gate") or not finale.phase in ["warning","chase","ready"] or finale.prediction.is_empty(): return _no("请先在档案室建立预测或校准，再靠近落体闸门。")
   finale.release_tick=tick;finale.open_tick=tick+int(ceil(float(finale.prediction.time_s)*60.0));finale.close_tick=int(finale.open_tick)+180
   message="已释放；纸片落地后安全窗口维持 3 秒。"
  "dodge":
   if dodge_cooldown_ticks>0: return _no("闪避尚未恢复。")
   dodge_ticks=10;dodge_cooldown_ticks=48
  "ending":
   if target!="cycle_console": return _no("请提交到观测塔记录终端。")
   if profile.completed: return {"ok":true,"message":"本章已完成。"}
   if finale.phase!="escaped" or not _near(actor,"cycle_console"): return _no("抵达观测塔并提交记录后才能完成。")
   profile.completed=true;finale.phase="complete"
  _:
   return _no("不支持的操作。")
 _record(kind,target,payload,actor,context)
 if kind in ["predict_gate","calibrate_gate"]: checkpoint_locked=true;checkpoint=snapshot()
 return {"ok":true,"message":message}

func _learn(id: String) -> void:
 if not id in profile.knowledge: profile.knowledge.append(id)
 knowledge_access[id]={"discovered":true,"understood":true,"authorized":id in ["observation","gravity","drag"]}

func _rig_ready() -> bool:
 return world.rig_power and holds.has("assist_a") and holds.has("assist_b") and holds.assist_a.actor=="echo_1" and holds.assist_b.actor=="echo_2" and _near("player","lab_drop",36)

func _advance_holds() -> void:
 for station: String in holds.keys():
  if not holds.has(station): continue
  var held: Dictionary=holds[station]
  if station=="assist_b" and holds.has("assist_a") and holds.assist_a.actor=="echo_1" and held.actor=="player": held.overlap+=1
  if not world.rig_power or not _near(held.actor,station,36) or tick>=int(held.end):
   if held.actor=="player":
    var payload: Dictionary={"duration":tick-int(held.begin),"overlap_ticks":held.overlap,"valid":world.rig_power and _near("player",station,36)}
    holds.erase(station);_record("hold_end",station,payload,"player",{})
   else:
    holds.erase(station)
    if tick<int(held.end): deviations.append({"tick":tick,"message":"%s 的 %s 操作中断：供电或站位与原计划不同。" % [held.actor,station]})

func experiment_display() -> Array:
 if pending_experiment.is_empty(): return [0.0,0.0]
 var fractions: Array=[]
 var elapsed: float=(tick-int(pending_experiment.tick))/60.0
 for specimen: Dictionary in pending_experiment.setup.samples:
  fractions.append(ExperimentModel.distance_at(elapsed,specimen,pending_experiment.setup.air_density)/2.0)
 return fractions
func _advance_experiment() -> void:
 if pending_experiment.is_empty(): return
 if pending_experiment.joint and not _rig_ready():
  pending_experiment={};notice.emit("联合实验中断：A/B/C 必须在整个测量期间有效。");return
 if tick<int(pending_experiment.finish_tick): return
 var record: Dictionary=pending_experiment.duplicate(true)
 record.erase("finish_tick");record.erase("joint")
 if not evidence.any(func(item: Dictionary) -> bool: return item.source_event_id==record.source_event_id): evidence.append(record)
 pending_experiment={};world.experiment=true
 notice.emit("仪器完成测量。靠近实验台读取记录，才能用于论证。")
 changed.emit()

func _advance_finale() -> void:
 if finale.phase=="warning" and tick>=int(finale.warning_end): finale.phase="chase";notice.emit("监考者开始追踪！利用闪避，穿过闸门抵达观测塔。")
 if finale.phase!="chase" or finale.examiner_room!=room_id or tick<int(finale.arrival_tick): return
 var position: Vector2=Vector2(finale.examiner_position[0],finale.examiner_position[1])
 position=position.move_toward(player_position,110.0/60.0)
 finale.examiner_position=[position.x,position.y]
 if position.distance_to(player_position)<18.0 and dodge_ticks==0:
  finale.phase="caught";mode="menu";notice.emit("被监考者拦截。恢复追逐前检查点，不重跑三个循环。")

func wait_next() -> Dictionary:
 if mode!="world": return _no("请先返回现象界。")
 if finale.phase in ["warning","chase"]: return _no("追踪期间不能快进。")
 var goal: int=7200 if cycle==1 and tick<7200 else tick+300
 for held: Dictionary in holds.values():
  if held.actor=="player": goal=int(held.end)
 for h: Dictionary in histories:
  for ev: Dictionary in h.track.events:
   if ev.kind=="hold_begin" and int(ev.tick)>tick: goal=int(ev.tick) if goal==tick+300 else mini(goal,int(ev.tick));break
 var before: int=deviations.size()
 while tick<goal:
  advance()
  if deviations.size()>before or mode!="world": break
 return {"ok":true,"message":"已逐步结算到 %02d:%02d。" % [tick/3600,(tick/60)%60]}

func causal_view() -> Dictionary:
 var rows: Array=[]
 for h: Dictionary in histories:
  var row: Dictionary={"cycle":h.cycle,"next_tick":-1,"action":"已结束"}
  for ev: Dictionary in h.track.events:
   if int(ev.tick)>tick and ev.kind.begins_with("hold"):
    row.next_tick=ev.tick;row.action=ev.kind+" / "+ev.target
    row.expected="实验供电接通；原角色在实验室工位 36 像素内；工位可用。"
    var actor: String="echo_%d" % h.cycle
    row.actual="供电%s；角色%s；工位%s。" % ["接通" if world.rig_power else "断开","已到位" if _near(actor,ev.target,36) else "尚未到位","占用中" if holds.has(ev.target) else "空闲"]
    break
  rows.append(row)
 return {"tick":tick,"histories":rows,"holds":holds.duplicate(true),"deviations":deviations.duplicate(true),"can_retry":not checkpoint.is_empty()}

func can_cycle() -> bool:
 var calibrated: bool=false
 for event: Dictionary in track.events:
  if event.kind=="hold_end" and event.payload.get("valid",false) and int(event.payload.get("duration",0))>=720:
   if cycle==1 and event.target=="assist_a": calibrated=true
   if cycle==2 and event.target=="assist_b" and int(event.payload.get("overlap_ticks",0))>=360: calibrated=true
 return calibrated and ((cycle==1 and world.experiment and "observation" in profile.knowledge) or (cycle==2 and world.mass))
func next_cycle() -> bool:
 if not can_cycle() or cycle >= 3 or not _near("player","cycle_console") or mode=="model": return false
 sample()
 histories.append({"cycle":cycle,"track":track.duplicate(true)})
 cycle += 1;tick = 0;room_id = "classroom";player_position = Vector2(320,224)
 track = {"samples":[],"events":[]};events = [];settled = [];deviations = []
 echo_cursors = [];echo_sample_cursors = []
 for _h: Dictionary in histories:
  echo_cursors.append(0);echo_sample_cursors.append(0)
 reset_world();mode = "world";battle = null;holds={};pending_experiment={};checkpoint_locked=false
 checkpoint={};cycle_checkpoint=snapshot();set_checkpoint()
 changed.emit()
 return true
func start_battle(id: String) -> bool:
 if mode!="world" or not content.encounters.has(id) or id in settled or not _near("player","lab_drop"): return false
 if (id=="mass" and cycle!=2) or (id=="drag" and cycle!=3): return false
 if not evidence.any(func(record: Dictionary) -> bool: return record.observed_by_player and record.setup.experiment=="mass"): return false
 if id=="drag" and not evidence.any(func(record: Dictionary) -> bool: return record.observed_by_player and record.setup.medium=="vacuum"): return false
 battle=ModelBattle.new(content.encounters[id],evidence);mode="model"
 return true
func suspend_battle() -> void:
 if battle!=null: battle.state.suspended=true
 mode="world"
func resume_battle() -> bool:
 if battle==null or not _near("player","lab_drop"): return false
 battle.state.suspended=false;mode="model"
 return true
func play_card(id: String, ids: Array=[]) -> Dictionary:
 if mode!="model" or battle==null or battle.state.suspended or not content.cards.has(id): return _no("没有当前论证或未知卡牌。")
 var result: Dictionary=battle.play(content.cards[id],ids)
 if result.ok: _record("play_card",id,{"evidence_ids":ids},"player",{})
 return result
func finish_battle() -> bool:
 if battle==null: return false
 var result: Dictionary=command("resolve",battle.definition.id)
 if not result.ok: return false
 battle=null;mode="world";checkpoint_locked=false
 return true
func compress_lab() -> Dictionary:
 return wait_next()
func restart_cycle() -> bool:
 if cycle_checkpoint.is_empty(): return false
 var saved: Dictionary=cycle_checkpoint.duplicate(true)
 if not restore(saved): return false
 cycle_checkpoint=saved;checkpoint_locked=false;set_checkpoint()
 return true
func snapshot() -> Dictionary:
 return {"cycle":cycle,"tick":tick,"room":room_id,"position":[player_position.x,player_position.y],"direction":direction,
  "profile":profile.duplicate(true),"world":world.duplicate(true),"inventory":inventory.duplicate(),"visited":visited.duplicate(),
  "histories":histories.duplicate(true),"track":track.duplicate(true),"events":events.duplicate(true),"echo_cursors":echo_cursors.duplicate(),
  "echo_sample_cursors":echo_sample_cursors.duplicate(),"deviations":deviations.duplicate(true),"settled":settled.duplicate(),
  "evidence":evidence.duplicate(true),"pending_experiment":pending_experiment.duplicate(true),"holds":holds.duplicate(true),"finale":finale.duplicate(true),"knowledge_access":knowledge_access.duplicate(true),"checkpoint_locked":checkpoint_locked,"dodge_ticks":dodge_ticks,"dodge_cooldown_ticks":dodge_cooldown_ticks,"loadout":loadout.duplicate(),"seq":_seq,"mode":"menu" if finale.phase=="caught" else ("model" if battle!=null and not battle.state.suspended else "world"),"battle":battle.state.duplicate(true) if battle != null else {}}
func restore(data: Dictionary) -> bool:
 if not SaveValidator.validate(data,content).is_empty(): return false
 if not data.has_all(["cycle","tick","room","position","profile","world","histories","track"]): return false
 if int(data.cycle) < 1 or int(data.cycle) > 3 or content.room(str(data.room)).is_empty(): return false
 if not data.position is Array or data.position.size() != 2: return false
 for key: String in ["profile","world","track"]:
  if not data[key] is Dictionary: return false
 if not data.histories is Array or not data.track.has_all(["samples","events"]): return false
 if not data.track.samples is Array or not data.track.events is Array: return false
 if not data.profile.has_all(["knowledge","choices","violation","hints","completed"]): return false
 if not data.profile.knowledge is Array or not data.profile.choices is Dictionary: return false
 for key: String in ["inventory","visited","echo_cursors","echo_sample_cursors","deviations","settled","loadout","events"]:
  if data.has(key) and not data[key] is Array: return false
 if data.has("battle") and not data.battle is Dictionary: return false
 if int(data.tick) < 0: return false
 var base: Dictionary = GameSession.new(content).snapshot()
 base.merge(data,true)
 if not base.world.has_all(world.keys()): return false
 if base.histories.size() > 3 or base.histories.size() != base.echo_cursors.size(): return false
 for h: Variant in base.histories:
  if not h is Dictionary or not h.get("track") is Dictionary: return false
  if not h.has_all(["cycle","track"]) or not h.track.has_all(["samples","events"]): return false
 if base.echo_sample_cursors.size() != base.histories.size(): return false
 for id: Variant in base.loadout:
  if not id is String or not content.cards.has(id): return false
 if not base.battle.is_empty() and not content.encounters.has(base.battle.get("id","")): return false
 cycle = int(base.cycle);tick = int(base.tick);room_id = str(base.room)
 player_position = Vector2(float(base.position[0]),float(base.position[1]));direction = str(base.direction)
 profile = base.profile.duplicate(true);world = base.world.duplicate(true);inventory = base.inventory.duplicate();visited = base.visited.duplicate()
 histories = base.histories.duplicate(true);track = base.track.duplicate(true);events = base.events.duplicate(true)
 echo_cursors = base.echo_cursors.duplicate();echo_sample_cursors = base.echo_sample_cursors.duplicate()
 deviations = base.deviations.duplicate(true);settled = base.settled.duplicate();loadout = base.loadout.duplicate();_seq = int(base.seq)
 evidence=base.evidence.duplicate(true);pending_experiment=base.pending_experiment.duplicate(true);holds=base.holds.duplicate(true);finale=base.finale.duplicate(true);knowledge_access=base.knowledge_access.duplicate(true);checkpoint_locked=base.checkpoint_locked;dodge_ticks=int(base.dodge_ticks);dodge_cooldown_ticks=int(base.dodge_cooldown_ticks)
 mode = base.mode;battle = null
 if not base.battle.is_empty():
  battle = ModelBattle.new(content.encounters[base.battle.id],evidence);battle.state = base.battle.duplicate(true);mode = base.mode
 changed.emit()
 return true
func set_checkpoint() -> void:
 if checkpoint_locked: return
 checkpoint = snapshot()
func rewind() -> bool:
 return restore(checkpoint) if not checkpoint.is_empty() else false
func objective() -> String:
 if profile.completed: return "序章已完成：实验记录、模型与三个自己的贡献都已封存。"
 if finale.phase=="caught": return "被监考者拦截：打开检查点，恢复追逐前的局部记录。"
 if finale.phase=="escaped": return "在观测塔记录终端提交最后的实验档案。"
 if finale.phase in ["warning","chase","ready"]: return "靠近走廊落体闸门释放，等待安全窗口；进入观测塔。"
 if cycle>=2 and not histories.is_empty():
  var last_end: int=-1
  for history: Dictionary in histories:
   for action: Dictionary in history.track.events:
    if action.kind=="hold_end": last_end=maxi(last_end,int(action.tick))
  var contribution_done: bool=track.events.any(func(e: Dictionary) -> bool: return e.kind=="hold_end" and e.target=="assist_b" and e.payload.get("valid",false) and e.payload.get("overlap_ticks",0)>=360) if cycle==2 else evidence.any(func(e: Dictionary) -> bool: return e.setup.medium=="vacuum")
  if last_end>=0 and tick>last_end and not contribution_done: return "历史协作窗口已结束：在因果面板选择重试本轮，历史时刻不会移动。"
 if cycle==1:
  if not "kit" in inventory: return "接通教室 A，去器材室取得实验包并接通 B。"
  if not "observation" in profile.knowledge: return "在实验室释放球与纸片；完成后读取真实测量。"
  if not can_cycle(): return "在实验室稳压工位 A 录制 12 秒操作（02:00 起）；可按等待快进。"
  return "去观测塔封存第一轮，真实操作将成为回声。"
 if cycle==2:
  if not world.mass: return "取实验包，在实验室完成同形不同质量对照，引用记录解释反例。"
  if not can_cycle(): return "站在安全锁 B，在回声 1 的 A 操作开始时录制；需重叠至少 6 秒。"
  return "去观测塔封存第二轮；两个操作记录已经相互配合。"
 if not world.drag: return "完成纸片形状对照；让两个回声维持 A/B，自己在 C 做真空实验并论证。"
 return "去封锁档案室，选择预测或实测校准；亲手通过落体闸门。"
