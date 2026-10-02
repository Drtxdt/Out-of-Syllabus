class_name GameUI
extends Control
@onready var header: Label = $Header/Margin/Column/Location
@onready var objective: Label = $Footer/Margin/Column/Objective
@onready var prompt: Label = $Footer/Margin/Column/Prompt
@onready var toolbar: HBoxContainer = $Header/Margin/Column/Toolbar
@onready var shade: ColorRect = $Shade
@onready var panel: PanelContainer = $Modal
@onready var body: VBoxContainer = $Modal/Margin/Scroll/Body
@onready var toast_label: Label = $Toast
var toast_time: float = 0.0
const INK: Color = Color("d8e2dd")
const GOLD: Color = Color("e1bc78")
func _ready() -> void:
 var theme_resource: Theme = Theme.new();theme_resource.default_font_size = 19
 if ResourceLoader.exists("res://assets/fonts/NotoSansCJKsc-Regular.otf"):
  theme_resource.default_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf") as FontFile
 else:
  var fallback: SystemFont = SystemFont.new();fallback.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"]);theme_resource.default_font = fallback
 theme_resource.set_color("font_color","Label",INK)
 theme_resource.set_color("default_color","RichTextLabel",INK)
 for style_name: String in ["normal","hover","pressed","focus","disabled"]:
  var style: StyleBoxFlat = StyleBoxFlat.new()
  style.bg_color = Color("284247") if style_name in ["hover","pressed"] else Color("172930")
  style.border_color = GOLD if style_name == "focus" else Color("426069")
  style.set_border_width_all(2 if style_name == "focus" else 1)
  style.content_margin_left = 16;style.content_margin_right = 16;style.content_margin_top = 10;style.content_margin_bottom = 10
  theme_resource.set_stylebox(style_name,"Button",style)
 var box: StyleBoxFlat = StyleBoxFlat.new();box.bg_color = Color("111e28");box.border_color = Color("537879");box.set_border_width_all(1)
 theme_resource.set_stylebox("panel","PanelContainer",box)
 theme = theme_resource
 close()
func _process(delta: float) -> void:
 toast_time = maxf(0,toast_time-delta);toast_label.visible = toast_time>0
func toast(message: String) -> void:
 toast_label.text = message;toast_time = 4.5
func clear_body() -> void:
 for child: Node in body.get_children():
  body.remove_child(child);child.queue_free()
func open(title: String, subtitle: String = "") -> void:
 clear_body();shade.show();panel.show()
 var heading: Label = label(title,30);heading.add_theme_color_override("font_color",GOLD)
 if not subtitle.is_empty(): label(subtitle,18)
 var line: HSeparator = HSeparator.new();body.add_child(line)
func close() -> void:
 shade.hide();panel.hide()
func label(text: String, size: int = 19, parent: Node = null) -> Label:
 var node: Label = Label.new();node.text = text;node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;node.add_theme_font_size_override("font_size",size)
 (body if parent == null else parent).add_child(node)
 return node
func button(text: String, callback: Callable, parent: Node = null) -> Button:
 var node: Button = Button.new();node.text = text;node.pressed.connect(callback)
 (body if parent == null else parent).add_child(node)
 return node
func row() -> HBoxContainer:
 var node: HBoxContainer = HBoxContainer.new();node.add_theme_constant_override("separation",10);body.add_child(node);return node
func focus_first() -> void:
 var candidates: Array[Node] = body.find_children("*","Button",true,false)
 if not candidates.is_empty(): (candidates[0] as Button).grab_focus()
