extends RefCounted

const Style := preload("res://scripts/presentation/moon_theme.gd")

## Формирует до трёх компактных колонок материалов, сохраняя точный расход с учётом ремесленных талантов.
static func entries(game:Node, recipe:Dictionary) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var kinds:Array=recipe.inputs.keys()
	var count:=mini(kinds.size(),2 if kinds.size()>3 else 3)
	for index in count:
		var kind:=String(kinds[index]); var have:int=game.inventory_item_count(kind)
		var need:int=game.CraftingSystem.material_cost(game,recipe,kind)
		result.append({"kind":kind,"have":have,"need":need,"label":("999+" if have>999 else str(have))+"/"+str(need)})
	if kinds.size()>3: result.append({"kind":"","label":"+"+str(kinds.size()-count)})
	return result

## Показывает иконки и количество вместо обрезанных названий; полный состав остаётся в подробностях рецепта.
static func draw(game:Node2D, row:Rect2, recipe:Dictionary) -> void:
	var parts:=entries(game,recipe)
	for index in parts.size():
		var entry:Dictionary=parts[index]; var point:=row.position+Vector2(238+index*74,4)
		if entry.kind.is_empty(): Style.text(game,Rect2(point,Vector2(70,28)),entry.label,10,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER); continue
		game.draw_item_icon(entry.kind,Rect2(point+Vector2(0,5),Vector2(18,18)))
		Style.text(game,Rect2(point+Vector2(22,0),Vector2(48,28)),entry.label,10,Style.SUCCESS if entry.have>=entry.need else Style.DANGER)
