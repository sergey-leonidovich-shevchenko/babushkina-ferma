extends RefCounted


## Собирает плотный демонстрационный фрагмент земли, дорог и воды для визуального QA редактора.
static func configure(game:Node,state:Dictionary,editor_system,asset_catalog_system)->void:
	state.objects=[]; state.history=[]; state.future=[]; state.next_id=1; state.level_name="Кисть местности 24×24"; state.grid=24
	var origin:=Vector2(game.camera_offset)+Vector2(360,120)
	editor_system.activate_asset(state,asset_catalog_system.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png"))
	for row in range(14):
		for column in range(22): editor_system.place_selected_asset(game,state,origin+Vector2(column*24+12,row*24+12),false)
	editor_system.activate_asset(state,asset_catalog_system.metadata("res://assets/game/tiles/editor/terrain/dirt_path_horizontal.png"))
	for column in range(22): editor_system.place_selected_asset(game,state,origin+Vector2(column*24+12,7*24+12),false)
	editor_system.activate_asset(state,asset_catalog_system.metadata("res://assets/game/tiles/editor/terrain/dirt_path_vertical.png"))
	for row in range(14): editor_system.place_selected_asset(game,state,origin+Vector2(10*24+12,row*24+12),false)
	editor_system.activate_asset(state,asset_catalog_system.metadata("res://assets/game/tiles/editor/terrain/dirt_path_cross.png")); editor_system.place_selected_asset(game,state,origin+Vector2(10*24+12,7*24+12),false)
	editor_system.activate_asset(state,asset_catalog_system.metadata("res://assets/game/tiles/editor/water/water_clear.png"))
	for row in range(2,7):
		for column in range(16,21): editor_system.place_selected_asset(game,state,origin+Vector2(column*24+12,row*24+12),false)
	editor_system.activate_asset(state,asset_catalog_system.metadata("res://assets/game/tiles/editor/terrain/grass_flowers.png")); state.mouse=Vector2(672,492); state.selected=-1; state.history=[]; state.future=[]; state.status="Клик — один тайл · зажать — непрерывная кисть"
