extends RefCounted

const META := "storage_sort_modes"
const MODES := ["name","category","count"]
const RANK := {"tool":0,"tools":0,"seeds":1,"food":2,"alchemy":3,"equipment":4,"resource":5,"craft":5,"quest":6,"other":6}

## Возвращает выбранный порядок только для текущего окна, не изменяя игровые количества.
static func mode(game: Node, side: String) -> String:
	return String(game.get_meta(META,{}).get(side,""))

## Последовательно выбирает имя, тип и убывающее количество для указанной стороны.
static func cycle(game: Node, side: String) -> String:
	var value:Dictionary=game.get_meta(META,{})
	value[side]=MODES[posmod(MODES.find(mode(game,side))+1,MODES.size())]
	game.set_meta(META,value); return value[side]

## Сравнивает типы или количества с устойчивым локализованным именем и идентификатором при равенстве.
static func before(game: Node, left: String, right: String, order: String, category: Callable, quantity: Callable) -> bool:
	if order=="category":
		var left_rank:int=RANK.get(category.call(left),7); var right_rank:int=RANK.get(category.call(right),7)
		if left_rank!=right_rank: return left_rank<right_rank
	elif order=="count":
		var left_count:int=int(quantity.call(left)); var right_count:int=int(quantity.call(right))
		if left_count!=right_count: return left_count>right_count
	var comparison:int=game.inventory_item_name(left).nocasecmp_to(game.inventory_item_name(right))
	return left<right if comparison==0 else comparison<0

## Сортирует переданный список без перестановки быстрых слотов, снаряжения или содержимого хранилища.
static func arrange(game: Node, items: Array, order: String, category: Callable, quantity: Callable) -> void:
	var keys:={}
	for kind in items: keys[kind]={"name":game.inventory_item_name(kind),"rank":RANK.get(category.call(kind),7) if order=="category" else 0,"count":int(quantity.call(kind)) if order=="count" else 0}
	items.sort_custom(func(left,right):
		var a:Dictionary=keys[left]; var b:Dictionary=keys[right]
		if order=="category" and a.rank!=b.rank: return a.rank<b.rank
		if order=="count" and a.count!=b.count: return a.count>b.count
		var comparison:int=String(a.name).nocasecmp_to(String(b.name))
		return left<right if comparison==0 else comparison<0)

## Сбрасывает временные настройки сортировки при успешной загрузке другой игры.
static func reset(game: Node) -> void:
	if game.has_meta(META): game.remove_meta(META)
