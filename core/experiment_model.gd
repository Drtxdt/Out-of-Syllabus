class_name ExperimentModel
extends RefCounted
# SI units. Small fixed integration steps, never render/physics-frame dependent.
static func fall_time(height: float, mass: float, area: float, density: float = 1.225, coefficient: float = 0.47) -> float:
 if height <= 0.0 or mass <= 0.0 or area < 0.0 or density < 0.0 or coefficient < 0.0:
  return -1.0
 if density == 0.0 or area == 0.0:
  return sqrt(2.0 * height / 9.81)
 var dt: float = 1.0 / 1000.0
 var y: float = 0.0
 var v: float = 0.0
 var t: float = 0.0
 var k: float = 0.5 * density * coefficient * area / mass
 for _i: int in range(120000):
  var old_y: float = y
  var a: float = 9.81 - k * v * absf(v)
  var mid_v: float = v + a * dt * 0.5
  y += mid_v * dt
  v += (9.81 - k * mid_v * absf(mid_v)) * dt
  if y >= height:
   return t + dt * (height - old_y) / (y - old_y)
  t += dt
 return -1.0
static func comparison(vacuum: bool, shape: String) -> Dictionary:
 var ball: ExperimentDef = load("res://content/experiments/ball.tres") as ExperimentDef
 var paper: ExperimentDef = load("res://content/experiments/paper.tres") as ExperimentDef
 var rho: float = 0.0 if vacuum else ball.air_density
 var area: float = paper.area_m2 if shape == "flat" else ball.area_m2
 return {"height": ball.height_m, "initial_velocity": 0.0, "vacuum": vacuum,
  "ball": fall_time(ball.height_m, ball.mass_kg, ball.area_m2, rho, ball.drag_coefficient),
  "paper": fall_time(ball.height_m, paper.mass_kg, area, rho, paper.drag_coefficient), "shape": shape}

static func setup(config: Dictionary) -> Dictionary:
 var kind: String = str(config.get("experiment",""))
 var medium: String = str(config.get("medium",""))
 var shape: String = str(config.get("shape","flat"))
 if not kind in ["initial","mass","shape"] or not medium in ["air","vacuum"] or not shape in ["flat","crumpled"]: return {}
 var heavy: Dictionary = {"id":"heavy_ball","mass_kg":0.08,"area_m2":0.00025,"coefficient":0.47}
 var light: Dictionary = {"id":"light_ball","mass_kg":0.02,"area_m2":0.00025,"coefficient":0.47}
 var flat: Dictionary = {"id":"flat_paper","mass_kg":0.002,"area_m2":0.006,"coefficient":0.47}
 var crumpled: Dictionary = {"id":"crumpled_paper","mass_kg":0.002,"area_m2":0.00025,"coefficient":0.47}
 var specimens: Array = [heavy,flat if shape=="flat" else crumpled]
 if kind=="mass": specimens=[heavy,light]
 if kind=="shape": specimens=[flat,crumpled]
 return {"experiment":kind,"medium":medium,"shape":shape,"height_m":2.0,"initial_velocity_m_s":0.0,"samples":specimens,"controlled_variables":["height","initial_velocity","medium"],"air_density":1.225 if medium=="air" else 0.0}

static func measure(conditions: Dictionary) -> Dictionary:
 var times: Array = []
 for specimen: Dictionary in conditions.samples:
  times.append(fall_time(conditions.height_m,specimen.mass_kg,specimen.area_m2,conditions.air_density,specimen.coefficient))
 return {"arrival_times_s":times,"comparison":"within_tolerance" if absf(times[0]-times[1])<=0.01 else "different","tolerance_s":0.01}
