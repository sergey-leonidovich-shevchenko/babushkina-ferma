extends RefCounted

const Bridge := preload("res://scripts/presentation/overworld_bridge_layers.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
# Проверяем и оставляем четыре текселя сплошного настила вокруг границы отсечения.
const DECK_INTERIOR := Rect2i(30, 28, 84, 174)
const DECK_MARGIN := 4

static var _decks: Array[Rect2] = []
static var _prepared := false


## Возвращает только гарантированно непрозрачную сердцевину обоих настилов.
static func deck_regions() -> Array[Rect2]:
	if _prepared:
		return _decks
	_prepared = true
	var guarded := DECK_INTERIOR.grow(DECK_MARGIN)
	if not Rect2i(Bridge.DECK).encloses(guarded):
		return _decks
	var image := Bridge.TEXTURE.get_image()
	if image == null or image.is_empty() or image.is_compressed():
		return _decks
	for y in range(guarded.position.y, guarded.end.y):
		for x in range(guarded.position.x, guarded.end.x):
			if image.get_pixel(x, y).a < 1.0:
				return _decks
	for index in Layout.BRIDGES.size():
		var bridge := Layout.bridge_render_rect(index)
		if bridge.size == Bridge.TEXTURE.get_size():
			_decks.append(
				Rect2(bridge.position + Vector2(DECK_INTERIOR.position), DECK_INTERIOR.size)
			)
	return _decks


## Делит контур на непересекающиеся полосы, в том числе когда настил образует внутреннее отверстие.
static func visible_polygons(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var visible := polygons
	for deck in deck_regions():
		var next: Array[PackedVector2Array] = []
		for polygon in visible:
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				bounds = bounds.expand(point)
			var overlap := bounds.intersection(deck)
			if not overlap.has_area():
				next.append(polygon)
				continue
			var bands := [
				Rect2(
					bounds.position, Vector2(overlap.position.x - bounds.position.x, bounds.size.y)
				),
				Rect2(
					Vector2(overlap.end.x, bounds.position.y),
					Vector2(bounds.end.x - overlap.end.x, bounds.size.y)
				),
				Rect2(
					Vector2(overlap.position.x, bounds.position.y),
					Vector2(overlap.size.x, overlap.position.y - bounds.position.y)
				),
				Rect2(
					Vector2(overlap.position.x, overlap.end.y),
					Vector2(overlap.size.x, bounds.end.y - overlap.end.y)
				),
			]
			for band: Rect2 in bands:
				if band.has_area():
					next.append_array(Geometry2D.intersect_polygons(polygon, rectangle(band)))
		visible = next
	return visible


## Общая геометрия осевого прямоугольника для отсечения по настилу и миру.
static func rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
