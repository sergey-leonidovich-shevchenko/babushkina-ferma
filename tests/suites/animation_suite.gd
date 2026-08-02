extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_animation_frame_modes()
	test_player_attack_and_slime_reaction()
	test_enemy_hurt_and_death_lifecycle()
	test_slime_attack_returns_to_idle()


## Сценарий: циклическая и одноразовая анимации выбирают правильные кадры.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_animation_frame_modes() -> void:
	var game := make_game()
	expect(game.AnimationSystem.frame(0.7, 4, 10.0) == 3, "looped animation wraps frames deterministically")
	expect(game.AnimationSystem.frame(2.0, 6, 10.0, false) == 5, "one-shot animation holds its final frame")
	game.free()


## Сценарий: атака героя запускает замах и реакцию слизня на попадание.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_player_attack_and_slime_reaction() -> void:
	var game := make_game()
	game.player = game.slime_position
	expect(game.attack_slime(), "slime accepts a close combat hit")
	expect(game.player_attack_timer == game.AnimationSystem.PLAYER_ATTACK_DURATION, "combat starts the player attack animation immediately")
	expect(game.slime_visual_state == "hurt", "surviving slime enters hurt animation")
	game.AnimationSystem.update(game, game.AnimationSystem.HURT_DURATION + 0.01)
	expect(game.slime_visual_state == "idle", "slime returns to idle after hurt animation")
	expect(game.tutorial_events_completed.has("combat_animation"), "combat animation has a tester tutorial event")
	game.free()


## Сценарий: обычный враг проходит состояния ранения, гибели и исчезновения.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_enemy_hurt_and_death_lifecycle() -> void:
	var game := make_game()
	game.current_location = "forest"
	game.player = game.enemy_nodes[0].position
	expect(game.CombatSystem.attack(game, 0), "animated enemy accepts damage")
	expect(game.enemy_nodes[0].visual_state == "hurt", "enemy enters hurt state after a non-lethal hit")
	game.AnimationSystem.update(game, game.AnimationSystem.HURT_DURATION + 0.01)
	expect(game.enemy_nodes[0].visual_state == "idle", "enemy hurt state expires into idle")
	for _hit in 4:
		game.CombatSystem.attack(game, 0)
	expect(not game.enemy_nodes[0].alive and game.enemy_nodes[0].visual_state == "death", "defeated enemy enters a one-shot death animation")
	expect(game.AnimationSystem.enemy_is_visible(game.enemy_nodes[0]), "defeated enemy stays visible while death animation plays")
	game.AnimationSystem.update(game, game.AnimationSystem.DEATH_DURATION + 0.01)
	expect(not game.AnimationSystem.enemy_is_visible(game.enemy_nodes[0]), "enemy disappears after its death animation finishes")
	game.free()


## Сценарий: атака слизня завершается возвратом в состояние покоя.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_slime_attack_returns_to_idle() -> void:
	var game := make_game()
	game.AnimationSystem.begin_slime_attack(game)
	expect(game.slime_visual_state == "attack", "slime attack uses its own one-shot state")
	game.AnimationSystem.update(game, game.AnimationSystem.ENEMY_ATTACK_DURATION + 0.01)
	expect(game.slime_visual_state == "idle", "slime attack returns to idle")
	game.free()
