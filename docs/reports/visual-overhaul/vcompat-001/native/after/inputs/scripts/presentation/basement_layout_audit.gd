extends RefCounted

const Data := preload("res://scripts/systems/basement_data.gd")
const Locale := preload("res://scripts/systems/basement_locale.gd")
const Controls := preload("res://scripts/systems/basement_input_system.gd")

## Измеряет реальные подписи, подробности и кнопки чертежа на каждом языке при общем увеличенном масштабе текста.
static func check(game: Node, checks: Array[Dictionary], locale: String, counts: Dictionary) -> void:
	var Audit=game.UiLayoutAuditSystem
	var contracts:Array=[["title",game.LocaleSystem.ui("basement_title"),652.0,28,14],["help",game.LocaleSystem.ui("basement_help"),820.0,12,8],["place_help",game.LocaleSystem.ui("basement_place_help"),872.0,11,8],["choose",game.LocaleSystem.ui("basement_choose"),200.0,12,8],["work",game.LocaleSystem.ui("basement_work",[9.0,3]),450.0,11,8]]
	for key in ["basement_build_tab","basement_upgrade_tab","basement_dismantle_tab"]: contracts.append([key,game.LocaleSystem.ui(key),134.0,12,8])
	for key in ["basement_place_button","basement_cancel_button"]: contracts.append([key,game.LocaleSystem.ui(key),168.0,12,8])
	for kind in Data.STATIONS:
		contracts.append([kind+"_row",Locale.name_for(game,kind),285.0,13,8])
		Audit._record_multiline_contract(checks,game,"crafting",locale,[kind+"_detail",Locale.name_for(game,kind),216.0,44.0,17,9]); counts.crafting=int(counts.crafting)+1
		var prices:Array=[{"inputs":Data.STATIONS[kind].inputs},Data.upgrade_cost(kind,1),Data.upgrade_cost(kind,2)]
		for index in prices.size():
			var cost:Dictionary=prices[index]; var text:String=game.ResearchSystem.material_text(game,cost.inputs,true)
			if int(cost.get("coins",0))>0: text=game.LocaleSystem.ui("study_need_money",[cost.coins])+"\n"+text
			Audit._record_multiline_contract(checks,game,"crafting",locale,[kind+"_cost_"+str(index),text,216.0,80.0,11,8]); counts.crafting=int(counts.crafting)+1
	for contract in contracts: Audit._record_text_contract(checks,game,"crafting",locale,contract); counts.crafting=int(counts.crafting)+1
	Audit._record_multiline_contract(checks,game,"crafting",locale,["basement_hold",game.LocaleSystem.ui("basement_hold_button"),184.0,30.0,11,8]); counts.crafting=int(counts.crafting)+1
	Audit._record(checks,"basement.rows.inside",Rect2(200,152,480,366).encloses(Rect2(210,461,470,38)),"Последняя строительная строка выходит за пергамент")
	Audit._record(checks,"basement.action.separate",Controls.ACTION.position.y>=482,"Кнопка перекрывает стоимость")
