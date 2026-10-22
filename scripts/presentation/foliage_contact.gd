extends RefCounted

const Frame:=preload("res://scripts/presentation/post_motion_frame.gd")
const Pose:=preload("res://scripts/systems/presentation_pose_system.gd")
const Speed:=preload("res://scripts/presentation/foliage_speed.gd")
const FLAG:=&"foliage_contact_enabled"
const RADIUS:=36.0
const GAIN:=8.0
const CAPACITY:=64

## Даёт компактное гладкое поле отталкивания без нормализации: в центре ноль, на краю нулевая производная.
static func displacement(hero:Vector2,root:Vector2,radius:float=RADIUS)->Vector2:
	if not hero.is_finite() or not root.is_finite() or not is_finite(radius) or radius<=0:return Vector2.ZERO
	var offset:=(hero-root)/radius;var square:=offset.length_squared()
	if not is_finite(square) or square>=1:return Vector2.ZERO
	return -offset*GAIN*pow(1.0-square,2.0)

## Возвращает фиксированный числовой буфер, не содержащий узлов, часов или данных сохранения.
static func empty()->PackedVector2Array:
	var result:=PackedVector2Array();result.resize(CAPACITY);return result

## Принимает только завершённую физику и видимую стопу; пауза хранит кадр, перенос/low/откат убирают старую реакцию.
static func values(game:Node,rows:Array,previous:PackedVector2Array)->PackedVector2Array:
	var result:=empty();var flag:Variant=game.get_meta(FLAG,true)
	if typeof(flag)!=TYPE_BOOL or not flag or rows.size()>CAPACITY:return result
	var frame:=Frame.read(game)
	if frame.is_empty() or not frame.active:return result
	if Pose.suspended(game):return previous.duplicate() if previous.size()==CAPACITY else result
	var hero:=Pose.ground(game);var strength:=Speed.strength(game)
	for i in rows.size():result[i]=displacement(hero,rows[i].anchor)*strength
	return result
