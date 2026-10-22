extends RefCounted

const ITEMS := {
	"apple_juice":{"names":["Яблочный сок","Apple juice","Zumo de manzana","Apfelsaft","Jus de pomme","苹果汁"],"color":"d6b054","sell":9,"buy":0,"effect":["item_effect_heal_energy",18,3]},
	"berry_juice":{"names":["Ягодный сок","Berry juice","Zumo de bayas","Beerensaft","Jus de baies","浆果汁"],"color":"b75f89","sell":8,"buy":0,"effect":["item_effect_heal_mana",18,8]},
	"pear_juice":{"names":["Грушевый сок","Pear juice","Zumo de pera","Birnensaft","Jus de poire","梨汁"],"color":"b9ba6a","sell":10,"buy":0,"effect":["item_effect_heal_energy",20,3]},
	"tomato_juice":{"names":["Томатный сок","Tomato juice","Zumo de tomate","Tomatensaft","Jus de tomate","番茄汁"],"color":"c65c4a","sell":8,"buy":0,"effect":["item_effect_heal_energy",15,2]},
	"fruit_pulp":{"names":["Фруктовый жмых","Fruit pulp","Pulpa de fruta","Obsttrester","Marc de fruits","果渣"],"color":"ae8759","sell":0,"buy":0},
	"cider":{"names":["Яблочный сидр","Apple cider","Sidra de manzana","Apfelwein","Cidre de pomme","苹果酒"],"color":"ca9b43","sell":22,"buy":0,"effect":["item_effect_heal_energy",26,5]},
	"berry_wine":{"names":["Ягодное вино","Berry wine","Vino de bayas","Beerenwein","Vin de baies","浆果酒"],"color":"934d78","sell":24,"buy":0,"effect":["item_effect_heal_mana",25,16]},
	"mead":{"names":["Медовый напиток","Mead","Hidromiel","Met","Hydromel","蜂蜜酒"],"color":"d5ab54","sell":25,"buy":0,"effect":["item_effect_heal_energy",28,6]},
	"fruit_vinegar":{"names":["Фруктовый уксус","Fruit vinegar","Vinagre de fruta","Obstessig","Vinaigre de fruits","果醋"],"color":"c29968","sell":8,"buy":0},
	"aged_cheese":{"names":["Выдержанный сыр","Aged cheese","Queso curado","Gereifter Käse","Fromage affiné","熟成奶酪"],"color":"dec276","sell":32,"buy":0,"effect":["item_effect_heal_energy",70,10]},
	"lunar_cordial":{"names":["Лунный кордиал","Lunar cordial","Licor lunar","Mondlikör","Cordial lunaire","月光露酒"],"color":"ada6d6","sell":42,"buy":0,"effect":["item_effect_heal_mana",45,30]},
	"pickled_vegetables":{"names":["Маринованные овощи","Pickled vegetables","Verduras encurtidas","Eingelegtes Gemüse","Légumes marinés","腌蔬菜"],"color":"8ca46c","sell":15,"buy":0,"effect":["item_effect_heal_energy",28,4]},
	"pickled_mushrooms":{"names":["Маринованные грибы","Pickled mushrooms","Setas encurtidas","Eingelegte Pilze","Champignons marinés","腌蘑菇"],"color":"b29a74","sell":18,"buy":0,"effect":["item_effect_heal_energy",30,5]},
	"apple_preserves":{"names":["Яблочное повидло","Apple preserves","Dulce de manzana","Apfelmus","Confiture de pomme","苹果酱"],"color":"c3a16a","sell":20,"buy":0,"effect":["item_effect_heal_energy",35,5]},
	"dried_fruit":{"names":["Сухофрукты","Dried fruit","Fruta seca","Trockenobst","Fruits séchés","果干"],"color":"b27d55","sell":14,"buy":0,"effect":["item_effect_heal_energy",20,4]},
	"dried_mushrooms":{"names":["Сушёные грибы","Dried mushrooms","Setas secas","Getrocknete Pilze","Champignons séchés","干蘑菇"],"color":"a49170","sell":12,"buy":0,"effect":["item_effect_heal_energy",15,3]},
	"travel_ration":{"names":["Походный паёк","Travel ration","Ración de viaje","Reiseration","Ration de voyage","旅行口粮"],"color":"ba9f72","sell":35,"buy":0,"effect":["item_effect_heal_energy",65,10]},
	"smoked_fish":{"names":["Копчёная рыба","Smoked fish","Pescado ahumado","Räucherfisch","Poisson fumé","熏鱼"],"color":"b88652","sell":16,"buy":0,"effect":["item_effect_heal_energy",38,6]},
	"smoked_meat":{"names":["Копчёное мясо","Smoked meat","Carne ahumada","Räucherfleisch","Viande fumée","熏肉"],"color":"9a6451","sell":20,"buy":0,"effect":["item_effect_heal_energy",45,7]},
	"smoked_cheese":{"names":["Копчёный сыр","Smoked cheese","Queso ahumado","Räucherkäse","Fromage fumé","熏奶酪"],"color":"c7954f","sell":30,"buy":0,"effect":["item_effect_heal_energy",60,9]},
	"herbed_fish":{"names":["Рыба с травами","Herbed fish","Pescado con hierbas","Kräuterfisch","Poisson aux herbes","香草鱼"],"color":"91a27b","sell":26,"buy":0,"effect":["item_effect_heal_energy",55,8]},
	"smoked_mushrooms":{"names":["Копчёные грибы","Smoked mushrooms","Setas ahumadas","Geräucherte Pilze","Champignons fumés","熏蘑菇"],"color":"a5825d","sell":16,"buy":0,"effect":["item_effect_heal_energy",25,4]},
	"canvas":{"names":["Плотный холст","Canvas","Lona","Segeltuch","Toile épaisse","帆布"],"color":"c5b997","sell":8,"buy":0},
	"fine_cloth":{"names":["Тонкая ткань","Fine cloth","Tela fina","Feiner Stoff","Tissu fin","细布"],"color":"bbced2","sell":14,"buy":0},
	"bandage":{"names":["Чистая повязка","Clean bandage","Venda limpia","Sauberer Verband","Bandage propre","干净绷带"],"color":"dfd8bf","sell":5,"buy":0,"effect":["item_effect_heal",30]},
	"leather":{"names":["Выделанная кожа","Leather","Cuero","Leder","Cuir","皮革"],"color":"a36c44","sell":10,"buy":0},
	"leather_strap":{"names":["Кожаные ремни","Leather straps","Correas de cuero","Lederriemen","Lanières de cuir","皮带"],"color":"98633e","sell":5,"buy":0},
	"cured_fur":{"names":["Выделанный мех","Cured fur","Piel curtida","Gegerbtes Fell","Fourrure apprêtée","熟制毛皮"],"color":"c28a52","sell":16,"buy":0},
	"book_binding":{"names":["Книжный переплёт","Book binding","Encuadernación","Bucheinband","Reliure","书皮"],"color":"87563e","sell":12,"buy":0},
	"tanning_agent":{"names":["Дубильный раствор","Tanning agent","Curtiente","Gerbmittel","Agent tannant","鞣剂"],"color":"9a7958","sell":4,"buy":0},
	"wax_candle":{"names":["Восковые свечи","Wax candles","Velas de cera","Wachskerzen","Bougies de cire","蜡烛"],"color":"e1c783","sell":6,"buy":0},
	"herbal_candle":{"names":["Травяная свеча","Herbal candle","Vela herbal","Kräuterkerze","Bougie aux herbes","香草蜡烛"],"color":"a6bb82","sell":12,"buy":0},
	"moon_candle":{"names":["Лунная свеча","Moon candle","Vela lunar","Mondkerze","Bougie lunaire","月光蜡烛"],"color":"aba0d5","sell":22,"buy":0},
	"soap":{"names":["Домашнее мыло","Soap","Jabón","Seife","Savon","肥皂"],"color":"dccb98","sell":5,"buy":0},
	"herbal_soap":{"names":["Травяное мыло","Herbal soap","Jabón herbal","Kräuterseife","Savon aux herbes","香草皂"],"color":"9eb987","sell":10,"buy":0},
	"incense":{"names":["Благовония","Incense","Incienso","Räucherwerk","Encens","香料"],"color":"9d8867","sell":16,"buy":0},
	"compost":{"names":["Компост","Compost","Compost","Kompost","Compost","堆肥"],"color":"8d704b","sell":1,"buy":0,"usable":true},
	"bone_meal":{"names":["Костная мука","Bone meal","Harina de huesos","Knochenmehl","Farine d’os","骨粉"],"color":"ccc5a9","sell":2,"buy":0},
	"growth_fertilizer":{"names":["Удобрение роста","Growth fertilizer","Abono de crecimiento","Wachstumsdünger","Engrais de croissance","生长肥"],"color":"97b77c","sell":4,"buy":0,"usable":true},
	"quality_fertilizer":{"names":["Удобрение урожая","Yield fertilizer","Abono de rendimiento","Ertragsdünger","Engrais de rendement","丰收肥"],"color":"cab06e","sell":5,"buy":0,"usable":true},
	"fishing_bait":{"names":["Рыболовная наживка","Fishing bait","Cebo de pesca","Angelköder","Appât de pêche","鱼饵"],"color":"b98c69","sell":1,"buy":0},
}
const STATIONS := {
	"fruit_press":{"icon":"apple_juice","energy":1,"inputs":{"plank":6,"nails":4,"metal":2},"upgrades":[{"coins":70,"inputs":{"wood_beam":4,"metal":3,"glass_bottle":2}},{"coins":180,"inputs":{"steel":2,"timber_frame":2,"clear_glass":2}}],"size":Vector2i(4,4)},
	"fermenter":{"icon":"cider","energy":1,"inputs":{"plank":8,"nails":6,"glass_bottle":2},"upgrades":[{"coins":65,"inputs":{"wood_beam":4,"nails":4,"glass_bottle":3}},{"coins":160,"inputs":{"timber_frame":2,"metal":4,"glass_bottle":4}}],"size":Vector2i(5,4)},
	"preserver":{"icon":"pickled_vegetables","energy":1,"inputs":{"plank":6,"metal":2,"glass_jar":2},"upgrades":[{"coins":80,"inputs":{"wood_beam":4,"brick":4,"glass_jar":2}},{"coins":190,"inputs":{"steel":2,"timber_frame":2,"porcelain_cup":2}}],"size":Vector2i(5,3)},
	"smoker":{"icon":"smoked_fish","energy":2,"inputs":{"plank":6,"brick":8,"metal":3},"upgrades":[{"coins":90,"inputs":{"brick":10,"metal":4,"wood_beam":2}},{"coins":220,"inputs":{"steel":3,"brick":12,"timber_frame":2}}],"size":Vector2i(4,4)},
	"loom":{"icon":"canvas","energy":1,"inputs":{"plank":10,"nails":6,"rope":2},"upgrades":[{"coins":75,"inputs":{"wood_beam":4,"rope":3,"nails":4}},{"coins":180,"inputs":{"timber_frame":2,"steel":2,"cloth":4}}],"size":Vector2i(6,4)},
	"tannery":{"icon":"leather","energy":1,"inputs":{"plank":8,"clay_pot":1,"nails":4},"upgrades":[{"coins":80,"inputs":{"wood_beam":4,"clay_pot":2,"metal":2}},{"coins":190,"inputs":{"timber_frame":2,"steel":2,"leather":4}}],"size":Vector2i(6,4)},
	"candlebench":{"icon":"wax_candle","energy":1,"inputs":{"plank":6,"metal":2,"ceramic_bowl":1},"upgrades":[{"coins":75,"inputs":{"wood_beam":4,"glass_vial":4,"metal":2}},{"coins":180,"inputs":{"steel":2,"porcelain_cup":2,"clear_glass":2}}],"size":Vector2i(5,3)},
	"gardenbench":{"icon":"compost","energy":1,"inputs":{"plank":8,"nails":4,"stone":4},"upgrades":[{"coins":60,"inputs":{"wood_beam":4,"nails":4,"clay_pot":1}},{"coins":150,"inputs":{"timber_frame":2,"metal":3,"bone_meal":4}}],"size":Vector2i(5,4)},
}
const WORKSHOPS := {
	"fruit_press":{"private":true,"location":"cellar_workshop","icon":"apple_juice","thermal":false,"upgrades":[{"coins":70,"inputs":{"wood_beam":4,"metal":3,"glass_bottle":2}},{"coins":180,"inputs":{"steel":2,"timber_frame":2,"clear_glass":2}}],"profession":"farming"},
	"fermenter":{"private":true,"location":"cellar_workshop","icon":"cider","thermal":false,"upgrades":[{"coins":65,"inputs":{"wood_beam":4,"nails":4,"glass_bottle":3}},{"coins":160,"inputs":{"timber_frame":2,"metal":4,"glass_bottle":4}}],"profession":"farming"},
	"preserver":{"private":true,"location":"cellar_workshop","icon":"pickled_vegetables","thermal":false,"upgrades":[{"coins":80,"inputs":{"wood_beam":4,"brick":4,"glass_jar":2}},{"coins":190,"inputs":{"steel":2,"timber_frame":2,"porcelain_cup":2}}],"profession":"farming"},
	"smoker":{"private":true,"location":"cellar_workshop","icon":"smoked_fish","thermal":true,"upgrades":[{"coins":90,"inputs":{"brick":10,"metal":4,"wood_beam":2}},{"coins":220,"inputs":{"steel":3,"brick":12,"timber_frame":2}}],"profession":"smithing","fuels":["wood","log","charcoal"]},
	"loom":{"private":true,"location":"cellar_workshop","icon":"canvas","thermal":false,"upgrades":[{"coins":75,"inputs":{"wood_beam":4,"rope":3,"nails":4}},{"coins":180,"inputs":{"timber_frame":2,"steel":2,"cloth":4}}],"profession":"smithing"},
	"tannery":{"private":true,"location":"cellar_workshop","icon":"leather","thermal":false,"upgrades":[{"coins":80,"inputs":{"wood_beam":4,"clay_pot":2,"metal":2}},{"coins":190,"inputs":{"timber_frame":2,"steel":2,"leather":4}}],"profession":"smithing"},
	"candlebench":{"private":true,"location":"cellar_workshop","icon":"wax_candle","thermal":false,"upgrades":[{"coins":75,"inputs":{"wood_beam":4,"glass_vial":4,"metal":2}},{"coins":180,"inputs":{"steel":2,"porcelain_cup":2,"clear_glass":2}}],"profession":"smithing"},
	"gardenbench":{"private":true,"location":"cellar_workshop","icon":"compost","thermal":false,"upgrades":[{"coins":60,"inputs":{"wood_beam":4,"nails":4,"clay_pot":1}},{"coins":150,"inputs":{"timber_frame":2,"metal":3,"bone_meal":4}}],"profession":"farming"},
}
const RESEARCH_ENTRIES := [
	{"kind":"canvas","tier":1,"batch":1,"parts":{"cloth_scrap":2}},
	{"kind":"fine_cloth","tier":2,"batch":1,"parts":{"cloth_scrap":3}},
	{"kind":"leather","tier":1,"batch":1,"parts":{"hide":1}},
	{"kind":"leather_strap","tier":1,"batch":1,"parts":{"leather":1}},
	{"kind":"cured_fur","tier":2,"batch":1,"parts":{"fur":1}},
	{"kind":"book_binding","tier":2,"batch":1,"parts":{"leather":1,"cloth_scrap":1}},
]

## Регистрирует имена новых продуктов на шести поддерживаемых языках.
static func names() -> Dictionary:
	var result:={}
	for kind in ITEMS: result[kind]=ITEMS[kind].names
	return result

## Хранит одинаковые пищевые эффекты в карточке предмета и при употреблении.
static func effects() -> Dictionary:
	var result:={}
	for kind in ITEMS:
		if ITEMS[kind].has("effect"): result[kind]=ITEMS[kind].effect
	return result

## Добавляет сохраняемые продукты, расходники и материалы в рюкзак.
static func inventory_items() -> Dictionary:
	var result:={}
	for kind in ITEMS:
		var value:Dictionary=ITEMS[kind]
		result[kind]={"name":value.names[0],"short":String(value.names[0]).left(9),"color":Color(value.color)}
		if value.has("effect"): result[kind].edible=true
		if value.get("usable",false): result[kind].usable=true
	return result

## Даёт торговле стоимость изделий, оставляя создание доступным через производственные цепочки.
static func products() -> Array:
	var result:=[]
	for kind in ITEMS: result.append({"kind":kind,"buy":0,"sell":ITEMS[kind].sell,"daily_stock":0})
	return result
