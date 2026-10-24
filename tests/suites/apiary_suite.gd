extends "res://tests/suites/suite_base.gd"

const Apiary := preload("res://scripts/systems/apiary_system.gd")
const Controls := preload("res://scripts/systems/apiary_input_system.gd")

## Проверяет пасеку от дикого роя до алхимии, собственных запасов, паузы и сохранения.
func run() -> void:
	test_wild_nests_and_access()
	test_construction_population_and_atomic_costs()
	test_daily_capacity_and_independent_hives()
	test_pause_save_and_invalid_stocks()
	test_complete_alchemy_chain_and_effects()
	test_devices_localization_and_sprite_regions()

## Открывает реальную рабочую сторону одного места пасеки и убирает вступительную сценку.
func open_hive(game: Node, index: int=0) -> Dictionary:
	game.current_location="overworld"; game.player=Apiary.Data.SITES[index]+Vector2(0,48); game.energy=12; game.attack_held=true
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0; game.tutorial_visible=false
	expect(game.FarmLifeSystem.interact(game,"life:apiary:"+str(index)),"working side opens its actual hive")
	expect(not game.attack_held and not game.action_held,"opening apiary resets held attacks and actions")
	return Apiary.state(game).hives[index]

## Выдаёт ровно стоимость следующей ступени и применяет настоящий расход ресурсов.
func build_next(game: Node, item: Dictionary) -> void:
	var cost:Dictionary=Apiary.Data.COSTS[int(item.level)]; game.energy=12; game.coins=int(cost.coins)
	for kind in cost.inputs: game.change_inventory_count(kind,int(cost.inputs[kind]))
	expect(Apiary.construct(game),"complete next-level resources construct or upgrade hive")

## Находит алхимическую цепочку по устойчивому ID и выполняет её настоящим крафтом у стола.
func alchemy(game: Node, kind: String) -> bool:
	var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:"+kind)
	return game.CraftingSystem.craft(game,index)

## Сценарий: дикие гнёзда дают начало пасеке без бесконечного сбора в один день.
## Исходное состояние: два не собранных гнезда, свободные подходы и ограниченная энергия.
## Ожидаемый результат: пчёлы и соты выдаются один раз, каждый запас восстанавливается независимо через три дня.
func test_wild_nests_and_access() -> void:
	var game:=make_game()
	for entry in Apiary.Data.WILD:
		game.current_location=entry.location; game.player=entry.position+Vector2(0,48); game.energy=12
		expect(game.NavigationSystem.is_walkable(game,game.player),"wild hive approach is on accessible ground: "+entry.id)
		expect(game.FarmLifeSystem.nearest_interaction(game,60)=="life:wild_hive:"+entry.id,"wild nest is a real nearby context target")
		expect(game.perform_context_action() and game.energy==10,"ordinary context interaction pays two energy")
		var bees:int=game.inventory_item_count("bees"); var comb:int=game.inventory_item_count("honeycomb")
		game.perform_context_action(); expect(game.inventory_item_count("bees")==bees and game.inventory_item_count("honeycomb")==comb and game.energy==10,"same-day repeated collection yields nothing and spends nothing")
	game.day+=2; var wild:Dictionary=Apiary.Data.WILD[1]; game.current_location=wild.location; game.player=wild.position+Vector2(0,48); var before:int=game.inventory_item_count("bees")
	Apiary.interact(game,"life:wild_hive:"+wild.id); expect(game.inventory_item_count("bees")==before,"two days do not finish nest regrowth")
	game.day+=1; Apiary.interact(game,"life:wild_hive:"+wild.id); expect(game.inventory_item_count("bees")==before+1,"third day restores exactly one independent wild nest")
	game.free()

## Сценарий: постройка, заселение и улучшение проверяют весь состав до первого списания.
## Исходное состояние: пустой участок, частичный набор досок, затем точные материалы и пчёлы.
## Ожидаемый результат: отказ атомарный, пустой улей не производит, улучшение сохраняет семью и запас.
func test_construction_population_and_atomic_costs() -> void:
	var game:=make_game(); var item:=open_hive(game); game.change_inventory_count("plank",6)
	var counts:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Apiary.construct(game) and counts==game.export_inventory_counts() and game.energy==12 and item.level==0,"missing last building material cannot partially pay construction")
	build_next(game,item); expect(item.level==1 and not item.colonized and game.energy==9,"new hive starts empty at level one and exact energy cost")
	game.day+=2; Apiary.update(game); expect(item.stock.is_empty(),"empty hive generates no free honeycomb or bees")
	game.change_inventory_count("bees",1); game.energy=0; counts=game.export_inventory_counts().duplicate()
	expect(not Apiary.populate(game) and counts==game.export_inventory_counts(),"population refuses without energy before consuming bees")
	game.energy=12; expect(Apiary.populate(game) and game.inventory_item_count("bees")==0 and game.energy==11,"one bee unit settles persistent colony once")
	game.day+=1; Apiary.update(game); var stock:Dictionary=item.stock.duplicate(); build_next(game,item)
	expect(item.level==2 and item.colonized and item.stock==stock,"paid upgrade preserves family and collected-so-far material")
	game.player-=Vector2(0,140); counts=game.export_inventory_counts().duplicate()
	expect(not Apiary.construct(game) and counts==game.export_inventory_counts(),"wrong side cannot build remotely through stale UI selection")
	game.free()

