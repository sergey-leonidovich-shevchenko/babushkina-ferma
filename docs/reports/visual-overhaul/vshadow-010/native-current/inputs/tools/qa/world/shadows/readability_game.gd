extends "res://tools/qa/world/render_order_game.gd"

const WorldSpace := preload("res://scripts/systems/world_projection_system.gd")
var shadow_contacts: Array[Dictionary] = []
var cached_contacts: Dictionary = {}


## Для каждого настоящего draw отделяет свежие вызовы от предыдущей камеры.
func _draw() -> void:
	shadow_contacts.clear()
	super._draw()


## Регистрирует фактические размеры mesh, а не заранее нарисованную маску доказательства.
func record_shadow_contact(owner: String, bounds: Rect2) -> void:
	var stretch := get_viewport().get_stretch_transform()
	var a := stretch * WorldSpace.world_to_screen(self, bounds.position)
	var b := stretch * WorldSpace.world_to_screen(self, bounds.end)
	var entry := {
		"owner": owner,
		"world": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"rect": [a.x, a.y, b.x - a.x, b.y - a.y]
	}
	shadow_contacts.append(entry)
	# Доска может быть записана в принятый render-command cache до наблюдаемого кадра.
	if owner == "village_board_visual":
		cached_contacts[str(current_location) + str(bounds)] = {
			"owner": owner, "bounds": bounds, "location": current_location
		}


## Перепроецирует только статическую доску той же локации; камера в кеше не хранится.
func contacts() -> Array[Dictionary]:
	var result := shadow_contacts.duplicate(true)
	for entry: Dictionary in cached_contacts.values():
		if entry.location != current_location:
			continue
		var bounds: Rect2 = entry.bounds
		var stretch := get_viewport().get_stretch_transform()
		var a := stretch * WorldSpace.world_to_screen(self, bounds.position)
		var b := stretch * WorldSpace.world_to_screen(self, bounds.end)
		var rect := [a.x, a.y, b.x - a.x, b.y - a.y]
		if not result.any(
			func(value: Dictionary) -> bool:
				return value.owner == entry.owner and value.rect == rect
		):
			result.append(
				{
					"owner": entry.owner,
					"world": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
					"rect": rect
				}
			)
	return result
