extends RefCounted

const DEFAULT_BIOME := "warm_valley"
const PROFILES := {
	"warm_valley":
	{
		"seed": 1741,
		"scale": 720.0,
		"shade": Color(0.80, 0.94, 0.70),
		"sun": Color(1.10, 1.04, 0.80),
	},
	"market_green":
	{
		"seed": 3253,
		"scale": 780.0,
		"shade": Color(0.88, 0.92, 0.63),
		"sun": Color(1.12, 1.00, 0.73),
	},
	"herb_garden":
	{
		"seed": 4877,
		"scale": 640.0,
		"shade": Color(0.70, 0.98, 0.66),
		"sun": Color(1.00, 1.11, 0.78),
	},
	"river_meadow":
	{
		"seed": 6121,
		"scale": 860.0,
		"shade": Color(0.67, 0.94, 1.04),
		"sun": Color(0.98, 1.09, 0.92),
	},
	"workyard_grass":
	{
		"seed": 7901,
		"scale": 690.0,
		"shade": Color(0.86, 0.86, 0.61),
		"sun": Color(1.11, 0.98, 0.72),
	},
	"orchard_floor":
	{
		"seed": 9349,
		"scale": 740.0,
		"shade": Color(0.69, 0.91, 0.61),
		"sun": Color(1.00, 1.08, 0.74),
	},
}


## Возвращает профиль биома без создания ресурсов, узлов или процессов на клетку.
static func profile(biome: String) -> Dictionary:
	return PROFILES.get(biome, PROFILES[DEFAULT_BIOME])


## Вычисляет один детерминированный цвет вершины из двух крупных плавных полей.
static func color_at(point: Vector2, biome: String) -> Color:
	var data := profile(biome)
	var seed: int = data.seed
	var scale: float = data.scale
	var first := _value_field(point / scale, seed)
	var second := _value_field(
		(point + Vector2(scale * 0.37, -scale * 0.21)) / (scale * 1.73), seed + 101
	)
	var amount := smoothstep(0.12, 0.88, clampf(first * 0.68 + second * 0.32, 0.0, 1.0))
	var shade: Color = data.shade
	var sun: Color = data.sun
	return shade.lerp(sun, amount)


## Даёт переносимое псевдослучайное значение через ограниченную целочисленную арифметику.
static func _lattice(cell: Vector2i, seed: int) -> float:
	var value := posmod(cell.x * 92837111 + cell.y * 689287499 + seed * 283923481, 2147483647)
	value = posmod(value * 48271 + 12820163, 2147483647)
	value = posmod(value * 48271 + 12345, 2147483647)
	return float(value) / 2147483647.0


## Интерполирует решётку без прямых границ между крупными цветовыми пятнами.
static func _value_field(point: Vector2, seed: int) -> float:
	var cell := Vector2i(floori(point.x), floori(point.y))
	var local := point - Vector2(cell)
	local = Vector2(
		local.x * local.x * (3.0 - 2.0 * local.x), local.y * local.y * (3.0 - 2.0 * local.y)
	)
	var top := lerpf(_lattice(cell, seed), _lattice(cell + Vector2i.RIGHT, seed), local.x)
	var bottom := lerpf(
		_lattice(cell + Vector2i.DOWN, seed), _lattice(cell + Vector2i.ONE, seed), local.x
	)
	return lerpf(top, bottom, local.y)
