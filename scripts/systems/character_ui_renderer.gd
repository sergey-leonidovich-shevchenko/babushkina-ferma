class_name CharacterUiRenderer
extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")

const PROFILE_PANEL := Rect2(48, 104, 264, 480)
const HERO_FRAME := Rect2(88, 116, 184, 126)
const COMMAND_BUTTON := Rect2(66, 542, 228, 34)
const COMPANION_RECTS := [Rect2(70, 486, 54, 54), Rect2(153, 486, 54, 54), Rect2(236, 486, 54, 54)]
const TEXT := {
	"character":["ГЕРОЙ","HERO","HÉROE","HELD","HÉROS","角色"],
	"effects":["ЭФФЕКТЫ","EFFECTS","EFECTOS","EFFEKTE","EFFETS","效果"],
	"none":["нет активных","none active","sin efectos","keine aktiv","aucun actif","无"],
	"companions":["НАПАРНИКИ","COMPANIONS","COMPAÑEROS","GEFÄHRTEN","COMPAGNONS","同伴"],
	"damage":["УРОН","DMG","DAÑO","SCHADEN","DÉGÂTS","伤害"],
	"defense":["ЗАЩ","DEF","DEF","ABWEHR","DÉF","防御"],
	"speed":["СКОР","SPD","VEL","TEMPO","VIT","速度"],
}


## Рисует постоянную карточку героя: портрет, ресурсы, боевые параметры, эффекты и действующую группу.
static func draw(game: Node2D) -> void:
	UiKitSystem.draw_panel(game, PROFILE_PANEL, false)
	game.draw_ui_string(game.UI_FONT, Vector2(72, 129), word(game, "character"), HORIZONTAL_ALIGNMENT_LEFT, 210, 13, Color("fff0cf"))
	game.draw_texture_rect(UiKitSystem.texture("portrait_frame"), HERO_FRAME, false)
	draw_hero_portrait(game, HERO_FRAME.grow(-18))
	var profile: Dictionary = game.state.player.profile
	game.draw_ui_string(game.UI_FONT, Vector2(68, 262), String(profile.get("name", "Герой")), HORIZONTAL_ALIGNMENT_CENTER, 224, 17, UiKitSystem.COLORS.text_light)
	game.draw_ui_string(game.UI_FONT, Vector2(68, 282), game.AdventurePolishRenderer.specialization_name(game, String(profile.get("specialization", "farmer"))), HORIZONTAL_ALIGNMENT_CENTER, 224, 10, Color("e4c686"))
	draw_xp(game)
	draw_resources(game)
	draw_stats(game)
	draw_effects(game)
	draw_companions(game)


## Рисует спокойный фронтальный кадр фактического возрастного облика героя без мировой камеры и тени.
static func draw_hero_portrait(game: Node2D, rect: Rect2) -> void:
	var stage: int = game.SkillSystem.hero_skin_stage(game.player_level)
	var texture: Texture2D = game.DirectionalCharacterSystem.HERO_TEXTURES[stage]
	var source: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.DOWN, 0.0, false)
	var destination := UiKitSystem.centered_content_rect(rect, Vector2(98, 112), 0)
	game.draw_texture_rect_region(texture, destination, source)


## Показывает общий уровень и прогресс до следующего очка развития в единой художественной шкале.
static func draw_xp(game: Node2D) -> void:
	var needed: int = game.SkillSystem.xp_to_next_character_level(game.player_level)
	var maximum: bool = game.player_level >= game.SkillSystem.MAX_CHARACTER_LEVEL
	var ratio := 1.0 if maximum else clampf(float(game.player_xp) / maxi(1, needed), 0.0, 1.0)
	UiKitSystem.draw_progress(game, Rect2(68, 287, 224, 30), ratio, Color("799750"))
	var label := "УР. %d  •  MAX" % game.player_level if maximum else "УР. %d  •  XP %d/%d" % [game.player_level, game.player_xp, needed]
	game.draw_ui_string(game.UI_FONT, Vector2(80, 307), label, HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color("fff0cf"))


## Рисует здоровье, ману и энергию одинаковыми компактными шкалами с точными значениями.
static func draw_resources(game: Node2D) -> void:
	var values := [
		["♥", game.player_hp, game.player_max_hp, Color("bd5148")],
		["◆", game.player_mana, game.player_max_mana, Color("536bc2")],
		["✦", game.energy, game.SkillSystem.max_stamina(game), Color("c58d32")],
	]
	for index in values.size():
		var row: Array = values[index]
		var rect := Rect2(68, 320 + index * 30, 224, 28)
		UiKitSystem.draw_progress(game, rect, float(row[1]) / maxi(1, int(row[2])), row[3])
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(13, 19), "%s  %d/%d" % [row[0], row[1], row[2]], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 26, 9, Color("fff0cf"))


