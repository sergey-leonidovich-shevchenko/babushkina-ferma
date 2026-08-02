extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const SKILLS := [
	{"id":"vitality","name":"Здоровье","icon":"❤","description":"+10 к максимальному здоровью за ранг"},
	{"id":"mana","name":"Мана","icon":"✦","description":"+10 к запасу маны и ускорение её восстановления"},
	{"id":"stamina","name":"Стамина","icon":"⚡","description":"+2 к запасу сил за ранг"},
	{"id":"farming","name":"Фермерство","icon":"♣","description":"Опыт за работу на грядках; с 3 ранга больше урожая","profession":true},
	{"id":"smithing","name":"Кузнечное дело","icon":"◆","description":"Опыт за крафт; с 3 ранга рецепты дешевле","profession":true},
	{"id":"combat","name":"Бой","icon":"⚔","description":"Опыт за победы; каждые 2 ранга дают +1 урон","profession":true},
	{"id":"mining","name":"Горное дело","icon":"⬟","description":"Опыт за добычу; с 3 ранга жилы дают больше","profession":true},
	{"id":"fishing","name":"Рыбалка","icon":"≈","description":"Опыт за улов; с 3 ранга рыба клюёт быстрее","profession":true},
]

## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_levels() -> Dictionary:
	var result := {}
	for skill in SKILLS:
		result[skill.id] = 0
	return result

## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_xp() -> Dictionary:
	var result := {}
	for skill in SKILLS:
		if skill.get("profession", false):
			result[skill.id] = 0
	return result

## Выполняет операцию «xp к следующего персонажа уровня» и возвращает результат согласно контракту метода.
static func xp_to_next_character_level(level: int) -> int:
	return 50 + maxi(level - 1, 0) * 25

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func xp_to_next_skill_rank(rank: int) -> int:
	return 20 + rank * 15

## Возвращает название или описание навыка на выбранном языке.
static func skill(game: Node, skill_id: String) -> int:
	return int(game.skill_levels.get(skill_id, 0))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func award_character_xp(game: Node, amount: int, reason: String = "") -> void:
	game.player_xp += amount
	var gained_levels := 0
	while game.player_xp >= xp_to_next_character_level(game.player_level):
		game.player_xp -= xp_to_next_character_level(game.player_level)
		game.player_level += 1
		game.skill_points += 1
		gained_levels += 1
	if gained_levels > 0:
		var old_max_hp: int = game.player_max_hp
		recalculate_resources(game)
		game.player_hp = mini(game.player_hp + game.player_max_hp - old_max_hp, game.player_max_hp)
		game.message = game.LocaleSystem.text("level_up", [game.player_level])
		game.play_sfx("level_up")
		game.notify_tutorial("level_up")
	elif not reason.is_empty():
		game.message = "%s: +%d опыта" % [reason, amount]

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func award_profession_xp(game: Node, skill_id: String, amount: int) -> bool:
	if not game.skill_xp.has(skill_id):
		return false
	game.skill_xp[skill_id] += amount
	var ranked_up := false
	while game.skill_xp[skill_id] >= xp_to_next_skill_rank(skill(game, skill_id)):
		game.skill_xp[skill_id] -= xp_to_next_skill_rank(skill(game, skill_id))
		game.skill_levels[skill_id] = skill(game, skill_id) + 1
		ranked_up = true
	if ranked_up:
		game.message = "%s повышено до ранга %d" % [name_for(skill_id), skill(game, skill_id)]
		game.notify_tutorial("profession")
	return ranked_up

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func allocate(game: Node, skill_id: String) -> bool:
	if game.skill_points <= 0 or not game.skill_levels.has(skill_id):
		game.message = game.LocaleSystem.text("no_points")
		return false
	var old_hp: int = game.player_max_hp
	var old_mana: int = game.player_max_mana
	game.skill_levels[skill_id] = skill(game, skill_id) + 1
	game.skill_points -= 1
	recalculate_resources(game)
	game.player_hp = mini(game.player_hp + game.player_max_hp - old_hp, game.player_max_hp)
	game.player_mana = mini(game.player_mana + game.player_max_mana - old_mana, game.player_max_mana)
	if skill_id == "stamina":
		game.energy = mini(game.energy + 2, max_stamina(game))
	game.message = game.LocaleSystem.text("rank_up", [name_for(skill_id), skill(game, skill_id)])
	game.notify_tutorial("skill_point")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func recalculate_resources(game: Node) -> void:
	var equipment_hp := 0
	if game.equipment.get("head", "") == "iron_helmet": equipment_hp += 10
	if game.equipment.get("body", "") == "guardian_armor": equipment_hp += 20
	if game.equipment.get("offhand", "") == "oak_shield": equipment_hp += 5
	game.player_max_hp = game.MAX_BASE_HP + (game.player_level - 1) * 10 + skill(game, "vitality") * 10 + equipment_hp
	game.player_max_mana = 40 + skill(game, "mana") * 10
	game.player_hp = mini(game.player_hp, game.player_max_hp)
	game.player_mana = mini(game.player_mana, game.player_max_mana)
	game.energy = mini(game.energy, max_stamina(game))

## Обновляет ресурсов на текущем кадре.
static func update_resources(game: Node, delta: float) -> void:
	if game.player_mana < game.player_max_mana:
		game.mana_regen_progress += delta * (1.0 + skill(game, "mana") * 0.15)
		while game.mana_regen_progress >= 1.0:
			game.mana_regen_progress -= 1.0
			game.player_mana = mini(game.player_mana + 1, game.player_max_mana)
	if game.energy < max_stamina(game):
		game.stamina_regen_progress += delta
		while game.stamina_regen_progress >= 4.0:
			game.stamina_regen_progress -= 4.0
			game.energy = mini(game.energy + 1, max_stamina(game))

## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func max_stamina(game: Node) -> int:
	return 12 + skill(game, "stamina") * 2

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func combat_bonus(game: Node) -> int:
	return skill(game, "combat") / 2

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func harvest_count(game: Node) -> int:
	return 1 + skill(game, "farming") / 3

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func mined_count(game: Node) -> int:
	return 1 + skill(game, "mining") / 3

## Выполняет операцию «рыбалки ожидания» и возвращает результат согласно контракту метода.
static func fishing_wait(game: Node) -> float:
	return maxf(1.0, 2.5 - skill(game, "fishing") * 0.15)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func fishing_count(game: Node) -> int:
	return 1 + skill(game, "fishing") / 5

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func material_cost(game: Node, amount: int) -> int:
	return maxi(1, amount - skill(game, "smithing") / 3)

## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func name_for(skill_id: String) -> String:
	return LocaleSystem.skill(skill_id)
