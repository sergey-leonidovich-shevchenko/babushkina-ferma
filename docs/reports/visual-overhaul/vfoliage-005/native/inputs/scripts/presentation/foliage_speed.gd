extends RefCounted

const Frame:=preload("res://scripts/presentation/post_motion_frame.gd")
const META:=&"foliage_actual_step"
const FLAG:=&"foliage_speed_enabled"
const REFERENCE_SPEED:=280.0
const EXTRA_GAIN:=0.9
const MAX_SPEED:=720.0

## Публикует только итог реально разрешённого шага; смена карты и скачок позиции очищают временный замер.
static func publish(game:Node,origin:Vector2,world:String,delta:float)->void:
	if game.has_meta(META):game.remove_meta(META)
	var frame:=Frame.read(game)
	if frame.is_empty() or not frame.active or world!=game.current_location or not origin.is_finite() or not is_finite(delta) or delta<=0:return
	var motion:Vector2=game.player-origin
	if not motion.is_finite() or motion.length()>maxf(8.0,MAX_SPEED*delta):return
	var velocity:=motion/delta
	if not velocity.is_finite():return
	var value:={"world":world,"player":Vector2(game.player),"seconds":frame.seconds,"origin":origin,"delta":delta,"velocity":velocity}
	value.make_read_only();game.set_meta(META,value)

## Читает скорость только того же завершённого такта; устаревшая, повреждённая или перенесённая запись не влияет на растение.
static func read(game:Node)->Vector2:
	var frame:=Frame.read(game);var value:Variant=game.get_meta(META,{})
	if frame.is_empty() or not frame.active or not value is Dictionary or not value.is_read_only() or value.size()!=6:return Vector2.ZERO
	for key in ["world","player","seconds","origin","delta","velocity"]:
		if not value.has(key):return Vector2.ZERO
	if typeof(value.world)!=TYPE_STRING or typeof(value.player)!=TYPE_VECTOR2 or typeof(value.seconds)!=TYPE_FLOAT or typeof(value.origin)!=TYPE_VECTOR2 or typeof(value.delta)!=TYPE_FLOAT or typeof(value.velocity)!=TYPE_VECTOR2:return Vector2.ZERO
	if value.world!=frame.world or value.player!=frame.player_world or value.seconds!=frame.seconds or not value.origin.is_finite() or not value.velocity.is_finite() or not is_finite(value.delta) or value.delta<=0:return Vector2.ZERO
	if not value.velocity.is_equal_approx((value.player-value.origin)/value.delta):return Vector2.ZERO
	return value.velocity

## Ограничивает добавочную силу по фактической скорости; покой сохраняет мягкий пространственный контакт без накопления импульсов.
static func gain(velocity:Vector2)->float:
	if not velocity.is_finite():return 1.0
	var fraction:=clampf(velocity.length()/REFERENCE_SPEED,0.0,1.0)
	return 1.0+EXTRA_GAIN*fraction*fraction

## Даёт отдельный технический откат к VFOLIAGE-004 без изменения ветра, геометрии или формата сохранения.
static func strength(game:Node)->float:
	var flag:Variant=game.get_meta(FLAG,true)
	return gain(read(game)) if typeof(flag)==TYPE_BOOL and flag else 1.0
