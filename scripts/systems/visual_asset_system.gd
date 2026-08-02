extends RefCounted

const BIOME_PROP_ATLAS := preload("res://assets/game/generated/biome_prop_atlas.png")
const PIRATE_ENEMY_ATLAS := preload("res://assets/game/generated/pirate_enemy_atlas.png")
const PIRATE_ITEM_ATLAS := preload("res://assets/game/generated/pirate_item_atlas.png")
const POTION_ATLAS := preload("res://assets/game/generated/potion_atlas.png")

const BIOME_ORDER := ["forest", "rocky", "ruins", "cursed", "glassworks"]
const PIRATE_ENEMY_ORDER := ["pirate", "zombie_pirate", "sea_ghost", "drowned_captain"]
const PIRATE_ITEM_CELLS := {
	"pirate_doubloon": Vector2i(0, 0), "ectoplasm": Vector2i(1, 0),
	"cursed_compass": Vector2i(2, 0), "pirate_cutlass": Vector2i(3, 0),
	"powder_keg": Vector2i(0, 1), "ship_key": Vector2i(1, 1),
	"treasure_map": Vector2i(2, 1), "captain_medallion": Vector2i(3, 1),
}
const POTION_CELLS := {
	"healing_potion":Vector2i(0,0), "mana_potion":Vector2i(1,0), "energy_potion":Vector2i(2,0), "invisibility_potion":Vector2i(3,0),
	"strength_potion":Vector2i(0,1), "regeneration_potion":Vector2i(1,1), "speed_potion":Vector2i(2,1), "defense_potion":Vector2i(3,1),
}
const LARGE_PROP_BASES := [
	Vector2(150, 245), Vector2(720, 230), Vector2(1260, 250), Vector2(1900, 225),
	Vector2(360, 1050), Vector2(980, 1030), Vector2(1600, 1050), Vector2(2220, 1030),
]
const SMALL_PROP_BASES := [
	Vector2(330, 700), Vector2(820, 610), Vector2(1360, 810),
	Vector2(1810, 590), Vector2(2260, 520), Vector2(1180, 610),
]
const BACKGROUNDS := {
	"forest": Color("315c3c"), "rocky": Color("6f6a5b"), "ruins": Color("665849"),
	"cursed": Color("3e304b"), "glassworks": Color("6f493b"),
}


## Возвращает фон приключенческого биома из единого визуального каталога.
static func background(location: String) -> Color:
	return BACKGROUNDS.get(location, Color("48624a"))


## Возвращает номер столбца биома в атласе или минус один для неизвестной локации.
static func biome_column(location: String) -> int:
	return BIOME_ORDER.find(location)


## Возвращает область одного биомного объекта в сетке пять на два.
static func biome_source(location: String, variant: int) -> Rect2:
	var cell := Vector2(BIOME_PROP_ATLAS.get_width() / 5.0, BIOME_PROP_ATLAS.get_height() / 2.0)
	return Rect2(Vector2(biome_column(location), clampi(variant, 0, 1)) * cell, cell)


## Рисует крупные ориентиры и малый декор выбранного приключенческого биома.
static func draw_biome(canvas: CanvasItem, location: String) -> void:
	if biome_column(location) < 0:
		return
	var large_size := Vector2(182, 190) if location in ["forest", "cursed"] else Vector2(168, 174)
	for base in LARGE_PROP_BASES:
		var rect := Rect2(base - Vector2(large_size.x * 0.5, large_size.y * 0.82), large_size)
		canvas.draw_texture_rect_region(BIOME_PROP_ATLAS, rect, biome_source(location, 0))
	for base in SMALL_PROP_BASES:
		var size := Vector2(112, 104)
		var rect := Rect2(base - Vector2(size.x * 0.5, size.y * 0.74), size)
		canvas.draw_texture_rect_region(BIOME_PROP_ATLAS, rect, biome_source(location, 1))


## Проверяет столкновение круглого персонажа с основаниями крупных биомных объектов.
static func blocks_biome_position(location: String, position: Vector2, radius: float) -> bool:
	if biome_column(location) < 0:
		return false
	for base in LARGE_PROP_BASES:
		if position.distance_to(base - Vector2(0, 12)) < radius + 38.0:
			return true
	return false


## Возвращает область семейства пирата в горизонтальном атласе врагов.
static func pirate_enemy_source(kind: String) -> Rect2:
	var cell := Vector2(PIRATE_ENEMY_ATLAS.get_width() / 4.0, PIRATE_ENEMY_ATLAS.get_height())
	return Rect2(Vector2(PIRATE_ENEMY_ORDER.find(kind), 0) * cell, cell)


## Рисует пиратского врага с общей анимацией движения, урона и исчезновения.
static func draw_pirate_enemy(game: Node2D, enemy: Dictionary, state: String) -> void:
	var index := PIRATE_ENEMY_ORDER.find(String(enemy.kind))
	if index < 0:
		return
	var modulate := Color.WHITE
	if state == "hurt": modulate = Color(1.0, 0.58, 0.58)
	elif state == "death": modulate.a = clampf(1.4 - float(enemy.get("visual_time", 0.0)), 0.0, 1.0)
	var size := 116.0 if enemy.kind == "drowned_captain" else 104.0
	var direction: Vector2 = enemy.get("direction", Vector2.DOWN)
	game.draw_living_atlas_sprite(PIRATE_ENEMY_ATLAS, pirate_enemy_source(enemy.kind), enemy.position, Vector2(size, size), float(enemy.get("visual_time", 0.0)), bool(enemy.get("moving", false)), float(index) * 0.8, direction.x < -0.1, modulate)


## Возвращает область пиратского предмета в сетке четыре на два.
static func pirate_item_source(kind: String) -> Rect2:
	if not PIRATE_ITEM_CELLS.has(kind):
		return Rect2()
	var cell := Vector2(PIRATE_ITEM_ATLAS.get_width() / 4.0, PIRATE_ITEM_ATLAS.get_height() / 2.0)
	return Rect2(Vector2(PIRATE_ITEM_CELLS[kind]) * cell, cell)


## Рисует предмет из тематического пиратского атласа и сообщает об успешной отрисовке.
static func draw_pirate_item(canvas: CanvasItem, kind: String, rect: Rect2) -> bool:
	if not PIRATE_ITEM_CELLS.has(kind):
		return false
	canvas.draw_texture_rect_region(PIRATE_ITEM_ATLAS, rect.grow(-1), pirate_item_source(kind))
	return true


## Возвращает область зелья в тематической сетке четыре на два.
static func potion_source(kind: String) -> Rect2:
	if not POTION_CELLS.has(kind): return Rect2()
	var cell := Vector2(POTION_ATLAS.get_width() / 4.0, POTION_ATLAS.get_height() / 2.0)
	return Rect2(Vector2(POTION_CELLS[kind]) * cell, cell)


## Рисует зелье из общего атласа и сообщает, был ли вид предмета распознан.
static func draw_potion(canvas: CanvasItem, kind: String, rect: Rect2) -> bool:
	if not POTION_CELLS.has(kind): return false
	canvas.draw_texture_rect_region(POTION_ATLAS, rect.grow(-1), potion_source(kind))
	return true
