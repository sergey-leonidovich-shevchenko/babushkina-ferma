extends RefCounted

const Presentation := preload("res://scripts/systems/item_presentation_system.gd")

## Применяет пищевой эффект из того же каталога, который показывают карточка предмета и рецепт.
static func apply(game: Node, kind: String) -> bool:
	if not Presentation.FOOD_EFFECTS.has(kind): return false
	var effect: Array=Presentation.FOOD_EFFECTS[kind]
	match String(effect[0]):
		"item_effect_heal": game.heal_player(int(effect[1]))
		"item_effect_heal_energy":
			game.heal_player(int(effect[1])); game.energy=mini(game.energy+int(effect[2]),game.SkillSystem.max_stamina(game))
		"item_effect_heal_mana":
			game.heal_player(int(effect[1])); game.player_mana=mini(game.player_mana+int(effect[2]),game.player_max_mana)
		"item_effect_regeneration":
			game.regeneration_timer=maxf(game.regeneration_timer,float(effect[2])); game.regeneration_tick_timer=0
		"item_effect_strength": game.strength_timer=maxf(game.strength_timer,float(effect[2]))
		"item_effect_speed": game.speed_timer=maxf(game.speed_timer,float(effect[2]))
		_: return false
	game.message=game.inventory_item_name(kind)+": "+Presentation.effect_text(game,kind)
	return true
