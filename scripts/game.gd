extends Node2D

const TILE := 48
const FARM_ORIGIN := Vector2i(408, 216)
const FARM_SIZE := Vector2i(6, 5)
const TITLE_ART := preload("res://assets/title_art.png")
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

var player := Vector2(260, 360)
var camera_offset := Vector2.ZERO
var current_location := "overworld"
var cave_entrance_position := Vector2(2290, 430)
var cave_exit_position := Vector2(180, 430)
var facing := Vector2.RIGHT
var speed := 210.0
var selected_tool: Tool = Tool.HOE
var plots: Dictionary = {}
var day := 1
var energy := 12
var seeds := 8
var carrots := 0
var coins := 20
var game_minutes := 6.0 * 60.0
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
var inventory_slots := ["seeds", "carrot", "pickaxe", "fishing_rod", "slime", "wood", "stone", "crystal", "fish", "sword", "bow", "crystal_sword", "apple", "berries", "nut", "mushroom", "iron_helmet", "guardian_armor", "travel_boots", "crystal_ring", "orange", "orc_blade", "red_crystal", "green_crystal", "raw_meat", "hide", "fur", "tusk", "bat_wing", "watermelon", "healing_potion", "oak_shield", "lizard_scale", ""]
var hotbar_slots := ["hoe", "seeds", "water", "hand", "pickaxe", "fishing_rod", "carrot", "apple", "berries", "mushroom"]
var selected_hotbar := 0
var equipment := {"head": "", "body": "", "legs": "", "hands": "", "offhand": "", "ring": ""}
var iron_helmet := 0
var guardian_armor := 0
var travel_boots := 0
var crystal_ring := 0
var materials := {"fiber":0,"rare_seeds":0,"metal":0,"bones":0,"ancient_key":0,"blue_gem":0,"red_crystal":0,"green_crystal":0,"orc_blade":0,"moon_relic":0,"raw_meat":0,"hide":0,"fur":0,"tusk":0,"bat_wing":0,"lizard_scale":0,"watermelon":0,"healing_potion":0,"oak_shield":0}
var crafting_open := false
var crafting_selected := 0
var world_gate_position := Vector2(2200, 760)
var enemy_nodes := [
	{"kind":"plant","location":"forest","position":Vector2(920,430),"hp":5,"alive":true},
	{"kind":"orc","location":"ruins","position":Vector2(1180,500),"hp":8,"alive":true},
	{"kind":"skeleton","location":"cave","position":Vector2(880,520),"hp":6,"alive":true},
	{"kind":"undead","location":"cursed","position":Vector2(1320,460),"hp":10,"alive":true},
	{"kind":"cave_guardian","location":"cave","position":Vector2(1450,500),"hp":12,"alive":true}
]
var wildlife_nodes := [
	{"kind":"deer","location":"overworld","position":Vector2(1320,430),"home":Vector2(1320,430),"direction":Vector2.RIGHT,"hp":3,"alive":true,"animation":0.0,"wander_timer":0.0,"panic":0.0},
	{"kind":"fox","location":"overworld","position":Vector2(1930,540),"home":Vector2(1930,540),"direction":Vector2.LEFT,"hp":3,"alive":true,"animation":0.4,"wander_timer":0.8,"panic":0.0},
	{"kind":"deer","location":"forest","position":Vector2(720,650),"home":Vector2(720,650),"direction":Vector2.DOWN,"hp":3,"alive":true,"animation":0.8,"wander_timer":1.0,"panic":0.0},
	{"kind":"fox","location":"forest","position":Vector2(1560,360),"home":Vector2(1560,360),"direction":Vector2.RIGHT,"hp":3,"alive":true,"animation":1.2,"wander_timer":0.3,"panic":0.0},
	{"kind":"boar","location":"forest","position":Vector2(2040,620),"home":Vector2(2040,620),"direction":Vector2.LEFT,"hp":5,"alive":true,"animation":0.2,"wander_timer":1.2,"panic":0.0},
	{"kind":"boar","location":"rocky","position":Vector2(1100,530),"home":Vector2(1100,530),"direction":Vector2.RIGHT,"hp":5,"alive":true,"animation":0.6,"wander_timer":0.5,"panic":0.0},
	{"kind":"bat","location":"cave","position":Vector2(680,430),"home":Vector2(680,430),"direction":Vector2.UP,"hp":2,"alive":true,"animation":0.0,"wander_timer":0.0,"panic":0.0},
	{"kind":"bat","location":"cave","position":Vector2(1780,610),"home":Vector2(1780,610),"direction":Vector2.LEFT,"hp":2,"alive":true,"animation":0.7,"wander_timer":1.0,"panic":0.0},
	{"kind":"bat","location":"cursed","position":Vector2(840,390),"home":Vector2(840,390),"direction":Vector2.RIGHT,"hp":2,"alive":true,"animation":1.4,"wander_timer":0.4,"panic":0.0},
	{"kind":"lizard","location":"forest","position":Vector2(1180,620),"home":Vector2(1180,620),"direction":Vector2.RIGHT,"hp":4,"alive":true,"animation":0.3,"wander_timer":0.5,"panic":0.0},
	{"kind":"lizard","location":"overworld","position":Vector2(1040,510),"home":Vector2(1040,510),"direction":Vector2.LEFT,"hp":4,"alive":true,"animation":1.1,"wander_timer":1.0,"panic":0.0}
]
var world_loot_seed := 0
var world_loot_nodes: Array = []
var dropped_items: Array = []
var shop_selected := 0
var shop_products := [
	{"name": "Семена моркови ×4", "kind": "seeds", "amount": 4, "buy": 5, "sell": 0, "icon": Rect2(0, 55, 36, 45)},
	{"name": "Морковь", "kind": "carrot", "buy": 10, "sell": 8, "icon": Rect2(34, 112, 30, 28)},
	{"name": "Лесные ягоды • 6 ч.", "kind": "berries", "buy": 0, "sell": 4, "forage": true},
	{"name": "Красный гриб • 12 ч.", "kind": "mushroom", "buy": 0, "sell": 7, "forage": true},
	{"name": "Сочный арбуз • 18 ч.", "kind": "watermelon", "buy": 0, "sell": 10, "forage": true},
	{"name": "Лесное яблоко • 1 день", "kind": "apple", "buy": 0, "sell": 12, "forage": true},
	{"name": "Крепкий орех • 2 дня", "kind": "nut", "buy": 0, "sell": 22, "forage": true}
]
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
var character_animation_directions := {}
var benchmark_autoplay := false
var benchmark_elapsed := 0.0

# RPG-состояние вертикального среза.
var player_hp := MAX_BASE_HP
var player_max_hp := MAX_BASE_HP
var player_xp := 0
var player_level := 1
var skill_points := 0
var skill_levels := SkillSystem.default_levels()
var skill_xp := SkillSystem.default_xp()
var player_mana := 40
var player_max_mana := 40
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
var loot_available := false
var slime_gel := 0
var wood := 2
var sword_crafted := false
var sword_equipped := false
var has_pickaxe := true
var has_fishing_rod := true
var has_bow := false
var has_crystal_sword := false
var equipped_weapon := "none"
var stone := 0
var crystals := 0
var fish := 0
var apples := 0
var berries := 0
var nuts := 0
var mushrooms := 0
var oranges := 0
var food_nodes := [
	{"position": Vector2(1320, 720), "location":"overworld", "kind":"mushroom", "active":true, "ready_at":0.0},
	{"position": Vector2(1740, 360), "location":"overworld", "kind":"berries", "active":true, "ready_at":0.0},
	{"position": Vector2(2010, 640), "location":"overworld", "kind":"nut", "active":true, "ready_at":0.0},
	{"position": Vector2(1110, 330), "location":"overworld", "kind":"apple", "active":true, "ready_at":0.0},
	{"position": Vector2(620, 690), "location":"forest", "kind":"berries", "active":true, "ready_at":0.0},
	{"position": Vector2(1420, 350), "location":"forest", "kind":"apple", "active":true, "ready_at":0.0},
	{"position": Vector2(1880, 680), "location":"forest", "kind":"nut", "active":true, "ready_at":0.0},
	{"position": Vector2(770, 510), "location":"overworld", "kind":"watermelon", "active":true, "ready_at":0.0},
	{"position": Vector2(1760, 740), "location":"forest", "kind":"watermelon", "active":true, "ready_at":0.0},
	{"position": Vector2(980, 720), "location":"forest", "kind":"mushroom", "active":true, "ready_at":0.0}
]
var fishing_state := "idle"
var fishing_timer := 0.0
var pond_position := Vector2(650, 700)
var resource_nodes := [
	{"position": Vector2(1190, 590), "location": "overworld", "kind": "stone", "hits": 2},
	{"position": Vector2(1830, 610), "location": "overworld", "kind": "red_crystal", "hits": 3},
	{"position": Vector2(520, 300), "location": "cave", "kind": "crystal", "hits": 3},
	{"position": Vector2(980, 570), "location": "cave", "kind": "stone", "hits": 2},
	{"position": Vector2(1500, 330), "location": "cave", "kind": "green_crystal", "hits": 3}
]
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
var tutorial_steps := [
	{"event": "move", "text": "Пройди немного стрелками или WASD"},
	{"event": "character_animation", "text": "Пройди во все четыре стороны и проверь анимацию героя"},
	{"event": "forage_harvest", "text": "Найди куст или плодовое дерево и собери урожай [E]"},
	{"event": "forage_regrow", "text": "Дождись повторного созревания дикого растения по игровым часам"},
	{"event": "forage_sale", "text": "Продай урожай в лавке: долгие культуры стоят дороже"},
	{"event": "talk", "text": "Подойди к бабушке и нажми E"},
	{"event": "hold_action", "text": "Выбери мотыгу [1] и держи движение + E"},
	{"event": "plant", "text": "Вспаши грядку [1], посади морковь [2]"},
	{"event": "water", "text": "Полей морковь лейкой [3]"},
	{"event": "rewater", "text": "Дождись красной капли и полей повторно"},
	{"event": "harvest", "text": "Дождись роста и собери морковь руками [4]"},
	{"event": "shop", "text": "Открой сельскую лавку клавишей E"},
	{"event": "trade", "text": "Купи или продай товар в таблице лавки"},
	{"event": "quest_complete", "text": "Принеси бабушке 10 морковок (F9 — тест-набор)"},
	{"event": "fight", "text": "Иди по дороге в лес и атакуй слизня [F]"},
	{"event": "loot", "text": "Подбери выпавшую слизь клавишей E"},
	{"event": "inventory", "text": "Открой инвентарь [I] и осмотри добычу"},
	{"event": "hotbar", "text": "В рюкзаке выбери предмет и назначь его клавишей 1–0"},
	{"event": "eat", "text": "Выбери еду в рюкзаке и нажми E или Enter"},
	{"event": "equipment", "text": "Выбери шлем или броню и надень клавишей Q"},
	{"event": "mine", "text": "Выбери кирку [5] и добудь камень или кристалл"},
	{"event": "fish", "text": "Выбери удочку [6] и поймай рыбу у пруда"},
	{"event": "craft_window", "text": "Открой верстак, выбери рецепт и создай предмет"},
	{"event": "equip", "text": "Надень или сними меч клавишей R"},
	{"event": "collision", "text": "Проверь препятствие и перейди реку только по мосту"},
	{"event": "travel", "text": "Найди светящийся вход в пещеру и нажми E"},
	{"event": "locations", "text": "Найди золотые врата и посети следующую локацию"},
	{"event": "mission_accept", "text": "Поговори со старостой или травницей и возьми миссию"},
	{"event": "mission_complete", "text": "Победи цель, подбери предмет и вернись за наградой"},
	{"event": "journal", "text": "Открой журнал [J] и проверь цели сюжетных и побочных миссий"},
	{"event": "side_mission", "text": "Выполни побочную миссию травницы Агафьи"},
	{"event": "colored_crystal", "text": "Добудь красный или зелёный кристалл киркой [5]"},
	{"event": "day", "text": "Вернись к дому и закончи день клавишей N"},
	{"event": "level_up", "text": "Набери 50 XP и повысь уровень персонажа"},
	{"event": "skill_point", "text": "Открой развитие [K] и вложи полученное очко в навык"},
	{"event": "profession", "text": "Развивай ремесло практикой: фермерство, крафт, бой, добычу или рыбалку"},
	{"event": "save", "text": "Сохрани игру [F5], затем проверь загрузку [F8]"},
	{"event": "wildlife", "text": "Найди пугливого зверя, проследи за побегом и добудь его лут [F]"},
	{"event": "world_loot", "text": "Найди случайный сундук, мешок, кости или хлам и обыщи его [E]"},
	{"event": "watermelon", "text": "Найди арбузную бахчу, собери арбуз [E] и съешь его из рюкзака"},
	{"event": "potion", "text": "Создай лечебное зелье на верстаке и используй его из рюкзака или hotbar"},
	{"event": "shield", "text": "Создай дубовый щит, открой [Tab] и надень его клавишей Q"},
	{"event": "lizard", "text": "Найди лугового листохвоста в деревне или лесу и добудь чешую [F]"}
]

