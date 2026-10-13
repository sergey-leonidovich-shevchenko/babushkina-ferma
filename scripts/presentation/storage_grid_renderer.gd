extends RefCounted

const Grid := preload("res://scripts/systems/storage_grid_system.gd")
const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Locale := preload("res://scripts/systems/dev_cabinet_locale.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const AMOUNTS := [1,10,100,-1]

## Рисует обе сетки и общую центральную карточку в уже принятой лунной теме.
static func draw(game: Node2D, cabinet: bool) -> void:
	var value:=Grid.state(game,cabinet)
	game.draw_rect(Rect2(0,0,1152,648),Style.BACKGROUND)
	Style.title(game,Rect2(32,22,850,36),Locale.text(game,"title") if cabinet else game.LocaleSystem.ui("home_storage"),27)
	Style.text(game,Rect2(32,62,1000,22),Locale.text(game,"subtitle") if cabinet else Locale.text(game,"storage_subtitle"),12,Style.MUTED)
	Style.button(game,Layout.CLOSE,"×")
	if cabinet: draw_catalog_controls(game)
	for side in 2:
		Style.panel(game,Layout.PANELS[side],Style.PANEL,Style.ACCENT if int(value.side)==side else Style.EDGE)
		var label:String=game.LocaleSystem.ui("backpack_column") if side==0 else (Locale.text(game,"title") if cabinet else game.LocaleSystem.ui("chest_column"))
		if side==1: label+=" · "+str(Grid.items(game,cabinet,side).size())
		Style.text(game,Rect2(Layout.grid(side).position+Vector2(0,-34),Vector2(Layout.grid(side).size.x-4,22)),label,14,Style.TEXT)
		draw_grid(game,cabinet,side)
	Style.panel(game,Layout.DETAIL,Style.INSET)
	var kind:=Grid.selected(game,cabinet)
	if not kind.is_empty(): draw_detail(game,cabinet,kind)
	else: Style.text(game,Layout.TITLE,empty_text(game,cabinet,int(value.side)),13,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	preload("res://scripts/presentation/storage_actions_renderer.gd").draw(game,cabinet)
	var notice:String=String(Cabinet.state(game).notice) if cabinet else String(game.message)
	Style.text(game,Rect2(32,618,1088,13),notice,10,Style.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	Style.text(game,Rect2(32,632,1088,12),Locale.text(game,"grid_help"),9,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

## Сохраняет восемь категорий и поиск только для содержимого шкафа; рюкзак всегда виден целиком.
static func draw_catalog_controls(game: Node2D) -> void:
	var value:=Cabinet.state(game)
	for index in Cabinet.TABS.size(): Style.button(game,Rect2(40+index*134,96,128,34),Locale.text(game,Cabinet.TABS[index]),int(value.tab)==index)
	Style.panel(game,Layout.SEARCH,Style.INSET,Style.ACCENT if value.searching else Style.EDGE)
	var text:String=String(value.query)+( "▏" if value.searching else "") if not String(value.query).is_empty() or value.searching else Locale.text(game,"search")
	Style.text(game,Layout.SEARCH.grow(-6),text,12,Style.TEXT if not String(value.query).is_empty() else Style.MUTED)
	Style.button(game,Layout.REFILL,Locale.text(game,"refill"))

## Выводит только пять текущих строк и независимый бегунок, а не весь каталог шкафа.
static func draw_grid(game: Node2D, cabinet: bool, side: int) -> void:
	var choices:=Grid.items(game,cabinet,side); var first:=Grid.start(game,cabinet,side); var value:=Grid.state(game,cabinet)
	for visible in Layout.columns(side)*Layout.ROWS:
		var index:=first+visible; var rect:=Layout.slot(side,visible)
		Style.slot(game,rect,int(value.side)==side and index==int(value.selected[side]) and index<choices.size())
		if index>=choices.size(): continue
		var kind:String=choices[index]
		game.draw_item_icon(kind,Layout.icon(side,visible))
		Style.text(game,Layout.count(side,visible),"×"+str(Grid.count(game,cabinet,side,kind)),11,Style.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	if choices.is_empty(): Style.text(game,Layout.grid(side).grow(-12),empty_text(game,cabinet,side),13,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Style.panel(game,Layout.track(side),Style.INSET,Style.EDGE)
	game.draw_rect(Layout.thumb(side,value.rows[side],choices.size()),Style.ACCENT if int(value.side)==side else Style.MUTED)

## Показывает полное имя, крупное превью, оба остатка и действие нужного направления.
static func draw_detail(game: Node2D, cabinet: bool, kind: String) -> void:
	var name:String=game.inventory_item_name(kind)
	var fitted:int=title_size(game,name)
	game.draw_multiline_string(game.UI_FONT,Layout.TITLE.position+Vector2(0,game.UI_FONT.get_ascent(fitted)),name,HORIZONTAL_ALIGNMENT_CENTER,Layout.TITLE.size.x,fitted,-1,Style.TEXT)
	game.draw_item_icon(kind,Rect2(446,262,120,104))
	Style.text(game,Rect2(394,374,224,22),Locale.text(game,"bag",[game.inventory_item_count(kind)]),12,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Style.text(game,Rect2(394,400,224,22),(Locale.text(game,"stock",[Grid.count(game,cabinet,1,kind)]) if cabinet else game.LocaleSystem.ui("chest_column")+": "+str(Grid.count(game,false,1,kind))),12,Style.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	var detail:=description(game,kind); var size:int=game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,detail,224,42,11)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(394,432+game.UI_FONT.get_ascent(size)),detail,HORIZONTAL_ALIGNMENT_CENTER,224,42,11,3,Style.MUTED)
	var side:int=Grid.state(game,cabinet).side
	for index in AMOUNTS.size():
		var amount:int=999 if cabinet and index==3 else AMOUNTS[index]
		var label:String=Locale.text(game,"take" if side==1 else "put",[amount]) if amount>0 else Locale.text(game,"stack")
		var enabled:bool=Grid.count(game,cabinet,side,kind)>0
		if side==1 and kind in Cabinet.UNIQUE: enabled=enabled and game.inventory_item_count(kind)==0 and index==0
		if not cabinet and side==0 and kind=="home_chest": enabled=false
		Style.button(game,Layout.transfer(index),label,false,enabled)

## Вписывает полное имя также по ширине, поскольку длинное немецкое слово может не переноситься шрифтом.
static func title_size(game: Node, name: String) -> int:
	var size:int=game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,name,Layout.TITLE.size.x,Layout.TITLE.size.y,18)
	while size>6:
		var measured:Vector2=game.UI_FONT.get_multiline_string_size(name,HORIZONTAL_ALIGNMENT_CENTER,Layout.TITLE.size.x,size)
		if measured.x<=Layout.TITLE.size.x and measured.y<=Layout.TITLE.size.y: break
		size-=1
	return size

## Даёт действующий эффект, характеристики снаряжения или описание назначения обычного материала.
static func description(game: Node, kind: String) -> String:
	var items:=preload("res://scripts/systems/item_presentation_system.gd"); var effect:String=items.effect_text(game,kind)
	if not effect.is_empty(): return effect
	var stats:Dictionary=items.stats(game,kind); var rows:Array[String]=[]
	for key in stats: rows.append(game.LocaleSystem.ui("item_stat_"+key)+" +"+str(stats[key]))
	return " · ".join(rows) if not rows.is_empty() else game.LocaleSystem.ui(game.InventorySystem.detail_key(kind))

## Отличает пустой рюкзак или сундук от отсутствующего результата текстового поиска шкафа.
static func empty_text(game: Node, cabinet: bool, side: int) -> String:
	return Locale.text(game,"empty") if cabinet and side==1 and not String(Cabinet.state(game).query).is_empty() else game.LocaleSystem.ui("empty")
