extends RefCounted

const Workshop := preload("res://scripts/systems/workshop_system.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const FuelButton := Rect2(210,120,166,28)
const LoadButton := Rect2(382,120,134,28)
const UpgradeButton := Rect2(522,120,158,28)

## Даёт полное читаемое содержимое всех зарезервированных партий одной очереди.
static func queue_text(game: Node) -> String:
	var labels:Array[String]=[]
	for job in Workshop.state(game,game.crafting_station).queue:
		var recipe:Dictionary=Workshop.Data.Recipes.recipe(job.id); labels.append(game.inventory_item_name(recipe.output)+" ×"+str(recipe.count))
	return game.LocaleSystem.ui("furnace_queue_names",[" → ".join(labels) if not labels.is_empty() else "—"])

## Рисует улучшение всех станков и отдельные топливные кнопки стеклодува над списком.
static func draw_toolbar(game: Node) -> void:
	var value:=Workshop.state(game,game.crafting_station)
	var buttons:Array=[[UpgradeButton,game.LocaleSystem.ui("furnace_upgrade")]]
	if game.crafting_station=="glassblowing":
		buttons.append([FuelButton,game.inventory_item_name(value.fuel)+" ×"+str(game.inventory_item_count(value.fuel))]); buttons.append([LoadButton,game.LocaleSystem.ui("furnace_load")])
	else: game.draw_ui_string(game.UI_FONT,Vector2(220,140),game.LocaleSystem.ui("workshop_energy",[game.energy]),HORIZONTAL_ALIGNMENT_LEFT,288,11,Kit.COLORS.ink)
	for entry in buttons:
		Kit.draw_nine_patch(game,"editor_button_normal",entry[0])
		game.draw_ui_string(game.UI_FONT,entry[0].position+Vector2(8,20),entry[1],HORIZONTAL_ALIGNMENT_CENTER,entry[0].size.x-16,11,Kit.COLORS.ink)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,486),queue_text(game),HORIZONTAL_ALIGNMENT_LEFT,450,28,10,2,Kit.COLORS.ink)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,521),Workshop.upgrade_text(game,game.crafting_station),HORIZONTAL_ALIGNMENT_LEFT,450,28,10,2,Kit.COLORS.ink)

## Разделяет топливные и хозяйственные нажатия, не выбирая скрытые строки за ними.
static func handle_pointer(game: Node, position: Vector2) -> bool:
	if UpgradeButton.has_point(position): Workshop.upgrade(game,game.crafting_station)
	elif game.crafting_station=="glassblowing" and FuelButton.has_point(position): Workshop.cycle_fuel(game)
	elif game.crafting_station=="glassblowing" and LoadButton.has_point(position): Workshop.load_fuel(game)
	else: return false
	game.queue_redraw(); return true
