extends RefCounted

enum Shape { TABLE, POST, ROOTS, BOOTS }

const INK := Color(0.15, 0.14, 0.09)
const EDGE_FRACTION := 0.52

# Опоры размечены в мировых пикселях относительно нижней точки рисунка.
const POST_BASE: Array[Vector2] = [
	Vector2(-10, -3),
	Vector2(-7, -6),
	Vector2(7, -6),
	Vector2(10, -3),
	Vector2(11, 2),
	Vector2(7, 5),
	Vector2(-7, 5),
	Vector2(-11, 2),
]
const ROOT_BASE: Array[Vector2] = [
	Vector2(-29, 0),
	Vector2(-19, -6),
	Vector2(-8, -4),
	Vector2(6, -7),
	Vector2(21, -5),
	Vector2(29, 0),
	Vector2(22, 6),
	Vector2(10, 4),
	Vector2(1, 9),
	Vector2(-10, 6),
	Vector2(-23, 6),
]

static var _meshes: Dictionary[Shape, ArrayMesh] = {}


## Рисует один общий mesh для каждого вида опоры, независимо от часа и анимации.
static func draw(canvas: CanvasItem, shape: Shape, anchor: Vector2) -> void:
	canvas.draw_mesh(mesh(shape), null, Transform2D(0.0, anchor))


## Геометрия создаётся один раз. Прозрачная кромка получает тот же цвет, что и ядро.
static func mesh(shape: Shape) -> ArrayMesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	match shape:
		Shape.TABLE:
			_lobe(vertices, colors, Vector2(0, -3), _ellipse(Vector2(44, 10)), 0.15)
			for foot: Vector2 in [
				Vector2(-32, 0), Vector2(32, 0), Vector2(-30, -13), Vector2(30, -13)
			]:
				_lobe(vertices, colors, foot, _ellipse(Vector2(9, 5)), 0.16)
		Shape.POST:
			_lobe(vertices, colors, Vector2.ZERO, POST_BASE, 0.25)
		Shape.ROOTS:
			_lobe(vertices, colors, Vector2.ZERO, ROOT_BASE, 0.19)
		Shape.BOOTS:
			for boot: Vector2 in [Vector2(-5, 1), Vector2(5, 1)]:
				_lobe(vertices, colors, boot, _ellipse(Vector2(9, 5)), 0.24)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[shape] = result
	return result


## Задаёт плоский контур отдельной опоры по двум радиусам.
static func _ellipse(radii: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for step: int in 12:
		points.append(Vector2.from_angle(TAU * step / 12.0) * radii)
	return points


## Добавляет ядро и прозрачную кромку одного пятна к общей геометрии тени.
static func _lobe(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	center: Vector2,
	outline: Array[Vector2],
	opacity: float,
) -> void:
	var solid := Color(INK, opacity)
	var feather := Color(INK, opacity * 0.7)
	var clear := Color(INK, 0.0)
	for index: int in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var inner_a := a * EDGE_FRACTION
		var inner_b := b * EDGE_FRACTION
		for point: Vector2 in [Vector2.ZERO, inner_a, inner_b, inner_a, a, b, inner_a, b, inner_b]:
			var vertex := point + center
			vertices.append(Vector3(vertex.x, vertex.y, 0.0))
		colors.append_array(
			[solid, feather, feather, feather, clear, clear, feather, clear, feather]
		)
