extends Control
@onready var world_node: Node2D = $WorldFrame/Viewport/World
@onready var player: PixelActor = $WorldFrame/Viewport/World/Player
@onready var ui: GameUI = $UI
@onready var feedback_sound: AudioStreamPlayer = $FeedbackSound
var content: GameContent
var session: GameSession
var saves: SaveStore
var settings: InputSettings
var room_node: Node2D
var echo_nodes: Array[PixelActor] = []
var nearest: Dictionary = {}
var dodge_time: float = 0.0
var dodge_cooldown: float = 0.0
var hazard_cooldown: float = 0.0
var rebind_action: String = ""
var loadout_selection: Array = []
var return_to_model: bool = false
var experimental_vacuum: bool = false
var experimental_shape: String = "flat"
var suppress_intro: bool = false
func _ready() -> void:
 content = GameContent.new();session = GameSession.new(content);saves = SaveStore.new();settings = InputSettings.new()
 session.changed.connect(update_hud);session.notice.connect(ui.toast)
 for entry: Array in [["实验日志",show_journal],["卡组",show_loadout],["等候 5 秒",wait_five],["检查点",restore_checkpoint],["保存",save_game],["设置",show_settings]]:
  ui.button(entry[0],entry[1],ui.toolbar).add_theme_font_size_override("font_size",16)
 if ResourceLoader.exists("res://assets/audio/confirm.wav"): feedback_sound.stream = load("res://assets/audio/confirm.wav")
 load_room();session.set_checkpoint()
 if not suppress_intro: show_welcome()
func load_room() -> void:
 if room_node != null:
  world_node.remove_child(room_node);room_node.queue_free()
 var scene: PackedScene = load("res://world/rooms/%s.tscn" % session.room_id)
 room_node = scene.instantiate() as Node2D;world_node.add_child(room_node);world_node.move_child(room_node,0)
 room_node.z_index = -1
 player.position = session.player_position
 update_props();update_hud()
func update_hud() -> void:
 if not is_instance_valid(ui) or session == null: return
 ui.header.text = "超纲  /  %s    ·    第 %d 轮    ·    %02d:%02d    ·    回声 %d" % [content.room(session.room_id).title,session.cycle,session.tick/3600,(session.tick/60)%60,session.histories.size()]
 ui.objective.text = "当前问题  →  " + session.objective()
func update_props() -> void:
 if room_node == null: return
 for prop: WorldProp in room_node.get_node("Props").get_children():
  prop.active = bool(session.world.get(prop.object_id,false))
  if prop.kind == "exit":
   var required: String = str(content.object(prop.object_id).get("requires",""))
   prop.active = required.is_empty() or bool(session.world.get(required,false))
  if prop.kind == "pickup": prop.active = prop.object_id in session.inventory
  if prop.kind == "hazard": prop.active = session.world.coil_disabled
  if prop.kind == "crate": prop.position.x = 224 + 32*int(session.world.crate)
  prop.queue_redraw()
func _physics_process(delta: float) -> void:
 if session == null or session.mode != "world":
  if player != null: player.moving = false
  return
 var input: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
 if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0 and input.length_squared()>0:
  dodge_time = 0.16;dodge_cooldown = 0.8
 dodge_time = maxf(0,dodge_time-delta);dodge_cooldown = maxf(0,dodge_cooldown-delta);hazard_cooldown = maxf(0,hazard_cooldown-delta)
 player.velocity = input * (235.0 if dodge_time>0 else 100.0)
 player.move_and_slide();player.moving = input.length_squared()>0
 player.position = player.position.clamp(Vector2(40,56),Vector2(600,306))
 if absf(input.x)>absf(input.y): player.facing = "left" if input.x<0 else "right"
 elif input.y != 0: player.facing = "up" if input.y<0 else "down"
 session.player_position = player.position;session.direction = player.facing
 session.advance(1,player.moving)
 update_echoes();update_props();update_nearest();update_hud()
 if session.room_id == "corridor" and not session.world.coil_disabled and player.position.distance_to(Vector2(176,136))<30 and hazard_cooldown<=0 and dodge_time<=0:
  hazard_cooldown = 2;player.position += Vector2(0,32);session.player_position = player.position
  ui.toast("异常电弧：可闪避通过；理解重力后，用知识应用隔离装置。")
