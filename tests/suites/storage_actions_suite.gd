extends "res://tests/suites/suite_base.gd"

const Actions := preload("res://scripts/systems/storage_actions_system.gd")
const Sorting := preload("res://scripts/systems/storage_sort_system.gd")
const Render := preload("res://scripts/presentation/storage_actions_renderer.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Controls := preload("res://scripts/systems/dev_cabinet_input.gd")
const Locale := preload("res://scripts/systems/storage_actions_locale.gd")

## Проверяет полные и совпадающие переносы, сортировку, все способы ввода и сохранность предметов.
func run() -> void:
	test_chest_all_items_and_equipment()
	test_matching_snapshot_and_repeated_actions()
	test_unique_and_failed_withdrawals_are_lossless()
	test_cabinet_deposit_ignores_filters_and_keeps_surplus()
	test_sorting_preserves_selection_and_gameplay_data()
	test_cabinet_count_order_refreshes_after_transfers()
	test_routed_keyboard_gamepad_pointer_and_search()
	test_pause_release_switch_and_json_saves()
	test_localized_button_geometry()

## Очищает стартовый рюкзак и открывает нужное реальное окно без вступительной сцены.
func prepare(game: Node, cabinet: bool=false) -> void:
	for kind in game.InventorySystem.ITEM_DATA:
		var count:int=game.inventory_item_count(kind)
		if count>0: game.change_inventory_count(kind,-count)
	for slot in game.equipment: game.equipment[slot]=""
	game.equipped_weapon="none"; game.sword_equipped=false
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION if cabinet else game.StorageSystem.CHEST_POSITION+Vector2(80,0)
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.tutorial_visible=false; game.home_chest_owned=true; game.home_chest_counts.clear()
	if cabinet: Cabinet.open(game)
	else: game.StorageSystem.open(game)

## Создаёт настоящее касание новой кнопки для основного маршрута ввода.
func touch(point: Vector2) -> InputEventScreenTouch:
	var event:=InputEventScreenTouch.new(); event.position=point; event.index=0; event.pressed=true; return event

## Сценарий: одной кнопкой переносится полный реестр вещей, включая надетое снаряжение.
## Исходное состояние: открытый сундук, все зарегистрированные виды в рюкзаке, шлем и лук надеты.
## Ожидаемый результат: количества сохраняются, последняя экипированная копия снимается, набор установки сундука остаётся у героя.
func test_chest_all_items_and_equipment() -> void:
	var game:=make_game(); prepare(game); var before:={}; var expected:=0
	for kind in game.InventorySystem.ITEM_DATA:
		game.change_inventory_count(kind,1 if kind in Cabinet.UNIQUE else 3)
		before[kind]=game.inventory_item_count(kind)
		if kind!="home_chest": expected+=int(before[kind])
	game.InventorySystem.equip(game,"iron_helmet"); game.equipped_weapon="bow"; game.equipment.hands="bow"
	var hotbar:Array=game.hotbar_slots.duplicate(); var energy:float=game.energy; var coins:int=game.coins
	game.storage_side=1
	expect(Actions.deposit_all(game,false)==expected,"store-all always moves the whole bag, even while chest column is active")
	for kind in before:
		expect(game.inventory_item_count(kind)+game.state.storage.count(kind)==int(before[kind]),"every item conserved across bulk transfer: "+kind)
		if kind!="home_chest": expect(game.inventory_item_count(kind)==0,"every transferable catalog kind left the bag: "+kind)
	expect(game.equipment.head.is_empty() and game.equipment.hands.is_empty() and game.equipped_weapon=="none","last worn copies unequip and clear active weapon")
	expect(game.energy==energy and game.coins==coins and game.hotbar_slots==hotbar,"bulk transfer spends no money or energy and keeps hotbar bindings")
	expect(game.inventory_item_count("home_chest")==3 and game.tutorial_events_completed.has("storage_quick"),"normal chest keeps its installation kit and records new tutorial")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game))); var restored:=make_game()
	expect(restored.SaveSystem.apply(restored,saved),"full storage supply survives a validated JSON save")
	for kind in before: expect(restored.inventory_item_count(kind)+restored.state.storage.count(kind)==int(before[kind]),"JSON preserves every deposited item: "+kind)
	var legacy:=saved.duplicate(true); legacy.weapons.erase("pickaxe"); legacy.weapons.erase("fishing_rod")
	expect(restored.SaveSystem.apply(restored,legacy) and not restored.has_pickaxe and not restored.has_fishing_rod,"old stored unique tools migrate without regenerating copies in the bag")
	var invalid:=saved.duplicate(true); invalid.weapons.pickaxe=3
	expect(not restored.SaveSystem.apply(restored,invalid) and not restored.has_pickaxe and restored.state.storage.count("pickaxe")==1,"malformed optional ownership flag is rejected atomically")
	restored.free(); game.free()