func _ready() -> void:
	LocaleSystem.load_locale()
	message = LocaleSystem.text("welcome")
	language_selected = maxi(LocaleSystem.LOCALES.find(LocaleSystem.current), 0)
	for y in FARM_SIZE.y:
		for x in FARM_SIZE.x:
			plots[Vector2i(x, y)] = {"tilled": false, "planted": false, "watered": false, "growth": 0.0, "stage": 0, "stage_flash": 0.0}
	if world_loot_nodes.is_empty():
		world_loot_seed = LootContainerSystem.random_seed() if world_loot_seed == 0 else world_loot_seed
		world_loot_nodes = LootContainerSystem.generate(world_loot_seed)
	benchmark_autoplay = "--autoplay" in OS.get_cmdline_user_args()
	if benchmark_autoplay:
		language_screen = false
		title_screen = false
		move_right_held = true
	sync_background_location()
	DiscoverySystem.show_location(self, current_location)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if title_screen:
		queue_redraw()
		return
	update_game_clock(delta)
	update_crops(delta)
	update_combat(delta)
	update_fishing(delta)
	update_status_effects(delta)
	PlayerSystem.update_animation(self, delta)
	SkillSystem.update_resources(self, delta)
	ForageSystem.update(self)
	DiscoverySystem.update(self, delta)
	WildlifeSystem.update(self, delta)
	if benchmark_autoplay:
		update_benchmark_route(delta)
	if shop_open or inventory_open or crafting_open or quest_log_open or skill_menu_open:
		queue_redraw()
		return
	update_player_movement(delta)
	update_held_action(delta)
	update_held_attack(delta)
	update_camera()
	queue_redraw()

func update_benchmark_route(delta: float) -> void:
	benchmark_elapsed += delta
	if benchmark_elapsed < 4.0:
		move_right_held = true
		move_down_held = false
	elif benchmark_elapsed < 7.0:
		move_right_held = true
		move_down_held = true
	else:
		move_right_held = false
		move_down_held = false
		if current_location == "overworld":
			current_location = "cave"
			sync_background_location()
			player = Vector2(900, 480)

func update_player_movement(delta: float) -> void:
	var direction := get_movement_direction()
	if direction.length() == 0.0:
		return
	facing = direction
	var current_speed := speed * (1.3 if speed_timer > 0.0 else 1.0) * InventorySystem.speed_multiplier(self)
	move_player_with_collisions(direction * current_speed * delta)
	notify_tutorial("move")
	character_animation_directions[PlayerSystem.direction_row(direction)] = true
	if character_animation_directions.size() >= 4:
		notify_tutorial("character_animation")
	clamp_player_position()

func move_player_with_collisions(motion: Vector2) -> void:
	NavigationSystem.move(self, motion)

func is_position_walkable(position: Vector2) -> bool:
	return NavigationSystem.is_walkable(self, position)

func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	return NavigationSystem.circle_intersects_rect(center, radius, rect)

func update_game_clock(delta: float) -> void:
	# Одна реальная секунда равна одной игровой минуте.
	game_minutes += delta
	if game_minutes >= 24.0 * 60.0:
		game_minutes -= 24.0 * 60.0
		day += 1
		message = LocaleSystem.text("new_day", [day])

func update_crops(delta: float) -> void:
	FarmSystem.update(self, delta)

func get_movement_direction() -> Vector2:
	return PlayerSystem.movement_direction(self)

func update_movement_key_state(event: InputEventKey) -> bool:
	return PlayerSystem.update_movement_key(self, event)

func clear_movement_keys() -> void:
	PlayerSystem.clear_keys(self)

func set_action_key_state(event: InputEventKey) -> bool:
	if event.keycode != KEY_E and event.keycode != KEY_SPACE:
		return false
	action_held = event.pressed
	if event.pressed and not event.echo:
		action_repeat_timer = ACTION_REPEAT_INTERVAL
	return true

func update_held_action(delta: float) -> void:
	if not action_held or title_screen or shop_open or inventory_open:
		return
	action_repeat_timer -= delta
	if action_repeat_timer > 0.0:
		return
	action_repeat_timer = ACTION_REPEAT_INTERVAL
	perform_repeatable_action()

func set_attack_key_state(event: InputEventKey) -> bool:
	if event.keycode != KEY_F:
		return false
	attack_held = event.pressed
	if event.pressed and not event.echo:
		attack_repeat_timer = ATTACK_REPEAT_INTERVAL
	return true

func update_held_attack(delta: float) -> void:
	if not attack_held or title_screen or shop_open or inventory_open:
		return
	attack_repeat_timer -= delta
	if attack_repeat_timer <= 0.0:
		attack_repeat_timer = ATTACK_REPEAT_INTERVAL
		attack_nearest_enemy()

func perform_repeatable_action() -> bool:
	var interaction := nearest_interaction()
	# При удержании повторяем только добычу и полевые инструменты.
	# NPC, магазин, портал и верстак остаются одноразовыми действиями.
	if interaction.begins_with("resource:"):
		return mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("drop:"):
		return collect_dropped_item(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"):
		return collect_food(int(interaction.get_slice(":", 1)))
	if current_location == "overworld":
		var held_kind: String = hotbar_slots[selected_hotbar]
		if not InventorySystem.data(held_kind).has("tool"):
			return false
		use_selected_tool()
		notify_tutorial("hold_action")
		return true
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_movement_keys()

func clamp_player_position() -> void:
	player.x = clampf(player.x, 40.0, WORLD_SIZE.x - 40.0)
	player.y = clampf(player.y, 120.0, WORLD_SIZE.y - 80.0)

func update_camera() -> void:
	# Камера привязана к целым пикселям: pixel-art не дрожит на субпикселях.
	camera_offset.x = roundf(clampf(player.x - 576.0, 0.0, WORLD_SIZE.x - 1152.0))
	camera_offset.y = roundf(clampf(player.y - 324.0, 0.0, WORLD_SIZE.y - 648.0))
	var background := get_node_or_null("WorldBackground")
	if background:
		background.position = -camera_offset

func sync_background_location() -> void:
	var background := get_node_or_null("WorldBackground")
	if background:
		background.set_location(current_location)

func apply_immediate_key_response(event: InputEventKey) -> void:
	if event.echo:
		return
	var direction := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: direction = Vector2.LEFT
		KEY_RIGHT: direction = Vector2.RIGHT
		KEY_UP: direction = Vector2.UP
		KEY_DOWN: direction = Vector2.DOWN
	match event.physical_keycode:
		KEY_A: direction = Vector2.LEFT
		KEY_D: direction = Vector2.RIGHT
		KEY_W: direction = Vector2.UP
		KEY_S: direction = Vector2.DOWN
	if direction != Vector2.ZERO:
		facing = direction

func _unhandled_input(event: InputEvent) -> void:
	if language_screen:
		handle_language_input(event)
		return
	if title_screen:
		if event.is_pressed():
			title_screen = false
			message = "Вспаши землю клавишей E"
			queue_redraw()
		return

	if shop_open:
		handle_shop_input(event)
		return
	if quest_log_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_J, KEY_ESCAPE]:
			toggle_quest_log()
			queue_redraw()
		return
	if skill_menu_open:
		handle_skill_menu_input(event)
		return
	if crafting_open:
		handle_crafting_input(event)
		return
	if inventory_open:
		handle_inventory_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		title_screen = true
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		use_active_item()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_hotbar(0)
			KEY_2: select_hotbar(1)
			KEY_3: select_hotbar(2)
			KEY_4: select_hotbar(3)
			KEY_5: select_hotbar(4)
			KEY_6: select_hotbar(5)
			KEY_7: select_hotbar(6)
			KEY_8: select_hotbar(7)
			KEY_9: select_hotbar(8)
			KEY_0: select_hotbar(9)
			KEY_B: open_shop()
			KEY_N: sleep_until_morning()
			KEY_F: attack_nearest_enemy()
			KEY_R: toggle_sword()
			KEY_T: tutorial_visible = not tutorial_visible
			KEY_Y: reset_tutorial()
			KEY_F9: grant_tester_kit()
			KEY_F5: save_game()
			KEY_F8: load_game()
			KEY_I, KEY_TAB: open_inventory()
			KEY_J: toggle_quest_log()
			KEY_K: open_skill_menu()
			KEY_H: DiscoverySystem.dismiss(self)
		queue_redraw()

func handle_language_input(event: InputEvent) -> bool:
	var choose := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_UP]: language_selected = posmod(language_selected - 1, LocaleSystem.LOCALES.size())
		elif event.keycode in [KEY_RIGHT, KEY_DOWN]: language_selected = posmod(language_selected + 1, LocaleSystem.LOCALES.size())
		elif event.keycode in [KEY_ENTER, KEY_SPACE]: choose = true
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			language_selected = int(event.keycode - KEY_1)
			choose = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP]: language_selected = posmod(language_selected - 1, LocaleSystem.LOCALES.size())
		elif event.button_index in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN]: language_selected = posmod(language_selected + 1, LocaleSystem.LOCALES.size())
		elif event.button_index == JOY_BUTTON_A: choose = true
	elif event is InputEventScreenTouch and event.pressed:
		for index in LocaleSystem.LOCALES.size():
			if language_button_rect(index).has_point(event.position):
				language_selected = index
				choose = true
				break
	if choose:
		LocaleSystem.set_locale(LocaleSystem.LOCALES[language_selected], persist_locale_selection)
		language_screen = false
		message = LocaleSystem.ui("title")
	queue_redraw()
	return true

func language_button_rect(index: int) -> Rect2:
	var column := index % 2
	var row := index / 2
	return Rect2(250 + column * 340, 230 + row * 82, 312, 62)

func targeted_plot() -> Vector2i:
	var target := player + facing * 42.0
	return Vector2i(floori((target.x - FARM_ORIGIN.x) / TILE), floori((target.y - FARM_ORIGIN.y) / TILE))

