extends "res://ui/evidence_view_base.gd"
var selected_ids: Array[String] = []
var _data: Dictionary = {}

func render(data: Dictionary) -> void:
 _data = data.duplicate(true)
 begin_render()
 var state: Dictionary = data.get("state", {})
 line(str(data.get("title", "论证桌")), true)
 line(str(data.get("question", "哪些实测证据支持你的模型？")))
 line("第 %s 回合 · 剩余行动 %s · %s\n%s" % [state.get("round", 1), state.get("actions", 2), display_name(str(state.get("model", "none"))), state.get("last", "")])
 line("条件核验", true)
 var conditions_grid: GridContainer = GridContainer.new()
 conditions_grid.name = "Conditions"
 conditions_grid.columns = 2
 conditions_grid.add_theme_constant_override("h_separation", 14)
 conditions_grid.add_theme_constant_override("v_separation", 4)
 add_child(conditions_grid)
 for value: Variant in data.get("conditions", []):
  var condition: Dictionary = value
  var status: String = str(condition.get("status", "unsupported"))
  var labels: Dictionary = {"satisfied":"满足", "unsupported":"缺证据", "contradicted":"矛盾"}
  var text: Label = Label.new()
  text.text = "[%s] %s：%s" % [labels.get(status, status), display_name(str(condition.get("id", ""))), condition.get("reason", "")]
  text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  text.add_theme_font_size_override("font_size", 17)
  conditions_grid.add_child(text)
  text.add_theme_color_override("font_color", Color("d88775") if status == "contradicted" else Color("92c6bb") if status == "satisfied" else Color("e1bc78"))
 line("选择本次引用的实测记录", true)
 var available: Array[String] = []
 for value: Variant in data.get("records", []):
  var record: Dictionary = value
  if not bool(record.get("observed_by_player", false)): continue
  var id: String = str(record.get("id", ""))
  available.append(id)
  var check: CheckBox = CheckBox.new()
  check.name = ("Evidence_" + id).validate_node_name()
  check.set_meta("semantic_key", "Evidence_" + id)
  check.text = record_text(record).replace("\n来源", " · 来源").replace(" · 已读取", "")
  check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  check.button_pressed = id in selected_ids
  check.toggled.connect(func(pressed: bool) -> void:
   if pressed and not id in selected_ids: selected_ids.append(id)
   elif not pressed: selected_ids.erase(id)
   render(_data))
  add_child(check)
 selected_ids.assign(selected_ids.filter(func(id: String) -> bool: return id in available))
 if available.is_empty(): line("没有已读取的记录。返回实验室测量并读取仪器。")
 line("已选 %s 份记录；同一来源不能充当独立重复实验。" % selected_ids.size())
 var cards_grid: GridContainer = GridContainer.new()
 cards_grid.name = "Cards"
 cards_grid.columns = 2
 cards_grid.add_theme_constant_override("h_separation", 10)
 cards_grid.add_theme_constant_override("v_separation", 10)
 add_child(cards_grid)
 for value: Variant in data.get("cards", []):
  var card: Dictionary = value
  var id: String = str(card.get("id", ""))
  var enabled: bool = bool(card.get("enabled", true)) and not bool(state.get("won", false)) and not bool(state.get("failed", false))
  var action: Button = button("Card_" + id, str(card.get("title", id)) + "\n" + str(card.get("description", "")), "play_card", id, {"evidence_ids":selected_ids.duplicate()}, enabled)
  remove_child(action)
  cards_grid.add_child(action)
  action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  action.add_theme_font_size_override("font_size", 17)
  action.tooltip_text = str(card.get("reason", ""))
  if not str(card.get("reason", "")).is_empty(): action.text += "\n" + str(card.reason)
 if bool(state.get("won", false)): button("FinishBattle", "提交论证", "finish_battle")
 if bool(state.get("failed", false)): button("RetryBattle", "重新论证", "start_battle", str(state.get("id", "")))
 button("CloseBattle", "暂存论证并返回", "close")
 end_render()
