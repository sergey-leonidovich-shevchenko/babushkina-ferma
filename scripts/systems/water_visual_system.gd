extends RefCounted

const CELL_SIZE := 24
const ROOT := "res://assets/game/tiles/editor/water/"
const SURFACE_KINDS := ["water_clear","water_ripples","water_deep","water_shallow","water_lilies","water_sparkles"]
const SHORE_KINDS := ["shore_north","shore_south","shore_west","shore_east","shore_outer_corner","shore_inner_corner"]
const RIVER_KINDS := ["river_horizontal","river_vertical","river_corner","river_t_junction","river_cross","river_end"]
const MODULES := {
	"water_clear":preload("res://assets/game/tiles/editor/water/water_clear.png"),
	"water_ripples":preload("res://assets/game/tiles/editor/water/water_ripples.png"),
	"water_deep":preload("res://assets/game/tiles/editor/water/water_deep.png"),
	"water_shallow":preload("res://assets/game/tiles/editor/water/water_shallow.png"),
	"water_lilies":preload("res://assets/game/tiles/editor/water/water_lilies.png"),
	"water_sparkles":preload("res://assets/game/tiles/editor/water/water_sparkles.png"),
	"shore_north":preload("res://assets/game/tiles/editor/water/shore_north.png"),
	"shore_south":preload("res://assets/game/tiles/editor/water/shore_south.png"),
	"shore_west":preload("res://assets/game/tiles/editor/water/shore_west.png"),
	"shore_east":preload("res://assets/game/tiles/editor/water/shore_east.png"),
	"shore_outer_corner":preload("res://assets/game/tiles/editor/water/shore_outer_corner.png"),
	"shore_inner_corner":preload("res://assets/game/tiles/editor/water/shore_inner_corner.png"),
	"river_horizontal":preload("res://assets/game/tiles/editor/water/river_horizontal.png"),
	"river_vertical":preload("res://assets/game/tiles/editor/water/river_vertical.png"),
	"river_corner":preload("res://assets/game/tiles/editor/water/river_corner.png"),
	"river_t_junction":preload("res://assets/game/tiles/editor/water/river_t_junction.png"),
	"river_cross":preload("res://assets/game/tiles/editor/water/river_cross.png"),
	"river_end":preload("res://assets/game/tiles/editor/water/river_end.png"),
	"pond_rocky":preload("res://assets/game/tiles/editor/water/pond_rocky.png"),
}
const FISH_SHEET := preload("res://assets/game/fishing/Fish Swimming.png")
const SPLASH_SHEET := preload("res://assets/game/fishing/Splash Effect.png")
const BUBBLE_SHEET := preload("res://assets/game/fishing/Bubbles Rising.png")
const EFFECT_SHEETS := {"fish":FISH_SHEET,"splash":SPLASH_SHEET,"bubbles":BUBBLE_SHEET}
const EFFECT_PROFILES := {
	"fish":{"frames":10,"frame_ms":130,"source_size":Vector2(16,16),"visual_size":Vector2(48,48),"content_size":Vector2(48,48),"offset":Vector2(0,16)},
	"splash":{"frames":18,"frame_ms":80,"source_size":Vector2(16,16),"visual_size":Vector2(72,72),"content_size":Vector2(64,64),"offset":Vector2.ZERO},
	"bubbles":{"frames":8,"frame_ms":150,"source_size":Vector2(16,16),"visual_size":Vector2(48,48),"content_size":Vector2(48,48),"offset":Vector2.ZERO},
}
const AMBIENT_WATER_POINTS := [Vector2(430,430),Vector2(850,655),Vector2(1180,748),Vector2(1580,842),Vector2(1930,955)]


## Возвращает единый профиль водной клетки для рендера, редактора и навигационного аудита.
static func profile() -> Dictionary:
	return {"visual_size":Vector2(CELL_SIZE,CELL_SIZE),"anchor":"top_left","collision":"water_cell","navigation_blocked":true}


## Возвращает отдельную crop-safe текстуру водного модуля без выборки соседней ячейки атласа.
static func texture(kind: String) -> Texture2D:
	return MODULES.get(kind,MODULES.water_clear)


## Возвращает ресурсный путь модуля, чтобы конструктор сохранял тот же каталог, который использует игра.
static func module_path(kind: String) -> String:
	return ROOT+kind+".png"


