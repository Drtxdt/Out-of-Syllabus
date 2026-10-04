extends RefCounted
const Physics = preload("res://core/v03/physics.gd")
const Combat = preload("res://core/v03/combat_session.gd")
const ROOMS: Array=["classroom","corridor","storage","lab","tower","archive"]
const ACTIONS: Array=["crumple","unfold","raise","release_pair","fix","pump","future"]
const KINDS: Array=["interact","paper_shape","release","observe","learn_rig","begin_battle","combat_action","end_turn","retreat","fix","power","bell","hold","joint_release","device_complete","seal","choose_future","forecast","calibrate","gate_release","dodge","submit"]

static func integer(v: Variant, low: int=0, high: int=100000000) -> bool:
 return Physics.numeric(v) and float(v)==floorf(float(v)) and float(v)>=low and float(v)<=high

static func position(p: Variant) -> bool:
 return p is Array and p.size()==2 and Physics.numeric(p[0]) and Physics.numeric(p[1]) and float(p[0])>=40 and float(p[0])<=600 and float(p[1])>=56 and float(p[1])<=306

static func json_value(v: Variant, depth: int=0) -> bool:
 if depth>40: return false
 if v is Dictionary:
  if v.size()>200: return false
  for key: Variant in v:
   if not key is String or not json_value(v[key],depth+1): return false
  return true
 if v is Array:
  if v.size()>500000: return false
  for item: Variant in v:
   if not json_value(item,depth+1): return false
  return true
 return v is String or v is bool or v==null or Physics.numeric(v)

