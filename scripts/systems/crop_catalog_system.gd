extends RefCounted

## Единый каталог культур связывает мешок семян, растение на грядке, урожай и сезонные правила.
const CROPS := {
	"carrot":{"seed":"seeds","harvest":"carrot","seasons":["spring","summer","autumn"],"growth":20.0,"yield":1,"xp":3},
	"tomato":{"seed":"tomato_seeds","harvest":"tomato","seasons":["summer"],"growth":28.0,"yield":2,"xp":4},
	"cabbage":{"seed":"cabbage_seeds","harvest":"cabbage","seasons":["spring","autumn"],"growth":30.0,"yield":1,"xp":4},
	"wheat":{"seed":"wheat_seeds","harvest":"wheat","seasons":["spring","summer","autumn"],"growth":24.0,"yield":3,"xp":3},
	"corn":{"seed":"corn_seeds","harvest":"corn","seasons":["summer"],"growth":32.0,"yield":2,"xp":4},
	"potato":{"seed":"potato_seeds","harvest":"potato","seasons":["spring","summer","autumn"],"growth":26.0,"yield":2,"xp":4},
	"onion":{"seed":"onion_seeds","harvest":"onion","seasons":["spring","summer","autumn"],"growth":22.0,"yield":2,"xp":3},
	"pumpkin":{"seed":"pumpkin_seeds","harvest":"pumpkin","seasons":["autumn"],"growth":44.0,"yield":1,"xp":7},
	"strawberry":{"seed":"strawberry_seeds","harvest":"strawberry","seasons":["spring","summer","autumn"],"growth":36.0,"yield":3,"xp":6,"regrow":16.0,"perennial":true,"seasonal_art":true},
	"beet":{"seed":"beet_seeds","harvest":"beet","seasons":["spring","autumn"],"growth":24.0,"yield":2,"xp":4},
	"pepper":{"seed":"pepper_seeds","harvest":"pepper","seasons":["summer"],"growth":34.0,"yield":2,"xp":5},
	"cucumber":{"seed":"cucumber_seeds","harvest":"cucumber","seasons":["summer"],"growth":30.0,"yield":3,"xp":5},
	"sunflower":{"seed":"sunflower_seeds","harvest":"sunflower","seasons":["summer"],"growth":38.0,"yield":1,"xp":6},
	"cotton":{"seed":"cotton_seeds","harvest":"cotton","seasons":["summer","autumn"],"growth":40.0,"yield":2,"xp":6},
	"melon":{"seed":"melon_seeds","harvest":"melon","seasons":["summer"],"growth":44.0,"yield":1,"xp":7},
	"herbs":{"seed":"herb_seeds","harvest":"herbs","seasons":["spring","summer","autumn"],"growth":34.0,"yield":3,"xp":6,"regrow":14.0,"perennial":true,"seasonal_art":true},
}

## Возвращает идентификатор культуры для зарегистрированного мешка семян или пустую строку.
static func crop_for_seed(seed_kind: String) -> String:
	for crop_kind in CROPS:
		if CROPS[crop_kind].seed == seed_kind: return crop_kind
	return ""

## Возвращает безопасные метаданные культуры, используя морковь для старых грядок.
static func data(crop_kind: String) -> Dictionary:
	return Dictionary(CROPS.get(crop_kind, CROPS.carrot))

## Проверяет, разрешён ли рост культуры в указанном сезоне.
static func grows_in_season(crop_kind: String, season: String) -> bool:
	return season in data(crop_kind).seasons

## Проверяет, остаётся ли взрослая культура на грядке после сбора урожая.
static func is_perennial(crop_kind: String) -> bool:
	return bool(data(crop_kind).get("perennial", false))

## Проверяет наличие отдельных четырёхсезонных кадров у культуры.
static func has_seasonal_art(crop_kind: String) -> bool:
	return bool(data(crop_kind).get("seasonal_art", false))

## Возвращает полное время первого созревания культуры в реальных секундах.
static func growth_duration(crop_kind: String) -> float:
	return maxf(float(data(crop_kind).get("growth", 20.0)), 4.0)

## Возвращает длительность четверти роста, соответствующую одной из пяти визуальных стадий.
static func stage_duration(crop_kind: String) -> float:
	return growth_duration(crop_kind) / 4.0

## Возвращает базовое количество урожая до бонуса фермерского навыка.
static func base_yield(crop_kind: String) -> int:
	return maxi(int(data(crop_kind).get("yield", 1)), 1)

## Возвращает опыт персонажа и фермерства за сбор культуры с учётом её сложности.
static func harvest_xp(crop_kind: String) -> int:
	return maxi(int(data(crop_kind).get("xp", 3)), 1)

## Возвращает время повторного плодоношения многолетника без новой посадки.
static func regrow_duration(crop_kind: String) -> float:
	return clampf(float(data(crop_kind).get("regrow", growth_duration(crop_kind) * 0.5)), stage_duration(crop_kind), growth_duration(crop_kind))

## Возвращает общий урожай с добавочным плодом от каждых трёх уровней фермерства.
static func harvest_count(game: Node, crop_kind: String) -> int:
	return base_yield(crop_kind) + game.SkillSystem.harvest_count(game) - 1

## Возвращает все идентификаторы семян в стабильном порядке каталога.
static func seed_kinds() -> Array[String]:
	var result: Array[String] = []
	for crop_kind in CROPS: result.append(String(CROPS[crop_kind].seed))
	return result
