extends RefCounted

const FUELS := {"wood":12.0,"log":32.0,"charcoal":24.0}
const SPEED := [1.0,1.25,1.5]
const EFFICIENCY := [1.0,1.2,1.5]
const LEVELS := {"omelet":2,"pancakes":2,"cheese":2,"bread":3,"cornbread":3,"pie":3,"fried_vegetables":2,"baked_potato":3,"vegetable_casserole":3,"mushroom_pie":3}
const COLD := ["flour","butter","mayonnaise"]
const TIMES := {"flour":4.0,"butter":4.0,"mayonnaise":4.0,"soup":8.0,"porridge":8.0,"truffle_soup":12.0,"jam":12.0,"omelet":10.0,"pancakes":10.0,"cheese":14.0,"bread":16.0,"cornbread":18.0,"pie":20.0}
const LEGACY_RECIPES := [
	{"id":"kitchen:flour","name":"Мука", "inputs":{"wheat":2}, "output":"flour", "count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:butter","name":"Сливочное масло", "inputs":{"milk":2}, "output":"butter", "count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:cheese","name":"Домашний сыр", "inputs":{"milk":3}, "output":"cheese", "count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:bread","name":"Деревенский хлеб", "inputs":{"flour":2}, "output":"bread", "count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:pie","name":"Яблочный пирог", "inputs":{"apple":2,"flour":1,"butter":1}, "output":"pie", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"id":"kitchen:jam","name":"Ягодное варенье", "inputs":{"berries":3,"honey":1}, "output":"jam", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"id":"kitchen:soup","name":"Овощной суп", "inputs":{"carrot":1,"potato":1,"onion":1}, "output":"soup", "count":1, "station":"cauldron","category":"food"},
	{"id":"kitchen:omelet","name":"Омлет с зеленью", "inputs":{"egg":2,"milk":1}, "output":"omelet", "count":1, "station":"cauldron","category":"food"},
	{"id":"kitchen:cornbread","name":"Кукурузный хлеб", "inputs":{"corn":2,"flour":1}, "output":"cornbread", "count":1, "station":"cauldron", "talent":"farm_cooking"},
	{"id":"kitchen:mayonnaise","name":"Домашний майонез","inputs":{"egg":1},"output":"mayonnaise","count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:pancakes","name":"Молочные блинчики","inputs":{"flour":1,"egg":1,"milk":1},"output":"pancakes","count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:porridge","name":"Молочная каша","inputs":{"wheat":2,"milk":1},"output":"porridge","count":1,"station":"cauldron","category":"food"},
	{"id":"kitchen:truffle_soup","name":"Трюфельная похлёбка","inputs":{"truffle":1,"milk":1,"mushroom":1},"output":"truffle_soup","count":1,"station":"cauldron","category":"food","talent":"farm_cooking"},
]
const NEW_RECIPES := [
	{"id":"kitchen:fried_vegetables","name":"Жареные овощи","station":"cauldron","output":"fried_vegetables","inputs":{"potato":2,"carrot":1,"onion":1},"count":2,"seconds":10.0,"energy":1,"private_kitchen":true},
	{"id":"kitchen:baked_potato","name":"Печёный картофель","station":"cauldron","output":"baked_potato","inputs":{"potato":2,"butter":1},"count":2,"seconds":14.0,"energy":1,"private_kitchen":true},
	{"id":"kitchen:vegetable_casserole","name":"Овощная запеканка","station":"cauldron","output":"vegetable_casserole","inputs":{"potato":2,"egg":1,"milk":1},"count":2,"seconds":18.0,"energy":2,"private_kitchen":true},
	{"id":"kitchen:mushroom_pie","name":"Грибной пирог","station":"cauldron","output":"mushroom_pie","inputs":{"mushroom":2,"flour":1,"butter":1},"count":1,"seconds":20.0,"energy":2,"private_kitchen":true},
]
const ITEMS := {
	"fried_vegetables":{"names":["Жареные овощи","Fried vegetables","Verduras salteadas","Gebratenes Gemüse","Légumes sautés","炒蔬菜"],"color":"c69452","sell":12,"effect":["item_effect_heal_energy",28,5]},
	"baked_potato":{"names":["Печёный картофель","Baked potato","Patata asada","Ofenkartoffel","Pomme de terre au four","烤土豆"],"color":"cba260","sell":14,"effect":["item_effect_heal_energy",32,7]},
	"vegetable_casserole":{"names":["Овощная запеканка","Vegetable casserole","Pastel de verduras","Gemüseauflauf","Gratin de légumes","蔬菜焗烤"],"color":"bd8850","sell":20,"effect":["item_effect_heal_energy",42,9]},
	"mushroom_pie":{"names":["Грибной пирог","Mushroom pie","Pastel de setas","Pilzpastete","Tourte aux champignons","蘑菇派"],"color":"b57d46","sell":26,"effect":["item_effect_heal_energy",64,10]},
}
static var _recipes:Dictionary={}

## Находит каноническую кухонную партию независимо от игрового узла, языка и порядкового индекса.
static func recipe(id: String) -> Dictionary:
	if _recipes.is_empty():
		for entry in LEGACY_RECIPES+NEW_RECIPES: _recipes[entry.id]=entry
	if _recipes.has(id): return _recipes[id]
	var batch:Dictionary=preload("res://scripts/systems/workshop_recipe_data.gd").recipe(id)
	return batch if batch.get("station","")=="cauldron" else {}

## Ограничивает сложность только личной кухни по настоящему способу готовки блюда.
static func level(recipe_value: Dictionary) -> int:
	return int(LEVELS.get(recipe_value.output,1))

## Рассчитывает длительность, учитывая число порций старого пакетного рецепта.
static func seconds(recipe_value: Dictionary) -> float:
	return float(recipe_value.get("seconds",float(TIMES.get(recipe_value.output,8))*int(recipe_value.count)))

## Возвращает целую стоимость постановки партии до резервирования ингредиентов.
static func energy(recipe_value: Dictionary) -> int:
	return int(recipe_value.get("energy",2 if recipe_value.output=="pie" else maxi(1,int(recipe_value.count))))

## Регистрирует четыре готовых блюда как обычные съедобные предметы.
static func inventory_items() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]={"name":ITEMS[kind].names[0],"short":ITEMS[kind].names[0],"color":Color(ITEMS[kind].color),"edible":true}
	return result

## Дополняет общий языковой каталог названиями новых блюд на шести языках.
static func names() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]=ITEMS[kind].names
	return result

## Даёт подсказке и употреблению пищи единый источник восстановительных эффектов.
static func effects() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]=ITEMS[kind].effect
	return result

## Даёт продаже готовые блюда без возможности купить их как бесплатный обход печи.
static func products() -> Array:
	var result:Array=[]
	for kind in ITEMS: result.append({"kind":kind,"buy":0,"sell":ITEMS[kind].sell})
	return result
