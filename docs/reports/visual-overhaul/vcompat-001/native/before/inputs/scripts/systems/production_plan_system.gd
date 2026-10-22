extends RefCounted

const MAX_DEPTH := 12
const MAX_OPERATIONS := 4096

## Рассчитывает точные партии на независимом виртуальном складе, ничего не списывая в игре.
static func plan(recipes: Array, index: int, stock: Dictionary={}, batches: int=1, choices: Dictionary={}, options: Dictionary={}) -> Dictionary:
	var value:={"recipes":recipes,"stock":stock.duplicate(true),"missing":{},"steps":[],"warnings":[],"operations":0,"truncated":false,"choices":choices,"options":options,"counter":int(options.get("counter",0)),"output_count":0}
	if index<0 or index>=recipes.size(): return {"missing":{},"steps":[],"warnings":["recipe"],"truncated":true,"output_count":0,"remaining":{}}
	var recipe:Dictionary=recipes[index]
	value.outputs={}
	for recipe_index in recipes.size():
		var entry:Dictionary=recipes[recipe_index]
		for kind in [entry.output]+entry.get("byproducts",{}).keys():
			if not value.outputs.has(kind): value.outputs[kind]=[]
			if recipe_index not in value.outputs[kind]: value.outputs[kind].append(recipe_index)
	for batch in clampi(batches,1,999):
		var amount:=_batch(value,index,[String(recipe.output)],0)
		if amount<0: break
		value.output_count+=amount; value.stock[recipe.output]=int(value.stock.get(recipe.output,0))-amount
	var remaining:={}
	for kind in value.stock:
		if int(value.stock[kind])>0: remaining[kind]=int(value.stock[kind])
	return {"missing":value.missing,"steps":value.steps,"warnings":value.warnings,"truncated":value.truncated,"output_count":value.output_count,"remaining":remaining}

## Регистрирует действительно недостающее внешнее сырьё, включая конечный выход из циклической ссылки.
static func _missing(value: Dictionary, kind: String, amount: int, warning: String="") -> void:
	value.missing[kind]=int(value.missing.get(kind,0))+amount
	if not warning.is_empty() and warning not in value.warnings: value.warnings.append(warning)

## Потребляет имеющийся запас, затем достраивает только недостающие полные партии с повторным использованием остатков.
static func _need(value: Dictionary, kind: String, amount: int, path: Array, depth: int) -> void:
	var taken:=mini(maxi(0,int(value.stock.get(kind,0))),amount)
	value.stock[kind]=int(value.stock.get(kind,0))-taken; amount-=taken
	if amount<=0: return
	if kind in path or depth>=MAX_DEPTH:
		_missing(value,kind,amount,"cycle:"+kind if kind in path else "depth:"+kind); return
	var candidates:Array=value.outputs.get(kind,[])
	if candidates.is_empty(): _missing(value,kind,amount); return
	var index:int=int(value.choices.get(kind,candidates[0]))
	if index not in candidates: index=candidates[0]
	while amount>0:
		if _batch(value,index,path+[kind],depth+1)<0: return
		taken=mini(maxi(0,int(value.stock.get(kind,0))),amount)
		if taken<=0: value.truncated=true; return
		value.stock[kind]=int(value.stock.get(kind,0))-taken; amount-=taken

## Сначала оплачивает виртуальные ингредиенты, затем применяет реальный порядок ремесленного бонуса и побочных выходов.
static func _batch(value: Dictionary, index: int, path: Array, depth: int) -> int:
	value.operations+=1
	if int(value.operations)>MAX_OPERATIONS: value.truncated=true; return -1
	var recipe:Dictionary=value.recipes[index]
	if int(recipe.count)<=0: value.truncated=true; return -1
	var costs:Dictionary=value.options.get("costs",{}).get(str(index),recipe.inputs)
	var input_kinds:Array=recipe.inputs.keys(); input_kinds.sort()
	for kind in input_kinds:
		_need(value,kind,maxi(1,int(costs.get(kind,recipe.inputs[kind]))),path,depth)
		if value.truncated: return -1
	var count:int=recipe.count
	if recipe.get("station","workbench")=="workbench":
		value.counter+=1
		if value.options.get("master",false) and int(value.counter)%5==0 and not recipe.get("no_bonus",false): count*=2
	value.stock[recipe.output]=int(value.stock.get(recipe.output,0))+count
	for kind in recipe.get("byproducts",{}): value.stock[kind]=int(value.stock.get(kind,0))+int(recipe.byproducts[kind])
	value.steps.append({"index":index,"id":String(recipe.get("id","legacy-"+str(index))),"count":count,"target":String(path[-1])})
	return count
