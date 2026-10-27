extends SceneTree

const Game := preload("res://scripts/game.gd")
const FOLDER := "res://assets/game/items/ui/"
const SMALL := 64
const LARGE := 160
const COLUMNS := 16

## Подготавливает два экранных размера из настоящих иконок без изменения исходных ресурсов и окраски.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Item-UI-Builder")
	var game:=Game.new(); game._ready()
	DirAccess.make_dir_recursive_absolute(FOLDER+"preview/")
	var kinds:Array=game.InventorySystem.ITEM_DATA.keys(); kinds.sort()
	var atlas:=Image.create(SMALL*COLUMNS,SMALL*ceili(kinds.size()/float(COLUMNS)),false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var entries:={}; var source_pixels:=0
	for index in kinds.size():
		var kind:String=kinds[index]; var visual:Dictionary=game.VisualAssetSystem.item_visual(kind)
		var source:Image=visual.texture.get_image(); if source.is_compressed(): source.decompress()
		var bounds:Rect2i=source.get_used_rect()
		if not bounds.has_area(): push_error("Пустая иконка "+kind); game.free(); quit(1); return
		var offset:=Vector2i((index%COLUMNS)*SMALL,(index/COLUMNS)*SMALL)
		atlas.blit_rect(fitted(source,bounds,SMALL,3),Rect2i(0,0,SMALL,SMALL),offset)
		if fitted(source,bounds,LARGE,8).save_png(FOLDER+"preview/"+kind+".png")!=OK: push_error("Не удалось сохранить "+kind)
		var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(source.save_png_to_buffer())
		entries[kind]={"cell":[offset.x,offset.y],"provider":visual.provider,"path":visual.texture.resource_path,"tint":visual.tint.to_html(false),"sourceHash":hash.finish().hex_encode()}
		source_pixels+=source.get_width()*source.get_height()
	if atlas.save_png(FOLDER+"thumbnails.png")!=OK: push_error("Не удалось сохранить атлас")
	var file:=FileAccess.open(FOLDER+"catalog.json",FileAccess.WRITE)
	var data:={"schema":1,"small":SMALL,"large":LARGE,"columns":COLUMNS,"entries":entries}
	file.store_string(JSON.stringify(data,"\t")); file.close()
	file=FileAccess.open(FOLDER+"catalog.gd",FileAccess.WRITE); file.store_string("extends RefCounted\n\n## Автоматический индекс двух экранных размеров; пересоздаётся tools/assets/authoring/build_item_ui_textures.gd.\nconst DATA := "+JSON.stringify(data,"\t")+"\n"); file.close()
	print("ITEM UI TEXTURES: %d items; %dx%d thumbnail atlas; %dpx previews"%[kinds.size(),atlas.get_width(),atlas.get_height(),LARGE])
	game.free(); quit()

## Вписывает целый непустой силуэт с прозрачным безопасным краем и сохранением пропорций.
func fitted(source: Image, bounds: Rect2i, size: int, padding: int) -> Image:
	return preload("res://tools/item_ui_fitter.gd").fitted(source,bounds,size,padding)
