extends "res://tests/suites/basement_suite.gd"

const Artisan := preload("res://scripts/systems/artisan_data.gd")
const Recipes := preload("res://scripts/systems/artisan_recipe_data.gd")
const Workshop := preload("res://scripts/systems/workshop_system.gd")
const Visual := preload("res://scripts/presentation/artisan_visual_system.gd")

## Проверяет построенные мастерские, все новые партии, оплату, топливо, уровни, сохранения и нарезку.
func run() -> void:
	test_catalog_and_locales()
	test_all_stations_and_production_recipes()
	test_atomic_queue_pause_and_isolation()
	test_upgrade_paid_queue_and_salvage()
	test_canonical_save_and_invalid_jobs()
	test_original_sprite_regions()
	test_new_alchemy_routes()

## Улучшает оплаченный станок настоящим удержанием с восстановлением энергии только между рабочими секундами стенда.
func upgrade_to(game: Node, item: Dictionary, target: int) -> void:
	while int(item.level)<target:
		game.crafting_open=false; game.player=Basement.Data.BOARD; Basement.open(game)
		var cost:=Basement.Data.upgrade_cost(item.kind,int(item.level)); game.coins+=int(cost.coins)
		for kind in cost.inputs: game.change_inventory_count(kind,int(cost.inputs[kind]))
		expect(Build.upgrade(game,int(item.id)),"blueprint reserves upgrade: "+item.kind)
		game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,int(item.id))
		for _second in int(item.duration): game.energy=12; Build.update_hold(game,1)
		expect(item.phase=="ready" and int(item.production.level)==int(item.level),"hold work finishes local upgrade: "+item.kind)

## Открывает единственную рабочую сторону реального построенного экземпляра.
func open_station(game: Node, item: Dictionary) -> void:
	game.current_location=Basement.Data.LOCATION; game.player=Basement.Layout.center(Basement.Layout.approach_cell(item))
	expect(Stations.interact(game,int(item.id)) and game.crafting_station==item.kind,"normal context opens artisan instance: "+item.kind)
	game.energy=12

## Сценарий: все новые продукты имеют честные нулевые запасы, торговую цену и переводы.
## Исходное состояние: новая игра без бесплатных построенных мастерских.
## Ожидаемый результат: зарегистрированы 8 станков, 41 предмет, 64 партии и 8 алхимических вариантов на шести языках.
func test_catalog_and_locales() -> void:
	var game:=make_game()
	expect(Artisan.STATIONS.size()==8 and Artisan.ITEMS.size()==41 and Recipes.RECIPES.size()==72,"reviewed expansion has complete coherent catalogs")
	for kind in Artisan.ITEMS:
		expect(game.inventory_item_count(kind)==0 and game.InventorySystem.ITEM_DATA.has(kind),"no free artisan output: "+kind)
		expect(game.VisualAssetSystem.has_item_icon(kind),"cached standalone icon: "+kind)
		expect(game.ShopSystem.PRODUCTS.any(func(value): return value.kind==kind),"artisan product can be sold: "+kind)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for kind in Artisan.ITEMS: expect(game.LocaleSystem.item(kind)!=kind,"localized artisan item: "+locale+" "+kind)
		for kind in Artisan.STATIONS:
			expect(game.LocaleSystem.ui(kind+"_title",[3])!=kind+"_title" and game.LocaleSystem.tutorial(kind)!=kind,"localized station and teaching: "+locale+" "+kind)
	for kind in Artisan.STATIONS:
		game.open_crafting(kind)
		expect(not game.crafting_open and Workshop.state(game,kind).is_empty(),"private workshop cannot be opened or created remotely: "+kind)
	game.free()

