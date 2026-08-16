extends "res://tests/suites/suite_base.gd"

const WorldLootRenderer := preload("res://scripts/systems/world_loot_renderer.gd")


## Запускает проверки прозрачности, разметки, тематического покрытия и коллизий новых атласов.
func run() -> void:
	test_generated_atlases_are_importable_and_transparent()
	test_every_adventure_biome_has_two_props()
	test_large_biome_props_have_safe_collisions()
	test_pirate_enemies_and_items_cover_their_catalogs()
	test_every_inventory_item_has_dedicated_icon()
	test_cave_textures_have_improved_resources()
	test_village_ambient_atlas_has_twelve_complete_cells()
	test_world_loot_atlas_replaces_container_placeholders()
	test_interior_profiles_keep_current_room_previews()


## Сценарий: все сгенерированные изображения загружаются Godot как прозрачные текстуры.
## Исходное состояние: PNG-файлы прошли удаление однотонного фона и импорт редактором.
## Ожидаемый результат: размеры согласованы, углы прозрачны, а центр содержит видимые пиксели.
func test_generated_atlases_are_importable_and_transparent() -> void:
	var atlases := {
		"res://assets/game/generated/pirate_enemy_atlas.png":Vector2i(1254,1254),
		"res://assets/game/generated/pirate_item_atlas.png":Vector2i(1254,1254), "res://assets/game/generated/potion_atlas.png":Vector2i(1254,1254),
		"res://assets/game/generated/inventory_core_atlas.png":Vector2i(1536,1024), "res://assets/game/generated/inventory_rare_atlas.png":Vector2i(1536,1024),
		"res://assets/game/generated/farm_food_atlas.png":Vector2i(1536,1024),
		"res://assets/game/environment/village_ambient_atlas_v1.png":Vector2i(1448,1086),
	}
	for path in atlases:
		var texture := load(path) as Texture2D
		var image := texture.get_image()
		var expected_size: Vector2i = atlases[path]
		expect(texture != null and image.get_size() == expected_size, "generated atlas imports at validated dimensions: %s" % path)
		expect(image.get_pixel(0, 0).a < 0.05 and image.get_pixel(expected_size.x - 1, expected_size.y - 1).a < 0.05, "generated atlas keeps transparent chroma-free corners: %s" % path)
		expect(_has_visible_sample(image), "generated atlas contains visible artwork inside transparent canvas: %s" % path)


## Проверяет разреженную сетку пикселей и подтверждает наличие непрозрачного содержимого.
func _has_visible_sample(image: Image) -> bool:
	for y in range(0, image.get_height(), 32):
		for x in range(0, image.get_width(), 32):
			if image.get_pixel(x, y).a > 0.5:
				return true
	return false


## Сценарий: четыре основных помещения снимаются непосредственно из игрового renderer после миграции мебели.
## Исходное состояние: каталог интерьера уже задаёт ячейку, опору, размер и footprint каждого предмета.
## Ожидаемый результат: для дома, магазина, гильдии и кузницы сохранены нативные контрольные кадры.
func test_interior_profiles_keep_current_room_previews() -> void:
	for location in ["cottage_interior","shop_interior","guild_interior","forge_interior"]:
		var path:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/interior_%s_ingame_preview.png"%location); var preview:=Image.load_from_file(path)
		expect(preview!=null and preview.get_size()==Vector2i(1152,648), "interior keeps a current native gameplay preview: %s"%location)


## Сценарий: каждый из пяти приключенческих биомов получает крупный ориентир и малый декор.
## Исходное состояние: дробный исходный лист разделён на десять самостоятельных модульных PNG.
## Ожидаемый результат: обе текстуры каждого биома валидны, уникальны и не требуют source-rect.
func test_every_adventure_biome_has_two_props() -> void:
	var game := make_game(); var paths:={}
	for location in game.EnvironmentVisualSystem.BIOME_ORDER:
		for variant in ["landmark","detail"]:
			var kind:="%s_%s"%[location,variant]; var texture:Texture2D=game.EnvironmentVisualSystem.texture(kind)
			paths[texture.resource_path]=true
			expect(game.EnvironmentVisualSystem.profile_is_valid(kind), "%s owns a modular independent sprite"%kind)
	expect(paths.size()==10, "five biomes use ten distinct runtime textures")
	var source:=FileAccess.get_file_as_string("res://scripts/systems/visual_asset_system.gd")
	expect(not source.contains("biome_prop_atlas.png") and not source.contains("313.5"), "runtime no longer samples the fractional biome atlas")
	for preview_name in ["season","moon","debug"]:
		var preview:Image=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/environment_%s_ingame_preview.png"%preview_name))
		expect(preview!=null and preview.get_size()==Vector2i(1152,648), "%s keeps a current native environment preview"%preview_name)
	game.free()


