extends Node2D

const TILE := 48
const FARM_ORIGIN := Vector2i(526, 850)
const FARM_SIZE := Vector2i(6, 5)
const TITLE_ART := preload("res://assets/title_art_rpg.png")
const PLANT_SHEET := preload("res://assets/game/environment/farm_plants.png")
const SUPPLY_SHEET := preload("res://assets/game/ui/farm_supplies.png")
const FARMER_SHEET := preload("res://assets/game/characters/farmer_walk.png")
const NPC_ATLAS := preload("res://assets/game/characters/npc_atlas.png")
const SLIME_SHEET := preload("res://assets/game/enemies/slime_idle.png")
const PREDATOR_PLANT_SHEET := preload("res://assets/game/enemies/predator_plant_idle.png")
const ORC_IDLE_SHEET := preload("res://assets/game/enemies/orc_idle.png")
const CAVE_GUARDIAN_TEXTURE := preload("res://assets/game/enemies/cave_guardian.png")
const ENEMY_RANK_ATLAS := preload("res://assets/game/enemies/enemy_rank_atlas.png")
const HAZARD_RANK_ATLAS := preload("res://assets/game/environment/hazard_rank_atlas.png")
const HERO_PROGRESSION_ATLAS := preload("res://assets/game/characters/hero_progression_atlas.png")
const BUILDING_ATLAS := preload("res://assets/game/buildings/building_atlas.png")
const COMPANION_ATLAS := preload("res://assets/game/buildings/companion_atlas.png")
const SKELETON_WARRIOR_TEXTURE := preload("res://assets/game/enemies/skeleton_warrior.png")
const CURSED_KNIGHT_TEXTURE := preload("res://assets/game/enemies/cursed_knight.png")
const FOREST_TREE := preload("res://assets/game/environment/forest_tree.png")
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_CRYSTAL := preload("res://assets/game/environment/cave_crystal.png")
const RESOURCE_CRYSTAL := preload("res://assets/game/resources/blue-crystal.png")
const RESOURCE_ROCK := preload("res://assets/game/resources/rock.png")
const NavigationSystem := preload("res://scripts/systems/navigation_system.gd")
const PlayerSystem := preload("res://scripts/systems/player_system.gd")
const InventorySystem := preload("res://scripts/systems/inventory_system.gd")
const CraftingSystem := preload("res://scripts/systems/crafting_system.gd")
const SaveSystem := preload("res://scripts/systems/save_system.gd")
const CombatSystem := preload("res://scripts/systems/combat_system.gd")
const WorldSystem := preload("res://scripts/systems/world_system.gd")
const FarmSystem := preload("res://scripts/systems/farm_system.gd")
const FishingSystem := preload("res://scripts/systems/fishing_system.gd")
const TreeSystem := preload("res://scripts/systems/tree_system.gd")
const PirateShipSystem := preload("res://scripts/systems/pirate_ship_system.gd")
const QuestSystem := preload("res://scripts/systems/quest_system.gd")
const RenderSystem := preload("res://scripts/systems/render_system.gd")
const ResourceSystem := preload("res://scripts/systems/resource_system.gd")
const ShopSystem := preload("res://scripts/systems/shop_system.gd")
const TutorialSystem := preload("res://scripts/systems/tutorial_system.gd")
const DiscoverySystem := preload("res://scripts/systems/discovery_system.gd")
const WildlifeSystem := preload("res://scripts/systems/wildlife_system.gd")
const LootContainerSystem := preload("res://scripts/systems/loot_container_system.gd")
const SkillSystem := preload("res://scripts/systems/skill_system.gd")
const ForageSystem := preload("res://scripts/systems/forage_system.gd")
const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const InputSystem := preload("res://scripts/systems/input_system.gd"); const InventoryInputSystem := preload("res://scripts/systems/inventory_input_system.gd")
const PresentationSystem := preload("res://scripts/systems/presentation_system.gd")
const InterfaceRenderer := preload("res://scripts/systems/interface_renderer.gd")
const AnimationSystem := preload("res://scripts/systems/animation_system.gd"); const AnimationRenderer := preload("res://scripts/systems/animation_renderer.gd"); const EnemyAnimationLibrary := preload("res://scripts/systems/enemy_animation_library.gd")
const DirectionalCharacterSystem := preload("res://scripts/systems/directional_character_system.gd"); const NpcMovementSystem := preload("res://scripts/systems/npc_movement_system.gd")
const AudioSystem := preload("res://scripts/systems/audio_system.gd")
const ContentRegistry := preload("res://scripts/systems/content_registry.gd")
const BuildingSystem := preload("res://scripts/systems/building_system.gd")
const CompanionSystem := preload("res://scripts/systems/companion_system.gd")
const EnvironmentHazardSystem := preload("res://scripts/systems/environment_hazard_system.gd")
const VisualAssetSystem := preload("res://scripts/systems/visual_asset_system.gd"); const PotionSystem := preload("res://scripts/systems/potion_system.gd"); const AnimationAssetRegistry := preload("res://scripts/systems/animation_asset_registry.gd")
const WorldEventSystem := preload("res://scripts/systems/world_event_system.gd"); const AtmosphereRenderer := preload("res://scripts/systems/atmosphere_renderer.gd"); const MoonGladeSystem := preload("res://scripts/systems/moon_glade_system.gd"); const MoonGladeRenderer := preload("res://scripts/systems/moon_glade_renderer.gd"); const CastleCampaignSystem := preload("res://scripts/systems/castle_campaign_system.gd"); const CastleCampaignRenderer := preload("res://scripts/systems/castle_campaign_renderer.gd")
const StorageSystem := preload("res://scripts/systems/storage_system.gd"); const EstateSystem := preload("res://scripts/systems/estate_system.gd"); const WorldMapSystem := preload("res://scripts/systems/world_map_system.gd"); const WorldMapRenderer := preload("res://scripts/systems/world_map_renderer.gd")
const ForgeSystem := preload("res://scripts/systems/forge_system.gd")
const ContractSystem := preload("res://scripts/systems/contract_system.gd"); const AdventurePolishSystem := preload("res://scripts/systems/adventure_polish_system.gd"); const AdventurePolishRenderer := preload("res://scripts/systems/adventure_polish_renderer.gd")
const ContractRenderer := preload("res://scripts/systems/contract_renderer.gd")
const VillageForegroundRenderer := preload("res://scripts/systems/village_foreground_renderer.gd"); const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const DebugPlaygroundSystem := preload("res://scripts/systems/debug_playground_system.gd"); const DebugPlaygroundRenderer := preload("res://scripts/systems/debug_playground_renderer.gd")
const MenuSystem := preload("res://scripts/systems/menu_system.gd"); const MenuRenderer := preload("res://scripts/systems/menu_renderer.gd"); const SettingsSystem := preload("res://scripts/systems/settings_system.gd")
const GameState := preload("res://scripts/state/game_state.gd")
const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")
const ITEM_HELMET := preload("res://assets/game/items/iron_helmet.png")
const ITEM_ARMOR := preload("res://assets/game/items/guardian_armor.png")
const ITEM_BOOTS := preload("res://assets/game/items/travel_boots.png")
const ITEM_DIAMOND := preload("res://assets/game/items/crystal_ring.png")
const ITEM_ORANGE := preload("res://assets/game/items/orange.png")
const ITEM_OAK_SHIELD := preload("res://assets/game/items/oak_shield.png")
const ITEM_WATERMELON := preload("res://assets/game/items/watermelon.png")
const ITEM_WATERMELON_SLICE := preload("res://assets/game/items/watermelon_slice.png")
const WATER_ANIMATION := preload("res://assets/game/fishing/Water Tile.png")
const FISH_ANIMATION := preload("res://assets/game/fishing/Fish Swimming.png")
const SPLASH_ANIMATION := preload("res://assets/game/fishing/Splash Effect.png")
const DEER_RUN_SHEET := preload("res://assets/game/wildlife/deer_run.png"); const FOX_RUN_SHEET := preload("res://assets/game/wildlife/fox_run.png"); const BOAR_RUN_SHEET := preload("res://assets/game/wildlife/boar_run.png"); const FANTASY_WILDLIFE_ATLAS := preload("res://assets/game/wildlife/fantasy_wildlife_atlas.png")
const WILDLIFE_ACTION_SHEETS := {"deer":preload("res://assets/game/wildlife/directional/deer_actions_8dir.png"),"fox":preload("res://assets/game/wildlife/directional/fox_actions_8dir.png"),"boar":preload("res://assets/game/wildlife/directional/boar_actions_8dir.png"),"bat":preload("res://assets/game/wildlife/directional/bat_actions_8dir.png"),"lizard":preload("res://assets/game/wildlife/directional/lizard_actions_8dir.png")}
const BONE_PILE_TEXTURE := preload("res://assets/game/world_loot/bone_pile.png")
const WORLD_SIZE := Vector2(2400, 1200)
const STAGE_DURATION := 5.0
const GROWTH_DURATION := 20.0
const MAX_BASE_HP := 100
const XP_PER_LEVEL := 50
const PLAYER_RADIUS := 18.0
const BRIDGE_RECT := Rect2(755, 575, 100, 190)
const TREE_POSITIONS := TreeSystem.POSITIONS
const CAVE_DECORATIONS := [Vector2(480,250), Vector2(720,600), Vector2(1040,300), Vector2(1380,720), Vector2(1720,280), Vector2(2050,620)]
const FORAGE_SPRITES := {
	# Атлас упакован в ячейки 72×72; область большего размера захватывает
	# соседние стадии роста и показывает несколько частей дерева одновременно.
	"berries": {"source": Rect2(696, 0, 72, 72), "size": Vector2(88, 88), "anchor": Vector2(44, 70)},
	"apple": {"source": Rect2(696, 144, 72, 72), "size": Vector2(88, 88), "anchor": Vector2(44, 70)},
	"nut": {"source": Rect2(696, 288, 72, 72), "size": Vector2(88, 88), "anchor": Vector2(44, 70)},
}

