extends VBoxContainer
const UI=preload("res://ui/v03/controls.gd")
signal command_requested(kind: String,target: String,payload: Dictionary)
var preview: Callable
var battle: Dictionary={}
var owned: Array=[]
var selected_action: String=""
var selected_target: String=""
var preview_result: Dictionary={}
var revision: int=-1
var _focus_name: String=""
var stats: Label
var intent: Label
var lane_row: HBoxContainer
var board: Control
var cards: GridContainer
var targets: HBoxContainer
var explanation: Label
var confirm: Button
var cancel: Button
var end_turn: Button
var log_label: Label
var playback: float=1.0

func _ready() -> void:
 add_theme_constant_override("separation",5)
 stats=UI.label(self,"",20);stats.name="CombatStats"
 intent=UI.label(self,"",17);intent.name="EnemyIntent"
 lane_row=UI.row(self);lane_row.name="Lanes"
 board=Control.new();board.set_script(preload("res://ui/v03/trajectory.gd"));board.custom_minimum_size.y=88;add_child(board)
 targets=UI.row(self);targets.name="Targets"
 cards=GridContainer.new();cards.columns=4;cards.add_theme_constant_override("h_separation",5);cards.add_theme_constant_override("v_separation",5);cards.name="Actions";add_child(cards)
 explanation=UI.label(self,"选择动作，再选择目标；预览不会消耗行动。",16);explanation.custom_minimum_size.y=44;explanation.name="Preview"
 var row: HBoxContainer=UI.row(self)
 confirm=UI.button(row,"ConfirmAction","确认动作",_confirm,false)
 cancel=UI.button(row,"CancelAction","取消选择",cancel_selection)
 end_turn=UI.button(row,"EndTurn","结束回合 / 执行释放",func() -> void: command_requested.emit("end_turn","",{}))
 UI.button(row,"Retreat","撤退",func() -> void: command_requested.emit("retreat","",{}))
 log_label=UI.label(self,"",15);log_label.name="CombatLog"

func render(value: Dictionary,actions: Array) -> void:
 if not is_node_ready(): await ready
 var focus: Control=get_viewport().gui_get_focus_owner()
 _focus_name=str(focus.name) if focus!=null and is_ancestor_of(focus) else ""
 battle=value.duplicate(true);owned=actions.duplicate()
 if int(battle.get("revision",0))!=revision:
  revision=int(battle.get("revision",0));selected_action="";selected_target="";preview_result={}
 stats.text="%s  · 第 %s 回合 · AP %s/2 · 你 %s HP · 敌方 %s HP" % [{"patrol":"巡逻纸偶","hammer":"双锤看守","bellows":"风箱纸偶"}.get(str(battle.get("id","")),"交锋"),battle.get("round",1),battle.get("ap",2),battle.get("hp",0),battle.get("enemy_hp",0)]
 var next: Dictionary=battle.get("intent",{})
 intent.text="敌方意图：%s · 通道 %s · 伤害 %s  |  %s · 护盾 %s" % [next.get("title","等待"),int(next.get("lane",1))+1,next.get("damage",0),"真空舱" if battle.get("medium","air")=="vacuum" else "空气",battle.get("shield",false)]
 _clear(lane_row)
 for index: int in range(3):
  var label: Label=UI.label(lane_row,("◆ 你" if int(battle.get("lane",1))==index else "◇")+"  通道 %s"%(index+1)+( "  ⚠" if int(next.get("lane",-1))==index else ""),16)
  label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if not battle.get("traces",[]).is_empty() and int(battle.get("revision",0))!=revision:playback=0.0
 board.render(battle,playback)
 var logs: Array=battle.get("log",[])
 log_label.text=str(logs.back()) if not logs.is_empty() else "通过实际操作改变物体与机关。"
 _render_actions();_render_targets();_render_preview()
 if not _focus_name.is_empty():
  var previous: Node=find_child(_focus_name,true,false)
  if previous is Button and not previous.disabled: previous.call_deferred("grab_focus")

