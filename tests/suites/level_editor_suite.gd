extends "res://tests/suites/suite_base.gd"

const TEST_DRAFT := "user://level_designs/level_editor_suite.json"
const TEST_PREFERENCES := "user://level_editor_preferences_suite.json"


## Запускает сценарии каталога, рисования, редактирования, импорта и обменного формата конструктора.
func run() -> void:
	test_catalog_contains_grouped_game_assets()
	test_f12_and_drag_drop_place_sprite_on_live_level()
	test_catalog_click_keeps_brush_for_later_map_click()
	test_click_brush_paints_every_crossed_grid_cell()
	test_ground_brush_replaces_cell_and_undoes_whole_stroke()
	test_rectangle_fill_is_one_dense_undoable_operation()
	test_eyedropper_copies_existing_object_into_brush()
	test_catalog_search_and_favorites_persist_outside_draft()
	test_new_editor_shortcuts_route_to_tools_and_filters()
	test_asset_anchors_keep_tiles_dense_and_large_objects_grounded()
	test_object_tools_and_history_preserve_layout()
	test_current_location_import_creates_editable_references()
	test_open_json_draft_round_trip_preserves_author_intent()
	test_autotile_masks_follow_four_neighbor_topology()
	test_road_brush_selects_visual_modules_and_rotations()
	test_water_brush_builds_shores_and_preserves_family()
	test_validation_blocks_broken_export_and_reports_map_issues()
	test_runtime_integration_freezes_simulation_and_draws_editor_layers()


## Сценарий: каталог автоматически сканирует растровые ресурсы проекта и группирует их по назначению.
## Исходное состояние: кэш конструктора очищен, в assets/game лежат тайлы, дома, растения, герои и предметы.
## Ожидаемый результат: каждый найденный путь существует, а основные дизайнерские группы не пусты.
func test_catalog_contains_grouped_game_assets() -> void:
	var game := make_game()
	game.LevelEditorSystem._catalog.clear()
	var entries: Array[Dictionary] = game.LevelEditorSystem.catalog()
	var categories: Dictionary = {}
	var all_exist := true
	for entry in entries:
		categories[entry.category] = int(categories.get(entry.category,0))+1
		all_exist = all_exist and ResourceLoader.exists(entry.path)
	expect(entries.size() >= 200 and all_exist, "level editor scans every available raster asset lazily")
	expect(entries.all(func(entry: Dictionary): return not "preview" in String(entry.path).to_lower()), "catalog hides technical preview sheets that are not placeable game objects")
	for category in ["terrain","buildings","vegetation","characters","items","farming","fishing","ui"]:
		expect(int(categories.get(category,0)) > 0, "level editor catalog exposes populated group: %s" % category)
	game.free()


## Сценарий: дизайнер не перетаскивает ресурс, а выбирает его обычным кликом и затем кликает по карте.
## Исходное состояние: редактор открыт, строка каталога нажата и отпущена внутри панели, холст остаётся пустым.
## Ожидаемый результат: ресурс остаётся активной кистью, а следующий отдельный клик создаёт ровно один объект.
func test_catalog_click_keeps_brush_for_later_map_click() -> void:
	var game := make_game(); game.LevelEditorSystem.toggle(game)
	var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(40,135); game.LevelEditorSystem.handle_input(game,press)
	var release_panel := InputEventMouseButton.new(); release_panel.button_index=MOUSE_BUTTON_LEFT; release_panel.pressed=false; release_panel.position=press.position; game.LevelEditorSystem.handle_input(game,release_panel)
	var chosen: Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(chosen.tool=="paint" and chosen.drag_kind=="" and not String(chosen.selected_asset).is_empty(), "plain catalog click arms a persistent paint brush without placing into the panel")
	var world_press := InputEventMouseButton.new(); world_press.button_index=MOUSE_BUTTON_LEFT; world_press.pressed=true; world_press.position=Vector2(515,347); game.LevelEditorSystem.handle_input(game,world_press)
	var world_release := InputEventMouseButton.new(); world_release.button_index=MOUSE_BUTTON_LEFT; world_release.pressed=false; world_release.position=world_press.position; game.LevelEditorSystem.handle_input(game,world_release)
	var painted: Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(painted.objects.size()==1 and painted.tool=="paint" and painted.selected_asset==chosen.selected_asset, "separate map click places one object and keeps the brush ready")
	game.free()


