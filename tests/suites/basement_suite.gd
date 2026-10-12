extends "res://tests/suites/suite_base.gd"

const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")
const Controls := preload("res://scripts/systems/basement_input_system.gd")
const Stations := preload("res://scripts/systems/basement_station_system.gd")
const Production := preload("res://scripts/systems/basement_production_system.gd")

## Проверяет пустой подвал, строительную оплату, удержание, геометрию, независимые очереди и настоящие слоты.
func run() -> void:
	test_room_entry_and_four_directions()
	test_placement_collision_routes_and_atomic_payment()
	test_hold_pause_energy_resume_and_level_one()
	test_independent_instances_upgrade_and_salvage()
	test_research_knowledge_and_local_recipe_levels()
	test_disk_save_and_invalid_layout_are_atomic()

## Готовит настоящую мастерскую без вступительной сценки и модальных подсказок стенда.
func enter(game: Node) -> void:
	game.current_location=Basement.Data.LOCATION; game.player=Basement.Data.BOARD
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.tutorial_visible=false; game.energy=12

## Возвращает минимальный кандидат из целых координат общей сетки.
func plan(kind: String, x: int, y: int, direction: int=0) -> Dictionary:
	return {"kind":kind,"x":x,"y":y,"direction":direction}

## Ставит оплаченные компоненты через настоящий чертёж и оставляет недостроенный экземпляр.
func place(game: Node, kind: String, x: int, y: int, direction: int=0) -> Dictionary:
	game.player=Basement.Data.BOARD; Basement.open(game); Basement.ui(game).tab=0
	Basement.ui(game).selected=Basement.Data.STATIONS.keys().find(kind); Controls.execute(game)
	for material in Basement.Data.STATIONS[kind].inputs: game.change_inventory_count(material,int(Basement.Data.STATIONS[kind].inputs[material]))
	expect(Build.build(game,plan(kind,x,y,direction)),"real blueprint reserves a complete station foundation: "+kind)
	return Basement.state(game).objects.back()

## Завершает настоящие пять секунд работы с расходом энергии, а не переключением стадии вручную.
func finish(game: Node, item: Dictionary) -> void:
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); game.energy=12
	expect(Stations.interact(game,int(item.id)),"construction starts only at the designated approach")
	Build.update_hold(game,5); expect(item.phase=="ready","five active seconds complete the paid level-one station")

## Сценарий: большая мастерская доступна из дома и каждый станок имеет четыре рабочих стороны.
## Исходное состояние: чистая модель и свободный пол без заранее построенных личных станков.
## Ожидаемый результат: лестница туда и обратно работает, все сорок ориентированных оснований имеют единственный свободный подход.
func test_room_entry_and_four_directions() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.home_chest_owned=true; game.player=Basement.Data.HOUSE_ENTRY
	expect(game.NavigationSystem.is_walkable(game,game.player),"stairs operating point remains walkable with the installed home chest")
	expect(game.BuildingSystem.nearest_interaction(game)=="interior_link:cellar_workshop" and game.perform_context_action(),"cottage stairs lead to a real separate cellar location")
	expect(game.current_location==Basement.Data.LOCATION and Basement.state(game).objects.is_empty(),"new cellar starts with no free completed machines")
	expect(game.WorldBoundsSystem.size(game.current_location)==Vector2(2400,1560),"large cellar supports camera scrolling beyond one screen")
	for kind in Basement.Data.STATIONS:
		for direction in 4:
			var item:=plan(kind,40,20,direction); var point:=Basement.Layout.center(Basement.Layout.approach_cell(item))
			expect(Basement.Layout.reason([],item).is_empty() and Basement.Layout.walkable(point,[Basement.Layout.rect(item)]),"station has a valid reachable rotated operating side: %s %d"%[kind,direction])
	expect(game.BuildingSystem.leave(game) and game.current_location=="cottage_interior","cellar exit returns inside the cottage rather than outside the village")
	game.free()

