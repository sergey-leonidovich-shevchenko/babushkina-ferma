extends "res://tests/suites/suite_base.gd"

const MapData:=preload("res://scripts/systems/village_map_data.gd")
const Probe:=preload("res://tests/support/village_route_probe.gd")
const Migration:=preload("res://scripts/systems/village_map_migration_system.gd")
const Terrain:=preload("res://scripts/systems/village_terrain_renderer.gd")
const Props:=preload("res://scripts/systems/village_prop_renderer.gd")
const Preview:=preload("res://scripts/systems/village_map_preview_system.gd")
const Background:=preload("res://scripts/world_background.gd")

## Проверяет новую деревню реальными маршрутами, границами спрайтов и переносом старого прогресса.
func run()->void:
	test_all_services_have_continuous_routes()
	test_bridge_and_fence_geometry_matches_materials()
	test_livestock_does_not_spawn_in_crops()
	test_old_map_migration_preserves_progress()
	test_minimap_is_warm_before_arrival_finishes()

## Сценарий: первое вступление прячет миникарту, а после 4.5 секунд открывает её возле уже движущегося героя.
## Исходное состояние: кеш пуст; запускается настоящий _ready фонового узла, затем время вступления истекает.
## Ожидаемый результат: текстура готова ещё до управления и после вступления используется тот же объект, без повторной растеризации.
func test_minimap_is_warm_before_arrival_finishes()->void:
	var previous:Texture2D=Preview._texture; Preview._texture=null
	var game:=make_game(); var background:=Background.new()
	game.FarmLifeSystem.state(game).cutscene="arrival"; game.FarmLifeSystem.state(game).cutscene_timer=4.5
	background._ready()
	var prepared:Texture2D=Preview._texture
	expect(prepared!=null and prepared.get_size()==MapData.WORLD_SIZE/12,"Мировой фон прогревает миникарту всей карты, включая новый южный луг, ещё при скрывающем её вступлении")
	game.FarmLifeSystem.update(game,4.5)
	expect(game.FarmLifeSystem.state(game).cutscene.is_empty() and Preview.texture()==prepared,"Окончание вступления получает ту же подготовленную текстуру, а не строит карту в игровом кадре")
	Preview.warmup()
	expect(Preview.texture()==prepared,"Повторный warmup при входе в сцену идемпотентен")
	Preview._texture=previous; background.free(); game.free()

## Сценарий: новый герой идёт от своего дома ко всем полезным точкам деревни.
## Исходное состояние: штатные здания, заборы, ресурсы и растения; живые враги временно убраны только из проверки статического маршрута.
## Ожидаемый результат: все 14 точек достижимы, а найденные пути проходятся настоящим NavigationSystem.move без прыжков через коллизии.
func test_all_services_have_continuous_routes()->void:
	var game:=make_game(); game.current_location="overworld"; game.player=MapData.START
	game.slime_alive=false; game.enemy_nodes.clear(); game.hazard_nodes.clear()
	game.world_loot_nodes=game.LootContainerSystem.generate(20260908)
	var parents:=Probe.reachable(game,MapData.START)
	var targets:={"бабушка":MapData.GRANDMOTHER,"дом":MapData.COTTAGE_DOOR+Vector2(0,48),"огород":Vector2(MapData.FARM_ORIGIN)+Vector2(144,96),"верстак":MapData.WORKBENCH,"магазин":MapData.SHOP_STALL,"ящик продажи":MapData.SELL_CRATE,"гильдия":MapData.GUILD_DOOR+Vector2(0,48),"рыбачка":MapData.NPCS.varvara,"пещера":MapData.CAVE_ENTRANCE+Vector2(0,48),"лес":MapData.FOREST_GATE,"ремонт":MapData.REPAIR,"доска усадьбы":game.EstateSystem.BOARD_POSITION,"западный мост":MapData.BRIDGES[0].get_center(),"восточный мост":MapData.BRIDGES[1].get_center()}
	for name in targets:
		var path:=Probe.path_to(parents,targets[name])
		expect(not path.is_empty(),"Маршрут от дома доступен: "+name)
		if not path.is_empty(): expect(Probe.walk(game,path),"Непрерывная физическая прогулка: "+name)
	game.free()

