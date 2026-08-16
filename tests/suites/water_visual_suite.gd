extends "res://tests/suites/suite_base.gd"

const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")
const WaterVisualSystem := preload("res://scripts/systems/water_visual_system.gd")


## Запускает все сценарии водного визуального контракта в фиксированном порядке.
func run() -> void:
	test_water_catalog_animation_and_navigation_share_the_24px_grid()


## Сценарий: вода, берега, рыба и всплески используют единый визуальный профиль вместо случайных масштабов.
## Исходное состояние: полный каталог содержит поверхность, четыре берега, углы, узкое русло и прозрачные CC0-эффекты.
## Ожидаемый результат: тайлы равны 24 px, все маски разрешаются, эффекты масштабируются целым числом, а водная сетка совпадает с базовой навигацией.
func test_water_catalog_animation_and_navigation_share_the_24px_grid() -> void:
	expect(WaterVisualSystem.SURFACE_KINDS.size()==6 and WaterVisualSystem.SHORE_KINDS.size()==6 and WaterVisualSystem.RIVER_KINDS.size()==6 and WaterVisualSystem.MODULES.size()==19, "water catalog owns six surfaces six shores six river modules and an isolated pond")
	for kind in WaterVisualSystem.MODULES:
		var texture:Texture2D=WaterVisualSystem.texture(kind); var image:=texture.get_image()
		expect(texture.get_size()==Vector2(24,24) and image.get_pixel(0,0).a>0.99 and image.get_pixel(23,23).a>0.99, "%s is an opaque crop-safe 24 px water module"%kind)
	for mask in 16:
		var variant:Dictionary=WaterVisualSystem.variant_for_mask(mask,Vector2i(7,11),mask%4)
		expect(WaterVisualSystem.MODULES.has(String(variant.kind)) and fmod(absf(float(variant.rotation)),PI*0.5)<0.001, "water neighbor mask %d resolves to a registered quarter-turn module"%mask)
	for missing_diagonal in 4:
		var variant:Dictionary=WaterVisualSystem.variant_for_mask(15,Vector2i(7,11),0,15&~(1<<missing_diagonal))
		expect(variant.kind=="shore_inner_corner" and is_equal_approx(float(variant.rotation),[0.0,PI*0.5,PI,-PI*0.5][missing_diagonal]),"missing diagonal %d resolves to the matching concave shoreline"%missing_diagonal)
	for frame in 4:
		expect(String(WaterVisualSystem.surface_kind(Vector2i(7,0),frame)) in WaterVisualSystem.SURFACE_KINDS, "animated surface frame %d stays inside the native water catalog"%frame)
	var cells:=WaterVisualSystem.first_location_cells(VillageLayoutSystem,"spring"); var mismatches:Array=[]
	for row in range(VillageLayoutSystem.OVERWORLD_TILE_COUNT.y):
		for col in range(VillageLayoutSystem.OVERWORLD_TILE_COUNT.x):
			var cell:=Vector2i(col,row); var center:=VillageLayoutSystem.tile_center(cell)
			if cells.has(cell)!=VillageLayoutSystem.is_water(center,0.0): mismatches.append(cell)
	expect(cells.size()>250 and mismatches.is_empty(), "visible modular water cells and zero-radius navigation contour share one 24 px authority")
	for bridge in VillageLayoutSystem.BRIDGES:
		expect(not cells.has(Vector2i(Vector2(bridge.get_center())/24.0)), "bridge center is removed from water topology and remains walkable")
	for effect_kind in ["fish","splash","bubbles"]:
		var effect:=WaterVisualSystem.effect_profile(effect_kind); var source:=Vector2(effect.source_size); var content:=Vector2(effect.content_size); var last:=WaterVisualSystem.effect_source_rect(effect_kind,int(effect.frames)-1)
		expect(fmod(content.x,source.x)==0.0 and fmod(content.y,source.y)==0.0 and last.end.x<=WaterVisualSystem.EFFECT_SHEETS[effect_kind].get_width(), "%s keeps integer pixel scale and crop-safe final frame"%effect_kind)
	expect(Vector2(WaterVisualSystem.effect_profile("fish").visual_size)==Vector2(48,48) and Vector2(WaterVisualSystem.effect_profile("splash").visual_size)==Vector2(72,72), "fish uses 48 px and splash uses the agreed 72 px modular frame")
	var renderer_source:=FileAccess.get_file_as_string("res://scripts/game_renderer.gd"); var editor_source:=FileAccess.get_file_as_string("res://scripts/systems/level_editor_validation_system.gd")
	expect(renderer_source.contains("WaterVisualSystem.draw_first_location_animations") and not renderer_source.contains("FISH_ANIMATION"), "world animation delegates water effects instead of owning sprite dimensions")
	expect(editor_source.contains("WaterVisualSystem.variant_for_mask") and editor_source.contains("WaterVisualSystem.module_path"), "level editor consumes the same water topology and module catalog as runtime")
	var preview:Texture2D=load("res://assets/generated/level_drafts/water_navigation_ingame_preview.png")
	expect(preview!=null and preview.get_size()==Vector2(1152,648), "water migration keeps a current F10 gameplay preview for visible contour and bridge review")
