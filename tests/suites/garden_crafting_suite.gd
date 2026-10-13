extends "res://tests/suites/world_farming_suite.gd"

const Garden := preload("res://scripts/systems/garden_crafting_system.gd")

## Проверяет применение расходников, локальные эффекты, сохранение удобрений и честный расход наживки.
func run() -> void:
	test_fertilizer_atomic_target_and_growth()
	test_harvest_bonus_and_one_cycle()
	test_fertilizer_save_and_old_slots()
	test_bait_cast_timing()
	test_consumable_effects()

## Подготавливает домашнюю пустую грядку перед героем без растущего растения.
func home_bed(game: Node) -> Dictionary:
	game.current_location="overworld"; game.facing=Vector2.RIGHT
	game.player=Vector2(game.FARM_ORIGIN)+Vector2(24,24)-Vector2(42,0)
	var plot:Dictionary=game.plots[Vector2i.ZERO]; plot.tilled=true; plot.planted=false
	return plot

## Сценарий: удобрение применимо только к пустому вспаханному участку перед героем.
## Исходное состояние: три смеси, дом, нетронутая земля и соседняя грядка без удобрения.
## Ожидаемый результат: ошибки ничего не расходуют, успешное применение ускоряет одну грядку и не отменяет полив или сезонность.
func test_fertilizer_atomic_target_and_growth() -> void:
	var game:=make_game(); var plot:=home_bed(game)
	game.change_inventory_count("compost",2)
	plot.tilled=false; expect(not game.PotionSystem.consume(game,"compost") and game.inventory_item_count("compost")==2,"untilled bed does not consume fertilizer")
	plot.tilled=true; plot.planted=true
	expect(not Garden.apply(game,"compost") and game.inventory_item_count("compost")==2,"planted crop cannot receive new fertilizer")
	plot.planted=false; expect(game.PotionSystem.consume(game,"compost") and plot.fertilizer=="compost" and game.inventory_item_count("compost")==1,"bag use targets actual tilled home soil")
	game.change_inventory_count("growth_fertilizer",1)
	expect(not Garden.apply(game,"growth_fertilizer") and game.inventory_item_count("growth_fertilizer")==1,"existing fertilizer cannot be silently replaced or stacked")
	plot.planted=true; plot.crop_kind="carrot"; plot.watered=true; plot.growth=0; plot.stage=0
	var plain:=plot.duplicate(true); plain.fertilizer=""
	game.FarmSystem.update_plot(game,plain,1); game.FarmSystem.update_plot(game,plot,1)
	expect(is_equal_approx(float(plot.growth),float(plain.growth)*1.2),"compost speeds only its own crop by twenty percent")
	plot.fertilizer="growth_fertilizer"; plot.growth=0; game.FarmSystem.update_plot(game,plot,1)
	expect(is_equal_approx(float(plot.growth),float(plain.growth)*1.35),"growth mix applies thirty-five percent speed")
	var growth:float=plot.growth; plot.watered=false; game.FarmSystem.update_plot(game,plot,2)
	expect(is_equal_approx(plot.growth,growth),"fertilizer never bypasses required watering")
	game.day=22; plot.watered=true; game.FarmSystem.update_plot(game,plot,2)
	expect(is_equal_approx(plot.growth,growth),"fertilizer never bypasses winter season")
	game.current_location="cellar_workshop"; expect(not Garden.apply(game,"compost") and game.inventory_item_count("compost")==1,"cellar floor is not a fertilizable bed")
	game.free()

## Сценарий: смесь урожая даёт один плод, удобрение расходуется только при успешном сборе.
## Исходное состояние: однолетняя морковь и многолетняя клубника с одной удобренной партией.
## Ожидаемый результат: незрелый сбор ничего не меняет, бонус первого сбора не распространяется на последующие урожаи.
func test_harvest_bonus_and_one_cycle() -> void:
	var game:=make_game(); var plot:=home_bed(game)
	plot.planted=true; plot.crop_kind="carrot"; plot.fertilizer="quality_fertilizer"; plot.growth=1
	expect(not game.FarmSystem.harvest(game,plot) and plot.fertilizer=="quality_fertilizer","failed harvest keeps purchased fertilizer")
	plot.growth=game.CropCatalogSystem.growth_duration("carrot"); var before:int=game.inventory_item_count("carrot")
	var normal:int=game.CropCatalogSystem.harvest_count(game,"carrot")
	expect(game.FarmSystem.harvest(game,plot) and game.inventory_item_count("carrot")==before+normal+1 and plot.fertilizer=="","successful harvest adds one crop then consumes fertilizer")
	plot.planted=true; plot.crop_kind="strawberry"; plot.fertilizer="growth_fertilizer"; plot.growth=game.CropCatalogSystem.growth_duration("strawberry")
	expect(game.FarmSystem.harvest(game,plot) and plot.planted and plot.fertilizer=="" and Garden.multiplier(plot)==1.0,"perennial second cycle has no permanent free fertilizer")
	game.free()

