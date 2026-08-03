extends RefCounted

const COUNCIL_POSITION := Vector2(900, 360)
const CLUE_POSITIONS := [Vector2(315, 230), Vector2(576, 205), Vector2(835, 250)]
const RITUAL_POSITION := Vector2(576, 375)
const BOSS_POSITION := Vector2(576, 245)
const SEAL_ALTAR_POSITION := Vector2(420, 270)
const POWER_ALTAR_POSITION := Vector2(730, 270)
const BOSS_MAX_HP := 36


## Создаёт сохранённое состояние сюжетного акта, расследования и финального выбора.
static func default_state() -> Dictionary:
	return {"stage":0,"clues":[false,false,false],"boss_alive":false,"boss_defeated":false,"boss_hp":BOSS_MAX_HP,"boss_phase":1,"boss_timer":0.0,"telegraph":0.0,"choice":"","completed":false}


## Нормализует данные кампании из новых и старых сохранений.
static func normalize_state(value: Dictionary) -> Dictionary:
	var result := default_state()
	for key in value:
		if result.has(key): result[key] = value[key]
	result.stage = clampi(int(result.stage), 0, 6)
	result.clues = Array(result.clues).slice(0, 3)
	while result.clues.size() < 3: result.clues.append(false)
	result.boss_hp = clampi(int(result.boss_hp), 0, BOSS_MAX_HP)
	result.boss_phase = clampi(int(result.boss_phase), 1, 3)
	result.boss_timer = maxf(float(result.boss_timer), 0.0)
	result.telegraph = maxf(float(result.telegraph), 0.0)
	if String(result.choice) not in ["", "seal", "power"]: result.choice = ""
	return result


## Проверяет завершение предыдущего акта и право начать расследование замка.
static func available(game: Node) -> bool:
	return game.mission_states.get("story_first_dawn", game.QuestSystem.AVAILABLE) == game.QuestSystem.COMPLETED


## Возвращает ближайший объект текущей стадии расследования.
static func nearest_interaction(game: Node, distance_limit: float = 92.0) -> String:
	var state: Dictionary = game.state.world.castle_campaign
	if not available(game) or state.completed: return ""
	var candidates := {}
	if state.stage == 0 and game.current_location == "castle_hall": candidates["castle_council"] = COUNCIL_POSITION
	elif state.stage == 1 and game.current_location == "castle_upper":
		for index in CLUE_POSITIONS.size():
			if not state.clues[index]: candidates["castle_clue:%d" % index] = CLUE_POSITIONS[index]
	elif state.stage == 2 and game.current_location == "castle_dungeon": candidates["castle_ritual"] = RITUAL_POSITION
	elif state.stage == 4 and game.current_location == "castle_dungeon":
		candidates["castle_choice:seal"] = SEAL_ALTAR_POSITION
		candidates["castle_choice:power"] = POWER_ALTAR_POSITION
	var nearest := ""
	for interaction in candidates:
		var distance: float = game.player.distance_to(candidates[interaction])
		if distance < distance_limit:
			distance_limit = distance
			nearest = interaction
	return nearest


## Возвращает позицию сюжетного взаимодействия для подсветки.
static func interaction_position(interaction: String) -> Vector2:
	if interaction == "castle_council": return COUNCIL_POSITION
	if interaction.begins_with("castle_clue:"): return CLUE_POSITIONS[int(interaction.get_slice(":", 1))]
	if interaction == "castle_ritual": return RITUAL_POSITION
	if interaction == "castle_choice:seal": return SEAL_ALTAR_POSITION
	if interaction == "castle_choice:power": return POWER_ALTAR_POSITION
	return Vector2.ZERO


