extends RefCounted

const ITEMS := {
	"iron_ore":{"names":["Железная руда","Iron ore","Mineral de hierro","Eisenerz","Minerai de fer","铁矿石"],"icon":"stone","tint":"b2aa9b","buy":0,"sell":3},
	"metal_scrap":{"names":["Металлолом","Metal scrap","Chatarra","Metallschrott","Ferraille","废金属"],"icon":"metal","tint":"8f9996","buy":4,"sell":2},
	"sand":{"names":["Песок","Sand","Arena","Sand","Sable","沙子"],"icon":"stone","tint":"dac59a","buy":2,"sell":1},
	"coal":{"names":["Каменный уголь","Coal","Carbón mineral","Kohle","Charbon","煤炭"],"icon":"stone","tint":"64646a","buy":5,"sell":3},
	"trash":{"names":["Горючий мусор","Burnable trash","Basura combustible","Brennbarer Müll","Déchets combustibles","可燃垃圾"],"icon":"fiber","tint":"9b9e7f","buy":1,"sell":0},
	"charcoal":{"names":["Древесный уголь","Charcoal","Carbón vegetal","Holzkohle","Charbon de bois","木炭"],"icon":"wood","tint":"494649","buy":0,"sell":3},
	"glass":{"names":["Стекло","Glass","Vidrio","Glas","Verre","玻璃"],"icon":"crystal","tint":"c4e1df","buy":0,"sell":5},
	"steel":{"names":["Стальной слиток","Steel ingot","Lingote de acero","Stahlbarren","Lingot d’acier","钢锭"],"icon":"metal","tint":"b8cbd7","buy":0,"sell":18},
	"slag":{"names":["Металлический шлак","Metal slag","Escoria metálica","Metallschlacke","Scories métalliques","金属炉渣"],"icon":"stone","tint":"9c8d7f","buy":0,"sell":1},
}
const FUELS := {"wood":12.0,"log":32.0,"coal":36.0,"charcoal":24.0,"trash":4.0}
const SPEED := [1.0,1.35,1.7]
const EFFICIENCY := [1.0,1.25,1.5]
const UPGRADES := [{"coins":80,"inputs":{"metal":4,"stone":12}},{"coins":200,"inputs":{"steel":3,"glass":4,"metal":4}}]
const RECIPES := [
	{"id":"furnace:ore","output":"metal","inputs":{"iron_ore":2},"count":1,"seconds":12.0,"furnace_level":1,"station":"furnace","byproducts":{"slag":1}},
	{"id":"furnace:scrap","output":"metal","inputs":{"metal_scrap":2},"count":1,"seconds":10.0,"furnace_level":1,"station":"furnace","byproducts":{"slag":1}},
	{"id":"furnace:glass","output":"glass","inputs":{"sand":3},"count":2,"seconds":14.0,"furnace_level":1,"station":"furnace"},
	{"id":"furnace:vials","output":"glass_vial","inputs":{"glass":1},"count":3,"seconds":8.0,"furnace_level":1,"station":"furnace"},
	{"id":"furnace:charcoal","output":"charcoal","inputs":{"wood":2},"count":2,"seconds":18.0,"furnace_level":1,"station":"furnace"},
	{"id":"furnace:steel","output":"steel","inputs":{"metal":2,"coal":1},"count":1,"seconds":20.0,"furnace_level":2,"station":"furnace"},
	{"id":"furnace:slag","output":"metal","inputs":{"slag":3},"count":1,"seconds":16.0,"furnace_level":3,"station":"furnace"},
]
const SPAWNS := [
	{"position":Vector2(960,760),"location":"rocky","kind":"iron_ore","hits":6},
	{"position":Vector2(1464,960),"location":"rocky","kind":"iron_ore","hits":6},
	{"position":Vector2(1872,720),"location":"rocky","kind":"coal","hits":6},
	{"position":Vector2(576,840),"location":"rocky","kind":"sand","hits":6},
	{"position":Vector2(600,1040),"location":"rocky","kind":"metal_scrap","hits":4},
	{"position":Vector2(1920,960),"location":"rocky","kind":"trash","hits":4},
]

## Дополняет общий языковой каталог без изменения исторических имён материалов.
static func names() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]=ITEMS[kind].names
	return result

## Регистрирует несъедобные материалы горна в единой модели инвентаря.
static func inventory_items() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]={"name":ITEMS[kind].names[0],"short":String(ITEMS[kind].names[0]).left(9),"color":Color(ITEMS[kind].tint)}
	return result

## Связывает лавку с ограниченным ежедневным запасом сырья и продажей результатов.
static func products() -> Array:
	var result:=[]
	for kind in ITEMS: result.append({"kind":kind,"buy":ITEMS[kind].buy,"sell":ITEMS[kind].sell,"daily_stock":8})
	return result

## Находит сохраняемый рецепт по ID, различая руду, лом и восстановление шлака.
static func recipe(id: String) -> Dictionary:
	for value in RECIPES+preload("res://scripts/systems/research_data.gd").RECIPES:
		if value.id==id and value.get("station","")=="furnace": return value
	return {}

## Дополняет производственные записи именем для общих справочников и окна крафта.
static func recipes() -> Array:
	var result:=RECIPES.duplicate(true)
	for value in result: value.name=value.output
	return result
