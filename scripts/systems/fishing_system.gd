extends RefCounted

const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")

const PHASE_IDLE := "idle"
const PHASE_CHARGING := "charging"
const PHASE_WAITING := "waiting"
const PHASE_BITE := "bite"
const PHASE_MINIGAME := "minigame"
const PHASE_RESULT := "result"
const HOOK_WINDOW := 1.25
const RESULT_TIME := 2.4
const TREASURE_CHANCE := 0.15
const TREASURE_LOOT := [
	{"kind":"wood", "count":2}, {"kind":"stone", "count":3}, {"kind":"rare_seeds", "count":1},
	{"kind":"metal", "count":1}, {"kind":"crystal", "count":1},
]
const FISH_CATALOG := [
	{"id":"river_perch", "name_key":"fish_river_perch", "behavior":"mixed", "difficulty":28.0, "min_size":18, "max_size":36},
	{"id":"silver_bream", "name_key":"fish_silver_bream", "behavior":"smooth", "difficulty":22.0, "min_size":24, "max_size":48},
	{"id":"deep_pike", "name_key":"fish_deep_pike", "behavior":"dart", "difficulty":58.0, "min_size":38, "max_size":92, "requires":"fish_deep_water", "advanced_rod":true},
	{"id":"stone_loach", "name_key":"fish_stone_loach", "behavior":"sinker", "difficulty":42.0, "min_size":16, "max_size":41, "requires":"fish_fine_rod"},
	{"id":"sunny_ide", "name_key":"fish_sunny_ide", "behavior":"floater", "difficulty":48.0, "min_size":27, "max_size":61, "requires":"fish_big_game", "advanced_rod":true},
]


## Готовит стабильную витрину мини-игры для визуальной проверки и снимков интерфейса.
static func configure_preview(game: Node) -> void:
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"; game.player = game.pond_position + Vector2(120, 0); game.tutorial_visible = false
	var state = game.state.fishing
	state.phase = PHASE_MINIGAME; state.total_caught = 2; state.elapsed = 2.0; state.cast_power = 0.86; state.bar_y = 0.54; state.bar_size = 0.31
	state.fish_id = "deep_pike"; state.fish_name = game.LocaleSystem.text("fish_deep_pike"); state.fish_behavior = "dart"; state.fish_difficulty = 58.0; state.fish_y = 0.48; state.fish_target = 0.48; state.fish_target_timer = 99.0
	state.catch_progress = 0.64; state.treasure_visible = true; state.treasure_appears_at = 1.0; state.treasure_y = 0.23; state.treasure_progress = 0.42


## Проверяет, находится ли герой достаточно близко к пригодному для заброса участку воды.
static func is_near_water(game: Node) -> bool:
	if game.current_location != "overworld":
		return false
	if game.player.distance_to(game.pond_position) < 235.0:
		return true
	return absf(game.player.y - VillageLayoutSystem.river_center_y(game.player.x)) < 105.0


## Обрабатывает нажатие удочки в зависимости от текущей стадии заброса или мини-игры.
static func use_rod(game: Node) -> bool:
	var state = game.state.fishing
	if state.phase == PHASE_MINIGAME:
		return true
	if state.phase == PHASE_BITE:
		_start_minigame(game)
		return true
	if state.phase in [PHASE_CHARGING, PHASE_WAITING, PHASE_RESULT]:
		if state.phase == PHASE_WAITING: game.message = game.LocaleSystem.text("fish_wait")
		return false
	var held_kind: String = String(game.hotbar_slots[game.selected_hotbar]) if game.selected_hotbar >= 0 and game.selected_hotbar < game.hotbar_slots.size() else ""
	if not game.has_fishing_rod and game.inventory_item_count("advanced_fishing_rod") <= 0: game.message = game.LocaleSystem.text("fish_no_rod"); return false
	if held_kind == "advanced_fishing_rod" and not game.TalentSystem.has(game, "fish_fine_rod"):
		game.message = "Сначала изучи талант «Точная снасть»"
		return false
	if not game.AdventurePolishSystem.can_use(game, "fishing_rod"): return false
	if not is_near_water(game): game.message = game.LocaleSystem.text("fish_need_water"); return false
	state.reset_cast()
	state.phase = PHASE_CHARGING
	game.message = game.LocaleSystem.text("fish_charge")
	game.play_sfx("fish_cast")
	game.AdventurePolishSystem.consume_durability(game, "fishing_rod")
	game.notify_tutorial("fish_cast")
	return true


