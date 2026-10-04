extends "res://tests/v03_session.gd"
var explored: int=0
var rejected: int=0
func options(id: String,tail: bool=false) -> Array:
 var result: Array=[["attack",""],["end_turn",""],["release_pair",""],["defend",""],["move_left",""],["move_right",""]]
 if id=="hammer":result.append_array([["raise","left"],["raise","right"]])
 else:result.append_array([["raise","paper"],["crumple","paper"],["unfold","paper"]])
 return result
func battle_key(state: Dictionary) -> String:
 var b: Dictionary=state.battle.duplicate(true)
 for key: String in ["log","revision","traces","device_tick"]:b.erase(key)
 return canonical(b)
func search(initial: Dictionary,id: String,opening: bool) -> Dictionary:
 var queue: Array=[{"state":initial,"path":[]}]
 var cursor: int=0
 var seen: Dictionary={battle_key(initial):true}
 var found: Dictionary={}
 while cursor<queue.size() and cursor<6000:
  var entry: Dictionary=queue[cursor];cursor+=1;explored+=1
  if entry.path.size()> (5 if opening else 9):continue
  for move: Array in options(id):
   # Branch fixture copies an already reached state; transitions exclusively use Session.command.
   var session: RefCounted=preload("res://core/v03/game_session.gd").new()
   session.state=entry.state.duplicate(true)
   var result: Dictionary=session.command("end_turn" if move[0]=="end_turn" else "combat_action","" if move[0]=="end_turn" else move[0],{"target":move[1]})
   if not result.ok:rejected+=1;continue
   var path: Array=entry.path.duplicate();path.append(move)
   var b: Dictionary=session.state.battle
   if b.outcome=="lost":continue
   if not opening and b.outcome=="won":return {"win":{"state":session.snapshot(),"path":path}}
   if opening and not b.shield:
    var mechanism: String=str(b.objects.left.height) if id=="hammer" else b.trigger
    if not found.has(mechanism):found[mechanism]={"state":session.snapshot(),"path":path}
    if found.size()>=2:return found
    continue
   if b.round>5:continue
   var key: String=battle_key(session.state)
   if seen.has(key):continue
   seen[key]=true;queue.append({"state":session.snapshot(),"path":path})
 return found
func run_cases() -> void:
 suite="v03-enumeration"
 for id: String in ["hammer","bellows"]:
  var session: Variant=session_battle(id)
  var paths: Dictionary=search(session.snapshot(),id,true)
  check(paths.size()>=2,id+" enumeration discovers two physical openings")
  for mechanism: String in paths:
   var victory: Dictionary=search(paths[mechanism].state,id,false)
   check(victory.has("win"),id+" enumerated opening reaches formal victory "+mechanism)
   if victory.has("win"):
    check(victory.win.state.flags[id],"formal session victory awards "+id)
    notes.append(JSON.stringify({"encounter":id,"mechanism":mechanism,"opening":paths[mechanism].path,"continuation":victory.win.path}))
 notes.append("Bounded breadth-first state enumeration: explored="+str(explored)+", rejected command edges="+str(rejected)+", each search <=6000 states, depth <=6 opening / <=10 continuation, round<=5. Not an exhaustive unbounded proof.")

