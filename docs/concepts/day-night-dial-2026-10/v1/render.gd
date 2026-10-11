extends SceneTree

const OUT := "res://docs/concepts/day-night-dial-2026-10/v1/"

class DialBoard extends Node2D:
	var textures: Dictionary = {}
	var mode := "board"
	var asset := ""
	var phase := 0.0
	var style := "wood"
	var dimension := 256.0

	## Рисует макет из исходных прозрачных слоёв без изменения игровых ресурсов.
	func _draw() -> void:
		if mode=="asset":
			draw_texture_rect(textures[asset],Rect2(0,0,256,256),false)
			return
		if mode=="dial":
			dial(Vector2(dimension/2,dimension/2),dimension,style,phase)
			return
		draw_rect(Rect2(0,0,1280,920),Color("14251f"))
		label(Vector2(48,58),"Лунная долина · небесный круг",28,Color("e8ecd7"))
		label(Vector2(48,88),"Рамка и долина стоят на месте. Вращается только небо с солнцем и луной.",17,Color("a7b99d"))
		label(Vector2(48,135),"Дерево и латунь",21,Color("e5c58b"))
		label(Vector2(48,493),"Камень и латунь",21,Color("c8d5d1"))
		for row in 2:
			for column in 3:
				var center := Vector2(214+column*352,300+row*355)
				dial(center,300,"wood" if row==0 else "stone",[-PI/3,0.0,PI][column])
				label(center+Vector2(-50,178),["Утро","День","Ночь"][column],17,Color("a7b99d"))
		label(Vector2(48,865),"В HUD: 96 px",17,Color("a7b99d"))
		dial(Vector2(255,864),96,"wood",0.0)
		dial(Vector2(370,864),80,"stone",PI)
		label(Vector2(450,872),"Без цифрового времени · один непрерывный оборот за игровые сутки",16,Color("a7b99d"))

	## Вращает только небесный диск; непрозрачные холмы скрывают заходящее светило.
	func dial(center: Vector2, size: float, frame: String, angle: float) -> void:
		var rect := Rect2(-Vector2.ONE*size/2,Vector2.ONE*size)
		draw_set_transform(center,angle)
		draw_texture_rect(textures["sky-rotor"],rect,false)
		draw_set_transform(center)
		var daylight := (cos(angle)+1.0)/2.0
		var light := Color("6b7fa6").lerp(Color.WHITE,daylight)
		draw_texture_rect(textures.landscape,rect,false,light)
		draw_texture_rect(textures["frame-"+frame],rect,false)
		draw_set_transform(Vector2.ZERO)

	## Пишет подписи макета единым читаемым шрифтом.
	func label(at: Vector2, text: String, size: int, color: Color) -> void:
		draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

## Начинает захват после создания корневого окна движка.
func _initialize() -> void:
	capture.call_deferred()

## Загружает четыре исходных PNG и снимает прозрачные предпросмотры и варианты.
func capture() -> void:
	var textures := {}
	for asset in ["sky-rotor","frame-wood","frame-stone","landscape"]:
		var source := Image.load_from_file(ProjectSettings.globalize_path(OUT+"assets/"+asset+".png"))
		assert(source!=null and not source.is_empty(),"Missing original art: "+asset)
		textures[asset]=ImageTexture.create_from_image(source)
		await shot(textures,"asset",asset,256,0.0,"wood","preview/"+asset+"-256.png")
	await shot(textures,"board","",256,0.0,"wood","comparison.png")
	for frame in ["wood","stone"]:
		for index in 4:
			await shot(textures,"dial","",512,[-PI/2,0.0,PI/2,PI][index],frame,"preview/"+frame+"-"+["dawn","day","dusk","night"][index]+".png")
	quit()

## Сохраняет результат настоящей отрисовки с линейной фильтрацией и исходной альфой.
func shot(textures: Dictionary, mode: String, asset: String, size: int, phase: float, style: String, name: String) -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,920) if mode=="board" else Vector2i(size,size)
	viewport.transparent_bg=mode!="board"; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := DialBoard.new(); board.textures=textures; board.mode=mode; board.asset=asset
	board.phase=phase; board.style=style; board.dimension=size; board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(board); board.queue_redraw()
	for _frame in 4: await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name))
	assert(result==OK,"Cannot write preview: "+name)
	print("DIAL PREVIEW: ",name)
	viewport.queue_free(); await process_frame
