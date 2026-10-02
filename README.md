# 超纲 OUT OF SYLLABUS

知识改变解法，过去的自己影响现在。此仓库是独立 Godot 4.7.2 工程，当前交付 **v0.1.0 可玩灰盒**：六个区域、三个循环、两场模型论证、两条历史回声和两个结尾。

这不是已达到 45–60 分钟及公开发行标准的 Demo。M0 工具链与主要机制已有实现；关卡节奏、正式美术、必要的双回声协作谜题和外部玩家测试仍需迭代。详见 docs/ROADMAP.md。

## 运行

安装版无需 Godot：运行 `build/windows/OutOfSyllabus.exe`。开发版用 `D:\Godot_v4.7.2\Godot_v4.7.2-stable_win64.exe` 打开本目录的 project.godot，按 F6 运行主场景或 F5 运行项目。也可运行 `tools/run.ps1`。

WASD 移动，E 交互，空格闪避，J 日志，K 卡组，F 等待五秒，Q 在异常装置附近应用知识，Esc 设置，F5 保存，F9 读取。所有按键可在设置中修改。菜单、对话和论证暂停世界时钟。

首次路线：教室接通 A → 走廊 → 器材室取实验包、接通 B → 实验室记录下落 → 观测塔结束循环。第二轮到实验室解释质量反例；第三轮启动真空泵并解释空气差异，最后进入档案室。日志与当前目标提供引导。

## 开发与验证

- `tools/verify.ps1`：导入与核心回归检查。
- `tools/verify.ps1 -Render`：额外运行真实 GPU 场景和分辨率冒烟测试。
- `tools/export.ps1`：生成 Windows x64 发布包。
- `node tools/forge_check.mjs`：MCP 编辑器树、实际运行、游戏树、截图、错误读取；会重启本项目编辑器。
- `python tools/install_templates.py`：安装固定版本的 Windows 模板，分段下载官方归档。

`tools/.venv` 是美术工具专用 Python 环境。七个 skill 安装于用户 `.codex/skills`，SHA 与位置见 toolchain.lock.json；重启 Codex 或新开一轮后重新发现。sprite-gen 的嵌套 CLI 素材生产尚未验收，正式入口优先使用内置 imagegen。

另一台机器可先运行 `python tools/bootstrap_forge.py` 重建固定的 MCP 服务器。

Godot Forge 固定源码构建，项目配置在 `.codex/config.toml`。需要 Codex 信任本项目后加载；当前会话已用 SDK 实际连接验证。个人 MCP 配置未修改。

## 文档

- docs/GAME_DESIGN.md：体验、范围、循环和结尾。
- docs/ARCHITECTURE.md：模块边界、回放、存档与迁移。
- docs/KNOWLEDGE_CARDS.md：科学规则与卡牌解法。
- docs/ASSET_PIPELINE.md：像素规格、来源与生产验收。
- docs/ROADMAP.md：开发队列与人工时间估算。
- docs/VALIDATION.md：实际验证及未完成门槛。

存档位于 Godot 的用户数据目录（Windows `%APPDATA%/Godot/app_userdata/超纲 · OUT OF SYLLABUS`），设置独立保存。测试使用独立文件名，不覆盖玩家 progress.json。
