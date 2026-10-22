extends RefCounted

const RECIPES := [
	{"id":"sawmill:planks","station":"sawmill","output":"plank","inputs":{"log":1},"count":4,"seconds":8.0,"workshop_level":1,"energy":1,"byproducts":{"sawdust":2}},
	{"id":"sawmill:beam","station":"sawmill","output":"wood_beam","inputs":{"plank":2},"count":1,"seconds":8.0,"workshop_level":1,"energy":1,"byproducts":{"sawdust":1}},
	{"id":"sawmill:offcuts","station":"sawmill","output":"wood","inputs":{"wood_offcut":4},"count":2,"seconds":6.0,"workshop_level":1,"energy":1,"byproducts":{"sawdust":1}},
	{"id":"sawmill:dowels","station":"sawmill","output":"wood_dowel","inputs":{"plank":2},"count":4,"seconds":10.0,"workshop_level":2,"energy":2,"byproducts":{"sawdust":1}},
	{"id":"sawmill:handle","station":"sawmill","output":"wood_handle","inputs":{"wood_beam":1,"wood_dowel":2},"count":2,"seconds":10.0,"workshop_level":2,"energy":2},
	{"id":"sawmill:frame","station":"sawmill","output":"timber_frame","inputs":{"wood_beam":2,"nails":4},"count":1,"seconds":12.0,"workshop_level":2,"energy":2},
	{"id":"sawmill:paper","station":"sawmill","output":"research_paper","inputs":{"sawdust":3,"clean_water":1},"count":3,"seconds":10.0,"workshop_level":2,"energy":1},
	{"id":"sawmill:wardrobe","station":"sawmill","output":"wooden_wardrobe","inputs":{"timber_frame":1,"plank":8,"cloth":1},"count":1,"seconds":18.0,"workshop_level":3,"energy":3},
	{"id":"sawmill:spear","station":"sawmill","output":"iron_spear","inputs":{"wood_handle":1,"metal":4,"nails":1},"count":1,"seconds":16.0,"workshop_level":3,"energy":3,"study_kind":"iron_spear"},
	{"id":"pottery:clay","station":"pottery","output":"wet_clay","inputs":{"clay":2,"clean_water":1},"count":2,"seconds":6.0,"workshop_level":1,"energy":1},
	{"id":"pottery:brick","station":"pottery","output":"unfired_brick","inputs":{"wet_clay":1},"count":2,"seconds":8.0,"workshop_level":1,"energy":1},
	{"id":"pottery:pot","station":"pottery","output":"unfired_pot","inputs":{"wet_clay":2},"count":1,"seconds":10.0,"workshop_level":1,"energy":2},
	{"id":"pottery:bowl","station":"pottery","output":"unfired_bowl","inputs":{"wet_clay":1},"count":1,"seconds":8.0,"workshop_level":1,"energy":1},
	{"id":"pottery:vase","station":"pottery","output":"unfired_vase","inputs":{"wet_clay":2,"sand":1},"count":1,"seconds":12.0,"workshop_level":2,"energy":2},
	{"id":"pottery:glaze","station":"pottery","output":"ceramic_glaze","inputs":{"mineral_base":1,"clean_water":1},"count":2,"seconds":8.0,"workshop_level":2,"energy":1},
	{"id":"pottery:glazed","station":"pottery","output":"glazed_vase_form","inputs":{"unfired_vase":1,"ceramic_glaze":1},"count":1,"seconds":12.0,"workshop_level":2,"energy":2},
	{"id":"pottery:porcelain_clay","station":"pottery","output":"porcelain_clay","inputs":{"clay":2,"sand":1,"distilled_water":1},"count":2,"seconds":10.0,"workshop_level":3,"energy":2},
	{"id":"pottery:porcelain","station":"pottery","output":"porcelain_form","inputs":{"porcelain_clay":1,"ceramic_glaze":1},"count":1,"seconds":16.0,"workshop_level":3,"energy":3},
	{"id":"pottery:recycle","station":"pottery","output":"clay","inputs":{"ceramic_shard":4,"clean_water":1},"count":1,"seconds":8.0,"workshop_level":2,"energy":1},
	{"id":"pottery:planter","station":"pottery","output":"potted_fern","inputs":{"clay_pot":1,"fiber":2,"flower":2},"count":1,"seconds":10.0,"workshop_level":2,"energy":1},
	{"id":"glassblowing:vials","station":"glassblowing","output":"glass_vial","inputs":{"glass":1},"count":3,"seconds":6.0,"workshop_level":1,"energy":1},
	{"id":"glassblowing:bottle","station":"glassblowing","output":"glass_bottle","inputs":{"glass":1},"count":1,"seconds":8.0,"workshop_level":1,"energy":1},
	{"id":"glassblowing:jar","station":"glassblowing","output":"glass_jar","inputs":{"glass":2},"count":2,"seconds":10.0,"workshop_level":1,"energy":2},
	{"id":"glassblowing:colored","station":"glassblowing","output":"colored_glass","inputs":{"glass":2,"red_crystal":1},"count":2,"seconds":12.0,"workshop_level":2,"energy":2},
	{"id":"glassblowing:clear","station":"glassblowing","output":"clear_glass","inputs":{"glass":2,"distilled_water":1},"count":2,"seconds":12.0,"workshop_level":2,"energy":2},
	{"id":"glassblowing:lens","station":"glassblowing","output":"optical_lens","inputs":{"clear_glass":2,"arcane_dust":1},"count":1,"seconds":16.0,"workshop_level":2,"energy":3},
	{"id":"glassblowing:moon","station":"glassblowing","output":"moon_glass","inputs":{"clear_glass":2,"moon_grass_powder":1,"arcane_dust":1},"count":1,"seconds":18.0,"workshop_level":3,"energy":3},
	{"id":"glassblowing:staff","station":"glassblowing","output":"moon_staff","inputs":{"wood_handle":2,"moon_glass":2,"crystal":2},"count":1,"seconds":20.0,"workshop_level":3,"energy":3,"study_kind":"moon_staff"},
	{"id":"kiln:brick","station":"furnace","output":"brick","inputs":{"unfired_brick":2},"count":2,"seconds":12.0,"furnace_level":1},
	{"id":"kiln:pot","station":"furnace","output":"clay_pot","inputs":{"unfired_pot":1},"count":1,"seconds":14.0,"furnace_level":1},
	{"id":"kiln:bowl","station":"furnace","output":"ceramic_bowl","inputs":{"unfired_bowl":1},"count":1,"seconds":10.0,"furnace_level":1},
	{"id":"kiln:vase","station":"furnace","output":"ceramic_vase","inputs":{"unfired_vase":1},"count":1,"seconds":18.0,"furnace_level":2},
	{"id":"kiln:glazed","station":"furnace","output":"glazed_vase","inputs":{"glazed_vase_form":1},"count":1,"seconds":20.0,"furnace_level":2},
	{"id":"kiln:porcelain","station":"furnace","output":"porcelain_cup","inputs":{"porcelain_form":1},"count":1,"seconds":22.0,"furnace_level":3},
	{"id":"workshop:ink","output":"research_ink","inputs":{"glass_bottle":1,"charcoal":1,"clean_water":2},"count":6,"research_supply":true,"category":"processing"},
	{"id":"workshop:porridge","station":"cauldron","output":"porridge","inputs":{"wheat":3,"milk":2,"ceramic_bowl":1},"count":2,"category":"food"},
	{"id":"workshop:jam","station":"cauldron","output":"jam","inputs":{"berries":4,"honey":2,"glass_jar":1},"count":2,"talent":"farm_cooking","category":"food"},
]
static var _recipes:Dictionary={}

## Находит каноническую технологию за постоянное время после первого построения общего индекса.
static func recipe(id: String) -> Dictionary:
	if _recipes.is_empty():
		for entry in RECIPES+preload("res://scripts/systems/artisan_recipe_data.gd").RECIPES: _recipes[entry.id]=entry
	return _recipes.get(id,{})

## Даёт обычным предметным окнам полный каталог с именами для существующих помощников.
static func recipes() -> Array:
	var result:=(RECIPES+preload("res://scripts/systems/artisan_recipe_data.gd").RECIPES.filter(func(value): return value.station!="alchemy")).duplicate(true)
	for entry in result: entry.name=entry.output
	return result
