extends RefCounted

const BIOME_PROP_ATLAS := preload("res://assets/game/generated/biome_prop_atlas.png")
const PIRATE_ENEMY_ATLAS := preload("res://assets/game/generated/pirate_enemy_atlas.png")
const PIRATE_ITEM_ATLAS := preload("res://assets/game/generated/pirate_item_atlas.png")
const POTION_ATLAS := preload("res://assets/game/generated/potion_atlas.png")
const SEASONAL_ATLAS := preload("res://assets/game/generated/seasonal_environment_atlas.png")
const ECLIPSE_ATLAS := preload("res://assets/game/generated/eclipse_event_atlas.png")
const INVENTORY_CORE_ATLAS := preload("res://assets/game/generated/inventory_core_atlas.png")
const INVENTORY_RARE_ATLAS := preload("res://assets/game/generated/inventory_rare_atlas.png")
const FARM_FOOD_ATLAS := preload("res://assets/game/generated/farm_food_atlas.png")
const FARM_LIFE_ATLAS := preload("res://assets/game/expansion_pack/expansion_atlas.png")
const ITEM_ICON_DIRECTORY := "res://assets/game/items/catalog"
static var item_icon_cache: Dictionary = {}

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
const INVENTORY_CORE_CELLS := {
	"hoe":Vector2i(0,0), "seeds":Vector2i(1,0), "water":Vector2i(2,0), "hand":Vector2i(3,0), "pickaxe":Vector2i(4,0), "fishing_rod":Vector2i(5,0),
	"axe":Vector2i(0,1), "carrot":Vector2i(1,1), "apple":Vector2i(2,1), "berries":Vector2i(3,1), "nut":Vector2i(4,1), "mushroom":Vector2i(5,1),
	"slime":Vector2i(0,2), "wood":Vector2i(1,2), "stone":Vector2i(2,2), "crystal":Vector2i(3,2), "red_crystal":Vector2i(4,2), "green_crystal":Vector2i(5,2),
	"fish":Vector2i(0,3), "sword":Vector2i(1,3), "bow":Vector2i(2,3), "arrows":Vector2i(3,3), "crystal_sword":Vector2i(4,3), "fiber":Vector2i(5,3),
}
const INVENTORY_RARE_CELLS := {
	"rare_seeds":Vector2i(0,0), "metal":Vector2i(1,0), "bones":Vector2i(2,0), "ancient_key":Vector2i(3,0), "blue_gem":Vector2i(4,0), "moon_relic":Vector2i(5,0),
	"raw_meat":Vector2i(0,1), "hide":Vector2i(1,1), "fur":Vector2i(2,1), "tusk":Vector2i(3,1), "bat_wing":Vector2i(4,1), "lizard_scale":Vector2i(5,1),
	"orc_blade":Vector2i(0,2), "home_chest":Vector2i(1,2), "guild_badge":Vector2i(2,2), "iron_helmet":Vector2i(3,2), "guardian_armor":Vector2i(4,2), "travel_boots":Vector2i(5,2),
	"crystal_ring":Vector2i(0,3), "orange":Vector2i(1,3), "watermelon":Vector2i(2,3), "oak_shield":Vector2i(3,3), "backpack_upgrade":Vector2i(5,3),
}
const FARM_FOOD_CELLS := {
	"tomato":Vector2i(0,0), "cabbage":Vector2i(1,0), "egg":Vector2i(2,0), "milk":Vector2i(3,0), "wheat":Vector2i(4,0), "corn":Vector2i(5,0),
	"potato":Vector2i(0,1), "onion":Vector2i(1,1), "cheese":Vector2i(2,1), "rope":Vector2i(3,1), "cotton":Vector2i(4,1), "flower":Vector2i(5,1),
	"honey":Vector2i(0,2), "bread":Vector2i(1,2), "pie":Vector2i(2,2), "pumpkin":Vector2i(3,2), "flour":Vector2i(4,2), "butter":Vector2i(5,2),
	"jam":Vector2i(0,3), "soup":Vector2i(1,3), "omelet":Vector2i(2,3), "cornbread":Vector2i(3,3), "wool":Vector2i(4,3), "bouquet":Vector2i(5,3),
}
const FARM_LIFE_CELLS := {"rustic_table":Vector2i(0,2),"wooden_chair":Vector2i(1,2),"woven_rug":Vector2i(2,2),"potted_fern":Vector2i(3,2),"wooden_wardrobe":Vector2i(4,2),"museum_token":Vector2i(2,1)}
const LARGE_PROP_BASES := [
	Vector2(150, 245), Vector2(720, 230), Vector2(1260, 250), Vector2(1900, 225),
	Vector2(360, 1050), Vector2(980, 1030), Vector2(1600, 1050), Vector2(2220, 1030),
]
const SMALL_PROP_BASES := [
	Vector2(330, 700), Vector2(820, 610), Vector2(1360, 810),
	Vector2(1810, 590), Vector2(2260, 520), Vector2(1180, 610),
]
const SEASONAL_TREE_BASE := Vector2(1695, 390)
const MOON_SOLID_BASES := [Vector2(1148, 650), Vector2(1690, 420), Vector2(2026, 750)]
const BACKGROUNDS := {
	"forest": Color("315c3c"), "rocky": Color("6f6a5b"), "ruins": Color("665849"),
	"cursed": Color("3e304b"), "glassworks": Color("6f493b"),
}


