extends "res://tests/suites/suite_base.gd"


## Запускает сценарии визуальной геометрии, игровых ролей, публикации и интеграции конструктора.
func run()->void:
	test_editor_visual_hierarchy_has_safe_non_overlapping_zones()
	test_editor_button_and_catalog_text_keep_carved_frame_padding()
	test_runtime_roles_collision_geometry_and_reachability()
	test_publish_starts_playtest_and_exit_returns_to_editor()
	test_runtime_integration_freezes_simulation_and_draws_editor_layers()


## Сценарий: панель конструктора группирует каталог, инструменты, файл, карту и свойства объекта в безопасные зоны.
## Исходное состояние: известны все прямоугольники кнопок, плавающих карточек, каталога и компактной панели слоёв.
## Ожидаемый результат: элементы не пересекаются, не выходят из корпуса, а длинные подписи помещаются после адаптации.
func test_editor_visual_hierarchy_has_safe_non_overlapping_zones()->void:
	var game:=make_game(); var editor=game.LevelEditorSystem
	var controls:Array[Rect2]=[editor.CATEGORY_PREV,editor.SEARCH_BUTTON,editor.CATEGORY_NEXT,editor.FAVORITES_BUTTON,editor.SELECT_TOOL_BUTTON,editor.PAINT_TOOL_BUTTON,editor.FILL_TOOL_BUTTON,editor.PICKER_TOOL_BUTTON,editor.ERASE_TOOL_BUTTON,editor.NEW_BUTTON,editor.SAVE_BUTTON,editor.LOAD_BUTTON,editor.EXPORT_BUTTON,editor.IMPORT_BUTTON,editor.PUBLISH_BUTTON,editor.VALIDATE_BUTTON,editor.GRID_BUTTON,editor.SLICE_BUTTON,editor.LAYER_BUTTON,editor.COLLISION_BUTTON,editor.LEVEL_NAME_BUTTON,editor.ROLE_BUTTON,editor.OBJECT_NAME_BUTTON,editor.OBJECT_NOTE_BUTTON]
	var contained:=controls.all(func(rect:Rect2):return editor.PANEL.encloses(rect)); var overlaps:=false
	for first in controls.size():
		for second in range(first+1,controls.size()):
			if controls[first].intersects(controls[second]): overlaps=true
	expect(contained and not overlaps,"editor controls stay inside the carved panel and never overlap each other")
	expect(editor.ASSET_ROWS.end.y<editor.SELECT_TOOL_BUTTON.position.y and not editor.PANEL.intersects(game.LevelEditorSystem.GroupSystem.PANEL),"catalog tools and floating layer palette occupy separate visual zones")
	var renderer=game.LevelEditorRenderer
	expect(not renderer.HELP_RECT.intersects(renderer.SELECTION_INFO_RECT) and not renderer.HELP_RECT.intersects(renderer.VALIDATION_INFO_RECT) and not renderer.SELECTION_INFO_RECT.intersects(renderer.VALIDATION_INFO_RECT),"shortcut object and validation cards have independent non-overlapping world-space areas")
	var labels:=[[editor.PICKER_TOOL_BUTTON,"ПИПЕТКА"],[editor.PUBLISH_BUTTON,"▶  T · ЗАПУСТИТЬ УРОВЕНЬ"],[editor.VALIDATE_BUTTON,"✓  R · ПРОВЕРИТЬ КАРТУ"],[editor.OBJECT_NOTE_BUTTON,"ЗАМЕТКА ДИЗАЙНЕРА"]]
	for sample in labels:
		var fitted:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,String(sample[1]),(sample[0] as Rect2).size.x-14,10,7); expect(game.UI_FONT.get_string_size(String(fitted.text),HORIZONTAL_ALIGNMENT_LEFT,-1,int(fitted.size)).x<=(sample[0] as Rect2).size.x-14,"editor label fits its authored button: %s"%sample[1])
	game.free()


