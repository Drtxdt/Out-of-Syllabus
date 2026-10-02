class_name EvidenceEvaluator
extends RefCounted

static func records_for(records: Array, ids: Array) -> Array:
 var result: Array = []
 var sources: Array = []
 for record: Dictionary in records:
  if record.id in ids and record.observed_by_player and not record.source_event_id in sources:
   result.append(record);sources.append(record.source_event_id)
 return result

static func evaluate(state: Dictionary, records: Array, requirements: PackedStringArray) -> Array:
 var used: Array = records_for(records,state.get("cited_ids",[]))
 var mass: bool = false
 var shape: bool = false
 var air: bool = false
 var vacuum: bool = false
 for record: Dictionary in used:
  var setup: Dictionary = record.setup
  var observed: Dictionary = record.observations
  if setup.experiment=="mass" and observed.comparison=="within_tolerance": mass=true
  if setup.experiment=="shape" and setup.medium=="air" and observed.comparison=="different": shape=true
  if setup.experiment=="initial" and setup.shape=="flat":
   if setup.medium=="air" and observed.comparison=="different": air=true
   if setup.medium=="vacuum" and observed.comparison=="within_tolerance": vacuum=true
 var repeated: bool = false
 for a: Dictionary in used:
  for b: Dictionary in used:
   if a.source_event_id!=b.source_event_id and a.setup==b.setup and a.observations.comparison==b.observations.comparison: repeated=true
 var proof: bool = ("measured" in state.evidence) or (state.repeated and repeated)
 var flags: Dictionary = {"observation":state.observed and not used.is_empty(),"controls":state.controlled and not used.is_empty(),"evidence":proof and state.controlled,"mass_independence":mass and state.model in ["gravity","drag"],"air_difference":air and shape and state.shape and state.model=="drag","vacuum_control":air and vacuum and state.vacuum and state.controlled}
 var reasons: Dictionary = {"observation":"读取并引用一份实测记录。","controls":"引用记录并核对高度与初速度。","evidence":"引用测量；重复路径需两次独立、相同条件的记录。","mass_independence":"需要同形不同质量的实测记录与重力模型（给定条件及容差）。","air_difference":"需要空气中球/纸与同纸形状对照，并加入阻力修正。","vacuum_control":"需要同一释放条件下的空气和真空实测，真空不能抹去空气记录。"}
 var result: Array = []
 for id: String in requirements:
  var status: String = "satisfied" if flags.get(id,false) else "unsupported"
  if state.model=="mass" and mass and id=="mass_independence": status="contradicted"
  result.append({"id":id,"status":status,"reason":"证据支持。" if status=="satisfied" else reasons[id]})
 return result
