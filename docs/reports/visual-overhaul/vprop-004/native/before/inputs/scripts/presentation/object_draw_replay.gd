extends RefCounted

const Command := preload("res://scripts/presentation/object_draw_command.gd")

## Проверяет фазу, мир и собственный материал CanvasItem, не меняя родителя, HUD или камеру.
static func can_draw(canvas: CanvasItem, packet: Dictionary, world: String, layer: String) -> bool:
	return is_instance_valid(canvas) and Command.valid(packet) and packet.world==world and packet.layer==layer and not canvas.use_parent_material and canvas.material==packet.material

## Выводит целый спрайт либо регион; при отказе вызывает прежний путь ровно один раз до любого draw.
static func draw(canvas: CanvasItem, packet: Dictionary, world: String, layer: String, fallback: Callable = Callable()) -> String:
	if not can_draw(canvas,packet,world,layer):
		if fallback.is_valid(): fallback.call(); return "fallback"
		return "rejected"
	var texture: Texture2D=packet.texture
	if packet.source==Rect2(Vector2.ZERO,texture.get_size()): canvas.draw_texture_rect(texture,packet.bounds,false,packet.modulate)
	else: canvas.draw_texture_rect_region(texture,packet.bounds,packet.source,packet.modulate)
	return "command"
