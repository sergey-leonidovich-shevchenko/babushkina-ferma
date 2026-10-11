extends RefCounted

const Layout := preload("res://scripts/systems/cave_layout_system.gd")
const MapData := preload("res://scripts/systems/cave_map_data.gd")
const Assets := preload("res://scripts/systems/cave_asset_system.gd")
const Lighting := preload("res://scripts/systems/cave_lighting_system.gd")
const Visibility := preload("res://scripts/systems/world_visibility_system.gd")
const Rooms := preload("res://scripts/systems/cave_room_data.gd")
const RoomTheme := preload("res://scripts/systems/cave_theme_renderer.gd")


## Собирает неизменную пещеру из материала пола и самостоятельных спрайтов, кешируемых CanvasItem.
static func draw_background(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2(-120,-120), MapData.WORLD_SIZE + Vector2(240,360)), Color("141820"))
	var location: String = canvas.location
	var floor := Layout.floor_polygon(location)
	var uvs := PackedVector2Array()
	for point in floor: uvs.append(point / 768.0)
	canvas.draw_polygon(floor,PackedColorArray([Rooms.COLORS.get(location,Color.WHITE)]),uvs,Assets.floor_texture())
	RoomTheme.draw_background(canvas,location)
	for rock in Rooms.ROCKS.get(location,[]): canvas.draw_rect(rock,Color("141820"))
	for wall in Layout.walls(location): _draw_shadow(canvas,wall.position,Vector2(wall.bounds.size.x*1.2,52),0.34)
	for wall in Layout.walls(location): _draw_sprite(canvas,wall.kind,wall.position)
	for prop in Rooms.decorations(location):
		_draw_shadow(canvas, prop.position, Vector2(Assets.profile(prop.kind).visual_size.x, 24), 0.22)
		_draw_sprite(canvas, prop.kind, prop.position)
	if location == "cave":
		_draw_sprite(canvas,"entrance",MapData.EXIT+Vector2(0,48))
		for offset in [Vector2(-96,0),Vector2(96,0)]: _draw_sprite(canvas,"torch",MapData.EXIT+offset-Vector2(0,24))


## Рисует независимые мягкие источники света за персонажами; истощённая жила больше не светится.
static func draw_lights(game: Node2D) -> void:
	if not Rooms.is_cave(game.current_location): return
	var visible := Visibility.visible_rect(game)
	var time := Time.get_ticks_msec() * 0.001
	for node in game.resource_nodes:
		if node.location != game.current_location or node.hits <= 0: continue
		var rect := Rect2(Vector2(node.position) - Vector2(120,80), Vector2(240,160))
		if visible.intersects(rect): game.draw_texture_rect(Lighting.soft_disc(), rect, false, Lighting.vein_tint(node.kind, node.position, time))
	RoomTheme.draw_lights(game,visible,time)
	if game.current_location != "cave": return
	for offset in [Vector2(-72,-32), Vector2(72,-32)]:
		var rect := Rect2(MapData.EXIT + offset - Vector2(128,96), Vector2(256,192))
		if visible.intersects(rect): game.draw_texture_rect(Lighting.soft_disc(), rect, false, Color(1.0,0.67,0.24,0.14 + 0.015 * sin(time * 4.2)))


## Отрисовывает жилу по тому же профилю, что использует добыча; после истощения остаётся мелкая осыпь.
static func draw_resource(game: Node2D, node: Dictionary) -> void:
	var ground: Vector2 = game.ResourceSystem.ground_anchor(node.position)
	var kind := Assets.resource_art(node.kind) if node.hits > 0 else "rubble"
	var destination := Assets.destination_rect(kind, ground)
	if not Visibility.visible_rect(game).intersects(destination): return
	_draw_shadow(game, ground - Vector2(0,6), Vector2(destination.size.x, 32), 0.38)
	_draw_sprite(game, kind, ground)


## Закрывает существ передними скалами; остальные стены и крупный декор перекрывают героя по его силуэту.
static func draw_foreground(game: Node2D) -> void:
	if not Rooms.is_cave(game.current_location): return
	var actor := Rect2(game.player - Vector2(48,80), Vector2(96,96))
	var visible := Visibility.visible_rect(game)
	for wall in Layout.walls(game.current_location):
		var bounds: Rect2 = wall.bounds
		if not visible.intersects(bounds): continue
		if bool(wall.front) or (game.player.y < wall.position.y and bounds.intersects(actor)):
			_draw_sprite(game, wall.kind, wall.position)
	for prop in Rooms.decorations(game.current_location):
		if game.player.y < prop.position.y and Assets.destination_rect(prop.kind, prop.position).intersects(actor):
			_draw_sprite(game, prop.kind, prop.position)


## Показывает небольшой ориентир перехода в глубину пещеры, сохраняя существующую игровую связь областей.
static func draw_deep_gate(game: Node2D) -> void:
	for passage in Rooms.passages(game.current_location): _draw_passage(game,passage.position,passage.target)
	if Rooms.has_world_exit(game.current_location): _draw_passage(game,MapData.DEEP_GATE,"cursed")


## Обозначает выход из туннеля и показывает название соседней комнаты только вблизи героя.
static func _draw_passage(game: Node2D, ground: Vector2, target: String) -> void:
	var rect := Rect2(ground-Vector2(64,32),Vector2(128,64))
	if not Visibility.visible_rect(game).intersects(rect.grow(48)): return
	game.draw_texture_rect(Lighting.soft_disc(),rect,false,Color(0.42,0.67,0.86,0.12))
	game.draw_arc(ground,24,0.0,TAU,24,Color(0.6,0.8,0.95,0.42),2.0,true)
	if game.player.distance_to(ground) < 160:
		game.draw_ui_string(game.UI_FONT,ground+Vector2(-120,48),game.LocaleSystem.location(target),HORIZONTAL_ALIGNMENT_CENTER,240,14,Color("c5d7e4"))


## Рисует самостоятельный спрайт без дробного исходного прямоугольника и без изменения точки опоры.
static func _draw_sprite(canvas: Node2D, kind: String, ground: Vector2) -> void:
	canvas.draw_texture_rect(Assets.texture(kind), Assets.destination_rect(kind, ground), false)


## Отделяет предмет от пола мягкой контактной тенью, независимой от его цветного изображения.
static func _draw_shadow(canvas: Node2D, ground: Vector2, size: Vector2, opacity: float) -> void:
	canvas.draw_texture_rect(Lighting.soft_disc(), Rect2(ground - size * 0.5, size), false, Color(0.015,0.02,0.03,opacity))
