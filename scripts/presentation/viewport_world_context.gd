# Контекст валидирует динамический игровой узел по числовой identity, а не по concrete class.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends RefCounted

const META := &"viewport_world_context"
const OWNER_META := &"viewport_world_owner"
const KEYS := ["game", "viewport", "background"]


## Выдаёт миру неизменяемый числовой токен его viewport и фонового узла.
static func bind(game: Node) -> Dictionary:
	var background := game.get_node_or_null("WorldBackground")
	if background == null:
		return {}
	var viewport := game.get_viewport() if game.is_inside_tree() else null
	var value := {
		"game": game.get_instance_id(),
		"viewport": viewport.get_instance_id() if viewport != null else 0,
		"background": background.get_instance_id(),
	}
	value.make_read_only()
	game.set_meta(META, value)
	background.bind_owner(value)
	return value


## Возвращает действующий токен.
## Обновляет его только после фактического переноса мира в другой viewport.
static func ensure(game: Node) -> Dictionary:
	var value := read(game)
	return bind(game) if value.is_empty() else value


## Читает контракт без записи.
## Отклоняет чужой viewport, фон или изменяемый словарь.
static func read(game: Node) -> Dictionary:
	if not game.has_meta(META):
		return {}
	var raw: Variant = game.get_meta(META)
	if not raw is Dictionary or not raw.is_read_only() or raw.size() != KEYS.size():
		return {}
	for key in KEYS:
		if not raw.has(key) or typeof(raw[key]) != TYPE_INT:
			return {}
	var background := game.get_node_or_null("WorldBackground")
	if background == null or int(raw.game) != game.get_instance_id():
		return {}
	if int(raw.background) != background.get_instance_id() or not background.owned_by(raw):
		return {}
	var viewport := game.get_viewport() if game.is_inside_tree() else null
	var viewport_id := viewport.get_instance_id() if viewport != null else 0
	return raw if int(raw.viewport) == viewport_id else {}


## Подтверждает, что узел принадлежит тому же миру.
## Он не может принять параметры соседнего viewport.
static func owns(game: Node, node: Node) -> bool:
	var value := read(game)
	return not value.is_empty() and node != null and node.get_meta(OWNER_META, {}) == value


## Возвращает стабильный ID владельца временного render-пакета без ссылки на Node.
static func owner_id(game: Node) -> int:
	var value := read(game)
	return int(value.game) if not value.is_empty() else 0
