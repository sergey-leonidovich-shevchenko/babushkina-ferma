extends RefCounted

const Data := preload("res://scripts/systems/furnace_data.gd")
const STATION := Vector2(660,370)

## Возвращает единое сохраняемое состояние общего горна без фонового таймера операционной системы.
static func state(game: Node) -> Dictionary:
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("furnace"): expansion.furnace={"level":1,"heat":0.0,"fuel":"wood","queue":[],"completed":0}
	return expansion.furnace

## Нормализует старые слоты и проверенные записи очереди, не выдавая сырьё повторно при загрузке.
static func restore(game: Node) -> void:
	var value:=state(game); value.level=clampi(int(value.get("level",1)),1,3)
	value.heat=clampf(float(value.get("heat",0)),0,120.0*int(value.level)); value.completed=maxi(0,int(value.get("completed",0)))
	value.fuel=String(value.get("fuel","wood")) if Data.FUELS.has(value.get("fuel","wood")) else "wood"
	var queue:=[]
	for job in value.get("queue",[]):
		if Data.recipe(String(job.get("id",""))).is_empty() or queue.size()>=int(value.level): continue
		var duration:=clampf(float(job.duration),0.01,60.0)
		queue.append({"id":job.id,"duration":duration,"remaining":clampf(float(job.remaining),0,duration)})
	value.queue=queue

## Ограничивает производственные и хозяйственные операции настоящей точкой у печи в кузнице.
static func at_station(game: Node) -> bool:
	return game.current_location=="forge_interior" and game.player.distance_to(STATION)<=80.0

## Даёт общий множитель скорости для новых и уже поставленных партий.
static func speed(game: Node) -> float:
	return float(Data.SPEED[int(state(game).level)-1])

## Проверяет вместимость очереди и уровень до списания ингредиентов.
static func can_enqueue(game: Node, recipe: Dictionary) -> bool:
	if Data.recipe(String(recipe.get("id",""))).is_empty(): return false
	var value:=state(game)
	return at_station(game) and int(value.level)>=int(recipe.furnace_level) and value.queue.size()<int(value.level)

## Списывает точную партию и сохраняет работу, оставляя выдачу результата единственному обработчику завершения.
static func enqueue(game: Node, recipe: Dictionary) -> bool:
	recipe=Data.recipe(String(recipe.get("id","")))
	if recipe.is_empty(): return false
	if not game.CraftingSystem.can_craft(game,recipe): game.message=summary(game,recipe); return false
	if not game.state.player.profile.has("workbench_crafts"): game.state.player.profile.workbench_crafts=game.state.player.craft_count
	for kind in recipe.inputs: game.change_inventory_count(kind,-int(recipe.inputs[kind]))
	var duration:=float(recipe.seconds)/speed(game)
	state(game).queue.append({"id":recipe.id,"duration":duration,"remaining":duration})
	game.message=game.LocaleSystem.ui("furnace_queued"); game.notify_tutorial("furnace_queue"); return true

## Выбирает доступный вид топлива без загрузки или потери предметов.
static func cycle_fuel(game: Node, offset: int=1) -> void:
	var value:=state(game); var kinds:=Data.FUELS.keys(); value.fuel=kinds[posmod(kinds.find(value.fuel)+offset,kinds.size())]
	game.queue_redraw()