## Собирает итоговые боевые величины из экипировки, профессий, талантов и временных усилений.
static func draw_stats(game: Node2D) -> void:
	var damage: int = 1 + game.InventorySystem.damage_bonus(game) + game.TalentSystem.combat_damage_bonus(game) + (1 if game.strength_timer > 0.0 else 0)
	var defense: int = maxi(0, 10 - game.InventorySystem.incoming_damage(game, 10)) + game.CompanionSystem.defense_bonus(game)
	var speed := roundi((game.InventorySystem.speed_multiplier(game) * game.TalentSystem.movement_multiplier(game) - 1.0) * 100.0)
	var stats := [["damage", damage], ["defense", defense], ["speed", "%+d%%" % speed]]
	for index in stats.size():
		var rect := Rect2(68 + index * 75, 412, 70, 28)
		UiKitSystem.draw_nine_patch(game, "badge", rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(4, 18), "%s %s" % [word(game, stats[index][0]), stats[index][1]], HORIZONTAL_ALIGNMENT_CENTER, 62, 8, Color("68432a"))


## Показывает до пяти активных временных эффектов символами и оставшимися секундами.
static func draw_effects(game: Node2D) -> void:
	game.draw_ui_string(game.UI_FONT, Vector2(70, 456), word(game, "effects"), HORIZONTAL_ALIGNMENT_LEFT, 100, 9, Color("e9cf96"))
	var effects := effect_entries(game)
	if effects.is_empty():
		game.draw_ui_string(game.UI_FONT, Vector2(158, 456), word(game, "none"), HORIZONTAL_ALIGNMENT_RIGHT, 132, 8, Color("a99778"))
		return
	for index in effects.size():
		var rect := Rect2(174 + index * 23, 442, 22, 22)
		UiKitSystem.draw_nine_patch(game, "badge", rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(1, 15), String(effects[index][0]), HORIZONTAL_ALIGNMENT_CENTER, 20, 8, Color("633c28"))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(-1, 28), "%.0f" % float(effects[index][1]), HORIZONTAL_ALIGNMENT_CENTER, 24, 7, Color("fff0cf"))


## Возвращает непустой список активных усилений в стабильном порядке интерфейса.
static func effect_entries(game: Node) -> Array:
	var result := []
	for entry in [["⚔", game.strength_timer], ["♥", game.regeneration_timer], ["➜", game.speed_timer], ["◉", game.invisibility_timer], ["◆", game.defense_timer]]:
		if float(entry[1]) > 0.0: result.append(entry)
	return result


## Рисует три слота напарников настоящими спрайтами и общую кнопку тактического приказа.
static func draw_companions(game: Node2D) -> void:
	game.draw_ui_string(game.UI_FONT, Vector2(70, 482), "%s  %d/%d" % [word(game, "companions"), game.active_companions.size(), game.CompanionSystem.capacity(game)], HORIZONTAL_ALIGNMENT_LEFT, 220, 9, Color("e9cf96"))
	var companion_ids: Array = game.CompanionSystem.COMPANIONS.keys()
	for index in COMPANION_RECTS.size():
		var companion_id := String(companion_ids[index])
		var active: bool = companion_id in game.active_companions
		var content := UiKitSystem.draw_slot(game, COMPANION_RECTS[index], active)
		draw_companion_portrait(game, companion_id, content)
		if companion_id not in game.recruited_companions: game.draw_rect(COMPANION_RECTS[index].grow(-5), Color(0.08, 0.07, 0.06, 0.55))
	UiKitSystem.draw_button(game, COMMAND_BUTTON, false, not game.active_companions.is_empty(), game.settings_state.reduced_motion)
	var command := String(game.state.player.companion_command).to_upper()
	game.draw_ui_string(game.UI_FONT, COMMAND_BUTTON.position + Vector2(10, 23), "L1 / C  •  %s" % command, HORIZONTAL_ALIGNMENT_CENTER, COMMAND_BUTTON.size.x - 20, 9, UiKitSystem.COLORS.text_light)


## Вырезает фронтальный кадр выбранного напарника и центрирует его внутри самостоятельного слота.
static func draw_companion_portrait(game: Node2D, companion_id: String, rect: Rect2) -> void:
	var texture: Texture2D = game.DirectionalCharacterSystem.COMPANION_TEXTURES[companion_id]
	var source: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.DOWN, 0.0, false)
	game.draw_texture_rect_region(texture, UiKitSystem.centered_content_rect(rect, Vector2(38, 42), 0), source)


## Возвращает короткий перевод подписи карточки персонажа для активного языка.
static func word(game: Node, key: String) -> String:
	return String(TEXT.get(key, [key, key, key, key, key, key])[game.LocaleSystem.index()])
