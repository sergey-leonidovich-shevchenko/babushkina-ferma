extends "res://tests/suites/suite_base.gd"

const Water := preload("res://scripts/systems/water_topology.gd")

## Запускает проверки чистой геометрии без подключения новой карты или художественного набора.
func run() -> void:
	test_cardinal_paths_are_atomic()
	test_all_neighbor_masks_and_diagonal_contacts()
	test_water_and_bridge_are_different_surfaces()
	test_radius_uses_circle_not_expanded_square()
	test_nearest_surface_respects_kind_bridge_and_range()
	test_chunks_cache_only_changed_revisions()
	test_local_edits_dirty_only_neighbor_chunks()
	test_bounds_limits_and_invalid_inputs()
	test_decorative_water_does_not_change_physics()
	test_shore_edges_are_axis_aligned()

## Сценарий: осевая река с поворотом и попытка добавить наклонную ветвь.
## Исходное состояние: пустой водный план, затем полностью допустимая Г-образная ось.
## Ожидаемый результат: течение кардинально, некорректная операция не оставляет частичных клеток.
func test_cardinal_paths_are_atomic() -> void:
	var plan := Water.new(); var river := plan.add_body("river")
	expect(plan.add_path([Vector2(24,24),Vector2(120,24),Vector2(120,120)],48,river),"orthogonal path is accepted")
	expect(plan.has_surface(Vector2(72,12)) and plan.has_surface(Vector2(132,96)),"both arms share the same water plane")
	expect(plan.flow_at(Vector2(72,12))==Vector2i.RIGHT and plan.flow_at(Vector2(132,96))==Vector2i.DOWN,"flow follows both cardinal arms")
	var count := plan.cell_count(); var revision := plan.revision()
	expect(not plan.add_path([Vector2(240,240),Vector2(288,240),Vector2(336,288)],48,river),"diagonal tail rejects the whole operation")
	expect(plan.cell_count()==count and plan.revision()==revision and not plan.has_surface(Vector2(264,240)),"failed path does not publish its valid prefix")
	expect(not plan.add_path([Vector2(24,24),Vector2(24,24)],48,river),"zero length path fails")
	expect(not plan.add_path(["bad",Vector2.ZERO],48,river),"invalid point type fails without an engine error")

## Сценарий: все кардинальные маски и независимые диагональные соседства.
## Исходное состояние: центральная клетка и произвольный набор восьми соседей.
## Ожидаемый результат: четырёхсвязная река и информация о вогнутых углах не смешиваются.
func test_all_neighbor_masks_and_diagonal_contacts() -> void:
	for mask in 16:
		for diagonals in 16:
			var plan := Water.new(); var river := plan.add_body("river"); var center := Vector2i(4,4)
			plan.add_rect(Rect2(Vector2(center)*24,Vector2(24,24)),river)
			for index in 4:
				if mask&(1<<index): plan.add_rect(Rect2(Vector2(center+Water.DIRECTIONS[index])*24,Vector2(24,24)),river)
				if diagonals&(1<<index): plan.add_rect(Rect2(Vector2(center+Water.DIAGONALS[index])*24,Vector2(24,24)),river)
			expect(plan.neighbor_mask(center)==mask,"all cardinal masks stay independent: %d/%d"%[mask,diagonals])
			expect(plan.diagonal_mask(center)==diagonals,"all concave masks stay independent: %d/%d"%[mask,diagonals])
	var plan := Water.new(); var body := plan.add_body("pond")
	plan.add_rect(Rect2(0,0,24,24),body); plan.add_rect(Rect2(24,24,24,24),body)
	expect(plan.neighbor_mask(Vector2i.ZERO)==0 and plan.shore_edges().size()==8,"diagonal contact keeps two separate water shores")

## Сценарий: герой проходит по настилу, под которым сохраняется водная поверхность.
## Исходное состояние: водоём и узкий мост с точной привязкой к сетке.
## Ожидаемый результат: круг помещается на настиле; выход за боковой край не разрешён.
func test_water_and_bridge_are_different_surfaces() -> void:
	var plan := Water.new(); var body := plan.add_body("river")
	plan.add_rect(Rect2(0,0,72,72),body); plan.add_bridge(Rect2(24,0,24,72))
	expect(plan.has_surface(Vector2(36,36)) and plan.kind_at(Vector2(36,36))=="river","water stays beneath a bridge")
	expect(plan.on_bridge(Vector2(36,36),12) and not plan.blocks_movement(Vector2(36,36),12),"fitting circle walks on the deck")
	expect(not plan.on_bridge(Vector2(36,36),13) and plan.blocks_movement(Vector2(36,36),13),"circle wider than deck cannot use point-only bridge override")
	plan.remove_bridge(Rect2(24,0,24,72))
	expect(plan.has_surface(Vector2(36,36)) and plan.blocks_movement(Vector2(36,36),6),"removing deck restores water blocking without filling it again")