## Сценарий: сетка не допускает пересечений, запертой лестницы и перекрытого прохода к другим станкам.
## Исходное состояние: свободные и занятые кандидаты, затем длинная линия станков с единственным проходом.
## Ожидаемый результат: неправильное размещение ничего не списывает; перекрывается только физически мешающая клетка, последний проход защищён.
func test_placement_collision_routes_and_atomic_payment() -> void:
	var game:=make_game(); enter(game); Basement.open(game); Basement.ui(game).selected=2; Controls.execute(game)
	var original_counts:Dictionary=game.export_inventory_counts().duplicate()
	expect(Controls.preview(game).reason=="basement_materials" and not Build.build(game,plan("pottery",40,20)) and game.export_inventory_counts()==original_counts and Basement.state(game).objects.is_empty(),"missing full construction cost is visible and refuses before payment")
	var item:=place(game,"pottery",40,20)
	game.player=Basement.Data.BOARD; Basement.open(game); Basement.ui(game).placing=true; Basement.ui(game).open=false
	var counts:Dictionary=game.export_inventory_counts().duplicate(); var coins:int=game.coins
	expect(not Build.build(game,plan("pottery",40,20)) and game.export_inventory_counts()==counts and game.coins==coins,"overlap refuses before any resource debit")
	expect(Basement.Layout.cell_blocked([item],Vector2i(40,20)) and not Basement.Layout.cell_blocked([item],Vector2i(46,20)),"placement grid identifies specific occupied cells")
	expect(not Basement.Layout.reason([],plan("pottery",3,0)).is_empty(),"stairs are protected from construction")
	expect(not Basement.Layout.reason([],plan("sawmill",91,50)).is_empty(),"whole footprint must fit the floor")
	var barrier:Array=[]
	for x in range(0,92,4):
		if x!=44: barrier.append(plan("pottery",x,25))
	barrier.append(plan("workbench",60,40))
	expect(Basement.Layout.valid_set(barrier),"stations remain usable while a passage through the line stays open")
	expect(Basement.Layout.reason(barrier,plan("pottery",44,25,2))=="basement_route","last passage cannot be sealed even when all footprint cells are unoccupied")
	var narrow:Array[Rect2]=[Rect2(96,840,1056,96),Rect2(1176,840,1128,96)]
	expect(not Basement.Layout.reachable(narrow).has(Vector2i(60,40)),"one-cell corridor is too narrow for the real 18px hero")
	narrow[1]=Rect2(1200,840,1104,96)
	expect(Basement.Layout.reachable(narrow).has(Vector2i(60,40)),"two-cell corridor remains traversable for the real hero")
	game.free()

## Сценарий: удержание молотка оплачивает каждую секунду, а отпускание и окна сохраняют частичный прогресс.
## Исходное состояние: новый гончарный круг при глобальном старом уровне три и два вида нехватки ресурсов.
## Ожидаемый результат: личный станок начинает с уровня один, пауза и отпускание останавливают стройку, последняя секунда расходуется единожды.
func test_hold_pause_energy_resume_and_level_one() -> void:
	var game:=make_game(); enter(game); game.WorkshopSystem.state(game,"pottery").level=3
	var item:=place(game,"pottery",35,18)
	expect(item.level==1 and item.production.level==1 and item.phase=="building","new station never inherits the old public station's level")
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item))
	expect(Controls.handle_input(game,key_event(KEY_E,KEY_E,true)),"ordinary held E begins assembly")
	game._physics_process(0.5); expect(is_equal_approx(item.work,0.5) and game.energy==12,"first partial second has progress but no premature energy debit")
	Controls.handle_input(game,key_event(KEY_E,KEY_E,false)); game._physics_process(2)
	expect(is_equal_approx(item.work,0.5) and game.energy==12,"release stops progress without losing paid components")
	Controls.handle_input(game,key_event(KEY_E,KEY_E,true)); game.inventory_open=true; var minutes:float=game.game_minutes; game._physics_process(10)
	expect(item.work==0.5 and game.game_minutes==minutes,"inventory pauses the world and the held construction")
	game.inventory_open=false; game._physics_process(0.5); expect(item.work==1 and game.energy==11,"resuming reaches one boundary and spends exactly one energy")
	game.energy=1; game._physics_process(4)
	expect(item.work==2 and item.phase=="building" and game.energy==0,"empty stamina stops at an affordable second boundary")
	game.energy=3; game._physics_process(3)
	expect(item.phase=="ready" and item.work==5 and game.energy==0,"restored stamina finishes only the remaining three seconds")
	Build.update_hold(game,20); expect(game.energy==0,"completed foundation cannot be charged again")
	game.free()

## Сценарий: два одинаковых станка имеют разные очереди и уровни, улучшение останавливает только свой экземпляр.
## Исходное состояние: два построенных распила, по бревну, затем оплаченное улучшение и демонтаж активной партии.
## Ожидаемый результат: результаты не удваиваются, производственная доля сохраняется, возврат включает половину журнала и полное сырьё отменённой очереди.
func test_independent_instances_upgrade_and_salvage() -> void:
	var game:=make_game(); enter(game); var left:=place(game,"sawmill",25,18); finish(game,left)
	var right:=place(game,"sawmill",38,18); finish(game,right)
	game.change_inventory_count("log",2); var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="sawmill:planks")
	for item in [left,right]:
		game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id); game.energy=12
		expect(game.CraftingSystem.craft(game,index),"each selected station owns its reserved job")
	game.crafting_open=false; Production.update(game,2)
	expect(left.production.queue[0].remaining==6 and right.production.queue[0].remaining==6,"each independent queue advances once, without active-binding duplication")
	game.player=Basement.Data.BOARD; Basement.open(game); game.coins=1000
	var cost:Dictionary=Basement.Data.upgrade_cost("sawmill",1)
	for material in cost.inputs: game.change_inventory_count(material,int(cost.inputs[material]))
	expect(Build.upgrade(game,left.id) and left.phase=="upgrading" and right.level==1,"blueprint targets one specific copy")
	Production.update(game,6); expect(left.production.queue[0].remaining==6 and right.production.queue.is_empty(),"unfinished upgrade stops its own production while the neighbor finishes")
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(left)); game.energy=12; Stations.interact(game,left.id); Build.update_hold(game,6)
	game.energy=2; Build.update_hold(game,1)
	expect(left.level==2 and is_equal_approx(left.production.queue[0].remaining/left.production.queue[0].duration,0.75),"upgrade preserves paid job progress as speed improves")
	expect(not game.WorkshopSystem.upgrade(game,"sawmill"),"personal station cannot upgrade directly from its crafting menu")
	game.player=Basement.Data.BOARD; Basement.open(game); var expected:=Build.salvage(left); var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(Build.dismantle(game,left.id) and Basement.object(game,left.id).is_empty(),"dismantling removes the selected footprint and only that copy")
	for material in expected: expect(game.inventory_item_count(material)==int(before.get(material,0))+int(expected[material]),"actual dismantling grants exact advertised components: "+material)
	expect(not Build.dismantle(game,left.id),"second dismantling cannot duplicate returned resources")
	game.free()

