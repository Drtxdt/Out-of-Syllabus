# Out of Syllabus
1. Lock Godot to 4.7.2. Do not upgrade dependencies implicitly.
2. Use typed GDScript and small composed scenes.
3. This is a Chinese, offline, Windows-first science mystery RPG.
4. Static maps use editable TileMapLayer scenes.
5. Keep exploration, model combat, knowledge, timeline and persistence independent.
6. Author chapters, cards, experiments and knowledge as Resources with stable IDs.
7. Knowledge authorization and validity are different checks.
8. All causal mutations go through GameSession.command; record semantic events.
9. Completed histories are immutable; current history may rewind with its checkpoint.
10. Echoes replay across every room; switches interact, inventory and dialogue do not award twice.
11. Only current-player actions enter new replay tracks.
12. Compression must advance and settle all intervening echo events.
13. Save versions and content versions require explicit compatibility checks and migration tests.
14. Run headless regression tests plus actual scene and exported-build smoke tests.
15. Use fixed pixel grids, nearest filtering and consistent palette; retain source assets separately.
16. Keep input remappable and Chinese UI readable; dialogs pause world time.
17. Keep each change scoped to the milestone; do not add multiplayer or unrelated systems.
18. Report only validations actually run, with remaining limitations.
