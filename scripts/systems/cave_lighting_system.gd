extends RefCounted

static var _soft_disc: GradientTexture2D
const VEIN_COLORS := {"crystal": Color("63cafa"), "green_crystal": Color("50dfa0"), "red_crystal": Color("ef6573"), "metal": Color("dfdcc8")}


## Создаёт один мягкий градиент, который повторно используется для контактных теней и свечения.
static func soft_disc() -> Texture2D:
	if _soft_disc != null: return _soft_disc
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.72), Color(1,1,1,0.16), Color(1,1,1,0)])
	_soft_disc = GradientTexture2D.new()
	_soft_disc.gradient = gradient; _soft_disc.width = 128; _soft_disc.height = 128
	_soft_disc.fill = GradientTexture2D.FILL_RADIAL
	_soft_disc.fill_from = Vector2(0.5,0.5); _soft_disc.fill_to = Vector2(1,0.5)
	return _soft_disc


## Рассчитывает очень слабое дыхание света без смещения самого ресурса и его физического основания.
static func vein_tint(kind: String, position: Vector2, time: float) -> Color:
	if not VEIN_COLORS.has(kind): return Color.TRANSPARENT
	var color: Color = VEIN_COLORS[kind]
	color.a = (0.055 if kind == "metal" else 0.12) * (0.9 + 0.1 * sin(time * 1.7 + position.x * 0.01))
	return color
