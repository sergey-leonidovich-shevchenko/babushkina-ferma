extends RefCounted

const Workshop := preload("res://scripts/presentation/workshop_icon_system.gd")
const WorkshopData := preload("res://scripts/systems/workshop_data.gd")
const Research := preload("res://scripts/presentation/research_icon_system.gd")
const ResearchData := preload("res://scripts/systems/research_data.gd")
const Furnace := preload("res://scripts/presentation/furnace_renderer.gd")
const FurnaceData := preload("res://scripts/systems/furnace_data.gd")
const Alchemy := preload("res://scripts/presentation/alchemy_icon_system.gd")
const Products := preload("res://scripts/systems/alchemy_product_data.gd")
static var _cache: Dictionary = {}

## Сбрасывает визуальные пакеты вместе с повторной загрузкой каталога или выбранных замен спрайтов.
static func clear() -> void:
	_cache.clear()

## Даёт игре, Wiki и аудиту один рисунок и цвет, сохраняя прежний порядок специализированных материалов.
static func profile(kind: String, base: Texture2D, override: bool = false) -> Dictionary:
	var key := kind+":"+str(base.get_instance_id() if base!=null else 0)+":"+str(override)
	if not _cache.has(key):
		var texture := base; var tint := Color.WHITE; var provider := "override" if override else "catalog"
		if not override:
			if WorkshopData.ITEMS.has(kind): texture=Workshop.texture(kind); provider="workshop"
			elif ResearchData.ITEMS.has(kind):
				texture=Research.texture(kind); provider="research"
				if Research.TEXTURES.has(kind): tint=Color(ResearchData.ITEMS[kind].color).lerp(Color.WHITE,0.6)
			elif FurnaceData.ITEMS.has(kind):
				texture=Furnace.item_texture(kind); provider="furnace"
				if kind!="glass": tint=Color(FurnaceData.ITEMS[kind].tint).lerp(Color.WHITE,0.05 if kind=="charcoal" else 0.3)
			elif Products.handles(kind): texture=Alchemy.texture(kind); tint=Alchemy.tint(kind); provider="alchemy"
		_cache[key]={"texture":texture,"tint":tint,"provider":provider,"square":provider in ["catalog","override"]}
	return _cache[key].duplicate()
