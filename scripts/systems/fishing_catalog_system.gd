extends RefCounted

const FISH_CATALOG := [
	{"id":"river_perch", "name_key":"fish_river_perch", "behavior":"mixed", "difficulty":28.0, "min_size":18, "max_size":36, "waters":["pond","river"], "depths":["shallow","middle"], "rarity":"common", "weight":9},
	{"id":"silver_bream", "name_key":"fish_silver_bream", "behavior":"smooth", "difficulty":22.0, "min_size":24, "max_size":48, "waters":["pond"], "depths":["shallow","middle"], "rarity":"common", "weight":8},
	{"id":"deep_pike", "name_key":"fish_deep_pike", "behavior":"dart", "difficulty":58.0, "min_size":38, "max_size":92, "waters":["river"], "depths":["deep"], "rarity":"rare", "weight":2, "requires":"fish_deep_water", "advanced_rod":true},
	{"id":"stone_loach", "name_key":"fish_stone_loach", "behavior":"sinker", "difficulty":42.0, "min_size":16, "max_size":41, "waters":["river"], "depths":["middle","deep"], "rarity":"uncommon", "weight":5, "requires":"fish_fine_rod"},
	{"id":"sunny_ide", "name_key":"fish_sunny_ide", "behavior":"floater", "difficulty":48.0, "min_size":27, "max_size":61, "waters":["pond","river"], "depths":["middle","deep"], "rarity":"rare", "weight":3, "requires":"fish_big_game", "advanced_rod":true},
	{"id":"spring_trout", "name_key":"fish_spring_trout", "behavior":"smooth", "difficulty":34.0, "min_size":22, "max_size":55, "waters":["river"], "depths":["shallow","middle"], "rarity":"uncommon", "weight":6, "seasons":["spring"], "weather":["clear","rain"]},
	{"id":"summer_catfish", "name_key":"fish_summer_catfish", "behavior":"sinker", "difficulty":46.0, "min_size":35, "max_size":78, "waters":["pond","river"], "depths":["deep"], "rarity":"rare", "weight":3, "seasons":["summer"], "time":"night", "requires":"fish_fine_rod"},
	{"id":"autumn_carp", "name_key":"fish_autumn_carp", "behavior":"mixed", "difficulty":39.0, "min_size":28, "max_size":69, "waters":["pond"], "depths":["shallow","middle"], "rarity":"uncommon", "weight":6, "seasons":["autumn"]},
	{"id":"winter_char", "name_key":"fish_winter_char", "behavior":"dart", "difficulty":53.0, "min_size":26, "max_size":64, "waters":["river"], "depths":["middle","deep"], "rarity":"rare", "weight":3, "seasons":["winter"], "requires":"fish_fine_rod"},
	{"id":"storm_eel", "name_key":"fish_storm_eel", "behavior":"dart", "difficulty":68.0, "min_size":44, "max_size":110, "waters":["river"], "depths":["deep"], "rarity":"legendary", "weight":1, "weather":["storm"], "requires":"fish_deep_water", "advanced_rod":true},
	{"id":"moon_koi", "name_key":"fish_moon_koi", "behavior":"floater", "difficulty":62.0, "min_size":31, "max_size":76, "waters":["pond"], "depths":["deep"], "rarity":"legendary", "weight":1, "time":"eclipse", "requires":"fish_big_game", "advanced_rod":true},
]


## Возвращает рыб, доступных для текущего сезона, погоды, времени и изученной снасти.
static func available_fish(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in FISH_CATALOG:
		if habitat_matches(game,candidate) and game.TalentSystem.can_catch_fish(game,candidate): result.append(candidate)
	return result if not result.is_empty() else [FISH_CATALOG[0]]


## Проверяет календарную среду рыбы отдельно от требований талантов и удочки.
static func habitat_matches(game: Node, fish: Dictionary) -> bool:
	var season: String = game.WorldEventSystem.season(game.day); var weather: String = game.WorldEventSystem.weather(game)
	if fish.has("seasons") and season not in fish.seasons: return false
	if fish.has("weather") and weather not in fish.weather: return false
	var time_rule: String = String(fish.get("time","")); var hour := float(game.game_minutes) / 60.0
	if time_rule == "night" and hour >= 6.0 and hour < 20.0: return false
	if time_rule == "eclipse" and not game.WorldEventSystem.eclipse_active(game.day,game.game_minutes): return false
	return true


## Фильтрует доступных рыб по конкретному водоёму и достигнутой глубине текущего заброса.
static func cast_pool(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fish in available_fish(game):
		if game.state.fishing.water_kind in fish.waters and game.state.fishing.depth_kind in fish.depths: result.append(fish)
	if not result.is_empty(): return result
	for fish in available_fish(game):
		if game.state.fishing.water_kind in fish.waters: result.append(fish)
	return result if not result.is_empty() else [FISH_CATALOG[0]]


## Выбирает рыбу из взвешенного пула воспроизводимо для одинакового состояния мира и заброса.
static func select_fish(game: Node) -> Dictionary:
	var pool := cast_pool(game); var total_weight := 0
	for fish in pool: total_weight += int(fish.weight)
	var seed: int = int(game.state.fishing.total_caught) * 17 + int(game.day) * 7 + int(game.game_minutes / 60.0) + roundi(float(game.state.fishing.cast_power) * 100.0)
	var roll := posmod(seed, maxi(total_weight, 1))
	for fish in pool:
		roll -= int(fish.weight)
		if roll < 0: return fish
	return pool[0]


## Возвращает неизменяемую запись вида по идентификатору или безопасный базовый вид.
static func fish_data(fish_id: String) -> Dictionary:
	for fish in FISH_CATALOG:
		if String(fish.id) == fish_id: return fish
	return FISH_CATALOG[0]