enum Tool { HOE, SEEDS, WATER, HAND, PICKAXE, ROD, AXE }

var state := GameState.new()
var player: Vector2:
	get: return state.player.position
	set(value): state.player.position = value
var camera_offset := Vector2.ZERO
var current_location: String:
	get: return state.world.location
	set(value): state.world.location = value
var cave_entrance_position := Vector2(180, 280)
var cave_exit_position := Vector2(180, 430)
var facing: Vector2:
	get: return state.player.facing
	set(value): state.player.facing = value
var speed := 210.0
var selected_tool: Tool = Tool.HOE
var plots: Dictionary:
	get: return state.world.plots
	set(value): state.world.plots = value
var day: int:
	get: return state.world.day
	set(value): state.world.day = value
var energy: int:
	get: return state.player.energy
	set(value): state.player.energy = value
var seeds: int:
	get: return state.inventory.count("seeds")
	set(value): state.inventory.set_count("seeds", value)
var carrots: int:
	get: return state.inventory.count("carrot")
	set(value): state.inventory.set_count("carrot", value)
var coins: int:
	get: return state.world.coins
	set(value): state.world.coins = value
var game_minutes: float:
	get: return state.world.minutes
	set(value): state.world.minutes = value
var message := ""
var language_screen := true
var language_selected := 0
var persist_locale_selection := true
var title_screen := true
var menu_state := MenuSystem.MenuState.new(); var settings_state := SettingsSystem.SettingsState.new()
var shop_open := false
var inventory_open := false; var inventory_filter := "all"
var inventory_selected := 0
var inventory_move_from := -1
var inventory_scroll_row := 0
var inventory_touch_drag_y := 0.0
var inventory_slots: Array:
	get: return state.inventory.slots
	set(value): state.inventory.slots = value
