extends SceneTree
## Real headless provenance/compiler probes; no native frame or performance claims.

const Sources := preload("res://tools/qa/ground/compiled_sources.gd")
const FOLDERS := {"ground_edge": "ground_masks", "axial_road": "axial_road_masks",
	"road_network": "road_network_masks", "plaza": "plaza_masks"}
var failures := 0
var checks := 0

func expect(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		print("FAIL: ",label)

func write_source(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _initialize() -> void:
	var output := ""
	var mode := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	if output.is_empty() or not mode in ["provenance","fresh"]: quit(2); return
	for kind: String in FOLDERS:
		var ids := ["apron","contact","stone"] if kind=="plaza" else ["main","connectors"]
		for id: String in ids:
			var path: String="res://assets/game/locations/overworld/"+FOLDERS[kind]+"/"+id+".res"
			var frozen: ArrayMesh=load(path)
			var metadata: Dictionary=frozen.get_meta("source_sha256")
			if mode=="provenance":
				for name: String in metadata:
					expect(Sources.matches(name,metadata[name]),"frozen source: "+name)
			else:
				var fresh: ArrayMesh=load(output.path_join(kind).path_join(id+".res"))
				expect(fresh!=null,"fresh mesh exists: "+kind+"/"+id)
				if fresh==null: continue
				expect(fresh.get_meta("source_sha256")==Sources.hashes(metadata.keys()),"fresh current hashes and exact logical keys")
				expect(fresh.get_meta("mask_spec")==frozen.get_meta("mask_spec"),"unchanged compiled mask specification")
				expect(var_to_bytes(fresh.surface_get_arrays(0))==var_to_bytes(frozen.surface_get_arrays(0)),"byte-equal geometry, UV and colours")
	if mode=="provenance": _tamper_checks(output)
	print("COMPILED SOURCES ",mode,": ",checks," checks, ",failures," failed")
	quit(0 if failures==0 else 1)

func _tamper_checks(root: String) -> void:
	for name: String in Sources.MOVED:
		var path := root.path_join(Sources.MOVED[name])
		var raw := FileAccess.get_file_as_bytes("res://"+Sources.MOVED[name])
		var legacy := raw.get_string_from_utf8()
		for logical: String in Sources.MOVED:
			legacy=legacy.replace('"res://'+Sources.MOVED[logical]+'"','"res://'+logical+'"')
		write_source(path,raw)
		var current := FileAccess.get_sha256(path)
		var previous := legacy.sha256_text()
		expect(Sources.matches(name,current,root),"current real bytes accepted")
		expect(Sources.matches(name,previous,root),"only preload address relocation accepted")
		write_source(path,(raw.get_string_from_utf8()+"\n# changed content\n").to_utf8_buffer())
		expect(not Sources.matches(name,current,root) and not Sources.matches(name,previous,root),"content tampering rejected")
		DirAccess.remove_absolute(path)
		write_source(root.path_join(name),legacy.to_utf8_buffer())
		expect(not Sources.matches(name,previous,root),"stale root source cannot replace missing canonical file")
		expect(Sources.hashes([name],root).is_empty(),"fresh compiler fails closed on missing source")
	for name: String in Sources.UNCHANGED:
		var path := root.path_join(name)
		var raw := FileAccess.get_file_as_bytes("res://"+name)
		write_source(path,raw)
		var digest := FileAccess.get_sha256(path)
		expect(Sources.matches(name,digest,root),"unchanged source accepted exactly")
		write_source(path,(raw.get_string_from_utf8()+"\n# changed content\n").to_utf8_buffer())
		expect(not Sources.matches(name,digest,root),"unchanged source tampering rejected")
	for name in ["../project.godot","tools/qa/ground/ground_edge_builder.gd","unknown"]:
		expect(Sources.current_sha(name,root).is_empty() and not Sources.matches(name,"a".repeat(64),root),"unknown/unsafe logical keys rejected")
	for digest in ["",null,123,"a".repeat(63)]:
		expect(not Sources.matches("tools/ground_edge_builder.gd",digest),"invalid digest rejected")
	expect(Sources.hashes(["scripts/systems/village_map_data.gd","unknown"]).is_empty(),"partial hash set rejected")
	expect(Sources.hashes(["scripts/systems/village_map_data.gd","scripts/systems/village_map_data.gd"]).is_empty(),"duplicate metadata keys rejected")
