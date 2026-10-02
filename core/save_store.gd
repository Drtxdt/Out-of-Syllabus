class_name SaveStore
extends RefCounted
const SCHEMA: int = 2
var path: String
var last_error: String = ""
# Test-only fault hooks; never serialized or enabled by the game.
var fail_step: String = ""
func _init(file: String = "") -> void:
 path = RuntimePaths.data_root() + "/progress.json" if file.is_empty() else file
func save_session(session: GameSession) -> bool:
 last_error = ""
 var payload: Dictionary = {"schema":SCHEMA,"content_version":1,"chapter":"fall","state":session.snapshot(),"checkpoint":session.checkpoint}
 if not _valid(payload, session.content):
  last_error = "候选存档结构无效。";return false
 var existing: Dictionary = _read(path)
 if _future(existing):
  last_error = "存档来自更新版本，不会覆盖。";return false
 var serialized: String = JSON.stringify(payload)
 var envelope: Dictionary = {"payload":serialized,"sha256":serialized.sha256_text()}
 if fail_step == "open": last_error = "模拟临时文件写入失败。";return false
 var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file == null:
  last_error = "无法写入临时存档，原存档未改变。";return false
 file.store_string(JSON.stringify(envelope));file.flush();file.close()
 if fail_step == "write" or not _valid(_read(path+".tmp"),session.content): last_error = "临时存档校验失败。";return false
 var absolute: String = ProjectSettings.globalize_path(path)
 if _valid(existing,session.content):
  if fail_step == "copy": last_error = "模拟备份失败。";return false
  var backup_error: Error = DirAccess.copy_absolute(absolute,absolute+".bak.tmp")
  if backup_error != OK or not _valid(_read(path+".bak.tmp"),session.content): last_error = "备份失败，保留原存档。";return false
  if DirAccess.rename_absolute(absolute+".bak.tmp",absolute+".bak") != OK: last_error = "备份替换失败。";return false
 elif FileAccess.file_exists(path):
  if DirAccess.rename_absolute(absolute,absolute+".corrupt."+str(Time.get_ticks_usec())) != OK: last_error = "无法隔离损坏主档。";return false
 if fail_step == "rename": last_error = "模拟主档替换失败。";return false
 var replace_error: Error = DirAccess.rename_absolute(absolute+".tmp",absolute)
 if replace_error != OK: last_error = "替换失败，保留原存档与备份。";return false
 return true
func _read(file_path: String) -> Dictionary:
 if not FileAccess.file_exists(file_path): return {}
 var parser: JSON = JSON.new()
 if parser.parse(FileAccess.get_file_as_string(file_path)) != OK: return {}
 var raw: Variant = parser.data
 if not raw is Dictionary or not raw.has_all(["payload","sha256"]): return {}
 if not raw.payload is String or str(raw.payload).sha256_text() != str(raw.sha256): return {}
 if parser.parse(raw.payload) != OK: return {}
 var payload: Variant = parser.data
 if not payload is Dictionary: return {}
 return payload
func migrate(payload: Dictionary) -> Dictionary:
 var copy: Dictionary = payload.duplicate(true)
 if int(copy.get("schema",0)) == 1:
  copy.schema = 2
  if copy.has("state") and not copy.state.has("echo_sample_cursors"):
   copy.state.echo_sample_cursors = []
   for _h: Variant in copy.state.get("histories",[]): copy.state.echo_sample_cursors.append(0)
  copy["checkpoint"] = {}
 return copy
func _future(payload: Dictionary) -> bool:
 return int(payload.get("schema",0)) > SCHEMA or int(payload.get("content_version",0)) > 1
func _valid(payload: Dictionary, content: GameContent) -> bool:
 if int(payload.get("schema",0)) != SCHEMA or payload.get("content_version") != 1 or payload.get("chapter") != "fall": return false
 if not SaveValidator.validate(payload.get("state"),content).is_empty(): return false
 var point: Variant = payload.get("checkpoint")
 return point is Dictionary and (point.is_empty() or SaveValidator.validate(point,content).is_empty())
func load_session(session: GameSession) -> bool:
 last_error = ""
 var payload: Dictionary = _read(path)
 if _future(payload):
  last_error = "存档来自更新版本，不能降级读取。";return false
 payload = migrate(payload)
 if not _valid(payload,session.content):
  payload = _read(path+".bak")
  if _future(payload): last_error = "备份来自更新版本。";return false
  payload = migrate(payload)
  if not _valid(payload,session.content): last_error = "主档和备份均无效，当前会话未改变。";return false
  last_error = "主存档不可用，已恢复上一份有效备份。"
 if not session.restore(payload.state): last_error = "存档结构异常。";return false
 session.checkpoint = payload.checkpoint.duplicate(true)
 return true
