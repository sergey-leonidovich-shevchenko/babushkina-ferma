extends RefCounted

const SEASONS := ["spring", "summer", "autumn", "winter"]
const WEATHER_NAMES := {"clear":"Ясно", "rain":"Дождь", "wind":"Ветрено", "snow":"Снег", "storm":"Гроза"}
const SEASON_NAMES := {"spring":"Весна", "summer":"Лето", "autumn":"Осень", "winter":"Зима"}
const DAYS_PER_SEASON := 7
const ECLIPSE_PERIOD := 5
const PORTAL_POSITION := Vector2(2030, 235)
const RETURN_PORTAL_POSITION := Vector2(220, 430)
const LOCATION_WEATHER_PROFILE := {
	"overworld": {"clear_to_wind": 0, "wind_to_rain": 0, "rain_boost": 0, "clear_boost": 0},
	"forest": {"clear_to_wind": 4, "wind_to_rain": 2, "rain_boost": 1, "clear_boost": 0},
	"rocky": {"clear_to_wind": 2, "wind_to_rain": 3, "rain_boost": 2, "clear_boost": 0},
	"ruins": {"clear_to_wind": 2, "wind_to_rain": 1, "rain_boost": 1, "storm_bonus": 1, "clear_boost": 0},
	"cave": {"clear_to_wind": 1, "wind_to_rain": 1, "rain_boost": 0, "clear_boost": 1},
	"cursed": {"clear_to_wind": 6, "wind_to_rain": 4, "rain_boost": 1, "storm_bonus": 1},
	"glassworks": {"clear_to_wind": 1, "wind_to_rain": 1, "rain_boost": 1, "clear_boost": 0},
	"pirate_ship": {"clear_to_wind": 5, "wind_to_rain": 3, "rain_boost": 2, "storm_bonus": 2},
	"moon_glade": {"clear_to_wind": 1, "wind_to_rain": 1, "clear_boost": 0},
}


## Возвращает сезон календарного дня; каждые семь дней начинается следующий сезон.
static func season(day: int) -> String:
	return SEASONS[((maxi(day, 1) - 1) / DAYS_PER_SEASON) % SEASONS.size()]


## Применяет локальный климат локации к глобальной погоде дня, сохраняя зимнюю валидацию.
static func apply_location_profile(day: int, base_weather: String, location: String) -> String:
	var profile: Dictionary = LOCATION_WEATHER_PROFILE.get(location, LOCATION_WEATHER_PROFILE.get("overworld", {}))
	var seed := posmod(day * 59 + String(location).length() * 11, 10)
	match base_weather:
		"clear":
			if int(profile.get("clear_to_wind", 0)) > 0 and seed < int(profile.get("clear_to_wind", 0)):
				base_weather = "wind"
		"wind":
			if int(profile.get("wind_to_rain", 0)) > 0 and seed < int(profile.get("wind_to_rain", 0)):
				base_weather = "rain"
		"rain":
			var boost := int(profile.get("rain_boost", 0))
			if boost > 0 and (seed + boost) % 7 == 0:
				base_weather = "storm"
		"storm":
			if int(profile.get("storm_bonus", 0)) > 0 and int(profile.get("clear_boost", 0)) > 0 and (seed % 10) < 2:
				base_weather = "rain"
	return base_weather


## Возвращает погоду дня для указанной локации, с учётом локального профиля.
static func location_weather(day: int, location: String) -> String:
	return apply_location_profile(day, weather_for_day(day), location)


## Возвращает локализованное короткое название текущего сезона.
static func season_name(day: int) -> String:
	return SEASON_NAMES[season(day)]


## Детерминированно выбирает погоду дня с сезонными ограничениями.
static func weather_for_day(day: int) -> String:
	var current := season(day)
	var roll := posmod(day * 37 + ((day - 1) / DAYS_PER_SEASON) * 11, 10)
	if current == "winter": return "snow" if roll < 5 else ("wind" if roll < 7 else "clear")
	if roll < 2: return "rain"
	if roll == 2 and current in ["spring", "autumn"]: return "storm"
	if roll < 5: return "wind"
	return "clear"


