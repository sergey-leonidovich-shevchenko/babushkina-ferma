extends RefCounted

## Рисует только те высокие объекты, за которыми в текущий момент проходит герой.
static func draw(game: Node2D) -> void:
	# Здания, кроны и перила уже находятся в мастер-атласе первой локации.
	# Старый условный foreground менял изображение при приближении героя и больше не нужен.
	if game.current_location != "overworld": return
