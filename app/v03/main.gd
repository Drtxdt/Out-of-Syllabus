extends Control
const UI=preload("res://ui/v03/controls.gd")
const Settings=preload("res://app/v03/input_settings.gd")
const CombatView=preload("res://ui/v03/combat_view.gd")
@onready var world: Node2D=$WorldFrame/Viewport/World
@onready var player: CharacterBody2D=$WorldFrame/Viewport/World/Player
@onready var objects_view: Node2D=$WorldFrame/Viewport/World/Objects
var session: RefCounted
var saves: RefCounted
var settings: RefCounted
var room_node: Node2D
var room_id: String=""
var hud: VBoxContainer
var objective: Label
var prompt: Label
var echo_status: Label
var hint_status: Label
var toast_label: Label
var toast_remaining: float=0
var shade: ColorRect
var panel: PanelContainer
var modal_body: VBoxContainer
var modal: String=""
var combat: VBoxContainer
var paper_visual: Control
var paper_status: Label
var echoes: Array[Node2D]=[]
var examiner: Node2D
var rebind: String=""
var archive_model: String="drag"
var paper_observed_release: int=-1
var paper_result_frames: int=0
var joint_visual: Control
var joint_summary: Label
var joint_result_frames: int=0
var joint_observed_source: String=""
var rig_visual: Control
var rig_status: Label
var rig_playback: float=0.0
var rig_data: Dictionary={}
var _hud_key: String=""
var _battle_revision: int=-1
var _request_seq: int=0
var _last_mode: String=""
var _slow_frame: int=0
var suppress_intro: bool=false

func _ready() -> void:
 theme=UI.theme()
 _build_ui()
 var core: Script=load("res://core/v03/game_session.gd")
 var storage: Script=load("res://core/v03/save_store.gd")
 if core==null or storage==null:
  _open("error","v0.3 核心尚未连接");UI.label(modal_body,"缺少新版会话或保存模块。保留旧版记录，等待集成。");return
 session=core.new();saves=storage.new();settings=Settings.new()
 session.connect("notice",toast)
 _sync_world()
 if not suppress_intro:_welcome()

func state() -> Dictionary:
 return session.get("state") if session!=null else {}

func _build_ui() -> void:
 hud=VBoxContainer.new();hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);hud.offset_left=20;hud.offset_right=-20;hud.offset_top=12;hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hud)
 objective=UI.label(hud,"超纲 / OUT OF SYLLABUS",20);objective.name="Objective"
 hint_status=UI.label(hud,"",16);hint_status.name="HintStatus";hint_status.add_theme_color_override("font_color",UI.GOLD)
 echo_status=UI.label(hud,"",16);echo_status.name="EchoStatus"
 var footer: PanelContainer=PanelContainer.new();footer.name="Footer";footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.grow_vertical=Control.GROW_DIRECTION_BEGIN;add_child(footer)
 var foot: HBoxContainer=UI.row(footer)
 prompt=UI.label(foot,"",18);prompt.name="Nearby";prompt.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 UI.button(foot,"Hint","提示",func() -> void:_dispatch("request_hint")).size_flags_horizontal=Control.SIZE_SHRINK_END
 UI.button(foot,"Notebook","笔记",show_notebook).size_flags_horizontal=Control.SIZE_SHRINK_END
 UI.button(foot,"Menu","设置",show_settings).size_flags_horizontal=Control.SIZE_SHRINK_END
 toast_label=Label.new();toast_label.name="Toast";toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);toast_label.offset_top=76;toast_label.offset_left=50;toast_label.offset_right=-50;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.add_theme_color_override("font_color",UI.GOLD);add_child(toast_label)
 shade=ColorRect.new();shade.name="Shade";shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.02,0.035,0.05,0.93);add_child(shade);shade.hide()
 panel=PanelContainer.new();panel.name="Modal";panel.anchor_left=0.025;panel.anchor_top=0.035;panel.anchor_right=0.975;panel.anchor_bottom=0.965;add_child(panel);panel.hide()
 modal_body=VBoxContainer.new();modal_body.name="Body";modal_body.add_theme_constant_override("separation",6);panel.add_child(modal_body)

