extends "res://tests/suites/suite_base.gd"

const Grid := preload("res://scripts/systems/storage_grid_system.gd")
const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Controls := preload("res://scripts/systems/storage_grid_input.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")

class NameProbe extends Node:
	var calls:=0
	## Считает обращения к имени, не замеряя нестабильные секунды на машине CI.
	func inventory_item_name(kind: String) -> String:
		calls+=1; return kind

## Проверяет строки обеих сторон, явные переносы, сенсорный ввод и подготовленные экранные размеры.
func run() -> void:
	test_independent_row_scrolling_and_focus()
	test_transfer_and_pointer_routes()
	test_drag_swipe_and_pause()
	test_two_texture_sizes_and_bounded_cache()
	test_sort_names_are_computed_once()

## Готовит доступный шкаф и достаточно видов в рюкзаке для нескольких строк.
func prepare(game: Node) -> void:
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	for kind in game.InventorySystem.ITEM_DATA:
		var count:int=game.inventory_item_count(kind)
		if count>0: game.change_inventory_count(kind,-count)
	var filled:=0
	for kind in game.InventorySystem.ITEM_DATA:
		if kind in Cabinet.UNIQUE: continue
		game.change_inventory_count(kind,40); filled+=1
		if filled>=40: break
	Cabinet.open(game)

## Сценарий: колесо двигает один ряд только под указателем, а клавиатура раскрывает выбранную строку.
## Исходное состояние: 40 видов слева, полный шкаф справа, обе стороны в начале.
## Ожидаемый результат: независимые первые индексы, отсутствие выдачи от прокрутки, последний предмет и пустые клетки безопасны.
func test_independent_row_scrolling_and_focus() -> void:
	var game:=make_game(); prepare(game); var before:Dictionary=game.export_inventory_counts().duplicate()
	for section in [Layout.PANELS[0],Layout.PANELS[1],Layout.DETAIL]:
		expect(Rect2(0,0,1152,648).encloses(section),"full-screen storage encloses both inventories and central detail")
	var wheel:=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; wheel.position=Layout.grid(1).get_center(); game._input(wheel)
	expect(Grid.start(game,true,1)==7 and Grid.start(game,true,0)==0,"cabinet wheel advances exactly one row without changing bag scroll")
	wheel.position=Layout.grid(0).get_center(); game._input(wheel)
	expect(Grid.start(game,true,0)==5 and Grid.start(game,true,1)==7 and before==game.export_inventory_counts(),"bag wheel changes its own row and never transfers inventory")
	Grid.select(game,true,1,0); game._input(key_event(KEY_END,KEY_END,true))
	expect(Cabinet.selected(game)==Cabinet.items(game).back() and Grid.start(game,true,1)==Grid.maximum_row(game,true,1)*7,"last item is reachable without a page boundary")
	var last:int=Grid.state(game,true).selected[1]; var motion:=InputEventMouseMotion.new(); motion.position=Layout.slot(1,34).get_center(); game._input(motion)
	expect(Grid.state(game,true).selected[1]==last,"empty last-row cells cannot select nonexistent items")
	Controls.query(game,"no_such_item"); expect(Grid.items(game,true,1).is_empty() and not Grid.items(game,true,0).is_empty(),"search filters only the cabinet while keeping the hero inventory visible")
	game.free()

## Сценарий: одинаковые центральные кнопки переносят из выбранной стороны и наведение только раскрывает предмет.
## Исходное состояние: открытый шкаф, оба остатка досок, затем установленный обычный сундук.
## Ожидаемый результат: точные количества в обоих направлениях, общий запас сохраняется, нет переноса от фокуса.
func test_transfer_and_pointer_routes() -> void:
	var game:=make_game(); prepare(game); game.change_inventory_count("plank",17)
	var index:int=Grid.items(game,true,0).find("plank"); Grid.select(game,true,0,index)
	var stock:int=Cabinet.state(game).stock.plank; var amount:int=game.inventory_item_count("plank")
	game._input(key_event(KEY_ENTER,KEY_ENTER,true)); expect(game.inventory_item_count("plank")==amount-1 and int(Cabinet.state(game).stock.plank)==stock+1,"left-side Enter deposits one into cabinet")
	Grid.select(game,true,1,Cabinet.items(game).find("plank")); Controls.pointer(game,Layout.transfer(1).get_center(),true)
	expect(game.inventory_item_count("plank")==amount+9 and int(Cabinet.state(game).stock.plank)==stock-9,"right-side visible quantity withdraws exactly ten")
	var before:Dictionary=game.export_inventory_counts().duplicate(); var motion:=InputEventMouseMotion.new(); motion.position=Layout.slot(0,0).get_center(); game._input(motion)
	expect(Grid.state(game,true).side==0 and before==game.export_inventory_counts(),"hover on hero inventory drives the central card without moving anything")
	var kind:=Grid.selected(game,true); preload("res://scripts/systems/storage_actions_system.gd").sort_bag(game,true)
	expect(Grid.selected(game,true)==kind,"hero-side cabinet sorting preserves its focused item")
	game._input(key_event(KEY_TAB,KEY_TAB,true)); game._input(joypad_button_event(JOY_BUTTON_LEFT_STICK,true))
	expect(Grid.selected(game,true)==kind and Grid.state(game,true).side==0,"Tab and L3 restore the remembered hero selection")
	Cabinet.close(game); game.home_chest_owned=true; game.StorageSystem.open(game); game.storage_selected=game.StorageSystem.inventory_items(game).find("plank")
	expect(Grid.transfer(game,false,10) and game.state.storage.count("plank")==10,"same grid transfers ten to ordinary chest")
	Grid.switch_side(game,false); expect(Grid.transfer(game,false,-1) and game.state.storage.count("plank")==0,"ordinary chest whole-stack action returns its actual stock")
	game.free()

