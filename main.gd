extends Node2D

# Containment Protocol - Godot 4.3
# Portrait 720x1280, drawn natively for low-overhead Android rendering.

const VIEW_SIZE := Vector2(720.0, 1280.0)
const BAR_TOP := 1080.0
const EVAC_ZONE := Vector2(360.0, 205.0)
const EVAC_RADIUS := 76.0
const MAX_WAVES := 5
const GRID_CELL_SIZE := 64.0
const UNIT_SELECT_RADIUS := 30.0
const BUILDING_RADIUS := 11.0

const DEPLOYMENTS := [
	{"name": "INFANTRY", "detail": "SQUAD  $100", "cost": 100, "kind": "infantry"},
	{"name": "BARRICADE", "detail": "WALL  $75", "cost": 75, "kind": "barricade"},
	{"name": "SNIPER", "detail": "TEAM  $200", "cost": 200, "kind": "sniper"},
	{"name": "AIRSTRIKE", "detail": "$300", "cost": 300, "kind": "airstrike"}
]

var civilians: Array[Vector2] = []
var zombies: Array[Dictionary] = []
var units: Array[Dictionary] = []
var barricades: Array[Vector2] = []
var funds := 300
var saved_count := 0
var lost_count := 0
var selected_deployment := 0
var game_state := "playing"
var wave := 0
var wave_timer := 2.0
var elapsed := 0.0
var message := "EVACUATE CIVILIANS. HOLD THE LINE."
var message_timer := 4.0
var airstrike_marker := Vector2.ZERO
var airstrike_timer := 0.0
var screen_font: Font
var buildings: Array[Rect2] = []
var civilian_grid: Dictionary = {}
var zombie_grid: Dictionary = {}
var zombie_positions: Array[Vector2] = []
var selected_unit_index := -1
var time_scale_index := 0
const TIME_SCALES := [1.0, 0.25, 0.0]
const TIME_LABELS := ["1x", "0.25x", "PAUSE"]
var bullet_tracers: Array[Dictionary] = []
var muzzle_flashes: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var shake_timer := 0.0
var shake_strength := 0.0

func _ready() -> void:
	randomize()
	screen_font = ThemeDB.fallback_font
	_setup_city()
	_start_round()
	queue_redraw()

func _start_round() -> void:
	civilians.clear()
	zombies.clear()
	units.clear()
	barricades.clear()
	funds = 300
	saved_count = 0
	lost_count = 0
	wave = 0
	wave_timer = 2.0
	elapsed = 0.0
	game_state = "playing"
	selected_deployment = 0
	selected_unit_index = -1
	time_scale_index = 0
	bullet_tracers.clear()
	muzzle_flashes.clear()
	shockwaves.clear()
	shake_timer = 0.0
	message = "EVACUATE CIVILIANS. HOLD THE LINE."
	message_timer = 4.0
	for i in range(45):
		civilians.append(Vector2(randf_range(52.0, 668.0), randf_range(510.0, 1030.0)))

