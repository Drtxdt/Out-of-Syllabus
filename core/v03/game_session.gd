extends RefCounted
signal changed
signal notice(text: String)
const Physics = preload("res://core/v03/physics.gd")
const Combat = preload("res://core/v03/combat_session.gd")
const Validator = preload("res://core/v03/save_validator.gd")
var state: Dictionary
var checkpoint: Dictionary = {}
var _content: Resource

func _init() -> void:
 _content=load("res://content/v03/chapter.tres")
 state={"cycle":1,"tick":0,"room":"classroom","position":[320.0,224.0],"direction":"down","mode":"world","revision":0,"seq":0,"stage":"paper","flags":{"paper_door":false,"patrol":false,"rig_demo":false,"hammer":false,"seal_kit":false,"joint":false,"bellows":false,"power":true,"safe_checked":false},"owned":[],"knowledge":{},"events":[],"samples":[],"histories":[],"segments":[],"attempt":{},"battle":{},"opening":{"shape":"crumpled","phase":"idle","trace":{},"release_tick":-1,"elapsed":0.0,"door_until":-1,"source_id":""},"observations":[],"finale":{"choice":"none","phase":"none","used":false,"violations":0,"prediction":{},"release_tick":-1,"open_tick":-1,"close_tick":-1,"examiner_room":"archive","examiner_position":[320.0,288.0],"warning_end":0,"dodge_until":0,"dodge_ready":0,"chase_started":0},"completed":false,"handled":[]}
 _sample();checkpoint=snapshot()
 state["motion_tick"]=-1;state["motion_distance"]=0.0;state["rig_demo"]={};checkpoint=snapshot()

func snapshot() -> Dictionary:
 return state.duplicate(true)

func restore(data: Dictionary) -> bool:
 if not Validator.validate(data).is_empty(): return false
 state=data.duplicate(true);changed.emit();return true

func objects() -> Array:
 for room: Dictionary in _content.rooms:
  if room.id==state.room:
   var result: Array=[]
   for obj: Dictionary in room.objects:
    if obj.kind=="enemy" and state.flags.get(obj.id,false): continue
    result.append(obj.duplicate(true))
   return result
 return []

func room_title() -> String:
 for room: Dictionary in _content.rooms:
  if room.id==state.room: return room.title
 return ""

func _object(id: String) -> Dictionary:
 for item: Dictionary in objects():
  if item.id==id: return item
 return {}

func _near(id: String, position: Array=[]) -> bool:
 var obj: Dictionary=_object(id)
 if obj.is_empty(): return false
 var point: Array=state.position if position.is_empty() else position
 return Vector2(point[0],point[1]).distance_to(Vector2(obj.x,obj.y)) <= (36.0 if obj.kind=="hold" else 48.0)

func nearby() -> Dictionary:
 var found: Dictionary={}
 var distance: float=INF
 for obj: Dictionary in objects():
  var d: float=Vector2(state.position[0],state.position[1]).distance_to(Vector2(obj.x,obj.y))
  if d<distance and _near(obj.id): found=obj;distance=d
 return found

func command(kind: String, target: String="", payload: Dictionary={}) -> Dictionary:
 if payload.has("revision") and (not payload.revision is int or int(payload.revision)!=int(state.revision)): return _no("局面已变化，请重新预览。")
 if payload.has("request_id") and not payload.request_id is String: return _no("请求编号无效。")
 var request: String=str(payload.get("request_id",""))
 if not request.is_empty() and request in state.handled: return _ok("这次操作已经完成。")
 if kind=="move": return _execute(kind,target,payload)
 var before: Dictionary=snapshot()
 var old_checkpoint: Dictionary=checkpoint.duplicate(true)
 var result: Dictionary=_execute(kind,target,payload)
 if not result.ok:
  state=before;checkpoint=old_checkpoint;return result
 if kind not in ["move","retry","fast_forward"]:
  _record(kind,target,payload,before)
  if not request.is_empty():
   state.handled.append(request)
   if state.handled.size()>256: state.handled.pop_front()
  if kind in ["begin_battle","bell"]: checkpoint=before
  if kind=="interact" and before.mode=="world" and state.mode=="combat": checkpoint=before
  if kind=="gate_release" and state.finale.used: checkpoint=snapshot()
  if kind=="seal": checkpoint=snapshot()
 changed.emit()
 return result

