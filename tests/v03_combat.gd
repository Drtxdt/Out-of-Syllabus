extends "res://tests/v03_test_base.gd"
const Combat=preload("res://core/v03/combat_session.gd")
const ALL: Array=["crumple","unfold","raise","release_pair","fix","pump","future"]
func act(state: Dictionary,action: String,target: String="",owned: Array=ALL) -> Dictionary:
 var before: String=canonical(state)
 var result: Dictionary=Combat.apply(state,action,target,owned)
 check(canonical(state)==before,"resolver is pure "+action)
 check(result.ok,"legal action "+action+" / "+target)
 return result.get("state",state)
func reject(state: Dictionary,action: String,target: String="",owned: Array=ALL) -> void:
 var before: String=canonical(state)
 check(not Combat.apply(state,action,target,owned).ok,"reject "+action+" / "+target)
 check(canonical(state)==before,"rejected resolver is pure")
func solve_hammer(defensive: bool) -> Dictionary:
 var s: Dictionary=Combat.initial("hammer")
 if defensive:
  s=act(s,"defend");s=act(s,"end_turn")
  check(s.objects.left.height==1.0,"enemy impact really lowers high support")
 else:s=act(s,"raise","right")
 s=act(s,"release_pair")
 s=act(s,"end_turn")
 check(not s.shield and s.trigger=="synchronized","real synchronized traces open hammer shield")
 check(s.traces.size()==2 and absf(s.traces[0].arrival_s-s.traces[1].arrival_s)<=0.01,"hammer uses sensor tolerance")
 s=act(s,"attack");s=act(s,"attack")
 check(s.outcome=="won","complete hammer path "+str(defensive))
 return s
func solve_bellows(crumpled: bool) -> Dictionary:
 var s: Dictionary=Combat.initial("bellows")
 if crumpled:s=act(s,"crumple","paper")
 s=act(s,"release_pair");s=act(s,"end_turn")
 check(s.trigger==("quick_switch" if crumpled else "curtain"),"mechanically distinct air strategy "+str(crumpled))
 s=act(s,"attack");s=act(s,"attack")
 check(s.phase=="vacuum" and s.medium=="vacuum" and s.shield,"phase transition preserves counterexample")
 s=act(s,"end_turn")
 s=act(s,"release_pair");s=act(s,"end_turn")
 check(s.shield,"old air timing strategy fails in vacuum")
 s=act(s,"raise","paper");s=act(s,"release_pair");s=act(s,"end_turn")
 check(not s.shield and s.trigger=="vacuum_height","legal vacuum height reaches device window")
 s=act(s,"attack");s=act(s,"attack")
 check(s.outcome=="won","complete bellows path "+str(crumpled))
 return s
func run_cases() -> void:
 suite="v03-combat"
 var s: Dictionary=Combat.initial("hammer")
 var before: String=canonical(s)
 for _i: int in range(100):
  var preview: Dictionary=Combat.apply(s,"raise","right",ALL)
  check(preview.ok,"preview valid")
 check(canonical(s)==before,"100 previews cannot consume AP, revision, history or random state")
 reject(s,"crumple","left");reject(s,"raise","missing");reject(s,"raise","right",[])
 reject(s,"pump","left");reject(s,"unknown","")
 var hit: Dictionary=act(s,"attack")
 check(hit.enemy_hp==s.enemy_hp and hit.ap==s.ap-1,"legal ineffective attack spends AP but no false damage")
 var low_ap: Dictionary=s.duplicate(true);low_ap.ap=0
 reject(low_ap,"raise","right")
 var bare: Dictionary=act(s,"end_turn")
 var guarded: Dictionary=act(act(s,"defend"),"end_turn")
 check(guarded.hp-bare.hp==3,"defend decreases actual damage by three")
 var moved: Dictionary=act(act(s,"move_left"),"end_turn")
 check(moved.hp==s.hp,"correct lane movement avoids intent")
 reject(moved,"move_left")
 var raised: Dictionary=solve_hammer(false)
 var lowered: Dictionary=solve_hammer(true)
 check(raised.objects.left.height!=lowered.objects.left.height and raised.hp!=lowered.hp,"hammer solutions differ in physical state and damage")
 solve_bellows(false);solve_bellows(true)
 var fixed: Dictionary=Combat.initial("bellows")
 fixed=act(fixed,"fix","paper")
 reject(fixed,"release_pair")
 fixed.ap=0 # Explicit low-AP unit fixture, not user-input validation.
 fixed=act(fixed,"unfix","paper",[])
 check(not fixed.objects.paper.fixed and fixed.ap==0,"free unfix prevents clamp soft lock")
 fixed=act(fixed,"end_turn");fixed=act(fixed,"release_pair");fixed=act(fixed,"end_turn")
 check(not fixed.shield,"unfixed apparatus usable again")
 var no_power: Dictionary=Combat.initial("bellows");no_power.powered=false
 reject(no_power,"pump")
 var leaking: Dictionary=Combat.initial("bellows");leaking.sealed=false
 reject(leaking,"pump")
 var identity: Dictionary=Combat.initial("bellows")
 var mass: float=identity.objects.paper.mass
 identity=act(identity,"crumple","paper")
 check(identity.objects.paper.mass==mass and identity.objects.paper.id=="paper","combat shape preserves specimen mass and ID")
 identity=act(identity,"unfold","paper")
 check(identity.objects.paper.mass==mass and identity.objects.paper.shape=="flat","unfold restores same paper")
 var patrol: Dictionary=Combat.initial("patrol")
 patrol=act(patrol,"attack");patrol=act(patrol,"attack");patrol=act(patrol,"end_turn");patrol=act(patrol,"attack")
 check(patrol.outcome=="won","ordinary fight completes through actions and enemy intent")
 reject(patrol,"attack")
 # Strong interface invariants: targets are meaningful, never silently ignored.
 reject(Combat.initial("hammer"),"attack","nonexistent")
 reject(Combat.initial("bellows"),"pump","nonexistent")
