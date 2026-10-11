extends RefCounted

const MASTER := preload("res://assets/game/characters/grandmother_v2/walk_master.png")
const DRAW_SCALE := 0.30
const WALK_FPS := 8.0
const GROUND_OFFSET := Vector2(0, 24)
const BOUNDS := [
	[Rect2(121,23,131,284), Rect2(418,23,133,282), Rect2(703,23,135,284), Rect2(1001,23,133,284)],
	[Rect2(109,330,146,283), Rect2(432,330,128,283), Rect2(710,330,134,283), Rect2(1017,330,134,283)],
	[Rect2(109,638,145,278), Rect2(417,638,132,276), Rect2(705,638,143,278), Rect2(1004,638,141,275)],
	[Rect2(120,944,134,272), Rect2(422,944,130,269), Rect2(704,944,135,270), Rect2(1001,944,137,269)],
]
const PIVOT_X := [[186,485,770,1065], [185,491,779,1079], [182,483,779,1078], [186,487,771,1068]]
const BASELINES := [307,613,916,1216]
static var _texture: Texture2D


## Выбирает четыре настоящих ракурса; левая диагональ больше не использует сломанный старый вид со спины.
static func direction_row(direction: Vector2) -> int:
	if direction.is_zero_approx(): return 0
	if absf(direction.x) >= absf(direction.y): return 1 if direction.x < 0.0 else 2
	return 3 if direction.y < 0.0 else 0


## Возвращает индивидуальный источник с запасом и измеренную опору тела, без горизонтального сдвига полос платья.
static func pose(direction: Vector2, time: float, moving: bool) -> Dictionary:
	var row := direction_row(direction)
	var frame := int(maxf(time, 0.0) * WALK_FPS) % 4 if moving else 1
	var source := Rect2(BOUNDS[row][frame]).grow(8)
	var pivot := Vector2(PIVOT_X[row][frame], BASELINES[row]) - source.position
	return {"texture": MASTER, "source": source, "pivot": pivot, "scale": DRAW_SCALE}


## Сохраняет прежнюю мировую опору NPC: ноги на 24px ниже логической позиции, масштаб одинаков в обеих осях.
static func destination(position: Vector2, frame: Dictionary) -> Rect2:
	return Rect2(position + GROUND_OFFSET - Vector2(frame.pivot) * DRAW_SCALE, Rect2(frame.source).size * DRAW_SCALE)


## Рисует бабушку вертикально и без процедурного перекоса, используя целиком нарисованные фазы шага.
static func draw_actor(game: Node2D, position: Vector2, direction: Vector2, moving: bool, tint: Color = Color.WHITE) -> void:
	game.DirectionalCharacterSystem.draw_soft_shadow(game, position + GROUND_OFFSET, Vector2(15,5))
	draw_pose(game, position, pose(direction, game.walk_animation_time, moving), tint)


## Использует один и тот же очищенный кадр в игре, редакторе и визуальной регрессии.
static func draw_pose(canvas: CanvasItem, position: Vector2, frame: Dictionary, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(texture(), destination(position, frame), frame.source, tint)


## Маскирует служебный зелёный фон только этого костюма без зелёных деталей, включая замкнутые островки и цветной кант.
## Текстура создаётся один раз до управления; в отличие от общего matte здесь не требуется дорогой flood fill.
static func texture() -> Texture2D:
	if _texture != null: return _texture
	var source := MASTER.get_image()
	if source.is_compressed(): source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var bytes := source.get_data()
	for offset in range(0, bytes.size(), 4):
		var red := int(bytes[offset])
		var green := int(bytes[offset + 1])
		var blue := int(bytes[offset + 2])
		if green > 32 and green > maxf(red, blue) * 1.35 + 8.0:
			bytes[offset + 3] = 0
	_texture = ImageTexture.create_from_image(Image.create_from_data(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8,bytes))
	return _texture


## Подготавливает прозрачность до начала игрового движения; в кадре больше не читается исходный PNG.
static func warmup() -> void:
	texture()


## Проверяет реальный мастер, целочисленные источники и допустимые точки опоры всех шестнадцати фаз.
static func profiles_are_valid() -> bool:
	var bounds := Rect2(Vector2.ZERO, MASTER.get_size())
	if MASTER.get_size() != Vector2(1254,1254): return false
	for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		for frame in 4:
			var value := pose(direction, (frame + 0.05) / WALK_FPS, true)
			var source: Rect2 = value.source
			if not bounds.encloses(source) or source.position != source.position.round(): return false
			if not Rect2(Vector2.ZERO, source.size).has_point(value.pivot): return false
	return true
