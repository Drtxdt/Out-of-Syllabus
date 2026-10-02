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
var active_view: Control
var view_kind: String = ""
var return_modal: String = ""
var rig_visual: Node2D
var examiner: PixelActor
var release_display: Label
func _ready() -> void:
 content = GameContent.new();session = GameSession.new(content);saves = SaveStore.new();settings = InputSettings.new()
 session.changed.connect(update_hud);session.notice.connect(ui.toast)
 for entry: Array in [["因果面板",show_causal],["实验日志",show_journal],["卡组",show_loadout],["等待关键动作",wait_five],["检查点",restore_checkpoint],["保存",save_game],["设置",show_settings]]:
  ui.button(entry[0],entry[1],ui.toolbar).add_theme_font_size_override("font_size",16)
 if ResourceLoader.exists("res://assets/audio/confirm.wav"): feedback_sound.stream = load("res://assets/audio/confirm.wav")
 load_room();session.set_checkpoint();session.cycle_checkpoint=session.snapshot()
 if not suppress_intro: show_welcome()
func load_room() -> void:
 if room_node != null:
  world_node.remove_child(room_node);room_node.queue_free()
 var scene: PackedScene = load("res://world/rooms/%s.tscn" % session.room_id)
 room_node = scene.instantiate() as Node2D;world_node.add_child(room_node);world_node.move_child(room_node,0)
 room_node.z_index = -1
 rig_visual=null
 if session.room_id=="lab":
  rig_visual=Node2D.new();rig_visual.set_script(load("res://world/lab_rig_visual.gd"));room_node.add_child(rig_visual)
 if examiner==null:
  examiner=load("res://world/player.tscn").instantiate() as PixelActor
  examiner.tint=Color("d88775");examiner.collision_layer=0;examiner.collision_mask=0;world_node.add_child(examiner)
 if release_display==null:
  release_display=Label.new();release_display.position=Vector2(218,60);release_display.add_theme_font_size_override("font_size",13);world_node.add_child(release_display)
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
  if prop.object_id=="fall_gate": prop.active=session.tick>=int(session.finale.open_tick) and session.tick<=int(session.finale.close_tick)
  if prop.object_id in ["assist_a","assist_b"]: prop.active=session.holds.has(prop.object_id)
  if prop.kind == "crate": prop.position.x = 224 + 32*int(session.world.crate)
  prop.queue_redraw()
 if rig_visual!=null: rig_visual.render({"powered":session.world.rig_power,"a_active":session.holds.has("assist_a"),"b_active":session.holds.has("assist_b"),"releasing":not session.pending_experiment.is_empty()})
 if examiner!=null:
  examiner.visible=session.finale.phase in ["warning","chase"] and session.finale.examiner_room==session.room_id
  examiner.position=Vector2(session.finale.examiner_position[0],session.finale.examiner_position[1]);examiner.moving=session.finale.phase=="chase"
 if release_display!=null:
  release_display.visible=not session.pending_experiment.is_empty() or (session.room_id=="corridor" and session.finale.phase in ["warning","chase","ready"])
  if not session.pending_experiment.is_empty(): release_display.text="测量中 · %.2f s" % (maxi(0,int(session.pending_experiment.finish_tick)-session.tick)/60.0)
  elif session.tick<int(session.finale.open_tick): release_display.text="落地还有 %.2f s" % ((int(session.finale.open_tick)-session.tick)/60.0)
  elif session.tick<=int(session.finale.close_tick): release_display.text="安全窗口 · %.1f s" % ((int(session.finale.close_tick)-session.tick)/60.0)
  else: release_display.text="靠近闸门交互释放"
func _physics_process(delta: float) -> void:
 if session == null or session.mode != "world":
  if player != null: player.moving = false
  return
 var input: Vector2 = Input.get_vector("move_left","move_right","move_up","move_down")
 if Input.is_action_just_pressed("dodge") and input.length_squared()>0: session.command("dodge", "player")
 dodge_time = maxf(0,dodge_time-delta);dodge_cooldown = maxf(0,dodge_cooldown-delta);hazard_cooldown = maxf(0,hazard_cooldown-delta)
 player.velocity = input * (235.0 if session.dodge_ticks>0 else 100.0)
 player.move_and_slide();player.moving = input.length_squared()>0
 player.position = player.position.clamp(Vector2(40,56),Vector2(600,306))
 if absf(input.x)>absf(input.y): player.facing = "left" if input.x<0 else "right"
 elif input.y != 0: player.facing = "up" if input.y<0 else "down"
 session.player_position = player.position;session.direction = player.facing
 session.advance(1,player.moving)
 update_echoes();update_props();update_nearest();update_hud()
 if session.finale.phase=="caught" and not ui.panel.visible:
  show_caught()