## Сценарий: пополнение существующих стеков отличается от переноса всего рюкзака.
## Исходное состояние: в сундуке две доски и нулевая запись моркови, в рюкзаке доски, морковь и молоко.
## Ожидаемый результат: совпадением считается положительный остаток до операции, пустые записи и новые виды не переносятся.
func test_matching_snapshot_and_repeated_actions() -> void:
	var game:=make_game(); prepare(game)
	game.home_chest_counts={"plank":2,"carrot":0}; game.change_inventory_count("plank",10); game.change_inventory_count("carrot",5); game.change_inventory_count("milk",4)
	expect(Actions.candidates(game,false,true)=={"plank":10},"matching snapshot excludes zero destination records and new types")
	expect(Actions.deposit_all(game,false,true)==10 and game.state.storage.count("plank")==12,"matching adds exact full stack to existing positive supply")
	expect(game.carrots==5 and game.inventory_item_count("milk")==4 and game.state.storage.count("carrot")==0,"matching leaves unrelated types in the bag")
	var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(Actions.deposit_all(game,false,true)==0 and game.export_inventory_counts()==before,"repeat matching transfers nothing and never creates a stack")
	expect(Actions.deposit_all(game,false)==9 and game.carrots==0 and game.state.storage.count("milk")==4,"all transfers both remaining types after matching")
	expect(Actions.deposit_all(game,false)==0 and game.message==Locale.text(game,"none"),"empty bag gives readable feedback without duplication")
	game.free()

## Сценарий: обратный перенос уникальных вещей не уничтожает стек и не выдаёт вторую копию герою.
## Исходное состояние: три кирки и доски в сундуке, неизвестный старый вид и неприменимый счётчик героя.
## Ожидаемый результат: выдаётся одна кирка, остаток сохраняется; повтор и невалидная выдача ничего не списывают.
func test_unique_and_failed_withdrawals_are_lossless() -> void:
	var game:=make_game(); prepare(game); game.home_chest_counts={"pickaxe":3,"plank":5,"unknown_old_item":2}
	expect(game.StorageSystem.withdraw(game,"pickaxe",3) and game.has_pickaxe and game.state.storage.count("pickaxe")==2,"whole-stack withdrawal caps unique transfer to one without losing remainder")
	expect(not game.StorageSystem.withdraw(game,"pickaxe",3) and game.state.storage.count("pickaxe")==2,"owned unique item cannot consume another stored copy")
	expect(not game.StorageSystem.withdraw(game,"unknown_old_item",2) and game.state.storage.count("unknown_old_item")==2,"unknown saved item is not deleted by failed transfer")
	game.state.inventory.counts.erase("plank")
	expect(not game.StorageSystem.withdraw(game,"plank",5) and game.state.storage.count("plank")==5,"failed inventory addition preserves the source stack")
	game.free()

