extends "res://tests/suites/suite_base.gd"


## Запускает проверку обязательного стандарта и полноты реестра движущихся объектов.
func run() -> void:
	test_eight_direction_index_is_stable()
	test_all_current_mobile_catalog_entries_are_audited()
	test_known_animation_debt_is_explicit_and_documented()


## Сценарий: восемь векторов движения однозначно сопоставляются восьми строкам будущих атласов.
## Исходное состояние: направления перечислены по часовой стрелке, начиная с движения вниз.
## Ожидаемый результат: возвращаются все индексы от нуля до семи без повторений.
func test_eight_direction_index_is_stable() -> void:
	var game := make_game(); var indices := {}
	for direction in [Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1)]:
		indices[game.AnimationAssetRegistry.direction_index(direction)] = true
	expect(indices.size() == 8 and indices.has(0) and indices.has(7), "direction resolver exposes eight unique animation rows")
	expect(game.AnimationAssetRegistry.REQUIRED_DIRECTIONS == 8 and game.AnimationAssetRegistry.MIN_WALK_FRAMES == 3 and game.AnimationAssetRegistry.MAX_WALK_FRAMES == 5, "sprite standard enforces eight directions and three-to-five walk frames")
	game.free()


## Сценарий: герой, спутники, мобильные враги и животные обязаны присутствовать в аудите.
## Исходное состояние: рабочие каталоги боя, спутников и животных используются как источник истины.
## Ожидаемый результат: ни один реально движущийся тип не может появиться вне реестра спрайтов.
func test_all_current_mobile_catalog_entries_are_audited() -> void:
	var game := make_game(); var required := ["hero"]
	for companion_id in game.CompanionSystem.COMPANIONS: required.append("companion_%s" % companion_id)
	for kind in game.CombatSystem.TYPES:
		if game.CombatSystem.TYPES[kind].mobile: required.append(kind)
	for kind in game.WildlifeSystem.TYPES: required.append(kind)
	for actor_id in required:
		expect(game.AnimationAssetRegistry.AUDIT.has(actor_id), "moving actor is registered for eight-direction art: %s" % actor_id)
	game.free()


## Сценарий: старые одноракурсные ассеты не маскируются процедурным покачиванием как готовая анимация.
## Исходное состояние: машинный аудит отражает фактическое число направлений и кадров текущих файлов.
## Ожидаемый результат: долг остаётся явным, а правило подробно записано в проектной документации.
func test_known_animation_debt_is_explicit_and_documented() -> void:
	var game := make_game(); var backlog: Array[String] = game.AnimationAssetRegistry.backlog()
	expect(backlog.size() == game.AnimationAssetRegistry.AUDIT.size() and backlog.has("hero") and backlog.has("drowned_captain"), "every currently incomplete moving sprite stays in explicit redraw backlog")
	var documentation := FileAccess.get_file_as_string("res://docs/SPRITE_STANDARD.md")
	expect(documentation.contains("восьми направлений") and documentation.contains("трёх до пяти кадров"), "Russian project standard records the permanent animation rule")
	game.free()