## Продвигает расследование через совет, улики, оборону ритуала и решение героя.
static func interact(game: Node, interaction: String) -> bool:
	var state: Dictionary = game.state.world.castle_campaign
	if interaction == "castle_council" and state.stage == 0:
		state.stage = 1
		game.message = game.LocaleSystem.text("castle_story_started")
		game.play_sfx("quest_accept"); game.notify_tutorial("castle_investigation")
		return true
	if interaction.begins_with("castle_clue:") and state.stage == 1:
		var index := int(interaction.get_slice(":", 1))
		if index < 0 or index >= state.clues.size() or state.clues[index]: return false
		state.clues[index] = true
		var found := clue_count(state)
		game.message = game.LocaleSystem.text("castle_clue_found", [found, 3])
		game.play_sfx("pickup")
		if found == 3:
			state.stage = 2
			game.notify_tutorial("quest_investigation")
		return true
	if interaction == "castle_ritual" and state.stage == 2:
		state.stage = 3; state.boss_alive = true; state.boss_hp = BOSS_MAX_HP; state.boss_phase = 1; state.boss_timer = 1.2
		game.message = game.LocaleSystem.text("castle_boss_awake")
		game.play_sfx("quest"); game.notify_tutorial("boss_phases")
		return true
	if interaction.begins_with("castle_choice:") and state.stage == 4:
		state.choice = interaction.get_slice(":", 1); state.stage = 5; state.completed = true
		game.coins += 600; game.award_xp(300); game.skill_points += 2
		game.SkillSystem.recalculate_resources(game)
		game.message = game.LocaleSystem.text("castle_choice_%s" % state.choice)
		game.play_sfx("quest_complete"); game.notify_tutorial("story_choice")
		return true
	return false


## Обновляет три боевые фазы босса, телеграф и урон по герою.
static func update(game: Node, delta: float) -> void:
	var state: Dictionary = game.state.world.castle_campaign
	if not state.boss_alive or game.current_location != "castle_dungeon": return
	state.boss_timer = maxf(float(state.boss_timer) - delta, 0.0)
	state.telegraph = maxf(float(state.telegraph) - delta, 0.0)
	if state.boss_timer > 0.0: return
	if state.telegraph <= 0.0:
		state.telegraph = 0.55
		state.boss_timer = 0.55
		return
	state.telegraph = 0.0
	var radius: float = 125.0 + float(state.boss_phase) * 24.0
	if game.player.distance_to(BOSS_POSITION) <= radius:
		game.CombatSystem.damage_player(game, 13 + state.boss_phase * 4, game.LocaleSystem.entity("shadow_regent"))
	state.boss_timer = 1.55 - state.boss_phase * 0.18


## Перенаправляет обычную атаку героя в активного Регента теней.
static func attack_boss(game: Node) -> bool:
	var state: Dictionary = game.state.world.castle_campaign
	if not state.boss_alive or game.current_location != "castle_dungeon": return false
	var attack_range := 280.0 if game.equipped_weapon == "bow" else 112.0
	if game.player.distance_to(BOSS_POSITION) > attack_range: return false
	game.PotionSystem.break_invisibility(game)
	var damage: int = game.CombatSystem.player_attack_damage(game)
	state.boss_hp = maxi(0, int(state.boss_hp) - damage)
	state.boss_phase = 3 if state.boss_hp <= 12 else (2 if state.boss_hp <= 24 else 1)
	game.AnimationSystem.begin_player_attack(game); game.play_sfx("hit")
	game.message = game.LocaleSystem.text("castle_boss_hit", [damage, state.boss_phase])
	if state.boss_hp <= 0:
		state.boss_alive = false; state.boss_defeated = true; state.stage = 4
		game.award_xp(180); game.change_inventory_count("blue_gem", 3)
		game.message = game.LocaleSystem.text("castle_boss_defeated")
		game.play_sfx("defeat")
	return true


## Возвращает количество найденных независимых улик.
static func clue_count(state: Dictionary) -> int:
	return state.clues.count(true)


## Формирует компактную текущую цель сюжетного акта для HUD.
static func objective(game: Node) -> String:
	var state: Dictionary = game.state.world.castle_campaign
	if not available(game): return ""
	match int(state.stage):
		0: return game.LocaleSystem.text("castle_objective_council")
		1: return game.LocaleSystem.text("castle_objective_clues", [clue_count(state), 3])
		2: return game.LocaleSystem.text("castle_objective_ritual")
		3: return game.LocaleSystem.text("castle_objective_boss", [state.boss_hp, BOSS_MAX_HP])
		4: return game.LocaleSystem.text("castle_objective_choice")
		_: return game.LocaleSystem.text("castle_objective_complete")
