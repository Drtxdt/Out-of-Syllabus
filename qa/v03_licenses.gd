extends SceneTree

func _initialize() -> void:
 var destination: String=""
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--license-output="):destination=argument.trim_prefix("--license-output=")
 if destination.is_empty():push_error("Missing license output directory");quit(2);return
 var license_file: FileAccess=FileAccess.open(destination.path_join("GODOT-LICENSE.txt"),FileAccess.WRITE)
 if license_file==null:push_error("Cannot write engine license");quit(1);return
 license_file.store_string(Engine.get_license_text());license_file.close()
 var third_party: FileAccess=FileAccess.open(destination.path_join("GODOT-THIRD-PARTY.json"),FileAccess.WRITE)
 if third_party==null:push_error("Cannot write engine notices");quit(1);return
 third_party.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"copyright":Engine.get_copyright_info(),"licenses":Engine.get_license_info()},"  "));third_party.close()
 quit(0)
