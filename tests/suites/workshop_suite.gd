extends "res://tests/suites/suite_base.gd"

const Workshop := preload("res://scripts/systems/workshop_system.gd")

## Проверяет три станка, точные партии, уровни, обжиг, связь деталей и настоящие сохранения.
func run() -> void:
	test_selected_sprites_depth_and_routes()
	test_materials_sources_and_real_stations()
	test_queue_atomic_energy_pause_and_outputs()
	test_all_three_upgrade_paths()
	test_every_production_and_firing_recipe()
	test_glass_fuel_isolation_and_resume()
	test_linked_upgrade_progression()
	test_vessels_support_cooking_and_research()
	test_controls_geometry_and_save()

## Сценарий: выбранные четыре семейства A работают отдельными спрайтами без соседних фрагментов и закрытых проходов.
## Исходное состояние: двенадцать ресурсов, три настоящие комнаты и все уровни исследовательского стола и станков.
## Ожидаемый результат: регионы целые, края прозрачны, пропорции и опора постоянны, герой проходит от двери к каждой услуге.
func test_selected_sprites_depth_and_routes() -> void:
	var Visual=preload("res://scripts/presentation/workshop_visual_system.gd"); var game:=make_game()
	var masters:Array[String]=[Visual.texture("sawmill",1).atlas.resource_path,Visual.texture("study_table",1).atlas.resource_path]
	expect(not game.LevelEditorSystem.catalog().any(func(entry): return String(entry.path) in masters),"constructor excludes raw multi-object masters instead of placing nine stations as one picture")
	for kind in Visual.SPRITES:
		var anchor:Vector2=Vector2(340,425) if kind=="study_table" else Workshop.Data.STATIONS[kind].anchor
		var location:String="guild_interior" if kind=="study_table" else Workshop.Data.STATIONS[kind].location
		var point:Vector2=game.ResearchSystem.STUDY_POINT if kind=="study_table" else Workshop.Data.STATIONS[kind].point
		game.current_location=location; var room:Dictionary=game.BuildingSystem.INTERIORS[location]
		expect(game.InteriorVisualSystem.props(location).any(func(prop): return prop.kind==kind and prop.position==anchor),"selected station owns its actual interior prop: "+kind)
		for level in range(1,4):
			var texture:AtlasTexture=Visual.texture(kind,level); var region:Rect2=texture.region; var image:=texture.get_image()
			expect(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(region) and region.position==region.position.floor() and region.size==region.size.floor() and texture.filter_clip,"whole integer region clips neighboring atlas objects: %s %d"%[kind,level])
			expect(transparent_border(image),"selected sprite has four transparent padded edges: %s %d"%[kind,level])
			var destination:Rect2=Visual.destination(kind,anchor,level)
			expect(is_equal_approx(destination.end.y,anchor.y) and is_equal_approx(destination.get_center().x,anchor.x) and is_equal_approx(destination.size.x/destination.size.y,region.size.x/region.size.y),"full silhouette preserves proportions and ground pivot: %s %d"%[kind,level])
			expect(game.InteriorRenderer.is_foreground_prop(kind,anchor,anchor-Vector2(0,20)) and not game.InteriorRenderer.is_foreground_prop(kind,anchor,anchor+Vector2(0,20)),"all levels use normal hero/furniture depth: "+kind)
		game.player=room.spawn
		for waypoint in [Vector2(point.x,room.spawn.y),point]:
			for _step in 100:
				if game.player.distance_to(waypoint)<0.1: break
				game.NavigationSystem.move(game,game.player.direction_to(waypoint)*minf(6,game.player.distance_to(waypoint)))
		expect(game.player.distance_to(point)<0.1,"actual movement reaches new station from room entrance: "+kind)
	game.free()

## Проверяет весь периметр ресурса по видимому альфа-порогу, исключая обрезанные предметы и соседние детали.
func transparent_border(image: Image) -> bool:
	if image==null or image.is_empty(): return false
	for x in image.get_width():
		if image.get_pixel(x,0).a>=8.0/255.0 or image.get_pixel(x,image.get_height()-1).a>=8.0/255.0: return false
	for y in image.get_height():
		if image.get_pixel(0,y).a>=8.0/255.0 or image.get_pixel(image.get_width()-1,y).a>=8.0/255.0: return false
	return true

