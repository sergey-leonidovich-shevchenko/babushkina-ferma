extends RefCounted

const BASE_CELL:=24
const SEASONS:=["spring","summer","autumn","winter"]
const BIOME_ORDER:=["forest","rocky","ruins","cursed","glassworks"]
const LARGE_PROP_BASES:=[Vector2(150,245),Vector2(720,230),Vector2(1260,250),Vector2(1900,225),Vector2(360,1050),Vector2(980,1030),Vector2(1600,1050),Vector2(2220,1030)]
const SMALL_PROP_BASES:=[Vector2(330,700),Vector2(820,610),Vector2(1360,810),Vector2(1810,590),Vector2(2260,520),Vector2(1180,610)]
const SEASONAL_TREE_BASE:=Vector2(1695,390)
const MOON_SOLID_BASES:=[Vector2(1148,650),Vector2(1690,420),Vector2(2026,750)]
const BACKGROUNDS:={"forest":Color("315c3c"),"rocky":Color("6f6a5b"),"ruins":Color("665849"),"cursed":Color("3e304b"),"glassworks":Color("6f493b")}

const TEXTURES:={
	"tree_spring":preload("res://assets/game/environment/seasons/tree_spring.png"),"tree_summer":preload("res://assets/game/environment/seasons/tree_summer.png"),"tree_autumn":preload("res://assets/game/environment/seasons/tree_autumn.png"),"tree_winter":preload("res://assets/game/environment/seasons/tree_winter.png"),
	"ground_spring":preload("res://assets/game/environment/seasons/ground_spring.png"),"ground_summer":preload("res://assets/game/environment/seasons/ground_summer.png"),"ground_autumn":preload("res://assets/game/environment/seasons/ground_autumn.png"),"ground_winter":preload("res://assets/game/environment/seasons/ground_winter.png"),
	"moon_portal":preload("res://assets/game/environment/moon/portal.png"),"moon_flower":preload("res://assets/game/environment/moon/flower.png"),"moon_crystal":preload("res://assets/game/environment/moon/crystal.png"),"moon_altar":preload("res://assets/game/environment/moon/altar.png"),
	"moon_echo":preload("res://assets/game/environment/moon/echo.png"),"moon_guardian":preload("res://assets/game/environment/moon/guardian.png"),"moon_stag":preload("res://assets/game/environment/moon/stag.png"),"moon_chest":preload("res://assets/game/environment/moon/chest.png"),
	"forest_landmark":preload("res://assets/game/environment/biomes/forest_landmark.png"),"forest_detail":preload("res://assets/game/environment/biomes/forest_detail.png"),
	"rocky_landmark":preload("res://assets/game/environment/biomes/rocky_landmark.png"),"rocky_detail":preload("res://assets/game/environment/biomes/rocky_detail.png"),
	"ruins_landmark":preload("res://assets/game/environment/biomes/ruins_landmark.png"),"ruins_detail":preload("res://assets/game/environment/biomes/ruins_detail.png"),
	"cursed_landmark":preload("res://assets/game/environment/biomes/cursed_landmark.png"),"cursed_detail":preload("res://assets/game/environment/biomes/cursed_detail.png"),
	"glassworks_landmark":preload("res://assets/game/environment/biomes/glassworks_landmark.png"),"glassworks_detail":preload("res://assets/game/environment/biomes/glassworks_detail.png"),
}
const PROFILES:={
	"tree_spring":{"size":Vector2(264,360),"pivot_y":0.97,"collision":Vector2(72,48)},"tree_summer":{"size":Vector2(264,360),"pivot_y":0.97,"collision":Vector2(72,48)},"tree_autumn":{"size":Vector2(264,360),"pivot_y":0.97,"collision":Vector2(72,48)},"tree_winter":{"size":Vector2(264,360),"pivot_y":0.97,"collision":Vector2(72,48)},
	"ground_spring":{"size":Vector2(144,144),"pivot_y":0.74,"collision":Vector2.ZERO},"ground_summer":{"size":Vector2(144,144),"pivot_y":0.74,"collision":Vector2.ZERO},"ground_autumn":{"size":Vector2(144,144),"pivot_y":0.74,"collision":Vector2.ZERO},"ground_winter":{"size":Vector2(144,144),"pivot_y":0.74,"collision":Vector2.ZERO},
	"moon_portal":{"size":Vector2(168,240),"pivot_y":0.78,"collision":Vector2.ZERO},"moon_flower":{"size":Vector2(144,216),"pivot_y":0.78,"collision":Vector2.ZERO},"moon_crystal":{"size":Vector2(192,240),"pivot_y":0.78,"collision":Vector2(72,48)},"moon_altar":{"size":Vector2(288,384),"pivot_y":0.78,"collision":Vector2(96,48)},
	"moon_echo":{"size":Vector2(144,216),"pivot_y":0.78,"collision":Vector2.ZERO},"moon_guardian":{"size":Vector2(168,240),"pivot_y":0.78,"collision":Vector2(72,48)},"moon_stag":{"size":Vector2(168,240),"pivot_y":0.78,"collision":Vector2.ZERO},"moon_chest":{"size":Vector2(168,168),"pivot_y":0.78,"collision":Vector2(72,48)},
	"forest_landmark":{"size":Vector2(168,240),"pivot_y":0.82,"collision":Vector2(72,48)},"rocky_landmark":{"size":Vector2(192,240),"pivot_y":0.82,"collision":Vector2(96,72)},"ruins_landmark":{"size":Vector2(192,240),"pivot_y":0.82,"collision":Vector2(96,72)},"cursed_landmark":{"size":Vector2(168,240),"pivot_y":0.82,"collision":Vector2(72,48)},"glassworks_landmark":{"size":Vector2(168,240),"pivot_y":0.82,"collision":Vector2(72,48)},
	"forest_detail":{"size":Vector2(144,168),"pivot_y":0.74,"collision":Vector2.ZERO},"rocky_detail":{"size":Vector2(144,168),"pivot_y":0.74,"collision":Vector2.ZERO},"ruins_detail":{"size":Vector2(144,168),"pivot_y":0.74,"collision":Vector2.ZERO},"cursed_detail":{"size":Vector2(144,168),"pivot_y":0.74,"collision":Vector2.ZERO},"glassworks_detail":{"size":Vector2(144,168),"pivot_y":0.74,"collision":Vector2.ZERO},
}


