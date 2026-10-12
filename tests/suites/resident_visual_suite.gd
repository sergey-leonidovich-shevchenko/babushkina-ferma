extends "res://tests/suites/suite_base.gd"

const Residents := preload("res://scripts/systems/resident_visual_system.gd")
const Sources := preload("res://scripts/editor/editor_actor_source_system.gd")

## Проверяет подготовленные человеческие кадры, общую опору, инспектор и правильные пропорции диалогов.
func run() -> void:
	test_all_native_frames_and_ground()
	test_portraits_editor_and_inspector()
	test_local_edge_cleanup_preserves_art()

## Сценарий: два архетипа NPC и три спутника проходят все восемь направлений и четыре фазы.
## Исходное состояние: пять атласов 512×1024 с готовым ростом 84 px, рамка выбирает только реально видимое тело.
## Ожидаемый результат: все 160 кадров целые, прозрачные, не пересекают соседнюю ячейку и ставят стопы на физическую позицию.
func test_all_native_frames_and_ground() -> void:
	var game := make_game()
	var textures: Array = game.DirectionalCharacterSystem.NPC_TEXTURES.slice(1)+game.DirectionalCharacterSystem.COMPANION_TEXTURES.values()
	for texture in textures:
		expect(texture.get_size()==Vector2(512,1024),"resident atlas is prepared at native dimensions")
		for row in 8:
			var direction := Vector2(-sin(row*TAU/8),cos(row*TAU/8))
			for column in 4:
				var pose := Residents.pose(texture,direction,(column+0.01)/8.0,true)
				var source: Rect2 = pose.source
				var cell := Rect2(column*128,row*128,128,128)
				var destination := Residents.destination(Vector2(1234,567),pose)
				var image: Image = texture.get_image().get_region(Rect2i(source))
				expect(cell.encloses(source) and source.position==source.position.round(),"resident pose cannot contain neighbouring figure")
				expect(not image.is_invisible() and source.size.y>=78 and source.size.y<=104 and source.size.x<112,"complete resident has consistent human height")
				expect((destination.position+pose.pivot).is_equal_approx(Vector2(1234,567)),"resident boots and physical point share the hero anchor")
				expect(absf(destination.end.y-567)<=5.0,"actual boot pixels remain near common ground")
	expect(game.DirectionalCharacterSystem.GROUND_OFFSET==Vector2.ZERO and game.DirectionalCharacterSystem.GrandmotherVisualSystem.GROUND_OFFSET==Vector2.ZERO,"no human keeps legacy downward foot offset")
	game.free()

## Сценарий: событие деревни и портал содержат внешний служебный пурпурный кант.
## Исходное состояние: исходный атлас и PNG неизменны, очистка включена только для трёх событий и портала.
## Ожидаемый результат: наружные ключи исчезают, большинство непрозрачного рисунка и все яркие пиксели портала сохранены, кэш повторно используется.
func test_local_edge_cleanup_preserves_art() -> void:
	var game := make_game()
	var matte := preload("res://scripts/systems/sprite_matte_system.gd")
	for column in 3:
		var original: Image=game.WorldPolishRenderer.ATLAS.get_image().get_region(Rect2i(game.WorldPolishRenderer.source(column,1)))
		var before: PackedByteArray=original.get_data()
		var texture: Texture2D=game.WorldPolishRenderer.event_texture(column)
		var cleaned:=texture.get_image(); var removed:=0; var opaque:=0; var untouched:=true
		for y in 128:
			for x in 128:
				var source:=original.get_pixel(x,y); var pixel:=cleaned.get_pixel(x,y)
				if source.a>0.5: opaque+=1
				if source.a>0.5 and pixel.a<0.5: removed+=1
				if not matte.is_service_color(roundi(source.r*255),roundi(source.g*255),roundi(source.b*255)) and not matte.is_dark_magenta(roundi(source.r*255),roundi(source.g*255),roundi(source.b*255)):
					untouched=untouched and source==pixel
		expect(removed>0 and float(removed)/maxi(opaque,1)<0.1,"event loses only a small exterior service matte")
		expect(untouched and original.get_data()==before,"event cleanup preserves ordinary colors and original image")
		expect(texture==game.WorldPolishRenderer.event_texture(column),"event cleanup is cached before gameplay")
	var raw: Texture2D=game.EnvironmentVisualSystem.TEXTURES.moon_portal
	var source:=raw.get_image(); var cleaned: Image=game.EnvironmentVisualSystem.texture("moon_portal").get_image(); var core_kept:=true
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x,y).a>0.5: core_kept=core_kept and source.get_pixel(x,y)==cleaned.get_pixel(x,y)
	expect(core_kept,"portal preserves every opaque stone and glowing core pixel")
	expect(game.EnvironmentVisualSystem.texture("moon_portal")==game.EnvironmentVisualSystem.texture("moon_portal"),"portal edge preparation is cached")
	game.free()

## Сценарий: гильдия, травница и спутники показаны в диалогах, редакторе и под инспектором F10.
## Исходное состояние: нативные кадры имеют собственное соотношение сторон; спутники перемещаются во всех направлениях.
## Ожидаемый результат: портреты не растянуты, кисть не уменьшает подготовленное тело, рамки совпадают с игровыми кадрами.
func test_portraits_editor_and_inspector() -> void:
	var game := make_game()
	for npc_id in game.QuestSystem.NPCS:
		var portrait: Dictionary = game.StoryUiRenderer.npc_portrait_layout(game,Rect2(20,30,160,180),npc_id)
		expect(is_equal_approx(portrait.destination.size.x/portrait.source.size.x,portrait.destination.size.y/portrait.source.size.y),"NPC portrait preserves natural aspect ratio")
	for kind in Sources.RESIDENT_NAMES:
		var path: String=Sources.RESIDENT_ROOT+kind+".png"
		var entry: Dictionary=game.LevelEditorSystem.AssetCatalogSystem.metadata(path)
		var pose := Residents.pose(load(path),Vector2.DOWN,0.0,false)
		expect(entry.slice_size==0 and entry.source_rect==pose.source and entry.display_size==pose.source.size,"editor offers one actual native-size resident template")
	game.current_location="overworld"; game.active_companions.assign(["mila","borislav","luna"])
	game.walk_animation_time=0.375
	for kind in game.active_companions:
		game.companion_positions[kind]=Vector2(700,600); game.companion_directions[kind]=Vector2.LEFT; game.companion_moving[kind]=true
	var objects: Array[Dictionary]=[]
	game.DebugObjectInspectorSystem.append_companions(game,objects)
	for object in objects:
		var kind: String=String(object.id).get_slice(":",1)
		var pose := Residents.pose(game.DirectionalCharacterSystem.COMPANION_TEXTURES[kind],Vector2.LEFT,game.walk_animation_time,true)
		expect(object.bounds==Residents.destination(Vector2(700,600),pose),"companion inspector matches exact animated body")
	game.free()