func _execute(kind: String, target: String, p: Dictionary) -> Dictionary:
 if kind=="retry":
  if checkpoint.is_empty(): return _no("没有可重试的检查点。")
  return _ok("已恢复本次尝试，封存历史不变。") if restore(checkpoint) else _no("检查点无效。")
 if state.completed: return _no("本章已经完成。")
 if state.mode=="caught": return _no("被拦截了，请重试追逐。")
 if kind in ["combat_action","end_turn","retreat"]:
  if state.mode!="combat": return _no("当前没有战斗。")
  if kind=="retreat":
   state.battle.outcome="retreated";state.mode="world";return _ok("离开阴影界，装置恢复到战前检查点可重试。")
  if kind=="combat_action" and not p.get("target","") is String: return _no("目标无效。")
  var response: Dictionary=Combat.apply(state.battle,"end_turn" if kind=="end_turn" else target,str(p.get("target","")),state.owned)
  if not response.ok: return response
  state.battle=response.state
  if state.battle.outcome=="won":
   var id: String=state.battle.id
   state.flags[id]=true;state.mode="world"
   if id=="hammer": _unlock("fix");state.stage="record_a"
   if id=="bellows": _learn("drag",true);state.stage="finale"
   if id=="patrol": state.stage="rig"
  return response
 if state.mode!="world": return _no("请先结束当前战斗。")
 match kind:
  "move":
   if target!="player" or not Physics.numeric(p.get("x")) or not Physics.numeric(p.get("y")): return _no("位置无效。")
   var point: Vector2=Vector2(p.x,p.y)
   var limit: float=4.0 if int(state.tick)<int(state.finale.dodge_until) else 1.75
   var used: float=float(state.motion_distance) if int(state.motion_tick)==int(state.tick) else 0.0
   var distance: float=point.distance_to(Vector2(state.position[0],state.position[1]))
   if distance+used>limit+0.01 or point.x<40 or point.x>600 or point.y<56 or point.y>306: return _no("移动步长或边界无效。")
   var facing: String=str(p.get("direction",state.direction))
   if facing not in ["up","down","left","right"]: return _no("朝向无效。")
   state.position=[point.x,point.y];state.direction=facing;state.motion_tick=state.tick;state.motion_distance=used+distance;_release_departed();return _ok("")
  "interact":
   if not _near(target): return _no("请靠近再操作。")
   var obj: Dictionary=_object(target)
   match obj.kind:
    "exit": return _visit(obj.target)
    "enemy": return _begin_battle(target)
    "rig": return _execute("learn_rig",target,{})
    "bell": return _execute("bell",target,{})
    "hold": return _execute("hold",target,{})
    "switch": return _execute("power",target,{})
    "barrier": return _execute("fix",target,{})
    "experiment": return _execute("joint_release",target,{})
    "cycle": return _execute("submit" if state.cycle==3 else "seal",target,{})
    "gate": return _execute("gate_release",target,{})
    "marker":
     if state.finale.choice!="refuse" or state.finale.prediction.is_empty(): return _no("先到档案室选择校准路线。")
     state.flags.safe_checked=true;return _ok("已用实测记录校准远端刻度，返回档案室释放闸门。")
    _: return _ok(str(obj.get("text",obj.title)))
  "paper_shape":
   if target!="paper" or not _near(target) or state.opening.phase=="falling": return _no("请在释放前靠近纸片。")
   if p.get("shape") not in ["flat","crumpled"]: return _no("请选择展开或揉团。")
   state.opening.shape=p.shape;state.opening.phase="idle";state.opening.trace={};state.opening.elapsed=0.0;_unlock("unfold" if p.shape=="flat" else "crumple")
   return _ok("同一张纸，形状改变，质量不变。")
  "release":
   if target!="paper" or not _near(target) or state.opening.phase=="falling": return _no("请在纸片夹具附近准备释放。")
   state.opening.trace=Physics.trace(Physics.setup("paper",state.opening.shape))
   state.opening.phase="falling";state.opening.release_tick=state.tick;state.opening.elapsed=0.0
   state.opening.source_id="c%d:e%d" % [state.cycle,int(state.seq)+1]
   return _ok("纸片释放，观察落地与机械延时。")
  "observe":
   if target=="lab_drop":
    if not _near(target) or state.attempt.is_empty() or state.attempt.phase!="success" or state.attempt.joint_trace.is_empty(): return _no("在 C 查看完成的联合测量后才能记录。")
    _observe(state.attempt.joint_trace,state.attempt.source_event_id,"两条历史共同维持真空；形状带来的空气时间差消失。")
    return _ok("联合测量已记入笔记。")
   if target!="paper" or not _near(target) or state.opening.phase!="landed": return _no("完成测量并看到结果后才可记录。")
   _observe(state.opening.trace,state.opening.source_id,"同一张纸，展开后在空气中落得更慢。")
   _unlock("unfold");_unlock("crumple");return _ok("观察已记入笔记。")
  "learn_rig":
   if target!="rig_demo" or not _near(target) or not state.flags.patrol: return _no("先通过走廊，再靠近配重示范台。")
   state.flags.rig_demo=true;_unlock("raise");_unlock("release_pair");_learn("gravity",true)
   state.rig_demo={"traces":[Physics.trace(Physics.setup("left")),Physics.trace(Physics.setup("right"))],"source_id":"c%d:e%d" % [state.cycle,int(state.seq)+1]}
   return _ok("亲手调高并齐放同形配重；两个质量不同的球近乎同时到达。")
  "begin_battle": return _begin_battle(target)
  "fix":
   if target!="paper_barrier" or not _near(target) or state.cycle!=2 or not "fix" in state.owned: return _no("第二轮可用固定动作稳住器材室纸幕。")
   state.flags.seal_kit=true;return _ok("固定纸幕后取出密封组件，安全锁 B 可以工作。")
  "power":
   if target!="rig_power" or not _near(target): return _no("请靠近实验供电。")
   state.flags.power=not state.flags.power
   if not state.flags.power and not state.attempt.is_empty(): _fail_attempt("供电中断，历史操作条件不再成立。")
   return _ok("实验供电已接通。" if state.flags.power else "实验供电已断开。")
  "bell":
   if target!="sync_bell" or not _near(target) or not state.flags.hammer: return _no("先解除双锤看守，再来到同步铃。")
   if not state.flags.power: return _no("先恢复实验供电。")
   if state.cycle==2 and not state.flags.seal_kit: return _no("先去器材室固定纸幕，取出密封组件。")
   if not state.attempt.is_empty() and state.attempt.phase in ["countdown","recording"]: return _no("装置已经在本次同步中。")
   state.attempt={"phase":"countdown","tick":-180,"holds":{},"powered":true,"message":"3、2、1 后开始；走到自己的工位。","start_world_tick":state.tick,"actions":[],"samples":[],"executed":[],"overlap":0,"joint_trace":{},"joint_start":-1,"source_event_id":"","origin_cycle":state.cycle}
   return _ok("同步倒数开始。第一轮操作 A，第二轮 B，第三轮 C。")
  "hold":
   if not _near(target) or not target in ["assist_a","assist_b"]: return _no("请站在工位操作区内。")
   if state.attempt.is_empty() or state.attempt.phase not in ["countdown","recording"]: return _no("先敲同步铃。")
   var expected: String="assist_a" if state.cycle==1 else "assist_b"
   if state.cycle==3 or target!=expected: return _no("这个工位由对应历史角色操作，你需要自己的工位。")
   if state.attempt.holds.has(target):
    state.attempt.holds.erase(target);_attempt_action("hold_end",target)
    if state.attempt.tick<360: _fail_attempt("提前离开工位，装置尚未完成。")
   else:
    for h: Dictionary in state.attempt.holds.values():
     if h.actor=="player": return _no("每个角色只能维持一个工位。")
    state.attempt.holds[target]={"actor":"player","begin":state.attempt.tick};_attempt_action("hold_begin",target)
   return _ok("留在操作区维持；再次交互或离开会结束。")
  "joint_release":
   if target!="lab_drop" or not _near(target) or state.cycle!=3 or state.attempt.is_empty() or state.attempt.phase!="recording": return _no("第三轮敲铃后，到 C 工位释放。")
   if not _joint_ready() or not state.attempt.joint_trace.is_empty(): return _no("需要两条真实回声持续维持 A/B，且释放架空闲。")
   state.attempt.joint_trace=Physics.trace(Physics.setup("paper","flat",2.0,0.0,"vacuum"));state.attempt.joint_start=state.attempt.tick
   state.attempt.source_event_id="c%d:e%d" % [state.cycle,int(state.seq)+1]
   return _ok("抽气并释放，A/B/C 必须共同维持至测量结束。")
  "seal":
   if target!="cycle_console" or not _near(target) or state.cycle>=3 or state.attempt.is_empty() or state.attempt.phase!="success": return _no("完成本轮装置后，到记录终端封存。")
   _seal();return _ok("真实操作已经封存，新一轮开始。")
  "fast_forward":
   if state.finale.phase in ["warning","chase"]: return _no("追逐时不能快进。")
   if state.attempt.is_empty() or state.attempt.phase not in ["countdown","recording"]: return _no("先启动装置并到自己的工位；准备阶段不需要等待。")
   for _i: int in range(720):
    advance()
    if state.attempt.phase in ["failed","success"]: break
    if state.cycle==3 and state.attempt.phase=="recording" and state.attempt.joint_trace.is_empty() and state.attempt.holds.has("assist_a") and state.attempt.holds.has("assist_b"):
     state.attempt.message="两条历史已经到位，请在 C 释放。";break
   return _ok(state.attempt.message)
  "choose_future":
   if target!="archive_terminal" or not _near(target) or not state.flags.bellows or not p.get("accept") is bool: return _no("解除风箱纸偶后，在档案室作出选择。")
   if state.finale.used: return _no("已经实际使用的能力不能撤销。")
   state.finale.choice="accept" if p.accept else "refuse";state.finale.prediction={};state.finale.phase="none"
   if p.accept: _unlock("future");_learn("future",false)
   return _ok("你可先预览轨迹，真正使用才会留下违规记录。" if p.accept else "用已有观察校准安全路线，无需重做实验。")
  "forecast":
   if target!="archive_terminal" or not _near(target) or state.finale.choice!="accept": return _no("请在档案室选择未来能力。")
   if p.get("model") not in ["gravity","drag"] or not Physics.numeric(p.get("height")) or p.get("medium") not in ["air","vacuum"]: return _no("请选择模型、介质和高度。")
   var config: Dictionary=Physics.setup("paper","flat",float(p.height),0.0,"vacuum" if p.model=="gravity" else p.medium)
   if config.is_empty(): return _no("参数超出模型范围。")
   state.finale.prediction={"origin":"prediction","model":p.model,"trace":Physics.trace(config),"parameters":p.duplicate(true)};state.finale.phase="ready"
   return _ok("轨迹预览已准备；到闸门亲手释放。预览不计违规。")
  "calibrate":
   if target!="archive_terminal" or not _near(target) or state.finale.choice!="refuse": return _no("请在档案室选择已有观察路线。")
   for record: Dictionary in state.observations:
    if record.observed and record.trace.setup.medium=="air" and record.trace.setup.shape=="flat":
     state.finale.prediction={"origin":"measurement","source_id":record.source_id,"trace":record.trace.duplicate(true)};state.finale.phase="ready"
     return _ok("引用了展开纸片的实测记录。去器材室校准远端刻度，再回来释放。")
   return _no("需要一份已观察的空气中展开纸片记录。")
  "gate_release":
   if target!="fall_gate" or not _near(target) or state.finale.phase!="ready": return _no("先在档案室建立预测或校准，再释放闸门。")
   if state.finale.choice=="refuse" and not state.flags.safe_checked: return _no("安全路线需先完成器材室远端刻度校准。")
   var real_trace: Dictionary=Physics.trace(Physics.setup("paper"))
   if absf(float(real_trace.arrival_s)-float(state.finale.prediction.trace.arrival_s))>0.01: return _no("这个模型与闸门中的空气纸片不符，预测窗口没有覆盖实测落点。请自行选择适用模型。")
   state.finale.release_tick=state.tick;state.finale.open_tick=int(state.tick)+int(ceil(real_trace.arrival_s*60.0));state.finale.close_tick=int(state.finale.open_tick)+180
   if state.finale.choice=="accept" and not state.finale.used:
    state.finale.used=true;state.finale.violations=1
   return _ok("闸门已释放。未来路线免去远端校准；纸片落地后通行窗口为 3 秒。")
  "dodge":
   if target!="player" or int(state.tick)<int(state.finale.dodge_ready): return _no("闪避尚未恢复。")
   state.finale.dodge_until=int(state.tick)+10;state.finale.dodge_ready=int(state.tick)+48;return _ok("闪避。")
  "submit":
   if target!="cycle_console" or not _near(target) or state.room!="tower" or state.finale.phase!="escaped": return _no("带着完整记录抵达观测塔后才能提交。")
   state.completed=true;state.mode="complete";state.finale.phase="complete";state.stage="complete"
   return _ok("你留下了越过许可的轨迹。" if state.finale.used else "你用亲眼看到的规律走到了这里。")
 return _no("当前不支持这个操作。")