func _physics_process(_delta: float) -> void:
 if session==null:return
 var s: Dictionary=state()
 if modal.is_empty() or modal=="paper_live":
  if s.mode=="world":
   _slow_frame+=1
   if modal!="paper_live" or _slow_frame%3==0:session.call("advance",1)
   if modal.is_empty():
    var movement: Vector2=Input.get_vector("move_left","move_right","move_up","move_down")
    var direction: String=str(s.direction)
    if not movement.is_zero_approx():
     direction=("left" if movement.x<0 else "right") if absf(movement.x)>absf(movement.y) else ("up" if movement.y<0 else "down")
     player.velocity=movement*(235.0 if int(s.tick)<int(s.finale.get("dodge_until",0)) else 100.0)
     player.move_and_slide()
     session.call("command","move","player",{"x":player.position.x,"y":player.position.y,"direction":direction})
    player.set("moving",not movement.is_zero_approx())
   else:player.set("moving",false)
  _sync_world()
 if modal in ["paper","paper_live"]:_update_paper()
 if state().mode=="combat" and modal.is_empty():show_combat()
 elif state().mode=="caught" and modal!="caught":show_caught()
 elif bool(state().completed) and modal.is_empty():show_ending()

func _process(delta: float) -> void:
 toast_remaining=maxf(0,toast_remaining-delta)
 if toast_label!=null:toast_label.visible=toast_remaining>0
 if session!=null:_observe_visible_results()
 if modal=="rig" and rig_visual!=null:
  rig_playback=minf(1.0,rig_playback+delta/2.4)
  rig_visual.render(rig_data,rig_playback)
  if rig_playback>=1.0:
   var times: PackedStringArray=[]
   for trace: Dictionary in rig_data.get("traces",[]):times.append("%.3f 秒"%float(trace.get("arrival_s",0)))
   rig_status.text="实际到达："+" / ".join(times)+"\n同形、同高度、同初速度，只改变质量。调高与齐放已经成为可用动作。"

func _unhandled_input(event: InputEvent) -> void:
 if session==null or settings==null:return
 if not rebind.is_empty() and event is InputEventKey and event.pressed and not event.echo:
  settings.call("bind_key",rebind,event.physical_keycode);rebind="";show_settings();get_viewport().set_input_as_handled();return
 if event.is_action_pressed("pause"):
  if modal=="combat" and combat!=null and not combat.selected_action.is_empty():combat.cancel_selection()
  elif modal.is_empty():show_settings()
  else:close_modal()
  get_viewport().set_input_as_handled();return
 if not modal.is_empty():return
 if event.is_action_pressed("interact"):_interact()
 elif event.is_action_pressed("dodge"):_dispatch("dodge","player")
 elif event.is_action_pressed("journal"):show_notebook()
 elif event.is_action_pressed("hint"):_dispatch("request_hint")
 elif event.is_action_pressed("wait"):_dispatch("fast_forward")
 elif event.is_action_pressed("save"):save_game()
 elif event.is_action_pressed("load"):load_game()

