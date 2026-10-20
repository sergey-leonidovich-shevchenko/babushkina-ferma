extends "res://tests/suites/suite_base.gd"

const Animals := preload("res://scripts/systems/livestock_system.gd")
const Data := preload("res://scripts/systems/livestock_data.gd")
const Visual := preload("res://scripts/systems/livestock_visual_system.gd")

## Запускает сценарии ежедневного ухода, запасов, миграции и безопасного двора.
func run() -> void:
	test_starting_yard_and_daily_care()
	test_missing_care_and_delayed_collection()
	test_stock_capacity_and_friendship()
	test_saved_produce_and_legacy_memory()
	test_walkways_and_sleeping_poses()
	test_expanded_yard_bounds_and_gates()
	test_learning_and_localization()
	test_old_planted_plot_keeps_progress()

## Сценарий: двор доступен до улучшений, корм и вода расходуются по дневным правилам.
## Исходное состояние: новая ферма нулевого уровня имеет четыре порции стартового корма.
## Ожидаемый результат: шесть животных доступны, повтор не списывает корм, утром появляются разные продукты.
func test_starting_yard_and_daily_care() -> void:
	var game := make_game(); var value: Dictionary=game.FarmLifeSystem.state(game)
	expect(game.state.world.estate.level==0 and value.animals.size()==6,"starting farm contains cow pig sheep and three hens before upgrades")
	game.player=Data.TROUGH
	expect(Animals.nearest(game,88)=="life:trough","starter trough is an actual nearby interaction")
	var initial: int=game.inventory_item_count("animal_feed")
	Animals.interact(game,value,"life:trough"); Animals.interact(game,value,"life:trough")
	expect(game.inventory_item_count("animal_feed")==initial-1,"feeding consumes one portion once a day")
	Animals.interact(game,value,"life:water"); game.day=2; Animals.update(game,value,0)
	expect(value.animals.hen.ready==1 and value.animals.cow.ready==1 and value.animals.pig.ready==1 and value.animals.sheep.ready==0,"daily milk eggs and slower wool and truffles use distinct production intervals")
	Animals.interact(game,value,"life:animal:hen"); Animals.interact(game,value,"life:animal:hen")
	expect(game.inventory_item_count("egg")==1 and value.animals.hen.bond==1,"collection cannot duplicate produce and petting is a separate action")
	expect(not Animals.interact(game,value,"life:animal:missing"),"unknown animal cannot index an empty catalog result")
	game.free()

## Сценарий: пропущенная вода не производит продукт, а обслуженный день можно собрать позже.
## Исходное состояние: сначала только корм, затем полный уход; игрок пропускает утро и обновляет воду.
## Ожидаемый результат: голод и жажда объясняются, старый запас сохраняется до нового ухода.
func test_missing_care_and_delayed_collection() -> void:
	var game := make_game(); var value: Dictionary=game.FarmLifeSystem.state(game)
	Animals.interact(game,value,"life:trough"); game.day=2; Animals.update(game,value,0)
	expect(value.animals.cow.ready==0,"feeding without fresh water does not silently produce milk")
	Animals.interact(game,value,"life:water"); Animals.interact(game,value,"life:trough")
	game.day=5; Animals.interact(game,value,"life:water")
	expect(value.animals.cow.ready==1,"updating water after missed morning first preserves the previous serviced day")
	Animals.interact(game,value,"life:animal:cow"); Animals.update(game,value,0)
	expect(game.inventory_item_count("milk")==1 and value.animals.cow.ready==0,"late collection grants the stored product exactly once")
	game.change_inventory_count("animal_feed",-game.inventory_item_count("animal_feed")); game.change_inventory_count("wheat",2)
	var counts: Dictionary=game.export_inventory_counts().duplicate(true)
	Animals.interact(game,value,"life:trough")
	expect(counts==game.export_inventory_counts() and value.animals.cow.fed_day==2,"insufficient fallback grain leaves every animal and inventory unchanged")
	game.free()

