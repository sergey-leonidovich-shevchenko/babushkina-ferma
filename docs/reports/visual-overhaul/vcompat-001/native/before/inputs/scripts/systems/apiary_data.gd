extends RefCounted

const SITES := [Vector2(216,1224),Vector2(336,1224),Vector2(456,1224)]
const WILD := [{"id":"meadow","location":"overworld","position":Vector2(144,648)},{"id":"forest","location":"forest","position":Vector2(552,888)}]
const COSTS := [{"inputs":{"plank":6,"nails":4,"stone":4},"coins":0,"energy":3},{"inputs":{"plank":4,"nails":4,"glass":1},"coins":50,"energy":4},{"inputs":{"wood_beam":4,"metal":2,"glass":2},"coins":120,"energy":6}]
const RAW := {
	"bees":["Пчёлы","Bees","Abejas","Bienen","Abeilles","蜜蜂"],
	"honeycomb":["Медовые соты","Honeycomb","Panal de miel","Honigwabe","Rayon de miel","蜂蜜巢脾"],
	"beeswax":["Пчелиный воск","Beeswax","Cera de abeja","Bienenwachs","Cire d’abeille","蜂蜡"],
	"pollen":["Цветочная пыльца","Bee pollen","Polen de abeja","Blütenpollen","Pollen d’abeille","蜂花粉"],
	"propolis":["Прополис","Propolis","Propóleo","Propolis","Propolis","蜂胶"],
	"wax_base":["Восковая основа","Wax base","Base de cera","Wachsgrundlage","Base de cire","蜡基质"],
	"bee_essence":["Пчелиная эссенция","Bee essence","Esencia de abeja","Bienenessenz","Essence d’abeille","蜜蜂精华"],
	"pollen_powder":["Порошок пыльцы","Pollen powder","Polvo de polen","Pollenpulver","Poudre de pollen","花粉末"],
	"propolis_tincture":["Настойка прополиса","Propolis tincture","Tintura de propóleo","Propolistinktur","Teinture de propolis","蜂胶浸液"],
	"honey_syrup":["Медовый сироп","Honey syrup","Jarabe de miel","Honigsirup","Sirop de miel","蜂蜜糖浆"],
}
const POTIONS := {
	"bee_balm":{"names":["Пчелиный бальзам","Bee balm","Bálsamo apícola","Bienenbalsam","Baume apicole","蜜蜂香膏"],"heal":50,"energy":4},
	"propolis_balm":{"names":["Прополисная мазь","Propolis ointment","Ungüento de propóleo","Propolissalbe","Pommade de propolis","蜂胶软膏"],"timer":"regeneration_timer","duration":30.0,"cleanse":true},
	"royal_tonic":{"names":["Маточный тоник","Royal tonic","Tónico real","Königstonikum","Tonique royal","蜂王补剂"],"energy":8,"mana":25},
}
const MIXES := [
	["honey",{"honeycomb":1},1,1,"supplies"],
	["wax_base",{"beeswax":1,"herb_oil":1},2,1,"supplies"],
	["bee_essence",{"bees":1,"sage_juice":1,"herb_solvent":1},2,2,"essence"],
	["pollen_powder",{"pollen":2},1,1,"powder"],
	["propolis_tincture",{"propolis":1,"herb_solvent":1},1,2,"tincture"],
	["honey_syrup",{"honey":1,"clean_water":1},2,1,"supplies"],
	["bee_balm",{"wax_base":1,"pollen_powder":1,"honey":1,"glass_vial":1},1,2,"potions"],
	["propolis_balm",{"propolis_tincture":1,"wax_base":1,"glass_vial":1},1,2,"potions"],
	["royal_tonic",{"bee_essence":1,"honey_syrup":1,"pollen_powder":1,"glass_vial":1},1,3,"potions"],
]
const COLORS := {"bees":"d8a542","honeycomb":"dda440","beeswax":"e1bf6f","pollen":"d9b442","propolis":"9c6c43","wax_base":"ddc890","bee_essence":"dbae63","pollen_powder":"d6ba5d","propolis_tincture":"b58051","honey_syrup":"d7a746","bee_balm":"ddbc81","propolis_balm":"b59673","royal_tonic":"d3a858"}
const SHORT := {"bees":["Пчёлы","Bees","Abejas","Bienen","Abeilles","蜜蜂"],"honeycomb":["Соты","Comb","Panal","Wabe","Rayon","巢脾"],"beeswax":["Воск","Wax","Cera","Wachs","Cire","蜂蜡"],"pollen":["Пыльца","Pollen","Polen","Pollen","Pollen","花粉"],"propolis":["Прополис","Propolis","Propóleo","Propolis","Propolis","蜂胶"]}

## Совмещает физическое основание улья с общей сеткой и постоянной южной рабочей точкой.
static func base(position: Vector2) -> Rect2:
	return Rect2(position-Vector2(36,24),Vector2(72,48))

## Возвращает всё оплаченное сырьё конкретного уровня для честного демонтажа.
static func paid(level: int) -> Dictionary:
	var result:={}
	for tier in range(level):
		for kind in COSTS[tier].inputs: result[kind]=int(result.get(kind,0))+int(COSTS[tier].inputs[kind])
	return result
