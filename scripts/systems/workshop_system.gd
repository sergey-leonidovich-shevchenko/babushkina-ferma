extends RefCounted

const Data := preload("res://scripts/systems/workshop_data.gd")
const Fuel := preload("res://scripts/systems/furnace_data.gd")
const BasementStations := preload("res://scripts/systems/basement_station_system.gd")

## Определяет три специализированные производственные станции.
static func handles(station: String) -> bool:
	return Data.STATIONS.has(station)

## Возвращает отдельный сохраняемый уровень, очередь и запас топлива выбранного ремесла.
static func state(game: Node, station: String) -> Dictionary:
	if not handles(station): return {}
	var local:=BasementStations.production(game,station)
	if not local.is_empty(): return local
	if Data.STATIONS[station].get("private",false): return {}
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("workshops"): expansion.workshops={}
	if not expansion.workshops.has(station): expansion.workshops[station]={"level":1,"queue":[],"heat":0.0,"fuel":"wood","completed":0}
	return expansion.workshops[station]

## Нормализует сохранённые работы, не смешивая технологии разных станков и не выдавая их заново.
static func restore(game: Node) -> void:
	for station in Data.STATIONS:
		if Data.STATIONS[station].get("private",false): continue
		var value:=state(game,station); value.level=clampi(int(value.get("level",1)),1,3)
		value.completed=maxi(0,int(value.get("completed",0))); value.heat=clampf(float(value.get("heat",0)),0,120.0*int(value.level))
		value.fuel=String(value.get("fuel","wood")) if Fuel.FUELS.has(value.get("fuel","wood")) else "wood"
		var queue:=[]
		for job in value.get("queue",[]):
			var recipe:Dictionary=Data.Recipes.recipe(String(job.id))
			if recipe.get("station","")!=station or queue.size()>=int(value.level): continue
			var duration:=clampf(float(job.duration),0.01,60)
			queue.append({"id":job.id,"duration":duration,"remaining":clampf(float(job.remaining),0,duration),"paid":job.get("paid",recipe.inputs).duplicate()})
		value.queue=queue

## Требует физическое присутствие у выбранного станка для постановки, загрузки и улучшения.
static func at_station(game: Node, station: String) -> bool:
	if not BasementStations.active(game,station).is_empty(): return true
	return handles(station) and not Data.STATIONS[station].get("private",false) and game.current_location==Data.STATIONS[station].location and game.player.distance_to(Data.STATIONS[station].point)<=80

## Возвращает скорость текущего уровня без изменения выхода или стоимости ресурсов.
static func speed(game: Node, station: String) -> float:
	return float(Data.SPEED[int(state(game,station).get("level",1))-1])

## Объясняет первое ограничение до любых списаний, включая энергию и открытое знание.
static func reason(game: Node, recipe: Dictionary) -> String:
	var station:String=String(recipe.get("station",""))
	if not handles(station) or not at_station(game,station): return game.LocaleSystem.ui("workshop_station_need")
	var value:=state(game,station)
	if int(value.level)<int(recipe.workshop_level): return game.LocaleSystem.ui("workshop_level_need",[recipe.workshop_level])
	if value.queue.size()>=int(value.level): return game.LocaleSystem.ui("furnace_queue_full")
	if recipe.has("study_kind") and not game.ResearchSystem.learned(game,recipe.study_kind): return game.LocaleSystem.ui("study_blueprint_need",[game.inventory_item_name(recipe.study_kind)])
	if game.energy<float(recipe.energy): return game.LocaleSystem.ui("study_need_energy",[recipe.energy])
	for kind in recipe.inputs:
		if game.inventory_item_count(kind)<int(recipe.inputs[kind]): return game.LocaleSystem.text("needs",[game.CraftingSystem.ingredients_text(game,recipe)])
	return ""

