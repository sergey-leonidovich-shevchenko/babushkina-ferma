extends RefCounted

const Kitchen := preload("res://scripts/systems/kitchen_system.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const FUEL := Rect2(210,120,166,28)
const LOAD := Rect2(382,120,134,28)
const STAGE := Rect2(522,120,158,28)
const FILTER := Rect2(714,120,216,28)

## Показывает все оплаченные партии конкретной кухни в порядке приготовления.
static func queue_text(game: Node) -> String:
	var labels:Array[String]=[]
	for job in Kitchen.state(game).queue:
		var recipe:Dictionary=Kitchen.Data.recipe(job.id)
		labels.append(game.inventory_item_name(recipe.output)+" ×"+str(recipe.count))
	return game.LocaleSystem.ui("furnace_queue_names",[" → ".join(labels) if not labels.is_empty() else "—"])

## Объясняет запас жара, вместимость и остановку первой партии без скрытого расхода топлива.
static func status(game: Node) -> String:
	var value:=Kitchen.state(game)
	var result:String=game.LocaleSystem.ui("kitchen_status",[value.heat,120*int(value.level),value.queue.size(),value.level])
	if not value.queue.is_empty():
		var job:Dictionary=value.queue[0]; var recipe:Dictionary=Kitchen.Data.recipe(job.id)
		result+="\n"+game.LocaleSystem.ui("kitchen_waiting" if recipe.output not in Kitchen.Data.COLD and value.heat<=0 else "kitchen_remaining",[] if recipe.output not in Kitchen.Data.COLD and value.heat<=0 else [job.remaining])
	return result

## Оставляет эффекты блюда справа и размещает топливо, группы и очередь в свободных полях окна.
static func draw_toolbar(game: Node) -> void:
	var value:=Kitchen.state(game)
	var buttons:Array=[[FUEL,game.inventory_item_name(value.fuel)+" ×"+str(game.inventory_item_count(value.fuel))],[LOAD,game.LocaleSystem.ui("furnace_load")],[STAGE,game.LocaleSystem.ui("kitchen_stage%d"%int(value.level))],[FILTER,"‹  "+game.LocaleSystem.ui("kitchen_filter_"+String(game.get_meta("kitchen_filter","all")))+"  ›"]]
	for entry in buttons:
		Kit.draw_nine_patch(game,"editor_button_normal",entry[0])
		game.draw_ui_string(game.UI_FONT,entry[0].position+Vector2(8,20),entry[1],HORIZONTAL_ALIGNMENT_CENTER,entry[0].size.x-16,11,Kit.COLORS.ink)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,486),queue_text(game),HORIZONTAL_ALIGNMENT_LEFT,450,28,10,2,Kit.COLORS.ink)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,521),status(game),HORIZONTAL_ALIGNMENT_LEFT,450,28,10,2,Kit.COLORS.ink)

## Обрабатывает мышь и касания только видимых кухонных кнопок.
static func handle_pointer(game: Node, position: Vector2) -> bool:
	if FUEL.has_point(position): Kitchen.cycle_fuel(game)
	elif LOAD.has_point(position): Kitchen.load_fuel(game)
	elif FILTER.has_point(position): Kitchen.cycle_filter(game,-1 if position.x<FILTER.get_center().x else 1)
	elif STAGE.has_point(position): game.message=game.LocaleSystem.ui("basement_upgrade_board")
	else: return false
	game.queue_redraw(); return true
