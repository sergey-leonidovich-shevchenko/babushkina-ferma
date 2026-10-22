extends RefCounted

const Data := preload("res://scripts/systems/workshop_data.gd")
const SHAPES := {
	"wood":'<path d="M13 56L63 24L86 39L37 73Z"/><path d="M13 56V67L37 83V73M37 73L86 39V51L37 83"/><path d="M24 57L62 33M35 63L75 38" fill="none"/>',
	"frame":'<path d="M15 28H85V83H15ZM28 40V70H72V40Z" fill-rule="evenodd"/><path d="M16 29L27 40M85 29L73 40M16 82L28 70M85 82L72 70"/>',
	"handle":'<path d="M40 16Q52 10 61 19L55 35L60 72Q58 87 45 88Q34 86 35 74L39 36Z"/><path d="M43 42L47 76" fill="none"/>',
	"dowels":'<path d="M19 38L27 31L64 69L56 77ZM39 20L47 13L83 51L75 59ZM18 63L26 56L51 82L43 89Z"/>',
	"pile":'<path d="M12 74L24 57L37 56L47 32L62 44L70 55L84 62L91 77Q55 94 12 74Z"/><path d="M31 65L43 55M58 61L67 72M38 78L52 74" fill="none"/>',
	"brick":'<path d="M12 35L65 19L88 37L34 55Z"/><path d="M12 35V70L34 87V55M34 55L88 37V71L34 87"/><path d="M28 43L67 30" fill="none"/>',
	"pot":'<path d="M25 31Q50 22 75 31L67 43Q84 72 68 83Q50 92 32 83Q16 72 33 43Z"/><ellipse cx="50" cy="32" rx="24" ry="7" fill="#504539"/><path d="M33 58Q26 71 40 79" fill="none"/>',
	"bowl":'<path d="M15 39Q50 27 85 39Q80 82 50 86Q20 82 15 39Z"/><ellipse cx="50" cy="39" rx="35" ry="11" fill="#655443"/><path d="M25 54Q29 72 41 76" fill="none"/>',
	"vase":'<path d="M36 14H64L60 32Q57 41 68 50Q82 70 65 85Q50 94 35 85Q18 70 32 50Q43 41 40 32Z"/><ellipse cx="50" cy="15" rx="14" ry="4" fill="#4e4a42"/><path d="M37 59Q30 71 39 79" fill="none"/>',
	"cup":'<path d="M72 42Q96 38 92 62Q88 72 75 71" fill="none" stroke-width="8"/><path d="M18 31H73L70 73Q47 88 24 73Z"/><ellipse cx="45" cy="31" rx="27" ry="8" fill="#6f746c"/><path d="M29 45L32 68" fill="none"/>',
	"shards":'<path d="M17 68L32 30L48 68L35 88ZM47 52L73 17L89 62L63 78ZM66 88L78 74L91 90Z"/>',
	"bottle":'<path d="M37 16H63V38L77 51L75 85Q50 94 25 85L23 51L37 38Z" fill-opacity="0.8"/><path d="M34 16H66V23H34Z" fill="#a27e4d"/><path d="M34 53L37 78" fill="none" stroke="#eef7e9" stroke-width="4"/>',
	"jar":'<path d="M26 28H74L79 40L76 85Q50 92 24 85L21 40Z" fill-opacity="0.7"/><path d="M22 20H78V30H22Z" fill="#ab8551"/><path d="M32 46V77" stroke="#eef7e9" stroke-width="4" fill="none"/>',
	"pane":'<path d="M13 40L61 13L88 30L41 60Z" fill-opacity="0.7"/><path d="M17 54L65 27L91 44L45 74Z" fill-opacity="0.7"/><path d="M27 45L59 26M37 66L70 44" stroke="#eef7f1" stroke-width="3" fill="none"/>',
	"lens":'<ellipse cx="50" cy="52" rx="35" ry="26" fill-opacity="0.7"/><ellipse cx="50" cy="50" rx="28" ry="20" fill-opacity="0.5"/><path d="M28 46Q40 31 58 34" stroke="#eef7f1" stroke-width="5" fill="none"/>',
}
static var _textures:Dictionary={}

## Создаёт отдельную реальную текстуру каждого материала один раз до первого кадра.
static func texture(kind: String) -> Texture2D:
	if not Data.ITEMS.has(kind): return null
	if not _textures.has(kind):
		var item:Dictionary=Data.ITEMS[kind]; var color:=Color(item.color); var outline:=color.darkened(0.45).to_html(false)
		var source:String='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100"><ellipse cx="50" cy="86" rx="34" ry="6" fill="#37483c" fill-opacity="0.2"/><g fill="#'+String(item.color)+'" stroke="#'+outline+'" stroke-width="2.2" stroke-linejoin="round">'+SHAPES[item.group]+'</g></svg>'
		var image:=Image.new()
		if image.load_svg_from_string(source)!=OK: return null
		_textures[kind]=ImageTexture.create_from_image(image)
	return _textures[kind]

## Переиспользует приготовленную иконку в любых предметных окнах без горячей SVG-растеризации.
static func draw_item(game: Node2D, kind: String, rect: Rect2) -> bool:
	var image:=texture(kind)
	if image==null: return false
	game.draw_texture_rect(image,rect,false); return true