## Продвигает активную стадию рыбалки с физикой, не зависящей от частоты кадров.
static func update(game: Node, delta: float) -> void:
	var state = game.state.fishing
	match state.phase:
		PHASE_CHARGING: _update_cast(game, delta)
		PHASE_WAITING: _update_wait(game, delta)
		PHASE_BITE: _update_bite(game, delta)
		PHASE_MINIGAME: _update_minigame(game, delta)
		PHASE_RESULT:
			state.timer -= delta
			if state.timer <= 0.0: state.reset_cast()


## Заполняет качающуюся шкалу силы и выпускает леску сразу после отпускания действия.
static func _update_cast(game: Node, delta: float) -> void:
	var state = game.state.fishing
	if not game.action_held:
		state.phase = PHASE_WAITING
		state.timer = game.SkillSystem.fishing_wait(game) * lerpf(1.12, 0.82, state.cast_power)
		game.message = game.LocaleSystem.text("fish_cast", [roundi(state.cast_power * 100.0)])
		return
	state.cast_power += delta * 0.82 * state.cast_direction
	if state.cast_power >= 1.0: state.cast_power = 1.0; state.cast_direction = -1.0
	elif state.cast_power <= 0.0: state.cast_power = 0.0; state.cast_direction = 1.0


## Отсчитывает задержку поклёвки и включает короткое окно для своевременной подсечки.
static func _update_wait(game: Node, delta: float) -> void:
	var state = game.state.fishing
	state.timer -= delta
	if state.timer > 0.0: return
	state.phase = PHASE_BITE
	state.timer = HOOK_WINDOW
	game.message = game.LocaleSystem.text("fish_bite")
	game.play_sfx("fish_bite")
	game.notify_tutorial("fish_hook")


## Завершает пропущенную поклёвку, когда игрок не успел подсечь рыбу.
static func _update_bite(game: Node, delta: float) -> void:
	var state = game.state.fishing
	state.timer -= delta
	if state.timer > 0.0: return
	state.reset_cast()
	game.message = game.LocaleSystem.text("fish_missed")


## Выбирает рыбу и подготавливает вертикальную мини-игру с обучающим первым уловом.
static func _start_minigame(game: Node) -> void:
	var state = game.state.fishing
	var available: Array[Dictionary] = []
	for candidate in FISH_CATALOG:
		if game.TalentSystem.can_catch_fish(game, candidate): available.append(candidate)
	var fish: Dictionary = available[state.total_caught % available.size()]
	state.phase = PHASE_MINIGAME
	state.elapsed = 0.0
	state.bar_y = 0.74
	state.bar_velocity = 0.0
	state.bar_size = clampf(0.24 + game.SkillSystem.skill(game, "fishing") * 0.014 + game.TalentSystem.fishing_bar_bonus(game), 0.24, 0.48)
	state.fish_id = fish.id; state.fish_name = game.LocaleSystem.text(fish.name_key); state.fish_behavior = fish.behavior; state.fish_difficulty = fish.difficulty
	state.fish_y = 0.48; state.fish_velocity = 0.0; state.fish_target = 0.48; state.fish_target_timer = 0.15
	state.catch_progress = 0.22; state.perfect = true
	state.treasure_visible = _treasure_roll(state.total_caught, state.cast_power)
	state.treasure_appears_at = 1.0 + fposmod(float(state.total_caught) * 0.613, 2.0)
	state.treasure_y = 0.18 + fposmod(float(state.total_caught) * 0.371, 0.64)
	state.treasure_progress = 0.0; state.treasure_caught = false
	game.message = game.LocaleSystem.text("fish_control")
	game.notify_tutorial("fish_control")


