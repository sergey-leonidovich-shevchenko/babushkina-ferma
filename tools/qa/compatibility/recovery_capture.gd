extends "res://tools/qa/compatibility/paper_theme_capture.gd"

var legacy:=false
var legacy_canvas:LegacyCanvas

class LegacyCanvas extends Node2D:
	var UI_FONT:Font
	## Передаёт подпись реального компонента редактора на отдельное контрольное полотно.
	func draw_ui_string(font:Font,point:Vector2,label:String,alignment:HorizontalAlignment,width:float,size:int,color:Color) -> void:
		draw_string(font,point,label,alignment,width,size,color)

## Снимает автоматическое восстановление и семейства интерфейса в отдельном профиле без слотов игрока.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Recovery-Review-20261014")
	folder="/private/tmp/moon-valley-recovery/"; DirAccess.make_dir_recursive_absolute(folder)
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport); current_scene=container
	for label in ["recovery","recovery-de-120","recovery-moving","recovery-expired","inventory","cabinet","storage","crafting","kitchen","alchemy","study","furnace","shop","forge","quest-log","talent-tree","world-map","calendar","bestiary","recipes","compendium","creation","dialogue","dialogue-long","basement","basement-placement","apiary","contracts","fishing","pause","settings","language","title","inventory-de-120","cabinet-de-120","legacy-surfaces"]:
		var only:=OS.get_environment("FARM_RECOVERY_ONLY")
		if not only.is_empty() and label not in only.split(","): continue
		if is_instance_valid(game): game.free()
		game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game)
		game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
		legacy=label=="legacy-surfaces"
		configure("hud" if label.begins_with("recovery") or legacy else label)
		if label.begins_with("recovery"):
			if label=="recovery-de-120": game.LocaleSystem.set_locale("de"); game.settings_state.text_scale=1.2
			game.current_location="cave"; game.player=preload("res://scripts/systems/cave_layout_system.gd").safe_start("cave")+Vector2(96,0)
			game.sync_background_location(); game.update_camera(); game.coins=20; game.player_hp=1
			game.CombatSystem.damage_player(game,999,game.LocaleSystem.entity("cave_guardian"))
			if label=="recovery-moving":
				var event:=InputEventKey.new(); event.keycode=KEY_D; event.physical_keycode=KEY_D; event.pressed=true
				game._input(event); game._physics_process(0.2)
			if label=="recovery-expired": preload("res://scripts/systems/recovery_system.gd").update(game,8)
		if legacy:
			game.hide(); legacy_canvas=LegacyCanvas.new(); legacy_canvas.UI_FONT=game.UI_FONT
			viewport.add_child(legacy_canvas); legacy_canvas.draw.connect(_draw_legacy)
		for _frame in 5:
			game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
			if legacy: legacy_canvas.queue_redraw()
			await process_frame; RenderingServer.force_draw()
		if viewport.get_texture().get_image().save_png(folder+label+".png")!=OK: push_error("Не сохранён кадр "+label)
		print("RECOVERY FRAME: "+label)
	print("RECOVERY CAPTURE: PASS"); quit()

## Показывает прежние API панелей и карточек в новой гладкой теме без старых деревянных PNG.
func _draw_legacy() -> void:
	if not legacy: return
	var kit:=preload("res://scripts/systems/ui_kit_system.gd"); var style:=preload("res://scripts/presentation/moon_theme.gd")
	legacy_canvas.draw_rect(Rect2(0,0,1152,648),style.BACKGROUND)
	legacy_canvas.draw_string(game.UI_FONT,Vector2(24,48),"Светлый интерфейс · совместимые компоненты",HORIZONTAL_ALIGNMENT_LEFT,1104,24,style.TEXT)
	var index:=0
	for kind in kit.TEXTURES:
		var rect:=Rect2(24+(index%5)*224,80+(index/5)*128,208,108)
		legacy_canvas.draw_style_box(kit.style(kind),rect)
		legacy_canvas.draw_string(game.UI_FONT,rect.position+Vector2(8,58),kind,HORIZONTAL_ALIGNMENT_CENTER,192,11,style.TEXT)
		index+=1
	preload("res://scripts/presentation/hud_chrome_system.gd").draw_panel(legacy_canvas,Rect2(24,602,208,28))
	preload("res://scripts/systems/debug_ui_kit_system.gd").draw_button(legacy_canvas,Rect2(248,592,48,48),"R",true,true,true)
	preload("res://scripts/systems/debug_ui_kit_system.gd").draw_catalog_row(legacy_canvas,Rect2(312,592,48,48),false,true)
