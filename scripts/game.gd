extends Node2D

const TILE := 48
const FARM_ORIGIN := Vector2i(408, 216)
const FARM_SIZE := Vector2i(6, 5)
const TITLE_ART := preload("res://assets/title_art.png")
const PLANT_SHEET := preload("res://assets/game/environment/farm_plants.png")
const SUPPLY_SHEET := preload("res://assets/game/ui/farm_supplies.png")
const FARMER_SHEET := preload("res://assets/game/characters/farmer_walk.png")
const SLIME_SHEET := preload("res://assets/game/enemies/slime_idle.png")
const FOREST_TREE := preload("res://assets/game/environment/forest_tree.png")
const RED_MUSHROOMS := preload("res://assets/game/environment/red_mushrooms.png")
const CAVE_CRYSTAL := preload("res://assets/game/environment/cave_crystal.png")
const RESOURCE_CRYSTAL := preload("res://assets/game/resources/blue-crystal.png")
const RESOURCE_ROCK := preload("res://assets/game/resources/rock.png")
const WORLD_SIZE := Vector2(2400, 1200)
const STAGE_DURATION := 5.0
const GROWTH_DURATION := 20.0
const MAX_BASE_HP := 100
const XP_PER_LEVEL := 50
const PLAYER_RADIUS := 18.0
const BRIDGE_RECT := Rect2(1450, 805, 110, 395)
const TREE_POSITIONS := [Vector2(1210,190), Vector2(1430,250), Vector2(1740,170), Vector2(1990,290), Vector2(2240,180), Vector2(1320,680), Vector2(1880,720), Vector2(2210,650)]
const CAVE_DECORATIONS := [Vector2(480,250), Vector2(720,600), Vector2(1040,300), Vector2(1380,720), Vector2(1720,280), Vector2(2050,620)]

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
var message := "Добро пожаловать на Бабушкину ферму!"
var title_screen := true
var shop_open := false
var inventory_open := false
var inventory_selected := 0
var inventory_move_from := -1
var inventory_slots := ["seeds", "carrot", "pickaxe", "fishing_rod", "slime", "wood", "stone", "crystal", "fish", "sword", "bow", "crystal_sword", "apple", "berries", "nut", "mushroom"]
var dropped_items: Array = []
var shop_selected := 0
var shop_products := [
	{"name": "Семена моркови ×4", "kind": "seeds", "buy": 5, "sell": 0, "icon": Rect2(0, 55, 36, 45)},
	{"name": "Морковь", "kind": "carrot", "buy": 10, "sell": 8, "icon": Rect2(34, 112, 30, 28)}
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
var benchmark_autoplay := false
var benchmark_elapsed := 0.0

# RPG-состояние вертикального среза.
var player_hp := MAX_BASE_HP
var player_max_hp := MAX_BASE_HP
var player_xp := 0
var player_level := 1
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
var food_nodes := [
	{"position": Vector2(1320, 720), "kind": "mushroom", "active": true},
	{"position": Vector2(1740, 360), "kind": "berries", "active": true},
	{"position": Vector2(2010, 640), "kind": "nut", "active": true},
	{"position": Vector2(1110, 330), "kind": "apple", "active": true}
]
var fishing_state := "idle"
var fishing_timer := 0.0
var pond_position := Vector2(650, 700)
var resource_nodes := [
	{"position": Vector2(1190, 590), "location": "overworld", "kind": "stone", "hits": 2},
	{"position": Vector2(1830, 610), "location": "overworld", "kind": "crystal", "hits": 3},
	{"position": Vector2(520, 300), "location": "cave", "kind": "crystal", "hits": 3},
	{"position": Vector2(980, 570), "location": "cave", "kind": "stone", "hits": 2},
	{"position": Vector2(1500, 330), "location": "cave", "kind": "crystal", "hits": 3}
]
var npc_position := Vector2(325, 360)
var workbench_position := Vector2(760, 176)
var quest_active := false
var quest_complete := false
var tutorial_visible := true
var tutorial_step := 0
var tutorial_steps := [
	{"event": "move", "text": "Пройди немного стрелками или WASD"},
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
	{"event": "eat", "text": "Выбери еду в рюкзаке и нажми E или Enter"},
	{"event": "mine", "text": "Выбери кирку [5] и добудь камень или кристалл"},
	{"event": "fish", "text": "Выбери удочку [6] и поймай рыбу у пруда"},
	{"event": "craft", "text": "Вернись к верстаку и создай меч [E]"},
	{"event": "equip", "text": "Надень или сними меч клавишей R"},
	{"event": "collision", "text": "Проверь препятствие и перейди реку только по мосту"},
	{"event": "travel", "text": "Найди светящийся вход в пещеру и нажми E"}
]

func _ready() -> void:
	for y in FARM_SIZE.y:
		for x in FARM_SIZE.x:
			plots[Vector2i(x, y)] = {"tilled": false, "planted": false, "watered": false, "growth": 0.0, "stage": 0, "stage_flash": 0.0}
	benchmark_autoplay = "--autoplay" in OS.get_cmdline_user_args()
	if benchmark_autoplay:
		title_screen = false
		move_right_held = true
	sync_background_location()
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
	if benchmark_autoplay:
		update_benchmark_route(delta)
	if shop_open or inventory_open:
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
	var current_speed := speed * (1.3 if speed_timer > 0.0 else 1.0)
	move_player_with_collisions(direction * current_speed * delta)
	walk_animation_time += delta
	notify_tutorial("move")
	clamp_player_position()

func move_player_with_collisions(motion: Vector2) -> void:
	var step_count := maxi(1, ceili(motion.length() / 8.0))
	var step := motion / float(step_count)
	var was_blocked := false
	for _index in step_count:
		var horizontal := player + Vector2(step.x, 0.0)
		if is_position_walkable(horizontal):
			player = horizontal
		elif not is_zero_approx(step.x):
			was_blocked = true
		var vertical := player + Vector2(0.0, step.y)
		if is_position_walkable(vertical):
			player = vertical
		elif not is_zero_approx(step.y):
			was_blocked = true
	if was_blocked:
		notify_tutorial("collision")

func is_position_walkable(position: Vector2) -> bool:
	if position.x < 40.0 or position.x > WORLD_SIZE.x - 40.0 or position.y < 120.0 or position.y > WORLD_SIZE.y - 80.0:
		return false
	if current_location == "cave":
		for decoration in CAVE_DECORATIONS:
			if position.distance_to(decoration) < PLAYER_RADIUS + 38.0:
				return false
	else:
		if position.y + PLAYER_RADIUS > 860.0 and not BRIDGE_RECT.grow(-18.0).has_point(position):
			return false
		var pond_delta := position - pond_position
		if pow(pond_delta.x / (189.0 + PLAYER_RADIUS), 2.0) + pow(pond_delta.y / (105.0 + PLAYER_RADIUS), 2.0) < 1.0:
			return false
		for tree in TREE_POSITIONS:
			if position.distance_to(tree + Vector2(0, 35)) < PLAYER_RADIUS + 42.0:
				return false
		var solid_rects := [
			Rect2(54, 130, 190, 150), Rect2(895, 175, 158, 117),
			Rect2(790, 392, 60, 54), Rect2(workbench_position - Vector2(32, 20), Vector2(64, 44))
		]
		for rect in solid_rects:
			if circle_intersects_rect(position, PLAYER_RADIUS, rect):
				return false
		if slime_alive and position.distance_to(slime_position) < PLAYER_RADIUS + 28.0:
			return false
	for node in resource_nodes:
		if node.hits > 0 and node.location == current_location and position.distance_to(node.position) < PLAYER_RADIUS + 30.0:
			return false
	return true

func circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) < radius * radius