## Сценарий: усадьба улучшена до животноводства, и все домашние животные появляются на западной лужайке.
## Исходное состояние: штатные грядки и здания новой деревни, случайные враги отключены только для проверки статической земли.
## Ожидаемый результат: животные и кормушка не попадают на грядки, воду или стену, а район грядок определяется точнее общего двора.
func test_livestock_does_not_spawn_in_crops()->void:
	var game:=make_game(); game.current_location="overworld"; game.enemy_nodes.clear(); game.slime_alive=false
	var points:Array=MapData.FARM_ANIMALS.values(); points.append(MapData.FARM_TROUGH)
	for point in points:
		expect(not game.VillageLayoutSystem.is_farm_zone(point) and game.NavigationSystem.walkability_reason(game,point,-1,false)=="walkable","Домашнее животноводство стоит на свободной лужайке: %s"%point)
	expect(game.VillageLayoutSystem.district_at(Vector2(MapData.FARM_ORIGIN)+Vector2(48,48))=="farm","Вложенный район грядок не теряется внутри homestead")
	game.free()

## Сценарий: герой пересекает обе переправы, а тест сверяет изолированные изображения с модульной геометрией.
## Исходное состояние: новая карта с PNG-мостом144×216, честным настилом96×192 и секциями забора без полей атласа.
## Ожидаемый результат: торцы и центр мостов свободны, вода рядом непроходима, спрайты имеют альфа-канал и целые размеры24px.
func test_bridge_and_fence_geometry_matches_materials()->void:
	var game:=make_game(); game.current_location="overworld"; game.slime_alive=false; game.enemy_nodes.clear()
	for bridge in MapData.BRIDGES:
		for y in range(int(bridge.position.y)-12,int(bridge.end.y)+13,12):
			var point:=Vector2(bridge.get_center().x,y)
			expect(not game.VillageLayoutSystem.is_water(point,game.PLAYER_RADIUS),"На всём настиле и обоих торцах нет воды: %s"%point)
		expect(game.VillageLayoutSystem.is_water(bridge.get_center()+Vector2(-84,0),0),"За перилами находится настоящая вода")
	expect(Terrain.BRIDGE.get_size()==Vector2(144,216),"Мост имеет собственный целочисленный PNG6×9клеток")
	for kind in Props.Props:
		var texture:Texture2D=Props.Props[kind]; var size:=texture.get_size()
		expect(int(size.x)%24==0 and int(size.y)%24==0,"Размер модульного объекта кратен24: "+kind)
		expect(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"У объекта действительно прозрачный фон: "+kind)
	for column in [1,2]: expect(Terrain.fence_source(column).size!=Vector2(64,64),"Ограда не рисует прозрачные поля исходной ячейки")
	expect(game.VillageLayoutSystem.MASTER_SOLID_RECTS.is_empty(),"У новой карты нет коллизий старого запечённого фона")
	game.free()

## Сценарий: игрок загружает старый прототип с открытым сундуком и сохранённым состоянием животных.
## Исходное состояние: старые координаты контейнера, содержимое и opened сохранены, герой находится в новой реке.
## Ожидаемый результат: меняются только размещения; сундук не выдаёт добычу снова, предметы и здоровье не сбрасываются, повторная миграция бездействует.
func test_old_map_migration_preserves_progress()->void:
	var game:=make_game(); game.current_location="overworld"; game.world_loot_seed=20260908
	game.world_loot_nodes=game.LootContainerSystem.generate(game.world_loot_seed)
	game.world_loot_nodes[0].opened=true; game.world_loot_nodes[0].position=Vector2(920,400)
	var contents:Dictionary=game.world_loot_nodes[0].contents.duplicate(true)
	var coins:int=game.coins; var xp:int=game.player_xp
	game.player=Vector2(400,312)
	Migration.apply(game,1)
	expect(game.world_loot_nodes[0].opened and game.world_loot_nodes[0].contents==contents,"Перенос сундука не сбрасывает добычу и opened")
	expect(game.coins==coins and game.player_xp==xp,"Редизайн карты не выдаёт и не отнимает награды")
	expect(game.player==MapData.START,"Персонаж из новой воды возвращается на безопасный старт")
	var position:Vector2=game.world_loot_nodes[0].position; game.player=MapData.START+Vector2(12,0)
	Migration.apply(game,MapData.REVISION)
	expect(game.world_loot_nodes[0].position==position and game.player==MapData.START+Vector2(12,0),"Повторная миграция не телепортирует уже играющего героя")
	game.free()
