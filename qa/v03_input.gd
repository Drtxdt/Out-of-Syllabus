extends SceneTree
## Editor CLI wrapper. Exported templates start the same Node driver through main.
func _initialize() -> void:
 call_deferred("_boot")
func _boot() -> void:
 var driver: Node=preload("res://qa/v03_input_driver.gd").new()
 root.add_child(driver)
 driver.start()
