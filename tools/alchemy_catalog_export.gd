extends SceneTree

## Выгружает точный игровой каталог для руководства и дизайна без запуска сцены или пользовательского сохранения.
func _initialize() -> void:
	var data:={"herbs":preload("res://scripts/systems/alchemy_herb_data.gd").HERBS,"items":preload("res://scripts/systems/alchemy_product_data.gd").names(),"potions":preload("res://scripts/systems/alchemy_product_data.gd").POTIONS,"recipes":preload("res://scripts/systems/alchemy_recipe_data.gd").recipes()}
	data.legacy={}
	var locale:=preload("res://scripts/systems/locale_system.gd")
	for recipe in data.recipes:
		for kind in recipe.inputs.keys()+[recipe.output]:
			if not data.items.has(kind): data.legacy[kind]=locale.ITEMS[kind]
	var file:=FileAccess.open("res://docs/design/alchemy-catalog.json",FileAccess.WRITE)
	if file==null: quit(1); return
	file.store_string(JSON.stringify(data,"\t")+"\n"); file.close(); print("ALCHEMY CATALOG: exported"); quit()
