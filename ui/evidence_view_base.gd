extends VBoxContainer
## Pure presentation helper. Rebuilds preserve semantic focus and parent scrolling.
signal action_requested(kind: String, target: String, payload: Dictionary)
var _focus_key: String = ""
var _scroll: ScrollContainer
var _scroll_y: int = 0
var _revision: int = 0

func begin_render() -> void:
 _revision += 1
 if is_inside_tree():
  var focused: Control = get_viewport().gui_get_focus_owner()
  _focus_key = str(focused.get_meta("semantic_key", "")) if focused != null and is_ancestor_of(focused) else ""
  var ancestor: Node = get_parent()
  while ancestor != null:
   if ancestor is ScrollContainer:
    _scroll = ancestor as ScrollContainer
    _scroll_y = _scroll.scroll_vertical
    break
   ancestor = ancestor.get_parent()
 for child: Node in get_children():
  remove_child(child)
  child.queue_free()
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation", 10)

func end_render() -> void:
 _restore.call_deferred(_revision)

func _restore(revision: int) -> void:
 if revision != _revision or not is_inside_tree(): return
 if not _focus_key.is_empty():
  for node: Node in find_children("*", "Button", true, false):
   var button: Button = node as Button
   if str(button.get_meta("semantic_key", "")) == _focus_key and not button.disabled:
    button.grab_focus()
    break
 if is_instance_valid(_scroll): _scroll.set_deferred("scroll_vertical", _scroll_y)

func line(text: String, heading: bool = false) -> Label:
 var label: Label = Label.new()
 label.text = text
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", 23 if heading else 18)
 if heading: label.add_theme_color_override("font_color", Color("e1bc78"))
 add_child(label)
 return label

func button(key: String, text: String, kind: String, target: String = "", payload: Dictionary = {}, enabled: bool = true) -> Button:
 var result: Button = Button.new()
 result.name = key.validate_node_name()
 result.set_meta("semantic_key", key)
 result.text = text
 result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 result.custom_minimum_size.y = 44
 result.disabled = not enabled
 result.pressed.connect(func() -> void: action_requested.emit(kind, target, payload.duplicate(true)))
 add_child(result)
 return result

func record_text(record: Dictionary) -> String:
 var setup: Dictionary = record.get("setup", {})
 var observations: Dictionary = record.get("observations", {})
 var experiment: String = str(setup.get("experiment", record.get("experiment_id", "")))
 var labels: Dictionary = {"initial":"球与纸片", "mass":"同形不同质量", "shape":"同纸不同形状", "air":"空气", "vacuum":"真空", "flat":"平展", "crumpled":"揉团"}
 return "%s · 第 %s 轮 · %s / %s\n实测 %s 秒；容差 ±%s 秒\n来源 %s · %s" % [record.get("id", ""), record.get("cycle", record.get("source_cycle", 1)), labels.get(experiment, experiment), labels.get(str(setup.get("medium", "")), "未标明介质"), observations.get("arrival_times_s", {}), observations.get("tolerance_s", 0.01), record.get("source_event_id", "未知"), "已读取" if bool(record.get("observed_by_player", false)) else "仪器待读取"]

func display_name(id: String) -> String:
 var names: Dictionary = {
  "none":"未选择", "mass":"质量假说", "gravity":"重力模型", "drag":"阻力模型",
  "observation":"现象观察", "controls":"控制变量", "evidence":"实测论据", "mass_independence":"质量无关",
  "air_difference":"空气中的差异", "vacuum_control":"真空对照", "hold_begin":"开始维持", "hold_end":"结束维持",
  "assist_a":"A 稳压工位", "assist_b":"B 安全锁", "lab_drop":"C 释放记录", "rig_power":"实验供电",
  "player":"当前的你", "lab":"实验室", "air":"空气", "vacuum":"真空", "flat":"平展", "crumpled":"揉团"}
 if names.has(id): return str(names[id])
 if id.begins_with("echo_"): return "第 %s 轮回声" % id.trim_prefix("echo_")
 if id.begins_with("echo:"): return "第 %s 轮回声" % id.trim_prefix("echo:")
 return id

func display_action(action: String) -> String:
 var parts: PackedStringArray = action.split(" / ")
 for index: int in range(parts.size()): parts[index] = display_name(parts[index])
 return " · ".join(parts)