## Обновляет инерционную зелёную зону, характер движения рыбы и обе шкалы прогресса.
static func _update_minigame(game: Node, delta: float) -> void:
	var state = game.state.fishing
	state.elapsed += delta
	_update_catch_bar(state, game.action_held, delta)
	_update_fish(state, delta)
	var fish_inside: bool = absf(state.fish_y - state.bar_y) <= state.bar_size * 0.5
	if fish_inside:
		state.catch_progress += delta * (0.34 - state.fish_difficulty * 0.0014)
	else:
		state.perfect = false
		if state.total_caught > 0: state.catch_progress -= delta * (0.20 + state.fish_difficulty * 0.0012)
	_update_treasure(state, delta)
	state.catch_progress = clampf(state.catch_progress, 0.0, 1.0)
	if state.catch_progress >= 1.0: _complete_catch(game)
	elif state.catch_progress <= 0.0: _lose_fish(game)


## Применяет ускорение удержания, гравитацию отпускания и смягчённый отскок от границ.
static func _update_catch_bar(state: RefCounted, held: bool, delta: float) -> void:
	state.bar_velocity += (-2.15 if held else 1.72) * delta
	state.bar_velocity = clampf(state.bar_velocity, -1.28, 1.28)
	state.bar_y += state.bar_velocity * delta
	var half: float = state.bar_size * 0.5
	if state.bar_y < half: state.bar_y = half; state.bar_velocity = absf(state.bar_velocity) * 0.28
	elif state.bar_y > 1.0 - half: state.bar_y = 1.0 - half; state.bar_velocity = -absf(state.bar_velocity) * 0.36


## Двигает рыбу к меняющимся целям согласно одному из пяти узнаваемых характеров поведения.
static func _update_fish(state: RefCounted, delta: float) -> void:
	state.fish_target_timer -= delta
	if state.fish_target_timer <= 0.0:
		var seed := sin(state.elapsed * 5.17 + state.total_caught * 2.31) * 43758.5453
		var random_unit := fposmod(seed, 1.0)
		var amplitude: float = clampf(0.18 + state.fish_difficulty / 115.0, 0.18, 0.82)
		state.fish_target = clampf(0.5 + (random_unit - 0.5) * amplitude, 0.04, 0.96)
		state.fish_target_timer = _target_interval(state.fish_behavior, state.fish_difficulty)
	var acceleration: float = (state.fish_target - state.fish_y) * (2.6 + state.fish_difficulty * 0.055)
	if state.fish_behavior == "sinker": acceleration += 0.42
	elif state.fish_behavior == "floater": acceleration -= 0.42
	elif state.fish_behavior == "dart": acceleration *= 1.75
	elif state.fish_behavior == "smooth": acceleration *= 0.62
	state.fish_velocity = lerpf(state.fish_velocity, acceleration, clampf(delta * 4.2, 0.0, 1.0))
	state.fish_y = clampf(state.fish_y + state.fish_velocity * delta, 0.02, 0.98)


## Возвращает интервал смены цели рыбы для выбранного характера и сложности.
static func _target_interval(behavior: String, difficulty: float) -> float:
	var base := clampf(0.82 - difficulty * 0.006, 0.24, 0.72)
	if behavior == "dart": return base * 0.48
	if behavior == "smooth": return base * 1.55
	return base


## Накапливает отдельную шкалу сундука только при перекрытии его управляемой зоной.
static func _update_treasure(state: RefCounted, delta: float) -> void:
	if not state.treasure_visible or state.treasure_caught or state.elapsed < state.treasure_appears_at: return
	if absf(state.treasure_y - state.bar_y) <= state.bar_size * 0.5:
		state.treasure_progress = minf(1.0, state.treasure_progress + delta * 0.52)
		if state.treasure_progress >= 1.0: state.treasure_caught = true


