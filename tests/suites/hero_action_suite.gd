extends "res://tests/suites/suite_base.gd"

const HeroAction := preload("res://scripts/systems/hero_action_system.gd")


## Запускает сценарии ракурса, непрерывности замаха и отделения визуальной позы от игрового результата.
func run() -> void:
	test_cardinal_views_keep_diagonal_movement_independent()
	test_muted_hoe_starts_pose_through_the_real_tool_action()
	test_held_tilling_does_not_restart_the_same_swing()
	test_turning_preserves_the_action_direction_and_target()
	test_location_change_discards_pose_and_accepts_a_new_action()
	test_pose_updates_do_not_move_or_reward_the_player()
	test_progress_and_frame_boundaries_are_stable()
	test_unsupported_and_failed_actions_do_not_create_poses()
	test_every_supported_tool_has_a_finite_pose()


## Сценарий: художественный ракурс выбирается для сторон, диагоналей и нулевого направления.
## Исходное состояние: система получает точные и нормализованные векторы, включая неравные компоненты диагонали.
## Ожидаемый результат: остаются четыре ракурса; при равенстве компонент приоритет горизонтальный, нулевой вектор смотрит вниз.
func test_cardinal_views_keep_diagonal_movement_independent() -> void:
	var cases := [
		[Vector2.ZERO, Vector2.DOWN], [Vector2.RIGHT, Vector2.RIGHT], [Vector2.LEFT, Vector2.LEFT],
		[Vector2.UP, Vector2.UP], [Vector2.DOWN, Vector2.DOWN],
		[Vector2(1, 1), Vector2.RIGHT], [Vector2(1, -1), Vector2.RIGHT],
		[Vector2(-1, 1), Vector2.LEFT], [Vector2(-1, -1), Vector2.LEFT],
		[Vector2(0.2, -1), Vector2.UP], [Vector2(-0.2, 1), Vector2.DOWN],
	]
	for pair in cases:
		var direction: Vector2 = pair[0]
		expect(HeroAction.cardinal(direction) == pair[1], "cardinal art view: " + str(direction))
		if not direction.is_zero_approx():
			expect(HeroAction.cardinal(direction.normalized()) == pair[1], "normalizing movement does not alter the artistic view: " + str(direction))


## Сценарий: игрок выключает звук и вскапывает настоящую клетку через use_selected_tool.
## Исходное состояние: перед героем первая пустая домашняя грядка, выбрана мотыга, есть энергия, аудио отключено.
## Ожидаемый результат: земля обрабатывается и начинается поза мотыги, хотя счётчик звуков не меняется.
func test_muted_hoe_starts_pose_through_the_real_tool_action() -> void:
	var game := make_game()
	prepare_home_target(game, Vector2i.ZERO)
	game.AudioSystem.set_enabled(game, false)
	var sounds_before: int = game.audio_sfx_count
	var target: Dictionary = game.WorldFarmingSystem.target(game)
	game.use_selected_tool()
	var pose := HeroAction.pose(game)
	expect(game.WorldFarmingSystem.read_target(game, target).tilled, "real muted hoe action tills the targeted plot")
	expect(not pose.is_empty() and String(pose.get("action", "")) == "hoe", "muting sound cannot suppress the digging animation")
	expect(Vector2(pose.get("target", Vector2.INF)) == Rect2(target.rect).get_center(), "hoe pose captures the center of the plot actually modified")
	expect(game.audio_sfx_count == sounds_before, "the visual action is not faked by emitting a muted sound event")
	expect(is_equal_approx(HeroAction.progress(game), 0.0), "a successful tool use begins at the preparation frame")
	game.free()


