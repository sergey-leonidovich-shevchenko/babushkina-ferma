extends "res://tests/suites/suite_base.gd"

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Controls := preload("res://scripts/systems/dev_cabinet_input.gd")
const Render := preload("res://scripts/presentation/dev_cabinet_renderer.gd")
const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")
const Locale := preload("res://scripts/systems/dev_cabinet_locale.gd")

## Проверяет полный склад, категории, физический доступ, выдачу, ввод, паузу, сохранение и выключение перед релизом.
func run() -> void:
	test_full_catalog_and_categories()
	test_room_access_and_feature_switch()
	test_all_items_transfer_without_free_side_effects()
	test_keyboard_search_controller_and_touch()
	test_pointer_focus_is_inspection_only()
	test_real_world_pause_and_release()
	test_save_load_and_old_slots()
	test_localized_layout()

## Ставит героя у шкафа и отключает только вступительную сцену стенда.
func prepare(game: Node) -> void:
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.tutorial_visible=false

## Создаёт настоящее касание для проверки того же маршрута, что принимает мобильная игра.
func touch(position: Vector2) -> InputEventScreenTouch:
	var event:=InputEventScreenTouch.new(); event.position=position; event.index=1; event.pressed=true; return event

## Сценарий: шкаф охватывает весь реестр и сохраняет каждый вид в одной тематической категории.
## Исходное состояние: новая игра, все основные и недавно добавленные предметы, пустой временный склад.
## Ожидаемый результат: каждый предмет имеет запас 999, новые регистрации подхватываются, категории дают полное объединение.
func test_full_catalog_and_categories() -> void:
	var game:=make_game(); var before:Dictionary=game.export_inventory_counts().duplicate()
	var value:=Cabinet.state(game)
	expect(value.stock.size()==game.InventorySystem.ITEM_DATA.size() and Cabinet.items(game).size()==value.stock.size(),"cabinet includes every registered item, not a hand-picked subset")
	for kind in game.InventorySystem.ITEM_DATA: expect(int(value.stock[kind])==999,"every cabinet item starts at 999: "+kind)
	var union:={}
	for index in range(1,Cabinet.TABS.size()):
		Cabinet.select_tab(game,index)
		for kind in Cabinet.items(game):
			expect(not union.has(kind),"categories do not duplicate the same item: "+kind); union[kind]=true
	expect(union.size()==value.stock.size() and before==game.export_inventory_counts(),"category browsing covers all items without granting them")
	expect(Cabinet.category(game,"seeds")=="seeds" and Cabinet.category(game,"tomato_seeds")=="seeds","seed bags are separate from tools")
	expect(Cabinet.category(game,"greater_mana")=="alchemy" and Cabinet.category(game,"moon_grass_powder")=="alchemy","potions and processed herbs stay together")
	expect(Cabinet.category(game,"bread")=="food" and Cabinet.category(game,"plank")=="craft" and Cabinet.category(game,"iron_spear")=="equipment","food, materials and equipment occupy their expected tabs")
	expect(Cabinet.category(game,"hand")=="tools" and Cabinet.category(game,"ancient_key")=="other","base actions and quest items remain available")
	var entry:Dictionary={"name":"Test item","short":"Test","color":Color.WHITE}; game.InventorySystem.ITEM_DATA["cabinet_future_item"]=entry
	expect(Cabinet.state(game).stock.get("cabinet_future_item",0)==999,"future registered item enters the full cabinet automatically")
	game.InventorySystem.ITEM_DATA.erase("cabinet_future_item"); Cabinet.state(game); game.free()