## Сценарий: знания общие, но сложность исследования, разборки и производства определяется выбранным личным столом.
## Исходное состояние: старый исследовательский уровень три, личные столы уровня один и герой с обратной стороны.
## Ожидаемый результат: глобальный уровень не обходит локальные ограничения, задняя сторона не открывает станок.
func test_research_knowledge_and_local_recipe_levels() -> void:
	var game:=make_game(); enter(game); game.ResearchSystem.state(game).level=3
	var study:=place(game,"study",25,18,2); finish(game,study)
	Stations.interact(game,study.id); expect(game.ResearchSystem.level(game)==1,"research complexity is local while knowledge remains global")
	game.crafting_open=false; game.player=Basement.Layout.rect(study).get_center()+Vector2(0,100)
	expect(not Stations.interact(game,study.id),"opposite side cannot use the research desk")
	var table:=place(game,"workbench",45,20); finish(game,table); Stations.interact(game,table.id)
	var recipe:Dictionary=game.CraftingSystem.RECIPES.filter(func(value): return value.output=="iron_spear" and value.get("station","workbench")=="workbench")[0]
	expect(Stations.recipe_reason(game,recipe)=="basement_recipe_level","complex existing equipment needs a sufficiently upgraded personal workbench")
	game.free()

## Сценарий: частичная стройка записывается в настоящий файл, неверное основание или тип отвергаются без изменения живой игры.
## Исходное состояние: оплаченный подвал, один рабочий интервал, сохранённый снимок и намеренно испорченные копии.
## Ожидаемый результат: загрузка сохраняет прогресс и пустые жесты, неизвестный вид, пересечение и отрицательный расход не проходят валидацию.
func test_disk_save_and_invalid_layout_are_atomic() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"pottery",30,18); game.player=Basement.Layout.center(Basement.Layout.approach_cell(item))
	Stations.interact(game,item.id); Build.update_hold(game,1.5)
	var path:="/private/tmp/farm-basement-save-%d.json"%Time.get_ticks_usec()
	expect(game.SaveSystem.save_at(game,path),"partially assembled workstation writes a real validated file")
	var restored:=make_game(); expect(restored.SaveSystem.load_at(restored,path),"real disk loading restores the construction payload")
	var loaded:=Basement.object(restored,item.id)
	expect(is_equal_approx(loaded.work,1.5) and loaded.paid==item.paid and int(Basement.ui(restored).holding)==0,"saved work and paid ledger survive while physical holding resets")
	var snapshot:Dictionary=restored.SaveSystem.snapshot(restored)
	for field in ["kind","direction","energy"]:
		var broken:Dictionary=snapshot.duplicate(true); broken.estate.expansion.basement.objects[0][field]="unknown" if field=="kind" else -1
		expect(not restored.SaveSystem.apply(restored,broken) and restored.SaveSystem.snapshot(restored)==snapshot,"invalid station field is rejected atomically: "+field)
	var overlapping:Dictionary=snapshot.duplicate(true); var duplicate:Dictionary=overlapping.estate.expansion.basement.objects[0].duplicate(true); duplicate.id=2; overlapping.estate.expansion.basement.objects.append(duplicate)
	expect(not restored.SaveSystem.apply(restored,overlapping) and restored.SaveSystem.snapshot(restored)==snapshot,"overlapping saved foundations cannot mutate the live room")
	var legacy:Dictionary=snapshot.duplicate(true); legacy.estate.expansion.erase("basement")
	expect(restored.SaveSystem.apply(restored,legacy) and Basement.state(restored).objects.is_empty(),"older save obtains an empty personal cellar without losing old global progress")
	DirAccess.remove_absolute(path); game.free(); restored.free()
