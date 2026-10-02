class_name ModelBattle
extends RefCounted
var definition: EncounterDef
var state: Dictionary = {}
var records: Array = []
func _init(def: EncounterDef = null, available: Array = []) -> void:
 records = available.duplicate(true)
 definition = def
 if def != null:
  state = {"id": def.id, "round": 1, "actions": 2, "model": "none", "observed": false,
   "controlled": false, "repeated": false, "shape": false, "vacuum": false,
   "suspended": false, "cited_ids": [], "evidence": [], "resolved": [], "won": false, "failed": false, "last": "先观察现象，或选择一个待检验的模型。"}
func play(card: CardDef, evidence_ids: Array = []) -> Dictionary:
 if state.is_empty() or state.won or state.failed:
  return {"ok": false, "message": "本次论证已经结束。"}
 var merged: Array = state.cited_ids.duplicate()
 for id: Variant in evidence_ids:
  if not id is String: return {"ok":false,"message":"证据编号无效。"}
  if not id in merged: merged.append(id)
 var selected: Array = EvidenceEvaluator.records_for(records,merged)
 for id: Variant in merged:
  if not records.any(func(record: Dictionary) -> bool: return record.id==id and record.observed_by_player): return {"ok":false,"message":"只能引用已读取的真实实验记录。"}
 if card.effect in ["observe","experiment","controls","measurement","repeat","shape","vacuum","counterexample"] and selected.is_empty():
  return {"ok":false,"message":"先到实验台释放并读取记录，再选择证据。"}
 if card.effect=="repeat":
  var independent: bool=false
  for a: Dictionary in selected:
   for b: Dictionary in selected:
    if a.source_event_id!=b.source_event_id and a.setup==b.setup: independent=true
  if not independent: return {"ok":false,"message":"重复实验需要另一份相同条件、独立来源的记录。"}
 match card.effect:
  "observe": state.observed = true
  "experiment":
   if not state.observed:
    return {"ok": false, "message": "先观察，再设计实验。"}
   state.controlled = true
  "mass_model": state.model = "mass"
  "gravity_model": state.model = "gravity"
  "controls": state.controlled = true
  "measurement":
   if not state.controlled:
    return {"ok": false, "message": "需要先控制高度与初速度。"}
   if not "measured" in state.evidence: state.evidence.append("measured")
  "repeat":
   if not state.controlled:
    return {"ok": false, "message": "重复实验前，先统一实验条件。"}
   state.repeated = true
  "counterexample":
   if state.model == "mass": state.model = "none"
   state.observed = true
  "shape": state.shape = true
  "vacuum":
   if not state.controlled:
    return {"ok": false, "message": "真空对照仍需控制高度与初速度。"}
   state.vacuum = true
  "drag_revision":
   if state.model == "none":
    return {"ok": false, "message": "先建立一个模型，才能修正它。"}
   state.model = "drag"
  "domain":
   if state.model == "mass":
    return {"ok": false, "message": "限定条件不能挽救与证据冲突的质量假说。"}
   state.shape = true
  _:
   return {"ok": false, "message": "这张卡不适用于当前实验。"}
 state.cited_ids = merged
 state.actions -= 1
 state.last = "使用「%s」。%s" % [card.title, evaluate()]
 if not state.won and int(state.actions) == 0:
  state.round += 1
  state.actions = 2
  if int(state.round) > definition.max_rounds:
   state.failed = true
   state.last += "
本次实验预算用尽。可重试，已获得的提示保留。"
  else:
   state.last += "
反例：" + definition.counterexamples[(int(state.round)-2) % definition.counterexamples.size()]
 return {"ok": true, "message": state.last}
func conditions() -> Array:
 return EvidenceEvaluator.evaluate(state,records,definition.requirements)
func evaluate() -> String:
 var resolved: Array=[]
 for condition: Dictionary in conditions():
  if condition.status=="satisfied": resolved.append(condition.id)
 state.resolved=resolved
 state.won=resolved.size()==definition.requirements.size()
 return "全部必需证据已解释。" if state.won else "还有未解释的实测记录，检查条件与证据来源。"
func progress() -> int:
 var n: int = 0
 for id: String in definition.requirements:
  if id in state.resolved: n += 1
 return int(100.0 * n / definition.requirements.size())
func hint(level: int) -> String:
 var tips: Array[String] = ["模型描述的是哪些条件？先观察，并统一实验的高度和初速度。", "同形状不同质量近似同时落地；纸片形状变化会改变空气阻力。", "用重力模型配合测量或重复实验。存在空气差异时，加入阻力修正、形状比较和真空对照。"]
 return tips[clampi(level,0,2)]