## Сценарий: крупный декор физически останавливает героя, не перекрывая вход и мировой переход.
## Исходное состояние: герой находится в лесу, где основания объектов берутся из визуального каталога.
## Ожидаемый результат: основание дерева непроходимо, а старт и восточные ворота остаются доступными.
func test_large_biome_props_have_safe_collisions() -> void:
	var game := make_game(); game.current_location = "forest"
	var prop_base: Vector2 = game.EnvironmentVisualSystem.LARGE_PROP_BASES[0]
	expect(game.EnvironmentVisualSystem.blocks_biome_position("forest", prop_base, game.PLAYER_RADIUS), "large biome prop owns collision matching its visible base")
	expect(not game.NavigationSystem.is_walkable(game, prop_base), "navigation rejects walking through generated biome prop")
	expect(game.NavigationSystem.is_walkable(game, Vector2(220,430)), "adventure spawn remains clear after visual enrichment")
	expect(game.NavigationSystem.is_walkable(game, game.world_gate_position), "world gate remains clear after visual enrichment")
	expect(not game.EnvironmentVisualSystem.blocks_biome_position("overworld", prop_base, game.PLAYER_RADIUS), "biome decoration does not leak into village collision")
	game.free()


## Сценарий: все корабельные враги и предметы разрешаются в тематические ячейки атласов.
## Исходное состояние: боевой каталог содержит четыре семейства, а визуальный каталог — восемь предметов.
## Ожидаемый результат: враги занимают четыре уникальные области, используемые предметы имеют валидные области.
func test_pirate_enemies_and_items_cover_their_catalogs() -> void:
	var game := make_game(); var enemy_origins := {}
	for kind in game.CombatSystem.PIRATE_FAMILIES:
		var source: Rect2 = game.VisualAssetSystem.pirate_enemy_source(kind)
		enemy_origins[str(source.position)] = true
		expect(source.size == Vector2(313.5, 1254.0), "pirate family maps to generated enemy atlas: %s" % kind)
	expect(enemy_origins.size() == 4, "pirate enemy families use distinct atlas cells")
	for kind in ["pirate_doubloon", "ectoplasm", "cursed_compass", "pirate_cutlass"]:
		var source: Rect2 = game.VisualAssetSystem.pirate_item_source(kind)
		expect(source.size == Vector2(313.5, 627.0), "active pirate item maps to generated icon atlas: %s" % kind)
	expect(game.VisualAssetSystem.PIRATE_ITEM_CELLS.size() == 8, "item atlas reserves four future thematic treasures without procedural placeholders")
	game.free()


## Сценарий: каждый предмет, способный попасть в инвентарь, проходит единый визуальный контракт.
## Исходное состояние: каталог предметов содержит инструменты, еду, ресурсы, экипировку и квестовый лут.
## Ожидаемый результат: у всех идентификаторов есть заранее загруженная отдельная текстура.
func test_every_inventory_item_has_dedicated_icon() -> void:
	var game := make_game()
	game.VisualAssetSystem.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	for kind in game.InventorySystem.ITEM_DATA:
		expect(game.VisualAssetSystem.has_item_icon(kind), "inventory item owns a dedicated icon: %s" % kind)
	var fitted: Rect2 = game.VisualAssetSystem.fitted_icon_rect(Rect2(10, 20, 74, 52))
	expect(fitted.size == Vector2(52, 52) and fitted.get_center() == Vector2(47, 46), "separate square icon is centered without non-uniform stretching")
	game.free()


## Сценарий: каждый предмет каталога использует отдельный очищенный прозрачный PNG.
## Исходное состояние: инструмент нарезки сформировал квадратные файлы вместо выборки соседних областей во время игры.
## Ожидаемый результат: каждый предмет импортируется, имеет единый размер и прозрачные углы без чужих фрагментов атласа.
func test_inventory_icons_are_individual_clean_sprites() -> void:
	var game := make_game()
	for kind in game.InventorySystem.ITEM_DATA:
		var path := "res://assets/game/items/catalog/%s.png" % kind
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		expect(image != null and image.get_size() == Vector2i(256, 256), "item owns normalized individual sprite: %s" % kind)
		expect(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(255, 255).a < 0.01, "individual item sprite keeps transparent guard corners: %s" % kind)
		var used := image.get_used_rect()
		expect(maxi(used.size.x, used.size.y) >= 190 and maxi(used.size.x, used.size.y) <= 220, "individual item fills its canvas without shrinking or clipping: %s" % kind)
	game.free()


