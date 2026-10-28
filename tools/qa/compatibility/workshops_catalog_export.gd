extends SceneTree

const Game := preload("res://scripts/game.gd")
const Workshop := preload("res://scripts/systems/workshop_system.gd")

## Экспортирует живые технологии, изделия и цены улучшений без второго вручную составленного каталога.
func _initialize() -> void:
	var game:=Game.new(); game.audio_enabled=false; game._ready(); game.LocaleSystem.current="ru"
	var payload:={"items":Workshop.Data.ITEMS,"stations":Workshop.Data.STATIONS,"recipes":Workshop.Data.Recipes.RECIPES,"research":Workshop.Data.RESEARCH_ENTRIES,"fuels":Workshop.Fuel.FUELS}
	var file:=FileAccess.open("res://docs/design/workshops/catalog.json",FileAccess.WRITE)
	if file==null: game.free(); quit(1); return
	file.store_string(JSON.stringify(payload,"  ")+"\n"); file.close()
	var text:="# Технологии ремесленной мастерской\n\nСгенерированы из WorkshopRecipeData. Время — базовые активные секунды до ускорения станка; энергия резервируется при постановке партии. Обжиг расходует жар горна, стеклодув — свой отдельный запас. Верстак и кухня создают результат сразу.\n\n| Станция | Изделие | Уровень | Сырьё | Выход | Побочный выход | Время | Энергия | Изучить |\n| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
	for recipe in Workshop.Data.Recipes.RECIPES:
		var station:String=recipe.get("station","workbench"); var label:String=game.LocaleSystem.ui(station+"_service") if Workshop.handles(station) else ("Горн" if station=="furnace" else ("Кухня" if station=="cauldron" else "Верстак"))
		text+="| %s | %s | %d | %s | %d | %s | %s | %d | %s |\n"%[label,game.inventory_item_name(recipe.output),recipe.get("workshop_level",recipe.get("furnace_level",1)),game.ResearchSystem.material_text(game,recipe.inputs),recipe.count,game.ResearchSystem.material_text(game,recipe.get("byproducts",{})),str(recipe.get("seconds","—")),recipe.get("energy",0),game.inventory_item_name(recipe.study_kind) if recipe.has("study_kind") else "—"]
	file=FileAccess.open("res://docs/design/workshops/recipes.md",FileAccess.WRITE)
	if file==null: game.free(); quit(1); return
	file.store_string(text); file.close(); print("WORKSHOPS CATALOG: %d items, %d recipes"%[Workshop.Data.ITEMS.size(),Workshop.Data.Recipes.RECIPES.size()]); game.free(); quit()
