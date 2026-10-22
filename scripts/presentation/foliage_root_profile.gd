extends RefCounted

const ALPHA_THRESHOLD := 224
const CELL_SIZE := Vector2i(362,362)
const PROFILES := {
	"flowers":{"root":Vector2i(180,330),"top":129,"mode":"ground"},
	"grass":{"root":Vector2i(178,325),"top":110,"mode":"ground"},
	"reeds":{"root":Vector2i(148,300),"top":62,"mode":"ground"},
	"berry_bush":{"root":Vector2i(150,325),"top":119,"mode":"ground"},
	"mossy_stone":{"root":Vector2i(180,280),"top":73,"mode":"rigid"},
	"stump":{"root":Vector2i(180,280),"top":87,"mode":"rigid"},
	"signpost":{"root":Vector2i(145,257),"top":40,"mode":"rigid"},
	"flower_fence":{"root":Vector2i(232,286),"top":93,"mode":"rigid"},
	"lantern":{"root":Vector2i(145,227),"top":0,"mode":"rigid"},
	"footbridge":{"root":Vector2i(185,235),"top":48,"mode":"rigid"},
	"leaves":{"root":Vector2i(140,210),"top":30,"mode":"floating"},
	"water_lilies":{"root":Vector2i(150,180),"top":62,"mode":"floating"},
	"grass_low":{"root":Vector2i(219,480),"top":214,"mode":"ground","size":Vector2i(438,512)},
}

## Возвращает отдельный паспорт опоры; чужой ID никогда не превращается в первый цветок атласа.
static func profile(kind:String)->Dictionary:
	if not PROFILES.has(kind):return {}
	var result:Dictionary=PROFILES[kind].duplicate(true)
	result.size=result.get("size",CELL_SIZE)
	result.lock_y=int(result.root.y)-6
	result.flexible=result.mode=="ground"
	return result

## Переводит пиксельную опору внутри настоящей области в прежний мировой прямоугольник без изменения размещения.
static func world_anchor(kind:String,destination:Rect2)->Vector2:
	var data:=profile(kind)
	if data.is_empty() or not destination.has_area() or not destination.position.is_finite() or not destination.size.is_finite():return Vector2.INF
	return destination.position+Vector2(data.root)/Vector2(data.size)*destination.size

## Даёт нулевой изгиб жёсткому декору, чужому пикселю, прозрачному краю и шести пикселям основания.
static func flexibility(kind:String,pixel:Vector2i,alpha:int)->float:
	var data:=profile(kind)
	if data.is_empty() or not data.flexible or alpha<ALPHA_THRESHOLD or alpha>255:return 0.0
	if pixel.x<0 or pixel.y<0 or pixel.x>=data.size.x or pixel.y>=data.size.y:return 0.0
	return pow(clampf(float(data.lock_y-pixel.y)/float(data.lock_y-data.top),0.0,1.0),2.0)

## Строит одноканальную маску из уже выделенной области один раз при подготовке материала, без чтения GPU в кадре.
static func build_mask(kind:String,source:Image)->Image:
	var data:=profile(kind)
	if data.is_empty() or source==null or source.is_empty() or source.get_size()!=data.size:return null
	var bytes:=PackedByteArray();bytes.resize(data.size.x*data.size.y);bytes.fill(0)
	if data.flexible:
		for y in range(data.lock_y):
			var value:=roundi(pow(clampf(float(data.lock_y-y)/float(data.lock_y-data.top),0.0,1.0),2.0)*255.0)
			if value==0:continue
			for x in data.size.x:
				if roundi(source.get_pixel(x,y).a*255.0)>=ALPHA_THRESHOLD:bytes[y*data.size.x+x]=value
	return Image.create_from_data(data.size.x,data.size.y,false,Image.FORMAT_L8,bytes)
