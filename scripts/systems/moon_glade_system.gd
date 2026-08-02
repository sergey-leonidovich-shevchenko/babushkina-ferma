extends RefCounted

const FLOWER_POSITION := Vector2(764, 405)
const CRYSTAL_POSITION := Vector2(1152, 625)
const ECHO_POSITIONS := [Vector2(1280, 390), Vector2(1450, 700), Vector2(1540, 510)]
const ALTAR_POSITION := Vector2(1690, 405)
const GUARDIAN_POSITION := Vector2(1840, 610)
const CHEST_POSITION := Vector2(2026, 735)
const GUARDIAN_MAX_HP := 12
const GUARDIAN_ATTACK_RANGE := 165.0
const GUARDIAN_ATTACK_INTERVAL := 1.35


## Создаёт полный прогресс одной экспедиции с сохранением общего числа побед.
static func default_state(completed_runs: int = 0) -> Dictionary:
	return {
		"event_day": 0, "flower_collected": false, "crystal_charged": false,
		"echoes": [false, false, false], "altar_activated": false,
		"guardian_alive": false, "guardian_defeated": false,
		"guardian_hp": GUARDIAN_MAX_HP, "guardian_attack_timer": 0.0,
		"chest_opened": false, "completed_runs": maxi(completed_runs, 0),
	}


## Дополняет старое или повреждённое состояние безопасными значениями текущей версии приключения.
static func normalize_state(saved: Dictionary) -> Dictionary:
	var result := default_state(int(saved.get("completed_runs", 0)))
	for key in result:
		if saved.has(key): result[key] = saved[key]
	result.event_day = maxi(int(result.event_day), 0)
	result.guardian_hp = clampi(int(result.guardian_hp), 0, GUARDIAN_MAX_HP)
	var echoes: Array = result.get("echoes", [])
	result.echoes = [bool(echoes[0]) if echoes.size() > 0 else false, bool(echoes[1]) if echoes.size() > 1 else false, bool(echoes[2]) if echoes.size() > 2 else false]
	return result


## Возвращает календарный номер затмения, продолжающегося после полуночи.
static func event_day(day: int, minutes: float) -> int:
	return day - 1 if minutes < 2.0 * 60.0 else day


## Подготавливает новую экспедицию один раз на каждое отдельное затмение.
static func prepare(game: Node) -> void:
	var state: Dictionary = game.state.world.moon_glade
	var current_event := event_day(game.day, game.game_minutes)
	if int(state.event_day) == current_event:
		return
	game.state.world.moon_glade = default_state(int(state.completed_runs))
	game.state.world.moon_glade.event_day = current_event


## Возвращает ближайший доступный объект текущего этапа приключения.
static func nearest_interaction(game: Node, maximum_distance: float) -> String:
	if game.current_location != "moon_glade": return ""
	var state: Dictionary = game.state.world.moon_glade
	var candidates := {}
	if not state.flower_collected: candidates["moon_flower"] = FLOWER_POSITION
	elif not state.crystal_charged: candidates["moon_crystal"] = CRYSTAL_POSITION
	elif not echoes_complete(state):
		for index in ECHO_POSITIONS.size():
			if not state.echoes[index]: candidates["moon_echo:%d" % index] = ECHO_POSITIONS[index]
	elif not state.altar_activated: candidates["moon_altar"] = ALTAR_POSITION
	elif state.guardian_defeated and not state.chest_opened: candidates["moon_chest"] = CHEST_POSITION
	var nearest := ""
	for interaction in candidates:
		var distance: float = game.player.distance_to(candidates[interaction])
		if distance < maximum_distance:
			maximum_distance = distance; nearest = interaction
	return nearest


## Возвращает мировую позицию лунного объекта для подсветки и контекстной карточки.
static func interaction_position(interaction: String) -> Vector2:
	if interaction == "moon_flower": return FLOWER_POSITION
	if interaction == "moon_crystal": return CRYSTAL_POSITION
	if interaction == "moon_altar": return ALTAR_POSITION
	if interaction == "moon_chest": return CHEST_POSITION
	if interaction.begins_with("moon_echo:"):
		var index := int(interaction.get_slice(":", 1))
		return ECHO_POSITIONS[index] if index >= 0 and index < ECHO_POSITIONS.size() else Vector2.ZERO
	return Vector2.ZERO


## Выполняет доступное контекстное действие и переводит экспедицию на следующий этап.
static func interact(game: Node, interaction: String) -> bool:
	if game.current_location != "moon_glade": return false
	var state: Dictionary = game.state.world.moon_glade
	if interaction == "moon_flower" and not state.flower_collected:
		state.flower_collected = true; game.message = game.LocaleSystem.text("moon_flower_found")
		game.notify_tutorial("moon_flower"); game.play_sfx("pickup"); return true
	if interaction == "moon_crystal" and state.flower_collected and not state.crystal_charged:
		state.crystal_charged = true; game.message = game.LocaleSystem.text("moon_crystal_charged")
		game.notify_tutorial("moon_crystal"); game.play_sfx("craft"); return true
	if interaction.begins_with("moon_echo:") and state.crystal_charged:
		var index := int(interaction.get_slice(":", 1))
		if index < 0 or index >= state.echoes.size() or state.echoes[index]: return false
		state.echoes[index] = true; game.message = game.LocaleSystem.text("moon_echo_cleared", [cleared_echo_count(state), state.echoes.size()])
		game.notify_tutorial("moon_echoes"); game.play_sfx("pickup"); return true
	if interaction == "moon_altar" and echoes_complete(state) and not state.altar_activated:
		state.altar_activated = true; state.guardian_alive = true; state.guardian_hp = GUARDIAN_MAX_HP
		state.guardian_attack_timer = GUARDIAN_ATTACK_INTERVAL; game.message = game.LocaleSystem.text("moon_guardian_awake")
		game.notify_tutorial("moon_altar"); game.play_sfx("quest"); return true
	if interaction == "moon_chest" and state.guardian_defeated and not state.chest_opened:
		return open_chest(game)
	return false