func update_game_clock(delta: float) -> void:
	# Одна реальная секунда равна одной игровой минуте.
	game_minutes += delta
	if game_minutes >= 24.0 * 60.0:
		game_minutes -= 24.0 * 60.0
		day += 1
		message = "Наступил день %d" % day

func update_crops(delta: float) -> void:
	for cell in plots:
		var plot: Dictionary = plots[cell]
		if plot.stage_flash > 0.0:
			plot.stage_flash = maxf(plot.stage_flash - delta, 0.0)
		if plot.planted and plot.watered and plot.growth < GROWTH_DURATION:
			var previous_stage: int = plot.stage
			plot.growth = minf(plot.growth + delta, GROWTH_DURATION)
			plot.stage = mini(int(plot.growth / STAGE_DURATION), 4)
			if plot.stage > previous_stage:
				plot.stage_flash = 0.7
				# На середине роста земля подсыхает: нужен второй полив.
				if plot.stage == 2:
					plot.watered = false
					message = "Земля подсохла — морковь просит второй полив"
				if plot.stage >= 4:
					message = "Морковь созрела — собери её руками [4]"
		plots[cell] = plot

func get_movement_direction() -> Vector2:
	var direction := Vector2(
		float(move_right_held) - float(move_left_held),
		float(move_down_held) - float(move_up_held)
	)
	return direction.normalized()

func update_movement_key_state(event: InputEventKey) -> bool:
	var handled := true
	var held := event.pressed
	if event.keycode == KEY_LEFT or event.physical_keycode == KEY_A:
		move_left_held = held
	elif event.keycode == KEY_RIGHT or event.physical_keycode == KEY_D:
		move_right_held = held
	elif event.keycode == KEY_UP or event.physical_keycode == KEY_W:
		move_up_held = held
	elif event.keycode == KEY_DOWN or event.physical_keycode == KEY_S:
		move_down_held = held
	else:
		handled = false
	return handled