## Возвращает отдельную текстуру окружения без дробной выборки исходного атласа.
static func texture(kind:String)->Texture2D:
	return TEXTURES.get(kind) as Texture2D


## Возвращает независимую копию профиля размера, опоры и основания объекта.
static func profile(kind:String)->Dictionary:
	return Dictionary(PROFILES.get(kind,{})).duplicate(true)


## Строит мировой прямоугольник с калиброванной нижней опорой старых координат уровня.
static func visual_rect(kind:String,position:Vector2,scale:float=1.0)->Rect2:
	var data:=profile(kind); var size:=Vector2(data.get("size",Vector2.ZERO))*scale
	return Rect2(position-Vector2(size.x*0.5,size.y*float(data.get("pivot_y",1.0))),size)


## Строит модульное основание из того же профиля и логической позиции объекта.
static func collision_rect(kind:String,position:Vector2)->Rect2:
	var size:=Vector2(profile(kind).get("collision",Vector2.ZERO))
	return Rect2(position-Vector2(size.x*0.5,size.y),size)


## Проверяет наличие, модульность и совпадение профиля с импортированным PNG.
static func profile_is_valid(kind:String)->bool:
	if not TEXTURES.has(kind) or not PROFILES.has(kind): return false
	var size:=Vector2(PROFILES[kind].size); var collision:=Vector2(PROFILES[kind].collision)
	return texture(kind).get_size()==size and int(size.x)%BASE_CELL==0 and int(size.y)%BASE_CELL==0 and int(collision.x)%BASE_CELL==0 and int(collision.y)%BASE_CELL==0


## Рисует независимый спрайт один к одному либо с равномерной пульсацией события.
static func draw(canvas:CanvasItem,kind:String,position:Vector2,tint:Color=Color.WHITE,scale:float=1.0)->void:
	canvas.draw_texture_rect(texture(kind),visual_rect(kind,position,scale),false,tint)


## Возвращает цвет фона приключенческого биома из общего каталога.
static func background(location:String)->Color:
	return BACKGROUNDS.get(location,Color("48624a"))


## Рисует сезонное дерево и два напочвенных кластера без искажения пропорций.
static func draw_seasonal_village(canvas:CanvasItem,season_index:int)->void:
	var season:String=SEASONS[clampi(season_index,0,SEASONS.size()-1)]
	draw(canvas,"tree_%s"%season,SEASONAL_TREE_BASE)
	for position in [Vector2(920,720),Vector2(1450,785)]: draw(canvas,"ground_%s"%season,position)