static func validate(data: Variant) -> String:
 if not data is Dictionary or not json_value(data): return "存档包含非 JSON 数据或过深结构。"
 var keys: Array=["cycle","tick","room","position","direction","mode","revision","seq","stage","flags","owned","knowledge","events","samples","histories","segments","attempt","battle","opening","observations","finale","completed","handled","motion_tick","motion_distance"]
 if not data.has_all(keys): return "存档缺少版本定义字段。"
 if not integer(data.cycle,1,3) or not integer(data.tick) or not integer(data.seq) or not integer(data.revision): return "时间、循环或序号无效。"
 if data.room not in ROOMS or not position(data.position) or data.direction not in ["up","down","left","right"]: return "角色位置无效。"
 if data.mode not in ["world","combat","caught","complete"] or not data.stage is String or not data.completed is bool: return "章节状态无效。"
 if not integer(data.motion_tick,-1,int(data.tick)) or not Physics.numeric(data.motion_distance) or float(data.motion_distance)<0 or float(data.motion_distance)>4.01: return "移动预算无效。"
 for key: String in ["flags","knowledge","attempt","battle","opening","finale"]:
  if not data[key] is Dictionary: return "嵌套对象无效："+key
 for key: String in ["owned","events","samples","histories","segments","observations","handled"]:
  if not data[key] is Array: return "列表无效："+key
 if data.histories.size()!=int(data.cycle)-1 or data.segments.size()!=data.histories.size(): return "循环与封存历史数量不符。"
 var flags: Array=["paper_door","patrol","rig_demo","hammer","seal_kit","joint","bellows","power","safe_checked"]
 if not data.flags.has_all(flags): return "世界标志不完整。"
 for flag: String in flags:
  if not data.flags[flag] is bool: return "世界标志类型错误。"
 if data.flags.patrol and not data.flags.paper_door or data.flags.rig_demo and not data.flags.patrol or data.flags.hammer and not data.flags.rig_demo or data.flags.bellows and not data.flags.joint: return "章节依赖矛盾。"
 if data.cycle>1 and not data.flags.hammer or data.flags.joint and data.cycle!=3: return "循环阶段不符。"
 var owned: Dictionary={}
 for id: Variant in data.owned:
  if not id is String or id not in ACTIONS or owned.has(id): return "未知或重复动作卡。"
  owned[id]=true
 for id: Variant in data.knowledge:
  if id not in ["gravity","drag","future"]: return "未知知识。"
  var access: Variant=data.knowledge[id]
  if not access is Dictionary or not access.has_all(["discovered","understood","authorized"]): return "知识权限无效。"
  for field: String in ["discovered","understood","authorized"]:
   if not access[field] is bool: return "知识权限不是布尔值。"
  if id=="future" and access.authorized: return "未来知识不能伪造许可。"
 var sources: Dictionary={}
 var error: String=track(data.events,data.samples,int(data.cycle),int(data.tick),sources)
 if not error.is_empty(): return error
 if not data.events.is_empty() and int(data.events.back().seq)!=int(data.seq): return "活动事件游标无效。"
 for i: int in range(data.histories.size()):
  var h: Variant=data.histories[i]
  if not h is Dictionary or not h.has_all(["cycle","events","samples"]) or h.cycle!=i+1: return "历史序号无效。"
  error=track(h.events,h.samples,i+1,100000000,sources)
  if not error.is_empty(): return error
 for i: int in range(data.segments.size()):
  error=segment(data.segments[i],i+1,sources)
  if not error.is_empty(): return error
 var seen: Dictionary={}
 for record: Variant in data.observations:
  if not record is Dictionary or not record.has_all(["id","source_id","cycle","tick","trace","observed","summary"]): return "观察记录结构无效。"
  if not record.source_id is String or not sources.has(record.source_id) or seen.has(record.source_id): return "观察来源不存在或重复。"
  if record.id!="observation_"+record.source_id or not record.observed is bool or not record.summary is String or not integer(record.cycle,1,int(data.cycle)) or not integer(record.tick): return "观察元数据无效。"
  if not Physics.valid_trace(record.trace): return "观察轨迹与模拟器不符。"
  var source: Dictionary=sources[record.source_id]
  if source.kind not in ["release","joint_release","interact"] or source.target not in ["paper","lab_drop"]: return "预测不能冒充实测。"
  seen[record.source_id]=true
 var o: Dictionary=data.opening
 if not o.has_all(["shape","phase","trace","release_tick","elapsed","door_until","source_id"]) or o.shape not in ["flat","crumpled"] or o.phase not in ["idle","falling","landed"]: return "开场装置状态无效。"
 if not integer(o.release_tick,-1,int(data.tick)) or not integer(o.door_until,-1,100000000) or not Physics.numeric(o.elapsed) or o.elapsed<0 or not o.trace is Dictionary: return "开场时间无效。"
 if o.phase!="idle" and (not Physics.valid_trace(o.trace) or not sources.has(o.source_id)): return "开场释放缺少真实轨迹来源。"
 error=attempt(data.attempt,sources,int(data.cycle))
 if not error.is_empty(): return error
 error=combat(data.battle)
 if not error.is_empty(): return error
 if data.mode=="combat" and data.battle.is_empty(): return "战斗模式缺少遭遇。"
 var f: Dictionary=data.finale
 if not f.has_all(["choice","phase","used","violations","prediction","release_tick","open_tick","close_tick","examiner_room","examiner_position","warning_end","dodge_until","dodge_ready","chase_started"]): return "结尾结构不完整。"
 if f.choice not in ["none","accept","refuse"] or f.phase not in ["none","ready","warning","chase","caught","escaped","complete"] or not f.used is bool or not integer(f.violations,0,1): return "结尾相位无效。"
 if f.used!=(f.violations==1) or f.used and f.choice!="accept" or data.completed!=(f.phase=="complete") or (data.mode=="caught")!=(f.phase=="caught") or (data.mode=="complete")!=data.completed: return "结尾结算矛盾。"
 if f.examiner_room not in ROOMS or not position(f.examiner_position): return "监考者位置无效。"
 for field: String in ["release_tick","open_tick","close_tick","warning_end","dodge_until","dodge_ready","chase_started"]:
  if not integer(f[field],-1,100000000): return "结尾时间无效。"
 if not f.prediction is Dictionary: return "预测无效。"
 if not f.prediction.is_empty():
  if not f.prediction.has_all(["origin","trace"]) or not Physics.valid_trace(f.prediction.trace): return "预测轨迹不正确。"
  if f.prediction.origin=="measurement":
   if not seen.has(f.prediction.get("source_id","")): return "校准缺少已观察记录。"
   var match_record: bool=false
   for record: Dictionary in data.observations:
    if record.source_id==f.prediction.source_id and record.observed and Physics.equivalent(record.trace,f.prediction.trace): match_record=true
   if not match_record: return "校准冒充实测。"
  elif f.prediction.origin=="prediction":
   if f.choice!="accept" or f.prediction.get("model") not in ["gravity","drag"] or not f.prediction.get("parameters") is Dictionary: return "预测模型来源无效。"
  else: return "预测来源类型无效。"
 if f.phase!="none" and f.prediction.is_empty(): return "结尾缺少校准或预测。"
 if data.handled.size()>256: return "请求记录过多。"
 for id: Variant in data.handled:
  if not id is String or id.is_empty(): return "请求记录无效。"
 return ""

