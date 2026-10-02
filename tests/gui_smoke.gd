extends SceneTree
var game: Control
var failures: Array[String]=[]
func _initialize() -> void:
 call_deferred("run")
func capture(label: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png("res://reports/"+label+".png")
 if error != OK: failures.append("screenshot "+label)
func run() -> void:
 game=load("res://app/main.tscn").instantiate()
 game.suppress_intro=true
 root.add_child(game)
 game.saves=SaveStore.new("user://gui_smoke.json")
 for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
  root.size=size
  game.show_welcome()
  await capture("welcome_%d" % size.y)
 game.close_modal()
 game.session.command("switch","switch_a",{"expected":false,"value":true})
 game.session.command("visit","storage");game.load_room()
 game.session.command("switch","switch_b",{"expected":false,"value":true})
 game.session.command("pickup","kit")
 game.session.command("visit","lab");game.load_room();game.show_experiment()
 await capture("experiment")
 game.session.command("experiment","lab_drop");game.session.command("knowledge","observation")
 game.close_modal();game.session.next_cycle();game.load_room()
 game.session.advance(600)
 game.session.command("visit","lab");game.load_room();game.begin_battle("mass")
 for card: String in ["observe","control","measurement","gravity"]: game.play_card(card)
 if not game.session.battle.state.won: failures.append("mass battle")
 game.session.finish_battle();game.ui.close();game.session.next_cycle();game.load_room()
 game.session.advance(1200);game.session.command("switch","pump",{"value":true})
 game.session.command("visit","lab");game.load_room();game.begin_battle("drag")
 for card: String in ["observe","control","measurement","gravity","shape","vacuum"]: game.play_card(card)
 await capture("model")
 game.play_card("drag")
 if not game.session.battle.state.won: failures.append("drag battle")
 game.session.finish_battle();game.ui.close();game.session.command("visit","archive");game.load_room();game.show_finale()
 await capture("choice")
 game.finish_chapter(true)
 await capture("ending")
 game.show_settings();await capture("settings")
 game.close_modal()
 for room: Dictionary in game.content.chapter.rooms:
  game.session.command("visit",room.id);game.load_room();game.update_echoes();await capture("room_"+room.id)
 game.save_game(false);game.load_game()
 if not game.session.profile.completed: failures.append("restore ending")
 print("GUI_SMOKE: six rooms, three resolutions, model battles, ending, save; failures=",failures)
 game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
