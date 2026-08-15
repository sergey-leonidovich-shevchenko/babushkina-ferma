extends RefCounted

## Дерево талантов расходует очки общего уровня, не смешивая их с профессиями,
## которые продолжают автоматически расти от практики соответствующих действий.

const GROUPS := [
	{"id":"combat", "name":"СРАЖЕНИЯ", "icon":"⚔"},
	{"id":"farming", "name":"ФЕРМЕРСТВО", "icon":"♣"},
	{"id":"fishing", "name":"РЫБАЛКА", "icon":"≈"},
	{"id":"crafting", "name":"РЕМЕСЛО", "icon":"◆"},
]

const TALENTS := [
	{"id":"combat_strength", "group":"combat", "name":"Сила", "icon":"⚔", "description":"Постоянно увеличивает урон героя на 1.", "requires":[]},
	{"id":"combat_agility", "group":"combat", "name":"Ловкость", "icon":"➶", "description":"Ускоряет движение на 8% и сокращает откат рывка.", "requires":[]},
	{"id":"combat_vitality", "group":"combat", "name":"Закалка", "icon":"♥", "description":"Добавляет 15 к максимальному здоровью.", "requires":["combat_strength"]},
	{"id":"combat_power_strike", "group":"combat", "name":"Мощный удар", "icon":"✦", "description":"Каждый четвёртый удар наносит ещё 2 урона.", "requires":["combat_strength"]},
	{"id":"combat_master", "group":"combat", "name":"Мастер боя", "icon":"★", "description":"Даёт ещё 10% скорости и 1 урон после освоения двух ветвей.", "requires":["combat_agility", "combat_power_strike"]},

	{"id":"farm_orchard", "group":"farming", "name":"Садовод", "icon":"♠", "description":"Открывает фруктовые саженцы и выращивание деревьев.", "requires":[]},
	{"id":"farm_wide_till", "group":"farming", "name":"Широкая борозда", "icon":"▰", "description":"Мотыга вскапывает линию из трёх клеток.", "requires":[]},
	{"id":"farm_field_master", "group":"farming", "name":"Поле 3×3", "icon":"▦", "description":"Мотыга обрабатывает сразу девять клеток.", "requires":["farm_wide_till"]},
	{"id":"farm_exotic_crops", "group":"farming", "name":"Редкие культуры", "icon":"✿", "description":"Открывает тыкву, дыню, хлопок и подсолнух.", "requires":["farm_orchard"]},
	{"id":"farm_cooking", "group":"farming", "name":"Домашняя кухня", "icon":"♨", "description":"Позволяет готовить еду в установленном котелке.", "requires":[]},

	{"id":"fish_fine_rod", "group":"fishing", "name":"Точная снасть", "icon":"⌁", "description":"Открывает улучшенную удочку и ловкую рыбу.", "requires":[]},
	{"id":"fish_deep_water", "group":"fishing", "name":"Глубокая вода", "icon":"▼", "description":"Улучшенная удочка достаёт глубоководную рыбу.", "requires":["fish_fine_rod"]},
	{"id":"fish_big_game", "group":"fishing", "name":"Большой улов", "icon":"◉", "description":"Повышает размер улова и открывает крупную рыбу.", "requires":["fish_fine_rod"]},
	{"id":"fish_crab_traps", "group":"fishing", "name":"Крабовые ловушки", "icon":"⌑", "description":"Открывает крафт и установку ловушек у воды.", "requires":[]},
	{"id":"fish_master", "group":"fishing", "name":"Речной знаток", "icon":"★", "description":"Расширяет зелёную зону и повышает качество улова.", "requires":["fish_deep_water", "fish_big_game"]},

	{"id":"craft_apprentice", "group":"crafting", "name":"Ученик мастера", "icon":"◇", "description":"Открывает сложные инструменты и устройства.", "requires":[]},
	{"id":"craft_efficient", "group":"crafting", "name":"Бережливость", "icon":"⅔", "description":"Снижает расход материалов сложных рецептов.", "requires":["craft_apprentice"]},
	{"id":"craft_alchemy", "group":"crafting", "name":"Алхимия", "icon":"⚗", "description":"Открывает приготовление продвинутых зелий.", "requires":["craft_apprentice"]},
	{"id":"craft_engineering", "group":"crafting", "name":"Механизмы", "icon":"⚙", "description":"Открывает ловушки и улучшенное снаряжение.", "requires":["craft_apprentice"]},
	{"id":"craft_master", "group":"crafting", "name":"Мастерская", "icon":"★", "description":"Даёт дополнительный предмет при каждом пятом крафте.", "requires":["craft_efficient", "craft_engineering"]},
]


## Создаёт полный словарь неоткрытых талантов для новой игры и миграции сохранений.
static func default_levels() -> Dictionary:
	var result := {}
	for talent in TALENTS:
		result[String(talent.id)] = 0
	return result


## Дополняет загруженный словарь новыми талантами и нормализует известные значения.
static func merge_levels(saved: Dictionary) -> Dictionary:
	var result := default_levels()
	for talent_id in result:
		result[talent_id] = clampi(int(saved.get(talent_id, 0)), 0, 1)
	return result


## Возвращает метаданные таланта по идентификатору или пустой словарь.
static func data(talent_id: String) -> Dictionary:
	for talent in TALENTS:
		if String(talent.id) == talent_id:
			return talent
	return {}


## Возвращает талант по безопасно зацикленному индексу интерфейса.
static func at(index: int) -> Dictionary:
	return TALENTS[posmod(index, TALENTS.size())]


