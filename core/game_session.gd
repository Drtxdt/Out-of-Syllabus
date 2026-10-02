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
func _init(data: GameContent = null) -> void:
 content = data if data != null else GameContent.new()
 reset_world()
func reset_world() -> void:
 world = {"switch_a": false, "switch_b": false, "crate": 0, "lab_gate": false, "pump": false, "experiment": false, "mass": false, "drag": false, "coil_disabled": false}
 inventory = []
 visited = ["classroom"]
func sample(moving: bool = false) -> void:
 if tick % SAMPLE_INTERVAL == 0 or track.samples.is_empty():
  track.samples.append({"tick": tick, "room": room_id, "x": player_position.x, "y": player_position.y, "direction": direction, "moving": moving})
func advance(steps: int = 1, moving: bool = false) -> void:
 if mode != "world": return
 for _i: int in range(steps):
  tick += 1
  for h: int in range(histories.size()):
   var actions: Array = histories[h].track.events
   var cursor: int = int(echo_cursors[h])
   while cursor < actions.size() and int(actions[cursor].tick) <= tick:
    var ev: Dictionary = actions[cursor]
    if ev.get("room", "") == room_id and ev.kind in ["talk", "pickup"]:
     notice.emit("历史回忆 · " + str(ev.payload.get("text", "过去的你拿起了" + str(ev.payload.get("title", ev.target)))))
    var result: Dictionary = command(ev.kind, ev.target, ev.payload, "echo_%d" % int(histories[h].cycle), {"source_cycle":histories[h].cycle,"source_event_id":ev.seq,"source_room":ev.room})
    if not result.ok:
     var message: String = "历史 %d · %s：%s" % [histories[h].cycle,ev.target,result.message]
     deviations.append({"tick":tick,"message":message})
     notice.emit("因果偏差 · " + result.message)
    cursor += 1
   echo_cursors[h] = cursor
  sample(moving)
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
func command(kind: String, target: String, payload: Dictionary = {}, actor: String = "player", context: Dictionary = {}) -> Dictionary:
 var echo: bool = actor != "player"
 var ok: bool = true
 var message: String = ""
 if echo and kind in ["pickup", "talk", "visit", "knowledge", "resolve", "ending", "compress"]:
  return {"ok":true,"message":"历史重现，不重复结算。"}
 match kind:
  "switch":
   if not target in ["switch_a","switch_b","pump","coil_disabled"]: return {"ok":false,"message":"机关已不存在。"}
   if payload.has("expected") and world[target] != payload.expected:
    ok = false; message = "机关状态与历史不同。"
   else:
    world[target] = payload.get("value",true)
    world.lab_gate = world.switch_a and world.switch_b
    message = "机关已更新。"
  "push":
   if int(world.crate) != int(payload.get("expected",0)):
    ok = false; message = "箱子已经移动，历史推箱未生效。"
   else:
    world.crate = int(world.crate)+1; message = "箱子移开，留下了新的路线。"
  "experiment":
   if bool(payload.get("vacuum",false)) and not world.pump:
    ok = false; message = "真空泵尚未启动。"
   else:
    world.experiment = true
    message = "实验记录已保存。"
  "pickup":
   if not target in inventory: inventory.append(target)
   message = "取得「%s」。" % payload.get("title",target)
  "talk": message = str(payload.get("text",""))
  "visit":
   if content.room(target).is_empty(): return {"ok":false,"message":"未知区域。"}
   room_id = target
   player_position = Vector2(float(payload.get("x",320)),float(payload.get("y",224)))
   if not target in visited: visited.append(target)
  "knowledge":
   if not content.knowledge.has(target): return {"ok":false,"message":"未知知识。"}
   if not target in profile.knowledge: profile.knowledge.append(target)
  "resolve":
   if target in settled: return {"ok":true,"message":"结果已结算。"}
   if not target in ["mass","drag"]: return {"ok":false,"message":"未知遭遇。"}
   settled.append(target);world[target] = true
   var knowledge_id: String = "gravity" if target == "mass" else "drag"
   if not knowledge_id in profile.knowledge: profile.knowledge.append(knowledge_id)
   message = "模型已建立，新知识改变了你眼中的世界。"
  "ending":
   if profile.completed: return {"ok":true,"message":"本章已完成。"}
   if not world.drag: return {"ok":false,"message":"尚未完成阻力论证。"}
   profile.choices["future_card"] = bool(payload.get("accept",false))
   if payload.get("accept",false): profile.violation += 1
   profile.completed = true
   message = "未经授权的知识已被检测。" if payload.get("accept",false) else "你选择留下可复核的证据。"
  _:
   return {"ok":false,"message":"不支持的操作。"}
 if ok:
  _seq += 1
  var event: Dictionary = {"seq":_seq,"cycle":cycle,"tick":tick,"actor":actor,"room":context.get("source_room",room_id),"kind":kind,"target":target,"payload":payload.duplicate(true)}
  event.merge(context)
  events.append(event)
  if not echo: track.events.append(event.duplicate(true))
  changed.emit()
 return {"ok":ok,"message":message}
