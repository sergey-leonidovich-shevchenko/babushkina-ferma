extends RefCounted

const FERTILIZERS := {"compost":1.2,"growth_fertilizer":1.35,"quality_fertilizer":1.0}
const Farming := preload("res://scripts/systems/world_farming_system.gd")

## Вносит один расходник в конкретную пустую грядку после проверки всех ограничений.
static func apply(game: Node, kind: String) -> bool:
	if not FERTILIZERS.has(kind): return false
	var target:=Farming.target(game)
	if not bool(target.valid): game.message=game.LocaleSystem.ui("fertilizer_need"); return false
	var plot:=Farming.read_target(game,target)
	if not plot.tilled or plot.planted: game.message=game.LocaleSystem.ui("fertilizer_need"); return false
	if not String(plot.get("fertilizer","")).is_empty(): game.message=game.LocaleSystem.ui("fertilizer_present"); return false
	if not game.change_inventory_count(kind,-1): return false
	plot.fertilizer=kind; Farming.write_target(game,target,plot)
	game.message=game.LocaleSystem.ui("fertilizer_used",[game.inventory_item_name(kind)])
	game.notify_tutorial("fertilizer"); game.queue_redraw(); return true

## Ускоряет только удобренную грядку, сохраняя сезонность и обязательный полив.
static func multiplier(plot: Dictionary) -> float:
	return float(FERTILIZERS.get(String(plot.get("fertilizer","")),1.0))

## Даёт добавочный плод за удобрение урожая и расходует его после успешного сбора.
static func harvest_bonus(plot: Dictionary) -> int:
	return 1 if plot.get("fertilizer","")=="quality_fertilizer" else 0

## Отбрасывает неизвестные виды удобрений до загрузки живой модели, принимая старые грядки без нового поля.
static func valid(plots: Array) -> bool:
	for plot in plots:
		var kind:String=String(plot.get("fertilizer",""))
		if not kind.is_empty() and (not FERTILIZERS.has(kind) or not bool(plot.tilled)): return false
	return true

## Расходует наживку только при фактическом выпуске лески, оставляя пустой запас допустимым.
static func cast_multiplier(game: Node) -> float:
	if not game.change_inventory_count("fishing_bait",-1): return 1.0
	game.notify_tutorial("fishing_bait"); return 0.65
