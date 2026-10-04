# 超纲 OUT OF SYLLABUS · v0.3

可玩的科学悬疑序章：把同一张纸揉团或展开，看见机关改变；把动作带进战斗；在三轮探索中与自己真实录下的操作合作，最后选择已有观察或未来预测。

六个区域、三次循环、一场普通战斗、双锤看守与风箱纸偶两场动作卡战、两个结尾已经连接。角色与部分装置使用有标识的可编辑占位，本版是本地试玩候选，真人盲测尚未完成。

## 运行

Windows 独立包：`build/v0.3/windows/OutOfSyllabusV03.exe`。v0.2 包保留在 `build/v0.2/windows/`，旧文档保留在 `docs/archive/v0.2/`。

开发引擎固定 **Godot 4.7.2.stable.official.ed1daf0bf**，打开 `project.godot`。工具从脚本位置解析项目目录；引擎通过 `-Godot` 或 `GODOT_PATH` 指定。

```powershell
./tools/run.ps1 -Godot <Godot可执行文件>
./tools/verify_v03.ps1 -Godot <Godot可执行文件> -RunId my-v03-check
./tools/export_v03.ps1 -Godot <Godot可执行文件> -RunId my-export -Templates <4.7.2模板目录>
./tools/verify_export_v03.ps1 -Godot <Godot可执行文件> -RunId my-exe-check -Render
```

WASD 移动、E 交互、空格闪避、H 提示、J 笔记、F 等待装置关键动作、Esc 设置或返回、F5 保存、F9 读取。Tab 和 Enter 操作菜单；设置支持改键及冲突交换。战斗先选动作，再选目标、预览与确认；基础攻击、防御、移动和结束回合不需要抽卡。

## 推荐路线

1. 展开纸片并释放，让机械延时门开放；走廊战胜巡逻纸偶。
2. 实验室操作配重示范，学习调高与齐放；通过改变配重到达时刻击败双锤看守。
3. 准备好后敲同步铃，到 A 维持操作并封存。第二轮处理器材室纸片障碍，与 A 回声共同完成 B；第三轮由 A/B 回声维持，自己在 C 释放。
4. 在风箱纸偶战中使用空气里的形状差异，再应对真空；同一动作的适用条件会改变。
5. 档案室选择已有观察的校准路线，或预测闸门走捷径。未来能力实际使用后登记一次违规，并触发预警与追逐；在观测塔提交后结算。被抓可从追逐前检查点重试。

局部装置由玩家敲铃启动，不要求赶全局预约。离位或断电会使历史操作失败；重试恢复准备检查点，封存历史不挪动。释放演出共用实际轨迹；配置和阅读暂停，开场释放的世界与回声同步慢放。

## 数据与证据

新版采用 schema 4 / content version 3，正式存档与设置位于 `user://v0.3/`。旧档不自动转换。主档、备份、临时档均校验；未来版本拒绝降级；候选会话全部验证后才替换活动状态。

QA 使用唯一 `-- --qa-profile=<run-id>` 或 `OOS_QA_PROFILE`，并通过 `OOS_QA_ROOT` 隔离数据。报告在 `reports/v0.3/`，包含提交、引擎、命令、退出码和实际截图。模拟文件故障、实际路径故障、渲染截图和真人测试分开记录。

实现与验收见 `docs/V03_PROGRESS.md`、`docs/V03_VALIDATION.md`、`docs/V03_CONTRACTS.md`。原 v0.2 验收事实仍见 `docs/VALIDATION.md`；不能作为新版通过证据。本地构建未自动推送或发布。
