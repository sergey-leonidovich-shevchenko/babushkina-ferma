extends "res://tests/suites/suite_base.gd"

const Data := preload("res://scripts/systems/village_region_data.gd")
const Regions := preload("res://scripts/systems/village_region_system.gd")
const Probe := preload("res://tests/support/region_route_probe.gd")
const Map := preload("res://scripts/presentation/village_region_map_renderer.gd")

## Проверяет связность наземной сети, физические маршруты, расселение, действия, воду, карту и старые сохранения.
func run() -> void:
	test_reciprocal_graph_and_unique_layouts()
	test_all_regions_have_real_reachable_routes()
	test_passages_work_both_ways_without_bouncing()
	test_residents_schedules_and_quests()
	test_region_services_fishing_and_isolated_harvest()
	test_json_save_and_old_region_defaults()
	test_map_input_names_and_font_scale()

## Отключает вступление и живых врагов только в стенде статической наземной навигации.
func prepare(game: Node) -> void:
	game.slime_alive=false; game.enemy_nodes.clear(); game.hazard_nodes.clear(); game.world_loot_nodes.clear()
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.tutorial_visible=false; game.day=1; game.game_minutes=720
	game.state.world.weather_day=game.day; game.state.world.weather="clear"
	game.NpcMovementSystem.initialize(game); game.NpcMovementSystem.update(game,0)

## Сценарий: стартовая область состоит из шести отдельных карт с развилками и круговыми маршрутами.
## Исходное состояние: первоначальная ферма и пять новых районов имеют парные именованные дороги.
## Ожидаемый результат: все карты достижимы, связи обратимы, схемы разные, новые районы не входят в линейный маршрут биомов.
func test_reciprocal_graph_and_unique_layouts() -> void:
	var visited:={"overworld":true}; var pending:Array=["overworld"]; var edges:=0; var shapes:={}
	while not pending.is_empty():
		var source:String=pending.pop_back(); shapes[str(Data.PATHS[source])]=true
		for link in Data.passages(source):
			edges+=1
			var reverse:Array=Data.passages(link.target).filter(func(back): return back.target==source and back.port==link.arrival and back.arrival==link.port)
			expect(reverse.size()==1,"district passage has a unique reciprocal link: "+source+"/"+link.port)
			expect(Vector2(link.spawn).distance_to(Data.port_position(link.target,link.arrival))>38,"arrival lies beyond reverse trigger")
			if not visited.has(link.target): visited[link.target]=true; pending.append(link.target)
	expect(visited.size()==6 and edges/2>=visited.size()+1 and shapes.size()==6,"six different outdoor maps form multiple genuine loops")
	var game:=make_game()
	for area in Data.IDS:
		expect(game.WorldSystem.NAMES.has(area),"every district is registered as game content")
		if Data.added(area): expect(area not in game.WorldSystem.LOCATIONS,"district is entered through a road, not linear biome cycling")
	expect(game.ContentRegistry.validate().is_empty(),"new residents and harvest have valid item and location references")
	game.free()

## Сценарий: герой физически идёт от входа к каждому проходу, жителю, рабочему месту и растению.
## Исходное состояние: реальные фасады, деревья, мебель, берега и мосты шести карт, без боевых помех стенда.
## Ожидаемый результат: цели связаны проходимой землёй, каждый восстановленный путь проходит настоящее движение.
func test_all_regions_have_real_reachable_routes() -> void:
	var game:=make_game(); prepare(game)
	for area in Data.IDS:
		game.current_location=area
		var first:Dictionary=Data.passages(area)[0]
		var start:Vector2=game.VillageLayoutSystem.MapData.START if area=="overworld" else Data.port_position(area,first.port)+Data.INWARD[first.port]*96
		expect(game.NavigationSystem.is_walkable(game,start),"district arrival point is physically walkable: "+area)
		var parents:=Probe.reachable(game,start); var targets:={}
		for link in Data.passages(area): targets["road:"+link.port]=link.position
		for npc in Data.NPC_AREAS:
			if Data.NPC_AREAS[npc]==area: targets["npc:"+npc]=Data.NPC_POINTS[npc]
		for service in Data.SERVICES.get(area,{}): targets["service:"+service]=Data.SERVICES[area][service]
		for food in game.food_nodes:
			if food.get("location","")==area and food.get("id","").begins_with("village_"): targets["harvest:"+food.id]=food.position
		for key in targets:
			var path:=Probe.path(parents,targets[key],32 if String(key).begins_with("road:") else 60)
			expect(not path.is_empty(),"connected route in "+area+" to "+key)
			if not path.is_empty(): expect(Probe.walk(game,path),"actual small-step walk in "+area+" to "+key)
	game.free()

