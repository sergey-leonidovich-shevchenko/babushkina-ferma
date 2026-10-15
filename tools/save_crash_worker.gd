extends SceneTree

const Store := preload("res://scripts/systems/atomic_json_store.gd")

## Пишет только в выделенный каталог родителя; на выбранной границе ждёт принудительного завершения дочернего процесса.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2: quit(2); return
	var path:String=args[0]; var checkpoint:String=args[1]
	if not path.begins_with("/private/tmp/farm-safe-crash-") or path.simplify_path()!=path or path.get_file()!="slot.json": quit(3); return
	var observer:=func(point: String, _target: String) -> bool:
		if point==checkpoint:
			var marker:=FileAccess.open(path+".checkpoint",FileAccess.WRITE)
			marker.store_string(point); marker.flush(); marker.close()
			while true: OS.delay_msec(20)
		return true
	Store.write(path,{"revision":2,"payload":"healthy"},healthy,true,observer)
	quit(4)

## Принимает только точный тестовый документ; обычные пользовательские слоты этот процесс не читает.
func healthy(data: Dictionary) -> bool:
	return (data.get("revision") is int or data.get("revision") is float) and float(data.revision) in [1.0,2.0] and data.get("payload","")=="healthy"