## Сценарий: компактные кнопки и двухстрочные карточки каталога рисуются внутри резной деревянной рамки.
## Исходное состояние: известны минимальная кнопка 70×32 px и вертикальные метрики обеих строк карточки ресурса.
## Ожидаемый результат: текст имеет симметричную safe-area, а название и путь не касаются верхней и нижней кромок.
func test_editor_button_and_catalog_text_keep_carved_frame_padding()->void:
	var game:=make_game(); var layout:Dictionary=game.DebugUiKitSystem.button_text_layout(Rect2(0,0,70,32),true); var renderer=game.LevelEditorRenderer
	expect(float(layout.inset)>=10.0 and float(layout.width)<=50.0,"compact editor button reserves carved horizontal borders instead of filling the full texture")
	expect(float(layout.baseline)>=18.0 and 32.0-float(layout.baseline)>=12.0 and int(layout.preferred_size)<=9,"compact editor label keeps visible vertical breathing room")
	expect(renderer.CATALOG_TITLE_BASELINE>=16.0 and renderer.CATALOG_PATH_BASELINE-renderer.CATALOG_TITLE_BASELINE>=10.0 and renderer.CATALOG_ROW_DRAW_HEIGHT-renderer.CATALOG_PATH_BASELINE>=12.0,"catalog title and path occupy independent padded baselines")
	game.free()


## Сценарий: дизайнер назначает точку старта, выход и точно подгоняет препятствие независимо от картинки.
## Исходное состояние: два маркера соединены свободным маршрутом, третий объект имеет отдельный collision-box.
## Ожидаемый результат: роли уникальны, геометрия редактируется по малой сетке, а недостижимый выход блокирует публикацию.
func test_runtime_roles_collision_geometry_and_reachability()->void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); var entry:Dictionary=game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")
	game.LevelEditorSystem.activate_asset(state,entry)
	for point in [Vector2(492,300),Vector2(684,300),Vector2(588,396)]: game.LevelEditorSystem.place_selected_asset(game,state,point,false)
	state.objects[0].runtime_role="spawn"; state.objects[1].runtime_role="exit"; state.objects[2].collision=true; state.objects[2].collision_size=Vector2(24,24); state.objects[2].collision_offset=Vector2.ZERO
	var ready:Dictionary=game.LevelEditorSystem.ValidationSystem.validate_runtime(state); expect(ready.valid and bool(ready.runtime),"strict runtime validator accepts one spawn and a reachable exit")
	state.selected=2; game.LevelEditorSystem.RuntimeAuthoringSystem.edit_collision(game.LevelEditorSystem,state,Vector2.RIGHT,true); game.LevelEditorSystem.RuntimeAuthoringSystem.edit_collision(game.LevelEditorSystem,state,Vector2.DOWN,false)
	expect(Vector2(state.objects[2].collision_size)==Vector2(36,24) and Vector2(state.objects[2].collision_offset)==Vector2(0,12),"collision box resizes and moves in half-grid increments without stretching the sprite")
	state.objects[2].position=Vector2(state.objects[1].position); state.objects[2].collision_size=Vector2(48,48); state.objects[2].collision_offset=Vector2.ZERO
	var blocked:Dictionary=game.LevelEditorSystem.ValidationSystem.validate_runtime(state); expect(not blocked.valid and blocked.errors.any(func(error:String):return "EXIT" in error),"runtime validation rejects an exit covered by collision")
	state.objects[2].position=Vector2(588,396); state.selected=2; state.objects[2].runtime_role=""; game.LevelEditorSystem.RuntimeAuthoringSystem.cycle_role(game.LevelEditorSystem,state); state.selected=0; state.objects[0].runtime_role=""; game.LevelEditorSystem.RuntimeAuthoringSystem.cycle_role(game.LevelEditorSystem,state)
	expect(String(state.objects[0].runtime_role)=="spawn" and String(state.objects[2].runtime_role).is_empty(),"assigning a new spawn automatically clears the previous spawn marker"); game.free()


