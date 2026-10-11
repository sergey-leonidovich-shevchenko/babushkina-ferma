extends SceneTree

const OUT := "res://docs/concepts/first-location-2026-10/river-v4/"

## Нарезает прозрачные детали по видимому контуру, сохраняя исходный альфа-канал и защитное поле.
func _initialize() -> void:
	var metadata := {}
	var definitions := {"bench":["bench.png",0,1],"lilies":["lilies.png",0,1],"railing_post":["railing-atlas.png",0,2],"railing_beam":["railing-atlas.png",1,2]}
	for id in definitions:
		var definition: Array = definitions[id]
		var source := Image.load_from_file(ProjectSettings.globalize_path(OUT+"source/"+definition[0]))
		var x0 := int(source.get_width()*definition[1]/definition[2])
		var x1 := int(source.get_width()*(definition[1]+1)/definition[2])
		var cell := source.get_region(Rect2i(x0,0,x1-x0,source.get_height()))
		var first := Vector2i(cell.get_width(),cell.get_height())
		var last := Vector2i(-1,-1)
		for y in cell.get_height():
			for x in cell.get_width():
				if cell.get_pixel(x,y).a>=0.10:
					first.x=mini(first.x,x); first.y=mini(first.y,y)
					last.x=maxi(last.x,x); last.y=maxi(last.y,y)
		assert(last.x>=first.x,"Пустой спрайт: "+id)
		var position := Vector2i(maxi(0,first.x-12),maxi(0,first.y-12))
		var end := Vector2i(mini(cell.get_width(),last.x+13),mini(cell.get_height(),last.y+13))
		var crop := Rect2i(position,end-position)
		var sprite := cell.get_region(crop)
		var error := sprite.save_png(ProjectSettings.globalize_path(OUT+"sprites/"+id+".png"))
		metadata[id]={"file":"sprites/"+id+".png","source":"source/"+definition[0],"cell":[x0,0,x1-x0,source.get_height()],"crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"size":[sprite.get_width(),sprite.get_height()],"alpha":"straight","anchor":"bottom_center"}
		print("SPRITE %s %s: %s"%[id,sprite.get_size(),error])
	var file := FileAccess.open(OUT+"sprites.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t")+"\n")
	quit()
