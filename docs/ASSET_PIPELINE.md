# 资产规格与生产

世界目标为 32×32 地图格、约 32×48 角色、四方向基础动画、640×360 画面与整数缩放。UI 独立使用较高分辨率以保证中文阅读。当前角色和地图是引擎原生几何占位，尚未作为正式风格验收。

## 生产顺序

规格与色板 → 单个角色少量动作 → 检查像素对齐、透明边、帧间一致性 → 引擎实看 → 批量生产。每次保留提示词、原始输出、修订记录、源链接、许可证和导入参数。

imagegen 是默认生成入口。sprite-gen 已安装，但它调用额外 Codex CLI 的路径与 Windows 运行方式尚未验收。pixel-art 辅助校验工具使用 tools/.venv，不污染系统 Python。依赖见 tools/requirements.lock.txt。

推荐占位可选 [Kenney Roguelike RPG Pack](https://kenney.nl/assets/roguelike-rpg-pack)，16×16 仅以整数倍进入32格，明确标注 CC0 与占位。当前未下载或使用 Kenney 资产。

## 当前实际来源

- 地砖、主角与物体：项目代码生成的几何像素占位；源码在 tools/build_world.gd、world/pixel_actor.gd、world/prop.gd。
- 确认音：原创 660 Hz 衰减正弦波，22050 Hz mono PCM，assets/audio/confirm.wav。
- 简体中文字体：Noto Sans CJK SC Regular，来自 notofonts/noto-cjk 仓库，许可证在 assets/fonts/LICENSE.txt。
- Godot Forge：固定仓库源码，保留其 LICENSE 于 addons/godot_forge/LICENSE。

正式生产首先打磨主角、监考者、实验台与观测塔；卡牌用清楚的科学图示和一致符号。公开包必须再次核对字体及依赖许可，保留制作来源清单。
