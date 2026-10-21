extends RefCounted

const META:=&"post_motion_visual_frame"
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")
const Pose:=preload("res://scripts/systems/presentation_pose_system.gd")
const Reference:=preload("res://scripts/presentation/visual_reference_mode.gd")
const Editor:=preload("res://scripts/systems/level_editor_system.gd")
const KEYS:=["world","player_world","seconds","active"]

## Публикует один неизменяемый кадр после движения, переходов и действий, без сохранения Node или желаемой позиции.
static func publish(game:Node,delta:float)->bool:
	if not is_finite(delta) or delta<=0.0 or not Vector2(game.player).is_finite():return false
	if game.language_screen or game.GameLoop.modal_active(game) or game.GameLoop.gameplay_window_open(game) or Editor.active(game):return false
	Clock.advance(game,delta)
	var value:={"world":String(game.current_location),"player_world":Vector2(game.player),"seconds":Clock.seconds(game),"active":allowed(game)}
	value.make_read_only();game.set_meta(META,value);return true

## Разрешает контакт только первой карте и обычному режиму эффектов, не привязывая кадр к экрану или камере.
static func allowed(game:Node)->bool:
	return game.current_location=="overworld" and not Editor.active(game) and not game.settings_state.reduced_motion and Reference.effects_enabled(game)

## Читает чистые данные; загрузка, перенос, чужой мир и повреждённая metadata немедленно отвергаются без записи.
static func read(game:Node)->Dictionary:
	if not game.has_meta(META):return {}
	var raw:Variant=game.get_meta(META)
	if not raw is Dictionary or not raw.is_read_only() or raw.size()!=KEYS.size():return {}
	for key in KEYS:
		if not raw.has(key):return {}
	if typeof(raw.world)!=TYPE_STRING or typeof(raw.player_world)!=TYPE_VECTOR2 or typeof(raw.seconds)!=TYPE_FLOAT or typeof(raw.active)!=TYPE_BOOL:return {}
	if not raw.player_world.is_finite() or not is_finite(raw.seconds) or raw.seconds<0.0:return {}
	if raw.world!=game.current_location or raw.player_world!=game.player or raw.seconds!=Clock.seconds(game) or raw.active!=allowed(game):return {}
	return raw

## Для шейдера даёт ту же отображаемую стопу, что герою; физический кадр подтверждает результат коллизий, а не ввод.
static func contact(game:Node,root:Vector2,radius:float)->Vector2:
	var value:=read(game)
	if value.is_empty() or not value.active or not allowed(game) or not root.is_finite() or not is_finite(radius) or radius<=0.0:return Vector2.ZERO
	return Pose.root_contact(game,root,radius)
