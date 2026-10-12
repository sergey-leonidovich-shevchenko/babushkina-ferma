extends RefCounted

const Apiary := preload("res://scripts/systems/apiary_system.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const PRIMARY := Rect2(220,430,300,44)
const UPGRADE := Rect2(548,430,300,44)
const DISMANTLE := Rect2(370,504,320,40)

## Показывает точную цену следующей ступени без скрытых компонентов или доплаты после действия.
static func cost_text(game: Node, level: int) -> String:
	if level>=3: return game.LocaleSystem.ui("furnace_max")
	var cost:Dictionary=Apiary.Data.COSTS[level]
	return game.LocaleSystem.ui("apiary_cost",[game.ResearchSystem.material_text(game,cost.inputs),cost.coins,cost.energy])

## Выбирает одно понятное основное действие: строительство, заселение либо сбор готового запаса.
static func primary_text(game: Node, item: Dictionary) -> String:
	if item.level==0: return game.LocaleSystem.ui("basement_build_tab")
	if not item.colonized: return game.LocaleSystem.ui("apiary_settle")
	return game.LocaleSystem.ui("apiary_harvest")

## Рисует окно конкретного улья с настоящим запасом, прогнозом и полной ценой улучшения.
static func draw(game: Node2D) -> void:
	var item:=Apiary.selected(game)
	if item.is_empty(): return
	game.ItemWindowRenderer.draw_shell(game,game.LocaleSystem.ui("apiary_title",[int(game.get_meta("apiary_ui").selected)+1]))
	game.ItemWindowRenderer.draw_section(game,Rect2(200,152,744,400))
	preload("res://scripts/presentation/apiary_visual_system.gd").draw_preview(game,int(item.level),Rect2(255,178,220,148))
	game.draw_ui_string(game.UI_FONT,Vector2(220,344),game.LocaleSystem.ui("apiary_population",[game.LocaleSystem.ui("apiary_present" if item.colonized else "apiary_absent"),item.level]),HORIZONTAL_ALIGNMENT_CENTER,300,12,Kit.COLORS.ink)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,367),cost_text(game,int(item.level)),HORIZONTAL_ALIGNMENT_CENTER,300,52,11,4,Kit.COLORS.ink)
	var extras:=""
	if int(item.level)>=2: extras+=" · "+game.inventory_item_name("pollen")+" ×1"
	if int(item.level)>=3: extras+=" · "+game.inventory_item_name("propolis")+" ×1"
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(548,190),game.LocaleSystem.ui("apiary_yield",[item.level,extras,int(item.level)*6,int(item.level)+1]),HORIZONTAL_ALIGNMENT_LEFT,340,86,12,5,Kit.COLORS.ink)
	for index in 4:
		var kind:String=["honeycomb","bees","pollen","propolis"][index]; var point:=Vector2(548,294+index*29)
		game.draw_item_icon(kind,Rect2(point,Vector2(24,24)))
		game.draw_ui_string(game.UI_FONT,point+Vector2(34,18),game.inventory_item_name(kind)+" ×"+str(item.stock.get(kind,0)),HORIZONTAL_ALIGNMENT_LEFT,298,12,Kit.COLORS.ink)
	for button in [[PRIMARY,primary_text(game,item),true],[UPGRADE,game.LocaleSystem.ui("basement_upgrade_tab"),item.level<3],[DISMANTLE,game.LocaleSystem.ui("basement_dismantle_tab"),item.level>0]]:
		Kit.draw_nine_patch(game,"editor_button_normal",button[0]); game.draw_ui_string(game.UI_FONT,button[0].position+Vector2(10,28),button[1],HORIZONTAL_ALIGNMENT_CENTER,button[0].size.x-20,13,Kit.COLORS.ink if button[2] else Color("967f5f"))
	game.draw_ui_string(game.UI_FONT,Vector2(220,494),game.message,HORIZONTAL_ALIGNMENT_CENTER,644,11,Kit.COLORS.ink)
	game.ItemWindowRenderer.draw_help(game,game.LocaleSystem.ui("apiary_help"))
