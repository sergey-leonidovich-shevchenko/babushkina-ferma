extends "res://wiki/scripts/export_catalog.gd"

const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const Workshop := preload("res://scripts/systems/workshop_data.gd")
var _pixel_info:Dictionary={}

## Создаёт самостоятельный снимок всего каталога для дизайн-аудита без игровых сохранений.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","MoonValleyArtReview")
	output="res://docs/concepts/visual-polish-2026-10-13/v1/current/"
	_export.call_deferred()

## Выгружает каждый предмет, его настоящий источник, окраску и проверяемые признаки для ручной ревизии.
func _export() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+"sprites"))
	game=Game.new(); game._ready(); game.LocaleSystem.current="ru"
	var by_image:Dictionary={}; var by_family:Dictionary={}; var providers:Dictionary={}
	for kind in game.InventorySystem.ITEM_DATA:
		var visual:Dictionary=game.VisualAssetSystem.item_visual(kind); var texture:Texture2D=visual.texture
		if texture==null: failed=true; push_error("Нет иконки: "+kind); continue
		var frame_value:=still(texture); var info:=pixel_info(texture); var base:Texture2D=game.item_texture(kind)
		var family:=family_for(kind,visual); var flags:Array=[]
		if info.empty: flags.append("empty"); failed=true
		if texture is ImageTexture and texture.resource_path.is_empty(): flags.append("procedural")
		if visual.tint!=Color.WHITE: flags.append("tinted")
		if texture!=base: flags.append("old-wiki-source-difference")
		if info.coverage<0.35: flags.append("small-silhouette")
		var record:Dictionary={"id":kind,"name":item_name(kind),"category":game.InventorySystem.category(kind),"provider":visual.provider,"family":family,"source":source_info(texture),"icon":frame_value,"tint":visual.tint.to_html(false),"pixels":info,"flags":flags,"decision":"review","priority":"P1" if "procedural" in flags else "P2"}
		entries.append(record)
		if not by_image.has(frame_value.image): by_image[frame_value.image]=[]
		by_image[frame_value.image].append(kind)
		if not by_family.has(family): by_family[family]=[]
		by_family[family].append(kind); providers[visual.provider]=int(providers.get(visual.provider,0))+1
	for record in entries:
		if by_image[record.icon.image].size()>1: record.flags.append("shared-image")
		if by_family[record.family].size()>1 and record.provider in ["alchemy","workshop"]: record.flags.append("shared-shape")
	var stats:Dictionary={"items":entries.size(),"images":images.size(),"providers":providers,"flags":{}}
	for record in entries:
		for flag in record.flags: stats.flags[flag]=int(stats.flags.get(flag,0))+1
	var file:=FileAccess.open(output+"audit.json",FileAccess.WRITE)
	if file==null: failed=true; push_error("Не удалось сохранить ревизию")
	else: file.store_string(JSON.stringify({"schema":1,"version":FileAccess.get_file_as_string("res://VERSION").strip_edges(),"stats":stats,"entries":entries,"images":images,"families":by_family},"\t")); file.close()
	game.free(); print("ART AUDIT: "+JSON.stringify(stats)); quit(1 if failed else 0)

## Возвращает проверяемый файл или область атласа, отделяя их от процедурного изображения.
func source_info(texture: Texture2D) -> Dictionary:
	if texture is AtlasTexture:
		var area:Rect2=texture.region
		return {"type":"atlas","path":texture.resource_path,"atlas":texture.atlas.resource_path,"region":[area.position.x,area.position.y,area.size.x,area.size.y]}
	return {"type":"generated-vector" if texture is ImageTexture and texture.resource_path.is_empty() else "raster","path":texture.resource_path}

## Измеряет прозрачное поле и непустой силуэт один раз для каждой текстуры, не меняя пиксели.
func pixel_info(texture: Texture2D) -> Dictionary:
	var key:=str(texture.get_instance_id())
	if not _pixel_info.has(key):
		var pixels:=texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		var used:=pixels.get_used_rect(); var size:=pixels.get_size()
		_pixel_info[key]={"width":size.x,"height":size.y,"used":[used.position.x,used.position.y,used.size.x,used.size.y],"coverage":float(used.size.x*used.size.y)/maxi(1,size.x*size.y),"empty":used.size==Vector2i.ZERO}
	return _pixel_info[key]

## Группирует повторяемую форму для очереди перерисовки, не объявляя переиспользование само по себе дефектом.
func family_for(kind: String, visual: Dictionary) -> String:
	if visual.provider=="workshop": return "workshop-"+String(Workshop.ITEMS[kind].group)
	if visual.provider=="alchemy":
		if Herbs.is_herb(kind): return "herb-"+("flower" if Herbs.HERBS[kind].shape=="flower" else "leaves")
		if kind.ends_with("_dried") or kind=="herb_pulp": return "herb-dried"
		if kind.ends_with("_powder") or kind=="mineral_base": return "herb-powder"
		if kind in ["herb_solvent","herb_oil"]: return "alchemy-carrier"
		if visual.texture is ImageTexture and visual.texture.resource_path.is_empty(): return "alchemy-vial"
		return "alchemy-native-"+kind
	return String(visual.provider)+"-"+kind