## Резервирует точную партию и энергию, оставляя весь выход единственному завершению работы.
static func enqueue(game: Node, recipe: Dictionary) -> bool:
	recipe=Data.Recipes.recipe(String(recipe.get("id","")))
	if recipe.is_empty() or recipe.get("station","")!=game.crafting_station or not handles(game.crafting_station): return false
	var why:=reason(game,recipe)
	if not why.is_empty(): game.message=why; return false
	if not game.TalentSystem.recipe_unlocked(game,recipe): game.message=game.LocaleSystem.ui("craft_locked"); return false
	for kind in recipe.inputs: game.change_inventory_count(kind,-int(recipe.inputs[kind]))
	game.energy-=float(recipe.energy)
	if not game.state.player.profile.has("workbench_crafts"): game.state.player.profile.workbench_crafts=game.state.player.craft_count
	var duration:=float(recipe.seconds)/speed(game,game.crafting_station)
	state(game,game.crafting_station).queue.append({"id":recipe.id,"duration":duration,"remaining":duration,"paid":recipe.inputs.duplicate()})
	game.message=game.LocaleSystem.ui("furnace_queued"); game.notify_tutorial("workshop_queue"); game.queue_redraw(); return true

## Переключает топливо у термической мастерской, сохраняя раздельность с кузнечным горном.
static func cycle_fuel(game: Node, offset: int=1) -> void:
	if not thermal(game.crafting_station) or not at_station(game,game.crafting_station): return
	var value:=state(game,game.crafting_station); var kinds:=fuels(game.crafting_station); value.fuel=kinds[posmod(kinds.find(value.fuel)+offset,kinds.size())]

## Загружает одну целую порцию топлива в собственный запас мастерской без сжигания при простое.
static func load_fuel(game: Node) -> bool:
	if not thermal(game.crafting_station) or not at_station(game,game.crafting_station): return false
	var value:=state(game,game.crafting_station)
	if value.fuel not in fuels(game.crafting_station): return false
	var heat:float=Fuel.FUELS[value.fuel]
	if game.inventory_item_count(value.fuel)<=0: game.message=game.LocaleSystem.ui("furnace_empty_fuel"); return false
	if float(value.heat)+heat>120.0*int(value.level): game.message=game.LocaleSystem.ui("furnace_fuel_full"); return false
	game.change_inventory_count(value.fuel,-1); value.heat+=heat; game.queue_redraw(); return true

## Даёт видимую полную стоимость следующего уровня из производственных данных.
static func upgrade_text(game: Node, station: String) -> String:
	if not BasementStations.active(game,station).is_empty(): return game.LocaleSystem.ui("basement_upgrade_board")
	var value:=state(game,station)
	if int(value.level)>=3: return game.LocaleSystem.ui("furnace_max")
	var cost:Dictionary=Data.STATIONS[station].upgrades[int(value.level)-1]
	return game.LocaleSystem.ui("furnace_upgrade_cost",[cost.coins,game.ResearchSystem.material_text(game,cost.inputs)])

## Улучшает нужный станок и ускоряет уже начатые партии с сохранением доли готовности.
static func upgrade(game: Node, station: String) -> bool:
	if BasementStations.blueprint_upgrade_required(game,station): return false
	if not at_station(game,station): return false
	var value:=state(game,station)
	if int(value.level)>=3: game.message=game.LocaleSystem.ui("furnace_max"); return false
	var cost:Dictionary=Data.STATIONS[station].upgrades[int(value.level)-1]
	if game.coins<int(cost.coins): game.message=upgrade_text(game,station); return false
	for kind in cost.inputs:
		if game.inventory_item_count(kind)<int(cost.inputs[kind]): game.message=upgrade_text(game,station); return false
	var old_speed:=speed(game,station); game.coins-=int(cost.coins)
	for kind in cost.inputs: game.change_inventory_count(kind,-int(cost.inputs[kind]))
	value.level+=1; var factor:=old_speed/speed(game,station)
	for job in value.queue: job.duration*=factor; job.remaining*=factor
	game.message=game.LocaleSystem.ui("workshop_upgraded",[game.LocaleSystem.ui(station+"_service"),value.level]); game.notify_tutorial("workshop_upgrade"); game.queue_redraw(); return true

## Обновляет только созданные очереди по активному игровому времени, не выполняя тяжёлую работу при простое.
static func update(game: Node, delta: float) -> void:
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("workshops"): return
	for station in Data.STATIONS:
		if Data.STATIONS[station].get("private",false) or not expansion.workshops.has(station) or expansion.workshops[station].queue.is_empty(): continue
		advance(game,station,expansion.workshops[station],maxf(delta,0))

