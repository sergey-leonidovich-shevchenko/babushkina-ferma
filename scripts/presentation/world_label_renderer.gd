extends RefCounted

const Style := preload("res://scripts/presentation/moon_theme.gd")
const Camera := preload("res://scripts/systems/camera_system.gd")

## Вписывает короткую мировую подпись в доступное поле камеры с учётом реальных метрик и масштаба текста.
static func bounds(game:Node, anchor:Vector2, label:String, maximum:float=200, extra_height:float=0) -> Rect2:
	var scale:float=game.settings_state.text_scale
	var size:=roundi(11*scale)
	var width:=clampf(game.UI_FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+16,48,maximum)
	var height:=maxf(22,game.UI_FONT.get_height(size)+8)+maxf(0,extra_height)
	var safe:=Camera.WorldProjection.screen_rect_to_world(game,Camera.playfield_rect(game).grow(-8))
	var origin:=anchor-Vector2(width/2,0)
	origin.x=clampf(origin.x,safe.position.x,safe.end.x-width)
	origin.y=clampf(origin.y,safe.position.y,safe.end.y-height)
	return Rect2(origin,Vector2(width,height))

## Рисует светлую подпись только рядом с героем, сохраняя крупную информацию в контекстной карточке HUD.
static func draw(game:Node2D, anchor:Vector2, label:String, near:Vector2, radius:float=180) -> void:
	if not preload("res://scripts/presentation/visual_reference_mode.gd").hud_visible(game): return
	if label.is_empty() or game.player.distance_to(near)>radius: return
	var rect:=bounds(game,anchor,label)
	Style.panel(game,rect)
	Style.text(game,rect.grow(-4),label,11,Style.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