func show_caught() -> void:
 pause("监考者拦截 / 局部重试")
 ui.label("这次尝试失败了。恢复追逐前的记录，违规不会重复累加。",23)
 ui.button("恢复追逐检查点",func() -> void: restore_now())
 ui.focus_first()
func update_echoes() -> void:
 var poses: Array = session.echo_poses()
 while echo_nodes.size()<poses.size():
  var echo_actor: PixelActor = load("res://world/player.tscn").instantiate() as PixelActor
  echo_actor.echo = true;echo_actor.collision_layer = 0;echo_actor.collision_mask = 0
  world_node.add_child(echo_actor);echo_nodes.append(echo_actor)
 for i: int in range(echo_nodes.size()):
  echo_nodes[i].visible = i<poses.size()
  if i<poses.size():
   echo_nodes[i].tint=Color("e1bc78") if int(poses[i].cycle)==1 else Color("92aade")
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
  var response: Dictionary=session.command("gate_release","fall_gate")
  ui.toast(response.message)
func pause(title: String, subtitle: String = "") -> void:
 if session.mode=="model": return_modal="battle"
 if session.mode == "world": session.mode = "menu"
 view_kind=""
 ui.open(title,subtitle)
func close_modal() -> void:
 if return_modal=="battle" and session.battle!=null:
  return_modal="";show_battle();return
 if session.finale.phase=="caught": show_caught();return
 session.suspend_battle();ui.close();view_kind="";player.position=session.player_position
func footer_button() -> void:
 ui.button("返回现象界",close_modal);ui.focus_first()
