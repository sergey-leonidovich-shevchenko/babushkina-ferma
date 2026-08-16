extends RefCounted


## Настраивает запрошенный системный экран и при необходимости включает автоматический снимок.
static func configure(game: Node) -> void:
	var arguments := OS.get_cmdline_user_args()
	if configure_world_guide_capture(game, arguments): return
	if configure_character_window_capture(game, arguments): return
	if configure_item_window_capture(game, arguments): return
	if configure_story_window_capture(game, arguments): return
	if "--capture-hud" in arguments:
		game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false; game.message = ""
		game.player = Vector2(1160, 650); game.set_meta("capture_hud_clean", true); game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/hud_ingame_preview.png")
		return
	if "--capture-language" in arguments:
		game.language_screen = true; game.title_screen = false; game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/language_ingame_preview.png")
		return
	if "--capture-defeat" in arguments:
		game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false
		game.set_meta("capture_hud_clean", true); game.MenuSystem.open_defeat(game, "Пират-призрак", 5); game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/defeat_ingame_preview.png")
		return
	if "--capture-ui-feedback" in arguments:
		game.language_screen = false; game.title_screen = false; game.current_location = "overworld"
		game.MenuSystem.open_pause(game); game.MenuSystem.open_settings(game, false); game.menu_state.settings_selected = 7
		game.ui_last_layer = "settings"; game.ui_transition_timer = game.UiFeedbackSystem.TRANSITION_DURATION
		game.UiFeedbackSystem.press(game, game.MenuRenderer.settings_item_rect(game.menu_state.settings_selected))
		game.set_meta("capture_ui_frames", 4); game.set_meta("capture_ui_output", "res://assets/generated/ui/ui_feedback_ingame_preview.png")
		return
	if "--capture-adaptive-ui" in arguments:
		game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.touch_controls_visible = true
		game.settings_state.text_scale = 1.2; game.settings_state.touch_scale = 1.3
		game.MenuSystem.open_pause(game); game.MenuSystem.open_settings(game, false); game.menu_state.settings_selected = 10
		game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/adaptive_ui_ingame_preview.png")
		return
	if not ("--settings-preview" in arguments or "--capture-settings" in arguments): return
	game.language_screen = false
	game.title_screen = false
	game.MenuSystem.open_pause(game)
	game.MenuSystem.open_settings(game, false)
	if "--capture-settings" in arguments:
		game.set_meta("capture_ui_frames", 6)
		game.set_meta("capture_ui_output", "res://assets/generated/ui/system_settings_ingame_preview.png")


## Настраивает одну из пяти вкладок энциклопедии как воспроизводимый визуальный эталон.
static func configure_world_guide_capture(game: Node, arguments: PackedStringArray) -> bool:
	var modes := {"--capture-world-map":0, "--capture-calendar":1, "--capture-bestiary":2, "--capture-collections":3, "--capture-recipes":4}
	var outputs := ["world_map", "calendar", "bestiary", "collections", "recipe_guide"]
	var mode := ""
	for flag in modes:
		if flag in arguments: mode = flag; break
	if mode.is_empty(): return false
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false; game.world_map_open = true; game.world_guide_page = int(modes[mode]); game.world_guide_selected = 12
	game.state.world.estate.discovered = game.WorldMapSystem.LOCATIONS.keys()
	for kind in game.CombatSystem.TYPES: game.seen_discoveries["enemy:%s:1" % kind] = true
	for index in game.FishingSystem.FISH_CATALOG.size():
		if index % 2 == 0: game.state.fishing.best_sizes[game.FishingSystem.FISH_CATALOG[index].id] = 24 + index * 4
	game.set_meta("capture_story_clean", true); game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/%s_ingame_preview.png" % outputs[int(modes[mode])])
	return true


## Настраивает книгу героя и способностей с показательными эффектами и действующей группой.
static func configure_character_window_capture(game: Node, arguments: PackedStringArray) -> bool:
	if not ("--talent-preview" in arguments or "--capture-talent-tree" in arguments): return false
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false; game.player_level = 7; game.player_xp = 82; game.skill_points = 4; game.coins = 800
	for talent_id in ["combat_strength", "combat_agility", "combat_vitality", "farm_orchard", "farm_wide_till", "fish_fine_rod", "craft_apprentice"]: game.talent_levels[talent_id] = 1
	game.recruited_companions.assign(["mila", "borislav", "luna"]); game.active_companions.assign(["mila", "luna"]); game.skill_levels.leadership = 2; game.strength_timer = 28.0; game.regeneration_timer = 17.0; game.speed_timer = 22.0; game.skill_menu_selected = 7; game.skill_menu_open = true
	game.set_meta("capture_story_clean", true)
	if "--capture-talent-tree" in arguments: game.set_meta("capture_ui_frames", 6); game.set_meta("capture_ui_output", "res://assets/generated/ui/talent_tree_ingame_preview.png")
	return true


