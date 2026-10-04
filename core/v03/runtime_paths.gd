extends RefCounted

static func profile_id() -> String:
 return RuntimePaths.profile_id()

static func report_root() -> String:
 var root: String=OS.get_environment("OOS_QA_ROOT")
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-root="): root=arg.trim_prefix("--qa-root=")
 if root.is_empty(): root=ProjectSettings.globalize_path("res://reports/v0.3") if not OS.has_feature("standalone") else OS.get_executable_path().get_base_dir().path_join("qa-reports")
 return root.path_join(profile_id() if not profile_id().is_empty() else "manual")

static func data_root() -> String:
 var root: String="user://v0.3" if profile_id().is_empty() else report_root().path_join("userdata")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
 return root

static func report_path(name: String) -> String:
 DirAccess.make_dir_recursive_absolute(report_root())
 return report_root().path_join(name)