## Открывает реальную станцию обычным контекстным действием и отключает только вступительный сценарий стенда.
func station(game: Node, kind: String) -> void:
	var data:Dictionary=Workshop.Data.STATIONS[kind]; game.current_location=data.location; game.player=data.point
	expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false)=="walkable","workshop has a real walkable operating point: "+kind)
	expect(game.nearest_interaction()=="interior_service:"+kind and game.perform_context_action() and game.crafting_station==kind,"ordinary context opens distinct workshop: "+kind)
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0; game.tutorial_visible=false

## Находит общую производственную запись по постоянному идентификатору.
func recipe_index(game: Node, id: String) -> int:
	return game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")==id)

## Выполняет одну технологию настоящим списанием, загрузкой топлива и завершением, не выдавая её выход напрямую.
func produce(game: Node, id: String) -> bool:
	var recipe:Dictionary=Workshop.Data.Recipes.recipe(id); var kind:String=recipe.get("station","workbench")
	if Workshop.handles(kind):
		var data:Dictionary=Workshop.Data.STATIONS[kind]; game.current_location=data.location; game.player=data.point; game.open_crafting(kind)
	else: game.current_location="forge_interior"; game.player=game.FurnaceSystem.STATION; game.open_crafting(kind)
	game.energy=12
	if kind=="furnace":
		game.FurnaceSystem.state(game).fuel="coal"
		if game.FurnaceSystem.state(game).heat<float(recipe.seconds): game.FurnaceSystem.load_fuel(game)
	elif kind=="glassblowing":
		Workshop.state(game,kind).fuel="coal"
		if Workshop.state(game,kind).heat<float(recipe.seconds): Workshop.load_fuel(game)
	if not game.CraftingSystem.craft(game,recipe_index(game,id)): return false
	if kind=="furnace": game.FurnaceSystem.update(game,60)
	else: Workshop.update(game,60)
	return true

## Сценарий: материалы зарегистрированы и глина реально добывается у доступных источников.
## Исходное состояние: чистая модель, кирка и две новые жилы в каменистой области.
## Ожидаемый результат: двадцать восемь иконок существуют, добыча и три контекстных точки работают.
func test_materials_sources_and_real_stations() -> void:
	var game:=make_game()
	expect(Workshop.Data.ITEMS.size()==28 and Workshop.Data.Recipes.RECIPES.size()==37,"three workshops add twenty-eight materials and thirty-seven actual technologies")
	for kind in Workshop.Data.ITEMS: expect(game.VisualAssetSystem.has_item_icon(kind) and game.InventorySystem.ITEM_DATA.has(kind),"workshop material has actual cached icon and inventory count: "+kind)
	game.current_location="rocky"; game.has_pickaxe=true; game.selected_tool=game.Tool.PICKAXE
	for spawn in Workshop.Data.SPAWNS:
		var index:int=game.resource_nodes.find_custom(func(node): return node.kind==spawn.kind and node.position==spawn.position)
		var point:=Vector2.INF
		for direction in 16:
			var candidate:Vector2=spawn.position+Vector2(80,0).rotated(TAU*direction/16.0)
			if game.NavigationSystem.walkability_reason(game,candidate,-1,false)=="walkable": point=candidate; break
		expect(point!=Vector2.INF,"new clay deposit has a reachable mining approach")
		game.player=point; var before:int=game.inventory_item_count("clay")
		expect(index>=0 and game.ResourceSystem.mine(game,index) and game.inventory_item_count("clay")>before,"pickaxe actually provides workshop clay")
	for kind in Workshop.Data.STATIONS: station(game,kind)
	game.free()