func show_welcome() -> void:
 pause("超纲 / OUT OF SYLLABUS","序章 · 下坠  /  证据与回声 v0.2.0")
 ui.label("钟声响了。教室里的纸片还没有落地。
你记得这个瞬间，却不记得自己为何记得。",25)
 ui.label("探索同一座学校，提出模型，面对反例。世界可以重置，理解会留下。
移动靠近物体后按交互键；对话与论证期间世界暂停。")
 if FileAccess.file_exists(saves.path): ui.button("继续已有记录",load_game)
 ui.button("开始新的记录",confirm_new_game)
 ui.label("v0.2 使用独立记录，旧档和旧版游戏保留。世界角色目前是可编辑像素占位；实际试玩时长尚待验证。",16)
 ui.focus_first()
func interact(item: Dictionary) -> void:
 feedback_sound.play()
 match str(item.kind):
  "exit":
   var required: String = str(item.get("requires",""))
   if not required.is_empty() and not session.world.get(required,false):
    ui.toast("联锁门未开启：接通教室 A 与器材室 B。" if required=="lab_gate" else "先完成第三轮的阻力论证。");return
   var travel: Dictionary=session.command("visit",item.target)
   if not travel.ok: ui.toast(travel.message);return
   load_room();session.set_checkpoint();save_game(false)
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
  "hold":
   var action: String="hold_end" if session.holds.has(item.id) and session.holds[item.id].actor=="player" else "hold_begin"
   var result: Dictionary=session.command(action,item.id);ui.toast(result.message)
   if result.ok: save_game(false)
  "gate":
   var result: Dictionary=session.command("gate_release","fall_gate");ui.toast(result.message)
  "experiment": show_experiment()
  "compression":
   var result: Dictionary = session.compress_lab();update_props();update_echoes();ui.toast(result.message);save_game(false)
  "cycle": show_cycle()
  "finale": show_finale()
  "hazard": ui.toast("闪避通过，或在理解知识后按应用知识键隔离装置。")
func mount_view(kind: String,title: String) -> Control:
 if is_instance_valid(active_view) and not active_view.is_queued_for_deletion() and view_kind==kind and active_view.get_parent()==ui.body:
  return active_view
 pause(title)
 active_view=load("res://ui/%s_view.tscn" % kind).instantiate() as Control
 ui.body.add_child(active_view);active_view.action_requested.connect(view_action);view_kind=kind
 return active_view

func show_experiment() -> void:
 if not session.checkpoint_locked:
  session.set_checkpoint()
  if session.cycle>=2 and session.tick<7200: session.checkpoint_locked=true
 var view: Control=mount_view("experiment","实验台 / 条件与证据")
 view.render({"records":session.evidence,"pending":session.pending_experiment,"pump":session.world.pump,"cycle":session.cycle})
 for child: Node in ui.body.get_children():
  if child.name=="EnterBattle": ui.body.remove_child(child);child.queue_free()
 if session.cycle>=2:
  var encounter: String="mass" if session.cycle==2 else "drag"
  if not encounter in session.settled:
   var button: Button=ui.button("进入模型界 · "+content.encounters[encounter].title,func() -> void:begin_battle(encounter))
   button.name="EnterBattle"
 ui.focus_first()

func begin_battle(id: String) -> void:
 session.mode="world"
 if session.battle!=null and session.battle.definition.id==id and not session.battle.state.failed:
  if session.resume_battle(): show_battle()
  return
 if session.start_battle(id): show_battle();save_game(false)
 else:
  session.mode="menu";ui.toast("尚缺已读取的质量对照记录；第三轮还需要双回声真空记录。")

func show_battle() -> void:
 if session.battle==null: close_modal();return
 var view: Control=mount_view("battle","论证桌 / 用证据检验模型")
 session.resume_battle();return_modal=""
 var cards: Array=[]
 for id: String in ["observe","experiment"]+session.loadout:
  var candidate: ModelBattle=ModelBattle.new(session.battle.definition,session.evidence)
  candidate.state=session.battle.state.duplicate(true)
  var allowed: Dictionary=candidate.play(content.cards[id],view.selected_ids)
  cards.append({"id":id,"title":content.cards[id].title,"description":content.cards[id].description,"enabled":allowed.ok,"reason":"" if allowed.ok else allowed.message})
 view.render({"title":session.battle.definition.title,"question":session.battle.definition.question,"state":session.battle.state,"conditions":session.battle.conditions(),"records":session.evidence,"cards":cards})

func view_action(kind: String,target: String,payload: Dictionary) -> void:
 match kind:
  "selection_changed": show_battle()
  "close": return_modal="";close_modal()
  "experiment":
   var response: Dictionary=session.command(kind,target,payload)
   ui.toast(response.message)
   if response.ok: ui.close();view_kind="";save_game(false)
  "read_evidence":
   var response: Dictionary=session.command(kind,target,payload);ui.toast(response.message)
   if response.ok: show_experiment();save_game(false)
  "play_card":
   var response: Dictionary=session.play_card(target,payload.get("evidence_ids",[]));ui.toast(response.message);show_battle();save_game(false)
  "finish_battle":
   if session.finish_battle():
    return_modal="";close_modal();session.set_checkpoint();save_game(false)
  "start_battle": begin_battle(target)
  "wait_next": close_modal();wait_five()
  "rewind": restore_now()
  "restart_cycle":
   if session.restart_cycle(): load_room();return_modal="";close_modal();save_game(false)

func play_card(id: String) -> void:
 var ids: Array=[]
 if is_instance_valid(active_view) and view_kind=="battle": ids=active_view.selected_ids
 var response: Dictionary=session.play_card(id,ids);ui.toast(response.message);show_battle();save_game(false)

func show_causal() -> void:
 var view: Control=mount_view("causal","因果检查 / 三个自己的贡献")
 view.render(session.causal_view());ui.focus_first()

func restore_now() -> void:
 if session.rewind():
  load_room();ui.close();view_kind="";return_modal="";save_game(false)
  if session.mode=="model": show_battle()

func show_cycle() -> void:
 pause("观测记录 / 循环边界")
 if session.finale.phase=="escaped":
  ui.label("你已经亲手通过闸门。将实验记录、模型和回声贡献一并封存。",23)
  ui.button("提交序章记录",func() -> void:
   var response: Dictionary=session.command("ending","cycle_console")
   if response.ok: save_game(false);show_ending()
   else: ui.toast(response.message))
  footer_button();return
 if session.can_cycle():
  ui.label("结束本轮后，物品和装置恢复初始状态。你的知识与整轮行动会留下，成为下一轮可见的回声。",24)
  ui.button("封存第 %d 轮，醒来" % session.cycle,func() -> void:
   if session.next_cycle():
    ui.close();load_room();session.set_checkpoint();save_game(false);ui.toast("钟声再次响起。过去的你仍在路上。"))
 else: ui.label("尚未达到本轮的记录条件。
"+session.objective(),23)
 footer_button()
func show_finale() -> void:
 pause("封锁档案 / 未来知识","会不会、许不许、当前条件能不能用，是三件不同的事。")
 if not session.world.drag: ui.label("先完成阻力论证。");footer_button();return
 if session.profile.completed: show_ending();return
 if session.finale.phase=="none":
  ui.label("观测塔的落体闸门需要一个可核验的时机。你可以借用数值积分预测，也可以依靠已有实测记录校准。",24)
  ui.label("未来方法未获许可；实际使用后监考者将追踪你。选择本身不会完成章节。",18)
  ui.button("借用未来知识",func() -> void: finish_chapter(true))
  ui.button("拒绝调用 · 用实测校准",func() -> void: finish_chapter(false))
 elif session.finale.phase=="chosen":
  if session.finale.choice:
   ui.label("当前装置：2米，空气，展开纸片。选择模型；计算只在模型适用时有效。",22)
   ui.button("尝试忽略阻力的重力模型",func() -> void: use_finale("gravity"))
   ui.button("选择重力＋阻力模型并计算",func() -> void: use_finale("drag"))
  else:
   ui.label("引用同条件的空气实测；预测不能充当观察。",22)
   for record: Dictionary in session.evidence:
    if record.observed_by_player and record.setup.experiment=="initial" and record.setup.medium=="air" and record.setup.shape=="flat":
     ui.button("校准 · "+record.id,func() -> void:
      var result: Dictionary=session.command("calibrate_gate","future_terminal",{"evidence_id":record.id})
      ui.toast(result.message)
      if result.ok: return_modal="";close_modal();save_game(false))
 else: ui.label("准备已经完成：去走廊闸门亲手释放，进入观测塔提交。",22)
 footer_button()

func finish_chapter(accept: bool) -> void:
 var result: Dictionary=session.command("choose_future","future_terminal",{"accept":accept})
 ui.toast(result.message)
 if result.ok: save_game(false);show_finale()

func use_finale(model: String) -> void:
 var result: Dictionary=session.command("predict_gate","future_terminal",{"model":model,"medium":"air","shape":"flat"})
 ui.toast(result.message)
 if result.ok: return_modal="";close_modal();save_game(false)

func show_ending() -> void:
 pause("序章结束 / 记录仍在继续")
 var accepted: bool = session.profile.choices.get("future_card",false)
 ui.label("未经授权的计算引来了监考者。
你抓住了落体窗口，把追踪留在塔门之外。" if accepted else "你把实验条件写在了答案旁边。
钟声没有再响。至少这一次没有。",28)
 ui.label("你解释了一个现象，也找到了模型的边界。
你的过去确实参与了实验，你的选择也确实改变了这次脱离。
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
 var result: Dictionary=session.wait_next();update_echoes();update_props();update_hud();ui.toast(result.message)
func restore_checkpoint() -> void:
 if session.checkpoint.is_empty(): ui.toast("还没有检查点。");return
 pause("恢复因果检查点","只回退当前进度，已经封存的历史保持不变。")
 ui.button("恢复最近区域 / 实验检查点",func() -> void:
  if session.rewind():
   load_room();ui.close();view_kind="";return_modal="";save_game(false)
   if session.mode=="model":show_battle())
 footer_button()
func save_game(show_message: bool = true) -> void:
 var ok: bool=saves.save_session(session)
 if show_message or not ok: ui.toast("记录已保存。" if ok else saves.last_error)
func load_game() -> void:
 if saves.load_session(session):
  load_room();ui.close()
  if session.mode=="model":show_battle()
  elif session.finale.phase=="caught":show_caught()
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
 load_room();session.set_checkpoint();session.cycle_checkpoint=session.snapshot();ui.close();view_kind="";return_modal="";save_game(false)
