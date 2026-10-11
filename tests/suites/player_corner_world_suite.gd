extends "res://tests/suites/suite_base.gd"

const CornerAssist := preload("res://scripts/systems/player_corner_assist_system.gd")


## Проверяет ручное огибание на настоящих основаниях деревни, не подменяя навигацию тестовой геометрией.
func run() -> void:
	test_real_tree_corner_is_safe_at_30_and_60_fps()
	test_real_orchard_corner_is_safe_at_30_and_60_fps()
	test_tree_center_does_not_choose_an_automatic_detour()
	test_default_displacement_does_not_turn_into_corner_assist()
	test_enemy_and_hazard_do_not_request_a_detour()
	test_real_river_bank_stays_solid_and_bridge_stays_open()


## Сценарий: игрок держит D возле нижнего левого края первого взрослого дерева восточной рощи.
## Исходное состояние: настоящая деревня и основание дерева сохранены; центр героя расположен на 16 px левее и 12 px ниже угла.
## Ожидаемый результат: при 30 и 60 FPS герой безопасно огибает край, смотрит по вводу и заканчивает путь с погрешностью менее одного малого шага.
func test_real_tree_corner_is_safe_at_30_and_60_fps() -> void:
	var game := village_fixture()
	var tree: Dictionary = game.state.world.tree_nodes[0]
	var rect: Rect2 = game.TreeSystem.collision_rect(tree)
	var origin := Vector2(rect.position.x - 16.0, rect.end.y + 12.0)
	expect(game.NavigationSystem.walkability_reason(game, origin) == "walkable" and game.NavigationSystem.walkability_reason(game, origin + Vector2(3.5, 0)) == "tree", "real village tree fixture starts free and hits its exact rounded corner")
	var slow := manual_trace(game, origin, 30, 0.5)
	var fast := manual_trace(game, origin, 60, 0.5)
	expect(bool(slow.safe) and bool(fast.safe), "tree corner assistance keeps every swept sample outside real world colliders")
	expect(Vector2(slow.position).x > rect.end.x + game.PLAYER_RADIUS and Vector2(fast.position).x > rect.end.x + game.PLAYER_RADIUS, "manual walking clears the real tree foundation at both frame rates")
	expect(Vector2(slow.position).distance_to(Vector2(fast.position)) <= 7.0, "30 and 60 FPS tree corner routes converge within one 30 FPS movement step")
	expect(bool(slow.facing) and bool(fast.facing) and bool(slow.bounded) and bool(fast.bounded), "tree correction preserves right-facing input and never exceeds commanded speed")
	game.free()


## Сценарий: игрок проходит справа вдоль нижнего края плодоносящей яблони, а не условного тестового прямоугольника.
## Исходное состояние: яблоня берётся из действующего каталога деревни; её основание учитывает собственную привязку OrchardSystem.
## Ожидаемый результат: алгоритм работает и с другим ground anchor, не проходит сквозь ствол и не зависит заметно от частоты кадров.
func test_real_orchard_corner_is_safe_at_30_and_60_fps() -> void:
	var game := village_fixture()
	var apple: Dictionary = game.food_nodes[3]
	var rect: Rect2 = game.OrchardSystem.collision_rect(apple.position, game.OrchardSystem.stage(apple))
	var origin := Vector2(rect.position.x - 16.0, rect.end.y + 12.0)
	expect(game.NavigationSystem.walkability_reason(game, origin) == "walkable" and game.NavigationSystem.walkability_reason(game, origin + Vector2(3.5, 0)) == "forage", "real orchard fixture resolves its fruit-tree foundation instead of the canopy")
	var slow := manual_trace(game, origin, 30, 0.5)
	var fast := manual_trace(game, origin, 60, 0.5)
	expect(bool(slow.safe) and bool(fast.safe) and Vector2(slow.position).x > rect.end.x + game.PLAYER_RADIUS and Vector2(fast.position).x > rect.end.x + game.PLAYER_RADIUS, "both orchard routes clear the trunk without entering an obstacle")
	expect(Vector2(slow.position).distance_to(Vector2(fast.position)) <= 7.0 and bool(slow.facing) and bool(fast.facing), "orchard correction preserves facing and a comparable path at 30 and 60 FPS")
	game.free()


