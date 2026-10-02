# v0.2 integration contracts

All causal gameplay actions use GameSession.command(kind, target, payload); UI never writes world/profile/battle. Session wrappers validate identically. UI dictionaries are read-only projections. Core/main/project/save contracts belong to the integration workstream.

## Evidence
`session.evidence: Array[Dictionary]`: each record has id, source_event_id, source_cycle, cycle, tick, room_id, experiment_id, setup, observations, origin_actor, observed_by_player, simulator_version. `setup` has experiment (initial/mass/shape), medium (air/vacuum), shape (flat/crumpled), height_m=2.0, initial_velocity_m_s=0.0, samples and controlled_variables. `observations` has arrival_times_s, comparison, tolerance_s=0.01. Source event IDs are `c<cycle>:e<seq>` strings. Echo repetition retains original source identity. Predictions are never evidence.

`experiment` target lab_drop, payload {experiment, medium, shape}; starts physical release, world clock must run. Pending experiment finishes after scientific duration. `read_evidence` target record id marks an instrument record observed. `session.pending_experiment` empty when idle. Vacuum final measurements require all three rig contributors in cycle 3. Notebook survives cycles, rewinds with current checkpoint.

## Encounter
`start_battle(id)` validates phase/location/records. `play_card(id, evidence_ids: Array=[]) -> Dictionary` submits selected records; `finish_battle()` only settles a recomputed valid victory. ModelBattle consumes immutable observed records, never generates measurements. `battle.conditions()` returns array {id,status,reason}, status satisfied/unsupported/contradicted. State retains original field names for the UI and save schema plus cited_ids.

## Replay
New world objects in lab: assist_a=(144,144), assist_b=(464,144), rig_power=(560,240); C is existing lab_drop=(304,152). Old lab gate remains unchanged.
`hold_begin` target assist_a/assist_b; proximity <=36, power=true, one station per actor. `hold_end` ends own hold. Automatic end after 720 ticks, or leaving; stored as real semantic begin/end actions. First-cycle A may start from tick 7200. `session.holds` maps station to {actor,begin,end}; historical replay derives actor position from original samples. Cycle 2 needs >=360 ticks of valid recorded A/B overlap. `wait_next()` advances safely to the next relevant event, or 7200 before first A, stopping at causal failures. `session.causal_view()` exposes histories/holds/deviations/next_tick. Stage checkpoints persist separately from incidental saves; `rewind()` restores local checkpoint; `restart_cycle()` uses cycle-start checkpoint and never edits sealed history.

## Knowledge and ending
Knowledge access map has discovered/understood/authorized separately; candidates can be tested before understood. Syllabus allows observation/gravity/drag; future numerical method unauthorized. Finale commands: `choose_future` {accept}; `predict_gate` {model:drag,medium:air,shape:flat}; `calibrate_gate` {evidence_id}; `gate_release`; `ending` at cycle_console after route complete. Choice alone never completes chapter. Forecast/calibration prepare timed falling gate; release manually activates window. Accept actual prediction adds violation once, warning then chase; actor movement/dodge provide escape to tower. `session.finale` snapshot stores phase/choice/used/prediction/gate timing/examiner. Denied commands do not mutate state or append events. Stable input-readable state is allowed for test assertions, never for normal-route writes.

## View component signals
Independent UI scenes extend VBoxContainer and expose `render(data: Dictionary)` plus `action_requested(kind: String,target: String,payload: Dictionary)`. Experiment view data: choices, records, pending, pump, cycle. Battle view: title, question, state, conditions, cards [{id,title,description,enabled,reason}], records. Causal view: histories [{cycle,next_tick,action}], holds, deviations, can_retry. Stable Button names and semantic focus preservation required. Main connects signals and supplies data; components must not import GameSession.

## Persistence/testing
S0 retains schema2 solely until baseline validated. v0.2 switches to schema3/content2 and rejects old saves without touching them; old build remains build/windows. New build goes build/v0.2/windows. QA defaults are RuntimePaths.data_root()/report_path(), root keyed by --qa-profile or OOS_QA_PROFILE, with distinct run IDs per worktree. Never run GUI concurrently. Original regression remains as legacy coverage until new equivalents replace obsolete routes, not weakened expectations. Windows certificate-store read errors observed under sandbox are environmental and must be reported separately, never hidden as game test successes.

## v0.2 存档与显示补充

Battle State 增加 `suspended: bool`：模型模式必须有未挂起论证，世界模式只允许显式挂起论证。追逐被捕存为 menu 并只能通过检查点重试。证据数值校验采用 1e-9 的序列化误差界限（远小于 0.01s 实验容差），仍重算科学结果，不放过伪造结果。未来方法有独立 KnowledgeAccess，理解不会授予许可。

RuntimePaths 支持绝对 `OOS_QA_ROOT` / `--qa-root`，导出游戏测试同样隔离。GUI/无头脚本始终显式指定日志路径。沙箱外隔离运行已确认 Windows 证书错误不会出现；最终脚本不忽略任何运行时错误。