## Направляет клавиши и кнопки геймпада в хозяйственные операции, оставляя выбор рецепта общему окну.
static func handle_controls(game: Node, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: cycle_fuel(game)
			KEY_F: load_fuel(game)
			KEY_U: upgrade(game)
			_: return false
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER: cycle_fuel(game,-1)
			JOY_BUTTON_RIGHT_SHOULDER: cycle_fuel(game)
			JOY_BUTTON_Y: load_fuel(game)
			JOY_BUTTON_LEFT_STICK: upgrade(game)
			_: return false
	else: return false
	game.queue_redraw(); return true

## Загружает одну целую порцию, сохраняя лишнее топливо в рюкзаке при полном запасе жара.
static func load_fuel(game: Node) -> bool:
	if not at_station(game): return false
	var value:=state(game); var heat:float=Data.FUELS[value.fuel]
	if game.inventory_item_count(value.fuel)<=0: game.message=game.LocaleSystem.ui("furnace_empty_fuel"); return false
	if float(value.heat)+heat>120.0*int(value.level): game.message=game.LocaleSystem.ui("furnace_fuel_full"); return false
	game.change_inventory_count(value.fuel,-1); value.heat+=heat; game.notify_tutorial("furnace_fuel"); game.queue_redraw(); return true

## Улучшает печь целиком и ускоряет оставшееся время работы, сохраняя долю готовности каждой партии.
static func upgrade(game: Node) -> bool:
	if not at_station(game): return false
	var value:=state(game)
	if int(value.level)>=3: game.message=game.LocaleSystem.ui("furnace_max"); return false
	var cost:Dictionary=Data.UPGRADES[int(value.level)-1]
	if game.coins<int(cost.coins): game.message=upgrade_text(game); return false
	for kind in cost.inputs:
		if game.inventory_item_count(kind)<int(cost.inputs[kind]): game.message=upgrade_text(game); return false
	game.coins-=int(cost.coins)
	for kind in cost.inputs: game.change_inventory_count(kind,-int(cost.inputs[kind]))
	var old_speed:=speed(game); value.level+=1; var factor:=old_speed/speed(game)
	for job in value.queue: job.duration*=factor; job.remaining*=factor
	game.message=game.LocaleSystem.ui("furnace_upgraded",[value.level]); game.notify_tutorial("furnace_upgrade"); game.queue_redraw(); return true

## Расходует тепло только на активную плавку, учитывая остановку без топлива и несколько завершений в одном шаге.
static func update(game: Node, delta: float) -> void:
	var value:=state(game); var elapsed:=maxf(delta,0); var efficiency:float=Data.EFFICIENCY[int(value.level)-1]
	while elapsed>0 and not value.queue.is_empty() and float(value.heat)>0:
		var job:Dictionary=value.queue[0]; var step:=minf(elapsed,minf(float(job.remaining),float(value.heat)*efficiency))
		job.remaining=maxf(0,float(job.remaining)-step); value.heat=maxf(0,float(value.heat)-step/efficiency); elapsed-=step
		if float(job.remaining)>0.00001: break
		value.queue.pop_front(); var recipe:Dictionary=Data.recipe(job.id)
		game.change_inventory_count(recipe.output,int(recipe.count))
		for kind in recipe.get("byproducts",{}): game.change_inventory_count(kind,int(recipe.byproducts[kind]))
		value.completed+=1; game.state.player.craft_count+=1; game.award_xp(3); game.SkillSystem.award_profession_xp(game,"smithing",4)
		game.message=game.LocaleSystem.ui("furnace_finished",[game.inventory_item_name(recipe.output),recipe.count]); game.notify_tutorial("furnace_done")

## Показывает запас, остановку или оставшееся время первой партии в том же меню, где выбирается рецепт.
static func status(game: Node) -> String:
	var value:=state(game); var result:String=game.LocaleSystem.ui("furnace_status",[value.heat,value.queue.size(),value.level])
	if not value.queue.is_empty(): result+="\n"+game.LocaleSystem.ui("furnace_waiting" if float(value.heat)<=0 else "furnace_remaining",[] if float(value.heat)<=0 else [value.queue[0].remaining])
	return result

## Описывает требования или реальный отложенный выход, не обещая мгновенного предмета.
static func summary(game: Node, recipe: Dictionary) -> String:
	var value:=state(game)
	if not at_station(game): return game.LocaleSystem.ui("furnace_station_need")
	if int(value.level)<int(recipe.furnace_level): return game.LocaleSystem.ui("furnace_level_need",[recipe.furnace_level])
	if value.queue.size()>=int(value.level): return game.LocaleSystem.ui("furnace_queue_full")
	for kind in recipe.inputs:
		if game.inventory_item_count(kind)<int(recipe.inputs[kind]): return game.LocaleSystem.text("needs",[game.CraftingSystem.ingredients_text(game,recipe)])
	var result:String=game.LocaleSystem.ui("furnace_summary",[recipe.count,float(recipe.seconds)/speed(game),value.queue.size(),value.level])
	for kind in recipe.get("byproducts",{}): result=result.get_slice("\n",0)+"\n"+game.LocaleSystem.ui("alchemy_byproduct",[game.inventory_item_name(kind),recipe.byproducts[kind]])
	return result

## Возвращает всю цену следующего улучшения для видимой подсказки и атомарного отказа.
static func upgrade_text(game: Node) -> String:
	var value:=state(game)
	if int(value.level)>=3: return game.LocaleSystem.ui("furnace_max")
	var cost:Dictionary=Data.UPGRADES[int(value.level)-1]; var parts:Array[String]=[]
	for kind in cost.inputs: parts.append(game.inventory_item_name(kind)+" ×"+str(cost.inputs[kind]))
	return game.LocaleSystem.ui("furnace_upgrade_cost",[cost.coins,", ".join(parts)])