## Сценарий: декоративный шкаф слева становится доступной услугой только в режиме разработки.
## Исходное состояние: обычный дом, входная точка, кровать и переключаемая настройка снабжения.
## Ожидаемый результат: герой может дойти до шкафа, обычное действие открывает окно, выключение убирает доступ и выдачу.
func test_room_access_and_feature_switch() -> void:
	var game:=make_game(); prepare(game)
	expect(game.NavigationSystem.is_walkable(game,Cabinet.POSITION),"cabinet has an actual walkable operating point")
	game.player=game.BuildingSystem.INTERIORS.cottage_interior.spawn
	for waypoint in [Vector2(Cabinet.POSITION.x,500),Cabinet.POSITION]:
		for _step in 180:
			if game.player.distance_to(waypoint)<0.1: break
			game.NavigationSystem.move(game,game.player.direction_to(waypoint)*minf(4,game.player.distance_to(waypoint)))
	expect(game.player.distance_to(Cabinet.POSITION)<0.1 and game.nearest_interaction()=="interior_service:dev_cabinet","normal movement from cottage entrance reaches the cabinet")
	expect(game.perform_context_action() and Cabinet.active(game) and game.tutorial_events_completed.has("dev_cabinet"),"context opens real cabinet and its tutorial")
	Cabinet.close(game); game.player=Vector2(300,390)
	expect(game.nearest_interaction()=="interior_service:bed" and not Cabinet.open(game),"cabinet does not steal the bed interaction or open remotely")
	prepare(game); Cabinet.open(game); var before:Dictionary=game.export_inventory_counts().duplicate()
	var was_enabled:bool=Cabinet.enabled(); ProjectSettings.set_setting(Cabinet.SETTING,false)
	expect(not Cabinet.active(game) and not Cabinet.open(game) and not Cabinet.take(game,"plank",999),"single release setting disables UI, interaction and all transfers")
	expect(game.nearest_interaction()!="interior_service:dev_cabinet" and before==game.export_inventory_counts(),"disabled developer cabinet grants nothing")
	ProjectSettings.set_setting(Cabinet.SETTING,was_enabled); Cabinet.close(game); game.current_location="forest"
	expect(not Cabinet.open(game),"cabinet cannot be summoned in another location")
	game.free()

## Сценарий: каждый вид можно получить с корректным остатком, без списаний героя и действий домашнего сундука.
## Исходное состояние: открытый шкаф, обычные предметы и пять старых уникальных видов.
## Ожидаемый результат: стек переносится точно, уникальный вид не теряется при повторной выдаче, пополнение меняет только шкаф.
func test_all_items_transfer_without_free_side_effects() -> void:
	var game:=make_game(); prepare(game); Cabinet.open(game)
	var energy:float=game.energy; var coins:int=game.coins; var chest:Dictionary=game.home_chest_counts.duplicate(); var crafted:int=game.state.player.craft_count
	for kind in Cabinet.state(game).stock:
		var before:int=game.inventory_item_count(kind); var amount:int=Cabinet.amount(game,kind,999)
		var success:=Cabinet.take(game,kind,999)
		expect(success==(amount>0),"every catalog entry obeys the actual inventory model: "+kind)
		expect(game.inventory_item_count(kind)==before+amount and int(Cabinet.state(game).stock[kind])==999-amount,"exact item and source quantities: "+kind)
		if amount>0: expect(game.inventory_slots.has(kind),"issued item occupies a usable backpack slot: "+kind)
	expect(game.energy==energy and game.coins==coins and game.home_chest_counts==chest and game.state.player.craft_count==crafted,"developer supply changes no energy, coins, ordinary chest or crafting progress")
	var counts:Dictionary=game.export_inventory_counts().duplicate(); Cabinet.refill(game)
	expect(counts==game.export_inventory_counts() and Cabinet.state(game).stock.values().all(func(count): return int(count)==999),"refill restores every supply without issuing a second batch")
	expect(Cabinet.take(game,"plank",10) and int(Cabinet.state(game).stock.plank)==989,"ten-unit transfer pays exactly ten")
	expect(Cabinet.take(game,"plank",100) and int(Cabinet.state(game).stock.plank)==889,"hundred-unit transfer pays exactly one hundred")
	expect(Cabinet.take(game,"plank",999) and int(Cabinet.state(game).stock.plank)==0,"whole-stack action clamps to remaining stock")
	counts=game.export_inventory_counts().duplicate()
	expect(not Cabinet.take(game,"plank",1) and not Cabinet.take(game,"unknown",999) and not Cabinet.take(game,"apple",-1) and counts==game.export_inventory_counts(),"empty, unknown and negative transfers are atomic")
	var unique_stock:int=Cabinet.state(game).stock.bow
	expect(not Cabinet.take(game,"bow",999) and int(Cabinet.state(game).stock.bow)==unique_stock,"already-owned legacy weapon does not waste a cabinet copy")
	var data:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game))); var restored:=make_game()
	expect(restored.SaveSystem.apply(restored,data),"a real JSON save accepts all supplied items together")
	for kind in game.InventorySystem.ITEM_DATA: expect(restored.inventory_item_count(kind)==game.inventory_item_count(kind),"every supplied item survives full JSON loading: "+kind)
	restored.free()
	game.free()

