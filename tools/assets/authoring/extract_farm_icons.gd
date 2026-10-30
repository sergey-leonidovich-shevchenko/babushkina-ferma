extends SceneTree

## Нарезает восемь предметов по регулярным ячейкам и сохраняет исходную прозрачность в самостоятельных иконках.
func _initialize() -> void:
	var source:=Image.load_from_file(ProjectSettings.globalize_path("res://docs/concepts/farmyard-2026-10/v1/sources/icons.png"))
	var kinds := ["animal_feed","truffle","mayonnaise","pancakes","porridge","truffle_soup","yarn","cloth"]
	for index in kinds.size():
		var tile:=source.get_region(Rect2i((index%4)*source.get_width()/4,(index/4)*source.get_height()/2,source.get_width()/4,source.get_height()/2))
		var sprite:=tile.get_region(tile.get_used_rect())
		var scale:=128.0/float(maxi(sprite.get_width(),sprite.get_height()))
		sprite.resize(roundi(sprite.get_width()*scale),roundi(sprite.get_height()*scale),Image.INTERPOLATE_LANCZOS)
		var canvas:=Image.create(160,160,false,Image.FORMAT_RGBA8)
		canvas.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),(canvas.get_size()-sprite.get_size())/2)
		assert(canvas.save_png(ProjectSettings.globalize_path("res://assets/game/items/catalog/"+kinds[index]+".png"))==OK)
	print("FARM ICONS: eight independent RGBA item sprites")
	quit()