## Проверяет, открыт ли талант в текущем сохранении.
static func has(game: Node, talent_id: String) -> bool:
	return int(game.talent_levels.get(talent_id, 0)) > 0


## Возвращает список ещё не выполненных зависимостей выбранного таланта.
static func missing_requirements(game: Node, talent_id: String) -> Array[String]:
	var result: Array[String] = []
	var talent := data(talent_id)
	for required_id in talent.get("requires", []):
		if not has(game, String(required_id)):
			result.append(String(required_id))
	return result


## Проверяет возможность вложить одно свободное очко без изменения состояния героя.
static func can_unlock(game: Node, talent_id: String) -> bool:
	return game.skill_points > 0 and not has(game, talent_id) and not data(talent_id).is_empty() and missing_requirements(game, talent_id).is_empty()


## Тратит очко общего уровня, применяет постоянные характеристики и запускает обучение.
static func unlock(game: Node, talent_id: String) -> bool:
	var talent := data(talent_id)
	if talent.is_empty():
		return false
	if has(game, talent_id):
		game.message = "Способность уже изучена"
		return false
	var missing := missing_requirements(game, talent_id)
	if not missing.is_empty():
		game.message = "Сначала изучи: %s" % requirement_names(missing)
		return false
	if game.skill_points <= 0:
		game.message = game.LocaleSystem.text("no_points")
		return false
	var old_max_hp: int = game.player_max_hp
	game.talent_levels[talent_id] = 1
	game.skill_points -= 1
	game.SkillSystem.recalculate_resources(game)
	game.player_hp = mini(game.player_hp + game.player_max_hp - old_max_hp, game.player_max_hp)
	game.message = "Изучено: %s" % String(talent.name)
	game.play_sfx("level_up")
	game.notify_tutorial("talent_tree")
	return true


## Собирает читабельные названия зависимостей для подсказки заблокированного узла.
static func requirement_names(requirements: Array[String]) -> String:
	var names: Array[String] = []
	for talent_id in requirements:
		var talent := data(talent_id)
		names.append(String(talent.get("name", talent_id)))
	return ", ".join(names)


## Возвращает постоянную прибавку к урону от боевых талантов.
static func combat_damage_bonus(game: Node) -> int:
	return int(has(game, "combat_strength")) + int(has(game, "combat_master"))


## Возвращает множитель скорости от ловкости и освоения всей боевой ветви.
static func movement_multiplier(game: Node) -> float:
	return 1.0 + (0.08 if has(game, "combat_agility") else 0.0) + (0.10 if has(game, "combat_master") else 0.0)


## Возвращает прибавку здоровья, которую SkillSystem включает в общий расчёт ресурсов.
static func health_bonus(game: Node) -> int:
	return 15 if has(game, "combat_vitality") else 0


## Возвращает число клеток, которое мотыга может обработать одним действием.
static func tilling_size(game: Node) -> int:
	if has(game, "farm_field_master"):
		return 9
	if has(game, "farm_wide_till"):
		return 3
	return 1


## Возвращает смещения грядок: линия направлена от героя, а улучшение создаёт квадрат 3×3.
static func tilling_offsets(game: Node) -> Array[Vector2i]:
	if tilling_size(game) == 1:
		return [Vector2i.ZERO]
	if tilling_size(game) == 9:
		var square: Array[Vector2i] = []
		for y in range(-1, 2):
			for x in range(-1, 2):
				square.append(Vector2i(x, y))
		return square
	var direction := Vector2i(roundi(game.facing.x), roundi(game.facing.y))
	if direction == Vector2i.ZERO:
		direction = Vector2i.RIGHT
	return [Vector2i.ZERO, direction, direction * 2]


## Проверяет доступность редкой культуры до расходования семян и энергии.
static func can_plant_crop(game: Node, crop_kind: String) -> bool:
	return crop_kind not in ["pumpkin", "melon", "cotton", "sunflower"] or has(game, "farm_exotic_crops")


## Проверяет, доступна ли герою рыба с указанными требованиями каталога.
static func can_catch_fish(game: Node, fish: Dictionary) -> bool:
	var required_talent := String(fish.get("requires", ""))
	if not required_talent.is_empty() and not has(game, required_talent):
		return false
	if bool(fish.get("advanced_rod", false)) and game.inventory_item_count("advanced_fishing_rod") <= 0:
		return false
	return true


## Возвращает прибавку к размеру рыбы от таланта охоты за крупным уловом.
static func fishing_size_bonus(game: Node) -> float:
	return 0.16 if has(game, "fish_big_game") else 0.0


## Возвращает прибавку к высоте управляемой зоны для мастера рыбалки.
static func fishing_bar_bonus(game: Node) -> float:
	return 0.06 if has(game, "fish_master") else 0.0


## Проверяет требование таланта, указанное непосредственно в рецепте.
static func recipe_unlocked(game: Node, recipe: Dictionary) -> bool:
	for talent_id in recipe.get("talents", []):
		if not has(game, String(talent_id)):
			return false
	var single_talent := String(recipe.get("talent", ""))
	return single_talent.is_empty() or has(game, single_talent)


## Рассчитывает фактическую цену ингредиента с учётом профессии и таланта бережливости.
static func recipe_material_cost(game: Node, amount: int) -> int:
	var result: int = game.SkillSystem.material_cost(game, amount)
	if has(game, "craft_efficient") and result >= 3:
		result -= 1
	return maxi(1, result)
