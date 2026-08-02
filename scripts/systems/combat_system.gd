extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const MAX_ENEMY_LEVEL := 5
const AGGRO_RADIUS := 380.0
const MELEE_DISTANCE := 68.0
const FAMILY_ORDER := ["plant", "orc", "skeleton", "undead", "cave_guardian"]
const TYPES := {
	"plant": {"name":"Хищное растение","hp":5,"damage":12,"xp":14,"speed":0.0,"mobile":false,"range":155.0,"loot":{"fiber":2,"rare_seeds":1}},
	"orc": {"name":"Орк-разбойник","hp":8,"damage":18,"xp":22,"speed":105.0,"mobile":true,"range":MELEE_DISTANCE,"loot":{"metal":2,"coins":15,"orc_blade":1}},
	"skeleton": {"name":"Скелет","hp":6,"damage":16,"xp":18,"speed":92.0,"mobile":true,"range":MELEE_DISTANCE,"loot":{"bones":3,"ancient_key":1}},
	"undead": {"name":"Проклятый рыцарь","hp":10,"damage":22,"xp":30,"speed":78.0,"mobile":true,"range":MELEE_DISTANCE,"loot":{"bones":2,"blue_gem":1}},
	"cave_guardian": {"name":"Хранитель глубин","hp":12,"damage":24,"xp":40,"speed":66.0,"mobile":true,"range":MELEE_DISTANCE + 8.0,"loot":{"moon_relic":1,"blue_gem":2}}
}
const SPAWNS := [
	{"kind":"plant","location":"forest","position":Vector2(920,430),"level":1},
	{"kind":"orc","location":"ruins","position":Vector2(1180,500),"level":1},
	{"kind":"skeleton","location":"cave","position":Vector2(880,520),"level":1},
	{"kind":"undead","location":"cursed","position":Vector2(1320,460),"level":1},
	{"kind":"cave_guardian","location":"cave","position":Vector2(1450,500),"level":1},
	{"kind":"plant","location":"forest","position":Vector2(520,420),"level":2},
	{"kind":"plant","location":"forest","position":Vector2(1260,700),"level":3},
	{"kind":"plant","location":"forest","position":Vector2(1880,690),"level":4},
	{"kind":"plant","location":"forest","position":Vector2(2180,390),"level":5},
	{"kind":"orc","location":"ruins","position":Vector2(720,680),"level":2},
	{"kind":"orc","location":"ruins","position":Vector2(1040,780),"level":3},
	{"kind":"orc","location":"ruins","position":Vector2(1920,720),"level":4},
	{"kind":"orc","location":"ruins","position":Vector2(2140,340),"level":5},
	{"kind":"skeleton","location":"cave","position":Vector2(500,720),"level":2},
	{"kind":"skeleton","location":"cave","position":Vector2(1120,300),"level":3},
	{"kind":"skeleton","location":"cave","position":Vector2(1740,730),"level":4},
	{"kind":"skeleton","location":"cave","position":Vector2(2080,340),"level":5},
	{"kind":"undead","location":"cursed","position":Vector2(760,720),"level":2},
	{"kind":"undead","location":"cursed","position":Vector2(1080,300),"level":3},
	{"kind":"undead","location":"cursed","position":Vector2(1800,680),"level":4},
	{"kind":"undead","location":"cursed","position":Vector2(2140,360),"level":5},
	{"kind":"cave_guardian","location":"cave","position":Vector2(640,300),"level":2},
	{"kind":"cave_guardian","location":"cave","position":Vector2(1220,760),"level":3},
	{"kind":"cave_guardian","location":"cave","position":Vector2(1680,300),"level":4},
	{"kind":"cave_guardian","location":"cave","position":Vector2(2160,680),"level":5},
]


## Создаёт противников с рассчитанными характеристиками и runtime-состоянием AI.
static func default_enemies() -> Array:
	var result: Array = []
	for spawn in SPAWNS:
		var enemy: Dictionary = spawn.duplicate(true)
		enemy.level = clampi(int(enemy.level), 1, MAX_ENEMY_LEVEL)
		enemy.max_hp = max_hp(enemy.kind, enemy.level)
		enemy.hp = enemy.max_hp
		enemy.alive = true
		enemy.home = enemy.position
		enemy.direction = Vector2.DOWN
		enemy.moving = false
		enemy.attack_timer = 0.0
		enemy.visual_state = "idle"
		enemy.visual_time = 0.0
		result.append(enemy)
	return result


## Рассчитывает здоровье врага с ростом примерно на 45 процентов за уровень.
static func max_hp(kind: String, level: int) -> int:
	var base: int = int(TYPES[kind].hp)
	return base + ceili(base * 0.45 * float(clampi(level, 1, MAX_ENEMY_LEVEL) - 1))


## Рассчитывает силу удара конкретного уровня.
static func attack_damage(kind: String, level: int) -> int:
	return int(TYPES[kind].damage) + (clampi(level, 1, MAX_ENEMY_LEVEL) - 1) * 3


## Рассчитывает награду опыта конкретного уровня.
static func xp_reward(kind: String, level: int) -> int:
	return int(roundi(float(TYPES[kind].xp) * (1.0 + 0.5 * float(clampi(level, 1, MAX_ENEMY_LEVEL) - 1))))


## Сопоставляет уровни 1–2, 3–4 и 5 трём различимым строкам атласа.
static func visual_rank(level: int) -> int:
	return mini(floori(float(clampi(level, 1, MAX_ENEMY_LEVEL) - 1) / 2.0), 2)