## Сценарий: клавиатура, геймпад, поиск и касание работают в общем модальном маршруте.
## Исходное состояние: открытый склад с полной выдачей и многими страницами.
## Ожидаемый результат: ввод не попадает в мир, поиск поддерживает название и идентификатор, страницы и явные кнопки доступны.
func test_keyboard_search_controller_and_touch() -> void:
	var game:=make_game(); prepare(game); Cabinet.open(game)
	game._input(key_event(KEY_PAGEDOWN,KEY_PAGEDOWN,true)); expect(int(Cabinet.state(game).selected)==35,"keyboard reaches next grid rows of full inventory")
	game._input(key_event(KEY_END,KEY_END,true)); expect(int(Cabinet.state(game).selected)==Cabinet.items(game).size()-1,"keyboard reaches last item of the whole registry")
	game._input(key_event(KEY_E,KEY_E,true)); expect(int(Cabinet.state(game).tab)==1 and int(Cabinet.state(game).selected)==0,"tab switches category before regular backpack shortcut")
	game._input(key_event(KEY_F,KEY_F,true))
	for character in "plank":
		var event:=key_event(KEY_P,KEY_P,true); event.unicode=String(character).unicode_at(0); game._input(event)
	expect(Cabinet.state(game).query=="plank" and Cabinet.items(game)==["plank"],"typed search accepts IDs and ignores world hotkeys")
	game._input(key_event(KEY_ENTER,KEY_ENTER,true)); var before:int=game.inventory_item_count("plank")
	var hundred:=key_event(KEY_ENTER,KEY_ENTER,true); hundred.shift_pressed=true; game._input(hundred)
	expect(game.inventory_item_count("plank")==before+100 and int(Cabinet.state(game).stock.plank)==899,"real keyboard route transfers one hundred")
	Controls.query(game,"доски"); expect(Cabinet.items(game)==["plank"],"search also matches localized names")
	Controls.query(game,""); game._input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true))
	expect(int(Cabinet.state(game).tab)==2,"gamepad shoulder selects food")
	game._input(touch(Render.tab_rect(6).get_center())); expect(int(Cabinet.state(game).tab)==6,"touch selects seeds tab")
	var seed:=Cabinet.selected(game); before=game.inventory_item_count(seed)
	game._input(touch(Render.take_rect(1).get_center())); expect(game.inventory_item_count(seed)==before+10,"touch transfers ten from its visible button")
	game._input(touch(Render.REFILL.get_center())); expect(int(Cabinet.state(game).stock[seed])==999,"touch refills all categories")
	game._input(key_event(KEY_F,KEY_F,true)); Controls.query(game,"no_such_item_here")
	expect(Cabinet.items(game).is_empty() and Cabinet.selected(game)=="","empty search remains navigable")
	game._input(key_event(KEY_ESCAPE,KEY_ESCAPE,true)); expect(Cabinet.active(game),"first escape only releases search focus")
	game._input(joypad_button_event(JOY_BUTTON_B,true)); expect(not Cabinet.active(game) and not game.inventory_open,"controller closes only the cabinet")
	game.free()