func valid_plot(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < FARM_SIZE.x and cell.y < FARM_SIZE.y

func use_selected_tool() -> void:
	if selected_tool == Tool.PICKAXE:
		mine_nearby_resource()
		return
	if selected_tool == Tool.ROD:
		use_fishing_rod()
		return
	var cell := targeted_plot()
	if not valid_plot(cell):
		message = LocaleSystem.text("face_plot")
		return
	var plot: Dictionary = plots[cell]
	if selected_tool != Tool.HAND and energy <= 0:
		message = LocaleSystem.text("no_energy")
		return
	match selected_tool:
		Tool.HOE:
			if not plot.tilled:
				plot.tilled = true
				energy -= 1
				SkillSystem.award_profession_xp(self, "farming", 1)
				message = LocaleSystem.text("soil_ready")
			else: message = LocaleSystem.text("already_tilled")
		Tool.SEEDS:
			if plot.tilled and not plot.planted and seeds > 0:
				plot.planted = true
				plot.growth = 0.0
				plot.stage = 0
				plot.stage_flash = 0.0
				seeds -= 1
				energy -= 1
				award_xp(1, "Посадка моркови")
				SkillSystem.award_profession_xp(self, "farming", 2)
				notify_tutorial("plant")
			elif seeds <= 0: message = LocaleSystem.text("no_seeds")
			else: message = LocaleSystem.text("till_first")
		Tool.WATER:
			if plot.planted and not plot.watered:
				var is_second_watering: bool = plot.growth >= STAGE_DURATION * 2.0
				plot.watered = true
				energy -= 1
				SkillSystem.award_profession_xp(self, "farming", 1)
				message = LocaleSystem.text("watered")
				notify_tutorial("rewater" if is_second_watering else "water")
			else: message = LocaleSystem.text("nothing_water")
		Tool.HAND:
			if plot.planted and plot.growth >= GROWTH_DURATION:
				plot.planted = false
				plot.tilled = true
				plot.watered = false
				plot.growth = 0.0
				plot.stage = 0
				plot.stage_flash = 0.0
				var harvested: int = SkillSystem.harvest_count(self)
				carrots += harvested
				award_xp(3)
				SkillSystem.award_profession_xp(self, "farming", 4)
				message = LocaleSystem.text("harvested", [inventory_item_name("carrot"), harvested])
				notify_tutorial("harvest")
			else: message = LocaleSystem.text("not_ripe")
	plots[cell] = plot

func sleep_until_morning() -> void:
	if player.distance_to(Vector2(126, 190)) > 105.0:
		message = LocaleSystem.text("sleep_near_home")
		return
	day += 1
	game_minutes = 6.0 * 60.0
	energy = SkillSystem.max_stamina(self)
	player_mana = player_max_mana
	message = LocaleSystem.text("morning", [day])
	notify_tutorial("day")

func open_shop() -> void:
	if player.distance_to(Vector2(972, 278)) > 100.0:
		message = "Подойди к лавке справа"
		return
	shop_open = true
	shop_selected = 0
	clear_movement_keys()
	message = "Добро пожаловать в сельскую лавку"
	notify_tutorial("shop")

func nearest_interaction() -> String:
	var interactions := {}
	if current_location == "overworld":
		interactions = {
			"npc": npc_position,
			"guild_master": guild_master_position,
			"herbalist": herbalist_position,
			"shop": Vector2(972, 278),
			"crate": Vector2(820, 420),
			"workbench": workbench_position,
			"cave_entrance": cave_entrance_position
		}
		if loot_available:
			interactions["loot"] = slime_position
	else:
		interactions = {"cave_exit": cave_exit_position}
	interactions["world_gate"] = world_gate_position
	var nearest := ""
	var nearest_distance := 92.0
	for key in interactions:
		var distance := player.distance_to(interactions[key])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = key
	for index in dropped_items.size():
		var distance: float = player.distance_to(dropped_items[index].position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "drop:%d" % index
	for index in world_loot_nodes.size():
		var container: Dictionary = world_loot_nodes[index]
		if container.opened or container.location != current_location:
			continue
		var distance: float = player.distance_to(container.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "container:%d" % index
	for index in resource_nodes.size():
		var node: Dictionary = resource_nodes[index]
		if node.hits <= 0 or node.location != current_location:
			continue
		var distance: float = player.distance_to(node.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "resource:%d" % index
	for index in food_nodes.size():
		var food: Dictionary = food_nodes[index]
		if not food.active or food.get("location", "overworld") != current_location:
			continue
		var distance: float = player.distance_to(food.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = "food:%d" % index
	return nearest

func perform_context_action() -> bool:
	var interaction := nearest_interaction()
	if interaction.begins_with("drop:"):
		return collect_dropped_item(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("container:"):
		return LootContainerSystem.open(self, int(interaction.get_slice(":", 1)))
	if interaction.begins_with("resource:"):
		return mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"):
		return collect_food(int(interaction.get_slice(":", 1)))
	match interaction:
		"npc":
			talk_to_grandmother()
			return true
		"guild_master":
			return QuestSystem.talk(self, "story_relic")
		"herbalist":
			return QuestSystem.talk(self, "side_seed")
		"shop":
			open_shop()
			return true
		"crate":
			sell_carrots()
			return true
		"workbench":
			open_crafting()
			return true
		"loot":
			collect_loot()
			return true
		"cave_entrance":
			enter_cave()
			return true
		"cave_exit":
			exit_cave()
			return true
		"world_gate":
			WorldSystem.travel(self)
			return true
	return false

func mine_nearby_resource() -> bool:
	return ResourceSystem.mine_nearby(self)

func mine_resource(index: int) -> bool:
	return ResourceSystem.mine(self, index)

func is_near_fishing_water() -> bool:
	return FishingSystem.is_near_water(self)

func use_fishing_rod() -> bool:
	return FishingSystem.use_rod(self)

func update_fishing(delta: float) -> void:
	FishingSystem.update(self, delta)

func enter_cave() -> void:
	current_location = "cave"
	sync_background_location()
	player = cave_exit_position + Vector2(90, 0)
	update_camera()
	message = "Кристальная пещера"
	DiscoverySystem.show_location(self, current_location)
	notify_tutorial("travel")

func exit_cave() -> void:
	current_location = "overworld"
	sync_background_location()
	player = cave_entrance_position - Vector2(100, 0)
	update_camera()
	message = "Ты вернулся в зачарованный лес"
	DiscoverySystem.show_location(self, current_location)

func open_inventory() -> void:
	inventory_open = true
	inventory_move_from = -1
	InventorySystem.ensure_capacity(self)
	InventorySystem.keep_selection_visible(self)
	clear_movement_keys()
	notify_tutorial("inventory")
	message = LocaleSystem.text("inventory_open")

func inventory_item_count(kind: String) -> int:
	match kind:
		"seeds": return seeds
		"carrot": return carrots
		"slime": return slime_gel
		"wood": return wood
		"sword": return 1 if sword_crafted else 0
		"pickaxe": return 1 if has_pickaxe else 0
		"fishing_rod": return 1 if has_fishing_rod else 0
		"stone": return stone
		"crystal": return crystals
		"fish": return fish
		"bow": return 1 if has_bow else 0
		"crystal_sword": return 1 if has_crystal_sword else 0
		"apple": return apples
		"berries": return berries
		"nut": return nuts
		"mushroom": return mushrooms
		"orange": return oranges
		"iron_helmet": return iron_helmet
		"guardian_armor": return guardian_armor
		"travel_boots": return travel_boots
		"crystal_ring": return crystal_ring
	return materials.get(kind, 0)

func inventory_item_name(kind: String) -> String:
	if kind.is_empty():
		return "Пусто"
	return InventorySystem.data(kind).name

func change_inventory_count(kind: String, amount: int) -> bool:
	if amount < 0 and inventory_item_count(kind) < -amount:
		return false
	match kind:
		"seeds": seeds += amount
		"carrot": carrots += amount
		"slime": slime_gel += amount
		"wood": wood += amount
		"sword":
			if amount < 0:
				sword_crafted = false
				sword_equipped = false
			elif amount > 0:
				sword_crafted = true
		"pickaxe": has_pickaxe = amount > 0
		"fishing_rod": has_fishing_rod = amount > 0
		"stone": stone += amount
		"crystal": crystals += amount
		"fish": fish += amount
		"bow": has_bow = amount > 0
		"crystal_sword": has_crystal_sword = amount > 0
		"apple": apples += amount
		"berries": berries += amount
		"nut": nuts += amount
		"mushroom": mushrooms += amount
		"orange": oranges += amount
		"iron_helmet": iron_helmet += amount
		"guardian_armor": guardian_armor += amount
		"travel_boots": travel_boots += amount
		"crystal_ring": crystal_ring += amount
		_:
			if not materials.has(kind): return false
			materials[kind] += amount
	if amount > 0 and inventory_item_count(kind) > 0:
		InventorySystem.ensure_item_slot(self, kind)
	return true

func handle_inventory_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		InventorySystem.scroll(self, -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		queue_redraw()
		return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: inventory_selected = posmod(inventory_selected - 1, inventory_slots.size())
			JOY_BUTTON_DPAD_RIGHT: inventory_selected = posmod(inventory_selected + 1, inventory_slots.size())
			JOY_BUTTON_DPAD_UP: inventory_selected = posmod(inventory_selected - 6, inventory_slots.size())
			JOY_BUTTON_DPAD_DOWN: inventory_selected = posmod(inventory_selected + 6, inventory_slots.size())
			JOY_BUTTON_A: consume_selected_item()
			JOY_BUTTON_X: equip_selected_item()
			JOY_BUTTON_Y: inventory_open = false
		InventorySystem.keep_selection_visible(self)
		queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_I, KEY_TAB:
			inventory_open = false
			inventory_move_from = -1
		KEY_LEFT: inventory_selected = posmod(inventory_selected - 1, inventory_slots.size())
		KEY_RIGHT: inventory_selected = posmod(inventory_selected + 1, inventory_slots.size())
		KEY_UP: inventory_selected = posmod(inventory_selected - 6, inventory_slots.size())
		KEY_DOWN: inventory_selected = posmod(inventory_selected + 6, inventory_slots.size())
		KEY_PAGEUP: inventory_selected = maxi(0, inventory_selected - InventorySystem.VISIBLE_SLOTS)
		KEY_PAGEDOWN: inventory_selected = mini(inventory_slots.size() - 1, inventory_selected + InventorySystem.VISIBLE_SLOTS)
		KEY_M: move_inventory_slot()
		KEY_X: drop_selected_item()
		KEY_ENTER, KEY_E: consume_selected_item()
		KEY_Q: equip_selected_item()
		KEY_1: assign_selected_to_hotbar(0)
		KEY_2: assign_selected_to_hotbar(1)
		KEY_3: assign_selected_to_hotbar(2)
		KEY_4: assign_selected_to_hotbar(3)
		KEY_5: assign_selected_to_hotbar(4)
		KEY_6: assign_selected_to_hotbar(5)
		KEY_7: assign_selected_to_hotbar(6)
		KEY_8: assign_selected_to_hotbar(7)
		KEY_9: assign_selected_to_hotbar(8)
		KEY_0: assign_selected_to_hotbar(9)
		KEY_DELETE, KEY_BACKSPACE: delete_selected_item()
	InventorySystem.keep_selection_visible(self)
	queue_redraw()

func move_inventory_slot() -> void:
	if inventory_move_from < 0:
		inventory_move_from = inventory_selected
		message = "Выбери новый слот и нажми M"
		return
	var previous: String = inventory_slots[inventory_selected]
	inventory_slots[inventory_selected] = inventory_slots[inventory_move_from]
	inventory_slots[inventory_move_from] = previous
	inventory_move_from = -1
	message = LocaleSystem.text("moved")

func drop_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	if kind.is_empty() or not change_inventory_count(kind, -1):
		message = "В этом слоте нечего выбрасывать"
		return false
	dropped_items.append({"kind": kind, "count": 1, "position": player + facing * 50.0})
	message = LocaleSystem.text("dropped")
	return true

func delete_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	if kind.is_empty() or not change_inventory_count(kind, -1):
		message = "В этом слоте нечего удалять"
		return false
	message = "Удалена 1 единица: %s" % inventory_item_name(kind)
	return true

func collect_dropped_item(index: int) -> bool:
	if index < 0 or index >= dropped_items.size():
		return false
	var item: Dictionary = dropped_items[index]
	if player.distance_to(item.position) > 92.0:
		return false
	change_inventory_count(item.kind, item.count)
	dropped_items.remove_at(index)
	message = LocaleSystem.text("picked", [inventory_item_name(item.kind)])
	return true

func collect_food(index: int) -> bool:
	return ForageSystem.collect(self, index)

func consume_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	return consume_item(kind)

func consume_item(kind: String) -> bool:
	if kind not in ["carrot", "apple", "berries", "nut", "mushroom", "orange", "watermelon", "healing_potion"]:
		message = LocaleSystem.text("cannot_use")
		return false
	if not change_inventory_count(kind, -1):
		message = "Еда закончилась"
		return false
	match kind:
		"carrot":
			heal_player(15)
			message = "Морковь: +15 здоровья"
		"apple":
			heal_player(30)
			message = "Яблоко: +30 здоровья"
		"berries":
			regeneration_timer = 8.0
			regeneration_tick_timer = 0.0
			message = "Ягоды: регенерация +5 HP/с на 8 секунд"
		"nut":
			strength_timer = 12.0
			message = "Орех: +1 к силе на 12 секунд"
		"mushroom":
			speed_timer = 10.0
			message = "Гриб: скорость +30% на 10 секунд"
		"orange":
			heal_player(20)
			energy = mini(energy + 2, SkillSystem.max_stamina(self))
			message = "Апельсин: +20 здоровья и +2 энергии"
		"watermelon":
			heal_player(25)
			energy = mini(energy + 4, SkillSystem.max_stamina(self))
			message = "Арбуз: +25 здоровья и +4 энергии"
		"healing_potion":
			heal_player(60)
			message = "Лечебное зелье: +60 здоровья"
			notify_tutorial("potion")
	notify_tutorial("eat")
	return true

func select_hotbar(index: int) -> bool:
	return InventorySystem.select_hotbar(self, index)

func assign_selected_to_hotbar(index: int) -> bool:
	return InventorySystem.assign_hotbar(self, inventory_selected, index)

func equip_selected_item() -> bool:
	return InventorySystem.equip(self, inventory_slots[inventory_selected])

func use_active_item() -> bool:
	var kind: String = hotbar_slots[selected_hotbar]
	var item := InventorySystem.data(kind)
	if item.get("edible", false):
		return consume_item(kind)
	if item.has("tool"):
		selected_tool = item.tool
		use_selected_tool()
		return true
	message = LocaleSystem.text("cannot_use")
	return false

func heal_player(amount: int) -> int:
	return PlayerSystem.heal(self, amount)

func award_xp(amount: int, reason: String = "") -> void:
	PlayerSystem.award_xp(self, amount, reason)

func update_status_effects(delta: float) -> void:
	PlayerSystem.update_effects(self, delta)

func talk_to_grandmother() -> void:
	QuestSystem.talk_to_grandmother(self)

func toggle_quest_log() -> void:
	quest_log_open = not quest_log_open
	if quest_log_open:
		clear_movement_keys()
		message = LocaleSystem.text("journal_open")
		notify_tutorial("journal")

func open_skill_menu() -> void:
	skill_menu_open = not skill_menu_open
	if skill_menu_open:
		skill_menu_selected = clampi(skill_menu_selected, 0, SkillSystem.SKILLS.size() - 1)
		clear_movement_keys()
		message = "Выбери развитие. Свободных очков: %d" % skill_points

func handle_skill_menu_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: skill_menu_selected = posmod(skill_menu_selected - 1, SkillSystem.SKILLS.size())
			JOY_BUTTON_DPAD_RIGHT: skill_menu_selected = posmod(skill_menu_selected + 1, SkillSystem.SKILLS.size())
			JOY_BUTTON_DPAD_UP: skill_menu_selected = posmod(skill_menu_selected - 2, SkillSystem.SKILLS.size())
			JOY_BUTTON_DPAD_DOWN: skill_menu_selected = posmod(skill_menu_selected + 2, SkillSystem.SKILLS.size())
			JOY_BUTTON_A: SkillSystem.allocate(self, SkillSystem.SKILLS[skill_menu_selected].id)
			JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_START: skill_menu_open = false
		queue_redraw()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_K: skill_menu_open = false
		KEY_LEFT: skill_menu_selected = posmod(skill_menu_selected - 1, SkillSystem.SKILLS.size())
		KEY_RIGHT: skill_menu_selected = posmod(skill_menu_selected + 1, SkillSystem.SKILLS.size())
		KEY_UP: skill_menu_selected = posmod(skill_menu_selected - 2, SkillSystem.SKILLS.size())
		KEY_DOWN: skill_menu_selected = posmod(skill_menu_selected + 2, SkillSystem.SKILLS.size())
		KEY_ENTER, KEY_E: SkillSystem.allocate(self, SkillSystem.SKILLS[skill_menu_selected].id)
	queue_redraw()

func attack_slime() -> bool:
	var attack_range := 280.0 if equipped_weapon == "bow" else 105.0
	if not slime_alive or player.distance_to(slime_position) > attack_range:
		message = LocaleSystem.text("no_enemy")
		return false
	var damage := 1 + (1 if strength_timer > 0.0 else 0) + InventorySystem.damage_bonus(self)
	if equipped_weapon == "forest_sword": damage = 2
	elif equipped_weapon == "crystal_sword": damage = 3
	elif equipped_weapon == "bow": damage = 2
	slime_hp -= damage
	message = "Удар по слизню: -%d HP" % damage
	notify_tutorial("fight")
	if slime_hp <= 0:
		slime_alive = false
		loot_available = true
		award_xp(10)
		SkillSystem.award_profession_xp(self, "combat", 5)
		message = "Слизень побеждён! +10 опыта. Подбери добычу [E]"
	return true

func attack_nearest_enemy() -> bool:
	var enemy_index := CombatSystem.nearest(self)
	var wildlife_index := WildlifeSystem.nearest(self)
	var enemy_distance := INF
	var wildlife_distance := INF
	if enemy_index >= 0:
		enemy_distance = player.distance_to(enemy_nodes[enemy_index].position)
	if wildlife_index >= 0:
		wildlife_distance = player.distance_to(wildlife_nodes[wildlife_index].position)
	if wildlife_distance < enemy_distance:
		return WildlifeSystem.attack(self, wildlife_index)
	if enemy_index >= 0:
		return CombatSystem.attack(self, enemy_index)
	if wildlife_index >= 0:
		return WildlifeSystem.attack(self, wildlife_index)
	if current_location == "overworld":
		return attack_slime()
	message = LocaleSystem.text("no_enemy")
	return false

func update_combat(delta: float) -> void:
	if not slime_alive or player.distance_to(slime_position) > 72.0:
		slime_attack_timer = 0.0
		return
	slime_attack_timer += delta
	if slime_attack_timer >= 1.5:
		slime_attack_timer = 0.0
		var incoming_damage := InventorySystem.incoming_damage(self, 20)
		player_hp -= incoming_damage
		message = "Слизень атакует! -%d здоровья" % incoming_damage
		if player_hp <= 0:
			player_hp = player_max_hp
			player = Vector2(260, 360)
			coins = maxi(0, coins - 5)
			message = "Бабушка спасла тебя. Потеряно 5 монет"

func collect_loot() -> bool:
	if not loot_available or player.distance_to(slime_position) > 92.0:
		return false
	loot_available = false
	slime_gel += 3
	message = "Получено: слизь ×3"
	notify_tutorial("loot")
	return true

func craft_sword() -> bool:
	if sword_crafted and not has_crystal_sword:
		if crystals < 5:
			message = "Для улучшения меча нужно 5 кристаллов"
			return false
		crystals -= 5
		has_crystal_sword = true
		message = "Создан кристальный меч: 3 урона"
		return true
	if sword_crafted and has_crystal_sword:
		message = "Все доступные мечи уже созданы"
		return false
	if slime_gel < 3 or wood < 2:
		message = "Для меча нужно: слизь 3, древесина 2"
		return false
	slime_gel -= 3
	wood -= 2
	sword_crafted = true
	message = "Создан липкий лесной меч! Надень его [R]"
	notify_tutorial("craft")
	return true

func toggle_sword() -> bool:
	var weapons := ["none"]
	if sword_crafted: weapons.append("forest_sword")
	if has_bow: weapons.append("bow")
	if has_crystal_sword: weapons.append("crystal_sword")
	if weapons.size() == 1:
		message = "Оружия пока нет"
		return false
	var current_index := weapons.find(equipped_weapon)
	equipped_weapon = weapons[(current_index + 1) % weapons.size()]
	sword_equipped = equipped_weapon == "forest_sword" or equipped_weapon == "crystal_sword"
	var weapon_names := {"none": "кулаки", "forest_sword": "лесной меч", "bow": "охотничий лук", "crystal_sword": "кристальный меч"}
	message = "Оружие: %s" % weapon_names[equipped_weapon]
	notify_tutorial("equip")
	return true

func notify_tutorial(event_name: String) -> void:
	TutorialSystem.notify(self, event_name)

func reset_tutorial() -> void:
	TutorialSystem.reset(self)

func open_crafting() -> void:
	crafting_open = true
	crafting_selected = 0
	clear_movement_keys()
	message = LocaleSystem.text("recipe_select")

func handle_crafting_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_ESCAPE, KEY_C: crafting_open = false
		KEY_UP: crafting_selected = posmod(crafting_selected - 1, CraftingSystem.RECIPES.size())
		KEY_DOWN: crafting_selected = posmod(crafting_selected + 1, CraftingSystem.RECIPES.size())
		KEY_ENTER, KEY_E: CraftingSystem.craft(self, crafting_selected)
	queue_redraw()

func export_inventory_counts() -> Dictionary:
	var counts := {}
	for kind in ["seeds","carrot","slime","wood","stone","crystal","fish","apple","berries","nut","mushroom","orange","iron_helmet","guardian_armor","travel_boots","crystal_ring"]:
		counts[kind] = inventory_item_count(kind)
	for kind in materials: counts[kind] = materials[kind]
	return counts

func import_inventory_counts(counts: Dictionary) -> void:
	seeds = counts.get("seeds",0); carrots = counts.get("carrot",0); slime_gel = counts.get("slime",0); wood = counts.get("wood",0)
	stone = counts.get("stone",0); crystals = counts.get("crystal",0); fish = counts.get("fish",0)
	apples = counts.get("apple",0); berries = counts.get("berries",0); nuts = counts.get("nut",0); mushrooms = counts.get("mushroom",0); oranges = counts.get("orange",0)
	iron_helmet = counts.get("iron_helmet",0); guardian_armor = counts.get("guardian_armor",0); travel_boots = counts.get("travel_boots",0); crystal_ring = counts.get("crystal_ring",0)
	for kind in materials: materials[kind] = counts.get(kind,0)

func save_game() -> bool:
	var saved := SaveSystem.save(self)
	message = LocaleSystem.text("saved" if saved else "save_failed")
	if saved:
		notify_tutorial("save")
	return saved

func load_game() -> bool:
	var loaded := SaveSystem.load(self)
	message = LocaleSystem.text("loaded" if loaded else "load_failed")
	return loaded

func grant_tester_kit() -> void:
	coins = maxi(coins, 500)
	carrots = maxi(carrots, 10)
	seeds = maxi(seeds, 20)
	slime_gel = maxi(slime_gel, 10)
	wood = maxi(wood, 10)
	crystals = maxi(crystals, 10)
	apples = maxi(apples, 3)
	berries = maxi(berries, 3)
	nuts = maxi(nuts, 3)
	mushrooms = maxi(mushrooms, 3)
	oranges = maxi(oranges, 3)
	materials.watermelon = maxi(materials.watermelon, 3)
	materials.healing_potion = maxi(materials.healing_potion, 2)
	materials.oak_shield = maxi(materials.oak_shield, 1)
	materials.lizard_scale = maxi(materials.lizard_scale, 2)
	iron_helmet = maxi(iron_helmet, 1)
	guardian_armor = maxi(guardian_armor, 1)
	travel_boots = maxi(travel_boots, 1)
	crystal_ring = maxi(crystal_ring, 1)
	skill_points = maxi(skill_points, 3)
	player_hp = player_max_hp
	slime_alive = true
	slime_hp = 3
	loot_available = false
	ForageSystem.reset_all(self)
	for index in enemy_nodes.size():
		enemy_nodes[index].alive = true
		enemy_nodes[index].hp = CombatSystem.TYPES[enemy_nodes[index].kind].hp
	for index in wildlife_nodes.size():
		wildlife_nodes[index].alive = true
		wildlife_nodes[index].hp = WildlifeSystem.TYPES[wildlife_nodes[index].kind].hp
		wildlife_nodes[index].position = wildlife_nodes[index].home
	message = "QA-набор выдан: ресурсы, морковь, монеты и 3 очка навыков"

func handle_shop_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_B:
			shop_open = false
			message = "Заходи ещё!"
		KEY_UP:
			shop_selected = posmod(shop_selected - 1, shop_products.size())
		KEY_DOWN:
			shop_selected = posmod(shop_selected + 1, shop_products.size())
		KEY_ENTER, KEY_SPACE:
			buy_selected_product()
		KEY_X:
			sell_selected_product()
	queue_redraw()

func buy_selected_product() -> bool:
	return ShopSystem.buy(self, shop_selected)

func sell_selected_product() -> bool:
	return ShopSystem.sell(self, shop_selected)

func sell_carrots() -> void:
	if carrots > 0:
		var earned := carrots * 8
		coins += earned
		carrots = 0
		message = "Продано! +%d монет" % earned
	else: message = "В рюкзаке нет моркови"

func _draw() -> void:
	RenderSystem.draw(self)

func draw_title_screen() -> void:
	if title_screen:
		draw_texture_rect(TITLE_ART, Rect2(0, 0, 1152, 648), false)
		draw_rect(Rect2(0, 0, 1152, 648), Color(0.04, 0.08, 0.08, 0.25))
		draw_string(UI_FONT, Vector2(576, 120), LocaleSystem.ui("title"), HORIZONTAL_ALIGNMENT_CENTER, 760, 46, Color("fff4cf"))
		draw_string(UI_FONT, Vector2(576, 565), LocaleSystem.ui("press_any"), HORIZONTAL_ALIGNMENT_CENTER, 420, 24, Color.WHITE)

func draw_language_screen() -> void:
	draw_texture_rect(TITLE_ART, Rect2(0, 0, 1152, 648), false)
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.03, 0.07, 0.07, 0.82))
	draw_string(UI_FONT, Vector2(196, 112), LocaleSystem.ui("choose_language"), HORIZONTAL_ALIGNMENT_CENTER, 760, 38, Color("fff4cf"))
	for index in LocaleSystem.LOCALES.size():
		var rect := language_button_rect(index)
		var selected := index == language_selected
		draw_rect(rect, Color("e8bd62") if selected else Color("365548"))
		draw_rect(rect.grow(-4), Color("fff0bd") if selected else Color("4d7161"))
		draw_string(UI_FONT, rect.position + Vector2(10, 40), "%d  %s" % [index + 1, LocaleSystem.language_name(index)], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 24, Color("352e28") if selected else Color.WHITE)
	draw_string(UI_FONT, Vector2(236, 540), LocaleSystem.ui("confirm"), HORIZONTAL_ALIGNMENT_CENTER, 680, 18, Color.WHITE)

func draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("7fad5c"))
	# Редкие крупные кластеры вместо ~5000 отдельных draw calls каждый кадр.
	for y in range(150, int(WORLD_SIZE.y), 190):
		for x in range(70 + (y % 140), int(WORLD_SIZE.x), 210):
			draw_circle(Vector2(x, y), 3.0, Color("99bd6a"))
			draw_line(Vector2(x - 6, y + 7), Vector2(x, y - 2), Color("668f4b"), 2)
			draw_line(Vector2(x + 6, y + 7), Vector2(x, y - 2), Color("668f4b"), 2)
	# river
	draw_rect(Rect2(0, 860, WORLD_SIZE.x, 340), Color("4f9fb0"))
	for x in range(0, int(WORLD_SIZE.x), 70): draw_line(Vector2(x, 900), Vector2(x + 34, 900), Color("83c9c5"), 3)
	# house and bed marker
	draw_rect(Rect2(54, 130, 190, 150), Color("e5c478"))
	draw_colored_polygon(PackedVector2Array([Vector2(38,145), Vector2(149,72), Vector2(260,145)]), Color("9c5338"))
	draw_rect(Rect2(128, 216, 43, 64), Color("6b4328"))
	draw_string(UI_FONT, Vector2(66, 308), LocaleSystem.ui("home"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# shop
	draw_rect(Rect2(910, 194, 128, 98), Color("f3d88e"))
	draw_rect(Rect2(895, 175, 158, 30), Color("d66b45"))
	draw_string(UI_FONT, Vector2(913, 238), LocaleSystem.ui("seeds_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("55382b"))
	draw_string(UI_FONT, Vector2(905, 320), LocaleSystem.ui("shop_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Несколько стадий плодовых деревьев из бесплатного sprite sheet.
	draw_texture_rect_region(PLANT_SHEET, Rect2(270, 126, 290, 90), Rect2(94, 0, 290, 90))
	# selling crate
	draw_rect(Rect2(790, 392, 60, 54), Color("9c633b"))
	for i in 3: draw_line(Vector2(794, 402 + i * 15), Vector2(846, 402 + i * 15), Color("d09755"), 4)
	draw_string(UI_FONT, Vector2(753, 473), LocaleSystem.ui("sell_sign"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))

func draw_farm() -> void:
	for cell in plots:
		var plot: Dictionary = plots[cell]
		var rect := Rect2(FARM_ORIGIN + cell * TILE, Vector2(TILE - 3, TILE - 3))
		if plot.tilled:
			draw_rect(rect, Color("835238") if not plot.watered else Color("4e4539"))
			for line_y in 3: draw_line(rect.position + Vector2(5, 13 + line_y * 12), rect.position + Vector2(40, 13 + line_y * 12), Color("a86c47"), 2)
		else:
			draw_rect(rect, Color("73994f"))
		if plot.planted:
			draw_crop(rect.get_center(), plot)
			draw_crop_progress(rect, plot)
			if not plot.watered and plot.growth < GROWTH_DURATION:
				draw_water_needed_icon(rect.position + Vector2(8, 4))
	var target := targeted_plot()
	if valid_plot(target):
		draw_rect(Rect2(FARM_ORIGIN + target * TILE, Vector2(TILE - 3, TILE - 3)), Color("fff3a6"), false, 3)

func draw_crop(center: Vector2, plot: Dictionary) -> void:
	var stage: int = plot.stage
	var flash: float = plot.stage_flash
	var bounce := 1.0 + sin(flash * 18.0) * flash * 0.16
	if flash > 0.0:
		draw_circle(center - Vector2(0, 8), 20.0 * flash, Color(1.0, 0.91, 0.38, flash * 0.35), false, 3.0)
	if stage == 0:
		draw_circle(center + Vector2(0, 5), 4, Color("d6b66a"))
		draw_line(center + Vector2(0, 3), center - Vector2(0, 3), Color("5e8a42"), 3)
	elif stage == 1:
		draw_line(center + Vector2(0, 7), center - Vector2(0, 8 * bounce), Color("315a36"), 4)
		draw_colored_polygon(PackedVector2Array([center - Vector2(1, 6), center - Vector2(12, 12), center - Vector2(5, 2)]), Color("63a34e"))
		draw_colored_polygon(PackedVector2Array([center - Vector2(-1, 5), center - Vector2(-11, 11), center - Vector2(-5, 1)]), Color("4f843f"))
	elif stage == 2:
		draw_circle(center + Vector2(0, 8), 5, Color("e98a3d"))
		draw_line(center + Vector2(0, 5), center - Vector2(0, 14 * bounce), Color("315a36"), 5)
		draw_circle(center - Vector2(8, 10), 8 * bounce, Color("5d9849"))
		draw_circle(center + Vector2(8, -11), 8 * bounce, Color("4a813e"))
	elif stage == 3:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 3), center + Vector2(7, 3), center + Vector2(3, 18), center + Vector2(-2, 20)]), Color("ee7a32"))
		draw_line(center + Vector2(0, 5), center - Vector2(0, 18 * bounce), Color("315a36"), 5)
		draw_circle(center - Vector2(9, 13), 10 * bounce, Color("66a24d"))
		draw_circle(center + Vector2(9, -13), 10 * bounce, Color("4b833e"))
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 1), center + Vector2(8, 1), center + Vector2(4, 20), center + Vector2(0, 24), center + Vector2(-5, 19)]), Color("f4772d"))
		draw_line(center + Vector2(0, 3), center - Vector2(0, 19), Color("315a36"), 5)
		draw_circle(center - Vector2(10, 14), 11, Color("68a54d"))
		draw_circle(center + Vector2(10, -14), 11, Color("4b873e"))

func draw_crop_progress(rect: Rect2, plot: Dictionary) -> void:
	var progress: float = clampf(plot.growth / GROWTH_DURATION, 0.0, 1.0)
	var bar := Rect2(rect.position + Vector2(3, -10), Vector2(rect.size.x - 6, 7))
	if progress >= 1.0:
		# Иконка готовности: золотой ромб с зелёной галочкой.
		var icon_center := rect.position + Vector2(rect.size.x - 5, -7)
		draw_colored_polygon(PackedVector2Array([icon_center + Vector2(0, -10), icon_center + Vector2(10, 0), icon_center + Vector2(0, 10), icon_center + Vector2(-10, 0)]), Color("ffd45c"))
		draw_polyline(PackedVector2Array([icon_center + Vector2(-5, 0), icon_center + Vector2(-1, 4), icon_center + Vector2(6, -5)]), Color("28583b"), 3.0)
		return
	draw_rect(bar, Color("243b35"))
	var fill_color := Color("e58b3e").lerp(Color("6fcb62"), progress)
	draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * progress, bar.size.y - 2)), fill_color)
	# Четыре крупных деления — по одному на каждую стадию.
	for marker in range(1, 4):
		var marker_x := bar.position.x + bar.size.x * marker / 4.0
		draw_line(Vector2(marker_x, bar.position.y), Vector2(marker_x, bar.end.y), Color("f7e4b0"), 1.5)

