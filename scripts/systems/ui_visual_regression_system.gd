extends RefCounted

const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")

const MANIFEST_PATH := "res://assets/generated/ui/visual_regression_manifest.json"
const REFERENCE_DIRECTORY := "res://assets/generated/ui/"
const HUD_PROFILE_DIRECTORY := REFERENCE_DIRECTORY + "adaptive_hud/"
const HUD_PROFILE_MANIFEST_PATH := HUD_PROFILE_DIRECTORY + "manifest.json"
const PERCEPTUAL_GRID := Vector2i(8, 8)
const PERCEPTUAL_CELL_SAMPLES := 4
const DEFAULT_PERCEPTUAL_THRESHOLDS := {"mean":0.020, "max_cell":0.100, "changed_ratio":0.150, "changed_cell":0.035}
const LOCALIZED_CONTROL_CONTRACTS := {
	"title":{"width":694.0,"size":54}, "title_subtitle":{"width":630.0,"size":24},
	"continue_game":{"width":198.0,"size":21}, "new_game":{"width":198.0,"size":21}, "settings":{"width":240.0,"size":21}, "exit_game":{"width":198.0,"size":21},
	"resume":{"width":340.0,"size":16}, "save_game":{"width":340.0,"size":16}, "load_game":{"width":340.0,"size":16}, "return_main_menu":{"width":340.0,"size":16},
	"master_volume":{"width":196.0,"size":8}, "music_volume":{"width":196.0,"size":8}, "sfx_volume":{"width":196.0,"size":8}, "sound_enabled":{"width":196.0,"size":8},
	"fullscreen":{"width":196.0,"size":8}, "vsync":{"width":196.0,"size":8}, "reduced_motion":{"width":196.0,"size":8}, "screen_shake":{"width":196.0,"size":8},
	"high_contrast":{"width":196.0,"size":8}, "control_preset":{"width":196.0,"size":8}, "text_scale":{"width":196.0,"size":8}, "touch_scale":{"width":196.0,"size":8}, "language_option":{"width":196.0,"size":8}
}


## Загружает версионированный список визуальных эталонов либо возвращает пустой документ при повреждении файла.
static func manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if parsed is Dictionary else {}


## Загружает отдельный список физических HUD-эталонов, которым разрешены разные пропорции экрана.
static func hud_profile_manifest() -> Dictionary:
	if not FileAccess.file_exists(HUD_PROFILE_MANIFEST_PATH): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(HUD_PROFILE_MANIFEST_PATH))
	return parsed if parsed is Dictionary else {}


## Проверяет существование, геометрию и perceptual-отпечаток эталона, допуская незначительный шум рендера.
static func validate_references() -> Array[String]:
	var errors: Array[String] = []; var document := manifest()
	if int(document.get("schema",0)) != 2: return ["visual manifest schema"]
	var design_size:=Vector2i(int(document.get("design_viewport",[0,0])[0]),int(document.get("design_viewport",[0,0])[1]))
	for entry in document.get("references",[]):
		var path := REFERENCE_DIRECTORY+String(entry.file)
		if not FileAccess.file_exists(path): errors.append("missing:%s"%entry.file); continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image==null: errors.append("invalid:%s"%entry.file); continue
		if image.get_width()!=int(entry.width) or image.get_height()!=int(entry.height): errors.append("size:%s"%entry.file)
		if image.get_size()!=design_size: errors.append("viewport:%s"%entry.file)
		if absf(float(image.get_width())/maxf(image.get_height(),1)-16.0/9.0)>0.01: errors.append("aspect:%s"%entry.file)
		if sampled_contrast(image)<0.08: errors.append("blank:%s"%entry.file)
		var perceptual:Dictionary=entry.get("perceptual",{})
		var baseline:Array[int]=signature_from_hex(String(perceptual.get("rgb_hex","")))
		if baseline.size()!=PERCEPTUAL_GRID.x*PERCEPTUAL_GRID.y*3: errors.append("perceptual-shape:%s"%entry.file); continue
		var thresholds:Dictionary=DEFAULT_PERCEPTUAL_THRESHOLDS.duplicate(); thresholds.merge(perceptual.get("thresholds",{}),true)
		if not signatures_match(baseline,image_signature(image),thresholds): errors.append("perceptual:%s"%entry.file)
	return errors