## Сценарий: автоматический переход переносит героя и допускает честный обратный проход после выхода из зоны.
## Исходное состояние: все шестнадцать направленных дорог, подготовленный герой и неизменные количества рюкзака.
## Ожидаемый результат: правильная комната и вход, нет мгновенного отскока, чужой или удалённый порт ничего не делает.
func test_passages_work_both_ways_without_bouncing() -> void:
	var game:=make_game(); prepare(game); var counts:Dictionary=game.export_inventory_counts().duplicate()
	for area in Data.IDS:
		for link in Data.passages(area):
			game.current_location=area; game.player=link.position; game.location_transition_armed=true; game.location_transition_cooldown=0
			game.move_right_held=true
			expect(game.LocationTransitionSystem.nearest_transition(game)=="village_passage:"+String(link.port),"actual road is recognized by automatic transition")
			expect(game.LocationTransitionSystem.update(game,0) and game.current_location==link.target and game.player==link.spawn,"automatic transition uses correct district and arrival")
			if Data.INWARD[link.port]==Data.INWARD[link.arrival]: expect(game.get_movement_direction()==Vector2.ZERO,"turning road releases movement that would point straight into reverse passage")
			expect(game.NavigationSystem.is_walkable(game,game.player) and not game.LocationTransitionSystem.update(game,0.1),"arrival is free and cannot bounce immediately: "+area+"/"+link.port+" "+game.NavigationSystem.walkability_reason(game,game.player))
			game.LocationTransitionSystem.update(game,0.5); game.player=Data.port_position(link.target,link.arrival)
			expect(game.LocationTransitionSystem.update(game,0) and game.current_location==area,"reverse road returns to its exact source")
	game.current_location="village_garden"; game.player=Vector2(768,624)
	expect(not Regions.travel(game,"left") and not Regions.travel(game,"right"),"unknown and remote passages reject travel")
	expect(game.export_inventory_counts()==counts and game.tutorial_events_completed.has("village_regions"),"travel changes no supplies and teaches the new road network")
	game.free()

## Сценарий: жители работают и гуляют в разных районах, сохраняя задания, дружбу и домашний распорядок.
## Исходное состояние: ясный день, двенадцать часов, четыре переселённых жителя и Мирон в гильдии.
## Ожидаемый результат: у каждого свой район, диалог работает в реальном месте, ночью люди возвращаются домой.
func test_residents_schedules_and_quests() -> void:
	var game:=make_game(); prepare(game); var places:={}
	for npc in Data.NPC_AREAS:
		var value:Dictionary=game.npc_movement[npc]
		expect(value.location==Data.NPC_AREAS[npc] and value.position.distance_to(Data.NPC_POINTS[npc])<=58,"resident works in their new district: "+npc)
		places[value.location]=true; game.current_location=value.location; game.player=value.position+Vector2(0,60)
		expect(game.QuestSystem.nearest_npc(game)==npc,"resident can be approached and selected in the correct area: "+npc)
		expect(game.AdventurePolishSystem.open_quest_dialogue(game,npc),"actual dialogue opens for relocated resident: "+npc)
		game.AdventurePolishSystem.handle_dialogue_key(game,KEY_ESCAPE)
	expect(places.size()==4 and game.npc_movement.miron.location=="guild_interior","four villagers no longer gather around Miron")
	game.current_location="forest"; game.game_minutes=23*60; game.NpcMovementSystem.update(game,0)
	for npc in Data.NPC_AREAS:
		var resident:Dictionary=game.npc_movement[npc]
		expect(game.BuildingSystem.is_interior(resident.location),"night schedule still leads to a real home: "+npc)
		expect(game.BuildingSystem.is_walkable_inside(resident.location,resident.position,game.PLAYER_RADIUS),"resident stands on the floor, outside furniture: "+npc)
	game.free()

