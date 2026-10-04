extends "res://tests/v03_test_base.gd"
func run_cases() -> void:
 suite="v03-content"
 var chapter: Resource=load("res://content/v03/chapter.tres")
 check(chapter!=null and chapter.content_version==3 and chapter.id=="fall_v03","versioned chapter manifest")
 var rooms: Dictionary={};var objects: Dictionary={}
 for room: Dictionary in chapter.rooms:
  check(not rooms.has(room.id),"unique room "+room.id);rooms[room.id]=room
  for object: Dictionary in room.objects:
   check(not objects.has(object.id),"unique object "+object.id);objects[object.id]=object
   check(not str(object.title).is_empty(),"object title "+object.id)
   check(object.x>=40 and object.x<=600 and object.y>=56 and object.y<=306,"reachable object bounds "+object.id)
 check(rooms.size()==6,"six chapter regions")
 for object: Dictionary in objects.values():
  if object.kind=="exit":check(rooms.has(object.target),"exit target exists "+object.id)
 for file: String in DirAccess.get_files_at("res://content/v03/goals"):
  if not file.ends_with(".tres"):continue
  var goal: Resource=load("res://content/v03/goals/"+file)
  check(goal.id==file.trim_suffix(".tres"),"stable goal filename ID "+file)
  check(not goal.short_text.is_empty() and goal.hint_sequence.size()>=3,"goal has progressive hints "+goal.id)
  for target: String in goal.target_ids:check(objects.has(target),"goal target exists "+goal.id+" / "+target)
 for id: String in ["crumple","unfold","raise","release_pair","fix","pump","future"]:
  var action: Resource=load("res://content/v03/"+id+".tres")
  check(action.id==id,"stable action ID "+id)
  check(action.cost>=0 and action.cost<=2,"AP budget supports action "+id)
  check(not action.title.is_empty() and not action.description.is_empty(),"action display complete "+id)
 for id: String in ["patrol","hammer","bellows"]:
  var encounter: Resource=load("res://content/v03/encounters/"+id+".tres")
  check(encounter.id==id and objects.has(id),"encounter links world object "+id)
  check(encounter.enemy_hp>0 and encounter.enemy_hp<=30,"bounded enemy health "+id)
  var battle: Dictionary=preload("res://core/v03/combat_session.gd").initial(id)
  check(battle.enemy_hp==encounter.enemy_hp and battle.shield==encounter.shielded,"encounter resource actually drives battle "+id)
 var reachable: Array=["classroom"]
 for _iteration: int in range(6):
  for room_id: String in reachable.duplicate():
   for object: Dictionary in rooms[room_id].objects:
    if object.kind=="exit" and object.target not in reachable:reachable.append(object.target)
 check(reachable.size()==6,"directed exit graph reaches every region")
