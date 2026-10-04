extends Node2D
## Editable geometric presentation placeholders; no causal or collision decisions.
var objects: Array=[]
var active_id: String=""
var powered: bool=true

func render(items: Array,nearby_id: String) -> void:
 if objects==items and active_id==nearby_id:return
 objects=items.duplicate(true);active_id=nearby_id;queue_redraw()

func _draw() -> void:
 var font: Font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
 for value: Variant in objects:
  var item: Dictionary=value
  var at: Vector2=Vector2(float(item.x),float(item.y))
  var color: Color=Color("e1bc78") if str(item.id)==active_id else Color("92c6bb")
  match str(item.kind):
   "exit":
    draw_rect(Rect2(at+Vector2(-14,-22),Vector2(28,28)),Color("172930"));draw_rect(Rect2(at+Vector2(-14,-22),Vector2(28,28)),color,false,2)
    draw_line(at+Vector2(-7,-6),at+Vector2(7,-6),color,2)
   "enemy":
    draw_polygon(PackedVector2Array([at+Vector2(-14,0),at+Vector2(-9,-28),at+Vector2(9,-28),at+Vector2(14,0)]),Color("6f4a3a"))
    draw_rect(Rect2(at+Vector2(-7,-21),Vector2(4,3)),color);draw_rect(Rect2(at+Vector2(3,-21),Vector2(4,3)),color)
   _:
    draw_rect(Rect2(at+Vector2(-15,-20),Vector2(30,25)),Color("172930"));draw_rect(Rect2(at+Vector2(-15,-20),Vector2(30,25)),color,false,2)
    draw_rect(Rect2(at+Vector2(-8,-14),Vector2(16,8)),color)
  if str(item.id)==active_id:draw_arc(at,21,0,TAU,24,color,1)
  var title: String=str(item.title)
  draw_string(font,at+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2,20),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