func _sync_world() -> void:
 var s: Dictionary=state()
 if s.is_empty():return
 if room_id!=str(s.room):
  if is_instance_valid(room_node):world.remove_child(room_node);room_node.queue_free()
  room_id=str(s.room)
  var map: PackedScene=load("res://world/rooms/%s.tscn"%room_id)
  if map!=null:
   room_node=map.instantiate();world.add_child(room_node);world.move_child(room_node,0)
   var props: Node2D=room_node.get_node_or_null("Props")
   if props!=null:props.hide()
 player.position=Vector2(float(s.position[0]),float(s.position[1]));player.set("facing",str(s.direction))
 var near: Dictionary=session.call("nearby")
 var gate_open: bool=int(s.finale.get("open_tick",-1))>=0 and int(s.tick)>=int(s.finale.open_tick) and int(s.tick)<=int(s.finale.close_tick)
 objects_view.call("render",session.call("objects"),str(near.get("id","")),{"shape":s.opening.get("shape","flat"),"holds":s.attempt.get("holds",{}),"powered":s.flags.get("power",true),"gate_open":gate_open})
 var poses: Array=session.call("echo_poses")
 while echoes.size()<poses.size():
  var echo: Node2D=load("res://world/player.tscn").instantiate();echo.set("echo",true);echo.set("collision_layer",0);echo.set("collision_mask",0);world.add_child(echo);echoes.append(echo)
 for index: int in range(echoes.size()):
  echoes[index].visible=index<poses.size()
  if index<poses.size():
   var pose: Dictionary=poses[index];echoes[index].position=Vector2(pose.x,pose.y);echoes[index].set("facing",pose.direction);echoes[index].set("moving",pose.moving)
 var finale: Dictionary=s.finale
 if examiner==null:
  examiner=load("res://world/player.tscn").instantiate();examiner.set("tint",Color("d88775"));examiner.set("collision_layer",0);examiner.set("collision_mask",0);world.add_child(examiner)
 examiner.visible=str(finale.get("phase","")) in ["warning","chase"] and str(finale.get("examiner_room",""))==room_id
 if examiner.visible:
  var position_data: Array=finale.get("examiner_position",[320,200]);examiner.position=Vector2(position_data[0],position_data[1])
 var attempt: Dictionary=s.attempt
 var echo_text: String=""
 if not attempt.is_empty() and room_id=="lab":
  var device_tick: int=int(attempt.get("tick",0))
  if attempt.get("phase","")=="countdown":echo_text="同步倒数 %s · 到自己的工位，交互开始维持"%maxi(1,int(ceil(-device_tick/60.0)))
  elif attempt.get("phase","")=="recording":
   var holds: Dictionary=attempt.get("holds",{})
   echo_text="同步 %.1f 秒 · A %s · B %s · %s"%[device_tick/60.0,"维持中" if holds.has("assist_a") else "空缺","维持中" if holds.has("assist_b") else "空缺","你操作 C 释放" if int(s.cycle)==3 else "留在自己的操作区"]
  else:echo_text="同步装置 · "+str(attempt.get("message",""))
 if room_id=="archive" and int(finale.get("release_tick",-1))>=0:
  echo_text="闸门已开启 · 剩余 %.1f 秒，走向出口"%maxf(0,(int(finale.close_tick)-int(s.tick))/60.0) if gate_open else "落体闸门正在计时，观察锁扣。"
 if finale.get("phase","")=="warning":echo_text="监考者的脚步接近了。准备移动与闪避。"
 if finale.get("phase","")=="chase":echo_text="监考者追逐中 · "+str(settings.call("display","dodge"))+" 闪避，前往观测塔"
 var objective_text: String="第 %s 轮 · %s"%[s.cycle,session.call("objective")]
 var near_text: String=(str(settings.call("display","interact"))+"  "+str(near.title)) if not near.is_empty() else "移动探索 · "+str(settings.call("display","pause"))+" 设置"
 var hint_text: String=str(session.call("hint")) if int(s.get("guide",{}).get("hint_level",0))>0 else ""
 var key: String=objective_text+near_text+echo_text+hint_text
 if key!=_hud_key:
  objective.text=objective_text;prompt.text=near_text;echo_status.text=echo_text;echo_status.visible=not echo_text.is_empty();_hud_key=key
  hint_status.text=hint_text;hint_status.visible=not hint_text.is_empty()
 _update_joint(near)

func _update_joint(near: Dictionary) -> void:
 if joint_visual==null:
  joint_visual=Control.new();joint_visual.set_script(preload("res://ui/v03/trajectory.gd"));joint_visual.position=Vector2(210,42);joint_visual.size=Vector2(220,92);world.add_child(joint_visual)
  joint_summary=Label.new();joint_summary.position=Vector2(166,136);joint_summary.size=Vector2(310,42);joint_summary.add_theme_font_size_override("font_size",12);joint_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;world.add_child(joint_summary)
 var attempt: Dictionary=state().attempt
 var trace: Dictionary=attempt.get("joint_trace",{})
 var visible_here: bool=room_id=="lab" and not trace.is_empty()
 joint_visual.visible=visible_here;joint_summary.visible=visible_here
 if not visible_here:joint_result_frames=0;return
 var elapsed: float=(int(attempt.get("tick",0))-int(attempt.get("joint_start",0)))/60.0
 var progress: float=clampf(elapsed/maxf(0.01,float(trace.get("arrival_s",1))),0,1)
 joint_visual.render({"trace":trace,"shape":"flat"},progress)
 var succeeded: bool=attempt.get("phase","")=="success"
 joint_summary.text="联合真空测量 · A/B 持续维持，C 释放" if not succeeded else "真空实测 %.3f 秒 · A/B/C 联合完成"%float(trace.get("arrival_s",0))
 if not succeeded or str(near.get("id",""))!="lab_drop":joint_result_frames=0