## Сценарий: дизайнер открывает конструктор и переносит выбранный тайл из панели прямо на живую карту.
## Исходное состояние: игра находится на первой локации, редактор закрыт, категория земли содержит спрайты.
## Ожидаемый результат: F12 открывает режим, drag-and-drop создаёт объект и привязывает начало тайла к сетке 24 px.
func test_f12_and_drag_drop_place_sprite_on_live_level() -> void:
	var game := make_game()
	var open_event := key_event(KEY_F12,KEY_F12,true)
	expect(game.LevelEditorSystem.handle_input(game,open_event) and game.LevelEditorSystem.active(game), "F12 opens the level editor over the live location")
	var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(40,135)
	game.LevelEditorSystem.handle_input(game,press)
	var dragging: Dictionary = game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(dragging.drag_kind == "catalog_asset" and dragging.tool == "paint" and not String(dragging.selected_asset).is_empty(), "asset row starts drag-and-drop and keeps the selected sprite as a brush")
	var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; release.position=Vector2(515,347)
	game.LevelEditorSystem.handle_input(game,release)
	var state: Dictionary = game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(state.objects.size()==1 and Vector2(state.objects[0].position)==Vector2(504,336), "dropped ground sprite uses the top-left origin of the shared 24 px world grid")
	expect(state.objects[0].asset_path==dragging.selected_asset and Vector2(state.objects[0].size)>Vector2.ZERO, "placed object keeps its asset path and native sprite dimensions")
	game.free()


## Сценарий: дизайнер выбирает траву кликом и одним зажатым движением проводит длинную полосу.
## Исходное состояние: активна категория земли, холст пуст, сетка равна 24 px, события мыши перескакивают через четыре клетки.
## Ожидаемый результат: кисть заполняет начальную, промежуточные и конечную клетки без единого промежутка.
func test_click_brush_paints_every_crossed_grid_cell() -> void:
	var game := make_game(); var state: Dictionary = game.LevelEditorSystem.default_state(game); state.active=true
	var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")
	game.LevelEditorSystem.activate_asset(state,entry); game.set_meta(game.LevelEditorSystem.META_KEY,state)
	var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(515,347); game.LevelEditorSystem.handle_input(game,press)
	var motion := InputEventMouseMotion.new(); motion.position=Vector2(611,347); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; game.LevelEditorSystem.handle_input(game,motion)
	var return_motion := InputEventMouseMotion.new(); return_motion.position=press.position; return_motion.button_mask=MOUSE_BUTTON_MASK_LEFT; game.LevelEditorSystem.handle_input(game,return_motion)
	var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; release.position=return_motion.position; game.LevelEditorSystem.handle_input(game,release)
	state=game.get_meta(game.LevelEditorSystem.META_KEY)
	var positions: Array = state.objects.map(func(object: Dictionary): return Vector2(object.position))
	expect(state.objects.size()==5 and positions==[Vector2(504,336),Vector2(528,336),Vector2(552,336),Vector2(576,336),Vector2(600,336)], "held brush rasterizes every crossed 24 px cell without gaps or duplicate cells on return")
	expect(state.objects.all(func(object: Dictionary): return object.anchor=="tile" and object.layer=="ground" and game.LevelEditorSystem.object_bounds(object).size==Vector2(24,24)), "terrain brush uses dense top-left tile bounds instead of sprite-center spacing")
	game.free()