## Сценарий: запас ограничен, ласка не повторяется, дружба увеличивает размер продукции.
## Исходное состояние: корова уже имеет дружбу шесть, игрок ежедневно обслуживает двор без сбора.
## Ожидаемый результат: утро даёт две единицы, запас ограничен тремя, сохранение не создаёт дополнительный продукт.
func test_stock_capacity_and_friendship() -> void:
	var game := make_game(); var value: Dictionary=game.FarmLifeSystem.state(game)
	value.animals.cow.bond=6
	for day in range(1,4):
		game.day=day; Animals.interact(game,value,"life:trough"); Animals.interact(game,value,"life:water")
	game.day=4; Animals.update(game,value,0)
	expect(value.animals.cow.ready==Data.STOCK_CAP,"uncollected high-bond milk respects a three-item storage limit")
	Animals.interact(game,value,"life:animal:cow"); Animals.interact(game,value,"life:animal:cow"); Animals.interact(game,value,"life:animal:cow")
	expect(game.inventory_item_count("milk")==3 and value.animals.cow.bond==7,"stored milk collects together and repeated petting only raises bond once")
	var restored := make_game(); restored.SaveSystem.apply(restored,game.SaveSystem.snapshot(game)); Animals.update(restored,restored.FarmLifeSystem.state(restored),0)
	expect(restored.inventory_item_count("milk")==3 and restored.FarmLifeSystem.state(restored).animals.cow.ready==0,"loading a collected day cannot regenerate its milk")
	game.free(); restored.free()

## Сценарий: старые три записи животных дополняются без потери уже собранного продукта и дружбы.
## Исходное состояние: сохранение не знает новых полей, у коровы сохранена дружба семь и сбор четвёртого дня.
## Ожидаемый результат: новые животные добавлены, старые значения сохранены, неверный тип нового поля отклонён атомарно.
func test_saved_produce_and_legacy_memory() -> void:
	var game := make_game(); game.day=5
	var document: Dictionary=game.SaveSystem.snapshot(game)
	document.estate.expansion.animals={"cow":{"fed_day":3,"collected_day":4,"bond":7}}
	document.estate.expansion.erase("livestock_started"); document.counts.erase("animal_feed")
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored,document),"old animal memory migrates through the production save loader")
	var value: Dictionary=restored.FarmLifeSystem.state(restored)
	Animals.update(restored,value,0)
	expect(value.animals.size()==6 and value.animals.cow.bond==7 and value.animals.cow.collected_day==4 and value.animals.cow.ready==0,"migration preserves friendship and collected-day markers")
	expect(restored.inventory_item_count("animal_feed")==4,"legacy save receives the finite starter feed once")
	var invalid: Dictionary=restored.SaveSystem.snapshot(restored); invalid.estate.expansion.animals.cow.ready="broken"
	var before: Dictionary=restored.SaveSystem.snapshot(restored)
	expect(not restored.SaveSystem.apply(restored,invalid) and restored.SaveSystem.snapshot(restored)==before,"invalid new fields are rejected before mutating inventory or animal state")
	game.free(); restored.free()

## Сценарий: герой проходит центральный двор, животные остаются в оградах и ночью спят.
## Исходное состояние: двор работает без улучшений; симуляция проходит несколько циклов прогулок.
## Ожидаемый результат: проход проходим, ноги не выходят из загона, ночь и пауза выбирают правильные кадры.
func test_walkways_and_sleeping_poses() -> void:
	var game := make_game(); var value: Dictionary=game.FarmLifeSystem.state(game)
	for y in range(936,1249,24):
		expect(game.NavigationSystem.walkability_reason(game,Vector2(948,y),-1,false)=="walkable","central yard walkway remains clear at y=%d"%y)
	for tick in 30:
		Animals.update(game,value,0.5)
		for animal in Data.ANIMALS:
			var pose := Animals.pose(game,animal)
			expect(Rect2(Data.PENS[animal.pen].rect).has_point(pose.position),"livestock walks within its own physical pen: %s"%animal.id)
	game.game_minutes=1260
	for animal in Data.ANIMALS: expect(Animals.pose(game,animal).frame==4,"night uses the independent resting pose: %s"%animal.id)
	var clock: float=game.get_meta("livestock_clock",0.0); game.open_inventory(); game.GameLoop.physics_process(game,1)
	expect(game.get_meta("livestock_clock",0.0)==clock,"full-screen backpack pauses livestock motion and production")
	expect(game.WorldFarmingSystem.tillability_reason(game,"overworld",Vector2i(16,24))=="outside_farm","animal pasture cannot be turned into accidental crops")
	for kind in ["cow","pig","hen","sheep"]:
		for index in 6: expect(not Visual.frame(kind,index).is_empty(),"six isolated action poses exist for %s/%d"%[kind,index])
	game.free()

