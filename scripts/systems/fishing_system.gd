extends RefCounted

static func is_near_water(game: Node) -> bool:
	return game.current_location == "overworld" and (game.player.distance_to(game.pond_position) < 235.0 or game.player.y > 800.0)

static func use_rod(game: Node) -> bool:
	if not game.has_fishing_rod: game.message = game.LocaleSystem.text("fish_no_rod"); return false
	if not is_near_water(game): game.message = game.LocaleSystem.text("fish_need_water"); return false
	if game.fishing_state == "idle":
		game.fishing_state = "casting"; game.fishing_timer = game.SkillSystem.fishing_wait(game); game.message = game.LocaleSystem.text("fish_cast"); return true
	if game.fishing_state == "ready":
		var caught: int = game.SkillSystem.fishing_count(game)
		game.fish += caught; game.fishing_state = "idle"; game.award_xp(4); game.SkillSystem.award_profession_xp(game, "fishing", 5); game.message = game.LocaleSystem.text("fish_caught", [caught]); game.notify_tutorial("fish"); return true
	game.message = game.LocaleSystem.text("fish_wait"); return false

static func update(game: Node, delta: float) -> void:
	if game.fishing_state != "casting": return
	game.fishing_timer -= delta
	if game.fishing_timer <= 0.0: game.fishing_state = "ready"; game.message = game.LocaleSystem.text("fish_bite")
