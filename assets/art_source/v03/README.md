# v0.3 双锤表现样板

`hammer-reference.png` 使用内置 imagegen 生成，已实际查看。它提供纸片／纸团、两夹具和机械护盾的视觉参考。它没有通过生产像素审计：1672×941 不符合 32 像素网格，92672 色超出锁定的 12 色。透明边与孤立像素检查通过。原始审计见 `hammer-audit.json`。目录继承 `art_source/.gdignore`，不导入运行时，不替代可编辑 TileMapLayer。

运行时继续使用明确标记的可编辑占位：`world/v03/objects.gd` 和 `ui/v03/trajectory.gd`。后者只绘制核心给出的物体条件与真实轨迹，不使用生成图推断结果。主角沿用 `world/pixel_actor.gd`；v0.2 保留的学生生成源图仍未通过生产审计。

生成提示词：

> Use case stylized-concept. Produce a visual development sample for a Chinese offline science mystery RPG, Out-of-Syllabus v0.3. One clean pixel-art orthographic side-facing combat stage, logical 640x360 intended runtime reference, 32-pixel grid, dark teal school laboratory. Three clear lanes across the foreground. At upper left and upper right, two mechanical hammer guardians with visible adjustable metal weights held in clamps: left weight at 2m and right at1m, copper wire leading to a central mechanical shield. Add a flat white paper and its folded ball variant as two small inset physical objects on lower side tables. No text, no HUD, no numerals, no characters. Palette restricted to #111e28 #172930 #284247 #426069 #537879 #92c6bb #d8e2dd #e1bc78 #b48655 #6f4a3a #d88775 #292b36. Hard crisp pixel edges, no antialiasing, no gradients, subtle top-right lighting. This is a source reference for editable apparatus, not a preapproved production sprite.

审计命令：`python quality_audit.py --image assets/art_source/v03/hammer-reference.png --grid 32 --max-colors 12 --json`。退出码 1 是真实质量不合格，不是已通过。实际引擎截图由主线独占 GUI 后检查；本工作区未启动 GUI。
