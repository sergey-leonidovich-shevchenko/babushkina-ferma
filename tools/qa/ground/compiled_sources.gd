extends RefCounted
## QA-only bridge: metadata keys remain logical; current bytes always come from canonical files.

const MOVED := {
	"tools/ground_edge_builder.gd": "tools/qa/ground/ground_edge_builder.gd",
	"tools/ground_edge_field.gd": "tools/qa/ground/ground_edge_field.gd",
	"tools/axial_road_builder.gd": "tools/qa/ground/axial_road_builder.gd",
	"tools/axial_road_field.gd": "tools/qa/ground/axial_road_field.gd",
	"tools/road_network_builder.gd": "tools/qa/ground/road_network_builder.gd",
	"tools/plaza_builder.gd": "tools/qa/ground/plaza_builder.gd",
	"tools/plaza_field.gd": "tools/qa/ground/plaza_field.gd",
}
const UNCHANGED := ["scripts/systems/village_map_data.gd", "scripts/systems/village_region_data.gd",
	"scripts/systems/cardinal_path_system.gd", "scripts/presentation/meadow_ground.gd"]

## No root fallback: a missing canonical file must fail even if an old file survives.
static func current_sha(name: String, root: String="res://") -> String:
	if not MOVED.has(name) and not name in UNCHANGED: return ""
	var path := root.path_join(MOVED.get(name,name))
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

## Fresh compilers record actual current bytes under the original, closed metadata schema.
static func hashes(names: Array, root: String="res://") -> Dictionary:
	var result := {}
	for name: String in names:
		var digest := current_sha(name,root)
		if digest.length()!=64 or result.has(name): return {}
		result[name]=digest
	return result

## Frozen masks accept only the seven reviewed quoted preload relocations, never arbitrary edits.
static func matches(name: String, recorded: Variant, root: String="res://") -> bool:
	if not recorded is String or recorded.length()!=64: return false
	var actual := current_sha(name,root)
	if actual.length()!=64: return false
	if actual==recorded: return true
	if not MOVED.has(name): return false
	var raw := FileAccess.get_file_as_bytes(root.path_join(MOVED[name]))
	var text := raw.get_string_from_utf8()
	if text.to_utf8_buffer()!=raw: return false
	for logical: String in MOVED:
		text=text.replace('"res://'+MOVED[logical]+'"','"res://'+logical+'"')
	return text.sha256_text()==recorded
