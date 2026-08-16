extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const SCREEN := Color(0.025, 0.055, 0.048, 0.94)
const SCREEN_EDITOR := Color(0.075, 0.050, 0.030, 0.94)
const TECH_GREEN := Color("78e2b1")
const TECH_GOLD := Color("e7bc62")
const DISABLED := Color("63706b")
const EDITOR_BUTTON_TEXT := Color("4b2c17")
const EDITOR_BUTTON_DISABLED := Color("806b55")


## Рисует общий резной корпус и отдельную техническую поверхность для F10 или конструктора уровней.
static func draw_panel(game: Node2D, rect: Rect2, editor: bool = false) -> Rect2:
	UiKitSystem.draw_panel(game,rect,true)
	var screen := rect.grow(-10.0)
	game.draw_rect(screen,SCREEN_EDITOR if editor else SCREEN)
	game.draw_rect(screen,Color(TECH_GOLD,0.72) if editor else Color(TECH_GREEN,0.72),false,2.0)
	return screen


## Рисует связанную с основным интерфейсом кнопку, оставляя активность и недоступность технически однозначными.
static func draw_button(game: Node2D, rect: Rect2, label: String, active: bool, enabled: bool = true, editor: bool = false) -> void:
	UiKitSystem.draw_button(game,rect,active,enabled,game.settings_state.reduced_motion,Time.get_ticks_msec())
	var accent := TECH_GOLD if editor else TECH_GREEN
	if active: game.draw_rect(rect.grow(-5.0),Color(accent,0.22))
	elif not enabled: game.draw_rect(rect.grow(-4.0),Color(0.04,0.05,0.045,0.52))
	game.draw_circle(rect.position+Vector2(12.0,rect.size.y*0.5),3.0,accent if active and enabled else DISABLED)
	var fitted:=fit_label(game.UI_FONT,label,rect.size.x-34.0,10,7); var color:=EDITOR_BUTTON_TEXT if editor and enabled else (EDITOR_BUTTON_DISABLED if editor else (Color("fff0c8") if enabled else Color("88928d")))
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(19.0,rect.size.y*0.62),String(fitted.text),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-34.0,int(fitted.size),color)


## Рисует компактный технический экран внутри деревянного корпуса для сведений, проверки или графика.
static func draw_readout(game: Node2D, rect: Rect2, editor: bool = false) -> void:
	game.draw_rect(rect,Color(0.02,0.032,0.029,0.94) if not editor else Color(0.045,0.03,0.02,0.94))
	game.draw_rect(rect,Color(TECH_GOLD,0.55) if editor else Color(TECH_GREEN,0.55),false,1.5)


## Рисует строку каталога как утопленный деревянный слот без добавления подписи поверх миниатюры.
static func draw_catalog_row(game: Node2D, rect: Rect2, selected: bool, editor: bool = false) -> void:
	UiKitSystem.draw_button(game,rect,selected,true,game.settings_state.reduced_motion,Time.get_ticks_msec())
	game.draw_rect(rect.grow(-4.0),Color(TECH_GOLD,0.16 if selected else (0.08 if editor else 0.05)))


## Уменьшает и при необходимости сокращает подпись по реальной ширине шрифта, не выпуская её за кнопку.
static func fit_label(font: Font, label: String, max_width: float, preferred_size: int = 10, minimum_size: int = 7) -> Dictionary:
	var size:=preferred_size; var text:=label
	while size>minimum_size and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width: size-=1
	if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=max_width: return {"text":text,"size":size}
	while text.length()>1 and font.get_string_size(text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width: text=text.left(text.length()-1)
	return {"text":text+"…","size":size}
