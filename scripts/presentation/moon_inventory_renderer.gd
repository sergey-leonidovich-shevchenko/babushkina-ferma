extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const Items := preload("res://scripts/systems/item_presentation_system.gd")

## Рисует непрозрачный полноэкранный рюкзак с общей геометрией указателя и крупными иконками.
static func draw(game: Node) -> void:
	var ui = game.InterfaceRenderer
	game.draw_rect(ui.VIEWPORT,MoonStyle.BACKGROUND)
	MoonStyle.panel(game,ui.INVENTORY_GRID_PANEL)
	MoonStyle.panel(game,ui.INVENTORY_DETAIL_RECT,MoonStyle.INSET)
	MoonStyle.panel(game,ui.INVENTORY_EQUIPMENT_RECT)
	for index in game.InventorySystem.FILTERS.size():
		var id: String = game.InventorySystem.FILTERS[index]
		var label: String = game.LocaleSystem.ui("inventory_all") if id=="all" else game.LocaleSystem.ui("category_short_"+id)
		MoonStyle.button(game,ui.inventory_category_rect(index),label,game.inventory_filter==id)
	MoonStyle.button(game,ui.SORT_BUTTON,game.LocaleSystem.ui("sort_inventory"))
	var indices: Array[int] = game.InventorySystem.filtered_indices(game)
	for visible in game.InventorySystem.VISIBLE_SLOTS:
		var position: int = game.inventory_scroll_row*game.InventorySystem.COLUMNS+visible
		draw_slot(game,indices[position] if position<indices.size() else -1,visible)
	var count: int = game.inventory_slots.filter(func(kind):return not String(kind).is_empty() and game.inventory_item_count(kind)>0).size()
	MoonStyle.text(game,Rect2(680,95,190,24),"%d / ∞"%count,MoonStyle.LABEL_SIZE,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	draw_scrollbar(game)
	draw_detail(game)
	draw_equipment(game)
	MoonStyle.text(game,Rect2(26,584,240,38),MoonStyle.sentence_case(game.LocaleSystem.ui("quick_access").get_slice(" • ",0)),MoonStyle.BODY_SIZE,MoonStyle.MUTED)
	for index in 10: game.InterfaceRenderer.draw_inventory_hotbar_slot(game,index)
	MoonStyle.button(game,ui.USE_BUTTON,game.InventoryInputSystem.action_label(game,"eat"),false,game.InventorySystem.can_use(ui.selected_kind(game)))
	MoonStyle.button(game,ui.EQUIP_BUTTON,game.InventoryInputSystem.action_label(game,"equip"),false,game.InventorySystem.can_equip(ui.selected_kind(game)))
	MoonStyle.button(game,ui.DROP_BUTTON,game.LocaleSystem.ui("drop_item"),false,not ui.selected_kind(game).is_empty())

## Рисует ячейку без текстурных орнаментов; выбор и перенос имеют разные внутренние состояния.
static func draw_slot(game: Node, index: int, visible: int) -> void:
	var rect: Rect2 = game.InterfaceRenderer.inventory_slot_rect(visible)
	var selected: bool = index>=0 and index==game.inventory_selected
	MoonStyle.panel(game,rect,Color("49633d") if selected else Color("2b4435"),MoonStyle.ACCENT if selected else MoonStyle.EDGE)
	if index<0: return
	var kind: String = game.inventory_slots[index]
	if kind.is_empty() or game.inventory_item_count(kind)<=0: return
	game.draw_item_icon(kind,game.InterfaceRenderer.inventory_icon_rect(visible))
	if index==game.inventory_move_from: game.draw_rect(rect.grow(-3),Color(0.7,0.85,0.5,0.18))
	var amount: int = game.inventory_item_count(kind)
	if amount>1: MoonStyle.text(game,Rect2(rect.end-Vector2(36,17),Vector2(30,13)),str(amount),MoonStyle.LABEL_SIZE,MoonStyle.TEXT,HORIZONTAL_ALIGNMENT_RIGHT)

## Рисует полосу прокрутки только при наличии скрытых рядов.
static func draw_scrollbar(game: Node) -> void:
	var maximum: int = game.InventorySystem.max_scroll_row(game)
	if maximum<=0: return
	var track := Rect2(566,150,4,398)
	game.draw_rect(track,MoonStyle.INSET)
	var thumb := 100.0
	game.draw_rect(Rect2(track.position+Vector2(0,(track.size.y-thumb)*game.inventory_scroll_row/float(maximum)),Vector2(4,thumb)),MoonStyle.ACCENT)

## Показывает настоящие свойства предмета, эффект, прочность и сравнение с надетой вещью.
static func draw_detail(game: Node) -> void:
	var rect: Rect2 = game.InterfaceRenderer.INVENTORY_TOOLTIP_RECT
	var kind: String = game.InterfaceRenderer.selected_kind(game)
	if kind.is_empty(): MoonStyle.text(game,rect,game.LocaleSystem.ui("empty_slot"),14,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER); return
	var origin := rect.position+Vector2(14,16)
	game.draw_item_icon(kind,Rect2(origin,Vector2(54,54)))
	game.draw_ui_multiline_string(game.UI_FONT,origin+Vector2(66,14),game.inventory_item_name(kind),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-94,42,16,2,MoonStyle.TEXT)
	MoonStyle.text(game,Rect2(origin+Vector2(66,45),Vector2(rect.size.x-94,20)),MoonStyle.sentence_case(game.LocaleSystem.ui("item_rarity_"+Items.rarity(kind))),MoonStyle.LABEL_SIZE,Items.rarity_color(kind))
	MoonStyle.text(game,Rect2(origin+Vector2(0,74),Vector2(rect.size.x-28,20)),MoonStyle.sentence_case(game.LocaleSystem.ui("category_"+game.InventorySystem.category(kind)))+" · ×%d"%game.inventory_item_count(kind),MoonStyle.LABEL_SIZE,MoonStyle.MUTED)
	game.draw_line(origin+Vector2(0,105),origin+Vector2(rect.size.x-28,105),MoonStyle.EDGE,1)
	game.draw_ui_multiline_string(game.UI_FONT,origin+Vector2(0,129),game.LocaleSystem.ui(game.InventorySystem.detail_key(kind)),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-28,52,MoonStyle.BODY_SIZE,3,MoonStyle.MUTED)
	var effect:=Items.effect_text(game,kind); var effect_area:=Rect2(origin+Vector2(0,176),Vector2(rect.size.x-28,38))
	var effect_size:int=game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,effect,effect_area.size.x,effect_area.size.y,MoonStyle.BODY_SIZE)
	game.draw_ui_multiline_string(game.UI_FONT,effect_area.position+Vector2(0,game.UI_FONT.get_ascent(effect_size)),effect,HORIZONTAL_ALIGNMENT_LEFT,effect_area.size.x,effect_area.size.y,MoonStyle.BODY_SIZE,2,MoonStyle.ACCENT)
	var durability: int = Items.durability(game,kind)
	if durability>=0: MoonStyle.text(game,Rect2(origin+Vector2(0,213),Vector2(rect.size.x-28,20)),game.LocaleSystem.ui("item_durability",[durability]),MoonStyle.LABEL_SIZE,MoonStyle.MUTED)
	var comparison: Dictionary = Items.comparison(game,kind)
	if not comparison.is_empty():
		MoonStyle.text(game,Rect2(origin+Vector2(0,242),Vector2(rect.size.x-28,18)),MoonStyle.sentence_case(game.LocaleSystem.ui("item_equipped" if comparison.same else "item_compare")),MoonStyle.LABEL_SIZE,MoonStyle.MUTED)
		var row_index := 0
		for row in comparison.rows:
			if row_index>=3: break
			var label: String = game.LocaleSystem.ui("item_stat_"+String(row.id))+"  %s (%+d)"%[row.candidate,int(row.delta)]
			MoonStyle.text(game,Rect2(origin+Vector2(0,264+row_index*17),Vector2(rect.size.x-28,17)),label,MoonStyle.LABEL_SIZE,MoonStyle.ACCENT)
			row_index+=1

## Рисует отдельную колонку надетых вещей с шестью подписанными слотами.
static func draw_equipment(game: Node) -> void:
	MoonStyle.title(game,Rect2(916,149,195,26),MoonStyle.sentence_case(game.LocaleSystem.ui("equipment")),MoonStyle.SECTION_SIZE)
	var slots := ["head","body","legs","hands","offhand","ring"]
	for index in slots.size():
		var rect := Rect2(916+(index%2)*99,195+(index/2)*110,86,78)
		MoonStyle.panel(game,rect,Color("2c4435"))
		var kind: String = game.equipment[slots[index]]
		if not kind.is_empty(): game.draw_item_icon(kind,rect.grow(-12))
		var label: String = game.LocaleSystem.ui("offhand_short" if slots[index]=="offhand" else slots[index])
		MoonStyle.text(game,Rect2(rect.position+Vector2(0,80),Vector2(86,20)),label,MoonStyle.LABEL_SIZE,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
