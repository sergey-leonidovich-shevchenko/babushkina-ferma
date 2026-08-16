extends RefCounted

## Обновляет все активные захваты кадров и завершает процесс после сохранения изображения.
static func process(game: Node) -> void:
	game.LevelEditorSystem.update_export_capture(game)
	if game.EnvironmentVisualSystem.update_preview_capture(game): return
	if game.BuildingVisualSystem.update_preview_capture(game): return
	if game.FarmLifeVisualSystem.update_preview_capture(game) or game.InteriorVisualSystem.update_preview_capture(game): return
	if game.WorldLootRenderer.update_preview_capture(game): return
	if game.DirectionalCharacterSystem.update_preview_capture(game) or game.CreatureVisualProfileSystem.update_preview_capture(game): return
	if game.WaterVisualSystem.update_preview_capture(game): return
	if game.CaveVisualSystem.update_preview_capture(game): return
	if game.TreeSystem.update_preview_capture(game): return
	if game.UiPreviewSystem.update_capture(game): return
	if update_named_capture(game, "capture_fence_frames", "res://assets/generated/level_drafts/fence_building_ingame_preview.png", "оград"): return
	if update_named_capture(game, "capture_level_editor_frames", "res://assets/generated/level_drafts/level_editor_ingame_preview.png", "конструктора"): return
	update_named_capture(game, "capture_first_level_frames", "res://assets/generated/level_drafts/first_level_ingame_preview.png", "первой локации")

## Уменьшает счётчик кадров и сохраняет единичный именованный preview в указанный путь.
static func update_named_capture(game: Node, meta_key: String, output_path: String, label: String) -> bool:
	if not game.has_meta(meta_key):
		return false
	var frames_left := int(game.get_meta(meta_key)) - 1
	game.set_meta(meta_key, frames_left)
	if frames_left > 0:
		return false
	game.remove_meta(meta_key)
	var image := game.get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path(output_path)
	var error := image.save_png(output)
	if error != OK:
		game.push_error("Не удалось сохранить предпросмотр %s: %s" % [label, error])
	game.get_tree().quit()
	return true

## Готовит безопасную витрину пяти рангов врагов, трёх угроз и максимального облика героя.
static func configure_enemy_levels(game: Node) -> void:
	game.language_screen = false
	game.title_screen = false
	game.current_location = "overworld"
	game.player = Vector2(1150, 650)
	game.player_level = game.SkillSystem.MAX_CHARACTER_LEVEL
	game.player_hp = game.player_max_hp
	game.tutorial_visible = false
	for index in mini(5, game.enemy_nodes.size()):
		var enemy: Dictionary = game.enemy_nodes[index]
		enemy.location = "overworld"
		enemy.level = index + 1
		enemy.max_hp = game.CombatSystem.max_hp(enemy.kind, enemy.level)
		enemy.hp = enemy.max_hp
		enemy.position = Vector2(700 + index * 225, 520)
		enemy.home = enemy.position
		enemy.attack_timer = 999.0
		game.enemy_nodes[index] = enemy
	for index in mini(3, game.hazard_nodes.size()):
		var hazard: Dictionary = game.hazard_nodes[index]
		hazard.location = "overworld"
		hazard.kind = game.EnvironmentHazardSystem.FAMILY_ORDER[index]
		hazard.level = 1 + index * 2
		hazard.position = Vector2(820 + index * 330, 820)
		hazard.cooldown = 999.0
		game.hazard_nodes[index] = hazard

## Готовит витрину финального этапа Лунной поляны со Стражем, алтарём и наградой.
static func configure_moon_glade(game: Node) -> void:
	game.language_screen = false
	game.title_screen = false
	game.current_location = "moon_glade"
	game.day = 5
	game.game_minutes = 21.0 * 60.0
	game.player = Vector2(1710, 610)
	game.tutorial_visible = false
	game.MoonGladeSystem.prepare(game)
	var moon_state: Dictionary = game.state.world.moon_glade
	moon_state.flower_collected = true
	moon_state.crystal_charged = true
	moon_state.echoes = [true, true, true]
	moon_state.altar_activated = true
	moon_state.guardian_alive = true
	moon_state.guardian_hp = game.MoonGladeSystem.GUARDIAN_MAX_HP
