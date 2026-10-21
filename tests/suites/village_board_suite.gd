extends RefCounted
const Board:=preload("res://scripts/presentation/village_board_visual.gd")
const Layout:=preload("res://scripts/systems/village_layout_system.gd")
const Points:=preload("res://tools/visual_camera_points.gd")
const Rules:=preload("res://tools/ground_seasons_fixture.gd")
const Wayfinding:=preload("res://scripts/systems/village_wayfinding_system.gd")
const Regions:=preload("res://scripts/systems/village_region_system.gd")
const Labels:=preload("res://scripts/presentation/world_label_renderer.gd")

## Проверяет самостоятельные виды, неизменные опоры и ограниченный кеш теней.
static func run(ctx:SceneTree)->void:
	var ground:=Vector2(720.25,612.5)
	for kind in ["board","sign"]:
		var paths:=[]
		for side in [0,1,3]:
			var view:=Board.view(kind,side);var rect:=Board.destination(kind,ground,side);paths.append(view.path)
			ctx.expect(rect.size.is_equal_approx(view.source.size*0.25),"board uniform source density: "+kind+str(side))
			ctx.expect((rect.position+rect.size*view.pivot).is_equal_approx(ground),"board exact fractional anchor: "+kind+str(side))
			ctx.expect(Board.shadow(kind,side)==Board.shadow(kind,side),"board reuses shadow mesh: "+kind+str(side))
			ctx.expect(Board.shadow(kind,side).get_surface_count()==1,"board single shadow surface: "+kind+str(side))
			ctx.expect(Board.contacts(kind,ground,side).size()==(2 if kind=="board" else 1),"board structural contacts retained: "+kind+str(side))
			ctx.expect(Board.approach(kind,ground,side)!=ground,"board one displayed reading side: "+kind+str(side))
		ctx.expect(paths[0]!=paths[1] and paths[1]!=paths[2] and paths[0]!=paths[2],"board three independent PNG: "+kind)
		ctx.expect(Board.destination(kind,ground,2)==Board.destination(kind,ground,0),"board legacy rear aliases front: "+kind)
	ctx.expect(Board._shadows.size()==6,"board mesh cache bounded to six")
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0])
	var rules:=Rules.rules(game);var before:Dictionary=game.SaveSystem.snapshot(game)
	for i in 24:
		Board.destination("board",Vector2(i*24,600),i%4);Board.shadow("sign",i%4)
	ctx.expect(game.SaveSystem.snapshot(game)==before and Rules.rules(game)==rules,"board lookups preserve save and 1200 navigation rules")
	var count:=0
	for prop in Layout.PROP_PLACEMENTS:
		if prop.kind!="board":continue
		count+=1
		ctx.expect(Layout.prop_collision_rect(prop)==Rect2(prop.position+Vector2(-36,0),Vector2(72,24)),"board original solid footprint: "+str(prop.position))
	ctx.expect(count==2,"board exactly two original solid placements")
	for link in Board.Regions.passages("overworld"):
		var point:=Board.sign_ground(link)
		ctx.expect(is_zero_approx(fposmod(point.x,24)) and is_zero_approx(fposmod(point.y,24)),"wayfinding post ground on grid: "+String(link.port))
	locales(ctx,game)
	game.player=Board.Regions.port_position("overworld","right")
	ctx.expect(Regions.travel(game,"right") and game.current_location=="village_market","board keeps actual market transition")
	game.player=Board.Regions.port_position("village_market","left")
	ctx.expect(Regions.travel(game,"left") and game.current_location=="overworld","board keeps actual return transition")
	game.free()

## Проверяет живой перевод и настоящие метрики шрифта во всех шести языках.
static func locales(ctx:SceneTree,game:Node)->void:
	var original:String=game.LocaleSystem.current;var variants:=[]
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale,false);var titles:=[]
		for link in Board.Regions.passages("overworld"):
			game.player=link.position+Board.Regions.INWARD[link.port]*80;game.update_camera()
			var title:String=Wayfinding.title(game,link);titles.append(title)
			var tags:String=Wayfinding.tags(game,link.port)
			var rect:=Labels.bounds(game,link.position+Vector2(0,24),title,200,0 if tags.is_empty() else 22)
			var fitted:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,title,rect.size.x-8,20,11)
			ctx.expect(title.begins_with(Wayfinding.ARROWS[link.port]) and title.length()>2,"wayfinding translated directional title: "+locale+String(link.port))
			ctx.expect(fitted>=8 and game.UI_FONT.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x<=rect.size.x-8,"wayfinding title fits real font width: "+locale+String(link.port))
			if not tags.is_empty():
				var tag_size:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,tags,rect.size.x-8,20,10)
				ctx.expect(tag_size>=8 and game.UI_FONT.get_string_size(tags,HORIZONTAL_ALIGNMENT_LEFT,-1,tag_size).x<=rect.size.x-8,"wayfinding second line fits real font width: "+locale+String(link.port))
			var glyphs:=true
			for i in title.length():glyphs=glyphs and game.UI_FONT.has_char(title.unicode_at(i))
			ctx.expect(glyphs,"wayfinding actual font supports locale glyphs: "+locale+String(link.port))
		variants.append(titles)
	ctx.expect(variants.size()==6 and variants[0]!=variants[1] and variants[1]!=variants[5],"wayfinding locales use live strings independently of PNG")
	game.LocaleSystem.set_locale(original,false)