## Сценарий: каждая новая технология исполняется на построенном станке после последовательных улучшений.
## Исходное состояние: восемь оплаченных экземпляров, три уровня, материалы выдаются только на проверяемую партию.
## Ожидаемый результат: уровни ограничивают доступ, вход списывается сразу, выход и побочные продукты приходят один раз позже.
func test_all_stations_and_production_recipes() -> void:
	var game:=make_game(); enter(game); var index:=0
	for station_kind in Artisan.STATIONS:
		var item:=place(game,station_kind,25+(index%4)*14,16+(index/4)*14,preload("res://scripts/systems/furniture_facing_system.gd").SELECTABLE[index%3]); finish(game,item); index+=1
		open_station(game,item)
		var high:Dictionary=Recipes.RECIPES.filter(func(value): return value.station==station_kind and int(value.workshop_level)==3)[0]
		expect(not Workshop.reason(game,high).is_empty(),"tier one cannot produce advanced goods: "+station_kind)
		upgrade_to(game,item,3)
		if station_kind=="candlebench": expect(int(Build.salvage(item).ceramic_shard)==2,"porcelain and bowl parts become ceramic shards on dismantle")
		if station_kind=="gardenbench": expect(int(Build.salvage(item).compost)==2,"organic upgrade leftovers return to the compost chain")
		for recipe in Recipes.RECIPES:
			if recipe.station!=station_kind: continue
			open_station(game,item)
			for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material]))
			var before:Dictionary=game.export_inventory_counts().duplicate(); var energy_before:float=game.energy
			var recipe_index:int=game.CraftingSystem.RECIPES.find_custom(func(value): return value.get("id","")==recipe.id)
			expect(recipe_index>=0 and game.CraftingSystem.craft(game,recipe_index),"actual recipe can be queued: "+recipe.id)
			expect(is_equal_approx(game.energy,energy_before-float(recipe.energy)) and game.inventory_item_count(recipe.output)==int(before.get(recipe.output,0)),"energy paid now and output deferred: "+recipe.id)
			for material in recipe.inputs: expect(game.inventory_item_count(material)==int(before.get(material,0))-int(recipe.inputs[material]),"exact production input: "+recipe.id+" "+material)
			if Workshop.thermal(station_kind):
				item.production.fuel="charcoal"; game.change_inventory_count("charcoal",1); expect(Workshop.load_fuel(game),"clean fuel loads the smoker")
			game.crafting_open=false; Workshop.advance(game,station_kind,item.production,60)
			expect(item.production.queue.is_empty() and game.inventory_item_count(recipe.output)==int(before.get(recipe.output,0))+int(recipe.count),"exact completed batch: "+recipe.id)
			for material in recipe.get("byproducts",{}): expect(game.inventory_item_count(material)==int(before.get(material,0))+int(recipe.byproducts[material]),"exact useful byproduct: "+recipe.id)
			var completed:int=item.production.completed; Workshop.advance(game,station_kind,item.production,60)
			expect(int(item.production.completed)==completed,"no repeated batch completion: "+recipe.id)
	expect(not game.state.world.estate.expansion.get("workshops",{}).keys().any(func(value): return Artisan.STATIONS.has(value)),"no hidden public duplicates for cellar-only workshops")
	game.free()

## Сценарий: неудачная постановка ничего не списывает, а рюкзак останавливает оплаченный станок.
## Исходное состояние: два пресса первого уровня, одна оплаченная партия и недостаток энергии или сырья.
## Ожидаемый результат: полная очередь, неверная рабочая сторона и удалённый доступ отклоняются; время и выход не дублируются.
func test_atomic_queue_pause_and_isolation() -> void:
	var game:=make_game(); enter(game)
	var left:=place(game,"fruit_press",25,18); finish(game,left); var right:=place(game,"fruit_press",42,18); finish(game,right)
	open_station(game,left); var recipe:Dictionary=Workshop.Data.Recipes.recipe("artisan:fruit_press:apple_juice")
	var before:Dictionary=game.export_inventory_counts().duplicate(); expect(not Workshop.enqueue(game,recipe) and before==game.export_inventory_counts(),"missing ingredients are atomic")
	for kind in recipe.inputs: game.change_inventory_count(kind,int(recipe.inputs[kind])*2)
	game.energy=0; before=game.export_inventory_counts().duplicate()
	expect(not Workshop.enqueue(game,recipe) and before==game.export_inventory_counts(),"missing energy preserves all input")
	game.energy=12; expect(Workshop.enqueue(game,recipe),"funded batch accepted")
	before=game.export_inventory_counts().duplicate(); expect(not Workshop.enqueue(game,recipe) and before==game.export_inventory_counts(),"full queue never charges second batch")
	var remaining:float=left.production.queue[0].remaining
	game.crafting_open=false; game.inventory_open=true; game._process(1)
	expect(is_equal_approx(left.production.queue[0].remaining,remaining),"backpack freezes actual artisan production")
	game.inventory_open=false; open_station(game,right)
	expect(right.production.queue.is_empty() and left.production.queue.size()==1,"selected same-kind station owns separate queue")
	game.player+=Vector2(60,0); before=game.export_inventory_counts().duplicate()
	expect(not Workshop.enqueue(game,recipe) and before==game.export_inventory_counts(),"wrong side cannot enqueue")
	game.current_location="forest"; Production.update(game,1)
	expect(is_equal_approx(left.production.queue[0].remaining,remaining-1) and right.production.queue.is_empty(),"paid work progresses exactly once outside its room")
	game.free()