func _observe_visible_results() -> void:
 # Count presentation frames, not physics ticks or repeated synchronization calls.
 # The third process frame follows two opportunities to actually draw the result.
 var s: Dictionary=state()
 if modal=="paper" and paper_visual!=null and s.opening.get("phase","")=="landed":
  paper_result_frames+=1
  if paper_result_frames>=3 and paper_observed_release!=int(s.opening.get("release_tick",-1)):
   var result: Dictionary=_dispatch("observe","paper")
   if result.get("ok",false):paper_observed_release=int(s.opening.get("release_tick",-1))
 if modal.is_empty() and joint_visual!=null and joint_visual.visible and s.attempt.get("phase","")=="success":
  var near: Dictionary=session.call("nearby")
  if str(near.get("id",""))=="lab_drop":
   joint_result_frames+=1
   var source: String=str(s.attempt.get("source_event_id",""))
   if joint_result_frames>=3 and source!=joint_observed_source:
    joint_observed_source=source;_observe_joint.call_deferred(source)

func _observe_joint(source: String) -> void:
 var result: Dictionary=_dispatch("observe","lab_drop")
 if not bool(result.get("ok",false)) and joint_observed_source==source:joint_observed_source=""

func _dispatch(kind: String,target: String="",payload: Dictionary={}) -> Dictionary:
 _request_seq+=1
 var request: Dictionary=payload.duplicate(true)
 request["request_id"]="ui:%s:%s"%[Time.get_ticks_usec(),_request_seq]
 var result: Dictionary=session.call("command",kind,target,request)
 if not str(result.get("message","")).is_empty():toast(str(result.message))
 _sync_world()
 if bool(result.get("ok",false)):
  if kind=="retry":joint_observed_source="";paper_observed_release=-1
  if kind not in ["move","fast_forward","dodge"]:save_game(false)
  if state().mode=="combat":show_combat()
  elif modal=="combat":close_modal()
 return result

func _interact() -> void:
 var item: Dictionary=session.call("nearby")
 if item.is_empty():return
 var id: String=str(item.id)
 match id:
  "paper":show_paper()
  "rig_demo":
   var result: Dictionary=_dispatch("learn_rig",id)
   if bool(result.get("ok",false)):show_rig()
  "sync_bell":_dispatch("bell",id)
  "assist_a","assist_b":_dispatch("hold",id)
  "lab_drop":_dispatch("joint_release",id)
  "rig_power":_dispatch("power",id)
  "paper_barrier":_dispatch("fix",id)
  "archive_terminal":show_archive()
  "fall_gate":_dispatch("gate_release",id)
  "cycle_console":
   if state().finale.get("phase","")=="escaped":_dispatch("submit",id)
   else:show_cycle()
  _: _dispatch("interact",id)

func _open(id: String,title: String="") -> void:
 modal=id;combat=null;paper_visual=null;paper_status=null;rig_visual=null;rig_status=null
 for child: Node in modal_body.get_children():modal_body.remove_child(child);child.queue_free()
 shade.show();panel.show()
 if not title.is_empty():UI.label(modal_body,title,23)

func close_modal() -> void:
 if state().mode=="combat":show_combat();return
 if state().mode=="caught":show_caught();return
 modal="";panel.hide();shade.hide();combat=null;paper_visual=null

func toast(text: String) -> void:
 toast_label.text=text;toast_remaining=5.0

