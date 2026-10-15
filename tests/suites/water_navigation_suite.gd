extends "res://tests/suites/suite_base.gd"

const Water := preload("res://scripts/systems/water_map_registry.gd")
const Data := preload("res://scripts/systems/water_layout_data.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Cave := preload("res://scripts/systems/cave_room_data.gd")
const Migration := preload("res://scripts/systems/village_map_migration_system.gd")

## Проверяет общий источник воды, настилы, ограниченный кэш и настоящую загрузку старого слота.
func run() -> void:
	test_axis_contours_match_cells()
	test_bridges_and_physics_share_source()
	test_registry_is_bounded_and_sealed()
	test_old_save_preserves_progress_and_repairs_all_maps()
	test_new_game_objects_remain_on_land()

## Сценарий: рисунок первой карты и пещерного озера сравнивается с каждой клеткой физики.
## Исходное состояние: осевые контуры реки и пруда, два ступенчатых подземных водоёма.
## Ожидаемый результат: нет наклонных рёбер и независимой воды, мост не вырезает поверхность.
func test_axis_contours_match_cells() -> void:
	var polygons: Array=[Map.river_polygon(),Map.pond_polygon()]
	for rect in Data.CAVE_POOLS.cave_lake: polygons.append(Cave.pool_polygon(rect,true))
	for polygon in polygons:
		var cardinal:=true
		for index in polygon.size():
			var delta: Vector2=polygon[(index+1)%polygon.size()]-polygon[index]
			cardinal=cardinal and (is_zero_approx(delta.x) or is_zero_approx(delta.y))
		expect(cardinal,"every water contour edge is cardinal")
	var mismatches:=0
	for y in range(0,1368,24):
		for x in range(0,2400,24):
			var point:=Vector2(x+12,y+12)
			var painted:=Geometry2D.is_point_in_polygon(point,polygons[0]) or Geometry2D.is_point_in_polygon(point,polygons[1])
			if painted!=Water.has_surface("overworld",point): mismatches+=1
	expect(mismatches==0,"all home water centers match painted contour")
	for bridge in Data.HOME_BRIDGES: expect(Water.has_surface("overworld",bridge.get_center()),"water remains beneath each deck")

## Сценарий: полный радиус героя пересекает каждый настил и касается берега за его краем.
## Исходное состояние: общий реестр для дома, речного района и пещерного озера.
## Ожидаемый результат: настил проходим, край воды блокирует; декоративная вода не меняет игровой пол.
func test_bridges_and_physics_share_source() -> void:
	for area in ["overworld","village_river"]:
		var plan:=Water.geometry(area)
		var bridges: Array=Data.HOME_BRIDGES if area=="overworld" else Data.VILLAGE_BRIDGES
		for rect in bridges:
			expect(not Water.blocks(area,rect.get_center(),18),"bridge center fits real body: "+area)
			var side: Vector2=Vector2(rect.position.x+8,rect.get_center().y) if area=="overworld" else Vector2(rect.get_center().x,rect.position.y+8)
			expect(Water.blocks(area,side,18),"point-only deck exemption cannot leak sideways: "+area)
		expect(plan.cell_count()>0,"blocking water is represented by actual cells")
	expect(Water.blocks("cave_lake",Vector2(900,540),18),"cave lake shares blocking registry")
	expect(not Water.blocks("moon_glade",Vector2(1300,900),18) and not Water.blocks("pirate_ship",Vector2(1200,600),18),"decorative pool and sea backdrop preserve existing navigation")
	expect(not Water.has_surface("forest",Vector2(900,540)),"dry locations do not acquire water")

## Сценарий: переходы между всеми водными картами и попытка изменить общий план.
## Исходное состояние: ограниченный реестр хранит максимум две карты, наружу возвращаются запечатанные планы.
## Ожидаемый результат: чужой код не меняет физику, старые активные ссылки остаются пригодными после вытеснения.
func test_registry_is_bounded_and_sealed() -> void:
	Water.clear_cache(); var held:=Water.geometry("overworld"); var count:int=held.cell_count()
	expect(not held.erase_rect(Rect2(0,240,240,96)) and held.add_body("pond")==-1,"shared static plans reject mutation")
	for area in Data.PROFILE_KINDS:
		expect(Water.geometry(area)!=null and Water.statistics().locations.size()<=2,"bounded registry prepares water: "+area)
	expect(held.cell_count()==count and held.has_surface(Vector2(864,456)),"eviction cannot invalidate active plan")
	expect(Water.statistics().errors.is_empty(),"all built-in water plans pass validation")

## Сценарий: старый слот хранит героя, открытый сундук, лут и противника в новом русле разных карт.
## Исходное состояние: ревизия четыре, изменённые монеты, урожай, здоровье, задания и содержимое.
## Ожидаемый результат: загрузчик переносит координаты своей карты, сохраняет прогресс и не повторяет миграцию.
func test_old_save_preserves_progress_and_repairs_all_maps() -> void:
	var game:=make_game(); game.current_location="overworld"; game.player=Vector2(1008,720)
	game.state.world.estate.map_revision=4; game.coins=139; game.plots[Vector2i.ZERO].tilled=true
	game.world_loot_nodes[0].location="overworld"; game.world_loot_nodes[0].position=Vector2(1008,744); game.world_loot_nodes[0].opened=true
	game.dropped_items=[{"kind":"wood","count":7,"location":"village_river","position":Vector2(1008,696)}]
	var enemy_index: int=game.enemy_nodes.find_custom(func(enemy): return enemy.location=="cave_lake")
	game.enemy_nodes[enemy_index].position=Vector2(900,540); game.enemy_nodes[enemy_index].hp=7
	var snapshot: Dictionary=game.SaveSystem.snapshot(game); var restored:=make_game()
	expect(restored.SaveSystem.apply(restored,snapshot),"production loader accepts old water layout fixture")
	expect(not Water.blocks(restored.current_location,restored.player,restored.PLAYER_RADIUS),"old hero lands on dry ground")
	expect(restored.world_loot_nodes[0].opened and restored.world_loot_nodes[0].contents==game.world_loot_nodes[0].contents,"opened state and chest contents survive relocation")
	expect(restored.dropped_items.size()==1 and restored.dropped_items[0].kind=="wood" and restored.dropped_items[0].count==7 and not Water.blocks("village_river",restored.dropped_items[0].position,18),"off-screen drop preserves quantity and its own map")
	expect(restored.enemy_nodes[enemy_index].hp==7 and not Water.blocks("cave_lake",restored.enemy_nodes[enemy_index].position,27),"off-screen enemy keeps health and reaches dry cave floor")
	expect(restored.coins==139 and restored.plots[Vector2i.ZERO].tilled and restored.mission_states==game.mission_states,"coins crops and quest progress remain intact")
	var stable: Dictionary=restored.SaveSystem.snapshot(restored); Migration.apply(restored,Data.REVISION)
	expect(restored.SaveSystem.snapshot(restored)==stable,"current revision migration is an exact no-op")
	expect(restored.get_meta("water_migration",[]).size()>=3,"migration exposes an explicit relocation report")
	game.free(); restored.free()

## Сценарий: новая игра создаёт ресурсы, добычу, растения и деревья после смены русла.
## Исходное состояние: штатная сцена без редактирования пользовательских документов.
## Ожидаемый результат: физические точки объектов сухие, деревья сохраняют пропорции и мировую сетку.
func test_new_game_objects_remain_on_land() -> void:
	var game:=make_game()
	for entries in [game.world_loot_nodes,game.enemy_nodes,game.food_nodes,game.wildlife_nodes]:
		var bad:=0
		for entry in entries:
			var area: String=entry.get("location","overworld")
			if area in ["overworld","village_river","cave_lake"] and Water.blocks(area,entry.position,27): bad+=1
		expect(bad==0,"fresh object collection stays outside blocking water")
	for point in Map.TREES+Map.BORDER_TREES:
		expect(not Water.blocks("overworld",point+Vector2(0,48),24),"tree ground anchor stays dry: "+str(point))
	game.free()
