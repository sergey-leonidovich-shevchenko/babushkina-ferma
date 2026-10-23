extends "res://tests/suites/suite_base.gd"

const Research := preload("res://scripts/systems/research_system.gd")
const Renderer := preload("res://scripts/presentation/research_renderer.gd")

## Запускает наблюдаемые сценарии изучения, разборки, повторной сборки и постоянных знаний.
func run() -> void:
	test_catalog_and_station_context()
	test_study_preserves_sample_and_atomic_cost()
	test_three_levels_and_complexity()
	test_all_actual_dismantling_outputs()
	test_equipped_worn_and_batch_items()
	test_recovered_recipes_and_material_loss()
	test_glass_furnace_and_pause()
	test_controls_and_real_save()

## Находит устойчивый индекс исследуемого вида, независимо от имеющихся вещей.
func entry_index(kind: String) -> int:
	return Research.Data.ENTRIES.find_custom(func(entry): return entry.kind==kind)

## Открывает нужную станцию реальным контекстным действием в игровой модели.
func station(game: Node, mode: String) -> void:
	game.current_location="guild_interior" if mode=="study" else "forge_interior"
	game.player=Research.STUDY_POINT if mode=="study" else Research.BENCH_POINT
	expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false)=="walkable","research station approach is walkable: "+mode)
	expect(game.nearest_interaction()=="interior_service:"+mode and game.perform_context_action() and game.crafting_station==mode,"ordinary context opens the correct research station: "+mode)
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.tutorial_visible=false

## Добавляет только расходники стенда, оставляя правила списания реальным действиям.
func supplies(game: Node) -> void:
	game.coins=1000; game.energy=12
	game.change_inventory_count("research_paper",100); game.change_inventory_count("research_ink",100)

## Сценарий: все исследуемые виды и компоненты существуют, обе станции открываются обычным действием.
## Исходное состояние: новая модель с неизменными прежними предметами и сервисами комнат.
## Ожидаемый результат: тридцать видов и шесть материалов зарегистрированы, знания не подменяют обычные рецепты.
func test_catalog_and_station_context() -> void:
	var game:=make_game()
	expect(Research.Data.BASE_ENTRIES.size()==30 and Research.Data.ENTRIES.size()>=30 and Research.Data.ITEMS.size()==6,"research keeps thirty historical types and six real component or supply items")
	expect(Research.validation_errors(game.InventorySystem.ITEM_DATA).is_empty(),"research outputs and blueprint gates reference valid canonical items")
	for kind in Research.Data.ITEMS: expect(game.VisualAssetSystem.has_item_icon(kind),"research material has an actual cached texture: "+kind)
	station(game,"study"); expect(game.CraftingSystem.visible_indices(game).size()==Research.Data.ENTRIES.size(),"research opens its own complete item catalog without fake crafting recipes")
	station(game,"recycling"); game.free()

## Сценарий: изучение один раз раскрывает состав вида и не уничтожает образец.
## Исходное состояние: две доски, расходники и деньги выданы; затем отдельные требования убираются.
## Ожидаемый результат: оплачивается ровно одна попытка, повтор и отсутствие требований не меняют ресурсы или знания.
func test_study_preserves_sample_and_atomic_cost() -> void:
	var game:=make_game(); station(game,"study"); game.change_inventory_count("plank",2)
	var index:=entry_index("plank"); var initial:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Research.execute(game,index) and game.export_inventory_counts()==initial and Research.state(game).known.is_empty(),"missing study supplies refuse atomically")
	supplies(game); var coins:int=game.coins; var paper:int=game.inventory_item_count("research_paper"); var xp:int=game.player_xp
	expect(game.CraftingSystem.craft_many(game,index,99)==1,"bulk study executes exactly one first discovery")
	expect(game.inventory_item_count("plank")==2 and game.inventory_item_count("research_paper")==paper-1 and game.coins==coins-5 and game.energy==9,"study preserves specimen and spends exact paper coins and energy")
	expect(Research.learned(game,"plank") and game.player_xp==xp+4,"first study unlocks permanent composition and awards discovery XP once")
	var counts:Dictionary=game.export_inventory_counts().duplicate(); coins=game.coins; var energy:float=game.energy
	expect(not Research.execute(game,index) and game.export_inventory_counts()==counts and game.coins==coins and game.energy==energy,"known type cannot be paid for twice")
	game.change_inventory_count("plank",-2)
	expect(Renderer.payload(game,Research.Data.entry("plank")).contains(game.inventory_item_name("wood_offcut")),"composition remains visible after the sample leaves the bag")
	var minutes:float=game.game_minutes; var day:int=game.day; game._physics_process(60)
	expect(game.game_minutes==minutes and game.day==day and game.energy==energy,"research window pauses actual world time and energy updates")
	for kind in ["ancient_key","moon_relic","eclipse_core"]: expect(entry_index(kind)<0,"story relic cannot be accidentally dismantled: "+kind)
	game.free()

