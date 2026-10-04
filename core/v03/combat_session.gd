extends RefCounted
const Physics = preload("res://core/v03/physics.gd")
const COSTS: Dictionary={"crumple":1,"unfold":1,"raise":1,"release_pair":1,"fix":1,"unfix":0,"pump":2,"future":2,"attack":1,"defend":1,"move_left":1,"move_right":1}

static func object(id: String, title: String, height: float=2.0, lane: int=1) -> Dictionary:
 var s: Dictionary=Physics.setup(id,"flat",height)
 return {"id":id,"title":title,"kind":"paper" if id=="paper" else "metal","mass":s.mass,"area":s.area,"coefficient":s.coefficient,"height":height,"shape":s.shape,"held":true,"fixed":false,"lane":lane}

static func initial(id: String) -> Dictionary:
 var objects: Dictionary={}
 if id=="hammer": objects={"left":object("left","重配重",2.0,0),"right":object("right","轻配重",1.0,2)}
 else: objects={"paper":object("paper","同一张纸",2.0,1),"weight":object("weight","金属配重",2.0,0)}
 return {"id":id,"round":1,"ap":2,"hp":14,"enemy_hp":9 if id=="patrol" else (6 if id=="hammer" else 12),"lane":1,"intent":{"title":"扫击中路" if id!="hammer" else "锤击高支架","lane":1,"damage":4},"objects":objects,"shield":id!="patrol","phase":"air","defending":false,"pending_release":false,"medium":"air","powered":true,"sealed":true,"log":[],"outcome":"active","revision":0,"traces":[],"trigger":"","device_tick":0}

static func apply(source: Dictionary, action: String, target: String, owned: Array) -> Dictionary:
 if source.is_empty() or source.outcome!="active": return deny("本场战斗已结束。")
 if action!="end_turn" and not COSTS.has(action): return deny("未知动作。")
 var targets: Dictionary={"attack":["","enemy"],"defend":["","player"],"move_left":["","player"],"move_right":["","player"],"release_pair":["","pair"],"pump":["","chamber"],"future":["","device"],"end_turn":[""]}
 if targets.has(action) and target not in targets[action]: return deny("这个动作不能作用于该目标。")
 if action not in ["attack","defend","move_left","move_right","unfix","end_turn"] and action not in owned: return deny("还没有掌握这个动作。")
 var cost: int=int(COSTS.get(action,0))
 if int(source.ap)<cost: return deny("行动点不足，先结束回合。")
 var s: Dictionary=source.duplicate(true)
 var obj: Dictionary=s.objects.get(target,{})
 var message: String=""
 match action:
  "crumple","unfold":
   if obj.is_empty() or obj.kind!="paper" or not obj.held: return deny("需要夹具里可变形的纸片。")
   obj.shape="crumpled" if action=="crumple" else "flat"
   obj.area=0.00025 if action=="crumple" else 0.006
   message="纸片形状改变；质量保持不变。"
   if s.medium=="vacuum": message+="真空里没有空气阻力，改变形状不改变落体时间。"
  "raise":
   if obj.is_empty() or not obj.held: return deny("需要夹具里尚未释放的物体。")
   obj.height=2.0 if float(obj.height)<2.0 else (3.5 if float(obj.height)<3.5 else 1.0)
   message="%s 的释放高度调整到 %.1f 米。" % [obj.title,obj.height]
  "fix","unfix":
   if obj.is_empty() or obj.kind!="paper": return deny("夹具只能固定这里的纸片。")
   obj.fixed=action=="fix";obj.held=true
   message="纸片固定在原位，成为遮挡。" if obj.fixed else "已松开固定，可在本轮释放。"
  "pump":
   if s.id!="bellows" or not s.powered or not s.sealed: return deny("只有通电且密封的玻璃舱可以抽气。")
   s.medium="vacuum";message="玻璃舱抽成真空，舱外不受影响。"
  "release_pair":
   if s.pending_release: return deny("本轮已经安排释放。")
   for item: Dictionary in s.objects.values():
    if not item.held or item.fixed: return deny("先松开固定并准备两个夹具。")
   s.pending_release=true;message="已安排本轮齐放；结束回合后按实际轨迹结算。"
  "attack":
   if s.shield: message="攻击碰到机械护盾，未造成伤害。"
   else:
    var hit: int=4 if s.id=="patrol" and s.objects.paper.shape=="crumpled" else 3
    s.enemy_hp=maxi(0,int(s.enemy_hp)-hit);message="攻击命中，造成 %d 点伤害。" % hit
    if s.id=="bellows" and s.phase=="air" and int(s.enemy_hp)<=6:
     s.phase="vacuum";s.medium="vacuum";s.shield=true;s.objects.paper.height=2.0
     message+="风箱封闭玻璃舱！真空中原来的纸片时间差消失。"
  "defend": s.defending=true;message="准备防御，下次伤害减少 3 点。"
  "move_left","move_right":
   var destination: int=int(s.lane)+(-1 if action=="move_left" else 1)
   if destination<0 or destination>2: return deny("已经在最外侧通道。")
   s.lane=destination;message="改变站位，避开预告攻击。"
  "future": message="轨迹已展开；这一回合可查看完整落点。";s["future_visible"]=true
  "end_turn":
   message=settle(s)
 s.ap-=cost
 if int(s.enemy_hp)<=0: s.outcome="won";message+=" 战斗胜利。"
 elif int(s.hp)<=0: s.outcome="lost";message+=" 倒下了，可恢复战前检查点。"
 s.revision+=1;s.log.append(message)
 if s.log.size()>12: s.log.pop_front()
 return {"ok":true,"message":message,"state":s,"effect":"ineffective" if action=="attack" and source.shield else "applied"}