## Сценарий: дизайнер перекрашивает клетку другим покрытием и отменяет весь предыдущий мазок.
## Исходное состояние: пять травяных клеток созданы одной непрерывной операцией и первая клетка выбирается повторно.
## Ожидаемый результат: новое покрытие заменяет землю без наложения, а Ctrl+Z восстанавливает состояние до мазка целиком.
func test_ground_brush_replaces_cell_and_undoes_whole_stroke() -> void:
	var game := make_game(); var state: Dictionary = game.LevelEditorSystem.default_state(game)
	game.LevelEditorSystem.activate_asset(state,game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")); game.LevelEditorSystem._begin_stroke(state)
	for x in range(5): game.LevelEditorSystem.place_selected_asset(game,state,Vector2(12+x*24,12),false)
	state.stroke_history_pushed=false; game.LevelEditorSystem.activate_asset(state,game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/ground_dirt.png")); game.LevelEditorSystem.place_selected_asset(game,state,Vector2(12,12))
	expect(state.objects.size()==5 and state.objects.back().asset_path.ends_with("ground_dirt.png"), "painting another ground texture replaces only the occupied cell")
	game.LevelEditorSystem.undo(state)
	expect(state.objects.size()==5 and state.objects[0].asset_path.ends_with("grass_lush.png"), "undo restores the replaced terrain cell without touching its neighbors")
	game.LevelEditorSystem.undo(state)
	expect(state.objects.is_empty(), "one undo removes the complete continuous five-cell stroke")
	game.free()


## Сценарий: дизайнер протягивает прямоугольную заливку от одной клетки до противоположного угла.
## Исходное состояние: активна травяная кисть, сетка 24 px, холст и история пусты.
## Ожидаемый результат: прямоугольник 4×3 заполняется без дыр и целиком отменяется одним Ctrl+Z.
func test_rectangle_fill_is_one_dense_undoable_operation() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); state.active=true
	game.LevelEditorSystem.activate_asset(state,game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")); state.tool="fill"; game.set_meta(game.LevelEditorSystem.META_KEY,state)
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(492,300); game.LevelEditorSystem.handle_input(game,press)
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(564,348); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; game.LevelEditorSystem.handle_input(game,motion)
	var release:=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; release.position=motion.position; game.LevelEditorSystem.handle_input(game,release); state=game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(state.objects.size()==12 and state.objects.all(func(object:Dictionary):return object.anchor=="tile"),"rectangle fill creates every cell of a dense four by three terrain area")
	game.LevelEditorSystem.undo(state); expect(state.objects.is_empty(),"one undo removes the complete rectangle fill")
	game.free()


## Сценарий: пипетка берёт уже размещённый срез атласа вместе с параметрами объекта.
## Исходное состояние: выбранный объект использует конкретный ресурс, слой, коллизию и квадратный source-rect.
## Ожидаемый результат: пипетка включает кисть того же ресурса, слоя, коллизии и номера кадра.
func test_eyedropper_copies_existing_object_into_brush() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); var path:="res://assets/game/environment/farm_plants.png"
	var object:={"asset_path":path,"name":"Морковь","layer":"objects","collision":true,"source":Rect2(48,48,48,48)}
	expect(game.LevelEditorSystem.ToolSystem.pick_object(state,object,game.LevelEditorSystem.CATEGORIES),"eyedropper accepts a real sprite object")
	expect(state.tool=="paint" and state.selected_asset==path and state.layer=="objects" and state.collision,"eyedropper copies the visual and physical brush settings")
	expect(state.slice_size==48 and state.slice_index==17,"eyedropper restores the exact square atlas frame")
	game.free()


## Сценарий: дизайнер ищет ресурс по имени, добавляет его в избранное и открывает новое состояние редактора.
## Исходное состояние: отдельный файл тестовых предпочтений отсутствует, документ карты не содержит UI-настроек.
## Ожидаемый результат: поиск работает поперёк категорий, избранное загружается отдельно и фильтрует каталог.
func test_catalog_search_and_favorites_persist_outside_draft() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PREFERENCES)); var game:=make_game(); var entries:Array[Dictionary]=game.LevelEditorSystem.catalog(); var favorite:="res://assets/game/tiles/editor/terrain/grass_lush.png"; var favorites:Array=[]
	var searched:Array[Dictionary]=game.LevelEditorSystem.AssetCatalogSystem.filter(entries,"items","grass lush",false,favorites)
	expect(searched.any(func(entry:Dictionary):return entry.path==favorite),"catalog search matches normalized asset names across category boundaries")
	expect(game.LevelEditorSystem.PreferencesStore.toggle_favorite(favorites,favorite,TEST_PREFERENCES),"favorite toggle writes the independent editor preferences file")
	var restored:Array[String]=game.LevelEditorSystem.PreferencesStore.load_favorites(TEST_PREFERENCES); var filtered:Array[Dictionary]=game.LevelEditorSystem.AssetCatalogSystem.filter(entries,"terrain","",true,restored)
	expect(restored==[favorite] and filtered.size()==1 and filtered[0].path==favorite,"favorite survives reload and restricts the catalog without entering the level document")
	var state:Dictionary=game.LevelEditorSystem.default_state(game); expect(not game.LevelEditorSystem.document(state).has("favorites"),"level draft remains free from personal catalog preferences")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PREFERENCES)); game.free()


