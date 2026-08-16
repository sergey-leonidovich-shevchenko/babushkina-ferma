extends RefCounted

## Выполняет последовательную инициализацию сервисов, данных, preview-режимов и сцены.
static func initialize(game: Node) -> void:
	_initialize_services(game)
	_initialize_world(game)
	var args := OS.get_cmdline_user_args()
	_configure_basic_previews(game, args)
	_configure_world_previews(game, args)
	_configure_window_previews(game, args)
	_prepare_menu(game, args)
	_initialize_runtime_systems(game)
	_finalize_previews(game, args)
	if game.current_location != "overworld":
		game.DiscoverySystem.show_location(game, game.current_location)
	game.queue_redraw()

## Инициализирует ввод, контент, локализацию, настройки и звук до создания мира.
static func _initialize_services(game: Node) -> void:
	game.InputSystem.ensure_default_actions()
	game.talent_levels = game.TalentSystem.merge_levels(game.talent_levels)
	game.VisualAssetSystem.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	for content_error in game.ContentRegistry.validate():
		game.push_error("Invalid game content: " + content_error)
	game.LocaleSystem.load_locale()
	if game.is_inside_tree():
		game.SettingsSystem.load(game)
	game.AudioSystem.initialize(game)
	game.message = game.LocaleSystem.text("welcome")
	game.language_selected = maxi(game.LocaleSystem.LOCALES.find(game.LocaleSystem.current), 0)

## Создаёт стартовые грядки и детерминированный набор мировой добычи.
static func _initialize_world(game: Node) -> void:
	for y in game.FARM_SIZE.y:
		for x in game.FARM_SIZE.x:
			game.plots[Vector2i(x, y)] = {
				"tilled": false,
				"planted": false,
				"watered": false,
				"growth": 0.0,
				"stage": 0,
				"stage_flash": 0.0,
				"crop_kind": "carrot",
			}
	if game.world_loot_nodes.is_empty():
		game.world_loot_seed = game.LootContainerSystem.random_seed() if game.world_loot_seed == 0 else game.world_loot_seed
		game.world_loot_nodes = game.LootContainerSystem.generate(game.world_loot_seed)

## Настраивает preview главных экранов, персонажей и диагностических режимов.
static func _configure_basic_previews(game: Node, args: PackedStringArray) -> void:
	game.benchmark_autoplay = "--autoplay" in args
	if "--title-preview" in args:
		game.language_screen = false
		game.title_screen = true
	if game.benchmark_autoplay:
		game.language_screen = false
		game.title_screen = false
		game.move_right_held = true
	if "--inventory-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.grant_tester_kit()
		game.open_inventory()
	if "--creation-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.AdventurePolishSystem.begin_new_game(game)
	if "--dialogue-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.current_location = "overworld"
		game.AdventurePolishSystem.open_quest_dialogue(game, "miron")
	if "--buildings-preview" in args:
		_configure_world_view(game, Vector2(590, 360))
	if "--companions-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.current_location = "prison_interior"
		game.player = Vector2(576, 470)
		game.coins = 500
		game.skill_levels.leadership = 2
	if "--animation-preview" in args or "--capture-characters" in args:
		_configure_character_preview(game, "--capture-characters" in args)
	if "--enemy-levels-preview" in args or "--capture-creatures" in args:
		game.configure_enemy_levels_preview()
		if "--capture-creatures" in args:
			game.CreatureVisualProfileSystem.configure_preview(game)
	if "--enemy-animations-preview" in args:
		game.EnemyAnimationLibrary.configure_preview(game)
	_configure_debug_preview(game, args)

## Настраивает витрину восьми направлений героя, жителей и напарников.
static func _configure_character_preview(game: Node, capture: bool) -> void:
	_configure_world_view(game, Vector2(700, 850))
	game.npc_position = Vector2(500, 810)
	game.guild_master_position = Vector2(650, 790)
	game.herbalist_position = Vector2(830, 810)
	game.recruited_companions.assign(["mila", "borislav", "luna"])
	game.active_companions.assign(["mila", "borislav", "luna"])
	game.companion_positions = {
		"mila": Vector2(560, 930),
		"borislav": Vector2(700, 930),
		"luna": Vector2(840, 930),
	}
	if capture:
		game.enemy_nodes = []
		game.hazard_nodes = []
		game.wildlife_nodes = []
		game.set_meta("capture_character_frames", 8)
		game.set_meta("capture_first_level_clean", true)

