extends RefCounted

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Sorting := preload("res://scripts/systems/storage_sort_system.gd")
const Locale := preload("res://scripts/systems/storage_actions_locale.gd")

## Разрешает массовые действия только в действительно открытом доступном хранилище.
static func available(game: Node, cabinet: bool) -> bool:
	if game.title_screen or game.language_screen or game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open: return false
	return Cabinet.active(game) and Cabinet.at_cabinet(game) if cabinet else game.storage_open and game.home_chest_owned and game.current_location=="cottage_interior"

## Получает текущие остатки выбранного хранилища, включая нулевые записи каталога шкафа.
static func contents(game: Node, cabinet: bool) -> Dictionary:
	return Cabinet.state(game).stock if cabinet else game.home_chest_counts

## Снимком выбирает все положительные зарегистрированные виды независимо от вкладки, поиска и страницы.
static func candidates(game: Node, cabinet: bool, matching: bool) -> Dictionary:
	var result:={}
	if not available(game,cabinet): return result
	var target:=contents(game,cabinet).duplicate()
	for kind in game.InventorySystem.ITEM_DATA:
		var amount:int=game.inventory_item_count(kind)
		if amount>0 and (cabinet or kind!="home_chest") and (not matching or int(target.get(kind,0))>0): result[kind]=amount
	return result

## Сохраняет уведомление в видимом окне и обновляет обучение без продвижения игрового времени.
static func notice(game: Node, cabinet: bool, label: String) -> void:
	game.message=label
	if cabinet: Cabinet.state(game).notice=label
	game.notify_tutorial("storage_quick"); game.queue_redraw()

## Возвращает весь положительный стек в шкаф с обычным снятием последней экипированной копии.
static func deposit_cabinet(game: Node, kind: String, amount: int) -> bool:
	if not available(game,true) or not Cabinet.state(game).stock.has(kind) or amount<=0 or amount>game.inventory_item_count(kind): return false
	if not game.change_inventory_count(kind,-amount): return false
	Cabinet.state(game).stock[kind]+=amount
	game.StorageSystem.refresh_equipment(game,kind); return true

## Переносит снимок рюкзака, чтобы новый вид не расширял набор совпадений во время одной операции.
static func deposit_all(game: Node, cabinet: bool, matching: bool=false) -> int:
	var source:=candidates(game,cabinet,matching)
	if not available(game,cabinet): return 0
	var focused:String=Cabinet.selected(game) if cabinet else ""; var total:=0; var types:=0
	for kind in source:
		var amount:int=int(source[kind])
		var transferred:bool=deposit_cabinet(game,kind,amount) if cabinet else game.StorageSystem.deposit(game,kind,amount)
		if transferred: total+=amount; types+=1
	if cabinet: Cabinet.refresh_selection(game,focused)
	else: game.StorageSystem.clamp_selection(game)
	notice(game,cabinet,Locale.text(game,"summary",[types,total]) if total>0 else Locale.text(game,"none"))
	return total

## Переставляет только слоты рюкзака, сохраняя выделенный предмет, быстрые привязки и количества.
static func sort_bag(game: Node, cabinet: bool) -> void:
	if not available(game,cabinet): return
	var selected:String=String(game.inventory_slots[game.inventory_selected]) if game.inventory_selected>=0 and game.inventory_selected<game.inventory_slots.size() else ""
	var focused:String=""
	var view:Dictionary=game.get_meta("storage_grid_cabinet",{}) if cabinet else {}
	if cabinet and int(view.get("side",1))==0:
		var choices:Array[String]=game.StorageSystem.inventory_items(game)
		if int(view.selected[0])<choices.size(): focused=choices[int(view.selected[0])]
	if not cabinet and game.storage_side==0:
		var choices:Array[String]=game.StorageSystem.inventory_items(game)
		if game.storage_selected>=0 and game.storage_selected<choices.size(): focused=choices[game.storage_selected]
	var items:Array[String]=[]
	for value in game.inventory_slots:
		var kind:=String(value)
		if not kind.is_empty() and game.inventory_item_count(kind)>0 and kind not in items: items.append(kind)
	for kind in game.InventorySystem.ITEM_DATA:
		if game.inventory_item_count(kind)>0 and kind not in items: items.append(kind)
	Sorting.arrange(game,items,Sorting.cycle(game,"bag"),game.InventorySystem.category,game.inventory_item_count)
	var size:int=maxi(game.inventory_slots.size(),items.size())
	game.inventory_slots.resize(size)
	for index in size: game.inventory_slots[index]=items[index] if index<items.size() else ""
	game.InventorySystem.ensure_capacity(game); game.inventory_selected=maxi(items.find(selected),0); game.inventory_scroll_row=0; game.inventory_move_from=-1
	if not cabinet and game.storage_side==0: game.storage_selected=maxi(items.find(focused),0)
	if cabinet and int(view.get("side",1))==0: view.selected[0]=maxi(items.find(focused),0)
	notice(game,cabinet,Locale.sort_label(game,"bag"))

## Меняет порядок хранилища с сохранением выбранного вида при перестановке строк или каталога.
static func sort_container(game: Node, cabinet: bool) -> void:
	if not available(game,cabinet): return
	var focused:String=Cabinet.selected(game) if cabinet else ""
	if not cabinet and game.storage_side==1:
		var choices:Array[String]=game.StorageSystem.stored_items(game)
		if game.storage_selected>=0 and game.storage_selected<choices.size(): focused=choices[game.storage_selected]
	Sorting.cycle(game,"container")
	if cabinet: Cabinet.refresh_selection(game,focused)
	elif game.storage_side==1: game.storage_selected=maxi(game.StorageSystem.stored_items(game).find(focused),0)
	notice(game,cabinet,Locale.sort_label(game,"container"))

## Перехватывает клавиатуру сундука до обновления движения и удержания игровых действий.
static func handle_window_input(game: Node, event: InputEvent) -> bool:
	if not available(game,false): return false
	game.InputSystem.handle_storage_input(game,event); return true

## Даёт одинаковые клавиши и команды геймпада для всех открытых хранилищ.
static func handle_input(game: Node, event: InputEvent, cabinet: bool) -> bool:
	if not available(game,cabinet): return false
	var command:=-1
	if event is InputEventKey and event.pressed and not event.echo: command=int(event.keycode)
	elif event is InputEventJoypadButton and event.pressed: command={JOY_BUTTON_START:KEY_D,JOY_BUTTON_BACK:KEY_M,JOY_BUTTON_RIGHT_STICK:KEY_S}.get(event.button_index,-1)
	match command:
		KEY_D: deposit_all(game,cabinet)
		KEY_M: deposit_all(game,cabinet,true)
		KEY_S:
			sort_bag(game,cabinet)
			if event is InputEventJoypadButton: sort_container(game,cabinet)
		KEY_T: sort_container(game,cabinet)
		_: return false
	return true
