extends SceneTree

const CONCEPT := "res://docs/concepts/farmyard-2026-10/v1/"
const ROOT := "res://assets/game/farmyard/v1/"

## Нарезает измеренные связные фигуры и готовит самостоятельные спрайты в их игровых размерах.
func _initialize() -> void:
	var regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONCEPT+"regions.json"))
	var catalog := {}; var names := ["cow","pig","hen","sheep"]
	for family in ["animals","props"]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(CONCEPT+"sources/"+family+".png"))
		for index in regions[family].size():
			var b: Array=regions[family][index]
			var kind: String=names[index/6] if family=="animals" else ["coop","barn","trough","water_tub","hay","compost"][index]
			var frame: int = index%6 if family=="animals" else 0
			var sprite := image.get_region(Rect2i(b[0],b[1],b[2],b[3]))
			var factor: float
			if family=="animals":
				factor=float({"cow":86,"pig":50,"hen":32,"sheep":66}[kind])/float(regions.animals[(index/6)*6][2])
			else:
				var target: Vector2=[Vector2(72,80),Vector2(112,104),Vector2(60,40),Vector2(48,40),Vector2(40,40),Vector2(48,48)][index]
				factor=minf(target.x/float(b[2]),target.y/float(b[3]))
			sprite.resize(maxi(1,roundi(b[2]*factor)),maxi(1,roundi(b[3]*factor)),Image.INTERPOLATE_LANCZOS)
			var path := "frames/%s-%d.png"%[kind,frame]
			assert(sprite.save_png(ProjectSettings.globalize_path(ROOT+path))==OK)
			if not catalog.has(kind): catalog[kind]=[]
			catalog[kind].append({"sprite":path,"pivot":[sprite.get_width()/2.0,sprite.get_height()],"size":[sprite.get_width(),sprite.get_height()]})
	FileAccess.open(ROOT+"frames.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"  ")+"\n")
	print("FARM EXTRACTION: 24 livestock poses and six independent props; original alpha retained")
	quit()
