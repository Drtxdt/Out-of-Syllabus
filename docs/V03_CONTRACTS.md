# v0.3 共享契约

实施接口版本 1。核心使用 `res://core/v03/game_session.gd`（RefCounted，预加载实例化）；旧 GameSession 保留为 v0.2 回归基线。所有新玩法因果状态由新版会话的 `command` 入口提交。UI 不直接写 `state`。

## 会话接口

- `state: Dictionary`：可读状态，字段见下。`snapshot() -> Dictionary` 深拷贝；`restore(data) -> bool` 完整候选校验后交换。
- `command(kind: String, target: String = "", payload: Dictionary = {}) -> Dictionary`：返回 `{ok: bool, message: String}`；失败不改状态。额外 `request_id` 和 `revision` 可用于去重和过期预览检查。
- `advance(steps: int = 1) -> void`：60 tick/s；`mode` 非 world 时不推进世界；战斗由 end_turn 结算。
- `objects() -> Array[Dictionary]`：当前房间的交互对象，字段 `id,title,kind,x,y`，exit 另含 `target`。地图复用 `world/rooms/{room}.tscn`，视图应隐藏旧 Props，按此列表绘制新版对象。
- `nearby() -> Dictionary`：当前最近且距离合法的对象，空字典表示无；UI 仅按此提示和提交交互。
- `objective() -> String`、`hint() -> String`：核心实时引导。
- `combat_preview(action, target) -> Dictionary`：纯预览，返回 `{ok,message,state,revision}`；state 为预览后的战斗状态，展示须遵循知识权限。
- `echo_poses() -> Array`：各项含 `cycle,x,y,moving,direction`，位置只由核心回放重建。
- `checkpoint: Dictionary`；`save_store.gd` 提供 `save_session(session)`、`load_session(session)`、`last_error`，schema 4/content 3。

`state` 固定字段：`cycle:int,tick:int,room:String,position:Array[float],direction:String,mode:String,revision:int,seq:int,stage:String,flags:Dictionary,owned:Array[String],knowledge:Dictionary,events:Array,samples:Array,histories:Array,segments:Array,attempt:Dictionary,battle:Dictionary,opening:Dictionary,observations:Array,finale:Dictionary,completed:bool,handled:Array[String]`。mode 为 world/combat/caught/complete；UI 模态暂停使用自身控制的暂停标记，不修改 mode。

## 世界命令

- `move/player/{x,y,direction}`：每 tick 允许正常步进，核心验证房间边界与速度；UI 可先用现有 CharacterBody2D 碰撞，再提交合法位置。
- `interact/<nearby.id>`：出口切房；门、配重、敌人、同步铃、工位等进入相应操作。返回信息，不自动打开任意菜单。
- `paper_shape/paper/{shape:"flat"|"crumpled"}`；`release/paper`：教室近景操作。`opening` 含 shape,phase(elapsed/landed/idle 以核心实现为准),trace,release_tick,door_until；动画读取 trace。
- `observe/paper`：仅释放结束、玩家靠近且结果被近景展示后由 UI 发出，记录实际观察。
- `learn_rig/rig_demo`：操作配重示范装置并解锁调高与齐放，需要靠近；这是原生装置操作，不要求玩家预先有卡。
- `begin_battle/patrol|hammer|bellows`：核心验证阶段、地点与附近敌人。也可通过敌人 interact 触发。
- `bell/sync_bell`：启动倒数及局部尝试；`hold/assist_a|assist_b` 开始或结束当前工位；`joint_release/lab_drop`；`power/rig_power` 切换供电；`fast_forward` 逐 tick 推进；`retry` 恢复检查点。
- `seal/cycle_console`：成功设备片段后封存并进入下一轮；`fix/paper_barrier` 第二轮固定纸片取得密封组件。
- `choose_future/archive_terminal/{accept:bool}`；`forecast/archive_terminal/{model:"drag"|"gravity",height:2.0,medium:"air"}`；`calibrate/archive_terminal` 使用已观察记录；`gate_release/fall_gate`；`dodge/player`；`submit/cycle_console`。

## 战斗命令

`combat_action/<action>/{target:<object id>,revision:<optional>,request_id:<optional>}`，以及 `end_turn`、`retreat`、`retry`。行动 ID：crumple,unfold,raise,release_pair,fix,unfix,pump,future,attack,defend,move_left,move_right。

战斗状态固定字段：`id,round,ap,hp,enemy_hp,lane,intent,objects,shield,phase,defending,pending_release,medium,log,outcome,revision,traces`。`objects` 是 ID 到物体字典的映射；物体含 id,title,kind,mass,area,coefficient,height,shape,held,lane。hammer 使用 left/right；bellows 使用 paper/weight；patrol 使用 paper。intent 含 title,lane,damage。outcome 为 active/won/lost/retreated。

UI 从 owned 和基础动作生成按钮，先选动作再选目标，调用纯预览，确认后提交。没有合法目标或 AP 时显示禁用原因。战斗画面展示三条通道、实际物体高度、敌方意图、双方 HP、AP、回合与结算日志；无需滚动完成主要操作。释放卡标记本轮待释放，end_turn 执行实际轨迹与敌方行为。

## 局部装置与结尾

`attempt` 为空表示未开始；非空含 phase(countdown/recording/success/failed),tick,holds,powered,message。工位 hold 字典以 station 为键，持有记录含 actor,begin。片段引用 source_cycle/start/end 事件与原姿态，完整来源不改写。echo_poses 直接提供位置。先铃后工位，准备阶段无限时。

`finale` 含 choice(none/accept/refuse),phase(none/ready/warning/chase/caught/escaped/complete),used,violations,prediction,release_tick,open_tick,close_tick,examiner_room,examiner_position,warning_end。未来实际 gate_release 才记使用与一次违规；错误模型保留错误预测，真实闸门按实际轨迹判定。塔内 submit 才 completed。

## 数据与运行

新版 `core/v03/runtime_paths.gd` 解析相同 QA 参数，默认数据 user://v0.3；报告 reports/v0.3。输入设置支持传入新版路径，不使用旧用户设置文件。新主场景 `app/v03/main.tscn`；保留旧 app/main.tscn。所有测试显式 --log-file，避免初始化日志落入旧用户目录。

允许为具体实现增加字段或展示方法；改变以上字段语义必须同步核心、UI 与测试。数值平衡可以更新，但轨迹、观察、结算、历史不可变与非法命令原子性不能弱化。
