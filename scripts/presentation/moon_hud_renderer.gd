extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const Clock := preload("res://scripts/presentation/celestial_clock_renderer.gd")
const Hub := preload("res://scripts/systems/menu_hub_system.gd")
const Quick := preload("res://scripts/presentation/quick_access_renderer.gd")
const STATUS := Rect2(18,14,220,70)
const HEALTH := Rect2(30,41,196,8)
const HEALTH_LABEL := Rect2(30,20,90,18)
const HEALTH_VALUE := Rect2(130,20,96,18)
const MANA := Rect2(30,72,92,3)
const STAMINA := Rect2(134,72,92,3)
const CLOCK := Rect2(950,14,128,116)
const COINS := Rect2(250,18,96,24)
const LOCATION := Rect2(364,17,488,25)

## Обновляет только визуальное здоровье, сохраняя числовое HP и мир независимыми от анимации шкалы.
static func update(game: Node, delta: float) -> void:
	var state: Dictionary = game.get_meta("moon_health",{"display":float(game.player_hp),"trail":float(game.player_hp),"last":game.player_hp,"wait":0.0,"heal":0.0})
	if game.player_hp<int(state.last): state.wait=0.35
	if game.player_hp>int(state.last): state.heal=0.65
	state.last=game.player_hp
	state.wait=maxf(0,float(state.wait)-delta); state.heal=maxf(0,float(state.heal)-delta)
	var factor := 1.0-exp(-delta*13.0)
	state.display=lerpf(float(state.display),float(game.player_hp),factor)
	if float(state.wait)<=0: state.trail=lerpf(float(state.trail),float(game.player_hp),1.0-exp(-delta*5.0))
	if game.settings_state.reduced_motion: state.display=float(game.player_hp); state.trail=float(game.player_hp); state.heal=0.0
	game.set_meta("moon_health",state)

## Рисует компактные ресурсы без портрета и небесный знак без цифровых часов.
static func draw(game: Node) -> void:
	MoonStyle.panel(game,STATUS)
	MoonStyle.text(game,HEALTH_LABEL,"HP",MoonStyle.LABEL_SIZE,Color("e4b5a5"))
	MoonStyle.text(game,HEALTH_VALUE,"%d / %d"%[game.player_hp,game.player_max_hp],MoonStyle.LABEL_SIZE,MoonStyle.TEXT,HORIZONTAL_ALIGNMENT_RIGHT)
	var health: Dictionary = game.get_meta("moon_health",{"display":float(game.player_hp),"trail":float(game.player_hp),"heal":0.0})
	game.draw_rect(HEALTH,MoonStyle.INSET)
	game.draw_rect(Rect2(HEALTH.position,Vector2(HEALTH.size.x*clampf(float(health.trail)/game.player_max_hp,0,1),HEALTH.size.y)),Color("d9bb7a"))
	var color := Color("d18570") if game.player_hp>game.player_max_hp*0.25 else Color("c75b53")
	color=color.lerp(Color("b1ce8d"),float(health.heal)/0.65)
	game.draw_rect(Rect2(HEALTH.position,Vector2(HEALTH.size.x*clampf(float(health.display)/game.player_max_hp,0,1),HEALTH.size.y)),color)
	draw_resource(game,MANA,float(game.player_mana)/game.player_max_mana,Color("81aec0"),"MP",game.player_mana)
	draw_resource(game,STAMINA,float(game.energy)/game.SkillSystem.max_stamina(game),Color("cbbd7a"),"EN",game.energy)
	MoonStyle.text(game,COINS,"● %d"%game.coins,MoonStyle.LABEL_SIZE,MoonStyle.ACCENT)
	MoonStyle.text(game,LOCATION,game.WorldSystem.name(game.current_location),MoonStyle.LABEL_SIZE,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Clock.draw(game,CLOCK)
	MoonStyle.button(game,Hub.OPEN_BUTTON,"☰")
	MoonStyle.text(game,Rect2(1092,62,38,14),"Tab",MoonStyle.HINT_SIZE,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Quick.draw_world(game)
	MoonStyle.button(game,game.InterfaceRenderer.pause_button_rect(game),"Ⅱ")
	game.InterfaceRenderer.HudRenderer.draw_effect_chips(game,effect_labels(game))
	if game.touch_controls_visible:
		game.InterfaceRenderer.HudRenderer.draw_action_button(game,game.InterfaceRenderer,game.InterfaceRenderer.dodge_button_rect(game),game.LocaleSystem.ui("dodge_short"),game.energy>=2,false,true)
		game.InterfaceRenderer.HudRenderer.draw_action_button(game,game.InterfaceRenderer,game.InterfaceRenderer.block_button_rect(game),game.LocaleSystem.ui("block_short"),game.energy>0,game.state.player.blocking,false)

## Рисует тонкий ресурс с точным значением в отдельной области, не увеличивая высоту карточки.
static func draw_resource(game: Node, track: Rect2, ratio: float, color: Color, label: String, amount: int) -> void:
	var text_rect := Rect2(track.position-Vector2(0,21),Vector2(track.size.x,18))
	MoonStyle.text(game,Rect2(text_rect.position,Vector2(30,18)),label,MoonStyle.LABEL_SIZE,color)
	MoonStyle.text(game,Rect2(text_rect.position+Vector2(32,0),Vector2(text_rect.size.x-32,18)),str(amount),MoonStyle.LABEL_SIZE,MoonStyle.TEXT,HORIZONTAL_ALIGNMENT_RIGHT)
	game.draw_rect(track,MoonStyle.INSET)
	game.draw_rect(Rect2(track.position,Vector2(track.size.x*clampf(ratio,0,1),track.size.y)),color)

## Показывает временные эффекты только пока они действуют, оставляя остальную область мира свободной.
static func effect_labels(game: Node) -> Array[String]:
	var labels: Array[String] = []
	for effect in [[game.regeneration_timer,"❤"],[game.strength_timer,"⚔"],[game.speed_timer,"➜"],[game.defense_timer,"◆"],[game.invisibility_timer,"◉"]]:
		if float(effect[0])>0: labels.append("%s %.0fs"%[effect[1],effect[0]])
	for effect in [["repellent","✦"],["mining","⛏"]]:
		var remaining:float=game.CraftingSystem.Alchemy.remaining(game,effect[0])
		if remaining>0: labels.append("%s %.0fs"%[effect[1],remaining])
	return labels
