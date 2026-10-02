class_name SaveValidator
extends RefCounted

static func number(value: Variant, minimum: float = -1000000.0, maximum: float = 1000000000.0) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func track_error(track: Variant, content: GameContent) -> String:
 if not track is Dictionary or not track.get("samples") is Array or not track.get("events") is Array: return "轨迹结构无效"
 var previous: int = -1
 for sample: Variant in track.samples:
  if not sample is Dictionary: return "采样必须是对象"
  if not number(sample.get("tick"),0) or int(sample.tick) < previous: return "采样时间无效"
  if content.room(str(sample.get("room",""))).is_empty(): return "采样房间无效"
  if not number(sample.get("x")) or not number(sample.get("y")): return "采样坐标无效"
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
 if not number(event.seq,1) or not number(event.cycle,1,3) or not number(event.tick,0): return "事件序号无效"
 if not event.actor is String or not event.kind is String or not event.target is String or not event.payload is Dictionary: return "事件类型无效"
 if content.room(str(event.room)).is_empty(): return "事件房间无效"
 return ""

static func validate(data: Variant, content: GameContent) -> String:
 if not data is Dictionary: return "状态必须是对象"
 var required: Array = ["cycle","tick","room","position","direction","profile","world","inventory","visited","histories","track","events","echo_cursors","echo_sample_cursors","deviations","settled","loadout","seq","mode","battle"]
 if not data.has_all(required): return "状态字段不完整"
 if not number(data.cycle,1,3) or not number(data.tick,0) or not number(data.seq,0): return "世界时钟无效"
 if content.room(str(data.room)).is_empty() or not data.direction in ["up","down","left","right"]: return "位置或朝向无效"
 if not data.position is Array or data.position.size()!=2 or not number(data.position[0]) or not number(data.position[1]): return "坐标无效"
 for key: String in ["profile","world","battle"]:
  if not data[key] is Dictionary: return key+" 类型无效"
 for key: String in ["inventory","visited","histories","events","echo_cursors","echo_sample_cursors","deviations","settled","loadout"]:
  if not data[key] is Array: return key+" 类型无效"
 var p: Dictionary = data.profile
 if not p.has_all(["knowledge","choices","violation","hints","completed"]): return "玩家资料不完整"
 if not p.knowledge is Array or not p.choices is Dictionary or not p.completed is bool or not number(p.violation,0) or not number(p.hints,0): return "玩家资料类型无效"
 for id: Variant in p.knowledge:
  if not id is String or not content.knowledge.has(id): return "未知知识"
 for key: String in ["switch_a","switch_b","lab_gate","pump","experiment","mass","drag","coil_disabled"]:
  if not data.world.get(key) is bool: return "机关状态无效"
 if not number(data.world.get("crate"),0,1): return "器材箱状态无效"
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
  if not h is Dictionary or not number(h.get("cycle"),1,2) or int(h.cycle)<=last_cycle: return "历史循环无效"
  last_cycle = int(h.cycle)
  error = track_error(h.get("track"),content)
  if not error.is_empty(): return error
  if not number(data.echo_cursors[index],0,h.track.events.size()): return "事件游标越界"
  if not number(data.echo_sample_cursors[index],0,maxi(0,h.track.samples.size()-1)): return "采样游标越界"
 for event: Variant in data.events:
  error = event_error(event,content)
  if not error.is_empty(): return error
 for d: Variant in data.deviations:
  if not d is Dictionary or not number(d.get("tick"),0) or not d.get("message") is String: return "偏差记录无效"
 if not data.mode in ["world","model"]: return "模式无效"
 if not data.battle.is_empty():
  var b: Dictionary = data.battle
  if not content.encounters.has(b.get("id","")): return "论证 ID 无效"
  if not b.has_all(["round","actions","model","observed","controlled","repeated","shape","vacuum","evidence","resolved","won","failed","last"]): return "论证字段不完整"
  if not number(b.round,1,100) or not number(b.actions,0,2) or not b.model in ["none","mass","gravity","drag"]: return "论证状态无效"
  for key: String in ["observed","controlled","repeated","shape","vacuum","won","failed"]:
   if not b[key] is bool: return "论证标记无效"
  if not b.evidence is Array or not b.resolved is Array or not b.last is String: return "论证证据无效"
 return ""
