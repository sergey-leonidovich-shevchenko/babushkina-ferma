extends SceneTree

var canvas:Node2D
var viewport:SubViewport
var entries:Array=[]

## Собирает контактные листы нативных кадров для обзора всех локаций и окон без изменения исходников.
func _initialize() -> void:
	_start.call_deferred()

## Читает готовые снимки и раскладывает их по двенадцать на контрольном листе.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var folder:="/private/tmp/moon-valley-design-audit/"+OS.get_environment("FARM_DESIGN_PHASE")+"/"
	if OS.get_environment("FARM_DESIGN_PHASE").is_empty(): folder="/private/tmp/moon-valley-design-audit/before/"
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,936); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	canvas=Node2D.new(); viewport.add_child(canvas); canvas.draw.connect(_draw_sheet)
	for group in ["world-","ui-"]:
		var paths:Array=[]
		for file in DirAccess.get_files_at(folder):
			if file.begins_with(group) and file.ends_with(".png") and not file.begins_with(group+"sheet-"): paths.append(file)
		paths.sort()
		for start in range(0,paths.size(),12):
			entries=[]
			for index in range(start,mini(start+12,paths.size())): entries.append({"name":paths[index],"texture":ImageTexture.create_from_image(Image.load_from_file(folder+paths[index]))})
			for _frame in 3: canvas.queue_redraw(); await process_frame; RenderingServer.force_draw()
			if viewport.get_texture().get_image().save_png(folder+group+"sheet-"+str(start/12)+".png")!=OK: push_error("Не сохранён контактный лист")
	print("DESIGN AUDIT GALLERY: PASS"); quit()

## Показывает полные кадры с подписями, сохраняя пропорции и все края исходного снимка.
func _draw_sheet() -> void:
	canvas.draw_rect(Rect2(0,0,1152,936),Color("f4e5c6"))
	for index in entries.size():
		var point:=Vector2((index%3)*384,(index/3)*234)
		canvas.draw_string(ThemeDB.fallback_font,point+Vector2(8,14),entries[index].name,HORIZONTAL_ALIGNMENT_LEFT,376,12,Color("463c2b"))
		canvas.draw_texture_rect(entries[index].texture,Rect2(point+Vector2(0,18),Vector2(384,216)),false)
