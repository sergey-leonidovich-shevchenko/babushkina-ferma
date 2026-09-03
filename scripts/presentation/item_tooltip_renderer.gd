extends RefCounted

const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")
const ItemPresentationSystem:=preload("res://scripts/systems/item_presentation_system.gd")


## Рисует унифицированную карточку предмета с редкостью, эффектом, прочностью и сравнением экипировки.
static func draw(game:Node,kind:String,rect:Rect2,amount:int=-1,draw_background:bool=false)->void:
	if kind.is_empty(): return
	if draw_background: UiKitSystem.draw_nine_patch(game,"tooltip",rect)
	var inner:=rect.grow(-12); var rarity:=ItemPresentationSystem.rarity(kind); var rarity_color:=ItemPresentationSystem.rarity_color(kind)
	game.draw_rect(Rect2(inner.position,Vector2(4,inner.size.y)),rarity_color)
	game.draw_item_icon(kind,Rect2(inner.position+Vector2(14,2),Vector2(62,62)))
	game.draw_ui_string(game.UI_FONT,inner.position+Vector2(84,23),game.inventory_item_name(kind),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-88,14,UiKitSystem.COLORS.ink)
	game.draw_ui_string(game.UI_FONT,inner.position+Vector2(84,43),game.LocaleSystem.ui("item_rarity_"+rarity),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-88,9,rarity_color)
	game.draw_ui_string(game.UI_FONT,inner.position+Vector2(84,59),game.LocaleSystem.ui("category_"+game.InventorySystem.category(kind)),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-88,8,Color("66804c"))
	game.draw_line(inner.position+Vector2(10,72),inner.position+Vector2(inner.size.x-6,72),Color("a98755"),1)
	var y:=90.0
	if amount>=0:
		game.draw_ui_string(game.UI_FONT,inner.position+Vector2(12,y),game.LocaleSystem.ui("quantity",[amount]),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-20,10,UiKitSystem.COLORS.ink); y+=20
	game.draw_ui_multiline_string(game.UI_FONT,inner.position+Vector2(12,y),game.LocaleSystem.ui(game.InventorySystem.detail_key(kind)),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-20,34,8,2,Color("765a3c")); y+=38
	var effect:=ItemPresentationSystem.effect_text(game,kind)
	if not effect.is_empty():
		game.draw_ui_multiline_string(game.UI_FONT,inner.position+Vector2(12,y),effect,HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-20,34,9,2,UiKitSystem.COLORS.success); y+=38
	var durability:=ItemPresentationSystem.durability(game,kind)
	if durability>=0:
		game.draw_ui_string(game.UI_FONT,inner.position+Vector2(12,y),game.LocaleSystem.ui("item_durability",[durability]),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-20,9,UiKitSystem.COLORS.ink); y+=9
		game.draw_rect(Rect2(inner.position+Vector2(12,y),Vector2(inner.size.x-24,5)),Color("493728")); game.draw_rect(Rect2(inner.position+Vector2(12,y),Vector2((inner.size.x-24)*durability/100.0,5)),Color("77ad5d") if durability>20 else UiKitSystem.COLORS.danger); y+=18
	var comparison:=ItemPresentationSystem.comparison(game,kind)
	if not comparison.is_empty():
		draw_comparison(game,comparison,Rect2(inner.position+Vector2(10,y),Vector2(inner.size.x-18,inner.size.y-y)))
	elif inner.size.y-y>=16:
		game.draw_ui_string(game.UI_FONT,inner.position+Vector2(12,inner.size.y-4),game.LocaleSystem.ui("sell_value",[game.ShopSystem.sell_price(kind)]),HORIZONTAL_ALIGNMENT_LEFT,inner.size.x-20,8,Color("775226"))


## Рисует компактные дельты характеристик относительно предмета, уже надетого в тот же слот.
static func draw_comparison(game:Node,comparison:Dictionary,rect:Rect2)->void:
	var title:String=game.LocaleSystem.ui("item_equipped") if bool(comparison.same) else game.LocaleSystem.ui("item_compare")
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(2,12),title,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-4,8,Color("765a3c"))
	var y:=29.0
	for row in comparison.rows:
		var delta:=int(row.delta); var suffix:="%+d%%"%delta if String(row.id)=="speed" else "%+d"%delta
		var value:="%d%%"%int(row.candidate) if String(row.id)=="speed" else str(row.candidate)
		var text:="%s  %s  (%s)"%[game.LocaleSystem.ui("item_stat_"+String(row.id)),value,suffix]
		var color:=UiKitSystem.COLORS.success if delta>0 else (UiKitSystem.COLORS.danger if delta<0 else Color("80684a"))
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(2,y),text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-4,8,color); y+=15