## Сценарий: разные семьи копят собственный ограниченный урожай за прошедшие игровые дни.
## Исходное состояние: ульи первого и третьего уровней, заселённые в один день, затем большой пропуск дней.
## Ожидаемый результат: сложные продукты требуют уровня, склад ограничен, сбор не забирает постоянную семью и не повторяется.
func test_daily_capacity_and_independent_hives() -> void:
	var game:=make_game(); var first:=open_hive(game,0); build_next(game,first); game.change_inventory_count("bees",1); Apiary.populate(game)
	var advanced:=open_hive(game,1)
	for tier in 3: build_next(game,advanced)
	game.change_inventory_count("bees",1); Apiary.populate(game); Controls.close(game)
	game.day+=3; Apiary.update(game)
	expect(first.stock.honeycomb==3 and first.stock.bees==1 and not first.stock.has("pollen"),"first level produces one comb daily and one surplus bee every third day")
	expect(advanced.stock.honeycomb==9 and advanced.stock.pollen==3 and advanced.stock.propolis==3 and advanced.stock.bees==1,"third level adds pollen and propolis without sharing another hive's stores")
	Apiary.update(game); expect(first.stock.honeycomb==3,"same-day repeated updates do not duplicate production")
	game.day+=1000; Apiary.update(game)
	expect(first.stock.honeycomb==6 and first.stock.bees==2 and advanced.stock.honeycomb==18 and advanced.stock.pollen==18 and advanced.stock.propolis==18 and advanced.stock.bees==4,"long absence clamps all material and bee capacities")
	open_hive(game,1); var stock:Dictionary=advanced.stock.duplicate(); game.energy=0
	expect(not Apiary.harvest(game) and stock==advanced.stock,"tired collection keeps all stored materials intact")
	game.energy=12; expect(Apiary.harvest(game) and advanced.stock.is_empty() and advanced.colonized and game.energy==10,"harvest takes all advertised stocks once while keeping working colony")
	var counts:Dictionary=game.export_inventory_counts().duplicate(); expect(not Apiary.harvest(game) and counts==game.export_inventory_counts() and game.energy==10,"empty harvest cannot repeat XP, output or energy costs")
	game.free()

## Сценарий: пасека проходит настоящий слот, а некорректные уровни и поддельные запасы отвергаются.
## Исходное состояние: населённый улей, один день продукции и открытое окно пасеки.
## Ожидаемый результат: окно ставит мир на паузу, загрузка сохраняет семью и урожай без повтора, разборка возвращает половину компонентов.
func test_pause_save_and_invalid_stocks() -> void:
	var game:=make_game(); var item:=open_hive(game); build_next(game,item); game.change_inventory_count("bees",1); Apiary.populate(game)
	var minutes:float=game.game_minutes; game._physics_process(600)
	expect(game.game_minutes==minutes and item.stock.is_empty(),"apiary modal blocks world time, fights and daily production")
	Controls.close(game); game.day+=1; Apiary.update(game)
	var path:=OS.get_temp_dir().path_join("farm-apiary-%d.json" % Time.get_ticks_usec()); expect(game.SaveSystem.save_at(game,path),"real file saves paid level and colony stock")
	var restored:=make_game(); expect(restored.SaveSystem.load_at(restored,path),"disk load restores apiary payload")
	var loaded:Dictionary=Apiary.state(restored).hives[0]; expect(loaded.colonized and loaded.level==1 and loaded.stock.honeycomb==1 and not Controls.active(restored),"load preserves colony and stock but closes ephemeral UI")
	Apiary.update(restored); expect(loaded.stock.honeycomb==1,"load on same day cannot repeat already credited comb")
	var snapshot:Dictionary=restored.SaveSystem.snapshot(restored)
	for corruption in ["level","amount","kind","fraction","pollen"]:
		var broken:Dictionary=snapshot.duplicate(true); var hive:Dictionary=broken.estate.expansion.apiary.hives[0]
		match corruption:
			"level": hive.level=4
			"amount": hive.stock.honeycomb=99
			"kind": hive.stock.unknown=1
			"fraction": hive.stock.honeycomb=1.5
			"pollen": hive.stock.pollen=1
		expect(not restored.SaveSystem.apply(restored,broken) and snapshot==restored.SaveSystem.snapshot(restored),"invalid apiary payload rejects atomically: "+corruption)
	var legacy:Dictionary=snapshot.duplicate(true); legacy.estate.expansion.erase("apiary")
	expect(restored.SaveSystem.apply(restored,legacy) and Apiary.state(restored).hives.all(func(hive): return hive.level==0),"old save gains empty plots without free bees or products")
	open_hive(game); var counts:Dictionary=game.export_inventory_counts().duplicate(); expect(Apiary.dismantle(game),"explicit dismantle returns accumulated stock and colony")
	for kind in Apiary.Data.paid(1): expect(game.inventory_item_count(kind)==int(counts.get(kind,0))+int(Apiary.Data.paid(1)[kind])/2,"half of actually paid components is returned: "+kind)
	expect(game.inventory_item_count("bees")==1 and game.inventory_item_count("honeycomb")==1 and not Apiary.dismantle(game),"population and stored comb are returned exactly once")
	DirAccess.remove_absolute(path); game.free(); restored.free()

