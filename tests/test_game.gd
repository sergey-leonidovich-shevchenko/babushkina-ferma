extends SceneTree

const GameScript = preload("res://scripts/game.gd")
const ArchitectureSuite = preload("res://tests/suites/architecture_suite.gd")
const CoreSuite = preload("res://tests/suites/core_suite.gd")
const ComfortSuite = preload("res://tests/suites/comfort_suite.gd")
const GameplaySuite = preload("res://tests/suites/gameplay_suite.gd")
const WorldSuite = preload("res://tests/suites/world_suite.gd"); const WaterVisualSuite = preload("res://tests/suites/water_visual_suite.gd")
const BuildingsSuite = preload("res://tests/suites/buildings_suite.gd")
const ProgressionSuite = preload("res://tests/suites/progression_suite.gd"); const TalentSuite = preload("res://tests/suites/talent_suite.gd")
const AnimationSuite = preload("res://tests/suites/animation_suite.gd")
const AudioSuite = preload("res://tests/suites/audio_suite.gd")
const InterfaceSuite = preload("res://tests/suites/interface_suite.gd")
const EnemyLevelsSuite = preload("res://tests/suites/enemy_levels_suite.gd")
const StorageForgeSuite = preload("res://tests/suites/storage_forge_suite.gd")
const ContractsSuite = preload("res://tests/suites/contracts_suite.gd")
const MenuSuite = preload("res://tests/suites/menu_suite.gd")
const StorySuite = preload("res://tests/suites/story_suite.gd")
const FishingSuite = preload("res://tests/suites/fishing_suite.gd")
const TreeSuite = preload("res://tests/suites/tree_suite.gd"); const CraftingPipelineSuite = preload("res://tests/suites/crafting_pipeline_suite.gd")
const PirateShipSuite = preload("res://tests/suites/pirate_ship_suite.gd")
const VisualAssetsSuite = preload("res://tests/suites/visual_assets_suite.gd")
const PotionSuite = preload("res://tests/suites/potion_suite.gd")
const SpriteStandardSuite = preload("res://tests/suites/sprite_standard_suite.gd")
const WorldEventsSuite = preload("res://tests/suites/world_events_suite.gd")
const ExpansionSuite = preload("res://tests/suites/expansion_suite.gd")
const AdventurePolishSuite = preload("res://tests/suites/adventure_polish_suite.gd")
const EnemyAnimationSuite = preload("res://tests/suites/enemy_animation_suite.gd")
const LivingWorldSuite = preload("res://tests/suites/living_world_suite.gd")
const FarmLifeSuite = preload("res://tests/suites/farm_life_suite.gd"); const WorldFarmingSuite = preload("res://tests/suites/world_farming_suite.gd"); const LevelEditorSuite = preload("res://tests/suites/level_editor_suite.gd"); const FenceBuildingSuite = preload("res://tests/suites/fence_building_suite.gd")
const FirstChapterSuite = preload("res://tests/suites/first_chapter_suite.gd"); const SpellSuite = preload("res://tests/suites/spell_suite.gd"); const UiVisualRegressionSuite = preload("res://tests/suites/ui_visual_regression_suite.gd"); const CombatEpicSuite = preload("res://tests/suites/combat_epic_suite.gd")
var passed := 0
var failed := 0

## Ожидает входа корневого окна в SceneTree, чтобы реальные дочерние viewport проверялись в рабочем дереве.
func _initialize() -> void:
	_run.call_deferred()

## Запускает прежние наборы в прежнем порядке и завершает процесс с кодом результата, без пропуска in-tree сценариев.
func _run() -> void:
	CoreSuite.new(self).run()
	var suites: Array = [
		ComfortSuite, GameplaySuite, WorldSuite, WaterVisualSuite, BuildingsSuite,
		ProgressionSuite, TalentSuite, SpellSuite, AnimationSuite, AudioSuite,
		InterfaceSuite, EnemyLevelsSuite, StorageForgeSuite, ContractsSuite, MenuSuite,
		StorySuite, FishingSuite, TreeSuite, CraftingPipelineSuite, PirateShipSuite,
		VisualAssetsSuite, PotionSuite, SpriteStandardSuite, WorldEventsSuite,
		ExpansionSuite, AdventurePolishSuite, EnemyAnimationSuite, CombatEpicSuite,
		LivingWorldSuite, FarmLifeSuite, FirstChapterSuite, WorldFarmingSuite,
		LevelEditorSuite, FenceBuildingSuite, UiVisualRegressionSuite,
	]
	for suite in suites: suite.new(self).run()
	ArchitectureSuite.run(self)
	print("TESTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

## Создаёт изолированный экземпляр игры с отключёнными стартовыми экранами.
func make_game() -> Node:
	var game := GameScript.new()
	game._ready()
	# Каждый сценарий начинает с базовой локали и не наследует язык предыдущего теста или пользовательских настроек.
	game.LocaleSystem.set_locale("ru"); game.language_screen = false
	game.title_screen = false
	return game

## Создаёт клавиатурное событие с заданными логической и физической клавишами.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	return event

## Регистрирует успешную или проваленную проверку с понятным названием.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)
