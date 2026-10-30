extends SceneTree

## Проверяет реальные текстовые контракты шести языков и увеличенный масштаб новых строительных окон.
func _initialize() -> void:
	var game:=preload("res://scripts/game.gd").new(); game.audio_enabled=false; game._ready()
	var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	for issue in report.issues: push_error(str(issue))
	print("BASEMENT UI: %d passed, %d failed"%[report.passed,report.failed]); game.free(); quit(0 if report.failed==0 else 1)
