extends "res://tests/v03_test_base.gd"
const Physics=preload("res://core/v03/physics.gd")
func run_cases() -> void:
 suite="v03-physics"
 for id: String in ["paper","left","right","weight"]:
  for medium: String in ["air","vacuum"]:
   for height: float in [0.25,1.0,2.0,3.5,8.0]:
    var setup: Dictionary=Physics.setup(id,"flat",height,0.0,medium)
    var trace: Dictionary=Physics.trace(setup)
    check(not trace.is_empty(),"trajectory exists "+id+" "+medium+" "+str(height))
    if trace.is_empty(): continue
    check(Physics.valid_trace(trace),"authoritative trace validates")
    check(Physics.valid_trace(JSON.parse_string(JSON.stringify(trace))),"trace survives JSON numerical roundtrip "+id+" "+medium+" "+str(height))
    check(absf(float(trace.points.back()[1])-height)<0.000001,"arrival endpoint equals release height")
    check(absf(Physics.distance_at(trace,trace.arrival_s)-height)<0.000001,"animation and arrival share endpoint")
    if medium=="vacuum":check(absf(trace.arrival_s-sqrt(2.0*height/9.81))<0.00001,"vacuum matches analytic fall")
 for height: float in [-1.0,0.0,0.249,8.001,INF,NAN]:check(Physics.setup("paper","flat",height).is_empty(),"invalid height "+str(height))
 for velocity: float in [-5.001,5.001,INF,NAN]:check(Physics.setup("paper","flat",2.0,velocity).is_empty(),"invalid velocity "+str(velocity))
 for id: String in ["","unknown"]:check(Physics.setup(id).is_empty(),"unknown specimen rejected")
 check(Physics.setup("paper","unknown").is_empty(),"unknown shape rejected")
 check(Physics.setup("paper","flat",2.0,0.0,"water").is_empty(),"unknown medium rejected")
 var flat: Dictionary=Physics.setup("paper","flat")
 var crumpled: Dictionary=Physics.setup("paper","crumpled")
 check(flat.mass==crumpled.mass and flat.id==crumpled.id,"shape change preserves mass and specimen identity")
 check(Physics.trace(flat).arrival_s>Physics.trace(crumpled).arrival_s,"air shape changes actual arrival")
 check(is_equal_approx(Physics.trace(Physics.setup("paper","flat",2,0,"vacuum")).arrival_s,Physics.trace(Physics.setup("paper","crumpled",2,0,"vacuum")).arrival_s),"vacuum removes aerodynamic shape timing advantage")
 var stationary: Dictionary=Physics.trace(flat)
 var downward: Dictionary=Physics.trace(Physics.setup("paper","flat",2.0,2.0))
 var upward: Dictionary=Physics.trace(Physics.setup("paper","flat",2.0,-2.0))
 check(downward.arrival_s<stationary.arrival_s and upward.arrival_s>stationary.arrival_s,"initial velocity influences trace in correct direction")
 var before: String=canonical(stationary)
 var mutated: Dictionary=Physics.trace(flat)
 mutated.points[0][1]=999.0
 check(canonical(Physics.trace(flat))==before,"cached trace returns isolated copy")
 check(not Physics.valid_trace(mutated),"changed point cannot masquerade as observation")
 mutated=stationary.duplicate(true);mutated.arrival_s+=0.1
 check(not Physics.valid_trace(mutated),"changed arrival rejected")
 mutated=stationary.duplicate(true);mutated.version=999
 check(not Physics.valid_trace(mutated),"future simulator version rejected")
 var malformed: Dictionary=flat.duplicate(true);malformed.height=-1.0
 check(Physics.trace(malformed).is_empty(),"trace rejects config bypassing setup height limits")
 malformed=flat.duplicate(true);malformed.medium="water"
 check(Physics.trace(malformed).is_empty(),"trace rejects unknown physical medium")
