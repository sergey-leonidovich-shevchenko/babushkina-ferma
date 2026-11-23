extends RefCounted

# Игровой Node2D — существующий композиционный фасад; поля проверяются игровыми suites.
@warning_ignore_start("unsafe_property_access")

const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const WorldEvents := preload("res://scripts/systems/world_event_system.gd")
const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
const Palette := preload("res://scripts/presentation/daylight_palette.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Caves := preload("res://scripts/systems/cave_room_data.gd")
const Lamp := preload("res://scripts/presentation/village_lamp_visual.gd")
const WeatherClock := preload("res://scripts/presentation/weather_visual_clock.gd")
const LightQuality := preload("res://scripts/presentation/lighting_quality.gd")


## Рисует поверх мира освещение, осадки и небесное событие, не затрагивая интерфейс.
static func draw(game: Node2D) -> void:
	if not Reference.effects_enabled(game):
		return
	var location: String = game.current_location
	var minutes: float = game.game_minutes
	var day: int = game.day
	if Caves.is_cave(location):
		return
	var darkness := WorldEvents.darkness(minutes)
	if location == "moon_glade":
		darkness *= 0.34
	var eclipse := WorldEvents.eclipse_active(day, minutes)
	var tint := Color(0.055, 0.08, 0.20, darkness)
	if eclipse:
		tint = Color(0.12, 0.03, 0.19, minf(darkness + 0.12, 0.75))
	elif location == "overworld" and Palette.enabled(game):
		tint = Palette.tint(minutes)
	tint = LightQuality.tint(game, tint)
	if tint.a > 0.0:
		game.draw_rect(Rect2(Vector2.ZERO, game.get_viewport_rect().size), tint)
	if darkness > 0.0:
		draw_lights(game, darkness)
	var weather := WorldEvents.weather(game)
	if weather in ["rain", "storm"]:
		draw_rain(game, weather == "storm")
	elif weather == "snow":
		draw_snow(game)
	if eclipse:
		draw_eclipse(game)


## Рисует тёплые ориентиры у домов, чтобы ночная деревня оставалась читаемой.
static func draw_lights(game: Node2D, darkness: float) -> void:
	if not LightQuality.decorative_enabled(game):
		return
	if game.current_location == "moon_glade":
		var return_screen := WorldSpace.world_to_screen(game, WorldEvents.RETURN_PORTAL_POSITION)
		game.draw_circle(return_screen, 72.0, Color(0.32, 0.66, 1.0, 0.14))
		return
	if game.current_location != "overworld":
		return
	# Корпус остаётся сухим; отдельный профиль привязывает свет к измеренному центру стекла.
	for prop: Dictionary in (
		VillageLayoutSystem.PROP_PLACEMENTS + VillageLayoutSystem.SCENIC_PLACEMENTS
	):
		if prop.kind != "lamp":
			continue
		var position: Vector2 = prop.position
		var screen := WorldSpace.world_to_screen(game, position + Vector2(0, 24))
		Lamp.draw_glow(game, screen, WorldSpace.zoom(game), darkness)
	var day: int = game.day
	var minutes: float = game.game_minutes
	if WorldEvents.eclipse_active(day, minutes):
		var portal_screen := WorldSpace.world_to_screen(game, WorldEvents.PORTAL_POSITION)
		game.draw_circle(portal_screen, 76.0 * WorldSpace.zoom(game), Color(0.28, 0.62, 1.0, 0.16))


## Рисует детерминированные диагональные дождевые полосы без создания узлов на каждом кадре.
static func draw_rain(game: Node2D, storm: bool) -> void:
	var size := game.get_viewport_rect().size
	var seconds := WeatherClock.seconds(game)
	var phase := seconds * 1000.0 / 18.0
	for index in 64:
		var x := fposmod(index * 97 + phase, size.x + 80) - 40.0
		var y := fposmod(index * 53 + phase * 2, size.y + 80) - 40.0
		game.draw_line(Vector2(x, y), Vector2(x - 9, y + 20), Color(0.62, 0.82, 1.0, 0.55), 2.0)
	if storm and not game.settings_state.reduced_motion and fposmod(seconds, 4.2) < 0.08:
		game.draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.9, 1.0, 0.25))


## Рисует мягкий снег как лёгкий экранный слой.
static func draw_snow(game: Node2D) -> void:
	var size := game.get_viewport_rect().size
	var phase := WeatherClock.seconds(game) * 1000.0 / 35.0
	for index in 52:
		var x := fposmod(index * 83 + phase + index * index, size.x)
		var y := fposmod(index * 61 + phase, size.y)
		game.draw_circle(Vector2(x, y), 1.5 + float(index % 3), Color(0.94, 0.98, 1.0, 0.78))


## Рисует затенённую луну и сияющий венец активного затмения.
static func draw_eclipse(game: Node2D) -> void:
	var center := Vector2(game.get_viewport_rect().size.x - 88.0, 122.0)
	game.draw_circle(center, 38.0, Color(0.48, 0.25, 0.72, 0.20))
	game.draw_circle(center, 28.0, Color("d7c8f3"))
	game.draw_circle(center + Vector2(9, -2), 25.0, Color("24152f"))
