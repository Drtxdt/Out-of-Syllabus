extends "res://ui/evidence_view_base.gd"
var experiment: String = "initial"
var medium: String = "air"
var shape: String = "flat"
var _data: Dictionary = {}

func render(data: Dictionary) -> void:
 _data = data.duplicate(true)
 begin_render()
 line("落体实验台", true)
 line("固定高度 2.00 米 · 初速度 0 · 测量容差 ±0.01 秒\n配置时暂停；释放后世界与回声继续运行。")
 var choices: Dictionary = data.get("choices", {})
 var pending: bool = not data.get("pending", {}).is_empty() if data.get("pending", {}) is Dictionary else bool(data.get("pending", false))
 _choice("Experiment", "对照", [{"id":"initial","title":"球与纸片"},{"id":"mass","title":"同形不同质量"},{"id":"shape","title":"同纸不同形状"}], str(choices.get("experiment", experiment)), pending)
 _choice("Medium", "介质", [{"id":"air","title":"空气"},{"id":"vacuum","title":"真空"}], str(choices.get("medium", medium)), pending)
 _choice("Shape", "纸片", [{"id":"flat","title":"平展"},{"id":"crumpled","title":"揉团"}], str(choices.get("shape", shape)), pending)
 line("第 %s 轮 · 真空泵：%s" % [data.get("cycle", 1), "已启动" if bool(data.get("pump", false)) else "未启动"])
 button("ReleaseExperiment", "测量进行中…" if pending else "释放并开始测量", "experiment", "lab_drop", {"experiment":experiment,"medium":medium,"shape":shape}, not pending)
 line("仪器记录", true)
 var records: Array = data.get("records", [])
 if records.is_empty(): line("暂无实测记录。先完成一次释放，再回来读取仪器。预测不会成为实测证据。")
 for value: Variant in records:
  var record: Dictionary = value
  line(record_text(record))
  if not bool(record.get("observed_by_player", false)):
   button("Read_" + str(record.id), "读取这次测量", "read_evidence", str(record.id))
 button("CloseExperiment", "返回实验室", "close")
 end_render()

func _choice(key: String, title: String, options: Array, selected: String, locked: bool) -> void:
 var row: HBoxContainer = HBoxContainer.new()
 row.name = key + "Choices"
 row.add_theme_constant_override("separation", 8)
 add_child(row)
 var caption: Label = Label.new()
 caption.text = title
 caption.custom_minimum_size.x = 48
 row.add_child(caption)
 match key:
  "Experiment": experiment = selected
  "Medium": medium = selected
  "Shape": shape = selected
 for value: Variant in options:
  var option: Dictionary = value
  var id: String = str(option.id)
  var pick: Button = Button.new()
  pick.name = key + "_" + id
  pick.set_meta("semantic_key", str(pick.name))
  pick.text = ("● " if selected == id else "○ ") + str(option.title)
  pick.custom_minimum_size.y = 40
  pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  pick.disabled = locked
  pick.pressed.connect(func() -> void:
   match key:
    "Experiment": experiment = id
    "Medium": medium = id
    "Shape": shape = id
   _data.erase("choices")
   render(_data))
  row.add_child(pick)
