extends RefCounted

## Рисует динамический верхний HUD, сообщения, мобильные боевые кнопки и их короткие реакции.
static func draw(game: Node, ui) -> void:
	ui.draw_hud_background(game)
	draw_menu_button(game, ui, ui.HUD_SKILL_BUTTON, ui.SKILL_BUTTON, game.LocaleSystem.ui("skills"), game.skill_points)
	draw_menu_button(game, ui, ui.HUD_QUEST_BUTTON, ui.QUEST_BUTTON, game.LocaleSystem.ui("quests"), active_quest_count(game))
	var hours := floori(game.game_minutes / 60.0); var minutes := int(game.game_minutes) % 60
	draw_player_portrait(game, ui)
	draw_bar(game, Rect2(187, 13, 274, 18), float(game.player_hp) / game.player_max_hp, "♥ HP", "%d/%d" % [game.player_hp, game.player_max_hp], Color("c94d47"))
	draw_bar(game, Rect2(187, 39, 274, 18), float(game.player_mana) / game.player_max_mana, "◆ MP", "%d/%d" % [game.player_mana, game.player_max_mana], Color("5368c9"))
	var stamina_max: int = game.SkillSystem.max_stamina(game)
	draw_bar(game, Rect2(187, 65, 274, 18), float(game.energy) / stamina_max, "✦ EN", "%d/%d" % [game.energy, stamina_max], Color("d49a32"))
	draw_clock(game, ui, hours, minutes)
	var effects: Array[String] = []
	if game.regeneration_timer > 0.0: effects.append("❤ %.0fs" % game.regeneration_timer)
	if game.strength_timer > 0.0: effects.append("⚔ %.0fs" % game.strength_timer)
	if game.speed_timer > 0.0: effects.append("➜ %.0fs" % game.speed_timer)
	if game.invisibility_timer > 0.0: effects.append("◉ %.0fs" % game.invisibility_timer)
	if game.defense_timer > 0.0: effects.append("◆ %.0fs" % game.defense_timer)
	if not game.active_companions.is_empty(): effects.append(game.LocaleSystem.ui("companion_command", [game.LocaleSystem.ui("companion_command_%s" % game.state.player.companion_command)]))
	game.draw_ui_string(game.UI_FONT, Vector2(695, 42), ui.location_icon(game.current_location), HORIZONTAL_ALIGNMENT_CENTER, 22, 15, Color("6f4325"))
	game.draw_ui_string(game.UI_FONT, Vector2(718, 41), game.WorldSystem.name(game.current_location).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 184, 11, Color("51301c"))
	var coin_pop: float = sin(clampf(game.hud_coin_pop / 0.36, 0.0, 1.0) * PI) * 3.0
	game.draw_ui_string(game.UI_FONT, Vector2(700, 70 - coin_pop), secondary_summary(game), HORIZONTAL_ALIGNMENT_LEFT, 186, 10 + int(coin_pop), Color("7b5226"))
	draw_effect_chips(game, effects)
	if game.state.fishing.phase == game.FishingSystem.PHASE_WAITING: game.draw_ui_string(game.UI_FONT, Vector2(446, 115), "%.1f" % maxf(game.state.fishing.timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 260, 20, Color("d7f6ff"))
	elif game.state.fishing.phase == game.FishingSystem.PHASE_BITE: game.draw_circle(Vector2(576, 105), 20 + sin(Time.get_ticks_msec() / 100.0) * 3, ui.GOLD); game.draw_ui_string(game.UI_FONT, Vector2(566, 112), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 22, Color("47351f"))
	ui.draw_atlas_piece(game, ui.CONTROL_ATLAS, ui.pause_button_rect(game).grow(9), ui.CONTROL_PAUSE_SOURCE)
	if game.touch_controls_visible:
		draw_action_button(game, ui, ui.dodge_button_rect(game), game.LocaleSystem.ui("dodge_short"), game.state.player.dodge_cooldown <= 0.0 and game.energy >= 2, game.state.player.dodge_timer > 0.0, true)
		draw_action_button(game, ui, ui.block_button_rect(game), game.LocaleSystem.ui("block_short"), game.energy > 0, game.state.player.blocking, false)
	ui.draw_hotbar(game)


## Формирует компактную строку монет, репутации и дня рождения без второго календаря внизу экрана.
static func secondary_summary(game: Node) -> String:
	var reputation := int(game.FarmLifeSystem.state(game).reputation)
	var summary := "● %d   ★ %d" % [game.coins, reputation]
	var birthday: String = game.FarmLifeSystem.birthday_npc(game)
	if not birthday.is_empty(): summary += "   🎂 %s" % game.QuestSystem.npc_name(birthday)
	return summary


## Рисует только активные временные эффекты отдельными компактными плашками под верхней панелью.
static func draw_effect_chips(game: Node, effects: Array[String]) -> void:
	var x := 690.0
	for effect in effects:
		var width := clampf(game.UI_FONT.get_string_size(effect, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 18.0, 48.0, 126.0)
		var rect := Rect2(x, 100, width, 20)
		if rect.end.x > 1128.0: break
		game.draw_rect(rect, Color(0.11, 0.07, 0.04, 0.88)); game.draw_rect(rect, Color("b88b42"), false, 1.0)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(8, 14), effect, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 8, Color("ffe7ad"))
		x += width + 6.0


## Рисует портрет героя, редкое моргание, уровень и шкалу опыта.
static func draw_player_portrait(game: Node, ui) -> void:
	var stage: int = game.SkillSystem.hero_skin_stage(game.player_level); var texture: Texture2D = game.DirectionalCharacterSystem.HERO_TEXTURES[stage]
	var source: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.DOWN, 0.0, false)
	source.position += Vector2(source.size.x * 0.22, 0.0); source.size = Vector2(source.size.x * 0.56, source.size.y * 0.62)
	game.draw_texture_rect_region(texture, Rect2(43, 8, 72, 72), source)
	if fmod(Time.get_ticks_msec() / 1000.0, 4.8) > 4.62: game.draw_line(Vector2(65, 40), Vector2(91, 40), Color("513527"), 2.0)
	game.draw_ui_string(game.UI_FONT, Vector2(52, 88), game.LocaleSystem.ui("level_short", [game.player_level]), HORIZONTAL_ALIGNMENT_CENTER, 56, 8, Color("ffe5a0"))
	var needed: int = game.SkillSystem.xp_to_next_character_level(game.player_level)
	game.draw_rect(Rect2(53, 91, 54 * clampf(float(game.player_xp) / needed, 0.0, 1.0), 2), ui.GOLD)


