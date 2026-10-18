extends "res://tests/suites/suite_base.gd"

const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Art := preload("res://scripts/presentation/house_furniture_visual_system.gd")
const Farm := preload("res://scripts/systems/farm_life_visual_system.gd")
const Editor := preload("res://scripts/systems/level_editor_asset_catalog_system.gd")


## Проверяет единый паспорт, независимость от имён и геометрию при смене плотности.
func run() -> void:
	test_three_sides_share_game_editor_and_footprint()
	test_filename_and_quality_do_not_define_identity_or_size()
	test_catalog_copy_and_missing_combinations_are_safe()


## Сценарий: игра и редактор запрашивают три вида одного предмета.
## Исходное состояние: паспорт действующего стола и старый задний слот сохранения.
## Ожидаемый результат: области, опоры и основания совпадают, задний слот использует передний рисунок.
func test_three_sides_share_game_editor_and_footprint() -> void:
	var game := make_game()
	for direction in [0,1,3]:
		var side: String = Art.Facing.NAMES[direction]
		var view := Resources.describe("prop.rustic_table",side)
		var profile := Farm.profile("rustic_table",direction)
		var editor := Editor.metadata(view.path)
		var position := Vector2(600,480)
		expect(Art.source("rustic_table",direction)==view.source,"runtime source comes from stable resource ID: "+side)
		expect(profile.visual==view.logical_size and profile.collision==view.footprint_size,"world dimensions and footprint share one passport: "+side)
		expect(editor.visual_resource_id==view.id and editor.source_rect==view.source and editor.collision_size==profile.collision,"F12 uses the same source and physical footprint: "+side)
		expect(editor.display_size==Art.destination("rustic_table",position,profile.visual,direction).size,"F12 preserves the exact uniformly fitted world size: "+side)
		expect(is_equal_approx(Resources.destination(view,position).end.y,position.y) and view.filter=="nearest" and view.space=="world","pivot, coordinate space and existing filter policy remain explicit: "+side)
		for grid in [6,12,24]:
			var state: Dictionary = game.LevelEditorSystem.default_state(game); state.grid=grid
			game.LevelEditorSystem.activate_asset(state,editor)
			var placed: bool = game.LevelEditorSystem.place_selected_asset(game,state,Vector2(800,400),false)
			expect(placed and state.objects[0].size==editor.display_size and state.objects[0].source==view.source and state.objects[0].collision_size==profile.collision and is_zero_approx(fposmod(state.objects[0].position.x-profile.collision.x*0.5,grid)),"actual F12 placement aligns footprint and consumes shared geometry: %s/%d"%[side,grid])
	expect(Art.texture("rustic_table",2)==Art.texture("rustic_table",0),"legacy north index retains front compatibility without a rear resource")
	var audit: Dictionary = preload("res://scripts/systems/world_visual_audit_system.gd").profiles()["farm_life.rustic_table"]
	expect(audit.visual_size==Resources.describe("prop.rustic_table").logical_size,"content validation reads the resolved metadata profile rather than an obsolete geometry duplicate")
	expect(Farm.PROFILES.rustic_table.visual==Resources.describe("prop.rustic_table").logical_size and Farm.PROFILES.rustic_table.collision==Resources.describe("prop.rustic_table").footprint_size and Farm.PROFILES.is_read_only(),"legacy raw profile catalog preserves complete immutable geometry derived from metadata")
	game.free()


## Сценарий: файл переименован, затем выбирается источник с двойной плотностью.
## Исходное состояние: копия проверенного паспорта, неизменные ID и мировые размеры.
## Ожидаемый результат: меняется только путь или область выборки; экранная геометрия и опора сохраняются.
func test_filename_and_quality_do_not_define_identity_or_size() -> void:
	var data := Resources.catalog()
	var before := Resources.resolve(data,"prop.rustic_table","south")
	var key: String = data.resources["prop.rustic_table"].views.south.variants.standard.texture
	data.textures[key].file="res://assets/game/neutral-name.png"
	var renamed := Resources.resolve(data,"prop.rustic_table","south")
	expect(renamed.id==before.id and renamed.path!=before.path and renamed.source==before.source,"stable identity and crop do not depend on PNG basename")
	data.textures["dense"]={"file":"res://assets/game/density-fixture.png"}
	data.resources["prop.rustic_table"].views.south.variants["dense"]={"texture":"dense","source_rect":[16,16,480,320]}
	var dense := Resources.resolve(data,"prop.rustic_table","south","dense")
	expect(dense.quality=="dense" and dense.source.size==before.source.size*2,"quality selects an explicit density fixture, not a filename suffix")
	expect(Resources.destination(dense,Vector2(80,200))==Resources.destination(before,Vector2(80,200)) and dense.footprint_size==before.footprint_size,"doubling source pixels does not double physical size or shift the ground pivot")


## Сценарий: вызывающий код меняет копию каталога или запрашивает неизвестную комбинацию.
## Исходное состояние: опубликован только standard и три полезных вида стола.
## Ожидаемый результат: исходные данные не меняются, неизвестные ID/качества не подменяются вымышленным видом.
func test_catalog_copy_and_missing_combinations_are_safe() -> void:
	var copy := Resources.catalog(); copy.resources.clear()
	expect(not Resources.describe("prop.rustic_table").is_empty(),"external edits cannot mutate cached metadata")
	expect(Resources.describe("prop.rustic_table").is_read_only(),"shared runtime descriptors are immutable and reused without per-frame reconstruction")
	expect(Art.SPRITES.is_read_only() and Art.SPRITES.rustic_table.is_read_only(),"legacy sprite catalog retains immutable containers after adopting metadata textures")
	expect(Resources.DATA is JSON and Resources.DATA.resource_path==Resources.PATH,"catalog is loaded as a typed Godot JSON resource with its explicit path")
	for request in [["missing","south",""],["prop.rustic_table","north",""],["prop.rustic_table","south","ultra"]]:
		expect(Resources.describe(request[0],request[1],request[2]).is_empty(),"unknown metadata combination is explicitly absent: "+str(request))