## Сценарий: увеличенные загоны занимают новый южный луг, свинка соответствует масштабу героя.
## Исходное состояние: все основания и ограды включены, герой проходит калитки без помощи углам.
## Ожидаемый результат: каждый загон просторнее, проходы доступны, камера и сохранение поддерживают новую землю; другие карты не увеличены.
func test_expanded_yard_bounds_and_gates() -> void:
	var game := make_game(); var routes := preload("res://tests/suites/village_clearance_suite.gd").new(context)
	for entry in [{"id":"coop","old":Vector2(168,72)},{"id":"pasture","old":Vector2(168,72)},{"id":"pigsty","old":Vector2(192,96)}]:
		var rect: Rect2=Data.PENS[entry.id].rect
		expect(rect.get_area()>=Vector2(entry.old).x*Vector2(entry.old).y*1.8,"expanded pen has materially more space: "+entry.id)
		var gate: Rect2=Data.PENS[entry.id].gate; var center:=gate.get_center()
		game.player=Vector2(Data.WALKWAY.get_center().x,center.y)
		expect(routes.walk_to(game,center+Vector2(-32 if entry.id!="pigsty" else 32,0)),"player enters the open pen gate: "+entry.id)
	for index in 6:
		expect(int(Visual.frame("pig",index).size[0])<=52,"pig frame fits the corrected smaller scale: "+str(index))
	game.player=Vector2(948,1248); game.clamp_player_position()
	expect(game.player.y==1248 and game.CameraSystem.target_offset(game).y==828,"new south field is reachable and the 120% camera follows it")
	expect(game.VillageLayoutSystem.OVERWORLD_TILE_COUNT==Vector2i(100,57),"terrain grid derives its southern extension from the map dimensions")
	var cell:=Vector2i(28,26); var plot: Dictionary=game.WorldFarmingSystem.empty_plot("overworld",cell)
	plot.tilled=true; plot.planted=true; plot.crop_kind="wheat"; game.state.world.world_plots[game.WorldFarmingSystem.plot_key("overworld",cell)]=plot
	var restored:=make_game(); expect(restored.SaveSystem.apply(restored,game.SaveSystem.snapshot(game)),"south field snapshot passes production validation")
	expect(restored.player==game.player and restored.state.world.world_plots.is_empty() and restored.plots.values().any(func(bed): return bed.planted and bed.crop_kind=="wheat"),"southern player remains in place while old crop moves home")
	game.current_location="cave"; game.player=Vector2(948,1248); game.clamp_player_position()
	expect(game.player.y==1120 and game.WorldBoundsSystem.size("cave")==Vector2(2400,1200),"extending the farm does not change cave boundaries")
	game.free(); restored.free()

## Сценарий: новый двор объясняет каждое действие и показывает переведённые продукты.
## Исходное состояние: локализация последовательно переключается на все шесть языков.
## Ожидаемый результат: корм, трюфель, вода, ласка и интервалы продукции не остаются техническими ключами.
func test_learning_and_localization() -> void:
	var game := make_game()
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for event in ["farmyard","animal_feed","animal_water","animal_pet","animal_product"]:
			expect(event in game.TutorialSystem.STEP_IDS and game.LocaleSystem.tutorial(event)!=event,"farm action is taught in %s: %s"%[locale,event])
		for kind in ["animal_feed","truffle"]: expect(game.LocaleSystem.item(kind)!=kind and game.VisualAssetSystem.item_texture(kind)!=null,"farm product has a localized name and separate icon: %s"%kind)
	game.LocaleSystem.current="ru"; game.free()

## Сценарий: старый игрок посадил овощ там, где новая ревизия построила загон.
## Исходное состояние: свободная грядка имеет растение, полив и накопленный рост; герой сохранён в другой локации.
## Ожидаемый результат: перенос выбирает свободную клетку с сохранением культуры, роста и числа растений; локация героя сохраняется.
func test_old_planted_plot_keeps_progress() -> void:
	var game := make_game(); game.state.world.estate.map_revision=3
	var cell := Vector2i(16,24)
	var plot: Dictionary=game.WorldFarmingSystem.empty_plot("overworld",cell)
	plot.tilled=true; plot.planted=true; plot.watered=true; plot.growth=23.5; plot.stage=2; plot.crop_kind="wheat"
	game.state.world.world_plots[game.WorldFarmingSystem.plot_key("overworld",cell)]=plot
	game.current_location="cottage_interior"
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored,game.SaveSystem.snapshot(game)),"old planted pasture snapshot loads safely")
	var plots: Array=restored.plots.values().filter(func(bed): return bed.planted)
	expect(plots.size()==1 and restored.current_location=="cottage_interior" and restored.state.world.world_plots.is_empty(),"yard migration preserves crop count and player location")
	var moved: Dictionary=plots[0]
	expect(moved.cell!=cell and moved.crop_kind=="wheat" and moved.growth==23.5 and moved.stage==2 and moved.planted and moved.watered,"moving old planted cells preserves full harvest progress")
	expect(not preload("res://scripts/systems/livestock_map_migration.gd").reserved(restored.FarmVisualSystem.plot_rect(Vector2(restored.FARM_ORIGIN),moved.cell)),"relocated crop sits on home farm outside animal pens")
	game.free(); restored.free()