## Сценарий: лесопилка резервирует сырьё и энергию, затем выдаёт доски и весь побочный выход.
## Исходное состояние: первый уровень, одно бревно и двенадцать энергии, остальные очереди пусты.
## Ожидаемый результат: сырьё списано сразу, результат отложен, окно приостанавливает время, партия завершается единожды.
func test_queue_atomic_energy_pause_and_outputs() -> void:
	var game:=make_game(); station(game,"sawmill"); game.change_inventory_count("log",2); var index:=recipe_index(game,"sawmill:planks")
	game.energy=0; var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(not game.CraftingSystem.craft(game,index) and game.export_inventory_counts()==before,"insufficient energy refuses a workshop batch before any material debit")
	game.energy=12; expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count("log")==1 and game.inventory_item_count("plank")==0 and game.energy==11,"sawmill spends one log and energy without instant output")
	before=game.export_inventory_counts().duplicate(); var energy:float=game.energy
	expect(not game.CraftingSystem.craft(game,index) and game.export_inventory_counts()==before and game.energy==energy,"full workshop queue refuses atomically")
	var minutes:float=game.game_minutes; game._physics_process(30)
	expect(Workshop.state(game,"sawmill").queue[0].remaining==8 and game.game_minutes==minutes and game.energy==energy,"actual crafting menu pauses all production and world time")
	game.crafting_open=false; game._physics_process(4)
	expect(is_equal_approx(Workshop.state(game,"sawmill").queue[0].remaining,4),"ordinary GameLoop advances the reserved job by actual active time")
	game._physics_process(4)
	expect(game.inventory_item_count("plank")==4 and game.inventory_item_count("sawdust")==2 and Workshop.state(game,"sawmill").completed==1,"completion grants exact planks plus sawdust once")
	Workshop.update(game,100); expect(game.inventory_item_count("plank")==4,"idle update cannot duplicate a completed production batch")
	game.free()

## Сценарий: каждый из трёх станков независимо улучшается до третьего уровня.
## Исходное состояние: частичная партия и неполные материалы, затем выданы обе цены выбранного станка.
## Ожидаемый результат: отказ атомарен, точные цены списаны, доля готовности сохранена и другие станки не улучшены.
func test_all_three_upgrade_paths() -> void:
	for kind in Workshop.Data.STATIONS:
		var game:=make_game(); station(game,kind); game.coins=1000; game.energy=12
		var recipe:Dictionary=Workshop.Data.Recipes.RECIPES.filter(func(value): return value.get("station","")==kind)[0]
		for item in recipe.inputs: game.change_inventory_count(item,int(recipe.inputs[item]))
		expect(game.CraftingSystem.craft(game,recipe_index(game,recipe.id)),"first-level job starts before upgrades: "+kind)
		if kind=="glassblowing": Workshop.state(game,kind).heat=100
		Workshop.update(game,2); var job:Dictionary=Workshop.state(game,kind).queue[0]; var fraction:float=float(job.remaining)/float(job.duration)
		var before:Dictionary=game.export_inventory_counts().duplicate(); var coins:int=game.coins
		expect(not Workshop.upgrade(game,kind) and game.export_inventory_counts()==before and game.coins==coins,"incomplete upgrade cost refuses atomically: "+kind)
		var total:=0
		for cost in Workshop.Data.STATIONS[kind].upgrades:
			for item in cost.inputs: game.change_inventory_count(item,int(cost.inputs[item]))
			total+=int(cost.coins); expect(Workshop.upgrade(game,kind),"declared workshop upgrade succeeds: "+kind)
			job=Workshop.state(game,kind).queue[0]
			expect(is_equal_approx(float(job.remaining)/float(job.duration),fraction),"upgrade accelerates queued work without changing its progress fraction")
		expect(Workshop.state(game,kind).level==3 and game.coins==1000-total and not Workshop.upgrade(game,kind),"maximum level and exact upgrade coins are preserved: "+kind)
		for other in Workshop.Data.STATIONS:
			if other!=kind: expect(Workshop.state(game,other).level==1,"upgrading one workshop does not change another: "+other)
		game.free()