## Сценарий: при удержании действия герой успевает обработать две соседние клетки в течение одного замаха.
## Исходное состояние: action_held включён, две домашние клетки пустые, первая анимация уже прошла 0,17 секунды.
## Ожидаемый результат: обе клетки обработаны, но повтор не возвращает визуальный таймер назад и не подменяет цель активного замаха.
func test_held_tilling_does_not_restart_the_same_swing() -> void:
	var game := make_game()
	prepare_home_target(game, Vector2i.ZERO)
	game.action_held = true
	game.use_selected_tool()
	HeroAction.update(game, 0.17)
	var before := HeroAction.pose(game).duplicate(true)
	prepare_home_target(game, Vector2i(1, 0))
	game.use_selected_tool()
	var current := HeroAction.pose(game)
	expect(game.plots[Vector2i.ZERO].tilled and game.plots[Vector2i(1, 0)].tilled, "held-style consecutive uses still perform both real farming actions")
	expect(is_equal_approx(float(current.get("remaining", -1)), float(before.get("remaining", -2))), "repeated hoe use cannot lock the sprite in its first frame")
	expect(current.get("target") == before.get("target") and current.get("direction") == before.get("direction"), "one ongoing swing keeps a consistent target and facing")
	HeroAction.update(game, HeroAction.DURATION)
	HeroAction.begin(game, "hoe", game.player + Vector2(36, 0))
	expect(is_equal_approx(HeroAction.progress(game), 0.0), "a completed swing can begin again while the button remains held")
	game.free()


## Сценарий: герой поворачивается и смещается после начала работы инструментом.
## Исходное состояние: замах направлен вправо-вверх, зафиксирован центр цели; затем facing становится строго влево.
## Ожидаемый результат: текущая поза остаётся правой и привязанной к исходной цели, следующий замах принимает новый ракурс.
func test_turning_preserves_the_action_direction_and_target() -> void:
	var game := make_game()
	game.facing = Vector2(1, -1).normalized()
	var target: Vector2 = game.player + Vector2(36, -24)
	HeroAction.begin(game, "hoe", target)
	game.facing = Vector2.LEFT
	game.player += Vector2(12, 0)
	HeroAction.update(game, 0.12)
	var pose := HeroAction.pose(game)
	expect(pose.get("direction") == Vector2.RIGHT and pose.get("target") == target, "turning during contact does not mirror the active tool across the body")
	expect(pose.get("location") == game.current_location, "the action remembers the location it belongs to")
	HeroAction.update(game, HeroAction.DURATION)
	HeroAction.begin(game, "hoe", game.player - Vector2(36, 0))
	expect(HeroAction.pose(game).get("direction") == Vector2.LEFT, "the next complete swing uses the new facing")
	game.free()


## Сценарий: герой меняет локацию посреди действия и сразу использует тот же инструмент.
## Исходное состояние: старая поза ещё активна; переход произошёл до очередного update анимационной системы.
## Ожидаемый результат: старая поза невидима, новый замах не блокируется её таймером, последующий переход очищает метаданные.
func test_location_change_discards_pose_and_accepts_a_new_action() -> void:
	var game := make_game()
	HeroAction.begin(game, "hoe", Vector2(400, 500))
	game.current_location = "forest"
	expect(HeroAction.pose(game).is_empty() and HeroAction.progress(game) == -1.0, "an action never renders on another location before update")
	HeroAction.begin(game, "hoe", Vector2(620, 480))
	var fresh := HeroAction.pose(game)
	expect(not fresh.is_empty() and fresh.get("location") == "forest" and fresh.get("target") == Vector2(620, 480), "a stale same-tool pose cannot swallow the first action after travel")
	game.current_location = "rocky"
	HeroAction.update(game, 0.0)
	expect(not game.has_meta(HeroAction.META), "location changes remove the old action snapshot even with zero elapsed time")
	game.free()


## Сценарий: визуальный замах проходит все фазы без вызова игрового действия.
## Исходное состояние: позиции, здоровье, энергия, общий опыт, предметы и земля зафиксированы до begin.
## Ожидаемый результат: begin/pose/progress/frame/update изменяют только визуальные метаданные, не двигают героя и не выдают награды.
func test_pose_updates_do_not_move_or_reward_the_player() -> void:
	var game := make_game()
	var position: Vector2 = game.player
	var facing: Vector2 = game.facing
	var initial := {"xp":game.state.player.xp, "energy":game.energy, "hp":game.state.player.hp, "seeds":game.seeds, "carrots":game.carrots}
	var plots: Dictionary = game.plots.duplicate(true)
	var sounds: int = game.audio_sfx_count
	HeroAction.begin(game, "plant", position + Vector2(30, 0))
	for index in 40:
		HeroAction.frame(HeroAction.progress(game))
		HeroAction.pose(game)
		HeroAction.update(game, 1.0 / 60.0)
	expect(game.player == position and game.facing == facing, "animation poses cannot push the player into collision textures")
	expect(game.state.player.xp == initial.xp and game.energy == initial.energy and game.state.player.hp == initial.hp, "animation-only progression cannot add XP or spend player resources")
	expect(game.seeds == initial.seeds and game.carrots == initial.carrots and game.plots == plots, "drawing a planting pose cannot duplicate farming results")
	expect(game.audio_sfx_count == sounds and HeroAction.pose(game).is_empty(), "visual animation finishes silently without re-triggering feedback events")
	game.free()


