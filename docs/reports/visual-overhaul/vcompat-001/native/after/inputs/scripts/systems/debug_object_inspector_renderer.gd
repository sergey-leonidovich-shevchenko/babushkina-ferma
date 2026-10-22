extends RefCounted

const OUTLINE := Color(0.0, 0.0, 0.0, 0.98)
const INFO_FILL := Color(0.015, 0.025, 0.025, 0.96)
const INFO_BORDER := Color("78e2b1")
const INFO_TEXT := Color("e9fff3")
const INFO_MUTED := Color("9fc8b5")


## Рисует чёрную рамку точно вокруг визуальной области объекта под курсором.
static func draw_world(game: Node2D) -> void:
	var pointer: Vector2 = game.get_meta("debug_inspector_cursor",game.get_local_mouse_position())
	var target: Dictionary = game.DebugObjectInspectorSystem.hovered_object(game,pointer)
	if target.is_empty(): return
	var bounds: Rect2 = target.bounds
	game.draw_rect(bounds.grow(3.0),OUTLINE,false,6.0)
	var corner := minf(12.0,minf(bounds.size.x,bounds.size.y)*0.22)
	for signs: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var point := Vector2(bounds.position.x if signs.x < 0 else bounds.end.x,bounds.position.y if signs.y < 0 else bounds.end.y)
		game.draw_line(point,point-Vector2(signs.x*corner,0),Color.BLACK,3.0)
		game.draw_line(point,point-Vector2(0,signs.y*corner),Color.BLACK,3.0)


## Рисует техническую карточку объекта в верхнем INFO-блоке основной F10-панели.
static func draw_info(game: Node2D, panel: Rect2, target: Dictionary) -> void:
	var rect := Rect2(panel.position+Vector2(12,42),Vector2(panel.size.x-24,170))
	game.DebugUiKitSystem.draw_readout(game,rect)
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(10,18),"INFO · %s" % target.category,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,12,Color("78e2b1"))
	var lines: Array[String] = [
		"Имя: %s" % target.name,
		"ID: %s" % target.id,
		"Локация: %s" % game.current_location,
		"X/Y: %.1f / %.1f" % [target.position.x,target.position.y],
		"Sprite bounds: %s" % bounds_text(target.bounds),
		"Коллизия: %s" % target.collision,
		"Состояние: %s" % target.state,
	]
	for detail in target.details: lines.append(String(detail))
	for index in mini(lines.size(),10):
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(10,37+index*13),lines[index],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,9,INFO_TEXT if index < 7 else INFO_MUTED)


## Возвращает координаты и размер визуального прямоугольника для компактной диагностической строки.
static func bounds_text(value: Rect2) -> String:
	return "%.0f/%.0f %.0f×%.0f" % [value.position.x,value.position.y,value.size.x,value.size.y]