## Сценарий: дизайнер переключает новые инструменты только клавиатурой, не покидая холст.
## Исходное состояние: конструктор активен, текстовый ввод выключен, каталог показывает обычную категорию.
## Ожидаемый результат: G и I выбирают инструменты, F фильтрует избранное, а slash открывает глобальный поиск.
func test_new_editor_shortcuts_route_to_tools_and_filters() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); state.active=true; game.set_meta(game.LevelEditorSystem.META_KEY,state)
	game.LevelEditorSystem.handle_input(game,key_event(KEY_G,KEY_G,true)); state=game.get_meta(game.LevelEditorSystem.META_KEY); expect(state.tool=="fill","G selects rectangle fill inside the editor")
	game.LevelEditorSystem.handle_input(game,key_event(KEY_I,KEY_I,true)); state=game.get_meta(game.LevelEditorSystem.META_KEY); expect(state.tool=="picker","I selects the eyedropper inside the editor")
	game.LevelEditorSystem.handle_input(game,key_event(KEY_F,KEY_F,true)); state=game.get_meta(game.LevelEditorSystem.META_KEY); expect(state.favorites_only,"F enables the favorites-only catalog filter")
	game.LevelEditorSystem.handle_input(game,key_event(KEY_SLASH,KEY_SLASH,true)); state=game.get_meta(game.LevelEditorSystem.META_KEY); expect(state.text_mode=="catalog_search","slash opens catalog search without triggering gameplay input")
	game.free()


## Сценарий: тайл, дерево и персонаж получают разные геометрические якоря из каталога.
## Исходное состояние: ресурсы земли и крупных мировых объектов анализируются без ручной настройки каждого файла.
## Ожидаемый результат: земля начинается в углу клетки, а дерево и герой опираются нижним центром на выбранную клетку.
func test_asset_anchors_keep_tiles_dense_and_large_objects_grounded() -> void:
	var game := make_game(); var state: Dictionary = game.LevelEditorSystem.default_state(game)
	var tile: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")
	var tree: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/environment/orchard/cherry_tree.png")
	var hero: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/characters/hero.png")
	expect(tile.anchor=="tile" and tile.layer=="ground" and not tile.collision, "terrain metadata uses a non-blocking top-left tile anchor")
	expect(tree.anchor=="bottom" and tree.layer=="objects" and tree.collision, "tree metadata grounds the trunk and enables collision")
	expect(hero.anchor=="bottom" and hero.layer=="objects" and not hero.collision, "character metadata grounds feet without forcing static collision")
	expect(game.LevelEditorSystem.placement_position(state,Vector2(31,47),"tile")==Vector2(24,24) and game.LevelEditorSystem.placement_position(state,Vector2(31,47),"bottom")==Vector2(36,48), "anchor positions follow the same 24 px cell contract")
	game.LevelEditorRenderer._texture_cache.clear(); var texture: Texture2D = game.LevelEditorRenderer.texture_for(String(tile.path))
	expect(texture!=null and game.LevelEditorRenderer._texture_cache.get(tile.path)==texture, "renderer retains lazily loaded editor texture instead of showing a transient white GPU placeholder")
	game.free()