func _welcome() -> void:
 _open("welcome","超纲 / OUT OF SYLLABUS · v0.3")
 UI.label(modal_body,"纸片还在下坠。试着改变它，看看门会发生什么。",25)
 UI.label(modal_body,"走近物体后按交互键。观察动作的结果，再把同一个动作带进战斗。\nWASD 移动 · E 交互 · Space 闪避 · Esc 设置\n世界与角色目前使用可编辑占位表现。")
 UI.button(modal_body,"NewGame","开始新的 v0.3 记录",new_game)
 UI.button(modal_body,"Continue","继续 v0.3 记录",load_game)
 UI.focus_first(modal_body)

func new_game() -> void:
 var core: Script=load("res://core/v03/game_session.gd");session=core.new();session.connect("notice",toast);paper_observed_release=-1;joint_observed_source="";room_id="";close_modal();_sync_world();save_game(false)

func save_game(notify: bool=true) -> void:
 if saves==null:return
 var ok: bool=saves.call("save_session",session)
 if notify or not ok:toast("v0.3 记录已保存。" if ok else str(saves.get("last_error")))

func load_game() -> void:
 if saves.call("load_session",session):
  room_id="";modal="";paper_observed_release=-1;joint_observed_source="";_sync_world();close_modal();toast("已恢复 v0.3 记录。")
 else:toast(str(saves.get("last_error")))

func show_paper() -> void:
 _open("paper","纸片计时门 · 改变同一张纸")
 UI.label(modal_body,"传感器接住纸片后驱动延时齿轮。展开或揉团，观察锁扣打开多久。",18)
 paper_visual=Control.new();paper_visual.set_script(preload("res://ui/v03/trajectory.gd"));paper_visual.custom_minimum_size.y=170;modal_body.add_child(paper_visual)
 paper_status=UI.label(modal_body,"",18);paper_status.name="PaperResult"
 var row: HBoxContainer=UI.row(modal_body)
 UI.button(row,"PaperFlat","展开",func() -> void:_dispatch("paper_shape","paper",{"shape":"flat"}))
 UI.button(row,"PaperCrumpled","揉团",func() -> void:_dispatch("paper_shape","paper",{"shape":"crumpled"}))
 UI.button(row,"PaperRelease","释放",func() -> void:
  var result: Dictionary=_dispatch("release","paper")
  if result.get("ok",false):modal="paper_live";paper_result_frames=0;_slow_frame=0)
 UI.button(row,"ClosePaper","返回现场",close_modal)
 _update_paper();UI.focus_first(row)

func show_rig() -> void:
 _open("rig","配重示范 · 两个质量，同一动作")
 var demo: Dictionary=state().get("rig_demo",{})
 var traces: Array=demo.get("traces",[])
 var visual_traces: Array=[]
 var objects: Dictionary={}
 for index: int in range(traces.size()):
  var trace: Dictionary=traces[index]
  var setup: Dictionary=trace.get("setup",{})
  var id: String=str(trace.get("id",setup.get("id","weight%s"%index)))
  var visual_trace: Dictionary=trace.duplicate(true);visual_trace["id"]=id;visual_traces.append(visual_trace)
  objects[id]={"title":"配重%s · %.3f kg"%[index+1,float(setup.get("mass",0))],"height":setup.get("height",2.0),"kind":"metal","held":false}
 rig_data={"objects":objects,"traces":visual_traces};rig_playback=0.0
 UI.label(modal_body,"调高夹具并同步释放。下面的动作与到达时间来自这次装置实际计算的轨迹。",18)
 rig_visual=Control.new();rig_visual.set_script(preload("res://ui/v03/trajectory.gd"));rig_visual.custom_minimum_size.y=170;modal_body.add_child(rig_visual)
 rig_status=UI.label(modal_body,"同形金属配重释放中 · 共同慢放",18)
 UI.button(modal_body,"CloseRig","返回实验室",close_modal);UI.focus_first(modal_body)