## Сценарий: новые районы содержат настоящие услуги, рыбалку и независимую добычу сада.
## Исходное состояние: открытые лавка, алхимия и верстак, два моста через воду, активная яблоня.
## Ожидаемый результат: контекст открывает соответствующее окно, вода блокирует тело, мосты проходимы, урожай не возрождается переходом.
func test_region_services_fishing_and_isolated_harvest() -> void:
	var game:=make_game(); prepare(game)
	for area in Data.SERVICES:
		for service in Data.SERVICES[area]:
			game.current_location=area; game.player=Data.SERVICES[area][service]
			expect(game.nearest_interaction()=="village_service:"+String(service) and game.perform_context_action(),"real context opens regional service: "+service)
			expect(game.shop_open if service=="shop" else game.crafting_open,"service uses existing paused item window: "+String(service))
			if service=="alchemy":
				expect(preload("res://scripts/systems/alchemy_system.gd").at_station(game),"garden alchemy validates its real working point")
				game.change_inventory_count("field_mint",2)
				var recipe:int=game.CraftingSystem.RECIPES.find_custom(func(value): return value.get("id","")=="alchemy:field_mint_juice")
				var before:int=game.inventory_item_count("field_mint_juice")
				expect(game.CraftingSystem.craft(game,recipe) and game.inventory_item_count("field_mint_juice")==before+1,"garden service actually produces alchemical juice")
				game.player+=Vector2(240,0)
				expect(not game.CraftingSystem.craft(game,recipe),"moving away cannot remotely operate garden alchemy")
			game.shop_open=false; game.crafting_open=false
	game.current_location="village_river"; game.player=Vector2(864,696)
	expect(game.FishingSystem.is_near_water(game) and game.FishingSystem.water_kind(game)=="river","new bank supports river ecosystem fishing")
	game.has_fishing_rod=true
	expect(game.FishingSystem.use_rod(game) and game.state.fishing.phase==game.FishingSystem.PHASE_CHARGING and game.get_meta("fish_visual_direction")==Vector2.RIGHT,"real river cast faces the water horizontally")
	game.state.fishing.reset_cast(); game.player=Vector2(1152,696)
	expect(game.FishingSystem.use_rod(game) and game.get_meta("fish_visual_direction")==Vector2.LEFT,"opposite bank reverses cast direction toward the same water")
	game.state.fishing.reset_cast(); game.player=Vector2(864,696)
	game.state.fishing.cast_power=0.5; var bobber:Vector2=game.FishingSystem.bobber_position(game)
	expect(Data.WATER.has_point(bobber) and not game.NavigationSystem.is_walkable(game,Vector2(1008,696)),"bobber lands in drawn water and hero cannot walk through it")
	expect(not game.NavigationSystem.is_walkable(game,Vector2(924,696)),"river guardrail is an actual village barrier")
	for bridge in Data.BRIDGES: expect(game.NavigationSystem.is_walkable(game,bridge.get_center()),"actual river bridge has a walkable floor")
	var index:int=game.food_nodes.find_custom(func(food): return food.get("id","").begins_with("village_orchard:") and food.kind=="apple")
	var node:Dictionary=game.food_nodes[index]; game.current_location=node.location; game.player=node.position+Vector2(0,60)
	var before:int=game.inventory_item_count("apple")
	expect(game.collect_food(index) and game.inventory_item_count("apple")>before,"orchard fruit is genuine usable inventory supply")
	var first:Dictionary=Data.passages("village_orchard")[0]; game.player=first.position; Regions.travel(game,first.port); game.player=Data.port_position(first.target,first.arrival); Regions.travel(game,first.arrival)
	expect(not game.food_nodes[index].active and not game.collect_food(index),"leaving and returning never respawns harvested fruit")
	game.free()