## Сценарий: склад останавливает настоящие игровые часы, урон и производственные очереди.
## Исходное состояние: герой у шкафа, оплаченная партия в личном прессе и активный яд или регенерация.
## Ожидаемый результат: физический кадр не продвигает мир, атаки и движение не проходят, закрытие снимает удержание.
func test_real_world_pause_and_release() -> void:
	var game:=make_game(); prepare(game)
	var fixture:=preload("res://tests/suites/artisan_suite.gd").new(context); fixture.enter(game)
	var press:=fixture.place(game,"fruit_press",25,18); fixture.finish(game,press); fixture.open_station(game,press)
	var recipe:Dictionary=game.WorkshopSystem.Data.Recipes.recipe("artisan:fruit_press:apple_juice")
	for kind in recipe.inputs: game.change_inventory_count(kind,int(recipe.inputs[kind]))
	game.WorkshopSystem.enqueue(game,recipe); game.crafting_open=false; prepare(game)
	game.action_held=true; game.attack_held=true; game.regeneration_timer=5
	expect(Cabinet.open(game) and not game.action_held and not game.attack_held,"opening clears all held world actions")
	var remaining:float=press.production.queue[0].remaining; var minutes:float=game.game_minutes; var player:Vector2=game.player; var hp:int=game.player_hp
	game._input(key_event(KEY_SPACE,KEY_SPACE,true)); game._input(key_event(KEY_W,KEY_W,true)); game._physics_process(3)
	expect(game.player==player and game.player_hp==hp and game.game_minutes==minutes and game.regeneration_timer==5,"actual physics freezes movement, clock and status effects")
	expect(is_equal_approx(press.production.queue[0].remaining,remaining) and not game.action_held and not game.attack_held,"actual physics freezes cellar queue and blocks combat input")
	game._input(key_event(KEY_ESCAPE,KEY_ESCAPE,true)); expect(not Cabinet.active(game) and not game.action_held and not game.attack_held,"close leaves no lingering action")
	game._physics_process(0.5)
	expect(float(press.production.queue[0].remaining)<remaining and game.game_minutes>minutes,"closing resumes actual production and clock")
	game.free()

## Сценарий: игровые предметы сохраняются, временный склад не засоряет слот и не удерживает его на паузе.
## Исходное состояние: выданы 100 досок и 999 единиц базового инструмента, открыт шкаф и сделан снимок.
## Ожидаемый результат: загруженный рюкзак сохраняет количества, шкаф сбрасывается до 999, некорректная загрузка его не меняет.
func test_save_load_and_old_slots() -> void:
	var game:=make_game(); prepare(game); Cabinet.open(game); Cabinet.take(game,"plank",100); Cabinet.take(game,"hoe",999)
	var before:int=game.inventory_item_count("plank"); var data:Dictionary=JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
	expect(not JSON.stringify(data).contains(Cabinet.META) and game.SaveSystem.ValidationSystem.valid(data),"temporary cabinet state is omitted from validated gameplay save")
	var invalid:=data.duplicate(true); invalid.location=""
	expect(not game.SaveSystem.apply(game,invalid) and Cabinet.active(game) and int(Cabinet.state(game).stock.plank)==899,"rejected save leaves current cabinet and stock intact")
	expect(game.SaveSystem.apply(game,data) and not Cabinet.active(game) and not game.has_meta(Cabinet.META),"valid load closes and resets temporary cabinet")
	expect(game.inventory_item_count("plank")==before and game.inventory_item_count("hoe")==999,"stackable supply and base tools survive JSON loading")
	expect(int(Cabinet.state(game).stock.plank)==999,"fresh session supply starts replenished")
	for kind in ["hoe","water","hand"]: data.counts.erase(kind)
	expect(game.SaveSystem.apply(game,data) and game.inventory_item_count("hoe")==0 and game.inventory_item_count("plank")==before,"old saves without explicit base tools remain compatible")
	game.free()

