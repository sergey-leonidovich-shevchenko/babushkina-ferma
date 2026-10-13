extends RefCounted

const Basement := preload("res://scripts/systems/basement_system.gd")
const Controls := preload("res://scripts/systems/basement_input_system.gd")
const Locale := preload("res://scripts/systems/basement_locale.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const Art := preload("res://scripts/presentation/basement_visual_system.gd")
const Room := preload("res://scripts/presentation/basement_room_renderer.gd")

## Рисует самостоятельные лестницы и выбранный настенный чертёж, оставляя остальную мастерскую под свободное размещение.
static func fixtures(game: Node2D) -> void:
	if game.current_location=="cottage_interior": Room.sprite(game,"stairs_down",Rect2(Basement.Data.HOUSE_ENTRY-Vector2(24,80),Vector2(72,72))); return
	if game.current_location!=Basement.Data.LOCATION: return
	Room.sprite(game,"stairs_up",Rect2(168,168,144,216))
	Room.sprite(game,"blueprint",Rect2(432,132,192,132))
	game.draw_circle(Basement.Data.BOARD,18,Color(0.8,0.68,0.4,0.15))

## Делит физические экземпляры на задний и передний проходы по общей нижней опоре относительно героя.
static func objects(game: Node2D, foreground: bool) -> void:
	if game.current_location!=Basement.Data.LOCATION: return
	var entries:Array=Basement.state(game).objects.duplicate()
	entries.sort_custom(func(left,right): return Basement.Layout.rect(left).end.y<Basement.Layout.rect(right).end.y)
	for item in entries:
		var bounds:=Basement.Layout.rect(item)
		if (bounds.end.y>game.player.y)!=foreground: continue
		if not bounds.grow(192).intersects(Rect2(game.camera_offset,Vector2(1152,648))): continue
		draw_station(game,item,item.phase!="ready")

## Показывает отдельный ракурс уровня и собственную кучу, опирая оба изображения на постоянное основание.
static func draw_station(game: Node2D, item: Dictionary, unfinished: bool, alpha: float=1) -> void:
	var bounds:=Basement.Layout.rect(item)
	for layer in 3:
		var points:=PackedVector2Array()
		for index in 24:
			var angle:=TAU*index/24; points.append(Vector2(bounds.get_center().x,bounds.end.y-12)+Vector2(cos(angle)*(bounds.size.x*0.47+layer*3),sin(angle)*(18+layer*2)))
		game.draw_colored_polygon(points,Color(0.09,0.06,0.035,alpha*0.055))
	if not unfinished or item.get("phase","")=="upgrading":
		game.draw_texture_rect(Art.texture(item.kind,int(item.get("level",1)),int(item.direction)),Art.destination(item),false,Color(1,1,1,alpha*(0.5 if unfinished else 1)))
		if not unfinished and alpha==1:
			preload("res://scripts/presentation/kitchen_fx_renderer.gd").draw(game,item,Art.destination(item))
			preload("res://scripts/presentation/artisan_fx_renderer.gd").draw(game,item,Art.destination(item))
	if unfinished:
		game.draw_texture_rect(Art.texture(item.kind,1,int(item.direction),true),Art.destination(item,true),false,Color(1,1,1,alpha))
	var direction:Vector2=Basement.Data.DIRECTIONS[int(item.direction)]; var center:=Basement.Layout.center(Basement.Layout.approach_cell(item))
	game.draw_colored_polygon(PackedVector2Array([center-direction*9,center+direction*9+direction.orthogonal()*7,center+direction*9-direction.orthogonal()*7]),Color(0.91,0.75,0.38,alpha*0.65))

## Накрывает видимый участок единой полной сетки и показывает реальные пересечения предварительного основания.
static func placement(game: Node2D) -> void:
	if game.current_location!=Basement.Data.LOCATION or not bool(Basement.ui(game).placing): return
	var viewport:=Rect2(game.camera_offset,Vector2(1152,648)); var region:=Basement.Data.FLOOR.intersection(viewport)
	var begin:=Basement.Layout.cell(region.position); var end:=Basement.Layout.cell(region.end)
	for x in range(begin.x,end.x+2):
		var px:=Basement.Data.FLOOR.position.x+x*24
		game.draw_line(Vector2(px,region.position.y),Vector2(px,region.end.y),Color(0.6,0.8,0.51,0.22),1)
	for y in range(begin.y,end.y+2):
		var py:=Basement.Data.FLOOR.position.y+y*24
		game.draw_line(Vector2(region.position.x,py),Vector2(region.end.x,py),Color(0.6,0.8,0.51,0.22),1)
	var preview:=Controls.preview(game); var item:Dictionary=preview.object; var size:=Basement.Layout.dimensions(item.kind,item.direction)
	for y in range(item.y,item.y+size.y):
		for x in range(item.x,item.x+size.x):
			var blocked:bool=Basement.Layout.cell_blocked(Basement.state(game).objects,Vector2i(x,y)) or (not preview.geometry.is_empty() and preview.geometry!="basement_occupied")
			var rect:=Rect2(Basement.Layout.center(Vector2i(x,y))-Vector2(12,12),Vector2(24,24))
			game.draw_rect(rect,Color(0.87,0.2,0.16,0.45) if blocked else Color(0.36,0.77,0.37,0.32)); game.draw_rect(rect,Color("df7359") if blocked else Color("b1d788"),false,1)
	draw_station(game,item,false,0.55)

## Рисует прогресс реальной стройки над героем и доступное удержание отдельной сенсорной кнопкой.
static func work_overlay(game: Node2D) -> void:
	if game.current_location!=Basement.Data.LOCATION: return
	var item:=Basement.object(game,int(Basement.ui(game).holding))
	if item.is_empty() or item.phase=="ready": return
	var rect:=Rect2(game.player+Vector2(-40,-90),Vector2(80,7))
	game.draw_rect(rect.grow(2),Color("2c251e")); game.draw_rect(rect,Color("5c5140"))
	game.draw_rect(Rect2(rect.position,Vector2(rect.size.x*float(item.work)/float(item.duration),rect.size.y)),Color("e7c267"))

## Показывает подсказки размещения, причину отказа и чертёж в экранном слое поверх игровой карты.
static func ui(game: Node2D) -> void:
	if game.current_location!=Basement.Data.LOCATION: return
	var value:=Basement.ui(game)
	if bool(value.placing):
		var rect:=Rect2(190,100,772,64); game.draw_rect(rect,Color(0.12,0.16,0.13,0.94))
		game.draw_ui_string(game.UI_FONT,Vector2(208,122),Locale.name_for(game,value.kind),HORIZONTAL_ALIGNMENT_CENTER,736,15,Color("f2ddac"))
		var why:String=Controls.preview(game).reason
		game.draw_ui_string(game.UI_FONT,Vector2(208,146),game.LocaleSystem.ui(why) if not why.is_empty() else game.LocaleSystem.ui("basement_paid"),HORIZONTAL_ALIGNMENT_CENTER,736,12,Color("ee8772") if not why.is_empty() else Color("b7d790"))
		game.draw_rect(Rect2(130,560,892,76),Color(0.12,0.16,0.13,0.94))
		for index in 4:
			var label:String=["Q / LB","R / RB",game.LocaleSystem.ui("basement_place_button"),game.LocaleSystem.ui("basement_cancel_button")][index]
			preload("res://scripts/presentation/basement_blueprint_renderer.gd").button(game,Controls.PLACE_BUTTONS[index],label,false)
		game.draw_ui_string(game.UI_FONT,Vector2(140,622),game.LocaleSystem.ui("basement_place_help"),HORIZONTAL_ALIGNMENT_CENTER,872,11,Color("f2ddac"))
	elif not bool(value.open) and not game.crafting_open and not game.inventory_open:
		var nearest:=Basement.nearest(game)
		if nearest.begins_with("basement_station:"):
			var item:=Basement.object(game,int(nearest.get_slice(":",1)))
			if item.phase!="ready":
				Kit.draw_nine_patch(game,"editor_button_normal",Controls.HOLD)
				game.draw_ui_multiline_string(game.UI_FONT,Controls.HOLD.position+Vector2(8,18),game.LocaleSystem.ui("basement_hold_button"),HORIZONTAL_ALIGNMENT_CENTER,184,30,11,2,Kit.COLORS.ink)
	preload("res://scripts/presentation/basement_blueprint_renderer.gd").draw(game)
