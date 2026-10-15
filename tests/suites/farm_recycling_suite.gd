extends "res://tests/suites/suite_base.gd"

const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")

## Проверяет возвраты всех оплаченных уровней и замкнутый стекольный цикл через настоящие станки.
func run() -> void:
	test_paid_levels_and_future_refunds()
	test_glass_loop_has_real_cost()

## Сценарий: каждый станок последовательно строится и улучшается, возврат проверяется до завершения работ.
## Исходное состояние: оплачен только первый уровень, затем отдельно второй и третий.
## Ожидаемый результат: возвращается половина накопленного журнала, будущие компоненты не возникают.
func test_paid_levels_and_future_refunds() -> void:
	var game:=make_game(); game.current_location=Basement.Data.LOCATION; game.player=Basement.Data.BOARD
	for kind in Basement.Data.STATIONS:
		var base:Dictionary=Basement.Data.STATIONS[kind].inputs
		for material in base: game.change_inventory_count(material,int(base[material]))
		Basement.open(game); Basement.ui(game).placing=true
		expect(Build.build(game,{"kind":kind,"x":25,"y":18,"direction":0}),"build before ledger audit: "+kind)
		var item:Dictionary=Basement.state(game).objects.back(); var paid:=base.duplicate()
		for level in range(1,4):
			expect(item.paid==paid,"ledger includes only confirmed payments: %s/%d"%[kind,level])
			var expected:={}
			for material in paid:
				var count:int=paid[material]; var returned:int=count/2; var waste:=Basement.Data.debris(material)
				if returned>0: expected[material]=int(expected.get(material,0))+returned
				expected[waste]=int(expected.get(waste,0))+count-returned
			expect(Build.salvage(item)==expected,"half rounded down plus actual waste: %s/%d"%[kind,level])
			var future:=item.duplicate(true); future.target=3
			expect(Build.salvage(future)==expected,"target tier alone grants no future resources: "+kind)
			Build.finish(game,item)
			if level==3: break
			var cost:=Basement.Data.upgrade_cost(kind,level); game.coins+=int(cost.get("coins",0))
			for material in cost.inputs: game.change_inventory_count(material,int(cost.inputs[material]))
			game.player=Basement.Data.BOARD; Basement.open(game)
			expect(Build.upgrade(game,int(item.id)),"pay next level before refund: "+kind)
			for material in cost.inputs: paid[material]=int(paid.get(material,0))+int(cost.inputs[material])
		Basement.state(game).objects.clear()
	game.free()

## Сценарий: стекло превращается в три колбы, разбирается на осколки и переплавляется обратно.
## Исходное состояние: одна единица стекла, две древесины, изученные колбы и стекло.
## Ожидаемый результат: возвращается одно стекло с расходом восемнадцати жара и шести энергии, повтор без колб атомарен.
func test_glass_loop_has_real_cost() -> void:
	var game:=make_game(); game.current_location="forge_interior"; game.player=game.FurnaceSystem.STATION
	game.change_inventory_count("glass",1); game.ResearchSystem.state(game).known=["glass","glass_vial"]
	game.crafting_station="furnace"; game.FurnaceSystem.load_fuel(game); game.FurnaceSystem.load_fuel(game)
	var value:Dictionary=game.FurnaceSystem.state(game); var heat:float=value.heat; var energy:int=game.energy
	expect(game.FurnaceSystem.enqueue(game,game.FurnaceSystem.Data.recipe("furnace:vials")),"glass enters a paid vial batch")
	game.FurnaceSystem.advance(game,value,8)
	game.crafting_station="recycling"; game.player=game.ResearchSystem.BENCH_POINT
	var index:int=game.ResearchSystem.Data.ENTRIES.find_custom(func(entry): return entry.kind=="glass_vial")
	expect(game.ResearchSystem.bulk(game,index,99)==3,"all three vials are consumed once by recycling")
	var before:Dictionary=game.SaveSystem.snapshot(game)
	expect(not game.ResearchSystem.execute(game,index) and game.SaveSystem.snapshot(game)==before,"empty repeated decomposition has no refund")
	game.crafting_station="furnace"; game.player=game.FurnaceSystem.STATION
	expect(game.FurnaceSystem.enqueue(game,game.FurnaceSystem.Data.recipe("recovery:glass")),"three shards reserve the recovery batch")
	game.FurnaceSystem.advance(game,value,10)
	expect(game.inventory_item_count("glass")==1 and game.inventory_item_count("glass_vial")==0 and game.inventory_item_count("glass_shard")==0,"closed glass loop creates no extra glass or shards")
	expect(is_equal_approx(heat-float(value.heat),18) and energy-game.energy==6,"closed loop actually pays fuel and recycling energy")
	game.free()
