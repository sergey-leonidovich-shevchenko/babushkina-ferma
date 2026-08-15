extends RefCounted

const XP_SOURCES := {
	"посадка":1, "урожай":3, "вспашка 1/3/9": [1,1,3], "добыча":1, "рубка":1,
	"крабовая ловушка":8, "крафт":4, "кузница":6, "обычное задание":25,
}


## Собирает детерминированный снимок баланса без изменения состояния игры.
static func snapshot(game: Node) -> Dictionary:
	var inventory_value := 0
	for kind in game.state.inventory.counts:
		inventory_value += game.inventory_item_count(kind) * game.ShopSystem.sell_price(String(kind))
	var professions := {}
	for profession in game.skill_levels:
		professions[profession] = {"rank":int(game.skill_levels[profession]), "xp":int(game.skill_xp.get(profession, 0))}
	return {
		"level":game.player_level, "xp":game.player_xp, "next_xp":game.SkillSystem.xp_to_next_character_level(game.player_level),
		"free_points":game.skill_points, "spent_points":game.TalentSystem.spent_points(game), "professions":professions,
		"hp":"%d/%d" % [game.player_hp, game.player_max_hp], "mana":"%d/%d" % [game.player_mana, game.player_max_mana], "energy":game.energy,
		"damage":game.CombatSystem.player_attack_damage(game), "speed":roundi(game.speed * game.TalentSystem.movement_multiplier(game)),
		"till_cells":game.TalentSystem.tilling_size(game), "harvest":game.SkillSystem.harvest_count(game),
		"fish_wait":snappedf(game.SkillSystem.fishing_wait(game), 0.01), "fish_bar_bonus":game.TalentSystem.fishing_bar_bonus(game),
		"coins":game.coins, "inventory_sale_value":inventory_value, "xp_sources":XP_SOURCES.duplicate(true),
	}


## Возвращает компактные строки для диагностической панели тестировщика.
static func lines(game: Node) -> Array[String]:
	var value := snapshot(game)
	return [
		"Уровень %d · XP %d/%d · очки %d+%d" % [value.level,value.xp,value.next_xp,value.free_points,value.spent_points],
		"HP %s · MP %s · EN %d" % [value.hp,value.mana,value.energy],
		"Урон %d · скорость %d px/s" % [value.damage,value.speed],
		"Мотыга %d кл. · урожай ×%d" % [value.till_cells,value.harvest],
		"Рыбалка: ожидание %.2f · зона +%.0f%%" % [value.fish_wait,float(value.fish_bar_bonus)*100.0],
		"Монеты %d · стоимость рюкзака %d" % [value.coins,value.inventory_sale_value],
	]