## Рисует одну статусную шкалу и белую вспышку здоровья после полученного урона.
static func draw_bar(game: Node, rect: Rect2, ratio: float, label: String, value: String, color: Color) -> void:
	var flash: float = game.hud_hp_flash / 0.42 if label.begins_with("♥") else 0.0
	var bar_color: Color = Color(color, 0.92).lerp(Color.WHITE, clampf(flash, 0.0, 1.0) * 0.55)
	var trough := Rect2(rect.position + Vector2(53, 5), Vector2(rect.size.x - 61, rect.size.y - 10))
	game.draw_rect(trough, Color("4b2f20")); game.draw_rect(Rect2(trough.position + Vector2.ONE, Vector2((trough.size.x - 2) * clampf(ratio, 0.0, 1.0), trough.size.y - 2)), bar_color)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(4, 14), label, HORIZONTAL_ALIGNMENT_LEFT, 46, 9, Color("5b3821")); game.draw_ui_string(game.UI_FONT, rect.position + Vector2(56, 14), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 65, 9, Color("fff4d0"))


## Рисует календарную карточку с плавной сменой минут и погодной иконки.
static func draw_clock(game: Node, ui, hours: int, minutes: int) -> void:
	var weather: String = game.WorldEventSystem.location_weather(game.day, game.current_location)
	var season: String = game.WorldEventSystem.season(game.day)
	var tick: float = clampf(game.hud_clock_tick / 0.32, 0.0, 1.0); var scale: float = 1.0 + sin(clampf(game.hud_weather_transition / 0.48, 0.0, 1.0) * PI) * 0.12
	var weather_rect: Rect2 = ui.centered_rect(ui.CLOCK_WEATHER_RECT, ui.CLOCK_WEATHER_RECT.size * scale)
	game.draw_texture_rect(ui.weather_icon(weather), weather_rect, false)
	game.draw_ui_string(game.UI_FONT, ui.CLOCK_TIME_RECT.position + Vector2(0, 29 - tick * 2.0), "%02d:%02d" % [hours, minutes], HORIZONTAL_ALIGNMENT_CENTER, ui.CLOCK_TIME_RECT.size.x, 20, Color("4a2c1b"))
	var calendar := "%s  •  %s  •  %s" % [game.LocaleSystem.ui("day_short", [game.day]), game.LocaleSystem.ui("season_" + season), game.LocaleSystem.ui("weather_" + weather)]
	game.draw_ui_string(game.UI_FONT, ui.CLOCK_CALENDAR_RECT.position + Vector2(0, 12), calendar.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, ui.CLOCK_CALENDAR_RECT.size.x, 6, Color("6b4326"))


