extends RefCounted

const Data := preload("res://scripts/systems/research_data.gd")
const TEXTURES := {"wood_offcut":preload("res://assets/game/items/catalog/plank.png"),"cloth_scrap":preload("res://assets/game/items/catalog/cloth.png")}
const SHAPES := {
	"research_paper":'<path d="M20 25L68 16L82 71L34 82Z" fill="#af9875"/><path d="M15 19L64 12L78 66L29 76Z" fill="#eadbb6" stroke="#897453" stroke-width="2"/><path d="M30 32L58 28M33 42L61 38M36 52L55 50" stroke="#ac9472" stroke-width="3"/><path d="M49 63L80 24L87 15L90 26L57 65Z" fill="#708e88"/><path d="M49 63L44 73L57 65" fill="#564739"/>',
	"research_ink":'<path d="M31 30L31 43L24 52L27 79Q49 87 72 78L75 51L65 42L65 30Z" fill="#45516a" stroke="#28383e" stroke-width="3"/><ellipse cx="48" cy="28" rx="19" ry="7" fill="#aa8150"/><path d="M32 52L37 72" stroke="#a4b4b4" stroke-width="4"/><path d="M43 58L58 56L62 69L46 72Z" fill="#d9cba6"/>',
	"glass_shard":'<path d="M14 61L37 22L48 62L33 81Z" fill="#c4e4e4" stroke="#789aa5" stroke-width="2"/><path d="M45 50L76 14L87 53L59 75Z" fill="#a9d1db" stroke="#789aa5" stroke-width="2"/><path d="M64 80L80 65L89 86Z" fill="#d3ece7"/><path d="M27 56L36 40M58 47L72 33" stroke="#fffce8" stroke-width="3"/>',
	"arcane_dust":'<ellipse cx="50" cy="77" rx="35" ry="10" fill="#497888" fill-opacity="0.3"/><path d="M16 75L33 51L44 52L51 36L68 55L85 75Q50 90 16 75" fill="#76b9d2" stroke="#426f8b" stroke-width="2"/><path d="M29 69L38 57L45 70L55 51L66 73" fill="none" stroke="#b7e4e7" stroke-width="4"/><path d="M27 42L30 39L34 44L30 48M70 35L74 32L78 37L74 42" fill="#b5d7eb"/>',
}
static var _cache:Dictionary={}

## Предоставляет реальные кэшированные текстуры расходников и деталей, не рисуя SVG в каждом кадре.
static func texture(kind: String) -> Texture2D:
	if TEXTURES.has(kind): return TEXTURES[kind]
	if not SHAPES.has(kind): return null
	if not _cache.has(kind):
		var image:=Image.new()
		if image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100">'+SHAPES[kind]+'</svg>')!=OK: return null
		_cache[kind]=ImageTexture.create_from_image(image)
	return _cache[kind]

## Рисует детали согласованным способом в рюкзаке, лавке и новых предметных окнах.
static func draw_item(game: Node2D, kind: String, rect: Rect2) -> bool:
	if not Data.ITEMS.has(kind): return false
	var image:=texture(kind)
	if image==null: return false
	game.draw_texture_rect(image,rect,false,Color(Data.ITEMS[kind].color).lerp(Color.WHITE,0.6) if TEXTURES.has(kind) else Color.WHITE)
	return true
