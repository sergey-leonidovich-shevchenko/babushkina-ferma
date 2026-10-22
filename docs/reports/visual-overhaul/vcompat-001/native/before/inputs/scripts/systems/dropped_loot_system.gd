extends RefCounted

const ATTRACTION_RADIUS := 96.0
const PICKUP_RADIUS := 26.0
const SPEED := 360.0
const STEP := 8.0
const SLIME_POSITION := "slime_loot_position"

## Притягивает только свободную добычу текущей локации, оставляя симуляцию неподвижной во всех модальных окнах.
static func update(game:Node,delta:float) -> void:
	if delta<=0.0 or game.language_screen or game.player_hp<=0 or game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game) or game.LevelEditorSystem.active(game): return
	for index in range(game.dropped_items.size()-1,-1,-1):
		var item:Dictionary=game.dropped_items[index]
		if item.get("location",game.current_location)!=game.current_location: continue
		var distance:float=game.player.distance_to(item.position)
		if bool(item.get("pickup_blocked",false)):
			if distance>ATTRACTION_RADIUS: item.pickup_blocked=false
			continue
		if distance>ATTRACTION_RADIUS: continue
		item.position=attract(game,item.position,delta)
		if game.player.distance_to(item.position)<=PICKUP_RADIUS: collect(game,index,PICKUP_RADIUS)
	if game.loot_available and game.current_location=="overworld":
		var position:=slime_position(game)
		if game.player.distance_to(position)<=ATTRACTION_RADIUS:
			position=attract(game,position,delta); game.set_meta(SLIME_POSITION,position)
			if game.player.distance_to(position)<=PICKUP_RADIUS: collect_slime(game,PICKUP_RADIUS)

## Двигает предмет плавно с одинаковой скоростью при разной частоте кадров и не пропускает твёрдые препятствия.
static func attract(game:Node,position:Vector2,delta:float) -> Vector2:
	var travel:=minf(position.distance_to(game.player),SPEED*delta)
	var steps:=maxi(1,ceili(travel/STEP))
	for _step in steps:
		if position.distance_to(game.player)<=PICKUP_RADIUS: break
		var next:=position.move_toward(game.player,travel/steps)
		if game.NavigationSystem.walkability_reason(game,next,-1,false)!="walkable": break
		position=next
	return position

## Переносит только реально принятый остаток; неизвестный предмет и повторный уникальный инструмент остаются на земле.
static func collect(game:Node,index:int,radius:float=92.0) -> bool:
	if index<0 or index>=game.dropped_items.size(): return false
	var item:Dictionary=game.dropped_items[index]
	if item.get("location",game.current_location)!=game.current_location or game.player.distance_to(item.position)>radius: return false
	var amount:=int(item.count)
	if amount<=0 or not game.InventorySystem.ITEM_DATA.has(item.kind): return false
	if item.kind in game.InventorySystem.UNIQUE_ITEMS:
		if game.inventory_item_count(item.kind)>0: return false
		amount=1
	if not game.change_inventory_count(item.kind,amount): return false
	item.count-=amount
	if int(item.count)<=0: game.dropped_items.remove_at(index)
	game.message=game.LocaleSystem.text("picked",[game.inventory_item_name(item.kind)])
	game.play_sfx("pickup"); game.notify_tutorial("loot")
	return true

## Возвращает отдельную позицию добычи сюжетного слизня, не перемещая тело побеждённого противника.
static func slime_position(game:Node) -> Vector2:
	return game.get_meta(SLIME_POSITION,game.slime_position)

## Выдаёт прежнюю сюжетную слизь через тот же автоматический контакт либо ручное взаимодействие.
static func collect_slime(game:Node,radius:float=92.0) -> bool:
	if not game.loot_available or game.current_location!="overworld" or game.player.distance_to(slime_position(game))>radius: return false
	if not game.change_inventory_count("slime",3): return false
	game.loot_available=false
	if game.has_meta(SLIME_POSITION): game.remove_meta(SLIME_POSITION)
	game.message=game.LocaleSystem.text("picked",[game.inventory_item_name("slime")])
	game.play_sfx("pickup"); game.notify_tutorial("loot")
	return true
