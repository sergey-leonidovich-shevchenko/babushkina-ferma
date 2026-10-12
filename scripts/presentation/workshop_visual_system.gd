extends RefCounted

const Workshop := preload("res://scripts/systems/workshop_system.gd")
const Research := preload("res://scripts/systems/research_system.gd")
const SPRITES := {
	"sawmill":[preload("res://assets/game/workshops/sawmill_1.tres"),preload("res://assets/game/workshops/sawmill_2.tres"),preload("res://assets/game/workshops/sawmill_3.tres")],
	"pottery":[preload("res://assets/game/workshops/pottery_1.tres"),preload("res://assets/game/workshops/pottery_2.tres"),preload("res://assets/game/workshops/pottery_3.tres")],
	"glassblowing":[preload("res://assets/game/workshops/glassblowing_1.tres"),preload("res://assets/game/workshops/glassblowing_2.tres"),preload("res://assets/game/workshops/glassblowing_3.tres")],
	"study_table":[preload("res://assets/game/workshops/study_table_1.tres"),preload("res://assets/game/workshops/study_table_2.tres"),preload("res://assets/game/workshops/study_table_3.tres")],
}

## Возвращает неизменную опору и коллизию всех уровней выбранного рабочего места.
static func profile(kind: String) -> Dictionary:
	if not SPRITES.has(kind): return {}
	return {"visual_size":Vector2(192,144) if kind=="study_table" else Vector2(168,144),"collision_size":Vector2(144,48) if kind=="study_table" else Vector2(120,48),"workshop":true}

## Выбирает самостоятельный спрайтовый ресурс соответствующего сохранённого уровня.
static func texture(kind: String, level: int) -> AtlasTexture:
	return SPRITES[kind][clampi(level,1,3)-1]

## Вписывает полный силуэт без растяжения в общий габарит и совмещает нижнюю опору с полом.
static func destination(kind: String, position: Vector2, level: int) -> Rect2:
	var source:=texture(kind,level).get_size(); var bounds:Vector2=profile(kind).visual_size
	var size:=source*minf(bounds.x/source.x,bounds.y/source.y)
	return Rect2(position-Vector2(size.x*0.5,size.y),size)

## Рисует выбранную ремесленную мастерскую A в обычном проходе глубины интерьерной мебели.
static func draw(game: Node2D, kind: String, position: Vector2, modulate: Color) -> void:
	var level:int=Research.state(game).level if kind=="study_table" else Workshop.state(game,kind).level
	game.draw_texture_rect(texture(kind,level),destination(kind,position,level),false,modulate)
