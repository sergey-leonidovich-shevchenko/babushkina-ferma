extends "res://tests/suites/suite_base.gd"

const Assist := preload("res://scripts/systems/player_corner_assist_system.gd")
const Navigation := preload("res://scripts/systems/navigation_system.gd")


## Запускает геометрические проверки близких краёв, закрытых проходов, скорости и симметрии управления.
func run() -> void:
	test_near_corner_in_all_directions()
	test_center_and_closed_side_do_not_steer()
	test_sweep_rejects_thin_obstacles()
	test_speed_and_frame_rate()
	test_diagonal_and_zero_input_stay_manual()
	test_empty_decoration_has_no_collision()


## Сценарий: игрок держит одно направление и чуть задевает каждый из восьми подходов к углам ствола.
## Исходное состояние: основание дерева 48×48 и круг ног радиусом 18, до безопасного края менее 12px.
## Ожидаемый результат: герой проходит, все подшаги законны, а боковая поправка остаётся в пределах половины клетки.
func test_near_corner_in_all_directions() -> void:
	var walkable := _tree_walkable()
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var tangent := Vector2(-direction.y, direction.x)
		for sign_value in [-1.0, 1.0]:
			var start: Vector2 = -direction * 60.0 + tangent * 32.0 * sign_value
			var route := _simulate(start, direction * 3.5, 42, walkable)
			var end: Vector2 = route.position
			expect(end.dot(direction) > 48.0, "close tree edge can be passed with one held direction: %s / %s" % [direction, sign_value])
			expect(route.safe, "every corner-assist substep stays outside the real circular collision")
			expect(absf((end - start).dot(tangent)) <= Assist.MAX_OFFSET + 1.0, "near-edge adjustment stays within half of the 24px ground cell")


## Сценарий: игрок упирается в середину ствола, длинную стену либо угол с закрытой боковой дорожкой.
## Исходное состояние: доступный проход дальше допуска или закрыт вторым объектом; один forward endpoint не доказывает наличие пути.
## Ожидаемый результат: помощь не выбирает объезд целого объекта и не проталкивает героя между препятствиями.
func test_center_and_closed_side_do_not_steer() -> void:
	var walkable := _tree_walkable()
	var center := _simulate(Vector2(-60, 0), Vector2(3.5, 0), 90, walkable)
	expect(is_zero_approx(Vector2(center.position).y) and Vector2(center.position).x <= -42.0, "head-on approach to trunk remains blocked without sideways drift")
	var wall := func(point: Vector2) -> bool: return point.x <= -42.0
	expect(Assist.assisted_step(Vector2(-42, -32), Vector2(3.5, 0), wall) == Vector2.ZERO, "long wall has no artificial corner escape")
	var closed := func(point: Vector2) -> bool: return walkable.call(point) and point.y > -34.0
	expect(Assist.assisted_step(Vector2(-42, -32), Vector2(3.5, 0), closed) == Vector2.ZERO, "second obstacle blocks the lateral escape corridor")
	var ambiguous := func(point: Vector2) -> bool: return point.x < 0.0 or absf(point.y) >= 3.0
	expect(Assist.find_edge(Vector2(-1, 0), Vector2.RIGHT, Vector2.DOWN, ambiguous) == 0.0, "equally near exits do not choose an arbitrary automatic route")


## Сценарий: свободная конечная точка лежит за тонкой непроходимой полосой.
## Исходное состояние: отрезок пересекает двухпиксельный блокер, хотя его начало и конец доступны.
## Ожидаемый результат: swept-проверка отвергает весь путь, поэтому поправка не телепортирует героя сквозь стену.
func test_sweep_rejects_thin_obstacles() -> void:
	var walkable := func(point: Vector2) -> bool: return not (point.x >= 5.0 and point.x <= 7.0)
	expect(walkable.call(Vector2.ZERO) and walkable.call(Vector2(12, 0)), "thin-wall fixture has free endpoints")
	expect(not Assist.segment_clear(Vector2.ZERO, Vector2(12, 0), walkable), "swept path catches an obstacle between otherwise free endpoints")


## Сценарий: одинаковый секундный проход повторяется с 30, 60 и 120 физическими шагами в секунду и одним длинным кадром.
## Исходное состояние: постоянная скорость 210px/s, дерево и старт неизменны, длинный кадр делится как в Navigation.move.
## Ожидаемый результат: каждый шаг не быстрее обычной ходьбы, траектории близки и при низкой частоте нет прохода сквозь дерево.
func test_speed_and_frame_rate() -> void:
	var walkable := _tree_walkable()
	var positions: Array[Vector2] = []
	for fps in [30, 60, 120]:
		var route := _simulate(Vector2(-60, -32), Vector2.RIGHT * 210.0 / fps, fps, walkable)
		positions.append(route.position)
		expect(route.safe and route.speed_safe, "corner assistance respects collision and per-frame speed at %d fps" % fps)
	for position in positions:
		expect(position.distance_to(positions[1]) < 9.0, "30/60/120Hz corner routes differ by less than one bounded navigation substep")
	var long_frame := _simulate(Vector2(-60, -32), Vector2(210, 0), 1, walkable)
	expect(long_frame.safe and long_frame.speed_safe and Vector2(long_frame.position).x > 48, "long frame is subdivided and cannot tunnel through the trunk")


## Сценарий: игрок отпускает клавиши или сам задаёт диагональ.
## Исходное состояние: персонаж находится у того же тесного края без какой-либо инерции или фонового маршрута.
## Ожидаемый результат: помощь возвращает нулевую поправку и не подменяет явное направление игрока.
func test_diagonal_and_zero_input_stay_manual() -> void:
	for motion in [Vector2.ZERO, Vector2(3, -3), Vector2(-3, 3)]:
		expect(Assist.assisted_step(Vector2(-42, -32), motion, _tree_walkable()) == Vector2.ZERO, "zero and diagonal intent never invoke cardinal corner steering")


## Сценарий: декоративному объекту явно назначен пустой физический профиль.
## Исходное состояние: герой стоит точно в его опоре, прямоугольник имеет нулевую ширину или высоту.
## Ожидаемый результат: безобидный декор не создаёт невидимый круг радиусом героя вокруг своей точки.
func test_empty_decoration_has_no_collision() -> void:
	for size in [Vector2.ZERO, Vector2(0, 24), Vector2(24, 0)]:
		expect(not Navigation.circle_intersects_rect(Vector2(300, 400), 18.0, Rect2(Vector2(300, 400), size)), "zero-area decoration does not become an invisible circular blocker: %s" % size)


## Создаёт ту же геометрию ствола и круга героя, что используется реальными мировыми профилями.
func _tree_walkable() -> Callable:
	return func(point: Vector2) -> bool: return not Navigation.circle_intersects_rect(point, 18.0, Rect2(-24, -24, 48, 48))


## Повторяет ограниченные восьмипиксельные шаги навигации, собирая безопасность всей траектории, а не только финальной точки.
func _simulate(start: Vector2, motion: Vector2, frames: int, walkable: Callable) -> Dictionary:
	var position := start
	var safe := true
	var speed_safe := true
	for _frame in frames:
		var count := maxi(1, ceili(motion.length() / 8.0))
		var step := motion / count
		for _part in count:
			var actual := step if walkable.call(position + step) else Assist.assisted_step(position, step, walkable)
			safe = safe and Assist.segment_clear(position, actual, walkable)
			speed_safe = speed_safe and actual.length() <= step.length() + 0.001
			position += actual
	return {"position": position, "safe": safe, "speed_safe": speed_safe}
