extends SceneTree
## Editor entry point; the exported build uses the same input-only driver.
func _initialize() -> void:
 if RuntimePaths.profile_id().is_empty(): quit(2);return
 call_deferred("run")
func run() -> void:
 var app: Node=load("res://app/main.tscn").instantiate()
 root.add_child(app)
 var driver: Node=Node.new()
 driver.set_script(load("res://qa/input_driver.gd"))
 app.add_child(driver)
