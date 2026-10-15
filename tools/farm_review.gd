extends "res://tools/dev_cabinet_review.gd"

## Запускает хозяйственные сценарии отдельно от пользовательских сохранений и выгружает фактические каталоги.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-FARM-Review")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	var suite:=preload("res://tests/suites/farm_economy_suite.gd").new(self)
	var rows:=suite.household()
	preload("res://tests/suites/farm_recycling_suite.gd").new(self).run()
	preload("res://tests/suites/farm_seasons_suite.gd").new(self).run()
	preload("res://tests/suites/farm_livestock_loop_suite.gd").new(self).run()
	preload("res://tests/suites/farm_queue_suite.gd").new(self).run()
	preload("res://tests/suites/farm_alchemy_learning_suite.gd").new(self).run()
	var fishing:=preload("res://tests/suites/farm_fishing_access_suite.gd").new(self); fishing.run()
	preload("res://tests/suites/production_plan_suite.gd").new(self).run()
	var game:=make_game(); var consumed:={}
	for recipe in game.CraftingSystem.RECIPES:
		for kind in recipe.inputs: consumed[kind]=true
	var unused:Array=[]
	for kind in game.InventorySystem.ITEM_DATA:
		if not consumed.has(kind): unused.append(kind)
	var report:={"schema":1,"scope":"service-operation model; no walking time or human playtest","days":rows,"recipes":game.CraftingSystem.RECIPES,"products":game.ShopSystem.default_products(),"crops":game.CropCatalogSystem.CROPS,"not_recipe_inputs":unused,"stations":game.WorkshopSystem.Data.STATIONS}
	var output:="/private/tmp/farm-economy.json"
	report.research=game.ResearchSystem.Data.ENTRIES
	report.fishing=fishing.report
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	game.free(); print("FARM REVIEW: %d passed, %d failed; %s"%[passed,failed,output]); quit(0 if failed==0 else 1)
