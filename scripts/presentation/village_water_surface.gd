extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const SurfaceShader := preload("res://scripts/presentation/village_water_surface.gdshader")
const RiverFlow := preload("res://scripts/presentation/village_river_flow.gd")
const QUALITY := &"water_surface_quality"
const DIRECTIONAL := &"water_surface_directional"
const LOOP_SECONDS := 64.0

var trim_decks := false:
	set(value):
		if trim_decks == value:
			return
		trim_decks = value
		queue_redraw()
		_river.queue_redraw()
var _season := "spring"
var _weather := "clear"
var _quality := ""
var _phase := -1.0
var _directed := false
var _flow_bound := false
var _surface_material := ShaderMaterial.new()
var _river_material := ShaderMaterial.new()
var _river := Node2D.new()


## Рисует речное русло отдельной командой перед прудом, с общим кодом шейдера.
func _init() -> void:
	_surface_material.shader = SurfaceShader
	_river_material.shader = SurfaceShader
	_river.name = "RiverCurrent"
	_river.show_behind_parent = true
	_river.draw.connect(_draw_river)
	add_child(_river)


## Меняет команды поверхности только при изменении сезонного тона.
func configure(season: String, weather: String) -> void:
	if _season == season and _weather == weather:
		return
	_season = season
	_weather = weather
	queue_redraw()
	_river.queue_redraw()


## Обновляет локальный материал без перестройки полигонов воды или запросов кеша земли.
func apply_profile(quality: String, seconds: float, directional: bool = true) -> void:
	var animated := quality in ["normal", "low"] and is_finite(seconds)
	var profile := quality if animated else "static"
	if profile != _quality:
		_quality = profile
		material = _surface_material if animated else null
		_river.material = _river_material if animated else null
		if animated:
			_surface_material.set_shader_parameter("fine_ripples", profile == "normal")
			_river_material.set_shader_parameter("fine_ripples", profile == "normal")
	if not animated:
		return
	if directional != _directed:
		_directed = directional
		if directional and not _flow_bound:
			var flow := RiverFlow.field()
			_river_material.set_shader_parameter("flow_coordinates", flow.texture)
			_river_material.set_shader_parameter("flow_bounds", flow.bounds)
			_flow_bound = true
		_river_material.set_shader_parameter("directed", _directed)
	var phase := fposmod(seconds, LOOP_SECONDS) * TAU / LOOP_SECONDS
	if _phase != phase:
		_phase = phase
		var ripple := Vector2(sin(phase * 9.0) * 0.78, sin(phase * 17.0) * 0.53)
		_surface_material.set_shader_parameter("ripple_offset", ripple)
		_river_material.set_shader_parameter("ripple_offset", ripple)
		_river_material.set_shader_parameter("flow_phase", phase)


## Оставляет колебание у пруда на исходной поверхности.
func _draw() -> void:
	Terrain.draw_surface(self, _season, true, _weather, "pond", trim_decks)


## Использует канонические речные полигоны с отсечением только закрытых настилом пикселей.
func _draw_river() -> void:
	Terrain.draw_surface(_river, _season, true, _weather, "river", trim_decks)