## Сценарий: наведение раскрывает предмет справа, а клавиатура и геймпад продолжают управлять тем же фокусом.
## Исходное состояние: полный открытый шкаф, вторая страница, активный поиск и пустые ячейки результата.
## Ожидаемый результат: карточка следует фокусу, наведение не выдаёт вещи, не переключает поиск и не выбирает пустоту.
func test_pointer_focus_is_inspection_only() -> void:
	var game:=make_game(); prepare(game); Cabinet.open(game)
	var choices:=Cabinet.items(game); var expected_index:=0; var stock:Dictionary=Cabinet.state(game).stock.duplicate(); var bag:Dictionary=game.export_inventory_counts().duplicate()
	var motion:=InputEventMouseMotion.new(); motion.position=Render.slot_rect(8).get_center(); game._input(motion)
	expect(Cabinet.selected(game)==choices[8],"mouse hover changes the item used by the right-hand card")
	game._input(key_event(KEY_PAGEDOWN,KEY_PAGEDOWN,true)); expected_index=Render.start(game)+2; motion.position=Render.slot_rect(2).get_center(); game._input(motion)
	expect(Cabinet.selected(game)==choices[expected_index],"hover addresses the actual item on the second page")
	game._input(key_event(KEY_RIGHT,KEY_RIGHT,true)); expect(Cabinet.selected(game)==choices[expected_index+1],"keyboard focus replaces the hovered item without mouse movement")
	game._input(joypad_button_event(JOY_BUTTON_DPAD_DOWN,true)); expect(Cabinet.selected(game)==choices[expected_index+1+Render.COLUMNS],"controller focus also drives the right-hand card")
	motion.position=Render.take_rect(0).get_center(); game._input(motion)
	expect(Cabinet.selected(game)==choices[expected_index+1+Render.COLUMNS] and stock==Cabinet.state(game).stock and bag==game.export_inventory_counts(),"hovering cells and take buttons never transfers stock")
	game._input(key_event(KEY_F,KEY_F,true)); motion.position=Render.slot_rect(7).get_center(); game._input(motion)
	expect(Cabinet.state(game).searching and Cabinet.selected(game)==choices[expected_index+1+Render.COLUMNS],"mouse inspection preserves active search editing and its selected item")
	Controls.query(game,"plank"); game._input(key_event(KEY_ESCAPE,KEY_ESCAPE,true)); motion.position=Render.slot_rect(1).get_center(); game._input(motion)
	expect(Cabinet.selected(game)=="plank","hover over an empty result cell keeps the existing detail card")
	motion.position=Render.slot_rect(0).position+Vector2(59,20); game._input(motion)
	expect(Cabinet.selected(game)=="plank","gaps between cells cannot focus a hidden item")
	Controls.query(game,"no_such_item_here"); motion.position=Render.slot_rect(0).get_center(); game._input(motion)
	expect(Cabinet.selected(game)=="" and bag==game.export_inventory_counts(),"empty search remains harmless when the mouse enters its grid")
	game.free()

## Сценарий: категории, кнопки и подсказки читаются на каждом языке при увеличенном тексте.
## Исходное состояние: полноэкранная панель, восемь вкладок, четыре кнопки выдачи и последний слот сетки.
## Ожидаемый результат: элементы не выходят за экран и не перекрывают друг друга, подписи локализованы и помещаются.
func test_localized_layout() -> void:
	var game:=make_game(); var viewport:=Rect2(0,0,1152,648); game.settings_state.text_scale=1.2
	for index in Cabinet.TABS.size(): expect(viewport.encloses(Render.tab_rect(index)) and not Render.tab_rect(index).intersects(Render.SEARCH),"tab and search have separate screen bounds")
	for index in Render.VISIBLE:
		expect(Layout.PANELS[1].encloses(Render.slot_rect(index)),"full grid cell stays inside list panel")
		expect(Render.slot_rect(index).encloses(Render.icon_rect(index)) and Render.slot_rect(index).encloses(Render.count_rect(index)) and not Render.icon_rect(index).intersects(Render.count_rect(index)),"icon and count have separate visible areas in every cell")
	for index in Render.AMOUNTS.size(): expect(Layout.DETAIL.encloses(Render.take_rect(index)),"take button stays inside item card")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for kind in game.InventorySystem.ITEM_DATA:
			var name:String=game.inventory_item_name(kind); var area:Rect2=Render.DETAIL_TITLE
			var fitted:int=preload("res://scripts/presentation/storage_grid_renderer.gd").title_size(game,name)
			var measured:Vector2=game.UI_FONT.get_multiline_string_size(name,HORIZONTAL_ALIGNMENT_CENTER,area.size.x,fitted)
			expect(measured.x<=area.size.x+0.01 and measured.y<=area.size.y+0.01,"full localized name fits the right card at 120 percent: "+locale+" "+kind)
		expect(game.InventorySystem.data("wooden_wardrobe").short!="wooden_wardrobe","registered furniture retains a readable fallback label")
		for key in Locale.TEXT: expect(Locale.text(game,key,[1] if key in ["found","take","put","stock","bag"] else (["Item",1] if key=="taken" else []))!=key,"localized cabinet label: "+locale+" "+key)
		for index in Cabinet.TABS.size():
			var rect:=Render.tab_rect(index).grow(-6); var text:=Locale.text(game,Cabinet.TABS[index])
			var size:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,text,rect.size.x,rect.size.y,13)
			expect(game.UI_FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=rect.size.x,"scaled localized tab fits shared button: "+locale+" "+text)
	game.free()