## Сценарий: таймер получает нулевое, отрицательное и слишком большое приращение, кадры выбираются на границах фаз.
## Исходное состояние: новая поза мотыги длится 0,48 секунды и имеет четыре кадра.
## Ожидаемый результат: прогресс монотонный, отрицательное время не перематывает замах, последняя поза не зависает после завершения.
func test_progress_and_frame_boundaries_are_stable() -> void:
	var game := make_game()
	expect(HeroAction.progress(game) == -1.0, "idle has an explicit no-action progress sentinel")
	HeroAction.begin(game, "hoe", game.player)
	HeroAction.update(game, 0.0)
	HeroAction.update(game, -1.0)
	expect(is_equal_approx(HeroAction.progress(game), 0.0), "zero and negative delta cannot alter a fresh swing")
	HeroAction.update(game, HeroAction.DURATION * 0.5)
	expect(is_equal_approx(HeroAction.progress(game), 0.5), "half of the fixed duration produces half progress")
	for pair in [[0.0, 0], [0.179, 0], [0.18, 1], [0.429, 1], [0.43, 2], [0.719, 2], [0.72, 3], [1.0, 3]]:
		expect(HeroAction.frame(pair[0]) == pair[1], "stable action frame boundary: " + str(pair[0]))
	HeroAction.update(game, 4.0)
	expect(HeroAction.pose(game).is_empty() and HeroAction.progress(game) == -1.0, "long frame delta clears the completed pose instead of holding its final image")
	game.free()


## Сценарий: неизвестное действие, недостаток энергии и работа внутри здания не должны запускать успешный замах.
## Исходное состояние: визуальной позы нет, затем проверяются неверный action, пустая энергия и запрещённая земля.
## Ожидаемый результат: все неуспешные действия оставляют героя без ложной анимации работы.
func test_unsupported_and_failed_actions_do_not_create_poses() -> void:
	var game := make_game()
	HeroAction.begin(game, "not_a_tool", game.player)
	expect(HeroAction.pose(game).is_empty(), "unknown tool id cannot create an action pose")
	prepare_home_target(game, Vector2i.ZERO)
	game.energy = 0
	game.use_selected_tool()
	expect(HeroAction.pose(game).is_empty() and not game.plots[Vector2i.ZERO].tilled, "a failed exhausted hoe attempt neither animates success nor tills soil")
	game.energy = 12
	game.current_location = "cottage_interior"
	game.player = Vector2(540, 400)
	game.use_selected_tool()
	expect(HeroAction.pose(game).is_empty(), "forbidden interior ground does not trigger a successful digging pose")
	game.free()


## Сценарий: каждый зарегистрированный инструмент последовательно начинает и завершает своё действие.
## Исходное состояние: все действия используют один таймер, а направление героя последовательно меняется.
## Ожидаемый результат: действия получают нужное имя, фиксированный срок и исчезают после его истечения.
func test_every_supported_tool_has_a_finite_pose() -> void:
	var game := make_game()
	for action in HeroAction.TOOLS:
		HeroAction.begin(game, action, game.player)
		var current := HeroAction.pose(game)
		expect(current.get("action") == action and is_equal_approx(float(current.get("remaining", -1)), HeroAction.DURATION), "supported finite action: " + String(action))
		HeroAction.update(game, HeroAction.DURATION + 0.001)
		expect(not game.has_meta(HeroAction.META), "completed action releases its snapshot: " + String(action))
	game.free()


## Ставит героя перед нужной домашней клеткой и сбрасывает только её почву для изолированного сценария мотыги.
func prepare_home_target(game: Node, cell: Vector2i) -> void:
	game.current_location = "overworld"
	game.facing = Vector2.RIGHT
	var rect: Rect2 = game.FarmVisualSystem.plot_rect(Vector2(game.FARM_ORIGIN), cell)
	game.player = rect.get_center() - Vector2.RIGHT * 42.0
	game.plots[cell] = game.WorldFarmingSystem.empty_plot("overworld", cell)
	game.selected_tool = game.Tool.HOE
	game.energy = 12
