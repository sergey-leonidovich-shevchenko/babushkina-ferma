extends RefCounted

const ATLAS:=preload("res://assets/game/environment/buildable_fence_atlas_v1.png")
const SOURCE_CELL:=Vector2(64,64)
const WorldVisualProfileSystem:=preload("res://scripts/systems/world_visual_profile_system.gd")


## Возвращает столбец и поворот модульного рисунка для любой маски четырёх соседей.
static func visual_for_mask(mask: int) -> Dictionary:
	if mask==0:return {"column":0,"rotation":0.0}
	if mask in [1,4,5]:return {"column":2,"rotation":0.0}
	if mask in [2,8,10]:return {"column":1,"rotation":0.0}
	var corners:={3:0.0,6:PI*0.5,12:PI,9:PI*1.5}
	if corners.has(mask):return {"column":3,"rotation":corners[mask]}
	var junctions:={7:0.0,14:PI*0.5,13:PI,11:PI*1.5}
	if junctions.has(mask):return {"column":4,"rotation":junctions[mask]}
	return {"column":5,"rotation":0.0}


## Возвращает область одного материала и одного модуля в строгом атласе 8×5.
static func source(style: int, column: int) -> Rect2:
	return Rect2(Vector2(clampi(column,0,7),clampi(style,0,4))*SOURCE_CELL,SOURCE_CELL)


## Рассчитывает мягкий сезонно-погодный оттенок без подмены материала ограды.
static func climate_color(game: Node) -> Color:
	var season: String=game.WorldEventSystem.season(game.day); var weather: String=game.WorldEventSystem.weather(game)
	var result: Color={"spring":Color.WHITE,"summer":Color("fff4d5"),"autumn":Color("f2c984"),"winter":Color("dce8ec")}.get(season,Color.WHITE)
	if weather in ["rain","storm"]: result*=Color("a9c5d5")
	elif weather=="wind": result*=Color("eee2c2")
	return result


## Рисует все пользовательские секции с автосоединением, глубиной и открытыми калитками.
static func draw_world(game: Node2D) -> void:
	var values: Array=game.FenceSystem.structures(game); var visible:=[]
	for structure in values:
		if structure.location==game.current_location: visible.append(structure)
	visible.sort_custom(func(left: Dictionary,right: Dictionary): return game.FenceSystem.structure_center(left).y<game.FenceSystem.structure_center(right).y)
	for structure in visible:
		draw_structure(game,structure)
	if game.FenceSystem.active(game): draw_target(game)


## Рисует одну секцию или калитку из строки выбранного материала.
static func draw_structure(game: Node2D, structure: Dictionary) -> void:
	var center: Vector2=game.FenceSystem.structure_center(structure); var rotation:=0.0; var column:=0; var profile_id:="fence_section"
	if structure.kind=="gate": column=7 if structure.open else 6; rotation=PI*0.5 if int(structure.orientation)==1 else 0.0; profile_id="fence_gate"
	else:
		var visual:=visual_for_mask(game.FenceSystem.connection_mask(game,structure)); column=visual.column; rotation=visual.rotation
	var size:Vector2=WorldVisualProfileSystem.visual_size(profile_id)
	game.draw_set_transform(center-game.camera_offset,rotation); game.draw_texture_rect_region(ATLAS,Rect2(-size*0.5,size),source(int(structure.style),column),climate_color(game)); game.draw_set_transform(-game.camera_offset)
	draw_weather_detail(game,center,size)