func _visit(destination: String) -> Dictionary:
 if state.room=="classroom" and state.cycle==1 and int(state.tick)>int(state.opening.door_until): return _no("纸片计时门已关闭，再展开纸片释放一次。")
 if destination=="lab" and not state.flags.patrol: return _no("巡逻纸偶挡住了实验室入口。")
 if destination=="archive" and not state.flags.bellows: return _no("档案室仍被风箱纸偶的异常封锁。")
 if destination=="tower":
  if state.cycle==3:
   if state.finale.phase not in ["chase","ready"] or state.finale.release_tick<0: return _no("先走完档案室的闸门路线。")
   if state.finale.used and int(state.tick)-int(state.finale.chase_started)<120: return _no("监考者仍封锁入口，躲开追踪后再进入。")
   state.finale.phase="escaped"
 if state.room=="archive" and state.finale.phase=="ready":
  if state.finale.choice=="refuse" and not state.flags.safe_checked:
   pass # A real longer route goes through the storage calibration marker.
  else:
   if state.tick<state.finale.open_tick or state.tick>state.finale.close_tick: return _no("先释放闸门，等纸片落地后通过。")
   if state.finale.used:
    state.finale.phase="warning";state.finale.warning_end=int(state.tick)+60
    state.finale.examiner_room="corridor";state.finale.examiner_position=[320.0,284.0]
 state.room=destination;state.position=[320.0,224.0];_sample()
 if state.finale.phase in ["warning","chase"]:
  state.finale.examiner_room=destination;state.finale.examiner_position=[320.0,284.0]
 return _ok("来到"+room_title())