static func track(events: Variant, samples: Variant, cycle: int, max_tick: int, sources: Dictionary) -> String:
 if not events is Array or not samples is Array: return "历史轨道类型错误。"
 var previous: int=-1
 var seq: int=0
 for e: Variant in events:
  if not e is Dictionary or not e.has_all(["id","cycle","seq","tick","room","position","kind","target","payload","scope"]): return "事件字段缺失。"
  if e.cycle!=cycle or not integer(e.seq,seq+1) or not integer(e.tick,maxi(0,previous),max_tick): return "事件顺序无效。"
  if e.id!="c%d:e%d" % [cycle,int(e.seq)] or sources.has(e.id) or e.kind not in KINDS or not e.target is String or not e.payload is Dictionary or e.scope not in ["world","device"] or e.room not in ROOMS or not position(e.position): return "事件身份或来源无效。"
  if e.kind=="paper_shape" and e.payload.get("shape") not in ["flat","crumpled"]: return "变形事件参数无效。"
  if e.kind=="choose_future" and not e.payload.get("accept") is bool: return "选择事件参数无效。"
  sources[e.id]=e;previous=int(e.tick);seq=int(e.seq)
 previous=-1
 for sample: Variant in samples:
  if not sample is Dictionary or not sample.has_all(["tick","room","position","direction"]) or not integer(sample.tick,maxi(0,previous),max_tick) or sample.room not in ROOMS or not position(sample.position) or sample.direction not in ["up","down","left","right"]: return "姿态采样无效。"
  previous=int(sample.tick)
 return ""

static func segment(s: Variant, cycle: int, sources: Dictionary) -> String:
 if not s is Dictionary or not s.has_all(["segment_id","source_cycle","source_begin_event_id","source_end_event_id","anchor_id","relative_ticks","commands","pose_samples","hash"]): return "片段字段缺失。"
 if s.source_cycle!=cycle or s.anchor_id!="sync_bell" or not integer(s.relative_ticks,359,600) or not s.commands is Array or s.commands.size()<2 or not s.pose_samples is Array or s.pose_samples.is_empty(): return "片段范围无效。"
 var unsigned: Dictionary=s.duplicate(true);unsigned.erase("hash")
 if not s.hash is String or JSON.stringify(unsigned).sha256_text()!=s.hash: return "封存片段哈希已改变。"
 if not sources.has(s.source_begin_event_id) or not sources.has(s.source_end_event_id): return "片段边界没有真实事件。"
 var last: int=-181
 for cmd: Variant in s.commands:
  if not cmd is Dictionary or not cmd.has_all(["tick","source_tick","event_id","kind","target","position","room"]): return "片段命令无效。"
  if not integer(cmd.tick,last,int(s.relative_ticks)) or not sources.has(cmd.event_id): return "片段命令顺序或来源无效。"
  var event: Dictionary=sources[cmd.event_id]
  if event.cycle!=cycle or event.tick!=cmd.source_tick or event.room!=cmd.room or event.position!=cmd.position or event.target!=cmd.target or cmd.target!=("assist_a" if cycle==1 else "assist_b") or cmd.kind not in ["hold_begin","hold_end"]: return "片段改写了原始操作。"
  if cmd.kind=="hold_begin" and event.kind not in ["hold","interact"] or cmd.kind=="hold_end" and event.kind not in ["hold","interact","device_complete"]: return "片段角色动作来源无效。"
  last=int(cmd.tick)
 if s.commands.front().kind!="hold_begin" or s.commands.back().kind!="hold_end": return "持有操作缺少起止。"
 var source_start: int=int(s.commands.front().source_tick)-int(s.commands.front().tick)
 last=-181
 for pose: Variant in s.pose_samples:
  if not pose is Dictionary or not pose.has_all(["tick","source_tick","room","position","direction"]) or not integer(pose.tick,last,int(s.relative_ticks)) or not position(pose.position) or pose.room not in ROOMS or not integer(pose.source_tick) or int(pose.source_tick)-int(pose.tick)!=source_start: return "片段采样时间被改写。"
  last=int(pose.tick)
 return ""