## Сценарий: шкаф принимает вещи обратно даже при поиске другого вида и увеличивает запас выше 999.
## Исходное состояние: открыта вкладка еды с поиском досок, доски в шкафу закончились, яблоки присутствуют.
## Ожидаемый результат: совпадения проверяют реальный склад, полный перенос не ограничен фильтром, пополнение не уничтожает внесённый избыток.
func test_cabinet_deposit_ignores_filters_and_keeps_surplus() -> void:
	var game:=make_game(); prepare(game,true)
	Cabinet.state(game).stock.plank=0; game.change_inventory_count("plank",5); game.change_inventory_count("apple",4); game.change_inventory_count("home_chest",2)
	Cabinet.select_tab(game,2); Controls.query(game,"plank")
	expect(Cabinet.items(game).is_empty() and Actions.deposit_all(game,true,true)==6,"matching operates on full stock instead of empty current search results")
	expect(game.inventory_item_count("plank")==5 and int(Cabinet.state(game).stock.plank)==0,"zero-stock type remains outside matching despite registered cabinet slot")
	expect(int(Cabinet.state(game).stock.apple)==1003 and int(Cabinet.state(game).stock.home_chest)==1001,"cabinet accepts surplus and installation items without installing anything")
	expect(Actions.deposit_all(game,true)==5 and game.inventory_item_count("plank")==0 and int(Cabinet.state(game).stock.plank)==5,"all stores the remaining filtered-out material")
	Cabinet.refill(game)
	expect(int(Cabinet.state(game).stock.plank)==999 and int(Cabinet.state(game).stock.apple)==1003,"refill restores depleted supply and preserves deposited surplus")
	Controls.query(game,""); Cabinet.select_tab(game,0)
	game.change_inventory_count("bow",1); game.equipped_weapon="bow"; game.equipment.hands="bow"
	expect(Actions.deposit_all(game,true)==1 and not game.has_bow and game.equipped_weapon=="none","returning unique weapon clears ownership and worn equipment")
	expect(Cabinet.take(game,"bow",999) and game.has_bow and int(Cabinet.state(game).stock.bow)==999,"returned unique item remains usable and is not duplicated")
	game.free()

## Сценарий: обе стороны имеют три порядка, сохраняющие выбранный предмет и игровые данные.
## Исходное состояние: четыре вида с разными количествами, выбранная морковь, неизменные быстрые слоты и содержимое сундука.
## Ожидаемый результат: имя, тип и количество переставляют только представление или слоты, JSON сохраняет вещи и порядок рюкзака.
func test_sorting_preserves_selection_and_gameplay_data() -> void:
	var game:=make_game(); prepare(game)
	for entry in [["stone",7],["apple",2],["carrot",2],["plank",15]]: game.change_inventory_count(entry[0],entry[1])
	game.inventory_slots=["stone","apple","carrot","plank"]; game.inventory_selected=2; game.storage_selected=2
	game.home_chest_counts={"stone":7,"apple":2,"carrot":2,"plank":15}
	var counts:Dictionary=game.export_inventory_counts().duplicate(); var stock:Dictionary=game.home_chest_counts.duplicate(); var hotbar:Array=game.hotbar_slots.duplicate(); var equipment:Dictionary=game.equipment.duplicate()
	Actions.sort_bag(game,false)
	expect(Sorting.mode(game,"bag")=="name" and game.inventory_slots.slice(0,4)==["plank","stone","apple","carrot"],"first sort orders localized names")
	Actions.sort_bag(game,false)
	expect(Sorting.mode(game,"bag")=="category" and game.inventory_slots.slice(0,4)==["apple","carrot","plank","stone"],"second sort groups food before materials")
	Actions.sort_bag(game,false)
	expect(Sorting.mode(game,"bag")=="count" and game.inventory_slots.slice(0,4)==["plank","stone","apple","carrot"],"third sort puts larger stacks first and names break ties")
	expect(game.inventory_slots[game.inventory_selected]=="carrot" and game.StorageSystem.inventory_items(game)[game.storage_selected]=="carrot","backpack and chest selection follow the same item through sorting")
	game.storage_side=1; game.storage_selected=game.StorageSystem.stored_items(game).find("carrot")
	for _mode in 3: Actions.sort_container(game,false)
	expect(game.StorageSystem.stored_items(game)==["plank","stone","apple","carrot"] and game.StorageSystem.stored_items(game)[game.storage_selected]=="carrot","storage sorting preserves its focused item")
	expect(counts==game.export_inventory_counts() and stock==game.home_chest_counts and hotbar==game.hotbar_slots and equipment==game.equipment,"sorting changes no quantities, equipment or quick bindings")
	var data:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game))); var slots:Array=game.inventory_slots.duplicate()
	expect(game.SaveSystem.apply(game,data) and game.inventory_slots==slots and not game.has_meta(Sorting.META),"sorted bag is saved while temporary view modes reset")
	game.free()

