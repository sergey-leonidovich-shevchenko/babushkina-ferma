extends "res://tests/suites/suite_base.gd"

const Layout := preload("res://scripts/presentation/compact_dialogue_layout.gd")
const Text := preload("res://scripts/systems/dialogue_text_layout_system.gd")
const Renderer := preload("res://scripts/presentation/compact_dialogue_renderer.gd")

## Запускает компактную геометрию, полный текст страниц и реальные действия диалога.
func run() -> void:
	test_compact_geometry_and_localization()
	test_readable_lossless_pages()
	test_long_dialogue_decision_after_pages()
	test_pointer_gift_and_close()

## Сценарий: компактный диалог сохраняет читаемые действия на всех языках и форматах экрана.
## Исходное состояние: шесть локалей, масштаб текста120%, один–четыре ответа и физические экраны от FullHD до4K.
## Ожидаемый результат: окно занимает меньше21% кадра, действия и подписи не пересекаются и находятся внутри окна.
func test_compact_geometry_and_localization() -> void:
	var game:=make_game(); game.settings_state.text_scale=1.2
	expect(Layout.WINDOW.get_area()/(1152.0*648)<0.21,"compact dialogue occupies under21percent of the design frame")
	for count in range(1,5):
		for index in count:
			var rect:=Layout.choice_rect(index,count)
			expect(Layout.WINDOW.encloses(rect) and rect.size.y>=44 and Layout.choice_at(rect.get_center(),count)==index,"choice is contained and touchable")
			expect(not rect.intersects(Layout.GIFT) and not rect.intersects(Layout.BODY),"choice does not overlap gift or text")
			if index>0: expect(not rect.intersects(Layout.choice_rect(index-1,count)),"choices do not overlap each other")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		for key in ["next","gift","help"]:
			var label:=Renderer.word(game,key); var rect:=Layout.HELP if key=="help" else Layout.GIFT.grow(-6)
			var size:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,label,rect.size.x,rect.size.y,9 if key=="help" else 13)
			expect(not label.is_empty() and game.UI_FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=rect.size.x,"localized compact control fits: "+locale+key)
	for screen in [Vector2(1920,1080),Vector2(2560,1600),Vector2(3440,1440),Vector2(3840,2160)]:
		var position:Vector2=game.UiScaleSystem.design_to_screen(Layout.GIFT.get_center(),screen)
		expect(Layout.GIFT.has_point(game.UiScaleSystem.screen_to_design(position,screen)),"physical pointer maps back into its visible control")
	game.free()

## Сценарий: длинный рассказ и слово без пробелов разбиваются на страницы, сохраняя выбранный размер текста.
## Исходное состояние: русские и китайские предложения, пустая реплика, переносы строк и длинное немецкое слово.
## Ожидаемый результат: страницы дают исходный текст дословно, каждый фрагмент помещается по обеим осям, повторный кадр использует кэш.
func test_readable_lossless_pages() -> void:
	var game:=make_game()
	for scale in [0.9,1.0,1.2]:
		game.settings_state.text_scale=scale
		for text in ["",("Привет, путник! Эта история должна остаться полностью читаемой.\n").repeat(24),"工匠在月光下收集材料并修复村庄的桥梁。".repeat(35),"Donaudampfschifffahrtsgesellschaft".repeat(30)]:
			game.state.player.adventure_ui.dialogue={"text":text,"page":0,"revealed":99999}
			var packet:=Text.layout(game); var combined:=""
			for page in packet.pages:
				combined+=page.text
				var measured:Vector2=game.UI_FONT.get_multiline_string_size(page.text,HORIZONTAL_ALIGNMENT_LEFT,Layout.BODY.size.x,int(packet.size))
				expect(measured.x<=Layout.BODY.size.x+0.01 and measured.y<=Layout.BODY.size.y+0.01,"every readable page fits without font shrinking")
			expect(combined==text and int(packet.size)==roundi(Layout.BODY_SIZE*scale),"page boundaries preserve every character and text scale")
			expect(Text.layout(game)==packet,"repeated frame reuses text layout")
	game.free()

## Сценарий: длинное поручение сначала дочитывается, затем принимается или отклоняется.
## Исходное состояние: задание Мирона доступно, реплика растянута на несколько страниц, у героя нет активного решения.
## Ожидаемый результат: Enter и клик по Далее меняют страницу без награды; только последний ответ меняет статус миссии.
func test_long_dialogue_decision_after_pages() -> void:
	var game:=make_game(); game.mission_states.story_relic=game.QuestSystem.AVAILABLE
	game.AdventurePolishSystem.open_quest_dialogue(game,"miron")
	var dialogue:Dictionary=game.state.player.adventure_ui.dialogue
	dialogue.text="Длинный рассказ о долине, мосте и ремесле. ".repeat(24); dialogue.revealed=99999
	var total:int=Text.layout(game).pages.size(); expect(total>1,"long dialogue really has multiple pages")
	for page in range(total-1):
		var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=Layout.choice_rect(0,1).get_center()
		game.AdventurePolishSystem.handle_input(game,touch)
		expect(Text.page_index(game)==page+1 and game.mission_states.story_relic==game.QuestSystem.AVAILABLE,"next page cannot implicitly accept a quest")
	game.AdventurePolishSystem.handle_input(game,key_event(KEY_ENTER,KEY_ENTER,true))
	expect(game.mission_states.story_relic==game.QuestSystem.ACTIVE and not game.state.player.adventure_ui.dialogue_open,"final confirmation accepts quest exactly once")
	game.AdventurePolishSystem.open_quest_dialogue(game,"miron"); game.state.player.adventure_ui.dialogue.text=dialogue.text; game.state.player.adventure_ui.dialogue.page=0
	game.AdventurePolishSystem.handle_input(game,key_event(KEY_ESCAPE,KEY_ESCAPE,true))
	expect(not game.state.player.adventure_ui.dialogue_open,"escape closes any page without another quest action")
	game.free()

## Сценарий: кнопки подарка и закрытия работают так же, как клавиатурные команды.
## Исходное состояние: в горячем слоте две ягоды; короткая беседа с Мироном открыта поверх остановленного мира.
## Ожидаемый результат: подарок забирает одну ягоду и повышает дружбу, крестик закрывает диалог без принятия задания.
func test_pointer_gift_and_close() -> void:
	var game:=make_game(); game.change_inventory_count("berries",2); game.hotbar_slots[0]="berries"; game.selected_hotbar=0
	game.AdventurePolishSystem.open_quest_dialogue(game,"miron")
	var minute:float=game.game_minutes; var hp:int=game.player_hp; var position:Vector2=game.player
	game._physics_process(0.75)
	expect(game.game_minutes==minute and game.player_hp==hp and game.player==position,"compact dialogue retains the world pause and hero safety")
	var mouse:=InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=true; mouse.position=Layout.GIFT.get_center()
	game.AdventurePolishSystem.handle_input(game,mouse)
	expect(game.inventory_item_count("berries")==1 and game.state.player.relationships.miron==8 and game.AdventurePolishSystem.has_modal(game),"gift click spends one edible item and keeps conversation open")
	var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=Layout.CLOSE.get_center(); game.AdventurePolishSystem.handle_input(game,touch)
	expect(not game.state.player.adventure_ui.dialogue_open,"close touch exits the dialogue")
	game.free()
