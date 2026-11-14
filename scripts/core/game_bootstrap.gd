# Композиционный игровой узел не имеет отдельного статического класса без цикла preload.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends RefCounted

const GamePreviewBootstrap := preload("res://scripts/core/game_preview_bootstrap.gd")


## Выполняет последовательную инициализацию сервисов, данных, preview-режимов и сцены.
static func initialize(game: Node) -> void:
	preload("res://scripts/presentation/visual_sampling_system.gd").preserve_legacy(game)
	_initialize_services(game)
	_initialize_world(game)
	preload("res://scripts/presentation/viewport_world_context.gd").bind(game)
	var args := OS.get_cmdline_user_args()
	GamePreviewBootstrap.configure(game, args)
	_prepare_menu(game, args)
	_initialize_runtime_systems(game)
	GamePreviewBootstrap.finalize(game, args)
	if game.current_location != "overworld":
		game.DiscoverySystem.show_location(game, game.current_location)
	game.queue_redraw()


## Инициализирует ввод, контент, локализацию, настройки и звук до создания мира.
static func _initialize_services(game: Node) -> void:
	game.InputSystem.ensure_default_actions()
	game.talent_levels = game.TalentSystem.merge_levels(game.talent_levels)
	game.VisualAssetSystem.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	game.DirectionalCharacterSystem.HeroVisualSystem.warmup()
	preload("res://scripts/systems/celestial_dial_assets_system.gd").warmup()
	game.DirectionalCharacterSystem.GrandmotherVisualSystem.warmup()
	for texture in (
		game.DirectionalCharacterSystem.NPC_TEXTURES.slice(1)
		+ game.DirectionalCharacterSystem.COMPANION_TEXTURES.values()
	):
		game.DirectionalCharacterSystem.Residents.warmup(texture)
	game.WorldPolishRenderer.warmup_events()
	game.EnvironmentVisualSystem.texture("moon_portal")
	preload("res://scripts/systems/wildlife_visual_system.gd").warmup(game)
	for content_error in game.ContentRegistry.validate():
		push_error("Invalid game content: " + content_error)
	game.LocaleSystem.load_locale()
	if game.is_inside_tree():
		game.SettingsSystem.load(
			game,
			game.SettingsSystem.SETTINGS_PATH,
			not bool(game.get_meta("capture_windowed", false))
		)
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
		game.world_loot_seed = (
			game.LootContainerSystem.random_seed()
			if game.world_loot_seed == 0
			else game.world_loot_seed
		)
		game.world_loot_nodes = game.LootContainerSystem.generate(game.world_loot_seed)
	preload("res://scripts/systems/world_rng_system.gd").restore(game)


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
	# Renderers may only read these persisted sections.  Normalize them before the
	# first frame so two viewports cannot acquire different save state by drawing.
	game.CraftingSystem.Alchemy.state(game)
	game.FenceSystem.structures(game)
	game.SpellSystem.state(game)
	preload("res://scripts/systems/water_save_migration.gd").apply(game)
	game.FirstChapterSystem.initialize(game)
	game.UiPreviewSystem.finalize(game)
	game.sync_background_location()
	game.AudioSystem.update_context_music(game)