## Сценарий: сложность изучения ограничена двумя последовательными улучшениями стола.
## Исходное состояние: есть образцы второго и третьего класса, но первый уровень и неполная цена улучшения.
## Ожидаемый результат: недоступные изучения и улучшения атомарны, уровни ограничены тремя, цена полностью списана.
func test_three_levels_and_complexity() -> void:
	var game:=make_game(); station(game,"study"); supplies(game); game.change_inventory_count("iron_helmet",1); game.change_inventory_count("crystal",1)
	var counts:Dictionary=game.export_inventory_counts().duplicate(); var coins:int=game.coins
	expect(not Research.execute(game,entry_index("iron_helmet")) and game.export_inventory_counts()==counts and game.coins==coins,"first desk cannot study equipment despite sufficient supplies")
	expect(not Research.upgrade(game) and game.export_inventory_counts()==counts and game.coins==coins,"incomplete upgrade costs leave every material untouched")
	for cost in Research.Data.UPGRADES:
		for kind in cost.inputs: game.change_inventory_count(kind,int(cost.inputs[kind]))
		expect(Research.upgrade(game),"declared desk upgrade succeeds with its full material price")
		if Research.state(game).level==2: expect(Research.execute(game,entry_index("iron_helmet")) and not Research.execute(game,entry_index("crystal")),"second level unlocks equipment but keeps crystals locked")
	game.energy=12
	expect(Research.state(game).level==3 and game.coins==565 and not Research.upgrade(game),"third level spends two upgrade costs plus one equipment discovery and cannot upgrade further")
	expect(Research.execute(game,entry_index("crystal")),"third desk genuinely studies a crystal sample")
	station(game,"recycling"); counts=game.export_inventory_counts().duplicate()
	expect(not Research.upgrade(game) and game.export_inventory_counts()==counts,"dismantling bench cannot remotely upgrade the guild desk")
	game.free()

## Сценарий: каждая каноническая разборка списывает полную партию и выдаёт только заявленные составляющие.
## Исходное состояние: изучены все виды, отдельные образцы выданы по очереди на разборочный верстак.
## Ожидаемый результат: все тридцать выходов совпадают с каталогом, нехватка знаний или образца запрещает действие.
func test_all_actual_dismantling_outputs() -> void:
	var game:=make_game(); station(game,"recycling"); game.change_inventory_count("wooden_chair",1)
	var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Research.execute(game,entry_index("wooden_chair")) and game.export_inventory_counts()==before,"unresearched object cannot be broken for unknown parts")
	for entry in Research.Data.ENTRIES:
		Research.state(game).known.append(entry.kind); game.change_inventory_count(entry.kind,int(entry.batch)); game.energy=12
		var sample:int=game.inventory_item_count(entry.kind); before=game.export_inventory_counts().duplicate()
		expect(Research.execute(game,entry_index(entry.kind)) and game.inventory_item_count(entry.kind)==sample-int(entry.batch),"dismantling spends exact sample batch: "+entry.kind)
		for kind in entry.parts: expect(game.inventory_item_count(kind)==int(before[kind])+int(entry.parts[kind]),"dismantling returns exact part: "+entry.kind+" -> "+kind)
	expect(Research.state(game).dismantled==Research.Data.ENTRIES.size(),"all canonical kinds completed through the actual operation")
	game.free()

