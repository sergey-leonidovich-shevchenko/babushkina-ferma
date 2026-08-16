class_name UiFeedbackSystem
extends RefCounted

const TRANSITION_DURATION := 0.24
const PRESS_DURATION := 0.13
const FOCUS_DURATION := 0.20
const PARTICLE_DURATION := 0.44


## Возвращает стабильный идентификатор самого верхнего интерфейсного слоя для обнаружения переходов.
static func active_layer(game: Node) -> String:
	if game.language_screen: return "language"
	if game.title_screen: return "settings" if game.menu_state.settings_open else "title"
	if game.menu_state.defeat_open: return "defeat"
	if not game.menu_state.confirmation.is_empty(): return "confirmation"
	if game.menu_state.settings_open: return "settings"
	if game.menu_state.pause_open: return "pause"
	if game.world_map_open: return "world_guide:%d" % game.world_guide_page
	if game.inventory_open: return "inventory"
	if game.shop_open: return "shop"
	if game.crafting_open: return "crafting"
	if game.storage_open: return "storage"
	if game.forge_open: return "forge"
	if game.quest_log_open: return "quest_log"
	if game.skill_menu_open: return "talents"
	if game.AdventurePolishSystem.has_modal(game): return "dialogue"
	return "world"


## Обновляет переходы, нажатия и декоративные частицы независимо от паузы симуляции мира.
static func update(game: Node, delta: float) -> void:
	var layer := active_layer(game)
	if game.ui_last_layer.is_empty():
		game.ui_last_layer = layer
	elif layer != game.ui_last_layer:
		var returned_to_world := layer == "world"
		game.ui_last_layer = layer
		game.ui_transition_timer = 0.0 if game.settings_state.reduced_motion else TRANSITION_DURATION
		if game.ui_sound_cooldown <= 0.0: game.play_sfx("ui_back" if returned_to_world else "ui_open")
	game.ui_transition_timer = maxf(0.0, game.ui_transition_timer - delta)
	game.ui_pressed_timer = maxf(0.0, game.ui_pressed_timer - delta)
	game.ui_focus_timer = maxf(0.0, game.ui_focus_timer - delta)
	game.ui_sound_cooldown = maxf(0.0, game.ui_sound_cooldown - delta)
	for particle in game.ui_particles:
		particle.age = float(particle.age) + delta
	game.ui_particles = game.ui_particles.filter(func(particle): return float(particle.age) < PARTICLE_DURATION)


## Регистрирует смену фокуса, не повторяя звук при удержании той же строки.
static func focus(game: Node, focus_id: String) -> bool:
	if focus_id == game.ui_focus_id: return false
	game.ui_focus_id = focus_id
	game.ui_focus_timer = 0.0 if game.settings_state.reduced_motion else FOCUS_DURATION
	game.play_sfx("ui_focus")
	game.ui_sound_cooldown = 0.035
	return true


## Запускает короткое утопление кнопки, искры подтверждения и мягкий звук нажатия.
static func press(game: Node, rect: Rect2) -> void:
	game.ui_pressed_rect = rect
	game.ui_pressed_timer = 0.0 if game.settings_state.reduced_motion else PRESS_DURATION
	if not game.settings_state.reduced_motion:
		spawn_particles(game, rect.get_center())
	game.play_sfx("ui_press")
	game.ui_sound_cooldown = 0.09


## Отмечает действие возврата отдельным спокойным звуком без декоративного всплеска.
static func back(game: Node) -> void:
	game.play_sfx("ui_back")
	game.ui_sound_cooldown = 0.09


## Создаёт воспроизводимое кольцо золотых искр вокруг точки подтверждения.
static func spawn_particles(game: Node, center: Vector2) -> void:
	for index in 8:
		var angle := TAU * float(index) / 8.0
		game.ui_particles.append({"origin":center, "velocity":Vector2.from_angle(angle) * (22.0 + index % 3 * 6.0), "age":0.0})


## Возвращает слегка утопленную область только для действительно нажатой кнопки.
static func animated_button_rect(game: Node, rect: Rect2, reduced_motion: bool) -> Rect2:
	if reduced_motion or game.ui_pressed_timer <= 0.0 or not approximately_same_rect(game.ui_pressed_rect, rect): return rect
	var progress: float = 1.0 - float(game.ui_pressed_timer) / PRESS_DURATION
	var inset: float = sin(progress * PI) * 1.5
	return Rect2(rect.position + Vector2(inset, inset + 1.0), rect.size - Vector2.ONE * inset * 2.0)


## Сравнивает экранные области с допуском, достаточным для независимых копий Rect2.
static func approximately_same_rect(left: Rect2, right: Rect2) -> bool:
	return left.position.distance_to(right.position) < 0.5 and left.size.distance_to(right.size) < 0.5


## Возвращает затухание верхнего переходного слоя от нуля до единицы.
static func transition_ratio(game: Node) -> float:
	if game.settings_state.reduced_motion or game.ui_transition_timer <= 0.0: return 0.0
	return clampf(game.ui_transition_timer / TRANSITION_DURATION, 0.0, 1.0)