## Сценарий: пещерные текстуры обновлены на детальные и заметные спрайты.
## Исходное состояние: у пещерного пола и входов использовались малые условные пиктограммы.
## Ожидаемый результат: кристаллы, камни и фон выглядят богаче и имеют читаемые формы.
func test_cave_textures_have_improved_resources() -> void:
	var resource_icons := {
		"res://assets/game/resources/rock.png": Vector2i(64, 64),
		"res://assets/game/resources/blue-crystal.png": Vector2i(64, 64),
		"res://assets/game/environment/cave_crystal.png": Vector2i(64, 64),
	}
	for path in resource_icons:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		var expected_size: Vector2i = resource_icons[path]
		expect(image != null, "cave resource imports without null image: %s" % path)
		expect(image.get_size() == expected_size, "cave resource keeps expected detail size: %s" % path)
		expect(image.get_pixel(0, 0).a < 0.03 and image.get_pixel(expected_size.x - 1, expected_size.y - 1).a < 0.03, "resource corners stay transparent for edge cleanup: %s" % path)
		expect(_has_visible_sample(image), "resource has visible art: %s" % path)


## Сценарий: новый деревенский атлас содержит двенадцать отдельных прозрачных элементов окружения.
## Исходное состояние: изображение после удаления chroma-key разбито на строгую сетку четыре на три.
## Ожидаемый результат: каждая ячейка содержит видимый спрайт, а промежутки и углы остаются прозрачными.
func test_village_ambient_atlas_has_twelve_complete_cells() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/game/environment/village_ambient_atlas_v1.png"))
	expect(image != null and image.get_size() == Vector2i(1448,1086), "village ambient atlas keeps exact 4x3 production grid")
	for row in 3:
		for column in 4:
			var area := Rect2i(column * 362, row * 362, 362, 362)
			expect(_cell_has_visible_sample(image, area), "village ambient cell contains artwork: %d:%d" % [column,row])
	expect(image.get_pixel(0,0).a < 0.03 and image.get_pixel(1447,1085).a < 0.03, "village ambient atlas has transparent outer corners")


## Проверяет видимость пикселей внутри одной ячейки атласа с безопасным разреженным шагом.
func _cell_has_visible_sample(image: Image, area: Rect2i) -> bool:
	for y in range(area.position.y + 24, area.end.y - 24, 16):
		for x in range(area.position.x + 24, area.end.x - 24, 16):
			if image.get_pixel(x,y).a > 0.5: return true
	return false


## Сценарий: мешок, хлам, сундук и кости больше не используют дробный лист и геометрические заглушки.
## Исходное состояние: восемь контейнеров экспортированы самостоятельными PNG с собственными профилями.
## Ожидаемый результат: каждый файл модульный и crop-safe, а пиратский сундук наследует профиль обычного сундука.
func test_world_loot_atlas_replaces_container_placeholders() -> void:
	expect(WorldLootRenderer.profiles_are_valid(), "eight world containers own modular independent sprites")
	for kind in WorldLootRenderer.TEXTURES:
		var texture:Texture2D=WorldLootRenderer.texture(kind); var image:Image=texture.get_image()
		expect(image.get_pixel(0,0).a<0.05 and image.get_pixel(image.get_width()-1,image.get_height()-1).a<0.05, "%s container keeps crop-safe transparent corners"%kind)
	expect(WorldLootRenderer.texture("pirate_chest")==WorldLootRenderer.texture("chest") and WorldLootRenderer.collision_rect("chest",Vector2.ZERO).size==Vector2(72,48), "pirate chest reuses the chest art and its matching rectangular base")
	var preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/world_loot_ingame_preview.png")); expect(preview!=null and preview.get_size()==Vector2i(1152,648),"world loot migration keeps a current native gameplay catalog")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	expect(not renderer_source.contains("draw_circle(position + Vector2(0, 5), 22") and not renderer_source.contains("draw_line(position - Vector2(18, 14)"), "legacy sack and trash geometry is removed from runtime renderer")
