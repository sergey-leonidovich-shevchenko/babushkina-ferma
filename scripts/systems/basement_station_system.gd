extends RefCounted

const Basement := preload("res://scripts/systems/basement_system.gd")

## Возвращает выбранный готовый станок только при совпадении вида, локации и единственной стороны обслуживания.
static func active(game: Node, kind: String="") -> Dictionary:
	if game.current_location!=Basement.Data.LOCATION: return {}
	var item:=Basement.object(game,int(game.get_meta("basement_active_station",0)))
	if item.is_empty() or item.phase!="ready" or (not kind.is_empty() and item.kind!=kind): return {}
	if game.player.distance_to(Basement.Layout.center(Basement.Layout.approach_cell(item)))>22: return {}
	return item

## Даёт память именно выбранного производственного экземпляра, не используя глобальный уровень соседнего станка.
static func production(game: Node, kind: String) -> Dictionary:
	var item:=active(game,kind)
	return item.production if not item.is_empty() else {}

## Возвращает локальную сложность стола, сохраняя прежнюю механику общедоступных деревенских рабочих мест.
static func level(game: Node, kind: String, fallback: int=1) -> int:
	var item:=active(game,kind)
	return int(item.level) if not item.is_empty() else fallback

## Проверяет готовность и сложность выбранного стола до расхода любых ингредиентов.
static func recipe_reason(game: Node, recipe: Dictionary) -> String:
	if game.current_location!=Basement.Data.LOCATION: return ""
	var item:=active(game,String(recipe.get("station","workbench")))
	if item.is_empty(): return "basement_station_need"
	return "basement_recipe_level" if int(item.level)<Basement.Data.recipe_level(recipe) else ""

## Локализует ограничение собственного стола и подставляет только действительно требуемые параметры.
static func reason_text(game: Node, recipe: Dictionary) -> String:
	var key:=recipe_reason(game,recipe)
	return game.LocaleSystem.ui(key,[Basement.Data.recipe_level(recipe)] if key=="basement_recipe_level" else [])

## Открывает готовый станок обычным предметным окном, а строительную кучу переводит в удерживаемую работу.
static func interact(game: Node, id: int) -> bool:
	var item:=Basement.object(game,id)
	if item.is_empty() or game.current_location!=Basement.Data.LOCATION or game.player.distance_to(Basement.Layout.center(Basement.Layout.approach_cell(item)))>22: return false
	if item.phase!="ready": Basement.ui(game).holding=id; Basement.ui(game).hold_time=0.0; game.action_held=false; return true
	game.set_meta("basement_active_station",id)
	if item.kind=="forge": game.open_forge()
	else: game.open_crafting(item.kind)
	return true

## Удерживает улучшение личного станка у настенного чертежа, вместо мгновенного списания из производственного меню.
static func blueprint_upgrade_required(game: Node, kind: String) -> bool:
	if active(game,kind).is_empty(): return false
	game.message=game.LocaleSystem.ui("basement_upgrade_board"); game.queue_redraw(); return true