## Сценарий: тепло не тратится при простое, очередь ускоряется после сборки улучшения, демонтаж возвращает незавершённое сырьё.
## Исходное состояние: два отдельных коптильных шкафа и одна рыба в очереди.
## Ожидаемый результат: запрещены мусор и уголь, нехватка жара останавливает партию, доля готовности и полная оплата сохранены.
func test_upgrade_paid_queue_and_salvage() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"smoker",25,18); finish(game,item)
	var other:=place(game,"smoker",42,18); finish(game,other); open_station(game,item)
	item.production.fuel="trash"; game.change_inventory_count("trash",1)
	expect(not Workshop.load_fuel(game) and game.inventory_item_count("trash")==1,"food smoker rejects dirty fuel")
	item.production.fuel="wood"; game.change_inventory_count("wood",1); expect(Workshop.load_fuel(game),"wood heats local smoker")
	expect(not preload("res://scripts/presentation/artisan_fx_renderer.gd").working(item),"idle smoker has no animated smoke")
	var heat:float=item.production.heat; Workshop.advance(game,"smoker",item.production,30)
	expect(item.production.heat==heat and other.production.heat==0,"idle heat stays local")
	var recipe:Dictionary=Workshop.Data.Recipes.recipe("artisan:smoker:smoked_fish")
	game.change_inventory_count("fish",2); expect(Workshop.enqueue(game,recipe),"smoking batch paid")
	expect(preload("res://scripts/presentation/artisan_fx_renderer.gd").working(item),"only fueled paid smoking emits animation")
	Workshop.advance(game,"smoker",item.production,1); var fraction:float=item.production.queue[0].remaining/item.production.queue[0].duration
	upgrade_to(game,item,2)
	expect(is_equal_approx(item.production.queue[0].remaining/item.production.queue[0].duration,fraction),"upgrade preserves completed share and only changes speed")
	item.production.heat=0.25; var remaining:float=item.production.queue[0].remaining; Workshop.advance(game,"smoker",item.production,5)
	expect(is_zero_approx(item.production.heat) and is_equal_approx(item.production.queue[0].remaining,remaining-0.3125),"heat exhausts at fractional working instant")
	expect(not preload("res://scripts/presentation/artisan_fx_renderer.gd").working(item),"exhausted smoker stops animated smoke")
	Workshop.advance(game,"smoker",item.production,10); expect(is_equal_approx(item.production.queue[0].remaining,remaining-0.3125),"cold smoker waits without completing")
	game.crafting_open=false; game.player=Basement.Data.BOARD; Basement.open(game)
	var returned:=Build.salvage(item); expect(int(returned.fish)==2,"dismantle returns all unfinished batch input")
	var before:Dictionary=game.export_inventory_counts().duplicate(); expect(Build.dismantle(game,int(item.id)),"blueprint dismantles chosen smoker")
	for kind in returned: expect(game.inventory_item_count(kind)==int(before.get(kind,0))+int(returned[kind]),"exact returned components and typed debris: "+kind)
	expect(Basement.object(game,int(other.id)).size()>0 and other.production.queue.is_empty(),"neighbor survives dismantling")
	var leatherbench:=place(game,"tannery",58,18); finish(game,leatherbench); upgrade_to(game,leatherbench,3)
	var leather_return:=Build.salvage(leatherbench)
	expect(int(leather_return.leather)==2 and int(leather_return.cloth_scrap)==2 and int(leather_return.ceramic_shard)==2,"paid leather returns half plus cloth scraps, tanning pots yield ceramic debris")
	game.free()