func _process(delta: float) -> void:
	_update_combat_effects(delta)
	if game_state != "playing":
		queue_redraw()
		return

	var sim_delta: float = delta * TIME_SCALES[time_scale_index]
	if sim_delta <= 0.0:
		queue_redraw()
		return

	elapsed += sim_delta
	message_timer = maxf(0.0, message_timer - sim_delta)
	airstrike_timer = maxf(0.0, airstrike_timer - sim_delta)
	wave_timer -= sim_delta

	if wave < MAX_WAVES and wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = 18.0

	# Civilians evacuate through the street network; the grid is rebuilt once
	# after movement so every zombie queries current civilian positions.
	for i in range(civilians.size() - 1, -1, -1):
		var civilian: Vector2 = civilians[i]
		var direction: Vector2 = (EVAC_ZONE - civilian).normalized()
		var displacement: Vector2 = direction * 43.0 * sim_delta
		civilian = _move_circle_with_buildings(civilian, displacement, 5.5)
		civilians[i] = civilian
		if civilian.distance_to(EVAC_ZONE) <= EVAC_RADIUS:
			civilians.remove_at(i)
			saved_count += 1
			funds += 25
			message = "CIVILIAN EVACUATED  +$25"
			message_timer = 1.1

	civilian_grid = _build_spatial_grid(civilians)
	for i in range(zombies.size() - 1, -1, -1):
		var zombie: Dictionary = zombies[i]
		var zpos: Vector2 = zombie["pos"]
		var target_index: int = _find_nearest_entity(civilian_grid, civilians, zpos, 640.0)
		var target: Vector2 = EVAC_ZONE
		if target_index >= 0:
			target = civilians[target_index]
		var speed: float = 112.0 if zombie["kind"] == "runner" else 61.0
		var displacement: Vector2 = (target - zpos).normalized() * speed * sim_delta
		zpos = _move_circle_with_buildings(zpos, displacement, 7.0)

		# Barricades remain deployable soft blockers in addition to city walls.
		for wall in barricades:
			if zpos.distance_to(wall) < 27.0:
				zpos -= (target - wall).normalized() * 38.0 * sim_delta
				break
		zombie["pos"] = zpos
		zombies[i] = zombie

		for c_idx in range(civilians.size() - 1, -1, -1):
			if zpos.distance_to(civilians[c_idx]) < 15.0:
				var infected_pos: Vector2 = civilians[c_idx]
				civilians.remove_at(c_idx)
				civilian_grid = _build_spatial_grid(civilians)
				lost_count += 1
				zombies.append({"pos": infected_pos, "kind": "shambler"})
				message = "CIVILIAN LOST"
				message_timer = 1.4
				break

	zombie_grid = _build_zombie_spatial_grid()
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - sim_delta)
		if float(unit["cooldown"]) > 0.0 or zombies.is_empty():
			continue
		var unit_pos: Vector2 = unit["pos"]
		var is_sniper: bool = unit["kind"] == "sniper"
		var attack_range: float = 390.0 if is_sniper else 205.0
		var target_index: int = _find_nearest_zombie(unit_pos, attack_range)
		if target_index >= 0:
			var target_pos: Vector2 = zombies[target_index]["pos"]
			_add_bullet_tracer(unit_pos, target_pos)
			zombies.remove_at(target_index)
			unit["cooldown"] = 1.05 if is_sniper else 0.62
			muzzle_flashes.append({"pos": unit_pos, "life": 0.10, "max_life": 0.10})
			zombie_grid = _build_zombie_spatial_grid()
		units[unit_index] = unit

	if wave >= MAX_WAVES and zombies.is_empty() and civilians.is_empty():
		game_state = "victory"
		message = "SECTOR SECURED"
	elif civilians.is_empty() and saved_count == 0 and lost_count > 0:
		game_state = "defeat"
		message = "EVACUATION FAILED"

	queue_redraw()


func _setup_city() -> void:
	buildings = [
		Rect2(48.0, 330.0, 190.0, 112.0),
		Rect2(482.0, 326.0, 190.0, 132.0),
		Rect2(58.0, 650.0, 174.0, 142.0),
		Rect2(488.0, 670.0, 184.0, 138.0),
		Rect2(270.0, 866.0, 180.0, 104.0)
	]

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / GRID_CELL_SIZE), floori(position.y / GRID_CELL_SIZE))

func _build_spatial_grid(positions: Array[Vector2]) -> Dictionary:
	var grid: Dictionary = {}
	for index in range(positions.size()):
		var cell: Vector2i = _cell_for(positions[index])
		if not grid.has(cell):
			var bucket: Array[int] = []
			grid[cell] = bucket
		var entries: Array = grid[cell]
		entries.append(index)
		grid[cell] = entries
	return grid

func _build_zombie_spatial_grid() -> Dictionary:
	zombie_positions.clear()
	zombie_positions.resize(zombies.size())
	for index in range(zombies.size()):
		zombie_positions[index] = zombies[index]["pos"]
	return _build_spatial_grid(zombie_positions)

