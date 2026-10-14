extends RefCounted

## Сохраняет старую посадку в свободной домашней грядке либо возвращает оплаченные предметы.
static func relocate(game: Node, plot: Dictionary) -> void:
	var fertilizer := String(plot.get("fertilizer",""))
	if not bool(plot.get("planted",false)):
		if not fertilizer.is_empty(): game.change_inventory_count(fertilizer,1)
		return
	for y in game.FARM_SIZE.y:
		for x in game.FARM_SIZE.x:
			var cell := Vector2i(x,y)
			var home: Dictionary = game.plots[cell]
			if bool(home.get("planted",false)) or not String(home.get("fertilizer","")).is_empty(): continue
			var moved := plot.duplicate(true)
			moved.location = "overworld"; moved.cell = cell; moved.tilled = true
			game.plots[cell] = moved
			return
	var crop := String(plot.get("crop_kind","carrot"))
	var data: Dictionary = game.CropCatalogSystem.data(crop)
	if float(plot.growth) >= game.CropCatalogSystem.growth_duration(crop):
		game.change_inventory_count(String(data.harvest),game.CropCatalogSystem.harvest_count(game,crop)+int(fertilizer=="quality_fertilizer"))
		if game.CropCatalogSystem.is_perennial(crop): game.change_inventory_count(String(data.seed),1)
	else:
		game.change_inventory_count(String(data.seed),1)
	if not fertilizer.is_empty(): game.change_inventory_count(fertilizer,1)
