extends RefCounted

## Единый каталог культур связывает мешок семян, растение на грядке, урожай и сезонные правила.
const CROPS := {
	"carrot":{"seed":"seeds","harvest":"carrot","seasons":["spring","summer","autumn"]},
	"tomato":{"seed":"tomato_seeds","harvest":"tomato","seasons":["summer"]},
	"cabbage":{"seed":"cabbage_seeds","harvest":"cabbage","seasons":["spring","autumn"]},
	"wheat":{"seed":"wheat_seeds","harvest":"wheat","seasons":["spring","summer","autumn"]},
	"corn":{"seed":"corn_seeds","harvest":"corn","seasons":["summer"]},
	"potato":{"seed":"potato_seeds","harvest":"potato","seasons":["spring","summer","autumn"]},
	"onion":{"seed":"onion_seeds","harvest":"onion","seasons":["spring","summer","autumn"]},
	"pumpkin":{"seed":"pumpkin_seeds","harvest":"pumpkin","seasons":["autumn"]},
	"strawberry":{"seed":"strawberry_seeds","harvest":"strawberry","seasons":["spring","summer","autumn"],"perennial":true,"seasonal_art":true},
	"beet":{"seed":"beet_seeds","harvest":"beet","seasons":["spring","autumn"]},
	"pepper":{"seed":"pepper_seeds","harvest":"pepper","seasons":["summer"]},
	"cucumber":{"seed":"cucumber_seeds","harvest":"cucumber","seasons":["summer"]},
	"sunflower":{"seed":"sunflower_seeds","harvest":"sunflower","seasons":["summer"]},
	"cotton":{"seed":"cotton_seeds","harvest":"cotton","seasons":["summer","autumn"]},
	"melon":{"seed":"melon_seeds","harvest":"melon","seasons":["summer"]},
	"herbs":{"seed":"herb_seeds","harvest":"herbs","seasons":["spring","summer","autumn"],"perennial":true,"seasonal_art":true},
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

## Возвращает все идентификаторы семян в стабильном порядке каталога.
static func seed_kinds() -> Array[String]:
	var result: Array[String] = []
	for crop_kind in CROPS: result.append(String(CROPS[crop_kind].seed))
	return result
