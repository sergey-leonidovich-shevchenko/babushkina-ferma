extends SceneTree

const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const MASTERS := "res://docs/concepts/storage-art-2026-10-13/v1/selected/"
const FOLDER := "res://assets/game/items/painted/"
var templates:Dictionary={}

## Собирает утверждённые растровые сосуды и целый подсолнух в компактные игровые ресурсы.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for id in ["vial","solvent","oil","juice","tincture","essence","balm","distillate","bottle_empty","jar_empty"]:
		templates[id]=fitted(Image.load_from_file(MASTERS+id+".png"))
	var kinds:Array=Products.names().keys()+["glass_bottle","glass_jar"]
	var paths:={}; var mapping:={}
	for kind in kinds:
		var group:=family(kind)
		if group.is_empty(): continue
		var image:Image=templates[group].duplicate()
		if kind not in ["herb_oil","herb_solvent","glass_vial","clean_water","distilled_water","glass_bottle","glass_jar"]: color_contents(image,group,Products.color_for(kind))
		if image.save_png(FOLDER+kind+".png")!=OK: push_error("Не удалось сохранить "+kind); quit(1); return
		paths[kind]=FOLDER+kind+".png"; mapping[kind]={"master":group,"color":Products.color_for(kind).to_html(false)}
	var sunflower:=fitted(Image.load_from_file("res://docs/concepts/storage-art-2026-10-13/v1/sunflower-proposal.png"))
	if sunflower.save_png(FOLDER+"sunflower.png")!=OK: push_error("Не удалось сохранить подсолнух"); quit(1); return
	paths.sunflower=FOLDER+"sunflower.png"; mapping.sunflower={"master":"sunflower-proposal","color":"ffffff"}
	var file:=FileAccess.open(FOLDER+"catalog.gd",FileAccess.WRITE)
	file.store_string("extends RefCounted\n\n## Утверждённые изображения A; сборка tools/assets/authoring/build_painted_item_icons.gd.\nconst ITEMS := "+JSON.stringify(paths,"\t")+"\n"); file.close()
	file=FileAccess.open(FOLDER+"mapping.json",FileAccess.WRITE); file.store_string(JSON.stringify(mapping,"\t")); file.close()
	print("PAINTED ITEM ICONS: %d approved item resources at 160px"%paths.size()); quit()

## Различает стадии и назначения сосудов, сохраняя ботанику, порошки и уже готовые изображения.
func family(kind: String) -> String:
	if kind=="glass_bottle": return "bottle_empty"
	if kind=="glass_jar": return "jar_empty"
	if kind=="glass_vial": return "vial"
	if kind in ["herb_solvent","clean_water"]: return "solvent"
	if kind=="distilled_water": return "distillate"
	if kind in ["herb_oil","miners_oil","honey_syrup"]: return "oil"
	if kind.ends_with("_balm") or kind in ["life_balsam","insect_repellent","wax_base"]: return "balm"
	if kind.ends_with("_juice"): return "juice"
	if kind.ends_with("_tincture") or kind.ends_with("_tonic") or kind.ends_with("_infusion") or kind.ends_with("_decoction"): return "tincture"
	if kind.ends_with("_essence") or kind=="solar_concentrate" or Products.POTIONS.has(kind): return "essence"
	return ""

## Нормализует исходный RGBA до160px, убирая полупрозрачную пыль снаружи и оставляя безопасный край.
func fitted(source: Image) -> Image:
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color:=source.get_pixel(x,y)
			if color.a<=0.08: source.set_pixel(x,y,Color.TRANSPARENT)
	var bounds:=source.get_used_rect(); var sprite:=source.get_region(bounds); var factor:=144.0/maxi(bounds.size.x,bounds.size.y)
	sprite.resize(maxi(1,roundi(bounds.size.x*factor)),maxi(1,roundi(bounds.size.y*factor)),Image.INTERPOLATE_LANCZOS)
	var result:=Image.create(160,160,false,Image.FORMAT_RGBA8); result.fill(Color.TRANSPARENT)
	result.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),(Vector2i(160,160)-sprite.get_size())/2); return result

## Применяет рецептурный цвет только к насыщенному содержимому; стеклянные блики, пробка и обвязка остаются исходными.
func color_contents(image: Image, group: String, target: Color) -> void:
	var reference:float={"juice":0.0,"tincture":0.77,"essence":0.62,"oil":0.10,"balm":0.20}.get(group,-1.0)
	if reference<0: return
	var width:int=image.get_width(); var height:int=image.get_height()
	for y in height:
		for x in width:
			var color:=image.get_pixel(x,y); var difference:=absf(color.h-reference); difference=minf(difference,1-difference)
			if color.a<0.08 or color.s<0.35 or difference>(0.06 if group in ["juice","oil"] else 0.14): continue
			if group=="juice" and y<height*0.15: continue
			if group=="oil" and (y<height*0.45 or x>width*0.78): continue
			if group=="balm" and y>height*0.32: continue
			image.set_pixel(x,y,Color.from_hsv(target.h,clampf(target.s*0.9+color.s*0.25,0.35,1),clampf(color.v*(0.65+target.v*0.35),0,1),color.a))