func _begin_battle(id: String) -> Dictionary:
 if id not in ["patrol","hammer","bellows"] or not _near(id) or state.flags.get(id,false): return _no("这里没有尚未完成的遭遇。")
 if id=="patrol" and not state.flags.paper_door: return _no("先通过纸片门。")
 if id=="hammer" and not state.flags.rig_demo: return _no("先操作配重示范台，学习调高和齐放。")
 if id=="bellows" and not state.flags.joint: return _no("需要第三轮三个角色共同完成真空实验。")
 state.battle=Combat.initial(id);state.mode="combat";return _ok("进入象征界战斗。" if id=="patrol" else "异常展开，进入阴影界。")

func combat_preview(action: String, target: String="") -> Dictionary:
 if state.mode!="combat": return _no("当前没有战斗。")
 var result: Dictionary=Combat.apply(state.battle,action,target,state.owned)
 result["revision"]=state.revision;result["can_predict"]=state.knowledge.has("gravity") and (state.battle.medium=="vacuum" or state.knowledge.has("drag") or state.battle.id=="hammer")
 return result

func _record(kind: String, target: String, payload: Dictionary, origin: Dictionary={}) -> void:
 var source: Dictionary=state if origin.is_empty() else origin
 state.revision+=1
 var next_seq: int=int(state.seq)+1 if source.cycle==state.cycle else int(source.seq)+1
 var event: Dictionary={"id":"c%d:e%d" % [source.cycle,next_seq],"cycle":source.cycle,"seq":next_seq,"tick":source.tick,"room":source.room,"position":source.position.duplicate(),"kind":kind,"target":target,"payload":payload.duplicate(true),"scope":"device" if kind in ["bell","hold","joint_release","device_complete"] or (kind=="interact" and target in ["sync_bell","assist_a","assist_b","lab_drop"]) else "world"}
 if source.cycle==state.cycle: state.seq=next_seq;state.events.append(event)
 else: state.histories.back().events.append(event)
 _sample()

