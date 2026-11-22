extends RefCounted

const Version := preload("res://scripts/presentation/visual_version.gd")

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Profile := preload("res://assets/game/locations/overworld/lamps/profile.json")
const Events := preload("res://scripts/systems/world_event_system.gd")
const WorldProfile := preload("res://scripts/systems/world_visual_profile_system.gd")
const Legacy := preload("res://assets/game/locations/overworld/modular/prop_lamp_v1.png")
static var _shadow: ArrayMesh
static var _glow: ArrayMesh


## Выбирает самостоятельный негорящий рисунок; старое заднее направление разрешается передним.
static func view(direction: int = 0) -> Dictionary:
	var facing_name: String = Facing.NAMES[Facing.visible(direction)]
	return Resources.describe("prop.village_lamp", facing_name)


## Удерживает измеренную опору у нижнего камня без покадрового вписывания в квадрат.
static func destination(ground: Vector2, direction: int = 0) -> Rect2:
	return Resources.destination(view(direction), ground)


## Возвращает измеренный центр стекла, одинаковый для корпуса и отдельного светового прохода.
static func emitter(ground: Vector2, direction: int = 0) -> Vector2:
	var data: Dictionary = Profile.data.views[Facing.NAMES[Facing.visible(direction)]]
	var x: float = data.emitter[0]
	var y: float = data.emitter[1]
	var anchor_x: float = data.anchor[0]
	var anchor_y: float = data.anchor[1]
	return ground + (Vector2(x, y) - Vector2(anchor_x, anchor_y)) * 0.25


## Показывает одну свободную рабочую сторону только в QA; новой механики зажигания не добавляет.
static func approach(ground: Vector2, direction: int = 0) -> Vector2:
	return (
		ground
		+ {0: Vector2(0, 48), 1: Vector2(-40, 0), 3: Vector2(40, 0)}[Facing.visible(direction)]
	)


## Повторно использует прежнюю кривую календаря, не создавая таймер или состояние пламени.
static func intensity(minutes: float) -> float:
	return clampf(Events.darkness(minutes) / float(Profile.data.glow.darkness_peak), 0.0, 1.0)


## Рисует сухой корпус независимо от часа; свечение не входит в PNG.
static func draw(canvas: CanvasItem, ground: Vector2, direction: int = 0) -> void:
	var facing_name: String = Facing.NAMES[Facing.visible(direction)]
	var texture: Texture2D = (
		Resources.sampled_texture("prop.village_lamp", facing_name)
		if Version.enabled(canvas)
		else null
	)
	if texture == null:
		canvas.draw_texture_rect(Legacy, WorldProfile.visual_rect("village_lamp", ground), false)
	else:
		canvas.draw_texture_rect(texture, destination(ground, direction), false)


## Выводит отдельную постоянную контактную тень до героя.
static func draw_shadow(canvas: CanvasItem, ground: Vector2, direction: int = 0) -> void:
	if not Version.enabled(canvas):
		return
	canvas.draw_mesh(shadow(direction), null, Transform2D(0.0, ground))


## Рисует мягкое свечение в экранном проходе атмосферы; общую трансформацию и материал не меняет.
static func draw_glow(
	canvas: CanvasItem, screen_ground: Vector2, zoom: float, darkness: float, direction: int = 0
) -> void:
	if not Version.enabled(canvas):
		var legacy_center := screen_ground - Vector2(0, 62) * zoom
		for ring in 4:
			canvas.draw_circle(
				legacy_center,
				(42.0 - ring * 8.0) * zoom,
				Color(1.0, 0.72 + ring * 0.025, 0.28, darkness * (0.035 + ring * 0.025))
			)
		canvas.draw_circle(legacy_center, 5.0 * zoom, Color(1.0, 0.88, 0.56, darkness * 0.58))
		return
	var strength := clampf(darkness / float(Profile.data.glow.darkness_peak), 0.0, 1.0)
	if strength <= 0.0:
		return
	var center := screen_ground + emitter(Vector2.ZERO, direction) * zoom
	canvas.draw_mesh(
		glow_mesh(direction),
		null,
		Transform2D(0.0, Vector2(zoom, zoom), 0.0, center),
		Color(1, 1, 1, strength)
	)


## Повторно использует одну геометрию основания во всех направлениях и размещениях.
static func shadow(_direction: int = 0) -> ArrayMesh:
	if _shadow != null:
		return _shadow
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for i in 24:
		for p: Vector2 in [
			Vector2.ZERO,
			Vector2.from_angle(TAU * i / 24.0) * Vector2(7, 2.5),
			Vector2.from_angle(TAU * (i + 1) / 24.0) * Vector2(7, 2.5)
		]:
			vertices.append(Vector3(p.x, p.y, 0))
		colors.append(Color(0.16, 0.12, 0.08, 0.18))
		colors.append(Color(0.16, 0.12, 0.08, 0))
		colors.append(Color(0.16, 0.12, 0.08, 0))
	_shadow = _mesh(vertices, colors)
	return _shadow


## Соединяет радиальные уровни плавной альфой; один mesh разделяется всеми фонарями и ракурсами.
static func glow_mesh(_direction: int = 0) -> ArrayMesh:
	if _glow != null:
		return _glow
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var data: Dictionary = Profile.data.glow
	var r: float = data.color[0]
	var g: float = data.color[1]
	var b_color: float = data.color[2]
	var rgb := Color(r, g, b_color, 1)
	var radii: Array = data.radii
	var alpha: Array = data.alpha
	var segments: int = data.segments
	for ring: int in radii.size() - 1:
		var inner: float = radii[ring]
		var outer: float = radii[ring + 1]
		var inner_alpha: float = alpha[ring]
		var outer_alpha: float = alpha[ring + 1]
		for sector: int in segments:
			var a := Vector2.from_angle(TAU * sector / float(segments))
			var b := Vector2.from_angle(TAU * (sector + 1) / float(segments))
			for pair: Array in [
				[a * inner, inner_alpha],
				[a * outer, outer_alpha],
				[b * outer, outer_alpha],
				[a * inner, inner_alpha],
				[b * outer, outer_alpha],
				[b * inner, inner_alpha]
			]:
				var point: Vector2 = pair[0]
				var opacity: float = pair[1]
				vertices.append(Vector3(point.x, point.y, 0))
				colors.append(Color(rgb.r, rgb.g, rgb.b, opacity))
	_glow = _mesh(vertices, colors)
	return _glow


## Формирует один общий цветной ArrayMesh без текстур или покадрового readback.
static func _mesh(vertices: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
