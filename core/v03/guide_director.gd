extends RefCounted
static var _definitions: Dictionary={}

static func goal_id(s: Dictionary) -> String:
 if s.completed: return "complete"
 if s.mode=="caught": return "retry"
 if s.mode=="combat": return "combat_"+str(s.battle.id)
 if not s.flags.paper_door: return "paper"
 if not s.flags.patrol: return "patrol"
 if not s.flags.rig_demo: return "rig"
 if not s.flags.hammer: return "hammer"
 if s.cycle<3 and not s.attempt.is_empty() and s.attempt.phase=="success": return "seal"
 if s.cycle==1: return "record_a"
 if s.cycle==2: return "kit" if not s.flags.seal_kit else "record_b"
 if not s.flags.joint: return "joint"
 if not s.flags.bellows: return "bellows"
 if s.finale.phase in ["warning","chase"]: return "chase"
 if s.finale.phase=="escaped": return "submit"
 if s.finale.phase=="ready": return "calibrate" if s.finale.choice=="refuse" and not s.flags.safe_checked else "gate"
 return "archive"

static func definition(id: String) -> Resource:
 if not _definitions.has(id): _definitions[id]=load("res://content/v03/goals/%s.tres" % id)
 return _definitions[id]

static func objective(s: Dictionary) -> String:
 return str(definition(goal_id(s)).short_text)

static func hint(s: Dictionary) -> String:
 var tips: PackedStringArray=definition(goal_id(s)).hint_sequence
 return tips[clampi(int(s.guide.hint_level),0,tips.size()-1)]

static func update(s: Dictionary, progress: bool=false, elapsed: bool=false) -> void:
 var id: String=goal_id(s)
 if s.guide.goal_id!=id or progress:
  s.guide={"goal_id":id,"idle_ticks":0,"hint_level":0};return
 if not elapsed: return
 if s.mode!="world" or s.opening.phase=="falling" or (not s.attempt.is_empty() and s.attempt.phase in ["countdown","recording"]): return
 s.guide.idle_ticks+=1
 s.guide.hint_level=maxi(int(s.guide.hint_level),mini(2,int(s.guide.idle_ticks)/1800))
