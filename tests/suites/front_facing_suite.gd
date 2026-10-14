extends "res://tests/suites/basement_suite.gd"

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const HouseArt := preload("res://scripts/presentation/house_furniture_visual_system.gd")
const StationArt := preload("res://scripts/presentation/basement_visual_system.gd")

## Проверяет три видимых ракурса, все способы поворота и безопасную совместимость старых сохранений.
func run() -> void:
	test_visible_art_catalog()
	test_world_workbench_preserves_working_sides_and_access()
	test_rotation_inputs_and_rejected_rear_build()
	test_old_home_furniture_faces_front()
	test_old_station_turn_keeps_production()
	test_blocked_old_station_keeps_access()

## Сценарий: каждый уровень мебели, станка и строительной кучи показывается с рабочей стороны.
## Исходное состояние: утверждённые передние и боковые ресурсы; направление вверх осталось в старых сохранениях.
## Ожидаемый результат: вверх использует передний рисунок, задние текстуры не загружаются, боковые стороны остаются самостоятельными.
func test_visible_art_catalog() -> void:
	expect(Facing.SELECTABLE==[0,1,3],"placement offers front, left and right only")
	var catalog:=preload("res://scripts/systems/level_editor_asset_catalog_system.gd").scan("res://assets/game/interiors/furniture_a")
	expect(not catalog.is_empty() and catalog.all(func(entry): return not String(entry.path).ends_with("_north.png")),"editor catalog hides deprecated rear furniture")
	expect(catalog.any(func(entry): return String(entry.path).ends_with("wooden_wardrobe_south.png")) and catalog.any(func(entry): return String(entry.path).ends_with("wooden_wardrobe_east.png")),"editor keeps useful front and side furniture sprites")
	for kind in HouseArt.SPRITES:
		expect(HouseArt.texture(kind,2)==HouseArt.texture(kind,0),"old home direction uses front art: "+kind)
		for texture in HouseArt.SPRITES[kind]: expect(not texture.resource_path.contains("_north"),"unused rear home texture is not preloaded: "+kind)
	for kind in Basement.Data.STATIONS:
		for tier in range(1,5):
			var front:=StationArt.texture(kind,mini(tier,3),0,tier==4)
			expect(front==StationArt.texture(kind,mini(tier,3),2,tier==4),"old station direction uses front art: %s %d"%[kind,tier])
			for direction in Facing.SELECTABLE:
				var texture:=StationArt.texture(kind,mini(tier,3),direction,tier==4)
				expect(not texture.resource_path.contains("_north"),"all production and construction art excludes rear files: %s %d"%[kind,tier])
	for start in Facing.SELECTABLE:
		expect(Facing.next(Facing.next(start),-1)==start,"reverse rotation restores its actual visible side")

## Сценарий: уличный верстак использует согласованные рабочие ракурсы и остаётся доступным для крафта.
## Исходное состояние: ферма и ремесленный двор с прежними точками взаимодействия, три спрайта ремесленного набора.
## Ожидаемый результат: вместо бытового стола выбираются тиски и инструменты, стороны сохраняют общий масштаб, основания и открытие рецептов не меняются.
func test_world_workbench_preserves_working_sides_and_access() -> void:
	var art := preload("res://scripts/presentation/world_workbench_visual_system.gd")
	var data := preload("res://scripts/systems/village_region_data.gd")
	var ground := Vector2(1440,768)
	for direction in Facing.SELECTABLE:
		var texture: AtlasTexture = art.texture(direction)
		var destination: Rect2 = art.destination(ground,direction)
		expect(texture==StationArt.texture("workbench",1,direction),"outdoor workbench uses approved tools and vise: "+str(direction))
		expect(is_equal_approx(destination.size.x/texture.get_width(),destination.size.y/texture.get_height()) and destination.end.y==ground.y,"workbench keeps proportions and ground anchor: "+str(direction))
	expect(art.texture(2)==art.texture(0),"obsolete rear direction displays visible workbench front")
	var game := make_game()
	expect(art.collision_rect(ground)==game.FarmLifeVisualSystem.collision_rect("rustic_table",ground),"new workbench preserves regional footprint")
	var props: Array = data.PROPS.village_workyard
	expect(props.any(func(prop): return prop.kind=="workbench" and prop.position==ground and prop.direction==0),"workyard declares a real front-facing workbench")
	game.current_location="overworld"; game.player=game.workbench_position+Vector2(0,72)
	expect(game.nearest_interaction()=="workbench" and game.perform_context_action() and game.crafting_open,"farm workbench retains actual paused crafting interaction")
	game.crafting_open=false; game.current_location="village_workyard"; game.player=data.SERVICES.village_workyard.workbench
	expect(game.nearest_interaction()=="village_service:workbench" and game.perform_context_action() and game.crafting_open,"workyard workbench retains actual paused crafting interaction")
	game.free()

