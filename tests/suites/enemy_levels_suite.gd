extends "res://tests/suites/suite_base.gd"

## Запускает все сценарии уровней врагов, поведения угроз, обликов и сохранения.
func run() -> void:
	test_enemy_catalog_scaling_and_ranked_loot()
	test_mobile_and_rooted_enemy_behaviour()
	test_environment_hazards_damage_and_block_movement()
	test_rank_atlases_and_hero_level_cap()
	test_enemy_runtime_state_is_saved()
	test_ranked_discovery_cards_are_distinct()


## Сценарий: каждое семейство имеет пять уровней, возрастающие характеристики и усиленную добычу.
## Исходное состояние: новый мир со стандартным каталогом из пяти семейств противников.
## Ожидаемый результат: уровни полны, здоровье с опытом растут, а элита оставляет втрое больше предметов.
func test_enemy_catalog_scaling_and_ranked_loot() -> void:
	var game := make_game()
	expect(game.enemy_nodes.size() == 30, "five ranked families and five pirate encounters populate the world")
	for kind in game.CombatSystem.FAMILY_ORDER:
		var levels: Array = game.enemy_nodes.filter(func(enemy): return enemy.kind == kind).map(func(enemy): return enemy.level)
		expect(levels == [1, 2, 3, 4, 5], "%s family contains levels one through five" % kind)
	expect(game.CombatSystem.max_hp("orc", 5) > game.CombatSystem.max_hp("orc", 1), "higher enemy levels gain health")
	expect(game.CombatSystem.attack_damage("orc", 5) > game.CombatSystem.attack_damage("orc", 1), "higher enemy levels deal more damage")
	expect(game.CombatSystem.xp_reward("orc", 5) > game.CombatSystem.xp_reward("orc", 1), "higher enemy levels grant more experience")
	expect(game.CombatSystem.visual_rank(1) == 0 and game.CombatSystem.visual_rank(3) == 1 and game.CombatSystem.visual_rank(5) == 2, "enemy levels select ordinary veteran and elite sprites")
	game.current_location = "cave"
	var elite_skeleton_index := 16
	expect(game.CombatSystem.apply_damage(game, elite_skeleton_index, 999), "elite enemy can be defeated through shared damage pipeline")
	var bone_drop: Dictionary = game.dropped_items.filter(func(item): return item.kind == "bones")[0]
	expect(bone_drop.count == 9 and game.tutorial_events_completed.has("enemy_levels"), "elite loot is tripled and ranked combat completes its tutorial")
	game.free()


## Сценарий: орк преследует героя, а укоренённое хищное растение остаётся на месте и атакует издали.
## Исходное состояние: выбранные враги живы, находятся в своей локации и видят героя в радиусе агрессии.
## Ожидаемый результат: мобильный враг меняет позицию, растение нет, но оба используют общий урон.
func test_mobile_and_rooted_enemy_behaviour() -> void:
	var game := make_game()
	game.current_location = "ruins"
	game.enemy_nodes[1].position = Vector2(900, 500)
	game.player = Vector2(1120, 500)
	var orc_start: Vector2 = game.enemy_nodes[1].position
	game.CombatSystem.update(game, 0.2)
	expect(game.enemy_nodes[1].position.x > orc_start.x and game.enemy_nodes[1].moving, "mobile enemy immediately chases in the required direction")
	expect(game.tutorial_events_completed.has("enemy_movement"), "first enemy chase completes movement tutorial step")
	game.current_location = "forest"
	game.player_hp = game.player_max_hp
	game.player = game.enemy_nodes[0].position + Vector2(100, 0)
	var plant_start: Vector2 = game.enemy_nodes[0].position
	game.CombatSystem.update(game, 0.1)
	expect(game.enemy_nodes[0].position == plant_start and not game.enemy_nodes[0].moving, "rooted predator plant never changes position")
	expect(game.player_hp == game.player_max_hp and game.enemy_nodes[0].visual_state == "attack", "rooted predator plant shows a ranged windup from its configured range")
	game.CombatSystem.update(game, 0.26)
	expect(game.player_hp < game.player_max_hp, "rooted predator plant deals damage on its contact frame")
	game.free()


## Сценарий: кактус ранит при касании, колючий цветок стреляет, а клетки растений непроходимы.
## Исходное состояние: герой с полным здоровьем по очереди помещён рядом с двумя угрозами.
## Ожидаемый результат: оба режима наносят масштабируемый урон, отмечаются в туториале и блокируют движение.
func test_environment_hazards_damage_and_block_movement() -> void:
	var game := make_game()
	expect(game.hazard_nodes.size() == 9, "three stationary hazard families expose three visual ranks")
	expect(game.EnvironmentHazardSystem.damage("cactus", 5) > game.EnvironmentHazardSystem.damage("cactus", 1), "hazard damage grows with its level")
	game.current_location = "rocky"
	var cactus: Dictionary = game.hazard_nodes[6]
	game.player = cactus.position + Vector2(50, 0)
	var hp_before: int = game.player_hp
	game.EnvironmentHazardSystem.update(game, 0.1)
	expect(game.player_hp < hp_before and game.tutorial_events_completed.has("contact_hazard"), "cactus causes contact damage and explains the feature")
	expect(not game.NavigationSystem.is_walkable(game, cactus.position), "hero cannot walk through cactus collision")
	game.current_location = "forest"
	var bloom: Dictionary = game.hazard_nodes[3]
	game.player = bloom.position + Vector2(120, 0)
	hp_before = game.player_hp
	game.EnvironmentHazardSystem.update(game, 0.1)
	expect(game.player_hp < hp_before and game.tutorial_events_completed.has("static_attacker"), "thorn bloom performs a stationary ranged attack")
	game.free()


