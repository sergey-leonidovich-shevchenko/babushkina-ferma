extends RefCounted

const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")

## Регистрирует продажу собранного сырья и изделий, оставляя покупку только у тары и чистой воды.
static func products() -> Array:
	var result:=[]
	for kind in Products.names():
		var herb:=Herbs.herb_for(kind); var price:=6
		if not herb.is_empty():
			price=2+int(Herbs.HERBS[herb].tier)*2
			if kind.ends_with("_powder"): price+=2
			if kind.ends_with("_tincture"): price+=4
		elif Products.POTIONS.has(kind): price=18
		elif kind.ends_with("_essence"): price=14
		elif kind=="herb_pulp": price=1
		var buy:=2 if kind in ["glass_vial","clean_water"] else 0
		result.append({"kind":kind,"buy":buy,"sell":0 if buy>0 else price,"daily_stock":8,"forage":Herbs.is_herb(kind)})
	return result
