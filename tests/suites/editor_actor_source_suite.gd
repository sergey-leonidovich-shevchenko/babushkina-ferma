extends "res://tests/suites/suite_base.gd"

const Sources := preload("res://scripts/editor/editor_actor_source_system.gd")
const AtlasPreview := preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd")


## Проверяет безопасные кадровые области новых мастер-листов и уникальный шаблон появления героя.
func run() -> void:
	test_irregular_masters_use_explicit_sources()
	test_hero_template_is_unique_spawn_not_decoration()
	test_grandmother_profile_and_legacy_unique_key()
	test_profile_brush_matches_placed_size()
	test_cleaned_masters_do_not_share_preview_crop()


## Сценарий: редактор выбирает новый лист героя, его мотыгу и три новых звериных атласа.
## Исходное состояние: реальные PNG имеют неравномерную геометрию, которая не допускает автоматическую ячейку 128 px.
## Ожидаемый результат: выбран source-rect внутри картинки, масштаб совпадает с игровым; сырые звериные мастера не предлагаются как декор.
func test_irregular_masters_use_explicit_sources() -> void:
	var game := make_game()
	var paths := [Sources.HERO_WALK, Sources.HERO_HOE, Sources.GRANDMOTHER]
	for filename in Sources.ANIMAL_MASTERS: paths.append("res://assets/game/wildlife/directional/" + filename)
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	for path in paths:
		var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata(path)
		game.LevelEditorSystem.activate_asset(state, entry)
		var texture := ResourceLoader.load(path) as Texture2D
		var source: Rect2 = game.LevelEditorSystem.selected_source(texture, state)
		expect(int(entry.slice_size) == 0 and source.has_area() and Rect2(Vector2.ZERO, texture.get_size()).encloses(source), "irregular master uses its explicit complete source: %s" % path)
		expect(state.source_mode == "custom" and source == Rect2(entry.source_rect) and Vector2(entry.display_size).x <= 96.0, "irregular master preserves the profile world scale: %s" % path)
	var entries: Array = game.LevelEditorSystem.AssetCatalogSystem.scan("res://assets/game")
	expect(not entries.any(func(entry: Dictionary): return String(entry.path).get_file() in Sources.ANIMAL_MASTERS), "raw animal masters cannot be accidentally painted as scenery or cut into 128-pixel fragments")
	expect(entries.filter(func(entry: Dictionary): return entry.path == Sources.HERO_WALK).size() == 1, "catalog exposes one explicit hero spawn template rather than raw action sheets")
	game.free()


## Сценарий: дизайнер ставит нового героя, затем пытается поставить второй экземпляр и кадр мотыги.
## Исходное состояние: пустой черновик и шаблон игрока с явным source-rect и ключом hero:player.
## Ожидаемый результат: появляется один SPAWN размером 96×96, а обе попытки дублирования отвергаются.
func test_hero_template_is_unique_spawn_not_decoration() -> void:
	var game := make_game(); var state: Dictionary = game.LevelEditorSystem.default_state(game)
	var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata(Sources.HERO_WALK)
	game.LevelEditorSystem.activate_asset(state, entry)
	expect(game.LevelEditorSystem.place_selected_asset(game, state, Vector2(600, 400), false), "hero template can be placed as a start point")
	expect(state.objects.size() == 1 and state.objects[0].runtime_role == "spawn" and state.objects[0].size == Vector2(96, 96), "explicit source does not inflate the hero into a 300-pixel decorative sprite")
	game.LevelEditorSystem.RuntimeAuthoringSystem.cycle_role(game.LevelEditorSystem, state)
	expect(state.objects[0].runtime_role == "spawn", "hero entity template cannot accidentally become static decoration through role cycling")
	expect(not game.LevelEditorSystem.place_selected_asset(game, state, Vector2(700, 400), false), "second hero template is rejected")
	game.LevelEditorSystem.activate_asset(state, game.LevelEditorSystem.AssetCatalogSystem.metadata(Sources.HERO_HOE))
	expect(not game.LevelEditorSystem.place_selected_asset(game, state, Vector2(800, 400), false), "alternate hero action sheet shares the same unique entity")
	game.free()


