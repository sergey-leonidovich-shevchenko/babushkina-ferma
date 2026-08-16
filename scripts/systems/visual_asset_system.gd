extends RefCounted

const PIRATE_ENEMY_ATLAS := preload("res://assets/game/generated/pirate_enemy_atlas.png")
const PIRATE_ITEM_ATLAS := preload("res://assets/game/generated/pirate_item_atlas.png")
const POTION_ATLAS := preload("res://assets/game/generated/potion_atlas.png")
const INVENTORY_CORE_ATLAS := preload("res://assets/game/generated/inventory_core_atlas.png")
const INVENTORY_RARE_ATLAS := preload("res://assets/game/generated/inventory_rare_atlas.png")
const FARM_FOOD_ATLAS := preload("res://assets/game/generated/farm_food_atlas.png")
const FARM_LIFE_ATLAS := preload("res://assets/game/expansion_pack/expansion_atlas.png")
const ITEM_ICON_DIRECTORY := "res://assets/game/items/catalog"
static var item_icon_cache: Dictionary = {}

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
