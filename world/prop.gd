class_name WorldProp
extends Node2D
@export var object_id: String = ""
@export var kind: String = "board"
var active: bool = false
func _draw() -> void:
 var c: Color = Color("d6b776") if active else Color("52757a")
 match kind:
  "exit":
   draw_rect(Rect2(-18,-25,36,33),Color("121f2c"))
   draw_rect(Rect2(-18,-25,36,33),c,false,2)
   draw_line(Vector2(-7,-7),Vector2(7,-7),c,2)
   draw_line(Vector2(3,-12),Vector2(8,-7),c,2)
   draw_line(Vector2(3,-2),Vector2(8,-7),c,2)
  "npc":
   draw_rect(Rect2(-7,-16,14,19),Color("b68a72"));draw_rect(Rect2(-5,-29,10,11),Color("d8c5aa"))
   draw_rect(Rect2(-6,-31,12,5),Color("253044"))
  "switch":
   draw_rect(Rect2(-12,-22,24,26),Color("192c35"));draw_rect(Rect2(-8,-18,16,12),c)
   draw_rect(Rect2(-2,-15,4,6),Color("ecdfb6"))
  "experiment":
   draw_rect(Rect2(-46,-7,92,16),Color("3c6970"));draw_line(Vector2(-26,-52),Vector2(-26,-6),c,3)
   draw_line(Vector2(26,-52),Vector2(26,-6),c,3);draw_line(Vector2(-26,-52),Vector2(26,-52),c,3)
   draw_circle(Vector2(-12,-37),5,Color("d5ded5"));draw_rect(Rect2(9,-40,8,3),Color("e8d7a0"))
  "crate":
   draw_rect(Rect2(-14,-24,28,28),Color("8e7557"));draw_rect(Rect2(-11,-21,22,22),Color("b09b71"),false,2)
   draw_line(Vector2(-10,-20),Vector2(10,0),Color("b09b71"),2)
  "hazard":
   if not active:
    draw_line(Vector2(-12,-10),Vector2(-3,-22),Color("d89a65"),3)
    draw_line(Vector2(-3,-22),Vector2(2,-6),Color("d89a65"),3)
    draw_line(Vector2(2,-6),Vector2(13,-20),Color("d89a65"),3)
  "pickup":
   if not active: draw_rect(Rect2(-12,-18,24,20),Color("cbb779"));draw_rect(Rect2(-4,-12,8,3),Color("34484e"))
  _:
   draw_rect(Rect2(-16,-24,32,28),Color("1a2b35"));draw_rect(Rect2(-12,-20,24,16),c)
   for y: int in [-16,-11]: draw_line(Vector2(-8,y),Vector2(8,y),Color("d7d4ae"),1)