## Сценарий: сохранение сохраняет оплаченные очереди, не принимает сокращённую длительность или подмену сырья.
## Исходное состояние: готовый пресс третьего уровня с наполовину выполненной партией.
## Ожидаемый результат: JSON восстанавливается без повторной оплаты и выдачи, некорректные документы отбрасываются до изменения игры.
func test_canonical_save_and_invalid_jobs() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"fruit_press",25,18); finish(game,item); upgrade_to(game,item,3); open_station(game,item)
	var recipe:Dictionary=Workshop.Data.Recipes.recipe("artisan:fruit_press:apple_juice")
	for kind in recipe.inputs: game.change_inventory_count(kind,int(recipe.inputs[kind]))
	Workshop.enqueue(game,recipe); Workshop.advance(game,"fruit_press",item.production,2)
	var snapshot:Dictionary=game.SaveSystem.snapshot(game); var parsed:Dictionary=JSON.parse_string(JSON.stringify(snapshot))
	expect(game.SaveSystem.ValidationSystem.valid(parsed),"JSON numbers validate for actual artisan construction and queue")
	var restored:=make_game(); game.SaveSystem.apply(restored,parsed)
	var loaded:Dictionary=Basement.state(restored).objects[0].production.queue[0]; var saved:Dictionary=parsed.estate.expansion.basement.objects[0].production.queue[0]
	expect(loaded.id==saved.id and is_equal_approx(loaded.duration,saved.duration) and is_equal_approx(loaded.remaining,saved.remaining) and restored.inventory_item_count("apple_juice")==0,"paid artisan queue restored without early or duplicate output")
	for kind in saved.paid: expect(int(loaded.paid[kind])==int(saved.paid[kind]),"JSON payment normalized without changing amount: "+kind)
	var path:="user://artisan-queue-test.json"
	expect(game.SaveSystem.save_at(game,path) and game.SaveSystem.load_at(restored,path),"artisan queue survives actual atomic disk save and load")
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var broken:=parsed.duplicate(true); broken.estate.expansion.basement.objects[0].production.queue[0].duration=0.01
	expect(not game.SaveSystem.ValidationSystem.valid(broken),"forged accelerated production rejected")
	broken=parsed.duplicate(true); broken.estate.expansion.basement.objects[0].production.queue[0].paid.apple=999
	expect(not game.SaveSystem.ValidationSystem.valid(broken),"forged dismantle refund rejected")
	Production.update(restored,60); expect(restored.inventory_item_count("apple_juice")==2,"loaded job finishes once")
	restored.free(); game.free()

## Сценарий: новые спрайты действительно нарезаны на уровни, ракурсы, кучи и иконки.
## Исходное состояние: 169 ресурсов с исходной альфой и измеренными целыми регионами.
## Ожидаемый результат: регионы не включают соседей, основание и пропорции постоянны, старый задний слот использует передний рисунок.
func test_original_sprite_regions() -> void:
	for kind in Visual.SPRITES:
		for tier in 4:
			for direction in 4:
				var texture:AtlasTexture=Visual.SPRITES[kind][tier][direction]
				expect(texture.filter_clip and texture.region.position==texture.region.position.floor() and texture.region.size==texture.region.size.floor(),"integer clipped sprite region: %s %d %d"%[kind,tier,direction])
				expect(transparent_edge(texture.get_image()),"intact transparent sprite edge: %s %d %d"%[kind,tier,direction])
				var item:Dictionary={"kind":kind,"x":25,"y":18,"level":mini(tier+1,3),"direction":direction}
				var dest:=preload("res://scripts/presentation/basement_visual_system.gd").destination(item,tier==3)
				expect(is_equal_approx(dest.end.y,Basement.Layout.rect(item).end.y) and is_equal_approx(dest.size.x/dest.size.y,texture.region.size.x/texture.region.size.y),"fixed ground pivot and proportional silhouette")
			if tier<3: expect(Visual.SPRITES[kind][tier][0]==Visual.SPRITES[kind][tier][2],"legacy rear slot uses approved front art: "+kind)
	for kind in Visual.ITEMS: expect(transparent_edge(Visual.ITEMS[kind].get_image()),"intact standalone inventory icon: "+kind)

## Сценарий: изделия новых ремёсел участвуют в существующей алхимической прогрессии.
## Исходное состояние: публичная лаборатория, открытый талант и максимальный изученный ранг.
## Ожидаемый результат: восемь новых путей реально расходуют ингредиенты и дают канонические действующие препараты.
func test_new_alchemy_routes() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.player=preload("res://scripts/systems/alchemy_system.gd").STATION
	game.talent_levels["craft_alchemy"]=1; preload("res://scripts/systems/alchemy_system.gd").state(game).xp=1000
	for recipe in Recipes.RECIPES:
		if recipe.station!="alchemy": continue
		game.open_crafting("alchemy")
		for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material]))
		var before:int=game.inventory_item_count(recipe.output)
		var index:int=game.CraftingSystem.RECIPES.find_custom(func(value): return value.get("id","")==recipe.id)
		expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count(recipe.output)==before+int(recipe.count),"artisan material enables actual alchemy: "+recipe.id)
	game.free()

## Проверяет край по видимой альфе, допуская только исходный шум до семи процентов непрозрачности.
func transparent_edge(image: Image) -> bool:
	for x in image.get_width():
		if image.get_pixel(x,0).a>=0.07 or image.get_pixel(x,image.get_height()-1).a>=0.07: return false
	for y in image.get_height():
		if image.get_pixel(0,y).a>=0.07 or image.get_pixel(image.get_width()-1,y).a>=0.07: return false
	return true