func clear_movement_keys() -> void:
	move_left_held = false
	move_right_held = false
	move_up_held = false
	move_down_held = false
	action_held = false
	attack_held = false

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
		attack_slime()

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
	if title_screen:
		if event.is_pressed():
			title_screen = false
			message = "Вспаши землю клавишей E"
			queue_redraw()
		return
	if shop_open:
		handle_shop_input(event)
		return
	if inventory_open:
		handle_inventory_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		title_screen = true
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		use_selected_tool()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: selected_tool = Tool.HOE
			KEY_2: selected_tool = Tool.SEEDS
			KEY_3: selected_tool = Tool.WATER
			KEY_4: selected_tool = Tool.HAND
			KEY_5: selected_tool = Tool.PICKAXE
			KEY_6: selected_tool = Tool.ROD
			KEY_B: open_shop()
			KEY_N: sleep_until_morning()
			KEY_F: attack_slime()
			KEY_R: toggle_sword()
			KEY_T: tutorial_visible = not tutorial_visible
			KEY_Y: reset_tutorial()
			KEY_F9: grant_tester_kit()
			KEY_I: open_inventory()
		queue_redraw()

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
		message = "Подойди к грядке и повернись к ней"
		return
	var plot: Dictionary = plots[cell]
	if selected_tool != Tool.HAND and energy <= 0:
		message = "Сил нет. Нажми N у кровати"
		return
	match selected_tool:
		Tool.HOE:
			if not plot.tilled:
				plot.tilled = true
				energy -= 1
				message = "Земля готова. Выбери семена [2]"
			else: message = "Эта грядка уже вспахана"
		Tool.SEEDS:
			if plot.tilled and not plot.planted and seeds > 0:
				plot.planted = true
				plot.growth = 0.0
				plot.stage = 0
				plot.stage_flash = 0.0
				seeds -= 1
				energy -= 1
				award_xp(1, "Посадка моркови")
				notify_tutorial("plant")
			elif seeds <= 0: message = "Семена кончились. Купи у лавки [B]"
			else: message = "Сначала вспаши пустую землю"
		Tool.WATER:
			if plot.planted and not plot.watered:
				var is_second_watering: bool = plot.growth >= STAGE_DURATION * 2.0
				plot.watered = true
				energy -= 1
				message = "Полито! Поспи [N], чтобы растение выросло"
				notify_tutorial("rewater" if is_second_watering else "water")
			else: message = "Здесь нечего поливать"
		Tool.HAND:
			if plot.planted and plot.growth >= GROWTH_DURATION:
				plot.planted = false
				plot.tilled = true
				plot.watered = false
				plot.growth = 0.0
				plot.stage = 0
				plot.stage_flash = 0.0
				carrots += 1
				message = "Морковь собрана! Продай у ящика [E]"
				notify_tutorial("harvest")
			else: message = "Урожай ещё не созрел"
	plots[cell] = plot

func sleep_until_morning() -> void:
	if player.distance_to(Vector2(126, 190)) > 105.0:
		message = "Чтобы спать, подойди к дому"
		return
	day += 1
	game_minutes = 6.0 * 60.0
	energy = 12
	message = "День %d, 06:00. Доброе утро!" % day

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
			"shop": Vector2(972, 278),
			"crate": Vector2(820, 420),
			"workbench": workbench_position,
			"cave_entrance": cave_entrance_position
		}
		if loot_available:
			interactions["loot"] = slime_position
	else:
		interactions = {"cave_exit": cave_exit_position}
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
		if not food.active or current_location != "overworld":
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
	if interaction.begins_with("resource:"):
		return mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"):
		return collect_food(int(interaction.get_slice(":", 1)))
	match interaction:
		"npc":
			talk_to_grandmother()
			return true
		"shop":
			open_shop()
			return true
		"crate":
			sell_carrots()
			return true
		"workbench":
			craft_sword()
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
	return false

func mine_nearby_resource() -> bool:
	var interaction := nearest_interaction()
	if not interaction.begins_with("resource:"):
		message = "Рядом нет залежей для добычи"
		return false
	return mine_resource(int(interaction.get_slice(":", 1)))

func mine_resource(index: int) -> bool:
	if not has_pickaxe or selected_tool != Tool.PICKAXE:
		message = "Для добычи выбери кирку [5]"
		return false
	if index < 0 or index >= resource_nodes.size():
		return false
	var node: Dictionary = resource_nodes[index]
	if node.hits <= 0 or node.location != current_location or player.distance_to(node.position) > 92.0:
		return false
	node.hits -= 1
	if node.kind == "crystal":
		crystals += 1
		message = "Добыт синий кристалл"
	else:
		stone += 1
		message = "Добыт камень"
	if node.hits <= 0:
		message += ". Жила исчерпана"
	resource_nodes[index] = node
	notify_tutorial("mine")
	return true

func is_near_fishing_water() -> bool:
	if current_location != "overworld":
		return false
	# Радиус взаимодействия чуть больше коллизии берега, чтобы удочка доставала до воды.
	var near_pond := player.distance_to(pond_position) < 235.0
	var near_river := player.y > 800.0
	return near_pond or near_river

func use_fishing_rod() -> bool:
	if not has_fishing_rod:
		message = "У тебя нет удочки"
		return false
	if not is_near_fishing_water():
		message = "Подойди к пруду или реке"
		return false
	if fishing_state == "idle":
		fishing_state = "casting"
		fishing_timer = 2.5
		message = "Поплавок в воде... жди поклёвки"
		return true
	if fishing_state == "ready":
		fish += 1
		fishing_state = "idle"
		message = "Поймана речная рыба!"
		notify_tutorial("fish")
		return true
	message = "Рыба ещё не клюнула"
	return false