## Подбирает спокойную либо декоративную внутреннюю воду с редкой анимируемой рябью.
static func surface_kind(cell: Vector2i, animation_frame: int = 0) -> String:
	var seed:=absi(cell.x*47+cell.y*89+23)
	if seed%19==0: return "water_lilies"
	if seed%7==0: return ["water_clear","water_ripples","water_clear","water_sparkles"][posmod(animation_frame+seed,4)]
	if seed%5==0: return "water_ripples"
	return "water_clear"


## Выбирает берег, угол, узкое русло либо внутреннюю воду по четырёхбитной маске N/E/S/W.
static func variant_for_mask(mask: int, cell: Vector2i, animation_frame: int = 0) -> Dictionary:
	if mask==15: return {"kind":surface_kind(cell,animation_frame),"rotation":0.0}
	var edges:={7:"shore_west",13:"shore_east",14:"shore_north",11:"shore_south"}
	if edges.has(mask): return {"kind":String(edges[mask]),"rotation":0.0}
	var corners:={6:0.0,12:PI*0.5,9:PI,3:-PI*0.5}
	if corners.has(mask): return {"kind":"shore_outer_corner","rotation":float(corners[mask])}
	if mask==5: return {"kind":"river_vertical","rotation":0.0}
	if mask==10: return {"kind":"river_horizontal","rotation":0.0}
	if mask in [1,2,4,8]: return {"kind":"river_end","rotation":{1:0.0,2:PI*0.5,4:PI,8:-PI*0.5}[mask]}
	return {"kind":"pond_rocky","rotation":0.0}


## Собирает клетки видимой воды первой локации тем же запросом, которым пользуется игровая навигация.
static func first_location_cells(layout: GDScript, season: String = "spring") -> Dictionary:
	var cells: Dictionary={}
	for row in range(layout.OVERWORLD_TILE_COUNT.y):
		for col in range(layout.OVERWORLD_TILE_COUNT.x):
			var cell:=Vector2i(col,row)
			if layout.overworld_tile(cell,season)==layout.OVERWORLD_TILE_WATER: cells[cell]=true
	return cells


## Рисует одну модульную водную клетку с поворотом вокруг центра без деформации PNG 24×24.
static func draw_module(canvas: Node2D, cell: Vector2i, cells: Dictionary, animation_frame: int, tint: Color = Color.WHITE) -> void:
	var mask:=neighbor_mask(cell,cells); var variant:=variant_for_mask(mask,cell,animation_frame); var destination:=Rect2(Vector2(cell)*CELL_SIZE,Vector2(CELL_SIZE,CELL_SIZE))
	canvas.draw_set_transform(destination.get_center(),float(variant.rotation)); canvas.draw_texture_rect(texture(String(variant.kind)),Rect2(-destination.size*0.5,destination.size),false,tint); canvas.draw_set_transform(Vector2.ZERO)


## Вычисляет четырёхбитную маску соседних водных клеток в порядке N/E/S/W.
static func neighbor_mask(cell: Vector2i, cells: Dictionary) -> int:
	var mask:=0; var directions:=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
	for index in directions.size():
		if cells.has(cell+directions[index]): mask|=1<<index
	return mask


## Возвращает профиль анимированного водного эффекта с модульной рамкой и целочисленным масштабом содержимого.
static func effect_profile(kind: String) -> Dictionary:
	return EFFECT_PROFILES.get(kind,EFFECT_PROFILES.bubbles)


## Возвращает изолированный исходный кадр 16×16 из CC0-листа рыбы, пузырьков либо всплеска.
static func effect_source_rect(kind: String, frame: int) -> Rect2:
	var effect:=effect_profile(kind); var count:=int(effect.frames); var source_size:=Vector2(effect.source_size)
	return Rect2(Vector2(posmod(frame,count)*int(source_size.x),0),source_size)


## Возвращает полную модульную рамку эффекта, используемую инспектором и визуальными тестами.
static func effect_visual_rect(kind: String, position: Vector2) -> Rect2:
	var effect:=effect_profile(kind); var size:=Vector2(effect.visual_size); var center:=position+Vector2(effect.offset)
	return Rect2(center-size*0.5,size)


