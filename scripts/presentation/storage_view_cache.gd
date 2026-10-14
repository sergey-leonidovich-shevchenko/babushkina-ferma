extends RefCounted

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Sorting := preload("res://scripts/systems/storage_sort_system.gd")
const Grid := preload("res://scripts/systems/storage_grid_system.gd")
const META := "storage_view_cache"

## Сохраняет только последний снимок каждого окна; точное сравнение обнаруживает также прямые изменения старого состояния и загрузку.
static func snapshot(game: Node, cabinet: bool) -> Dictionary:
	var cache:Dictionary=game.get_meta(META,{})
	var cabinet_state:Dictionary=Cabinet.state(game) if cabinet else {}
	var stock:Dictionary=cabinet_state.stock if cabinet else game.home_chest_counts
	var key:Array=[game.state.inventory.counts.duplicate(),game.inventory_slots.duplicate(),stock.duplicate(),game.sword_crafted,game.has_pickaxe,game.has_fishing_rod,game.has_bow,game.has_crystal_sword,game.LocaleSystem.current,Sorting.mode(game,"container"),game.InventorySystem.ITEM_DATA.size()]
	if cabinet: key.append_array([cabinet_state.tab,cabinet_state.query])
	var slot:="cabinet" if cabinet else "chest"
	var entry:Dictionary=cache.get(slot,{})
	if entry.get("key",[])==key:
		entry.hits+=1
		return entry.data
	if cabinet and not entry.is_empty() and entry.key[2]!=stock: cabinet_state.cache.clear()
	var counts:Dictionary={}
	for kind in game.InventorySystem.ITEM_DATA: counts[kind]=game.inventory_item_count(kind)
	var all:=false; var matching:=false
	for kind in counts:
		if counts[kind]<=0 or (not cabinet and kind=="home_chest"): continue
		all=true
		if int(stock.get(kind,0))>0: matching=true
	var data:Dictionary={"items":[Grid.items(game,cabinet,0),Grid.items(game,cabinet,1)],"counts":[counts,stock.duplicate()],"all":all,"matching":matching}
	cache[slot]={"key":key,"data":data,"builds":int(entry.get("builds",0))+1,"hits":int(entry.get("hits",0))}
	game.set_meta(META,cache)
	return data

## Выбирает центральный предмет из того же снимка, который рисуют обе колонки, без дополнительных обходов рюкзака.
static func selected(game: Node, cabinet: bool, data: Dictionary) -> String:
	var state:=Grid.state(game,cabinet); var choices:Array=data.items[int(state.side)]
	return "" if choices.is_empty() else String(choices[clampi(state.selected[state.side],0,choices.size()-1)])

## Даёт счётчики перестроений без доступа к изменяемым спискам и количествам.
static func statistics(game: Node, cabinet: bool) -> Dictionary:
	var entry:Dictionary=game.get_meta(META,{}).get("cabinet" if cabinet else "chest",{})
	return {"builds":int(entry.get("builds",0)),"hits":int(entry.get("hits",0))}
