extends RefCounted

const Recipes := preload("res://scripts/systems/workshop_recipe_data.gd")
const SPEED := [1.0,1.35,1.7]
const EFFICIENCY := [1.0,1.25,1.5]
const BASE_STATIONS := {
	"sawmill":{"location":"guild_interior","point":Vector2(885,485),"anchor":Vector2(885,440),"icon":"wood_beam","thermal":false,"upgrades":[{"coins":100,"inputs":{"wood_beam":4,"metal":3,"stone":6}},{"coins":250,"inputs":{"steel":3,"timber_frame":2,"wood_dowel":8}}]},
	"pottery":{"location":"cottage_interior","point":preload("res://scripts/systems/house_furniture_data.gd").POTTERY_POINT,"anchor":preload("res://scripts/systems/house_furniture_data.gd").POTTERY_POSITION,"icon":"clay_pot","thermal":false,"upgrades":[{"coins":100,"inputs":{"plank":6,"metal":2,"clay":6}},{"coins":220,"inputs":{"brick":8,"steel":2,"ceramic_glaze":3}}]},
	"glassblowing":{"location":"forge_interior","point":Vector2(850,490),"anchor":Vector2(850,450),"icon":"glass_bottle","thermal":true,"upgrades":[{"coins":120,"inputs":{"brick":6,"metal":3,"glass":4}},{"coins":280,"inputs":{"steel":3,"clear_glass":4,"timber_frame":2}}]},
}
static var STATIONS:Dictionary=BASE_STATIONS.merged(preload("res://scripts/systems/artisan_data.gd").WORKSHOPS)
const ITEMS := {
	"wood_beam":{"names":["Деревянный брус","Timber beam","Viga de madera","Holzbalken","Poutre de bois","木梁"],"group":"wood","color":"9d693c","buy":0,"sell":3},
	"wood_dowel":{"names":["Деревянные шканты","Wood dowels","Espigas de madera","Holzdübel","Chevilles de bois","木榫"],"group":"dowels","color":"b78750","buy":0,"sell":1},
	"timber_frame":{"names":["Столярная рама","Timber frame","Marco de madera","Holzrahmen","Cadre de bois","木框架"],"group":"frame","color":"95683d","buy":0,"sell":8},
	"wood_handle":{"names":["Деревянная рукоять","Wood handle","Mango de madera","Holzgriff","Manche en bois","木柄"],"group":"handle","color":"b78b58","buy":0,"sell":3},
	"sawdust":{"names":["Опилки","Sawdust","Serrín","Sägemehl","Sciure","锯末"],"group":"pile","color":"caa76b","buy":0,"sell":0},
	"clay":{"names":["Глина","Clay","Arcilla","Ton","Argile","黏土"],"group":"pile","color":"ad7658","buy":3,"sell":1},
	"wet_clay":{"names":["Глиняная масса","Wet clay","Masa de arcilla","Tonmasse","Pâte d’argile","湿黏土"],"group":"pile","color":"976b57","buy":0,"sell":1},
	"unfired_brick":{"names":["Кирпич-сырец","Unfired brick","Ladrillo crudo","Roher Ziegel","Brique crue","未烧砖"],"group":"brick","color":"a98c74","buy":0,"sell":1},
	"unfired_pot":{"names":["Заготовка горшка","Unfired pot","Maceta cruda","Roher Topf","Pot cru","未烧陶罐"],"group":"pot","color":"a18a72","buy":0,"sell":2},
	"unfired_bowl":{"names":["Заготовка миски","Unfired bowl","Cuenco crudo","Rohe Schale","Bol cru","未烧陶碗"],"group":"bowl","color":"a18a72","buy":0,"sell":1},
	"unfired_vase":{"names":["Заготовка вазы","Unfired vase","Jarrón crudo","Rohe Vase","Vase cru","未烧花瓶"],"group":"vase","color":"a18a72","buy":0,"sell":2},
	"glazed_vase_form":{"names":["Ваза под глазурью","Glazed vase form","Vaso esmaltado crudo","Glasierte Rohvase","Vase cru émaillé","上釉花瓶坯"],"group":"vase","color":"7caba0","buy":0,"sell":3},
	"porcelain_clay":{"names":["Фарфоровая масса","Porcelain clay","Pasta de porcelana","Porzellanmasse","Pâte de porcelaine","瓷土"],"group":"pile","color":"ded4b9","buy":0,"sell":2},
	"porcelain_form":{"names":["Заготовка фарфора","Porcelain form","Forma de porcelana","Porzellanrohling","Forme de porcelaine","瓷器坯"],"group":"cup","color":"d6cdb6","buy":0,"sell":3},
	"ceramic_glaze":{"names":["Керамическая глазурь","Ceramic glaze","Esmalte cerámico","Keramikglasur","Glaçure céramique","陶瓷釉"],"group":"bottle","color":"72aaa0","buy":0,"sell":2},
	"brick":{"names":["Обожжённый кирпич","Fired brick","Ladrillo cocido","Gebrannter Ziegel","Brique cuite","烧制砖"],"group":"brick","color":"bc7552","buy":0,"sell":3},
	"clay_pot":{"names":["Глиняный горшок","Clay pot","Maceta de barro","Tontopf","Pot en terre","陶罐"],"group":"pot","color":"ba815a","buy":0,"sell":7},
	"ceramic_bowl":{"names":["Керамическая миска","Ceramic bowl","Cuenco cerámico","Keramikschale","Bol en céramique","陶碗"],"group":"bowl","color":"bd855f","buy":0,"sell":5},
	"ceramic_vase":{"names":["Керамическая ваза","Ceramic vase","Jarrón cerámico","Keramikvase","Vase en céramique","陶瓷花瓶"],"group":"vase","color":"bf825c","buy":0,"sell":10},
	"glazed_vase":{"names":["Глазурованная ваза","Glazed vase","Jarrón esmaltado","Glasierte Vase","Vase émaillé","釉陶花瓶"],"group":"vase","color":"619f96","buy":0,"sell":15},
	"porcelain_cup":{"names":["Фарфоровая чашка","Porcelain cup","Taza de porcelana","Porzellantasse","Tasse en porcelaine","瓷杯"],"group":"cup","color":"e3e1cf","buy":0,"sell":20},
	"ceramic_shard":{"names":["Керамические черепки","Ceramic shards","Fragmentos cerámicos","Keramikscherben","Tessons de céramique","陶瓷碎片"],"group":"shards","color":"a87959","buy":0,"sell":0},
	"glass_bottle":{"names":["Стеклянная бутылка","Glass bottle","Botella de vidrio","Glasflasche","Bouteille en verre","玻璃瓶"],"group":"bottle","color":"a0cfcb","buy":0,"sell":5},
	"glass_jar":{"names":["Стеклянная банка","Glass jar","Tarro de vidrio","Glasgefäß","Bocal en verre","玻璃罐"],"group":"jar","color":"b6d8cf","buy":0,"sell":5},
	"clear_glass":{"names":["Прозрачное стекло","Clear glass","Vidrio claro","Klarglas","Verre clair","透明玻璃"],"group":"pane","color":"c5e0e2","buy":0,"sell":6},
	"optical_lens":{"names":["Оптическая линза","Optical lens","Lente óptica","Optische Linse","Lentille optique","光学镜片"],"group":"lens","color":"b5dadd","buy":0,"sell":18},
	"colored_glass":{"names":["Цветное стекло","Colored glass","Vidrio de color","Buntglas","Verre coloré","彩色玻璃"],"group":"pane","color":"cf8797","buy":0,"sell":9},
	"moon_glass":{"names":["Лунное стекло","Moon glass","Vidrio lunar","Mondglas","Verre lunaire","月光玻璃"],"group":"pane","color":"8ac0e0","buy":0,"sell":24},
}
const BASE_RESEARCH_ENTRIES := [
	{"kind":"wood_beam","tier":1,"batch":1,"parts":{"wood_offcut":2}},
	{"kind":"wood_dowel","tier":1,"batch":4,"parts":{"wood_offcut":1}},
	{"kind":"timber_frame","tier":2,"batch":1,"parts":{"wood_offcut":4,"metal_scrap":1}},
	{"kind":"wood_handle","tier":1,"batch":1,"parts":{"wood_offcut":1}},
	{"kind":"clay_pot","tier":1,"batch":1,"parts":{"ceramic_shard":2}},
	{"kind":"ceramic_bowl","tier":1,"batch":1,"parts":{"ceramic_shard":1}},
	{"kind":"ceramic_vase","tier":2,"batch":1,"parts":{"ceramic_shard":2}},
	{"kind":"glazed_vase","tier":2,"batch":1,"parts":{"ceramic_shard":2}},
	{"kind":"porcelain_cup","tier":3,"batch":1,"parts":{"ceramic_shard":1}},
	{"kind":"glass_bottle","tier":1,"batch":1,"parts":{"glass_shard":1}},
	{"kind":"glass_jar","tier":1,"batch":1,"parts":{"glass_shard":1}},
	{"kind":"clear_glass","tier":2,"batch":1,"parts":{"glass_shard":2}},
	{"kind":"colored_glass","tier":2,"batch":1,"parts":{"glass_shard":2}},
	{"kind":"optical_lens","tier":2,"batch":1,"parts":{"glass_shard":2,"arcane_dust":1}},
	{"kind":"moon_glass","tier":3,"batch":1,"parts":{"glass_shard":2,"arcane_dust":1}},
]
static var RESEARCH_ENTRIES:Array=BASE_RESEARCH_ENTRIES+preload("res://scripts/systems/artisan_data.gd").RESEARCH_ENTRIES
const SPAWNS := [
	{"position":Vector2(820,960),"location":"rocky","kind":"clay","hits":8},
	{"position":Vector2(1700,1080),"location":"rocky","kind":"clay","hits":8},
]

## Дополняет общий языковой каталог именами материалов трёх ремёсел.
static func names() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]=ITEMS[kind].names
	return result.merged(preload("res://scripts/systems/artisan_data.gd").names())

## Регистрирует сырьё, заготовки и изделия как сохраняемые предметы.
static func inventory_items() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]={"name":ITEMS[kind].names[0],"short":String(ITEMS[kind].names[0]).left(9),"color":Color(ITEMS[kind].color)}
	return result.merged(preload("res://scripts/systems/artisan_data.gd").inventory_items())

## Продаёт только сырой глиняный запас, позволяя торговать готовыми изделиями без покупки деталей.
static func products() -> Array:
	var result:=[]
	for kind in ITEMS: result.append({"kind":kind,"buy":ITEMS[kind].buy,"sell":ITEMS[kind].sell,"daily_stock":8})
	return result+preload("res://scripts/systems/artisan_data.gd").products()