## Сценарий: герой поворачивает предварительное основание клавиатурой, геймпадом и экранными кнопками.
## Исходное состояние: открытый режим размещения с полным запасом строительных компонентов.
## Ожидаемый результат: каждый цикл содержит три ракурса, прямое размещение спинкой отвергается без списаний.
func test_rotation_inputs_and_rejected_rear_build() -> void:
	var game:=make_game(); enter(game); Basement.open(game); Controls.execute(game)
	var ui:=Basement.ui(game)
	var click:=InputEventMouseButton.new(); click.pressed=true; click.button_index=MOUSE_BUTTON_LEFT; click.position=Controls.PLACE_BUTTONS[1].get_center()
	for event in [key_event(KEY_R,KEY_R,true),joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true),click]:
		ui.direction=0
		for direction in [1,3,0]:
			expect(Controls.handle_input(game,event) and int(ui.direction)==direction,"every input skips the rear-facing placement option")
	ui.direction=0
	for direction in [3,1,0]:
		expect(Controls.handle_input(game,key_event(KEY_Q,KEY_Q,true)) and int(ui.direction)==direction,"reverse keyboard rotation skips rear art")
	ui.direction=2; expect(int(Controls.candidate(game).direction)==0,"stale preview state cannot recreate rear direction")
	for kind in Basement.Data.STATIONS.workbench.inputs: game.change_inventory_count(kind,int(Basement.Data.STATIONS.workbench.inputs[kind]))
	var before:Dictionary=game.export_inventory_counts().duplicate(true)
	expect(not Build.build(game,plan("workbench",30,18,2)) and before==game.export_inventory_counts() and Basement.state(game).objects.is_empty(),"rear-facing build refuses before materials are paid")
	game.free()

## Сценарий: в старом доме шкаф записан задней стороной, а временный поворот строительства тоже направлен вверх.
## Исходное состояние: настоящий снимок дома со шкафом на свободных клетках.
## Ожидаемый результат: загрузка сохраняет место и количество мебели, шкаф и новый предпросмотр смотрят вперёд.
func test_old_home_furniture_faces_front() -> void:
	var game:=make_game(); game.current_location="cottage_interior"
	var value:Dictionary=game.FarmLifeSystem.state(game)
	value.furniture=[{"kind":"wooden_wardrobe","position":Vector2(396,408),"direction":2}]
	var saved:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
	var counts:Dictionary=game.export_inventory_counts().duplicate(true)
	expect(game.SaveSystem.apply(game,saved),"legacy rear wardrobe still passes actual save validation")
	value=game.FarmLifeSystem.state(game)
	expect(value.furniture.size()==1 and value.furniture[0].direction==0 and value.furniture[0].position==Vector2(396,408),"wardrobe turns front without moving its footprint")
	expect(counts==game.export_inventory_counts(),"reorienting furniture does not spend or refund inventory")
	value.build_direction=2
	expect(int(preload("res://scripts/systems/house_furniture_layout_system.gd").candidate(game).direction)==0,"home preview ignores stale rear direction")
	game.free()

## Сценарий: старый станок записан спинкой к игроку с уже оплаченной незавершённой партией досок.
## Исходное состояние: лесопилка, два прошедших производственных секунды и свободный подход с обеих сторон.
## Ожидаемый результат: JSON-загрузка разворачивает станок без перемещения, потери сырья, прогресса или повторной выдачи.
func test_old_station_turn_keeps_production() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"sawmill",30,18); finish(game,item)
	Stations.interact(game,item.id); game.change_inventory_count("log",1)
	var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="sawmill:planks")
	expect(game.CraftingSystem.craft(game,index),"legacy production scenario pays through the real crafting path")
	game.crafting_open=false; Production.update(game,2); item.direction=2
	var production:Dictionary=item.production.duplicate(true); var counts:Dictionary=game.export_inventory_counts().duplicate(true)
	var saved:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
	expect(game.SaveSystem.apply(game,saved),"old rear station loads with its paid job")
	var loaded:=Basement.object(game,item.id)
	expect(loaded.direction==0 and loaded.x==30 and loaded.y==18,"safe rotation preserves instance and footprint")
	expect(JSON.parse_string(JSON.stringify(loaded.production))==JSON.parse_string(JSON.stringify(production)),"safe rotation preserves every production field")
	expect(counts==game.export_inventory_counts() and Basement.Layout.valid_set(Basement.state(game).objects),"rotation keeps inventory quantities and all routes valid")
	var again:Dictionary=game.SaveSystem.snapshot(game)
	expect(game.SaveSystem.apply(game,JSON.parse_string(JSON.stringify(again))) and JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))==JSON.parse_string(JSON.stringify(again)),"repeated JSON load is idempotent after the facing migration")
	game.free()

## Сценарий: соседний станок занимает новый передний подход старой строительной кучи.
## Исходное состояние: начатый гончарный круг с прежним северным доступом и верстак перед ним.
## Ожидаемый результат: загрузка оставляет физический подход и прогресс, показывает передний рисунок и позволяет закончить сборку.
func test_blocked_old_station_keeps_access() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"pottery",30,18); item.direction=2
	var neighbor:=place(game,"workbench",30,23)
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id); Build.update_hold(game,1.5)
	var saved:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
	expect(game.SaveSystem.apply(game,saved),"tight old layout remains a valid load")
	var loaded:=Basement.object(game,item.id)
	expect(loaded.direction==2 and loaded.work==1.5 and Basement.object(game,neighbor.id).y==23,"blocked rotation never moves or loses paid stations")
	expect(StationArt.texture("pottery",1,loaded.direction)==StationArt.texture("pottery",1,0),"tight legacy station still displays its visible front")
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(loaded)); game.energy=12
	expect(Stations.interact(game,loaded.id),"preserved old operating point remains interactive")
	Build.update_hold(game,3.5)
	expect(loaded.phase=="ready" and Basement.Layout.valid_set(Basement.state(game).objects),"paid construction can finish without relocating neighbors")
	game.free()
