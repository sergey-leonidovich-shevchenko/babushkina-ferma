extends RefCounted

const ITEMS := {
	"research_paper":{"names":["Исследовательская бумага","Research paper","Papel de estudio","Forschungspapier","Papier de recherche","研究纸"],"icon":"cloth","color":"ddcba7","buy":3,"sell":1},
	"research_ink":{"names":["Исследовательские чернила","Research ink","Tinta de estudio","Forschungstinte","Encre de recherche","研究墨水"],"icon":"mana_potion","color":"52616f","buy":5,"sell":1},
	"wood_offcut":{"names":["Деревянные обрезки","Wood offcuts","Recortes de madera","Holzreste","Chutes de bois","木料边角"],"icon":"plank","color":"b88b58","buy":0,"sell":0},
	"cloth_scrap":{"names":["Лоскуты ткани","Cloth scraps","Retales de tela","Stoffreste","Chutes de tissu","布料碎片"],"icon":"cloth","color":"a9bda1","buy":0,"sell":0},
	"glass_shard":{"names":["Стеклянные осколки","Glass shards","Fragmentos de vidrio","Glasscherben","Éclats de verre","玻璃碎片"],"icon":"crystal","color":"b6d5d8","buy":0,"sell":0},
	"arcane_dust":{"names":["Кристальная пыль","Crystal dust","Polvo de cristal","Kristallstaub","Poudre de cristal","晶体粉末"],"icon":"blue_gem","color":"8fbee1","buy":0,"sell":0},
}
const COSTS := [{"coins":5,"energy":3,"inputs":{"research_paper":1,"research_ink":1}},{"coins":15,"energy":5,"inputs":{"research_paper":2,"research_ink":1}},{"coins":35,"energy":8,"inputs":{"research_paper":3,"research_ink":2}}]
const UPGRADES := [{"coins":120,"inputs":{"plank":8,"glass":3,"metal":4}},{"coins":300,"inputs":{"steel":3,"glass":6,"arcane_dust":2,"optical_lens":1}}]
const BASE_ENTRIES := [
	{"kind":"plank","tier":1,"batch":2,"parts":{"wood_offcut":2}},
	{"kind":"nails","tier":1,"batch":8,"parts":{"metal_scrap":1}},
	{"kind":"rope","tier":1,"batch":1,"parts":{"fiber":1}},
	{"kind":"cloth","tier":1,"batch":1,"parts":{"cloth_scrap":2}},
	{"kind":"yarn","tier":1,"batch":2,"parts":{"fiber":1}},
	{"kind":"wooden_chair","tier":1,"batch":1,"parts":{"wood_offcut":3,"metal_scrap":1}},
	{"kind":"rustic_table","tier":1,"batch":1,"parts":{"wood_offcut":6,"metal_scrap":1}},
	{"kind":"wooden_wardrobe","tier":1,"batch":1,"parts":{"wood_offcut":8,"metal_scrap":2}},
	{"kind":"woven_rug","tier":1,"batch":1,"parts":{"cloth_scrap":3,"fiber":1}},
	{"kind":"potted_fern","tier":1,"batch":1,"parts":{"fiber":1,"stone":1}},
	{"kind":"glass_vial","tier":1,"batch":1,"parts":{"glass_shard":1}},
	{"kind":"glass","tier":1,"batch":1,"parts":{"glass_shard":2}},
	{"kind":"crab_trap","tier":1,"batch":1,"parts":{"wood_offcut":3,"fiber":1,"metal_scrap":1}},
	{"kind":"sword","tier":1,"batch":1,"parts":{"wood_offcut":1,"slime":1}},
	{"kind":"iron_spear","tier":2,"batch":1,"parts":{"metal_scrap":4,"wood_offcut":2}},
	{"kind":"war_hammer","tier":2,"batch":1,"parts":{"metal_scrap":6,"stone":2}},
	{"kind":"iron_helmet","tier":2,"batch":1,"parts":{"metal_scrap":3}},
	{"kind":"guardian_armor","tier":2,"batch":1,"parts":{"metal_scrap":6,"arcane_dust":1}},
	{"kind":"oak_shield","tier":2,"batch":1,"parts":{"wood_offcut":3,"metal_scrap":1}},
	{"kind":"travel_boots","tier":2,"batch":1,"parts":{"cloth_scrap":2,"hide":1}},
	{"kind":"cauldron","tier":2,"batch":1,"parts":{"metal_scrap":4}},
	{"kind":"bow","tier":2,"batch":1,"parts":{"wood_offcut":2,"fiber":1}},
	{"kind":"orc_blade","tier":2,"batch":1,"parts":{"metal_scrap":3}},
	{"kind":"pirate_cutlass","tier":2,"batch":1,"parts":{"metal_scrap":3,"wood_offcut":1}},
	{"kind":"crystal_ring","tier":2,"batch":1,"parts":{"arcane_dust":1,"metal_scrap":2}},
	{"kind":"advanced_fishing_rod","tier":2,"batch":1,"parts":{"wood_offcut":2,"metal_scrap":2,"fiber":1}},
	{"kind":"crystal_sword","tier":3,"batch":1,"parts":{"arcane_dust":3,"metal_scrap":2}},
	{"kind":"moon_staff","tier":3,"batch":1,"parts":{"arcane_dust":4,"wood_offcut":2}},
	{"kind":"blue_gem","tier":3,"batch":1,"parts":{"arcane_dust":2}},
	{"kind":"crystal","tier":3,"batch":1,"parts":{"arcane_dust":2}},
]
static var ENTRIES: Array = BASE_ENTRIES+preload("res://scripts/systems/workshop_data.gd").RESEARCH_ENTRIES
const RECIPES := [
	{"id":"research:paper","name":"research_paper","output":"research_paper","inputs":{"fiber":2,"clean_water":1},"count":3,"research_supply":true,"category":"processing"},
	{"id":"research:ink","name":"research_ink","output":"research_ink","inputs":{"charcoal":1,"clean_water":1},"count":3,"research_supply":true,"category":"processing"},
	{"id":"recovery:plank","name":"plank","output":"plank","inputs":{"wood_offcut":4,"nails":1},"count":2,"study_kind":"plank","category":"processing"},
	{"id":"recovery:cloth","name":"cloth","output":"cloth","inputs":{"cloth_scrap":4,"fiber":1},"count":1,"study_kind":"cloth","category":"processing"},
	{"id":"recovery:chair","name":"wooden_chair","output":"wooden_chair","inputs":{"wood_offcut":5,"nails":2},"count":1,"study_kind":"wooden_chair","category":"construction"},
	{"id":"recovery:spear","name":"iron_spear","output":"iron_spear","inputs":{"metal_scrap":6,"plank":2,"nails":2},"count":1,"study_kind":"iron_spear","category":"equipment"},
	{"id":"recovery:helmet","name":"iron_helmet","output":"iron_helmet","inputs":{"metal_scrap":5,"stone":2},"count":1,"study_kind":"iron_helmet","category":"equipment"},
	{"id":"recovery:boots","name":"travel_boots","output":"travel_boots","inputs":{"cloth_scrap":4,"hide":2},"count":1,"study_kind":"travel_boots","category":"equipment"},
	{"id":"recovery:cauldron","name":"cauldron","output":"cauldron","inputs":{"metal_scrap":6,"stone":3},"count":1,"study_kind":"cauldron","talent":"farm_cooking","category":"equipment"},
	{"id":"recovery:glass","name":"glass","output":"glass","inputs":{"glass_shard":3},"count":1,"seconds":10.0,"furnace_level":1,"station":"furnace","study_kind":"glass"},
	{"id":"recovery:crystal","name":"crystal","output":"crystal","inputs":{"arcane_dust":3,"glass":1},"count":1,"study_kind":"crystal","category":"processing"},
]

## Находит исследуемый вид по каноническому идентификатору без принятия произвольного состава.
static func entry(kind: String) -> Dictionary:
	for value in ENTRIES:
		if value.kind==kind: return value
	return {}

## Дополняет переводимый каталог именами расходников и возвратных материалов.
static func names() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]=ITEMS[kind].names
	return result

## Регистрирует новые материалы в общей модели рюкзака.
static func inventory_items() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]={"name":ITEMS[kind].names[0],"short":String(ITEMS[kind].names[0]).left(9),"color":Color(ITEMS[kind].color)}
	return result

## Даёт лавке ограниченный запас бумаги и чернил, сохраняя добычу деталей только через разборку.
static func products() -> Array:
	var result:=[]
	for kind in ITEMS: result.append({"kind":kind,"buy":ITEMS[kind].buy,"sell":ITEMS[kind].sell,"daily_stock":8})
	return result
