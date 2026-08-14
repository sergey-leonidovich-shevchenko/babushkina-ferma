extends RefCounted

const POTIONS := {
	"healing_potion": {"message":"+60 HP"},
	"mana_potion": {"message":"+30 маны"},
	"energy_potion": {"message":"+8 энергии"},
	"invisibility_potion": {"timer":"invisibility_timer", "duration":18.0, "message":"невидимость на 18 секунд"},
	"strength_potion": {"timer":"strength_timer", "duration":30.0, "message":"сила на 30 секунд"},
	"regeneration_potion": {"timer":"regeneration_timer", "duration":20.0, "message":"регенерация на 20 секунд"},
	"speed_potion": {"timer":"speed_timer", "duration":25.0, "message":"скорость на 25 секунд"},
	"defense_potion": {"timer":"defense_timer", "duration":30.0, "message":"защита на 30 секунд"},
}


## Проверяет, относится ли предмет к зарегистрированной линейке зелий.
static func is_potion(kind: String) -> bool:
	return POTIONS.has(kind)


## Употребляет еду или зелье, применяет эффект и обновляет шаг обучения.
static func consume(game: Node, kind: String) -> bool:
	if not game.InventorySystem.can_use(kind):
		game.message = game.LocaleSystem.text("cannot_use")
		return false
	if not game.change_inventory_count(kind, -1):
		game.message = "Предмет закончился"
		return false
	if is_potion(kind):
		_apply_potion(game, kind)
		game.notify_tutorial("potion")
		if kind == "invisibility_potion": game.notify_tutorial("invisibility")
	else:
		_apply_food(game, kind)
	game.notify_tutorial("eat")
	return true


## Применяет мгновенный или временный эффект выбранного зелья.
static func _apply_potion(game: Node, kind: String) -> void:
	var data: Dictionary = POTIONS[kind]
	match kind:
		"healing_potion": game.heal_player(60)
		"mana_potion": game.player_mana = mini(game.player_mana + 30, game.player_max_mana)
		"energy_potion": game.energy = mini(game.energy + 8, game.SkillSystem.max_stamina(game))
		_:
			game.set(data.timer, maxf(float(game.get(data.timer)), float(data.duration) * game.EstateSystem.potion_multiplier(game)))
			if kind == "regeneration_potion": game.regeneration_tick_timer = 0.0
	game.message = "%s: %s" % [game.inventory_item_name(kind), data.message]


## Применяет существующие пищевые эффекты через единый конвейер расходников.
static func _apply_food(game: Node, kind: String) -> void:
	match kind:
		"carrot": game.heal_player(15); game.message = "Морковь: +15 здоровья"
		"apple": game.heal_player(30); game.message = "Яблоко: +30 здоровья"
		"pear": game.heal_player(24); game.energy = mini(game.energy + 2, game.SkillSystem.max_stamina(game)); game.message = "Груша: +24 здоровья и +2 энергии"
		"cherry": game.regeneration_timer = 6.0; game.regeneration_tick_timer = 0.0; game.message = "Вишня: регенерация +5 HP/с на 6 секунд"
		"plum": game.heal_player(20); game.player_mana = mini(game.player_mana + 8, game.player_max_mana); game.message = "Слива: +20 здоровья и +8 маны"
		"berries": game.regeneration_timer = 8.0; game.regeneration_tick_timer = 0.0; game.message = "Ягоды: регенерация +5 HP/с на 8 секунд"
		"nut": game.strength_timer = 12.0; game.message = "Орех: +1 к силе на 12 секунд"
		"mushroom": game.speed_timer = 10.0; game.message = "Гриб: скорость +30% на 10 секунд"
		"orange": game.heal_player(20); game.energy = mini(game.energy + 2, game.SkillSystem.max_stamina(game)); game.message = "Апельсин: +20 здоровья и +2 энергии"
		"watermelon": game.heal_player(25); game.energy = mini(game.energy + 4, game.SkillSystem.max_stamina(game)); game.message = "Арбуз: +25 здоровья и +4 энергии"
		"tomato", "cabbage", "corn", "potato", "onion": game.heal_player(10); game.message = "%s: +10 здоровья" % game.inventory_item_name(kind)
		"egg", "milk": game.heal_player(14); game.energy = mini(game.energy + 2, game.SkillSystem.max_stamina(game)); game.message = "%s: +14 здоровья и +2 энергии" % game.inventory_item_name(kind)
		"cheese", "honey", "bread", "butter": game.heal_player(22); game.energy = mini(game.energy + 3, game.SkillSystem.max_stamina(game)); game.message = "%s: +22 здоровья и +3 энергии" % game.inventory_item_name(kind)
		"pumpkin", "jam", "cornbread": game.heal_player(28); game.energy = mini(game.energy + 4, game.SkillSystem.max_stamina(game)); game.message = "%s: +28 здоровья и +4 энергии" % game.inventory_item_name(kind)
		"pie", "soup", "omelet": game.heal_player(40); game.energy = mini(game.energy + 6, game.SkillSystem.max_stamina(game)); game.message = "%s: +40 здоровья и +6 энергии" % game.inventory_item_name(kind)


## Обновляет длительность бафов и периодическое восстановление здоровья.
static func update_effects(game: Node, delta: float) -> void:
	for timer in ["strength_timer", "speed_timer", "invisibility_timer", "defense_timer"]:
		game.set(timer, maxf(float(game.get(timer)) - delta, 0.0))
	if game.regeneration_timer <= 0.0: return
	game.regeneration_timer = maxf(game.regeneration_timer - delta, 0.0)
	game.regeneration_tick_timer += delta
	while game.regeneration_tick_timer >= 1.0:
		game.regeneration_tick_timer -= 1.0
		game.heal_player(5)


## Снимает невидимость после агрессивного действия героя.
static func break_invisibility(game: Node) -> bool:
	if game.invisibility_timer <= 0.0:
		return false
	game.invisibility_timer = 0.0
	game.message = "Невидимость рассеялась после атаки"
	return true