## Сценарий: размещённый элемент копируют, поворачивают, отражают, масштабируют, удаляют и возвращают.
## Исходное состояние: в черновике один выбранный спрайт с исходной трансформацией и пустой историей.
## Ожидаемый результат: инструменты меняют только выбранный объект, а undo/redo точно восстанавливают состояния.
func test_object_tools_and_history_preserve_layout() -> void:
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	state.selected_asset="res://assets/game/tiles/grass.png"
	game.LevelEditorSystem.place_selected_asset(game,state,Vector2(500,300))
	game.LevelEditorSystem.duplicate_selected(state)
	expect(state.objects.size()==2 and state.objects[1].position==Vector2(state.objects[0].position)+Vector2(24,24), "duplicate is offset by one active grid cell")
	game.LevelEditorSystem.transform_selected(state,"rotate"); game.LevelEditorSystem.transform_selected(state,"flip_x"); game.LevelEditorSystem.transform_selected(state,"scale_up")
	expect(is_equal_approx(float(state.objects[1].rotation),PI*0.5) and state.objects[1].flip_x and is_equal_approx(float(state.objects[1].scale),1.25), "rotation flip and scale compose on the selected object")
	game.LevelEditorSystem.delete_selected(state)
	expect(state.objects.size()==1, "delete removes only the selected level object")
	game.LevelEditorSystem.undo(state); expect(state.objects.size()==2, "undo restores a deleted object")
	game.LevelEditorSystem.redo(state); expect(state.objects.size()==1, "redo reapplies the deletion")
	game.free()


## Сценарий: уже существующая игровая локация становится основой нового дизайнерского черновика.
## Исходное состояние: первая локация содержит здания, NPC, декорации и коллизии runtime-систем.
## Ожидаемый результат: импорт создаёт именованные референсы с исходной позицией, размерами и техническим id.
func test_current_location_import_creates_editable_references() -> void:
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	game.LevelEditorSystem.import_current_level(game,state)
	var first: Dictionary = state.objects[0] if not state.objects.is_empty() else {}
	expect(state.objects.size()>5 and bool(first.get("reference",false)), "current level imports its runtime objects as editable references")
	expect(not String(first.get("runtime_id","")).is_empty() and Vector2(first.get("size",Vector2.ZERO))>Vector2.ZERO, "imported reference keeps technical id and visible bounds")
	expect(first.get("position",Vector2.ZERO)==first.get("original_position",Vector2.ONE), "import records original coordinates for an unambiguous redesign diff")
	game.free()


## Сценарий: автор подписывает уровень и объект, сохраняет JSON, затем открывает его в чистом состоянии.
## Исходное состояние: один размещённый тайл имеет слой, коллизию, заметку, поворот и масштаб.
## Ожидаемый результат: открытый формат и повторная загрузка без потерь сохраняют все дизайнерские решения.
func test_open_json_draft_round_trip_preserves_author_intent() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DRAFT))
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	state.level_name="level editor suite"; state.level_notes="Общий замысел тестового уровня"; state.selected_asset="res://assets/game/tiles/grass.png"; state.layer="ground"; state.collision=true
	game.LevelEditorSystem.place_selected_asset(game,state,Vector2(321,222)); state.objects[0].name="Тихая поляна"; state.objects[0].notes="Оставить проход справа"; state.objects[0].rotation=PI*0.5; state.objects[0].scale=1.5
	var payload: Dictionary = game.LevelEditorSystem.document(state)
	expect(payload.format=="babushkina-ferma-level-draft" and payload.objects[0].notes=="Оставить проход справа", "export document is self-describing and keeps author notes")
	expect(game.LevelEditorSystem.save_draft(game,state,false) and FileAccess.file_exists(TEST_DRAFT), "draft saves into the user level-design directory")
	var restored: Dictionary = game.LevelEditorSystem.default_state(game)
	expect(game.LevelEditorSystem.load_draft(game,restored,TEST_DRAFT), "saved level draft can be loaded for later editing")
	var object: Dictionary = restored.objects[0]
	expect(restored.level_notes==state.level_notes and object.name=="Тихая поляна" and object.layer=="ground" and object.collision, "draft round-trip preserves labels notes layers and collision intent")
	expect(is_equal_approx(float(object.rotation),PI*0.5) and is_equal_approx(float(object.scale),1.5), "draft round-trip preserves object transforms")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DRAFT)); game.free()


