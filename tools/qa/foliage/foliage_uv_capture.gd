extends SceneTree

const UV:=preload("res://scripts/presentation/foliage_uv.gd")
const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
const Source:=preload("res://tests/suites/foliage_root_suite.gd")
const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer:=preload("res://tools/qa/world/render_order_game.gd")
const Quad:=preload("res://tools/qa/foliage/foliage_uv_quad.gd")
const Board:=preload("res://tools/qa/foliage/foliage_uv_board.gd")
var output:=""
var profile:=""
var size:=Vector2i(1152,648)
var game:Node
var first:SubViewport
var second:SubViewport
var reflected:SubViewport
var board:Node2D
var rows:=[]
var errors:=[]
var snapshot_text:=""
var snapshot_sha:=""
var atlases:={}
var isolated:={}
var masks:={}

## Запускает видимые GPU-target только в свежем профиле; не читает пользовательские сохранения.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VFOLIAGE-002-") or "/" in profile or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сравнивает все типы и оба отражения при трёх деформациях, затем проверяет намеренную утечку из соседей.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=true
	game.set_meta(&"camera_reference_zoom",1.2);preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
	root.title="VFOLIAGE-002 | Local UV and roots";root.mode=Window.MODE_WINDOWED;root.size=size;root.show();root.grab_focus()
	first=_viewport();second=_viewport();reflected=_viewport()
	var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer);board=Board.new();layer.add_child(board);board.first=first.get_texture();board.second=second.get_texture()
	_prepare_textures()
	await _settle(1800);root.mode=Window.MODE_WINDOWED;root.size=size;await _settle(1000)
	snapshot_text=JSON.stringify(game.SaveSystem.snapshot(game));snapshot_sha=snapshot_text.sha256_text()
	for kind in Roots.PROFILES:
		for flip in [false,true]:
			for bend in [Vector2.ZERO,Vector2(8,5),Vector2(-8,-5)]:await _case(kind,flip,bend,false)
	for flip in [false,true]:
		await _case("grass",flip,Vector2(8,5),true)
	board.hide();game.observe_draw=false
	for i in 4:game.queue_redraw();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("ordinary-game.png"))
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-002","profile":profile,"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"performance_eligible":false,"hardware_input_accepted":false,"snapshot_text":snapshot_text,"snapshot_sha":snapshot_sha,"rows":rows,"errors":errors})+"\n")
	print("UV NATIVE: ",rows.size()," pairs; ",errors);quit(0 if errors.is_empty() else 2)

## Создаёт отдельный владеющий viewport с измеренной проекцией, без общих uniform мира.
func _viewport()->SubViewport:
	var result:=SubViewport.new();result.size=Vector2i(192,192);result.transparent_bg=false
	result.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(result);result.canvas_transform=Transform2D(0,Vector2(1.2,1.2),0,Vector2.ZERO);return result

## Красит только QA-соседей; выбранная область и отдельный эталон сохраняют исходные RGBA.
func _prepare_textures()->void:
	var atlas:=Image.load_from_file(ProjectSettings.globalize_path(Source.ATLAS_PATH))
	for kind in Roots.PROFILES:
		var source:=Source.source_image(kind,atlas);isolated[kind]=ImageTexture.create_from_image(source)
		masks[kind]=ImageTexture.create_from_image(Roots.build_mask(kind,source))
		if kind=="grass_low":atlases[kind]=isolated[kind];continue
		var hostile:=Image.create(1448,1086,false,Image.FORMAT_RGBA8)
		for cell in 12:hostile.fill_rect(Rect2i(cell%4*362,cell/4*362,362,362),[Color.MAGENTA,Color.CYAN,Color.YELLOW,Color.GREEN][cell%4])
		var region:=Rect2i(Ambient.source_rect(kind));hostile.blit_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),region.position)
		atlases[kind]=ImageTexture.create_from_image(hostile)

