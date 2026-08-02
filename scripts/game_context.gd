extends Node2D

const TILE := 48
const FARM_ORIGIN := Vector2i(408, 216)
const FARM_SIZE := Vector2i(6, 5)
const TITLE_ART := preload("res://assets/title_art_rpg.png")
const PLANT_SHEET := preload("res://assets/game/environment/farm_plants.png")
const SUPPLY_SHEET := preload("res://assets/game/ui/farm_supplies.png")
const FARMER_SHEET := preload("res://assets/game/characters/farmer_walk.png")
const SLIME_SHEET := preload("res://assets/game/enemies/slime_idle.png")
const PREDATOR_PLANT_SHEET := preload("res://assets/game/enemies/predator_plant_idle.png")
const ORC_IDLE_SHEET := preload("res://assets/game/enemies/orc_idle.png")
const CAVE_GUARDIAN_TEXTURE := preload("res://assets/game/enemies/cave_guardian.png")
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
const InputSystem := preload("res://scripts/systems/input_system.gd")
const PresentationSystem := preload("res://scripts/systems/presentation_system.gd")
const AnimationSystem := preload("res://scripts/systems/animation_system.gd")
const AnimationRenderer := preload("res://scripts/systems/animation_renderer.gd")
const AudioSystem := preload("res://scripts/systems/audio_system.gd")
const ContentRegistry := preload("res://scripts/systems/content_registry.gd")
const GameState := preload("res://scripts/state/game_state.gd")
const UI_FONT := preload("res://assets/game/fonts/ui_font.tres")
const ITEM_HELMET := preload("res://assets/game/items/iron_helmet.png")
const ITEM_ARMOR := preload("res://assets/game/items/guardian_armor.png")
const ITEM_BOOTS := preload("res://assets/game/items/travel_boots.png")
const ITEM_DIAMOND := preload("res://assets/game/items/crystal_ring.png")
const ITEM_ORANGE := preload("res://assets/game/items/orange.png")
const ITEM_HEALING_POTION := preload("res://assets/game/items/healing_potion.png")
const ITEM_OAK_SHIELD := preload("res://assets/game/items/oak_shield.png")
const ITEM_WATERMELON := preload("res://assets/game/items/watermelon.png")
const ITEM_WATERMELON_SLICE := preload("res://assets/game/items/watermelon_slice.png")
const WATER_ANIMATION := preload("res://assets/game/fishing/Water Tile.png")
const FISH_ANIMATION := preload("res://assets/game/fishing/Fish Swimming.png")
const SPLASH_ANIMATION := preload("res://assets/game/fishing/Splash Effect.png")
const DEER_RUN_SHEET := preload("res://assets/game/wildlife/deer_run.png")
const FOX_RUN_SHEET := preload("res://assets/game/wildlife/fox_run.png")
const BOAR_RUN_SHEET := preload("res://assets/game/wildlife/boar_run.png")
const MEADOW_LIZARD := preload("res://assets/game/wildlife/meadow_lizard.png")
const BONE_PILE_TEXTURE := preload("res://assets/game/world_loot/bone_pile.png")
const WORLD_SIZE := Vector2(2400, 1200)
const STAGE_DURATION := 5.0
const GROWTH_DURATION := 20.0
const MAX_BASE_HP := 100
const XP_PER_LEVEL := 50
const PLAYER_RADIUS := 18.0
const BRIDGE_RECT := Rect2(1450, 805, 110, 395)
const TREE_POSITIONS := [Vector2(1210,190), Vector2(1430,250), Vector2(1740,170), Vector2(1990,290), Vector2(2240,180), Vector2(1320,680), Vector2(1880,720), Vector2(2210,650)]
const CAVE_DECORATIONS := [Vector2(480,250), Vector2(720,600), Vector2(1040,300), Vector2(1380,720), Vector2(1720,280), Vector2(2050,620)]
const FORAGE_SPRITES := {
	# The atlas is packed in 72×72 cells here. A larger source region leaks
	# neighbouring growth stages into the same world sprite.
	"berries": {"source": Rect2(696, 0, 72, 72), "size": Vector2(88, 88), "anchor": Vector2(44, 70)},
	"apple": {"source": Rect2(696, 144, 72, 72), "size": Vector2(88, 88), "anchor": Vector2(44, 70)},
	"nut": {"source": Rect2(696, 288, 72, 72), "size": Vector2(88, 88), "anchor": Vector2(44, 70)},
}

enum Tool { HOE, SEEDS, WATER, HAND, PICKAXE, ROD }

var state := GameState.new()
var player: Vector2:
	get: return state.player.position
	set(value): state.player.position = value
var camera_offset := Vector2.ZERO
var current_location: String:
	get: return state.world.location
	set(value): state.world.location = value
var cave_entrance_position := Vector2(2290, 430)
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
var shop_open := false
var inventory_open := false
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
var world_gate_position := Vector2(2200, 760)
var enemy_nodes := CombatSystem.default_enemies()
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
var title_alpha := 1.0
var movement_enabled := false
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
var audio_step_timer := 0.0

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
var player_mana: int:
	get: return state.player.mana
	set(value): state.player.mana = value
var player_max_mana: int:
	get: return state.player.max_mana
	set(value): state.player.max_mana = value
var mana_regen_progress := 0.0
var stamina_regen_progress := 0.0
var strength_timer := 0.0
var regeneration_timer := 0.0
var speed_timer := 0.0
var regeneration_tick_timer := 0.0
var slime_position := Vector2(1580, 500)
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
var fishing_state := "idle"
var fishing_timer := 0.0
var pond_position := Vector2(650, 700)
var resource_nodes := ResourceSystem.default_nodes()
var npc_position := Vector2(325, 360)
var guild_master_position := Vector2(360, 620)
var herbalist_position := Vector2(850, 650)
var workbench_position := Vector2(760, 176)
var quest_active := false
var quest_complete := false
var mission_states := {"story_relic":"available", "side_seed":"available"}
var quest_log_open := false
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


## Узкий контракт данных, который нужен renderer. Композиционный корень
## переопределяет операции; объявления здесь позволяют проверять слой отдельно.
func language_button_rect(_index: int) -> Rect2:
	return Rect2()


func targeted_plot() -> Vector2i:
	return Vector2i.ZERO


func valid_plot(_cell: Vector2i) -> bool:
	return false


func get_movement_direction() -> Vector2:
	return Vector2.ZERO


func inventory_item_name(_kind: String) -> String:
	return ""


func inventory_item_count(_kind: String) -> int:
	return 0


func nearest_interaction() -> String:
	return ""
