extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const SurfaceShader := preload("res://scripts/presentation/village_water_surface.gdshader")
const QUALITY := &"water_surface_quality"
const LOOP_SECONDS := 64.0

var _season := "spring"
var _weather := "clear"
var _quality := ""
var _phase := -1.0
var _surface_material := ShaderMaterial.new()


## Подключает один общий шейдер к собственному материалу фонового узла.
func _ready() -> void:
	_surface_material.shader = SurfaceShader


## Меняет команды поверхности только при изменении сезонного тона.
func configure(season: String, weather: String) -> void:
	if _season == season and _weather == weather:
		return
	_season = season
	_weather = weather
	queue_redraw()


## Обновляет локальный материал без перестройки полигонов воды или запросов кеша земли.
func apply_profile(quality: String, seconds: float) -> void:
	var animated := quality in ["normal", "low"] and is_finite(seconds)
	var profile := quality if animated else "static"
	if profile != _quality:
		_quality = profile
		if animated:
			_surface_material.set_shader_parameter("fine_ripples", profile == "normal")
			material = _surface_material
		else:
			material = null
	if not animated:
		return
	var phase := fposmod(seconds, LOOP_SECONDS) * TAU / LOOP_SECONDS
	if _phase != phase:
		_phase = phase
		_surface_material.set_shader_parameter(
			"ripple_offset", Vector2(sin(phase * 9.0) * 0.78, sin(phase * 17.0) * 0.53)
		)


## Рисует поверхность по тому же отсечённому контуру, что и слой дна.
func _draw() -> void:
	Terrain.draw_surface(self, _season, true, _weather)
