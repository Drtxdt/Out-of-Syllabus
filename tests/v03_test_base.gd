extends SceneTree
## v0.3 domain harness. Fixture mutations must be explicitly named; never input-playthrough evidence.
var checks: int=0
var failures: Array[String]=[]
var notes: Array[String]=[]
var suite: String="v03"
var report_root: String=""
var started: int=0

func _initialize() -> void:
 started=Time.get_ticks_usec()
 var profile: String=OS.get_environment("OOS_QA_PROFILE")
 var base: String=OS.get_environment("OOS_QA_ROOT")
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--qa-profile="): profile=argument.trim_prefix("--qa-profile=")
  if argument.begins_with("--qa-root="): base=argument.trim_prefix("--qa-root=")
 if profile.is_empty():
  push_error("Unique QA profile required; refusing normal player data")
  quit(2);return
 if base.is_empty(): base=ProjectSettings.globalize_path("res://reports/v0.3")
 report_root=base.path_join(profile.validate_filename())
 if DirAccess.make_dir_recursive_absolute(report_root)!=OK:
  push_error("Cannot create isolated report path");quit(2);return
 run_cases()
 finish()

func run_cases() -> void:
 check(false,"suite must implement run_cases")

func check(value: bool,label: String) -> bool:
 checks+=1
 if not value:
  failures.append(label);push_error(label)
 return value

func canonical(value: Variant) -> String:
 return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func session_new() -> Variant:
 var script: Script=load("res://core/v03/game_session.gd")
 if not check(script!=null,"v0.3 session exists"): return null
 return script.new()

func denied(session: Variant,kind: String,target: String="",payload: Dictionary={}) -> void:
 var before: String=canonical(session.snapshot())
 var point: String=canonical(session.checkpoint)
 var result: Dictionary=session.command(kind,target,payload)
 check(not result.ok,"reject "+kind+" / "+target)
 check(canonical(session.snapshot())==before,"atomic denial "+kind+" / "+target)
 check(canonical(session.checkpoint)==point,"denial preserves checkpoint "+kind+" / "+target)

func restore_rejected(session: Variant,candidate: Dictionary,label: String) -> void:
 var before: String=canonical(session.snapshot())
 check(not session.restore(candidate),"reject snapshot "+label)
 check(canonical(session.snapshot())==before,"restore atomic "+label)

func write_text(path: String,text: String) -> bool:
 var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
 if not check(file!=null,"open QA fixture "+path): return false
 file.store_string(text);file.close();return true

func envelope(path: String,payload: Dictionary) -> void:
 var raw: String=JSON.stringify(payload)
 write_text(path,JSON.stringify({"payload":raw,"sha256":raw.sha256_text()}))

func finish() -> void:
 var result: Dictionary={"suite":suite,"version":"v0.3","engine":Engine.get_version_info().string,"commit":OS.get_environment("OOS_QA_COMMIT"),"checks":checks,"failures":failures,"notes":notes,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"kind":"domain fixtures, not user input or human playtest"}
 var file: FileAccess=FileAccess.open(report_root.path_join(suite+".json"),FileAccess.WRITE)
 if file==null:
  push_error("QA report write failed");quit(2);return
 file.store_string(JSON.stringify(result,"  "));file.close()
 print(suite.to_upper(),": ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
