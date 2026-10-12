extends "res://tests/suites/suite_base.gd"

const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Alchemy := preload("res://scripts/systems/alchemy_system.gd")
const Flies := preload("res://scripts/systems/cave_boss_projectile_system.gd")

## Запускает проверки реальных ресурсов, временных эффектов, укусов, добычи и игрового времени.
func run() -> void:
	test_all_potions_apply_registered_effects()
	test_cleansing_repellent_pause_and_expiration()
	test_mining_oil_and_regeneration_elapsed_time()

## Сценарий: каждый новый расходник применяется через обычный инвентарь.
## Исходное состояние: ресурсы снижены, лаборатории нет, эффекты ещё не действуют.
## Ожидаемый результат: предмет расходуется один раз и меняет только объявленные ресурсы или длительности.
func test_all_potions_apply_registered_effects() -> void:
	var game:=make_game()
	for kind in Products.POTIONS:
		var data:Dictionary=Products.POTIONS[kind]; game.player_hp=10; game.player_mana=0; game.energy=0
		game.change_inventory_count(kind,1)
		expect(game.PotionSystem.is_potion(kind) and game.consume_item(kind) and game.inventory_item_count(kind)==0,"alchemy consumable uses real inventory pipeline: "+kind)
		expect(game.player_hp==mini(10+int(data.get("heal",0)),game.player_max_hp) and game.player_mana==mini(int(data.get("mana",0)),game.player_max_mana) and game.energy==mini(int(data.get("energy",0)),game.SkillSystem.max_stamina(game)),"potion applies its exact instant effects: "+kind)
		if data.has("timer"): expect(game.get(data.timer)==data.duration,"potion starts exact combat duration: "+kind)
		if data.has("effect"): expect(Alchemy.remaining(game,data.effect)==data.duration,"potion starts exact household duration: "+kind)
		expect(not game.consume_item(kind),"empty stack cannot reapply effects: "+kind)
	game.strength_timer=80.0; game.change_inventory_count("hunter_elixir",1); game.consume_item("hunter_elixir")
	expect(game.strength_timer==80.0,"shorter same-family potion cannot weaken or stack duration")
	game.state.world.estate.level=4; game.speed_timer=0.0; game.change_inventory_count("wind_step_elixir",1); game.consume_item("wind_step_elixir")
	expect(is_equal_approx(game.speed_timer,40.0*game.EstateSystem.potion_multiplier(game)),"laboratory duration multiplier matches declared effect")
	game.free()

## Сценарий: очищение снимает прикреплённую муху, а бальзам предотвращает новые укусы.
## Исходное состояние: герой укушен, затем применяет два разных препарата и открывает алхимию.
## Ожидаемый результат: отвар очищает без защиты, бальзам блокирует укусы, окно останавливает время, истёкший эффект исчезает.
func test_cleansing_repellent_pause_and_expiration() -> void:
	var game:=make_game(); expect(Flies.attach_fly(game,4.0),"fly genuinely attaches before cleansing")
	game.change_inventory_count("purifying_decoction",1); game.consume_item("purifying_decoction")
	expect(game.state.world.cave_boss.fly_timer==0.0 and Flies.attach_fly(game,3.0),"decoction removes current bites without granting immunity")
	game.change_inventory_count("insect_repellent",1); game.consume_item("insect_repellent")
	expect(game.state.world.cave_boss.fly_timer==0.0 and not Flies.attach_fly(game,5.0),"repellent cleanses and blocks incoming fly attachment")
	game.state.player.blocking=true; game.energy=5
	expect(not Flies.attach_fly(game,3.0) and game.energy==5,"repellent prevents unnecessary block stamina cost")
	game.state.player.blocking=false
	game.CraftingSystem.open(game,"alchemy"); var time:float=game.game_minutes; var hp:int=game.player_hp
	game._physics_process(20.0)
	expect(Alchemy.remaining(game,"repellent")==60.0 and game.game_minutes==time and game.player_hp==hp,"alchemy window pauses buffs, clock and damage together")
	game.crafting_open=false; game.update_status_effects(60.0)
	expect(Alchemy.remaining(game,"repellent")==0.0 and Flies.attach_fly(game,2.0),"flies can attach only after full protection expiration")
	expect(game.tutorial_events_completed.has("alchemy_effects"),"first preparation teaches practical effects")
	game.free()

## Сценарий: масло увеличивает реальный выход кирки, а регенерация не лечит после своего срока.
## Исходное состояние: доступны жила и кирка, ранги добычи неизменны, временные эффекты запущены.
## Ожидаемый результат: один удар даёт дополнительный ресурс без скидки прочности, большие шаги времени не удваивают лечение.
func test_mining_oil_and_regeneration_elapsed_time() -> void:
	var game:=make_game(); var index:int=game.resource_nodes.find_custom(func(node): return node.kind=="stone" and node.hits>0)
	game.current_location=game.resource_nodes[index].location; game.player=game.resource_nodes[index].position; game.has_pickaxe=true; game.selected_tool=game.Tool.PICKAXE
	var base:int=game.SkillSystem.mined_count(game); var count:int=game.inventory_item_count("stone"); var durability:int=game.state.inventory.durability.pickaxe
	game.change_inventory_count("miners_oil",1); game.consume_item("miners_oil")
	expect(game.ResourceSystem.mine(game,index) and game.inventory_item_count("stone")==count+base+1,"miner oil adds one actual resource to a pickaxe hit")
	expect(game.state.inventory.durability.pickaxe==durability-1,"enhanced mining preserves ordinary tool wear")
	game.update_status_effects(60.0); expect(game.SkillSystem.mined_count(game)==base,"mining bonus expires without permanent skill mutation")
	game.player_max_hp=500; game.player_hp=1; game.change_inventory_count("life_balsam",1); game.consume_item("life_balsam")
	game.update_status_effects(60.0)
	expect(game.player_hp==151 and game.regeneration_timer==0.0,"thirty-second regeneration heals exactly one hundred fifty over a sixty-second step")
	game.free()