## Сценарий: игрок продолжает держать D, упёршись прямо в центр ствола.
## Исходное состояние: герой стоит в одном пикселе от левой границы круга столкновения настоящего дерева, далеко от обоих углов.
## Ожидаемый результат: помощник не выбирает сам маршрут вокруг препятствия и не сдвигает героя вбок.
func test_tree_center_does_not_choose_an_automatic_detour() -> void:
	var game := village_fixture()
	var rect: Rect2 = game.TreeSystem.collision_rect(game.state.world.tree_nodes[1])
	var origin := Vector2(rect.position.x - game.PLAYER_RADIUS - 1.0, rect.get_center().y)
	expect(game.NavigationSystem.walkability_reason(game, origin) == "walkable", "real center-contact fixture starts outside all neighboring foundations")
	var trace := manual_trace(game, origin, 60, 0.5)
	expect(Vector2(trace.position).is_equal_approx(origin), "holding a direction into the middle of a tree does not trigger autopilot")
	expect(bool(trace.safe) and bool(trace.facing), "blocked center contact stays outside the real tree and preserves input facing")
	game.free()


## Сценарий: физическое отбрасывание или рывок вызывает общий метод движения без разрешения мягкого обхода.
## Исходное состояние: герой стоит возле того же проходимого угла; прямой сдвиг заблокирован, боковой маршрут существует.
## Ожидаемый результат: default-вызов остаётся прямым и неподвижным, тогда как явная ручная ходьба получает разрешённую коррекцию.
func test_default_displacement_does_not_turn_into_corner_assist() -> void:
	var game := village_fixture()
	var rect: Rect2 = game.TreeSystem.collision_rect(game.state.world.tree_nodes[0])
	var origin := Vector2(rect.position.x - 16.0, rect.end.y + 12.0)
	game.player = origin
	var physical_assist: bool = game.move_player_with_collisions(Vector2(7, 0))
	expect(not physical_assist and game.player.is_equal_approx(origin), "shared knockback and dash displacement does not opt into manual corner correction")
	var manual_assist: bool = game.NavigationSystem.move(game, Vector2(7, 0), true)
	expect(manual_assist and game.player.y > origin.y and game.NavigationSystem.is_walkable(game, game.player), "only explicit manual movement can use the safe tree-side opening")
	game.free()


## Сценарий: герой касается края круглого врага или опасной зоны, где геометрически возможен короткий боковой путь.
## Исходное состояние: на свободной поляне по очереди стоит один живой противник и одна опасность; обычные стены не перекрывают проверку.
## Ожидаемый результат: ни enemy, ни hazard не запускают автоматический обход и не втягивают игрока в зону урона.
func test_enemy_and_hazard_do_not_request_a_detour() -> void:
	var game := village_fixture()
	var origin := Vector2(1876, 642)
	game.slime_alive = false
	game.enemy_nodes = [{"position": Vector2(1900, 600), "location": "overworld", "alive": true}]
	game.hazard_nodes = []
	game.player = origin
	expect(game.NavigationSystem.walkability_reason(game, origin) == "walkable" and game.NavigationSystem.walkability_reason(game, origin + Vector2(3.5, 0)) == "enemy", "live enemy contact fixture starts outside its actual collision circle")
	var enemy_assist: bool = game.NavigationSystem.move(game, Vector2(3.5, 0), true)
	expect(not enemy_assist and game.player.is_equal_approx(origin), "enemy edge never triggers an unsolicited lateral dodge")
	game.enemy_nodes = []
	game.hazard_nodes = [{"position": Vector2(1900, 600), "location": "overworld"}]
	game.player = origin
	expect(game.NavigationSystem.walkability_reason(game, origin + Vector2(3.5, 0)) == "hazard", "hazard negative scenario exercises the actual hazard collision reason")
	var hazard_assist: bool = game.NavigationSystem.move(game, Vector2(3.5, 0), true)
	expect(not hazard_assist and game.player.is_equal_approx(origin), "hazard edge does not receive corner assistance")
	game.free()


