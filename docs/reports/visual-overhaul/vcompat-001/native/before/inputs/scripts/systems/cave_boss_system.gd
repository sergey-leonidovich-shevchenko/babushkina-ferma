extends RefCounted

const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Attacks := preload("res://scripts/systems/cave_boss_attack_system.gd")
const Minions := preload("res://scripts/systems/cave_boss_minion_system.gd")
const Shots := preload("res://scripts/systems/cave_boss_projectile_system.gd")

## Находит выделенного хранителя святилища, сохраняя прежние индексы остальных врагов.
static func index(game: Node) -> int:
	var cached := int(game.get_meta("cave_boss_index", -1))
	if cached >= 0 and cached < game.enemy_nodes.size() and bool(game.enemy_nodes[cached].get("cave_boss", false)): return cached
	for enemy_index in game.enemy_nodes.size():
		if bool(game.enemy_nodes[enemy_index].get("cave_boss", false)):
			game.set_meta("cave_boss_index", enemy_index); return enemy_index
	return -1

## Начинает пробуждённый у алтаря бой с паузой перед первой атакой.
static func start(game: Node) -> bool:
	var boss_index := index(game)
	if game.current_location != Data.LOCATION or boss_index < 0 or not game.enemy_nodes[boss_index].alive: return false
	var state: Dictionary = game.state.world.cave_boss
	if state.active: return false
	state.active = true; state.phase = Data.phase(int(game.enemy_nodes[boss_index].hp)); state.recovery = 1.6
	game.notify_tutorial("cave_boss_phases")
	return true

## Очищает только временные угрозы при выходе, загрузке или поражении героя.
static func reset(game: Node) -> void:
	game.state.world.cave_boss = Data.default_state()

## Готовит отдельный проверочный запуск боя с оружием и едой без автоматической записи сохранения.
static func configure_preview(game: Node) -> void:
	game.language_screen = false; game.title_screen = false; game.current_location = Data.LOCATION
	game.player = preload("res://scripts/systems/cave_boss_arena_data.gd").ALTAR + Vector2(72,24); game.tutorial_visible = false
	game.state.player.profile.created = true
	game.FarmLifeSystem.state(game).cutscene = ""; game.FarmLifeSystem.state(game).cutscene_timer = 0.0
	game.FirstChapterSystem.state(game).completed = true
	game.enemy_nodes = game.CombatSystem.default_enemies(); reset(game)
	game.change_inventory_count("iron_spear",1); game.change_inventory_count("apple",15)
	game.InventorySystem.equip(game,"iron_spear"); game.player_hp = game.player_max_hp
	game.discovery_current.clear(); game.discovery_timer = 0.0
	game.sync_background_location(); game.update_camera()

## Реагирует на потерю здоровья немедленно, отменяя прежнюю атаку при переходе стадии.
static func on_damage(game: Node) -> void:
	var boss_index := index(game)
	if boss_index < 0: return
	var boss: Dictionary = game.enemy_nodes[boss_index]
	if not boss.alive:
		preload("res://scripts/systems/cave_boss_arena_system.gd").award_relic(game)
		reset(game); game.state.world.cave_boss.victory = 4.0
		game.notify_tutorial("cave_boss_victory")
		return
	if not game.state.world.cave_boss.active: return
	var state: Dictionary = game.state.world.cave_boss
	var phase := Data.phase(int(boss.hp))
	if phase <= int(state.phase): return
	state.phase = phase; state.attack = {}; state.zones.clear(); state.projectiles.clear(); state.cycle = 0; state.recovery = 2.2; state.summoning = 0.0
	state.transition = 2.2
	for minion in state.minions:
		minion.attack = 0.0; minion.fly_windup = 0.0
		minion.cooldown = maxf(float(minion.cooldown),1.0)
		minion.fly_cooldown = maxf(float(minion.fly_cooldown),1.0)
	state.summon_timer = maxf(float(state.summon_timer), 5.0)
	game.notify_tutorial("cave_boss_phases")

## Продвигает бой небольшими шагами, прекращая симуляцию при паузе или смене комнаты.
static func update(game: Node, delta: float) -> void:
	var state: Dictionary = game.state.world.cave_boss
	if game.current_location != Data.LOCATION or game.menu_state.defeat_open:
		if state.active or not state.minions.is_empty() or state.fly_timer > 0.0: reset(game)
		return
	if game.menu_state.pause_open or game.menu_state.settings_open or preload("res://scripts/systems/menu_hub_system.gd").active(game): return
	state.victory = maxf(0.0, float(state.victory) - delta)
	var boss_index := index(game)
	if boss_index < 0 or not game.enemy_nodes[boss_index].alive: return
	if not state.active: return
	on_damage(game)
	var remaining := maxf(0.0, delta)
	while remaining > 0.0 and game.state.world.cave_boss.active:
		var step := minf(remaining, 0.05)
		_tick(game, boss_index, step); remaining -= step
		if game.menu_state.defeat_open: reset(game); return

## Выполняет один боевой шаг с честными окнами восстановления и отдельным предупреждением призыва.
static func _tick(game: Node, boss_index: int, delta: float) -> void:
	var state: Dictionary = game.state.world.cave_boss
	state.clock += delta; state.hit_cooldown = maxf(0.0, float(state.hit_cooldown) - delta)
	for effect in state.effects: effect.time += delta
	state.effects = state.effects.filter(func(effect): return float(effect.time) < 0.65)
	Shots.update(game, delta); Shots.update_bites(game, delta)
	if float(state.transition) > 0.0:
		state.transition = maxf(0.0,float(state.transition)-delta)
		state.recovery = maxf(0.0,float(state.recovery)-delta)
		return
	Minions.update(game, delta)
	if game.menu_state.defeat_open: return
	state.summon_timer = maxf(0.0, float(state.summon_timer) - delta)
	if not state.attack.is_empty(): Attacks.update(game, boss_index, delta); return
	if float(state.summoning) > 0.0:
		state.summoning = maxf(0.0, float(state.summoning) - delta)
		if float(state.summoning) <= 0.0:
			var kinds: Array = ["skeleton", "skeleton"] if int(state.phase) == 1 else (["zombie","vampire"] if int(state.phase) == 2 else ["skeleton","zombie","vampire"])
			Minions.summon(game, kinds); state.recovery = 1.0; state.summon_timer = 20.0
		return
	state.recovery = maxf(0.0, float(state.recovery) - delta)
	if float(state.recovery) > 0.0 or game.invisibility_timer > 0.0: return
	if float(state.summon_timer) <= 0.0 and Minions.living_count(game) < Data.MINION_LIMIT:
		state.summoning = 1.2; game.notify_tutorial("cave_boss_summons"); return
	var catalog: Array = Data.PHASES[int(state.phase) - 1]
	var id := String(catalog[posmod(int(state.cycle), catalog.size())])
	state.cycle += 1
	Attacks.begin(game, id, game.enemy_nodes[boss_index])