func _update_paper() -> void:
 if paper_visual==null:return
 var opening: Dictionary=state().opening
 var phase: String=str(opening.get("phase","idle"))
 var trace: Dictionary=opening.get("trace",{})
 var elapsed: float=float(opening.get("elapsed",0))
 var duration: float=maxf(0.01,float(trace.get("arrival_s",1)))
 var view_data: Dictionary=opening.duplicate(true)
 view_data["door_open"]=int(state().tick)<=int(opening.get("door_until",-1))
 paper_visual.render(view_data,clampf(elapsed/duration,0,1))
 paper_status.text="纸片：%s · %s"%["平展" if opening.get("shape","flat")=="flat" else "揉团",{"idle":"准备释放","falling":"下坠中 · 世界与机关同步 3 倍慢放","landed":"纸片到达传感器"}.get(phase,phase)]
 if phase=="landed":
  paper_status.text+="\n实测 %.3f 秒 · 门剩余 %.1f 秒"%[float(trace.get("arrival_s",0)),maxf(0,float(opening.get("door_until",0)-state().tick)/60.0)]
  modal="paper" # Landed result is visible; reading pauses the shared clock.

func show_combat() -> void:
 var battle: Dictionary=state().battle
 if battle.is_empty():return
 if modal!="combat" or combat==null:
  _open("combat")
  combat=VBoxContainer.new();combat.set_script(CombatView);combat.size_flags_vertical=Control.SIZE_EXPAND_FILL;modal_body.add_child(combat)
  combat.preview=Callable(session,"combat_preview");combat.command_requested.connect(_combat_command)
  _battle_revision=-1
 if _battle_revision!=int(battle.get("revision",0)):
  combat.render(battle,state().owned);_battle_revision=int(battle.get("revision",0))
  if get_viewport().gui_get_focus_owner()==null:UI.focus_first(combat)

func _combat_command(kind: String,target: String,payload: Dictionary) -> void:
 _dispatch(kind,target,payload)
 if state().battle.get("outcome","")=="lost":show_caught()

func show_cycle() -> void:
 _open("cycle","封存本轮真实操作")
 UI.label(modal_body,"只封存你亲手完成的装置片段。下一轮准备好后敲同步铃，过去的动作才开始回放。",21)
 UI.label(modal_body,str(session.call("objective")))
 UI.button(modal_body,"SealCycle","封存并进入下一轮",func() -> void:
  var result: Dictionary=_dispatch("seal","cycle_console")
  if result.get("ok",false):room_id="";close_modal();_sync_world())
 UI.button(modal_body,"CancelSeal","继续准备",close_modal);UI.focus_first(modal_body)

func show_archive() -> void:
 _open("archive","档案室 · 借来的轨迹")
 UI.label(modal_body,"已有观察支持安全校准。未来知识可以揭示更短路线的窗口；选择本身不会记违规，实际使用后才承担后果。",20)
 var row: HBoxContainer=UI.row(modal_body)
 UI.button(row,"AcceptFuture","接受未来知识",func() -> void:_dispatch("choose_future","archive_terminal",{"accept":true});show_archive())
 UI.button(row,"RefuseFuture","坚持已有观察",func() -> void:_dispatch("choose_future","archive_terminal",{"accept":false});show_archive())
 UI.label(modal_body,"预测模型：")
 var models: HBoxContainer=UI.row(modal_body)
 UI.button(models,"ModelDrag",("● " if archive_model=="drag" else "")+"重力与空气阻力",func() -> void:archive_model="drag";show_archive())
 UI.button(models,"ModelGravity",("● " if archive_model=="gravity" else "")+"仅重力",func() -> void:archive_model="gravity";show_archive())
 var operations: HBoxContainer=UI.row(modal_body)
 UI.button(operations,"Forecast","预览轨迹（2米 / 空气）",func() -> void:_dispatch("forecast","archive_terminal",{"model":archive_model,"height":2.0,"medium":"air"});show_archive())
 UI.button(operations,"Calibrate","用已有观察校准",func() -> void:_dispatch("calibrate","archive_terminal");show_archive())
 var finale: Dictionary=state().finale
 var prediction: Dictionary=finale.get("prediction",{})
 var summary: String="尚未准备轨迹或校准记录。"
 if not prediction.is_empty():
  summary="%s · 到达 %.3f 秒"%["未来预测（尚未实际使用）" if prediction.get("origin","")=="prediction" else "已观察的实测记录",float(prediction.get("trace",{}).get("arrival_s",0))]
  if prediction.get("origin","")=="measurement":summary+="\n下一步：器材室远端校准刻度，然后返回闸门。"
 UI.label(modal_body,"当前选择：%s\n%s"%[{"none":"尚未选择","accept":"接受","refuse":"拒绝"}.get(str(finale.get("choice","none")),""),summary],17)
 UI.label(modal_body,"完成准备后返回现场，走到落体闸门亲手释放并通行。")
 UI.button(modal_body,"CloseArchive","返回现场",close_modal);UI.focus_first(modal_body)

