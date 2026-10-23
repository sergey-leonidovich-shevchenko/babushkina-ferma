extends "res://scripts/game.gd"

func _enter_tree() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "Codex-Performance-Probe-" + str(Time.get_ticks_usec()))

func _ready() -> void:
	super._ready()
	Engine.max_fps = 60
	print("PERFORMANCE CONFIG: ", JSON.stringify({"cap": Engine.max_fps, "autoplay": benchmark_autoplay, "debug": DebugOverlaySystem.active(self)}))