## Обновляет дальние удары неподвижного Стража затмения.
static func update(game: Node, delta: float) -> void:
	if game.current_location != "moon_glade": return
	var state: Dictionary = game.state.world.moon_glade
	if not state.guardian_alive or game.invisibility_timer > 0.0: return
	state.guardian_attack_timer = maxf(float(state.guardian_attack_timer) - delta, 0.0)
	if game.player.distance_to(GUARDIAN_POSITION) <= GUARDIAN_ATTACK_RANGE and state.guardian_attack_timer <= 0.0:
		state.guardian_attack_timer = GUARDIAN_ATTACK_INTERVAL
		game.CombatSystem.damage_player(game, 22, game.LocaleSystem.entity("eclipse_guardian"))


## Наносит Стражу урон выбранным оружием и открывает сундук после победы.
static func attack_guardian(game: Node) -> bool:
	if game.current_location != "moon_glade": return false
	var state: Dictionary = game.state.world.moon_glade
	if not state.guardian_alive: return false
	var attack_range := 280.0 if game.equipped_weapon == "bow" else 105.0
	if game.player.distance_to(GUARDIAN_POSITION) > attack_range: return false
	game.PotionSystem.break_invisibility(game)
	var damage: int = game.CombatSystem.player_attack_damage(game)
	state.guardian_hp = maxi(0, int(state.guardian_hp) - damage)
	game.AnimationSystem.begin_player_attack(game); game.play_sfx("attack")
	if state.guardian_hp <= 0:
		state.guardian_alive = false; state.guardian_defeated = true
		game.award_xp(70, game.LocaleSystem.entity("eclipse_guardian")); game.SkillSystem.award_profession_xp(game, "combat", 35)
		game.message = game.LocaleSystem.text("moon_guardian_defeated"); game.play_sfx("defeat"); game.notify_tutorial("moon_guardian")
	else:
		game.message = game.LocaleSystem.text("moon_guardian_hit", [damage, state.guardian_hp, GUARDIAN_MAX_HP]); game.play_sfx("hit")
	return true


## Выдаёт гарантированную награду и уникальный талисман за первую завершённую экспедицию.
static func open_chest(game: Node) -> bool:
	var state: Dictionary = game.state.world.moon_glade
	if state.chest_opened or not state.guardian_defeated: return false
	state.chest_opened = true; state.completed_runs += 1
	game.coins += 120; game.change_inventory_count("blue_gem", 2); game.change_inventory_count("healing_potion", 1)
	if state.completed_runs == 1: game.change_inventory_count("eclipse_core", 1)
	game.award_xp(60, game.LocaleSystem.text("moon_treasure_reason")); game.message = game.LocaleSystem.text("moon_treasure_opened")
	game.play_sfx("level_up"); game.notify_tutorial("moon_treasure")
	return true


## Возвращает локализованную текущую цель для компактного списка заданий.
static func objective(game: Node) -> String:
	var state: Dictionary = game.state.world.moon_glade
	if not state.flower_collected: return game.LocaleSystem.text("moon_objective_flower")
	if not state.crystal_charged: return game.LocaleSystem.text("moon_objective_crystal")
	if not echoes_complete(state): return game.LocaleSystem.text("moon_objective_echoes", [cleared_echo_count(state), state.echoes.size()])
	if not state.altar_activated: return game.LocaleSystem.text("moon_objective_altar")
	if state.guardian_alive: return game.LocaleSystem.text("moon_objective_guardian", [state.guardian_hp, GUARDIAN_MAX_HP])
	if not state.chest_opened: return game.LocaleSystem.text("moon_objective_chest")
	return game.LocaleSystem.text("moon_objective_return")


## Проверяет завершение всех трёх встреч с лунными эхами.
static func echoes_complete(state: Dictionary) -> bool:
	return cleared_echo_count(state) == state.echoes.size()


## Подсчитывает успокоенные эха без изменения состояния экспедиции.
static func cleared_echo_count(state: Dictionary) -> int:
	var count := 0
	for cleared in state.echoes:
		if cleared: count += 1
	return count


## Проверяет дополнительную коллизию активного Стража.
static func blocks_position(game: Node, position: Vector2, radius: float) -> bool:
	return game.current_location == "moon_glade" and game.state.world.moon_glade.guardian_alive and position.distance_to(GUARDIAN_POSITION) < radius + 34.0
