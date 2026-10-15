extends "res://tests/suites/suite_base.gd"

const Query := preload("res://scripts/systems/water_fishing_query.gd")
const Water := preload("res://scripts/systems/water_map_registry.gd")
const Rod := preload("res://scripts/systems/fishing_system.gd")
const Recovery := preload("res://scripts/systems/recovery_system.gd")

## Проверяет реальную линию заброса, тип воды, расход, паузу и жизненный цикл поплавка.
func run() -> void:
	test_cardinal_banks_turns_and_range()
	test_deck_and_low_rails_are_explicit_cast_positions()
	test_fence_wall_and_late_obstacle_preserve_resources()
	test_bobber_is_anchored_and_queries_are_cached()
	test_pause_cancel_travel_death_and_load()

## Сценарий: заброс с четырёх сторон осевой реки, возле каждого поворота и у пруда.
## Исходное состояние: настоящая вода фермы, несколько сил заброса и прежний рыбацкий каталог.
## Ожидаемый результат: поплавок видим на воде в пределах дальности, поза направлена к воде, виды не подменяются.
func test_cardinal_banks_turns_and_range() -> void:
	var game:=prepared()
	var fixtures: Array=[
		[Vector2(396,180),Vector2.DOWN],[Vector2(144,396),Vector2.UP],
		[Vector2(900,720),Vector2.RIGHT],[Vector2(1176,720),Vector2.LEFT],
		[Vector2(576,180),Vector2.DOWN],[Vector2(696,564),Vector2.UP],
		[Vector2(1032,348),Vector2.DOWN],[Vector2(1032,1080),Vector2.UP],
		[Vector2(1992,888),Vector2.LEFT]]
	for fixture in fixtures:
		game.player=fixture[0]
		for power in [0.0,0.5,1.0]:
			Rod.cancel(game); game.action_held=true
			var began:=Rod.use_rod(game)
			expect(began,"cast starts at real bank: "+str(fixture[0]))
			if not began: continue
			expect(game.get_meta("fish_visual_direction")==fixture[1],"pose faces the actual water independently of flow")
			game.state.fishing.cast_power=power; game.action_held=false; Rod.update(game,0.016)
			var point:=Rod.bobber_position(game)
			expect(game.state.fishing.phase=="waiting" and point.is_finite() and Water.has_surface("overworld",point) and not Water.geometry("overworld").on_bridge(point),"released bobber is visible water rather than a deck or shore")
			expect(point.distance_to(game.player)<=Query.RANGE+0.01 and Query.clear_line(game,point),"cast keeps its bounded unobstructed line")
			expect(game.state.fishing.water_kind==Water.geometry("overworld").kind_at(point),"habitat comes from the released water point")
	Rod.cancel(game); game.player=Vector2(396,600)
	expect(not Rod.use_rod(game) and game.state.fishing.phase=="idle","out-of-range cast has no phantom waiting stage")
	game.free()

## Сценарий: герой рыбачит с мостового настила и поверх низких перил речной набережной.
## Исходное состояние: обе переправы фермы и берега речного района остаются непроходимыми сбоку.
## Ожидаемый результат: рыбалка разрешена, поплавок за пределами настила; ограда по-прежнему блокирует ходьбу.
func test_deck_and_low_rails_are_explicit_cast_positions() -> void:
	var game:=prepared()
	for bridge in Query.Water.Data.HOME_BRIDGES:
		game.player=bridge.get_center(); game.action_held=true
		expect(Rod.use_rod(game),"the protected deck is an explicit legal casting position")
		game.action_held=false; Rod.update(game,0.016)
		expect(game.state.fishing.cast_target.is_finite() and not Water.geometry("overworld").on_bridge(game.state.fishing.cast_target),"bobber exits the bridge footprint")
		Rod.cancel(game)
	game.current_location="village_river"
	for point in [Vector2(864,696),Vector2(1152,696)]:
		game.player=point; game.action_held=true
		expect(Rod.use_rod(game),"low river railing allows a cast from either bank")
		game.action_held=false; Rod.update(game,0.016)
		expect(game.state.fishing.cast_target.is_finite() and Water.has_surface("village_river",game.state.fishing.cast_target),"district bobber belongs to actual district water")
		Rod.cancel(game)
	expect(not game.NavigationSystem.is_walkable(game,Vector2(924,696)),"casting over low rails does not grant walking through them")
	game.free()

