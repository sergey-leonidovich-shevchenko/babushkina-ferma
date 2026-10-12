extends RefCounted

const Data := preload("res://scripts/systems/basement_data.gd")
const Layout := preload("res://scripts/systems/basement_layout_system.gd")

## Возвращает личную мастерскую с независимыми экземплярами станков и без заранее построенных машин.
static func state(game: Node) -> Dictionary:
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("basement"): expansion.basement={"version":1,"next_id":1,"revision":0,"objects":[]}
	return expansion.basement

## Ищет конкретный экземпляр по устойчивому идентификатору, а не месту в массиве.
static func object(game: Node, id: int) -> Dictionary:
	for value in state(game).objects:
		if int(value.id)==id: return value
	return {}

## Создаёт только временное состояние чертежа, размещения и удерживаемого строительства.
static func ui(game: Node) -> Dictionary:
	if not game.has_meta("basement_ui"): game.set_meta("basement_ui",{"open":false,"placing":false,"tab":0,"selected":0,"kind":"workbench","x":12,"y":12,"direction":0,"holding":0,"hold_time":0.0,"cache_key":"","preview":{},"touch_id":-1})
	return game.get_meta("basement_ui")

## Проверяет модальный строительный интерфейс отдельно от активной работы молотком.
static func modal(game: Node) -> bool:
	var value:Dictionary=game.get_meta("basement_ui",{})
	return bool(value.get("open",false)) or bool(value.get("placing",false))

## Открывает настенный чертёж только у его настоящей точки и приостанавливает другие окна.
static func open(game: Node) -> bool:
	if game.current_location!=Data.LOCATION or game.player.distance_to(Data.BOARD)>60: return false
	var value:=ui(game); value.open=true; value.placing=false; value.holding=0; value.selected=0
	game.action_held=false
	game.clear_movement_keys(); game.notify_tutorial("basement_blueprint"); return true

## Закрывает строительные режимы без отмены оплаченных работ и возвращает камеру к герою.
static func close(game: Node) -> void:
	var value:=ui(game); value.open=false; value.placing=false; value.holding=0; value.touch_id=-1
	game.action_held=false
	game.clear_movement_keys(); game.update_camera(); game.queue_redraw()

## Возвращает новую производственную память без копирования уровня другого экземпляра того же вида.
static func production() -> Dictionary:
	return {"level":1,"queue":[],"heat":0.0,"fuel":"wood","completed":0}

