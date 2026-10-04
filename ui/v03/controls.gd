extends RefCounted
const INK: Color = Color("d8e2dd")
const GOLD: Color = Color("e1bc78")

static func theme() -> Theme:
 var result: Theme = Theme.new()
 result.default_font_size = 18
 result.default_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
 result.set_color("font_color","Label",INK)
 for state: String in ["normal","hover","pressed","focus","disabled"]:
  var style: StyleBoxFlat = StyleBoxFlat.new()
  style.bg_color = Color("284247") if state in ["hover","pressed"] else Color("172930")
  style.border_color = GOLD if state == "focus" else Color("426069")
  style.set_border_width_all(2 if state == "focus" else 1)
  style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=5;style.content_margin_bottom=5
  result.set_stylebox(state,"Button",style)
 var panel: StyleBoxFlat = StyleBoxFlat.new()
 panel.bg_color = Color("111e28");panel.border_color=Color("537879");panel.set_border_width_all(1)
 panel.content_margin_left=14;panel.content_margin_right=14;panel.content_margin_top=10;panel.content_margin_bottom=10
 result.set_stylebox("panel","PanelContainer",panel)
 return result

static func label(parent: Node, text: String, font_size: int = 18) -> Label:
 var node: Label = Label.new()
 node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size",font_size)
 parent.add_child(node)
 return node

static func button(parent: Node, id: String, text: String, callback: Callable, enabled: bool = true) -> Button:
 var node: Button = Button.new()
 node.name=id;node.text=text;node.disabled=not enabled
 node.custom_minimum_size.y=34;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.pressed.connect(callback);parent.add_child(node)
 return node

static func row(parent: Node) -> HBoxContainer:
 var result: HBoxContainer=HBoxContainer.new()
 result.add_theme_constant_override("separation",8);parent.add_child(result)
 return result

static func focus_first(parent: Node) -> void:
 for child: Node in parent.find_children("*","Button",true,false):
  var button: Button=child as Button
  if button.is_visible_in_tree() and not button.disabled:
   button.grab_focus();return

static func action_name(id: String) -> String:
 var names: Dictionary={"crumple":"揉团","unfold":"展开","raise":"调高","release_pair":"齐放","fix":"固定","unfix":"松开","pump":"抽气","future":"借来的轨迹","attack":"攻击","defend":"防御","move_left":"向左移动","move_right":"向右移动"}
 return str(names.get(id,id))