## Сценарий: все технологии имеют настоящий отложенный выход и собственный порог уровня.
## Исходное состояние: сырьё каждой партии выдано отдельно, ремесленные бонусы активны.
## Ожидаемый результат: двадцать восемь станочных и шесть обжиговых технологий дают точные изделия без удвоения и скидки.
func test_every_production_and_firing_recipe() -> void:
	for recipe in Workshop.Data.Recipes.RECIPES:
		if not Workshop.handles(String(recipe.get("station",""))) and recipe.get("station","")!="furnace": continue
		var game:=make_game(); game.talent_levels.craft_efficient=3; game.talent_levels.craft_master=1; game.energy=12
		var kind:String=recipe.station
		if Workshop.handles(kind): station(game,kind)
		else: game.current_location="forge_interior"; game.player=game.FurnaceSystem.STATION; game.open_crafting("furnace")
		for item in recipe.inputs: game.change_inventory_count(item,int(recipe.inputs[item]))
		if recipe.has("study_kind"): game.ResearchSystem.state(game).known.append(recipe.study_kind)
		var level:int=recipe.get("workshop_level",recipe.get("furnace_level",1)); var index:=recipe_index(game,recipe.id)
		if level>1: expect(not game.CraftingSystem.craft(game,index),"advanced production requires actual station level: "+recipe.id)
		if Workshop.handles(kind): Workshop.state(game,kind).level=level
		else: game.FurnaceSystem.state(game).level=level
		var before:Dictionary=game.export_inventory_counts().duplicate(); var counter:int=game.state.player.profile.get("workbench_crafts",game.state.player.craft_count)
		expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count(recipe.output)==int(before[recipe.output]),"production output is deferred: "+recipe.id)
		for item in recipe.inputs: expect(game.inventory_item_count(item)==int(before[item])-int(recipe.inputs[item]),"production debits exact input despite talents: "+recipe.id+" / "+item)
		if kind=="glassblowing": Workshop.state(game,kind).heat=100
		if kind=="furnace": game.FurnaceSystem.state(game).heat=100; game.FurnaceSystem.update(game,100)
		else: Workshop.update(game,100)
		expect(game.inventory_item_count(recipe.output)==int(before[recipe.output])+int(recipe.count),"exact completed production without master double output: "+recipe.id)
		for item in recipe.get("byproducts",{}): expect(game.inventory_item_count(item)==int(before[item])+int(recipe.byproducts[item]),"all sawdust byproduct is actually delivered")
		expect(game.state.player.profile.workbench_crafts==counter,"production never advances the workbench bonus counter")
		game.free()

## Сценарий: стеклодув использует собственное топливо и возобновляет частичную партию.
## Исходное состояние: партия стекла, затем одна энергия жара и отдельный запас кузнечного горна.
## Ожидаемый результат: без жара работа ждёт, дозагрузка продолжает её, простой и переполнение не тратят топливо.
func test_glass_fuel_isolation_and_resume() -> void:
	var game:=make_game(); station(game,"glassblowing"); game.change_inventory_count("glass",2); game.change_inventory_count("coal",2)
	game.FurnaceSystem.state(game).heat=72; game.CraftingSystem.craft(game,recipe_index(game,"glassblowing:bottle")); Workshop.update(game,100)
	expect(Workshop.state(game,"glassblowing").queue[0].remaining==8 and game.FurnaceSystem.state(game).heat==72,"glassblower cannot steal the independent furnace heat reserve")
	Workshop.state(game,"glassblowing").heat=1; Workshop.update(game,100)
	expect(Workshop.state(game,"glassblowing").queue[0].remaining==7 and game.inventory_item_count("glass_bottle")==0,"empty heat stops partially completed glass without awarding an item")
	Workshop.state(game,"glassblowing").fuel="coal"; expect(Workshop.load_fuel(game),"glassblower loads actual coal at its station")
	Workshop.update(game,7); expect(game.inventory_item_count("glass_bottle")==1 and Workshop.state(game,"glassblowing").queue.is_empty(),"refilled glass work resumes and completes exactly once")
	var heat:float=Workshop.state(game,"glassblowing").heat; Workshop.update(game,100)
	expect(Workshop.state(game,"glassblowing").heat==heat,"idle glassblower preserves its fuel reserve")
	Workshop.state(game,"glassblowing").heat=119; var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Workshop.load_fuel(game) and game.export_inventory_counts()==before,"overfull reserve refuses an entire fuel portion")
	station(game,"sawmill"); expect(not Workshop.load_fuel(game),"nonthermal station does not consume coal")
	game.free()

