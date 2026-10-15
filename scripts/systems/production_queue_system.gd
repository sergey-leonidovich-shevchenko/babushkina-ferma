extends RefCounted

const Kitchen := preload("res://scripts/systems/kitchen_data.gd")
const BUTTON := Rect2(938,120,150,28)
const WORDS := {
	"cancel":["Отменить первую","Cancel first","Cancelar primera","Ersten abbrechen","Annuler la première","取消首批"],
	"refund":["Сырьё возвращено; потраченные жар и энергия не возвращаются","Materials returned; spent heat and energy stay spent","Material devuelto; calor y energía gastados no se devuelven","Material zurück; verbrauchte Wärme und Energie bleiben verbraucht","Matériaux rendus ; chaleur et énergie dépensées non remboursées","已返还原料；已消耗的热量和体力不退还"],
	"cost":["Жар %.1f • топливо +%d","Heat %.1f • fuel +%d","Calor %.1f • combustible +%d","Wärme %.1f • Brennstoff +%d","Chaleur %.1f • combustible +%d","热量 %.1f • 燃料 +%d"],
	"cold":["Без топлива","No fuel","Sin combustible","Ohne Brennstoff","Sans combustible","无需燃料"],
}

## Возвращает перевод общего договора очереди на одном из шести языков.
static func word(game: Node, id: String, values: Array=[]) -> String:
	var index:int=maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))
	var text:String=WORDS[id][index]
	return text%values if not values.is_empty() else text

## Отличает сохраняемые очереди от мгновенного верстака и общей деревенской кухни.
static func handles(game: Node) -> bool:
	return game.crafting_station=="furnace" or game.WorkshopSystem.handles(game.crafting_station) or game.CraftingSystem.Kitchen.active(game)

## Получает только выбранный экземпляр у его рабочей стороны, исключая удалённую отмену.
static func active(game: Node) -> Dictionary:
	if not game.crafting_open: return {}
	if game.crafting_station=="furnace":
		return game.FurnaceSystem.state(game) if game.FurnaceSystem.at_station(game) else {}
	if game.WorkshopSystem.handles(game.crafting_station):
		return game.WorkshopSystem.state(game,game.crafting_station) if game.WorkshopSystem.at_station(game,game.crafting_station) else {}
	return game.CraftingSystem.Kitchen.state(game) if game.CraftingSystem.Kitchen.active(game) else {}

## Возвращает точную цену оставшегося в очереди сырья без возврата уже потраченных жара и энергии.
static func cancel_first(game: Node) -> bool:
	var value:=active(game)
	if value.is_empty() or value.queue.is_empty(): return false
	var job:Dictionary=value.queue.pop_front()
	for kind in job.paid: game.change_inventory_count(kind,int(job.paid[kind]))
	game.message=word(game,"refund"); game.notify_tutorial("production_cancel"); game.queue_redraw(); return true

## Рассчитывает длительность и жар из тех же скоростей и эффективности, что использует завершение партии.
static func heat_cost(game: Node, recipe: Dictionary) -> float:
	var station:=String(recipe.get("station","workbench")); var value:Dictionary={}; var duration:=0.0; var efficiency:=1.0
	if station=="furnace":
		value=game.FurnaceSystem.state(game); duration=float(recipe.seconds)/game.FurnaceSystem.speed(game)
		efficiency=game.FurnaceSystem.Data.EFFICIENCY[int(value.level)-1]
	elif game.WorkshopSystem.thermal(station):
		value=game.WorkshopSystem.state(game,station)
		if value.is_empty(): return 0
		duration=float(recipe.seconds)/game.WorkshopSystem.speed(game,station)
		efficiency=game.WorkshopSystem.Data.EFFICIENCY[int(value.level)-1]
	elif station=="cauldron" and game.CraftingSystem.Kitchen.active(game) and recipe.output not in Kitchen.COLD:
		value=game.CraftingSystem.Kitchen.state(game); duration=Kitchen.seconds(recipe)/float(Kitchen.SPEED[int(value.level)-1])
		efficiency=Kitchen.EFFICIENCY[int(value.level)-1]
	return duration/efficiency

## Показывает точный жар партии и число дополнительных порций выбранного топлива с учётом текущего запаса.
static func cost_text(game: Node, recipe: Dictionary) -> String:
	var heat:=heat_cost(game,recipe)
	if heat<=0: return word(game,"cold")
	var value:=active(game)
	if value.is_empty(): return ""
	var fuels:Dictionary=Kitchen.FUELS if game.CraftingSystem.Kitchen.active(game) else game.FurnaceSystem.Data.FUELS
	var portions:=ceili(maxf(0,heat-float(value.heat)-0.00001)/float(fuels.get(value.fuel,1)))
	return word(game,"cost",[heat,portions])

## Обрабатывает явную отмену клавиатурой и свободной кнопкой правого стика.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not handles(game): return false
	if (event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_DELETE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_RIGHT_STICK):
		cancel_first(game); return true
	return false

## Рисует общую кнопку без перекрытия топливных фильтров и краткую цену над карточкой рецепта.
static func draw(game: Node) -> void:
	if not handles(game): return
	var value:=active(game); var enabled:bool=not value.is_empty() and not value.queue.is_empty()
	preload("res://scripts/presentation/moon_theme.gd").button(game,BUTTON,word(game,"cancel"),false,enabled)
	if game.crafting_selected<0 or game.crafting_selected>=game.CraftingSystem.RECIPES.size(): return
	var recipe:Dictionary=game.CraftingSystem.RECIPES[game.crafting_selected]
	game.draw_ui_string(game.UI_FONT,Vector2(714,162),cost_text(game,recipe),HORIZONTAL_ALIGNMENT_CENTER,216,10,Color("684b31"))

## Обрабатывает мышь и касание в той же области, которая нарисована общей кнопкой.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	if not handles(game) or not BUTTON.has_point(point): return false
	cancel_first(game); return true
