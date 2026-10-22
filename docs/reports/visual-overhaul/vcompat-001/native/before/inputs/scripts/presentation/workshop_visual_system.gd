extends RefCounted

const Workshop := preload("res://scripts/systems/workshop_system.gd")
const Research := preload("res://scripts/systems/research_system.gd")
const Cardinal := preload("res://scripts/presentation/basement_visual_system.gd")
const SPRITES := {
	"sawmill":Cardinal.SPRITES.sawmill,
	"pottery":Cardinal.SPRITES.pottery,
	"glassblowing":Cardinal.SPRITES.glassblowing,
	"study_table":Cardinal.SPRITES.study,
}

## Возвращает неизменную опору и коллизию всех уровней выбранного рабочего места.
static func profile(kind: String) -> Dictionary:
	if not SPRITES.has(kind): return {}
	return {"visual_size":Vector2(192,144) if kind=="study_table" else Vector2(168,144),"collision_size":Vector2(144,48) if kind=="study_table" else Vector2(120,48),"workshop":true}

## Выбирает согласованную рабочую сторону того же станка и уровня вместо старого диагонального рисунка.
static func texture(kind: String, level: int) -> AtlasTexture:
	return Cardinal.texture("study" if kind=="study_table" else kind,level,0)

## Вписывает полный силуэт без растяжения в общий габарит и совмещает нижнюю опору с полом.
static func destination(kind: String, position: Vector2, level: int) -> Rect2:
	var source:=texture(kind,level).get_size(); var bounds:Vector2=profile(kind).visual_size
	var size:=source*minf(bounds.x/source.x,bounds.y/source.y)
	return Rect2(position-Vector2(size.x*0.5,size.y),size)

## Рисует выбранную ремесленную мастерскую A в обычном проходе глубины интерьерной мебели.
static func draw(game: Node2D, kind: String, position: Vector2, modulate: Color) -> void:
	var level:int=Research.state(game).level if kind=="study_table" else Workshop.state(game,kind).level
	game.draw_texture_rect(texture(kind,level),destination(kind,position,level),false,modulate)
