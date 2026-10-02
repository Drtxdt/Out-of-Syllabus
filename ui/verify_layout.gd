extends SceneTree
## Headless Control geometry checks. Does not replace rendered screenshot QA.
var failures: int = 0

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func settle() -> void:
 for frame: int in range(4): await process_frame

func run() -> void:
 var records: Array = []
 for index: int in range(40):
  records.append({"id":"c1:e%s" % index,"source_event_id":"c1:e%s" % index,"cycle":1,"observed_by_player":true,"setup":{"experiment":"mass","medium":"air"},"observations":{"arrival_times_s":[0.64,0.64],"tolerance_s":0.01}})
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1920,1080),Vector2i(960,540)]:
  var viewport: SubViewport = SubViewport.new()
  viewport.size = dimensions
  root.add_child(viewport)
  var ui: GameUI = load("res://ui/game_ui.tscn").instantiate()
  viewport.add_child(ui)
  var world: SubViewportContainer = SubViewportContainer.new()
  world.set_script(load("res://app/world_frame.gd"))
  var world_viewport: SubViewport = SubViewport.new()
  world_viewport.size = Vector2i(640,360)
  world.add_child(world_viewport)
  viewport.add_child(world)
  for title: String in ["因果面板","实验日志","卡组","等待关键动作","检查点","保存","设置"]:
   ui.button(title,func() -> void: pass,ui.toolbar).add_theme_font_size_override("font_size",16)
  ui.open("实验台 / 条件与证据")
  var view: VBoxContainer = load("res://ui/experiment_view.tscn").instantiate()
  ui.body.add_child(view)
  view.call("render", {"records":records,"pending":{},"cycle":1})
  await settle()
  var expected_scale: int = int(minf(dimensions.x / 640.0, dimensions.y / 360.0))
  check(world.scale == Vector2.ONE * expected_scale, "%s integer world scale" % dimensions)
  check(world.position == ((Vector2(dimensions) - Vector2(640,360) * expected_scale) / 2).floor(), "%s centered world margins" % dimensions)
  check(world_viewport.size == Vector2i(640,360), "%s fixed world resolution" % dimensions)
  check(ui.size == Vector2(dimensions) and ui.scale == Vector2.ONE, "%s native independent UI" % dimensions)
  var scroll: ScrollContainer = ui.get_node("Modal/Margin/Scroll")
  var release: Button = view.get_node("ReleaseExperiment")
  var release_bottom: float = release.get_global_rect().end.y
  var visible_bottom: float = scroll.get_global_rect().end.y
  print("LAYOUT ",dimensions," toolbar=",ui.toolbar.size.x," modal=",ui.panel.size," release_bottom=",release_bottom," visible_bottom=",visible_bottom," body=",ui.body.size)
  check(ui.toolbar.get_global_rect().end.x <= dimensions.x, "%s toolbar remains on-screen" % dimensions)
  check(ui.body.size.x <= scroll.size.x, "%s experiment avoids horizontal overflow" % dimensions)
  check(release_bottom <= visible_bottom, "%s release visible above 40 records" % dimensions)
  var close: Button = view.get_node("CloseExperiment")
  close.grab_focus()
  await settle()
  print("FOCUS ",dimensions," bottom=",close.get_global_rect().end.y," visible=",visible_bottom," scroll=",scroll.scroll_vertical)
  check(close.get_global_rect().end.y <= visible_bottom + 1, "%s keyboard focus scrolls into view" % dimensions)
  ui.open("论证桌 / 用证据检验模型")
  await settle()
  check(scroll.scroll_vertical == 0, "%s new modal starts at top" % dimensions)
  var battle_view: VBoxContainer = load("res://ui/battle_view.tscn").instantiate()
  ui.body.add_child(battle_view)
  var cards: Array = []
  for index: int in range(8): cards.append({"id":"card%s" % index,"title":"测量与独立重复实验","description":"比较控制变量条件，引用已读取的实测记录。","enabled":true})
  var battle_data: Dictionary = {"records":records,"state":{"round":1,"actions":2},"cards":cards,"conditions":[{"id":"mass_independence","status":"unsupported","reason":"需要控制变量的实测证据"}]}
  battle_view.call("render",battle_data)
  await settle()
  var last_card: Button = battle_view.get_node("Cards/Card_card7")
  last_card.grab_focus()
  await settle()
  check(last_card.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "%s last card accessible by keyboard" % dimensions)
  var old_scroll: int = scroll.scroll_vertical
  battle_view.call("render",battle_data)
  await settle()
  check(scroll.scroll_vertical == old_scroll, "%s card redraw preserves scroll" % dimensions)
  check(viewport.gui_get_focus_owner() == battle_view.get_node("Cards/Card_card7"), "%s card redraw preserves semantic focus" % dimensions)
  check(ui.body.size.x <= scroll.size.x, "%s cards avoid horizontal overflow" % dimensions)
  viewport.queue_free()
  await settle()
 print("UI_LAYOUT_CHECKS failures=",failures)
 quit(1 if failures else 0)
