class_name ModelBattle
extends RefCounted
var definition: EncounterDef
var state: Dictionary = {}
func _init(def: EncounterDef = null) -> void:
 definition = def
 if def != null:
  state = {"id": def.id, "round": 1, "actions": 2, "model": "none", "observed": false,
   "controlled": false, "repeated": false, "shape": false, "vacuum": false,
   "evidence": [], "resolved": [], "won": false, "failed": false, "last": "先观察现象，或选择一个待检验的模型。"}
func play(card: CardDef) -> Dictionary:
 if state.is_empty() or state.won or state.failed:
  return {"ok": false, "message": "本次论证已经结束。"}
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
func evaluate() -> String:
 var resolved: Array = []
 var proof: bool = "measured" in state.evidence or bool(state.repeated)
 if state.observed: resolved.append("observation")
 if state.controlled: resolved.append("controls")
 if proof and state.controlled: resolved.append("evidence")
 if state.model in ["gravity", "drag"]: resolved.append("mass_independence")
 if definition.id == "drag":
  if state.model == "drag" and state.shape: resolved.append("air_difference")
  # Merely declaring vacuum cannot explain the observed in-air measurement.
  if state.vacuum and state.controlled and state.model in ["gravity", "drag"]: resolved.append("vacuum_control")
 state.resolved = resolved
 state.won = true
 for id: String in definition.requirements:
  if not id in resolved: state.won = false
 return "全部必需证据已解释。" if state.won else "还有未解释的观察，继续检查模型与条件。"
func progress() -> int:
 var n: int = 0
 for id: String in definition.requirements:
  if id in state.resolved: n += 1
 return int(100.0 * n / definition.requirements.size())
func hint(level: int) -> String:
 var tips: Array[String] = ["模型描述的是哪些条件？先观察，并统一实验的高度和初速度。", "同形状不同质量近似同时落地；纸片形状变化会改变空气阻力。", "用重力模型配合测量或重复实验。存在空气差异时，加入阻力修正、形状比较和真空对照。"]
 return tips[clampi(level,0,2)]