## Добавляет снег, влажный блеск или ветровые листья поверх уже построенной ограды.
static func draw_weather_detail(game: Node2D, center: Vector2, size: Vector2) -> void:
	var season: String=game.WorldEventSystem.season(game.day); var weather: String=game.WorldEventSystem.weather(game)
	if season=="winter" or weather=="snow":
		game.draw_line(center+Vector2(-size.x*0.32,-size.y*0.29),center+Vector2(size.x*0.30,-size.y*0.29),Color(0.92,0.98,1,0.82),3.0)
	elif weather in ["rain","storm"]:
		game.draw_line(center+Vector2(-size.x*0.24,-size.y*0.30),center+Vector2(size.x*0.08,-size.y*0.18),Color(0.72,0.9,1,0.55),1.5)
	elif weather=="wind":
		game.draw_line(center+Vector2(size.x*0.18,-size.y*0.18),center+Vector2(size.x*0.32,-size.y*0.25),Color("d99b42"),2.0)


## Рисует клеточное превью цели зелёным либо красным до расходования предмета.
static func draw_target(game: Node2D) -> void:
	var value: Dictionary=game.FenceSystem.runtime(game); var cell: Vector2i=game.FenceSystem.target_cell(game); var reason: String=game.FenceSystem.placement_reason(game,cell,value.piece,int(value.orientation)); var cells: Array[Vector2i]=[cell]
	if value.piece=="gate": cells.append(cell+(Vector2i.RIGHT if int(value.orientation)==0 else Vector2i.DOWN))
	for occupied in cells:
		var rect:=Rect2(Vector2(occupied*game.FenceSystem.CELL_SIZE),Vector2(game.FenceSystem.CELL_SIZE,game.FenceSystem.CELL_SIZE)); game.draw_rect(rect,Color(0.3,0.95,0.45,0.25) if reason=="ok" else Color(1,0.2,0.18,0.28)); game.draw_rect(rect,Color("8ef09d") if reason=="ok" else Color("ff665c"),false,2.0)


## Рисует компактную памятку режима с материалом, типом и остатком строительных наборов.
static func draw_ui(game: Node2D) -> void:
	if game.shop_open or game.inventory_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open or game.quest_log_open or game.skill_menu_open or game.world_map_open:return
	if not game.FenceSystem.active(game):
		if game.touch_controls_visible and game.current_location in game.FenceSystem.BUILDABLE_LOCATIONS:
			var launcher: Rect2=game.FenceSystem.TOUCH_BUTTON; game.draw_rect(launcher,Color(0.18,0.11,0.055,0.92)); game.draw_rect(launcher,Color("d7a94f"),false,2.0); game.draw_item_icon(game.FenceSystem.SECTION_ITEM,launcher.grow(-8)); game.draw_ui_string(game.UI_FONT,launcher.position+Vector2(5,52),"Z",HORIZONTAL_ALIGNMENT_LEFT,18,11,Color("fff0c8"))
		return
	var value: Dictionary=game.FenceSystem.runtime(game); var rect:=Rect2(744,452,392,116); game.draw_rect(rect,Color(0.08,0.055,0.035,0.94)); game.draw_rect(rect,Color("d7a94f"),false,3.0)
	game.draw_ui_string(game.MENU_FONT,rect.position+Vector2(16,28),game.LocaleSystem.ui("fence_builder"),HORIZONTAL_ALIGNMENT_LEFT,360,18,Color("fff0c8"))
	var piece: String=game.LocaleSystem.ui("fence_gate") if value.piece=="gate" else game.LocaleSystem.ui("fence_section"); var counts:="%s ×%d · %s ×%d"%[game.inventory_item_name(game.FenceSystem.SECTION_ITEM),game.inventory_item_count(game.FenceSystem.SECTION_ITEM),game.inventory_item_name(game.FenceSystem.GATE_ITEM),game.inventory_item_count(game.FenceSystem.GATE_ITEM)]
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(16,55),"%s · %s"%[game.FenceSystem.style_name(game,value.style),piece],HORIZONTAL_ALIGNMENT_LEFT,360,15,Color("ffe09a")); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(16,78),counts,HORIZONTAL_ALIGNMENT_LEFT,360,12,Color("d9c59c")); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(16,101),game.LocaleSystem.ui("fence_controls"),HORIZONTAL_ALIGNMENT_LEFT,360,11,Color("eee0c2"))