func can_cycle() -> bool:
 return (cycle == 1 and world.experiment and "kit" in inventory) or (cycle == 2 and world.mass)
func next_cycle() -> bool:
 if not can_cycle() or cycle >= 3: return false
 sample()
 histories.append({"cycle":cycle,"track":track.duplicate(true)})
 cycle += 1;tick = 0;room_id = "classroom";player_position = Vector2(320,224)
 track = {"samples":[],"events":[]};events = [];settled = [];deviations = []
 echo_cursors = [];echo_sample_cursors = []
 for _h: Dictionary in histories:
  echo_cursors.append(0);echo_sample_cursors.append(0)
 reset_world();mode = "world";battle = null
 changed.emit()
 return true
func start_battle(id: String) -> bool:
 if mode != "world" or not content.encounters.has(id): return false
 if id in settled: return false
 battle = ModelBattle.new(content.encounters[id]);mode = "model"
 return true
func finish_battle() -> bool:
 if battle == null or not battle.state.won: return false
 command("resolve",battle.definition.id)
 battle = null;mode = "world"
 return true
func compress_lab() -> Dictionary:
 if not "gravity" in profile.knowledge: return {"ok":false,"message":"需要先理解一次实验流程。"}
 if world.pump or int(world.crate) != 0: return {"ok":false,"message":"装置状态发生变化，请重新观察。"}
 var before: Dictionary = world.duplicate(true)
 # Advance through every event: never jump the simulation clock.
 for _i: int in range(180):
  advance()
  if world.pump != before.pump or world.crate != before.crate:
   return {"ok":false,"message":"压缩中发现历史干预，已停在变化处。"}
 return command("experiment","lab_drop",{"vacuum":false,"shape":"flat","compressed":true})
func snapshot() -> Dictionary:
 return {"cycle":cycle,"tick":tick,"room":room_id,"position":[player_position.x,player_position.y],"direction":direction,
  "profile":profile.duplicate(true),"world":world.duplicate(true),"inventory":inventory.duplicate(),"visited":visited.duplicate(),
  "histories":histories.duplicate(true),"track":track.duplicate(true),"events":events.duplicate(true),"echo_cursors":echo_cursors.duplicate(),
  "echo_sample_cursors":echo_sample_cursors.duplicate(),"deviations":deviations.duplicate(true),"settled":settled.duplicate(),
  "loadout":loadout.duplicate(),"seq":_seq,"mode":"model" if battle != null else "world","battle":battle.state.duplicate(true) if battle != null else {}}
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
 mode = "world";battle = null
 if not base.battle.is_empty():
  battle = ModelBattle.new(content.encounters[base.battle.id]);battle.state = base.battle.duplicate(true);mode = "model"
 changed.emit()
 return true
func set_checkpoint() -> void:
 checkpoint = snapshot()
func rewind() -> bool:
 return restore(checkpoint) if not checkpoint.is_empty() else false
func objective() -> String:
 if profile.completed: return "序章已完成 · 可以检查历史、继续探索，或开始新的记录。"
 if cycle == 1:
  if not "kit" in inventory: return "去器材室取得实验包，沿途观察这座学校。"
  if not world.experiment: return "在实验室比较金属球与纸片，记录暂定解释。"
  return "去观测塔结束第一轮记录。你的行动会被保留下来。"
 if cycle == 2:
  if not world.mass: return "重访实验室，解释不同质量物体近似同时落地的反例。"
  return "去观测塔开启下一轮。留意历史中的自己。"
 if not world.pump: return "启动器材室真空泵，准备新的对照实验。"
 if not world.drag: return "在实验室解释空气阻力与真空对照，完成模型修正。"
 return "进入封锁档案室，决定是否使用未来知识。"
