extends "res://tests/suites/suite_base.gd"


## Запускает проверку обязательного стандарта и полноты реестра движущихся объектов.
func run() -> void:
	test_world_visual_profiles_are_grid_safe()
	test_eight_direction_index_is_stable()
	test_human_character_package_is_compliant()
	test_all_current_mobile_catalog_entries_are_audited()
	test_known_animation_debt_is_explicit_and_documented()


## Сценарий: главные семейства мирового арта используют общий машинно-проверяемый каталог геометрии.
## Исходное состояние: каталог содержит землю, мост, четыре стадии дерева, героя, жителей, животных и ранги врагов.
## Ожидаемый результат: все размеры кратны 24 px, anchors валидны, а визуальный и физический мост совпадают.
func test_world_visual_profiles_are_grid_safe() -> void:
	var profiles = GameScript.WorldVisualProfileSystem
	expect(profiles.validation_errors().is_empty(), "all shared visual profiles satisfy the 24-pixel geometry contract")
	expect(profiles.visual_size("terrain") == Vector2(24, 24) and profiles.visual_size("farm_plot") == Vector2(48, 48), "terrain and farm plots use base grid modules")
	expect(profiles.visual_rect("hero", Vector2(100, 200)) == Rect2(64, 104, 72, 96), "hero profile keeps the authored bottom-center foot anchor")
	expect(profiles.collision_rect("bridge", Vector2(100, 200)) == Rect2(52, 104, 96, 192), "bridge collision is derived from the same four-by-eight-cell profile")


## Сценарий: восемь векторов движения однозначно сопоставляются восьми строкам будущих атласов.
## Исходное состояние: направления перечислены в фактическом порядке строк атласа против часовой стрелки, начиная снизу.
## Ожидаемый результат: возвращаются все индексы от нуля до семи без повторений.
func test_eight_direction_index_is_stable() -> void:
	var game := make_game(); var directions := [Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1)]
	for expected_row in directions.size():
		expect(game.AnimationAssetRegistry.direction_index(directions[expected_row]) == expected_row, "direction resolver selects documented animation row %d" % expected_row)
	expect(game.AnimationAssetRegistry.direction_index(Vector2.RIGHT) == 6 and game.AnimationAssetRegistry.direction_index(Vector2(1, -1)) == 5 and game.AnimationAssetRegistry.direction_index(Vector2(1, 1)) == 7, "east and both east diagonals select the actual right-facing atlas rows")
	expect(game.AnimationAssetRegistry.REQUIRED_DIRECTIONS == 8 and game.AnimationAssetRegistry.MIN_WALK_FRAMES == 3 and game.AnimationAssetRegistry.MAX_WALK_FRAMES == 5, "sprite standard enforces eight directions and three-to-five walk frames")
	game.free()


## Сценарий: герой, три архетипа жителей и все напарники переведены на новый формат.
## Исходное состояние: реестр содержит фактические метаданные десяти атласов 4 × 8.
## Ожидаемый результат: каждый человеческий подвижный тип проходит машинную проверку стандарта.
func test_human_character_package_is_compliant() -> void:
	var game := make_game()
	var actors := ["hero", "npc_grandmother", "npc_official", "npc_herbalist", "companion_mila", "companion_borislav", "companion_luna"]
	for actor_id in actors:
		expect(game.AnimationAssetRegistry.is_compliant(actor_id), "human actor has eight directions and four walk frames: %s" % actor_id)
	game.free()


## Сценарий: герой, спутники, мобильные враги и животные обязаны присутствовать в аудите.
## Исходное состояние: рабочие каталоги боя, спутников и животных используются как источник истины.
## Ожидаемый результат: ни один реально движущийся тип не может появиться вне реестра спрайтов.
func test_all_current_mobile_catalog_entries_are_audited() -> void:
	var game := make_game(); var required := ["hero", "npc_grandmother", "npc_official", "npc_herbalist"]
	for companion_id in game.CompanionSystem.COMPANIONS: required.append("companion_%s" % companion_id)
	for kind in game.CombatSystem.TYPES:
		if game.CombatSystem.TYPES[kind].mobile: required.append(kind)
	for kind in game.WildlifeSystem.TYPES: required.append(kind)
	for actor_id in required:
		expect(game.AnimationAssetRegistry.AUDIT.has(actor_id), "moving actor is registered for eight-direction art: %s" % actor_id)
	game.free()


## Сценарий: после пакета животных ни один подвижный объект не остаётся с одноракурсным ассетом.
## Исходное состояние: машинный аудит отражает фактическое число направлений и кадров всех файлов.
## Ожидаемый результат: backlog пуст, а постоянное правило подробно записано в документации.
func test_known_animation_debt_is_explicit_and_documented() -> void:
	var game := make_game(); var backlog: Array[String] = game.AnimationAssetRegistry.backlog()
	expect(not backlog.has("hero") and not backlog.has("companion_mila") and not backlog.has("npc_official"), "finished human animation package leaves the redraw backlog")
	expect(backlog.is_empty(), "finished wildlife package closes the complete moving actor redraw backlog")
	var documentation := FileAccess.get_file_as_string("res://docs/SPRITE_STANDARD.md")
	expect(documentation.contains("восьми направлений") and documentation.contains("трёх до пяти кадров"), "Russian project standard records the permanent animation rule")
	game.free()
