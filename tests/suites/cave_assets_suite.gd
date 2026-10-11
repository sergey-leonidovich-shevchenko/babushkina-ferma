extends "res://tests/suites/suite_base.gd"

const Assets := preload("res://scripts/systems/cave_asset_system.gd")


## Запускает проверки самостоятельных спрайтов, прозрачных полей и общей опоры пещерного набора.
func run() -> void:
	test_modular_assets_have_transparent_margins()
	test_resource_art_is_distinct_and_grounded()


## Сценарий: согласованный лист нарезан на самостоятельные PNG и загружен игровым каталогом.
## Исходное состояние: стены, вход, жилы и декор имеют отдельные файлы и центральные пространственные профили.
## Ожидаемый результат: все двадцать изображений имеют прозрачные поля, видимые пиксели и двойное разрешение.
func test_modular_assets_have_transparent_margins() -> void:
	expect(Assets.CATALOG.size() == 20 and Assets.validation_errors().is_empty(), "twenty independent cave sprites use validated modular profiles")
	for kind in Assets.CATALOG:
		var sprite := Assets.texture(kind)
		var image := sprite.get_image()
		if image.is_compressed(): image.decompress()
		var size := image.get_size()
		expect(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(size.x - 1, size.y - 1).a < 0.01, "%s has transparent crop-safe corners" % kind)
		expect(image.get_used_rect().has_area() and image.get_used_rect().end.y <= size.y - 4, "%s contains complete art with a safe bottom margin" % kind)
		expect(Vector2(size) == Vector2(Assets.profile(kind).visual_size) * 2.0, "%s retains double runtime resolution" % kind)
	expect(Assets.floor_texture().get_width() >= 512 and Assets.floor_texture().get_height() >= 512, "cave floor is an independent repeatable material")


## Сценарий: каждый добываемый материал выбирает собственный рисунок вместо перекрашивания одной текстуры.
## Исходное состояние: каталог содержит камень, три кристальные жилы и металлическую руду.
## Ожидаемый результат: пять путей текстур уникальны, а изображение и коллизия используют одну нижнюю опору.
func test_resource_art_is_distinct_and_grounded() -> void:
	var paths := {}
	var ground := Vector2(720, 600)
	for kind in Assets.RESOURCE_ART:
		var art := Assets.resource_art(kind)
		paths[Assets.texture(art).resource_path] = true
		var visible := Assets.destination_rect(art, ground)
		var collision := Assets.collision_rect(art, ground)
		expect(visible.end.y == ground.y and collision.end.y == ground.y, "%s shares the visible ground and solid base" % kind)
		expect(visible.encloses(collision), "%s collision stays inside its sprite module" % kind)
	expect(paths.size() == 5, "five resource kinds own five distinct sprites")
