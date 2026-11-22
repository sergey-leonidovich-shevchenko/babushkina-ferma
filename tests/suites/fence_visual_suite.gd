# Динамический игровой фасад проверяется реальными материалами и погодными сценариями.
@warning_ignore_start(
	"untyped_declaration", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access"
)
extends "res://tests/suites/suite_base.gd"


## Проверяет прежний атлас и действительный выбор погодного слоя без зависимости от пробелов.
func run() -> void:
	test_atlas_has_strict_modular_layout()
	test_renderer_reacts_to_season_and_weather()


## Сценарий: художественный лист читается как строгий модульный атлас без захвата соседних
## изображений.
## Исходное состояние: нормализованный PNG содержит пять материалов и восемь типов соединений.
## Ожидаемый результат: размер равен 512×320, каждая ячейка 64×64, а края сохраняют прозрачность.
func test_atlas_has_strict_modular_layout() -> void:
	var texture: Texture2D = load("res://assets/game/environment/buildable_fence_atlas_v1.png")
	var image := texture.get_image()
	expect(
		image.get_size() == Vector2i(512, 320),
		"fence atlas is an exact 8 by 5 sheet of 64 px source cells"
	)
	var transparent_corners := true
	for row in 5:
		for column in 8:
			var origin := Vector2i(column * 64, row * 64)
			transparent_corners = (
				transparent_corners
				and image.get_pixelv(origin).a < 0.1
				and image.get_pixelv(origin + Vector2i(63, 63)).a < 0.1
			)
	expect(
		transparent_corners,
		"every fence module keeps transparent padding and cannot bleed into its neighbour"
	)
	var game := make_game()
	expect(
		(
			game.WorldVisualProfileSystem.visual_size("fence_section") == Vector2(48, 48)
			and game.WorldVisualProfileSystem.visual_size("fence_gate") == Vector2(72, 72)
		),
		"runtime fence and gate artwork use exact modular frames"
	)
	game.free()
	expect(
		(
			ResourceLoader.exists("res://assets/game/items/catalog/fence_kit.png")
			and ResourceLoader.exists("res://assets/game/items/catalog/gate_kit.png")
		),
		"section and gate kits have dedicated inventory icons"
	)


## Сценарий: один материал получает разные мягкие оттенки для лета, осени, зимы и осадков.
## Исходное состояние: день и принудительная погода изменяются без замены исходного атласа.
## Ожидаемый результат: цветовая обработка различается, а снег и дождь остаются отдельным слоем
## рендера.
func test_renderer_reacts_to_season_and_weather() -> void:
	var game := make_game()
	var colors := {}
	for day in [1, 8, 15, 22]:
		game.day = day
		game.state.world.weather_day = day
		game.state.world.weather = "clear"
		colors[game.FenceRenderer.climate_color(game)] = true
	expect(colors.size() == 4, "fence finish has four distinct seasonal treatments")
	game.day = 1
	game.state.world.weather_day = 1
	game.state.world.weather = "rain"
	var rain: Color = game.FenceRenderer.climate_color(game)
	game.state.world.weather = "clear"
	var clear: Color = game.FenceRenderer.climate_color(game)
	expect(rain != clear, "rain adds a wet tint without changing the selected fence material")
	expect(
		(
			game.FenceRenderer.weather_detail_kind("winter", "clear") == "snow"
			and game.FenceRenderer.weather_detail_kind("spring", "snow") == "snow"
			and game.FenceRenderer.weather_detail_kind("winter", "rain") == "snow"
		),
		"actual fence layer keeps snow and winter precedence"
	)
	expect(
		(
			game.FenceRenderer.weather_detail_kind("spring", "rain") == "wet"
			and game.FenceRenderer.weather_detail_kind("spring", "storm") == "wet"
		),
		"actual fence layer keeps both wet-weather variants"
	)
	expect(
		game.FenceRenderer.weather_detail_kind("spring", "wind") == "wind",
		"actual fence layer keeps wind details"
	)
	expect(
		game.FenceRenderer.weather_detail_kind("spring", "clear") == "none",
		"clear spring does not add a weather layer"
	)
	game.free()