## Проверяет размеры, содержательность и точные суммы эталонов HUD для 16:9, 16:10 и 21:9.
static func validate_hud_profile_references() -> Array[String]:
	var errors:Array[String]=[]; var document:=hud_profile_manifest()
	if int(document.get("schema",0))!=1: return ["hud-profile-schema"]
	var entries:Array=document.get("profiles",[])
	if entries.size()!=HudLayoutSystem.DISPLAY_PROFILES.size(): errors.append("hud-profile-count")
	for profile in HudLayoutSystem.DISPLAY_PROFILES:
		var index:=entries.find_custom(func(entry):return String(entry.get("id",""))==String(profile.id))
		if index<0: errors.append("hud-profile-missing:%s"%profile.id); continue
		var entry:Dictionary=entries[index]; var path:=HUD_PROFILE_DIRECTORY+String(entry.file)
		if not FileAccess.file_exists(path): errors.append("hud-profile-file:%s"%profile.id); continue
		var image:=Image.load_from_file(ProjectSettings.globalize_path(path)); var size:Vector2i=profile.size
		if image==null: errors.append("hud-profile-invalid:%s"%profile.id); continue
		if image.get_size()!=size or int(entry.width)!=size.x or int(entry.height)!=size.y: errors.append("hud-profile-size:%s"%profile.id)
		if sampled_contrast(image)<0.08: errors.append("hud-profile-blank:%s"%profile.id)
		if FileAccess.get_sha256(path)!=String(entry.sha256): errors.append("hud-profile-hash:%s"%profile.id)
	return errors


## Измеряет диапазон яркости по равномерной сетке, чтобы пустой или одноцветный кадр не прошёл gate.
static func sampled_contrast(image: Image, samples: int = 24) -> float:
	var minimum := 1.0; var maximum := 0.0
	for row in samples:
		for column in samples:
			var x := mini(roundi((column+0.5)*image.get_width()/samples),image.get_width()-1); var y := mini(roundi((row+0.5)*image.get_height()/samples),image.get_height()-1)
			var color := image.get_pixel(x,y); var luminance := color.r*0.2126+color.g*0.7152+color.b*0.0722
			minimum=minf(minimum,luminance); maximum=maxf(maximum,luminance)
	return maximum-minimum


## Возвращает нормализованную среднюю разницу двух кадров по одинаковой сетке контрольных точек.
static func visual_difference(first: Image, second: Image, samples: int = 32) -> float:
	if first==null or second==null or first.get_size()!=second.get_size(): return 1.0
	var total := 0.0
	for row in samples:
		for column in samples:
			var x := mini(roundi((column+0.5)*first.get_width()/samples),first.get_width()-1); var y := mini(roundi((row+0.5)*first.get_height()/samples),first.get_height()-1)
			var a:=first.get_pixel(x,y); var b:=second.get_pixel(x,y); total+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
	return total/(samples*samples)


## Строит компактный RGB-отпечаток кадра по устойчивой сетке усреднённых контрольных точек.
static func image_signature(image:Image, grid:Vector2i=PERCEPTUAL_GRID)->Array[int]:
	var result:Array[int]=[]
	if image==null or image.is_empty(): return result
	for row in grid.y:
		for column in grid.x:
			var sum:=Vector3.ZERO
			for sample_y in PERCEPTUAL_CELL_SAMPLES:
				for sample_x in PERCEPTUAL_CELL_SAMPLES:
					var x:=mini(floori((column+(sample_x+0.5)/PERCEPTUAL_CELL_SAMPLES)*image.get_width()/grid.x),image.get_width()-1)
					var y:=mini(floori((row+(sample_y+0.5)/PERCEPTUAL_CELL_SAMPLES)*image.get_height()/grid.y),image.get_height()-1)
					var color:=image.get_pixel(x,y); sum+=Vector3(color.r,color.g,color.b)
			var divisor:=float(PERCEPTUAL_CELL_SAMPLES*PERCEPTUAL_CELL_SAMPLES)
			result.append(roundi(sum.x/divisor*255.0)); result.append(roundi(sum.y/divisor*255.0)); result.append(roundi(sum.z/divisor*255.0))
	return result