## Сценарий: сортировка шкафа по количеству обновляется после выдачи и возврата с сохранением фокуса.
## Исходное состояние: в шкафу девять камней и пять досок, прочие остатки нулевые, выбран камень.
## Ожидаемый результат: изменение количества переставляет виды сразу, выделение остаётся на камне, пополнение также сохраняет фокус.
func test_cabinet_count_order_refreshes_after_transfers() -> void:
	var game:=make_game(); prepare(game,true); var value:=Cabinet.state(game)
	for kind in value.stock: value.stock[kind]=0
	value.stock.stone=9; value.stock.plank=5; Cabinet.refresh_selection(game,"stone")
	for _mode in 3: Actions.sort_container(game,true)
	expect(Cabinet.items(game).slice(0,2)==["stone","plank"] and Cabinet.selected(game)=="stone","count order initially puts larger stock first and preserves focus")
	expect(Cabinet.take(game,"stone",8) and Cabinet.items(game).slice(0,2)==["plank","stone"] and Cabinet.selected(game)=="stone","withdrawal invalidates sorted cache and follows the same item")
	expect(Actions.deposit_all(game,true,true)==8 and Cabinet.items(game).slice(0,2)==["stone","plank"] and Cabinet.selected(game)=="stone","deposit restores count order without moving selection to another item")
	Cabinet.refill(game); expect(Cabinet.selected(game)=="stone","refill keeps the selected type even after all quantities become equal")
	game.free()

## Сценарий: все новые кнопки достигаются основным маршрутизатором без конфликта с вводом поиска.
## Исходное состояние: открытый сундук или шкаф, предметы и реальные события клавиатуры, геймпада, мыши, касаний.
## Ожидаемый результат: D/M/S/T и кнопки выполняют нужную операцию, печать в поиске не переносит вещи.
func test_routed_keyboard_gamepad_pointer_and_search() -> void:
	var game:=make_game(); prepare(game); game.change_inventory_count("plank",10)
	game._input(key_event(KEY_D,KEY_D,true)); expect(game.inventory_item_count("plank")==0 and game.state.storage.count("plank")==10,"keyboard D deposits all through the real route")
	game.change_inventory_count("plank",3); game.change_inventory_count("apple",5)
	game._input(joypad_button_event(JOY_BUTTON_BACK,true)); expect(game.inventory_item_count("plank")==0 and game.inventory_item_count("apple")==5,"gamepad View stores only matching types")
	game._input(joypad_button_event(JOY_BUTTON_RIGHT_STICK,true)); expect(Sorting.mode(game,"bag")=="name" and Sorting.mode(game,"container")=="name","R3 sorts both sides without closing storage")
	var mouse:=InputEventMouseButton.new(); mouse.pressed=true; mouse.button_index=MOUSE_BUTTON_LEFT; mouse.position=Render.rect(2,false).get_center(); game._input(mouse)
	expect(Sorting.mode(game,"bag")=="category","routed mouse reaches backpack sorting button")
	game._input(touch(Render.rect(0,false).get_center())); expect(game.inventory_item_count("apple")==0 and game.state.storage.count("apple")==5,"routed touch stores all remaining items")
	game.storage_open=false; prepare(game,true); game.change_inventory_count("plank",7)
	game._input(key_event(KEY_F,KEY_F,true)); var letter:=key_event(KEY_D,KEY_D,true); letter.unicode=100; game._input(letter)
	expect(Cabinet.state(game).query=="d" and game.inventory_item_count("plank")==7,"typing D in focused search never triggers deposit")
	game._input(key_event(KEY_ESCAPE,KEY_ESCAPE,true)); game._input(touch(Render.rect(0,true).get_center()))
	expect(game.inventory_item_count("plank")==0 and int(Cabinet.state(game).stock.plank)==1006,"cabinet touch deposits into actual stock")
	game.change_inventory_count("plank",2); game._input(joypad_button_event(JOY_BUTTON_START,true))
	expect(game.inventory_item_count("plank")==0 and int(Cabinet.state(game).stock.plank)==1008,"cabinet Start stores all despite retained search query")
	game._input(key_event(KEY_T,KEY_T,true)); expect(Sorting.mode(game,"container")=="category" and Cabinet.active(game),"cabinet sorting uses its own window and keeps it open")
	game.free()

