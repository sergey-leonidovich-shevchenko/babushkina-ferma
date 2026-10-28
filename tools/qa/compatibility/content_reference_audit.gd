extends SceneTree

const Graph := preload("res://scripts/systems/content_reference_graph.gd")

## Проверяет каталоги без создания игры, чтения пользовательских конфигов, выдачи вещей или записи слотов.
func _initialize() -> void:
	var data:=Graph.snapshot(); var started:=Time.get_ticks_usec(); var errors:=Graph.errors(data)
	print("CONTENT REFERENCES: ",JSON.stringify({"items":data.items.size(),"recipes":data.recipes.size(),"missions":data.missions.size(),"stations":data.stations.size(),"languages":6,"validation_usec":Time.get_ticks_usec()-started,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
