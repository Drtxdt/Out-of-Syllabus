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
