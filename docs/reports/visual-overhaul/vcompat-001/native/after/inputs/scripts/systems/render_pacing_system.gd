extends RefCounted

const IDLE_SLEEP_USEC := 500

## Перерисовывает изменившийся мир без сотен повторных GPU-кадров и без второго таймера поверх VSync.
static func apply() -> void:
	Engine.max_fps=0
	OS.low_processor_usage_mode=true
	OS.low_processor_usage_mode_sleep_usec=IDLE_SLEEP_USEC