var hotbar_slots: Array:
	get: return state.inventory.hotbar
	set(value): state.inventory.hotbar = value
var selected_hotbar: int:
	get: return state.inventory.selected_hotbar
	set(value): state.inventory.selected_hotbar = value
var equipment: Dictionary:
	get: return state.inventory.equipment
	set(value): state.inventory.equipment = value
var iron_helmet: int:
	get: return state.inventory.count("iron_helmet")
	set(value): state.inventory.set_count("iron_helmet", value)
var guardian_armor: int:
	get: return state.inventory.count("guardian_armor")
	set(value): state.inventory.set_count("guardian_armor", value)
var travel_boots: int:
	get: return state.inventory.count("travel_boots")
	set(value): state.inventory.set_count("travel_boots", value)
var crystal_ring: int:
	get: return state.inventory.count("crystal_ring")
	set(value): state.inventory.set_count("crystal_ring", value)
var materials: Dictionary:
	get: return state.inventory.counts
	set(value): state.inventory.import_counts(value)
var crafting_open := false
var crafting_selected := 0
var storage_open := false
var storage_side := 0
var storage_selected := 0
var forge_open := false
var forge_selected := 0
var home_chest_owned: bool:
	get: return state.storage.owned
	set(value): state.storage.owned = value
var home_chest_counts: Dictionary:
	get: return state.storage.counts
	set(value): state.storage.counts = value
