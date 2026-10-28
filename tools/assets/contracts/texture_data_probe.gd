extends SceneTree

const Intents := preload("res://scripts/presentation/texture_intent_system.gd")
var views: Array[Dictionary]=[]
var result := {"cpu":[],"gpu":[],"guard_refused_wrong":true}
var output := OS.get_environment("VTEXTURE_OUTPUT")
var hdr := OS.get_environment("VTEXTURE_HDR")=="1"

## Принимает только новый каталог диагностики вне пользовательских сохранений.
func _initialize() -> void:
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output); capture.call_deferred()

## Читает импортированные байты и готовит правильные и намеренно ошибочные GPU-выборки.
func capture() -> void:
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://fixtures.json"))
	for entry in fixtures.textures:
		var texture := load("res://"+entry.file) as Texture2D
		var image := texture.get_image()
		result.cpu.append({"name":entry.name,"format":image.get_format(),"mipmaps":image.has_mipmaps(),"rgba":Array(image.get_data())})
		if entry.intent=="negative_alpha": continue
		for wrong in [false,true]: add_view(texture,entry,wrong)
	for frame in 20:
		await process_frame; RenderingServer.force_draw(false)
	for entry in views:
		var image: Image=entry.viewport.get_texture().get_image()
		var values: Array=[]
		for y in 8:
			for x in 16:
				var color := image.get_pixel(x*8+4,y*8+4)
				values.append([color.r,color.g,color.b,color.a])
		var name: String=entry.name+("-wrong" if entry.wrong else "-correct")
		var display := image.duplicate(); display.convert(Image.FORMAT_RGBA8)
		display.save_png(output+"/"+name+".png")
		result.gpu.append({"name":entry.name,"wrong":entry.wrong,"format":image.get_format(),"hdr":entry.viewport.use_hdr_2d,"pixels":values,"file":name+".png"})
	result.merge({"engine":Engine.get_version_info().string,"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"device":RenderingServer.get_video_adapter_name(),"requested_hdr":hdr,"performance_eligible":false})
	FileAccess.open(output+"/readback.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEXTURE GPU: ",result.method," hdr=",hdr," cpu=",result.cpu.size()," gpu=",result.gpu.size()); quit()

## Использует производственную фабрику; только отрицательный контроль сознательно обходит её отказ.
func add_view(texture: Texture2D, entry: Dictionary, wrong: bool) -> void:
	var viewport := SubViewport.new(); viewport.size=Vector2i(128,64)
	viewport.use_hdr_2d=hdr; viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var color_role: bool=Intents.profile(entry.intent).source_color
	var hint := "source_color, " if color_role!=wrong else ""
	var shader := Shader.new()
	shader.code="shader_type canvas_item; render_mode unshaded, blend_disabled; uniform sampler2D sample_map : "+hint+"filter_nearest, repeat_disable; void fragment(){ COLOR=texture(sample_map,UV); }"
	var binding := {"sample_map":Intents.binding(texture,entry.intent)}
	var material := Intents.material(shader,binding)
	if wrong:
		result.guard_refused_wrong=result.guard_refused_wrong and material==null
		material=ShaderMaterial.new(); material.shader=shader; material.set_shader_parameter("sample_map",texture)
	elif material==null: quit(3); return
	var rectangle := ColorRect.new(); rectangle.size=Vector2(128,64); rectangle.material=material
	viewport.add_child(rectangle); views.append({"viewport":viewport,"name":entry.name,"wrong":wrong})