## Завершает удачный улов, рассчитывает размер, качество, опыт, рекорд и сокровище.
static func _complete_catch(game: Node) -> void:
	var state = game.state.fishing
	var catch_index: int = state.total_caught
	var fish := fish_data(state.fish_id)
	var size_factor := clampf(state.cast_power * 0.7 + game.SkillSystem.skill(game, "fishing") * 0.03 + game.TalentSystem.fishing_size_bonus(game) - (0.0 if state.perfect else 0.08), 0.0, 1.0)
	state.fish_size = roundi(lerpf(float(fish.min_size), float(fish.max_size), size_factor))
	state.quality = _quality_for(state.cast_power, state.perfect)
	var previous_best := int(state.best_sizes.get(state.fish_id, 0))
	state.best_sizes[state.fish_id] = maxi(previous_best, state.fish_size)
	var caught: int = game.SkillSystem.fishing_count(game)
	game.fish += caught
	state.total_caught += caught
	var experience := roundi((5.0 + state.fish_difficulty * 0.1) * (2.4 if state.perfect else 1.0))
	game.award_xp(experience)
	game.SkillSystem.award_profession_xp(game, "fishing", experience)
	if state.treasure_caught:
		var loot: Dictionary = TREASURE_LOOT[catch_index % TREASURE_LOOT.size()]
		game.change_inventory_count(loot.kind, loot.count); state.treasure_loot = loot.kind
	state.result_text = game.LocaleSystem.text("fish_result", [state.fish_name, state.fish_size, game.LocaleSystem.text("quality_" + state.quality), " ★" if state.perfect else "", " + 🎁" if state.treasure_caught else ""])
	state.phase = PHASE_RESULT; state.timer = RESULT_TIME
	game.message = state.result_text
	game.play_sfx("fish_catch")
	game.notify_tutorial("fish")
	if bool(fish.get("advanced_rod", false)): game.notify_tutorial("advanced_fishing")


## Возвращает данные уже выбранной рыбы, не меняя результат при завершении мини-игры.
static func fish_data(fish_id: String) -> Dictionary:
	for fish in FISH_CATALOG:
		if String(fish.id) == fish_id: return fish
	return FISH_CATALOG[0]


## Устанавливает новую ловушку у воды либо собирает созревшую существующую ловушку.
static func use_crab_trap(game: Node) -> bool:
	if not game.TalentSystem.has(game, "fish_crab_traps"):
		game.message = "Изучи «Крабовые ловушки» в ветке рыбалки"
		return false
	for trap in game.state.fishing.traps:
		if String(trap.location) == game.current_location and game.player.distance_to(Vector2(trap.position)) < 90.0:
			if game.day < int(trap.ready_day):
				game.message = "Ловушка будет готова завтра"
				return false
			game.change_inventory_count("crab", 1)
			trap.ready_day = game.day + 1
			game.award_xp(8, "Крабовая ловушка")
			game.SkillSystem.award_profession_xp(game, "fishing", 6)
			game.message = "Пойман речной краб • +8 XP"
			game.notify_tutorial("crab_trap_collect")
			return true
	if not is_near_water(game):
		game.message = game.LocaleSystem.text("fish_need_water")
		return false
	if game.inventory_item_count("crab_trap") <= 0:
		game.message = "Нужна крабовая ловушка"
		return false
	game.change_inventory_count("crab_trap", -1)
	game.state.fishing.traps.append({"location":game.current_location, "position":game.player + game.facing.normalized() * 54.0, "ready_day":game.day + 1})
	game.message = "Ловушка установлена • проверь её завтра"
	game.notify_tutorial("crab_trap_place")
	return true


## Завершает сорвавшийся улов и возвращает управление миру после короткого результата.
static func _lose_fish(game: Node) -> void:
	var state = game.state.fishing
	state.phase = PHASE_RESULT; state.timer = RESULT_TIME; state.result_text = game.LocaleSystem.text("fish_escaped")
	game.message = state.result_text


## Рассчитывает качество по дальности заброса и повышает его за идеальную мини-игру.
static func _quality_for(cast_power: float, perfect: bool) -> String:
	var quality := "normal"
	if cast_power >= 0.8: quality = "gold"
	elif cast_power >= 0.45: quality = "silver"
	if perfect and quality == "silver": quality = "gold"
	elif perfect and quality == "gold": quality = "iridium"
	return quality


## Возвращает воспроизводимый пятнадцатипроцентный шанс сундука без нестабильности тестов.
static func _treasure_roll(catch_index: int, cast_power: float) -> bool:
	var value := fposmod(sin((catch_index + 1) * 12.9898 + cast_power * 78.233) * 43758.5453, 1.0)
	return value < TREASURE_CHANCE