func update_fishing(delta: float) -> void:
	if fishing_state != "casting":
		return
	fishing_timer -= delta
	if fishing_timer <= 0.0:
		fishing_state = "ready"
		message = "КЛЮЁТ! Нажми E ещё раз"

func enter_cave() -> void:
	current_location = "cave"
	sync_background_location()
	player = cave_exit_position + Vector2(90, 0)
	update_camera()
	message = "Кристальная пещера"
	notify_tutorial("travel")

func exit_cave() -> void:
	current_location = "overworld"
	sync_background_location()
	player = cave_entrance_position - Vector2(100, 0)
	update_camera()
	message = "Ты вернулся в зачарованный лес"

func open_inventory() -> void:
	inventory_open = true
	inventory_move_from = -1
	clear_movement_keys()
	notify_tutorial("inventory")
	message = "Инвентарь открыт"

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
	return 0

func inventory_item_name(kind: String) -> String:
	match kind:
		"seeds": return "Семена моркови"
		"carrot": return "Морковь"
		"slime": return "Слизь"
		"wood": return "Древесина"
		"sword": return "Лесной меч"
		"pickaxe": return "Кирка"
		"fishing_rod": return "Удочка"
		"stone": return "Камень"
		"crystal": return "Синий кристалл"
		"fish": return "Речная рыба"
		"bow": return "Охотничий лук"
		"crystal_sword": return "Кристальный меч"
		"apple": return "Лесное яблоко"
		"berries": return "Лесные ягоды"
		"nut": return "Крепкий орех"
		"mushroom": return "Красный гриб"
	return "Пусто"

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
		_:
			return false
	return true

func handle_inventory_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_I:
			inventory_open = false
			inventory_move_from = -1
		KEY_LEFT: inventory_selected = posmod(inventory_selected - 1, 16)
		KEY_RIGHT: inventory_selected = posmod(inventory_selected + 1, 16)
		KEY_UP: inventory_selected = posmod(inventory_selected - 4, 16)
		KEY_DOWN: inventory_selected = posmod(inventory_selected + 4, 16)
		KEY_M: move_inventory_slot()
		KEY_X: drop_selected_item()
		KEY_ENTER, KEY_E: consume_selected_item()
		KEY_DELETE, KEY_BACKSPACE: delete_selected_item()
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
	message = "Предмет перемещён"

func drop_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	if kind.is_empty() or not change_inventory_count(kind, -1):
		message = "В этом слоте нечего выбрасывать"
		return false
	dropped_items.append({"kind": kind, "count": 1, "position": player + facing * 50.0})
	message = "Предмет выброшен рядом"
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
	message = "Поднято: %s" % inventory_item_name(item.kind)
	return true

func collect_food(index: int) -> bool:
	if index < 0 or index >= food_nodes.size():
		return false
	var food: Dictionary = food_nodes[index]
	if not food.active or current_location != "overworld" or player.distance_to(food.position) > 92.0:
		return false
	food.active = false
	food_nodes[index] = food
	change_inventory_count(food.kind, 1)
	message = "Собрано: %s. Съешь в рюкзаке [I]" % inventory_item_name(food.kind)
	return true

func consume_selected_item() -> bool:
	var kind: String = inventory_slots[inventory_selected]
	if kind not in ["carrot", "apple", "berries", "nut", "mushroom"]:
		message = "Этот предмет нельзя съесть"
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
	notify_tutorial("eat")
	return true

func heal_player(amount: int) -> int:
	var previous_hp := player_hp
	player_hp = mini(player_hp + amount, player_max_hp)
	return player_hp - previous_hp

func award_xp(amount: int, reason: String = "") -> void:
	player_xp += amount
	var leveled_up := false
	while player_xp >= XP_PER_LEVEL:
		player_xp -= XP_PER_LEVEL
		player_level += 1
		player_max_hp += 10
		player_hp = player_max_hp
		leveled_up = true
	if leveled_up:
		message = "Новый уровень %d! Максимум здоровья +10" % player_level
	elif not reason.is_empty():
		message = "%s: +%d опыта" % [reason, amount]

func update_status_effects(delta: float) -> void:
	strength_timer = maxf(strength_timer - delta, 0.0)
	speed_timer = maxf(speed_timer - delta, 0.0)
	if regeneration_timer <= 0.0:
		return
	regeneration_timer = maxf(regeneration_timer - delta, 0.0)
	regeneration_tick_timer += delta
	while regeneration_tick_timer >= 1.0:
		regeneration_tick_timer -= 1.0
		heal_player(5)

func talk_to_grandmother() -> void:
	notify_tutorial("talk")
	if not quest_active and not quest_complete:
		quest_active = true
		message = "Задание: принеси бабушке 10 морковок"
	elif quest_active and carrots >= 10:
		carrots -= 10
		coins += 50
		award_xp(25)
		quest_active = false
		quest_complete = true
		has_bow = true
		message = "Квест выполнен! +50 монет, +25 опыта и охотничий лук"
		notify_tutorial("quest_complete")
	elif quest_active:
		message = "Бабушка ждёт морковь: %d/10" % carrots
	else:
		message = "Спасибо за помощь, внучек!"