## Настраивает журнал, диалог, обучение или награду как воспроизводимый визуальный эталон сюжетного UI.
static func configure_story_window_capture(game: Node, arguments: PackedStringArray) -> bool:
	var mode := ""
	var outputs := {
		"--capture-quest-log":"quest_log_ingame_preview.png", "--capture-dialogue":"dialogue_ingame_preview.png",
		"--capture-tutorial":"tutorial_ingame_preview.png", "--capture-notification":"notification_ingame_preview.png",
		"--capture-chapter-reward":"chapter_reward_ingame_preview.png",
	}
	for flag in outputs:
		if flag in arguments: mode = flag; break
	if mode.is_empty(): return false
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.message = ""
	game.set_meta("capture_story_clean", true); game.set_meta("capture_ui_frames", 8); game.set_meta("capture_ui_output", "res://assets/generated/ui/%s" % outputs[mode])
	var chapter: Dictionary = game.FirstChapterSystem.state(game); chapter.completed = true; chapter.reward_pending = false
	match mode:
		"--capture-quest-log":
			game.tutorial_visible = false; game.quest_log_open = true; game.quest_log_page = 0
			game.mission_states.story_relic = game.QuestSystem.ACTIVE; game.mission_states.side_seed = game.QuestSystem.COMPLETED
			game.change_inventory_count("moon_relic", 0)
		"--capture-dialogue":
			game.tutorial_visible = false; game.AdventurePolishSystem.open_quest_dialogue(game, "miron")
		"--capture-tutorial":
			game.tutorial_visible = true; game.tutorial_step = mini(2, game.tutorial_steps.size() - 1)
		"--capture-notification":
			game.tutorial_visible = false; game.set_meta("capture_notification_text", "Задание выполнено • +120 монет • редкая награда")
		"--capture-chapter-reward":
			game.tutorial_visible = false; chapter.completed = false; chapter.reward_pending = true
	return true


## Настраивает один из пяти предметных экранов как воспроизводимый полноэкранный визуальный эталон.
static func configure_item_window_capture(game: Node, arguments: PackedStringArray) -> bool:
	var mode := ""
	var outputs := {
		"--capture-inventory":"inventory_ingame_preview.png", "--capture-shop":"shop_ingame_preview.png",
		"--capture-crafting":"crafting_ingame_preview.png", "--capture-storage":"storage_ingame_preview.png",
		"--capture-forge":"forge_ingame_preview.png",
	}
	for flag in outputs:
		if flag in arguments: mode = flag; break
	if mode.is_empty(): return false
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.tutorial_visible = false; game.message = ""
	game.set_meta("capture_hud_clean", true); game.set_meta("capture_ui_frames", 6)
	game.set_meta("capture_ui_output", "res://assets/generated/ui/%s" % outputs[mode])
	match mode:
		"--capture-inventory": game.open_inventory()
		"--capture-shop": game.shop_open = true; game.shop_selected = 0; game.coins = 240
		"--capture-crafting": game.CraftingSystem.open(game, "workbench")
		"--capture-storage":
			game.home_chest_owned = true; game.current_location = "cottage_interior"; game.state.storage.change("carrot", 12); game.state.storage.change("crystal", 4); game.StorageSystem.open(game)
		"--capture-forge":
			game.current_location = "forge_interior"; game.change_inventory_count("sword", 1); game.materials.metal = 8; game.materials.stone = 5; game.open_forge()
	return true


## Убирает стартовые заставки из чистых HUD- и сюжетных эталонов после инициализации живого мира.
static func finalize(game: Node) -> void:
	if not game.has_meta("capture_hud_clean") and not game.has_meta("capture_story_clean"): return
	var life: Dictionary = game.FarmLifeSystem.state(game)
	life.first_day = 6; life.cutscene = ""; life.cutscene_timer = 0.0
	if game.has_meta("capture_story_clean"):
		game.current_location = "overworld"
		game.player = Vector2(1160, 650)
	game.message = ""; game.DiscoverySystem.dismiss(game)
	if game.has_meta("capture_notification_text"): game.message = String(game.get_meta("capture_notification_text"))


## Сохраняет системный UI-экран после стабилизации нескольких кадров и завершает режим предпросмотра.
static func update_capture(game: Node) -> bool:
	if not game.has_meta("capture_ui_frames"): return false
	if game.has_meta("capture_notification_text"): game.message = String(game.get_meta("capture_notification_text")); game.queue_redraw()
	var frames_left := int(game.get_meta("capture_ui_frames")) - 1
	game.set_meta("capture_ui_frames", frames_left)
	if frames_left > 0: return false
	game.remove_meta("capture_ui_frames")
	if game.has_meta("capture_notification_text"): game.remove_meta("capture_notification_text")
	var output := ProjectSettings.globalize_path(String(game.get_meta("capture_ui_output")))
	game.remove_meta("capture_ui_output")
	var error := game.get_viewport().get_texture().get_image().save_png(output)
	if error != OK: push_error("Не удалось сохранить предпросмотр интерфейса: %s" % error)
	game.get_tree().quit()
	return true