## Сценарий: дизайнер рисует три одинаковых тайла земли Г-образной непрерывной кистью.
## Исходное состояние: сетка 24 px, клетки касаются сторонами, диагональные клетки соседями не считаются.
## Ожидаемый результат: каждому тайлу назначается стабильная четырёхбитная маска N/E/S/W для будущего автотайла.
func test_autotile_masks_follow_four_neighbor_topology() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); state.selected_asset="res://assets/game/tiles/editor/terrain/grass_lush.png"; state.layer="ground"
	var entry:Dictionary=game.LevelEditorSystem.AssetCatalogSystem.metadata(state.selected_asset); game.LevelEditorSystem.activate_asset(state,entry)
	for point in [Vector2(12,12),Vector2(36,12),Vector2(36,36)]: game.LevelEditorSystem.place_selected_asset(game,state,point,false)
	var masks:Array=[]
	for object in state.objects: masks.append(int(object.get("autotile_mask",0)))
	expect(masks==[2,12,1],"autotile masks encode east, south-west and north neighbors without diagonal leakage")
	var payload:Dictionary=game.LevelEditorSystem.document(state)
	expect(payload.objects[1].autotile_mask==12,"open JSON export preserves the generated autotile topology")
	game.free()


## Сценарий: дорожная кисть рисует линию с поворотом без ручного выбора трёх разных PNG.
## Исходное состояние: выбран любой модуль семейства dirt_path, три клетки образуют угол восток–юг.
## Ожидаемый результат: окончания и угол подставляются автоматически, а семейство остаётся связным после замены путей.
func test_road_brush_selects_visual_modules_and_rotations() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); var entry:Dictionary=game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/dirt_path_horizontal.png"); game.LevelEditorSystem.activate_asset(state,entry); state.layer="ground"
	for point in [Vector2(12,12),Vector2(36,12),Vector2(36,36)]: game.LevelEditorSystem.place_selected_asset(game,state,point,false)
	expect(String(state.objects[0].asset_path).ends_with("dirt_path_end.png") and is_equal_approx(float(state.objects[0].rotation),PI*0.5),"west road endpoint rotates toward its eastern neighbor")
	expect(String(state.objects[1].asset_path).ends_with("dirt_path_corner.png") and int(state.objects[1].autotile_mask)==12,"middle road cell becomes the matching south-west corner")
	expect(String(state.objects[2].asset_path).ends_with("dirt_path_end.png") and int(state.objects[2].autotile_mask)==1,"south road endpoint remains connected after visual path substitution")
	game.free()


## Сценарий: дизайнер рисует цельный квадрат воды одной кистью вместо ручного выбора каждого берега.
## Исходное состояние: выбран обычный water_clear, девять клеток образуют водоём три на три.
## Ожидаемый результат: центр становится живой водой, стороны — берегами, углы — повёрнутыми углами, а семейство переживает JSON round-trip.
func test_water_brush_builds_shores_and_preserves_family() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); var entry:Dictionary=game.LevelEditorSystem.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/water/water_clear.png"); game.LevelEditorSystem.activate_asset(state,entry); state.layer="ground"
	for y in 3:
		for x in 3: game.LevelEditorSystem.place_selected_asset(game,state,Vector2(12+x*24,12+y*24),false)
	var by_cell:Dictionary={}
	for object in state.objects: by_cell[Vector2i(int(object.position.x/24),int(object.position.y/24))]=object
	expect(String(by_cell[Vector2i(1,0)].asset_path).ends_with("shore_north.png") and String(by_cell[Vector2i(0,1)].asset_path).ends_with("shore_west.png"), "water brush automatically selects matching north and west shores")
	expect(String(by_cell[Vector2i(0,0)].asset_path).ends_with("shore_outer_corner.png") and int(by_cell[Vector2i(0,0)].autotile_mask)==6, "water corner is an isolated crop-safe module with the correct topology")
	expect(String(by_cell[Vector2i(1,1)].asset_path).contains("water_") and String(by_cell[Vector2i(1,1)].autotile_family)=="water_body", "water interior keeps a stable family after visual substitution")
	var payload:Dictionary=game.LevelEditorSystem.document(state); var saved_family:=String(payload.objects[4].autotile_family)
	expect(saved_family=="water_body", "open level document preserves automatic shoreline ownership")
	game.free()