## Настраивает стенд отладки, навигационную сетку, миссии и инспектор объектов.
static func _configure_debug_preview(game: Node, args: PackedStringArray) -> void:
	if "--debug-playground" in args:
		game.DebugPlaygroundSystem.configure(game)
	if "--debug-navigation" in args:
		game.DebugOverlaySystem.toggle(game)
	if "--debug-missions" in args:
		game.language_screen = false
		game.title_screen = false
		if not game.DebugOverlaySystem.active(game):
			game.DebugOverlaySystem.toggle(game)
		var debug_state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
		debug_state.missions_expanded = true
		game.set_meta(game.DebugOverlaySystem.META_KEY, debug_state)
	if "--debug-inspector" in args:
		_configure_world_view(game, Vector2(1160, 650))
		if not game.DebugOverlaySystem.active(game):
			game.DebugOverlaySystem.toggle(game)
		game.set_meta("debug_inspector_cursor", Vector2(576, 324))

## Настраивает ферму, окружение и отдельные каталоги мировых объектов для визуальной проверки.
static func _configure_world_previews(game: Node, args: PackedStringArray) -> void:
	if "--farm-life-preview" in args:
		_configure_world_view(game, Vector2(445, 710))
		game.state.world.estate.level = 3
		game.day = 4
	if "--farm-plot-preview" in args:
		_configure_farm_plot_preview(game)
	if "--crop-catalog-preview" in args:
		_configure_crop_catalog_preview(game)
	if "--first-level-preview" in args or "--capture-first-level" in args:
		_configure_world_view(game, Vector2(1160, 650))
	if "--capture-first-level" in args:
		game.set_meta("capture_first_level_frames", 6)
		game.set_meta("capture_first_level_clean", true)
	if "--water-navigation-preview" in args or "--capture-water-navigation" in args:
		game.WaterVisualSystem.configure_navigation_preview(game)
	game.BuildingVisualSystem.configure_from_arguments(game, args)
	game.EnvironmentVisualSystem.configure_from_arguments(game, args)
	game.FarmLifeVisualSystem.configure_preview(game, args)
	game.WorldLootRenderer.configure_preview(game, args)
	game.InteriorVisualSystem.configure_preview(game, args)
	if "--cave-preview" in args or "--capture-cave" in args:
		game.CaveVisualSystem.configure_preview(game)
		if "--capture-cave" in args: game.set_meta("capture_cave_frames", 6)
	if "--tree-stages-preview" in args or "--capture-tree-stages" in args:
		game.TreeSystem.configure_preview(game)
	if "--capture-tree-stages" in args: game.set_meta("capture_tree_stage_frames", 6)
	if "--fence-preview" in args or "--capture-fences" in args:
		game.FenceSystem.configure_preview(game)
	if "--capture-fences" in args: game.set_meta("capture_fence_frames", 6)
	if "--moon-glade-preview" in args:
		game.configure_moon_glade_preview()

## Заполняет пять тестовых грядок последовательными стадиями роста.
static func _configure_farm_plot_preview(game: Node) -> void:
	_configure_world_view(game, Vector2(224, 1030))
	var preview_stages := [0, 1, 2, 3, 4]
	for preview_x in preview_stages.size():
		var preview_plot: Dictionary = game.plots[Vector2i(preview_x, 1)]
		preview_plot.tilled = true
		preview_plot.planted = true
		preview_plot.watered = preview_x % 2 == 0
		preview_plot.stage = preview_stages[preview_x]
		preview_plot.growth = preview_x * game.STAGE_DURATION
		game.plots[Vector2i(preview_x, 1)] = preview_plot

