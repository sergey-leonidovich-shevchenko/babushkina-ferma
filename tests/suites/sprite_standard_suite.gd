extends "res://tests/suites/suite_base.gd"


## Запускает проверку обязательного стандарта и полноты реестра движущихся объектов.
func run() -> void:
	test_world_visual_profiles_are_grid_safe()
	test_geometry_queries_preserve_independent_profiles()
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
	expect(profiles.visual_rect("hero", Vector2(100, 200)) == Rect2(52, 104, 96, 96), "hero profile preserves square artwork and the authored bottom-center foot anchor")
	expect(profiles.collision_rect("bridge", Vector2(100, 200)) == Rect2(52, 104, 96, 192), "bridge collision is derived from the same four-by-eight-cell profile")


## Сценарий: вызывающий код редактирует полученные профили после запроса геометрии.
## Исходное состояние: проверяются все мировые семейства, контейнеры и фасады с отрицательными координатами.
## Ожидаемый результат: внешние изменения копии не портят последующие размеры, дверной проход и fallback неизвестных ID.
func test_geometry_queries_preserve_independent_profiles() -> void:
	var world = GameScript.WorldVisualProfileSystem; var loot = preload("res://scripts/systems/world_loot_visual_system.gd"); var buildings = GameScript.BuildingVisualSystem
	var position := Vector2(-120, 240)
	for id in world.PROFILES:
		var visual: Rect2 = world.visual_rect(id, position); var collision: Rect2 = world.collision_rect(id, position)
		var copy: Dictionary = world.profile(id); copy.visual_size = Vector2.ONE; copy.collision_size = Vector2.ONE; copy.anchor = "top_left"
		expect(world.visual_rect(id, position) == visual and world.collision_rect(id, position) == collision and world.profile(id).visual_size != Vector2.ONE, "world geometry remains isolated from profile edits: %s" % id)
	for kind in loot.kinds():
		var visual: Rect2 = loot.visual_rect(kind, position); var collision: Rect2 = loot.collision_rect(kind, position)
		var copy: Dictionary = loot.profile(kind); copy.visual_size = Vector2.ONE; copy.collision_offset = Vector2.ONE
		expect(loot.visual_rect(kind, position) == visual and loot.collision_rect(kind, position) == collision and loot.profile(kind).visual_size != Vector2.ONE, "loot geometry remains isolated from profile edits: %s" % kind)
	for id in buildings.PROFILES:
		var facade: Rect2 = buildings.destination_rect(id, position); var foundation: Rect2 = buildings.collision_bounds(id, position); var walls: Array[Rect2] = buildings.collision_rects(id, position)
		var copy: Dictionary = buildings.profile(id); copy.visual_size = Vector2.ONE; copy.foundation_size = Vector2.ONE; copy.door_size = Vector2.ONE
		expect(buildings.destination_rect(id, position) == facade and buildings.collision_bounds(id, position) == foundation and buildings.collision_rects(id, position) == walls, "building geometry remains isolated from profile edits: %s" % id)
		expect(buildings.door_rect(id, position) == Rect2(-144, 216, 48, 24) and walls[1].position.x - walls[0].end.x == 48, "building retains two-cell doorway after profile edits: %s" % id)
	expect(world.visual_rect("unknown", position) == Rect2(position, Vector2.ZERO) and world.collision_rect("unknown", position) == Rect2(position, Vector2.ZERO), "unknown world profile retains zero-sized geometry")
	expect(loot.visual_rect("pirate_chest", position) == loot.visual_rect("chest", position) and loot.collision_rect("unknown", position) == loot.collision_rect("chest", position), "container aliases and unknown-kind chest fallback remain valid")
	expect(buildings.destination_rect("unknown", position) == buildings.destination_rect("cottage", position) and buildings.collision_rects("unknown", position) == buildings.collision_rects("cottage", position), "unknown building retains cottage fallback")


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


## Сценарий: новые четырёхнаправленные пакеты сосуществуют со старыми восьминаправленными персонажами.
## Исходное состояние: реестр задаёт отдельные требования направлений и кадров, в том числе исключение старого кабана.
## Ожидаемый результат: пакеты выполняют свой машинный контракт, а документация не требует восемь ракурсов от нового героя.
func test_known_animation_debt_is_explicit_and_documented() -> void:
	var game := make_game(); var backlog: Array[String] = game.AnimationAssetRegistry.backlog()
	expect(not backlog.has("hero") and not backlog.has("companion_mila") and not backlog.has("npc_official"), "finished human animation package leaves the redraw backlog")
	expect(backlog.is_empty(), "registered actor packages satisfy their explicit direction and minimum-frame contracts")
	var documentation := FileAccess.get_file_as_string("res://docs/SPRITE_STANDARD.md")
	expect(documentation.contains("четыре настоящих направления") and documentation.contains("восемь направлений") and documentation.contains("required_directions") and documentation.contains("minimum_frames"), "Russian project standard records explicit four/eight-direction animation contracts")
	game.free()