## Сценарий: новые атласы имеют ожидаемую сетку, а герой меняет четыре облика до максимального уровня 20.
## Исходное состояние: новый герой первого уровня и импортированные прозрачные текстуры рангов.
## Ожидаемый результат: размеры атласов стабильны, границы обликов верны и опыт не превышает потолок.
func test_rank_atlases_and_hero_level_cap() -> void:
	var game := make_game()
	expect(game.ENEMY_RANK_ATLAS.get_size() == Vector2(1620, 972), "enemy rank atlas keeps exact five by three source grid")
	expect(game.HAZARD_RANK_ATLAS.get_size() == Vector2(1254, 1254), "hazard rank atlas keeps exact three by three source grid")
	expect(game.DirectionalCharacterSystem.HERO_TEXTURES.size()==4 and game.DirectionalCharacterSystem.profiles_are_valid(), "four hero progression skins use current directional sheets")
	expect(game.CreatureVisualProfileSystem.profiles_are_valid() and [game.CreatureVisualProfileSystem.enemy_size(1),game.CreatureVisualProfileSystem.enemy_size(3),game.CreatureVisualProfileSystem.enemy_size(5)]==[Vector2(96,96),Vector2(120,120),Vector2(144,144)],"enemy levels resolve to three modular visual ranks")
	expect(game.CreatureVisualProfileSystem.wildlife_size()==Vector2(96,96) and game.CreatureVisualProfileSystem.hazard_size("thorn_bloom")==Vector2(120,120),"wildlife and rooted hazards use approved 96/120 px profiles")
	var preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/creatures_ingame_preview.png")); expect(preview!=null and preview.get_size()==Vector2i(1152,648),"creature migration keeps a current native gameplay preview")
	expect([game.SkillSystem.hero_skin_stage(1), game.SkillSystem.hero_skin_stage(6), game.SkillSystem.hero_skin_stage(11), game.SkillSystem.hero_skin_stage(16), game.SkillSystem.hero_skin_stage(20)] == [0, 1, 2, 3, 3], "hero appearance changes at levels six eleven and sixteen")
	game.SkillSystem.award_character_xp(game, 500)
	expect(game.player_level == 6 and game.tutorial_events_completed.has("hero_skin"), "reaching level six unlocks the second hero skin and tutorial event")
	game.SkillSystem.award_character_xp(game, 100000)
	expect(game.player_level == 20 and game.player_xp == 0, "character experience is capped cleanly at level twenty")
	game.free()


## Сценарий: изменённые уровень, позиция, направление и таймер атаки врага переживают сохранение.
## Исходное состояние: runtime-поля первого врага и первой угрозы изменены перед созданием снимка.
## Ожидаемый результат: загрузка восстанавливает их и ограничивает некорректный уровень героя двадцатым.
func test_enemy_runtime_state_is_saved() -> void:
	var game := make_game()
	game.enemy_nodes[0].level = 4
	game.enemy_nodes[0].position = Vector2(777, 333)
	game.enemy_nodes[0].direction = Vector2.LEFT
	game.enemy_nodes[0].attack_timer = 1.25
	game.hazard_nodes[0].cooldown = 0.75
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	snapshot.level = 99
	game.enemy_nodes[0].level = 1
	game.enemy_nodes[0].position = Vector2.ZERO
	game.hazard_nodes[0].cooldown = 0.0
	expect(game.SaveSystem.apply(game, snapshot), "ranked enemy snapshot loads successfully")
	expect(game.enemy_nodes[0].level == 4 and game.enemy_nodes[0].position == Vector2(777, 333), "save restores enemy level and world position")
	expect(game.enemy_nodes[0].direction == Vector2.LEFT and is_equal_approx(game.enemy_nodes[0].attack_timer, 1.25), "save restores enemy facing and attack cooldown")
	expect(is_equal_approx(game.hazard_nodes[0].cooldown, 0.75) and game.player_level == 20, "save restores hazard cooldown and clamps hero level")
	game.free()


## Сценарий: карточки обнаружения различают уровни одного врага и описывают природные угрозы.
## Исходное состояние: новый мир с локалью по умолчанию и пустой историей обнаружений.
## Ожидаемый результат: заголовки содержат уровень, а разные ранги не подавляют подсказки друг друга.
func test_ranked_discovery_cards_are_distinct() -> void:
	var game := make_game()
	var enemy_hint: Dictionary = game.DiscoverySystem.enemy_hint(game, "orc", 4)
	var hazard_hint: Dictionary = game.DiscoverySystem.hazard_hint(game, "cactus", 5)
	expect(enemy_hint.title.contains("4") and enemy_hint.text == game.LocaleSystem.ui("hint_enemy"), "enemy discovery card displays its level")
	expect(hazard_hint.title.contains("5") and hazard_hint.text == game.LocaleSystem.ui("hint_hazard"), "hazard discovery card explains stationary danger")
	expect(game.DiscoverySystem.show(game, "enemy:orc:1", enemy_hint) and game.DiscoverySystem.show(game, "enemy:orc:5", enemy_hint), "different levels of one family have independent discoveries")
	game.free()
