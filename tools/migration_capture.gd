extends SceneTree

const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Editor := preload("res://scripts/systems/level_editor_asset_catalog_system.gd")
const Store := preload("res://scripts/editor/level_editor_document_store.gd")
const SIDES := ["south","west","east"]
var output:=OS.get_environment("VMIGRATION_OUTPUT")
var case:Dictionary
var rows:Array=[]
var viewport:SubViewport
var gallery:Node2D
var faults:Array=[]

## Запрещает запуск в рабочей игре, повторную запись и обращение к профилю игрока.
func _initialize() -> void:
	var profile:=OS.get_environment("VMIGRATION_PROFILE")
	if ProjectSettings.get_setting("application/config/name")!="VPIPELINE-009 isolated fixture" or output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-009-") or "/" in profile or "\\" in profile:quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Проверяет реальные каталог, метаданные F12 и сериализатор до нативного рисования.
func _start() -> void:
	case=JSON.parse_string(FileAccess.get_file_as_string("res://migration-case.json"))
	var state:={"objects":[],"level_name":"Initial","level_notes":"","next_id":1,"base_location":"migration_fixture","grid":24,"history":[],"future":[],"selected":-1,"selected_ids":[]}
	var stub:=WorldStub.new()
	if not Store.load_draft(stub,state,"res://saved-draft.json"):faults.append("draft did not load")
	stub.free()
	# Это только прототип будущего адаптера; рабочий VisualResourceCatalog не изменяется.
	if case.phase in ["dual","retired"]:
		Resources.editor_profile(Resources.describe("prop.rustic_table").path)
		for side in SIDES:Resources._path_views[case.paths[side]]=Resources.describe("prop.rustic_table",side)
	var missing:=0;var unadapted:=0
	for index in SIDES.size():
		var side:String=SIDES[index];var view:Dictionary=Resources.describe("prop.rustic_table",side)
		var metadata:Dictionary=Editor.metadata(view.path)
		var old:Dictionary=Resources.editor_profile(case.paths[side])
		var object:Dictionary=state.objects[index]
		var present:=ResourceLoader.exists(object.asset_path)
		if not present:missing+=1
		if old.get("visual_resource_id","")!="prop.rustic_table":unadapted+=1
		if metadata.get("visual_resource_id","")!="prop.rustic_table" or Vector2(metadata.collision_size)!=Vector2(view.footprint_size):faults.append("new F12 metadata differs: "+side)
		var texture:=Resources.texture("prop.rustic_table",side)
		rows.append({"side":side,"id":view.id,"path":view.path,"uid":resource_uid(view.path),"old_uid":resource_uid(object.asset_path) if present else "","png_sha256":FileAccess.get_sha256(view.path),"pixels":pair(texture.get_size()),"source":[view.source.position.x,view.source.position.y,view.source.size.x,view.source.size.y],"pivot":pair(view.pivot),"logical_size":pair(view.logical_size),"footprint":pair(view.footprint_size),"rgba_sha256":pixels_sha(texture),"old_path":object.asset_path,"old_exists":present,"old_profile_id":old.get("visual_resource_id",""),"new_profile_id":metadata.get("visual_resource_id","")})
	var document:Dictionary=Store.document(state)
	var expected_missing:=3 if case.phase=="retired" else 0
	var expected_unadapted:=3 if case.phase=="unadapted" else 0
	if missing!=expected_missing or unadapted!=expected_unadapted or bool(document.validation.valid)!=(missing==0):faults.append("negative control or draft validation differs")
	var frames:={}
	if DisplayServer.get_name()!="headless":
		viewport=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport);gallery=Gallery.new();gallery.rows=rows;gallery.objects=state.objects;viewport.add_child(gallery)
		DirAccess.make_dir_recursive_absolute(output)
		for background in ["dark","light"]:
			gallery.background=background;gallery.queue_redraw()
			for frame in 8:await process_frame;RenderingServer.force_draw(false)
			var image:=viewport.get_texture().get_image();var path:=output.path_join(background+".png")
			if image.get_size()!=Vector2i(1152,648) or image.save_png(path)!=OK:faults.append("invalid GPU frame")
			frames[background]=FileAccess.get_sha256(path)
	else:DirAccess.make_dir_recursive_absolute(output)
	var metadata:={"phase":case.phase,"rows":rows,"document":document,"missing_old_paths":missing,"unadapted_old_paths":unadapted,"frames":frames,"framebuffer":[1152,648],"target":"fixed_gpu_subviewport","display_server":DisplayServer.get_name(),"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().string,"profile":OS.get_user_data_dir().get_file(),"source_sha256":FileAccess.get_sha256("res://tools/migration_capture.gd"),"draft_sha256":FileAccess.get_sha256("res://saved-draft.json"),"performance_eligible":false,"prototype_adapter":case.phase in ["dual","retired"],"errors":faults}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t")+"\n")
	if viewport!=null:viewport.free()
	print("MIGRATION FIXTURE: ",case.phase,"; missing=",missing,"; unadapted=",unadapted,"; errors=",faults)
	quit(0 if faults.is_empty() else 2)

## Сохраняет размеры без неявной смены типа координат.
func pair(value:Vector2) -> Array:
	return [value.x,value.y]

## Измеряет настоящий UID импортированного файла, не копируя его новому источнику.
func resource_uid(path:String) -> String:
	var id:=ResourceLoader.get_resource_uid(path)
	return ResourceUID.id_to_text(id) if id>=0 else ""

## Связывает реальную импортированную текстуру с точными RGBA-байтами.
func pixels_sha(texture:Texture2D) -> String:
	var image:=texture.get_image()
	if image.is_compressed():image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
	return hash.finish().hex_encode()

class WorldStub extends Node:
	const WorldSystem := {"NAMES":{}}
	var current_location:="migration_fixture"
	## Не запускает игровой мир при чтении отдельного тестового черновика.
	func sync_background_location() -> void:
		pass

class Gallery extends Node2D:
	var rows:Array=[]
	var objects:Array=[]
	var old_textures:Dictionary={}
	var background:="dark"
	## Рисует тот же стол через каталог и старый F12-путь с настоящей адресной фильтрацией.
	func _draw() -> void:
		var dark:=background=="dark";var ink:=Color("efe5c9") if dark else Color("443728")
		draw_rect(Rect2(0,0,1152,648),Color("1b2529") if dark else Color("efe5ca"))
		draw_string(ThemeDB.fallback_font,Vector2(24,32),"VPIPELINE-009 / rename-only compatibility fixture",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
		for index in rows.size():
			var row:Dictionary=rows[index];var view:Dictionary=Resources.describe(row.id,row.side)
			var point:=Vector2(192+index*384,280)
			var bounds:Vector2=Vector2(view.logical_size)*2
			draw_texture_rect_region(Resources.sampled_texture(row.id,row.side),Resources.destination(view,point,bounds),view.source)
			draw_string(ThemeDB.fallback_font,point+Vector2(-150,30),"Catalog / "+row.side,HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
			var object:Dictionary=objects[index];point.y=560
			if row.old_exists:
				if not old_textures.has(object.asset_path):old_textures[object.asset_path]=load(object.asset_path)
				var texture:Texture2D=old_textures[object.asset_path]
				texture=Resources.sampled_for_path(object.asset_path,texture)
				var size:Vector2=Vector2(object.size)*2
				draw_texture_rect_region(texture,Rect2(point-size*Vector2(0.5,1),size),object.source)
			else:
				draw_line(point-Vector2(64,120),point+Vector2(64,0),Color("db6552"),8)
				draw_line(point+Vector2(64,-120),point-Vector2(64,0),Color("db6552"),8)
			draw_string(ThemeDB.fallback_font,point+Vector2(-150,30),"Saved F12 path / "+row.side,HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
