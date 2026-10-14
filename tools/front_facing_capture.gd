extends SceneTree

const House := preload("res://scripts/presentation/house_furniture_visual_system.gd")
const Stations := preload("res://scripts/presentation/basement_visual_system.gd")
const LABELS := ["Стол", "Стул", "Шкаф", "Сундук", "Исследовательский стол", "Верстак", "Гончарный круг", "Печь"]
var viewport: SubViewport
var canvas: Node2D

## Снимает нативную галерею прежнего направления вверх без чтения пользовательских сохранений.
func _initialize() -> void:
	_start.call_deferred()

## Рисует контрольный лист через настоящие владельцы спрайтов и сохраняет прозрачность средствами движка.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	canvas=Node2D.new(); viewport.add_child(canvas); canvas.draw.connect(_draw_gallery)
	for _frame in 4: await process_frame; canvas.queue_redraw(); RenderingServer.force_draw()
	var phase:=OS.get_environment("FARM_FACING_CAPTURE_PHASE"); if phase.is_empty(): phase="before"
	var folder:="res://docs/reports/front-facing-2026-10-14/"
	DirAccess.make_dir_recursive_absolute(folder)
	if viewport.get_texture().get_image().save_png(folder+phase+".png")!=OK: push_error("Не удалось сохранить галерею ракурсов"); quit(1); return
	print("FRONT FACING CAPTURE: "+phase); quit()

## Сравнивает видимые рабочие поверхности восьми предметов при прежнем сохранённом направлении вверх.
func _draw_gallery() -> void:
	canvas.draw_rect(Rect2(0,0,1152,648),Color("f4e5c6"))
	var font:=ThemeDB.fallback_font
	canvas.draw_string(font,Vector2(32,42),"Мебель и станки · прежний поворот вверх",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("4b3526"))
	for index in 8:
		var origin:=Vector2(24+(index%4)*282,72+(index/4)*276)
		canvas.draw_style_box(_panel(),Rect2(origin,Vector2(258,248)))
		canvas.draw_string(font,origin+Vector2(12,27),LABELS[index],HORIZONTAL_ALIGNMENT_LEFT,238,17,Color("4b3526"))
		var position:=origin+Vector2(129,216)
		if index<4: House.draw(canvas,["rustic_table","wooden_chair","wooden_wardrobe","home_chest"][index],position,Vector2(192,168),2)
		else:
			var texture:=Stations.texture(["study","workbench","pottery","cauldron"][index-4],3,2)
			var size:=texture.get_size(); size*=minf(216/size.x,168/size.y)
			canvas.draw_texture_rect(texture,Rect2(position-Vector2(size.x/2,size.y),size),false)

## Возвращает простую рамку контрольного листа без стилизации игровых ресурсов.
func _panel() -> StyleBoxFlat:
	var value:=StyleBoxFlat.new(); value.bg_color=Color("e8d5af"); value.border_color=Color("b79b72"); value.set_border_width_all(1); value.set_corner_radius_all(10); return value
