extends RefCounted
const DEFAULTS: Dictionary={"move_up":KEY_W,"move_down":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"interact":KEY_E,"dodge":KEY_SPACE,"journal":KEY_J,"wait":KEY_F,"pause":KEY_ESCAPE,"save":KEY_F5,"load":KEY_F9}
const LABELS: Dictionary={"move_up":"向上","move_down":"向下","move_left":"向左","move_right":"向右","interact":"交互","dodge":"闪避","journal":"笔记","wait":"等待关键动作","pause":"设置 / 返回","save":"保存","load":"读取"}
var keys: Dictionary=DEFAULTS.duplicate()
var path: String
var reduced_effects: bool=true
var volume: float=0.4

func _init() -> void:
 var paths: Script=load("res://core/v03/runtime_paths.gd")
 path=paths.data_root()+"/settings.cfg"
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var config: ConfigFile=ConfigFile.new()
 if config.load(path)==OK:
  for action: String in keys: keys[action]=int(config.get_value("input",action,keys[action]))
  reduced_effects=bool(config.get_value("accessibility","reduced_effects",true))
  volume=clampf(float(config.get_value("audio","volume",0.4)),0.0,1.0)
 apply()

func apply() -> void:
 for action: String in keys:
  if not InputMap.has_action(action):InputMap.add_action(action)
  InputMap.action_erase_events(action)
  var event: InputEventKey=InputEventKey.new();event.physical_keycode=int(keys[action]);InputMap.action_add_event(action,event)
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.0001)))

func bind_key(action: String,key: int) -> void:
 for existing: String in keys:
  if existing!=action and int(keys[existing])==key:keys[existing]=keys[action];break
 keys[action]=key;apply();save()

func save() -> void:
 var config: ConfigFile=ConfigFile.new()
 for action: String in keys:config.set_value("input",action,keys[action])
 config.set_value("accessibility","reduced_effects",reduced_effects)
 config.set_value("audio","volume",volume);config.save(path)

func display(action: String) -> String:
 return OS.get_keycode_string(int(keys[action]))
