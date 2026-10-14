extends SceneTree

const FOLDER:="res://docs/concepts/depth-guardian-2026-10-14/v1/"
var viewport:SubViewport
var canvas:Node2D
var mode:=""
var images:Dictionary={}

## Готовит реальные прозрачные мастера к просмотру на светлом фоне без изменения исходных PNG.
func _initialize() -> void:
	_start.call_deferred()

## Сохраняет два полноразмерных листа и сравнение вариантов, не включая их в игровые ресурсы.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	viewport=SubViewport.new(); viewport.size=Vector2i(1600,1120); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	canvas=Node2D.new(); viewport.add_child(canvas); canvas.draw.connect(_draw)
	for key in ["a","b"]: images[key]=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(FOLDER+"sources/"+key+"-board.png")))
	for key in ["a","b","comparison"]:
		mode=key; viewport.size=Vector2i(1600,700) if key=="comparison" else Vector2i(1600,1120)
		for _frame in 3: canvas.queue_redraw(); await process_frame; RenderingServer.force_draw()
		if viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(FOLDER+(key if key=="comparison" else key+"-review")+".png"))!=OK: push_error("Не сохранён лист хранителя "+key)
	print("GUARDIAN CONCEPTS: PASS"); quit()

## Показывает полные фигуры с подписями вариантов, сохраняя пропорции и настоящую прозрачность.
func _draw() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,viewport.size),Color("f4e9d2"))
	var font:=ThemeDB.fallback_font
	if mode=="comparison":
		for index in 2:
			var key:="a" if index==0 else "b"; var x:=16+index*800
			canvas.draw_string(font,Vector2(x+12,46),("A · Кристальный рыцарь" if index==0 else "B · Каменный голем"),HORIZONTAL_ALIGNMENT_LEFT,768,28,Color("463c2b"))
			canvas.draw_texture_rect(images[key],Rect2(x,78,768,512),false)
		canvas.draw_string(font,Vector2(28,654),"Варианты внешности. После выбора — отдельные кадры ходьбы, атаки, ранения и поражения.",HORIZONTAL_ALIGNMENT_LEFT,1544,22,Color("6f6653"))
	else:
		canvas.draw_string(font,Vector2(32,46),"A · Кристальный рыцарь" if mode=="a" else "B · Каменный голем",HORIZONTAL_ALIGNMENT_LEFT,1536,28,Color("463c2b"))
		canvas.draw_texture_rect(images[mode],Rect2(32,72,1536,1024),false)
