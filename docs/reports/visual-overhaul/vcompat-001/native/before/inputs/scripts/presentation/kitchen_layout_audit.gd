extends RefCounted

const Data := preload("res://scripts/systems/kitchen_data.gd")

## Проверяет кухонные группы, очередь и длительность на реальных размерах панелей на каждом языке.
static func check(game: Node, checks: Array[Dictionary], locale: String, counts: Dictionary) -> void:
	var Audit=game.UiLayoutAuditSystem; var contracts:Array=[]
	for level in range(1,4): contracts.append(["kitchen_stage%d"%level,game.LocaleSystem.ui("kitchen_stage%d"%level),142.0,11,8])
	for group in ["all","hot","cold"]: contracts.append(["kitchen_filter_"+group,"‹  "+game.LocaleSystem.ui("kitchen_filter_"+group)+"  ›",200.0,11,8])
	contracts.append(["kitchen_help",game.LocaleSystem.ui("kitchen_help"),820.0,12,8])
	for contract in contracts: Audit._record_text_contract(checks,game,"crafting",locale,contract); counts.crafting=int(counts.crafting)+1
	for recipe in Data.LEGACY_RECIPES+Data.NEW_RECIPES:
		var text:String=game.LocaleSystem.ui("kitchen_summary",[recipe.count,Data.seconds(recipe),Data.energy(recipe),game.LocaleSystem.ui("kitchen_cold" if recipe.output in Data.COLD else "kitchen_hot")])
		Audit._record_multiline_contract(checks,game,"crafting",locale,[recipe.id+"_kitchen",text,210.0,32.0,11,8]); counts.crafting=int(counts.crafting)+1
	var names:Array[String]=[]
	for recipe in Data.NEW_RECIPES.slice(1): names.append(game.inventory_item_name(recipe.output)+" ×2")
	Audit._record_multiline_contract(checks,game,"crafting",locale,["kitchen_queue",game.LocaleSystem.ui("furnace_queue_names",[" → ".join(names)]),450.0,28.0,10,8]); counts.crafting=int(counts.crafting)+1
	for label in [game.LocaleSystem.ui("kitchen_waiting"),game.LocaleSystem.ui("kitchen_remaining",[99.9])]:
		Audit._record_multiline_contract(checks,game,"crafting",locale,["kitchen_status",game.LocaleSystem.ui("kitchen_status",[360,360,3,3])+"\n"+label,450.0,28.0,10,8]); counts.crafting=int(counts.crafting)+1
	Audit._record(checks,"kitchen.rows.clear",game.ItemWindowRenderer.craft_row_rect(6).end.y<=474,"Рецепт перекрывает очередь кухни")
