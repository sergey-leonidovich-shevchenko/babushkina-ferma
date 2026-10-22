extends Node2D

var first:Texture2D
var second:Texture2D
var caption:=""
var observing:=false
var frames:=[]

## Показывает реальные GPU-target рядом, не изменяя их пиксели и не добавляя новую графику в игру.
func _draw()->void:
	if observing:frames.append(Engine.get_process_frames())
	draw_rect(Rect2(0,0,1152,648),Color("f3eddc"))
	var font:=ThemeDB.fallback_font
	draw_string(font,Vector2(32,45),"VFOLIAGE-002 | local UV, linear sampling and fixed root",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("483e30"))
	draw_string(font,Vector2(32,80),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("5c5549"))
	draw_string(font,Vector2(90,130),"Atlas with colored neighbors",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("483e30"))
	draw_string(font,Vector2(650,130),"Isolated source reference",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("483e30"))
	if first!=null:draw_texture_rect(first,Rect2(90,150,384,384),false)
	if second!=null:draw_texture_rect(second,Rect2(650,150,384,384),false)
	for x in [90,650]:
		var anchor:=Vector2(x,150)+Vector2(80.25,138.25)*1.2*2
		draw_line(anchor-Vector2(7,0),anchor+Vector2(7,0),Color.CYAN,2);draw_line(anchor-Vector2(0,7),anchor+Vector2(0,7),Color.CYAN,2)
	draw_string(font,Vector2(32,585),"Cyan: fixed source root. 192x192 GPU targets, 120% projection. No wind clock.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("5c5549"))
