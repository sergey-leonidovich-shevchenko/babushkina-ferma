extends SceneTree

var passed := 0
var failed := 0

## Проверяет ограничения отдельно от пользовательских настроек и обычных игровых слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VGROUND-008-review-"+str(Time.get_ticks_usec()))
	preload("res://tests/suites/decoration_rules_suite.gd").run(self)
	var rules:=preload("res://scripts/presentation/village_decoration_rules.gd"); var plan:=rules.legacy_plan()
	print("DECORATION COUNTS: ",rules.legacy_candidates().size()," / ",plan.accepted.size()," / ",plan.rejected.size()," zones=",rules.exclusions().size())
	print("DECORATION RULES: ",passed," passed, ",failed," failed")
	quit(0 if failed==0 else 1)

## Сохраняет понятное имя каждого нарушенного условия без утверждений о нативном FPS.
func expect(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)
