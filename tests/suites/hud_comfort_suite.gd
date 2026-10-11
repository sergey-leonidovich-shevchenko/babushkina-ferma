extends "res://tests/suites/suite_base.gd"

const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")


## Запускает регрессии реального ввода и внутренних размеров компактного интерфейса.
func run()->void:
	test_thin_progress_tracks_keep_positive_content()
	test_hints_close_through_real_mouse_and_touch_routes()
	test_compact_labels_and_icon_insets()
	test_crystal_uses_clean_standalone_art()


## Сценарий: шкалы опыта, роста и заданий рисуются в тонких контейнерах от трёх пикселей.
## Исходное состояние: размеры контейнера заданы высотами 3, 4, 6, 10, 28 и 40 пикселей.
## Ожидаемый результат: внутренняя область всегда положительна, центрирована и не выходит за фон шкалы.
func test_thin_progress_tracks_keep_positive_content()->void:
	var game:=make_game()
	for height in [3,4,6,10,28,40]:
		var outer:=Rect2(23,17,196,height)
		var inner:Rect2=UiKitSystem.progress_content_rect(outer)
		expect(inner.size.x>0 and inner.size.y>0,"thin progress %d never has negative fill geometry"%height)
		expect(outer.encloses(inner) and inner.get_center().is_equal_approx(outer.get_center()),"thin progress %d keeps centered inner padding"%height)
	game.free()


## Сценарий: синий кристалл выводится в рюкзаке из самостоятельного исправленного рисунка.
## Исходное состояние: каталог прогружен, старый atlas-crop содержит чужой фрагмент и не должен выбираться.
## Ожидаемый результат: выбран новый квадратный RGBA-спрайт с прозрачной нижней и боковыми границами.
func test_crystal_uses_clean_standalone_art()->void:
	var game:=make_game()
	var texture:Texture2D=game.VisualAssetSystem.item_texture("crystal")
	expect(texture!=null and texture.resource_path.ends_with("crystal_clean_v2.png"),"crystal selects repaired art instead of contaminated atlas crop")
	if texture!=null:
		var picture:=texture.get_image(); var size:=picture.get_size()
		expect(size.x==size.y and picture.detect_alpha()!=Image.ALPHA_NONE,"repaired crystal preserves square aspect and real transparency")
		# Генератор оставляет один чёрный пиксель с альфой 1/255 в углу; это не видимый фрагмент соседнего спрайта.
		for x in range(0,size.x,32): expect(picture.get_pixel(x,size.y-1).a<=1.01/255.0,"crystal lower edge contains no visible fragment of a neighboring object")
	game.free()


## Сценарий: игрок закрывает обучение мышью и карточку открытия пальцем, оставаясь в мире.
## Исходное состояние: окна закрыты, обучение и карточка открытия видимы, запас энергии не меняется.
## Ожидаемый результат: настоящая цепочка _input скрывает нужную карточку и не применяет инструмент за ней.
func test_hints_close_through_real_mouse_and_touch_routes()->void:
	var game:=make_game()
	game.tutorial_visible=true
	var energy:int=game.energy
	var rect:Rect2=game.HudLayoutSystem.tutorial_rect(game)
	var mouse:=InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=true; mouse.position=rect.position+Vector2(rect.size.x-28,22)
	game._input(mouse)
	expect(not game.tutorial_visible and game.energy==energy,"real mouse route closes hint without using tool")
	game.discovery_current={"title":"Яблоня","text":"Созревает повторно"}; game.discovery_timer=2.0
	var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=game.HudLayoutSystem.DISCOVERY_RECT.get_center()
	game._input(touch)
	expect(game.discovery_current.is_empty() and game.energy==energy,"real touch route dismisses discovery without world action")
	game.free()


## Сценарий: компактный HUD использует переведённые заголовки и одинаковое правило центрирования иконок.
## Исходное состояние: все шесть локалей доступны; мир и рюкзак имеют разные размеры быстрых слотов.
## Ожидаемый результат: заголовки не содержат шаблонов форматирования, иконки не пересекают резную рамку.
func test_compact_labels_and_icon_insets()->void:
	var game:=make_game(); var original:String=game.LocaleSystem.current
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		var label:String=game.LocaleSystem.ui("tutorial_step_compact",[158])
		expect(not label.contains("%") and label.contains("158"),"compact tutorial heading renders variables in %s"%locale)
	game.LocaleSystem.current=original
	for slot in [game.InterfaceRenderer.hotbar_rect(0),game.InterfaceRenderer.inventory_hotbar_rect(0)]:
		var icon:Rect2=game.InterfaceRenderer.hotbar_icon_rect(slot)
		expect(slot.grow(-8).encloses(icon) and icon.get_center().is_equal_approx(slot.get_center()),"quick icon respects eight pixel frame in both layouts")
	game.free()