## Сценарий: цены улучшения обеспечиваются продукцией уже доступного предыдущего уровня.
## Исходное состояние: выданы базовые доски, глина, металл, химические основы и топливо; продвинутых изделий нет.
## Ожидаемый результат: брусья, кирпичи, глазурь, прозрачное стекло и линза производятся до требующего их улучшения.
func test_linked_upgrade_progression() -> void:
	var game:=make_game(); game.coins=3000
	var raw:Dictionary={"log":10,"plank":40,"nails":24,"clay":30,"clean_water":30,"sand":24,"glass":20,"coal":20,"metal":30,"stone":30,"steel":12,"mineral_base":4,"distilled_water":6,"arcane_dust":4}
	for item in raw: game.change_inventory_count(item,int(raw[item]))
	for _batch in 4: expect(produce(game,"sawmill:beam"),"level-one sawmill supplies its own first upgrade beams")
	station(game,"sawmill"); expect(Workshop.upgrade(game,"sawmill"),"sawmill reaches second level from genuinely produced beams")
	for _batch in 4: produce(game,"sawmill:beam")
	for _batch in 2: expect(produce(game,"sawmill:frame") and produce(game,"sawmill:dowels"),"second-level wood production supplies frames and dowels")
	station(game,"sawmill"); expect(Workshop.upgrade(game,"sawmill"),"sawmill reaches third level without requiring a third-level product")
	for _batch in 4:
		produce(game,"pottery:clay"); produce(game,"pottery:brick"); produce(game,"pottery:brick"); expect(produce(game,"kiln:brick"),"first-level clay forms are genuinely fired before use as bricks")
	station(game,"pottery"); expect(Workshop.upgrade(game,"pottery"),"pottery second level needs only baseline materials")
	produce(game,"pottery:glaze"); produce(game,"pottery:glaze"); station(game,"pottery")
	expect(Workshop.upgrade(game,"pottery"),"pottery reaches third level using its second-level glaze and fired bricks")
	produce(game,"pottery:clay"); produce(game,"pottery:brick"); produce(game,"pottery:brick")
	for _batch in 3: expect(produce(game,"kiln:brick"),"all six glassblower upgrade bricks are actually fired")
	station(game,"glassblowing"); expect(Workshop.upgrade(game,"glassblowing"),"glassblower second level is reachable with fired pottery and baseline glass")
	expect(produce(game,"glassblowing:clear") and produce(game,"glassblowing:lens"),"optical lens is genuinely available at second glassblower level")
	expect(game.inventory_item_count("optical_lens")==1 and game.ResearchSystem.Data.UPGRADES[1].inputs.optical_lens==1,"research third-level upgrade uses a real second-level lens without circular unlock")
	for _batch in 4: expect(produce(game,"sawmill:beam"),"unlocked sawmill continues supplying glassblower frame parts")
	for _batch in 2: expect(produce(game,"sawmill:frame") and produce(game,"glassblowing:clear"),"second-level technologies produce the complete final glassblower price")
	station(game,"glassblowing"); expect(Workshop.upgrade(game,"glassblowing"),"third glassblower level does not require its own third-level products")
	produce(game,"sawmill:planks"); game.current_location="guild_interior"; game.player=game.ResearchSystem.STUDY_POINT
	expect(game.ResearchSystem.upgrade(game) and game.ResearchSystem.upgrade(game),"real lens supports both research desk upgrades without a circular gate")
	game.free()

## Сценарий: бутылки и керамика входят в реальные рецепты исследовательских расходников и пищи.
## Исходное состояние: исходные продукты и сосуды выданы, ремесленные таланты активны.
## Ожидаемый результат: расход точный, чернила не удваиваются, готовые блюда сохраняют прежние пищевые свойства.
func test_vessels_support_cooking_and_research() -> void:
	var game:=make_game(); game.talent_levels.craft_efficient=3; game.talent_levels.craft_master=1; game.talent_levels.farm_cooking=1
	for id in ["workshop:ink","workshop:porridge","workshop:jam"]:
		var recipe:Dictionary=Workshop.Data.Recipes.recipe(id); game.open_crafting(recipe.get("station","workbench"))
		for item in recipe.inputs: game.change_inventory_count(item,int(recipe.inputs[item]))
		var before:Dictionary=game.export_inventory_counts().duplicate(); game.state.player.profile.workbench_crafts=4
		expect(game.CraftingSystem.craft(game,recipe_index(game,id)) and game.inventory_item_count(recipe.output)==int(before[recipe.output])+int(recipe.count),"vessel recipe grants exact undoubled output: "+id)
		for item in recipe.inputs: expect(game.inventory_item_count(item)==int(before[item])-int(recipe.inputs[item]),"vessel recipe debits actual pottery or glass packaging: "+item)
		if id!="workshop:ink": expect(game.InventorySystem.can_use(recipe.output) and not game.ItemPresentationSystem.effect_text(game,recipe.output).is_empty(),"served products remain actual edible items with known effects")
	game.free()