## Возвращает область фактических пикселей внутри модульной рамки без дробного масштабирования исходника.
static func effect_content_rect(kind: String, position: Vector2) -> Rect2:
	var effect:=effect_profile(kind); var size:=Vector2(effect.content_size); var center:=position+Vector2(effect.offset)
	return Rect2(center-size*0.5,size)


## Рисует один кадр водного эффекта, сохраняя прозрачность и целочисленный масштаб пикселей.
static func draw_effect(canvas: Node2D, kind: String, position: Vector2, frame: int, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(EFFECT_SHEETS.get(kind,BUBBLE_SHEET),effect_content_rect(kind,position),effect_source_rect(kind,frame),tint)


## Добавляет над цельным мастер-артом только прозрачные живые эффекты, не повторяя непрозрачную воду и траву.
static func draw_first_location_animations(game: Node2D) -> void:
	if game.current_location!="overworld": return
	var ticks: int=Time.get_ticks_msec(); var season: String=game.WorldEventSystem.season(game.day)
	if season!="winter":
		for index in AMBIENT_WATER_POINTS.size():
			var point:Vector2=AMBIENT_WATER_POINTS[index]
			if not game.VillageLayoutSystem.is_water(point,2.0): continue
			var bubble_frame: int=posmod(int(ticks/int(EFFECT_PROFILES.bubbles.frame_ms))+index*2,int(EFFECT_PROFILES.bubbles.frames))
			draw_effect(game,"bubbles",point,bubble_frame,Color(0.88,0.98,1.0,0.72))
	var fish_frame: int=posmod(int(ticks/int(EFFECT_PROFILES.fish.frame_ms)),int(EFFECT_PROFILES.fish.frames))
	draw_effect(game,"fish",game.pond_position,fish_frame,Color(1,1,1,0.86))
	if game.state.fishing.phase in [game.FishingSystem.PHASE_WAITING,game.FishingSystem.PHASE_BITE]:
		draw_bobber(game,ticks)
	if game.state.fishing.phase==game.FishingSystem.PHASE_BITE:
		var splash_frame: int=posmod(int(ticks/int(EFFECT_PROFILES.splash.frame_ms)),int(EFFECT_PROFILES.splash.frames))
		draw_effect(game,"splash",game.FishingSystem.bobber_position(game),splash_frame)


## Рисует натянутую леску, поплавок и спокойную рябь в фактической точке заброса.
static func draw_bobber(game: Node2D, ticks: int) -> void:
	var position:Vector2=game.FishingSystem.bobber_position(game); var pulse:=sin(ticks/180.0)*2.0
	game.draw_line(game.player+Vector2(0,-18),position,Color(0.93,0.90,0.72,0.82),1.2)
	game.draw_arc(position,12.0+pulse,0.0,TAU,24,Color(0.72,0.91,1.0,0.48),1.2)
	game.draw_circle(position+Vector2(0,-3),5.0,Color("f4e4b3")); game.draw_circle(position+Vector2(0,-6),3.0,Color("d9544d"))


## Готовит отдельный контрольный кадр пруда с включённой сеткой F10 и причинами непроходимости.
static func configure_navigation_preview(game: Node) -> void:
	game.language_screen=false; game.title_screen=false; game.current_location="overworld"; game.player=Vector2(1420,760); game.tutorial_visible=false; game.set_meta("capture_first_level_clean",true)
	var debug_state:Dictionary=game.DebugOverlaySystem.default_state(); debug_state.grid_size=CELL_SIZE; debug_state.opacity=0.30; debug_state.hitboxes=true; game.set_meta(game.DebugOverlaySystem.META_KEY,debug_state); game.DebugOverlaySystem.refresh_grid(game)
	game.set_meta("capture_water_navigation_frames",8)


## Сохраняет контрольный кадр воды после нескольких полноценно отрисованных кадров и завершает preview-процесс.
static func update_preview_capture(game: Node) -> bool:
	if not game.has_meta("capture_water_navigation_frames"): return false
	var frames_left:=int(game.get_meta("capture_water_navigation_frames"))-1; game.set_meta("capture_water_navigation_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_water_navigation_frames"); var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.push_error("Renderer не предоставил кадр воды"); game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/water_navigation_ingame_preview.png"); var error:=image.save_png(output)
	if error!=OK: game.push_error("Не удалось сохранить предпросмотр воды: %s"%error)
	game.get_tree().quit(); return true