func _find_nearest_entity(grid: Dictionary, positions: Array[Vector2], origin: Vector2, radius: float) -> int:
	# Bound the cell neighborhood: lookup work stays independent of total entity count.
	var cell_radius: int = mini(ceili(radius / GRID_CELL_SIZE), 6)
	var center_cell: Vector2i = _cell_for(origin)
	var best_index := -1
	var best_distance := radius * radius
	for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
		for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			var entries: Array = grid[cell]
			for raw_index in entries:
				var index: int = int(raw_index)
				if index >= positions.size():
					continue
				var distance: float = origin.distance_squared_to(positions[index])
				if distance < best_distance:
					best_distance = distance
					best_index = index
	return best_index

func _find_nearest_zombie(origin: Vector2, radius: float) -> int:
	return _find_nearest_entity(zombie_grid, zombie_positions, origin, radius)

func _move_circle_with_buildings(origin: Vector2, displacement: Vector2, radius: float) -> Vector2:
	var position: Vector2 = origin
	var remaining: Vector2 = displacement
	for iteration in range(2):
		var candidate: Vector2 = position + remaining
		for building in buildings:
			var closest: Vector2 = Vector2(
				clampf(candidate.x, building.position.x, building.end.x),
				clampf(candidate.y, building.position.y, building.end.y)
			)
			var offset: Vector2 = candidate - closest
			var distance: float = offset.length()
			if distance < radius:
				var normal := Vector2.ZERO
				if distance > 0.001:
					normal = offset / distance
				else:
					var left_gap: float = candidate.x - building.position.x
					var right_gap: float = building.end.x - candidate.x
					var top_gap: float = candidate.y - building.position.y
					var bottom_gap: float = building.end.y - candidate.y
					var smallest: float = minf(minf(left_gap, right_gap), minf(top_gap, bottom_gap))
					if smallest == left_gap:
						normal = Vector2.LEFT
					elif smallest == right_gap:
						normal = Vector2.RIGHT
					elif smallest == top_gap:
						normal = Vector2.UP
					else:
						normal = Vector2.DOWN
				candidate = closest + normal * radius
				var into_wall: float = remaining.dot(normal)
				if into_wall < 0.0:
					remaining -= normal * into_wall
		position = candidate
	return position

func _is_valid_street_position(position: Vector2) -> bool:
	if position.x < 28.0 or position.x > 692.0 or position.y < 270.0 or position.y > 1060.0:
		return false
	for building in buildings:
		var expanded := building.grow(UNIT_SELECT_RADIUS)
		if expanded.has_point(position):
			return false
	return true

func _update_combat_effects(delta: float) -> void:
	shake_timer = maxf(0.0, shake_timer - delta)
	for i in range(bullet_tracers.size() - 1, -1, -1):
		bullet_tracers[i]["life"] = float(bullet_tracers[i]["life"]) - delta
		if float(bullet_tracers[i]["life"]) <= 0.0:
			bullet_tracers.remove_at(i)
	for i in range(muzzle_flashes.size() - 1, -1, -1):
		muzzle_flashes[i]["life"] = float(muzzle_flashes[i]["life"]) - delta
		if float(muzzle_flashes[i]["life"]) <= 0.0:
			muzzle_flashes.remove_at(i)
	for i in range(shockwaves.size() - 1, -1, -1):
		var effect: Dictionary = shockwaves[i]
		effect["life"] = float(effect["life"]) - delta
		effect["radius"] = minf(190.0, float(effect["radius"]) + 280.0 * delta)
		if float(effect["life"]) <= 0.0:
			shockwaves.remove_at(i)
		else:
			shockwaves[i] = effect

func _add_bullet_tracer(origin: Vector2, target: Vector2) -> void:
	bullet_tracers.append({"from": origin, "to": target, "life": 0.12, "max_life": 0.12})

