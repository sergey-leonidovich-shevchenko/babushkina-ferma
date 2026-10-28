extends SceneTree

const Game := preload("res://scripts/game.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const Bounds := preload("res://scripts/systems/wildlife_visual_system.gd")
const Picker := preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const MAINTENANCE := "res://scripts/systems/runtime_maintenance_system.gd"
var game: Node
var outputs: Array[WeakRef] = []
var cleanup_times: Array[int] = []

## Измеряет удержание временных ресурсов на одинаковой синтетической нагрузке до и после исправления.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Runtime-Cleanup-Review")
	_run.call_deferred()

## Сохраняет движковые счётчики и объём кешей, не называя ускоренную нагрузку длительной игровой сессией.
func _run() -> void:
	game=Game.new(); game._ready(); game.title_screen=false; game.language_screen=false
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION
	var phase := "after" if FileAccess.file_exists(MAINTENANCE) else "before"
	var report := {"phase":phase,"protocol":"synthetic resource churn, headless; not real-time soak or FPS measurement","samples":[]}
	report.samples.append(snapshot(0))
	for batch in 8:
		churn(batch,250)
		if phase=="after":
			var maintenance=load(MAINTENANCE); maintenance.request(game)
			while maintenance.busy(game):
				var started := Time.get_ticks_usec(); maintenance.update(game)
				cleanup_times.append(Time.get_ticks_usec()-started)
				await process_frame
		await process_frame
		report.samples.append(snapshot((batch+1)*250))
	var live := 0
	for reference in outputs:
		if reference.get_ref()!=null: live+=1
	report.live_temporary_textures=live; report.temporary_textures=outputs.size()
	report.cleanup_usec=cleanup_times
	var folder := "res://docs/reports/runtime-cleanup-2026-10-15/"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("RUNTIME CLEANUP REVIEW: ",phase," temporary textures still retained: ",live,"/",outputs.size())
	game.free(); quit()

## Создаёт и отпускает новые текстуры и запросы, повторяя путь редакторского предпросмотра и шкафа.
func churn(batch: int, count: int) -> void:
	for index in count:
		var source := Image.create(64,64,false,Image.FORMAT_RGBA8)
		source.fill(Color(0.3,0.6,0.8,1)); source.set_pixel(0,0,Color.MAGENTA)
		var owner := ImageTexture.create_from_image(source)
		var result: Texture2D=Matte.clean_texture(owner)
		Bounds.visible_bounds(result,Rect2i(0,0,64,64)); Picker.visible_preview_source(result,Rect2(0,0,64,64))
		outputs.append(weakref(result))
		var state := Cabinet.state(game); state.query="missing_%d_%d"%[batch,index]; Cabinet.items(game)

## Возвращает только компактные числовые данные, чтобы сам измеритель не удерживал игровые ресурсы.
func snapshot(created: int) -> Dictionary:
	return {"created":created,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"matte":Matte._textures.size(),"bounds":Bounds._bounds.size(),"picker":Picker._visible_source_cache.size(),"queries":Cabinet.state(game).cache.size()}