func _sample() -> void:
 var sample: Dictionary={"tick":state.tick,"room":state.room,"position":state.position.duplicate(),"direction":state.direction}
 if state.samples.is_empty() or state.samples.back()!=sample: state.samples.append(sample)

func _unlock(id: String) -> void:
 if id not in state.owned: state.owned.append(id)

func _learn(id: String, authorized: bool) -> void:
 state.knowledge[id]={"discovered":true,"understood":true,"authorized":authorized}

func _observe(trace_data: Dictionary, source: String, summary: String, observed: bool=true) -> void:
 for item: Dictionary in state.observations:
  if item.source_id==source:
   if observed: item.observed=true
   return
 state.observations.append({"id":"observation_"+source,"source_id":source,"cycle":state.cycle,"tick":state.tick,"trace":trace_data.duplicate(true),"observed":observed,"summary":summary})

func advance(steps: int=1) -> void:
 if state.mode!="world": return
 for _i: int in range(clampi(steps,0,108000)):
  state.tick+=1
  if state.opening.phase=="falling":
   state.opening.elapsed=(int(state.tick)-int(state.opening.release_tick))/60.0
   if state.opening.elapsed>=state.opening.trace.arrival_s:
    state.opening.phase="landed"
    if state.opening.trace.arrival_s>0.74: state.opening.door_until=int(state.tick)+180;state.flags.paper_door=true
    notice.emit("纸片到达，机械延时已开启。" if state.opening.trace.arrival_s>0.74 else "纸团落得太快，延时齿轮没有接上。试试展开。")
  _advance_attempt()
  _advance_chase()
  if int(state.tick)%6==0: _sample()
  if state.mode!="world": break