static func attempt(a: Dictionary, sources: Dictionary, cycle: int) -> String:
 if a.is_empty(): return ""
 if not a.has_all(["phase","tick","holds","powered","message","start_world_tick","actions","samples","executed","overlap","joint_trace","joint_start","source_event_id","origin_cycle"]): return "尝试状态缺失。"
 if a.phase not in ["countdown","recording","success","failed"] or not integer(a.tick,-180,601) or not a.holds is Dictionary or not a.powered is bool or not a.message is String or not integer(a.start_world_tick) or not integer(a.overlap,0,600) or a.origin_cycle!=cycle: return "尝试状态无效。"
 for key: String in ["actions","samples","executed"]:
  if not a[key] is Array: return "尝试游标无效。"
 var actors: Array=[]
 for station: Variant in a.holds:
  var h: Variant=a.holds[station]
  if station not in ["assist_a","assist_b"] or not h is Dictionary or not h.has_all(["actor","begin"]) or h.actor not in ["player","echo_1","echo_2"] or h.actor in actors or not integer(h.begin,-180,600): return "工位占用无效。"
  actors.append(h.actor)
 for command: Variant in a.actions:
  if not command is Dictionary or not command.has_all(["tick","source_tick","event_id","kind","target","position","room"]) or not integer(command.tick,-180,600) or not sources.has(command.event_id) or not position(command.position): return "当前尝试缺少真实命令。"
 for pose: Variant in a.samples:
  if not pose is Dictionary or not pose.has_all(["tick","source_tick","room","position","direction"]) or not integer(pose.tick,-180,600) or not integer(pose.source_tick) or pose.room not in ROOMS or not position(pose.position): return "当前尝试采样无效。"
 for key: Variant in a.executed:
  if not key is String: return "执行游标不是来源 ID。"
 if not a.joint_trace is Dictionary or not integer(a.joint_start,-1,600): return "联合释放状态无效。"
 if not a.joint_trace.is_empty() and (not Physics.valid_trace(a.joint_trace) or not sources.has(a.source_event_id)): return "联合实验来源无效。"
 return ""

static func combat(b: Dictionary) -> String:
 if b.is_empty(): return ""
 var keys: Array=["id","round","ap","hp","enemy_hp","lane","intent","objects","shield","phase","defending","pending_release","medium","powered","sealed","log","outcome","revision","traces","trigger","device_tick"]
 if not b.has_all(keys) or b.id not in ["patrol","hammer","bellows"]: return "战斗字段缺失。"
 if not integer(b.round,1,10000) or not integer(b.ap,0,2) or not integer(b.hp,0,14) or not integer(b.enemy_hp,0,12) or not integer(b.lane,0,2) or not integer(b.revision) or not integer(b.device_tick): return "战斗数值越界。"
 for key: String in ["shield","defending","pending_release","powered","sealed"]:
  if not b[key] is bool: return "战斗布尔状态无效。"
 if b.phase not in ["air","vacuum"] or b.medium not in ["air","vacuum"] or b.outcome not in ["active","won","lost","retreated"]: return "战斗相位无效。"
 if (b.outcome=="won")!=(b.enemy_hp==0) or b.outcome=="lost" and b.hp!=0: return "战斗结算矛盾。"
 if not b.intent is Dictionary or not b.intent.has_all(["title","lane","damage"]) or not b.intent.title is String or not integer(b.intent.lane,0,2) or not integer(b.intent.damage,0,10): return "敌方意图无效。"
 if not b.log is Array or b.log.size()>12 or not b.traces is Array or not b.objects is Dictionary: return "战斗嵌套字段无效。"
 var expected: Dictionary=Combat.initial(b.id).objects
 if b.objects.size()!=expected.size(): return "战斗物体数量不符。"
 for id: String in expected:
  var o: Variant=b.objects.get(id)
  if not o is Dictionary or not o.has_all(["id","title","kind","mass","area","coefficient","height","shape","held","fixed","lane"]): return "物体字段缺失。"
  if o.id!=id or o.kind!=expected[id].kind or not o.title is String or not o.held is bool or not o.fixed is bool or not integer(o.lane,0,2): return "物体身份或夹具无效。"
  if not Physics.numeric(o.height) or float(o.height) not in [1.0,2.0,3.5] or o.shape not in (["flat","crumpled"] if id=="paper" else ["solid"]): return "物体条件无效。"
  var canonical: Dictionary=Physics.setup(id,"flat" if o.shape=="solid" else o.shape,float(o.height),0.0,b.medium)
  for field: String in ["mass","area","coefficient"]:
   if not Physics.equivalent(o[field],canonical[field]): return "物体质量或阻力参数被改写。"
 for t: Variant in b.traces:
  if not t is Dictionary: return "轨迹无效。"
  var trace: Dictionary=t.duplicate(true);trace.erase("id")
  if not Physics.valid_trace(trace): return "战斗轨迹无效。"
 return ""
