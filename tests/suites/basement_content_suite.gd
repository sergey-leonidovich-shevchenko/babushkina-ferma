extends "res://tests/suites/basement_suite.gd"

const Art := preload("res://scripts/presentation/basement_visual_system.gd")

## Проверяет все виды, все ступени улучшений, независимое тепло, сенсорный ввод и модульный художественный каталог.
func run() -> void:
	test_all_kinds_costs_tiers_and_sprites()
	test_two_furnaces_and_glassblower_are_independent()
	test_touch_rotation_pagination_and_hold_release()
	test_duplicate_approaches_and_queue_save()

## Сценарий: каждый из десяти видов строится первым уровнем и улучшается двумя отдельными работами.
## Исходное состояние: свободный пол, точная стоимость, энергия выдаётся по секунде для каждой стадии.
## Ожидаемый результат: уровни, журнал, расход и все 160 прозрачных ракурсов согласованы, переводы доступны на шести языках.
func test_all_kinds_costs_tiers_and_sprites() -> void:
	var game:=make_game(); enter(game)
	for kind in Basement.Data.STATIONS:
		var spec:Dictionary=Basement.Data.STATIONS[kind]
		expect(game.InventorySystem.ITEM_DATA.has(spec.icon),"blueprint uses a real item icon: "+kind)
		for material in spec.inputs: expect(game.InventorySystem.ITEM_DATA.has(material),"construction cost is obtainable: "+material)
		var item:=place(game,kind,30,18); finish(game,item)
		for target in [2,3]:
			game.player=Basement.Data.BOARD; Basement.open(game); game.coins=1000
			var cost:=Basement.Data.upgrade_cost(kind,target-1); var coins:int=game.coins
			for material in cost.inputs: game.change_inventory_count(material,int(cost.inputs[material]))
			expect(Build.upgrade(game,item.id) and game.coins==coins-int(cost.coins),"specific tier reserves exact costs before assembly: %s %d"%[kind,target])
			game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id)
			var seconds:=int(item.duration); var energy:=int(item.energy)
			for second in seconds:
				game.energy=energy; Build.update_hold(game,1); expect(game.energy==0,"one whole second spends exactly its difficulty: %s %d"%[kind,target])
			expect(item.level==target and item.phase=="ready" and item.production.level==target,"assembly updates only the chosen tier: %s %d"%[kind,target])
		game.player=Basement.Data.BOARD; Basement.open(game)
		expect(not Build.upgrade(game,item.id),"fourth tier cannot spend resources")
		expect(Build.dismantle(game,item.id),"all ten kinds can be dismantled")
		for direction in 4:
			for tier in range(1,5):
				var texture:=Art.texture(kind,mini(tier,3),direction,tier==4)
				var source:=texture.atlas.get_image(); var region:Rect2=texture.region
				expect(region.position.x>=0 and region.position.y>=0 and Rect2(Vector2.ZERO,source.get_size()).encloses(region),"sprite is an independent complete source region: %s %d %d"%[kind,tier,direction])
				var count:=0
				for corner in [region.position,region.position+Vector2(region.size.x-1,0),region.end-Vector2.ONE,region.position+Vector2(0,region.size.y-1)]:
					if source.get_pixelv(Vector2i(corner)).a<0.07: count+=1
				expect(count==4,"region corners preserve transparent gutters: %s %d %d"%[kind,tier,direction])
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for kind in Basement.Data.STATIONS: expect(preload("res://scripts/systems/basement_locale.gd").name_for(game,kind)!=kind,"station name translated: "+locale+" "+kind)
		for key in preload("res://scripts/systems/basement_locale.gd").TUTORIAL: expect(game.LocaleSystem.tutorial(key)!=key,"construction teaching translated: "+locale+" "+key)
	game.free()

## Сценарий: два личных горна и стеклодув одновременно плавят разные партии на собственном топливе.
## Исходное состояние: три построенных станка, одна партия железа, одна партия меди и стеклянная бутылка.
## Ожидаемый результат: локальный выбор не меняет соседнее тепло или общедоступный горн, двойного продвижения нет.
func test_two_furnaces_and_glassblower_are_independent() -> void:
	var game:=make_game(); enter(game)
	var left:=place(game,"furnace",25,18); finish(game,left)
	var right:=place(game,"furnace",40,18); finish(game,right)
	var glass:=place(game,"glassblowing",55,18); finish(game,glass)
	var entries:=[left,right,glass]; var ids:=["furnace:ore","furnace:scrap","glassblowing:bottle"]
	for index in entries.size():
		var item:Dictionary=entries[index]; game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id)
		var recipe_index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")==ids[index])
		expect(recipe_index>=0,"independent heat scenario refers to an actual recipe")
		if recipe_index<0: continue
		var recipe:Dictionary=game.CraftingSystem.RECIPES[recipe_index]
		for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material]))
		game.change_inventory_count("coal",2); game.energy=12; item.production.fuel="coal"
		expect(game.FurnaceSystem.load_fuel(game) if item.kind=="furnace" else game.WorkshopSystem.load_fuel(game),"fuel targets the selected physical instance")
		expect(game.CraftingSystem.craft(game,recipe_index),"recipe targets its selected physical instance")
	game.crafting_open=false
	var before:Array=entries.map(func(item): return item.production.queue[0].remaining)
	var public_heat:float=game.FurnaceSystem.legacy_state(game).heat
	game.FurnaceSystem.update(game,1); game.WorkshopSystem.update(game,1); Production.update(game,1)
	for index in entries.size(): expect(is_equal_approx(entries[index].production.queue[0].remaining,before[index]-1),"one world second advances one independent job exactly once")
	expect(game.FurnaceSystem.legacy_state(game).heat==public_heat,"personal fueling does not leak into the public furnace")
	game.free()

