extends "res://tests/suites/suite_base.gd"

const Attack := preload("res://scripts/systems/player_attack_system.gd")
const Shots := preload("res://scripts/systems/player_projectile_system.gd")

## Проверяет подготовку, физический полёт, промахи, прерывание, снимки и отсутствие старых атак после загрузки.
func run() -> void:
	test_every_weapon_waits_for_contact()
	test_miss_interrupt_and_snapshot()
	test_projectile_cover_and_interception()
	test_minion_identity_and_all_target_categories()
	test_pause_and_save_reset()
	test_room_transition_and_defeat_cancel_threats()

## Создаёт настоящий боевой мир на проверенном свободном полу без вмешательства других существ.
func arena(weapon: String = "forest_sword") -> Node:
	var game := make_game(); game.current_location="cave"; game.player=Vector2(1020,520)
	game.resource_nodes.clear(); game.wildlife_nodes.clear(); game.hazard_nodes.clear()
	var enemy: Dictionary = game.enemy_nodes[0].duplicate(true)
	enemy.kind="orc"; enemy.location="cave"; enemy.position=Vector2(1080,520); enemy.hp=50; enemy.max_hp=50; enemy.alive=true
	game.enemy_nodes=[enemy]
	game.change_inventory_count(game.WeaponSystem.item_kind(weapon),1); game.equipped_weapon=weapon
	game.FarmLifeSystem.state(game).cutscene=""; game.FirstChapterSystem.state(game).completed=true
	return game

## Сценарий: все девять классов оружия начинают замах против неподвижной живой цели.
## Исходное состояние: исправное оружие, пустая серия, свободный пол; дальние классы имеют 200 пикселей до врага.
## Ожидаемый результат: до контактной фазы нет урона и остановки, после неё только одно попадание или один физический снаряд.
func test_every_weapon_waits_for_contact() -> void:
	for weapon in game_weapons():
		var game := arena(weapon)
		var ranged: bool = game.WeaponSystem.weapon_class(weapon) in ["bow","staff"]
		if ranged: game.player=Vector2(880,520)
		var hp: int = game.enemy_nodes[0].hp
		expect(game.CombatSystem.attack(game,0),"weapon begins one prepared attack: "+weapon)
		var windup: float = game.get_meta(Attack.KEY).contact
		game.WeaponSystem.update(game,windup-0.001)
		expect(game.enemy_nodes[0].hp==hp and Shots.state(game).is_empty() and game.FarmLifeSystem.state(game).hit_stop==0.0,"preparation never damages or emits early shot: "+weapon)
		game.WeaponSystem.update(game,0.002)
		if ranged:
			expect(game.enemy_nodes[0].hp==hp and Shots.state(game).size()==1,"ranged release starts physical travel: "+weapon)
			game.WeaponSystem.update(game,0.7)
		expect(game.enemy_nodes[0].hp<hp and game.state.player.combat_hits==1,"actual contact damages once: "+weapon)
		var after: int = game.enemy_nodes[0].hp
		game.WeaponSystem.update(game,3.0)
		expect(game.enemy_nodes[0].hp==after and Shots.state(game).is_empty(),"recovery cannot repeat damage: "+weapon)
		game.free()

## Возвращает полный опубликованный каталог оружия без безоружного резервного режима.
func game_weapons() -> Array:
	return preload("res://scripts/systems/weapon_system.gd").ORDER

