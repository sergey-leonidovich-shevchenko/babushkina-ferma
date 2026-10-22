extends RefCounted

const EFFECT_SIZE:=Vector2(72,72)
const TEXTURES:=[
	preload("res://assets/game/effects/actions/effect_00.png"),preload("res://assets/game/effects/actions/effect_01.png"),preload("res://assets/game/effects/actions/effect_02.png"),preload("res://assets/game/effects/actions/effect_03.png"),
	preload("res://assets/game/effects/actions/effect_04.png"),preload("res://assets/game/effects/actions/effect_05.png"),preload("res://assets/game/effects/actions/effect_06.png"),preload("res://assets/game/effects/actions/effect_07.png"),
	preload("res://assets/game/effects/actions/effect_08.png"),preload("res://assets/game/effects/actions/effect_09.png"),preload("res://assets/game/effects/actions/effect_10.png"),preload("res://assets/game/effects/actions/effect_11.png"),
	preload("res://assets/game/effects/actions/effect_12.png"),preload("res://assets/game/effects/actions/effect_13.png"),preload("res://assets/game/effects/actions/effect_14.png"),preload("res://assets/game/effects/actions/effect_15.png"),
]


## Возвращает отдельную текстуру эффекта по безопасно ограниченному индексу.
static func texture(index:int)->Texture2D:
	return TEXTURES[clampi(index,0,TEXTURES.size()-1)]


## Возвращает модульный мировой прямоугольник эффекта с опорой по центру.
static func effect_rect(position:Vector2,flip_x:bool=false)->Rect2:
	if flip_x: return Rect2(position+Vector2(EFFECT_SIZE.x*0.5,-EFFECT_SIZE.y*0.5),Vector2(-EFFECT_SIZE.x,EFFECT_SIZE.y))
	return Rect2(position-EFFECT_SIZE*0.5,EFFECT_SIZE)


## Рисует эффект без дробной выборки и произвольного runtime-масштаба.
static func draw(canvas:CanvasItem,index:int,position:Vector2,flip_x:bool=false,tint:Color=Color.WHITE)->void:
	canvas.draw_texture_rect(texture(index),effect_rect(position,flip_x),false,tint)


## Проверяет полный набор независимых прозрачных эффектов единого размера 72×72.
static func profiles_are_valid()->bool:
	if TEXTURES.size()!=16: return false
	for effect in TEXTURES:
		if effect.get_size()!=EFFECT_SIZE: return false
	return true