## Сценарий: ограда или пользовательская стена закрывает линию, в том числе после начала зарядки.
## Исходное состояние: свободный берег, удочка и наживка; препятствие проверяется обычной навигацией.
## Ожидаемый результат: отказ не тратит прочность, наживку, монеты или опыт и не оставляет анимацию заброса.
func test_fence_wall_and_late_obstacle_preserve_resources() -> void:
	var game:=prepared(); game.player=Vector2(144,420); game.change_inventory_count("fishing_bait",2)
	var initial: Dictionary=game.state.inventory.durability.duplicate(true); var coins: int=game.coins; var xp: int=game.player_xp
	var fence: Dictionary={"location":"overworld","cell":[6,15],"kind":"section","style":0,"orientation":0,"open":false}
	game.FenceSystem.structures(game).append(fence)
	expect(not Rod.use_rod(game),"solid fence rejects the cast before charge")
	game.FenceSystem.structures(game).clear(); game.action_held=true
	expect(Rod.use_rod(game) and game.state.inventory.durability==initial,"charging alone never wears the rod")
	game.FenceSystem.structures(game).append(fence); game.action_held=false; Rod.update(game,0.016)
	expect(game.state.fishing.phase=="idle" and game.HeroActionSystem.pose(game).is_empty(),"obstacle introduced during charging cancels without a stuck pose")
	expect(game.inventory_item_count("fishing_bait")==2 and game.state.inventory.durability==initial and game.coins==coins and game.player_xp==xp,"failed release preserves all consumables and rewards")
	game.FenceSystem.structures(game).clear()
	game.set_meta(game.PublishedLevelSystem.META_KEY,{"active":true,"objects":[{"position":Vector2(144,372),"size":Vector2(48,24),"collision":true}]})
	expect(not Rod.use_rod(game),"published wall is not ignored by the fishing ray")
	game.remove_meta(game.PublishedLevelSystem.META_KEY); game.action_held=true; Rod.use_rod(game); game.action_held=false; Rod.update(game,0.016)
	expect(game.state.fishing.phase=="waiting" and game.inventory_item_count("fishing_bait")==1 and game.state.inventory.durability.fishing_rod==int(initial.fishing_rod)-1,"one actual release spends exactly one bait and durability")
	game.free()

## Сценарий: тысяча запросов поплавка и изменение направления героя после успешного заброса.
## Исходное состояние: закреплённая точка воды и измеренная привязка лески к спрайту удочки.
## Ожидаемый результат: нет повторного поиска по карте, поплавок не следует за игроком, леска остаётся у снасти.
func test_bobber_is_anchored_and_queries_are_cached() -> void:
	var game:=prepared(); game.player=Vector2(1992,888); release(game)
	var point:=Rod.bobber_position(game); var searches: int=game.get_meta("water_fishing_queries",0)
	for index in 1000: Rod.bobber_position(game)
	game.facing=Vector2.DOWN
	expect(Rod.bobber_position(game)==point and game.get_meta("water_fishing_queries",0)==searches,"stationary bobber rendering performs no new spatial searches")
	var line:=preload("res://scripts/systems/hero_action_visual_system.gd").fishing_line_origin(game)
	expect(line.is_finite() and line.distance_to(game.player)>20 and game.get_meta("fish_visual_direction")==Vector2.LEFT,"line origin uses the held rod and the cast direction")
	game.player+=Vector2(0,12)
	expect(Rod.bobber_position(game)==point,"a small forced displacement cannot drag the bobber onto land")
	game.free()

## Сценарий: открытие рюкзака, отмена, переход, смерть и повторная загрузка во время ожидания рыбы.
## Исходное состояние: настоящий успешный заброс и непустая постоянная рыбная статистика.
## Ожидаемый результат: пауза сохраняет точку и таймер; остальные завершения убирают временное состояние без потери коллекции.
func test_pause_cancel_travel_death_and_load() -> void:
	var game:=prepared(); game.player=Vector2(1992,888); game.state.fishing.total_caught=3; release(game)
	var point: Vector2=game.state.fishing.cast_target; var timer: float=game.state.fishing.timer; var visual: float=game.state.fishing.visual_time
	game.open_inventory(); game.GameLoop.physics_process(game,1.0)
	expect(game.state.fishing.timer==timer and game.state.fishing.cast_target==point and game.state.fishing.visual_time==visual,"backpack freezes the bite and its visual clock")
	game.inventory_open=false; Rod.use_rod(game)
	expect(game.state.fishing.phase=="idle" and not game.state.fishing.cast_target.is_finite(),"manual reel-in clears the fixed target")
	release(game); game.current_location="village_river"; game.sync_background_location()
	expect(game.state.fishing.phase=="idle" and not game.has_meta(game.HeroActionSystem.META),"ordinary transition immediately clears the old rod and bobber")
	game.current_location="overworld"; release(game); Recovery.begin(game,"slime",0)
	expect(game.state.fishing.phase=="idle" and not game.state.fishing.cast_target.is_finite(),"recovery removes an unfinished cast")
	release(game); var snapshot: Dictionary=game.SaveSystem.snapshot(game); var restored:=prepared()
	expect(restored.SaveSystem.apply(restored,snapshot) and restored.state.fishing.phase=="idle" and not restored.state.fishing.cast_target.is_finite() and restored.state.fishing.total_caught==3,"load retains collection but never restores an obsolete fishing action")
	game.free(); restored.free()

## Создаёт отдельную игровую модель без движущихся врагов и событий, мешающих проверке берегов.
func prepared() -> Node:
	var game:=make_game(); game.current_location="overworld"; game.has_fishing_rod=true; game.state.world.estate.event=""
	game.enemy_nodes.clear(); game.slime_alive=false; game.hazard_nodes.clear(); return game

## Выпускает настоящий заброс после начала зарядки, сохраняя обычную обработку расходников.
func release(game: Node) -> void:
	game.action_held=true; Rod.use_rod(game); game.state.fishing.cast_power=0.5; game.action_held=false; Rod.update(game,0.016)