## Сценарий: снятие и износ экипировки меняют доступность и выход, мелкие предметы разбираются партиями.
## Исходное состояние: копьё надето и заточено, затем снято и сломано; в рюкзаке двадцать гвоздей.
## Ожидаемый результат: надетое копьё не исчезает, износ уменьшает возврат, новые изделия не наследуют старую заточку.
func test_equipped_worn_and_batch_items() -> void:
	var game:=make_game(); station(game,"recycling"); Research.state(game).known=["iron_spear","nails"]
	game.change_inventory_count("iron_spear",1); game.InventorySystem.equip(game,"iron_spear"); game.state.forge.set_level("iron_spear",2); game.state.inventory.durability.iron_spear=0
	var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Research.execute(game,entry_index("iron_spear")) and game.export_inventory_counts()==before,"equipped weapon is protected from destruction")
	game.InventorySystem.equip(game,"iron_spear"); game.energy=12
	expect(Research.parts(game,Research.Data.entry("iron_spear"))=={"metal_scrap":2,"wood_offcut":1},"fully worn spear returns half its canonical recoverable parts")
	expect(Research.execute(game,entry_index("iron_spear")) and game.inventory_item_count("metal_scrap")==2 and game.state.forge.level("iron_spear")==0,"last dismantled weapon clears old sharpening without refunding upgrades")
	game.change_inventory_count("nails",20); var energy:float=game.energy
	expect(Research.bulk(game,entry_index("nails"),99)==2 and game.inventory_item_count("nails")==4 and game.energy==energy-4,"bulk dismantling uses complete eight-nail batches and exact energy only")
	game.free()

## Сценарий: открытые знания дают новые рецепты, но таланты не превращают переработку в бесконечный источник.
## Исходное состояние: ресурсы вторичной сборки выданы, знание сначала отсутствует, затем изучено; активны ремесленные таланты.
## Ожидаемый результат: все дополнительные рецепты требуют своё знание и используют точный расход без двойного выхода.
func test_recovered_recipes_and_material_loss() -> void:
	var game:=make_game(); game.crafting_station="workbench"; game.talent_levels.craft_efficient=3; game.talent_levels.craft_master=1; game.talent_levels.farm_cooking=1
	for recipe in Research.Data.RECIPES:
		if recipe.get("station","")=="furnace": continue
		for kind in recipe.inputs: game.change_inventory_count(kind,int(recipe.inputs[kind]))
		var index:int=game.CraftingSystem.RECIPES.find_custom(func(value): return value.get("id","")==recipe.id)
		if recipe.has("study_kind"):
			expect(not game.CraftingSystem.craft(game,index),"recovered recipe is locked until original type is studied: "+recipe.id)
			Research.state(game).known.append(recipe.study_kind)
		var before:int=game.inventory_item_count(recipe.output); var inputs:Dictionary=game.export_inventory_counts().duplicate(); game.state.player.profile.workbench_crafts=4
		expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count(recipe.output)==before+int(recipe.count),"recovered or supply recipe ignores master double output: "+recipe.id)
		for kind in recipe.inputs: expect(game.inventory_item_count(kind)==int(inputs[kind])-int(recipe.inputs[kind]),"recovered recipe ignores efficiency discounts: "+recipe.id+" / "+kind)
	for kind in ["cloth","wooden_chair","crystal"]:
		station(game,"recycling"); game.energy=12
		expect(Research.execute(game,entry_index(kind)),"actual recovered item can be dismantled after assembly: "+kind)
		game.crafting_station="workbench"
		var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("study_kind","")==kind and recipe.get("station","workbench")=="workbench")
		expect(not game.CraftingSystem.craft(game,index),"actual craft-dismantle cycle leaves too few parts to repeat even with master talents: "+kind)
	game.free()

