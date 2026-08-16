extends "res://tests/suites/suite_base.gd"


## Запускает полный набор регрессий оружия, временных шкал боя и кузнечного обслуживания.
func run() -> void:
	test_weapon_catalog_has_distinct_classes_and_assets()
	test_crafted_weapon_equips_and_drives_runtime_profile()
	test_player_cooldown_blocks_repeat_until_recovery()
	test_enemy_windup_delays_damage_until_contact()
	test_durability_breakage_repair_and_sharpening()


## Сценарий: каталог содержит разные боевые классы с полноценными отдельными иконками.
## Исходное состояние: новая игра загрузила каталог инвентаря и кэш графических ресурсов.
## Ожидаемый результат: копьё, молот и посох имеют разные характеристики и квадратные RGBA-иконки.
func test_weapon_catalog_has_distinct_classes_and_assets() -> void:
	var game := make_game()
	expect(game.WeaponSystem.weapon_class("iron_spear") == "spear" and game.WeaponSystem.range_of("iron_spear") > game.WeaponSystem.range_of("war_hammer"), "spear and hammer expose distinct tactical profiles")
	expect(game.WeaponSystem.weapon_class("moon_staff") == "staff" and game.WeaponSystem.range_of("moon_staff") > 250.0, "moon staff is a real ranged magic weapon")
	for kind in ["iron_spear", "war_hammer", "moon_staff"]:
		var texture: Texture2D = game.item_texture(kind)
		expect(texture != null and texture.get_size() == Vector2(64, 64), "new weapon owns a centered standalone icon: %s" % kind)
		expect(game.state.inventory.durability.has(kind), "new weapon participates in durability state: %s" % kind)
	game.free()


## Сценарий: созданное на верстаке копьё можно надеть в руки без специальных условий в боевом коде.
## Исходное состояние: герою выданы доски, металл и гвозди для одного рецепта железного копья.
## Ожидаемый результат: рецепт выдаёт предмет, экипировка синхронизирует оружие и его дальность.
func test_crafted_weapon_equips_and_drives_runtime_profile() -> void:
	var game := make_game()
	game.change_inventory_count("plank", 2); game.change_inventory_count("metal", 4); game.change_inventory_count("nails", 2)
	var recipe_index: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "iron_spear")
	expect(game.CraftingSystem.craft(game, recipe_index), "iron spear can be produced through the normal crafting pipeline")
	expect(game.InventorySystem.equip(game, "iron_spear"), "crafted spear can be equipped in the hands slot")
	expect(game.equipped_weapon == "iron_spear" and game.equipment.hands == "iron_spear", "inventory equipment and combat runtime stay synchronized")
	game.free()


## Сценарий: удержание атаки не позволяет наносить новый урон до завершения индивидуальной перезарядки.
## Исходное состояние: герой с лесным мечом стоит рядом с живым хищным растением в лесу.
## Ожидаемый результат: первый удар проходит, мгновенный повтор блокируется, после таймера удар снова доступен.
func test_player_cooldown_blocks_repeat_until_recovery() -> void:
	var game := make_game()
	game.current_location = "forest"; game.change_inventory_count("sword", 1); game.InventorySystem.equip(game, "sword"); game.player = game.enemy_nodes[0].position
	expect(game.attack_nearest_enemy(), "first user-facing attack starts immediately")
	expect(game.player_attack_timer > 0.0 and game.player_attack_cooldown > 0.0 and not game.attack_nearest_enemy(), "active attack timeline blocks an immediate repeated hit")
	game.AnimationSystem.update(game, 1.0)
	expect(game.attack_nearest_enemy(), "weapon accepts a new attack after recovery")
	game.free()


## Сценарий: противник сначала показывает замах и только в контактном кадре наносит урон герою.
## Исходное состояние: герой стоит вплотную к орку, его таймер атаки завершён, здоровье полное.
## Ожидаемый результат: начало анимации не отнимает HP, контакт отнимает HP и запускает отдачу героя.
func test_enemy_windup_delays_damage_until_contact() -> void:
	var game := make_game()
	game.current_location = "ruins"; var enemy_index := 1; game.player = game.enemy_nodes[enemy_index].position; game.enemy_nodes[enemy_index].attack_timer = 0.0
	var hp_before: int = game.player_hp
	game.CombatSystem.update(game, 0.01)
	expect(game.enemy_nodes[enemy_index].visual_state == "attack" and game.enemy_nodes[enemy_index].attack_pending, "enemy enters a readable attack windup")
	expect(game.player_hp == hp_before, "windup frame does not deal invisible early damage")
	game.CombatSystem.update(game, game.CombatSystem.attack_impact_delay("melee") + 0.02)
	expect(game.player_hp < hp_before and game.player_hurt_timer > 0.0 and not game.enemy_nodes[enemy_index].attack_pending, "contact frame deals damage and starts player hit reaction")
	game.free()


## Сценарий: оружие изнашивается, ломается, полностью ремонтируется и получает постоянную заточку.
## Исходное состояние: у героя есть молот с одной единицей прочности, монеты и материалы кузницы.
## Ожидаемый результат: расход ломает молот, ремонт возвращает сто процентов, улучшение повышает урон.
func test_durability_breakage_repair_and_sharpening() -> void:
	var game := make_game()
	game.change_inventory_count("war_hammer", 1); game.InventorySystem.equip(game, "war_hammer"); game.state.inventory.durability.war_hammer = 1
	game.AdventurePolishSystem.consume_durability(game, "weapon")
	expect(game.state.inventory.durability.war_hammer == 0 and not game.WeaponSystem.can_start_attack(game), "broken equipped hammer is rejected by combat")
	game.coins = 20
	expect(game.AdventurePolishSystem.repair(game, "war_hammer") and game.state.inventory.durability.war_hammer == 100, "forge repairs the complete missing durability")
	game.materials.metal = 20; game.materials.stone = 20
	var upgrade_index: int = game.ForgeSystem.UPGRADES.find_custom(func(upgrade): return upgrade.kind == "war_hammer")
	var before: int = game.ForgeSystem.weapon_damage_bonus(game, "war_hammer")
	expect(upgrade_index >= 0 and game.ForgeSystem.can_upgrade(game, upgrade_index), "repaired hammer and supplied materials satisfy forge requirements")
	var upgraded: bool = game.ForgeSystem.upgrade(game, upgrade_index)
	expect(upgraded and game.ForgeSystem.level(game, "war_hammer") == 1, "hammer sharpening consumes materials and stores its forge level")
	expect(game.ForgeSystem.weapon_damage_bonus(game, "war_hammer") == before + 2, "hammer sharpening increases live heavy-weapon damage")
	game.free()