func show_caught() -> void:
 _open("caught","这一次没能通过")
 UI.label(modal_body,"恢复最近检查点，已经封存的历史不会改写。追逐重试不会重复记违规。",22)
 UI.button(modal_body,"RetryCheckpoint","重试",func() -> void:
  var result: Dictionary=_dispatch("retry")
  if result.get("ok",false):modal="";room_id="";close_modal();_sync_world())
 UI.button(modal_body,"CaughtSettings","设置",show_settings);UI.focus_first(modal_body)

func show_ending() -> void:
 _open("ending","序章 · 记录已封存")
 UI.label(modal_body,"你借用了尚未获准的轨迹，也承担了追赶而来的目光。" if state().finale.get("choice","")=="accept" else "你用亲手看到的规律走到了观测塔。",25)
 UI.label(modal_body,"三轮真实操作留下了回声。知识改变了你的解法，记录保留了它的来源。")
 UI.button(modal_body,"EndingNotebook","查看笔记",show_notebook)
 UI.button(modal_body,"EndingSave","保存完成记录",save_game);UI.focus_first(modal_body)

func show_notebook() -> void:
 _open("notebook","笔记 · 已发生的观察")
 var scroll: ScrollContainer=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;modal_body.add_child(scroll)
 var body: VBoxContainer=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 UI.label(body,str(session.call("hint")),20)
 var names: PackedStringArray=[]
 for id: Variant in state().owned:names.append(UI.action_name(str(id)))
 UI.label(body,"已学动作："+"、".join(names))
 for observation: Dictionary in state().observations:
  var trace: Dictionary=observation.get("trace",{})
  UI.label(body,str(observation.get("summary","已完成观察"))+"\n第 %s 轮 · %s · 到达 %.3f 秒"%[observation.get("cycle",1),"真空装置" if trace.get("setup",{}).get("medium","air")=="vacuum" else "空气中的落体",float(trace.get("arrival_s",0))],16)
 UI.label(body,"已封存 %s 轮历史，%s 个装置片段。"%[state().histories.size(),state().segments.size()])
 UI.button(modal_body,"CloseNotebook","返回",close_modal);UI.focus_first(modal_body)

func show_settings() -> void:
 _open("settings","设置 · v0.3 独立记录")
 var grid: GridContainer=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",5);modal_body.add_child(grid)
 for id: String in Settings.DEFAULTS:
  UI.button(grid,"Bind_"+id,Settings.LABELS[id]+"  ["+str(settings.call("display",id))+"]",func() -> void:rebind=id;toast("按下新的按键；已有冲突会交换。"))
 var reduced: CheckButton=CheckButton.new();reduced.name="ReducedEffects";reduced.text="减少闪烁与视觉干扰";reduced.button_pressed=bool(settings.get("reduced_effects"));modal_body.add_child(reduced)
 reduced.toggled.connect(func(value: bool) -> void:settings.set("reduced_effects",value);settings.call("save"))
 var audio: HSlider=HSlider.new();audio.name="Volume";audio.min_value=0;audio.max_value=1;audio.step=0.05;audio.value=float(settings.get("volume"));modal_body.add_child(audio)
 audio.value_changed.connect(func(value: float) -> void:settings.set("volume",value);settings.call("apply");settings.call("save"))
 var row: HBoxContainer=UI.row(modal_body)
 UI.button(row,"Save","保存",save_game);UI.button(row,"Load","读取",load_game);UI.button(row,"Retry","恢复检查点",func() -> void:_dispatch("retry");close_modal())
 UI.button(modal_body,"CloseSettings","返回",close_modal);UI.focus_first(modal_body)
