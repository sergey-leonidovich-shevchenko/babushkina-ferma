extends Node2D

const Data := preload("res://tools/grass_compare/mesh_data.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Wind := preload("res://tools/grass_compare/wind.gdshader")
const TEXTURE_PATH := "res://docs/reports/visual-overhaul/vart-008/native/sprites/grass-low.png"
const GROUP_SIZE := 64
var game: Node
var method := "batch"
var wind_time := 0.0
var controlled := true
var shader_material: ShaderMaterial
var chunks := []
var roots := []
var build_usec := 0
var update_usec := 0
var mesh_builds := 0
var vertex_updates := 0
var input_bytes := 0
var cpu_upload_bytes := 0

## Создаёт изолированный визуальный слой за production-актёрами, используя один принятый PNG.
func configure(owner_game: Node, variant: String, points: Array) -> void:
	var started:=Time.get_ticks_usec()
	game=owner_game; method=variant; roots=points.duplicate(); show_behind_parent=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var image:=Image.load_from_file(TEXTURE_PATH); image.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(image)
	shader_material=ShaderMaterial.new(); shader_material.shader=Wind
	shader_material.set_shader_parameter("gpu_wind",method!="cpu")
	if method!="none":
		var step:=1 if method=="items" else GROUP_SIZE
		for i in range(0,roots.size(),step):
			var group:=roots.slice(i,mini(i+step,roots.size()))
			var origin:Vector2=group[0] if method=="items" else Vector2.ZERO
			var data:=Data.arrays(group,origin); var mesh:=Data.mesh(data,method=="cpu")
			var instance:=MeshInstance2D.new(); instance.mesh=mesh; instance.texture=texture; instance.material=shader_material; instance.position=origin
			add_child(instance); chunks.append({"mesh":mesh,"data":data}); mesh_builds+=1
		input_bytes=roots.size()*(Data.VERTICES*(8+8+16)+Data.INDICES*4)
	build_usec=Time.get_ticks_usec()-started
	set_time(0.0)

## Обновляет собственные визуальные часы и проекцию; пауза и другой мир не изменяют фазу.
func _process(delta: float) -> void:
	var started:=Time.get_ticks_usec()
	transform=WorldProjection.transform(game); visible=game.current_location=="overworld"
	if not controlled and visible and not game.GameLoop.modal_active(game) and not game.GameLoop.gameplay_window_open(game): set_time(wind_time+delta)
	update_usec=Time.get_ticks_usec()-started

## При одинаковой фазе выбирает только способ деформации, не меняя порядок корней или графику.
func set_time(value: float) -> void:
	wind_time=value
	shader_material.set_shader_parameter("wind_time",wind_time)
	if method=="cpu":
		for chunk in chunks:
			var vertices:=Data.deform(chunk.data,wind_time)
			chunk.mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())
			vertex_updates+=1; cpu_upload_bytes+=vertices.size()*8

## Возвращает факты структуры/передач; эти числа не являются измерением резидентной VRAM.
func statistics() -> Dictionary:
	return {"method":method,"roots":roots.size(),"canvas_items":chunks.size(),"mesh_builds":mesh_builds,"vertex_updates":vertex_updates,
		"cpu_upload_bytes":cpu_upload_bytes,"input_array_bytes":input_bytes,"build_usec":build_usec,"wind_time":wind_time}