static func settle(s: Dictionary) -> String:
 var message: String=""
 s.traces=[]
 if s.pending_release:
  for item: Dictionary in s.objects.values():
   var t: Dictionary=Physics.trace(Physics.setup(item.id,"flat" if item.shape=="solid" else item.shape,float(item.height),0.0,s.medium))
   t["id"]=item.id;s.traces.append(t)
  if s.id=="hammer":
   var difference: float=absf(float(s.traces[0].arrival_s)-float(s.traces[1].arrival_s))
   if difference<=0.01: s.shield=false;s.trigger="synchronized";message="两个配重在容差内到达，机械护盾打开。"
   else: message="落地相差 %.3f 秒，护盾保持关闭。" % difference
  elif s.id=="bellows":
   var arrival: float=float(s.traces[0].arrival_s)
   if s.medium=="air":
    if arrival>=0.78 and arrival<=0.92: s.shield=false;s.trigger="curtain";message="展开纸片挡住扫描，护盾开启。"
    elif arrival<0.70: s.shield=false;s.trigger="quick_switch";message="纸团抢先击中开关，护盾开启。"
    else: message="落点没有进入装置窗口。"
   elif arrival>=0.80 and arrival<=0.95:
    s.shield=false;s.trigger="vacuum_height";message="改变高度后，真空落体进入 0.80–0.95 秒窗口，护盾开启。"
   else: message="真空落体过早；调整夹具高度，目标窗口为 0.80–0.95 秒。"
  else: message="纸片按实际轨迹下落。"
  s.pending_release=false
 var damage: int=0
 if int(s.lane)==int(s.intent.lane):
  damage=maxi(0,int(s.intent.damage)-(3 if s.defending else 0))
  if s.id=="patrol" and s.objects.paper.shape=="flat": damage=maxi(0,damage-2)
  if s.objects.has("paper") and s.objects.paper.fixed and s.objects.paper.shape=="flat": damage=maxi(0,damage-2)
  s.hp=maxi(0,int(s.hp)-damage)
 if s.id=="hammer" and s.shield:
  var high: String="left" if float(s.objects.left.height)>=float(s.objects.right.height) else "right"
  s.objects[high].height=1.0
  message+=" 锤击把较高支架压到 1 米。"
 message+=" 敌人执行预告攻击，受到 %d 点伤害。" % damage
 s.device_tick+=90;s.round+=1;s.ap=2;s.defending=false
 s.intent={"title":"锤击高支架" if s.id=="hammer" else "扫描第 %d 路" % ((int(s.round)%3)+1),"lane":int(s.round)%3,"damage":4}
 return message

static func deny(message: String) -> Dictionary:
 return {"ok":false,"message":message}
