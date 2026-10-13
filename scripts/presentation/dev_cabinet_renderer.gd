extends RefCounted

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Locale := preload("res://scripts/systems/dev_cabinet_locale.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const COLUMNS := 10
const VISIBLE := 50
const SEARCH := Rect2(40,142,648,36)
const REFILL := Rect2(934,142,178,36)
const CLOSE := Rect2(1070,26,42,38)
const PREVIOUS := Rect2(700,142,44,36)
const NEXT := Rect2(880,142,44,36)
const AMOUNTS := [1,10,100,999]
const DETAIL_TITLE := Rect2(836,210,256,42)

## Даёт одинаковую геометрию восьми вкладок для рисунка, мыши и касания.
static func tab_rect(index: int) -> Rect2:
	return Rect2(40+index*134,96,128,34)

## Даёт область одной из пятидесяти компактных ячеек текущей страницы.
static func slot_rect(index: int) -> Rect2:
	return Rect2(52+(index%COLUMNS)*74,206+(index/COLUMNS)*72,68,66)

## Центрирует увеличенную иконку, оставляя снизу отдельное место под количество.
static func icon_rect(index: int) -> Rect2:
	return Rect2(slot_rect(index).position+Vector2(12,4),Vector2(44,44))

## Отделяет реальный остаток от иконки без подписи названия внутри сетки.
static func count_rect(index: int) -> Rect2:
	return Rect2(slot_rect(index).position+Vector2(4,50),Vector2(60,13))

## Даёт общие кнопки выдачи единицы, десяти, ста или полного стека.
static func take_rect(index: int) -> Rect2:
	return Rect2(836+(index%2)*132,486+(index/2)*40,124,32)

## Определяет страницу по выделению, не оставляя выбранный предмет за пределами экрана.
static func start(game: Node) -> int:
	return (int(Cabinet.state(game).selected)/VISIBLE)*VISIBLE

## Рисует полноэкранный склад разработки в уже используемой лунной теме.
static func draw(game: Node2D) -> void:
	if not Cabinet.active(game): return
	var value:=Cabinet.state(game); var choices:=Cabinet.items(game); var kind:=Cabinet.selected(game)
	game.draw_rect(Rect2(0,0,1152,648),Style.BACKGROUND)
	Style.title(game,Rect2(40,22,730,36),Locale.text(game,"title"),27)
	Style.text(game,Rect2(40,62,990,22),Locale.text(game,"subtitle"),12,Style.MUTED)
	Style.button(game,CLOSE,"×")
	for index in Cabinet.TABS.size(): Style.button(game,tab_rect(index),Locale.text(game,Cabinet.TABS[index]),int(value.tab)==index)
	Style.panel(game,SEARCH,Style.INSET,Style.ACCENT if value.searching else Style.EDGE)
	Style.text(game,SEARCH.grow(-8),String(value.query)+( "▏" if value.searching else "") if not String(value.query).is_empty() or value.searching else Locale.text(game,"search"),13,Style.TEXT if not String(value.query).is_empty() else Style.MUTED)
	Style.text(game,Rect2(750,142,124,36),Locale.text(game,"found",[choices.size()]),13,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Style.button(game,REFILL,Locale.text(game,"refill"))
	Style.panel(game,Rect2(40,194,756,380)); Style.panel(game,Rect2(816,194,296,380),Style.INSET)
	var first:=start(game)
	for visible in VISIBLE:
		var index:=first+visible
		if index>=choices.size(): break
		draw_slot(game,String(choices[index]),visible,index==int(value.selected))
	if choices.is_empty(): Style.text(game,Rect2(60,340,712,50),Locale.text(game,"empty"),17,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	if not kind.is_empty(): draw_detail(game,kind)
	Style.button(game,PREVIOUS,"‹",false,first>0); Style.button(game,NEXT,"›",false,first+VISIBLE<choices.size())
	var notice:String=String(value.notice)
	preload("res://scripts/presentation/storage_actions_renderer.gd").draw(game,true)
	Style.text(game,Rect2(40,617,1072,12),"%d / %d"%[first/VISIBLE+1,maxi(1,ceili(choices.size()/float(VISIBLE)))]+(" • "+notice if not notice.is_empty() else ""),10,Style.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	Style.text(game,Rect2(40,632,1072,12),Locale.text(game,"help"),9,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

## Показывает только увеличенную иконку и реальный остаток; название находится в правой карточке.
static func draw_slot(game: Node2D, kind: String, visible: int, selected: bool) -> void:
	var rect:=slot_rect(visible); Style.slot(game,rect,selected)
	game.draw_item_icon(kind,icon_rect(visible))
	Style.text(game,count_rect(visible),"×"+str(Cabinet.state(game).stock[kind]),11,Style.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)

## Показывает полное имя и назначение выбранного предмета перед явной выдачей в рюкзак.
static func draw_detail(game: Node2D, kind: String) -> void:
	var name:String=game.inventory_item_name(kind)
	var size:int=game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,name,DETAIL_TITLE.size.x,DETAIL_TITLE.size.y,18)
	game.draw_ui_multiline_string(game.UI_FONT,DETAIL_TITLE.position+Vector2(0,game.UI_FONT.get_ascent(size)),name,HORIZONTAL_ALIGNMENT_CENTER,DETAIL_TITLE.size.x,DETAIL_TITLE.size.y,18,-1,Style.TEXT)
	Style.text(game,Rect2(836,256,256,18),kind,10,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	game.draw_item_icon(kind,Rect2(906,280,116,102))
	Style.text(game,Rect2(836,386,256,24),Locale.text(game,"stock",[Cabinet.state(game).stock[kind]]),14,Style.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	Style.text(game,Rect2(836,412,256,24),Locale.text(game,"bag",[game.inventory_item_count(kind)]),12,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var effect:String=Locale.text(game,"unique") if kind in Cabinet.UNIQUE else preload("res://scripts/systems/item_presentation_system.gd").effect_text(game,kind)
	if effect.is_empty(): effect=Locale.text(game,Cabinet.category(game,kind))
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(836,452),effect,HORIZONTAL_ALIGNMENT_CENTER,256,28,11,2,Style.MUTED)
	for index in AMOUNTS.size(): Style.button(game,take_rect(index),Locale.text(game,"take",[AMOUNTS[index]]),false,Cabinet.amount(game,kind,AMOUNTS[index])>0 and (kind not in Cabinet.UNIQUE or index==0))
