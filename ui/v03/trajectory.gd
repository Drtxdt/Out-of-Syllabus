extends Control
## Draws only the supplied physical state or precomputed trace.
var data: Dictionary={}
var progress: float=1.0
func render(value: Dictionary,playback: float=1.0) -> void:
 data=value.duplicate(true);progress=playback;queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("172930"))
 var font: Font=get_theme_default_font()
 var objects: Dictionary=data.get("objects",{})
 if objects.is_empty():objects={"paper":{"title":"同一张纸","shape":data.get("shape","flat"),"height":2.0,"lane":1}}
 var count: int=0
 for id: String in objects:
  var object: Dictionary=objects[id]
  var x: float=size.x*(count+1.0)/(objects.size()+1.0)
  var height: float=float(object.get("height",2.0))
  var y: float=size.y-26-clampf(height/3.5,0,1)*(size.y-52)
  var trace: Dictionary=data.get("trace",{})
  var duration: float=float(trace.get("arrival_s",0))
  for candidate: Dictionary in data.get("traces",[]):
   duration=maxf(duration,float(candidate.get("arrival_s",0)))
   if str(candidate.get("id",""))==id:trace=candidate
  if trace.has("points"):
   var points: Array=trace.points
   var sample_time: float=progress*duration
   var sample: Array=[]
   for point: Array in points:
    if float(point[0])>sample_time:break
    sample=point
   if not sample.is_empty():y=size.y-26-clampf((float(trace.get("setup",{}).get("height",height))-float(sample[1]))/3.5,0,1)*(size.y-52)
  draw_line(Vector2(x-35,size.y-22),Vector2(x+35,size.y-22),Color("537879"),2)
  draw_line(Vector2(x+28,8),Vector2(x+28,size.y-26),Color("426069"),1)
  for mark: int in range(1,4):
   var mark_y: float=size.y-26-float(mark)/3.5*(size.y-52)
   draw_line(Vector2(x+24,mark_y),Vector2(x+31,mark_y),Color("92c6bb"),1)
  var paper: bool=str(object.get("kind","paper"))=="paper"
  var width: float=30 if paper and str(object.get("shape","flat"))=="flat" else 12
  draw_rect(Rect2(x-width/2,y,width,6 if width>12 else 12),Color("d8e2dd") if paper else Color("e1bc78"))
  if bool(object.get("held",false)):draw_line(Vector2(x,y-8),Vector2(x,8),Color("e1bc78"),2)
  var text_width: float=minf(230,size.x/(objects.size()+1.0))
  draw_string(font,Vector2(x-text_width/2,size.y-4),str(object.get("title",id))+" %.1f m"%height,HORIZONTAL_ALIGNMENT_LEFT,text_width,14)
  count+=1
 if data.has("phase") and data.has("door_until"):
  var gate_x: float=size.x-100
  var success: bool=bool(data.get("door_open",false))
  draw_rect(Rect2(gate_x,20,58,size.y-54),Color("111e28"))
  draw_rect(Rect2(gate_x,20,58,size.y-54),Color("537879"),false,2)
  draw_rect(Rect2(gate_x+4,24,50,8 if success else size.y-62),Color("92c6bb") if success else Color("6f4a3a"))
  draw_string(font,Vector2(gate_x-15,size.y-8),"延时锁扣" if success else "计时门",HORIZONTAL_ALIGNMENT_LEFT,100,14)
