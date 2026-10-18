extends SceneTree

const Game:=preload("res://scripts/game.gd")
const FONT:=preload("res://assets/game/fonts/ui_font.tres")
var output:=OS.get_environment("VSLICE_OUTPUT")
var game:Node
var gallery:Gallery
var viewport:SubViewport
var preview:TextureRect

## Требует настоящий дисплей, новый диагностический каталог и отдельный профиль.
func _initialize() -> void:
	var profile:=OS.get_environment("VSLICE_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or ProjectSettings.localize_path(output).begins_with("res://assets/") or not profile.begins_with("Codex-VPIPELINE-008-") or "/" in profile or "\\" in profile or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	capture.call_deferred()

## Сравнивает полноразмерные исходники, игровые регионы и намеренно урезанные копии при одинаковой камере.
func capture() -> void:
	game=Game.new();game._ready()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1.0
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1152,648)
	viewport=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	gallery=Gallery.new();gallery.prepare(game);viewport.add_child(gallery)
	preview=TextureRect.new();preview.texture=viewport.get_texture();preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;root.add_child(preview);preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(output)
	var metadata:={"engine":Engine.get_version_info().string,"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"target":"fixed_gpu_subviewport","framebuffer":[1152,648],"profile":OS.get_user_data_dir().get_file(),"source_sha256":FileAccess.get_sha256("res://tools/slice_capture.gd"),"performance_eligible":false,"frames":{},"targets":gallery.metadata}
	for background in ["dark","light"]:
		gallery.background=background
		for mode in ["reference","game","clipped"]:
			gallery.mode=mode
			for index in 12:gallery.queue_redraw();await process_frame;RenderingServer.force_draw(false)
			var name:String=mode+"-"+background;var pixels:=viewport.get_texture().get_image()
			if pixels.get_size()!=Vector2i(1152,648) or pixels.save_png(output+"/"+name+".png")!=OK:
				print("SLICE CAPTURE REJECTED: ",name," ",pixels.get_size());cleanup();quit(3);return
			metadata.frames[name]=FileAccess.get_sha256(output+"/"+name+".png")
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"  ")+"\n")
	cleanup();print("SLICE CAPTURE: ",output);quit()

## Освобождает диагностическую сцену также при отказе, не оставляя отдельный игровой узел вне дерева.
func cleanup() -> void:
	if is_instance_valid(game):game.free()
	if is_instance_valid(preview):preview.free()
	if is_instance_valid(viewport):viewport.free()

class Gallery extends Node2D:
	var mode:="game"
	var background:="dark"
	var cases:Array=[]
	var metadata:Array=[]

	## Использует настоящие выбранные предметы, контактные позы трёх видов оружия и ячейку взрослого подсолнуха.
	func prepare(game:Node) -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var visual:Dictionary=game.VisualAssetSystem.item_draw_visual("sunflower",160)
		add("ui/sunflower/160",visual.texture,Rect2(Vector2.ZERO,visual.texture.get_size()),visual.texture.get_size()*0.5,1.0,Rect2(0,36,160,124))
		visual=game.VisualAssetSystem.item_draw_visual("sword",160)
		add("ui/sword/160",visual.texture,Rect2(Vector2.ZERO,visual.texture.get_size()),visual.texture.get_size()*0.5,1.0,Rect2(0,28,160,132))
		var combat:=preload("res://scripts/systems/hero_combat_visual_system.gd")
		for kind in ["bow","blade","spear"]:
			var pose:Dictionary=combat.pose(kind,Vector2.RIGHT,0.68)
			var source:Rect2=pose.source;var cut:=source
			cut.size.x-=14 if kind=="bow" else 45
			add("characters/hero/"+kind+"/east/2",pose.texture,source,pose.pivot,pose.scale*2.0,cut)
		var farm:=preload("res://scripts/systems/farm_visual_system.gd")
		var source:Rect2=farm.crop_source(4,"sunflower","spring")
		var cut:=source;cut.position.y+=18;cut.size.y-=18
		add("crops/sunflower/spring/4",farm.crop_texture("sunflower"),source,Vector2(32,64),1.5,cut)

	## Готовит независимый целый кадр тем же фильтром для сравнения с выборкой региона движком.
	func add(id:String,texture:Texture2D,source:Rect2,pivot:Vector2,scale_value:float,cut:Rect2) -> void:
		var pixels:=texture.get_image()
		if pixels.is_compressed():pixels.decompress()
		pixels.convert(Image.FORMAT_RGBA8)
		var reference:Texture2D=ImageTexture.create_from_image(pixels.get_region(Rect2i(source)))
		if texture is CanvasTexture:
			var wrapper:=CanvasTexture.new();wrapper.diffuse_texture=reference;wrapper.texture_filter=texture.texture_filter;wrapper.texture_repeat=texture.texture_repeat;reference=wrapper
		var index:=cases.size();var ground:=Vector2(192+(index%3)*384,300+(index/3)*300)
		if id.begins_with("ui/"):ground.y-=80
		cases.append({"id":id,"texture":texture,"source":source,"pivot":pivot,"scale":scale_value,"cut":cut,"reference":reference,"ground":ground})
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(pixels.get_data())
		metadata.append({"id":id,"rgba_sha256":hash.finish().hex_encode(),"source":[source.position.x,source.position.y,source.size.x,source.size.y],"cut":[cut.position.x,cut.position.y,cut.size.x,cut.size.y],"pivot":[pivot.x,pivot.y],"scale":scale_value,"roi":[index%3*384,65+index/3*300,384,270]})

	## Сохраняет рамку и точку опоры даже у испорченного контроля: меняются только действительно потерянные пиксели.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color("19232b") if background=="dark" else Color("f1ead8"))
		var ink:=Color("fff3d6") if background=="dark" else Color("253137")
		draw_string(FONT,Vector2(24,32),"VPIPELINE-008 / "+mode+" / "+background,HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
		for value in cases:
			var full:=Rect2(value.ground-Vector2(value.pivot)*value.scale,Rect2(value.source).size*value.scale)
			if mode=="reference":draw_texture_rect(value.reference,full,false)
			else:
				var source:Rect2=value.cut if mode=="clipped" else value.source
				var pivot:Vector2=Vector2(value.pivot)-(source.position-Rect2(value.source).position)
				draw_texture_rect_region(value.texture,Rect2(value.ground-pivot*value.scale,source.size*value.scale),source)
			draw_rect(full.grow(2),Color("7faf82"),false,1)
			draw_line(value.ground-Vector2(6,0),value.ground+Vector2(6,0),Color("e3b95e"),1)
			draw_line(value.ground-Vector2(0,6),value.ground+Vector2(0,6),Color("e3b95e"),1)
			draw_string(FONT,Vector2(value.ground.x-165,full.end.y+25),value.id,HORIZONTAL_ALIGNMENT_LEFT,360,14,ink)
