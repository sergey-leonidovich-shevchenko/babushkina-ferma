extends "res://tests/suites/suite_base.gd"

const Store := preload("res://scripts/systems/atomic_json_store.gd")
const POINTS := ["primary.before_stage","primary.after_open","primary.after_write","primary.after_flush","primary.after_validate","backup.before_stage","backup.after_open","backup.after_write","backup.after_flush","backup.after_validate","backup.before_replace","backup.after_replace","primary.before_replace","primary.after_replace"]

## Проверяет локальный отказ каждой границы и порчу временного JSON без обращения к слотам пользователя.
func run() -> void:
	test_every_write_boundary()
	test_corrupt_temporary_and_invalid_payload()

## Принимает только маленький документ этого стенда, включая семантику номера ревизии.
func valid(data: Dictionary) -> bool:
	return (data.get("revision") is int or data.get("revision") is float) and float(data.revision) in [1.0,2.0] and data.get("payload","")=="healthy"

## Удаляет только файлы конкретного уникального временного пути текущего теста.
func cleanup(path: String) -> void:
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)

## Сценарий: искусственный отказ возвращается до и после каждой стадии временной записи и переименования.
## Исходное состояние: валидная ревизия один, новый документ ревизии два и отдельный путь в системном tmp.
## Ожидаемый результат: до подтверждения основной файл прежний, после него новый; хотя бы один последний здоровый слот доступен.
func test_every_write_boundary() -> void:
	for checkpoint in POINTS:
		var path:=OS.get_temp_dir().path_join("farm-safe-fault-%d.json" % Time.get_ticks_usec())
		expect(Store.write(path,{"revision":1,"payload":"healthy"},valid),"fault baseline writes: "+checkpoint)
		var reached:=[false]
		var fault:=func(point: String, _path: String) -> bool:
			if point==checkpoint: reached[0]=true; return false
			return true
		var committed:bool=checkpoint=="primary.after_replace"
		expect(Store.write(path,{"revision":2,"payload":"healthy"},valid,true,fault)==committed and reached[0],"write result follows the commit boundary: "+checkpoint)
		var primary:=Store.read(path)
		expect(valid(primary) and int(primary.revision)==(2 if committed else 1),"latest healthy primary survives fault: "+checkpoint)
		expect(not FileAccess.file_exists(path+".tmp") and not FileAccess.file_exists(path+".bak.tmp"),"rejected write cleans only temporary files: "+checkpoint)
		cleanup(path)

## Сценарий: временный файл подменён неверным JSON, новый документ нарушает схему или имитируется отказ полного диска.
## Исходное состояние: исправный основной документ и временный путь, недоступный только для текущей операции.
## Ожидаемый результат: ни синтаксическая, ни структурная ошибка не заменяет здоровый файл; инъекция не остаётся включённой.
func test_corrupt_temporary_and_invalid_payload() -> void:
	var path:=OS.get_temp_dir().path_join("farm-safe-fault-%d.json" % Time.get_ticks_usec())
	Store.write(path,{"revision":1,"payload":"healthy"},valid)
	var corrupt:=func(point: String, target: String) -> bool:
		if point=="primary.after_flush":
			var file:=FileAccess.open(target+".tmp",FileAccess.WRITE); file.store_string("{broken"); file.close()
		return true
	expect(not Store.write(path,{"revision":2,"payload":"healthy"},valid,true,corrupt) and Store.read(path).revision==1,"corrupted staged text refuses before backup or primary promotion")
	expect(not Store.write(path,{"revision":99},valid,true) and Store.read(path).revision==1,"invalid application schema never reaches commit")
	var no_space:=func(point: String, _target: String) -> bool: return point!="primary.after_write"
	expect(not Store.write(path,{"revision":2,"payload":"healthy"},valid,true,no_space) and Store.read(path).revision==1,"simulated short write/full disk preserves old slot")
	expect(Store.write(path,{"revision":2,"payload":"healthy"},valid,true) and Store.read(path).revision==2,"fault callback belongs only to its own write")
	cleanup(path)