## Завершает полные партии и останавливает термическую работу точно на исчерпании жара.
static func advance(game: Node, station: String, value: Dictionary, elapsed: float) -> void:
	var thermal:bool=Data.STATIONS[station].thermal; var efficiency:float=Data.EFFICIENCY[int(value.level)-1]
	while elapsed>0 and not value.queue.is_empty():
		if thermal and float(value.heat)<=0: break
		var job:Dictionary=value.queue[0]; var step:=minf(elapsed,float(job.remaining))
		if thermal: step=minf(step,float(value.heat)*efficiency)
		job.remaining=maxf(0,float(job.remaining)-step); elapsed-=step
		if thermal: value.heat=maxf(0,float(value.heat)-step/efficiency)
		if float(job.remaining)>0.00001: break
		value.queue.pop_front(); var recipe:Dictionary=Data.Recipes.recipe(job.id)
		game.change_inventory_count(recipe.output,int(recipe.count))
		for kind in recipe.get("byproducts",{}): game.change_inventory_count(kind,int(recipe.byproducts[kind]))
		value.completed+=1; game.state.player.craft_count+=1; game.award_xp(3); game.SkillSystem.award_profession_xp(game,Data.STATIONS[station].get("profession","smithing"),4)
		game.message=game.LocaleSystem.ui("workshop_finished",[game.inventory_item_name(recipe.output),recipe.count]); game.notify_tutorial(station)
		if recipe.output in ["clay","research_paper"]: game.notify_tutorial("workshop_recycling")

## Показывает очередь и оставшееся время, а стеклодуву также собственный запас жара.
static func status(game: Node) -> String:
	var value:=state(game,game.crafting_station)
	var text:String=game.LocaleSystem.ui("workshop_queue_status",[value.queue.size(),value.level])
	if thermal(game.crafting_station): text=game.LocaleSystem.ui("furnace_status",[value.heat,value.queue.size(),value.level])
	if not value.queue.is_empty():
		var waiting:bool=thermal(game.crafting_station) and float(value.heat)<=0
		var key:String=("smoker_waiting" if game.crafting_station=="smoker" else "furnace_waiting") if waiting else "furnace_remaining"
		text+="\n"+game.LocaleSystem.ui(key,[] if waiting else [value.queue[0].remaining])
	return text

## Сообщает точный выход, расход энергии, длительность и побочный материал выбранной технологии.
static func summary(game: Node, recipe: Dictionary) -> String:
	var why:=reason(game,recipe)
	if not why.is_empty(): return why
	var text:String=game.LocaleSystem.ui("workshop_summary",[recipe.count,float(recipe.seconds)/speed(game,recipe.station),recipe.energy])
	if not recipe.get("byproducts",{}).is_empty(): text+="\n"+game.ResearchSystem.material_text(game,recipe.byproducts)
	return text

## Обрабатывает улучшение и топливо, оставляя обычную навигацию и постановку общему окну рецептов.
static func handle_controls(game: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_U: upgrade(game,game.crafting_station)
		elif event.keycode==KEY_Q and thermal(game.crafting_station): cycle_fuel(game)
		elif event.keycode==KEY_F and thermal(game.crafting_station): load_fuel(game)
		else: return false
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_LEFT_STICK: upgrade(game,game.crafting_station)
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER] and thermal(game.crafting_station): cycle_fuel(game,-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1)
		elif event.button_index==JOY_BUTTON_Y and thermal(game.crafting_station): load_fuel(game)
		else: return false
	else: return false
	game.queue_redraw(); return true

## Проверяет необходимость жара у выбранного вида мастерской.
static func thermal(station: String) -> bool:
	return handles(station) and bool(Data.STATIONS[station].thermal)

## Ограничивает пищевую коптильню чистым топливом, сохраняя прежний выбор у стеклодува.
static func fuels(station: String) -> Array:
	return Data.STATIONS[station].get("fuels",Fuel.FUELS.keys()) if handles(station) else []