## Сценарий: перед экспортом карта содержит пустое имя, пропавший ресурс и непроходимую землю.
## Исходное состояние: обычное локальное сохранение допустимо для незавершённого черновика, проектный экспорт обязан быть строгим.
## Ожидаемый результат: валидатор перечисляет ошибки и предупреждение, а затем принимает исправленный ресурс и название.
func test_validation_blocks_broken_export_and_reports_map_issues() -> void:
	var game:=make_game(); var state:Dictionary=game.LevelEditorSystem.default_state(game); state.level_name=""; state.objects=[{"id":1,"asset_path":"res://missing.png","name":"Сломанный тайл","position":Vector2.ZERO,"size":Vector2(24,24),"source":Rect2(),"anchor":"tile","layer":"ground","collision":true,"rotation":0.0,"reference":false}]
	var broken:Dictionary=game.LevelEditorSystem.validate_draft(state)
	expect(not broken.valid and broken.errors.size()>=2 and broken.warnings.size()==1,"validator reports missing title sprite and suspicious ground collision")
	expect(not game.LevelEditorSystem.save_draft(game,state,true),"strict project export is blocked while validation errors remain")
	state.level_name="valid editor map"; state.objects[0].asset_path="res://assets/game/tiles/editor/terrain/grass_lush.png"; var ready:Dictionary=game.LevelEditorSystem.validate_draft(state)
	expect(ready.valid and String(state.status).contains("готово"),"corrected draft becomes export-ready while retaining non-fatal warnings")
	game.free()


## Сценарий: конструктор подключён к единственному игровому циклу, отрисовке и диагностической панели.
## Исходное состояние: исходники интеграционных модулей и список доступных F10-команд читаются напрямую.
## Ожидаемый результат: режим останавливает симуляцию, рисует все четыре слоя и доступен как включённая команда.
func test_runtime_integration_freezes_simulation_and_draws_editor_layers() -> void:
	var core := FileAccess.get_file_as_string("res://scripts/game_core.gd")
	var loop := FileAccess.get_file_as_string("res://scripts/core/game_loop.gd")
	var input_router := FileAccess.get_file_as_string("res://scripts/core/game_input_router.gd")
	var render := FileAccess.get_file_as_string("res://scripts/systems/render_system.gd")
	var debug := FileAccess.get_file_as_string("res://scripts/systems/debug_overlay_system.gd")
	expect(core.contains("GameLoop.physics_process") and core.contains("GameInputRouter.route") and loop.contains("game.LevelEditorSystem.active(game)") and input_router.contains("game.LevelEditorSystem.handle_input(game, event)"), "live editor owns input and pauses gameplay simulation through dedicated core modules")
	for layer in ["background","ground","objects","foreground"]:
		expect(render.contains("LevelEditorRenderer.draw_layer(game,\"%s\")"%layer), "renderer composes level-editor layer: %s"%layer)
	expect(debug.contains('"action":"level_editor"') and debug.contains('"enabled":true'), "F10 panel exposes the enabled level-constructor command")
	var renderer := FileAccess.get_file_as_string("res://scripts/systems/level_editor_renderer.gd")
	expect(renderer.contains("DebugUiKitSystem.draw_panel") and renderer.contains("DebugUiKitSystem.draw_catalog_row") and renderer.contains("DebugUiKitSystem.draw_readout"), "level editor uses the shared carved shell for panel catalog and technical readouts")
	var preview := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/level_editor_ingame_preview.png"))
	expect(preview != null and preview.get_width()>=1152 and absf(float(preview.get_width())/preview.get_height()-16.0/9.0)<0.01, "level editor keeps a native-or-larger sixteen-by-nine visual reference")
