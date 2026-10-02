class_name RuntimePaths
extends RefCounted

static func profile_id() -> String:
 var value: String = OS.get_environment("OOS_QA_PROFILE")
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--qa-profile="): value = argument.trim_prefix("--qa-profile=")
 return value.validate_filename().replace(".", "_")

static func report_root() -> String:
 var id: String = profile_id()
 if id.is_empty(): id = "manual"
 var base: String=OS.get_environment("OOS_QA_ROOT")
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--qa-root="): base=argument.trim_prefix("--qa-root=")
 if base.is_empty(): base=ProjectSettings.globalize_path("res://reports/v0.2") if not OS.has_feature("standalone") else OS.get_executable_path().get_base_dir()+"/qa-reports"
 return base.path_join(id)

static func data_root() -> String:
 var root: String = "user://v0.2" if profile_id().is_empty() else report_root() + "/userdata"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
 return root

static func report_path(name: String) -> String:
 var root: String = report_root()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
 return root + "/" + name
