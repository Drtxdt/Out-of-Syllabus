extends Node2D
## Editable code-native apparatus sample, in the 640x360 world coordinate system.
## Presentation only: integrator supplies power and valid occupancy projections.
var drop_fractions: Array = [0.0,0.0]
var powered: bool = true
var a_active: bool = false
var b_active: bool = false
var releasing: bool = false
const INK: Color = Color("111e28")
const FRAME: Color = Color("537879")
const PANEL: Color = Color("172930")
const LIGHT: Color = Color("92c6bb")
const GOLD: Color = Color("e1bc78")

func render(data: Dictionary) -> void:
 drop_fractions=data.get("drop_fractions",[0.0,0.0])
 powered = bool(data.get("powered", true))
 a_active = bool(data.get("a_active", false))
 b_active = bool(data.get("b_active", false))
 releasing = bool(data.get("releasing", false))
 queue_redraw()

func _draw() -> void:
 # Wire routes remain behind the three distinct instruments.
 var wire: Color = LIGHT if powered else FRAME
 draw_line(Vector2(144,136), Vector2(144,104), wire, 2)
 draw_line(Vector2(144,104), Vector2(464,104), wire, 2)
 draw_line(Vector2(464,104), Vector2(464,136), wire, 2)
 draw_line(Vector2(304,104), Vector2(304,128), wire, 2)
 _station(Vector2(144,144), a_active, "A")
 _station(Vector2(464,144), b_active, "B")
 draw_rect(Rect2(286,116,36,52), INK)
 draw_rect(Rect2(286,116,36,52), FRAME, false, 2)
 draw_rect(Rect2(292,122,24,36), PANEL)
 for y: int in range(126,158,6): draw_line(Vector2(314,y),Vector2(318,y),FRAME,1)
 draw_rect(Rect2(295,126+roundi(float(drop_fractions[0])*24),5,5), GOLD)
 draw_rect(Rect2(305,126+roundi(float(drop_fractions[1])*24),5,2), LIGHT)
 draw_rect(Rect2(286,168,36,6), FRAME)
 draw_rect(Rect2(294,177,20,3), GOLD if a_active and b_active and powered else FRAME)

func _station(at: Vector2, active: bool, letter: String) -> void:
 draw_rect(Rect2(at + Vector2(-17,-24),Vector2(34,40)), INK)
 draw_rect(Rect2(at + Vector2(-17,-24),Vector2(34,40)),FRAME,false,2)
 draw_rect(Rect2(at + Vector2(-12,-19),Vector2(24,12)),PANEL)
 draw_rect(Rect2(at + Vector2(-9,-16),Vector2(5,5)), LIGHT if active and powered else GOLD)
 for x: int in range(0,10,3): draw_rect(Rect2(at + Vector2(x,-16),Vector2(1,5)),FRAME)
 draw_rect(Rect2(at + Vector2(-9,0),Vector2(18,4)),GOLD)
 draw_rect(Rect2(at + Vector2(-2,-3),Vector2(4,10)),LIGHT if active else FRAME)
 # Pixel glyphs remain legible without a world font dependency.
 var points: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(2,1),Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(0,3),Vector2i(2,3)]
 if letter == "B": points.append(Vector2i(1,3))
 for point: Vector2i in points: draw_rect(Rect2(at + Vector2(-3,20) + Vector2(point)*2,Vector2(2,2)),GOLD)
