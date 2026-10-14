extends "res://tools/storage_perf_review.gd"

## Дополняет прежний нативный профиль числом действительно запрошенных предметных оригиналов.
func snapshot() -> Dictionary:
	var value:=super.snapshot()
	if game!=null: value.item_sources=game.VisualAssetSystem.item_cache_info()
	return value
