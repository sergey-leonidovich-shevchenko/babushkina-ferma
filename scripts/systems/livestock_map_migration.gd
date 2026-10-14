extends RefCounted

const Data := preload("res://scripts/systems/livestock_data.gd")

## Определяет клетки нового двора, занятые загонами, основаниями или центральной дорожкой.
static func reserved(rect: Rect2) -> bool:
	for pen in Data.PENS.values():
		if Rect2(pen.rect).grow(8).intersects(rect): return true
	for prop in Data.PROPS:
		if Data.prop_base(prop).grow(8).intersects(rect): return true
	return Data.WALKWAY.grow(8).intersects(rect)

## Переносит старые пользовательские посадки из новых препятствий, сохраняя весь выращенный прогресс.
static func apply(game: Node) -> void:
	var original_location: String=game.current_location
	game.current_location="overworld"
	var farming = game.WorldFarmingSystem
	for key in game.state.world.world_plots.keys().duplicate():
		var plot: Dictionary=game.state.world.world_plots[key]
		if plot.location!="overworld" or not reserved(farming.cell_rect(plot.cell)): continue
		var replacement := _free_cell(game,plot.cell)
		if replacement==Vector2i(-1,-1): continue
		game.state.world.world_plots.erase(key); plot.cell=replacement
		game.state.world.world_plots[farming.plot_key("overworld",replacement)]=plot
	for node in game.food_nodes:
		if node.get("location","")!="overworld" or not bool(node.get("planted_by_player",false)): continue
		var cell: Vector2i=farming.cell_at(node.position)
		if not reserved(farming.cell_rect(cell)): continue
		var replacement := _free_cell(game,cell)
		if replacement!=Vector2i(-1,-1): node.position=farming.cell_rect(replacement).get_center()
	game.current_location=original_location

## Выбирает ближайшую свободную пригодную клетку вне двора без перезаписи другой грядки.
static func _free_cell(game: Node, origin: Vector2i) -> Vector2i:
	for radius in range(1,21):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if maxi(absi(x),absi(y))!=radius: continue
				var cell := origin+Vector2i(x,y)
				if reserved(game.WorldFarmingSystem.cell_rect(cell)): continue
				if game.state.world.world_plots.has(game.WorldFarmingSystem.plot_key("overworld",cell)): continue
				if game.WorldFarmingSystem.outdoor_soil_reason(game,"overworld",cell)=="tillable": return cell
	return Vector2i(-1,-1)
