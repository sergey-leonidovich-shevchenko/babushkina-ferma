extends SceneTree

const OUT := "res://docs/concepts/day-night-dial-2026-10/v2/"
const Clock := preload("res://scripts/presentation/celestial_clock_renderer.gd")
var textures: Array[Texture2D] = []

class LetterboxMask extends Node2D:
	var extent := Vector2.ZERO
	var content := Rect2()

	## Сохраняет поля KEEP при съёмке полного физического окна.
	func _draw() -> void:
		for rect in [Rect2(0,0,extent.x,content.position.y),Rect2(0,content.end.y,extent.x,extent.y-content.end.y),Rect2(0,content.position.y,content.position.x,content.size.y),Rect2(content.end.x,content.position.y,extent.x-content.end.x,content.size.y)]:
			if rect.has_area(): draw_rect(rect,Color("0b1512"))

class Dial extends "res://scripts/game.gd":
	## Оставляет контрольный циферблат независимым от загрузки настроек и пользовательского сохранения.
	func _ready() -> void:
		pass

	## Использует реальный игровой рендер часов с настоящими шрифтами и отдельными слоями.
	func _draw() -> void:
		preload("res://scripts/presentation/celestial_clock_renderer.gd").draw(self,Rect2(0,0,128,116))

class ReviewGame extends "res://scripts/game.gd":
	## Не читает пользовательский слот и не применяет настройки во время захвата.
	func _ready() -> void:
		pass

## Начинает съёмку после запуска настоящего графического устройства.
func _initialize() -> void:
	capture.call_deferred()

## Снимает шесть положений орбиты, четыре фазы и три физических формата игрового окна.
func capture() -> void:
	assert(DisplayServer.get_name()!="headless","Native GPU required")
	var board := SubViewport.new(); board.size=Vector2i(1120,456); board.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(board)
	var canvas := Node2D.new(); board.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0,0,1120,456),Color("14251f"))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(24,32),"Лунная долина · игровые часы",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e8ecd7"))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(24,64),"Слева восход, справа закат. Долина и рамка неподвижны.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a7b99d"))
		for index in 6: canvas.draw_string(ThemeDB.fallback_font,Vector2(24+index*180,280),["Рассвет","Утро","Полдень","Закат","Вечер","Ночь"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a7b99d"))
		for index in 4: canvas.draw_string(ThemeDB.fallback_font,Vector2(600,319+index*29),["Новолуние","Растущая","Полная","Убывающая"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a7b99d"))
	)
	for index in 6:
		var dial := Dial.new(); dial.day=15; dial.game_minutes=[360,480,720,1080,1200,1440][index]
		dial.position=Vector2(14+index*180,84); dial.scale=Vector2.ONE*1.3; board.add_child(dial); dial.set_physics_process(false); dial.set_process(false)
	for index in 4:
		var dial := Dial.new(); dial.day=1+index*7; dial.game_minutes=0
		dial.position=Vector2(28+index*138,304); board.add_child(dial); dial.set_physics_process(false); dial.set_process(false)
	canvas.queue_redraw()
	for frame in 8: await RenderingServer.frame_post_draw
	assert(board.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"clock-strip.png"))==OK)
	board.queue_free(); await process_frame
	var game := preload("res://main.tscn").instantiate(); game.set_script(ReviewGame)
	game.world_loot_seed=20261011; game.audio_enabled=false; game.GameBootstrap._initialize_services(game); game.GameBootstrap._initialize_world(game); game.GameBootstrap._initialize_runtime_systems(game)
	root.add_child(game); game.set_physics_process(false); game.set_process(false)
	game.title_screen=false; game.language_screen=false; game.current_location="overworld"; game.player=Vector2(432,672); game.day=15; game.game_minutes=720
	game.state.world.weather_day=15; game.state.world.weather="clear"; game.state.world.estate.event=""; game.FarmLifeSystem.state(game).cutscene=""; game.discovery_current.clear(); game.message=""; game.tutorial_visible=false
	game.update_camera(); game.sync_background_location(); game.get_node("WorldBackground").position=-game.camera_offset; game.settings_state.text_scale=1.2
	var profiles := [{"id":"16x9_ru","size":Vector2i(1152,648),"locale":"ru"},{"id":"16x10_de","size":Vector2i(1280,800),"locale":"de"},{"id":"ultrawide_zh","size":Vector2i(1680,720),"locale":"zh"}]
	root.mode=Window.MODE_WINDOWED
	var masks := CanvasLayer.new(); masks.layer=127; root.add_child(masks)
	var mask := LetterboxMask.new(); masks.add_child(mask)
	for profile in profiles:
		game.LocaleSystem.set_locale(profile.locale,false)
		root.size=profile.size; root.content_scale_size=profile.size; root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var layout: Dictionary = game.UiScaleSystem.viewport_layout(Vector2(profile.size))
		var transform := Transform2D.IDENTITY.scaled(Vector2.ONE*float(layout.scale)); transform.origin=layout.offset; root.canvas_transform=transform
		mask.extent=Vector2(profile.size); mask.content=Rect2(layout.offset,layout.content_size); mask.queue_redraw()
		game.queue_redraw()
		for frame in 12: await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image(); assert(image.get_size()==profile.size)
		assert(image.save_png(ProjectSettings.globalize_path(OUT+profile.id+".png"))==OK)
		print("DIAL CAPTURE: ",profile.id," ",image.get_size())
	quit()
