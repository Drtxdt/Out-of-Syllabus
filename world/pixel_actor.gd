class_name PixelActor
extends CharacterBody2D
var facing: String = "down"
var moving: bool = false
var clock: float = 0.0
var echo: bool = false
var tint: Color = Color("68cec5")
func _process(delta: float) -> void:
 clock += delta
 queue_redraw()
func _draw() -> void:
 var stride: int = (1 if int(clock*8.0)%2 == 0 else -1) if moving else 0
 var body: Color = tint if not echo else Color("debd76")
 draw_rect(Rect2(-7,2,14,4),Color(0.03,0.06,0.08,0.7))
 draw_rect(Rect2(-6,-17,12,15),body)
 draw_rect(Rect2(-5,-28,10,11),Color("e2c6a4") if not echo else body)
 draw_rect(Rect2(-6,-30,12,5),Color("263742"))
 draw_rect(Rect2(-5,-3,4,7+stride),Color("263742"))
 draw_rect(Rect2(1,-3,4,7-stride),Color("263742"))
 draw_rect(Rect2(-9,-15,3,10-stride),body.darkened(0.15))
 draw_rect(Rect2(6,-15,3,10+stride),body.darkened(0.15))
 if facing != "up":
  var eye_x: int = -3 if facing == "left" else 2
  draw_rect(Rect2(eye_x,-23,2,2),Color("14212b"))
 if echo:
  for y: int in range(-30,5,4): draw_line(Vector2(-9,y),Vector2(9,y),Color("0c141d"),1)