## Возвращает одну ячейку сезонного атласа четыре на два.
static func seasonal_source(season_index: int, ground_variant: bool = false) -> Rect2:
	var cell := Vector2(SEASONAL_ATLAS.get_width() / 4.0, SEASONAL_ATLAS.get_height() / 2.0)
	return Rect2(Vector2(clampi(season_index, 0, 3), 1 if ground_variant else 0) * cell, cell)


## Возвращает одну ячейку событийного атласа четыре на два.
static func eclipse_source(column: int, bottom_row: bool = false) -> Rect2:
	var cell := Vector2(ECLIPSE_ATLAS.get_width() / 4.0, ECLIPSE_ATLAS.get_height() / 2.0)
	return Rect2(Vector2(clampi(column, 0, 3), 1 if bottom_row else 0) * cell, cell)


## Рисует сезонные ориентиры деревни: дерево и два небольших природных кластера.
static func draw_seasonal_village(canvas: CanvasItem, season_index: int) -> void:
	canvas.draw_texture_rect_region(SEASONAL_ATLAS, Rect2(1605, 210, 184, 190), seasonal_source(season_index))
	for position in [Vector2(920, 720), Vector2(1450, 785)]:
		canvas.draw_texture_rect_region(SEASONAL_ATLAS, Rect2(position - Vector2(57, 70), Vector2(114, 104)), seasonal_source(season_index, true))


## Проверяет основания сезонного дерева и крупных объектов Лунной поляны для общей навигации.
static func blocks_event_position(location: String, position: Vector2, radius: float) -> bool:
	if location == "overworld": return position.distance_to(SEASONAL_TREE_BASE) < radius + 42.0
	if location == "moon_glade":
		for base in MOON_SOLID_BASES:
			if position.distance_to(base) < radius + 42.0: return true
	return false


## Рисует портал и декорации Лунной поляны из единого событийного атласа.
static func draw_eclipse_world(canvas: CanvasItem, location: String, portal_position: Vector2, portal_visible: bool) -> void:
	if portal_visible:
		canvas.draw_texture_rect_region(ECLIPSE_ATLAS, Rect2(portal_position - Vector2(64, 112), Vector2(128, 128)), eclipse_source(0))


## Рисует уникальный талисман затмения через ту же ячейку лунного кристалла.
static func draw_eclipse_item(canvas: CanvasItem, kind: String, rect: Rect2) -> bool:
	if kind != "eclipse_core": return false
	canvas.draw_texture_rect_region(ECLIPSE_ATLAS, rect, eclipse_source(2))
	return true


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
	canvas.draw_texture_rect_region(PIRATE_ITEM_ATLAS, rect.grow(-1), safe_atlas_source(pirate_item_source(kind), 12.0))
	return true


