extends RefCounted

const WATER_HEIGHT := 12.0

## Возвращает небольшой спокойный масштаб существующей капли, сохраняя её красное значение в обучении.
static func water_pose(game:Node, anchor:Vector2, seconds:float) -> Dictionary:
	var reduced:bool=game.settings_state.reduced_motion
	var phase:=seconds*TAU/2.2+anchor.x*0.01
	return {"center":anchor+Vector2(0,0 if reduced else sin(phase)*0.45),"scale":WATER_HEIGHT/19.0*(1.0 if reduced else 1.0+sin(phase)*0.025)}

## Размещает небольшой знак без круглой подложки; уменьшение движения сохраняет неподвижную опору.
static func center(game:Node, anchor:Vector2, seconds:float) -> Vector2:
	var bob:=0.0 if game.settings_state.reduced_motion else sin(seconds*TAU/2.2+anchor.x*0.01)*1.25
	return anchor+Vector2(0,bob)

## Рисует читаемый знак с мягкой тенью вместо геометрического значка, не меняя значение задания или готовности.
static func draw(game:Node2D, anchor:Vector2, marker:String, height:int=17) -> void:
	var point:=center(game,anchor,Time.get_ticks_msec()/1000.0)
	var ink:=Color("a6c580") if marker=="✓" else Color("f4ce75")
	var font:Font=game.UI_FONT
	var position:=point+Vector2(-10,font.get_ascent(height)*0.5)
	game.draw_string_outline(font,position,marker,HORIZONTAL_ALIGNMENT_CENTER,20,height,2,Color(0.20,0.14,0.08,0.85))
	game.draw_string(font,position,marker,HORIZONTAL_ALIGNMENT_CENTER,20,height,ink)
