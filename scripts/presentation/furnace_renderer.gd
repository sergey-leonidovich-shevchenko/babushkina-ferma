extends RefCounted

const Furnace := preload("res://scripts/systems/furnace_system.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")
const FUEL_BUTTON := Rect2(210,120,166,28)
const LOAD_BUTTON := Rect2(382,120,134,28)
const UPGRADE_BUTTON := Rect2(522,120,158,28)
const TEXTURES := {"metal":preload("res://assets/game/items/catalog/metal.png"),"stone":preload("res://assets/game/items/catalog/stone.png"),"wood":preload("res://assets/game/items/catalog/wood.png"),"fiber":preload("res://assets/game/items/catalog/fiber.png"),"crystal":preload("res://assets/game/items/catalog/crystal.png")}
static var _glass:Texture2D

## Предоставляет общему реестру настоящую переиспользуемую текстуру каждого материала горна.
static func item_texture(kind: String) -> Texture2D:
	if kind=="glass":
		if _glass==null:
			var image:=Image.new()
			if image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100"><g fill="#c9e5e3" fill-opacity="0.72" stroke="#7ca4af" stroke-width="2"><path d="M18 37L62 12L86 27L42 53Z"/><path d="M18 46L62 21L86 36L42 62Z"/><path d="M18 55L62 30L86 45L42 71Z"/></g><path d="M29 41L60 24M29 60L49 49" stroke="#fffdec" stroke-width="3"/><path d="M18 55V61L42 78V71" fill="#97bbc2"/></svg>')!=OK: return null
			_glass=ImageTexture.create_from_image(image)
		return _glass
	return TEXTURES[Furnace.Data.ITEMS[kind].icon] if Furnace.Data.ITEMS.has(kind) else null

## Отмечает варианты руды, стекла и топлива собственным цветом поверх существующих иконок.
static func draw_item(game: Node2D, kind: String, rect: Rect2) -> bool:
	var texture:=item_texture(kind)
	if texture==null: return false
	var tint:=Color.WHITE if kind=="glass" else Color(Furnace.Data.ITEMS[kind].tint).lerp(Color.WHITE,0.05 if kind=="charcoal" else 0.3)
	game.draw_texture_rect(texture,rect,false,tint); return true

## Рисует три доступных способа управления печью и всю стоимость следующего улучшения.
static func draw_toolbar(game: Node) -> void:
	var value:=Furnace.state(game)
	for entry in [[FUEL_BUTTON,game.inventory_item_name(value.fuel)+"  ×"+str(game.inventory_item_count(value.fuel))],[LOAD_BUTTON,game.LocaleSystem.ui("furnace_load")],[UPGRADE_BUTTON,game.LocaleSystem.ui("furnace_upgrade")]]:
		Kit.draw_nine_patch(game,"editor_button_normal",entry[0])
		game.draw_ui_string(game.UI_FONT,entry[0].position+Vector2(8,20),entry[1],HORIZONTAL_ALIGNMENT_CENTER,entry[0].size.x-16,11,Kit.COLORS.ink)
	var queued:Array[String]=[]
	for job in value.queue:
		var recipe:Dictionary=Furnace.Data.recipe(job.id); queued.append(game.inventory_item_name(recipe.output)+" ×"+str(recipe.count))
	game.draw_ui_string(game.UI_FONT,Vector2(220,486),game.LocaleSystem.ui("furnace_queue_names",[" → ".join(queued) if not queued.is_empty() else "—"]),HORIZONTAL_ALIGNMENT_LEFT,450,11,Kit.COLORS.ink)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(220,508),Furnace.upgrade_text(game),HORIZONTAL_ALIGNMENT_LEFT,450,36,10,2,Kit.COLORS.ink)

## Разделяет переключение топлива, загрузку и улучшение без случайной постановки рецепта в очередь.
static func handle_pointer(game: Node, position: Vector2) -> bool:
	if FUEL_BUTTON.has_point(position): Furnace.cycle_fuel(game)
	elif LOAD_BUTTON.has_point(position): Furnace.load_fuel(game)
	elif UPGRADE_BUTTON.has_point(position): Furnace.upgrade(game)
	else: return false
	game.queue_redraw(); return true

## Показывает уровень у существующей печи, сохраняя ранее выбранный интерьер и его коллизию.
static func draw_station(game: Node2D) -> void:
	if game.current_location!="forge_interior": return
	game.draw_ui_string(game.UI_FONT,Vector2(634,290),["I","II","III"][int(Furnace.state(game).level)-1],HORIZONTAL_ALIGNMENT_CENTER,26,12,Color("e4c784"))
