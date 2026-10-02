class_name SaveValidator
extends RefCounted

static func number(value: Variant, minimum: float = -1000000.0, maximum: float = 1000000000.0) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func integer(value: Variant, minimum: float = 0, maximum: float = 1000000000) -> bool:
 return number(value,minimum,maximum) and float(value)==floor(float(value))

static func track_error(track: Variant, content: GameContent) -> String:
 if not track is Dictionary or not track.get("samples") is Array or not track.get("events") is Array: return "轨迹结构无效"
 var previous: int = -1
 for sample: Variant in track.samples:
  if not sample is Dictionary: return "采样必须是对象"
  if not integer(sample.get("tick"),0) or int(sample.tick) < previous: return "采样时间无效"
  if content.room(str(sample.get("room",""))).is_empty(): return "采样房间无效"
  if not number(sample.get("x"),0,640) or not number(sample.get("y"),0,360): return "采样坐标无效"
  if not sample.get("direction") in ["up","down","left","right"] or not sample.get("moving") is bool: return "采样姿态无效"
  previous = int(sample.tick)
 previous = -1
 for event: Variant in track.events:
  var error: String = event_error(event,content)
  if not error.is_empty(): return error
  if int(event.tick) < previous: return "事件时间倒序"
  previous = int(event.tick)
 return ""

static func event_error(event: Variant, content: GameContent) -> String:
 if not event is Dictionary or not event.has_all(["seq","cycle","tick","actor","room","kind","target","payload"]): return "事件来源不完整"
 if not integer(event.seq,1) or not integer(event.cycle,1,3) or not integer(event.tick,0): return "事件序号无效"
 if not event.actor is String or not event.kind is String or not event.target is String or not event.payload is Dictionary: return "事件类型无效"
 if event.kind=="switch" and (not event.payload.get("value") is bool or (event.payload.has("expected") and not event.payload.expected is bool)): return "机关事件参数无效"
 if event.kind=="experiment" and ExperimentModel.setup(event.payload).is_empty(): return "实验事件参数无效"
 if event.kind not in ["switch","push","pickup","talk","visit","experiment","read_evidence","hold_begin","hold_end","resolve","choose_future","predict_gate","calibrate_gate","gate_release","dodge","ending","play_card"]: return "未知事件类型"
 if event.kind=="hold_end":
  for key: String in ["duration","overlap_ticks"]:
   if event.payload.has(key) and not integer(event.payload[key],0): return "维持事件时间无效"
  if event.payload.has("valid") and not event.payload.valid is bool: return "维持事件结果无效"
 if event.kind=="choose_future" and not event.payload.get("accept") is bool: return "路线选择无效"
 if event.kind=="play_card" and not event.payload.get("evidence_ids") is Array: return "出牌引用无效"
 if content.room(str(event.room)).is_empty(): return "事件房间无效"
 return ""

