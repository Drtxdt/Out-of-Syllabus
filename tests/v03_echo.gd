extends "res://tests/v03_session.gd"
func rig(cycle: int=1) -> Variant:
 var s: Variant=session_new()
 s.state.flags.paper_door=true;s.state.cycle=cycle;s.state.flags.hammer=true;s.state.flags.patrol=true;s.state.flags.rig_demo=true;s.state.flags.seal_kit=true
 s.state.owned=["crumple","unfold","raise","release_pair","fix"]
 at(s,"lab","sync_bell")
 return s
func record_first(s: Variant) -> void:
 check(s.command("bell","sync_bell").ok,"first bell accepted without history")
 at(s,"lab","assist_a")
 check(s.command("hold","assist_a").ok,"first hold recorded")
 s.advance(660)
 check(s.state.attempt.phase=="success","zero history first recording succeeds")
 at(s,"tower","cycle_console")
 check(s.command("seal","cycle_console").ok,"seal first real segment")
func run_cases() -> void:
 suite="v03-echo"
 var s: Variant=rig()
 s.advance(50000)
 record_first(s)
 check(s.state.cycle==2 and s.state.segments.size()==1 and s.state.histories.size()==1,"preparation can be arbitrarily late")
 if s.state.histories.is_empty():return
 var first: String=canonical(s.state.histories[0])
 var segment: Dictionary=s.state.segments[0]
 check(segment.source_cycle==1,"original cycle retained")
 check(segment.commands.any(func(command: Dictionary) -> bool:return command.kind=="hold_begin"),"segment contains real begin")
 check(segment.commands.any(func(command: Dictionary) -> bool:return command.kind=="hold_end"),"segment contains real stop when device completed")
 for command: Dictionary in segment.commands:
  check(command.source_tick>=50000,"original source timestamp remains unchanged")
 at(s,"lab","sync_bell")
 check(s.command("bell","sync_bell").ok,"second bell begins new local clock")
 at(s,"lab","assist_b")
 check(s.command("hold","assist_b").ok,"player B joins historical A")
 var saved: Dictionary=s.snapshot()
 print("VALIDATOR: ",preload("res://core/v03/save_validator.gd").validate(saved))
 var normal: Variant=session_new();if not check(normal.restore(saved),"normal progression candidate valid"):return
 var compressed: Variant=session_new();check(compressed.restore(saved),"fast-forward candidate valid")
 while normal.state.attempt.phase in ["countdown","recording"]:normal.advance(1)
 check(compressed.command("fast_forward").ok,"fast-forward through every local event")
 for key: String in normal.state:
  if canonical(normal.state[key])!=canonical(compressed.state[key]):print("DIFF ",key," ",normal.state[key]," vs ",compressed.state[key])
 check(canonical(normal.snapshot())==canonical(compressed.snapshot()),"normal and fast-forward settle same source/time state")
 s.advance(660)
 check(s.state.attempt.phase=="success","one-history second recording succeeds")
 check(canonical(s.state.histories[0])==first,"second recording cannot rewrite first history")
 at(s,"tower","cycle_console");check(s.command("seal","cycle_console").ok,"seal second real segment")
 var sealed: String=canonical(s.state.histories)
 at(s,"lab","sync_bell");check(s.command("bell","sync_bell").ok,"third local attempt starts")
 at(s,"lab","lab_drop");s.advance(181)
 check(s.state.attempt.holds.size()==2,"two histories fill A and B")
 check(s.command("joint_release","lab_drop").ok,"current C releases with both histories")
 s.advance(120)
 check(s.state.flags.joint and s.state.attempt.phase=="success","two-history joint measurement succeeds")
 check(canonical(s.state.histories)==sealed,"joint success leaves historical records unchanged")
 check("pump" in s.state.owned,"joint observation unlocks pump")
 var missing: Variant=rig(3)
 check(missing.command("bell","sync_bell").ok,"empty-history negative setup starts")
 at(missing,"lab","lab_drop");missing.advance(181)
 denied(missing,"joint_release","lab_drop")
 var power: Variant=rig()
 check(power.command("bell","sync_bell").ok,"power failure attempt starts")
 at(power,"lab","assist_a");power.command("hold","assist_a");power.advance(200)
 at(power,"lab","rig_power");check(power.command("power","rig_power").ok,"player cuts power")
 check(power.state.attempt.phase=="failed","power cutoff produces local failure")
 var before_history: String=canonical(power.state.histories)
 check(power.command("retry").ok,"local retry available")
 check(power.state.attempt.is_empty() and power.state.flags.power and canonical(power.state.histories)==before_history,"retry restores pre-bell state and immutable history")
 var release_early: Variant=rig();release_early.command("bell","sync_bell")
 at(release_early,"lab","assist_a");release_early.command("hold","assist_a");release_early.advance(200)
 check(release_early.command("hold","assist_a").ok and release_early.state.attempt.phase=="failed","early manual release fails local attempt")
 var late: Variant=session_new()
 var third_start: Dictionary=JSON.parse_string(JSON.stringify(s.checkpoint))
 print("CHECKPOINT VALIDATOR: ",preload("res://core/v03/save_validator.gd").validate(third_start))
 check(late.restore(third_start),"third pre-bell checkpoint restores")
 check(late.command("bell","sync_bell").ok,"third late-release attempt starts")
 at(late,"lab","lab_drop");late.advance(580)
 denied(late,"joint_release","lab_drop")
 check(canonical(late.state.histories)==sealed,"missed source duration does not extend historical holds")








 var store: RefCounted=preload("res://core/v03/save_store.gd").new(report_root.path_join("sealed.json"))
 check(store.save_session(s),"complete two-history session saves")
 var loaded: Variant=session_new()
 check(store.load_session(loaded),"sealed segment hashes survive actual JSON disk load")
 check(canonical(s.snapshot())==canonical(loaded.snapshot()),"two-history disk load preserves semantic state")
 var altered: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
 altered.segments[0].hash="forged"
 restore_rejected(loaded,altered,"forged sealed hash")
 altered=JSON.parse_string(JSON.stringify(s.snapshot()))
 altered.segments[0].commands[0].source_tick+=1
 var unsigned: Dictionary=altered.segments[0].duplicate(true);unsigned.erase("hash")
 altered.segments[0].hash=preload("res://core/v03/physics.gd").semantic_hash(unsigned)
 restore_rejected(loaded,altered,"rehashed forged source time")
