extends "res://tests/suites/suite_base.gd"

const Art := preload("res://scripts/systems/cave_boss_art_system.gd")

## Запускает проверки прозрачных кадров, отдельных анимаций и повторного использования ресурсов.
func run() -> void:
	test_atlas_regions_are_real_transparent_sprites()
	test_sheets_cover_attacks_emergence_and_flying_creatures()
	test_prepared_frames_preserve_every_region_and_anchor()

## Сценарий: каждый нарисованный кадр можно независимо вырезать по каталогу атласа.
## Исходное состояние: шесть новых PNG с настоящим альфа-каналом и явными областями кадров.
## Ожидаемый результат: 89 непустых кадров лежат внутри текстур, а загрузка повторно использует кэш.
func test_atlas_regions_are_real_transparent_sprites() -> void:
	var total := 0
	for kind in Art.catalog():
		var texture := Art.texture(kind)
		var image := texture.get_image()
		expect(image != null and image.detect_alpha() != Image.ALPHA_NONE, "boss sprite atlas contains real alpha: " + kind)
		expect(image.get_pixel(0,0).a < 0.05, "boss sprite atlas has transparent background: " + kind)
		expect(texture == Art.texture(kind), "boss sprite atlas is cached: " + kind)
		for value in Art.catalog()[kind].frames:
			var r: Array = value.region
			var region := Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
			expect(Rect2i(Vector2i.ZERO,image.get_size()).encloses(region), "sprite frame stays inside source: %s/%d/%d" % [kind,value.row,value.column])
			var frame := image.get_region(region)
			expect(frame.get_used_rect().has_area(), "sprite frame is independently visible: %s/%d/%d" % [kind,value.row,value.column])
			expect(float(value.anchor[1]) > 0.0 and float(value.anchor[1]) <= 1.0, "sprite frame has valid ground anchor")
			total += 1
	expect(total == 89, "six reusable atlases contain 89 separately drawable frames")

## Сценарий: отдельные строки покрывают замахи босса, появление нежити и настоящие кадры полёта.
## Исходное состояние: каталог содержит хранителя, три вида нежити, эффекты, муху и мышь.
## Ожидаемый результат: все четыре состояния персонажей имеют четыре кадра, эффект кристалла имеет пять.
func test_sheets_cover_attacks_emergence_and_flying_creatures() -> void:
	for kind in ["guardian","skeleton","zombie","vampire"]:
		for row in 4: expect(Art.count(kind,row) == 4, "actor sheet has four distinct frames: %s/%d" % [kind,row])
	expect(Art.count("effects",1) == 5 and Art.count("effects",3) == 4, "effects use the actual five crystal frames and four moonfire frames")
	expect(Art.count("flyers",0) == 4 and Art.count("flyers",1) == 4, "fly and bat own independent four-frame flight loops")
	expect(FileAccess.file_exists(Art.ROOT + "generation.json"), "sprite generation retains exact prompts and original master paths")

## Сценарий: горячий индекс запрашивает каждый кадр и ошибочные крайние номера.
## Исходное состояние: исходный каталог содержит 89 областей, кеш уже прогрет отрисовкой.
## Ожидаемый результат: индексация точно сохраняет рисунок и опору, неверная строка безопасна.
func test_prepared_frames_preserve_every_region_and_anchor() -> void:
	for kind in Art.catalog():
		for original in Art.catalog()[kind].frames:
			var frame := Art.frame(kind,int(original.row),int(original.column))
			expect(frame.region == original.region and frame.anchor == original.anchor,"prepared frame exactly matches original atlas region and anchor")
			expect(frame.source == Rect2(original.region[0],original.region[1],original.region[2],original.region[3]),"prepared source preserves exact integer pixels")
		expect(Art.frame(kind,999,0).is_empty() and Art.count(kind,999) == 0,"unknown row has no accidental frame")
		expect(Art.frame(kind,0,-20).column == 0 and Art.frame(kind,0,999).column == Art.count(kind,0)-1,"extreme frame numbers clamp to valid art")
