extends SceneTree
var failures: int = 0
func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 var record: Dictionary = {"id":"c1:e1", "source_event_id":"c1:e1", "cycle":1,"observed_by_player":true,"setup":{"experiment":"mass","medium":"air"},"observations":{"arrival_times_s":[0.64,0.64],"tolerance_s":0.01}}
 var samples: Dictionary = {
  "experiment":{"records":[record],"pending":{},"pump":false,"cycle":1},
  "battle":{"state":{"round":1,"actions":2},"records":[record],"cards":[{"id":"measure","title":"精密测量","enabled":true}],"conditions":[{"id":"evidence","status":"unsupported","reason":"需要引用记录"}]},
  "causal":{"tick":60,"histories":[{"cycle":1,"next_tick":120,"action":"维持 A"}],"holds":{},"deviations":[],"can_retry":true}}
 for key: String in samples:
  var scene: PackedScene = load("res://ui/%s_view.tscn" % key)
  check(scene != null, key + " scene loads")
  var view: VBoxContainer = scene.instantiate()
  root.add_child(view)
  view.call("render", samples[key])
  await process_frame
  if key == "experiment":
   view.size.x = 920
   await process_frame
   check(view.get_node("ReleaseExperiment").position.y < 350, "release stays within compact configuration area")
   var choice: Button = view.get_node("ExperimentChoices/Experiment_mass") as Button
   choice.grab_focus()
   choice.pressed.emit()
   await process_frame
   check(root.gui_get_focus_owner() == view.get_node("ExperimentChoices/Experiment_mass"), "configuration focus survives selection")
  if key == "battle":
   var evidence: CheckBox = view.get_node("Evidence_c1_e1") as CheckBox
   check(evidence != null, "stable evidence node")
   evidence.grab_focus()
   evidence.button_pressed = true
   await process_frame
   var card: Button = view.get_node("Cards/Card_measure") as Button
   var received: Array = []
   view.connect("action_requested", func(kind: String, target: String, payload: Dictionary) -> void: received.append([kind,target,payload]))
   card.pressed.emit()
   check(received.size() == 1 and received[0][2].evidence_ids == ["c1:e1"], "selected evidence emitted with card")
   check(root.gui_get_focus_owner() == view.get_node("Evidence_c1_e1"), "semantic focus survives rerender")
  view.queue_free()
  await process_frame
 print("UI_VIEW_CHECKS failures=", failures)
 quit(1 if failures else 0)