## Сценарий: круг касается края и проходит рядом с углом одного тайла.
## Исходное состояние: единственная водная клетка.
## Ожидаемый результат: нет ложной квадратной коллизии и незамеченного пересечения.
func test_radius_uses_circle_not_expanded_square() -> void:
	var plan := Water.new(); plan.add_rect(Rect2(0,0,24,24),plan.add_body("pond"))
	expect(not plan.blocks_movement(Vector2(27,27),4),"circle outside corner remains dry despite overlapping expanded AABB")
	expect(plan.blocks_movement(Vector2(27,27),4.3),"slightly larger circle intersects the real corner")
	expect(plan.blocks_movement(Vector2(27,12),4),"radius blocks crossing the side")
	expect(not plan.blocks_movement(Vector2(28,12),4),"exact tangency does not become a penetration")

## Сценарий: поплавку нужна видимая вода нужного типа в пределах дальности.
## Исходное состояние: река, настил над ближайшей клеткой и отдельный пруд.
## Ожидаемый результат: найденная точка не лежит на настиле и не выходит за предел дальности.
func test_nearest_surface_respects_kind_bridge_and_range() -> void:
	var plan := Water.new(); var river := plan.add_body("river"); var pond := plan.add_body("pond")
	plan.add_rect(Rect2(48,0,48,48),river); plan.add_rect(Rect2(120,0,48,48),pond); plan.add_bridge(Rect2(48,0,24,48))
	var found := plan.nearest_surface(Vector2(0,12),80,["river"])
	expect(found.is_finite() and plan.has_surface(found) and not plan.on_bridge(found),"nearest cast skips hidden water under the deck")
	expect(plan.kind_at(plan.nearest_surface(Vector2(0,12),160,["pond"]))=="pond","query uses semantic water kind")
	expect(not plan.nearest_surface(Vector2(0,12),40).is_finite(),"out-of-range cast has no invented target")
	expect(not plan.nearest_surface(Vector2(0,12),160,["lava"]).is_finite(),"unknown requested kind has no target")
	var copy := plan.body(river); copy.kind="lava"
	expect(plan.kind_at(Vector2(84,12))=="river","external metadata copy cannot alter water semantics")

## Сценарий: много одинаковых запросов, повторное добавление, стирание и изменение снимков.
## Исходное состояние: построенный чанк с известной ревизией.
## Ожидаемый результат: неизменный кадр не перестраивает разбиение, внешние массивы не портят источник.
func test_chunks_cache_only_changed_revisions() -> void:
	var plan := Water.new(); var body := plan.add_body("river")
	plan.add_rect(Rect2(-24,-24,48,48),body)
	var chunks := plan.chunks(); expect(chunks.size()==4,"negative cells use floor division for chunk coordinates")
	chunks.clear(); var cells := plan.cells(); cells.clear()
	var revision := plan.revision()
	for index in 30: plan.chunks(); plan.has_surface(Vector2.ZERO)
	expect(plan.cache_builds==1 and plan.cell_count()==4 and plan.chunks().size()==4,"readers cannot invalidate cached source or mutate snapshots")
	plan.add_rect(Rect2(-24,-24,48,48),body); plan.chunks()
	expect(plan.revision()==revision and plan.cache_builds==1,"identical paint does not invalidate geometry")
	plan.erase_rect(Rect2(0,0,24,24)); plan.chunks()
	expect(plan.cell_count()==3 and not plan.has_surface(Vector2(12,12)) and plan.cache_builds==2,"erase invalidates exactly the changed revision")