## Рисует книгу или свиток с наведением, подписью и анимированным бейджем.
static func draw_menu_button(game: Node, ui, texture: Texture2D, rect: Rect2, label: String, badge: int) -> void:
	var hovered := game.is_inside_tree() and rect.has_point(game.get_local_mouse_position()); game.draw_texture_rect(texture, rect.grow(3.0 if hovered else 0.0), false, Color(1.08, 1.04, 0.88) if hovered else Color.WHITE)
	var icon: Texture2D = ui.HUD_SKILL_ICON if rect == ui.SKILL_BUTTON else ui.HUD_QUEST_ICON
	var icon_size := Vector2(50, 62) if rect == ui.SKILL_BUTTON else Vector2(58, 62)
	game.draw_texture_rect(icon, Rect2(rect.get_center() - icon_size * 0.5, icon_size), false)
	if badge > 0:
		var center := rect.position + Vector2(rect.size.x - 15 + sin(Time.get_ticks_msec() / 125.0) * 2.0, 15)
		game.draw_circle(center, 10, Color("c64d35")); game.draw_circle(center, 10, ui.GOLD, false, 2.0); game.draw_ui_string(game.UI_FONT, center + Vector2(-7, 5), str(badge), HORIZONTAL_ALIGNMENT_CENTER, 14, 9, Color.WHITE)
	if hovered:
		var clean := label.get_slice(" • ", 1) if " • " in label else label; game.draw_rect(Rect2(rect.position.x - 4, 98, rect.size.x + 8, 22), Color(0.18, 0.10, 0.05, 0.92)); game.draw_ui_string(game.UI_FONT, Vector2(rect.position.x, 113), clean, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 9, Color("ffe4a2"))


## Подсчитывает активные сюжетные и побочные задания для бейджа свитка.
static func active_quest_count(game: Node) -> int:
	var count := 1 if game.quest_active and not game.quest_complete else 0
	for state in game.mission_states.values():
		if state == "active": count += 1
	return count


## Рисует спрайтовую боевую кнопку в обычном, нажатом или недоступном состоянии.
static func draw_action_button(game: Node, ui, rect: Rect2, label: String, enabled: bool, pressed: bool, dodge: bool) -> void:
	var state_index: int = 2 if not enabled else (1 if pressed else 0); var sources: Array = ui.CONTROL_DODGE_SOURCES if dodge else ui.CONTROL_BLOCK_SOURCES
	ui.draw_atlas_piece(game, ui.CONTROL_ATLAS, rect.grow(8), sources[state_index]); game.draw_ui_string(game.UI_FONT, rect.position + Vector2(2, 47), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4, 8, Color("ffe7ad") if enabled else Color("8f918b"))
	if dodge and game.state.player.dodge_cooldown > 0.0:
		var ratio: float = clampf(game.state.player.dodge_cooldown / 1.15, 0.0, 1.0); game.draw_arc(rect.get_center(), 23, -PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Color(0.12, 0.08, 0.05, 0.78), 5.0)


## Показывает команду взаимодействия в углу экрана, не закрывая выбранный объект.
static func draw_interaction_prompt(game: Node, ui) -> void:
	if game.nearest_interaction().is_empty(): return
	ui.draw_atlas_piece(game, ui.CONTROL_ATLAS, ui.INTERACTION_PROMPT, Rect2(940, 96, 300, 184)); game.draw_ui_string(game.UI_FONT, ui.INTERACTION_PROMPT.position + Vector2(48, 37), game.LocaleSystem.ui("action"), HORIZONTAL_ALIGNMENT_CENTER, 228, 12, Color("4b3424"))
