extends RefCounted

const STATION := [
	[preload("res://assets/game/kitchen/kitchen_1_south.tres"),preload("res://assets/game/kitchen/kitchen_1_west.tres"),preload("res://assets/game/kitchen/kitchen_1_south.tres"),preload("res://assets/game/kitchen/kitchen_1_east.tres")],
	[preload("res://assets/game/kitchen/kitchen_2_south.tres"),preload("res://assets/game/kitchen/kitchen_2_west.tres"),preload("res://assets/game/kitchen/kitchen_2_south.tres"),preload("res://assets/game/kitchen/kitchen_2_east.tres")],
	[preload("res://assets/game/kitchen/kitchen_3_south.tres"),preload("res://assets/game/kitchen/kitchen_3_west.tres"),preload("res://assets/game/kitchen/kitchen_3_south.tres"),preload("res://assets/game/kitchen/kitchen_3_east.tres")],
	[preload("res://assets/game/kitchen/kitchen_pile_south.tres"),preload("res://assets/game/kitchen/kitchen_pile_west.tres"),preload("res://assets/game/kitchen/kitchen_pile_south.tres"),preload("res://assets/game/kitchen/kitchen_pile_east.tres")],
]
const FOOD := {
	"fried_vegetables":preload("res://assets/game/kitchen/fried_vegetables.tres"),
	"baked_potato":preload("res://assets/game/kitchen/baked_potato.tres"),
	"vegetable_casserole":preload("res://assets/game/kitchen/vegetable_casserole.tres"),
	"mushroom_pie":preload("res://assets/game/kitchen/mushroom_pie.tres"),
}

const FIRE := [preload("res://assets/game/kitchen/fire_0.tres"),preload("res://assets/game/kitchen/fire_1.tres"),preload("res://assets/game/kitchen/fire_2.tres"),preload("res://assets/game/kitchen/fire_3.tres")]

## Возвращает отдельную иконку блюда из утверждённого ремесленного атласа.
static func food_texture(kind: String) -> AtlasTexture:
	return FOOD.get(kind)