## Снимает actual draw обоих MeshInstance2D; модификатор unsafe принадлежит только отрицательному QA-контролю.
func _case(kind:String,flip:bool,bend:Vector2,unsafe:bool)->void:
	var id:=kind+"-"+str(int(flip))+"-"+str(int(bend.x))+("-unsafe" if unsafe else "")
	var folder:=output.path_join("pairs").path_join(id);DirAccess.make_dir_recursive_absolute(folder)
	var source_size:Vector2i=Roots.profile(kind).size
	var region:=Rect2i(Vector2i.ZERO,source_size) if kind=="grass_low" else Rect2i(Ambient.source_rect(kind))
	var data:=UV.mesh_data(kind,0.2 if kind=="grass_low" else 0.25,flip)
	if unsafe:
		var coords:PackedVector2Array=data.arrays[Mesh.ARRAY_TEX_UV]
		for i in coords.size():coords[i]=coords[i]*1.2-Vector2(0.1,0.1)
		data.arrays[Mesh.ARRAY_TEX_UV]=coords
	var mesh:=UV.make_mesh(data);var quads:=[]
	for viewport in [first,second,reflected]:
		var texture:Texture2D=atlases[kind] if viewport==first else isolated[kind]
		var source_region:Rect2i=region if viewport==first else Rect2i(Vector2i.ZERO,source_size)
		var reference:bool=viewport==reflected
		var parameters:=UV.parameters(kind,source_region,Vector2i(texture.get_size()),false if reference else flip)
		var quad:=Quad.new();quad.mesh=mesh
		if reference and flip:
			var reference_data:=UV.mesh_data(kind,data.scale,false)
			if unsafe:
				var reference_uv:PackedVector2Array=reference_data.arrays[Mesh.ARRAY_TEX_UV]
				for i in reference_uv.size():reference_uv[i]=reference_uv[i]*1.2-Vector2(0.1,0.1)
				reference_data.arrays[Mesh.ARRAY_TEX_UV]=reference_uv
			quad.mesh=UV.make_mesh(reference_data);quad.scale.x=-1.0
		quad.texture=texture;quad.material=UV.make_material(parameters,texture,masks[kind]);quad.position=Vector2(80.25,138.25)
		quad.material.set_shader_parameter("bend",Vector2(-bend.x,bend.y) if reference and flip else bend)
		if unsafe and viewport==first:
			var shader:=Shader.new();var code:=UV.ShaderSource.code
			var safe_line:="vec2 pixel = clamp(local_uv * source_rect.zw, vec2(0.5), source_rect.zw - vec2(0.5));"
			if code.count(safe_line)!=1:errors.append("negative-control shader mutation missing")
			shader.code=code.replace(safe_line,"vec2 pixel = local_uv * source_rect.zw;");quad.material.shader=shader
		viewport.add_child(quad);quads.append(quad)
	board.caption=id+(" | intentional negative control" if unsafe else " | safe atlas / isolated reference");board.show()
	for i in 3:game.queue_redraw();board.queue_redraw();await RenderingServer.frame_post_draw
	for q in quads:q.records.clear();q.observing=true
	game.draw_records.clear();game.observe_draw=true;board.frames.clear();board.observing=true
	var before:=JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text()
	for i in 2:
		for q in quads:q.queue_redraw()
		game.queue_redraw();board.queue_redraw();await RenderingServer.frame_post_draw
	game.observe_draw=false;board.observing=false
	first.get_texture().get_image().save_png(folder.path_join("atlas.png"));second.get_texture().get_image().save_png(folder.path_join("isolated.png"));reflected.get_texture().get_image().save_png(folder.path_join("reflected.png"))
	var uniforms:=[]
	for q in quads:q.observing=false;uniforms.append(q.records.duplicate(true))
	var draws:=[]
	for r in game.draw_records:draws.append({"before_sha":JSON.stringify(r.before).sha256_text(),"after_sha":JSON.stringify(r.after).sha256_text(),"equal":r.equal,"geometry_equal":r.geometry_equal,"frame":r.process_frame})
	var entry:={"id":id,"kind":kind,"flip":flip,"bend":[bend.x,bend.y],"unsafe":unsafe,"before_sha":before,"after_sha":JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text(),"window":Points.pair(DisplayServer.window_get_size()),"logical":Points.pair(root.get_visible_rect().size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"targets":[Points.pair(first.size),Points.pair(second.size),Points.pair(reflected.size)],"projection":[first.canvas_transform.x.x,first.canvas_transform.y.y],"uniforms":uniforms,"game_draws":draws,"board_frames":board.frames.duplicate(),"active_during":[first.get_child_count(),second.get_child_count(),reflected.get_child_count()],"vertices":[]}
	for point in data.arrays[Mesh.ARRAY_VERTEX]:entry.vertices.append(Points.pair(point))
	if kind in ["grass","grass_low"] and (bend==Vector2.ZERO or unsafe or flip):root.get_texture().get_image().save_png(folder.path_join("window.png"))
	for q in quads:q.queue_free()
	await process_frame
	entry.active_after=[first.get_child_count(),second.get_child_count(),reflected.get_child_count()];rows.append(entry)
	if before!=snapshot_sha or entry.after_sha!=snapshot_sha or draws.size()!=2 or uniforms[0].size()!=2 or uniforms[1].size()!=2 or uniforms[2].size()!=2 or entry.active_after!=[0,0,0] or entry.window!=Points.pair(size) or not entry.visible:errors.append(id+": callback/state/ownership/window failed")

## Ожидает только оконный сервер; игровая симуляция и shader time не продвигаются.
func _settle(ms:int)->void:
	var until:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<until:game.queue_redraw();await process_frame