## Декодирует компактное hex-представление RGB-отпечатка из JSON-манифеста.
static func signature_from_hex(value:String)->Array[int]:
	var result:Array[int]=[]
	if value.length()%2!=0: return result
	for offset in range(0,value.length(),2): result.append(value.substr(offset,2).hex_to_int())
	return result


## Возвращает среднее, худшее локальное и долю заметно изменённых блоков между двумя perceptual-отпечатками.
static func signature_metrics(first:Array,second:Array,changed_cell:float=0.035)->Dictionary:
	if first.size()!=second.size() or first.is_empty() or first.size()%3!=0: return {"mean":1.0,"max_cell":1.0,"changed_ratio":1.0}
	var total:=0.0; var maximum:=0.0; var changed:=0; var cells:=first.size()/3
	for cell in cells:
		var offset:=cell*3
		var difference:=(absf(float(first[offset])-float(second[offset]))+absf(float(first[offset+1])-float(second[offset+1]))+absf(float(first[offset+2])-float(second[offset+2])))/(3.0*255.0)
		total+=difference; maximum=maxf(maximum,difference)
		if difference>changed_cell: changed+=1
	return {"mean":total/cells,"max_cell":maximum,"changed_ratio":float(changed)/cells}


## Решает, является ли новый кадр визуально эквивалентным эталону в пределах объявленных допусков.
static func signatures_match(first:Array,second:Array,thresholds:Dictionary=DEFAULT_PERCEPTUAL_THRESHOLDS)->bool:
	var metrics:=signature_metrics(first,second,float(thresholds.get("changed_cell",DEFAULT_PERCEPTUAL_THRESHOLDS.changed_cell)))
	return float(metrics.mean)<=float(thresholds.get("mean",DEFAULT_PERCEPTUAL_THRESHOLDS.mean)) and float(metrics.max_cell)<=float(thresholds.get("max_cell",DEFAULT_PERCEPTUAL_THRESHOLDS.max_cell)) and float(metrics.changed_ratio)<=float(thresholds.get("changed_ratio",DEFAULT_PERCEPTUAL_THRESHOLDS.changed_ratio))


## Сравнивает произвольный снятый кадр с утверждённым файлом и возвращает диагностические метрики вместо одного hash-флага.
static func compare_with_reference(reference_file:String,candidate:Image)->Dictionary:
	var document:=manifest()
	for entry in document.get("references",[]):
		if String(entry.get("file",""))!=reference_file: continue
		var perceptual:Dictionary=entry.get("perceptual",{}); var thresholds:Dictionary=DEFAULT_PERCEPTUAL_THRESHOLDS.duplicate(); thresholds.merge(perceptual.get("thresholds",{}),true)
		var baseline:Array[int]=signature_from_hex(String(perceptual.get("rgb_hex",""))); var signature:=image_signature(candidate); var metrics:=signature_metrics(baseline,signature,float(thresholds.changed_cell))
		metrics.ok=candidate!=null and candidate.get_size()==Vector2i(int(entry.width),int(entry.height)) and signatures_match(baseline,signature,thresholds)
		metrics.file=reference_file; metrics.exact_sha=FileAccess.get_sha256(REFERENCE_DIRECTORY+reference_file)==String(entry.get("sha256",""))
		return metrics
	return {"ok":false,"file":reference_file,"error":"reference-not-found"}


## Проверяет все варианты ключевых кнопок во всех локалях реальной метрикой текущего шрифта и контейнера.
static func validate_localized_controls(game: Node) -> Array[String]:
	var errors: Array[String] = []
	for key in LOCALIZED_CONTROL_CONTRACTS:
		var values: Array = game.LocaleSystem.UI.get(key,[]); var contract: Dictionary = LOCALIZED_CONTROL_CONTRACTS[key]
		if values.size()!=game.LocaleSystem.LOCALES.size(): errors.append("locale-count:%s"%key); continue
		for locale_index in values.size():
			var size: int = game.UiScaleSystem.fitted_font_size(game,game.UI_FONT,String(values[locale_index]),float(contract.width),int(contract.size))
			if size<6: errors.append("overflow:%s:%s"%[key,game.LocaleSystem.LOCALES[locale_index]])
	return errors
