extends RefCounted

## Дополняет игровые позы конечными сетками совместимости и тремя разрешёнными видами мебели.
static func append(ctx:Object) -> void:
	var ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
	for kind in ambient.CELLS:ctx.append_frame("ambient/"+kind,ambient.ATLAS,ambient.source_rect(kind),ambient.CELL*Vector2(0.5,1))
	var fence:=preload("res://scripts/systems/fence_renderer.gd")
	for style in 5:
		for column in 8:ctx.append_frame("fence/"+str(style)+"/"+str(column),fence.ATLAS,fence.source(style,column),Vector2(32,32))
	var polish:=preload("res://scripts/systems/world_polish_renderer.gd")
	for row in 4:
		for column in 5:ctx.append_frame("legacy/polish/"+str(row)+"/"+str(column),polish.ATLAS,polish.source(column,row),Vector2(64,64))
	var furniture:=preload("res://scripts/presentation/house_furniture_visual_system.gd")
	for kind in furniture.SPRITES:
		for side in [0,1,3] if furniture.SPRITES[kind].size()>1 else [0]:
			var source:Rect2=furniture.source(kind,side)
			ctx.append_frame("furniture/"+kind+"/"+furniture.Facing.NAMES[side],furniture.texture(kind,side),source,source.size*Vector2(0.5,1))
	var farm:=preload("res://scripts/systems/farm_life_visual_system.gd")
	for kind in farm.PROFILES:ctx.append_frame("legacy/farm_life/"+kind,farm.ATLAS,farm.source_rect(kind),Vector2(64,128))
	var interior:=preload("res://scripts/systems/interior_visual_system.gd")
	for kind in interior.PROFILES:
		if kind in furniture.KINDS or kind in ["pottery","cauldron"] or interior.WorkshopVisualSystem.SPRITES.has(kind):continue
		var source:Rect2=interior.source_rect(kind)
		ctx.append_frame("interior/"+kind,interior.ATLAS,source,source.size*Vector2(0.5,1))
	var village:=preload("res://scripts/systems/village_layout_system.gd")
	var props:=preload("res://assets/game/environment/village_prop_atlas_v2.png")
	for kind in village.PROP_CELLS:ctx.append_frame("legacy/village/"+kind,props,village.prop_source_rect(kind),village.PROP_ATLAS_CELL*Vector2(0.5,1))
	for kind in ctx.game.FORAGE_SPRITES:
		var source:Rect2=ctx.game.FORAGE_SPRITES[kind].source
		ctx.append_frame("forage/"+kind,ctx.game.PLANT_SHEET,source,source.size*Vector2(0.5,1))
	var cell:Vector2=ctx.game.ENEMY_RANK_ATLAS.get_size()/Vector2(5,3)
	for row in 3:
		for column in 5:ctx.append_frame("legacy/enemy_rank/"+str(row)+"/"+str(column),ctx.game.ENEMY_RANK_ATLAS,Rect2(Vector2(column,row)*cell,cell),cell*Vector2(0.5,0.66))
	legacy_icons(ctx)

## Проверяет сохранённые fallback-регионы отдельно от фактически выбранных современных иконок.
static func legacy_icons(ctx:Object) -> void:
	var assets:=preload("res://scripts/systems/visual_asset_system.gd")
	for kind in assets.PIRATE_ENEMY_ORDER:
		var source:Rect2=assets.pirate_enemy_source(kind)
		ctx.append_frame("legacy/pirate_enemy/"+kind,assets.PIRATE_ENEMY_ATLAS,source,source.size*Vector2(0.5,0.66))
	for kind in assets.PIRATE_ITEM_CELLS:ctx.append_frame("legacy/icon/pirate/"+kind,assets.PIRATE_ITEM_ATLAS,assets.safe_atlas_source(assets.pirate_item_source(kind),12),assets.pirate_item_source(kind).size*0.5-Vector2(12,12))
	for kind in assets.POTION_CELLS:ctx.append_frame("legacy/icon/potion/"+kind,assets.POTION_ATLAS,assets.safe_atlas_source(assets.potion_source(kind),12),assets.potion_source(kind).size*0.5-Vector2(12,12))
	for cells in [assets.INVENTORY_CORE_CELLS,assets.INVENTORY_RARE_CELLS,assets.FARM_FOOD_CELLS]:
		for kind in cells:
			var source:Rect2=assets.safe_atlas_source(assets.inventory_item_source(kind))
			ctx.append_frame("legacy/icon/inventory/"+kind,assets.inventory_item_atlas(kind),source,source.size*0.5)