## Сценарий: цель уходит из замаха, герой получает удар, затем меняет экипировку в новой атаке.
## Исходное состояние: меч или лук готовы; здоровье и усиления фиксируются в начале, серия считается только по попаданиям.
## Ожидаемый результат: уход и прерывание дают промах; смена оружия не меняет урон; выпущенную стрелу входящий удар не отменяет.
func test_miss_interrupt_and_snapshot() -> void:
	for weapon in ["forest_sword","bow","moon_staff"]:
		var game := arena(weapon)
		if weapon!="forest_sword": game.player=Vector2(880,520)
		expect(game.CombatSystem.attack(game,0),"miss begins attack")
		game.enemy_nodes[0].position+=Vector2(0,100)
		game.WeaponSystem.update(game,2.0)
		expect(game.enemy_nodes[0].hp==50 and game.state.player.combat_hits==0,"moved target is not hit by old aim: "+weapon)
		game.enemy_nodes[0].position=Vector2(1080,520)
		expect(game.CombatSystem.attack(game,0),"interrupted attack begins")
		game.CombatSystem.damage_player(game,1,"interrupt")
		game.WeaponSystem.update(game,2.0)
		expect(game.enemy_nodes[0].hp==50 and Shots.state(game).is_empty(),"hurt cancels unreleased attack: "+weapon)
		game.free()
	var game := arena("war_hammer")
	var expected: int = roundi(game.CombatSystem.player_attack_damage(game)*game.FarmLifeSystem.vulnerability("orc","war_hammer"))
	expect(game.CombatSystem.attack(game,0),"snapshot hammer begins")
	game.equipped_weapon="none"; game.facing=Vector2.LEFT; game.strength_timer=30
	game.WeaponSystem.update(game,1.5)
	expect(game.enemy_nodes[0].hp==50-expected,"weapon, direction and damage snapshot survives equip and buff change")
	game.free()
	game=arena("bow"); game.player=Vector2(880,520); game.CombatSystem.attack(game,0)
	game.WeaponSystem.update(game,0.45); game.CombatSystem.damage_player(game,1,"after release"); game.WeaponSystem.update(game,0.8)
	expect(game.enemy_nodes[0].hp<50,"already released arrow survives interruption")
	game.free()

## Сценарий: герой покидает комнату до контакта, затем несколько вражеских стрел одновременно приводят к поражению.
## Исходное состояние: подготовленный лук, явная синхронизация комнаты; второй бой с пятью HP и тремя стрелами.
## Ожидаемый результат: прежний замах не возвращается после повторного входа; поражение восстанавливает HP один раз и убирает остальные угрозы.
func test_room_transition_and_defeat_cancel_threats() -> void:
	var game := arena("bow"); game.player=Vector2(880,520); game.sync_background_location()
	expect(game.CombatSystem.attack(game,0),"room transition begins pending bow")
	game.current_location="cave_fungal"; game.sync_background_location(); game.current_location="cave"; game.sync_background_location()
	game.WeaponSystem.update(game,2.0)
	expect(game.enemy_nodes[0].hp==50 and not game.has_meta(Attack.KEY) and Shots.state(game).is_empty(),"leaving and immediately reentering cannot restore old attack")
	game.player_hp=5
	var incoming := preload("res://scripts/systems/enemy_projectile_system.gd")
	for arrow in 3: incoming.launch_at(game,Vector2(1080,520),game.player,20,"arrow",320,320,"skeleton")
	incoming.update(game,1.0)
	expect(game.menu_state.defeat_open and game.player_hp==game.player_max_hp and incoming.state(game).is_empty(),"defeat discards remaining volley without damaging rescued hero")
	game.free()

## Сценарий: стрела встречает камень, а следующий выстрел перехватывает второе живое существо.
## Исходное состояние: цель в 200 пикселях, перед ней промежуточная преграда либо тело другого врага.
## Ожидаемый результат: покрытие уничтожает снаряд, первое тело получает единственный урон, исходная дальняя цель остаётся целой.
func test_projectile_cover_and_interception() -> void:
	var game := arena("bow"); game.player=Vector2(880,520)
	var stone: Dictionary = game.ResourceSystem.default_nodes()[0].duplicate(true)
	stone.location="cave"; stone.position=Vector2(980,520); stone.hits=4; game.resource_nodes=[stone]
	game.CombatSystem.attack(game,0); game.WeaponSystem.update(game,1.5)
	expect(game.enemy_nodes[0].hp==50 and Shots.state(game).is_empty(),"real resource cover consumes arrow before target")
	game.resource_nodes.clear()
	var interceptor: Dictionary = game.enemy_nodes[0].duplicate(true); interceptor.erase("attack_uid"); interceptor.position=Vector2(980,520)
	game.enemy_nodes.append(interceptor)
	game.CombatSystem.attack(game,0); game.WeaponSystem.update(game,1.5)
	expect(game.enemy_nodes[0].hp==50 and game.enemy_nodes[1].hp<50,"first intersected body receives projectile instead of selected far target")
	game.free()