static func validate(data: Variant, content: GameContent) -> String:
 if not data is Dictionary: return "状态必须是对象"
 var required: Array = ["cycle","tick","room","position","direction","profile","world","inventory","visited","histories","track","events","echo_cursors","echo_sample_cursors","deviations","settled","loadout","seq","mode","battle","evidence","pending_experiment","holds","finale","knowledge_access","checkpoint_locked","dodge_ticks","dodge_cooldown_ticks"]
 if not data.has_all(required): return "状态字段不完整"
 if not integer(data.cycle,1,3) or not integer(data.tick,0) or not integer(data.seq,0): return "世界时钟无效"
 if content.room(str(data.room)).is_empty() or not data.direction in ["up","down","left","right"]: return "位置或朝向无效"
 if not data.position is Array or data.position.size()!=2 or not number(data.position[0],0,640) or not number(data.position[1],0,360): return "坐标无效"
 for key: String in ["profile","world","battle","pending_experiment","holds","finale","knowledge_access"]:
  if not data[key] is Dictionary: return key+" 类型无效"
 for key: String in ["inventory","visited","histories","events","echo_cursors","echo_sample_cursors","deviations","settled","loadout","evidence"]:
  if not data[key] is Array: return key+" 类型无效"
 var p: Dictionary = data.profile
 if not p.has_all(["knowledge","choices","violation","hints","completed"]): return "玩家资料不完整"
 if not p.knowledge is Array or not p.choices is Dictionary or not p.completed is bool or not integer(p.violation,0,1) or not integer(p.hints,0): return "玩家资料类型无效"
 for id: Variant in p.knowledge:
  if not id is String or not content.knowledge.has(id): return "未知知识"
 for key: String in ["switch_a","switch_b","lab_gate","pump","experiment","mass","drag","coil_disabled","rig_power"]:
  if not data.world.get(key) is bool: return "机关状态无效"
 if not integer(data.world.get("crate"),0,1): return "器材箱状态无效"
 for id: Variant in data.loadout:
  if not id is String or not content.cards.has(id): return "未知卡牌"
 for id: Variant in data.visited:
  if not id is String or content.room(id).is_empty(): return "未知已访问房间"
 for id: Variant in data.inventory:
  if not id is String or content.object(id).get("kind") != "pickup": return "未知物品"
 for id: Variant in data.settled:
  if not id in ["mass","drag"]: return "未知结算"
 var error: String = track_error(data.track,content)
 if not error.is_empty(): return error
 if data.histories.size()>2 or data.histories.size()!=data.echo_cursors.size() or data.histories.size()!=data.echo_sample_cursors.size(): return "历史游标数量无效"
 var last_cycle: int = 0
 for index: int in range(data.histories.size()):
  var h: Variant = data.histories[index]
  if not h is Dictionary or not integer(h.get("cycle"),1,2) or int(h.cycle)<=last_cycle: return "历史循环无效"
  last_cycle = int(h.cycle)
  error = track_error(h.get("track"),content)
  if not error.is_empty(): return error
  if not integer(data.echo_cursors[index],0,h.track.events.size()): return "事件游标越界"
  if not integer(data.echo_sample_cursors[index],0,maxi(0,h.track.samples.size()-1)): return "采样游标越界"
 for event: Variant in data.events:
  error = event_error(event,content)
  if not error.is_empty(): return error
 for d: Variant in data.deviations:
  if not d is Dictionary or not number(d.get("tick"),0) or not d.get("message") is String: return "偏差记录无效"
 if not data.mode in ["world","model","menu"]: return "模式无效"
 if data.mode=="model" and data.battle.is_empty(): return "论证模式缺少论证"
 if data.mode=="menu" and data.finale.get("phase")!="caught": return "暂停模式缺少失败上下文"
 if not data.battle.is_empty():
  if not data.battle.get("suspended") is bool: return "论证挂起状态无效"
  if (data.mode=="model") == data.battle.suspended: return "论证与交互模式不一致"
  var b: Dictionary = data.battle
  if not content.encounters.has(b.get("id","")): return "论证 ID 无效"
  if not b.has_all(["round","actions","model","observed","controlled","repeated","shape","vacuum","evidence","resolved","won","failed","last"]): return "论证字段不完整"
  if not integer(b.round,1,100) or not integer(b.actions,0,2) or not b.model in ["none","mass","gravity","drag"]: return "论证状态无效"
  for key: String in ["observed","controlled","repeated","shape","vacuum","won","failed"]:
   if not b[key] is bool: return "论证标记无效"
  if not b.evidence is Array or not b.resolved is Array or not b.last is String: return "论证证据无效"
 var source_ids: Array=[]
 for record: Variant in data.evidence:
  error=evidence_error(record,data,content)
  if not error.is_empty(): return error
  if record.source_event_id in source_ids: return "重复证据来源"
  source_ids.append(record.source_event_id)
 if not data.pending_experiment.is_empty():
  error=evidence_error(data.pending_experiment,data,content)
  if not error.is_empty(): return error
  if not number(data.pending_experiment.get("finish_tick"),data.tick) or not data.pending_experiment.get("joint") is bool: return "测量进度无效"
 if not data.checkpoint_locked is bool or not number(data.dodge_ticks,0,10) or not number(data.dodge_cooldown_ticks,0,48): return "交互时间无效"
 for station: Variant in data.holds:
  if not station in ["assist_a","assist_b"]: return "未知持有工位"
  var held: Variant=data.holds[station]
  if not held is Dictionary or not held.has_all(["actor","begin","end","overlap","context"]): return "持有状态不完整"
  if not held.actor in ["player","echo_1","echo_2"] or not number(held.begin,0,data.tick) or not number(held.end,data.tick) or not number(held.overlap,0,720) or not held.context is Dictionary: return "持有状态无效"
 var f: Dictionary=data.finale
 if not f.has_all(["phase","choice","used","prediction","release_tick","open_tick","close_tick","warning_end","examiner_room","examiner_position","arrival_tick"]): return "结尾状态不完整"
 if not f.phase in ["none","chosen","ready","warning","chase","caught","escaped","complete"] or not f.choice is bool or not f.used is bool or not f.prediction is Dictionary: return "结尾状态无效"
 if (f.phase=="complete") != p.completed: return "章节完成状态不一致"
 if (f.phase=="caught") != (data.mode=="menu"): return "拦截状态与暂停不一致"
 if not f.prediction.is_empty():
  if not number(f.prediction.get("time_s"),0.01,60) or not f.prediction.get("origin") in ["prediction","measurement"]: return "闸门预测无效"
  if f.prediction.origin=="prediction" and f.prediction.get("model")!="drag": return "预测模型无效"
  if f.prediction.origin=="measurement" and not data.evidence.any(func(r: Dictionary) -> bool: return r.id==f.prediction.get("evidence_id") and r.observed_by_player): return "校准缺少实测来源"
 for key: String in ["release_tick","open_tick","close_tick","warning_end","arrival_tick"]:
  if not number(f[key],-1): return "结尾时钟无效"
 if content.room(str(f.examiner_room)).is_empty() or not f.examiner_position is Array or f.examiner_position.size()!=2 or not number(f.examiner_position[0]) or not number(f.examiner_position[1]): return "追踪位置无效"
 for id: Variant in data.knowledge_access:
  var access: Variant=data.knowledge_access[id]
  if not content.knowledge.has(id) or not access is Dictionary or not access.has_all(["discovered","understood","authorized"]): return "知识状态无效"
  for key: String in ["discovered","understood","authorized"]:
   if not access[key] is bool: return "知识标记无效"
 if not data.battle.is_empty():
  if not data.battle.get("cited_ids") is Array: return "论证引用无效"
  for id: Variant in data.battle.cited_ids:
   if not data.evidence.any(func(record: Dictionary) -> bool: return record.id==id and record.observed_by_player): return "论证引用了不存在或未读记录"
 return ""

