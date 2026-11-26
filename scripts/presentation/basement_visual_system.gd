extends RefCounted

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const Artisan := preload("res://scripts/systems/artisan_data.gd")
const Kitchen := preload("res://scripts/presentation/kitchen_visual_system.gd")
const Layout := preload("res://scripts/systems/basement_layout_system.gd")
const StationSprites := preload("res://scripts/presentation/basement_station_sprites.gd")
const ARTISAN_SPRITE_PATHS := {
	0: "res://assets/game/artisan/%s_%d_south.tres",
	1: "res://assets/game/artisan/%s_%d_west.tres",
	3: "res://assets/game/artisan/%s_%d_east.tres",
}
const SHELL := {
	"wall": preload("res://assets/game/basement/wall.tres"),
	"corner_left": preload("res://assets/game/basement/corner_left.tres"),
	"corner_right": preload("res://assets/game/basement/corner_right.tres"),
	"post": preload("res://assets/game/basement/post.tres"),
	"lantern": preload("res://assets/game/basement/lantern.tres"),
	"blueprint": preload("res://assets/game/basement/blueprint.tres"),
	"stairs_up": preload("res://assets/game/basement/stairs_up.tres"),
	"stairs_down": preload("res://assets/game/basement/stairs_down.tres"),
	"crates": preload("res://assets/game/basement/crates.tres"),
	"barrel": preload("res://assets/game/basement/barrel.tres"),
	"materials": preload("res://assets/game/basement/materials.tres"),
	"beam": preload("res://assets/game/basement/beam.tres"),
}

static var _artisan_station_textures: Dictionary[String, AtlasTexture] = {}


## Выбирает отдельный ракурс нужного уровня либо собственной строительной кучи.
static func texture(kind: String, level: int, direction: int, pile: bool = false) -> AtlasTexture:
	direction = Facing.visible(direction)
	var tier := 4 if pile else clampi(level, 1, 3)
	if kind in Artisan.STATIONS:
		# Атласы нужны лишь при запросе спрайта. Кеш ограничен 8 × 4 × 3 ресурсами.
		var template: String = ARTISAN_SPRITE_PATHS[direction]
		var path := template % [kind, tier]
		if not _artisan_station_textures.has(path):
			_artisan_station_textures[path] = (
				ResourceLoader.load(path, "AtlasTexture") as AtlasTexture
			)
		return _artisan_station_textures[path]
	var sprite_index := (tier - 1) * Facing.SELECTABLE.size() + Facing.SELECTABLE.find(direction)
	var sprite: Variant = (
		Kitchen.STATION[tier - 1][direction]
		if kind == "cauldron"
		else StationSprites.SPRITES[kind][sprite_index]
	)
	return sprite if sprite is AtlasTexture else null


## Совмещает полный силуэт с нижней опорой основания без растяжения или растровых поворотов.
static func destination(item: Dictionary, pile: bool = false) -> Rect2:
	var bounds := Layout.rect(item)
	# Оба поля проверяет планировщик или валидатор сохранения. JSON хранит числа как float.
	@warning_ignore("unsafe_call_argument")
	var level := int(item.get("level", 1))
	@warning_ignore("unsafe_call_argument")
	var direction := int(item.direction)
	var size := texture(str(item.kind), level, direction, pile).get_size()
	var width := maxf(bounds.size.x, 72) + 24
	var height := 120.0 if pile else 168.0
	size *= minf(width / size.x, height / size.y)
	return Rect2(Vector2(bounds.get_center().x - size.x / 2, bounds.end.y - size.y), size)