## Сценарий: сохранение в новом районе сохраняет добычу и прогресс, старые слоты получают новые участки без сброса.
## Исходное состояние: собранный сад, собственная куча предметов, дружба, активная миссия и обычный JSON-снимок.
## Ожидаемый результат: район, координаты, дружба, миссия и истощение восстановлены; старый слот дополняется новым контентом.
func test_json_save_and_old_region_defaults() -> void:
	var game:=make_game(); prepare(game); game.current_location="village_orchard"; game.player=Vector2(1104,816)
	var index:int=game.food_nodes.find_custom(func(food): return food.get("id","").begins_with("village_orchard:")); game.food_nodes[index].active=false; game.food_nodes[index].ready_at=1500
	game.state.player.relationships.agafya=22; game.mission_states.side_seed=game.QuestSystem.ACTIVE
	game.dropped_items.append({"kind":"apple","count":3,"position":Vector2(1104,864),"location":"village_orchard"})
	var data:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game))); var restored:=make_game()
	expect(restored.SaveSystem.apply(restored,data) and restored.current_location=="village_orchard" and restored.player==game.player,"real JSON save restores exact outdoor district and position")
	var restored_index:int=restored.food_nodes.find_custom(func(food): return food.get("id","")==game.food_nodes[index].id)
	expect(not restored.food_nodes[restored_index].active and int(restored.food_nodes[restored_index].ready_at)==1500,"harvest cooldown survives load")
	expect(restored.state.player.relationships.agafya==22 and restored.mission_states.side_seed==game.QuestSystem.ACTIVE and restored.dropped_items[0].location=="village_orchard","existing relationships, quests and local drops are not reset")
	data.location="overworld"; data.player=[432,672]
	data.forage=data.forage.filter(func(food): return not String(food.get("id","")).begins_with("village_"))
	expect(restored.SaveSystem.apply(restored,data) and restored.food_nodes.any(func(food): return food.get("id","").begins_with("village_orchard:") and food.active),"old save gets default new harvest without overwriting old progress")
	game.free(); restored.free()

## Сценарий: схема районов доступна мышью, клавиатурой и геймпадом на всех языках.
## Исходное состояние: стартовая область, первая страница карты, шесть районов и текст 120%.
## Ожидаемый результат: V/R3 и кнопка переключают общий мир и районы, названия и подписи помещаются в карточки.
func test_map_input_names_and_font_scale() -> void:
	var game:=make_game(); prepare(game); game.WorldMapSystem.toggle(game)
	game.world_guide_page=0
	expect(Map.active(game) and Map.POINTS.size()==6,"world menu initially shows the outdoor district network")
	game._input(key_event(KEY_V,KEY_V,true)); expect(not Map.active(game),"real V route switches to whole-world view")
	game._input(joypad_button_event(JOY_BUTTON_RIGHT_STICK,true)); expect(Map.active(game),"controller R3 restores district view")
	game.WorldMapSystem.handle_pointer(game,Map.TOGGLE.get_center()); expect(not Map.active(game),"shared toggle hit-zone switches maps")
	game.settings_state.text_scale=1.2
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for area in Data.IDS:
			var label:String=game.LocaleSystem.location(area); var size:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,label,160,28,12)
			expect(label!=area and size>=8 and game.UI_FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=160,"district card fits localized name: "+locale+" "+area)
	game.free()
