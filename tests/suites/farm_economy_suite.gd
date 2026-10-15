extends "res://tests/suites/suite_base.gd"

const Animals := preload("res://scripts/systems/livestock_system.gd")

## Проверяет воспроизводимый семидневный маршрут без выдачи ресурсов разработчика.
func run() -> void:
	test_seven_day_household()

## Сценарий: новичок выращивает морковь, ухаживает за двором и продаёт переработанную продукцию.
## Исходное состояние: обычные двадцать монет, восемь семян и четыре стартовые порции корма.
## Ожидаемый результат: семь дней проходят без отрицательных запасов и замыкают три хозяйственных цикла.
func test_seven_day_household() -> void:
	var rows := household()
	expect(rows.size()==7 and int(rows[-1].coins)>20,"seven ordinary days fund feed and seed renewals")
	expect(int(rows[-1].mayonnaise_sold)>0 and int(rows[-1].butter_sold)>0,"eggs and milk reach actual processed sales")

## Проходит игровые операции, меняя только положение героя между доступными рабочими точками.
func household() -> Array:
	var game:=make_game(); var rows:Array=[]; var mayo:=0; var butter:=0
	var initial:Dictionary=game.export_inventory_counts()
	expect(game.coins==20 and initial.seeds==8 and initial.animal_feed==4,"ordinary start has no cabinet grants")
	for day in range(1,8):
		game.current_location="overworld"
		var value:Dictionary=game.FarmLifeSystem.state(game)
		Animals.update(game,value,0)
		for animal in Animals.Data.ANIMALS:
			Animals.interact(game,value,"life:animal:"+animal.id)
		if game.inventory_item_count("animal_feed")==0: buy(game,"animal_feed")
		Animals.feed(game,value); Animals.interact(game,value,"life:water")
		if game.inventory_item_count("seeds")<2: buy(game,"seeds")
		for index in 2:
			game.player=Vector2(game.FARM_ORIGIN)+Vector2(24+index*48,24)-Vector2(42,0); game.facing=Vector2.RIGHT
			game.selected_hotbar=1; game.selected_tool=game.Tool.HOE; game.use_selected_tool()
			game.selected_tool=game.Tool.SEEDS; game.use_selected_tool()
			game.selected_tool=game.Tool.WATER; game.use_selected_tool()
			var plot:Dictionary=game.plots[Vector2i(index,0)]
			game.FarmSystem.update_plot(game,plot,100)
			game.use_selected_tool(); game.FarmSystem.update_plot(game,plot,100)
			game.selected_tool=game.Tool.HAND; game.use_selected_tool()
			expect(not plot.planted,"ordinary two-water crop harvested on day %d"%day)
		game.current_location="cottage_interior"; game.crafting_station="cauldron"
		while game.inventory_item_count("egg")>0:
			if not craft(game,"kitchen:mayonnaise"): break
			sell(game,"mayonnaise"); mayo+=1
		while game.inventory_item_count("milk")>=2:
			if not craft(game,"kitchen:butter"): break
			sell(game,"butter"); butter+=1
		while game.inventory_item_count("carrot")>0: sell(game,"carrot")
		rows.append({"day":day,"coins":game.coins,"energy_left":game.energy,"seeds":game.inventory_item_count("seeds"),"feed":game.inventory_item_count("animal_feed"),"milk":game.inventory_item_count("milk"),"mayonnaise_sold":mayo,"butter_sold":butter,"level":game.player_level})
		expect(game.energy>=0 and game.coins>=0,"household stays within its actual energy and coin budget")
		if day<7: game.sleep_until_morning()
	game.free(); return rows

## Покупает настоящий ограниченный дневной товар вместо выдачи его тестовым инвентарём.
func buy(game: Node, kind: String) -> void:
	for index in game.shop_products.size():
		if game.shop_products[index].kind==kind:
			expect(game.ShopSystem.buy(game,index),"household buys "+kind); return
	expect(false,"missing household product "+kind)

## Продаёт готовый предмет по настоящей цене с учётом качества и репутации.
func sell(game: Node, kind: String) -> void:
	for index in game.shop_products.size():
		if game.shop_products[index].kind==kind:
			expect(game.ShopSystem.sell(game,index),"household sells "+kind); return
	expect(false,"missing household sale "+kind)

## Выполняет зарегистрированный доступный рецепт без обхода стоимости и талантов.
func craft(game: Node, id: String) -> bool:
	for index in game.CraftingSystem.RECIPES.size():
		if game.CraftingSystem.RECIPES[index].get("id","")==id:
			var result:bool=game.CraftingSystem.craft(game,index)
			expect(result,"household crafts "+id); return result
	expect(false,"missing household recipe "+id)
	return false