func attack_slime() -> bool:
	var attack_range := 280.0 if equipped_weapon == "bow" else 105.0
	if not slime_alive or player.distance_to(slime_position) > attack_range:
		message = "Рядом нет противника"
		return false
	var damage := 1 + (1 if strength_timer > 0.0 else 0)
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
		message = "Слизень побеждён! +10 опыта. Подбери добычу [E]"
	return true

func update_combat(delta: float) -> void:
	if not slime_alive or player.distance_to(slime_position) > 72.0:
		slime_attack_timer = 0.0
		return
	slime_attack_timer += delta
	if slime_attack_timer >= 1.5:
		slime_attack_timer = 0.0
		player_hp -= 20
		message = "Слизень атакует! -20 здоровья"
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
	if tutorial_step >= tutorial_steps.size():
		return
	if tutorial_steps[tutorial_step].event == event_name:
		tutorial_step += 1

func reset_tutorial() -> void:
	tutorial_step = 0
	tutorial_visible = true
	message = "Обучение начато заново"

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
	player_hp = player_max_hp
	slime_alive = true
	slime_hp = 3
	loot_available = false
	for index in food_nodes.size():
		food_nodes[index].active = true
	message = "QA-набор выдан: ресурсы, морковь и монеты"

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
	var product: Dictionary = shop_products[shop_selected]
	if coins < product.buy:
		message = "Не хватает монет"
		return false
	coins -= product.buy
	if product.kind == "seeds":
		seeds += 4
	elif product.kind == "carrot":
		carrots += 1
	message = "Куплено: %s" % product.name
	notify_tutorial("trade")
	return true

func sell_selected_product() -> bool:
	var product: Dictionary = shop_products[shop_selected]
	if product.sell <= 0:
		message = "Этот товар лавка не покупает"
		return false
	if product.kind == "carrot" and carrots > 0:
		carrots -= 1
		coins += product.sell
		message = "Продано: морковь +%d монет" % product.sell
		notify_tutorial("trade")
		return true
	message = "У тебя нет этого товара"
	return false

func sell_carrots() -> void:
	if carrots > 0:
		var earned := carrots * 8
		coins += earned
		carrots = 0
		message = "Продано! +%d монет" % earned
	else: message = "В рюкзаке нет моркови"

