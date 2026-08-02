extends RefCounted


## Рисует поверх мира освещение, осадки и небесное событие, не затрагивая интерфейс.
static func draw(game: Node2D) -> void:
	var darkness: float = game.WorldEventSystem.darkness(game.game_minutes)
	if game.current_location == "moon_glade": darkness *= 0.34
	if darkness > 0.0:
		var tint := Color(0.055, 0.08, 0.20, darkness)
		if game.WorldEventSystem.eclipse_active(game.day, game.game_minutes): tint = Color(0.12, 0.03, 0.19, minf(darkness + 0.12, 0.75))
		game.draw_rect(Rect2(Vector2.ZERO, game.get_viewport_rect().size), tint)
		draw_lights(game, darkness)
	var weather: String = game.WorldEventSystem.weather(game)
	if weather in ["rain", "storm"]: draw_rain(game, weather == "storm")
	elif weather == "snow": draw_snow(game)
	if game.WorldEventSystem.eclipse_active(game.day, game.game_minutes): draw_eclipse(game)


## Рисует тёплые ориентиры у домов, чтобы ночная деревня оставалась читаемой.
static func draw_lights(game: Node2D, darkness: float) -> void:
	if game.current_location == "moon_glade":
		var return_screen: Vector2 = game.WorldEventSystem.RETURN_PORTAL_POSITION - game.camera_offset
		game.draw_circle(return_screen, 72.0, Color(0.32, 0.66, 1.0, 0.14))
		return
	if game.current_location != "overworld": return
	for point in [Vector2(470, 345), Vector2(805, 345), Vector2(1110, 345), Vector2(1510, 345)]:
		var screen: Vector2 = point - game.camera_offset
		game.draw_circle(screen, 34.0, Color(1.0, 0.72, 0.28, darkness * 0.20))
		game.draw_circle(screen, 12.0, Color(1.0, 0.82, 0.44, darkness * 0.48))
	if game.WorldEventSystem.eclipse_active(game.day, game.game_minutes):
		var portal_screen: Vector2 = game.WorldEventSystem.PORTAL_POSITION - game.camera_offset
		game.draw_circle(portal_screen, 76.0, Color(0.28, 0.62, 1.0, 0.16))


## Рисует детерминированные диагональные дождевые полосы без создания узлов на каждом кадре.
static func draw_rain(game: Node2D, storm: bool) -> void:
	var size := game.get_viewport_rect().size
	var phase := Time.get_ticks_msec() / 18
	for index in 64:
		var x := float(posmod(index * 97 + phase, int(size.x + 80))) - 40.0
		var y := float(posmod(index * 53 + phase * 2, int(size.y + 80))) - 40.0
		game.draw_line(Vector2(x, y), Vector2(x - 9, y + 20), Color(0.62, 0.82, 1.0, 0.55), 2.0)
	if storm and posmod(Time.get_ticks_msec(), 4200) < 80: game.draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.9, 1.0, 0.25))


## Рисует мягкий снег как лёгкий экранный слой.
static func draw_snow(game: Node2D) -> void:
	var size := game.get_viewport_rect().size
	var phase := Time.get_ticks_msec() / 35
	for index in 52:
		var x := float(posmod(index * 83 + phase + index * index, int(size.x)))
		var y := float(posmod(index * 61 + phase, int(size.y)))
		game.draw_circle(Vector2(x, y), 1.5 + float(index % 3), Color(0.94, 0.98, 1.0, 0.78))


## Рисует затенённую луну и сияющий венец активного затмения.
static func draw_eclipse(game: Node2D) -> void:
	var center := Vector2(game.get_viewport_rect().size.x - 88.0, 122.0)
	game.draw_circle(center, 38.0, Color(0.48, 0.25, 0.72, 0.20))
	game.draw_circle(center, 28.0, Color("d7c8f3"))
	game.draw_circle(center + Vector2(9, -2), 25.0, Color("24152f"))