func _attempt_action(kind: String, station: String) -> void:
 state.attempt.actions.append({"tick":state.attempt.tick,"source_tick":state.tick,"event_id":"c%d:e%d" % [state.cycle,int(state.seq)+1],"kind":kind,"target":station,"position":state.position.duplicate(),"room":state.room})
 state.attempt.samples.append({"tick":state.attempt.tick,"source_tick":state.tick,"room":state.room,"position":state.position.duplicate(),"direction":state.direction})

func _release_departed() -> void:
 if state.attempt.is_empty() or state.attempt.phase not in ["countdown","recording"]: return
 for station: String in state.attempt.holds.keys():
  var hold: Dictionary=state.attempt.holds[station]
  if hold.actor=="player" and not _near(station):
   state.attempt.holds.erase(station);_fail_attempt("离开操作区，持有已释放。")

func _joint_ready() -> bool:
 var a: Dictionary=state.attempt
 return state.flags.power and a.holds.has("assist_a") and a.holds.has("assist_b") and a.holds.assist_a.actor=="echo_1" and a.holds.assist_b.actor=="echo_2" and _near("lab_drop")

func _advance_attempt() -> void:
 if state.attempt.is_empty() or state.attempt.phase not in ["countdown","recording"]: return
 var a: Dictionary=state.attempt
 a.tick+=1;a.powered=state.flags.power
 if not state.flags.power: _fail_attempt("供电中断。");return
 if a.tick>=0: a.phase="recording"
 # Each historical segment is consumed only in this local scope, in cycle/event order.
 for segment: Dictionary in state.segments:
  var actor: String="echo_%d" % int(segment.source_cycle)
  for action: Dictionary in segment.commands:
   var key: String=actor+":"+action.event_id+":"+action.kind
   if int(action.tick)>int(a.tick) or key in a.executed: continue
   a.executed.append(key)
   if action.kind=="hold_begin":
    if not state.flags.power or a.holds.has(action.target): _fail_attempt("历史工位被占用或无电。");return
    a.holds[action.target]={"actor":actor,"begin":a.tick}
   else: a.holds.erase(action.target)
  var pose: Dictionary=_segment_pose(segment,int(a.tick))
  for station: String in a.holds.keys():
   if a.holds[station].actor==actor and (pose.is_empty() or pose.room!="lab" or not _near(station,pose.position)):
    _fail_attempt("回声离开了原操作区。");return
 _release_departed()
 if a.phase=="failed": return
 if int(a.tick)%6==0: a.samples.append({"tick":a.tick,"source_tick":state.tick,"room":state.room,"position":state.position.duplicate(),"direction":state.direction})
 if a.tick<0: return
 var valid: bool=a.holds.has("assist_a") and (state.cycle==1 or a.holds.has("assist_b"))
 if valid: a.overlap+=1
 if state.cycle<3 and int(a.overlap)>=(480 if state.cycle==1 else 360):
  var station: String="assist_a" if state.cycle==1 else "assist_b"
  _attempt_action("hold_end",station)
  _record("device_complete",station,{"attempt_tick":a.tick,"overlap":a.overlap})
  a.phase="success";a.message="装置完成，真实有效操作已录制；去观测塔封存。";a.holds={};notice.emit(a.message)
 elif state.cycle==3 and not a.joint_trace.is_empty():
  if not _joint_ready(): _fail_attempt("A/B/C 在测量中断开，当前尝试失败。");return
  if (int(a.tick)-int(a.joint_start))/60.0>=float(a.joint_trace.arrival_s):
   state.flags.joint=true;_unlock("pump");_learn("gravity",true)
   _observe(a.joint_trace,a.source_event_id,"两条历史共同维持真空；形状带来的空气时间差消失。",false)
   a.phase="success";a.message="三人联合测量完成，风箱纸偶显现。";a.holds={};notice.emit(a.message)
 if a.tick>600 and a.phase=="recording": _fail_attempt("错过本次局部窗口；重试后重新敲铃，历史不会移动。")