func _clear(parent: Node) -> void:
 for child: Node in parent.get_children():parent.remove_child(child);child.queue_free()

func _render_actions() -> void:
 _clear(cards)
 var actions: Array=["attack","defend","move_left","move_right"]
 for value: Variant in owned:
  if str(value) in ["crumple","unfold","raise","release_pair","fix","pump","future"] and not value in actions:actions.append(value)
 if "fix" in owned:actions.append("unfix")
 for value: Variant in actions:
  var action: String=str(value)
  var possible: bool=false
  var reason: String="没有合法目标"
  for target: String in _target_ids():
   var outcome: Dictionary=_preview(action,target)
   if bool(outcome.get("ok",false)):possible=true;break
   reason=str(outcome.get("message",reason))
  var cost: int=0 if action=="unfix" else (2 if action in ["pump","future"] else 1)
  var label: String=("● " if selected_action==action else "")+UI.action_name(action)+" · %s AP"%cost
  var button: Button=UI.button(cards,"Action_"+action,label,func() -> void:_select_action(action),possible)
  button.tooltip_text=reason if not possible else "选择后查看目标与预览"
  if not possible:button.text+=" · 不可用"

func _target_ids() -> Array[String]:
 var ids: Array[String]=[""]
 for id: String in battle.get("objects",{}):ids.append(id)
 return ids

func _process(delta: float) -> void:
 if playback<1.0:
  playback=minf(1.0,playback+delta/1.2)
  if board!=null:board.render(battle,playback)

func _select_action(action: String) -> void:
 selected_action=action;selected_target="";preview_result={}
 _render_actions();_render_targets();_render_preview()
 UI.focus_first(targets)

func _render_targets() -> void:
 _clear(targets)
 if selected_action.is_empty():
  UI.label(targets,"目标：先选择动作",16);return
 var valid: Array[String]=[]
 for id: String in _target_ids():
  var result: Dictionary=_preview(selected_action,id)
  if bool(result.get("ok",false)):valid.append(id)
 # Core may accept blank/default aliases. Show one default and actual objects.
 for id: String in valid:
  if id in ["player","enemy","pair","chamber"] and "" in valid:continue
  var object: Dictionary=battle.get("objects",{}).get(id,{})
  var name: String=str(object.get("title",{"":"默认目标","player":"自己","enemy":"敌方","pair":"双夹具","chamber":"玻璃舱"}.get(id,id)))
  UI.button(targets,"Target_"+("default" if id.is_empty() else id),("● " if selected_target==id and not preview_result.is_empty() else "")+name,func() -> void:_select_target(id))
 if valid.is_empty():UI.label(targets,"没有合法目标；取消或结束回合。",16)

func _select_target(id: String) -> void:
 selected_target=id;preview_result=_preview(selected_action,id)
 _render_targets();_render_preview()
 if not confirm.disabled:confirm.grab_focus()

func _preview(action: String,target: String) -> Dictionary:
 if not preview.is_valid():return {"ok":false,"message":"核心预览尚未连接"}
 return preview.call(action,target)

func _render_preview() -> void:
 confirm.disabled=preview_result.is_empty() or not bool(preview_result.get("ok",false))
 if preview_result.is_empty():explanation.text="选择动作，再选择目标；预览不会消耗行动。"
 else:
  explanation.text=UI.action_name(selected_action)+" → "+str(preview_result.get("message","确认后执行"))
  if not bool(preview_result.get("can_predict",false)):explanation.text+="\n尚不足以可靠预测到达时刻；请观察实际结果。"

func _confirm() -> void:
 if confirm.disabled:return
 command_requested.emit("combat_action",selected_action,{"target":selected_target,"revision":preview_result.get("revision",revision)})

func cancel_selection() -> void:
 selected_action="";selected_target="";preview_result={}
 _render_actions();_render_targets();_render_preview();UI.focus_first(cards)