## Возвращает область зелья в тематической сетке четыре на два.
static func potion_source(kind: String) -> Rect2:
	if not POTION_CELLS.has(kind): return Rect2()
	var cell := Vector2(POTION_ATLAS.get_width() / 4.0, POTION_ATLAS.get_height() / 2.0)
	return Rect2(Vector2(POTION_CELLS[kind]) * cell, cell)


## Рисует зелье из общего атласа и сообщает, был ли вид предмета распознан.
static func draw_potion(canvas: CanvasItem, kind: String, rect: Rect2) -> bool:
	if not POTION_CELLS.has(kind): return false
	canvas.draw_texture_rect_region(POTION_ATLAS, rect.grow(-1), safe_atlas_source(potion_source(kind), 12.0))
	return true


## Загружает отдельные иконки до первого кадра, чтобы отрисовка не инициировала ресурсные операции.
static func initialize_item_icons(kinds: Array) -> void:
	item_icon_cache.clear()
	for value in kinds:
		var kind := String(value)
		var icon_kind := "carrot_seeds" if kind == "seeds" else kind
		var path := "%s/%s.png" % [ITEM_ICON_DIRECTORY, icon_kind]
		if ResourceLoader.exists(path): item_icon_cache[kind] = load(path)


## Возвращает заранее кэшированную отдельную текстуру предмета.
static func item_texture(kind: String) -> Texture2D:
	return item_icon_cache.get(kind) as Texture2D


## Вписывает квадратную иконку в доступную область без растяжения по одной из осей.
static func fitted_icon_rect(rect: Rect2) -> Rect2:
	var side := minf(rect.size.x, rect.size.y)
	return Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


## Возвращает атлас, которому принадлежит предмет основного каталога рюкзака.
static func inventory_item_atlas(kind: String) -> Texture2D:
	if INVENTORY_CORE_CELLS.has(kind): return INVENTORY_CORE_ATLAS
	if INVENTORY_RARE_CELLS.has(kind): return INVENTORY_RARE_ATLAS
	if FARM_FOOD_CELLS.has(kind): return FARM_FOOD_ATLAS
	return null


## Возвращает область предмета в фактическом инвентарном атласе шесть на четыре.
static func inventory_item_source(kind: String) -> Rect2:
	var atlas := inventory_item_atlas(kind)
	if atlas == null: return Rect2()
	var cell := Vector2(atlas.get_width() / 6.0, atlas.get_height() / 4.0)
	var coordinates: Vector2i = INVENTORY_CORE_CELLS.get(kind, INVENTORY_RARE_CELLS.get(kind, FARM_FOOD_CELLS.get(kind, Vector2i(-1, -1))))
	return Rect2(Vector2(coordinates) * cell, cell) if coordinates.x >= 0 else Rect2()


## Убирает служебные пиксели с границ сгенерированной ячейки, не захватывая соседний спрайт.
static func safe_atlas_source(source: Rect2, padding: float = 18.0) -> Rect2:
	if source.size.x <= padding * 2.0 or source.size.y <= padding * 2.0: return source
	return source.grow(-padding)


## Рисует предмет из основного или редкого инвентарного атласа.
static func draw_inventory_item(canvas: CanvasItem, kind: String, rect: Rect2) -> bool:
	var atlas := inventory_item_atlas(kind)
	if atlas == null: return false
	canvas.draw_texture_rect_region(atlas, rect.grow(-1), safe_atlas_source(inventory_item_source(kind)))
	return true


## Рисует предмет быта или музейную награду из атласа жизненного расширения.
static func draw_farm_life_item(canvas: CanvasItem, kind: String, rect: Rect2) -> bool:
	if not FARM_LIFE_CELLS.has(kind): return false
	var source := Rect2(Vector2(FARM_LIFE_CELLS[kind]) * Vector2(128, 128), Vector2(128, 128))
	canvas.draw_texture_rect_region(FARM_LIFE_ATLAS, rect.grow(-1), safe_atlas_source(source, 14.0))
	return true


## Проверяет, что зарегистрированный предмет имеет собственную текстуру или ячейку атласа.
static func has_item_icon(kind: String) -> bool:
	return item_texture(kind) != null
