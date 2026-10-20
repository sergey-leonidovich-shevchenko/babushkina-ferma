extends RefCounted

const DESIGN_SIZE := Vector2(1152,648)
const REFERENCE_ZOOM := 1.2
const OVERRIDE := &"camera_reference_zoom"

## Приближает только первую локацию целиком; остальные карты и ручной F12 сохраняют прежний профиль.
static func zoom(game: Node) -> float:
	if game.get("current_location")!="overworld" or bool(game.get_meta(&"level_editor",{}).get("active",false)): return 1.0
	if bool(game.get_meta(&"published_level_runtime",{}).get("active",false)): return 1.0
	var value: float = float(game.get_meta(OVERRIDE,REFERENCE_ZOOM))
	return value if value in [1.0,REFERENCE_ZOOM] else REFERENCE_ZOOM

## Даёт явный контроль/откат без свободного уменьшения и без изменения сохранения или настроек игрока.
static func set_reference_zoom(game: Node, value: float) -> bool:
	if value not in [1.0,REFERENCE_ZOOM]: return false
	game.set_meta(OVERRIDE,value)
	return true

## Возвращает единый масштабированный мировой слой; локальный поворот применяется до проекции камеры.
static func transform(game: Node, local: Transform2D = Transform2D.IDENTITY) -> Transform2D:
	var amount := zoom(game)
	# Screen shake is disabled project-wide; the projection adds no hidden displacement.
	var offset: Vector2 = -game.camera_offset
	return Transform2D(Vector2(amount,0),Vector2(0,amount),offset*amount)*local

## Применяет ту же матрицу к обычному миру и вложенным спрайтам с поворотом/отражением.
static func apply(game: Node2D, position: Vector2 = Vector2.ZERO, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	game.draw_set_transform_matrix(transform(game,Transform2D(rotation,scale,0.0,position)))

## Переводит мировую точку в логический экран до единственного оконного/Retina преобразования движка.
static func world_to_screen(game: Node, world: Vector2) -> Vector2:
	return transform(game)*world

## Преобразует логический ввод обратно в физический мир тем же обратным преобразованием.
static func screen_to_world(game: Node, screen: Vector2) -> Vector2:
	return transform(game).affine_inverse()*screen

## Возвращает реальное поле мира: при 120% это 960×540, а не прежние 1152×648.
static func field_size(game: Node) -> Vector2:
	return DESIGN_SIZE/zoom(game)

## Даёт единую область отсечения в мировых единицах, включая дробную камеру.
static func view_rect(game: Node) -> Rect2:
	return screen_rect_to_world(game,Rect2(Vector2.ZERO,DESIGN_SIZE))

## Переводит экранные границы HUD/рабочего поля в мировые границы подписей.
static func screen_rect_to_world(game: Node, rect: Rect2) -> Rect2:
	return Rect2(screen_to_world(game,rect.position),rect.size/zoom(game))

## Синхронизирует отдельный фоновый узел с той же проекцией, не создавая дополнительных viewport.
static func sync_background(game: Node) -> void:
	var background := game.get_node_or_null("WorldBackground")
	if background:
		background.scale=Vector2.ONE*zoom(game)
		background.position=world_to_screen(game,Vector2.ZERO)
