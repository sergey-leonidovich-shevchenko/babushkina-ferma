extends SceneTree

const Game := preload("res://scripts/game.gd")
const Data := preload("res://scripts/systems/research_data.gd")

## Экспортирует фактический каталог изучения и повторной сборки, не поддерживая вручную второй набор чисел.
func _initialize() -> void:
	var game:=Game.new(); game.audio_enabled=false; game._ready(); game.LocaleSystem.current="ru"
	var payload:={"items":Data.ITEMS,"study_costs":Data.COSTS,"upgrades":Data.UPGRADES,"entries":Data.ENTRIES,"recipes":Data.RECIPES}
	var file:=FileAccess.open("res://docs/design/research-catalog.json",FileAccess.WRITE)
	if file==null: game.free(); quit(1); return
	file.store_string(JSON.stringify(payload,"  ")+"\n"); file.close()
	var text:="# Каталог изучения и разборки\n\nСгенерирован из ResearchData. Изучение сохраняет один образец; стол требуемого уровня открывает знания навсегда. Разборка уничтожает полную указанную партию и расходует две единицы энергии на уровень сложности. Выход ниже указан для исправных вещей; износ уменьшает его до половины с округлением вниз и минимумом одного элемента каждого вида.\n\n| Вещь | Уровень | Партия разборки | Детали |\n| --- | --- | --- | --- |\n"
	for entry in Data.ENTRIES: text+="| %s | %d | %d | %s |\n"%[game.inventory_item_name(entry.kind),entry.tier,entry.batch,game.ResearchSystem.material_text(game,entry.parts)]
	text+="\n## Новые рецепты\n\nСкидка и двойной выход верстака не применяются. Прежние рецепты сохраняются.\n\n| Рецепт | Сырьё | Выход | Требуется изучить | Станция |\n| --- | --- | --- | --- | --- |\n"
	for recipe in Data.RECIPES:
		text+="| %s | %s | %d | %s | %s |\n"%[game.inventory_item_name(recipe.output),game.ResearchSystem.material_text(game,recipe.inputs),recipe.count,game.inventory_item_name(recipe.study_kind) if recipe.has("study_kind") else "—","Горн" if recipe.get("station","")=="furnace" else "Верстак"]
	file=FileAccess.open("res://docs/design/research-recipes.md",FileAccess.WRITE)
	if file==null: game.free(); quit(1); return
	file.store_string(text); file.close(); print("RESEARCH CATALOG: %d types, %d recipes"%[Data.ENTRIES.size(),Data.RECIPES.size()]); game.free(); quit()