## Сценарий: дизайнер выбирает новый облик бабушки, затем пытается поставить второй экземпляр через старый атлас.
## Исходное состояние: оба ресурса остаются доступны для совместимости, но относятся к одной уникальной жительнице.
## Ожидаемый результат: палитра показывает отдельный кадр с игровыми пропорциями; старый путь не обходит запрет дубликата.
func test_grandmother_profile_and_legacy_unique_key() -> void:
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata(Sources.GRANDMOTHER)
	game.LevelEditorSystem.activate_asset(state, entry)
	expect(entry.unique_key == "npc:grandmother" and entry.slice_size == 0 and entry.source_rect.size.y < 320, "new grandmother is one actual frame instead of a green 4x4 sheet")
	expect(game.LevelEditorSystem.place_selected_asset(game,state,Vector2(400,400),false), "new grandmother sprite can be placed from the editor palette")
	var legacy: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/characters/directional/npc_grandmother_walk_8dir.png")
	game.LevelEditorSystem.activate_asset(state,legacy)
	expect(not game.LevelEditorSystem.place_selected_asset(game,state,Vector2(500,400),false) and state.objects.size() == 1, "legacy grandmother resource cannot duplicate the same unique NPC")
	game.free()


## Сценарий: дизайнер выбирает штатный кадр бабушки или героя, затем вручную изменяет область кадра.
## Исходное состояние: профиль сам включил custom-режим и задаёт отдельный мировой масштаб.
## Ожидаемый результат: размер кисти совпадает с размещением; ручной crop сохраняет своё прежнее поведение.
func test_profile_brush_matches_placed_size() -> void:
	var game := make_game()
	for path in [Sources.GRANDMOTHER,Sources.HERO_WALK,Sources.HERO_HOE]:
		var state: Dictionary = game.LevelEditorSystem.default_state(game)
		var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata(path)
		game.LevelEditorSystem.activate_asset(state,entry)
		var texture: Texture2D = game.LevelEditorRenderer.texture_for(path)
		var source: Rect2 = game.LevelEditorSystem.selected_source(texture,state)
		var size: Vector2 = game.LevelEditorRenderer.drag_preview_size(entry,source,texture.get_size(),state)
		expect(size == Vector2(entry.display_size), "profile brush keeps the production pixel scale: %s" % path)
		var placed: bool = game.LevelEditorSystem.place_selected_asset(game,state,Vector2(600,400),false)
		expect(placed and Vector2(state.objects[0].size) == size, "profile brush size exactly matches the placed object: %s" % path)
		state.objects.clear(); state.custom_source = source.grow(-2)
		var custom_source: Rect2 = game.LevelEditorSystem.selected_source(texture,state)
		var custom_size: Vector2 = game.LevelEditorRenderer.drag_preview_size(entry,custom_source,texture.get_size(),state)
		placed = game.LevelEditorSystem.place_selected_asset(game,state,Vector2(600,400),false)
		expect(placed and custom_size == custom_source.size and Vector2(state.objects[0].size) == custom_size, "manually changed crop keeps matching brush and placement dimensions: %s" % path)
	game.free()


## Сценарий: ALL-превью подряд показывает очищенные мастер-листы героя и бабушки одинакового размера.
## Исходное состояние: у обеих ImageTexture пустой resource_path, но непрозрачные границы разные.
## Ожидаемый результат: кеш возвращает собственную область каждого мастера и сохраняет её при повторном просмотре.
func test_cleaned_masters_do_not_share_preview_crop() -> void:
	var hero: Texture2D = Sources.texture(Sources.HERO_WALK,ResourceLoader.load(Sources.HERO_WALK) as Texture2D)
	var grandmother: Texture2D = Sources.texture(Sources.GRANDMOTHER,ResourceLoader.load(Sources.GRANDMOTHER) as Texture2D)
	var source := Rect2(Vector2.ZERO,hero.get_size())
	var hero_bounds := Rect2(hero.get_image().get_used_rect())
	var grandmother_bounds := Rect2(grandmother.get_image().get_used_rect())
	expect(hero.resource_path.is_empty() and grandmother.resource_path.is_empty() and hero.get_size() == grandmother.get_size() and hero_bounds != grandmother_bounds, "cleaned same-size masters reproduce the empty-resource-path cache collision")
	expect(AtlasPreview.visible_preview_source(hero,source) == hero_bounds, "hero preview uses its own alpha bounds")
	expect(AtlasPreview.visible_preview_source(grandmother,source) == grandmother_bounds, "grandmother preview does not inherit the hero crop")
	expect(AtlasPreview.visible_preview_source(hero,source) == hero_bounds, "returning to the hero keeps its independent cached crop")
