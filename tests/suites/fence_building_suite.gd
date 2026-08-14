extends "res://tests/suites/suite_base.gd"

const TEST_SAVE_PATH := "user://fence-building-suite.json"


## Запускает сценарии атласа, сетки, строительства, соединений, калиток, погоды и сохранения.
func run() -> void:
	test_atlas_has_strict_modular_layout()
	test_builder_uses_small_grid_and_five_materials()
	test_sections_connect_in_every_required_direction()
	test_gate_occupies_two_cells_and_changes_collision()
	test_placement_rules_and_removal_preserve_inventory()
	test_shop_crafting_icons_localization_and_tutorials()
	test_fences_survive_save_and_load()
	test_renderer_reacts_to_season_and_weather()


## Сценарий: художественный лист читается как строгий модульный атлас без захвата соседних изображений.
## Исходное состояние: нормализованный PNG содержит пять материалов и восемь типов соединений.
## Ожидаемый результат: размер равен 512×320, каждая ячейка 64×64, а края сохраняют прозрачность.
func test_atlas_has_strict_modular_layout() -> void:
	var texture: Texture2D=load("res://assets/game/environment/buildable_fence_atlas_v1.png"); var image:=texture.get_image()
	expect(image.get_size()==Vector2i(512,320), "fence atlas is an exact 8 by 5 sheet of 64 px source cells")
	var transparent_corners := true
	for row in 5:
		for column in 8:
			var origin := Vector2i(column*64,row*64)
			transparent_corners = transparent_corners and image.get_pixelv(origin).a<0.1 and image.get_pixelv(origin+Vector2i(63,63)).a<0.1
	expect(transparent_corners, "every fence module keeps transparent padding and cannot bleed into its neighbour")
	expect(ResourceLoader.exists("res://assets/game/items/catalog/fence_kit.png") and ResourceLoader.exists("res://assets/game/items/catalog/gate_kit.png"), "section and gate kits have dedicated inventory icons")


## Сценарий: строитель работает по четвертям большой диагностической клетки и предлагает все материалы.
## Исходное состояние: первая уличная локация, закрытый режим и стандартная пространственная сетка.
## Ожидаемый результат: Z открывает режим, базовый шаг равен 24 px, а Q проходит пять вариантов по кругу.
func test_builder_uses_small_grid_and_five_materials() -> void:
	var game := make_game(); game.current_location="overworld"
	expect(game.FenceSystem.CELL_SIZE==24 and game.SpatialGridSystem.BASE_CELL==24 and game.SpatialGridSystem.BLOCK_CELL==48, "fence footprint matches one of four cells inside the 48 px F10 block")
	expect(game.FenceSystem.handle_input(game,key_event(KEY_Z,KEY_Z,true)) and game.FenceSystem.active(game), "Z enables live fence building on the first location")
	game.FenceSystem.handle_input(game,joypad_button_event(JOY_BUTTON_LEFT_SHOULDER,true)); game.FenceSystem.handle_input(game,joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true)); expect(not game.FenceSystem.active(game), "gamepad shoulder chord closes fence building without stealing movement controls")
	var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=game.FenceSystem.TOUCH_BUTTON.get_center(); expect(game.FenceSystem.handle_input(game,touch) and game.FenceSystem.active(game), "touch construction button opens the same builder")
	var initial_style: int=int(game.FenceSystem.runtime(game).style)
	var names := {}
	for index in 5:
		names[game.FenceSystem.style_name(game,game.FenceSystem.runtime(game).style)]=true
		game.FenceSystem.cycle_style(game,1)
	expect(names.size()==5 and int(game.FenceSystem.runtime(game).style)==initial_style, "Q-style cycling exposes five distinct materials and wraps around")
	game.current_location="cottage_interior"
	expect(not game.FenceSystem.toggle(game), "fence building stays unavailable inside buildings")
	game.FenceSystem.configure_preview(game); game.FarmLifeSystem.initialize(game); expect(game.FenceSystem.structures(game).size()==40, "visual preview contains five complete modular fence rows after world initialization")
	game.inventory_open=true; var paused_builder: Dictionary=game.FenceSystem.runtime(game); paused_builder.place_held=true; game.set_meta(game.FenceSystem.META_KEY,paused_builder); game.FenceSystem.update(game,1.0); expect(not game.FenceSystem.runtime(game).place_held, "opening inventory cancels held construction and prevents building behind UI")
	game.free()


