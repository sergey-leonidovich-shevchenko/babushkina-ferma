extends RefCounted

const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const MIXES := [
	["glass_vial",{"crystal":1},3,1,"supplies"], ["distilled_water",{"clean_water":2},2,2,"supplies"],
	["herb_solvent",{"wheat":2,"honey":1},3,2,"supplies"], ["herb_oil",{"nut":2},1,1,"supplies"],
	["mineral_base",{"stone":2},2,1,"supplies"], ["animal_feed",{"herb_pulp":2,"wheat":1},2,1,"supplies"],
	["vital_essence",{"yarrow_tincture":1,"nettle_powder":1,"honey":1},2,3,"essence"],
	["ember_essence",{"ember_grass_tincture":1,"sunpetal_powder":1,"red_crystal":1},2,3,"essence"],
	["frost_essence",{"frost_fern_tincture":1,"silver_lichen_powder":1,"crystal":1},2,3,"essence"],
	["shadow_essence",{"ghost_orchid_tincture":1,"nightshade_powder":1,"ectoplasm":1},2,3,"essence"],
	["ether_essence",{"moon_grass_tincture":1,"starflower_powder":1,"crystal":1},2,3,"essence"],
	["meadow_tonic",{"chamomile_juice":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["clarity_drops",{"field_mint_juice":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["vigor_infusion",{"nettle_powder":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["honey_balm",{"red_clover_juice":1,"honey":1,"glass_vial":1},1,1,"potions"],
	["purifying_decoction",{"wormwood_powder":1,"wild_thyme_juice":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["hunter_elixir",{"ember_grass_powder":1,"bitter_root_tincture":1,"distilled_water":1,"glass_vial":1},1,2,"potions"],
	["stone_skin_draught",{"silver_lichen_powder":1,"juniper_tincture":1,"mineral_base":1,"glass_vial":1},1,2,"potions"],
	["wind_step_elixir",{"lemon_balm_tincture":1,"field_mint_powder":1,"distilled_water":1,"glass_vial":1},1,2,"potions"],
	["moon_veil_potion",{"shadow_essence":1,"valerian_tincture":1,"moon_grass_juice":1,"glass_vial":1},1,3,"potions"],
	["life_balsam",{"moon_moss_tincture":1,"sporecap_powder":1,"herb_oil":1,"glass_vial":1},1,3,"potions"],
	["greater_healing",{"vital_essence":1,"rosehip_tincture":1,"distilled_water":1,"glass_vial":1},1,3,"potions"],
	["greater_mana",{"ether_essence":1,"sage_tincture":1,"distilled_water":1,"glass_vial":1},1,3,"potions"],
	["balanced_elixir",{"frost_essence":1,"red_clover_tincture":1,"lemon_balm_juice":1,"glass_vial":1},1,3,"potions"],
	["insect_repellent",{"wild_thyme_powder":1,"wormwood_tincture":1,"herb_oil":1,"glass_vial":1},1,2,"potions"],
	["miners_oil",{"bitter_root_powder":1,"silver_lichen_tincture":1,"herb_oil":1,"glass_vial":1},1,2,"potions"],
	["solar_concentrate",{"ember_essence":1,"vital_essence":1,"sunpetal_tincture":1,"glass_vial":1},1,4,"potions"],
	["healing_potion",{"yarrow_juice":1,"rosehip_powder":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["mana_potion",{"field_mint_powder":1,"moon_grass_juice":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["energy_potion",{"nettle_juice":1,"lemon_balm_powder":1,"clean_water":1,"glass_vial":1},1,1,"potions"],
	["invisibility_potion",{"nightshade_powder":1,"valerian_tincture":1,"glass_vial":1},1,2,"potions"],
	["strength_potion",{"ember_grass_juice":1,"bitter_root_powder":1,"glass_vial":1},1,2,"potions"],
	["regeneration_potion",{"bloodthorn_tincture":1,"yarrow_powder":1,"glass_vial":1},1,2,"potions"],
	["speed_potion",{"lemon_balm_juice":1,"wild_thyme_tincture":1,"glass_vial":1},1,2,"potions"],
	["defense_potion",{"silver_lichen_juice":1,"juniper_powder":1,"mineral_base":1,"glass_vial":1},1,2,"potions"],
]

## Формирует проверяемые рецепты без изменения исторических индексов верстака и кухни.
static func recipes() -> Array:
	var result:=[]
	for herb in Herbs.HERBS:
		for form in Herbs.FORMS:
			var inputs:Dictionary={herb:2}; var count:=1; var rank:=1
			if form=="dried": count=2
			if form=="powder": inputs={herb+"_dried":2}
			if form=="tincture": inputs={herb+"_juice":1,"herb_solvent":1}; rank=2
			var recipe:=entry(herb+"_"+form,inputs,count,rank,form)
			if form=="juice": recipe.byproducts={"herb_pulp":1}
			result.append(recipe)
	for mix in MIXES: result.append(entry(mix[0],mix[1],mix[2],mix[3],mix[4]))
	return result

## Хранит требования ранга, таланта и лаборатории рядом с выходом каждой партии.
static func entry(output: String, inputs: Dictionary, count: int, rank: int, group: String) -> Dictionary:
	var result:={"name":output,"id":"alchemy:"+output,"output":output,"inputs":inputs,"count":count,"station":"alchemy","alchemy_rank":rank,"alchemy_group":group}
	if rank>=2: result.talent="craft_alchemy"
	if rank>=4: result.laboratory=true
	return result
