extends PanelContainer
const UI=preload("res://ui/v03/controls.gd")
var plot: Control
var summary: Label
func _ready() -> void:
 name="JointReadout"
 custom_minimum_size=Vector2(336,112)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var row: HBoxContainer=UI.row(self)
 plot=Control.new();plot.set_script(preload("res://ui/v03/trajectory.gd"));plot.custom_minimum_size=Vector2(88,76);row.add_child(plot)
 var column: VBoxContainer=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column)
 UI.label(column,"联合真空测量",18)
 summary=UI.label(column,"A / B 维持 · C 释放中",16)
func render(trace: Dictionary,progress: float,succeeded: bool) -> void:
 plot.render({"trace":trace,"shape":"flat","show_labels":false},progress)
 summary.text="实测 %.3f 秒\nA / B / C 合作完成"%float(trace.get("arrival_s",0)) if succeeded else "A / B 正在维持\nC 释放中"
