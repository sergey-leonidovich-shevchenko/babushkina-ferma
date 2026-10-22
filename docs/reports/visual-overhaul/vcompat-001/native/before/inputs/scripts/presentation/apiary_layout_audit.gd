extends RefCounted

const Apiary := preload("res://scripts/systems/apiary_system.gd")
const Locale := preload("res://scripts/systems/apiary_locale.gd")
const Render := preload("res://scripts/presentation/apiary_renderer.gd")

## Проверяет реальные подписи, стоимость, прогноз и кнопки пасеки на каждом языке при 120% шрифта.
static func check(game: Node, checks: Array[Dictionary], locale: String, counts: Dictionary) -> void:
	var Audit=game.UiLayoutAuditSystem
	var texts:Array=[["apiary_title",game.LocaleSystem.ui("apiary_title",[3]),652.0,28,14],["apiary_help",game.LocaleSystem.ui("apiary_help"),820.0,12,8],["apiary_settle",game.LocaleSystem.ui("apiary_settle"),280.0,13,8],["apiary_harvest",game.LocaleSystem.ui("apiary_harvest"),280.0,13,8]]
	for pair in texts: Audit._record_text_contract(checks,game,"crafting",locale,pair); counts.crafting=int(counts.crafting)+1
	for level in range(3):
		Audit._record_multiline_contract(checks,game,"crafting",locale,["apiary_cost_%d"%level,Render.cost_text(game,level),300.0,52.0,11,8]); counts.crafting=int(counts.crafting)+1
	var extras:String=" · "+game.inventory_item_name("pollen")+" ×1 · "+game.inventory_item_name("propolis")+" ×1"
	Audit._record_multiline_contract(checks,game,"crafting",locale,["apiary_yield",game.LocaleSystem.ui("apiary_yield",[3,extras,18,4]),340.0,86.0,12,8]); counts.crafting=int(counts.crafting)+1
	for kind in Apiary.Data.RAW:
		Audit._record_multiline_contract(checks,game,"crafting",locale,[kind+"_source",Locale.source_text(game,kind),210.0,34.0,11,8]); counts.crafting=int(counts.crafting)+1
	Audit._record(checks,"apiary.buttons.separate",not Render.PRIMARY.intersects(Render.UPGRADE) and not Render.PRIMARY.intersects(Render.DISMANTLE) and not Render.UPGRADE.intersects(Render.DISMANTLE),"Кнопки улья пересекаются")