## Сценарий: осколки переплавляются по открытому знанию через обычную сохраняемую очередь горна.
## Исходное состояние: три осколка и топливо, состав стекла сначала неизвестен, затем изучен.
## Ожидаемый результат: плавка не выдаёт стекло мгновенно, меню сохраняет паузу, десять активных секунд дают ровно один лист.
func test_glass_furnace_and_pause() -> void:
	var game:=make_game(); game.current_location="forge_interior"; game.player=game.FurnaceSystem.STATION; game.open_crafting("furnace")
	game.change_inventory_count("glass_shard",3); var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="recovery:glass")
	expect(not game.CraftingSystem.craft(game,index) and game.inventory_item_count("glass_shard")==3,"unlearned glass prevents a furnace enqueue without consuming shards")
	Research.state(game).known.append("glass"); game.FurnaceSystem.state(game).heat=20
	expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count("glass")==0,"glass recycling uses real deferred furnace output")
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	var day:int=game.day; var minutes:float=game.game_minutes; game.tutorial_visible=false; game._physics_process(30)
	expect(game.FurnaceSystem.state(game).queue[0].remaining==10 and game.day==day and game.game_minutes==minutes,"research-aware furnace keeps modal time paused")
	game.crafting_open=false; game.FurnaceSystem.update(game,10)
	expect(game.inventory_item_count("glass")==1 and game.tutorial_events_completed.has("study_reuse"),"recycled glass is granted exactly once after actual heating")
	game.free()

## Сценарий: клавиатура, геймпад и касание меняют выбор, знания и уровень переживают настоящий файл сохранения.
## Исходное состояние: стол открыт, бумаги и доски выданы; затем записан изученный вид и число разборок.
## Ожидаемый результат: выбор не расходует предмет, изучение работает, повреждённая память отклоняется атомарно.
func test_controls_and_real_save() -> void:
	var game:=make_game(); station(game,"study"); supplies(game); game.change_inventory_count("plank",2); game.crafting_selected=entry_index("plank")
	game.handle_crafting_input(key_event(KEY_DOWN,KEY_DOWN,true)); expect(game.crafting_selected==1,"keyboard research navigation selects another item without study")
	game.handle_crafting_input(joypad_button_event(JOY_BUTTON_DPAD_UP,true)); expect(game.crafting_selected==0,"gamepad returns to first study row")
	game.ItemWindowRenderer.handle_crafting_pointer(game,game.ItemWindowRenderer.CRAFT_ACTION.get_center())
	expect(Research.learned(game,"plank") and game.inventory_item_count("plank")==2,"touch study preserves the selected sample")
	var path:=OS.get_temp_dir().path_join("farm-research-save-%d.json" % Time.get_ticks_usec())
	Research.state(game).dismantled=7; expect(game.SaveSystem.save_at(game,path),"research writes a real validated disk save")
	var restored:=make_game(); expect(restored.SaveSystem.load_at(restored,path) and Research.state(restored).known==["plank"] and Research.state(restored).dismantled==7,"disk restores permanent research without charging the sample again")
	var unchanged:Dictionary=restored.SaveSystem.snapshot(restored); var broken:Dictionary=unchanged.duplicate(true); broken.estate.expansion.research.known=[9]
	expect(not restored.SaveSystem.apply(restored,broken) and restored.SaveSystem.snapshot(restored)==unchanged,"malformed known array is rejected before live state changes")
	var legacy:Dictionary=unchanged.duplicate(true); legacy.estate.expansion.erase("research")
	expect(restored.SaveSystem.apply(restored,legacy) and Research.state(restored).level==1 and Research.state(restored).known.is_empty(),"pre-research save initializes an empty level-one desk")
	Research.state(restored).known=["plank","plank","nonexistent"]; Research.restore(restored)
	expect(Research.state(restored).known==["plank"],"restore deduplicates known types and removes unknown identifiers")
	DirAccess.remove_absolute(path); game.free(); restored.free()