## Сценарий: удобрения на домашнем и мировом участке сохраняются независимо.
## Исходное состояние: два оплаченных удобрения и JSON-снимок игры.
## Ожидаемый результат: загрузка сохраняет вид и локальный эффект, старые грядки остаются совместимыми, неизвестное удобрение отклоняется.
func test_fertilizer_save_and_old_slots() -> void:
	var game:=make_game(); var home:=home_bed(game); game.change_inventory_count("quality_fertilizer",1); Garden.apply(game,"quality_fertilizer")
	var cell:=find_tillable_cell(game,"forest"); place_target(game,"forest",cell)
	var target:Dictionary=game.WorldFarmingSystem.target(game); var world:Dictionary=game.WorldFarmingSystem.read_target(game,target); world.tilled=true; game.WorldFarmingSystem.write_target(game,target,world)
	game.change_inventory_count("compost",1); expect(Garden.apply(game,"compost") and world.fertilizer=="compost","free world plot receives its own fertilizer")
	var data:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
	expect(game.SaveSystem.ValidationSystem.valid(data),"fertilized home and world plots validate")
	var restored:=make_game(); game.SaveSystem.apply(restored,data)
	expect(restored.plots[Vector2i.ZERO].fertilizer==home.fertilizer and restored.state.world.world_plots[target.key].fertilizer=="compost","JSON preserves independent bed fertilizers")
	var invalid:=data.duplicate(true); invalid.plots[0].fertilizer="magic_infinite_fertilizer"
	expect(not game.SaveSystem.ValidationSystem.valid(invalid),"unknown fertilizer cannot alter live save")
	invalid=data.duplicate(true); invalid.world_plots[0].fertilizer=42
	expect(not game.SaveSystem.ValidationSystem.valid(invalid),"wrong fertilizer type rejected")
	for value in data.plots+data.world_plots: value.erase("fertilizer")
	expect(game.SaveSystem.ValidationSystem.valid(data),"old saves without fertilizer still validate")
	game.SaveSystem.apply(restored,data)
	expect(restored.plots[Vector2i.ZERO].fertilizer=="" and restored.state.world.world_plots[target.key].fertilizer=="","old slot clears stale fertilizer from live model")
	restored.free(); game.free()

## Сценарий: наживка расходуется после действительного заброса и уменьшает только ожидание поклёвки.
## Исходное состояние: удочка у пруда, два расходника и одинаковая сила заброса.
## Ожидаемый результат: зарядка ничего не тратит, выпуск лески тратит одну наживку, последующие стадии не списывают её повторно.
func test_bait_cast_timing() -> void:
	var game:=make_game(); game.current_location="overworld"; game.player=game.pond_position+Vector2(120,0); game.has_fishing_rod=true
	game.change_inventory_count("fishing_bait",2); game.action_held=true
	expect(game.FishingSystem.use_rod(game) and game.inventory_item_count("fishing_bait")==2,"starting charge preserves bait")
	game.state.fishing.cast_power=0.7; game.FishingSystem.update(game,0.1)
	expect(game.inventory_item_count("fishing_bait")==2,"holding charge does not spend bait")
	game.state.fishing.cast_power=0.7; var normal:float=game.SkillSystem.fishing_wait(game)*lerpf(1.12,0.82,0.7)
	game.action_held=false; game.FishingSystem.update(game,0.1)
	expect(game.state.fishing.phase=="waiting" and game.inventory_item_count("fishing_bait")==1 and is_equal_approx(game.state.fishing.timer,normal*0.65),"released cast spends exactly one and reduces wait thirty-five percent")
	game.FishingSystem.update(game,0.1); expect(game.inventory_item_count("fishing_bait")==1,"waiting does not consume repeated bait")
	game.state.fishing.reset_cast(); game.change_inventory_count("fishing_bait",-1)
	game.state.fishing.phase="charging"; game.state.fishing.cast_power=0.7; game.FishingSystem.update(game,0.1)
	expect(is_equal_approx(game.state.fishing.timer,normal),"no bait keeps legacy fishing wait")
	game.state.fishing.reset_cast(); game.current_location="cellar_workshop"; game.change_inventory_count("fishing_bait",1)
	expect(not game.FishingSystem.use_rod(game) and game.inventory_item_count("fishing_bait")==1,"invalid location never spends bait")
	game.free()

## Сценарий: новые готовые продукты имеют тот же эффект, что показан в карточке.
## Исходное состояние: по одному новому пищевому продукту и повязке, здоровье и энергия истощены.
## Ожидаемый результат: каждый заявленный эффект применяется с единичным расходом и не превышает максимум ресурсов.
func test_consumable_effects() -> void:
	var game:=make_game(); var data:=preload("res://scripts/systems/artisan_data.gd")
	for kind in data.effects():
		game.change_inventory_count(kind,1); game.player_hp=1; game.energy=0; game.player_mana=0
		var effect:Array=data.effects()[kind]
		expect(game.PotionSystem.consume(game,kind) and game.inventory_item_count(kind)==0,"new consumable has real single-use effect: "+kind)
		expect(game.player_hp==mini(1+int(effect[1]),game.player_max_hp),"effect matches displayed healing: "+kind)
		if String(effect[0])=="item_effect_heal_energy": expect(game.energy==mini(int(effect[2]),game.SkillSystem.max_stamina(game)),"food stamina effect: "+kind)
		if String(effect[0])=="item_effect_heal_mana": expect(game.player_mana==mini(int(effect[2]),game.player_max_mana),"drink mana effect: "+kind)
	game.free()