## Сценарий: одна подготовка наносит контактный урон слизню, зверю и двум сюжетным боссам; массив миньонов меняет индексы.
## Исходное состояние: живые доступные цели в дальности меча, удалённый сосед миньона не является целью.
## Ожидаемый результат: все категории ждут контакт, устойчивый идентификатор сохраняет нужного миньона после уплотнения массива.
func test_minion_identity_and_all_target_categories() -> void:
	for category in ["slime","wildlife","moon","castle"]:
		var game := arena()
		match category:
			"slime": game.current_location="overworld"; game.player=game.slime_position-Vector2(50,0)
			"wildlife":
				var animal: Dictionary = game.WildlifeSystem.default_animals()[0].duplicate(true)
				animal.location="cave"; animal.position=Vector2(1080,520); animal.hp=50; game.wildlife_nodes=[animal]
			"moon": game.current_location="moon_glade"; game.state.world.moon_glade.guardian_alive=true; game.player=game.MoonGladeSystem.GUARDIAN_POSITION-Vector2(50,0)
			"castle": game.current_location="castle_dungeon"; game.state.world.castle_campaign.boss_alive=true; game.player=game.CastleCampaignSystem.BOSS_POSITION-Vector2(50,0)
		var before := target_hp(game,category)
		expect(Attack.begin(game,category) and target_hp(game,category)==before,"all target categories start without early damage: "+category)
		game.WeaponSystem.update(game,1.5)
		expect(target_hp(game,category)<before,"all target categories receive contact: "+category)
		game.free()
	var game := arena(); game.current_location=game.CaveBossSystem.Data.LOCATION; game.state.world.cave_boss.active=true; game.player=Vector2(1468,640)
	game.enemy_nodes.clear()
	game.state.world.cave_boss.minions=[{"kind":"skeleton","alive":true,"hp":20,"position":Vector2(1468,740),"emerge":0.0},{"kind":"zombie","alive":true,"hp":20,"position":Vector2(1528,640),"emerge":0.0}]
	expect(game.CaveBossSystem.Minions.attack(game,1),"minion starts prepared strike")
	game.state.world.cave_boss.minions.remove_at(0); game.WeaponSystem.update(game,1.5)
	expect(game.state.world.cave_boss.minions[0].hp<20,"minion identity survives removal of an earlier array member")
	game.free()

## Читает здоровье четырёх независимых адаптеров, не запуская их атаки или награды.
func target_hp(game: Node, category: String) -> int:
	match category:
		"slime": return game.slime_hp
		"wildlife": return game.wildlife_nodes[0].hp
		"moon": return game.state.world.moon_glade.guardian_hp
		"castle": return game.state.world.castle_campaign.boss_hp
	return 0

## Сценарий: меню замораживает подготовку и полёт, успешная загрузка убирает старые замахи обеих сторон.
## Исходное состояние: стартовый слот сериализован до атаки; затем герой и стрелок готовят контакт, растение готовит плевок.
## Ожидаемый результат: пауза не продвигает события; повреждённый документ ничего не сбрасывает, валидная загрузка очищает все угрозы.
func test_pause_and_save_reset() -> void:
	var game := make_game(); game.current_location="cave"; game.player=Vector2(880,520); game.has_bow=true; game.equipped_weapon="bow"
	var index: int = game.enemy_nodes.find_custom(func(enemy): return enemy.kind=="skeleton" and enemy.location=="cave")
	for enemy in game.enemy_nodes: enemy.alive=false
	game.enemy_nodes[index].alive=true; game.enemy_nodes[index].position=Vector2(1080,520)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	expect(game.CombatSystem.attack(game,index),"save reset test prepares attack")
	game.inventory_open=true; var elapsed: float=game.get_meta(Attack.KEY).elapsed
	Attack.update(game,10.0)
	expect(game.get_meta(Attack.KEY).elapsed==elapsed and Shots.state(game).is_empty(),"full screen menu freezes windup")
	game.inventory_open=false; game.WeaponSystem.update(game,0.45)
	var position: Vector2=Shots.state(game)[0].position; game.menu_state.pause_open=true; Attack.update(game,10.0)
	expect(Shots.state(game)[0].position==position,"pause freezes existing physical projectile")
	game.menu_state.pause_open=false
	game.enemy_nodes[index].attack_pending=true; game.enemy_nodes[index].impact_timer=0.1
	expect(not game.SaveSystem.apply(game,{}) and not Shots.state(game).is_empty(),"failed save validation preserves live combat")
	expect(game.SaveSystem.apply(game,saved),"valid save applies")
	expect(Shots.state(game).is_empty() and not game.has_meta(Attack.KEY) and not game.enemy_nodes[index].attack_pending and game.player_attack_timer==0.0,"successful load clears both sides of transient combat")
	game.free()