func _fail_attempt(message: String) -> void:
 state.attempt.phase="failed";state.attempt.message=message;state.attempt.holds={};notice.emit(message)

func _segment_pose(segment: Dictionary, replay_tick: int) -> Dictionary:
 var found: Dictionary={}
 for sample: Dictionary in segment.pose_samples:
  if int(sample.tick)>replay_tick: break
  found=sample
 return found

func _seal() -> void:
 var a: Dictionary=state.attempt
 var segment: Dictionary={"segment_id":"segment_%d" % state.cycle,"source_cycle":state.cycle,"source_begin_event_id":a.actions.front().event_id,"source_end_event_id":a.actions.back().event_id,"anchor_id":"sync_bell","relative_ticks":int(a.tick),"commands":a.actions.duplicate(true),"pose_samples":a.samples.duplicate(true)}
 segment["hash"]=JSON.stringify(segment).sha256_text();state.segments.append(segment)
 state.histories.append({"cycle":state.cycle,"events":state.events.duplicate(true),"samples":state.samples.duplicate(true)})
 state.cycle+=1;state.tick=0;state.seq=0;state.room="classroom";state.position=[320.0,224.0];state.events=[];state.samples=[];state.attempt={};state.battle={};state.flags.power=true;state.stage="record_b" if state.cycle==2 else "joint"
 state.motion_tick=-1;state.motion_distance=0.0
 state.opening={"shape":"crumpled","phase":"idle","trace":{},"release_tick":-1,"elapsed":0.0,"door_until":-1,"source_id":""}
 _sample()

