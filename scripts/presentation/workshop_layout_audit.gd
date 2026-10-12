extends RefCounted

const Workshop := preload("res://scripts/systems/workshop_system.gd")

## Проверяет новые станки на каждом языке, включая реальные области цены, выхода, очереди и топлива.
static func check(game: Node, checks: Array[Dictionary], locale: String, counts: Dictionary) -> void:
	var Audit=game.UiLayoutAuditSystem; var contracts:Array=[]
	contracts.append(["workshop_help",game.LocaleSystem.ui("workshop_help"),820.0,12,8])
	for station in Workshop.Data.STATIONS:
		contracts.append([station+"_title",game.LocaleSystem.ui(station+"_title",[3]),652.0,28,14])
		contracts.append([station+"_category",game.LocaleSystem.ui(station+"_service"),226.0,12,8])
		contracts.append([station+"_context",game.LocaleSystem.ui(station+"_context"),244.0,11,8])
		for index in Workshop.Data.STATIONS[station].upgrades.size():
			var cost:Dictionary=Workshop.Data.STATIONS[station].upgrades[index]
			var text:String=game.LocaleSystem.ui("furnace_upgrade_cost",[cost.coins,game.ResearchSystem.material_text(game,cost.inputs)])
			Audit._record_multiline_contract(checks,game,"crafting",locale,[station+"_upgrade_%d"%index,text,450.0,28.0,10,8]); counts.crafting=int(counts.crafting)+1
		var choices:Array=Workshop.Data.Recipes.RECIPES.filter(func(recipe): return recipe.get("station","")==station)
		var names:Array[String]=[]
		for recipe in choices.slice(maxi(0,choices.size()-3)): names.append(game.inventory_item_name(recipe.output)+" ×99")
		Audit._record_multiline_contract(checks,game,"crafting",locale,[station+"_queue",game.LocaleSystem.ui("furnace_queue_names",[" → ".join(names)]),450.0,28.0,10,8]); counts.crafting=int(counts.crafting)+1
	for recipe in Workshop.Data.Recipes.RECIPES:
		if not Workshop.handles(String(recipe.get("station",""))): continue
		var text:String=game.LocaleSystem.ui("workshop_summary",[recipe.count,recipe.seconds,recipe.energy])
		if not recipe.get("byproducts",{}).is_empty(): text+="\n"+game.ResearchSystem.material_text(game,recipe.byproducts)
		Audit._record_multiline_contract(checks,game,"crafting",locale,[recipe.id+"_real_summary",text,210.0,32.0,11,8]); counts.crafting=int(counts.crafting)+1
	for contract in contracts: Audit._record_text_contract(checks,game,"crafting",locale,contract); counts.crafting=int(counts.crafting)+1
	var shell:Rect2=game.ItemWindowRenderer.CRAFT_SECTION; var queue:=Rect2(220,474,450,28); var price:=Rect2(220,509,450,28)
	Audit._record(checks,"workshop.footer.inside",shell.encloses(queue) and shell.encloses(price),"Производственная очередь или цена выходит за панель")
	Audit._record(checks,"workshop.footer.separate",not queue.intersects(price),"Очередь перекрывает цену улучшения")
	Audit._record(checks,"workshop.rows.clear",game.ItemWindowRenderer.craft_row_rect(6).end.y<=queue.position.y,"Нижний рецепт перекрывает производственную очередь")