static func evidence_error(record: Variant,data: Dictionary,_content: GameContent) -> String:
 if not record is Dictionary or not record.has_all(["id","source_event_id","source_cycle","cycle","tick","room_id","experiment_id","setup","observations","origin_actor","observed_by_player","simulator_version"]): return "证据字段不完整"
 if not record.id is String or not record.source_event_id is String or not integer(record.source_cycle,1,3) or not integer(record.cycle,1,3) or not integer(record.tick,0) or record.room_id!="lab" or not record.observed_by_player is bool or record.simulator_version!=1: return "证据来源无效"
 if not record.origin_actor is String or not record.origin_actor in ["player","echo_1","echo_2"]: return "证据操作者无效"
 if record.cycle>data.cycle or (record.cycle==data.cycle and record.tick>data.tick): return "证据来自未来"
 if not record.setup is Dictionary or not record.observations is Dictionary: return "证据结构无效"
 var setup: Dictionary=ExperimentModel.setup(record.setup)
 if setup.is_empty() or setup!=record.setup or record.experiment_id!=setup.experiment: return "实验条件不是已执行的参数"
 var result: Dictionary=ExperimentModel.measure(setup)
 if not record.observations.get("arrival_times_s") is Array or record.observations.arrival_times_s.size()!=2: return "测量结果结构无效"
 if record.observations.get("comparison")!=result.comparison or not number(record.observations.get("tolerance_s"),0.01,0.01): return "测量判据无效"
 for i: int in range(2):
  if not number(record.observations.arrival_times_s[i],0,60) or absf(float(record.observations.arrival_times_s[i])-float(result.arrival_times_s[i]))>0.000000001: return "测量结果与科学模型不符"
 var source: Dictionary={}
 var tracks: Array=[data.track]
 for history: Dictionary in data.histories: tracks.append(history.track)
 for candidate: Dictionary in tracks:
  for event: Dictionary in candidate.events:
   if "c%d:e%d" % [event.cycle,event.seq]==record.source_event_id: source=event
 if not source.is_empty() and (record.source_cycle!=source.cycle or record.tick<source.tick): return "证据来源时间不一致"
 if source.is_empty() or source.kind!="experiment" or ExperimentModel.setup(source.payload)!=setup: return "证据没有真实释放事件"
 return ""
