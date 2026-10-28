extends SceneTree

const GameScript := preload("res://scripts/game.gd")
const OUTPUT_PATH := "res://docs/reports/ui_layout_audit.json"


## Запускает живой UI-аудит, сохраняет стабильную аналитику в JSON и завершает процесс кодом результата.
func _initialize()->void:
	var game:=GameScript.new(); game._ready(); game.language_screen=false; game.title_screen=false
	var report:Dictionary=game.UiLayoutAuditSystem.project_report(game); var file:=FileAccess.open(OUTPUT_PATH,FileAccess.WRITE)
	if file==null: push_error("UI AUDIT: не удалось открыть отчёт"); game.free(); quit(2); return
	file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); print("UI AUDIT: %d/%d проверок пройдено, проблем %d"%[report.passed,report.checks,report.failed]); game.free(); quit(0 if int(report.failed)==0 else 1)
