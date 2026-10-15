extends RefCounted

const LESSONS := ["alchemy:chamomile_juice","alchemy:field_mint_juice","alchemy:nettle_dried","alchemy:nettle_powder","alchemy:red_clover_dried","alchemy:red_clover_powder","alchemy:wild_thyme_dried","alchemy:wild_thyme_powder","alchemy:meadow_tonic","alchemy:clarity_drops"]
const WORDS := {
	"next":["Учебный опыт %d/10","Learning experiment %d/10","Experimento guiado %d/10","Lernversuch %d/10","Expérience guidée %d/10","教学实验 %d/10"],
	"known":["Уже изготовлено","Already made","Ya elaborado","Bereits hergestellt","Déjà fabriqué","已制作"],
	"untried":["Ещё не изготовлено","Not made yet","Aún sin elaborar","Noch nicht hergestellt","Pas encore fabriqué","尚未制作"],
	"shop":["Лавка: вода и флаконы","Shop: water and vials","Tienda: agua y frascos","Laden: Wasser und Fläschchen","Boutique : eau et fioles","商店：水和空瓶"],
	"table":["Алхимический стол","Alchemy table","Mesa de alquimia","Alchemietisch","Table d’alchimie","炼金台"],
	"ready":["Ингредиенты в рюкзаке","Ingredients in backpack","Ingredientes en mochila","Zutaten im Rucksack","Ingrédients dans le sac","原料已在背包中"],
	"complete":["Десять опытов завершены; второй ранг открыт","Ten experiments done; rank two unlocked","Diez experimentos; rango dos desbloqueado","Zehn Versuche fertig; Rang zwei erreicht","Dix expériences terminées ; rang deux atteint","完成十次实验；解锁二阶"],
}

## Выдаёт короткую учебную строку без отдельной копии рецептурного каталога.
static func word(game: Node, id: String, values: Array=[]) -> String:
	var index:int=maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))
	var text:String=WORDS[id][index]
	return text%values if not values.is_empty() else text

## Находит первый ещё не выполненный опыт по постоянным открытиям, позволяя свободный порядок крафта.
static func next_id(game: Node) -> String:
	for id in LESSONS:
		if id not in game.CraftingSystem.Alchemy.state(game).discovered: return id
	return ""

## Разделяет уже сделанный препарат, ближайший учебный шаг и пока не опробованный рецепт.
static func status(game: Node, recipe: Dictionary) -> String:
	var id:=String(recipe.get("id",""))
	if id in game.CraftingSystem.Alchemy.state(game).discovered: return word(game,"known")
	return word(game,"next",[LESSONS.find(id)+1]) if id==next_id(game) else word(game,"untried")

## Находит реальные источники ближайших ингредиентов, не выдавая сырьё и не открывая всю ветку.
static func sources(game: Node, recipe: Dictionary) -> String:
	var herbs:=preload("res://scripts/systems/alchemy_herb_data.gd"); var rows:Array[String]=[]
	for kind in recipe.inputs:
		if game.inventory_item_count(kind)>=int(recipe.inputs[kind]): continue
		var source:String
		if herbs.HERBS.has(kind): source=game.LocaleSystem.location(herbs.HERBS[kind].location)
		elif kind in ["glass_vial","clean_water"]:
			if word(game,"shop") not in rows: rows.append(word(game,"shop"))
			continue
		else: source=word(game,"table")
		var row:String=game.inventory_item_name(kind)+" — "+source
		if row not in rows: rows.append(row)
	return "; ".join(rows) if not rows.is_empty() else word(game,"ready")

## Выбирает ближайший учебный рецепт только внутри текущего фильтра и показывает источник его сырья.
static func open_hint(game: Node, visible: Array[int]) -> void:
	var id:=next_id(game)
	if id.is_empty(): game.message=word(game,"complete"); return
	var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")==id)
	if index not in visible: return
	game.crafting_selected=index
	var recipe:Dictionary=game.CraftingSystem.RECIPES[index]
	game.message=status(game,recipe)+": "+sources(game,recipe); game.notify_tutorial("alchemy_learning")