func update_echoes() -> void:
 var poses: Array = session.echo_poses()
 while echo_nodes.size()<poses.size():
  var echo_actor: PixelActor = load("res://world/player.tscn").instantiate() as PixelActor
  echo_actor.echo = true;echo_actor.collision_layer = 0;echo_actor.collision_mask = 0
  world_node.add_child(echo_actor);echo_nodes.append(echo_actor)
 for i: int in range(echo_nodes.size()):
  echo_nodes[i].visible = i<poses.size()
  if i<poses.size():
   echo_nodes[i].position = Vector2(poses[i].x,poses[i].y);echo_nodes[i].facing = poses[i].direction;echo_nodes[i].moving = poses[i].moving
func update_nearest() -> void:
 nearest = {};var distance: float = 48.0
 for item: Dictionary in content.room(session.room_id).objects:
  var prop: Node2D = room_node.get_node("Props/"+item.id) as Node2D
  var d: float = player.position.distance_to(prop.position)
  if d<distance: distance=d;nearest=item
 ui.prompt.text = "[%s] %s" % [settings.display("interact"),nearest.title] if not nearest.is_empty() else "%s%s%s%s 移动  ·  %s 闪避  ·  %s 日志  ·  %s 应用知识" % [settings.display("move_up"),settings.display("move_left"),settings.display("move_down"),settings.display("move_right"),settings.display("dodge"),settings.display("journal"),settings.display("apply_knowledge")]
func _unhandled_input(event: InputEvent) -> void:
 if session == null: return
 if not rebind_action.is_empty() and event is InputEventKey and event.pressed and not event.echo:
  settings.bind_key(rebind_action,event.physical_keycode);rebind_action="";show_settings();get_viewport().set_input_as_handled();return
 if event.is_action_pressed("pause"):
  if ui.panel.visible: close_modal()
  else: show_settings()
  return
 if ui.panel.visible: return
 if event.is_action_pressed("interact") and not nearest.is_empty(): interact(nearest)
 elif event.is_action_pressed("journal"): show_journal()
 elif event.is_action_pressed("cards"): show_loadout()
 elif event.is_action_pressed("wait"): wait_five()
 elif event.is_action_pressed("save"): save_game()
 elif event.is_action_pressed("load"): load_game()
 elif event.is_action_pressed("apply_knowledge"):
  if "gravity" in session.profile.knowledge and session.room_id == "corridor" and player.position.distance_to(Vector2(176,136)) < 70:
   session.command("switch","coil_disabled",{"value":true});ui.toast("应用知识：隔离异常装置，走廊恢复安全。")
  else: ui.toast("先理解重力模型，并靠近走廊异常装置。")
func pause(title: String, subtitle: String = "") -> void:
 if session.mode == "world": session.mode = "menu"
 ui.open(title,subtitle)
func close_modal() -> void:
 if session.battle != null:
  show_battle();return
 session.mode = "world";ui.close();player.position = session.player_position
func footer_button() -> void:
 ui.button("返回现象界",close_modal);ui.focus_first()
