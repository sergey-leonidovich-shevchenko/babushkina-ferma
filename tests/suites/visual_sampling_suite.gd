extends "res://tests/suites/suite_base.gd"

const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Dial := preload("res://scripts/systems/celestial_dial_assets_system.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")


## Запускает независимые проверки адресной фильтрации, защиты атласов и реальных потребителей.
func run() -> void:
	test_filters_share_pixels_without_mutating_source_or_canvas()
	test_invalid_or_unsafe_sampling_is_absent()
	test_runtime_editor_and_clock_own_their_wrappers()
	test_global_default_cannot_override_legacy_canvas()


## Сценарий: один PNG используется одновременно с двумя фильтрами на общем полотне.
## Исходное состояние: настоящий стол и неизменная опора из паспорта.
## Ожидаемый результат: обёртки делят исходник, фильтры независимы, размеры и исходные данные сохранены.
func test_filters_share_pixels_without_mutating_source_or_canvas() -> void:
	var source := Resources.texture("prop.rustic_table")
	var a := Sampling.create(source,"legacy_world")
	var b := Sampling.create(source,"painted_world")
	expect(a!=b and a.diffuse_texture==source and b.diffuse_texture==source,"independent filters share one existing texture without CPU/GPU image copies")
	expect(a.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and b.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"nearest and linear are explicit per-texture overrides")
	expect(a.get_size()==source.get_size() and b.get_size()==source.get_size(),"filtering preserves source dimensions")
	expect(a.texture_repeat==CanvasItem.TEXTURE_REPEAT_DISABLED and b.texture_repeat==CanvasItem.TEXTURE_REPEAT_DISABLED,"standalone sampling never wraps the opposite edge")
	expect(source.resource_path==Resources.describe("prop.rustic_table").path,"source path remains available to icons and exporters")
	var policy := Sampling.policy(); policy.families.clear()
	expect(Sampling.policy().families.size()==5,"external policy copies cannot change the runtime family contract")


## Сценарий: запрашивается неизвестное семейство, пустой источник или линейный атлас без подготовленных полей.
## Исходное состояние: настоящий миниатюрный атлас и собственная ссылка на один его регион.
## Ожидаемый результат: небезопасные запросы явно отсутствуют, прежний nearest остаётся доступен.
func test_invalid_or_unsafe_sampling_is_absent() -> void:
	var atlas := AtlasTexture.new(); atlas.atlas=Prepared.ATLAS; atlas.region=Rect2(0,0,64,64)
	expect(Sampling.create(null,"painted_world")==null,"missing texture cannot silently create a white placeholder")
	expect(Sampling.create(Prepared.ATLAS,"unknown")==null,"unknown family is explicitly absent")
	expect(Sampling.create(Prepared.ATLAS,"painted_ui","atlas")==null,"unprepared atlas cannot enable linear through a layout declaration")
	expect(Sampling.create(atlas,"painted_ui")==null,"AtlasTexture cannot disguise an unprepared atlas as standalone")
	expect(Sampling.create(atlas,"legacy_ui","atlas")!=null,"legacy atlas retains its nearest drawing path")
	expect(Sampling.create(Prepared.ATLAS,"legacy_ui","bad")==null,"unknown layout is not guessed from a PNG filename")
	expect(Sampling.create(Sampling.create(Prepared.ATLAS,"legacy_ui"),"legacy_ui")==null,"nested wrappers are refused rather than multiplying resources")


## Сценарий: игровой стол, F12 и опубликованный уровень запрашивают один паспорт, часы — своё семейство.
## Исходное состояние: три полезных ракурса стола и существующие три слоя циферблата.
## Ожидаемый результат: обёртки переиспользуются, исходники остаются отдельными, геометрия не меняется.
func test_runtime_editor_and_clock_own_their_wrappers() -> void:
	var editor := preload("res://scripts/systems/level_editor_renderer.gd")
	for side in ["south","west","east"]:
		var view := Resources.describe("prop.rustic_table",side)
		var sampled := Resources.sampled_texture("prop.rustic_table",side)
		expect(sampled==Resources.sampled_texture("prop.rustic_table",side) and sampled==Resources.sampled_texture("prop.rustic_table",side,"standard"),"repeated and explicit-quality requests reuse one wrapper: "+side)
		expect(sampled is CanvasTexture and sampled.diffuse_texture==Resources.texture("prop.rustic_table",side),"metadata filter shares the source texture: "+side)
		expect(editor.texture_for(view.path)==sampled and sampled.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"palette, ghost and published renderer share the runtime family: "+side)
	for kind in ["sky","landscape","frame"]:
		var clock := Dial.texture(kind)
		expect(clock==Dial.texture(kind) and clock.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR and clock.get_size()==Vector2(512,512),"painted clock remains independently linear and cached: "+kind)
	expect(Resources.sampled_texture("missing")==null,"missing metadata ID cannot select an unrelated sampling family")
	expect(Resources.sampled_for_path("unknown",Prepared.ATLAS)==Prepared.ATLAS,"files outside the passport preserve their existing owner")


## Сценарий: общий флаг проекта случайно переключён на linear до создания игры.
## Исходное состояние: изолированный игровой экземпляр и сохранённое исходное значение настройки.
## Ожидаемый результат: мир и интерфейс явно сохраняют nearest, часы остаются linear, общий флаг восстановлен.
func test_global_default_cannot_override_legacy_canvas() -> void:
	var path := "rendering/textures/canvas_textures/default_texture_filter"
	var previous = ProjectSettings.get_setting(path)
	ProjectSettings.set_setting(path,Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
	var game := make_game()
	expect(game.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"bootstrap pins the legacy canvas instead of inheriting the project default")
	expect(Dial.texture("frame").texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"pinning the canvas does not erase the painted clock override")
	expect(ProjectSettings.get_setting(path)==Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR,"resource policy does not mutate the project default")
	game.free(); ProjectSettings.set_setting(path,previous)
