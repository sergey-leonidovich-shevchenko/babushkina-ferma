extends SceneTree

var textures: Array[Texture2D] = []

## Складывает два нативных кадра без изменения их пиксельного размера.
func _initialize() -> void:
	capture.call_deferred()

## Сохраняет сравнение исходного луга и работающего фермерского двора с одинаковой камерой.
func capture() -> void:
	var root_path := "res://docs/concepts/farmyard-2026-10/v1/"
	for name in ["before","after"]:
		textures.append(ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(root_path+name+"-yard.png"))))
	var viewport:=SubViewport.new(); viewport.size=Vector2i(2304,696); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var board:=Node2D.new(); viewport.add_child(board)
	board.draw.connect(func():
		board.draw_rect(Rect2(0,0,2304,696),Color("17281f"))
		for index in 2:
			board.draw_texture(textures[index],Vector2(index*1152,48))
			board.draw_string(ThemeDB.fallback_font,Vector2(index*1152+24,32),"БЫЛО: стартовый луг" if index==0 else "СТАЛО: животные, уход и открытые загоны",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f4e6c2"))
	)
	board.queue_redraw()
	for _frame in 8: await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(root_path+"comparison.png"))==OK)
	quit()
