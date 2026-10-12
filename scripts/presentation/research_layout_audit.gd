extends RefCounted

const Research := preload("res://scripts/systems/research_system.gd")

## Проверяет фактические размеры текстовых областей новых окон на каждом языке и крупном шрифте.
static func check(game: Node, checks: Array[Dictionary], locale: String, counts: Dictionary) -> void:
	var Audit=game.UiLayoutAuditSystem
	var contracts:Array=[]
	for level in range(1,4): contracts.append(["study_title_%d"%level,game.LocaleSystem.ui("study_title",[level]),652.0,28,14])
	for key in ["study_help","recycling_help"]: contracts.append([key,game.LocaleSystem.ui(key),820.0,12,8])
	contracts.append(["recycling_title",game.LocaleSystem.ui("recycling_title"),652.0,28,14])
	contracts.append(["study_upgrade",game.LocaleSystem.ui("study_upgrade"),228.0,11,8])
	contracts.append(["study_action",game.LocaleSystem.ui("study_action"),182.0,14,10])
	contracts.append(["study_progress",game.LocaleSystem.ui("study_progress",[30,30]),450.0,12,8])
	contracts.append(["sample",game.LocaleSystem.ui("study_sample_kept"),210.0,11,8])
	for tier in range(1,4):
		var cost:Dictionary=Research.Data.COSTS[tier-1]
		var text:String=game.LocaleSystem.ui("study_money_energy",[cost.coins,cost.energy])+"\n"+Research.material_text(game,cost.inputs,true)
		Audit._record_multiline_contract(checks,game,"crafting",locale,["study_price_%d"%tier,text,210.0,48.0,11,8]); counts.crafting=int(counts.crafting)+1
	for index in Research.Data.UPGRADES.size():
		var cost:Dictionary=Research.Data.UPGRADES[index]
		var text:String=game.LocaleSystem.ui("furnace_upgrade_cost",[cost.coins,Research.material_text(game,cost.inputs)])
		Audit._record_multiline_contract(checks,game,"crafting",locale,["study_upgrade_price_%d"%index,text,450.0,32.0,10,8]); counts.crafting=int(counts.crafting)+1
	for entry in Research.Data.ENTRIES:
		contracts.append(["study_batch_"+entry.kind,game.LocaleSystem.ui("study_results",[entry.batch]),226.0,12,8])
		contracts.append(["study_name_"+entry.kind,game.inventory_item_name(entry.kind),220.0,12,8])
		for key in ["study_known","study_unknown"]: contracts.append([entry.kind+"_"+key,game.LocaleSystem.ui("study_row",[entry.tier,game.LocaleSystem.ui(key)]),178.0,10,7])
		contracts.append(["recycling_action_"+entry.kind,game.LocaleSystem.ui("recycling_action",[entry.batch]),182.0,14,10])
		var text:String=game.LocaleSystem.ui("study_need_energy",[int(entry.tier)*2])+"\n"+Research.material_text(game,Research.parts(game,entry))
		Audit._record_multiline_contract(checks,game,"crafting",locale,["recycling_payload_"+entry.kind,text,210.0,48.0,11,8]); counts.crafting=int(counts.crafting)+1
	for key in ["study_known","study_unknown","study_hidden","study_sample_need","study_unequip","study_station_need"]:
		Audit._record_multiline_contract(checks,game,"crafting",locale,[key,game.LocaleSystem.ui(key),210.0,36.0,11,8]); counts.crafting=int(counts.crafting)+1
	for contract in contracts: Audit._record_text_contract(checks,game,"crafting",locale,contract); counts.crafting=int(counts.crafting)+1