func _draw() -> void:
	if title_screen:
		draw_texture_rect(TITLE_ART, Rect2(0, 0, 1152, 648), false)
		draw_rect(Rect2(0, 0, 1152, 648), Color(0.04, 0.08, 0.08, 0.25))
		draw_string(ThemeDB.fallback_font, Vector2(576, 120), "БАБУШКИНА ФЕРМА", HORIZONTAL_ALIGNMENT_CENTER, 760, 46, Color("fff4cf"))
		draw_string(ThemeDB.fallback_font, Vector2(576, 565), "Нажми любую клавишу", HORIZONTAL_ALIGNMENT_CENTER, 420, 24, Color.WHITE)
		return
	draw_set_transform(-camera_offset)
	if current_location == "overworld":
		draw_farm()
		draw_rpg_world()
	draw_resource_nodes()
	draw_player()
	draw_interaction_highlight()
	draw_set_transform(Vector2.ZERO)
	draw_ui()

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
	draw_string(ThemeDB.fallback_font, Vector2(66, 308), "ДОМ • сон [N]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# shop
	draw_rect(Rect2(910, 194, 128, 98), Color("f3d88e"))
	draw_rect(Rect2(895, 175, 158, 30), Color("d66b45"))
	draw_string(ThemeDB.fallback_font, Vector2(913, 238), "СЕМЕНА", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("55382b"))
	draw_string(ThemeDB.fallback_font, Vector2(905, 320), "Лавка [B]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))
	# Несколько стадий плодовых деревьев из бесплатного sprite sheet.
	draw_texture_rect_region(PLANT_SHEET, Rect2(270, 126, 290, 90), Rect2(94, 0, 290, 90))
	# selling crate
	draw_rect(Rect2(790, 392, 60, 54), Color("9c633b"))
	for i in 3: draw_line(Vector2(794, 402 + i * 15), Vector2(846, 402 + i * 15), Color("d09755"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(753, 473), "Продажа [E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("213a2c"))

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
	var frame := int(walk_animation_time * 8.0) % 6 if get_movement_direction() != Vector2.ZERO else 0
	var direction_row := 0
	if absf(facing.x) > absf(facing.y): direction_row = 2 if facing.x < 0 else 3
	elif facing.y < 0: direction_row = 1
	draw_texture_rect_region(FARMER_SHEET, Rect2(render_position - Vector2(32, 48), Vector2(64, 64)), Rect2(frame * 64, direction_row * 64, 64, 64))
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
	draw_string(ThemeDB.fallback_font, npc_position + Vector2(-40, 55), "Бабушка", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("293c2f"))
	draw_rect(Rect2(workbench_position - Vector2(32, 20), Vector2(64, 44)), Color("865334"))
	draw_line(workbench_position - Vector2(25, 8), workbench_position + Vector2(25, -8), Color("d09a59"), 5)
	draw_string(ThemeDB.fallback_font, workbench_position + Vector2(-45, 45), "Верстак", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("293c2f"))
	if slime_alive:
		var slime_frame := int(Time.get_ticks_msec() / 140.0) % 6
		draw_texture_rect_region(SLIME_SHEET, Rect2(slime_position - Vector2(32, 40), Vector2(64, 64)), Rect2(slime_frame * 64, 0, 64, 64))
		draw_rect(Rect2(slime_position + Vector2(-28, -50), Vector2(56, 7)), Color("402d32"))
		draw_rect(Rect2(slime_position + Vector2(-27, -49), Vector2(54.0 * slime_hp / 3.0, 5)), Color("dc554b"))
	elif loot_available:
		draw_circle(slime_position, 13, Color("78d6a5"))
		draw_circle(slime_position - Vector2(4, 4), 4, Color("baf1c8"))
	for item in dropped_items:
		draw_circle(item.position, 12, inventory_item_color(item.kind))
		draw_circle(item.position - Vector2(3, 3), 3, Color("fff3c4"))
	draw_food_nodes()
	# Вход в отдельную пещерную локацию.
	draw_circle(cave_entrance_position, 52, Color("283a43"))
	draw_circle(cave_entrance_position, 38 + sin(Time.get_ticks_msec() / 170.0) * 4, Color("66d5cf"), false, 6)
	draw_string(ThemeDB.fallback_font, cave_entrance_position + Vector2(-58, 78), "Кристальная пещера", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7fff4"))

func draw_food_nodes() -> void:
	for food in food_nodes:
		if not food.active:
			continue
		var position: Vector2 = food.position
		match food.kind:
			"mushroom":
				draw_texture_rect(RED_MUSHROOMS, Rect2(position - Vector2(28, 28), Vector2(56, 56)), false)
			"berries":
				draw_texture_rect_region(PLANT_SHEET, Rect2(position - Vector2(44, 70), Vector2(88, 88)), Rect2(288, 0, 96, 96))
			"apple":
				draw_texture_rect_region(PLANT_SHEET, Rect2(position - Vector2(44, 70), Vector2(88, 88)), Rect2(288, 144, 96, 96))
			"nut":
				draw_texture_rect_region(PLANT_SHEET, Rect2(position - Vector2(44, 70), Vector2(88, 88)), Rect2(288, 288, 96, 96))
		draw_circle(position, 30, Color(1.0, 0.88, 0.32, 0.24))

func draw_resource_nodes() -> void:
	for node in resource_nodes:
		if node.hits <= 0 or node.location != current_location:
			continue
		var texture: Texture2D = RESOURCE_CRYSTAL if node.kind == "crystal" else RESOURCE_ROCK
		draw_texture_rect(texture, Rect2(node.position - Vector2(28, 28), Vector2(56, 56)), false)

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
	draw_string(ThemeDB.fallback_font, Vector2(90, 100), "КРИСТАЛЬНАЯ ПЕЩЕРА", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("9ce9dd"))

func inventory_item_color(kind: String) -> Color:
	match kind:
		"seeds": return Color("d8b86b")
		"carrot": return Color("ee7a32")
		"slime": return Color("72d4a2")
		"wood": return Color("a46c42")
		"sword": return Color("d9e4e6")
		"pickaxe": return Color("87989c")
		"fishing_rod": return Color("b77a45")
		"stone": return Color("8f8a7c")
		"crystal": return Color("54d7e8")
		"fish": return Color("5aa4d6")
		"bow": return Color("c58a4d")
		"crystal_sword": return Color("6ce8ef")
		"apple": return Color("df4b45")
		"berries": return Color("7656c7")
		"nut": return Color("a8733e")
		"mushroom": return Color("d95c50")
	return Color.WHITE

func interaction_position(interaction: String) -> Vector2:
	if interaction.begins_with("drop:"):
		var index := int(interaction.get_slice(":", 1))
		if index >= 0 and index < dropped_items.size():
			return dropped_items[index].position
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
		"shop": return Vector2(972, 278)
		"crate": return Vector2(820, 420)
		"workbench": return workbench_position
		"loot": return slime_position
		"cave_entrance": return cave_entrance_position
		"cave_exit": return cave_exit_position
	return Vector2.ZERO

func draw_interaction_highlight() -> void:
	var interaction := nearest_interaction()
	if interaction.is_empty():
		return
	var center := interaction_position(interaction)
	var pulse := 34.0 + sin(Time.get_ticks_msec() / 130.0) * 4.0
	draw_circle(center, pulse, Color("ffe36e"), false, 4.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-45, -48), "E • действие", HORIZONTAL_ALIGNMENT_CENTER, 90, 16, Color("fff4bd"))

func draw_ui() -> void:
	draw_rect(Rect2(0, 0, 1152, 106), Color("182f2b"))
	var hours := floori(game_minutes / 60.0)
	var minutes := int(game_minutes) % 60
	draw_string(ThemeDB.fallback_font, Vector2(24, 34), "ДЕНЬ %d   %02d:%02d" % [day, hours, minutes], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe39d"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 68), "⚡ %d   🪙 %d   Семена: %d   Морковь: %d" % [energy, coins, seeds, carrots], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_player_status_bars()
	draw_string(ThemeDB.fallback_font, Vector2(390, 94), "Слизь %d  Камень %d  Кристалл %d  Рыба %d  Оружие: %s" % [slime_gel, stone, crystals, fish, equipped_weapon], HORIZONTAL_ALIGNMENT_LEFT, 740, 13, Color("bde8d2"))
	var tools := ["1 Мотыга", "2 Семена", "3 Лейка", "4 Руки", "5 Кирка", "6 Удочка"]
	for i in 6:
		var box := Rect2(480 + i * 111, 18, 103, 55)
		draw_rect(box, Color("d8bd77") if i == selected_tool else Color("38564d"))
		draw_string(ThemeDB.fallback_font, box.position + Vector2(6, 34), tools[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("1f312b") if i == selected_tool else Color.WHITE)
	if fishing_state == "casting":
		draw_string(ThemeDB.fallback_font, Vector2(576, 205), "Поплавок... %.1f" % maxf(fishing_timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 260, 20, Color("d7f6ff"))
	elif fishing_state == "ready":
		draw_circle(Vector2(576, 195), 22 + sin(Time.get_ticks_msec() / 100.0) * 3, Color("ffdc5c"))
		draw_string(ThemeDB.fallback_font, Vector2(576, 202), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 24, Color("5b4526"))
	draw_rect(Rect2(190, 592, 772, 42), Color("182f2b"))
	draw_string(ThemeDB.fallback_font, Vector2(576, 620), message, HORIZONTAL_ALIGNMENT_CENTER, 730, 18, Color("fff4cf"))
	if quest_active:
		draw_rect(Rect2(850, 108, 278, 52), Color("293b34"))
		draw_string(ThemeDB.fallback_font, Vector2(865, 140), "Квест: морковь %d/10" % mini(carrots, 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffe5a2"))
	if tutorial_visible and tutorial_step < tutorial_steps.size():
		draw_rect(Rect2(18, 108, 420, 68), Color("263c36"))
		draw_string(ThemeDB.fallback_font, Vector2(34, 132), "ОБУЧЕНИЕ %d/%d  [T скрыть • Y заново • F9 QA]" % [tutorial_step + 1, tutorial_steps.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ed6b3"))
		draw_string(ThemeDB.fallback_font, Vector2(34, 160), tutorial_steps[tutorial_step].text, HORIZONTAL_ALIGNMENT_LEFT, 385, 17, Color.WHITE)
	if shop_open:
		draw_shop()
	if inventory_open:
		draw_inventory()

func draw_player_status_bars() -> void:
	var hp_ratio := clampf(float(player_hp) / float(player_max_hp), 0.0, 1.0)
	var hp_bar := Rect2(24, 77, 160, 18)
	draw_rect(hp_bar, Color("3a2528"))
	draw_rect(hp_bar.grow(-2), Color("71333a"))
	draw_rect(Rect2(hp_bar.position + Vector2(2, 2), Vector2((hp_bar.size.x - 4) * hp_ratio, hp_bar.size.y - 4)), Color("e25555").lerp(Color("63cf72"), hp_ratio))
	draw_string(ThemeDB.fallback_font, Vector2(29, 91), "HP %d/%d" % [player_hp, player_max_hp], HORIZONTAL_ALIGNMENT_CENTER, 150, 13, Color.WHITE)
	var xp_ratio := clampf(float(player_xp) / float(XP_PER_LEVEL), 0.0, 1.0)
	var xp_bar := Rect2(202, 77, 170, 18)
	draw_rect(xp_bar, Color("222e3c"))
	draw_rect(Rect2(xp_bar.position + Vector2(2, 2), Vector2((xp_bar.size.x - 4) * xp_ratio, xp_bar.size.y - 4)), Color("5b9de3"))
	draw_string(ThemeDB.fallback_font, Vector2(205, 91), "УР. %d • XP %d/%d" % [player_level, player_xp, XP_PER_LEVEL], HORIZONTAL_ALIGNMENT_CENTER, 164, 13, Color.WHITE)
	var effects: Array[String] = []
	if regeneration_timer > 0.0: effects.append("❤ реген %.0fс" % regeneration_timer)
	if strength_timer > 0.0: effects.append("⚔ сила %.0fс" % strength_timer)
	if speed_timer > 0.0: effects.append("➜ скорость %.0fс" % speed_timer)
	if not effects.is_empty():
		draw_rect(Rect2(450, 108, 680, 26), Color(0.08, 0.16, 0.14, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2(465, 127), "ЭФФЕКТЫ: " + "   ".join(effects), HORIZONTAL_ALIGNMENT_LEFT, 650, 15, Color("ffeaa3"))

func draw_inventory() -> void:
	draw_rect(Rect2(180, 64, 792, 520), Color("2d2925"))
	draw_rect(Rect2(198, 82, 756, 484), Color("e8cf96"))
	draw_rect(Rect2(198, 82, 756, 70), Color("594334"))
	draw_string(ThemeDB.fallback_font, Vector2(576, 128), "РЮКЗАК", HORIZONTAL_ALIGNMENT_CENTER, 320, 30, Color("fff0bd"))
	for index in inventory_slots.size():
		var column := index % 4
		var row := index / 4
		var slot := Rect2(242 + column * 136, 176 + row * 78, 118, 66)
		var selected := index == inventory_selected
		var moving := index == inventory_move_from
		draw_rect(slot, Color("f0c96f") if selected else Color("715744"))
		draw_rect(slot.grow(-4), Color("fff0bd") if not moving else Color("95d2a6"))
		var kind: String = inventory_slots[index]
		if not kind.is_empty() and inventory_item_count(kind) > 0:
			draw_circle(slot.position + Vector2(22, 23), 13, inventory_item_color(kind))
			draw_string(ThemeDB.fallback_font, slot.position + Vector2(43, 25), inventory_item_name(kind), HORIZONTAL_ALIGNMENT_LEFT, 68, 13, Color("352e28"))
			draw_string(ThemeDB.fallback_font, slot.position + Vector2(90, 54), "×%d" % inventory_item_count(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("352e28"))
		else:
			draw_string(ThemeDB.fallback_font, slot.position + Vector2(45, 39), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("937d61"))
	draw_string(ThemeDB.fallback_font, Vector2(576, 526), "Стрелки: слот   M: переместить   X: выбросить   Delete: удалить   I: закрыть", HORIZONTAL_ALIGNMENT_CENTER, 710, 16, Color("493b2f"))

func draw_shop() -> void:
	# Отдельная сцена-интерьер поверх игрового мира.
	draw_rect(Rect2(112, 70, 928, 520), Color("33271f"))
	draw_rect(Rect2(132, 90, 888, 480), Color("f0d49a"))
	for plank_y in range(108, 560, 32):
		draw_line(Vector2(132, plank_y), Vector2(1020, plank_y), Color("d8b878"), 2)
	draw_rect(Rect2(132, 90, 888, 72), Color("744b32"))
	draw_string(ThemeDB.fallback_font, Vector2(576, 138), "СЕЛЬСКАЯ ЛАВКА", HORIZONTAL_ALIGNMENT_CENTER, 500, 30, Color("fff1c4"))
	# Прилавок и декоративные припасы из набора.
	draw_rect(Rect2(158, 190, 210, 302), Color("9b663d"))
	draw_texture_rect_region(SUPPLY_SHEET, Rect2(175, 208, 176, 136), Rect2(0, 0, 176, 136))
	draw_string(ThemeDB.fallback_font, Vector2(174, 470), "Бабушкины запасы", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("fff1c4"))
	# Таблица товаров.
	var table := Rect2(405, 190, 570, 260)
	draw_rect(table, Color("fff4cf"))
	draw_rect(Rect2(table.position, Vector2(table.size.x, 48)), Color("53704b"))
	draw_string(ThemeDB.fallback_font, table.position + Vector2(62, 31), "ТОВАР", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, table.position + Vector2(350, 31), "КУПИТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, table.position + Vector2(455, 31), "ПРОДАТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for i in shop_products.size():
		var product: Dictionary = shop_products[i]
		var row := Rect2(table.position + Vector2(0, 48 + i * 86), Vector2(table.size.x, 86))
		draw_rect(row, Color("f2c96f") if i == shop_selected else Color("f8e8b5"))
		draw_rect(row, Color("76543c"), false, 2)
		draw_texture_rect_region(SUPPLY_SHEET, Rect2(row.position + Vector2(10, 9), Vector2(52, 66)), product.icon)
		draw_string(ThemeDB.fallback_font, row.position + Vector2(72, 50), product.name, HORIZONTAL_ALIGNMENT_LEFT, 260, 19, Color("3d3428"))
		draw_string(ThemeDB.fallback_font, row.position + Vector2(370, 50), "%d 🪙" % product.buy, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("3d3428"))
		draw_string(ThemeDB.fallback_font, row.position + Vector2(478, 50), ("%d 🪙" % product.sell) if product.sell > 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("3d3428"))
	draw_string(ThemeDB.fallback_font, Vector2(690, 495), "↑↓ выбрать   Enter купить   X продать   B закрыть", HORIZONTAL_ALIGNMENT_CENTER, 560, 18, Color("493b2f"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var is_action_key := set_action_key_state(event)
		var is_attack_key := set_attack_key_state(event)
		var is_movement_key := update_movement_key_state(event)
		if not title_screen and event.pressed and is_movement_key:
			apply_immediate_key_response(event)
		if is_action_key and not title_screen and not shop_open and not inventory_open:
			if event.pressed and not event.echo:
				if not perform_context_action() and current_location == "overworld":
					use_selected_tool()
			get_viewport().set_input_as_handled()
		if is_attack_key and not title_screen and not shop_open and not inventory_open:
			if event.pressed and not event.echo:
				attack_slime()
			get_viewport().set_input_as_handled()