## Сценарий: каждый пчелиный ингредиент проходит настоящую алхимию до рабочих препаратов.
## Исходное состояние: собранные соты, воск, пчёлы, пыльца и прополис, стол дома и изученная алхимия.
## Ожидаемый результат: разделение даёт мёд и воск, все цепочки списывают полный состав, препараты применяют заявленные эффекты.
func test_complete_alchemy_chain_and_effects() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.player=game.CraftingSystem.Alchemy.STATION; game.CraftingSystem.open(game,"alchemy")
	game.change_inventory_count("honeycomb",1); expect(alchemy(game,"honey") and game.inventory_item_count("honey")==1 and game.inventory_item_count("beeswax")==1,"one comb yields exactly one honey and one wax byproduct")
	game.talent_levels.craft_alchemy=1; game.CraftingSystem.Alchemy.state(game).xp=120
	for mix in Apiary.Data.MIXES:
		for kind in mix[1]: game.change_inventory_count(kind,int(mix[1][kind]))
		expect(alchemy(game,mix[0]),"bee resource has real available alchemy continuation: "+mix[0])
	for kind in Apiary.Data.POTIONS:
		game.player_hp=10; game.player_mana=0; game.energy=0; game.regeneration_timer=0; game.state.world.cave_boss.fly_timer=4
		var data:Dictionary=Apiary.Data.POTIONS[kind]
		expect(game.consume_item(kind),"new apiary potion can be consumed: "+kind)
		if data.has("heal"): expect(game.player_hp==10+int(data.heal),"apiary balm applies its exact healing")
		if data.has("energy"): expect(game.energy==int(data.energy),"apiary potion applies its exact energy")
		if data.has("mana"): expect(game.player_mana==int(data.mana),"royal tonic restores exact mana")
		if data.get("cleanse",false): expect(game.state.world.cave_boss.fly_timer==0 and game.regeneration_timer==30,"propolis ointment clears fly bites and activates real regeneration")
	game.free()

## Сценарий: пасека работает мышью и геймпадом, а её ресурсы видны на всех языках.
## Исходное состояние: пустое место пасеки, первые материалы и утверждённый атлас A.
## Ожидаемый результат: маршрутизатор потребляет ввод, названия и обучение переведены, все силуэты отделены от соседей.
func test_devices_localization_and_sprite_regions() -> void:
	var game:=make_game(); open_hive(game); var item:Dictionary=Apiary.state(game).hives[0]
	for kind in Apiary.Data.COSTS[0].inputs: game.change_inventory_count(kind,int(Apiary.Data.COSTS[0].inputs[kind]))
	game._input(joypad_button_event(JOY_BUTTON_A,true)); expect(item.level==1,"real gamepad router constructs selected hive")
	game.change_inventory_count("bees",1); var tap:=InputEventScreenTouch.new(); tap.pressed=true; tap.position=preload("res://scripts/presentation/apiary_renderer.gd").PRIMARY.get_center()
	game._input(tap); expect(item.colonized,"touch uses same primary population action")
	game._input(joypad_button_event(JOY_BUTTON_B,true)); expect(not Controls.active(game),"gamepad closes apiary modal")
	for index in Apiary.Data.SITES.size(): expect(game.NavigationSystem.is_walkable(game,Apiary.Data.SITES[index]+Vector2(0,48)),"each hive operating side remains accessible")
	expect(not game.NavigationSystem.is_walkable(game,Apiary.Data.SITES[0]),"built hive uses physical foundation")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for kind in Apiary.Data.RAW: expect(game.LocaleSystem.item(kind)!=kind and game.VisualAssetSystem.item_texture(kind)!=null,"apiary material has name and real icon: "+kind+" "+locale)
		for key in Apiary.Data.POTIONS: expect(game.LocaleSystem.item(key)!=key,"apiary potion is translated: "+locale)
		for key in preload("res://scripts/systems/apiary_locale.gd").TUTORIAL: expect(game.LocaleSystem.tutorial(key)!=key and key in game.TutorialSystem.STEP_IDS,"apiary event is an actual translated tutorial step")
	game.LocaleSystem.current="ru"
	for texture in preload("res://scripts/presentation/apiary_visual_system.gd").TEXTURES.values(): expect(texture is AtlasTexture and texture.region.size.x>100 and texture.region.size.y>100,"chosen hive or resource has full measured region")
	game.free()
