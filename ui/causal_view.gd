extends "res://ui/evidence_view_base.gd"

func render(data: Dictionary) -> void:
 begin_render()
 line("回声因果面板", true)
 line("A 稳压与 B 安全锁必须由两个角色持续维持，当前的你操作 C 释放。离位或断电会结束维持。")
 var now: int = int(data.get("tick", 0))
 var histories: Array = data.get("histories", [])
 if histories.is_empty(): line("尚无历史回声。第一轮先完成准备，再录制 A 工位。")
 for value: Variant in histories:
  var history: Dictionary = value
  var next_tick: int = int(history.get("next_tick", -1))
  line("第 %s 轮回声" % history.get("cycle", "?"), true)
  line("下一动作：%s\n%s" % [display_action(str(history.get("action", "无后续动作"))), "剩余 %.1f 秒" % (maxi(0, next_tick - now) / 60.0) if next_tick >= 0 else "本轮动作已经完成"])
  if history.has("expected"): line("预期条件：%s" % history.expected)
  if history.has("actual"): line("实际条件：%s" % history.actual)
 line("当前工位", true)
 var holds: Dictionary = data.get("holds", {})
 for station: String in ["assist_a", "assist_b"]:
  var hold: Dictionary = holds.get(station, {})
  line("%s：%s" % ["A 稳压" if station == "assist_a" else "B 安全锁", "空缺" if hold.is_empty() else "%s · 剩余 %.1f 秒" % [display_name(str(hold.get("actor", "?"))), maxi(0, int(hold.get("end", now)) - now) / 60.0]])
 line("因果偏差", true)
 var deviations: Array = data.get("deviations", [])
 if deviations.is_empty(): line("暂无偏差。历史动作仍需要满足此刻的房间、距离与供电条件。")
 for value: Variant in deviations:
  if value is Dictionary: line(str(value.get("reason", value.get("message", value))))
  else: line(str(value))
 button("WaitNextEcho", "快进至下一关键动作", "wait_next")
 button("RetryCheckpoint", "恢复实验检查点", "rewind", "", {}, bool(data.get("can_retry", false)))
 button("RestartCycle", "重试本轮（已封存历史保留）", "restart_cycle", "", {}, bool(data.get("can_retry", false)))
 button("CloseCausal", "返回现场", "close")
 end_render()