## Сценарий: длинный список и управление используют общую геометрию, незавершённые очереди сохраняются в файл.
## Исходное состояние: третья лесопилка имеет четыре бревна, затем частичную очередь; меню меняет выбор и топливо.
## Ожидаемый результат: три партии ограничены очередью и энергией, footer не выбирает скрытый рецепт, загрузка не списывает сырьё повторно.
func test_controls_geometry_and_save() -> void:
	var game:=make_game(); station(game,"sawmill"); Workshop.state(game,"sawmill").level=3; game.change_inventory_count("log",4); game.energy=2
	var index:=recipe_index(game,"sawmill:planks")
	expect(game.CraftingSystem.craft_many(game,index,99)==2 and game.inventory_item_count("log")==2 and game.energy==0,"batch queue is limited by upfront energy as well as slots")
	expect(game.message==game.LocaleSystem.ui("furnace_queued_many",[2]),"batch message accurately describes deferred queued work")
	expect(game.CraftingSystem.recipe_at(game,Vector2(300,521))==-1,"footer cannot select a hidden recipe below seven visible rows")
	Workshop.update(game,1); var duration:float=Workshop.state(game,"sawmill").queue[0].remaining
	var path:="/private/tmp/farm-workshops-save-%d.json"%Time.get_ticks_usec()
	expect(game.SaveSystem.save_at(game,path),"workshops write a real validated disk save")
	var restored:=make_game(); expect(restored.SaveSystem.load_at(restored,path) and Workshop.state(restored,"sawmill").queue.size()==2 and is_equal_approx(Workshop.state(restored,"sawmill").queue[0].remaining,duration),"partial duration and two reserved jobs survive disk loading")
	Workshop.update(restored,100); expect(restored.inventory_item_count("plank")==8 and restored.inventory_item_count("sawdust")==4 and restored.inventory_item_count("log")==2,"loaded reserved jobs finish without paying or granting twice")
	var unchanged:Dictionary=restored.SaveSystem.snapshot(restored); var broken:Dictionary=unchanged.duplicate(true)
	broken.estate.expansion.workshops.sawmill.queue=[{"id":"sawmill:planks","duration":8,"remaining":"bad"}]
	expect(not restored.SaveSystem.apply(restored,broken) and restored.SaveSystem.snapshot(restored)==unchanged,"malformed production queue is rejected atomically")
	station(game,"glassblowing"); game.change_inventory_count("coal",1); game.crafting_selected=recipe_index(game,"glassblowing:vials")
	game.handle_crafting_input(key_event(KEY_Q,KEY_Q,true)); expect(Workshop.state(game,"glassblowing").fuel=="log","glassblower keyboard cycles its own fuel")
	game.handle_crafting_input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true)); expect(Workshop.state(game,"glassblowing").fuel=="coal","glassblower gamepad cycles to coal")
	game.ItemWindowRenderer.handle_crafting_pointer(game,preload("res://scripts/presentation/workshop_renderer.gd").LoadButton.get_center())
	expect(Workshop.state(game,"glassblowing").heat==36,"touch loads one fuel portion without enqueuing an unrelated recipe")
	var legacy:Dictionary=unchanged.duplicate(true); legacy.estate.expansion.erase("workshops"); legacy.resource_hits.resize(restored.resource_nodes.size()-Workshop.Data.SPAWNS.size())
	expect(restored.SaveSystem.apply(restored,legacy) and Workshop.state(restored,"sawmill").level==1 and Workshop.state(restored,"sawmill").queue.is_empty() and restored.resource_nodes.back().hits==8,"old save initializes empty level-one workshops and restores absent clay source stock")
	DirAccess.remove_absolute(path); game.free(); restored.free()
