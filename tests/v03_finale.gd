extends "res://tests/v03_session.gd"
func finale_fixture() -> Variant:
 var s: Variant=session_new()
 at(s,"classroom","paper")
 s.command("paper_shape","paper",{"shape":"flat"});s.command("release","paper");s.advance(120);s.command("observe","paper")
 # Explicit domain fixture: end-chapter access, not an input-playthrough claim.
 s.state.cycle=3;s.state.flags.patrol=true;s.state.flags.rig_demo=true;s.state.flags.hammer=true;s.state.flags.joint=true;s.state.flags.bellows=true
 at(s,"archive","archive_terminal")
 return s
func run_cases() -> void:
 suite="v03-finale"
 var s: Variant=finale_fixture()
 check(s.command("choose_future","archive_terminal",{"accept":true}).ok,"accept future knowledge")
 check(not s.state.finale.used and s.state.finale.violations==0,"choice alone no ability use or violation")
 check(s.command("forecast","archive_terminal",{"model":"gravity","height":2.0,"medium":"air"}).ok,"wrong model remains selectable")
 at(s,"archive","fall_gate");denied(s,"gate_release","fall_gate")
 check(s.state.finale.prediction.model=="gravity","rejected gate cannot silently correct model")
 at(s,"archive","archive_terminal")
 check(s.command("forecast","archive_terminal",{"model":"drag","height":2.0,"medium":"air"}).ok,"valid forecast")
 check(s.state.finale.violations==0,"preview unpenalized")
 at(s,"archive","fall_gate")
 check(s.command("gate_release","fall_gate").ok,"actual future operation succeeds")
 check(s.state.finale.used and s.state.finale.violations==1,"actual operation settles one violation")
 check(s.command("gate_release","fall_gate").ok,"gate can be released again")
 check(s.state.finale.violations==1,"re-release cannot duplicate penalty")
 var r: Variant=finale_fixture()
 check(r.command("choose_future","archive_terminal",{"accept":false}).ok,"refuse future")
 check(r.command("calibrate","archive_terminal").ok,"existing observed record calibrates")
 check(r.state.finale.prediction.origin=="measurement","refusal uses measured origin")
 at(r,"archive","fall_gate");denied(r,"gate_release","fall_gate")
 at(r,"storage","calibration_marker");check(r.command("interact","calibration_marker").ok,"manual remote calibration")
 at(r,"archive","fall_gate");check(r.command("gate_release","fall_gate").ok,"calibrated refusal opens")
 check(not r.state.finale.used and r.state.finale.violations==0,"refusal never uses future ability")
 var empty: Variant=finale_fixture();empty.state.observations=[]
 empty.command("choose_future","archive_terminal",{"accept":false});denied(empty,"calibrate","archive_terminal")

