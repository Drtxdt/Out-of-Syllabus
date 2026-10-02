extends SubViewportContainer
## The world uses a fixed pixel grid; UI remains in native window coordinates.
const WORLD_SIZE: Vector2 = Vector2(640, 360)

func _ready() -> void:
 stretch = false
 set_anchors_preset(Control.PRESET_TOP_LEFT)
 size = WORLD_SIZE
 get_viewport().size_changed.connect(fit_window)
 fit_window()

func fit_window() -> void:
 var available: Vector2 = get_viewport_rect().size
 var integer_scale: int = maxi(1, int(floor(minf(available.x / WORLD_SIZE.x, available.y / WORLD_SIZE.y))))
 scale = Vector2.ONE * integer_scale
 position = ((available - WORLD_SIZE * integer_scale) * 0.5).floor()
