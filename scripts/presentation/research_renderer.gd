extends RefCounted

const Research := preload("res://scripts/systems/research_system.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const UPGRADE := Rect2(698,120,244,28)

## Выбирает первую из восьми строк, оставляя отдельное место полной цене улучшения.
static func first_index(game: Node) -> int:
	return clampi(game.crafting_selected-3,0,maxi(0,Research.Data.ENTRIES.size()-8))

## Возвращает понятную метку уровня и постоянного статуса знания.
static func row_text(game: Node, entry: Dictionary) -> String:
	return game.LocaleSystem.ui("study_row",[entry.tier,game.LocaleSystem.ui("study_known" if Research.learned(game,entry.kind) else "study_unknown")])

## Показывает точный расход до изучения, затем раскрывает реальный состав без требования нового образца.
static func payload(game: Node, entry: Dictionary) -> String:
	if game.crafting_station=="study" and not Research.learned(game,entry.kind):
		var cost:Dictionary=Research.Data.COSTS[int(entry.tier)-1]
		return game.LocaleSystem.ui("study_money_energy",[cost.coins,cost.energy])+"\n"+Research.material_text(game,cost.inputs,true)
	if not Research.learned(game,entry.kind): return game.LocaleSystem.ui("study_hidden")
	var text:=Research.material_text(game,Research.parts(game,entry))
	if game.crafting_station=="recycling": text=game.LocaleSystem.ui("study_need_energy",[int(entry.tier)*2])+"\n"+text
	return text

## Рисует каталог исследования или разборки в действующем каркасе с отдельными действиями.
static func draw(game: Node) -> void:
	var Shell=game.ItemWindowRenderer
	var study:bool=game.crafting_station=="study"; var value:=Research.state(game)
	Shell.draw_shell(game,game.LocaleSystem.ui("study_title",[Research.level(game)]) if study else game.LocaleSystem.ui("recycling_title"))
	Shell.draw_section(game,Shell.CRAFT_SECTION)
	game.draw_ui_string(game.UI_FONT,Vector2(220,140),game.LocaleSystem.ui("study_progress",[value.known.size(),Research.Data.ENTRIES.size()]),HORIZONTAL_ALIGNMENT_LEFT,450,12,Kit.COLORS.ink)
	if study:
		Kit.draw_nine_patch(game,"editor_button_normal",UPGRADE)
		game.draw_ui_string(game.UI_FONT,UPGRADE.position+Vector2(8,20),game.LocaleSystem.ui("study_upgrade"),HORIZONTAL_ALIGNMENT_CENTER,UPGRADE.size.x-16,11,Kit.COLORS.ink)
	var first:=first_index(game)
	for index in range(first,mini(first+8,Research.Data.ENTRIES.size())):
		var entry:Dictionary=Research.Data.ENTRIES[index]; var row:Rect2=Shell.craft_row_rect(index-first)
		var enabled:=Research.reason(game,entry,game.crafting_station).is_empty()
		Shell.draw_item_row(game,row,entry.kind,index==game.crafting_selected,enabled)
		game.draw_item_icon(entry.kind,Rect2(row.position+Vector2(14,5),Vector2(28,28)))
		game.draw_ui_string(game.UI_FONT,row.position+Vector2(52,25),game.inventory_item_name(entry.kind),HORIZONTAL_ALIGNMENT_LEFT,220,12,Kit.COLORS.ink)
		game.draw_ui_string(game.UI_FONT,row.position+Vector2(282,24),row_text(game,entry),HORIZONTAL_ALIGNMENT_LEFT,178,10,Color("456537") if Research.learned(game,entry.kind) else Kit.COLORS.danger)
	var entry:Dictionary=Research.Data.ENTRIES[clampi(game.crafting_selected,0,Research.Data.ENTRIES.size()-1)]
	var known:=Research.learned(game,entry.kind); var why:=Research.reason(game,entry,game.crafting_station); var detail:Rect2=Shell.CRAFT_DETAIL
	Shell.draw_table_header(game,Rect2(detail.position,Vector2(detail.size.x,42)))
	var header:String=game.LocaleSystem.ui("study_unknown") if study and not known else game.LocaleSystem.ui("study_results",[entry.batch])
	game.draw_ui_string(game.UI_FONT,detail.position+Vector2(10,27),header,HORIZONTAL_ALIGNMENT_CENTER,226,12,Color("fff0cf"))
	game.draw_item_icon(entry.kind,Rect2(detail.position+Vector2(83,58),Vector2(80,80)))
	game.draw_ui_multiline_string(game.UI_FONT,detail.position+Vector2(10,159),game.inventory_item_name(entry.kind),HORIZONTAL_ALIGNMENT_CENTER,226,40,17,2,Kit.COLORS.ink)
	var sample:String=game.LocaleSystem.ui("study_sample_kept") if study else "%d / %d"%[game.inventory_item_count(entry.kind),entry.batch]
	game.draw_ui_string(game.UI_FONT,Vector2(714,372),sample,HORIZONTAL_ALIGNMENT_CENTER,210,11,Color("456537"))
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(714,397),why,HORIZONTAL_ALIGNMENT_CENTER,210,36,11,3,Color("456537") if known and study else Kit.COLORS.danger)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(714,447),payload(game,entry),HORIZONTAL_ALIGNMENT_CENTER,210,48,11,4,Kit.COLORS.ink)
	Kit.draw_nine_patch(game,"editor_button_selected" if why.is_empty() else "editor_button_normal",Shell.CRAFT_ACTION)
	var action:String=game.LocaleSystem.ui("study_action") if study else game.LocaleSystem.ui("recycling_action",[entry.batch])
	game.draw_ui_string(game.UI_FONT,Shell.CRAFT_ACTION.position+Vector2(14,26),action,HORIZONTAL_ALIGNMENT_CENTER,182,14,Kit.COLORS.ink if why.is_empty() else Color("846d50"))
	var footer:String=Research.upgrade_text(game) if study else game.LocaleSystem.ui("study_no_bonus")
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,527),footer,HORIZONTAL_ALIGNMENT_LEFT,450,32,10,2,Kit.COLORS.ink)
	Shell.draw_help(game,game.LocaleSystem.ui("study_help" if study else "recycling_help"))

## Разделяет выбор строки, изучение и улучшение, чтобы нажатие имени не уничтожало вещь.
static func handle_pointer(game: Node, position: Vector2) -> bool:
	var Shell=game.ItemWindowRenderer
	if game.crafting_station=="study" and UPGRADE.has_point(position): Research.upgrade(game)
	elif Shell.CRAFT_ACTION.has_point(position): Research.execute(game,game.crafting_selected)
	else:
		var first:=first_index(game)
		for row in 8:
			if Shell.craft_row_rect(row).has_point(position) and first+row<Research.Data.ENTRIES.size(): game.crafting_selected=first+row; break
	game.queue_redraw(); return true