## Возвращает множитель добычи: обычный, двойной для ветерана и тройной для элиты.
static func loot_multiplier(level: int) -> int:
	return 1 + floori(float(clampi(level, 1, MAX_ENEMY_LEVEL) - 1) / 2.0)


## Находит ближайшего живого противника в радиусе выбранного оружия.
static func nearest(game: Node) -> int:
	var result := -1
	var distance_limit := 280.0 if game.equipped_weapon == "bow" else 105.0
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if enemy.alive and enemy.location == game.current_location:
			var distance: float = game.player.distance_to(enemy.position)
			if distance < distance_limit:
				distance_limit = distance
				result = index
	return result


## Обновляет погоню, направление и атаки всех противников активной локации.
static func update(game: Node, delta: float) -> void:
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if not enemy.alive or enemy.location != game.current_location:
			continue
		var data: Dictionary = TYPES[enemy.kind]
		var distance: float = enemy.position.distance_to(game.player)
		enemy.moving = false
		if bool(data.mobile) and distance <= AGGRO_RADIUS and distance > float(data.range):
			var direction: Vector2 = enemy.position.direction_to(game.player)
			var motion := direction * (float(data.speed) + float(enemy.level - 1) * 7.0) * delta
			var next_position: Vector2 = game.NavigationSystem.move_enemy(game, index, motion)
			enemy.moving = next_position.distance_squared_to(enemy.position) > 0.04
			if enemy.moving:
				enemy.direction = enemy.position.direction_to(next_position)
				enemy.position = next_position
				game.notify_tutorial("enemy_movement")
		distance = enemy.position.distance_to(game.player)
		enemy.attack_timer = maxf(float(enemy.get("attack_timer", 0.0)) - delta, 0.0)
		if distance <= float(data.range) and enemy.attack_timer <= 0.0:
			enemy.attack_timer = maxf(0.75, 1.65 - float(enemy.level) * 0.09)
			enemy.visual_state = "attack"
			enemy.visual_time = 0.0
			damage_player(game, attack_damage(enemy.kind, enemy.level), LocaleSystem.entity(enemy.kind))
		game.enemy_nodes[index] = enemy


## Перемещает проверенный удар героя в общую систему урона.
static func attack(game: Node, index: int) -> bool:
	if index < 0 or index >= game.enemy_nodes.size(): return false
	var enemy: Dictionary = game.enemy_nodes[index]
	if not enemy.alive or enemy.location != game.current_location: return false
	var attack_range := 280.0 if game.equipped_weapon == "bow" else 105.0
	if game.player.distance_to(enemy.position) > attack_range: return false
	var damage: int = 1 + (1 if game.strength_timer > 0 else 0) + game.InventorySystem.damage_bonus(game)
	if game.equipped_weapon == "forest_sword": damage += 1
	elif game.equipped_weapon == "crystal_sword": damage += 2
	elif game.equipped_weapon == "bow": damage += 1
	game.AnimationSystem.begin_player_attack(game)
	game.play_sfx("attack")
	apply_damage(game, index, damage)
	game.notify_tutorial("combat_animation")
	return true


## Наносит урон цели и масштабирует опыт с добычей по её уровню ровно один раз.
static func apply_damage(game: Node, index: int, damage: int, attacker_name: String = "") -> bool:
	if index < 0 or index >= game.enemy_nodes.size() or damage <= 0:
		return false
	var enemy: Dictionary = game.enemy_nodes[index]
	if not enemy.alive or enemy.location != game.current_location:
		return false
	if enemy.level > 1:
		game.notify_tutorial("enemy_levels")
	enemy.hp -= damage
	enemy = game.AnimationSystem.hit_enemy(enemy, enemy.hp <= 0)
	game.play_sfx("defeat" if enemy.hp <= 0 else "hit")
	if enemy.hp <= 0:
		enemy.alive = false
		var reward := xp_reward(enemy.kind, enemy.level)
		game.award_xp(reward)
		game.SkillSystem.award_profession_xp(game, "combat", reward / 2)
		var multiplier := loot_multiplier(enemy.level)
		for kind in TYPES[enemy.kind].loot:
			var count: int = int(TYPES[enemy.kind].loot[kind]) * multiplier
			if kind == "coins": game.coins += count
			else: game.dropped_items.append({"kind":kind,"count":count,"position":enemy.position})
		game.message = "%s • ур. %d: +%d XP" % [LocaleSystem.entity(enemy.kind), enemy.level, reward]
	else:
		var prefix := "%s → " % attacker_name if not attacker_name.is_empty() else ""
		game.message = "%s%s: -%d HP" % [prefix, LocaleSystem.entity(enemy.kind), damage]
	game.enemy_nodes[index] = enemy
	return true


## Применяет входящий урон с учётом экипировки, напарников и спасения после поражения.
static func damage_player(game: Node, raw_damage: int, source_name: String) -> int:
	var incoming := maxi(1, game.InventorySystem.incoming_damage(game, raw_damage) - game.CompanionSystem.defense_bonus(game))
	game.player_hp -= incoming
	game.message = "%s: -%d HP" % [source_name, incoming]
	if game.player_hp <= 0:
		game.player_hp = game.player_max_hp
		game.player = Vector2(260, 360)
		game.coins = maxi(0, game.coins - 5)
		game.message = "Бабушка спасла тебя. Потеряно 5 монет"
	return incoming


## Передаёт атаку напарника в общий конвейер урона без анимации героя.
static func companion_attack(game: Node, index: int, damage: int, attacker_name: String) -> bool:
	return apply_damage(game, index, damage, attacker_name)
