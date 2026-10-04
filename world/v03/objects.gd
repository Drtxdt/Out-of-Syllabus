extends Node2D
## Editable geometric presentation placeholders; no causal or collision decisions.
var objects: Array=[]
var active_id: String=""
var powered: bool=true
var context: Dictionary={}

func render(items: Array,nearby_id: String,projection: Dictionary={}) -> void:
 if objects==items and active_id==nearby_id and context==projection:return
 objects=items.duplicate(true);active_id=nearby_id;context=projection.duplicate(true);queue_redraw()

func _draw() -> void:
 var font: Font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
 for value: Variant in objects:
  var item: Dictionary=value
  var at: Vector2=Vector2(float(item.x),float(item.y))
  var engaged: bool=bool(item.get("active",false))
  var color: Color=Color("e1bc78") if str(item.id)==active_id else (Color("92c6bb") if engaged else Color("537879"))
  match str(item.kind):
   "gate":
    draw_rect(Rect2(at+Vector2(-20,-40),Vector2(40,45)),Color("172930"))
    draw_rect(Rect2(at+Vector2(-20,-40),Vector2(40,45)),color,false,2)
    if not bool(item.get("active",context.get("gate_open",false))):
     for x: int in range(-15,20,10):draw_rect(Rect2(at+Vector2(x,-35),Vector2(4,35)),Color("6f4a3a"))
    else:draw_rect(Rect2(at+Vector2(-15,-35),Vector2(30,5)),Color("92c6bb"))
   "paper","barrier":
    draw_rect(Rect2(at+Vector2(-20,0),Vector2(40,5)),Color("537879"))
    draw_line(at+Vector2(-17,-35),at+Vector2(-17,0),color,2)
    var flat: bool=context.get("shape","flat")=="flat" or item.kind=="barrier"
    draw_rect(Rect2(at+Vector2(-11,-22),Vector2(24,4) if flat else Vector2(10,10)),Color("d8e2dd"))
    if item.kind=="barrier":
     var fixed: bool=bool(item.get("fixed",false))
     if fixed:
      draw_line(at+Vector2(-12,-28),at+Vector2(-12,-16),Color("e1bc78"),3)
      draw_line(at+Vector2(13,-28),at+Vector2(13,-16),Color("e1bc78"),3)
      draw_rect(Rect2(at+Vector2(22,-10),Vector2(15,13)),Color("426069"),false,2)
     else:
      draw_line(at+Vector2(-10,-19),at+Vector2(12,-24),Color("d8e2dd"),3)
      draw_rect(Rect2(at+Vector2(22,-10),Vector2(15,13)),Color("b48655"))
    elif engaged:draw_rect(Rect2(at+Vector2(15,-12),Vector2(5,7)),Color("92c6bb"))
   "hold":
    draw_rect(Rect2(at+Vector2(-17,-29),Vector2(34,35)),Color("172930"))
    draw_rect(Rect2(at+Vector2(-17,-29),Vector2(34,35)),color,false,2)
    draw_rect(Rect2(at+Vector2(-10,-22),Vector2(20,9)),Color("92c6bb") if bool(item.get("active",context.get("holds",{}).has(item.id))) else Color("6f4a3a"))
    draw_line(at+Vector2(-9,-3),at+Vector2(9,-3),Color("e1bc78"),3)
   "bell":
    draw_colored_polygon(PackedVector2Array([at+Vector2(-13,-7),at+Vector2(-9,-26),at+Vector2(9,-26),at+Vector2(13,-7)]),Color("e1bc78"))
    draw_rect(Rect2(at+Vector2(-3,-5),Vector2(6,7)),color)
   "experiment","rig":
    draw_rect(Rect2(at+Vector2(-23,-40),Vector2(46,46)),Color("172930"));draw_rect(Rect2(at+Vector2(-23,-40),Vector2(46,46)),color,false,2)
    draw_rect(Rect2(at+Vector2(-14,-28),Vector2(9,9)),Color("e1bc78"));draw_rect(Rect2(at+Vector2(5,-28),Vector2(9,4)),Color("d8e2dd"))
    if engaged:draw_rect(Rect2(at+Vector2(-15,-8),Vector2(30,4)),Color("92c6bb"))
   "switch":
    draw_rect(Rect2(at+Vector2(-13,-24),Vector2(26,30)),Color("172930"));draw_rect(Rect2(at+Vector2(-5,-18),Vector2(10,12)),Color("92c6bb") if bool(item.get("active",context.get("powered",true))) else Color("6f4a3a"))
   "exit":
    draw_rect(Rect2(at+Vector2(-14,-22),Vector2(28,28)),Color("172930"));draw_rect(Rect2(at+Vector2(-14,-22),Vector2(28,28)),color,false,2)
    draw_line(at+Vector2(-7,-6),at+Vector2(7,-6),color,2)
   "enemy":
    draw_colored_polygon(PackedVector2Array([at+Vector2(-14,0),at+Vector2(-9,-28),at+Vector2(9,-28),at+Vector2(14,0)]),Color("6f4a3a"))
    draw_rect(Rect2(at+Vector2(-7,-21),Vector2(4,3)),color);draw_rect(Rect2(at+Vector2(3,-21),Vector2(4,3)),color)
   _:
    draw_rect(Rect2(at+Vector2(-15,-20),Vector2(30,25)),Color("172930"));draw_rect(Rect2(at+Vector2(-15,-20),Vector2(30,25)),color,false,2)
    draw_rect(Rect2(at+Vector2(-8,-14),Vector2(16,8)),color)
  if str(item.id)==active_id:draw_arc(at,21,0,TAU,24,color,1)
  var title: String=str(item.title)
  draw_string(font,at+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2,20),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)

