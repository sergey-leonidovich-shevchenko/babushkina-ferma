extends SceneTree

const Scene := preload("res://main.tscn")

## Поднимает обычный режим эталона из аргументов игры в изолированном пользовательском каталоге.
func _initialize() -> void:
	_start.call_deferred()

## Запускает неизменённый игровой профиль снимка на нативном холсте без настроек и сохранений пользователя.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Paper-Theme-References")
	var container:=SubViewportContainer.new(); root.add_child(container)
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	var game:=Scene.instantiate(); game.set_meta("capture_windowed",true); game.audio_enabled=false; viewport.add_child(game); current_scene=container
	# Офлайн-эталон завершает уже поставленную очередь F10 до первого снимка, не меняя бюджет игрового кадра.
	if game.DebugOverlaySystem.active(game):
		var state:Dictionary=game.get_meta(game.DebugOverlaySystem.META_KEY)
		var limit:int=Dictionary(state.get("grid_build",{})).get("pending",[]).size()+1
		for _batch in limit:
			if Dictionary(game.get_meta(game.DebugOverlaySystem.META_KEY)).get("grid_build",{}).is_empty(): break
			game.DebugOverlaySystem.GridBuildSystem.advance(game)