func draw_water_needed_icon(center: Vector2) -> void:
	# Красная капля: заметный сигнал, что рост поставлен на паузу.
	var pulse := 1.0 + sin(Time.get_ticks_msec() / 130.0) * 0.08
	var points := PackedVector2Array([
		center + Vector2(0, -9) * pulse,
		center + Vector2(7, 1) * pulse,
		center + Vector2(5, 7) * pulse,
		center + Vector2(0, 10) * pulse,
		center + Vector2(-5, 7) * pulse,
		center + Vector2(-7, 1) * pulse
	])
	draw_colored_polygon(points, Color("e4473f"))
	draw_circle(center + Vector2(-2, 2), 2.0, Color("ffaaa0"))

func draw_player() -> void:
	var render_position := player.round()
	var moving := get_movement_direction() != Vector2.ZERO
	var frame := PlayerSystem.animation_frame(walk_animation_time, moving)
	var direction_row := PlayerSystem.direction_row(facing)
	var bob := roundf(PlayerSystem.sprite_bob(walk_animation_time, moving))
	var shadow_points := PackedVector2Array()
	for point_index in 16:
		var angle := TAU * point_index / 16.0
		shadow_points.append(render_position + Vector2(cos(angle) * 18.0, 8.0 + sin(angle) * 6.0))
	draw_colored_polygon(shadow_points, Color(0.08, 0.11, 0.10, 0.35))
	if moving and frame in [0, 3]:
		var dust_origin := render_position - facing * 12.0 + Vector2(0, 7)
		draw_circle(dust_origin + Vector2(-7, 1), 3.0, Color(0.70, 0.66, 0.55, 0.38))
		draw_circle(dust_origin + Vector2(6, -1), 2.0, Color(0.70, 0.66, 0.55, 0.28))
	var sprite_rect := Rect2(render_position - Vector2(40, 66) + Vector2(0, bob), Vector2(80, 80))
	draw_texture_rect_region(FARMER_SHEET, sprite_rect, Rect2(frame * 64, direction_row * 64, 64, 64))
	if equipped_weapon == "forest_sword":
		draw_line(render_position + facing * 10.0, render_position + facing * 34.0, Color("d9e4e6"), 5)
	elif equipped_weapon == "crystal_sword":
		draw_line(render_position + facing * 10.0, render_position + facing * 38.0, Color("69e6f0"), 7)
	elif equipped_weapon == "bow":
		draw_arc(render_position + facing * 18.0, 15, -1.4, 1.4, 12, Color("b77a45"), 4)

