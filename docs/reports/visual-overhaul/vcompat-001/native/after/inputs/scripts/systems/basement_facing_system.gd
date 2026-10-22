extends RefCounted

const Layout := preload("res://scripts/systems/basement_layout_system.gd")

## Разворачивает старые станки к игроку только при сохранении доступности всех рабочих мест.
static func restore(objects: Array) -> bool:
	var changed:=false
	for item in objects:
		if int(item.direction)!=2: continue
		var candidate:Dictionary=item.duplicate(); candidate.direction=0
		var others:Array=objects.filter(func(other): return int(other.id)!=int(item.id))
		if not Layout.reason(others,candidate).is_empty(): continue
		item.direction=0; changed=true
	return changed
