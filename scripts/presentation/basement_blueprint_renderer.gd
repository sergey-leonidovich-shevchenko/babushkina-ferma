extends RefCounted

const Basement := preload("res://scripts/systems/basement_system.gd")
const Controls := preload("res://scripts/systems/basement_input_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")
const Locale := preload("res://scripts/systems/basement_locale.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const Art := preload("res://scripts/presentation/basement_visual_system.gd")

## Рисует общий чертёж с тремя явными действиями и каталогом видов либо независимых экземпляров.
static func draw(game: Node2D) -> void:
	var value:=Basement.ui(game)
	if not bool(value.open): return
	game.ItemWindowRenderer.draw_shell(game,game.LocaleSystem.ui("basement_title"))
	var keys:=["basement_build_tab","basement_upgrade_tab","basement_dismantle_tab"]
	for index in 3:
		button(game,Controls.TABS[index],game.LocaleSystem.ui(keys[index]),int(value.tab)==index)
	var entries:=Controls.choices(game); var first:=Controls.first(game)
	for index in 2: button(game,Controls.PAGES[index],"↑" if index==0 else "↓",false)
	game.draw_ui_string(game.UI_FONT,Vector2(772,140),"%d–%d / %d"%[mini(first+1,entries.size()),mini(first+8,entries.size()),entries.size()],HORIZONTAL_ALIGNMENT_CENTER,140,11,Kit.COLORS.ink)
	game.ItemWindowRenderer.draw_section(game,Rect2(200,152,480,366))
	for index in range(first,mini(first+8,entries.size())):
		var item:Dictionary={"kind":entries[index],"level":1} if int(value.tab)==0 else entries[index]
		var rect:=Rect2(210,160+(index-first)*43,470,38)
		game.ItemWindowRenderer.draw_item_row(game,rect,Basement.Data.STATIONS[item.kind].icon,index==int(value.selected),true)
		game.draw_item_icon(Basement.Data.STATIONS[item.kind].icon,Rect2(rect.position+Vector2(12,5),Vector2(28,28)))
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(52,25),Locale.name_for(game,item.kind),HORIZONTAL_ALIGNMENT_LEFT,285,13,Kit.COLORS.ink)
		var label:="#%d · %d"%[item.id,item.level] if int(value.tab)>0 else "1"
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(345,24),label,HORIZONTAL_ALIGNMENT_RIGHT,108,12,Kit.COLORS.ink)
	var item:=Controls.selected(game)
	if item.is_empty():
		game.draw_ui_multiline_string(game.UI_FONT,Vector2(260,244),game.LocaleSystem.ui("basement_empty"),HORIZONTAL_ALIGNMENT_CENTER,360,80,18,3,Kit.COLORS.ink)
	else: detail(game,item)
	game.ItemWindowRenderer.draw_help(game,game.LocaleSystem.ui("basement_help"))

## Показывает точные компоненты, энергию, длительность и возврат перед выполнением действия.
static func detail(game: Node2D, item: Dictionary) -> void:
	var tab:=int(Basement.ui(game).tab)
	game.ItemWindowRenderer.draw_table_header(game,Rect2(698,152,244,42))
	game.draw_ui_string(game.UI_FONT,Vector2(708,179),game.LocaleSystem.ui(["basement_build_tab","basement_upgrade_tab","basement_dismantle_tab"][tab]),HORIZONTAL_ALIGNMENT_CENTER,224,13,Color("fff0cf"))
	var texture:=Art.texture(item.kind,int(item.level),int(item.get("direction",0)))
	var size:=texture.get_size()*minf(112.0/texture.get_width(),84.0/texture.get_height())
	game.draw_texture_rect(texture,Rect2(Vector2(822,254)-size/2,size),false)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(714,311),Locale.name_for(game,item.kind),HORIZONTAL_ALIGNMENT_CENTER,216,44,17,2,Kit.COLORS.ink)
	var cost:Dictionary={"inputs":item.inputs} if tab==0 else (Basement.Data.upgrade_cost(item.kind,item.level) if tab==1 else {"inputs":Build.salvage(item)})
	var active:bool=tab!=1 or (item.phase=="ready" and int(item.level)<3)
	var heading:String=game.LocaleSystem.ui("basement_new_level") if tab==0 else (game.LocaleSystem.ui("basement_return") if tab==2 else game.LocaleSystem.ui("basement_level",[Locale.name_for(game,item.kind),mini(3,int(item.level)+1)]))
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(714,363),heading,HORIZONTAL_ALIGNMENT_CENTER,216,38,11,3,Kit.COLORS.ink)
	if not cost.is_empty():
		var text:String=game.ResearchSystem.material_text(game,cost.inputs,tab!=2)
		if int(cost.get("coins",0))>0: text=game.LocaleSystem.ui("study_need_money",[cost.coins])+"\n"+text
		game.draw_ui_multiline_string(game.UI_FONT,Vector2(714,402),text,HORIZONTAL_ALIGNMENT_CENTER,216,80,11,6,Kit.COLORS.ink)
	var seconds:float=Basement.Data.WORK_SECONDS[0 if tab==0 else mini(2,int(item.level))]; var energy:int=mini(3,int(Basement.Data.STATIONS[item.kind].energy)+(0 if tab==0 else int(item.level)))
	if tab!=2: game.draw_ui_string(game.UI_FONT,Vector2(220,536),game.LocaleSystem.ui("basement_work",[seconds,energy]),HORIZONTAL_ALIGNMENT_LEFT,450,11,Kit.COLORS.ink)
	if tab==0: game.draw_ui_string(game.UI_FONT,Vector2(220,554),game.LocaleSystem.ui("basement_paid"),HORIZONTAL_ALIGNMENT_LEFT,450,10,Kit.COLORS.ink)
	var action:String=game.LocaleSystem.ui("basement_choose") if tab==0 else game.LocaleSystem.ui("basement_upgrade_tab" if tab==1 else "basement_dismantle_tab")
	button(game,Controls.ACTION,action,active)

## Рисует единообразную кнопку с текстом внутри измеренной области без дополнительной обработки SVG на кадре.
static func button(game: Node2D, rect: Rect2, label: String, selected: bool) -> void:
	Kit.draw_nine_patch(game,"editor_button_selected" if selected else "editor_button_normal",rect)
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(8,rect.size.y*0.7),label,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-16,12,Kit.COLORS.ink)