func show_welcome() -> void:
 pause("超纲 / OUT OF SYLLABUS","序章 · 下坠  /  可玩灰盒 v0.1.0")
 ui.label("钟声响了。教室里的纸片还没有落地。
你记得这个瞬间，却不记得自己为何记得。",25)
 ui.label("探索同一座学校，提出模型，面对反例。世界可以重置，理解会留下。
移动靠近物体后按交互键；对话与论证期间世界暂停。")
 if FileAccess.file_exists(saves.path): ui.button("继续已有记录",load_game)
 ui.button("开始新的记录",confirm_new_game)
 ui.label("这是用于验证玩法与因果规则的灰盒。正式美术、目标时长和外部玩家试玩仍待验收。",16)
 ui.focus_first()
func interact(item: Dictionary) -> void:
 feedback_sound.play()
 match str(item.kind):
  "exit":
   var required: String = str(item.get("requires",""))
   if not required.is_empty() and not session.world.get(required,false):
    ui.toast("联锁门未开启：接通教室 A 与器材室 B。" if required=="lab_gate" else "先完成第三轮的阻力论证。");return
   session.command("visit",item.target);load_room();session.set_checkpoint();save_game(false)
  "switch":
   var target: String = item.id
   var current: bool = bool(session.world.get(target,false))
   session.command("switch",target,{"expected":current,"value":not current});update_props();ui.toast("%s：%s" % [item.title,"接通" if not current else "断开"])
  "pickup":
   session.command("pickup",item.id,{"title":item.title});ui.toast("实验包已放入背包。");update_props();save_game(false)
  "crate":
   var result: Dictionary = session.command("push","crate",{"expected":0});ui.toast(result.message);update_props()
  "npc":
   var text: String = item.texts[mini(session.cycle-1,item.texts.size()-1)]
   session.command("talk",item.id,{"text":text});pause(item.title);ui.label(text,25);footer_button()
  "board": pause(item.title);ui.label(item.text,23);footer_button()
  "experiment": show_experiment()
  "compression":
   var result: Dictionary = session.compress_lab();update_props();update_echoes();ui.toast(result.message);save_game(false)
  "cycle": show_cycle()
  "finale": show_finale()
  "hazard": ui.toast("闪避通过，或在理解知识后按应用知识键隔离装置。")
func show_experiment() -> void:
 session.set_checkpoint()
 pause("实验台 / 条件与证据","高度 2.00 m · 初速度 0 m/s · 同时释放 · 结果为独立科学模型计算")
 if session.cycle == 1 and not "kit" in session.inventory:
  ui.label("先去器材室取实验包。设备不能替你控制变量。");footer_button();return
 var settings_row: HBoxContainer = ui.row()
 ui.button("环境："+("真空" if experimental_vacuum else "空气"),func() -> void:
  if not session.world.pump and not experimental_vacuum: ui.toast("先到器材室启动真空泵。")
  else: experimental_vacuum = not experimental_vacuum;show_experiment(),settings_row)
 ui.button("纸片："+("展开" if experimental_shape=="flat" else "揉团"),func() -> void:
  experimental_shape = "crumpled" if experimental_shape=="flat" else "flat";show_experiment(),settings_row)
 var result: Dictionary = ExperimentModel.comparison(experimental_vacuum,experimental_shape)
 ui.label("金属球  %.3f 秒        纸片  %.3f 秒" % [result.ball,result.paper],29)
 ui.label("这里显示预测；按下记录后才成为本次实验记录。空气中的结果依赖所选形状、质量和阻力参数。",17)
 ui.button("控制条件并记录本次实验",func() -> void:
  var previous_mode: String = session.mode;session.mode="world"
  var response: Dictionary = session.command("experiment","lab_drop",result);session.mode=previous_mode
  if response.ok: session.command("knowledge","observation");save_game(false)
  ui.toast(response.message))
 if session.cycle>=2:
  var encounter: String = "mass" if session.cycle==2 else "drag"
  if encounter in session.settled: ui.label("本轮的模型论证已经完成。")
  elif encounter=="drag" and not session.world.pump: ui.label("启动真空泵后，才能进入最终对照论证。")
  else: ui.button("进入模型界 · "+content.encounters[encounter].title,func() -> void: begin_battle(encounter))
 ui.label("第一轮记录之后前往观测塔。第二轮开始，同一地点会出现新问题。",17)
 footer_button()
func begin_battle(id: String) -> void:
 session.mode="world"
 if session.start_battle(id): show_battle();save_game(false)
func show_battle() -> void:
 if session.battle == null: close_modal();return
 var b: ModelBattle = session.battle
 ui.open("模型界 / "+b.definition.title,"解释现象，而不是消灭证据。世界与回声暂时停止。")
 ui.label(b.definition.question,25)
 var names: Dictionary = {"none":"尚未建立","mass":"质量假说（待检验）","gravity":"重力模型","drag":"重力 + 空气阻力"}
 ui.label("模型：%s     解释度：%d%%     第 %d 轮 / 剩余行动 %d" % [names[b.state.model],b.progress(),b.state.round,b.state.actions],20)
 var bar: ProgressBar = ProgressBar.new();bar.value=b.progress();bar.custom_minimum_size.y=12;bar.show_percentage=false;ui.body.add_child(bar)
 var requirements: Dictionary = {"observation":"读取现象","controls":"控制释放条件","evidence":"测量或重复验证","mass_independence":"解释质量反例","air_difference":"解释空气与形状差异","vacuum_control":"解释真空对照"}
 var pending: Array[String] = []
 for id: String in b.definition.requirements:
  if not id in b.state.resolved: pending.append(requirements[id])
 ui.label("下一目标："+" · ".join(pending) if not pending.is_empty() else "证据链完整。",18)
 ui.label(b.state.last,16)
 if not b.state.won and not b.state.failed:
  ui.label("下一反例："+b.definition.counterexamples[(int(b.state.round)-1)%b.definition.counterexamples.size()],16)
 if b.state.won:
  ui.button("提交模型，返回现象界",func() -> void:
   session.finish_battle();ui.close();session.set_checkpoint();save_game(false);ui.toast("模型已提交，新的路线可以使用。"))
 elif b.state.failed:
  ui.label(b.hint(int(session.profile.hints)),19)
  ui.button("保留提示，重新论证",func() -> void:
   session.profile.hints+=1;session.battle=ModelBattle.new(b.definition);show_battle())
 else:
  var grid: GridContainer = GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",8);ui.body.add_child(grid)
  var equipped: Array = ["observe","experiment"]+session.loadout
  for id: String in equipped:
   var card: CardDef = content.cards[id]
   var button: Button = ui.button("%s  ·  %s" % [card.kind,card.title],func() -> void: play_card(id),grid)
   button.tooltip_text=card.description;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var actions: HBoxContainer = ui.row()
  ui.button("提示",func() -> void: ui.toast(b.hint(int(session.profile.hints)));session.profile.hints+=1,actions)
  ui.button("检查 / 调整卡组",show_loadout,actions)
  ui.button("放下论证，回到实验台",func() -> void: session.battle=null;session.mode="world";ui.close();save_game(false),actions)
 ui.focus_first()
func play_card(id: String) -> void:
 if session.battle == null: return
 var result: Dictionary = session.battle.play(content.cards[id]);feedback_sound.play()
 if not result.ok: ui.toast(result.message)
 show_battle();save_game(false)
func show_cycle() -> void:
 pause("观测记录 / 循环边界")
 if session.can_cycle():
  ui.label("结束本轮后，物品和装置恢复初始状态。你的知识与整轮行动会留下，成为下一轮可见的回声。",24)
  ui.button("封存第 %d 轮，醒来" % session.cycle,func() -> void:
   if session.next_cycle():
    ui.close();load_room();session.set_checkpoint();save_game(false);ui.toast("钟声再次响起。过去的你仍在路上。"))
 else: ui.label("尚未达到本轮的记录条件。
"+session.objective(),23)
 footer_button()
func show_finale() -> void:
 pause("封锁档案 / 未来知识","数值方法能够逼近模型的预测，但不能替你选择正确的模型。")
 if not session.world.drag:
  ui.label("档案尚未解锁。完成第三轮论证后再来。");footer_button();return
 if session.profile.completed: show_ending();return
 ui.label("一页来自未来的推导落在桌面上。你能够借用数值积分，提前算出装置在阻力下的运动。
页面右上角印着：许可等级不足。",24)
 ui.label("选择借用：超纲度 +1，监考者出现。
选择拒绝：保留可复核的实验记录。两种选择都能结束本章。",20)
 ui.button("借用未来知识 · 超纲度 +1",func() -> void: finish_chapter(true))
 ui.button("拒绝调用 · 留下实验记录",func() -> void: finish_chapter(false))
 footer_button()
func finish_chapter(accept: bool) -> void:
 session.command("ending","chapter_fall",{"accept":accept});save_game(false);show_ending()
func show_ending() -> void:
 pause("序章结束 / 记录仍在继续")
 var accepted: bool = session.profile.choices.get("future_card",false)
 ui.label("未经授权的知识已被检测。
走廊尽头，一个身影转向了你。" if accepted else "你把实验条件写在了答案旁边。
钟声没有再响。至少这一次没有。",28)
 ui.label("你解释了一个现象，也找到了模型的边界。
下一章候选：电路与测量。
完成记录已经保存。",21)
 ui.button("查看我的实验日志",show_journal);footer_button()
func show_journal() -> void:
 pause("实验日志 / 历史没有被覆盖","当前目标："+session.objective())
 ui.label("已理解："+"、".join(session.profile.knowledge)+"    超纲度："+str(session.profile.violation),20)
 ui.label("世界记录 %d 条 · 当前轨迹 %d 个采样 · 历史 %d 轮" % [session.events.size(),session.track.samples.size(),session.histories.size()],17)
 for room: Dictionary in content.chapter.rooms:
  ui.label(("● " if room.id in session.visited else "○ ")+room.title+"  —  "+room.subtitle,17)
 var count: int = 0
 for i: int in range(session.events.size()-1,-1,-1):
  var e: Dictionary = session.events[i]
  if e.kind in ["experiment","resolve","talk","ending"]:
   ui.label("[%02d:%02d] %s / %s / %s" % [int(e.tick)/3600,(int(e.tick)/60)%60,e.actor,e.kind,e.target],16);count+=1
   if e.kind=="experiment" and e.payload.has("ball"):
    ui.label("球 %.3f s · 纸 %.3f s · %s" % [e.payload.ball,e.payload.paper,"真空" if e.payload.vacuum else "空气"],16)
   if count>=8: break
 if not session.deviations.is_empty():
  ui.label("因果偏差",23)
  for i: int in range(maxi(0,session.deviations.size()-5),session.deviations.size()): ui.label(session.deviations[i].message,17)
 footer_button()
func show_loadout() -> void:
 return_to_model=session.battle!=null
 loadout_selection=session.loadout.duplicate()
 draw_loadout()
func draw_loadout() -> void:
 pause("知识卡组 / 选择六张","观察与基础实验始终可用。推荐配置覆盖本章全部必需工具。当前选择 %d / 6" % loadout_selection.size())
 for id: String in content.chapter.card_ids:
  if id in ["observe","experiment","future"]: continue
  var card: CardDef=content.cards[id]
  var button: Button=ui.button(("☑ " if id in loadout_selection else "□ ")+card.title+"  —  "+card.description,func() -> void:
   if id in loadout_selection: loadout_selection.erase(id)
   elif loadout_selection.size()<6: loadout_selection.append(id)
   draw_loadout())
  button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",17)
 ui.button("恢复推荐配置",func() -> void: loadout_selection=["gravity","control","measurement","shape","vacuum","drag"];draw_loadout())
 var confirm: Button=ui.button("保存六张卡",func() -> void:
  session.loadout=loadout_selection.duplicate();save_game(false)
  if return_to_model: show_battle()
  else: close_modal())
 confirm.disabled=loadout_selection.size()!=6
 footer_button()
func wait_five() -> void:
 if session.mode!="world": return
 session.advance(300);update_echoes();update_props();update_hud();ui.toast("世界时间推进 5 秒；历史事件已逐一结算。")
func restore_checkpoint() -> void:
 if session.checkpoint.is_empty(): ui.toast("还没有检查点。");return
 pause("恢复因果检查点","只回退当前进度，已经封存的历史保持不变。")
 ui.button("恢复最近区域 / 实验检查点",func() -> void:
  if session.rewind():
   load_room();ui.close();save_game(false)
   if session.battle!=null:show_battle())
 footer_button()
func save_game(show_message: bool = true) -> void:
 var ok: bool=saves.save_session(session)
 if show_message or not ok: ui.toast("记录已保存。" if ok else saves.last_error)
func load_game() -> void:
 if saves.load_session(session):
  load_room();ui.close()
  if session.battle!=null:show_battle()
  ui.toast("记录已恢复。" if saves.last_error.is_empty() else saves.last_error)
 else: ui.toast(saves.last_error)
func show_settings() -> void:
 pause("设置 / 每一种理解都有自己的节奏")
 var check: CheckButton=CheckButton.new();check.text="降低闪烁与视觉干扰";check.button_pressed=settings.reduced_effects;ui.body.add_child(check)
 check.toggled.connect(func(value: bool) -> void:settings.reduced_effects=value;settings.save())
 ui.label("音量",17)
 var volume: HSlider=HSlider.new();volume.min_value=0;volume.max_value=1;volume.step=0.05;volume.value=settings.volume;ui.body.add_child(volume)
 volume.value_changed.connect(func(value: float) -> void:settings.volume=value;settings.apply();settings.save())
 ui.label("点击一项后按新键；冲突按键会交换。",17)
 var grid: GridContainer=GridContainer.new();grid.columns=3;ui.body.add_child(grid)
 for action: String in InputSettings.DEFAULTS:
  var button: Button=ui.button(InputSettings.LABELS[action]+"  ["+settings.display(action)+"]",func() -> void:
   rebind_action=action;ui.toast("请按下新的按键："+InputSettings.LABELS[action]),grid)
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 ui.button("读取最近存档",load_game)
 footer_button()

func confirm_new_game() -> void:
 if FileAccess.file_exists(saves.path):
  pause("开始新记录", "当前进度会被新记录替换；上一份存档保留为备份。")
  ui.button("确定开始新记录",new_game)
  ui.button("继续已有记录",load_game)
 else: new_game()
func new_game() -> void:
 session=GameSession.new(content)
 session.changed.connect(update_hud);session.notice.connect(ui.toast)
 experimental_vacuum=false;experimental_shape="flat"
 load_room();session.set_checkpoint();ui.close();save_game(false)
