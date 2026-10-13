extends RefCounted

const Layout := preload("res://scripts/presentation/compact_dialogue_layout.gd")

## Разбивает реплику на читаемые страницы без удаления символов и уменьшения выбранного кегля.
static func pages(font: Font, text: String, width: float, height: float, size: int) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]; var start:=0
	while start<text.length():
		var low:=1; var high:=text.length()-start; var fitted:=1
		while low<=high:
			var middle:=(low+high)/2
			var measured:=font.get_multiline_string_size(text.substr(start,middle),HORIZONTAL_ALIGNMENT_LEFT,width,size)
			if measured.x<=width+0.01 and measured.y<=height+0.01: fitted=middle; low=middle+1
			else: high=middle-1
		if start+fitted<text.length():
			var prefix:=text.substr(start,fitted); var boundary:=maxi(prefix.rfind(" "),prefix.rfind("\n"))
			if boundary>fitted/2: fitted=boundary+1
		result.append({"text":text.substr(start,fitted),"start":start,"length":fitted}); start+=fitted
	if result.is_empty(): result.append({"text":"","start":0,"length":0})
	return result

## Кэширует переносы текущей реплики по тексту, реальному шрифту и пользовательскому масштабу.
static func layout(game: Node) -> Dictionary:
	var dialogue:Dictionary=game.state.player.adventure_ui.get("dialogue",{})
	var text:=String(dialogue.get("text",""))
	var size:=maxi(1,roundi(Layout.BODY_SIZE*game.settings_state.text_scale))
	var key:=[text,game.UI_FONT.get_instance_id(),game.UI_FONT.get_rids(),size]
	var cached:Dictionary=dialogue.get("_compact_layout",{})
	if cached.get("key",[])!=key:
		cached={"key":key,"size":size,"pages":pages(game.UI_FONT,text,Layout.BODY.size.x,Layout.BODY.size.y,size)}
		dialogue._compact_layout=cached
	return cached

## Возвращает индекс существующей страницы и не позволяет старому полю выйти за её пределы.
static func page_index(game: Node) -> int:
	var page:=clampi(int(game.state.player.adventure_ui.get("dialogue",{}).get("page",0)),0,layout(game).pages.size()-1)
	game.state.player.adventure_ui.dialogue.page=page
	return page

## Определяет, требуется ли сначала дочитать следующую страницу до решения по поручению.
static func has_next(game: Node) -> bool:
	return page_index(game)<layout(game).pages.size()-1

## Переключает страницу, сохраняя выбор миссии и начиная плавное раскрытие следующего фрагмента.
static func advance(game: Node) -> bool:
	if not has_next(game): return false
	var dialogue:Dictionary=game.state.player.adventure_ui.dialogue
	dialogue.page=page_index(game)+1
	dialogue.revealed=maxf(float(dialogue.get("revealed",0)),float(layout(game).pages[int(dialogue.page)].start))
	game.state.player.adventure_ui.choice=0
	return true

## Возвращает только раскрытую часть текущей страницы, сохраняя все символы полного рассказа.
static func visible_text(game: Node) -> String:
	var packet:Dictionary=layout(game).pages[page_index(game)]
	var revealed:=floori(float(game.state.player.adventure_ui.dialogue.get("revealed",String(game.state.player.adventure_ui.dialogue.get("text","")).length())))
	return String(packet.text).left(clampi(revealed-int(packet.start),0,int(packet.length)))