func draw_rpg_world() -> void:
	# Бабушка и верстак.
	draw_circle(npc_position - Vector2(0, 15), 13, Color("e7b68b"))
	draw_rect(Rect2(npc_position - Vector2(15, 2), Vector2(30, 35)), Color("854d6f"))
	draw_string(UI_FONT, npc_position + Vector2(-40, 55), LocaleSystem.entity("grandmother"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("293c2f"))
	draw_mission_npc(guild_master_position, LocaleSystem.quest("story_relic", "giver"), "story_relic", Color("496b8c"))
	draw_mission_npc(herbalist_position, LocaleSystem.quest("side_seed", "giver"), "side_seed", Color("568255"))
	draw_rect(Rect2(workbench_position - Vector2(32, 20), Vector2(64, 44)), Color("865334"))
	draw_line(workbench_position - Vector2(25, 8), workbench_position + Vector2(25, -8), Color("d09a59"), 5)
	draw_string(UI_FONT, workbench_position + Vector2(-45, 45), LocaleSystem.entity("workbench"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("293c2f"))
	if slime_alive:
		var slime_frame := int(Time.get_ticks_msec() / 140.0) % 6
		draw_texture_rect_region(SLIME_SHEET, Rect2(slime_position - Vector2(32, 40), Vector2(64, 64)), Rect2(slime_frame * 64, 0, 64, 64))
		draw_rect(Rect2(slime_position + Vector2(-28, -50), Vector2(56, 7)), Color("402d32"))
		draw_rect(Rect2(slime_position + Vector2(-27, -49), Vector2(54.0 * slime_hp / 3.0, 5)), Color("dc554b"))
	elif loot_available:
		draw_circle(slime_position, 13, Color("78d6a5"))
		draw_circle(slime_position - Vector2(4, 4), 4, Color("baf1c8"))
	# Вход в отдельную пещерную локацию.
	draw_circle(cave_entrance_position, 52, Color("283a43"))
	draw_circle(cave_entrance_position, 38 + sin(Time.get_ticks_msec() / 170.0) * 4, Color("66d5cf"), false, 6)
	draw_string(UI_FONT, cave_entrance_position + Vector2(-58, 78), LocaleSystem.location("cave"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7fff4"))

func draw_mission_npc(position: Vector2, npc_name: String, mission_id: String, color: Color) -> void:
	draw_circle(position - Vector2(0, 16), 13, Color("e6b38a"))
	draw_rect(Rect2(position - Vector2(16, 2), Vector2(32, 38)), color)
	draw_string(UI_FONT, position + Vector2(-62, 58), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 124, 15, Color("293c2f"))
	var state: String = mission_states.get(mission_id, QuestSystem.AVAILABLE)
	var marker := "!" if state == QuestSystem.AVAILABLE else ("✓" if state == QuestSystem.COMPLETED else "?")
	draw_circle(position - Vector2(0, 62), 16, Color("f1ca5c") if state != QuestSystem.COMPLETED else Color("70bd78"))
	draw_string(UI_FONT, position + Vector2(-8, -56), marker, HORIZONTAL_ALIGNMENT_CENTER, 16, 20, Color("3b3225"))

func forage_sprite_layout(kind: String, position: Vector2) -> Dictionary:
	var sprite: Dictionary = FORAGE_SPRITES.get(kind, {})
	if sprite.is_empty():
		return {}
	return {
		"source": sprite.source,
		"destination": Rect2(position - Vector2(sprite.anchor), Vector2(sprite.size)),
	}

func draw_food_nodes() -> void:
	for food in food_nodes:
		if food.get("location", "overworld") != current_location:
			continue
		var position: Vector2 = food.position
		var alpha := 1.0 if food.active else 0.36
		match food.kind:
			"mushroom":
				draw_texture_rect(RED_MUSHROOMS, Rect2(position - Vector2(28, 28), Vector2(56, 56)), false, Color(1, 1, 1, alpha))
			"watermelon":
				draw_texture_rect(ITEM_WATERMELON, Rect2(position - Vector2(32, 38), Vector2(64, 64)), false, Color(1, 1, 1, alpha))
			"berries", "apple", "nut":
				var layout := forage_sprite_layout(food.kind, position)
				draw_texture_rect_region(PLANT_SHEET, layout.destination, layout.source, Color(1, 1, 1, alpha))
		if food.active:
			draw_circle(position, 30 + sin(Time.get_ticks_msec() / 170.0) * 3, Color(1.0, 0.88, 0.32, 0.24), false, 3)
		else:
			draw_string(UI_FONT, position + Vector2(-55, 42), ForageSystem.remaining_text(self, food), HORIZONTAL_ALIGNMENT_CENTER, 110, 12, Color("e7d6a3"))

func fishing_animation_frame(frame_count: int, frame_ms: int = 140) -> int:
	return int(Time.get_ticks_msec() / frame_ms) % frame_count

func draw_fishing_animations() -> void:
	var water_frame := fishing_animation_frame(32, 180)
	draw_texture_rect_region(WATER_ANIMATION, Rect2(0, 860, WORLD_SIZE.x, 340), Rect2(water_frame * 16, 0, 16, 16), Color(1,1,1,0.32))
	var fish_frame := fishing_animation_frame(10, 130)
	draw_texture_rect_region(FISH_ANIMATION, Rect2(pond_position + Vector2(-24, -8), Vector2(48, 48)), Rect2(fish_frame * 16, 0, 16, 16))
	if fishing_state == "ready":
		var splash_frame := fishing_animation_frame(18, 80)
		draw_texture_rect_region(SPLASH_ANIMATION, Rect2(pond_position + Vector2(-32, -32), Vector2(64, 64)), Rect2(splash_frame * 16, 0, 16, 16))

func draw_resource_nodes() -> void:
	for node in resource_nodes:
		if node.hits <= 0 or node.location != current_location:
			continue
		var is_crystal: bool = node.kind in ["crystal", "red_crystal", "green_crystal"]
		var texture: Texture2D = RESOURCE_CRYSTAL if is_crystal else RESOURCE_ROCK
		var tint := Color.WHITE
		if node.kind == "red_crystal": tint = Color("ef6872")
		elif node.kind == "green_crystal": tint = Color("6bdc83")
		draw_texture_rect(texture, Rect2(node.position - Vector2(28, 28), Vector2(56, 56)), false, tint)

func draw_dropped_items() -> void:
	for item in dropped_items:
		if item_texture(item.kind):
			draw_item_icon(item.kind, Rect2(item.position - Vector2(22, 22), Vector2(44, 44)))
		else:
			draw_circle(item.position, 15, inventory_item_color(item.kind))
		draw_circle(item.position, 23 + sin(Time.get_ticks_msec() / 150.0) * 3, Color("fff0a8"), false, 3)
		draw_string(UI_FONT, item.position + Vector2(-55, 42), inventory_item_name(item.kind), HORIZONTAL_ALIGNMENT_CENTER, 110, 13, Color("fff4cf"))

func draw_world_loot() -> void:
	for container in world_loot_nodes:
		if container.location != current_location:
			continue
		var position: Vector2 = container.position.round()
		var alpha := 0.38 if container.opened else 1.0
		match container.kind:
			"chest":
				draw_rect(Rect2(position - Vector2(27, 16), Vector2(54, 34)), Color(0.35, 0.20, 0.10, alpha))
				draw_rect(Rect2(position - Vector2(24, 13), Vector2(48, 12)), Color(0.62, 0.36, 0.16, alpha))
				draw_rect(Rect2(position - Vector2(4, 4), Vector2(8, 13)), Color(0.93, 0.72, 0.25, alpha))
				if container.opened:
					draw_line(position - Vector2(24, 16), position + Vector2(20, -32), Color(0.48, 0.27, 0.12, alpha), 8)
			"bone_pile":
				draw_texture_rect(BONE_PILE_TEXTURE, Rect2(position - Vector2(38, 38), Vector2(76, 76)), false, Color(1, 1, 1, alpha))
			"sack":
				draw_circle(position + Vector2(0, 5), 22, Color(0.62, 0.47, 0.27, alpha))
				draw_colored_polygon(PackedVector2Array([position + Vector2(-11,-10),position + Vector2(11,-10),position + Vector2(5,-25),position + Vector2(-5,-25)]), Color(0.76, 0.61, 0.37, alpha))
			"trash":
				draw_circle(position, 25, Color(0.26, 0.31, 0.27, alpha))
				draw_line(position - Vector2(18, 14), position + Vector2(17, 13), Color(0.58, 0.46, 0.31, alpha), 7)
				draw_circle(position + Vector2(10, -8), 8, Color(0.43, 0.49, 0.45, alpha))
		if not container.opened:
			var pulse := 34.0 + sin(Time.get_ticks_msec() / 180.0 + float(container.id)) * 3.0
			draw_circle(position, pulse, Color(1.0, 0.82, 0.30, 0.35), false, 3)
		else:
			draw_string(UI_FONT, position + Vector2(-35, 38), LocaleSystem.ui("empty"), HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color(0.8, 0.8, 0.75, 0.55))

func draw_enemy_nodes_and_gate() -> void:
	draw_circle(world_gate_position, 42 + sin(Time.get_ticks_msec() / 180.0) * 4, Color("e6b85e"), false, 6)
	draw_string(UI_FONT, world_gate_position + Vector2(-75, 68), WorldSystem.name(WorldSystem.next_location(current_location)), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("fff0bd"))
	for enemy in enemy_nodes:
		if not enemy.alive or enemy.location != current_location: continue
		var data: Dictionary = CombatSystem.TYPES[enemy.kind]
		var position: Vector2 = enemy.position
		var enemy_texture := enemy_sprite_texture(enemy.kind)
		if enemy.kind in ["cave_guardian", "skeleton", "undead"]:
			var bob := sin(Time.get_ticks_msec() / 180.0) * 2.0
			var size := 124.0 if enemy.kind == "cave_guardian" else (92.0 if enemy.kind == "skeleton" else 108.0)
			draw_texture_rect(enemy_texture, Rect2(position - Vector2(size * 0.5, size * 0.70 + bob), Vector2(size, size)), false)
		elif enemy_texture:
			var frame := int(Time.get_ticks_msec() / 180.0) % 4
			var row := enemy_direction_row(player - position)
			var size := 82.0 if enemy.kind == "plant" else 74.0
			draw_texture_rect_region(enemy_texture, Rect2(position - Vector2(size * 0.5, size * 0.64), Vector2(size, size)), Rect2(frame * 64, row * 64, 64, 64))
		else:
			draw_circle(position, 30, data.color)
		draw_rect(Rect2(position - Vector2(31, 48), Vector2(62, 7)), Color("402d32"))
		draw_rect(Rect2(position - Vector2(30, 47), Vector2(60.0 * enemy.hp / float(data.hp), 5)), Color("dc554b"))
		draw_string(UI_FONT, position + Vector2(-65, 55), LocaleSystem.entity(enemy.kind), HORIZONTAL_ALIGNMENT_CENTER, 130, 14, Color("fff0bd"))

func enemy_sprite_texture(kind: String) -> Texture2D:
	match kind:
		"plant": return PREDATOR_PLANT_SHEET
		"orc": return ORC_IDLE_SHEET
		"cave_guardian": return CAVE_GUARDIAN_TEXTURE
		"skeleton": return SKELETON_WARRIOR_TEXTURE
		"undead": return CURSED_KNIGHT_TEXTURE
	return null

func enemy_direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x < 0.0 else 3
	return 1 if direction.y < 0.0 else 0

func draw_wildlife() -> void:
	for animal in wildlife_nodes:
		if not animal.alive or animal.location != current_location:
			continue
		var data: Dictionary = WildlifeSystem.TYPES[animal.kind]
		var position: Vector2 = animal.position.round()
		if animal.kind == "bat":
			var flap := 10.0 + sin(animal.animation * 14.0) * 8.0
			draw_colored_polygon(PackedVector2Array([position, position + Vector2(-28, -flap), position + Vector2(-18, 12)]), Color("6f6484"))
			draw_colored_polygon(PackedVector2Array([position, position + Vector2(28, -flap), position + Vector2(18, 12)]), Color("6f6484"))
			draw_circle(position, 10, Color("40374e"))
			draw_circle(position + Vector2(-4, -2), 2, Color("e78a70"))
			draw_circle(position + Vector2(4, -2), 2, Color("e78a70"))
		elif animal.kind == "lizard":
			var bob := sin(animal.animation * 7.0) * 2.0
			draw_texture_rect(MEADOW_LIZARD, Rect2(position - Vector2(48, 34 - bob), Vector2(96, 64)), false)
		else:
			var texture: Texture2D = DEER_RUN_SHEET
			if animal.kind == "fox": texture = FOX_RUN_SHEET
			elif animal.kind == "boar": texture = BOAR_RUN_SHEET
			var row := 0
			if absf(animal.direction.x) > absf(animal.direction.y): row = 2 if animal.direction.x < 0.0 else 3
			elif animal.direction.y < 0.0: row = 1
			var frame: int = int(animal.animation * 9.0) % int(data.frames)
			draw_texture_rect_region(texture, Rect2(position - Vector2(32, 40), Vector2(64, 64)), Rect2(frame * 32, row * 32, 32, 32))
		if animal.hp < data.hp:
			draw_rect(Rect2(position - Vector2(25, 44), Vector2(50, 5)), Color("402d32"))
			draw_rect(Rect2(position - Vector2(24, 43), Vector2(48.0 * animal.hp / float(data.hp), 3)), Color("dc554b"))

func draw_cave_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("18232c"))
	for y in range(100, int(WORLD_SIZE.y), 230):
		for x in range(80, int(WORLD_SIZE.x), 260):
			draw_circle(Vector2(x + (y % 160), y), 4, Color("34434b"))
	draw_circle(cave_exit_position, 54, Color("0e151a"))
	draw_circle(cave_exit_position, 40, Color("b1e4d5"), false, 5)
	var crystal_positions := [Vector2(480, 250), Vector2(720, 600), Vector2(1040, 300), Vector2(1380, 720), Vector2(1720, 280), Vector2(2050, 620)]
	for crystal_position in crystal_positions:
		draw_texture_rect(CAVE_CRYSTAL, Rect2(crystal_position - Vector2(32, 32), Vector2(64, 64)), false)
		draw_circle(crystal_position, 42, Color(0.35, 0.95, 0.85, 0.12))
	draw_string(UI_FONT, Vector2(90, 100), LocaleSystem.location("cave").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("9ce9dd"))

func inventory_item_color(kind: String) -> Color:
	return InventorySystem.data(kind).color

func item_texture(kind: String) -> Texture2D:
	match kind:
		"iron_helmet": return ITEM_HELMET
		"guardian_armor": return ITEM_ARMOR
		"travel_boots": return ITEM_BOOTS
		"crystal_ring": return ITEM_DIAMOND
		"orange": return ITEM_ORANGE
		"healing_potion": return ITEM_HEALING_POTION
		"oak_shield": return ITEM_OAK_SHIELD
		"watermelon": return ITEM_WATERMELON_SLICE
	return null

func draw_item_icon(kind: String, rect: Rect2) -> void:
	var texture := item_texture(kind)
	if texture:
		draw_texture_rect(texture, rect, false)
	else:
		draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.34, inventory_item_color(kind))

func interaction_position(interaction: String) -> Vector2:
	if interaction.begins_with("drop:"):
		var index := int(interaction.get_slice(":", 1))
		if index >= 0 and index < dropped_items.size():
			return dropped_items[index].position
	if interaction.begins_with("container:"):
		var index := int(interaction.get_slice(":", 1))
		if index >= 0 and index < world_loot_nodes.size():
			return world_loot_nodes[index].position
	if interaction.begins_with("resource:"):
		var index := int(interaction.get_slice(":", 1))
		if index >= 0 and index < resource_nodes.size():
			return resource_nodes[index].position
	if interaction.begins_with("food:"):
		var index := int(interaction.get_slice(":", 1))
		if index >= 0 and index < food_nodes.size():
			return food_nodes[index].position
	match interaction:
		"npc": return npc_position
		"guild_master": return guild_master_position
		"herbalist": return herbalist_position
		"shop": return Vector2(972, 278)
		"crate": return Vector2(820, 420)
		"workbench": return workbench_position
		"loot": return slime_position
		"cave_entrance": return cave_entrance_position
		"cave_exit": return cave_exit_position
		"world_gate": return world_gate_position
	return Vector2.ZERO

func draw_interaction_highlight() -> void:
	var interaction := nearest_interaction()
	if interaction.is_empty():
		return
	var center := interaction_position(interaction)
	var pulse := 34.0 + sin(Time.get_ticks_msec() / 130.0) * 4.0
	draw_circle(center, pulse, Color("ffe36e"), false, 4.0)
	draw_string(UI_FONT, center + Vector2(-45, -48), LocaleSystem.ui("action"), HORIZONTAL_ALIGNMENT_CENTER, 90, 16, Color("fff4bd"))

func draw_ui() -> void:
	draw_rect(Rect2(0, 0, 1152, 106), Color("182f2b"))
	var hours := floori(game_minutes / 60.0)
	var minutes := int(game_minutes) % 60
	draw_string(UI_FONT, Vector2(24, 34), LocaleSystem.ui("day", [day, hours, minutes]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe39d"))
	draw_string(UI_FONT, Vector2(24, 68), LocaleSystem.ui("resources", [energy, coins, seeds, carrots]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_rect(Rect2(830, 14, 145, 36), Color("4d6659"))
	var skill_button_text := LocaleSystem.ui("skills") if skill_points == 0 else "%s (%d)" % [LocaleSystem.ui("skills"), skill_points]
	draw_string(UI_FONT, Vector2(840, 38), skill_button_text, HORIZONTAL_ALIGNMENT_CENTER, 125, 14, Color("fff0bd"))
	draw_rect(Rect2(990, 14, 145, 36), Color("4d6659"))
	draw_string(UI_FONT, Vector2(1000, 38), LocaleSystem.ui("quests"), HORIZONTAL_ALIGNMENT_CENTER, 125, 14, Color("fff0bd"))
	draw_player_status_bars()
	draw_string(UI_FONT, Vector2(390, 68), "Слизь %d  Камень %d  Кристалл %d  Рыба %d  Оружие: %s" % [slime_gel, stone, crystals, fish, equipped_weapon], HORIZONTAL_ALIGNMENT_LEFT, 740, 13, Color("bde8d2"))
	if fishing_state == "casting":
		draw_string(UI_FONT, Vector2(576, 205), "Поплавок... %.1f" % maxf(fishing_timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 260, 20, Color("d7f6ff"))
	elif fishing_state == "ready":
		draw_circle(Vector2(576, 195), 22 + sin(Time.get_ticks_msec() / 100.0) * 3, Color("ffdc5c"))
		draw_string(UI_FONT, Vector2(576, 202), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 24, Color("5b4526"))
	draw_rect(Rect2(190, 510, 772, 34), Color("182f2b"))
	draw_string(UI_FONT, Vector2(211, 533), message, HORIZONTAL_ALIGNMENT_CENTER, 730, 17, Color("fff4cf"))
	draw_hotbar()
	draw_mission_tracker()
	if tutorial_visible and tutorial_step < tutorial_steps.size():
		draw_rect(Rect2(18, 108, 420, 68), Color("263c36"))
		draw_string(UI_FONT, Vector2(34, 132), LocaleSystem.ui("tutorial", [tutorial_step + 1, tutorial_steps.size()]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ed6b3"))
		draw_string(UI_FONT, Vector2(34, 160), LocaleSystem.tutorial(tutorial_steps[tutorial_step].event), HORIZONTAL_ALIGNMENT_LEFT, 385, 17, Color.WHITE)
	draw_discovery_card()
	if shop_open:
		draw_shop()
	if inventory_open:
		draw_inventory()
	if crafting_open:
		draw_crafting_window()
	if quest_log_open:
		draw_quest_log()
	if skill_menu_open:
		draw_skill_menu()

func draw_discovery_card() -> void:
	if discovery_current.is_empty():
		return
	var card := discovery_card_rect()
	draw_rect(card, Color(0.08, 0.12, 0.11, 0.96))
	draw_rect(card.grow(-4), Color("355347"))
	draw_rect(Rect2(card.position + Vector2(4, 4), Vector2(card.size.x - 8, 28)), Color("d5ad55"))
	draw_string(UI_FONT, card.position + Vector2(12, 23), LocaleSystem.ui("new_nearby"), HORIZONTAL_ALIGNMENT_LEFT, 205, 11, Color("352c21"))
	draw_string(UI_FONT, card.position + Vector2(220, 23), LocaleSystem.ui("hide"), HORIZONTAL_ALIGNMENT_RIGHT, 76, 11, Color("352c21"))
	draw_string(UI_FONT, card.position + Vector2(12, 51), discovery_current.title, HORIZONTAL_ALIGNMENT_LEFT, 282, 17, Color("fff0bd"))
	draw_multiline_string(UI_FONT, card.position + Vector2(12, 72), discovery_current.text, HORIZONTAL_ALIGNMENT_LEFT, 282, 12, 2, Color.WHITE)
	var ratio := clampf(discovery_timer / DiscoverySystem.CARD_DURATION, 0.0, 1.0)
	draw_rect(Rect2(card.position + Vector2(8, card.size.y - 7), Vector2((card.size.x - 16) * ratio, 3)), Color("f1ca5c"))

func discovery_card_rect() -> Rect2:
	return Rect2(824, 354, 310, 108)

func draw_mission_tracker() -> void:
	var lines: Array[String] = []
	if quest_active:
		lines.append("Бабушкина морковь: %d/10" % mini(carrots, 10))
	for mission_id in QuestSystem.MISSIONS:
		if mission_states.get(mission_id) == QuestSystem.ACTIVE:
			lines.append("%s — %s" % [QuestSystem.mission_data(mission_id).title, QuestSystem.objective_text(self, mission_id)])
	if lines.is_empty():
		return
	var height := 30.0 + lines.size() * 22.0
	draw_rect(Rect2(790, 108, 338, height), Color(0.10, 0.18, 0.16, 0.92))
	draw_string(UI_FONT, Vector2(804, 130), LocaleSystem.ui("quest_tracker"), HORIZONTAL_ALIGNMENT_LEFT, 310, 15, Color("f1ca5c"))
	for index in lines.size():
		draw_string(UI_FONT, Vector2(804, 153 + index * 22), lines[index], HORIZONTAL_ALIGNMENT_LEFT, 310, 14, Color("fff4cf"))

func draw_quest_log() -> void:
	draw_rect(Rect2(120, 62, 912, 524), Color("29251f"))
	draw_rect(Rect2(140, 82, 872, 484), Color("e6d3a4"))
	draw_rect(Rect2(140, 82, 872, 64), Color("5d4937"))
	draw_string(UI_FONT, Vector2(326, 125), LocaleSystem.ui("quest_log"), HORIZONTAL_ALIGNMENT_CENTER, 500, 28, Color("fff1c4"))
	var row_y := 172.0
	for mission_id in QuestSystem.MISSIONS:
		var mission: Dictionary = QuestSystem.mission_data(mission_id)
		var state: String = mission_states.get(mission_id, QuestSystem.AVAILABLE)
		var state_name: String = {QuestSystem.AVAILABLE:LocaleSystem.ui("available"), QuestSystem.ACTIVE:LocaleSystem.ui("active"), QuestSystem.COMPLETED:LocaleSystem.ui("completed")}[state]
		draw_rect(Rect2(170, row_y, 812, 142), Color("fff0bd") if state != QuestSystem.COMPLETED else Color("c9e2bd"))
		draw_string(UI_FONT, Vector2(190, row_y + 29), "%s • %s" % [mission.type, mission.title], HORIZONTAL_ALIGNMENT_LEFT, 520, 20, Color("493b2f"))
		draw_string(UI_FONT, Vector2(770, row_y + 29), state_name, HORIZONTAL_ALIGNMENT_RIGHT, 185, 15, Color("50704e"))
		draw_string(UI_FONT, Vector2(190, row_y + 62), mission.description, HORIZONTAL_ALIGNMENT_LEFT, 745, 15, Color("493b2f"))
		draw_string(UI_FONT, Vector2(190, row_y + 92), LocaleSystem.ui("objective", [QuestSystem.objective_text(self, mission_id)]), HORIZONTAL_ALIGNMENT_LEFT, 520, 16, Color("6b5038"))
		draw_string(UI_FONT, Vector2(190, row_y + 119), LocaleSystem.ui("reward", [mission.coins, mission.xp, inventory_item_name(mission.reward_item), mission.reward_count]), HORIZONTAL_ALIGNMENT_LEFT, 720, 14, Color("49704d"))
		row_y += 158.0
	draw_string(UI_FONT, Vector2(320, 548), LocaleSystem.ui("quest_close"), HORIZONTAL_ALIGNMENT_CENTER, 512, 16, Color("493b2f"))

func draw_player_status_bars() -> void:
	var hp_ratio := clampf(float(player_hp) / float(player_max_hp), 0.0, 1.0)
	var hp_bar := Rect2(24, 77, 160, 18)
	draw_rect(hp_bar, Color("3a2528"))
	draw_rect(hp_bar.grow(-2), Color("71333a"))
	draw_rect(Rect2(hp_bar.position + Vector2(2, 2), Vector2((hp_bar.size.x - 4) * hp_ratio, hp_bar.size.y - 4)), Color("e25555").lerp(Color("63cf72"), hp_ratio))
	draw_string(UI_FONT, Vector2(29, 91), "HP %d/%d" % [player_hp, player_max_hp], HORIZONTAL_ALIGNMENT_CENTER, 150, 13, Color.WHITE)
	var xp_needed := SkillSystem.xp_to_next_character_level(player_level)
	var xp_ratio := clampf(float(player_xp) / float(xp_needed), 0.0, 1.0)
	var xp_bar := Rect2(202, 77, 170, 18)
	draw_rect(xp_bar, Color("222e3c"))
	draw_rect(Rect2(xp_bar.position + Vector2(2, 2), Vector2((xp_bar.size.x - 4) * xp_ratio, xp_bar.size.y - 4)), Color("5b9de3"))
	draw_string(UI_FONT, Vector2(205, 91), "УР. %d • XP %d/%d" % [player_level, player_xp, xp_needed], HORIZONTAL_ALIGNMENT_CENTER, 164, 13, Color.WHITE)
	var mana_ratio := clampf(float(player_mana) / float(player_max_mana), 0.0, 1.0)
	var mana_bar := Rect2(380, 77, 150, 18)
	draw_rect(mana_bar, Color("252846"))
	draw_rect(Rect2(mana_bar.position + Vector2(2, 2), Vector2((mana_bar.size.x - 4) * mana_ratio, mana_bar.size.y - 4)), Color("596bd8"))
	draw_string(UI_FONT, Vector2(383, 91), LocaleSystem.ui("mana_label", [player_mana, player_max_mana]), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, Color.WHITE)
	var stamina_max := SkillSystem.max_stamina(self)
	var stamina_ratio := clampf(float(energy) / float(stamina_max), 0.0, 1.0)
	var stamina_bar := Rect2(538, 77, 150, 18)
	draw_rect(stamina_bar, Color("3b3222"))
	draw_rect(Rect2(stamina_bar.position + Vector2(2, 2), Vector2((stamina_bar.size.x - 4) * stamina_ratio, stamina_bar.size.y - 4)), Color("e0a640"))
	draw_string(UI_FONT, Vector2(541, 91), LocaleSystem.ui("stamina_label", [energy, stamina_max]), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, Color.WHITE)
	var effects: Array[String] = []
	if regeneration_timer > 0.0: effects.append("❤ реген %.0fс" % regeneration_timer)
	if strength_timer > 0.0: effects.append("⚔ сила %.0fс" % strength_timer)
	if speed_timer > 0.0: effects.append("➜ скорость %.0fс" % speed_timer)
	if not effects.is_empty():
		draw_rect(Rect2(450, 108, 680, 26), Color(0.08, 0.16, 0.14, 0.88))
		draw_string(UI_FONT, Vector2(465, 127), LocaleSystem.ui("effects") + " " + "   ".join(effects), HORIZONTAL_ALIGNMENT_LEFT, 650, 15, Color("ffeaa3"))

func draw_hotbar() -> void:
	var start_x := 176.0
	for index in 10:
		var slot := Rect2(start_x + index * 80.0, 558, 72, 72)
		var selected := index == selected_hotbar
		draw_rect(slot, Color("f2c96f") if selected else Color("263c36"))
		draw_rect(slot.grow(-4), Color("fff0bd") if selected else Color("49665c"))
		var kind: String = hotbar_slots[index]
		var item := InventorySystem.data(kind)
		draw_item_icon(kind, Rect2(slot.position + Vector2(17, 10), Vector2(38, 38)))
		draw_string(UI_FONT, slot.position + Vector2(5, 16), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("352e28") if selected else Color.WHITE)
		draw_string(UI_FONT, slot.position + Vector2(4, 61), item.short, HORIZONTAL_ALIGNMENT_CENTER, 64, 11, Color("352e28") if selected else Color.WHITE)

func draw_inventory() -> void:
	draw_rect(Rect2(38, 40, 1076, 552), Color("2d2925"))
	draw_rect(Rect2(54, 56, 1044, 520), Color("e8cf96"))
	draw_rect(Rect2(54, 56, 1044, 62), Color("594334"))
	draw_string(UI_FONT, Vector2(270, 98), LocaleSystem.ui("inventory"), HORIZONTAL_ALIGNMENT_CENTER, 440, 25, Color("fff0bd"))
	var first_visible := inventory_scroll_row * InventorySystem.COLUMNS
	var last_visible := mini(first_visible + InventorySystem.VISIBLE_SLOTS, inventory_slots.size())
	for index in range(first_visible, last_visible):
		var column := index % 6
		var row := index / 6 - inventory_scroll_row
		var slot := Rect2(72 + column * 112, 126 + row * 69, 102, 61)
		var selected := index == inventory_selected
		var moving := index == inventory_move_from
		draw_rect(slot, Color("f0c96f") if selected else Color("715744"))
		draw_rect(slot.grow(-4), Color("fff0bd") if not moving else Color("95d2a6"))
		var kind: String = inventory_slots[index]
		if not kind.is_empty() and inventory_item_count(kind) > 0:
			draw_item_icon(kind, Rect2(slot.position + Vector2(5, 6), Vector2(30, 30)))
			draw_string(UI_FONT, slot.position + Vector2(37, 23), inventory_item_name(kind), HORIZONTAL_ALIGNMENT_LEFT, 61, 10, Color("352e28"))
			draw_string(UI_FONT, slot.position + Vector2(73, 51), "×%d" % inventory_item_count(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("352e28"))
		else:
			draw_string(UI_FONT, slot.position + Vector2(45, 39), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("937d61"))
	var total_rows := ceili(float(inventory_slots.size()) / InventorySystem.COLUMNS)
	var scroll_track := Rect2(750, 126, 10, 337)
	draw_rect(scroll_track, Color("8c7559"))
	var thumb_height := maxf(34.0, scroll_track.size.y * InventorySystem.VISIBLE_ROWS / float(maxi(total_rows, InventorySystem.VISIBLE_ROWS)))
	var scroll_ratio := float(inventory_scroll_row) / float(maxi(InventorySystem.max_scroll_row(self), 1))
	draw_rect(Rect2(scroll_track.position + Vector2(1, (scroll_track.size.y - thumb_height) * scroll_ratio), Vector2(8, thumb_height)), Color("f0c96f"))
	draw_string(UI_FONT, Vector2(650, 106), LocaleSystem.ui("row", [inventory_scroll_row + 1, maxi(total_rows - InventorySystem.VISIBLE_ROWS + 1, 1)]), HORIZONTAL_ALIGNMENT_RIGHT, 100, 11, Color("d8c49a"))
	draw_equipment_panel()
	for index in 10:
		var assign_box := Rect2(72 + index * 68, 492, 62, 44)
		draw_rect(assign_box, Color("f0c96f") if index == selected_hotbar else Color("715744"))
		draw_string(UI_FONT, assign_box.position + Vector2(3, 14), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(UI_FONT, assign_box.position + Vector2(4, 35), InventorySystem.data(hotbar_slots[index]).short, HORIZONTAL_ALIGNMENT_CENTER, 54, 9, Color.WHITE)
	draw_rect(Rect2(770, 500, 142, 38), Color("6e9b63"))
	draw_rect(Rect2(928, 500, 142, 38), Color("c08a55"))
	draw_string(UI_FONT, Vector2(778, 525), LocaleSystem.ui("eat"), HORIZONTAL_ALIGNMENT_CENTER, 126, 13, Color.WHITE)
	draw_string(UI_FONT, Vector2(936, 525), LocaleSystem.ui("equip"), HORIZONTAL_ALIGNMENT_CENTER, 126, 13, Color.WHITE)
	draw_string(UI_FONT, Vector2(72, 563), LocaleSystem.ui("inventory_help"), HORIZONTAL_ALIGNMENT_LEFT, 990, 13, Color("493b2f"))

func draw_equipment_panel() -> void:
	draw_rect(Rect2(770, 136, 300, 350), Color("6f5542"))
	draw_string(UI_FONT, Vector2(790, 168), LocaleSystem.ui("equipment"), HORIZONTAL_ALIGNMENT_CENTER, 260, 22, Color("fff0bd"))
	draw_circle(Vector2(920, 265), 48, Color("e5b68d"))
	draw_rect(Rect2(882, 310, 76, 105), Color("638d72"))
	var slots := ["head", "body", "legs", "hands", "offhand", "ring"]
	var labels := {"head":LocaleSystem.ui("head"), "body":LocaleSystem.ui("body"), "legs":LocaleSystem.ui("legs"), "hands":LocaleSystem.ui("hands"), "offhand":LocaleSystem.ui("offhand"), "ring":LocaleSystem.ui("ring")}
	for index in slots.size():
		var slot_name: String = slots[index]
		var left := index % 2 == 0
		var box := Rect2(790 if left else 972, 195 + (index / 2) * 82, 82, 64)
		draw_rect(box, Color("fff0bd"))
		var kind: String = equipment[slot_name]
		draw_string(UI_FONT, box.position + Vector2(4, 16), labels[slot_name], HORIZONTAL_ALIGNMENT_CENTER, 74, 11, Color("493b2f"))
		if not kind.is_empty():
			draw_item_icon(kind, Rect2(box.position + Vector2(23, 23), Vector2(36, 36)))
			draw_string(UI_FONT, box.position + Vector2(4, 59), InventorySystem.data(kind).short, HORIZONTAL_ALIGNMENT_CENTER, 74, 10, Color("493b2f"))

func draw_skill_menu() -> void:
	draw_rect(Rect2(92, 48, 968, 552), Color("25232c"))
	draw_rect(Rect2(112, 68, 928, 512), Color("e4d4a9"))
	draw_rect(Rect2(112, 68, 928, 70), Color("493e61"))
	draw_string(UI_FONT, Vector2(180, 108), LocaleSystem.ui("character"), HORIZONTAL_ALIGNMENT_LEFT, 510, 28, Color("fff2c7"))
	draw_string(UI_FONT, Vector2(735, 106), LocaleSystem.ui("level_points", [player_level, skill_points]), HORIZONTAL_ALIGNMENT_RIGHT, 270, 18, Color("f5cf6a"))
	for index in SkillSystem.SKILLS.size():
		var skill: Dictionary = SkillSystem.SKILLS[index]
		var column := index % 2
		var row := index / 2
		var box := Rect2(142 + column * 444, 158 + row * 92, 414, 78)
		var selected := index == skill_menu_selected
		draw_rect(box, Color("efc75f") if selected else Color("6c5c48"))
		draw_rect(box.grow(-4), Color("fff0bd") if selected else Color("f0dfb5"))
		draw_string(UI_FONT, box.position + Vector2(14, 29), "%s  %s" % [skill.icon, LocaleSystem.skill(skill.id)], HORIZONTAL_ALIGNMENT_LEFT, 245, 19, Color("43382f"))
		draw_string(UI_FONT, box.position + Vector2(310, 29), LocaleSystem.ui("rank", [SkillSystem.skill(self, skill.id)]), HORIZONTAL_ALIGNMENT_RIGHT, 88, 15, Color("4c674c"))
		draw_string(UI_FONT, box.position + Vector2(14, 55), LocaleSystem.skill(skill.id, true), HORIZONTAL_ALIGNMENT_LEFT, 380, 12, Color("665746"))
		if skill.get("profession", false):
			var needed := SkillSystem.xp_to_next_skill_rank(SkillSystem.skill(self, skill.id))
			var ratio := clampf(float(skill_xp.get(skill.id, 0)) / float(needed), 0.0, 1.0)
			var bar := Rect2(box.position + Vector2(14, 64), Vector2(380, 6))
			draw_rect(bar, Color("766751"))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("6da86d"))
	draw_string(UI_FONT, Vector2(220, 556), LocaleSystem.ui("skill_help"), HORIZONTAL_ALIGNMENT_CENTER, 712, 15, Color("493b2f"))

func draw_crafting_window() -> void:
	draw_rect(Rect2(170, 70, 812, 510), Color("33271f"))
	draw_rect(Rect2(190, 90, 772, 470), Color("e8cf96"))
	draw_rect(Rect2(190, 90, 772, 64), Color("744b32"))
	draw_string(UI_FONT, Vector2(326, 132), LocaleSystem.ui("workbench"), HORIZONTAL_ALIGNMENT_CENTER, 500, 28, Color("fff1c4"))
	for index in CraftingSystem.RECIPES.size():
		var recipe: Dictionary = CraftingSystem.RECIPES[index]
		var row := Rect2(220, 174 + index * 68, 712, 58)
		draw_rect(row, Color("f2c96f") if index == crafting_selected else Color("fff0bd"))
		draw_string(UI_FONT, row.position + Vector2(18, 35), inventory_item_name(recipe.output), HORIZONTAL_ALIGNMENT_LEFT, 230, 17, Color("493b2f"))
		draw_string(UI_FONT, row.position + Vector2(250, 35), CraftingSystem.ingredients_text(self, recipe), HORIZONTAL_ALIGNMENT_LEFT, 440, 14, Color("49704d") if CraftingSystem.can_craft(self, recipe) else Color("a64d45"))
	draw_string(UI_FONT, Vector2(220, 535), LocaleSystem.ui("craft_help"), HORIZONTAL_ALIGNMENT_CENTER, 712, 16, Color("493b2f"))

func draw_shop() -> void:
	# Отдельная сцена-интерьер поверх игрового мира.
	draw_rect(Rect2(112, 70, 928, 520), Color("33271f"))
	draw_rect(Rect2(132, 90, 888, 480), Color("f0d49a"))
	for plank_y in range(108, 560, 32):
		draw_line(Vector2(132, plank_y), Vector2(1020, plank_y), Color("d8b878"), 2)
	draw_rect(Rect2(132, 90, 888, 72), Color("744b32"))
	draw_string(UI_FONT, Vector2(576, 138), LocaleSystem.ui("shop"), HORIZONTAL_ALIGNMENT_CENTER, 500, 30, Color("fff1c4"))
	# Прилавок и декоративные припасы из набора.
	draw_rect(Rect2(158, 190, 210, 302), Color("9b663d"))
	draw_texture_rect_region(SUPPLY_SHEET, Rect2(175, 208, 176, 136), Rect2(0, 0, 176, 136))
	draw_string(UI_FONT, Vector2(174, 470), LocaleSystem.ui("grandma_stock"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff1c4"))
	# Таблица товаров.
	var table := Rect2(405, 174, 570, 324)
	draw_rect(table, Color("fff4cf"))
	draw_rect(Rect2(table.position, Vector2(table.size.x, 42)), Color("53704b"))
	draw_string(UI_FONT, table.position + Vector2(62, 28), LocaleSystem.ui("product"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(UI_FONT, table.position + Vector2(350, 28), LocaleSystem.ui("buy"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(UI_FONT, table.position + Vector2(455, 28), LocaleSystem.ui("sell"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	for i in shop_products.size():
		var product: Dictionary = shop_products[i]
		var row := Rect2(table.position + Vector2(0, 42 + i * 47), Vector2(table.size.x, 47))
		draw_rect(row, Color("f2c96f") if i == shop_selected else Color("f8e8b5"))
		draw_rect(row, Color("76543c"), false, 2)
		if product.has("icon"):
			draw_texture_rect_region(SUPPLY_SHEET, Rect2(row.position + Vector2(12, 5), Vector2(34, 38)), product.icon)
		else:
			draw_item_icon(product.kind, Rect2(row.position + Vector2(13, 7), Vector2(32, 32)))
		draw_string(UI_FONT, row.position + Vector2(56, 30), inventory_item_name(product.kind), HORIZONTAL_ALIGNMENT_LEFT, 286, 14, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(370, 30), ("%d 🪙" % product.buy) if product.buy > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3d3428"))
		draw_string(UI_FONT, row.position + Vector2(478, 30), ("%d 🪙" % product.sell) if product.sell > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("3d3428"))
	draw_string(UI_FONT, Vector2(690, 535), LocaleSystem.ui("shop_help"), HORIZONTAL_ALIGNMENT_CENTER, 560, 16, Color("493b2f"))

func _input(event: InputEvent) -> void:
	if handle_gamepad_and_touch(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var is_action_key := set_action_key_state(event)
		var is_attack_key := set_attack_key_state(event)
		var is_movement_key := update_movement_key_state(event)
		if not title_screen and event.pressed and is_movement_key:
			apply_immediate_key_response(event)
		if is_action_key and not title_screen and not shop_open and not inventory_open and not quest_log_open and not skill_menu_open:
			if event.pressed and not event.echo:
				if not perform_context_action() and current_location == "overworld":
					use_active_item()
			get_viewport().set_input_as_handled()
		if is_attack_key and not title_screen and not shop_open and not inventory_open and not quest_log_open and not skill_menu_open:
			if event.pressed and not event.echo:
				attack_nearest_enemy()
			get_viewport().set_input_as_handled()

func handle_gamepad_and_touch(event: InputEvent) -> bool:
	if title_screen and ((event is InputEventJoypadButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		title_screen = false
		return true
	if event is InputEventJoypadButton and event.pressed:
		if skill_menu_open:
			handle_skill_menu_input(event)
			return true
		if quest_log_open:
			if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
				toggle_quest_log()
			return true
		if inventory_open:
			handle_inventory_input(event)
			return true
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT:
				select_hotbar(posmod(selected_hotbar - 1, 10))
				return true
			JOY_BUTTON_DPAD_RIGHT:
				select_hotbar(posmod(selected_hotbar + 1, 10))
				return true
			JOY_BUTTON_A:
				if not perform_context_action(): use_active_item()
				return true
			JOY_BUTTON_X:
				attack_nearest_enemy()
				return true
			JOY_BUTTON_Y:
				open_inventory()
				return true
			JOY_BUTTON_BACK:
				toggle_quest_log()
				return true
			JOY_BUTTON_START:
				open_skill_menu()
				return true
	if event is InputEventScreenDrag and inventory_open:
		inventory_touch_drag_y += event.relative.y
		if absf(inventory_touch_drag_y) >= 36.0:
			InventorySystem.scroll(self, -1 if inventory_touch_drag_y > 0.0 else 1)
			inventory_touch_drag_y = 0.0
		queue_redraw()
		return true
	if event is InputEventScreenTouch and event.pressed:
		if discovery_card_rect().has_point(event.position) and not discovery_current.is_empty():
			DiscoverySystem.dismiss(self)
			return true
		if Rect2(990, 0, 162, 62).has_point(event.position):
			toggle_quest_log()
			return true
		if skill_menu_open:
			if event.position.y >= 158.0 and event.position.y < 526.0 and event.position.x >= 142.0 and event.position.x < 1000.0:
				var column := clampi(int((event.position.x - 142.0) / 444.0), 0, 1)
				var row := clampi(int((event.position.y - 158.0) / 92.0), 0, 3)
				skill_menu_selected = row * 2 + column
				SkillSystem.allocate(self, SkillSystem.SKILLS[skill_menu_selected].id)
			return true
		if Rect2(830, 0, 145, 62).has_point(event.position):
			open_skill_menu()
			return true
		if inventory_open:
			if event.position.y >= 126.0 and event.position.y < 471.0 and event.position.x >= 72.0 and event.position.x < 744.0:
				var column := clampi(int((event.position.x - 72.0) / 112.0), 0, 5)
				var row := clampi(int((event.position.y - 126.0) / 69.0), 0, 4)
				inventory_selected = mini((row + inventory_scroll_row) * 6 + column, inventory_slots.size() - 1)
			elif event.position.y >= 490.0 and event.position.y < 545.0 and event.position.x < 760.0:
				assign_selected_to_hotbar(clampi(int((event.position.x - 72.0) / 68.0), 0, 9))
			elif Rect2(770, 490, 150, 58).has_point(event.position):
				consume_selected_item()
			elif Rect2(928, 490, 150, 58).has_point(event.position):
				equip_selected_item()
			return true
		if event.position.y >= 548.0:
			var index := clampi(int((event.position.x - 176.0) / 80.0), 0, 9)
			select_hotbar(index)
		else:
			if not perform_context_action(): use_active_item()
		return true
	return false