## Сценарий: изменение внутренней клетки и клетки у границы группы.
## Исходное состояние: две далёкие группы и уже обработанный пакет грязных областей.
## Ожидаемый результат: далёкая группа не инвалидируется; сосед кромки получает обновление.
func test_local_edits_dirty_only_neighbor_chunks() -> void:
	var plan := Water.new(); var id := plan.add_body("river")
	plan.add_rect(Rect2(48,48,24,24),id); plan.add_rect(Rect2(2400,2400,24,24),id); plan.take_dirty_chunks()
	plan.add_rect(Rect2(72,72,24,24),id)
	var dirty := plan.take_dirty_chunks()
	expect(dirty.size()==1 and Vector2i.ZERO in dirty,"interior edit invalidates just its own chunk")
	expect(plan.take_dirty_chunks().is_empty(),"dirty queue is drained without touching source cells")
	plan.add_rect(Rect2(360,48,24,24),id)
	dirty=plan.take_dirty_chunks()
	expect(dirty.size()==2 and Vector2i.ZERO in dirty and Vector2i.RIGHT in dirty,"boundary edit refreshes both sides of the shoreline seam")
	expect(plan.chunk_cells(Vector2i(6,6)).size()==1,"distant chunk retains its exact membership")
	plan.erase_rect(Rect2(2400,2400,24,24))
	expect(plan.chunk_cells(Vector2i(6,6)).is_empty(),"removing the last cell clears the obsolete group")

## Сценарий: некорректные границы, размеры, поток, радиус и слишком большой участок.
## Исходное состояние: ограниченная карта и заранее зарегистрированный водоём.
## Ожидаемый результат: геометрия не округляет ошибочные данные и не выделяет неограниченную память.
func test_bounds_limits_and_invalid_inputs() -> void:
	var plan := Water.new(Rect2(0,0,48,48)); var body := plan.add_body("river")
	expect(plan.add_rect(Rect2(-24,-24,96,96),body) and plan.cell_count()==4,"bounds clip whole aligned cells")
	expect(not plan.add_rect(Rect2(1,0,24,24),body) and not plan.add_rect(Rect2(0,0,24,24),999),"off-grid geometry and unknown body are rejected")
	expect(not plan.add_rect(Rect2(0,0,24,24),body,Vector2i(1,1)),"diagonal flow is rejected")
	var large := Water.new(); var id := large.add_body("river")
	expect(not large.add_rect(Rect2(0,0,(Water.MAX_CELLS+1)*24,24),id) and large.cell_count()==0,"oversized paint fails before allocation or partial publish")
	expect(not large.add_rect(Rect2(120000.5,0,24,24),id),"large coordinates do not enlarge the accepted grid error")
	var invalid := Water.new(Rect2(1,0,48,48)); var invalid_body := invalid.add_body("river")
	expect(not invalid.add_rect(Rect2(0,0,24,24),invalid_body) and not invalid.add_rect(Rect2(0,0,24,24),invalid_body),"invalid initial bounds remain invalid after multiple attempts")
	var negative := Water.new(Rect2(0,0,-48,48)); var negative_body := negative.add_body("river")
	expect(not negative.add_rect(Rect2(0,0,24,24),negative_body),"negative-size bounds are not mistaken for an unrestricted map")
	expect(plan.blocks_movement(Vector2(NAN,0),2) and plan.blocks_movement(Vector2.ZERO,-1),"invalid physical query fails closed")
	expect(not plan.nearest_surface(Vector2.ZERO,INF).is_finite(),"unbounded nearest query is rejected")

## Сценарий: декоративная вода Лунной поляны использует тот же контур без новой скрытой физики.
## Исходное состояние: водоём явно помечен непроходимым либо декоративным при создании.
## Ожидаемый результат: визуальная поверхность не равна автоматическому запрету движения.
func test_decorative_water_does_not_change_physics() -> void:
	var plan := Water.new(); var id := plan.add_body("decorative","stone",false)
	plan.add_rect(Rect2(0,0,48,48),id)
	expect(plan.has_surface(Vector2(12,12)) and not plan.blocks_movement(Vector2(12,12),8),"decorative pool keeps its existing nonblocking semantics")

## Сценарий: renderer получает прямые стороны небольшого квадратного водоёма.
## Исходное состояние: четыре смежные клетки воды.
## Ожидаемый результат: только внешний периметр и кардинальные нормали, без внутренних и диагональных швов.
func test_shore_edges_are_axis_aligned() -> void:
	var plan := Water.new(); plan.add_rect(Rect2(0,0,48,48),plan.add_body("lake"))
	var edges := plan.shore_edges(); expect(edges.size()==8,"four tiles expose eight outer segments")
	for edge in edges:
		var delta: Vector2=edge.finish-edge.start
		expect((is_zero_approx(delta.x) or is_zero_approx(delta.y)) and is_equal_approx(delta.length(),24),"shore edge is one cardinal tile")
		expect(edge.normal in Water.DIRECTIONS,"shore normal points toward a cardinal dry neighbor")