func _draw_buildings() -> void:
	for building in buildings:
		draw_rect(building, Color("#172b27"))
		draw_rect(building, Color("#49645a"), false, 3.0)
		draw_line(building.position + Vector2(10.0, 14.0), building.position + Vector2(building.size.x - 10.0, 14.0), Color("#314a41"), 2.0)
		draw_line(building.position + Vector2(10.0, building.size.y - 14.0), building.position + Vector2(building.size.x - 10.0, building.size.y - 14.0), Color("#314a41"), 2.0)

func _spawn_wave() -> void:
	wave += 1
	var count := 5 + wave * 3
	for i in range(count):
		var x := randf_range(42.0, 678.0)
		var y := randf_range(1130.0, 1260.0)
		var runner := randf() < (0.16 + float(wave) * 0.045)
		zombies.append({
			"pos": Vector2(x, y),
			"kind": "runner" if runner else "shambler"
		})
	message = "HORDE WAVE %d INBOUND" % wave
	message_timer = 2.5

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)

func _handle_tap(pos: Vector2) -> void:
	if game_state != "playing":
		if pos.y > 900.0:
			_start_round()
		return
	if pos.x >= 520.0 and pos.y >= 145.0 and pos.y <= 215.0:
		time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()
		queue_redraw()
		return
	if pos.y >= BAR_TOP:
		var button_width := VIEW_SIZE.x / 4.0
		selected_deployment = clampi(int(pos.x / button_width), 0, 3)
		message = str(DEPLOYMENTS[selected_deployment]["name"]) + " SELECTED"
		message_timer = 1.2
		queue_redraw()
		return
	if pos.y < 270.0:
		return

	# Squad hit-testing takes priority over repositioning, so tapping another
	# deployed squad changes selection instead of moving the current selection.
	for squad_index in range(units.size() - 1, -1, -1):
		if pos.distance_to(units[squad_index]["pos"]) <= UNIT_SELECT_RADIUS:
			selected_unit_index = squad_index
			message = "SQUAD SELECTED — TAP STREET TO MOVE"
			message_timer = 2.0
			queue_redraw()
			return
	# First tap selects a deployed squad; the next valid street tap repositions it.
	if selected_unit_index >= 0 and selected_unit_index < units.size():
		if _is_valid_street_position(pos):
			units[selected_unit_index]["pos"] = pos
			message = "SQUAD REPOSITIONED"
			message_timer = 1.2
			selected_unit_index = -1
			queue_redraw()
			return
		selected_unit_index = -1
	for i in range(units.size() - 1, -1, -1):
		if pos.distance_to(units[i]["pos"]) <= UNIT_SELECT_RADIUS:
			selected_unit_index = i
			message = "SQUAD SELECTED — TAP STREET TO MOVE"
			message_timer = 2.0
			queue_redraw()
			return
	if not _is_valid_street_position(pos):
		message = "POSITION BLOCKED — SELECT AN OPEN STREET"
		message_timer = 1.4
		queue_redraw()
		return

	var deployment: Dictionary = DEPLOYMENTS[selected_deployment]
	var cost: int = deployment["cost"]
	if funds < cost:
		message = "INSUFFICIENT FUNDS"
		message_timer = 1.5
		queue_redraw()
		return

	var kind: String = deployment["kind"]
	if kind == "airstrike":
		_execute_airstrike(pos)
		funds -= cost
	elif kind == "barricade":
		barricades.append(pos)
		funds -= cost
		message = "BARRICADE DEPLOYED"
	elif kind == "sniper":
		units.append({"pos": pos, "kind": "sniper", "cooldown": 0.2})
		funds -= cost
		message = "SNIPER TEAM DEPLOYED"
	else:
		units.append({"pos": pos, "kind": "infantry", "cooldown": 0.1})
		funds -= cost
		message = "INFANTRY SQUAD DEPLOYED"
	message_timer = 1.6
	queue_redraw()

