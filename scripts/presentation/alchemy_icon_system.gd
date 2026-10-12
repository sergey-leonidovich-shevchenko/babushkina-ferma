extends RefCounted

const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const LEAVES := preload("res://assets/game/items/catalog/herbs.png")
const FLOWER := preload("res://assets/game/items/catalog/flower.png")
const POWDER := preload("res://assets/game/items/catalog/flour.png")
const SEEDS := preload("res://assets/game/items/catalog/herb_seeds.png")
static var _textures:Dictionary={}

## Предоставляет настоящую текстуру каждому материалу: прежний спрайт или заранее подготовленный векторный флакон.
static func texture(kind: String) -> Texture2D:
	if not Products.handles(kind): return null
	if _textures.has(kind): return _textures[kind]
	var result:Texture2D
	if Herbs.is_herb(kind): result=FLOWER if Herbs.HERBS[kind].shape=="flower" else LEAVES
	elif kind.ends_with("_dried") or kind=="herb_pulp": result=LEAVES
	elif kind.ends_with("_powder") or kind=="mineral_base": result=POWDER
	elif kind in ["herb_solvent","herb_oil"]: result=SEEDS
	else:
		var liquid:="" if kind=="glass_vial" else '<rect x="24" y="48" width="52" height="34" fill="#%s"/>'%Products.color_for(kind).to_html(false)
		var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100"><path d="M38 12H62V30L80 45V83L70 90H30L20 83V45L38 30Z" fill="#c5d0b6" stroke="#635e48" stroke-width="2"/>%s<rect x="35" y="8" width="30" height="10" fill="#a17645"/><path d="M30 52V73" stroke="#fffedd" stroke-opacity="0.7" stroke-width="4"/></svg>'%liquid
		var image:=Image.new()
		if image.load_svg_from_string(svg)!=OK: return null
		result=ImageTexture.create_from_image(image)
	_textures[kind]=result; return result

## Применяет цвет только к переиспользуемому сырью; цвет векторного флакона уже встроен в его текстуру.
static func tint(kind: String) -> Color:
	if Herbs.is_herb(kind): return Products.color_for(kind).lerp(Color.WHITE,0.55)
	if kind.ends_with("_dried") or kind=="herb_pulp": return Color("c7b38d")
	if kind.ends_with("_powder") or kind=="mineral_base": return Products.color_for(kind).lerp(Color.WHITE,0.4)
	if kind in ["herb_solvent","herb_oil"]: return Color("dac29b")
	return Color.WHITE
