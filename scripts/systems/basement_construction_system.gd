extends RefCounted

const Basement := preload("res://scripts/systems/basement_system.gd")
const Stations := preload("res://scripts/systems/basement_station_system.gd")

## Объясняет нехватку денег или полного состава до любых списаний.
static func cost_reason(game: Node, cost: Dictionary) -> String:
	if game.coins<int(cost.get("coins",0)): return "basement_money"
	for kind in cost.inputs:
		if game.inventory_item_count(kind)<int(cost.inputs[kind]): return "basement_materials"
	return ""

## Списывает точную согласованную стоимость без ремесленных скидок и обновляет журнал реально потраченных компонентов.
static func pay(game: Node, cost: Dictionary, ledger: Dictionary) -> void:
	game.coins-=int(cost.get("coins",0))
	for kind in cost.inputs:
		game.change_inventory_count(kind,-int(cost.inputs[kind])); ledger[kind]=int(ledger.get(kind,0))+int(cost.inputs[kind])

## Подтверждает свободное размещение и резервирует материалы новой стройки всегда первого уровня.
static func build(game: Node, candidate: Dictionary) -> bool:
	if game.current_location!=Basement.Data.LOCATION or not Basement.ui(game).placing or not Basement.Data.STATIONS.has(candidate.get("kind","")): return false
	var value:=Basement.state(game); var why:=Basement.Layout.reason(value.objects,candidate,game.player)
	var cost:={"inputs":Basement.Data.STATIONS[candidate.kind].inputs}
	if why.is_empty(): why=cost_reason(game,cost)
	if value.objects.size()>=256: why="basement_limit"
	if not why.is_empty(): game.message=game.LocaleSystem.ui(why); return false
	var ledger:={}; pay(game,cost,ledger)
	var item:={"id":int(value.next_id),"kind":candidate.kind,"x":int(candidate.x),"y":int(candidate.y),"direction":int(candidate.direction),"level":1,"phase":"building","target":1,"work":0.0,"duration":5.0,"energy":int(Basement.Data.STATIONS[candidate.kind].energy),"paid":ledger,"production":Basement.production()}
	value.next_id+=1; value.objects.append(item); value.revision+=1; Basement.close(game)
	game.notify_tutorial("basement_build"); game.queue_redraw(); return true

## Начинает отдельное улучшение выбранного экземпляра у чертежа с сохранением оплаченной производственной очереди.
static func upgrade(game: Node, id: int) -> bool:
	var item:=Basement.object(game,id)
	if not Basement.ui(game).open or game.current_location!=Basement.Data.LOCATION or game.player.distance_to(Basement.Data.BOARD)>60 or item.is_empty() or item.phase!="ready" or int(item.level)>=3: return false
	var cost:=Basement.Data.upgrade_cost(item.kind,item.level); var why:=cost_reason(game,cost)
	if not why.is_empty(): game.message=game.LocaleSystem.ui(why); return false
	pay(game,cost,item.paid); item.phase="upgrading"; item.target=int(item.level)+1; item.work=0.0
	item.duration=Basement.Data.WORK_SECONDS[int(item.target)-1]; item.energy=mini(3,int(Basement.Data.STATIONS[item.kind].energy)+int(item.target)-1)
	Basement.state(game).revision+=1; Basement.close(game); game.notify_tutorial("basement_upgrade"); return true

## Вычисляет весь возврат до демонтажа, округляя половину каждого компонента вниз и превращая остаток в соответствующий лом.
static func salvage(item: Dictionary) -> Dictionary:
	var result:={}
	for kind in item.paid:
		var amount:int=item.paid[kind]; var returned:=amount/2; var waste:=amount-returned
		if returned>0: result[kind]=int(result.get(kind,0))+returned
		var debris:=Basement.Data.debris(kind)
		if waste>0: result[debris]=int(result.get(debris,0))+waste
	for job in item.production.queue:
		var recipe:Dictionary=preload("res://scripts/systems/furnace_data.gd").recipe(job.id) if item.kind=="furnace" else preload("res://scripts/systems/workshop_recipe_data.gd").recipe(job.id)
		var inputs:Dictionary=job.get("paid",recipe.get("inputs",{}))
		for kind in inputs: result[kind]=int(result.get(kind,0))+int(inputs[kind])
	return result

## Демонтирует любой личный экземпляр или недострой, сохраняя оплаченные заготовки очереди и необратимо убирая его опору.
static func dismantle(game: Node, id: int) -> bool:
	var item:=Basement.object(game,id)
	if not Basement.ui(game).open or game.current_location!=Basement.Data.LOCATION or game.player.distance_to(Basement.Data.BOARD)>60 or item.is_empty(): return false
	var output:=salvage(item)
	for kind in output: game.change_inventory_count(kind,int(output[kind]))
	var value:=Basement.state(game); value.objects.erase(item); value.revision+=1; Basement.ui(game).selected=0
	if int(game.get_meta("basement_active_station",0))==id: game.remove_meta("basement_active_station")
	game.notify_tutorial("basement_dismantle"); game.queue_redraw(); return true

## Продвигает стройку только во время настоящего удержания у рабочей стороны и оплачивает каждый законченный рабочий интервал.
static func update_hold(game: Node, delta: float) -> bool:
	if game.current_location!=Basement.Data.LOCATION: return false
	var value:=Basement.ui(game); var item:=Basement.object(game,int(value.holding))
	if item.is_empty() or item.phase=="ready" or game.current_location!=Basement.Data.LOCATION or game.player.distance_to(Basement.Layout.center(Basement.Layout.approach_cell(item)))>22 or game.get_movement_direction()!=Vector2.ZERO:
		value.holding=0; return false
	var elapsed:=maxf(delta,0.0)
	while elapsed>0.00001 and float(item.work)<float(item.duration):
		if game.energy<float(item.energy): game.message=game.LocaleSystem.ui("basement_energy"); return true
		var boundary:=minf(floorf(float(item.work))+1,float(item.duration)); var step:=minf(elapsed,boundary-float(item.work))
		item.work=float(item.work)+step; elapsed-=step; value.hold_time=float(value.hold_time)+step
		if is_equal_approx(float(item.work),boundary): item.work=boundary; game.energy-=float(item.energy)
	game.facing=-Vector2(Basement.Data.DIRECTIONS[int(item.direction)])
	game.HeroActionSystem.begin(game,"build",Basement.Layout.rect(item).get_center())
	if float(item.work)>=float(item.duration)-0.00001: finish(game,item); value.holding=0
	return true

## Завершает сборку единожды и ускоряет прежнюю очередь пропорционально новому уровню без повторной оплаты сырья.
static func finish(game: Node, item: Dictionary) -> void:
	var previous:=int(item.level); item.level=int(item.target); item.phase="ready"; item.production.level=item.level
	if item.kind in ["sawmill","pottery","glassblowing","furnace"]:
		var speed:=[1.0,1.35,1.7]; var factor:float=speed[previous-1]/speed[int(item.level)-1]
		for job in item.production.queue: job.duration*=factor; job.remaining*=factor
	Basement.state(game).revision+=1; game.notify_tutorial("basement_finish"); game.play_sfx("craft"); game.queue_redraw()
