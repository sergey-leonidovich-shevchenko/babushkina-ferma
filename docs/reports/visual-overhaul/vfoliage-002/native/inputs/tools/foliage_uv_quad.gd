extends MeshInstance2D

var records:=[]
var observing:=false

## Наблюдает настоящий CanvasItem draw с фактическими uniform; встроенная отрисовка MeshInstance2D не заменяется.
func _draw()->void:
	if not observing:return
	var region:Vector4=material.get_shader_parameter("source_rect")
	var bend:Vector2=material.get_shader_parameter("bend")
	var dimensions:Vector2=material.get_shader_parameter("atlas_size")
	var source:Texture2D=material.get_shader_parameter("source_atlas");var mask:Texture2D=material.get_shader_parameter("root_mask")
	records.append({"frame":Engine.get_process_frames(),"region":[region.x,region.y,region.z,region.w],"atlas_size":[dimensions.x,dimensions.y],"source_valid":source!=null and source.get_rid().is_valid(),"mask_valid":mask!=null and mask.get_rid().is_valid(),"shader_sha":material.shader.code.sha256_text(),"mirror_x":material.get_shader_parameter("mirror_x"),"bend":[bend.x,bend.y],"lock_v":material.get_shader_parameter("lock_v"),"top_v":material.get_shader_parameter("top_v"),"flexible":material.get_shader_parameter("flexible"),"position":[position.x,position.y],"scale":[scale.x,scale.y],"vertices":mesh.surface_get_array_len(0),"indices":mesh.surface_get_array_index_len(0)})