## Проверяет сохранённые основания, уникальность идентификаторов и рабочие подходы до применения слота.
static func valid(value: Dictionary) -> bool:
	if float(value.version)!=1 or float(value.next_id)!=int(value.next_id) or int(value.next_id)<1: return false
	var objects:Array=value.get("objects",[])
	if objects.size()>256: return false
	var ids:={}
	for item in objects:
		if float(item.id)!=int(item.id) or int(item.id)<1 or ids.has(int(item.id)) or not Data.STATIONS.has(item.kind): return false
		if float(item.x)!=int(item.x) or float(item.y)!=int(item.y) or float(item.direction)!=int(item.direction) or int(item.direction) not in range(4): return false
		if int(item.level) not in range(1,4) or item.phase not in ["building","upgrading","ready"]: return false
		if float(item.level)!=int(item.level) or float(item.target)!=int(item.target) or float(item.energy)!=int(item.energy) or int(item.energy) not in range(1,4): return false
		if item.phase=="building" and (int(item.level)!=1 or int(item.target)!=1): return false
		if item.phase=="upgrading" and (int(item.level)>=3 or int(item.target)!=int(item.level)+1): return false
		if int(item.target) not in range(1,4) or (item.phase=="ready" and int(item.target)!=int(item.level)): return false
		if float(item.work)<0 or float(item.work)>float(item.duration) or not is_equal_approx(float(item.duration),Data.WORK_SECONDS[int(item.target)-1]): return false
		if int(item.energy)!=mini(3,int(Data.STATIONS[item.kind].energy)+int(item.target)-1): return false
		var expected:Dictionary=Data.STATIONS[item.kind].inputs.duplicate()
		for tier in range(1,int(item.target)):
			for kind in Data.upgrade_cost(item.kind,tier).inputs: expected[kind]=int(expected.get(kind,0))+int(Data.upgrade_cost(item.kind,tier).inputs[kind])
		if item.paid.size()!=expected.size(): return false
		for kind in expected:
			if not item.paid.has(kind) or float(item.paid[kind])!=int(expected[kind]): return false
		if not preload("res://scripts/systems/furnace_data.gd").FUELS.has(item.production.fuel): return false
		if item.kind=="cauldron" and not preload("res://scripts/systems/kitchen_data.gd").FUELS.has(item.production.fuel): return false
		if int(item.production.level)!=int(item.level) or item.production.queue.size()>int(item.level) or float(item.production.heat)<0: return false
		if item.kind=="cauldron" and float(item.production.heat)>120*int(item.level): return false
		for kind in item.paid:
			if not preload("res://scripts/systems/inventory_system.gd").ITEM_DATA.has(kind) or float(item.paid[kind])!=int(item.paid[kind]) or int(item.paid[kind])<0: return false
		for job in item.production.queue:
			var recipe:Dictionary=preload("res://scripts/systems/furnace_data.gd").recipe(job.id) if item.kind=="furnace" else (preload("res://scripts/systems/kitchen_data.gd").recipe(job.id) if item.kind=="cauldron" else preload("res://scripts/systems/workshop_recipe_data.gd").recipe(job.id))
			if recipe.get("station","")!=item.kind or float(job.duration)<=0 or float(job.remaining)<0 or float(job.remaining)>float(job.duration): return false
			if Data.recipe_level(recipe)>int(item.level): return false
			if item.kind=="cauldron":
				if job.get("paid",{}).size()!=recipe.inputs.size(): return false
				var expected_seconds:float=preload("res://scripts/systems/kitchen_data.gd").seconds(recipe)/preload("res://scripts/systems/kitchen_data.gd").SPEED[int(item.level)-1]
				if not is_equal_approx(float(job.duration),expected_seconds): return false
			for kind in job.get("paid",{}):
				if not recipe.inputs.has(kind) or float(job.paid[kind])!=int(recipe.inputs[kind]): return false
		if item.phase!="ready" and (float(item.work)<0 or float(item.work)>float(item.duration) or int(item.target) not in range(1,4) or float(item.duration)<=0): return false
		ids[int(item.id)]=true
	return Layout.valid_set(objects)

## Восстанавливает прогресс без выдачи материалов и сбрасывает только неподдерживаемые временные жесты.
static func restore(game: Node) -> void:
	var value:=state(game); var largest:=0
	for item in value.objects:
		largest=maxi(largest,int(item.id)); item.production.level=int(item.level)
		for kind in item.paid: item.paid[kind]=int(item.paid[kind])
		for job in item.production.queue:
			for kind in job.get("paid",{}): job.paid[kind]=int(job.paid[kind])
		item.production.heat=clampf(float(item.production.heat),0,120.0*int(item.level))
	value.next_id=maxi(int(value.get("next_id",1)),largest+1); value.revision=maxi(0,int(value.get("revision",0)))
	if game.has_meta("basement_ui"): game.remove_meta("basement_ui")
	if game.has_meta("basement_active_station"): game.remove_meta("basement_active_station")
	if game.has_meta("kitchen_filter"): game.remove_meta("kitchen_filter")

## Находит единственный доступный рабочий подход, строительную кучу или настенный чертёж.
static func nearest(game: Node, radius: float=60) -> String:
	if game.current_location!=Data.LOCATION: return ""
	var result:=""; var best:=radius
	if game.player.distance_to(Data.BOARD)<best: result="basement_board"; best=game.player.distance_to(Data.BOARD)
	for item in state(game).objects:
		var distance:float=game.player.distance_to(Layout.center(Layout.approach_cell(item)))
		if distance<minf(best,22): result="basement_station:%d"%item.id; best=distance
	return result

## Возвращает настоящую позицию подхода для общей подсветки и интерфейса взаимодействий.
static func interaction_position(game: Node, interaction: String) -> Vector2:
	if interaction=="basement_board": return Data.BOARD
	var item:=object(game,int(interaction.get_slice(":",1)))
	return Layout.center(Layout.approach_cell(item)) if not item.is_empty() else Vector2.ZERO

## Объясняет личную геометрию подвала общей навигации и учитывает все оплаченные строительные кучи.
static func walkable(game: Node, position: Vector2, radius: float) -> bool:
	return Layout.walkable(position,Layout.rectangles(state(game).objects),radius)