## Сценарий: быстрые действия не снимают паузу и не работают в отключённом или чужом хранилище.
## Исходное состояние: открытые реальные окна, рабочие часы, предметы и переключаемая настройка разработчика.
## Ожидаемый результат: физический мир стоит, закрытые и выключенные окна не меняют вещи, временный шкаф исключён из JSON.
func test_pause_release_switch_and_json_saves() -> void:
	for cabinet in [false,true]:
		var game:=make_game(); prepare(game,cabinet); game.change_inventory_count("plank",5)
		var minutes:float=game.game_minutes; var energy:float=game.energy; var player:Vector2=game.player; game.regeneration_timer=5
		Actions.deposit_all(game,cabinet); Actions.sort_bag(game,cabinet); Actions.sort_container(game,cabinet); game._physics_process(3)
		expect(game.game_minutes==minutes and game.player==player and game.energy==energy and game.regeneration_timer==5,"quick actions keep real physics paused in each storage window")
		var before:Dictionary=game.export_inventory_counts().duplicate(); game.current_location="forest"
		expect(Actions.deposit_all(game,cabinet)==0 and game.export_inventory_counts()==before,"remote window cannot move inventory")
		game.current_location="cottage_interior"
		game.menu_state.pause_open=true
		expect(Actions.deposit_all(game,cabinet)==0 and not Actions.handle_input(game,key_event(KEY_D,KEY_D,true),cabinet),"pause overlay keeps bulk commands inactive")
		game.menu_state.pause_open=false
		if cabinet:
			var enabled:bool=Cabinet.enabled(); ProjectSettings.set_setting(Cabinet.SETTING,false)
			expect(Actions.deposit_all(game,true)==0 and not Render.pointer(game,Render.rect(0,true).get_center(),true),"release switch disables all cabinet actions")
			ProjectSettings.set_setting(Cabinet.SETTING,enabled)
			var data:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
			expect(not JSON.stringify(data).contains(Cabinet.META) and game.SaveSystem.apply(game,data) and int(Cabinet.state(game).stock.plank)==999,"temporary supply keeps its explicit session-only save contract")
		else:
			game.storage_open=false; expect(Actions.deposit_all(game,false)==0,"closed chest rejects bulk mutation")
		game.free()

## Сценарий: новые кнопки читаются и не перекрывают прежние действия, списки или поиск.
## Исходное состояние: оба окна, четыре прямоугольника действий, шесть языков и масштаб текста 120%.
## Ожидаемый результат: рисунок и hit-зоны общие, кнопки раздельны, все подписи и три режима помещаются.
func test_localized_button_geometry() -> void:
	var game:=make_game(); game.settings_state.text_scale=1.2
	for cabinet in [false,true]:
		for index in Render.KEYS.size():
			var rect:=Render.rect(index,cabinet)
			expect(Rect2(0,0,1152,648).encloses(rect) and rect.size.y>=32,"new action stays on screen with a usable hit area")
			for other in range(index+1,Render.KEYS.size()): expect(not rect.intersects(Render.rect(other,cabinet)),"new storage actions never overlap")
			if not cabinet: expect(not rect.intersects(game.InterfaceRenderer.STORAGE_LEFT_ROWS) and not rect.intersects(game.InterfaceRenderer.STORAGE_RIGHT_ROWS) and not rect.intersects(game.InterfaceRenderer.STORAGE_TRANSFER_ONE) and not rect.intersects(game.InterfaceRenderer.STORAGE_TRANSFER_ALL),"chest toolbar avoids rows and old stack actions")
			else: expect(not rect.intersects(preload("res://scripts/presentation/dev_cabinet_renderer.gd").SEARCH),"cabinet toolbar never overlaps search")
		for locale in game.LocaleSystem.LOCALES:
			game.LocaleSystem.current=locale
			for order in ["","name","category","count"]:
				game.set_meta(Sorting.META,{"bag":order,"container":order})
				for index in Render.KEYS.size():
					var key:String=Render.KEYS[index]; var label:String=Locale.sort_label(game,key) if index>=2 else Locale.text(game,key)
					var rect:=Render.rect(index,cabinet).grow(-10)
					var size:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,label,rect.size.x,rect.size.y,12)
					expect(size>=8 and game.UI_FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=rect.size.x,"scaled action label fits: "+locale+" "+label)
	game.free()
