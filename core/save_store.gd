class_name SaveStore
extends RefCounted
const SCHEMA: int = 2
var path: String
var last_error: String = ""
func _init(file: String = "user://progress.json") -> void:
 path = file
func save_session(session: GameSession) -> bool:
 last_error = ""
 var payload: Dictionary = {"schema":SCHEMA,"content_version":1,"chapter":"fall","state":session.snapshot(),"checkpoint":session.checkpoint}
 var serialized: String = JSON.stringify(payload)
 var envelope: Dictionary = {"payload":serialized,"sha256":serialized.sha256_text()}
 var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file == null:
  last_error = "无法写入临时存档，原存档未改变。";return false
 file.store_string(JSON.stringify(envelope));file.flush();file.close()
 if _read(path+".tmp").is_empty(): last_error = "临时存档校验失败。";return false
 var absolute: String = ProjectSettings.globalize_path(path)
 if FileAccess.file_exists(path):
  var backup_error: Error = DirAccess.copy_absolute(absolute,absolute+".bak")
  if backup_error != OK: last_error = "备份失败，保留原存档。";return false
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
func load_session(session: GameSession) -> bool:
 last_error = ""
 var payload: Dictionary = _read(path)
 if not payload.is_empty() and int(payload.get("schema",0)) > SCHEMA:
  last_error = "存档来自更新版本，不能降级读取。";return false
 if payload.is_empty():
  payload = _read(path+".bak")
  if not payload.is_empty(): last_error = "主存档不可用，已恢复上一份有效备份。"
 payload = migrate(payload)
 if int(payload.get("schema",0)) != SCHEMA or int(payload.get("content_version",0)) != 1 or payload.get("chapter","") != "fall":
  last_error = "没有兼容的存档；不会覆盖或重置现有文件。";return false
 if not session.restore(payload.get("state",{})):
  last_error = "存档结构异常。";return false
 session.checkpoint = payload.get("checkpoint",{}).duplicate(true)
 return true