## Сценарий: бегунок и свайп прокручивают строки, пока настоящие игровые часы заморожены.
## Исходное состояние: шкаф с длинным каталогом, удержание полосы и касание правой сетки.
## Ожидаемый результат: крайние строки достижимы, свайп не листает страницу и не запускает мир.
func test_drag_swipe_and_pause() -> void:
	var game:=make_game(); prepare(game); var minutes:float=game.game_minutes; var hp:int=game.player_hp
	Controls.pointer(game,Layout.track(1).position+Vector2(5,10),true)
	var motion:=InputEventMouseMotion.new(); motion.position=Layout.track(1).end-Vector2(5,1); game._input(motion)
	expect(Grid.state(game,true).rows[1]==Grid.maximum_row(game,true,1),"scroll thumb reaches the final row")
	var release:=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; game._input(release)
	Grid.state(game,true).rows[1]=0
	var touch:=InputEventScreenTouch.new(); touch.position=Layout.slot(1,7).get_center(); touch.pressed=true; game._input(touch)
	var drag:=InputEventScreenDrag.new(); drag.position=touch.position-Vector2(0,64); game._input(drag)
	expect(Grid.start(game,true,1)==7,"a 64px upward swipe advances one cabinet row")
	game._physics_process(3); expect(game.game_minutes==minutes and game.player_hp==hp and not game.action_held and not game.attack_held,"scroll interactions keep world, health and combat paused")
	game.free()

## Сценарий: сетка и карточка используют разные заранее собранные размеры без обрезанных краёв.
## Исходное состояние: полный реестр и очищенный ограниченный кеш превью.
## Ожидаемый результат: все миниатюры 64px, превью 160px, рисунки непустые и кеш не растёт с каждым предметом.
func test_two_texture_sizes_and_bounded_cache() -> void:
	var game:=make_game(); Prepared.clear()
	for kind in game.InventorySystem.ITEM_DATA:
		var small:Dictionary=game.VisualAssetSystem.item_draw_visual(kind,40); var big:Dictionary=game.VisualAssetSystem.item_draw_visual(kind,120)
		expect(small.texture.get_size()==Vector2(64,64) and big.texture.get_size()==Vector2(160,160) and small.tint==big.tint,"both prepared sizes and material tint exist: "+kind)
		var original:Image=game.VisualAssetSystem.item_visual(kind).texture.get_image()
		if original.is_compressed(): original.decompress()
		var digest:=HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(original.save_png_to_buffer())
		expect(digest.finish().hex_encode()==preload("res://assets/game/items/ui/catalog.gd").DATA.entries[kind].sourceHash,"prepared source fingerprint stays current: "+kind)
		var image:Image=small.texture.get_image(); var used:=image.get_used_rect()
		expect(used.has_area() and used.position.x>=1 and used.position.y>=1 and used.end.x<=63 and used.end.y<=63,"small silhouette keeps safe transparent edges: "+kind)
	expect(Prepared.cache_info().large<=Prepared.PREVIEW_LIMIT,"visiting all items cannot retain every large preview")
	var source:Dictionary=game.VisualAssetSystem.item_visual("plank")
	expect(source.texture!=game.VisualAssetSystem.item_draw_visual("plank",40).texture,"canonical source remains separate from drawing thumbnails")
	game.free()

## Сценарий: локализованная сортировка большого списка не вызывает имя заново на каждом сравнении.
## Исходное состояние: 385 уникальных видов в обратном порядке и счётчик имён.
## Ожидаемый результат: ровно одно имя на вид, прежний алфавитный порядок и устойчивое количество.
func test_sort_names_are_computed_once() -> void:
	var probe:=NameProbe.new(); var items:Array=[]
	for index in range(384,-1,-1): items.append("item_%03d"%index)
	preload("res://scripts/systems/storage_sort_system.gd").arrange(probe,items,"name",func(_kind):return "resource",func(_kind):return 1)
	expect(probe.calls==385 and items[0]=="item_000" and items.back()=="item_384","sorting performs one name lookup per item and preserves lexical ordering")
	probe.free()
