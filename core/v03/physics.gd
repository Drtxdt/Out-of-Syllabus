extends RefCounted
## One fixed-step SI solver for observations, previews and animation.
const VERSION: int = 2
static var _cache: Dictionary = {}

static func setup(id: String, shape: String = "flat", height: float = 2.0, velocity: float = 0.0, medium: String = "air") -> Dictionary:
 if not id in ["paper", "left", "right", "weight"] or not shape in ["flat", "crumpled"] or not medium in ["air", "vacuum"]: return {}
 if not is_finite(height) or not is_finite(velocity) or height < 0.25 or height > 8.0 or absf(velocity) > 5.0: return {}
 return {"id":id,"shape":shape if id=="paper" else "solid","height":height,"initial_velocity":velocity,"medium":medium,"mass":0.002 if id=="paper" else (0.02 if id=="right" else 0.08),"area":0.006 if id=="paper" and shape=="flat" else 0.00025,"coefficient":0.47}

static func trace(config: Dictionary) -> Dictionary:
 if not config.has_all(["id","shape","height","initial_velocity","medium"]): return {}
 if not config.id is String or not config.shape is String or not config.medium is String or not numeric(config.height) or not numeric(config.initial_velocity): return {}
 var canonical: Dictionary=setup(config.id,"flat" if config.shape=="solid" else config.shape,float(config.height),float(config.initial_velocity),config.medium)
 if canonical.is_empty() or not equivalent(canonical,config): return {}
 config=canonical
 var key: String=JSON.stringify(config)+str(VERSION)
 if _cache.has(key): return _cache[key].duplicate(true)
 var height: float=float(config.height)
 var y: float=0.0
 var v: float=float(config.initial_velocity)
 var elapsed: float=0.0
 var points: Array=[[0.0,0.0,v]]
 var k: float=(1.225 if config.medium=="air" else 0.0)*0.5*float(config.coefficient)*float(config.area)/float(config.mass)
 var arrived: bool=false
 for step: int in range(120000):
  var old_y: float=y
  var mid_v: float=v+(9.81-k*v*absf(v))*0.0005
  y+=mid_v*0.001
  v+=(9.81-k*mid_v*absf(mid_v))*0.001
  if y>=height:
   elapsed+=0.001*(height-old_y)/(y-old_y)
   points.append([elapsed,height,v]);arrived=true;break
  elapsed+=0.001
  if step%16==15: points.append([elapsed,y,v])
 if not arrived: return {}
 var result: Dictionary={"version":VERSION,"setup":config.duplicate(true),"hash":key.sha256_text(),"points":points,"arrival_s":elapsed,"tolerance_s":0.01}
 if _cache.size()>256: _cache.clear()
 _cache[key]=result.duplicate(true)
 return result

static func distance_at(trace_data: Dictionary, seconds: float) -> float:
 if trace_data.is_empty(): return 0.0
 var points: Array=trace_data.points
 for i: int in range(1,points.size()):
  if seconds<=float(points[i][0]):
   var span: float=float(points[i][0])-float(points[i-1][0])
   return lerpf(float(points[i-1][1]),float(points[i][1]),clampf((seconds-float(points[i-1][0]))/span,0.0,1.0))
 return float(trace_data.setup.height)

static func valid_trace(value: Variant) -> bool:
 if not value is Dictionary or not value.has_all(["version","setup","hash","points","arrival_s","tolerance_s"]): return false
 var c: Variant=value.setup
 if not c is Dictionary or not c.has_all(["id","shape","height","initial_velocity","medium"]): return false
 if not c.id is String or not c.shape is String or not c.medium is String: return false
 if not numeric(c.height) or not numeric(c.initial_velocity): return false
 var canonical: Dictionary=setup(c.id,"flat" if c.shape=="solid" else c.shape,float(c.height),float(c.initial_velocity),c.medium)
 if canonical.is_empty() or not equivalent(canonical,c): return false
 return equivalent(trace(canonical),value)

static func equivalent(left: Variant, right: Variant) -> bool:
 if numeric(left) and numeric(right): return absf(float(left)-float(right))<=0.00000001
 if left is Dictionary and right is Dictionary:
  if left.size()!=right.size(): return false
  for key: Variant in left:
   if not right.has(key) or not equivalent(left[key],right[key]): return false
  return true
 if left is Array and right is Array:
  if left.size()!=right.size(): return false
  for i: int in range(left.size()):
   if not equivalent(left[i],right[i]): return false
  return true
 return typeof(left)==typeof(right) and left==right

static func numeric(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func semantic_hash(value: Variant) -> String:
 # Position precision is 0.0001 px for this fingerprint; integral event/tick
 # identities are additionally validated exactly. JSON may round float text.
 return JSON.stringify(_hash_value(value),"",true).sha256_text()

static func _hash_value(value: Variant) -> Variant:
 if numeric(value): return "number:%.4f" % float(value)
 if value is Dictionary:
  var result: Dictionary={}
  for key: Variant in value: result[key]=_hash_value(value[key])
  return result
 if value is Array:
  var result: Array=[]
  for item: Variant in value: result.append(_hash_value(item))
  return result
 return value
