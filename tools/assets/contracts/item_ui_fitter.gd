extends RefCounted

## Подготавливает целый силуэт с прозрачным полем; используется только сборщиком и проверкой готового пакета.
static func fitted(source: Image, bounds: Rect2i, size: int, padding: int) -> Image:
	var sprite := source.get_region(bounds); var factor := float(size-padding*2)/maxi(bounds.size.x,bounds.size.y)
	sprite.resize(maxi(1,roundi(bounds.size.x*factor)),maxi(1,roundi(bounds.size.y*factor)),Image.INTERPOLATE_LANCZOS)
	var target := Image.create(size,size,false,Image.FORMAT_RGBA8); target.fill(Color.TRANSPARENT)
	target.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),(Vector2i(size,size)-sprite.get_size())/2)
	return target