## Сценарий: касание выбирает последние строки, поворачивает основание и отпускает только свой строительный жест.
## Исходное состояние: полный каталог десяти видов и недострой в мастерской.
## Ожидаемый результат: доступен весь каталог, три поворота замыкаются, отмена ничего не списывает и чужой палец не прерывает работу.
func test_touch_rotation_pagination_and_hold_release() -> void:
	var game:=make_game(); enter(game); Basement.open(game)
	Controls.handle_input(game,touch(1,Controls.PAGES[1].get_center(),true))
	expect(int(Basement.ui(game).selected)==8,"touch paging reaches the ninth and tenth stations")
	Controls.execute(game); var counts:Dictionary=game.export_inventory_counts().duplicate()
	for direction in 3: Controls.handle_input(game,touch(1,Controls.PLACE_BUTTONS[1].get_center(),true))
	expect(int(Basement.ui(game).direction)==0,"three touch rotations return to the same physical orientation")
	Basement.ui(game).pointer=Vector2(1150,320); var motion:=InputEventMouseMotion.new(); motion.position=Vector2(600,620)
	Controls.handle_input(game,motion); var camera_before:Vector2=game.camera_offset; Controls.update(game,1)
	expect(game.camera_offset==camera_before and Basement.ui(game).pointer==Vector2.ZERO,"moving from an edge onto the toolbar immediately stops camera panning")
	Controls.handle_input(game,touch(1,Controls.PLACE_BUTTONS[3].get_center(),true))
	expect(not Basement.modal(game) and game.export_inventory_counts()==counts,"touch cancel never reserves construction materials")
	var item:=place(game,"pottery",30,18); game.player=Basement.Layout.center(Basement.Layout.approach_cell(item))
	Controls.handle_input(game,touch(4,Controls.HOLD.get_center(),true)); Build.update_hold(game,0.5)
	Controls.handle_input(game,touch(3,Controls.HOLD.get_center(),false)); expect(int(Basement.ui(game).holding)==item.id,"a different finger cannot release the held construction")
	game.inventory_open=true; Controls.handle_input(game,touch(4,Controls.HOLD.get_center(),false)); game.inventory_open=false
	Build.update_hold(game,3); expect(item.work==0.5 and int(Basement.ui(game).holding)==0,"own release is processed even while the world is paused")
	game.free()

## Сценарий: два рабочих подхода не совпадают, а реальные производственные заготовки переживают диск и демонтаж.
## Исходное состояние: встречные станки с одной точкой и личная очередь распила с оплаченным бревном.
## Ожидаемый результат: неоднозначный подход запрещён, сохранённая очередь возвращает своё сырьё один раз.
func test_duplicate_approaches_and_queue_save() -> void:
	var one:=plan("pottery",30,18); var two:=plan("pottery",30,25,2)
	expect(Basement.Layout.reason([one],two)=="basement_approach","two opposite desks cannot hide behind the same interaction point")
	var game:=make_game(); enter(game); var item:=place(game,"sawmill",25,18); finish(game,item); Stations.interact(game,item.id)
	game.change_inventory_count("log",1); var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="sawmill:planks")
	expect(game.CraftingSystem.craft(game,index),"real saved job reserves its inputs")
	game.crafting_open=false; Production.update(game,2)
	var path:=OS.get_temp_dir().path_join("farm-basement-queue-%d.json" % Time.get_ticks_usec())
	expect(game.SaveSystem.save_at(game,path),"private queue writes a validated disk save")
	var restored:=make_game(); expect(restored.SaveSystem.load_at(restored,path),"private queue loads from a real disk save")
	var loaded:=Basement.object(restored,item.id)
	expect(loaded.production.queue[0].remaining==6 and loaded.production.queue[0].paid.log==1,"remaining time and exact reserved raw material survive serialization")
	restored.player=Basement.Data.BOARD; Basement.open(restored); var logs:int=restored.inventory_item_count("log")
	Build.dismantle(restored,item.id); expect(restored.inventory_item_count("log")==logs+1,"cancelled saved production refunds its own log once")
	DirAccess.remove_absolute(path); game.free(); restored.free()

## Создаёт один сенсорный жест с настоящим индексом пальца.
func touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event:=InputEventScreenTouch.new(); event.index=index; event.position=position; event.pressed=pressed; return event
