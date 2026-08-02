extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_animation_frame_modes()
	test_directional_character_atlas_frames()
	test_npc_wander_stays_near_home()
	test_living_sprite_motion_and_atlases()
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


## Сценарий: новый общий аниматор выбирает строку направления и четыре последовательных кадра.
## Исходное состояние: атлас героя имеет восемь строк и четыре столбца, герой смотрит на северо-восток.
## Ожидаемый результат: ячейки целочисленные, строка равна пяти, покой держит первый кадр, а ходьба меняет его.
func test_directional_character_atlas_frames() -> void:
	var game := make_game()
	var texture: Texture2D = game.DirectionalCharacterSystem.HERO_TEXTURES[0]
	var idle: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2(1, -1), 0.4, false)
	var walking: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2(1, -1), 0.4, true)
	expect(texture.get_width() == 888 and texture.get_height() == 1776, "directional atlas uses exact 222-pixel cells")
	expect(idle.position == Vector2(0, 1110) and idle.size == Vector2(222, 222), "north-east selects row five and idle frame zero")
	expect(walking.position.x > idle.position.x and walking.position.y == idle.position.y, "walk time advances the frame without changing direction")
	game.free()


## Сценарий: житель начинает прогулку без случайности и не покидает безопасный радиус дома.
## Исходное состояние: бабушка стоит дома, её таймер ожидания принудительно завершён, активна деревня.
## Ожидаемый результат: движение начинается сразу, позиция меняется, радиус соблюдается и шаг обучения отмечается.
func test_npc_wander_stays_near_home() -> void:
	var game := make_game()
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"
	var state: Dictionary = game.npc_movement["grandmother"]
	var home: Vector2 = state.home
	state.timer = 0.0
	game.NpcMovementSystem.update(game, 0.1)
	expect(state.moving and state.position != home, "NPC starts a deterministic walk when the pause expires")
	for _frame in 80:
		game.NpcMovementSystem.update(game, 0.1)
	expect(state.position.distance_to(home) <= game.NpcMovementSystem.WANDER_RADIUS + 1.0, "NPC stays inside the configured home radius")
	expect(game.tutorial_events_completed.has("npc_wander"), "NPC walk has a tester tutorial event")
	game.free()


## Сценарий: единые атласы NPC и зверей используют разные циклы дыхания и шага.
## Исходное состояние: новая игра и детерминированные моменты времени для общего motion-профиля.
## Ожидаемый результат: оба прозрачных атласа загружены, покой живой, фазы различаются, а ходьба заметнее дыхания.
func test_living_sprite_motion_and_atlases() -> void:
	var game := make_game()
	expect(game.NPC_ATLAS.get_width() == 2172 and game.NPC_ATLAS.get_height() == 724, "three coherent NPC sprites are loaded")
	expect(game.FANTASY_WILDLIFE_ATLAS.get_width() == 2172 and game.FANTASY_WILDLIFE_ATLAS.get_height() == 724, "redrawn bat and lizard atlas is loaded")
	var idle_start: Dictionary = game.PresentationSystem.living_motion(0.0, false)
	var idle_later: Dictionary = game.PresentationSystem.living_motion(0.45, false)
	var shifted: Dictionary = game.PresentationSystem.living_motion(0.45, false, 1.7)
	var walking: Dictionary = game.PresentationSystem.living_motion(0.45, true)
	expect(idle_start.offset != idle_later.offset and idle_start.scale != idle_later.scale, "standing characters breathe instead of freezing")
	expect(idle_later.offset != shifted.offset, "living characters use desynchronized animation phases")
	expect(absf(walking.offset.y) > absf(idle_later.offset.y) and absf(walking.rotation) > absf(idle_later.rotation), "walking cycle has a stronger step and body lean")
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
