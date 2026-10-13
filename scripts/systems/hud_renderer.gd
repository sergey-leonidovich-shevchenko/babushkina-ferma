extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")
const Paper := preload("res://scripts/presentation/paper_theme_palette.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const Chrome := preload("res://scripts/presentation/hud_chrome_system.gd")

## Рисует динамический верхний HUD, сообщения, мобильные боевые кнопки и их короткие реакции.
static func draw(game: Node, _ui) -> void:
	preload("res://scripts/presentation/moon_hud_renderer.gd").draw(game)


## Формирует компактную строку монет, репутации и дня рождения без второго календаря внизу экрана.
static func secondary_summary(game: Node) -> String:
	var reputation := int(game.FarmLifeSystem.state(game).reputation)
	var summary := "● %d   ★ %d" % [game.coins, reputation]
	var birthday: String = game.FarmLifeSystem.birthday_npc(game)
	if not birthday.is_empty(): summary += "   🎂 %s" % game.QuestSystem.npc_name(birthday)
	return summary


## Рисует только активные временные эффекты отдельными компактными плашками под верхней панелью.
static func draw_effect_chips(game: Node, effects: Array[String]) -> void:
	var lane := HudLayoutSystem.EFFECTS_RECT; var x := lane.position.x; var y := lane.position.y
	for effect in effects:
		var width := clampf(game.UI_FONT.get_string_size(effect, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 18.0, 48.0, 126.0)
		if x+width>lane.end.x: x=lane.position.x; y+=24.0
		var rect := Rect2(x,y,width,20)
		if rect.end.y>lane.end.y: break
		Style.panel(game,rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(8, 14), effect, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 8, Paper.TEXT)
		x += width + 6.0


## Рисует портрет героя, редкое моргание, уровень и шкалу опыта.
static func draw_player_portrait(game: Node, ui) -> void:
	game.DirectionalCharacterSystem.HeroVisualSystem.draw_portrait(game, Chrome.PORTRAIT_IMAGE, true)
	Chrome.draw_text(game, Chrome.LEVEL, game.LocaleSystem.ui("level_short", [game.player_level]), 8, Chrome.TEXT)
	var needed: int = game.SkillSystem.xp_to_next_character_level(game.player_level)
	game.draw_rect(Chrome.EXPERIENCE, Color("34281c"))
	game.draw_rect(Rect2(Chrome.EXPERIENCE.position, Vector2(Chrome.EXPERIENCE.size.x * clampf(float(game.player_xp) / needed, 0.0, 1.0), 2)), ui.GOLD)


## Рисует одну статусную шкалу и белую вспышку здоровья после полученного урона.
static func draw_bar(game: Node, rect: Rect2, ratio: float, label: String, value: String, color: Color) -> void:
	var flash: float = game.hud_hp_flash / 0.42 if label=="HP" else 0.0
	var bar_color: Color = Color(color, 0.92).lerp(Color.WHITE, clampf(flash, 0.0, 1.0) * 0.55)
	var parts := Chrome.stat_parts(rect)
	var trough: Rect2 = parts.track
	var fill := Chrome.fill_rect(trough, ratio)
	game.draw_rect(trough, Color("171d19"))
	game.draw_rect(trough, Color("9c7b45"), false, 1)
	if fill.has_area():
		game.draw_rect(fill, bar_color)
		game.draw_line(fill.position, Vector2(fill.end.x, fill.position.y), bar_color.lightened(0.22), 1)
	Chrome.draw_text(game, parts.label, label, 8, Chrome.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	Chrome.draw_text(game, parts.value, value, 9, Chrome.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)


## Рисует компактные часы с погодой и календарём в отдельных областях; размер картинки не прыгает при смене погоды.
static func draw_clock(game: Node, ui, hours: int, minutes: int) -> void:
	var weather: String = game.WorldEventSystem.location_weather(game.day, game.current_location)
	var season: String = game.WorldEventSystem.season(game.day)
	game.draw_texture_rect(ui.weather_icon(weather), ui.CLOCK_WEATHER_RECT, false)
	Chrome.draw_text(game, ui.CLOCK_TIME_RECT, "%02d:%02d" % [hours, minutes], 20)
	var calendar := "%s  •  %s" % [game.LocaleSystem.ui("day_short", [game.day]), game.LocaleSystem.ui("season_" + season)]
	Chrome.draw_text(game, ui.CLOCK_CALENDAR_RECT, calendar, 9, Chrome.MUTED)


## Рисует книгу или свиток с наведением, подписью и анимированным бейджем.
static func draw_menu_button(game: Node, ui, _texture: Texture2D, rect: Rect2, label: String, badge: int) -> void:
	var hovered := game.is_inside_tree() and rect.has_point(game.get_local_mouse_position())
	UiKitSystem.draw_slot(game,rect,hovered)
	var icon: Texture2D = ui.HUD_SKILL_ICON if rect == ui.SKILL_BUTTON else ui.HUD_QUEST_ICON
	var icon_size := Vector2(24, 28) if rect == ui.SKILL_BUTTON else Vector2(27, 28)
	game.draw_texture_rect(icon, Rect2(rect.get_center() - icon_size * 0.5 - Vector2(0, 2), icon_size), false)
	if badge > 0:
		var center := rect.position + Vector2(rect.size.x-6,6)
		game.draw_circle(center,8,Color("8b4530")); game.draw_circle(center,8,ui.GOLD,false,1.0); game.draw_ui_string(game.UI_FONT,center+Vector2(-7,3),str(badge),HORIZONTAL_ALIGNMENT_CENTER,14,8,Color.WHITE)
	Chrome.draw_text(game, Rect2(rect.position + Vector2(5, 32), Vector2(12, 11)), "K" if rect == ui.SKILL_BUTTON else "J", 8, Color("493320"))
	if hovered:
		var clean := label.get_slice(" • ", 1) if " • " in label else label
		var tooltip := Rect2(rect.end.x-120, 76, 120, 25)
		draw_quiet_panel(game, tooltip)
		Chrome.draw_text(game, tooltip.grow(-4), clean, 10)


## Рисует спокойную древесную плашку с тонкой латунной кромкой и мягкой тенью для вторичной информации.
static func draw_quiet_panel(game: Node, rect: Rect2) -> void:
	Style.panel(game,rect)


## Подсчитывает активные сюжетные и побочные задания для бейджа свитка.
static func active_quest_count(game: Node) -> int:
	var count := 1 if game.quest_active and not game.quest_complete else 0
	for state in game.mission_states.values():
		if state == "active": count += 1
	return count


## Рисует спрайтовую боевую кнопку в обычном, нажатом или недоступном состоянии.
static func draw_action_button(game: Node, ui, rect: Rect2, label: String, enabled: bool, pressed: bool, dodge: bool) -> void:
	Style.panel(game,rect,Paper.SELECTED if pressed else Paper.PANEL,Paper.ACCENT_TEXT if pressed else Paper.EDGE)
	Style.text(game,rect.grow(-4),("↗  " if dodge else "◆  ")+label,10,Paper.TEXT if enabled else Paper.DISABLED,HORIZONTAL_ALIGNMENT_CENTER)
	if dodge and game.state.player.dodge_cooldown > 0.0:
		var ratio: float = clampf(game.state.player.dodge_cooldown / 1.15, 0.0, 1.0); game.draw_arc(rect.get_center(), 23, -PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Color(0.12, 0.08, 0.05, 0.78), 5.0)


## Рисует единственную приоритетную цель с прямой ссылкой на полный журнал заданий.
static func draw_objective_card(game: Node) -> void:
	var objective: Dictionary = HudLayoutSystem.primary_objective(game)
	if objective.is_empty(): return
	var rect := HudLayoutSystem.objective_rect(game)
	UiKitSystem.draw_nine_patch(game, "tooltip", rect)
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(18,26),"◆",HORIZONTAL_ALIGNMENT_LEFT,20,11,Color("8a542e"))
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(38,26),String(objective.title),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-78,11,Color("75472c"))
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(rect.size.x-32,26),"J",HORIZONTAL_ALIGNMENT_CENTER,16,10,Color("876440"))
	game.draw_line(rect.position+Vector2(18,33),Vector2(rect.end.x-18,rect.position.y+33),Color(0.48,0.32,0.17,0.28),1)
	game.draw_ui_multiline_string(game.UI_FONT,rect.position+Vector2(18,51),String(objective.text),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-36,rect.size.y-61,12,3,UiKitSystem.COLORS.ink)
	var ratio := float(objective.get("ratio", -1.0))
	if ratio>0.0: UiKitSystem.draw_progress(game,Rect2(rect.position+Vector2(18,rect.size.y-11),Vector2(rect.size.x-36,4)),ratio,Color("719451"))


## Показывает команду взаимодействия в углу экрана, не закрывая выбранный объект.
static func draw_interaction_prompt(game: Node, ui) -> void:
	if game.BasementSystem.modal(game): return
	if game.inventory_open or game.shop_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open or game.AdventurePolishSystem.has_modal(game): return
	var interaction: String = game.nearest_interaction()
	if interaction.is_empty(): return
	var rect := HudLayoutSystem.interaction_rect(game)
	preload("res://scripts/presentation/moon_theme.gd").panel(game,rect)
	preload("res://scripts/presentation/moon_theme.gd").text(game,rect.grow(-6),HudLayoutSystem.interaction_label(game,interaction),12,preload("res://scripts/presentation/moon_theme.gd").TEXT,HORIZONTAL_ALIGNMENT_CENTER)