func echo_poses() -> Array:
 var result: Array=[]
 if state.room=="lab" and not state.attempt.is_empty() and state.attempt.phase in ["countdown","recording"]:
  for segment: Dictionary in state.segments:
   var pose: Dictionary=_segment_pose(segment,int(state.attempt.tick))
   if not pose.is_empty() and pose.room==state.room: result.append({"cycle":segment.source_cycle,"x":pose.position[0],"y":pose.position[1],"moving":false,"direction":pose.direction})
  return result
 for history: Dictionary in state.histories:
  var found: Dictionary={}
  for sample: Dictionary in history.samples:
   if int(sample.tick)>int(state.tick): break
   found=sample
  if not found.is_empty() and found.room==state.room: result.append({"cycle":history.cycle,"x":found.position[0],"y":found.position[1],"moving":false,"direction":found.direction})
 return result

func _advance_chase() -> void:
 var f: Dictionary=state.finale
 if f.phase=="warning" and int(state.tick)>=int(f.warning_end):
  f.phase="chase";f.chase_started=state.tick;notice.emit("灯光转红，监考者追来了！移动并闪避，撑过两秒后进入观测塔。")
 if f.phase!="chase" or f.examiner_room!=state.room: return
 var enemy: Vector2=Vector2(f.examiner_position[0],f.examiner_position[1])
 enemy=enemy.move_toward(Vector2(state.position[0],state.position[1]),110.0/60.0)
 f.examiner_position=[enemy.x,enemy.y]
 if enemy.distance_to(Vector2(state.position[0],state.position[1]))<18.0 and int(state.tick)>=int(f.dodge_until):
  f.phase="caught";state.mode="caught";notice.emit("被监考者拦截，恢复追逐前检查点。")

func objective() -> String:
 if state.completed: return "记录已提交，序章完成。"
 if state.mode=="combat": return "看敌人预告，操作物体，结束回合看结果。"
 if state.mode=="caught": return "恢复追逐检查点，再次闪避。"
 if not state.flags.paper_door: return "门关得太快——让这张纸慢一点。"
 if not state.flags.patrol: return "走出教室，面对走廊的巡逻纸偶。"
 if not state.flags.rig_demo: return "在实验室亲手调高、齐放配重。"
 if not state.flags.hammer: return "改变配重落地时刻，打开双锤护盾。"
 if state.cycle==1: return "敲同步铃，操作 A；成功后去塔内封存。"
 if state.cycle==2:
  return "用固定稳住器材室纸幕，取出密封组件。" if not state.flags.seal_kit else "敲铃，让过去的 A 配合现在的 B。"
 if not state.flags.joint: return "准备好后敲铃，让 A/B 回声配合你在 C 释放。"
 if not state.flags.bellows: return "应对风箱纸偶：真空后换一种控制落点的方法。"
 if state.finale.phase in ["warning","chase"]: return "监考者正在追踪，闪避并抵达观测塔。"
 if state.finale.phase=="escaped": return "到观测塔记录终端提交。"
 if state.finale.phase=="ready": return "到器材室校准刻度。" if state.finale.choice=="refuse" and not state.flags.safe_checked else "到档案室闸门释放，落地后走出档案室。"
 return "去档案室选择：已有规律，或借来的轨迹。"

func hint() -> String:
 if not state.flags.paper_door: return "展开同一张纸，再释放。看落地是否让延时齿轮接上。"
 if state.mode=="combat":
  if state.battle.id=="hammer": return "调高较低支架后齐放；也可先防御，让锤击压低较高支架。"
  if state.battle.id=="bellows": return "空气中形状能改变落点；真空阶段把纸片抬到 3.5 米再齐放。"
  return "攻击造成伤害，防御减少伤害，左右移动避开预告通道。"
 return objective()+" 操作失败可以局部重试，过去的记录不会改变。"

static func _ok(message: String) -> Dictionary:
 return {"ok":true,"message":message}
static func _no(message: String) -> Dictionary:
 return {"ok":false,"message":message}
