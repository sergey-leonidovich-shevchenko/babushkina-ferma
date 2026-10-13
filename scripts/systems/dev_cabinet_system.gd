extends RefCounted

const META := "dev_supply_cabinet"
const SETTING := "development/supply_cabinet_enabled"
const POSITION := Vector2(190,398)
const TABS := ["all","craft","food","alchemy","equipment","tools","seeds","other"]
const STOCK := 999
const UNIQUE := ["sword","bow","crystal_sword","pickaxe","fishing_rod"]
const DECOR := ["home_chest","backpack_upgrade","rustic_table","wooden_chair","wooden_wardrobe","woven_rug","potted_fern","museum_token","fence_kit","gate_kit","bandage"]
const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Locale := preload("res://scripts/systems/dev_cabinet_locale.gd")

## Отделяет временное снабжение разработки от окончательного режима игры одной настройкой проекта.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING,false))

## Проверяет открытое окно без создания склада или бесплатных предметов при обычной игре.
static func active(game: Node) -> bool:
	return enabled() and bool(game.get_meta(META,{}).get("open",false)) and game.current_location=="cottage_interior" and not game.title_screen and not game.language_screen

## Требует доступ к шкафу слева в доме и исключает титульные и паузные экраны.
static func at_cabinet(game: Node) -> bool:
	return enabled() and game.current_location=="cottage_interior" and game.player.distance_to(POSITION)<=52 and not game.language_screen and not game.title_screen and not game.menu_state.pause_open

## Создаёт запас из полного реестра и автоматически добавляет будущие зарегистрированные предметы.
static func state(game: Node) -> Dictionary:
	if not game.has_meta(META): game.set_meta(META,{"open":false,"tab":0,"selected":0,"query":"","searching":false,"stock":{},"cache":{},"axes":{},"notice":""})
	var value:Dictionary=game.get_meta(META)
	if value.stock.size()!=game.InventorySystem.ITEM_DATA.size():
		for kind in game.InventorySystem.ITEM_DATA:
			if not value.stock.has(kind): value.stock[kind]=STOCK
		for kind in value.stock.keys():
			if not game.InventorySystem.ITEM_DATA.has(kind): value.stock.erase(kind)
		value.cache.clear()
	return value

## Разделяет категории без потерь: семена и алхимия определяются прежде общих инструментов и расходников.
static func category(game: Node, kind: String) -> String:
	if kind=="seeds" or kind.ends_with("_seeds") or kind=="fruit_sapling": return "seeds"
	if Products.handles(kind) or game.PotionSystem.is_potion(kind): return "alchemy"
	var data:Dictionary=game.InventorySystem.ITEM_DATA[kind]
	if data.has("tool"): return "tools"
	if data.has("equip"): return "equipment"
	if kind in DECOR or game.InventorySystem.category(kind)=="quest": return "other"
	if data.has("edible"): return "food"
	return "craft"

## Кэширует локализованный поиск и категории, чтобы отрисовка не пересобирала сотни имён каждый кадр.
static func items(game: Node) -> Array:
	var value:=state(game); var tab:String=TABS[int(value.tab)]; var query:String=String(value.query).strip_edges().to_lower()
	var key:String=game.LocaleSystem.current+":"+tab+":"+query
	if not value.cache.has(key):
		var result:=[]
		for kind in value.stock:
			if tab!="all" and category(game,kind)!=tab: continue
			if not query.is_empty() and not String(kind).contains(query) and not game.inventory_item_name(kind).to_lower().contains(query): continue
			result.append(kind)
		result.sort_custom(func(left,right): return game.inventory_item_name(left).nocasecmp_to(game.inventory_item_name(right))<0)
		value.cache[key]=result
	return value.cache[key]

## Открывает шкаф только обычным подходом, очищая удержанные действия до остановки мира.
static func open(game: Node) -> bool:
	if not at_cabinet(game) or game.inventory_open or game.crafting_open or game.storage_open or game.shop_open: return false
	state(game).open=true; game.clear_movement_keys(); game.action_held=false; game.attack_held=false; game.state.player.blocking=false
	game.notify_tutorial("dev_cabinet"); game.queue_redraw(); return true

## Закрывает временную панель, оставляя её запас в текущем сеансе и не сохраняя его в игровом слоте.
static func close(game: Node) -> void:
	if game.has_meta(META): game.get_meta(META).open=false; game.get_meta(META).searching=false
	game.clear_movement_keys(); game.action_held=false; game.attack_held=false; game.queue_redraw()

## Сбрасывает временный склад при загрузке, не затрагивая уже полученные предметы рюкзака.
static func reset(game: Node) -> void:
	if game.has_meta(META): game.remove_meta(META)

## Выбирает вкладку с первой строки и сохраняет введённый поиск между категориями.
static func select_tab(game: Node, index: int) -> void:
	var value:=state(game); value.tab=posmod(index,TABS.size()); value.selected=0; value.notice=""; game.queue_redraw()

## Ограничивает выбор доступным результатом поиска и возвращает его постоянный идентификатор.
static func selected(game: Node) -> String:
	var choices:=items(game); var value:=state(game)
	value.selected=clampi(int(value.selected),0,maxi(0,choices.size()-1))
	return String(choices[int(value.selected)]) if not choices.is_empty() else ""

## Передаёт единичное старое оружие честно, а обычные предметы выдаёт запрошенным стеком.
static func amount(game: Node, kind: String, requested: int) -> int:
	if not active(game) or not at_cabinet(game) or not state(game).stock.has(kind) or requested<=0: return 0
	if kind in UNIQUE: return 1 if game.inventory_item_count(kind)==0 and int(state(game).stock[kind])>0 else 0
	return mini(requested,int(state(game).stock[kind]))

## Списывает только успешно выданное количество, не расходуя энергию, деньги или запас домашнего сундука.
static func take(game: Node, kind: String, requested: int) -> bool:
	var count:=amount(game,kind,requested)
	if count<=0: return false
	if not game.change_inventory_count(kind,count): return false
	var value:=state(game); value.stock[kind]-=count
	value.notice=Locale.text(game,"taken",[game.inventory_item_name(kind),count]); game.queue_redraw(); return true

## Пополняет весь каталог до установленного запаса только через явно открытую панель разработки.
static func refill(game: Node) -> void:
	if not active(game) or not at_cabinet(game): return
	var value:=state(game)
	for kind in value.stock: value.stock[kind]=STOCK
	value.notice=Locale.text(game,"refilled"); game.queue_redraw()
