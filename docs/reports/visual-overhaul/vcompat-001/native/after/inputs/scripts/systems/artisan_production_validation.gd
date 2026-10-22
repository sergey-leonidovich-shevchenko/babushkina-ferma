extends RefCounted

const Data := preload("res://scripts/systems/artisan_data.gd")
const Recipes := preload("res://scripts/systems/workshop_recipe_data.gd")

## Проверяет каноническую оплату и длительность новых партий до применения сохранения.
static func valid(item: Dictionary) -> bool:
	if not Data.STATIONS.has(item.kind): return true
	if float(item.production.heat)>120*int(item.level): return false
	for job in item.production.queue:
		var recipe:Dictionary=Recipes.recipe(String(job.id))
		if recipe.get("station","")!=item.kind or job.get("paid",{}).size()!=recipe.inputs.size(): return false
		var expected:float=float(recipe.seconds)/[1.0,1.35,1.7][int(item.level)-1]
		if not is_equal_approx(float(job.duration),expected): return false
		for kind in job.paid:
			if not recipe.inputs.has(kind) or float(job.paid[kind])!=int(recipe.inputs[kind]): return false
	return true