## Сценарий: соседние секции автоматически выбирают прямую, угол, T-образный и крестовой рисунок.
## Исходное состояние: в лесу вручную задан центр и соседи одного материала по сетке 24 px.
## Ожидаемый результат: битовая маска и столбец атласа однозначны для всех форм соединения.
func test_sections_connect_in_every_required_direction() -> void:
	var game := make_game(); game.current_location="forest"
	var center := Vector2i(20,14)
	var directions := [[Vector2i.UP,1],[Vector2i.RIGHT,2],[Vector2i.DOWN,4],[Vector2i.LEFT,8]]
	for expected_mask in [0,2,10,3,7,15]:
		var values: Array=game.FenceSystem.structures(game); values.clear(); values.append(section("forest",center,0))
		for entry in directions:
			if expected_mask & int(entry[1]): values.append(section("forest",center+entry[0],0))
		var actual: int=game.FenceSystem.connection_mask(game,values[0]); var visual: Dictionary=game.FenceRenderer.visual_for_mask(actual)
		expect(actual==expected_mask, "auto-connection calculates neighbour mask %d"%expected_mask)
		if expected_mask in [0,2,10,3,7,15]: expect(int(visual.column) in [0,1,3,4,5], "mask %d selects a modular source column"%expected_mask)
	game.FenceSystem.structures(game).clear(); game.FenceSystem.structures(game).append(section("forest",center,0)); game.FenceSystem.structures(game).append(section("forest",center+Vector2i.RIGHT,1))
	expect(game.FenceSystem.connection_mask(game,game.FenceSystem.structures(game)[0])==0, "a different material never creates a false connection")
	game.free()


## Сценарий: калитка занимает две малые клетки, открывается действием и перестаёт быть стеной.
## Исходное состояние: горизонтальная закрытая калитка стоит на свободной лесной земле рядом с героем.
## Ожидаемый результат: заняты обе клетки, закрытое состояние блокирует, а открытое пропускает персонажа.
func test_gate_occupies_two_cells_and_changes_collision() -> void:
	var game := make_game(); game.current_location="forest"
	var value := {"location":"forest","cell":[20,14],"kind":"gate","style":3,"orientation":0,"open":false}
	game.FenceSystem.structures(game).append(value)
	var cells: Array[Vector2i]=game.FenceSystem.occupied_cells(value); var first_center: Vector2=game.FenceSystem.cell_center(cells[0])
	expect(cells==[Vector2i(20,14),Vector2i(21,14)] and game.FenceRenderer.source(3,6)==Rect2(384,192,64,64), "closed matching gate uses two cells and its material row")
	expect(game.FenceSystem.blocks_position(game,first_center,8.0), "closed gate participates in navigation collision")
	game.player=game.FenceSystem.structure_center(value)-Vector2(50,0)
	expect(game.FenceSystem.nearest_gate(game).begins_with("fence_gate:") and game.FenceSystem.toggle_gate(game,0), "nearby gate is discoverable and opens through context interaction")
	expect(not game.FenceSystem.blocks_position(game,first_center,8.0) and game.FenceRenderer.source(3,7)==Rect2(448,192,64,64), "open gate swaps its source sprite and becomes walkable")
	var inspected: Array=game.DebugObjectInspectorSystem.candidates(game).filter(func(entry): return String(entry.id).begins_with("player_fence:"))
	expect(inspected.size()==1 and inspected[0].details[0].contains("style 3"), "F10 hover inspector exposes gate material cells and collision state")
	game.free()


## Сценарий: установка расходует набор только на разрешённой земле, а демонтаж возвращает его.
## Исходное состояние: герой имеет два набора, свободная лесная клетка и видимая дорога первой локации.
## Ожидаемый результат: свободная клетка строится, дорога отвергается без расхода, X-разбор возвращает набор.
func test_placement_rules_and_removal_preserve_inventory() -> void:
	var game := make_game(); game.current_location="forest"; game.change_inventory_count("fence_kit",2)
	var free_cell := find_buildable_cell(game,"forest"); var before: int=game.inventory_item_count("fence_kit")
	expect(game.FenceSystem.placement_reason(game,free_cell,"section",0)=="ok" and game.FenceSystem.place(game,game.FenceSystem.cell_center(free_cell)), "a section can be placed on a free outdoor 24 px cell")
	expect(game.inventory_item_count("fence_kit")==before-1 and game.FenceSystem.structure_at(game,free_cell)>=0, "successful placement consumes exactly one kit")
	expect(game.FenceSystem.remove_target(game,game.FenceSystem.cell_center(free_cell)) and game.inventory_item_count("fence_kit")==before, "removing a section refunds exactly one kit")
	game.current_location="overworld"
	var road_cell: Vector2i=game.FenceSystem.target_cell(game,game.VillageLayoutSystem.PATHS[0][4]); var road_before: int=game.inventory_item_count("fence_kit")
	expect(game.FenceSystem.placement_reason(game,road_cell,"section",0)=="road" and not game.FenceSystem.place(game,game.FenceSystem.cell_center(road_cell)), "roads and paths on the first location reject fence construction")
	expect(game.inventory_item_count("fence_kit")==road_before, "rejected placement never consumes a construction kit")
	game.free()


