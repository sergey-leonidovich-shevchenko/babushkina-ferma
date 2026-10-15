extends "res://tests/suites/suite_base.gd"

const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")

## Проверяет сохранение количества сквозь перенос, крафт, стройку и настоящее продолжение слота.
func run() -> void:
	test_transfer_journal_and_save_boundaries()
	test_unique_crafting_and_zero_delta()
	test_every_foundation_payment_and_salvage()

## Снимает полное постоянное состояние до команды, не включая сообщения об отказе и положение курсора.
func persistent(game: Node) -> Dictionary:
	return game.SaveSystem.snapshot(game)

## Проверяет точную дельту всех зарегистрированных предметов, включая уникальные флаги героя.
func delta_matches(game: Node, before: Dictionary, delta: Dictionary) -> bool:
	for kind in game.InventorySystem.ITEM_DATA:
		if game.inventory_item_count(kind)!=int(before.get(kind,0))+int(delta.get(kind,0)): return false
	return true

## Снимает количества всех предметов через общий интерфейс, а не только стеки обычного рюкзака.
func counts(game: Node) -> Dictionary:
	var result:={}
	for kind in game.InventorySystem.ITEM_DATA: result[kind]=game.inventory_item_count(kind)
	return result

## Сценарий: воспроизводимый журнал переносов со сменой направления, отказами и загрузкой между командами.
## Исходное состояние: установлен сундук, пять разных стеков и уникальный лук, две сотни команд.
## Ожидаемый результат: сумма двух инвентарей постоянна на каждом шаге; неудача ничего не меняет.
func test_transfer_journal_and_save_boundaries() -> void:
	var game:=make_game(); game.home_chest_owned=true; game.current_location="cottage_interior"
	var kinds:=["wood","apple","log","research_ink","flower","bow"]
	for kind in kinds: game.change_inventory_count(kind,1 if kind=="bow" else 17)
	var totals:={}
	for kind in kinds: totals[kind]=game.inventory_item_count(kind)+game.state.storage.count(kind)
	for step in 200:
		var kind:String=kinds[(step*17+step/7)%kinds.size()]; var amount:=(step*13)%23-2
		var before:=persistent(game)
		var success:bool=game.StorageSystem.deposit(game,kind,amount) if step%3==0 else game.StorageSystem.withdraw(game,kind,amount)
		var conserved:=true
		for item in kinds: conserved=conserved and game.inventory_item_count(item)+game.state.storage.count(item)==int(totals[item])
		expect(conserved,"all hero/chest quantities conserved at journal step %d"%step)
		if not success: expect(persistent(game)==before,"failed transfer changes no persistent state at step %d"%step)
		if step%31==0:
			var loaded:=make_game(); expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(persistent(game)))),"transfer journal resumes through JSON at step %d"%step)
			game.free(); game=loaded
	game.free()

## Сценарий: повторное создание уникального оружия, пакетная команда и нулевая операция над инструментами.
## Исходное состояние: запас на много мечей и активный бонус пятого крафта, затем уже полученный меч.
## Ожидаемый результат: выдаётся один предмет за одну цену; повторы не списывают ресурсы, ноль не удаляет оружие.
func test_unique_crafting_and_zero_delta() -> void:
	var game:=make_game(); game.wood=100; game.slime_gel=100; game.sword_crafted=false
	game.talent_levels.craft_master=1; game.state.player.profile.workbench_crafts=4
	var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output=="sword")
	var recipe:Dictionary=game.CraftingSystem.RECIPES[index]; var before:=counts(game); var delta:={"sword":1}
	for kind in recipe.inputs: delta[kind]=-game.CraftingSystem.material_cost(game,recipe,kind)
	expect(game.CraftingSystem.max_craftable(game,recipe)==1 and game.CraftingSystem.craft_many(game,index,99)==1,"bulk unique crafting pays for one sword only")
	expect(delta_matches(game,before,delta),"unique recipe delta equals its registered input and single output")
	var saved:=persistent(game)
	expect(not game.CraftingSystem.craft(game,index) and game.CraftingSystem.craft_many(game,index,99)==0 and persistent(game)==saved,"repeated unique crafting refuses before resource XP or counter changes")
	for kind in game.InventorySystem.UNIQUE_ITEMS:
		game.change_inventory_count(kind,1); saved=persistent(game)
		expect(game.change_inventory_count(kind,0) and persistent(game)==saved,"zero delta preserves unique item and all equipment: "+kind)
	game.free()

## Сценарий: каждый станок оплачивается, сохраняется и демонтируется через настоящий чертёж.
## Исходное состояние: пустой подвал и точный комплект каждого зарегистрированного основания.
## Ожидаемый результат: дельта соответствует каталогу, повтор и пересечение атомарны, возврат не повторяется.
func test_every_foundation_payment_and_salvage() -> void:
	var game:=make_game(); game.current_location=Basement.Data.LOCATION; game.player=Basement.Data.BOARD
	for kind in Basement.Data.STATIONS:
		var cost:Dictionary=Basement.Data.STATIONS[kind].inputs; var debit:={}
		for material in cost: game.change_inventory_count(material,int(cost[material])); debit[material]=-int(cost[material])
		Basement.open(game); Basement.ui(game).placing=true
		var before:=counts(game); var candidate:={"kind":kind,"x":25,"y":18,"direction":0}
		expect(Build.build(game,candidate) and delta_matches(game,before,debit),"complete foundation pays registered ingredients once: "+kind)
		var saved:=persistent(game)
		expect(not Build.build(game,candidate) and persistent(game)==saved,"duplicate confirmation after closing blueprint is atomic: "+kind)
		Basement.open(game); Basement.ui(game).placing=true; saved=persistent(game)
		expect(not Build.build(game,candidate) and persistent(game)==saved,"overlapping placement refuses without partial payment: "+kind)
		var loaded:=make_game(); expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(saved))),"paid foundation and ledger survive JSON: "+kind)
		game.free(); game=loaded; game.player=Basement.Data.BOARD; Basement.open(game)
		var item:Dictionary=Basement.state(game).objects.back(); var output:=Build.salvage(item); before=counts(game)
		expect(Build.dismantle(game,int(item.id)) and delta_matches(game,before,output),"dismantling grants exactly the advertised ledger salvage: "+kind)
		saved=persistent(game)
		expect(not Build.dismantle(game,int(item.id)) and persistent(game)==saved,"repeat dismantling cannot grant another return: "+kind)
	game.free()
