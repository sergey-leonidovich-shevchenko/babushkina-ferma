extends RefCounted

const LOCATION := "cellar_workshop"
const GRID := 24
const ROOM := Rect2(48,48,2304,1464)
const FLOOR := Rect2(96,240,2208,1224)
const SIZE := Vector2(2400,1560)
const STAIRS := Rect2(168,240,144,144)
const SPAWN := Vector2(240,408)
const BOARD := Vector2(528,396)
const HOUSE_ENTRY := Vector2(816,514)
const DIRECTIONS := [Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT]
const WORK_SECONDS := [5.0,7.0,9.0]
const BASE_STATIONS := {
	"workbench":{"icon":"wood_handle","size":Vector2i(4,3),"energy":1,"inputs":{"wood":8,"stone":6},"upgrades":[{"coins":60,"inputs":{"plank":6,"metal":3}},{"coins":150,"inputs":{"steel":2,"timber_frame":2}}]},
	"sawmill":{"icon":"wood_beam","size":Vector2i(5,4),"energy":1,"inputs":{"plank":6,"wood":10,"nails":4}},
	"pottery":{"icon":"clay_pot","size":Vector2i(4,4),"energy":1,"inputs":{"plank":4,"clay":4,"stone":6}},
	"furnace":{"icon":"brick","size":Vector2i(4,4),"energy":2,"inputs":{"stone":20,"clay":6,"plank":4}},
	"glassblowing":{"icon":"glass_bottle","size":Vector2i(5,4),"energy":2,"inputs":{"brick":8,"metal":4,"glass":4,"plank":4}},
	"study":{"icon":"research_paper","size":Vector2i(5,3),"energy":2,"inputs":{"plank":8,"glass":2,"research_paper":3,"research_ink":1}},
	"recycling":{"icon":"metal_scrap","size":Vector2i(5,3),"energy":1,"inputs":{"plank":6,"metal":3,"nails":4},"upgrades":[{"coins":70,"inputs":{"wood_beam":4,"metal":4}},{"coins":160,"inputs":{"steel":3,"timber_frame":2}}]},
	"alchemy":{"icon":"glass_vial","size":Vector2i(5,3),"energy":1,"inputs":{"plank":6,"glass_vial":4,"stone":4},"upgrades":[{"coins":100,"inputs":{"glass":6,"wood_beam":4,"metal":2}},{"coins":240,"inputs":{"clear_glass":4,"optical_lens":1,"steel":2}}]},
	"cauldron":{"icon":"cauldron","size":Vector2i(4,4),"energy":1,"inputs":{"cauldron":1,"stone":8,"wood":4},"upgrades":[{"coins":70,"inputs":{"brick":6,"metal":3}},{"coins":160,"inputs":{"steel":2,"ceramic_bowl":3,"glass_jar":2}}]},
	"forge":{"icon":"war_hammer","size":Vector2i(4,4),"energy":2,"inputs":{"metal":6,"stone":12,"wood":6},"upgrades":[{"coins":100,"inputs":{"metal":6,"brick":8}},{"coins":240,"inputs":{"steel":4,"timber_frame":2}}]},
}
static var STATIONS:Dictionary=BASE_STATIONS.merged(preload("res://scripts/systems/artisan_data.gd").STATIONS)
const WOOD := ["wood","log","plank","wood_beam","wood_dowel","wood_handle","timber_frame","wood_offcut","fiber","cloth","research_paper"]
const METAL := ["metal","metal_scrap","steel","nails","cauldron"]

## Возвращает существующие согласованные цены специализированных станков либо собственную цену обычного стола.
static func upgrade_cost(kind: String, level: int) -> Dictionary:
	if level<1 or level>=3 or not STATIONS.has(kind): return {}
	if kind in ["sawmill","pottery","glassblowing"]: return preload("res://scripts/systems/workshop_data.gd").STATIONS[kind].upgrades[level-1]
	if kind=="furnace": return preload("res://scripts/systems/furnace_data.gd").UPGRADES[level-1]
	if kind=="study": return preload("res://scripts/systems/research_data.gd").UPGRADES[level-1]
	return STATIONS[kind].upgrades[level-1]

## Различает деревянные, металлические, стеклянные и минеральные остатки без превращения камня в бесплатный металл.
static func debris(kind: String) -> String:
	if kind in ["leather","cured_fur","fine_cloth","canvas"]: return "cloth_scrap"
	if kind=="bone_meal": return "compost"
	if kind in WOOD: return "sawdust"
	if kind in METAL: return "metal_scrap"
	if kind in ["glass","glass_vial","glass_jar","clear_glass","optical_lens"]: return "glass_shard"
	if kind in ["clay","brick","ceramic_bowl","clay_pot","porcelain_cup"]: return "ceramic_shard"
	return "slag"

## Даёт минимальный уровень стола для существующей сложности рецепта без смены его состава.
static func recipe_level(recipe: Dictionary) -> int:
	if recipe.has("workshop_level"): return int(recipe.workshop_level)
	if recipe.has("furnace_level"): return int(recipe.furnace_level)
	if recipe.get("station","")=="alchemy": return clampi(int(recipe.get("alchemy_rank",1))-1,1,3)
	if recipe.get("station","workbench")=="workbench":
		var entry:Dictionary=preload("res://scripts/systems/research_data.gd").entry(recipe.output)
		return int(entry.get("tier",1))
	if recipe.get("station","")=="cauldron": return preload("res://scripts/systems/kitchen_data.gd").level(recipe)
	return 1