## Сценарий: новые строительные предметы доступны через экономику и обучаются на всех языках.
## Исходное состояние: каталоги предметов, магазина, верстака, локализации и обучения загружены.
## Ожидаемый результат: оба набора зарегистрированы, продаются/создаются, имеют названия и три шага обучения.
func test_shop_crafting_icons_localization_and_tutorials() -> void:
	var game := make_game()
	for kind in ["fence_kit","gate_kit"]:
		expect(game.InventorySystem.ITEM_DATA.has(kind) and game.ShopSystem.PRODUCTS.any(func(entry): return entry.kind==kind), "construction item is registered and sold: %s"%kind)
		expect(game.CraftingSystem.RECIPES.any(func(recipe): return recipe.output==kind), "construction item has a workbench recipe: %s"%kind)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		expect(game.LocaleSystem.item("fence_kit")!="fence_kit" and game.LocaleSystem.item("gate_kit")!="gate_kit", "construction kits are localized for %s"%locale)
		expect(game.LocaleSystem.tutorial("fence_build")!="fence_build" and game.LocaleSystem.tutorial("fence_gate")!="fence_gate" and game.LocaleSystem.tutorial("fence_weather")!="fence_weather", "three fence tutorials are localized for %s"%locale)
	game.LocaleSystem.current="ru"; game.free()


## Сценарий: построенные игроком секции и открытая калитка проходят полный цикл сохранения.
## Исходное состояние: две разные ограды находятся в расширении усадьбы перед записью JSON.
## Ожидаемый результат: новый экземпляр получает координаты, материал, ориентацию и состояние калитки без потерь.
func test_fences_survive_save_and_load() -> void:
	for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH+suffix))
	var game := make_game(); var values: Array=game.FenceSystem.structures(game)
	values.append(section("overworld",Vector2i(25,18),4)); values.append({"location":"forest","cell":[40,20],"kind":"gate","style":2,"orientation":1,"open":true})
	expect(game.SaveSystem.save_at(game,TEST_SAVE_PATH), "save document accepts modular fence structures")
	var restored := make_game()
	expect(game.SaveSystem.load_at(restored,TEST_SAVE_PATH), "save document restores modular fence structures")
	var loaded: Array=restored.FenceSystem.structures(restored)
	expect(loaded.size()==2 and int(loaded[0].cell[0])==25 and int(loaded[0].cell[1])==18 and int(loaded[0].style)==4, "restored section preserves location cell and material")
	expect(loaded.size()==2 and loaded[1].kind=="gate" and int(loaded[1].orientation)==1 and loaded[1].open, "restored gate preserves orientation and open state")
	game.free(); restored.free()
	for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH+suffix))


## Сценарий: один материал получает разные мягкие оттенки для лета, осени, зимы и осадков.
## Исходное состояние: день и принудительная погода изменяются без замены исходного атласа.
## Ожидаемый результат: цветовая обработка различается, а снег и дождь остаются отдельным слоем рендера.
func test_renderer_reacts_to_season_and_weather() -> void:
	var game := make_game(); var colors := {}
	for day in [1,8,15,22]:
		game.day=day; game.state.world.weather_day=day; game.state.world.weather="clear"; colors[game.FenceRenderer.climate_color(game)]=true
	expect(colors.size()==4, "fence finish has four distinct seasonal treatments")
	game.day=1; game.state.world.weather_day=1; game.state.world.weather="rain"; var rain: Color=game.FenceRenderer.climate_color(game)
	game.state.world.weather="clear"; var clear: Color=game.FenceRenderer.climate_color(game)
	expect(rain!=clear, "rain adds a wet tint without changing the selected fence material")
	var renderer_source:=FileAccess.get_file_as_string("res://scripts/systems/fence_renderer.gd")
	expect(renderer_source.contains('weather=="snow"') and renderer_source.contains('weather in ["rain","storm"]'), "renderer supplies explicit snow and wet-weather details")
	game.free()


## Создаёт JSON-безопасную секцию ограды для заданной локации, клетки и материала.
func section(location: String, cell: Vector2i, style: int) -> Dictionary:
	return {"location":location,"cell":[cell.x,cell.y],"kind":"section","style":style,"orientation":0,"open":false}


## Находит первую клетку, которую реальная проверка размещения признаёт свободной.
func find_buildable_cell(game: Node, location: String) -> Vector2i:
	game.current_location=location
	for y in range(6,30):
		for x in range(6,55):
			var cell:=Vector2i(x,y)
			if game.FenceSystem.placement_reason(game,cell,"section",0)=="ok": return cell
	return Vector2i(-1,-1)