var forge_upgrades: Dictionary:
	get: return state.forge.upgrades
	set(value): state.forge.upgrades = value
var contract_open: bool:
	get: return state.contracts.board_open
	set(value): state.contracts.board_open = value
var contract_selected: int:
	get: return state.contracts.selected
	set(value): state.contracts.selected = value
var world_gate_position := Vector2(2200, 760)
var enemy_nodes := CombatSystem.default_enemies()
var hazard_nodes := EnvironmentHazardSystem.default_hazards()
var wildlife_nodes := WildlifeSystem.default_animals()
var world_loot_seed: int:
	get: return state.world.world_loot_seed
	set(value): state.world.world_loot_seed = value
var world_loot_nodes: Array:
	get: return state.world.world_loot_nodes
	set(value): state.world.world_loot_nodes = value
var dropped_items: Array:
	get: return state.world.dropped_items
	set(value): state.world.dropped_items = value
var shop_selected := 0
var shop_products := ShopSystem.default_products()
var move_left_held := false
var move_right_held := false
var move_up_held := false
var move_down_held := false
var action_held := false
var action_repeat_timer := 0.0
const ACTION_REPEAT_INTERVAL := 0.18
var attack_held := false
var attack_repeat_timer := 0.0
const ATTACK_REPEAT_INTERVAL := 0.4
var walk_animation_time := 0.0
var player_attack_timer := 0.0
var character_animation_directions := {}
var benchmark_autoplay := false
var benchmark_elapsed := 0.0
var audio_enabled := true
var audio_current_music := ""
var audio_last_sfx := ""
var audio_sfx_count := 0
var audio_sfx_slot := 0
var audio_music_slot := 1
var audio_music_fade := 0.0
# Сенсорный профиль и короткие реакции HUD не входят в сохранение: это только состояние представления.
var touch_controls_visible := OS.has_feature("mobile"); var hud_last_hp := -1; var hud_hp_flash := 0.0; var hud_last_coins := -1; var hud_coin_pop := 0.0; var hud_last_minute := -1; var hud_clock_tick := 0.0; var hud_last_weather := ""; var hud_weather_transition := 0.0
var companion_positions := {}
var companion_moving := {}
var companion_directions := {}
var companion_attack_timer := 0.0
var companion_heal_timer := 0.0; var npc_movement := {}

# RPG-состояние вертикального среза.
var player_hp: int:
	get: return state.player.hp
	set(value): state.player.hp = value
var player_max_hp: int:
	get: return state.player.max_hp
	set(value): state.player.max_hp = value
var player_xp: int:
	get: return state.player.xp
	set(value): state.player.xp = value
var player_level: int:
	get: return state.player.level
	set(value): state.player.level = value
var skill_points: int:
	get: return state.player.skill_points
	set(value): state.player.skill_points = value