## Заполняет тестовые грядки зрелыми культурами из полного каталога растений.
static func _configure_crop_catalog_preview(game: Node) -> void:
	_configure_world_view(game, Vector2(224, 1030))
	var crop_kinds: Array = game.CropCatalogSystem.CROPS.keys()
	for preview_index in mini(crop_kinds.size(), game.FARM_SIZE.x * game.FARM_SIZE.y):
		var preview_cell := Vector2i(preview_index % game.FARM_SIZE.x, preview_index / game.FARM_SIZE.x)
		var crop_plot: Dictionary = game.plots[preview_cell]
		crop_plot.tilled = true
		crop_plot.planted = true
		crop_plot.watered = true
		crop_plot.stage = 4
		crop_plot.growth = game.GROWTH_DURATION
		crop_plot.crop_kind = crop_kinds[preview_index]
		game.plots[preview_cell] = crop_plot

## Настраивает preview игровых окон, хранилища, кузницы, контрактов, истории и рыбалки.
static func _configure_window_previews(game: Node, args: PackedStringArray) -> void:
	if "--storage-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.current_location = "cottage_interior"
		game.home_chest_owned = true
		game.grant_tester_kit()
		game.StorageSystem.open(game)
	if "--forge-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.current_location = "forge_interior"
		game.grant_tester_kit()
		game.open_forge()
	if "--contracts-preview" in args:
		game.ContractSystem.configure_preview(game)
	if "--story-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.quest_log_open = true
		game.quest_log_page = 0
		if "--map-preview" in args:
			game.quest_log_open = false
			game.world_map_open = true
			game.state.world.estate.discovered = game.WorldMapSystem.LOCATIONS.keys()
	if "--fishing-preview" in args:
		game.FishingSystem.configure_preview(game)

## Подготавливает титульное меню и применяет отложенный запрос новой игры.
static func _prepare_menu(game: Node, args: PackedStringArray) -> void:
	if game.MenuSystem.consume_new_game_request():
		game.language_screen = false
		game.title_screen = false
		game.AdventurePolishSystem.begin_new_game(game)
	game.MenuSystem.prepare_title(game)
	if "--pause-preview" in args:
		game.language_screen = false
		game.title_screen = false
		game.MenuSystem.open_pause(game)
	game.UiPreviewSystem.configure(game)

## Запускает runtime-системы и синхронизирует фон и музыку после preview-конфигурации.
static func _initialize_runtime_systems(game: Node) -> void:
	game.NpcMovementSystem.initialize(game)
	game.FarmLifeSystem.initialize(game)
	game.FirstChapterSystem.initialize(game)
	game.UiPreviewSystem.finalize(game)
	game.sync_background_location()
	game.AudioSystem.update_context_music(game)

## Убирает заставки из preview и активирует редактор уровня после запуска runtime-систем.
static func _finalize_previews(game: Node, args: PackedStringArray) -> void:
	if "--farm-plot-preview" in args or "--debug-inspector" in args:
		_disable_farm_intro(game)
	if "--fence-preview" in args or "--capture-fences" in args:
		_disable_farm_intro(game)
		var fence_life: Dictionary = game.FarmLifeSystem.state(game)
		fence_life.achievements = ["first_week", "collector", "curator", "beloved", "rancher"]
	if game.has_meta("capture_first_level_clean"):
		_disable_farm_intro(game)
	if "--level-editor-preview" in args or "--capture-level-editor" in args:
		_configure_world_view(game, Vector2(1160, 650))
		game.LevelEditorSystem.toggle(game)
		var editor_state: Dictionary = game.get_meta(game.LevelEditorSystem.META_KEY)
		game.LevelEditorSystem.configure_preview(game, editor_state)
		game.set_meta(game.LevelEditorSystem.META_KEY, editor_state)
		if "--capture-level-editor" in args:
			game.set_meta("capture_level_editor_frames", 6)

## Переводит сцену в чистый вид первой локации с заданным положением героя.
static func _configure_world_view(game: Node, player_position: Vector2) -> void:
	game.language_screen = false
	game.title_screen = false
	game.current_location = "overworld"
	game.player = player_position
	game.tutorial_visible = false

## Отключает вступительную кат-сцену фермы для чистого автоматического preview.
static func _disable_farm_intro(game: Node) -> void:
	var life: Dictionary = game.FarmLifeSystem.state(game)
	life.first_day = 6
	life.cutscene = ""
	life.cutscene_timer = 0.0
	game.message = ""
	game.DiscoverySystem.dismiss(game)
