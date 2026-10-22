extends RefCounted

const Data := preload("res://scripts/systems/kitchen_data.gd")
const Stations := preload("res://scripts/systems/basement_station_system.gd")

## Требует конкретную готовую личную кухню у её единственной рабочей стороны.
static func active(game: Node) -> bool:
	return game.crafting_station=="cauldron" and not Stations.active(game,"cauldron").is_empty()

## Возвращает только собственную производственную память выбранной кухни.
static func state(game: Node) -> Dictionary:
	return Stations.production(game,"cauldron")

## Объясняет очередь, сложность, таланты, энергию и полный состав без частичных списаний.
static func reason(game: Node, recipe: Dictionary) -> String:
	if not active(game): return "basement_station_need"
	if recipe.get("station","")!="cauldron": return "basement_station_need"
	var value:=state(game)
	if Data.level(recipe)>int(value.level): return "basement_recipe_level"
	if not game.TalentSystem.recipe_unlocked(game,recipe): return "craft_locked"
	if value.queue.size()>=int(value.level): return "furnace_queue_full"
	if game.energy<Data.energy(recipe): return "study_need_energy"
	for kind in recipe.inputs:
		if game.inventory_item_count(kind)<int(recipe.inputs[kind]): return "kitchen_ingredients"
	return ""

## Резервирует настоящую партию с точным составом, выдавая еду и опыт только после работы.
static func enqueue(game: Node, recipe: Dictionary) -> bool:
	var why:=reason(game,recipe)
	if not why.is_empty(): game.message=reason_text(game,recipe); return false
	for kind in recipe.inputs: game.change_inventory_count(kind,-int(recipe.inputs[kind]))
	game.energy-=Data.energy(recipe)
	var duration:=Data.seconds(recipe)/float(Data.SPEED[int(state(game).level)-1])
	state(game).queue.append({"id":recipe.id,"duration":duration,"remaining":duration,"paid":recipe.inputs.duplicate()})
	game.notify_tutorial("kitchen_queue"); game.message=game.LocaleSystem.ui("furnace_queued"); game.queue_redraw(); return true

## Локализует ограничение кухни с параметрами из того же источника стоимости.
static func reason_text(game: Node, recipe: Dictionary) -> String:
	var key:=reason(game,recipe)
	return game.LocaleSystem.ui(key,[Data.level(recipe)] if key=="basement_recipe_level" else ([Data.energy(recipe)] if key=="study_need_energy" else []))

## Меняет только три кухонных вида топлива, исключая мусор и производственные отходы.
static func cycle_fuel(game: Node, direction: int=1) -> void:
	if not active(game): return
	var kinds:Array=Data.FUELS.keys(); var value:=state(game)
	value.fuel=kinds[posmod(kinds.find(value.fuel)+direction,kinds.size())]; game.queue_redraw()

## Загружает одну порцию топлива с атомарной проверкой наличия и вместимости.
static func load_fuel(game: Node) -> bool:
	if not active(game): return false
	var value:=state(game); var fuel:=String(value.fuel)
	if not Data.FUELS.has(fuel): return false
	if float(value.heat)+float(Data.FUELS.get(fuel,0))>120*int(value.level)+0.001: game.message=game.LocaleSystem.ui("furnace_fuel_full"); return false
	if game.inventory_item_count(fuel)<1: game.message=game.LocaleSystem.ui("furnace_empty_fuel"); return false
	game.change_inventory_count(fuel,-1); value.heat=minf(120*int(value.level),float(value.heat)+float(Data.FUELS[fuel]))
	game.notify_tutorial("kitchen_fuel"); game.queue_redraw(); return true

## Продвигает переданную очередь ровно один раз и тратит жар только на термические блюда.
static func advance(game: Node, value: Dictionary, delta: float) -> void:
	var elapsed:=maxf(delta,0); var efficiency:float=Data.EFFICIENCY[int(value.level)-1]
	while elapsed>0 and not value.queue.is_empty():
		var job:Dictionary=value.queue[0]; var recipe:=Data.recipe(job.id); var thermal:bool=recipe.output not in Data.COLD
		if thermal and float(value.heat)<=0: break
		var step:=minf(elapsed,float(job.remaining))
		if thermal: step=minf(step,float(value.heat)*efficiency)
		job.remaining=maxf(0,float(job.remaining)-step); elapsed-=step
		if thermal: value.heat=maxf(0,float(value.heat)-step/efficiency)
		if float(job.remaining)>0.00001: break
		value.queue.pop_front(); value.completed=int(value.completed)+1
		game.change_inventory_count(recipe.output,int(recipe.count)); game.state.player.craft_count+=1
		game.award_xp(4); game.SkillSystem.award_profession_xp(game,"farming",3)
		game.notify_tutorial("craft_window"); game.notify_tutorial("cooking"); game.notify_tutorial("kitchen_done"); game.play_sfx("craft")

## Показывает полную длительность и текущую причину ожидания выбранного рецепта.
static func summary(game: Node, recipe: Dictionary) -> String:
	var why:=reason_text(game,recipe)
	if not why.is_empty(): return why
	return game.LocaleSystem.ui("kitchen_summary",[recipe.count,Data.seconds(recipe)/float(Data.SPEED[int(state(game).level)-1]),Data.energy(recipe),game.LocaleSystem.ui("kitchen_cold" if recipe.output in Data.COLD else "kitchen_hot")])

## Разделяет выбор топлива, его загрузку и обычную навигацию по кулинарным рецептам.
static func handle_controls(game: Node, event: InputEvent) -> bool:
	if not active(game): return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_TAB: cycle_filter(game,-1 if event.shift_pressed else 1); return true
		if event.keycode in [KEY_LEFT,KEY_RIGHT]: cycle_filter(game,-1 if event.keycode==KEY_LEFT else 1); return true
		if event.keycode==KEY_Q: cycle_fuel(game); return true
		if event.keycode==KEY_F: load_fuel(game); return true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]: cycle_filter(game,-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1); return true
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]: cycle_fuel(game,-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1); return true
		if event.button_index==JOY_BUTTON_Y: load_fuel(game); return true
	return false

## Меняет группу рецептов без списания ингредиентов и сбрасывает выбор на доступную строку.
static func cycle_filter(game: Node, direction: int=1) -> void:
	if not active(game): return
	var groups:=["all","hot","cold"]; var current:=String(game.get_meta("kitchen_filter","all"))
	game.set_meta("kitchen_filter",groups[posmod(groups.find(current)+direction,3)])
	var visible:Array=game.CraftingSystem.visible_indices(game)
	game.crafting_selected=visible[0] if not visible.is_empty() else -1; game.queue_redraw()
