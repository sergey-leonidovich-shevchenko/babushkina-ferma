extends RefCounted

static var _textures: Dictionary = {}


## Один раз очищает явно подключённый проблемный PNG, не меняя исходный файл и обычные текстуры игры.
static func clean_texture(texture: Texture2D) -> Texture2D:
	if texture == null: return texture
	var key := texture.get_rid().get_id()
	if _textures.has(key): return _textures[key]
	var image := texture.get_image()
	if image == null: return texture
	if image.is_compressed(): image.decompress()
	var cleaned := clean_image(image)
	var result := ImageTexture.create_from_image(cleaned)
	_textures[key] = result
	return result


## Удаляет только насыщенный служебный цвет, связанный с прозрачным внешним краем; внутренние детали сохраняет.
static func clean_image(source: Image, dark_magenta: bool = false) -> Image:
	var image := source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var bytes := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var count := width * height
	var candidates := PackedByteArray(); candidates.resize(count)
	var visited := PackedByteArray(); visited.resize(count)
	var queue := PackedInt32Array()
	for index in count:
		var offset := index * 4
		if bytes[offset + 3] > 0 and (is_service_color(bytes[offset], bytes[offset + 1], bytes[offset + 2]) or (dark_magenta and is_dark_magenta(bytes[offset],bytes[offset+1],bytes[offset+2]))): candidates[index] = 1
	for index in count:
		if candidates[index] == 0: continue
		var x := index % width
		var y := index / width
		var outside := x == 0 or y == 0 or x == width - 1 or y == height - 1
		if not outside:
			for adjacent in [index - 1, index + 1, index - width, index + width]:
				if bytes[adjacent * 4 + 3] < 20: outside = true; break
		if outside: queue.append(index); visited[index] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]; cursor += 1
		bytes[index * 4 + 3] = 0
		var x := index % width
		for adjacent in [index - width, index + width, index - 1 if x > 0 else -1, index + 1 if x < width - 1 else -1]:
			if adjacent >= 0 and adjacent < count and candidates[adjacent] == 1 and visited[adjacent] == 0:
				visited[adjacent] = 1; queue.append(adjacent)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)


## Отличает почти чистый красный, зелёный и пурпурный matte от естественного оранжевого меха и тёмной обводки.
static func is_service_color(red: int, green: int, blue: int) -> bool:
	return (red > 210 and green < 55 and blue < 70) or (green > 215 and red < 65 and blue < 80) or (red > 165 and blue > 165 and green < 72)

## Отличает тёмный почти чистый пурпурный ключ событий от синеватой ткани и настоящей цветной тени.
static func is_dark_magenta(red: int, green: int, blue: int) -> bool:
	return red>=90 and blue>=90 and absi(red-blue)<=26 and green<=mini(22,int(red*0.1+4))