func _execute_airstrike(center: Vector2) -> void:
	airstrike_marker = center
	airstrike_timer = 0.8
	shockwaves.append({"pos": center, "radius": 8.0, "life": 0.65, "max_life": 0.65})
	shake_timer = 0.28
	shake_strength = 5.0
	var radius := 112.0
	for i in range(zombies.size() - 1, -1, -1):
		if center.distance_to(zombies[i]["pos"]) <= radius:
			zombies.remove_at(i)
	var casualties := 0
	for i in range(civilians.size() - 1, -1, -1):
		if center.distance_to(civilians[i]) <= radius:
			civilians.remove_at(i)
			casualties += 1
	if casualties > 0:
		lost_count += casualties
		var penalty := casualties * 75
		funds = maxi(0, funds - penalty)
		message = "FRIENDLY FIRE: %d CIVILIANS LOST (-$%d)" % [casualties, penalty]
	else:
		message = "AIRSTRIKE COMPLETE"
	message_timer = 2.5

func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if shake_timer > 0.0:
		shake_offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#07110f"))
	_draw_grid()
	_draw_evac_zone()
	_draw_buildings()
	_draw_entities()
	_draw_hud()
	_draw_deployment_bar()
	if airstrike_timer > 0.0:
		draw_arc(airstrike_marker, 112.0, 0.0, TAU, 48, Color(1.0, 0.42, 0.12, airstrike_timer), 4.0)
	for wave_effect in shockwaves:
		var alpha: float = clampf(float(wave_effect["life"]) / float(wave_effect["max_life"]), 0.0, 1.0)
		draw_arc(wave_effect["pos"], float(wave_effect["radius"]), 0.0, TAU, 48, Color(1.0, 0.48, 0.16, alpha), 3.0)
	if game_state != "playing":
		_draw_end_screen()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_grid() -> void:
	for x in range(0, 721, 60):
		draw_line(Vector2(x, 0), Vector2(x, BAR_TOP), Color(0.12, 0.23, 0.19, 0.32), 1.0)
	for y in range(0, int(BAR_TOP) + 1, 60):
		draw_line(Vector2(0, y), Vector2(720, y), Color(0.12, 0.23, 0.19, 0.32), 1.0)
	draw_rect(Rect2(18, 18, 684, 1040), Color(0.12, 0.24, 0.19, 0.12), false, 2.0)

func _draw_evac_zone() -> void:
	draw_circle(EVAC_ZONE, EVAC_RADIUS, Color(0.05, 0.55, 0.25, 0.18))
	draw_arc(EVAC_ZONE, EVAC_RADIUS, 0.0, TAU, 48, Color("#48e58b"), 3.0)
	draw_arc(EVAC_ZONE, EVAC_RADIUS - 12.0, 0.0, TAU, 48, Color(0.28, 0.85, 0.55, 0.35), 1.0)
	_draw_text("EVAC ZONE", EVAC_ZONE + Vector2(-48, 5), 15, Color("#8cf5b5"))

func _draw_entities() -> void:
	for civilian in civilians:
		draw_circle(civilian, 5.5, Color("#8bdcff"))
		draw_circle(civilian, 2.0, Color("#e3f8ff"))
	for zombie in zombies:
		var p: Vector2 = zombie["pos"]
		if zombie["kind"] == "runner":
			draw_circle(p, 8.0, Color("#ff8a32"))
			draw_circle(p, 3.0, Color("#ffe0a8"))
		else:
			draw_circle(p, 7.0, Color("#f0444f"))
	for wall in barricades:
		draw_rect(Rect2(wall - Vector2(15, 15), Vector2(30, 30)), Color("#9b8b70"), false, 4.0)
		draw_line(wall + Vector2(-11, 0), wall + Vector2(11, 0), Color("#cbb99a"), 3.0)
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var p: Vector2 = unit["pos"]
		var sniper: bool = unit["kind"] == "sniper"
		var tint := Color("#6bdc9a") if not sniper else Color("#8ab6ff")
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), tint)
		draw_arc(p, 390.0 if sniper else 205.0, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.10), 1.0)
		if unit_index == selected_unit_index:
			draw_arc(p, 24.0, 0.0, TAU, 32, Color("#fff28a"), 3.0)
	for tracer in bullet_tracers:
		var alpha: float = clampf(float(tracer["life"]) / float(tracer["max_life"]), 0.0, 1.0)
		draw_line(tracer["from"], tracer["to"], Color(1.0, 0.88, 0.48, alpha), 2.0)
	for flash in muzzle_flashes:
		var alpha: float = clampf(float(flash["life"]) / float(flash["max_life"]), 0.0, 1.0)
		draw_circle(flash["pos"], 8.0 * alpha, Color(1.0, 0.78, 0.35, alpha))

