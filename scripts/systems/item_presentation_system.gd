extends RefCounted

const RARITY_ORDER := ["common","uncommon","rare","epic","legendary"]
const RARITY_COLORS := {
	"common":Color("8a765b"), "uncommon":Color("5f914c"), "rare":Color("3f78b7"),
	"epic":Color("8953ad"), "legendary":Color("d08b32")
}
const RARITY_ITEMS := {
	"uncommon":["advanced_fishing_rod","crab_trap","cauldron","fruit_sapling","red_crystal","green_crystal","nails","rope","honey","pie","jam","soup","omelet","cornbread","iron_helmet","travel_boots","oak_shield"],
	"rare":["rare_seeds","blue_gem","crystal","healing_potion","mana_potion","energy_potion","invisibility_potion","strength_potion","regeneration_potion","speed_potion","defense_potion","guardian_armor","crystal_ring","orc_blade","iron_spear","war_hammer","pirate_cutlass","guild_badge"],
	"epic":["crystal_sword","moon_staff","ancient_key","moon_relic","cursed_compass"],
	"legendary":["eclipse_core"]
}
const BASE_FOOD_EFFECTS := {
	"carrot":["item_effect_heal",15], "apple":["item_effect_heal",30], "pear":["item_effect_heal_energy",24,2], "plum":["item_effect_heal_mana",20,8],
	"orange":["item_effect_heal_energy",20,2], "watermelon":["item_effect_heal_energy",25,4], "tomato":["item_effect_heal",10], "cabbage":["item_effect_heal",10], "corn":["item_effect_heal",10], "potato":["item_effect_heal",10], "onion":["item_effect_heal",10],
	"egg":["item_effect_heal_energy",14,2], "milk":["item_effect_heal_energy",14,2], "cheese":["item_effect_heal_energy",50,7], "honey":["item_effect_heal_energy",22,3], "bread":["item_effect_heal_energy",24,6], "butter":["item_effect_heal_energy",22,3],
	"pumpkin":["item_effect_heal_energy",28,4], "jam":["item_effect_heal_energy",60,8], "cornbread":["item_effect_heal_energy",28,4], "pie":["item_effect_heal_energy",80,10], "soup":["item_effect_heal_energy",40,6], "omelet":["item_effect_heal_energy",48,8],
	"mayonnaise":["item_effect_heal_energy",20,4], "pancakes":["item_effect_heal_energy",36,10], "porridge":["item_effect_heal_energy",24,8], "truffle_soup":["item_effect_heal_energy",48,8],
	"strawberry":["item_effect_heal_energy",15,2], "beet":["item_effect_heal",12], "pepper":["item_effect_heal_energy",12,1], "cucumber":["item_effect_heal_energy",10,1], "melon":["item_effect_heal_energy",25,4], "crab":["item_effect_heal_energy",22,3],
	"cherry":["item_effect_regeneration",5,6], "berries":["item_effect_regeneration",5,8], "nut":["item_effect_strength",1,12], "mushroom":["item_effect_speed",30,10],
	"healing_potion":["item_effect_heal",60], "mana_potion":["item_effect_mana",30], "energy_potion":["item_effect_energy",8], "invisibility_potion":["item_effect_invisibility",18],
	"strength_potion":["item_effect_strength",1,30], "regeneration_potion":["item_effect_regeneration",5,20], "speed_potion":["item_effect_speed",30,25], "defense_potion":["item_effect_defense",4,30]
}


static var FOOD_EFFECTS:Dictionary=BASE_FOOD_EFFECTS.merged(preload("res://scripts/systems/kitchen_data.gd").effects())

## Возвращает визуальную редкость предмета, не вмешиваясь в баланс выпадения и продажи.
static func rarity(kind:String)->String:
	var herbs:=preload("res://scripts/systems/alchemy_herb_data.gd"); var source:=herbs.herb_for(kind)
	if not source.is_empty(): return RARITY_ORDER[clampi(int(herbs.HERBS[source].tier)-1,0,3)]
	if kind=="solar_concentrate": return "legendary"
	if kind.ends_with("_essence") and preload("res://scripts/systems/alchemy_product_data.gd").ITEMS.has(kind): return "epic"
	if preload("res://scripts/systems/alchemy_product_data.gd").POTIONS.has(kind): return "rare"
	for rarity_id in ["legendary","epic","rare","uncommon"]:
		if kind in RARITY_ITEMS[rarity_id]: return rarity_id
	return "common"


## Возвращает цвет редкости для рамки, метки и сравнения предмета.
static func rarity_color(kind:String)->Color:
	return RARITY_COLORS[rarity(kind)]


## Формирует локализованное описание фактического эффекта еды или зелья.
static func effect_text(game:Node,kind:String)->String:
	if preload("res://scripts/systems/alchemy_product_data.gd").handles(kind): return preload("res://scripts/systems/alchemy_locale.gd").effect_text(game,kind)
	if not FOOD_EFFECTS.has(kind): return ""
	var effect:Array=FOOD_EFFECTS[kind]; return game.LocaleSystem.ui(String(effect[0]),effect.slice(1))


## Возвращает текущую прочность предмета либо минус один, если предмет не изнашивается.
static func durability(game:Node,kind:String)->int:
	var durability_kind:=kind
	if kind=="sword": durability_kind="sword"
	return int(game.state.inventory.durability.get(durability_kind,-1))


## Рассчитывает только бонусы выбранного предмета, чтобы сравнение не зависело от остальной экипировки героя.
static func stats(game:Node,kind:String)->Dictionary:
	var result:={}; var item:Dictionary=game.InventorySystem.data(kind); var slot:=String(item.get("equip",""))
	if slot=="hands":
		var weapon:String=game.WeaponSystem.weapon_for_item(kind); result.damage=game.WeaponSystem.damage_bonus(weapon)+game.ForgeSystem.weapon_damage_bonus(game,weapon)
	match kind:
		"iron_helmet": result.health=10+game.ForgeSystem.level(game,kind)*2; result.defense=game.ForgeSystem.level(game,kind)
		"guardian_armor": result.health=20+game.ForgeSystem.level(game,kind)*4; result.defense=game.ForgeSystem.level(game,kind)*2
		"oak_shield": result.health=5; result.defense=5+game.ForgeSystem.level(game,kind)
		"travel_boots": result.speed=10+game.ForgeSystem.level(game,kind)*2
		"crystal_ring": result.damage=1
		"guild_badge": result.health=10; result.damage=1
		"eclipse_core": result.health=15; result.damage=2
	return result


## Сравнивает экипируемый предмет с текущим предметом того же слота и возвращает дельты характеристик.
static func comparison(game:Node,kind:String)->Dictionary:
	var item:Dictionary=game.InventorySystem.data(kind); var slot:=String(item.get("equip",""))
	if slot.is_empty(): return {}
	var equipped:=String(game.equipment.get(slot,"")); var candidate_stats:=stats(game,kind); var equipped_stats:=stats(game,equipped) if not equipped.is_empty() else {}; var rows:Array[Dictionary]=[]
	for stat_id in ["damage","defense","health","speed"]:
		if not candidate_stats.has(stat_id) and not equipped_stats.has(stat_id): continue
		var candidate:=int(candidate_stats.get(stat_id,0)); var current:=int(equipped_stats.get(stat_id,0))
		rows.append({"id":stat_id,"current":current,"candidate":candidate,"delta":candidate-current})
	return {"slot":slot,"equipped":equipped,"same":equipped==kind,"rows":rows}