## Сценарий: игрок упирается в настоящий наклонный берег, затем проходит по центру северного моста.
## Исходное состояние: геометрия реки и обоих мостов взята из новой деревни без подмены тестовыми препятствиями.
## Ожидаемый результат: помощник не превращает берег в обходную дорожку, а пересечение реки по существующему мосту остаётся свободным.
func test_real_river_bank_stays_solid_and_bridge_stays_open() -> void:
	var game := village_fixture()
	var shore := Vector2(744, 470)
	game.player = shore
	expect(game.NavigationSystem.walkability_reason(game, shore) == "walkable" and game.NavigationSystem.walkability_reason(game, shore + Vector2(0, -3.5)) == "water", "real river bank fixture separates dry land from the radius-expanded water edge")
	var shore_assist: bool = game.NavigationSystem.move(game, Vector2(0, -3.5), true)
	expect(not shore_assist and game.player.is_equal_approx(shore), "holding into the river does not create a sideways water bypass")
	game.player = Vector2(864, 336)
	var bridge_safe := true
	var bridge_assisted := false
	for _frame in 36:
		var previous: Vector2 = game.player
		bridge_assisted = game.NavigationSystem.move(game, Vector2(0, 7), true) or bridge_assisted
		bridge_safe = clear_world_segment(game, previous, game.player) and bridge_safe
	expect(bridge_safe and game.player.is_equal_approx(Vector2(864, 588)), "north bridge remains fully traversable from bank to bank with real world collision")
	expect(not bridge_assisted, "the open center of a bridge needs no artificial corner displacement")
	game.free()


## Подготавливает обычную деревню без активной физики, сохраняя её реальные статические и динамические размещения.
func village_fixture() -> Node:
	var game := make_game()
	game.current_location = "overworld"
	game.move_up_held = false
	game.move_down_held = false
	game.move_left_held = false
	game.move_right_held = false
	return game


## Записывает одинаковый отрезок ручной ходьбы и проверяет безопасность не только концов, но и промежуточных проб.
func manual_trace(game: Node, origin: Vector2, fps: int, duration: float) -> Dictionary:
	game.player = origin
	game.move_right_held = true
	if game.has_meta(CornerAssist.FAILED_PROBE_META): game.remove_meta(CornerAssist.FAILED_PROBE_META)
	var safe: bool = game.NavigationSystem.is_walkable(game, origin)
	var right_facing := true
	var bounded := true
	var delta := 1.0 / float(fps)
	for _frame in roundi(duration * fps):
		var previous: Vector2 = game.player
		game.update_player_movement(delta)
		safe = clear_world_segment(game, previous, game.player) and safe
		right_facing = game.facing.is_equal_approx(Vector2.RIGHT) and right_facing
		bounded = previous.distance_to(game.player) <= game.speed * delta + 0.002 and bounded
	game.move_right_held = false
	return {"position": game.player, "safe": safe, "facing": right_facing, "bounded": bounded}


## Повторно проверяет весь фактический путь героя по полной игровой навигации с независимым шагом не больше двух пикселей.
func clear_world_segment(game: Node, origin: Vector2, destination: Vector2) -> bool:
	var count := maxi(1, ceili(origin.distance_to(destination) / 2.0))
	for index in range(count + 1):
		if not game.NavigationSystem.is_walkable(game, origin.lerp(destination, float(index) / count)): return false
	return true
