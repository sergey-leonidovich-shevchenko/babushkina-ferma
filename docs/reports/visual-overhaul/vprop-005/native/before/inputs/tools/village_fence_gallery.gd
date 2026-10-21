extends Node2D
var game:Node
var background:="light"
var observe:=false
var records:=[]

## Показывает все маски и открытые проёмы на четырёх настоящих GPU-фонах.
func _draw()->void:
	var f=load("res://scripts/presentation/village_fence_visual.gd")
	var color:Color={"light":Color("e9dfc3"),"dark":Color("202522"),"grass":Color("789355"),"evening":Color("514955")}[background]
	draw_rect(Rect2(0,0,1280,720),color)
	draw_string(ThemeDB.fallback_font,Vector2(24,32),"VPROP-005 | 16 connections; closed / open gates",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE if background in ["dark","evening"] else Color("302517"))
	for mask in 16:
		var p:=Vector2(80+(mask%8)*136,116+(mask/8)*120)
		f.draw_section(self,p,mask)
		draw_string(ThemeDB.fallback_font,p+Vector2(-16,38),str(mask),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE if background in ["dark","evening"] else Color("302517"))
	for orientation in [0,1]:
		for opened in [false,true]:
			var p:=Vector2(160+int(opened)*310,406+orientation*130)
			f.draw_gate(self,p,orientation,opened)
			draw_string(ThemeDB.fallback_font,p+Vector2(-40,40),str(orientation)+(" open" if opened else " closed"),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE if background in ["dark","evening"] else Color("302517"))
	if observe:records.append({"background":background,"masks":16,"gates":4})
