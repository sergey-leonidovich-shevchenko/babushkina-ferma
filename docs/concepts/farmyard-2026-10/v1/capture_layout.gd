extends SceneTree

const OUT := "res://docs/concepts/farmyard-2026-10/v1/"
var base: Texture2D

## Запускает подготовку вариантов планировки после создания дерева сцены.
func _initialize() -> void:
	capture.call_deferred()

## Показывает два модульных двора на текущем игровом плане без изменения игровых ресурсов.
func capture() -> void:
	base = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://docs/reports/five-priorities-2026-10-11/village/after-overview.png")))
	var viewport := SubViewport.new(); viewport.size=Vector2i(2400,1200); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var board := Node2D.new(); viewport.add_child(board)
	board.draw.connect(func():
		board.draw_texture(base,Vector2.ZERO)
		board.draw_rect(Rect2(0,0,2400,68),Color("17281f"))
		board.draw_string(ThemeDB.fallback_font,Vector2(32,44),"А · ЮЖНЫЙ ДВОР С ПРОХОДОМ                    Б · КОМПАКТНЫЙ ДВОР У ДОМА",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("f5e2b7"))
		for rect in [Rect2(672,936,168,96),Rect2(672,1056,168,120),Rect2(888,1032,168,144)]:
			board.draw_rect(rect,Color(0.17,0.39,0.24,0.84)); board.draw_rect(rect,Color("dcb66e"),false,5)
		board.draw_rect(Rect2(852,912,24,264),Color("dfbc83"))
		board.draw_string(ThemeDB.fallback_font,Vector2(685,982),"КУРЯТНИК",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("fff0cb"))
		board.draw_string(ThemeDB.fallback_font,Vector2(685,1110),"КОРОВА + ОВЦА",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("fff0cb"))
		board.draw_string(ThemeDB.fallback_font,Vector2(903,1120),"СВИНКА",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("fff0cb"))
		board.draw_line(Vector2(864,936),Vector2(864,864),Color("dfbc83"),20)
		var compact:=Rect2(96,576,192,192)
		board.draw_rect(compact,Color(0.35,0.23,0.18,0.8)); board.draw_rect(compact,Color("dcb66e"),false,5)
		board.draw_string(ThemeDB.fallback_font,Vector2(102,615),"Б · МАЛО МЕСТА",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("fff0cb"))
		board.draw_string(ThemeDB.fallback_font,Vector2(672,907),"А · Выбираю просторный двор: проход и отдельные загоны",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("fff2d7"))
	)
	board.queue_redraw()
	for _frame in 8: await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"layout-options.png"))==OK)
	quit()