## Возвращает погоду состояния для текущей/переданной локации и безопасно восстанавливает её при старом сохранении.
static func weather(game: Node, location: String = "") -> String:
	var target_location: String = location if not location.is_empty() else game.current_location
	if target_location.is_empty(): target_location = "overworld"
	var requested_is_current: bool = target_location == game.current_location
	if requested_is_current:
		if game.state.world.weather_day != game.day or not WEATHER_NAMES.has(game.state.world.weather):
			game.state.world.weather_day = game.day
			game.state.world.weather = location_weather(game.day, target_location)
		return game.state.world.weather
	return location_weather(game.day, target_location)


## Синхронизирует смену дня, поливает грядки осадками и открывает обучающие подсказки.
static func update(game: Node) -> void:
	var previous_day: int = game.state.world.weather_day
	var current_weather := weather(game, game.current_location)
	if previous_day != game.day:
		if current_weather in ["rain", "storm"]:
			for cell in game.plots:
				if game.plots[cell].tilled: game.plots[cell].watered = true
		game.notify_tutorial("season")
		if current_weather != "clear": game.notify_tutorial("weather")
	if is_night(game.game_minutes): game.notify_tutorial("night")
	if eclipse_active(game.day, game.game_minutes): game.notify_tutorial("eclipse")


## Возвращает множитель роста культур с учётом сезона и естественного полива.
static func crop_growth_multiplier(game: Node) -> float:
	var multiplier: float = {"spring":1.15, "summer":1.0, "autumn":0.9, "winter":0.55}[season(game.day)]
	if weather(game) in ["rain", "storm"]: multiplier *= 1.1
	return multiplier


## Проверяет, относится ли игровое время к ночи.
static func is_night(minutes: float) -> bool:
	return minutes >= 20.0 * 60.0 or minutes < 5.0 * 60.0


## Проверяет окно затмения, включая продолжение события после полуночи.
static func eclipse_active(day: int, minutes: float) -> bool:
	return (day % ECLIPSE_PERIOD == 0 and minutes >= 20.0 * 60.0) or ((day - 1) % ECLIPSE_PERIOD == 0 and minutes < 2.0 * 60.0)


## Возвращает силу затемнения от рассвета через день и сумерки к ночи.
static func darkness(minutes: float) -> float:
	if minutes < 5.0 * 60.0: return 0.62
	if minutes < 7.0 * 60.0: return lerpf(0.62, 0.0, (minutes - 300.0) / 120.0)
	if minutes < 18.0 * 60.0: return 0.0
	if minutes < 20.0 * 60.0: return lerpf(0.0, 0.62, (minutes - 1080.0) / 120.0)
	return 0.62


## Возвращает ближайший доступный лунный портал либо пустое взаимодействие.
static func nearest_interaction(game: Node, maximum_distance: float) -> String:
	var moon_interaction: String = game.MoonGladeSystem.nearest_interaction(game, maximum_distance)
	if not moon_interaction.is_empty():
		maximum_distance = game.player.distance_to(game.MoonGladeSystem.interaction_position(moon_interaction))
	var portal := PORTAL_POSITION if game.current_location == "overworld" else RETURN_PORTAL_POSITION
	if game.current_location == "moon_glade" or eclipse_active(game.day, game.game_minutes):
		if game.player.distance_to(portal) < maximum_distance: return "moon_portal"
	return moon_interaction


## Перемещает героя между деревней и Лунной поляной через временный портал.
static func use_portal(game: Node) -> bool:
	if game.current_location == "moon_glade":
		game.current_location = "overworld"; game.player = PORTAL_POSITION - Vector2(90, 0)
	elif eclipse_active(game.day, game.game_minutes):
		game.current_location = "moon_glade"; game.player = RETURN_PORTAL_POSITION + Vector2(90, 0)
		game.MoonGladeSystem.prepare(game)
	else:
		return false
	game.sync_background_location(); game.update_camera(); game.notify_tutorial("moon_portal")
	if game.current_location == "moon_glade": game.DiscoverySystem.show_location(game, "moon_glade")
	game.message = "Лунная поляна" if game.current_location == "moon_glade" else "Возвращение в деревню"
	return true


## Формирует компактную строку сезона, погоды и редкого небесного события для HUD.
static func hud_text(game: Node) -> String:
	var text := "%s · %s" % [season_name(game.day), WEATHER_NAMES[weather(game)]]
	if eclipse_active(game.day, game.game_minutes): text += " · Лунное затмение"
	return text