func _draw_hud() -> void:
	draw_rect(Rect2(18, 18, 684, 126), Color("#0b1b17"))
	_draw_text("CONTAINMENT PROTOCOL", Vector2(34, 52), 23, Color("#e2f4e9"))
	_draw_text("FUNDS  $%d" % funds, Vector2(34, 88), 21, Color("#f4d77b"))
	_draw_text("WAVE %d/%d" % [wave, MAX_WAVES], Vector2(245, 88), 18, Color("#ffad62"))
	_draw_text("SAVED %d   LOST %d   HORDE %d" % [saved_count, lost_count, zombies.size()], Vector2(34, 122), 17, Color("#9cbcaf"))
	if message_timer > 0.0:
		_draw_text(message, Vector2(34, 177), 16, Color("#ffbd76"))
	draw_rect(Rect2(530, 154, 172, 52), Color("#183329"))
	draw_rect(Rect2(530, 154, 172, 52), Color("#6ccf91"), false, 2.0)
	_draw_text("TIME  " + TIME_LABELS[time_scale_index], Vector2(545, 187), 17, Color("#e5f8eb"))

func _draw_deployment_bar() -> void:
	draw_rect(Rect2(0, BAR_TOP, 720, 200), Color("#0b1715"))
	draw_line(Vector2(0, BAR_TOP), Vector2(720, BAR_TOP), Color("#45665a"), 2.0)
	for i in range(4):
		var x := float(i) * 180.0
		var selected := i == selected_deployment
		var bg := Color("#254538") if selected else Color("#12251f")
		draw_rect(Rect2(x + 5, BAR_TOP + 10, 170, 178), bg)
		draw_rect(Rect2(x + 5, BAR_TOP + 10, 170, 178), Color("#72d69a") if selected else Color("#29443a"), false, 2.0)
		var deployment: Dictionary = DEPLOYMENTS[i]
		var title_color := Color("#e8fff0") if selected else Color("#b2c7bc")
		_draw_text(str(deployment["name"]), Vector2(x + 15, BAR_TOP + 53), 17, title_color)
		_draw_text(str(deployment["detail"]), Vector2(x + 15, BAR_TOP + 91), 16, Color("#f0cc77"))
		var hint := "TAP MAP" if i != 3 else "TAP TARGET"
		_draw_text(hint, Vector2(x + 15, BAR_TOP + 133), 13, Color("#8da99a"))

func _draw_end_screen() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.01, 0.04, 0.03, 0.88))
	var title := "SECTOR SECURED" if game_state == "victory" else "EVACUATION FAILED"
	var tint := Color("#72f0a2") if game_state == "victory" else Color("#ff6868")
	_draw_text(title, Vector2(95, 510), 38, tint)
	_draw_text("CIVILIANS SAVED: %d" % saved_count, Vector2(190, 575), 22, Color("#e0eee5"))
	_draw_text("CIVILIANS LOST: %d" % lost_count, Vector2(190, 615), 22, Color("#e0a0a0"))
	draw_rect(Rect2(150, 700, 420, 90), Color("#244a38"))
	draw_rect(Rect2(150, 700, 420, 90), Color("#8ce5ad"), false, 3.0)
	_draw_text("PLAY AGAIN", Vector2(278, 755), 27, Color("#f0fff5"))

func _draw_text(value: String, position: Vector2, size: int, color: Color) -> void:
	if screen_font != null:
		draw_string(screen_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