## Рисует доступный лунный портал отдельной текстурой с естественными пропорциями.
static func draw_eclipse_world(canvas:CanvasItem,location:String,portal_position:Vector2,portal_visible:bool)->void:
	if portal_visible: draw(canvas,"moon_portal",portal_position)


## Рисует квестовый кристалл в интерфейсе без неравномерного растяжения.
static func draw_eclipse_item(canvas:CanvasItem,kind:String,rect:Rect2)->bool:
	if kind!="eclipse_core": return false
	var source_size:=texture("moon_crystal").get_size(); var scale:=minf(rect.size.x/source_size.x,rect.size.y/source_size.y); var size:=source_size*scale
	canvas.draw_texture_rect(texture("moon_crystal"),Rect2(rect.get_center()-size*0.5,size),false)
	return true


## Рисует крупные ориентиры и малый декор выбранного биома из отдельных PNG.
static func draw_biome(canvas:CanvasItem,location:String)->void:
	if location not in BIOME_ORDER: return
	for position in LARGE_PROP_BASES: draw(canvas,"%s_landmark"%location,position)
	for position in SMALL_PROP_BASES: draw(canvas,"%s_detail"%location,position)


## Проверяет столкновение персонажа с основаниями крупных биомных ориентиров.
static func blocks_biome_position(location:String,position:Vector2,radius:float)->bool:
	if location not in BIOME_ORDER: return false
	for base in LARGE_PROP_BASES:
		if circle_intersects_rect(position,radius,collision_rect("%s_landmark"%location,base)): return true
	return false


## Проверяет основания сезонного дерева и трёх твёрдых объектов Лунной поляны.
static func blocks_event_position(location:String,position:Vector2,radius:float)->bool:
	if location=="overworld": return circle_intersects_rect(position,radius,collision_rect("tree_spring",SEASONAL_TREE_BASE))
	if location=="moon_glade":
		var kinds:=["moon_crystal","moon_altar","moon_chest"]
		for index in MOON_SOLID_BASES.size():
			if circle_intersects_rect(position,radius,collision_rect(kinds[index],MOON_SOLID_BASES[index])): return true
	return false


## Проверяет пересечение круглого персонажа с модульным прямоугольным основанием.
static func circle_intersects_rect(center:Vector2,radius:float,rect:Rect2)->bool:
	if rect.size==Vector2.ZERO: return false
	var closest:=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
	return center.distance_squared_to(closest)<radius*radius


## Готовит сезонный, лунный или диагностический кадр окружения по аргументу запуска.
static func configure_from_arguments(game:Node,arguments:PackedStringArray)->bool:
	var output:=""
	if "--capture-environment-season" in arguments:
		game.language_screen=false; game.title_screen=false; game.current_location="overworld"; game.player=Vector2(1695,350); game.day=15; output="season"
	elif "--capture-environment-moon" in arguments:
		game.language_screen=false; game.title_screen=false; game.current_location="moon_glade"; game.player=Vector2(1450,500); output="moon"
		game.state.world.moon_glade=game.MoonGladeSystem.default_state(); game.state.world.moon_glade.crystal_charged=true; game.state.world.moon_glade.guardian_alive=true
	elif "--capture-environment-debug" in arguments:
		game.language_screen=false; game.title_screen=false; game.current_location="forest"; game.player=Vector2(720,450); output="debug"
		var debug_state:Dictionary=game.DebugOverlaySystem.default_state(); debug_state.grid_size=BASE_CELL; debug_state.opacity=0.30; debug_state.hitboxes=true
		game.set_meta(game.DebugOverlaySystem.META_KEY,debug_state); game.DebugOverlaySystem.refresh_grid(game)
	else: return false
	game.tutorial_visible=false; game.set_meta("capture_first_level_clean",true); game.set_meta("capture_environment_frames",8); game.set_meta("capture_environment_output",output)
	return true


## Сохраняет контрольный кадр окружения после полноценных кадров отрисовки.
static func update_preview_capture(game:Node)->bool:
	if not game.has_meta("capture_environment_frames"): return false
	var frames_left:=int(game.get_meta("capture_environment_frames"))-1; game.set_meta("capture_environment_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_environment_frames"); var name:=String(game.get_meta("capture_environment_output","preview")); game.remove_meta("capture_environment_output")
	var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/environment_%s_ingame_preview.png"%name); var error:=image.save_png(output)
	if error!=OK: push_error("Не удалось сохранить предпросмотр окружения %s: %s"%[name,error])
	game.get_tree().quit(); return true
