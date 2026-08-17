extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const SCREEN := Color(0.025, 0.055, 0.048, 0.94)
const SCREEN_EDITOR := Color(0.075, 0.050, 0.030, 0.94)
const TECH_GREEN := Color("78e2b1")
const TECH_GOLD := Color("e7bc62")
const DISABLED := Color("63706b")
const EDITOR_BUTTON_TEXT := Color("2b190d")
const EDITOR_BUTTON_DISABLED := Color("755f49")


## Рисует общий резной корпус и отдельную техническую поверхность для F10 или конструктора уровней.
static func draw_panel(game: Node2D, rect: Rect2, editor: bool = false) -> Rect2:
	UiKitSystem.draw_panel(game,rect,true)
	var screen := rect.grow(-10.0)
	game.draw_rect(screen,SCREEN_EDITOR if editor else SCREEN)
	game.draw_rect(screen,Color(TECH_GOLD,0.72) if editor else Color(TECH_GREEN,0.72),false,2.0)
	return screen


## Рисует связанную с основным интерфейсом кнопку, оставляя активность и недоступность технически однозначными.
static func draw_button(game: Node2D, rect: Rect2, label: String, active: bool, enabled: bool = true, editor: bool = false) -> void:
	if editor and absf(rect.size.x-rect.size.y)<=rect.size.y*0.35: game.draw_texture_rect(UiKitSystem.texture("editor_card_selected" if active and enabled else "editor_card_normal"),rect,false)
	elif editor: UiKitSystem.draw_nine_patch(game,"editor_button_selected" if active and enabled else "editor_button_normal",rect)
	else: UiKitSystem.draw_button(game,rect,active,enabled,game.settings_state.reduced_motion,Time.get_ticks_msec())
	if not enabled: game.draw_rect(rect.grow(-6.0),Color(0.12,0.10,0.08,0.34))
	var inset:=minf(12.0,maxf(6.0,rect.size.x*0.09)); var fitted:=fit_label(game.UI_FONT,label,rect.size.x-inset*2.0,10 if editor else 11,7 if editor else 8); var color:=EDITOR_BUTTON_TEXT if editor and enabled else (EDITOR_BUTTON_DISABLED if editor else (Color("fff0c8") if enabled else Color("88928d")))
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(inset,rect.size.y*0.65),String(fitted.text),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-inset*2.0,int(fitted.size),color)


## Рисует компактный технический экран внутри деревянного корпуса для сведений, проверки или графика.
static func draw_readout(game: Node2D, rect: Rect2, editor: bool = false) -> void:
	game.draw_rect(rect,Color(0.02,0.032,0.029,0.94) if not editor else Color(0.045,0.03,0.02,0.94))
	game.draw_rect(rect,Color(TECH_GOLD,0.55) if editor else Color(TECH_GREEN,0.55),false,1.5)


## Рисует строку каталога как утопленный деревянный слот без добавления подписи поверх миниатюры.
static func draw_catalog_row(game: Node2D, rect: Rect2, selected: bool, editor: bool = false) -> void:
	if editor and absf(rect.size.x-rect.size.y)<=rect.size.y*0.25: game.draw_texture_rect(UiKitSystem.texture("editor_card_selected" if selected else "editor_card_normal"),rect,false)
	elif editor: UiKitSystem.draw_nine_patch(game,"editor_button_selected" if selected else "editor_button_normal",rect)
	else: UiKitSystem.draw_button(game,rect,selected,true,game.settings_state.reduced_motion,Time.get_ticks_msec())


## Уменьшает и при необходимости сокращает подпись по реальной ширине шрифта, не выпуская её за кнопку.
static func fit_label(font: Font, label: String, max_width: float, preferred_size: int = 10, minimum_size: int = 7) -> Dictionary:
	var size:=preferred_size; var text:=label
	while size>minimum_size and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width: size-=1
	if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=max_width: return {"text":text,"size":size}
	while text.length()>1 and font.get_string_size(text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width: text=text.left(text.length()-1)
	return {"text":text+"…","size":size}