## Сценарий: валидный авторский уровень публикуется и без перезапуска открывается как игровая локация.
## Исходное состояние: редактор активен, карта имеет старт, выход и одно отдельное препятствие между ними.
## Ожидаемый результат: JSON записан, герой сталкивается с box, достижение выхода возвращает тот же черновик.
func test_publish_starts_playtest_and_exit_returns_to_editor()->void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); state.active=true; state.level_name="published level suite"; var entry:Dictionary=game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")
	game.LevelEditorSystem.activate_asset(state,entry)
	for point in [Vector2(492,300),Vector2(684,300),Vector2(588,396)]: game.LevelEditorSystem.place_selected_asset(game,state,point,false)
	state.objects[0].runtime_role="spawn"; state.objects[1].runtime_role="exit"; state.objects[2].collision=true; state.objects[2].collision_size=Vector2(24,24); state.objects[2].collision_offset=Vector2.ZERO; game.set_meta(game.LevelEditorSystem.META_KEY,state)
	var path:="res://level_designs/published/published_level_suite.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	expect(game.PublishedLevelSystem.publish_and_play(game,state) and game.PublishedLevelSystem.active(game) and FileAccess.file_exists(path),"publish atomically writes a runtime level and immediately starts its playtest")
	expect(game.player==Vector2(state.objects[0].position) and game.PublishedLevelSystem.blocks_position(game,Vector2(state.objects[2].position),8.0),"playtest spawns at the marker and uses the authored collision geometry")
	game.player=Vector2(state.objects[1].position); game.PublishedLevelSystem.update(game); var restored:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(not game.PublishedLevelSystem.active(game) and restored.active and String(restored.status).contains("ПРОЙДЕН"),"reaching the authored exit completes the test and restores the editable draft")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); game.free()


## Сценарий: конструктор подключён к единственному игровому циклу, отрисовке и диагностической панели.
## Исходное состояние: исходники интеграционных модулей и список доступных F10-команд читаются напрямую.
## Ожидаемый результат: режим останавливает симуляцию, рисует все четыре слоя и доступен как включённая команда.
func test_runtime_integration_freezes_simulation_and_draws_editor_layers()->void:
	var core:=FileAccess.get_file_as_string("res://scripts/game_core.gd"); var loop:=FileAccess.get_file_as_string("res://scripts/core/game_loop.gd"); var input_router:=FileAccess.get_file_as_string("res://scripts/core/game_input_router.gd"); var render:=FileAccess.get_file_as_string("res://scripts/systems/render_system.gd"); var debug:=FileAccess.get_file_as_string("res://scripts/systems/debug_overlay_system.gd")
	expect(core.contains("GameLoop.physics_process") and loop.contains("game.LevelEditorSystem.active(game)") and input_router.contains("game.LevelEditorSystem.handle_input(game, event)"),"live editor owns input and pauses gameplay simulation through dedicated core modules")
	for layer in ["background","ground","objects","foreground"]: expect(render.contains("LevelEditorRenderer.draw_layer(game,\"%s\")"%layer),"renderer composes level-editor layer: %s"%layer)
	expect(debug.contains('"action":"level_editor"') and debug.contains('"enabled":true'),"F10 panel exposes the enabled level-constructor command")
	var renderer:=FileAccess.get_file_as_string("res://scripts/systems/level_editor_renderer.gd"); expect(renderer.contains("DebugUiKitSystem.draw_panel") and renderer.contains("draw_section_label") and renderer.contains("fit_label"),"level editor uses a grouped shared shell and adaptive labels")
	var preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/level_editor_ingame_preview.png")); expect(preview!=null and preview.get_width()>=1152 and absf(float(preview.get_width())/preview.get_height()-16.0/9.0)<0.01,"level editor keeps a reviewed sixteen-by-nine visual reference")
	var atlas_preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/level_editor_atlas_picker_preview.png")); expect(atlas_preview!=null and atlas_preview.get_width()>=1152 and absf(float(atlas_preview.get_width())/atlas_preview.get_height()-16.0/9.0)<0.01,"visual frame picker keeps a reviewed sixteen-by-nine reference")