var skill_levels := SkillSystem.default_levels()
var skill_xp := SkillSystem.default_xp()
var recruited_companions: Array[String]:
	get: return state.player.recruited_companions
	set(value): state.player.recruited_companions = value
var active_companions: Array[String]:
	get: return state.player.active_companions
	set(value): state.player.active_companions = value
var player_mana: int:
	get: return state.player.mana
	set(value): state.player.mana = value
var player_max_mana: int:
	get: return state.player.max_mana
	set(value): state.player.max_mana = value
var mana_regen_progress := 0.0
var stamina_regen_progress := 0.0
var strength_timer := 0.0; var regeneration_timer := 0.0; var speed_timer := 0.0; var invisibility_timer := 0.0; var defense_timer := 0.0
var regeneration_tick_timer := 0.0
var slime_position := Vector2(2010, 470)
var slime_hp := 3
var slime_alive := true
var slime_attack_timer := 0.0
var slime_visual_state := "idle"
var slime_visual_time := 0.0
var loot_available := false
var slime_gel: int:
	get: return state.inventory.count("slime")
	set(value): state.inventory.set_count("slime", value)
var wood: int:
	get: return state.inventory.count("wood")
	set(value): state.inventory.set_count("wood", value)
var sword_crafted := false
var sword_equipped := false
var has_pickaxe := true
var has_fishing_rod := true
var has_bow := false
var has_crystal_sword := false
var equipped_weapon := "none"
var stone: int:
	get: return state.inventory.count("stone")
	set(value): state.inventory.set_count("stone", value)
var crystals: int:
	get: return state.inventory.count("crystal")
	set(value): state.inventory.set_count("crystal", value)
var fish: int:
	get: return state.inventory.count("fish")
	set(value): state.inventory.set_count("fish", value)
var apples: int:
	get: return state.inventory.count("apple")
	set(value): state.inventory.set_count("apple", value)
var berries: int:
	get: return state.inventory.count("berries")
	set(value): state.inventory.set_count("berries", value)
var nuts: int:
	get: return state.inventory.count("nut")
	set(value): state.inventory.set_count("nut", value)
var mushrooms: int:
	get: return state.inventory.count("mushroom")
	set(value): state.inventory.set_count("mushroom", value)
var oranges: int:
	get: return state.inventory.count("orange")
	set(value): state.inventory.set_count("orange", value)
var food_nodes := ForageSystem.default_nodes()
var pond_position := Vector2(1550, 965)
var resource_nodes := ResourceSystem.default_nodes()
var npc_position := Vector2(350, 1020)
var guild_master_position := Vector2(1450, 535)
var herbalist_position := Vector2(1220, 535)
var workbench_position := Vector2(430, 1080)
var quest_active := false
var quest_complete := false
var mission_states := QuestSystem.default_states()
var quest_log_open := false; var quest_log_page := 0; var world_map_open := false
var skill_menu_open := false
var skill_menu_selected := 0
var tutorial_visible := true
var tutorial_step := 0
var tutorial_events_completed := {}
var seen_discoveries := {}
var discovery_current := {}
var discovery_timer := 0.0
var discovery_scan_timer := 0.0
var tutorial_steps := TutorialSystem.steps()


## Узкий контракт данных, который нужен отрисовщику. Композиционный корень
## переопределяет операции; объявления здесь позволяют проверять слой отдельно.
func language_button_rect(_index: int) -> Rect2:
	return Rect2()


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func targeted_plot() -> Vector2i:
	return Vector2i.ZERO


## Проверяет заявленное методом условие без изменения игрового состояния.
func valid_plot(_cell: Vector2i) -> bool:
	return false


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
func get_movement_direction() -> Vector2:
	return Vector2.ZERO


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func inventory_item_name(_kind: String) -> String:
	return ""


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func inventory_item_count(_kind: String) -> int:
	return 0


## Выполняет операцию «ближайшего взаимодействия» и возвращает результат согласно контракту метода.
func nearest_interaction() -> String:
	return ""
