extends RefCounted

const Graph := preload("res://scripts/systems/production_graph_system.gd")
const Plan := preload("res://scripts/systems/production_plan_system.gd")

## Выгружает общий граф и отдельные эталоны игрового расчёта для проверки браузерного планировщика.
static func build(ctx: Object) -> Dictionary:
	var graph:=Graph.catalog(ctx.game); var cases:Array=[]
	for index in graph.recipes.size():
		cases.append({"index":index,"batches":1,"stock":{},"choices":{},"options":{},"result":Plan.plan(graph.recipes,index)})
	for output in ["bread","woven_rug","wax_base","glass_bottle"]:
		var index:int=graph.recipes.find_custom(func(recipe): return recipe.output==output)
		for batches in [2,7,99]:
			var stock:={"wheat":5,"flour":1,"glass":1,"honeycomb":2}; var options:={"master":true,"counter":4}
			var choices:={}
			if output=="glass_bottle": choices.glass=graph.recipes.find_custom(func(recipe): return recipe.id=="recovery:glass")
			if output=="woven_rug":
				options.costs={}
				for recipe_index in graph.recipes.size():
					var costs:={}
					for kind in graph.recipes[recipe_index].inputs: costs[kind]=1
					options.costs[str(recipe_index)]=costs
			cases.append({"index":index,"batches":batches,"stock":stock,"choices":choices,"options":options,"result":Plan.plan(graph.recipes,index,stock,batches,choices,options)})
	var file:=FileAccess.open(ctx.output+"production-cases.json",FileAccess.WRITE)
	if file==null: ctx.failed=true; push_error("Не удалось записать эталоны производственного плана")
	else: file.store_string(JSON.stringify(cases)); file.close()
	return graph
