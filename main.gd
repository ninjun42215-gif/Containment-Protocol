extends Node2D

# Containment Protocol - Godot 4.3
# Portrait 720x1280, drawn natively for low-overhead Android rendering.

const VIEW_SIZE := Vector2(720.0, 1280.0)
const WORLD_SIZE := Vector2(3000.0, 4400.0)
const BAR_TOP := 1080.0
const EVAC_RADIUS := 76.0
const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.4
const CAMERA_DRAG_THRESHOLD := 14.0
const MINIMAP_SIZE := Vector2(154.0, 190.0)
const OUTPOST_COST := 220
const TURRET_COST := 140
const WALL_COST := 75
const OUTPOST_INCOME_INTERVAL := 5.0
const TURRET_RANGE := 220.0
const OUTPOST_COMMAND_RADIUS := 320.0
const OUTPOST_MAX_COUNT := 6
const OUTPOST_COST_STEP := 60
const STRUCTURE_REPAIR_COST := 40
const STRUCTURE_UPGRADE_COST := 150
const DIAGNOSTIC_BUTTON := Rect2(210.0, 214.0, 94.0, 52.0)
const STRUCTURE_ACTION_TOP := 350.0
const MEDEVAC_COST := 250
const MEDEVAC_HP := 150.0
const MEDEVAC_RING := 95.0
const MEDEVAC_CAPACITY := 8
const MEDEVAC_LANDING_TIME := 3.0
const GRID_CELL_SIZE := 64.0
const UNIT_SELECT_RADIUS := 30.0
const BUILDING_RADIUS := 11.0
const FLARE_COST := 40
const FLARE_LIFETIME := 6.0
const FLARE_LURE_RADIUS := 220.0
const AUDIO_SAMPLE_RATE := 22050.0

const UNIT_DEPLOYMENTS := [
	{"name": "INFANTRY", "detail": "SQUAD  $100", "cost": 100, "kind": "infantry"},
	{"name": "SNIPER", "detail": "TEAM  $200", "cost": 200, "kind": "sniper"},
	{"name": "AIRSTRIKE", "detail": "$300", "cost": 300, "kind": "airstrike"},
	{"name": "FLARE", "detail": "BEACON  $40", "cost": FLARE_COST, "kind": "flare"},
	{"name": "MEDEVAC", "detail": "LIFT  $250", "cost": MEDEVAC_COST, "kind": "medevac"}
]
const BASE_DEPLOYMENTS := [
	{"name": "OUTPOST", "detail": "$220", "cost": OUTPOST_COST, "kind": "outpost"},
	{"name": "TURRET", "detail": "$140", "cost": TURRET_COST, "kind": "turret"},
	{"name": "WALL", "detail": "$75", "cost": WALL_COST, "kind": "wall"}
]

var civilians: Array[Vector2] = []
var zombies: Array[Dictionary] = []
var units: Array[Dictionary] = []
var barricades: Array[Dictionary] = []
var flares: Array[Dictionary] = []
var medevac: Dictionary = {}
var sector_index := 0
var sector_name := "Downtown Grid"
var sector_wave_limit := 30
var primary_hq_position := Vector2(-1.0, -1.0)
var shelter_flush_timer := 15.0
var supply_drop_timer := 150.0
var supply_crates: Array[Dictionary] = []
var civilian_steering: Array[Dictionary] = []
var campaign_started := false
var endless_containment := false
var day_phase := "DAY"
var save_path := "user://containment_save.json"
var manual_paused := false
var lifecycle_paused := false
var preview_position := Vector2.ZERO
var preview_active := false
var sfx_enabled := true
var audio_player: AudioStreamPlayer
var audio_queue: Array[String] = []
var audio_effect := ""
var audio_phase := 0.0
var audio_samples_left := 0
var audio_rng := RandomNumberGenerator.new()
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
var evacuation_zones: Array[Vector2] = []
var spawn_districts: Array[Rect2] = []
var outposts: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
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
var camera_position := WORLD_SIZE * 0.5
var camera_zoom := 0.62
var camera_dragging := false
var camera_drag_origin := Vector2.ZERO
var camera_last_position := Vector2.ZERO
var camera_drag_distance := 0.0
var touch_points: Dictionary = {}
var pinch_start_distance := 0.0
var pinch_start_zoom := 1.0
var multi_touch_gesture := false
var previous_pinch_center := Vector2.ZERO
var command_tab := 0
var viewport_size := VIEW_SIZE
var selected_structure_type := ""
var selected_structure_index := -1
var diagnostics_enabled := false
var fps_sample_timer := 0.0
var fps_sample_value := 0
var fps_frame_count := 0

func _ready() -> void:
	randomize()
	screen_font = ThemeDB.fallback_font
	viewport_size = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_configure_sector(0)
	_setup_audio()
	game_state = "title"
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_operation()
		lifecycle_paused = true
		manual_paused = true
		audio_queue.clear()
		audio_effect = ""
		audio_samples_left = 0
		if audio_player != null:
			audio_player.stop()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if audio_player != null and sfx_enabled:
			audio_player.play()
		queue_redraw()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if game_state == "title":
			game_state = "sector_select"
		elif game_state == "sector_select":
			game_state = "title"
		elif game_state == "playing":
			manual_paused = not manual_paused
			lifecycle_paused = false
		else:
			game_state = "sector_select"
		queue_redraw()

func _start_round() -> void:
	_start_sector(sector_index)

func _start_sector(index: int) -> void:
	sector_index = clampi(index, 0, 2)
	_configure_sector(sector_index)
	civilians.clear()
	zombies.clear()
	units.clear()
	barricades.clear()
	flares.clear()
	outposts.clear()
	turrets.clear()
	supply_crates.clear()
	civilian_steering.clear()
	evacuation_zones.clear()
	primary_hq_position = Vector2(-1.0, -1.0)
	campaign_started = false
	endless_containment = false
	shelter_flush_timer = 15.0
	supply_drop_timer = 150.0
	day_phase = "DAY"
	medevac.clear()
	camera_position = WORLD_SIZE * 0.5
	camera_zoom = 0.62
	command_tab = 0
	manual_paused = false
	lifecycle_paused = false
	funds = 300
	saved_count = 0
	lost_count = 0
	wave = 0
	wave_timer = 180.0
	elapsed = 0.0
	game_state = "hq_placement"
	selected_deployment = 0
	selected_unit_index = -1
	selected_structure_type = ""
	selected_structure_index = -1
	diagnostics_enabled = false
	fps_sample_timer = 0.0
	fps_sample_value = 0
	fps_frame_count = 0
	time_scale_index = 0
	bullet_tracers.clear()
	muzzle_flashes.clear()
	shockwaves.clear()
	shake_timer = 0.0
	preview_active = false
	audio_queue.clear()
	audio_effect = ""
	message = "EVACUATE CIVILIANS. HOLD THE LINE."
	message_timer = 4.0
	for district in spawn_districts:
		for i in range(24):
			var spawn_point := Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
			if _is_open_world_position(spawn_point, 18.0):
				civilians.append(spawn_point)
				civilian_steering.append({})
	for district in spawn_districts:
		for outbreak_index in range(6):
			var outbreak_position := Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
			if _is_open_world_position(outbreak_position, 18.0):
				zombies.append({"pos": outbreak_position, "kind": "shambler", "hp": 30.0, "max_hp": 30.0, "wall_cooldown": 0.0})
	message = "SCOUT THE CITY — SELECT PRIMARY HQ LOCATION"
	message_timer = 6.0
	camera_position = WORLD_SIZE * 0.5
	_clamp_camera()

func _process(delta: float) -> void:
	_update_audio()
	if delta > 0.0:
		fps_frame_count += 1
		fps_sample_timer += delta
		if fps_sample_timer >= 0.5:
			fps_sample_value = roundi(float(fps_frame_count) / fps_sample_timer)
			fps_frame_count = 0
			fps_sample_timer = 0.0
	_update_combat_effects(delta)
	if game_state != "playing":
		queue_redraw()
		return
	if manual_paused or lifecycle_paused:
		queue_redraw()
		return
	_update_flares(delta)

	var sim_delta: float = delta * TIME_SCALES[time_scale_index]
	if sim_delta <= 0.0:
		queue_redraw()
		return

	elapsed += sim_delta
	_update_medevac(sim_delta)
	message_timer = maxf(0.0, message_timer - sim_delta)
	airstrike_timer = maxf(0.0, airstrike_timer - sim_delta)
	wave_timer -= sim_delta

	if wave < 30 and wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = 180.0
		_save_operation()
	elif wave >= 30 and endless_containment and wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = 180.0
		_save_operation()
	_shelter_flush_timer_step(sim_delta)
	_update_supply_drops(sim_delta)
	var phase_index: int = int(float(maxi(wave, 1) - 1) / 6.0) % 3
	day_phase = "DAY" if phase_index == 0 else ("DUSK" if phase_index == 1 else "NIGHT")

	# Civilians evacuate through the street network; the grid is rebuilt once
	# after movement so every zombie queries current civilian positions.
	for i in range(civilians.size() - 1, -1, -1):
		var civilian: Vector2 = civilians[i]
		var civilian_safe_target: Vector2 = _nearest_evac_zone(civilian)
		var nearest_outpost_distance := INF
		for outpost in outposts:
			if int(outpost.get("sheltered", 0)) >= int(outpost.get("capacity", 12)):
				continue
			var outpost_distance: float = civilian.distance_squared_to(outpost["pos"])
			if outpost_distance <= float(outpost["safe_radius"]) * float(outpost["safe_radius"]) and outpost_distance < nearest_outpost_distance:
				nearest_outpost_distance = outpost_distance
				civilian_safe_target = outpost["pos"]
		var direction: Vector2 = (civilian_safe_target - civilian).normalized()
		var displacement: Vector2 = direction * 43.0 * sim_delta
		var civilian_steer: Dictionary = civilian_steering[i] if i < civilian_steering.size() else {}
		civilian = _move_circle_with_buildings(civilian, displacement, 5.5, sim_delta, civilian_safe_target, civilian_steer)
		if i < civilian_steering.size():
			civilian_steering[i] = civilian_steer
		civilians[i] = civilian
		var reached_safe_zone := civilian.distance_to(_nearest_evac_zone(civilian)) <= EVAC_RADIUS
		var reached_outpost_index := -1
		for outpost_index in range(outposts.size()):
			var safe_outpost: Dictionary = outposts[outpost_index]
			if civilian.distance_to(safe_outpost["pos"]) <= 28.0 and int(safe_outpost.get("sheltered", 0)) < int(safe_outpost.get("capacity", 12)):
				reached_outpost_index = outpost_index
				reached_safe_zone = true
				break
		if reached_safe_zone:
			civilians.remove_at(i)
			if i < civilian_steering.size():
				civilian_steering.remove_at(i)
			if reached_outpost_index >= 0:
				outposts[reached_outpost_index]["sheltered"] = int(outposts[reached_outpost_index].get("sheltered", 0)) + 1
			else:
				saved_count += 1
				funds += 35
			message = "CIVILIAN SHELTERED / EVACUATED  +$35"
			message_timer = 1.1

	_rebuild_spatial_grid(civilian_grid, civilians)
	for i in range(zombies.size() - 1, -1, -1):
		var zombie: Dictionary = zombies[i]
		zombie["turret_attack_cooldown"] = maxf(0.0, float(zombie.get("turret_attack_cooldown", 0.0)) - sim_delta)
		var zpos: Vector2 = zombie["pos"]
		var target_index: int = _find_nearest_entity(civilian_grid, civilians, zpos, 640.0)
		var target: Vector2 = _nearest_evac_zone(zpos)
		if target_index >= 0:
			target = civilians[target_index]
		var lure_index: int = _find_nearest_flare(zpos)
		if lure_index >= 0:
			target = flares[lure_index]["pos"]
		if not medevac.is_empty() and str(medevac.get("phase", "")) == "landed" and zpos.distance_to(medevac["pos"]) <= 150.0:
			target = medevac["pos"]
		var zombie_kind: String = str(zombie["kind"])
		var speed := 112.0 if zombie_kind == "runner" else 61.0
		if zombie_kind == "brute":
			speed = 34.0
		var displacement: Vector2 = (target - zpos).normalized() * speed * sim_delta
		if not medevac.is_empty() and str(medevac.get("phase", "")) == "landed" and zpos.distance_to(medevac["pos"]) <= 34.0:
			var medevac_cooldown: float = float(zombie.get("medevac_cooldown", 0.0))
			if medevac_cooldown <= 0.0:
				medevac["hp"] = maxf(0.0, float(medevac["hp"]) - (35.0 if zombie_kind == "brute" else 20.0))
				zombie["medevac_cooldown"] = 1.0
				if float(medevac["hp"]) <= 0.0:
					lost_count += int(medevac.get("onboard", 0))
					message = "MEDEVAC DESTROYED — ONBOARD LOST"
					message_timer = 2.5
					medevac.clear()
			else:
				zombie["medevac_cooldown"] = maxf(0.0, medevac_cooldown - sim_delta)
		zpos = _move_circle_with_buildings(zpos, displacement, 10.0 if zombie_kind == "brute" else 7.0, sim_delta, target, zombie)

		for wall_index in range(barricades.size() - 1, -1, -1):
			var wall: Dictionary = barricades[wall_index]
			var wall_pos: Vector2 = wall["pos"]
			if zpos.distance_to(wall_pos) < 30.0:
				if zombie_kind == "brute":
					var attack_cooldown: float = float(zombie.get("wall_cooldown", 0.0))
					if attack_cooldown <= 0.0:
						wall["hp"] = maxf(0.0, float(wall["hp"]) - 50.0)
						zombie["wall_cooldown"] = 1.0
						if float(wall["hp"]) <= 0.0:
							barricades.remove_at(wall_index)
							message = "CONCRETE BARRICADE DESTROYED"
							message_timer = 1.2
						else:
							barricades[wall_index] = wall
					else:
						zombie["wall_cooldown"] = maxf(0.0, attack_cooldown - sim_delta)
				else:
					zpos -= (target - wall_pos).normalized() * 38.0 * sim_delta
				break
		_update_outpost_damage(sim_delta)

	for turret_index in range(turrets.size() - 1, -1, -1):
			var nearby_turret: Dictionary = turrets[turret_index]
			var turret_position: Vector2 = nearby_turret["pos"]
			if zpos.distance_to(turret_position) <= 26.0:
				if float(zombie["turret_attack_cooldown"]) <= 0.0:
					var turret_damage := 28.0 if zombie_kind == "brute" else 14.0
					nearby_turret["hp"] = maxf(0.0, float(nearby_turret["hp"]) - turret_damage)
					zombie["turret_attack_cooldown"] = 1.0
					if float(nearby_turret["hp"]) <= 0.0:
						turrets.remove_at(turret_index)
						message = "SENTRY TURRET DESTROYED"
						message_timer = 1.2
					else:
						turrets[turret_index] = nearby_turret
				break
		zombie["pos"] = zpos
		zombies[i] = zombie

		var civilian_cell := _cell_for(zpos)
		var infected_index := -1
		for cell_y in range(civilian_cell.y - 1, civilian_cell.y + 2):
			for cell_x in range(civilian_cell.x - 1, civilian_cell.x + 2):
				var cell_key := Vector2i(cell_x, cell_y)
				if not civilian_grid.has(cell_key):
					continue
				var nearby_civilians: Array = civilian_grid[cell_key]
				for raw_civilian_index in nearby_civilians:
					var civilian_index: int = int(raw_civilian_index)
					if civilian_index < civilians.size() and zpos.distance_to(civilians[civilian_index]) < 15.0:
						infected_index = civilian_index
						break
				if infected_index >= 0:
					break
			if infected_index >= 0:
				break
		if infected_index >= 0:
			var infected_pos: Vector2 = civilians[infected_index]
			civilians.remove_at(infected_index)
			if infected_index < civilian_steering.size():
				civilian_steering.remove_at(infected_index)
			_rebuild_spatial_grid(civilian_grid, civilians)
			lost_count += 1
			zombies.append({"pos": infected_pos, "kind": "shambler", "hp": 30.0, "max_hp": 30.0})
			message = "CIVILIAN LOST"
			message_timer = 1.4

	_rebuild_zombie_spatial_grid()
	for outpost_index in range(outposts.size()):
		var outpost: Dictionary = outposts[outpost_index]
		outpost["income_timer"] = float(outpost["income_timer"]) - sim_delta
		if float(outpost["income_timer"]) <= 0.0:
			var income_amount := 25 if int(outpost.get("level", 1)) >= 2 else 15
			funds += income_amount
			outpost["income_timer"] = OUTPOST_INCOME_INTERVAL
			message = "OUTPOST SUPPLY +$%d" % income_amount
			message_timer = 0.8
		outposts[outpost_index] = outpost

	for turret_index in range(turrets.size() - 1, -1, -1):
		var turret: Dictionary = turrets[turret_index]
		turret["cooldown"] = maxf(0.0, float(turret["cooldown"]) - sim_delta)
		if float(turret["cooldown"]) <= 0.0:
			var turret_range := float(turret.get("range", TURRET_RANGE))
			var target_zombie := _find_nearest_zombie(turret["pos"], turret_range)
			if target_zombie >= 0:
				var turret_target: Vector2 = zombies[target_zombie]["pos"]
				var turret_damage := float(turret.get("damage", 22.0))
				var base_interval := float(turret.get("fire_interval", 0.18))
				var command_buff := false
				for command_outpost in outposts:
					if turret["pos"].distance_to(command_outpost["pos"]) <= OUTPOST_COMMAND_RADIUS:
						command_buff = true
						break
				var fire_interval := base_interval * (0.8 if command_buff else 1.0)
				if int(turret.get("level", 1)) >= 2:
					var tracer_direction: Vector2 = (turret_target - turret["pos"]).normalized().orthogonal() * 5.0
					_add_bullet_tracer(turret["pos"] + tracer_direction, turret_target + tracer_direction)
					_add_bullet_tracer(turret["pos"] - tracer_direction, turret_target - tracer_direction)
				else:
					_add_bullet_tracer(turret["pos"], turret_target)
				_damage_zombie(target_zombie, turret_damage)
				turret["cooldown"] = fire_interval
				_rebuild_zombie_spatial_grid()
		turrets[turret_index] = turret

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
			_damage_zombie(target_index, 80.0 if is_sniper else 35.0)
			unit["cooldown"] = 1.05 if is_sniper else 0.62
			muzzle_flashes.append({"pos": unit_pos, "life": 0.10, "max_life": 0.10})
			_queue_sfx("gunfire")
			_rebuild_zombie_spatial_grid()
		units[unit_index] = unit

	if wave >= 30 and zombies.is_empty() and civilians.is_empty() and medevac.is_empty() and _total_sheltered_civilians() == 0 and not endless_containment:
		game_state = "victory"
		_save_operation()
		message = "SECTOR SECURED"
	elif civilians.is_empty() and saved_count == 0 and lost_count > 0 and medevac.is_empty() and _total_sheltered_civilians() == 0:
		game_state = "defeat"
		message = "EVACUATION FAILED"

	queue_redraw()


func _setup_city() -> void:
	_configure_sector(sector_index)

func _configure_sector(index: int) -> void:
	match index:
		0:
			sector_name = "Downtown Grid"
			sector_wave_limit = 30
			buildings = _generate_city_blocks(0)
		1:
			sector_name = "Highway Chokepoint"
			sector_wave_limit = 30
			buildings = _generate_city_blocks(1)
		_:
			sector_name = "Central Plaza"
			sector_wave_limit = 30
			buildings = _generate_city_blocks(2)

	spawn_districts = [Rect2(80.0, 80.0, 720.0, 720.0), Rect2(2200.0, 80.0, 720.0, 720.0), Rect2(80.0, 3600.0, 720.0, 720.0), Rect2(2200.0, 3600.0, 720.0, 720.0)]

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / GRID_CELL_SIZE), floori(position.y / GRID_CELL_SIZE))

func _rebuild_spatial_grid(grid: Dictionary, positions: Array[Vector2]) -> void:
	# Reuse occupied buckets between frames to avoid allocating a new Dictionary
	# and new bucket Arrays for every entity-index rebuild.
	for cell_key in grid:
		var existing_bucket: Array = grid[cell_key]
		existing_bucket.clear()
	for index in range(positions.size()):
		var cell: Vector2i = _cell_for(positions[index])
		if not grid.has(cell):
			var new_bucket: Array[int] = []
			grid[cell] = new_bucket
		var entries: Array = grid[cell]
		entries.append(index)

func _rebuild_zombie_spatial_grid() -> void:
	zombie_positions.resize(zombies.size())
	for index in range(zombies.size()):
		zombie_positions[index] = zombies[index]["pos"]
	_rebuild_spatial_grid(zombie_grid, zombie_positions)

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

func _move_circle_with_buildings(origin: Vector2, displacement: Vector2, radius: float, delta: float, target: Vector2 = Vector2.ZERO, steering: Dictionary = {}) -> Vector2:
	var position: Vector2 = origin
	var remaining: Vector2 = displacement
	var lock_time: float = maxf(0.0, float(steering.get("lock_time", 0.0)) - delta)
	steering["lock_time"] = lock_time
	var locked_tangent: Vector2 = steering.get("tangent", Vector2.ZERO)
	if lock_time > 0.0 and locked_tangent.length_squared() > 0.001:
		remaining = locked_tangent.normalized() * displacement.length()
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
					var original_progress := remaining.dot((target - position).normalized()) if target != Vector2.ZERO else 0.0
					remaining -= normal * into_wall
					var tangent_progress := remaining.dot((target - candidate).normalized()) if target != Vector2.ZERO else remaining.length()
					if target != Vector2.ZERO and original_progress > 0.0 and tangent_progress < original_progress * 0.35:
						var corners: Array[Vector2] = [
							building.position - Vector2(radius, radius),
							Vector2(building.end.x + radius, building.position.y - radius),
							building.end + Vector2(radius, radius),
							Vector2(building.position.x - radius, building.end.y + radius)
						]
						var nearest_corner := corners[0]
						var nearest_corner_distance := target.distance_squared_to(nearest_corner)
						for corner in corners:
							var corner_distance := target.distance_squared_to(corner)
							if corner_distance < nearest_corner_distance:
								nearest_corner = corner
								nearest_corner_distance = corner_distance
						var tangent := (nearest_corner - candidate).normalized()
						tangent = tangent - normal * tangent.dot(normal)
						if tangent.length_squared() > 0.001:
							if tangent.dot(target - candidate) < 0.0:
								tangent = -tangent
							remaining = tangent.normalized() * maxf(remaining.length(), displacement.length() * 0.65)
							steering["tangent"] = tangent.normalized()
							steering["lock_time"] = 0.35
		position = candidate
	return position


func _generate_city_blocks(style: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var cell_w: float = 300.0 if style == 1 else 250.0
	var cell_h: float = 340.0 if style == 2 else 300.0
	for row in range(1, 14):
		for col in range(1, 11):
			if (row + col + style) % 5 == 0:
				continue
			var width: float = cell_w * randf_range(0.58, 0.82)
			var height: float = cell_h * randf_range(0.55, 0.80)
			var x: float = float(col) * (cell_w + 25.0) + randf_range(4.0, 18.0)
			var y: float = float(row) * (cell_h + 18.0) + randf_range(3.0, 16.0)
			if x + width < WORLD_SIZE.x - 20.0 and y + height < WORLD_SIZE.y - 20.0:
				result.append(Rect2(x, y, width, height))
	return result

func _is_open_world_position(position: Vector2, margin: float = 28.0) -> bool:
	if position.x < margin or position.x > WORLD_SIZE.x - margin or position.y < margin or position.y > WORLD_SIZE.y - margin:
		return false
	for building in buildings:
		if building.grow(margin).has_point(position):
			return false
	return true

func _is_valid_street_position(position: Vector2) -> bool:
	if position.x < 28.0 or position.x > WORLD_SIZE.x - 28.0 or position.y < 270.0 or position.y > WORLD_SIZE.y - 220.0:
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
		if not bool(effect.get("toxic", false)):
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
	var escalation_phase: int = int(float(wave - 1) / 6.0) + 1
	# Escalate through the 30-wave campaign; endless mode grows more slowly
	# after the campaign ceiling so entity counts remain bounded on mobile.
	var phase_multiplier: float = minf(1.0 + float(escalation_phase - 1) * 0.25, 3.0)
	var count: int = mini(roundi(float(18 + wave * 8) * phase_multiplier), 900)
	var brute_chance: float = clampf(0.08 + float(wave) * 0.008, 0.08, 0.32)
	var spitter_chance: float = clampf(0.10 + float(wave) * 0.006, 0.10, 0.28)
	var runner_chance: float = clampf(0.16 + float(wave) * 0.006, 0.16, 0.34)
	for i in range(count):
		var district: Rect2 = spawn_districts[randi_range(0, spawn_districts.size() - 1)]
		var spawn_point := Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
		var x: float = spawn_point.x
		var y: float = spawn_point.y
		var roll := randf()
		var kind := "shambler"
		if wave >= 2 and roll < brute_chance:
			kind = "brute"
		elif wave >= 2 and roll < brute_chance + spitter_chance:
			kind = "spitter"
		elif roll < brute_chance + spitter_chance + runner_chance:
			kind = "runner"
		var hp := 30.0
		if kind == "runner":
			hp = 25.0
		elif kind == "brute":
			hp = 180.0 + float(wave) * 15.0
		elif kind == "spitter":
			hp = 42.0 + float(wave) * 4.0
		zombies.append({"pos": Vector2(x, y), "kind": kind, "hp": hp, "max_hp": hp, "wall_cooldown": 0.0})
	if wave % 5 == 0:
		_spawn_refugee_wave()
	message = "PHASE %d — HORDE WAVE %d INBOUND" % [ceili(float(wave) / 6.0), wave]
	message_timer = 3.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touch_points[touch.index] = touch.position
			if touch_points.size() == 1:
				camera_drag_origin = touch.position
				camera_last_position = touch.position
				camera_drag_distance = 0.0
				camera_dragging = false
			elif touch_points.size() == 2:
				multi_touch_gesture = true
				var points: Array = touch_points.values()
				var first_point: Vector2 = points[0]
				var second_point: Vector2 = points[1]
				pinch_start_distance = first_point.distance_to(second_point)
				previous_pinch_center = (first_point + second_point) * 0.5
		else:
			if touch_points.has(touch.index):
				if touch_points.size() == 1 and not multi_touch_gesture and not camera_dragging and camera_drag_distance < CAMERA_DRAG_THRESHOLD:
					_handle_tap(touch.position)
				touch_points.erase(touch.index)
			if touch_points.is_empty():
				multi_touch_gesture = false
			if touch_points.size() < 2:
				pinch_start_distance = 0.0
			if touch_points.size() == 1:
				camera_last_position = touch_points.values()[0]
				camera_drag_distance = 0.0
				camera_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_points.has(drag.index):
			touch_points[drag.index] = drag.position
		if touch_points.size() >= 2:
			var points: Array = touch_points.values()
			var first_point: Vector2 = points[0]
			var second_point: Vector2 = points[1]
			var center := (first_point + second_point) * 0.5
			var distance := first_point.distance_to(second_point)
			camera_position -= (center - previous_pinch_center) / camera_zoom
			_clamp_camera()
			if pinch_start_distance > 0.0 and distance > 1.0:
				_zoom_camera(distance / pinch_start_distance, center)
			pinch_start_distance = distance
			previous_pinch_center = center
		else:
			camera_drag_distance += drag.relative.length()
			if camera_drag_distance > CAMERA_DRAG_THRESHOLD:
				camera_dragging = true
			if camera_dragging:
				camera_position -= drag.relative / camera_zoom
				_clamp_camera()
				queue_redraw()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				camera_drag_origin = mouse.position
				camera_drag_distance = 0.0
				camera_dragging = false
			elif not camera_dragging and camera_drag_distance < CAMERA_DRAG_THRESHOLD:
				_handle_tap(mouse.position)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.12, mouse.position)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(0.89, mouse.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var motion := event as InputEventMouseMotion
		camera_drag_distance += motion.relative.length()
		if camera_drag_distance > CAMERA_DRAG_THRESHOLD:
			camera_dragging = true
		if camera_dragging:
			camera_position -= motion.relative / camera_zoom
			_clamp_camera()
			queue_redraw()

func _handle_tap(pos: Vector2) -> void:
	if game_state == "title":
		if pos.y >= viewport_size.y * 0.63 and _has_valid_save():
			_resume_operation()
		else:
			game_state = "sector_select"
		queue_redraw()
		return
	if game_state == "hq_placement":
		if pos.y >= viewport_size.y - 70.0 and pos.x >= 24.0 and pos.x <= viewport_size.x - 24.0 and primary_hq_position.x >= 0.0:
			campaign_started = true
			game_state = "playing"
			wave_timer = 1.0
			_save_operation()
			message = "PRIMARY HQ ESTABLISHED — OPERATION STARTED"
			message_timer = 3.0
			queue_redraw()
			return
		if pos.y >= viewport_size.y - 150.0:
			return
		var hq_world: Vector2 = _screen_to_world(pos)
		if _is_open_world_position(hq_world, 32.0):
			primary_hq_position = hq_world
			evacuation_zones.clear()
			evacuation_zones.append(hq_world)
			message = "PRIMARY COMMAND HQ LOCATION LOCKED"
			message_timer = 2.0
		else:
			message = "HQ MUST BE ON AN OPEN STREET"
			message_timer = 1.5
		queue_redraw()
		return
	if game_state == "sector_select":
		if pos.y >= viewport_size.y * 0.44 and pos.y < viewport_size.y * 0.80:
			var selected_sector := clampi(int((pos.y - viewport_size.y * 0.44) / (viewport_size.y * 0.12)), 0, 2)
			_start_sector(selected_sector)
		queue_redraw()
		return
	if game_state == "victory" or game_state == "defeat":
		if game_state == "victory" and wave >= 30 and pos.y >= viewport_size.y * 0.66 and pos.y <= viewport_size.y * 0.82:
			endless_containment = true
			game_state = "playing"
			wave_timer = 1.0
			message = "ENDLESS CONTAINMENT ACTIVATED"
			message_timer = 3.0
		else:
			game_state = "sector_select"
		queue_redraw()
		return
	if game_state != "playing":
		return
	if manual_paused or lifecycle_paused:
		if pos.x >= viewport_size.x * 0.2 and pos.x <= viewport_size.x * 0.8 and pos.y >= viewport_size.y * 0.52 and pos.y <= viewport_size.y * 0.68:
			manual_paused = false
			lifecycle_paused = false
		queue_redraw()
		return
	var minimap_rect := Rect2(Vector2(viewport_size.x - MINIMAP_SIZE.x - 18.0, 18.0), MINIMAP_SIZE)
	if minimap_rect.has_point(pos):
		var local := (pos - minimap_rect.position) / minimap_rect.size
		camera_position = Vector2(local.x * WORLD_SIZE.x, local.y * WORLD_SIZE.y)
		_clamp_camera()
		queue_redraw()
		return
	if pos.x >= viewport_size.x - 112.0 and pos.y >= 220.0 and pos.y <= 276.0:
		_zoom_camera(1.18, viewport_size * 0.5)
		return
	if pos.x >= viewport_size.x - 112.0 and pos.y >= 282.0 and pos.y <= 338.0:
		_zoom_camera(0.85, viewport_size * 0.5)
		return
	if pos.x <= 190.0 and pos.y >= 214.0 and pos.y <= 266.0:
		time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()
		queue_redraw()
		return
	if pos.x <= 190.0 and pos.y >= 274.0 and pos.y <= 326.0:
		sfx_enabled = not sfx_enabled
		if not sfx_enabled:
			audio_queue.clear()
			audio_effect = ""
		queue_redraw()
		return
	if DIAGNOSTIC_BUTTON.has_point(pos):
		diagnostics_enabled = not diagnostics_enabled
		queue_redraw()
		return
	if not selected_structure_type.is_empty() and pos.y >= STRUCTURE_ACTION_TOP + 34.0 and pos.y <= STRUCTURE_ACTION_TOP + 84.0:
		if pos.x >= 24.0 and pos.x <= 190.0:
			_repair_selected_structure()
			return
		if pos.x >= 204.0 and pos.x <= 370.0:
			_upgrade_selected_structure()
			return
	var bar_top := viewport_size.y - 200.0
	if pos.y >= bar_top:
		if pos.y <= bar_top + 48.0:
			command_tab = 1 - command_tab
			selected_deployment = 0
			queue_redraw()
			return
		var choices: Array = UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS
		var button_width := viewport_size.x / float(choices.size())
		selected_deployment = clampi(int(pos.x / button_width), 0, choices.size() - 1)
		message = str(choices[selected_deployment]["name"]) + " SELECTED"
		message_timer = 1.2
		queue_redraw()
		return
	if pos.y < 270.0:
		return
	var world_pos := _screen_to_world(pos)
	if _select_structure_at(world_pos):
		message = "%s SELECTED" % selected_structure_type.to_upper()
		message_timer = 1.2
		queue_redraw()
		return
	selected_structure_type = ""
	selected_structure_index = -1
	for squad_index in range(units.size() - 1, -1, -1):
		if world_pos.distance_to(units[squad_index]["pos"]) <= UNIT_SELECT_RADIUS:
			selected_unit_index = squad_index
			message = "SQUAD SELECTED — TAP STREET TO MOVE"
			message_timer = 2.0
			queue_redraw()
			return
	if selected_unit_index >= 0 and selected_unit_index < units.size():
		if _is_valid_street_position(world_pos):
			units[selected_unit_index]["pos"] = world_pos
			message = "SQUAD REPOSITIONED"
			message_timer = 1.2
			selected_unit_index = -1
			queue_redraw()
			return
		selected_unit_index = -1
	var choices: Array = UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS
	if selected_deployment >= choices.size():
		selected_deployment = 0
	var deployment: Dictionary = choices[selected_deployment]
	var cost: int = int(deployment["cost"])
	var kind: String = str(deployment["kind"])
	if funds < cost:
		message = "INSUFFICIENT FUNDS"
		message_timer = 1.5
		queue_redraw()
		return
	if not _is_valid_street_position(world_pos):
		message = "POSITION BLOCKED — SELECT OPEN STREET"
		message_timer = 1.4
		queue_redraw()
		return
	match kind:
		"airstrike":
			_execute_airstrike(world_pos)
		"flare":
			flares.append({"pos": world_pos, "life": FLARE_LIFETIME, "phase": 0.0})
			_queue_sfx("flare")
		"medevac":
			if not medevac.is_empty():
				message = "MEDEVAC ALREADY ACTIVE"
				message_timer = 1.5
				return
			medevac = {"pos": Vector2(-90.0, world_pos.y), "target": world_pos, "phase": "inbound", "hp": MEDEVAC_HP, "landing_timer": MEDEVAC_LANDING_TIME, "onboard": 0, "attack_flash": 0.0}
		"infantry", "sniper":
			units.append({"pos": world_pos, "kind": kind, "cooldown": 0.1})
		"outpost":
			if outposts.size() >= OUTPOST_MAX_COUNT:
				message = "FORWARD OUTPOST LIMIT REACHED (6)"
				message_timer = 1.5
				return
			var outpost_cost := OUTPOST_COST + outposts.size() * OUTPOST_COST_STEP
			if funds < outpost_cost:
				message = "OUTPOST COST $%d — INSUFFICIENT FUNDS" % outpost_cost
				message_timer = 1.5
				return
			outposts.append({"pos": world_pos, "income_timer": OUTPOST_INCOME_INTERVAL, "safe_radius": 175.0, "vision_radius": 260.0, "command_radius": OUTPOST_COMMAND_RADIUS, "hp": 500.0, "max_hp": 500.0, "level": 1, "capacity": 12, "sheltered": 0})
			cost = outpost_cost
		"turret":
			turrets.append({"pos": world_pos, "hp": 250.0, "max_hp": 250.0, "cooldown": 0.1, "level": 1, "range": TURRET_RANGE, "vision_radius": TURRET_RANGE, "damage": 22.0, "fire_interval": 0.18})
		"wall":
			barricades.append({"pos": world_pos, "hp": 400.0, "max_hp": 400.0})
	funds -= cost
	message = str(deployment["name"]) + " DEPLOYED"
	message_timer = 1.6
	queue_redraw()

func _update_medevac(delta: float) -> void:
	if medevac.is_empty():
		return
	var phase: String = str(medevac["phase"])
	var position: Vector2 = medevac["pos"]
	if phase == "inbound":
		var target: Vector2 = medevac["target"]
		position.x = move_toward(position.x, target.x, 260.0 * delta)
		if absf(position.x - target.x) <= 1.0:
			position = target
			medevac["phase"] = "landed"
			medevac["landing_timer"] = MEDEVAC_LANDING_TIME
			var extracted := 0
			for civilian_index in range(civilians.size() - 1, -1, -1):
				if extracted >= MEDEVAC_CAPACITY:
					break
				if position.distance_to(civilians[civilian_index]) <= MEDEVAC_RING:
					civilians.remove_at(civilian_index)
					if civilian_index < civilian_steering.size():
						civilian_steering.remove_at(civilian_index)
					extracted += 1
			medevac["onboard"] = extracted
			_flush_nearby_shelters(position)
			if extracted > 0:
				message = "MEDEVAC ABOARD — %d CIVILIANS" % extracted
				message_timer = 2.0
	elif phase == "landed":
		medevac["landing_timer"] = float(medevac["landing_timer"]) - delta
		medevac["attack_flash"] = maxf(0.0, float(medevac.get("attack_flash", 0.0)) - delta)
		if float(medevac["landing_timer"]) <= 0.0:
			var rescued: int = int(medevac.get("onboard", 0))
			saved_count += rescued
			funds += rescued * 40
			message = "MEDEVAC LIFTED — +$%d" % (rescued * 40)
			message_timer = 2.0
			medevac["phase"] = "outbound"
	elif phase == "outbound":
		position.x += 260.0 * delta
		if position.x > WORLD_SIZE.x + 100.0:
			medevac.clear()
			return
	medevac["pos"] = position

func _execute_airstrike(center: Vector2) -> void:
	airstrike_marker = center
	airstrike_timer = 0.8
	_queue_sfx("airstrike")
	shockwaves.append({"pos": center, "radius": 8.0, "life": 0.65, "max_life": 0.65})
	shake_timer = 0.28
	shake_strength = 5.0
	var radius := 112.0
	for i in range(zombies.size() - 1, -1, -1):
		if center.distance_to(zombies[i]["pos"]) <= radius:
			_damage_zombie(i, 10000.0)
	var casualties := 0
	for i in range(civilians.size() - 1, -1, -1):
		if center.distance_to(civilians[i]) <= radius:
			civilians.remove_at(i)
			if i < civilian_steering.size():
				civilian_steering.remove_at(i)
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
	viewport_size = get_viewport_rect().size
	if game_state == "title" or game_state == "sector_select":
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#07110f"))
		for x in range(0, int(viewport_size.x) + 1, 60):
			draw_line(Vector2(x, 0.0), Vector2(x, viewport_size.y), Color(0.12, 0.23, 0.19, 0.32), 1.0)
		for y in range(0, int(viewport_size.y) + 1, 60):
			draw_line(Vector2(0.0, y), Vector2(viewport_size.x, y), Color(0.12, 0.23, 0.19, 0.32), 1.0)
		_draw_title_screen()
		return
	if game_state == "hq_placement":
		var hq_hint := "TAP OPEN STREET TO PLACE PRIMARY HQ" if primary_hq_position.x < 0.0 else "HQ LOCKED — TAP START OPERATION"
		_draw_world_scene()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(0.0, viewport_size.y - 150.0, viewport_size.x, 150.0), Color("#071713", 0.96))
		_draw_text("SELECT HQ LOCATION", Vector2(24.0, viewport_size.y - 112.0), 22, Color("#e8fff0"))
		_draw_text(hq_hint, Vector2(24.0, viewport_size.y - 78.0), 15, Color("#a9c8b7"))
		if primary_hq_position.x >= 0.0:
			draw_rect(Rect2(24.0, viewport_size.y - 62.0, viewport_size.x - 48.0, 48.0), Color("#244a38"))
			_draw_text("[ START OPERATION ]", Vector2(170.0, viewport_size.y - 30.0), 19, Color("#f0fff5"))
		return
	var shake_offset := Vector2.ZERO
	if shake_timer > 0.0:
		shake_offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	var world_transform_origin := viewport_size * 0.5 - camera_position * camera_zoom + shake_offset
	draw_set_transform(world_transform_origin, 0.0, Vector2(camera_zoom, camera_zoom))
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#07110f"))
	_draw_grid()
	_draw_evac_zone()
	_draw_buildings()
	_draw_fog()
	_draw_entities()
	_draw_medevac()
	_draw_placement_preview()
	var visible_effect_rect := _camera_view_rect().grow(220.0)
	for flare in flares:
		var flare_pos: Vector2 = flare["pos"]
		if not visible_effect_rect.has_point(flare_pos):
			continue
		var pulse: float = 1.0 + 0.18 * sin(float(flare["phase"]) * 8.0)
		draw_circle(flare_pos, 11.0 * pulse, Color(1.0, 0.78, 0.12, 0.18))
		draw_circle(flare_pos, 5.0 * pulse, Color("#ffe45c"))
		draw_arc(flare_pos, 18.0 * pulse, 0.0, TAU, 32, Color(1.0, 0.82, 0.22, 0.8), 2.0)
	for wave_effect in shockwaves:
		if not visible_effect_rect.has_point(wave_effect["pos"]):
			continue
		var alpha: float = clampf(float(wave_effect["life"]) / float(wave_effect["max_life"]), 0.0, 1.0)
		var ring_color := Color(0.35, 1.0, 0.28, alpha) if bool(wave_effect.get("toxic", false)) else Color(1.0, 0.48, 0.16, alpha)
		draw_arc(wave_effect["pos"], float(wave_effect["radius"]), 0.0, TAU, 48, ring_color, 3.0)
	if airstrike_timer > 0.0 and visible_effect_rect.has_point(airstrike_marker):
		draw_arc(airstrike_marker, 112.0, 0.0, TAU, 48, Color(1.0, 0.42, 0.12, airstrike_timer), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if day_phase == "DUSK":
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.30, 0.14, 0.05, 0.08))
	elif day_phase == "NIGHT":
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.03, 0.06, 0.20, 0.18))
	_draw_hud()
	_draw_structure_actions()
	_draw_minimap()
	_draw_deployment_bar()
	if manual_paused or lifecycle_paused:
		_draw_pause_overlay()
	if game_state != "playing":
		_draw_end_screen()

func _draw_grid() -> void:
	var visible_rect := _camera_view_rect().grow(100.0)
	var start_x := maxi(0, floori(visible_rect.position.x / 80.0) * 80)
	var end_x := mini(int(WORLD_SIZE.x), ceili(visible_rect.end.x / 80.0) * 80)
	var start_y := maxi(0, floori(visible_rect.position.y / 80.0) * 80)
	var end_y := mini(int(WORLD_SIZE.y), ceili(visible_rect.end.y / 80.0) * 80)
	for x in range(start_x, end_x + 1, 80):
		draw_line(Vector2(x, start_y), Vector2(x, end_y), Color(0.12, 0.23, 0.19, 0.32), 1.0)
	for y in range(start_y, end_y + 1, 80):
		draw_line(Vector2(start_x, y), Vector2(end_x, y), Color(0.12, 0.23, 0.19, 0.32), 1.0)

func _draw_dashed_circle(center: Vector2, radius: float, tint: Color, segments: int) -> void:
	for segment in range(0, segments, 2):
		var start_angle := TAU * float(segment) / float(segments)
		var end_angle := TAU * float(segment + 1) / float(segments)
		var start_point := center + Vector2(cos(start_angle), sin(start_angle)) * radius
		var end_point := center + Vector2(cos(end_angle), sin(end_angle)) * radius
		draw_line(start_point, end_point, tint, 2.0)

func _draw_evac_zone() -> void:
	for zone in evacuation_zones:
		draw_circle(zone, EVAC_RADIUS, Color(0.05, 0.55, 0.25, 0.18))
		draw_arc(zone, EVAC_RADIUS, 0.0, TAU, 48, Color("#48e58b"), 3.0)
		draw_arc(zone, EVAC_RADIUS - 12.0, 0.0, TAU, 48, Color(0.28, 0.85, 0.55, 0.35), 1.0)
		var zone_label: String = "PRIMARY HQ" if zone.distance_squared_to(primary_hq_position) < 1.0 else "FORWARD SAFE ZONE"
		_draw_text(zone_label, zone + Vector2(-45.0, 5.0), 13, Color("#8cf5b5"))
	for outpost in outposts:
		draw_circle(outpost["pos"], float(outpost["safe_radius"]), Color(0.10, 0.65, 0.32, 0.035))
		draw_arc(outpost["pos"], float(outpost["vision_radius"]), 0.0, TAU, 48, Color(0.25, 0.85, 0.48, 0.16), 1.0)
		_draw_dashed_circle(outpost["pos"], OUTPOST_COMMAND_RADIUS, Color(0.35, 0.88, 0.55, 0.34), 48)

func _draw_title_screen() -> void:
	draw_rect(Rect2(viewport_size.x * 0.06, viewport_size.y * 0.16, viewport_size.x * 0.88, viewport_size.y * 0.68), Color(0.02, 0.07, 0.055, 0.96))
	draw_rect(Rect2(viewport_size.x * 0.06, viewport_size.y * 0.16, viewport_size.x * 0.88, viewport_size.y * 0.68), Color("#4d7964"), false, 2.0)
	_draw_text("CONTAINMENT", Vector2(viewport_size.x * 0.14, viewport_size.y * 0.26), 42, Color("#e4f6e9"))
	_draw_text("PROTOCOL", Vector2(viewport_size.x * 0.29, viewport_size.y * 0.30), 42, Color("#79e7a4"))
	_draw_text("TACTICAL EVACUATION COMMAND", Vector2(viewport_size.x * 0.17, viewport_size.y * 0.35), 18, Color("#a9c8b7"))
	if game_state == "title":
		draw_rect(Rect2(viewport_size.x * 0.19, viewport_size.y * 0.51, viewport_size.x * 0.62, 100.0), Color("#1d4935"))
		draw_rect(Rect2(viewport_size.x * 0.19, viewport_size.y * 0.51, viewport_size.x * 0.62, 100.0), Color("#75e6a0"), false, 3.0)
		_draw_text("TAP TO SELECT SECTOR", Vector2(viewport_size.x * 0.27, viewport_size.y * 0.56), 22, Color("#f0fff5"))
		if _has_valid_save():
			draw_rect(Rect2(viewport_size.x * 0.14, viewport_size.y * 0.66, viewport_size.x * 0.72, 78.0), Color("#294c3c"))
			draw_rect(Rect2(viewport_size.x * 0.14, viewport_size.y * 0.66, viewport_size.x * 0.72, 78.0), Color("#e4c66d"), false, 2.0)
			_draw_text("RESUME SAVED OPERATION", Vector2(viewport_size.x * 0.19, viewport_size.y * 0.71), 18, Color("#fff4c7"))
	else:
		_draw_text("SELECT OPERATIONAL SECTOR", Vector2(viewport_size.x * 0.19, viewport_size.y * 0.42), 22, Color("#d8eee0"))
		var names: Array[String] = ["01  DOWNTOWN GRID", "02  HIGHWAY CHOKEPOINT", "03  CENTRAL PLAZA"]
		var details: Array[String] = ["DENSE URBAN GRID  •  30 WAVES", "HIGHWAY CORRIDORS  •  30 WAVES", "OPEN PLAZA DISTRICTS  •  30 WAVES"]
		for index in range(3):
			var y := viewport_size.y * 0.44 + float(index) * viewport_size.y * 0.12
			draw_rect(Rect2(viewport_size.x * 0.10, y, viewport_size.x * 0.80, 96.0), Color("#18352a"))
			draw_rect(Rect2(viewport_size.x * 0.10, y, viewport_size.x * 0.80, 96.0), Color("#69b98a"), false, 2.0)
			_draw_text(names[index], Vector2(viewport_size.x * 0.14, y + 38.0), 20, Color("#e8fff0"))
			_draw_text(details[index], Vector2(viewport_size.x * 0.14, y + 70.0), 13, Color("#a9c8b7"))
	_draw_text("ANDROID TACTICAL RESPONSE UNIT", Vector2(viewport_size.x * 0.21, viewport_size.y * 0.86), 15, Color("#648675"))

func _draw_pause_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.04, 0.03, 0.78))
	_draw_text("SIMULATION PAUSED", viewport_size * 0.5 + Vector2(-145.0, -50.0), 30, Color("#e8fff0"))
	draw_rect(Rect2(viewport_size * 0.5 - Vector2(210.0, -10.0), Vector2(420.0, 100.0)), Color("#244a38"))
	draw_rect(Rect2(viewport_size * 0.5 - Vector2(210.0, -10.0), Vector2(420.0, 100.0)), Color("#8ce5ad"), false, 3.0)
	_draw_text("RESUME  /  BACK", viewport_size * 0.5 + Vector2(-115.0, 70.0), 24, Color("#f0fff5"))

func _draw_medevac() -> void:
	if medevac.is_empty():
		return
	var position: Vector2 = medevac["pos"]
	var phase: String = str(medevac["phase"])
	if phase == "landed":
		draw_circle(position, MEDEVAC_RING, Color(0.12, 0.95, 0.42, 0.10))
		draw_arc(position, MEDEVAC_RING, 0.0, TAU, 64, Color("#63f59a"), 3.0)
		draw_arc(position, MEDEVAC_RING - 8.0, 0.0, TAU, 64, Color(0.45, 1.0, 0.65, 0.35), 1.0)
	draw_line(position + Vector2(-34.0, -18.0), position + Vector2(34.0, -18.0), Color("#d7e8e1"), 3.0)
	draw_line(position + Vector2(0.0, -18.0), position + Vector2(0.0, 18.0), Color("#d7e8e1"), 2.0)
	draw_rect(Rect2(position + Vector2(-24.0, -9.0), Vector2(48.0, 18.0)), Color("#5ccf91"))
	draw_circle(position + Vector2(24.0, 0.0), 8.0, Color("#b9e8d1"))
	if phase == "landed":
		var hp_ratio: float = clampf(float(medevac["hp"]) / MEDEVAC_HP, 0.0, 1.0)
		draw_rect(Rect2(position + Vector2(-28.0, 25.0), Vector2(56.0, 5.0)), Color("#552b2b"))
		draw_rect(Rect2(position + Vector2(-28.0, 25.0), Vector2(56.0 * hp_ratio, 5.0)), Color("#65ee96"))
		_draw_text("ONBOARD %d/8" % int(medevac.get("onboard", 0)), position + Vector2(-40.0, 48.0), 11, Color("#aaffc5"))

func _is_position_visible(world_position: Vector2) -> bool:
	for zone in evacuation_zones:
		if world_position.distance_squared_to(zone) <= 250.0 * 250.0:
			return true
	for unit in units:
		var unit_radius: float = (390.0 if str(unit["kind"]) == "sniper" else 205.0) * _night_vision_multiplier()
		if world_position.distance_squared_to(unit["pos"]) <= unit_radius * unit_radius:
			return true
	for outpost in outposts:
		var outpost_radius: float = float(outpost.get("vision_radius", 260.0)) * _night_vision_multiplier()
		if world_position.distance_squared_to(outpost["pos"]) <= outpost_radius * outpost_radius:
			return true
	for turret in turrets:
		var turret_radius: float = float(turret.get("vision_radius", TURRET_RANGE)) * _night_vision_multiplier()
		if world_position.distance_squared_to(turret["pos"]) <= turret_radius * turret_radius:
			return true
	for flare in flares:
		if world_position.distance_squared_to(flare["pos"]) <= 260.0 * 260.0:
			return true
	return false

func _draw_fog() -> void:
	var visible_rect := _camera_view_rect()
	var tile_size := 80.0
	var start_x := maxi(0, floori(visible_rect.position.x / tile_size) * int(tile_size))
	var end_x := mini(int(WORLD_SIZE.x), ceili(visible_rect.end.x / tile_size) * int(tile_size))
	var start_y := maxi(0, floori(visible_rect.position.y / tile_size) * int(tile_size))
	var end_y := mini(int(WORLD_SIZE.y), ceili(visible_rect.end.y / tile_size) * int(tile_size))
	for tile_y in range(start_y, end_y, int(tile_size)):
		for tile_x in range(start_x, end_x, int(tile_size)):
			var tile_center := Vector2(float(tile_x) + tile_size * 0.5, float(tile_y) + tile_size * 0.5)
			if not _is_position_visible(tile_center):
				draw_rect(Rect2(Vector2(tile_x, tile_y), Vector2(tile_size, tile_size)), Color(0.008, 0.022, 0.019, 0.82))

func _draw_entities() -> void:
	var visible_rect := _camera_view_rect().grow(80.0)
	for civilian in civilians:
		if not visible_rect.has_point(civilian):
			continue
		draw_circle(civilian, 5.5, Color("#8bdcff"))
		draw_circle(civilian, 2.0, Color("#e3f8ff"))
	for zombie in zombies:
		var p: Vector2 = zombie["pos"]
		if not visible_rect.has_point(p) or (game_state != "hq_placement" and not _is_position_visible(p)):
			continue
		var kind: String = str(zombie["kind"])
		if kind == "runner":
			draw_circle(p, 8.0, Color("#ff8a32"))
			draw_circle(p, 3.0, Color("#ffe0a8"))
		elif kind == "brute":
			draw_circle(p, 13.0, Color("#9b59d0"))
			draw_circle(p, 5.0, Color("#e5b7ff"))
		elif kind == "spitter":
			draw_circle(p, 7.5, Color("#50ff54"))
			draw_circle(p, 2.5, Color("#d4ffd0"))
		else:
			draw_circle(p, 7.0, Color("#f0444f"))
	for wall in barricades:
		var wall_pos: Vector2 = wall["pos"]
		if not visible_rect.has_point(wall_pos):
			continue
		var wall_hp: float = float(wall["hp"]) / float(wall["max_hp"])
		draw_rect(Rect2(wall_pos - Vector2(15, 15), Vector2(30, 30)), Color("#9b8b70"), false, 4.0)
		draw_line(wall_pos + Vector2(-11, 0), wall_pos + Vector2(11, 0), Color("#cbb99a", 0.35 + 0.65 * wall_hp), 3.0)
	for crate in supply_crates:
		if visible_rect.has_point(crate["pos"]):
			draw_circle(crate["pos"], 18.0, Color(0.9, 0.72, 0.24, 0.2))
			draw_rect(Rect2(crate["pos"] - Vector2(11.0, 11.0), Vector2(22.0, 22.0)), Color("#d8b65b"))
			draw_line(crate["pos"] + Vector2(-7.0, 0.0), crate["pos"] + Vector2(7.0, 0.0), Color("#fff0b0"), 2.0)
	for outpost in outposts:
		if visible_rect.has_point(outpost["pos"]):
			draw_rect(Rect2(outpost["pos"] - Vector2(15.0, 15.0), Vector2(30.0, 30.0)), Color("#43d77a"))
	for turret in turrets:
		if visible_rect.has_point(turret["pos"]):
			draw_rect(Rect2(turret["pos"] - Vector2(11.0, 11.0), Vector2(22.0, 22.0)), Color("#e2bb63"))
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var p: Vector2 = unit["pos"]
		if not visible_rect.has_point(p):
			continue
		var sniper: bool = unit["kind"] == "sniper"
		var tint := Color("#6bdc9a") if not sniper else Color("#8ab6ff")
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), tint)
		draw_arc(p, (390.0 if sniper else 205.0) * _night_vision_multiplier(), 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.10), 1.0)
		if unit_index == selected_unit_index:
			draw_arc(p, 24.0, 0.0, TAU, 32, Color("#fff28a"), 3.0)
	for tracer in bullet_tracers:
		if not visible_rect.has_point(tracer["from"]) and not visible_rect.has_point(tracer["to"]):
			continue
		var alpha: float = clampf(float(tracer["life"]) / float(tracer["max_life"]), 0.0, 1.0)
		draw_line(tracer["from"], tracer["to"], Color(1.0, 0.88, 0.48, alpha), 2.0)
	for flash in muzzle_flashes:
		if not visible_rect.has_point(flash["pos"]):
			continue
		var alpha: float = clampf(float(flash["life"]) / float(flash["max_life"]), 0.0, 1.0)
		draw_circle(flash["pos"], 8.0 * alpha, Color(1.0, 0.78, 0.35, alpha))

func _draw_minimap() -> void:
	var minimap_rect := Rect2(Vector2(viewport_size.x - MINIMAP_SIZE.x - 18.0, 18.0), MINIMAP_SIZE)
	draw_rect(minimap_rect, Color("#081713", 0.96))
	for building in buildings:
		var building_rect := Rect2(minimap_rect.position + building.position / WORLD_SIZE * minimap_rect.size, building.size / WORLD_SIZE * minimap_rect.size)
		draw_rect(building_rect, Color("#52685d"))
	for zone in evacuation_zones:
		draw_circle(minimap_rect.position + zone / WORLD_SIZE * minimap_rect.size, 2.2, Color("#54e98e"))
	for civilian in civilians:
		draw_circle(minimap_rect.position + civilian / WORLD_SIZE * minimap_rect.size, 1.5, Color("#65cfff"))
	for zombie in zombies:
		var zombie_pos: Vector2 = zombie["pos"]
		if _is_position_visible(zombie_pos):
			draw_circle(minimap_rect.position + zombie_pos / WORLD_SIZE * minimap_rect.size, 1.9, Color("#f34d58", 0.78))
	for outpost in outposts:
		draw_rect(Rect2(minimap_rect.position + outpost["pos"] / WORLD_SIZE * minimap_rect.size - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("#55f08b"))
	for crate in supply_crates:
		draw_circle(minimap_rect.position + crate["pos"] / WORLD_SIZE * minimap_rect.size, 2.0, Color("#e8ca69"))
	for turret in turrets:
		draw_rect(Rect2(minimap_rect.position + turret["pos"] / WORLD_SIZE * minimap_rect.size - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color("#f1d071"))
	var camera_rect := _camera_view_rect()
	var mini_camera := Rect2(minimap_rect.position + camera_rect.position / WORLD_SIZE * minimap_rect.size, camera_rect.size / WORLD_SIZE * minimap_rect.size)
	draw_rect(mini_camera, Color("#f4e28a", 0.12))
	draw_rect(mini_camera, Color("#f4e28a"), false, 1.5)
	draw_rect(Rect2(Vector2(viewport_size.x - 112.0, 220.0), Vector2(94.0, 56.0)), Color("#183329"))
	draw_rect(Rect2(Vector2(viewport_size.x - 112.0, 220.0), Vector2(94.0, 56.0)), Color("#6ccf91"), false, 2.0)
	_draw_text("ZOOM +", Vector2(viewport_size.x - 101.0, 244.0), 14, Color("#e5f8eb"))
	draw_rect(Rect2(Vector2(viewport_size.x - 112.0, 282.0), Vector2(94.0, 56.0)), Color("#183329"))
	draw_rect(Rect2(Vector2(viewport_size.x - 112.0, 282.0), Vector2(94.0, 56.0)), Color("#6ccf91"), false, 2.0)
	_draw_text("ZOOM -", Vector2(viewport_size.x - 101.0, 306.0), 14, Color("#e5f8eb"))

func _draw_hud() -> void:
	draw_rect(Rect2(18.0, 18.0, 390.0, 126.0), Color("#0b1b17", 0.94))
	_draw_text("CONTAINMENT PROTOCOL", Vector2(34.0, 52.0), 22, Color("#e2f4e9"))
	_draw_text("FUNDS  $%d" % funds, Vector2(34.0, 88.0), 21, Color("#f4d77b"))
	_draw_text("SECTOR %02d  WAVE %d/%d" % [sector_index + 1, wave, sector_wave_limit], Vector2(34.0, 122.0), 15, Color("#ffad62"))
	_draw_text("SAVED %d  LOST %d  HORDE %d" % [saved_count, lost_count, zombies.size()], Vector2(34.0, 142.0), 13, Color("#9cbcaf"))
	_draw_text("%s  |  %s" % [day_phase, "ENDLESS" if endless_containment else "CAMPAIGN"], Vector2(34.0, 162.0), 12, Color("#a9c8b7"))
	if message_timer > 0.0:
		_draw_text(message, Vector2(34.0, 177.0), 14, Color("#ffbd76"))
	draw_rect(Rect2(18.0, 214.0, 172.0, 52.0), Color("#183329"))
	draw_rect(Rect2(18.0, 214.0, 172.0, 52.0), Color("#6ccf91"), false, 2.0)
	_draw_text("TIME  " + TIME_LABELS[time_scale_index], Vector2(33.0, 247.0), 17, Color("#e5f8eb"))
	draw_rect(Rect2(18.0, 274.0, 172.0, 52.0), Color("#183329"))
	draw_rect(Rect2(18.0, 274.0, 172.0, 52.0), Color("#6ccf91") if sfx_enabled else Color("#8b6262"), false, 2.0)
	_draw_text("[SFX: ON]" if sfx_enabled else "[SFX: OFF]", Vector2(33.0, 307.0), 16, Color("#e5f8eb"))
	draw_rect(DIAGNOSTIC_BUTTON, Color("#183329"))
	draw_rect(DIAGNOSTIC_BUTTON, Color("#6ccf91") if diagnostics_enabled else Color("#49645a"), false, 2.0)
	_draw_text("DIAG", DIAGNOSTIC_BUTTON.position + Vector2(20.0, 32.0), 16, Color("#e5f8eb"))
	if diagnostics_enabled:
		var entity_count := civilians.size() + zombies.size() + units.size() + barricades.size() + outposts.size() + turrets.size() + flares.size()
		draw_rect(Rect2(210.0, 274.0, 210.0, 52.0), Color("#0b1b17", 0.94))
		_draw_text("FPS %d | ENT %d" % [fps_sample_value, entity_count], Vector2(220.0, 306.0), 14, Color("#a9c8b7"))

func _draw_structure_actions() -> void:
	if selected_structure_type.is_empty() or selected_structure_index < 0:
		return
	var structure_label := selected_structure_type.to_upper()
	var can_upgrade := selected_structure_type == "outpost" or selected_structure_type == "turret"
	var structure_hp := 0.0
	var structure_max_hp := 1.0
	match selected_structure_type:
		"outpost":
			if selected_structure_index >= outposts.size():
				return
			structure_hp = float(outposts[selected_structure_index]["hp"])
			structure_max_hp = float(outposts[selected_structure_index]["max_hp"])
			structure_label = "OUTPOST  LV.%d" % int(outposts[selected_structure_index].get("level", 1))
		"turret":
			if selected_structure_index >= turrets.size():
				return
			structure_hp = float(turrets[selected_structure_index]["hp"])
			structure_max_hp = float(turrets[selected_structure_index]["max_hp"])
			structure_label = "SENTRY  LV.%d" % int(turrets[selected_structure_index].get("level", 1))
		"wall":
			if selected_structure_index >= barricades.size():
				return
			structure_hp = float(barricades[selected_structure_index]["hp"])
			structure_max_hp = float(barricades[selected_structure_index]["max_hp"])
			structure_label = "REINFORCED WALL"
		_:
			return
	draw_rect(Rect2(18.0, STRUCTURE_ACTION_TOP, 380.0, 94.0), Color("#0b1b17", 0.96))
	_draw_text("%s  HP %d/%d" % [structure_label, roundi(structure_hp), roundi(structure_max_hp)], Vector2(30.0, STRUCTURE_ACTION_TOP + 24.0), 14, Color("#dcefe4"))
	draw_rect(Rect2(24.0, STRUCTURE_ACTION_TOP + 34.0, 166.0, 50.0), Color("#254538"))
	draw_rect(Rect2(24.0, STRUCTURE_ACTION_TOP + 34.0, 166.0, 50.0), Color("#72d69a"), false, 2.0)
	_draw_text("REPAIR $40", Vector2(40.0, STRUCTURE_ACTION_TOP + 65.0), 16, Color("#f0fff5"))
	if can_upgrade:
		var level := 1
		if selected_structure_type == "outpost":
			level = int(outposts[selected_structure_index].get("level", 1))
		else:
			level = int(turrets[selected_structure_index].get("level", 1))
		if level < 2:
			draw_rect(Rect2(204.0, STRUCTURE_ACTION_TOP + 34.0, 166.0, 50.0), Color("#3a3420"))
			draw_rect(Rect2(204.0, STRUCTURE_ACTION_TOP + 34.0, 166.0, 50.0), Color("#e4c66d"), false, 2.0)
			_draw_text("UPGRADE $150", Vector2(213.0, STRUCTURE_ACTION_TOP + 65.0), 15, Color("#fff4c7"))

func _draw_deployment_bar() -> void:
	var top := viewport_size.y - 200.0
	draw_rect(Rect2(0.0, top, viewport_size.x, 200.0), Color("#0b1715"))
	draw_line(Vector2(0.0, top), Vector2(viewport_size.x, top), Color("#45665a"), 2.0)
	var half_width := viewport_size.x * 0.5
	draw_rect(Rect2(0.0, top, half_width, 48.0), Color("#254538") if command_tab == 0 else Color("#12251f"))
	draw_rect(Rect2(half_width, top, half_width, 48.0), Color("#254538") if command_tab == 1 else Color("#12251f"))
	_draw_text("UNITS & STRIKES", Vector2(28.0, top + 32.0), 16, Color("#e8fff0"))
	_draw_text("BUILD BASE", Vector2(half_width + 42.0, top + 32.0), 16, Color("#e8fff0"))
	var choices: Array = UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS
	var button_width := viewport_size.x / float(choices.size())
	for i in range(choices.size()):
		var x := float(i) * button_width
		var selected := i == selected_deployment
		draw_rect(Rect2(x + 3.0, top + 54.0, button_width - 6.0, 140.0), Color("#254538") if selected else Color("#12251f"))
		draw_rect(Rect2(x + 3.0, top + 54.0, button_width - 6.0, 140.0), Color("#72d69a") if selected else Color("#29443a"), false, 2.0)
		var deployment: Dictionary = choices[i]
		_draw_text(str(deployment["name"]), Vector2(x + 8.0, top + 91.0), 13, Color("#e8fff0") if selected else Color("#b2c7bc"))
		var detail := str(deployment["detail"])
		if str(deployment["kind"]) == "outpost":
			detail = "$%d" % _deployment_cost("outpost")
		_draw_text(detail, Vector2(x + 8.0, top + 126.0), 12, Color("#f0cc77"))
		_draw_text("TAP MAP", Vector2(x + 8.0, top + 163.0), 10, Color("#8da99a"))

func _select_structure_at(world_position: Vector2) -> bool:
	for index in range(outposts.size() - 1, -1, -1):
		if world_position.distance_to(outposts[index]["pos"]) <= 28.0:
			selected_structure_type = "outpost"
			selected_structure_index = index
			selected_unit_index = -1
			return true
	for index in range(turrets.size() - 1, -1, -1):
		if world_position.distance_to(turrets[index]["pos"]) <= 24.0:
			selected_structure_type = "turret"
			selected_structure_index = index
			selected_unit_index = -1
			return true
	for index in range(barricades.size() - 1, -1, -1):
		if world_position.distance_to(barricades[index]["pos"]) <= 26.0:
			selected_structure_type = "wall"
			selected_structure_index = index
			selected_unit_index = -1
			return true
	return false

func _repair_selected_structure() -> void:
	if funds < STRUCTURE_REPAIR_COST:
		message = "REPAIR REQUIRES $40"
		message_timer = 1.2
		return
	var repaired := false
	match selected_structure_type:
		"outpost":
			if selected_structure_index < outposts.size():
				var structure: Dictionary = outposts[selected_structure_index]
				var old_hp := float(structure["hp"])
				structure["hp"] = minf(float(structure["max_hp"]), old_hp + 100.0)
				outposts[selected_structure_index] = structure
				repaired = float(structure["hp"]) > old_hp
		"turret":
			if selected_structure_index < turrets.size():
				var structure: Dictionary = turrets[selected_structure_index]
				var old_hp := float(structure["hp"])
				structure["hp"] = minf(float(structure["max_hp"]), old_hp + 100.0)
				turrets[selected_structure_index] = structure
				repaired = float(structure["hp"]) > old_hp
		"wall":
			if selected_structure_index < barricades.size():
				var structure: Dictionary = barricades[selected_structure_index]
				var old_hp := float(structure["hp"])
				structure["hp"] = minf(float(structure["max_hp"]), old_hp + 100.0)
				barricades[selected_structure_index] = structure
				repaired = float(structure["hp"]) > old_hp
	if repaired:
		funds -= STRUCTURE_REPAIR_COST
		message = "STRUCTURE REPAIRED +100 HP"
	else:
		message = "STRUCTURE ALREADY AT FULL HP"
	message_timer = 1.3
	queue_redraw()

func _upgrade_selected_structure() -> void:
	if funds < STRUCTURE_UPGRADE_COST:
		message = "UPGRADE REQUIRES $150"
		message_timer = 1.2
		return
	var upgraded := false
	if selected_structure_type == "turret" and selected_structure_index < turrets.size():
		var turret: Dictionary = turrets[selected_structure_index]
		if int(turret.get("level", 1)) < 2:
			turret["level"] = 2
			turret["range"] = 280.0
			turret["damage"] = 32.0
			turret["fire_interval"] = 0.15
			turrets[selected_structure_index] = turret
			upgraded = true
	elif selected_structure_type == "outpost" and selected_structure_index < outposts.size():
		var outpost: Dictionary = outposts[selected_structure_index]
		if int(outpost.get("level", 1)) < 2:
			outpost["level"] = 2
			outpost["safe_radius"] = 230.0
			outpost["capacity"] = 20
			outposts[selected_structure_index] = outpost
			upgraded = true
	if upgraded:
		funds -= STRUCTURE_UPGRADE_COST
		message = "STRUCTURE UPGRADED TO LEVEL 2"
	else:
		message = "NO AVAILABLE UPGRADE"
	message_timer = 1.5
	queue_redraw()

func _update_preview_position(position: Vector2) -> void:
	preview_position = _screen_to_world(position)
	preview_active = true
	queue_redraw()

func _draw_placement_preview() -> void:
	if not preview_active or game_state != "playing":
		return
	var choices: Array = UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS
	if selected_deployment < 0 or selected_deployment >= choices.size():
		return
	var deployment: Dictionary = choices[selected_deployment]
	var kind: String = str(deployment["kind"])
	var radius := _deployment_range(kind)
	var deployment_cost := _deployment_cost(kind)
	var valid := _is_valid_street_position(preview_position) and funds >= deployment_cost
	if kind == "outpost" and outposts.size() >= OUTPOST_MAX_COUNT:
		valid = false
	if kind == "medevac" and not medevac.is_empty():
		valid = false
	var tint := Color(0.2, 1.0, 0.48, 0.18) if valid else Color(1.0, 0.18, 0.2, 0.20)
	var line_tint := Color("#56f58f") if valid else Color("#ff555d")
	draw_circle(preview_position, radius, tint)
	draw_arc(preview_position, radius, 0.0, TAU, 56, line_tint, 2.5)
	draw_circle(preview_position, 5.0, Color(line_tint.r, line_tint.g, line_tint.b, 0.8))

func _deployment_cost(kind: String) -> int:
	if kind == "outpost":
		return OUTPOST_COST + outposts.size() * OUTPOST_COST_STEP
	return OUTPOST_COST if kind == "outpost" else int((UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS)[selected_deployment]["cost"])

func _deployment_range(kind: String) -> float:
	match kind:
		"infantry":
			return 205.0
		"sniper":
			return 390.0
		"airstrike":
			return 112.0
		"flare":
			return FLARE_LURE_RADIUS
		"medevac":
			return MEDEVAC_RING
		"wall":
			return 30.0
		"outpost":
			return 175.0
		"turret":
			return TURRET_RANGE
	return 30.0

func _find_nearest_flare(position: Vector2) -> int:
	var best_index := -1
	var best_distance := FLARE_LURE_RADIUS * FLARE_LURE_RADIUS
	for index in range(flares.size()):
		var distance: float = position.distance_squared_to(flares[index]["pos"])
		if distance <= best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _update_flares(delta: float) -> void:
	for index in range(flares.size() - 1, -1, -1):
		var flare: Dictionary = flares[index]
		flare["life"] = float(flare["life"]) - delta
		flare["phase"] = float(flare["phase"]) + delta
		if float(flare["life"]) <= 0.0:
			flares.remove_at(index)
		else:
			flares[index] = flare

func _damage_zombie(index: int, damage: float) -> void:
	if index < 0 or index >= zombies.size():
		return
	var zombie: Dictionary = zombies[index]
	zombie["hp"] = maxf(0.0, float(zombie.get("hp", 30.0)) - damage)
	if float(zombie["hp"]) > 0.0:
		zombies[index] = zombie
		return
	var dead_position: Vector2 = zombie["pos"]
	var dead_kind: String = str(zombie["kind"])
	zombies.remove_at(index)
	if dead_kind == "spitter":
		_spitter_burst(dead_position)

func _spitter_burst(center: Vector2) -> void:
	shockwaves.append({"pos": center, "radius": 45.0, "life": 0.35, "max_life": 0.35, "toxic": true})
	var infected := 0
	for index in range(civilians.size() - 1, -1, -1):
		if center.distance_to(civilians[index]) <= 45.0:
			var infected_position: Vector2 = civilians[index]
			civilians.remove_at(index)
			if index < civilian_steering.size():
				civilian_steering.remove_at(index)
			zombies.append({"pos": infected_position, "kind": "shambler", "hp": 30.0, "max_hp": 30.0})
			infected += 1
	if infected > 0:
		lost_count += infected
		message = "TOXIC BURST — %d CIVILIANS INFECTED" % infected
		message_timer = 2.0
	else:
		message = "SPITTER TOXIC BURST"
		message_timer = 1.0
	_queue_sfx("infection")

func _setup_audio() -> void:
	audio_rng.randomize()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = AUDIO_SAMPLE_RATE
	generator.buffer_length = 0.25
	var player := AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = -7.0
	audio_player = player
	add_child(audio_player)
	audio_player.play()
	var playback: AudioStreamGeneratorPlayback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		pass

func _queue_sfx(effect: String) -> void:
	if not sfx_enabled:
		return
	if audio_queue.size() < 12:
		audio_queue.append(effect)

func _update_audio() -> void:
	if audio_player == null or not audio_player.playing:
		return
	var playback: AudioStreamGeneratorPlayback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	if not sfx_enabled:
		while playback.get_frames_available() > 0:
			if playback != null:
				playback.push_frame(Vector2.ZERO)
		return
	while audio_samples_left <= 0 and not audio_queue.is_empty():
		audio_effect = audio_queue.pop_front()
		audio_phase = 0.0
		match audio_effect:
			"gunfire":
				audio_samples_left = 1500
			"airstrike":
				audio_samples_left = 11025
			"flare":
				audio_samples_left = 4400
			"infection":
				audio_samples_left = 3300
	while playback.get_frames_available() > 0:
		var sample := 0.0
		if audio_samples_left > 0:
			var progress := 1.0 - float(audio_samples_left) / 11025.0
			match audio_effect:
				"gunfire":
					sample = (audio_rng.randf_range(-1.0, 1.0) * 0.55 + sin(audio_phase * TAU) * 0.25) * (float(audio_samples_left) / 1500.0)
				"airstrike":
					sample = (audio_rng.randf_range(-1.0, 1.0) * 0.32 + sin(audio_phase * TAU * 48.0) * 0.35) * (1.0 - progress) * 0.8
				"flare":
					sample = (audio_rng.randf_range(-1.0, 1.0) * 0.10 + sin(audio_phase * TAU * 880.0) * 0.08) * (1.0 - progress)
				"infection":
					var beep_phase := fposmod(audio_phase, 0.11)
					sample = sin(audio_phase * TAU * 1040.0) * 0.22 if beep_phase < 0.055 else 0.0
			audio_phase += 1.0 / AUDIO_SAMPLE_RATE
			audio_samples_left -= 1
		if playback != null:
			playback.push_frame(Vector2(sample, sample))

func _draw_end_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.01, 0.04, 0.03, 0.88))
	var title := "30-WAVE OPERATION SECURED" if game_state == "victory" else "EVACUATION FAILED"
	var tint := Color("#72f0a2") if game_state == "victory" else Color("#ff6868")
	_draw_text(title, Vector2(viewport_size.x * 0.13, viewport_size.y * 0.40), 38, tint)
	_draw_text("SECTOR %02d — %s" % [sector_index + 1, sector_name.to_upper()], Vector2(viewport_size.x * 0.18, viewport_size.y * 0.44), 18, Color("#b9d9c6"))
	_draw_text("CIVILIANS SAVED: %d" % saved_count, Vector2(viewport_size.x * 0.26, viewport_size.y * 0.48), 22, Color("#e0eee5"))
	_draw_text("CIVILIANS LOST: %d" % lost_count, Vector2(viewport_size.x * 0.26, viewport_size.y * 0.52), 22, Color("#e0a0a0"))
	draw_rect(Rect2(viewport_size.x * 0.21, viewport_size.y * 0.57, viewport_size.x * 0.58, 90), Color("#244a38"))
	draw_rect(Rect2(viewport_size.x * 0.21, viewport_size.y * 0.57, viewport_size.x * 0.58, 90), Color("#8ce5ad"), false, 3.0)
	if wave >= 30 and game_state == "victory":
		draw_rect(Rect2(viewport_size.x * 0.21, viewport_size.y * 0.68, viewport_size.x * 0.58, 72.0), Color("#3a3420"))
		draw_rect(Rect2(viewport_size.x * 0.21, viewport_size.y * 0.68, viewport_size.x * 0.58, 72.0), Color("#e4c66d"), false, 2.0)
		_draw_text("CONTINUE ENDLESS CONTAINMENT", Vector2(viewport_size.x * 0.245, viewport_size.y * 0.725), 16, Color("#fff4c7"))
	_draw_text("RETURN TO SECTOR SELECT", Vector2(viewport_size.x * 0.25, viewport_size.y * 0.615), 20, Color("#f0fff5"))


func _on_viewport_size_changed() -> void:
	viewport_size = get_viewport_rect().size
	_clamp_camera()
	queue_redraw()

func _camera_view_rect() -> Rect2:
	var size: Vector2 = viewport_size / maxf(camera_zoom, 0.01)
	return Rect2(camera_position - size * 0.5, size)

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return camera_position + (screen_position - viewport_size * 0.5) / maxf(camera_zoom, 0.01)

func _clamp_camera() -> void:
	var half_view: Vector2 = viewport_size / maxf(camera_zoom, 0.01) * 0.5
	camera_position.x = clampf(camera_position.x, minf(half_view.x, WORLD_SIZE.x * 0.5), maxf(WORLD_SIZE.x - half_view.x, WORLD_SIZE.x * 0.5))
	camera_position.y = clampf(camera_position.y, minf(half_view.y, WORLD_SIZE.y * 0.5), maxf(WORLD_SIZE.y - half_view.y, WORLD_SIZE.y * 0.5))

func _zoom_camera(factor: float, screen_anchor: Vector2) -> void:
	var before: Vector2 = _screen_to_world(screen_anchor)
	camera_zoom = clampf(camera_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var after: Vector2 = _screen_to_world(screen_anchor)
	camera_position += before - after
	_clamp_camera()
	queue_redraw()

func _nearest_evac_zone(position: Vector2) -> Vector2:
	if evacuation_zones.is_empty():
		return primary_hq_position if primary_hq_position.x >= 0.0 else WORLD_SIZE * 0.5
	var nearest: Vector2 = evacuation_zones[0]
	var nearest_distance: float = position.distance_squared_to(nearest)
	for zone in evacuation_zones:
		var distance: float = position.distance_squared_to(zone)
		if distance < nearest_distance:
			nearest = zone
			nearest_distance = distance
	return nearest

func _night_vision_multiplier() -> float:
	return 0.8 if day_phase == "NIGHT" else 1.0

func _update_outpost_damage(delta: float) -> void:
	if outposts.is_empty() or zombies.is_empty():
		return
	for zombie_index in range(zombies.size() - 1, -1, -1):
		var zombie: Dictionary = zombies[zombie_index]
		var attack_cooldown: float = maxf(0.0, float(zombie.get("outpost_attack_cooldown", 0.0)) - delta)
		if attack_cooldown > 0.0:
			zombie["outpost_attack_cooldown"] = attack_cooldown
			zombies[zombie_index] = zombie
			continue
		var zombie_position: Vector2 = zombie["pos"]
		for outpost_index in range(outposts.size() - 1, -1, -1):
			var outpost: Dictionary = outposts[outpost_index]
			if zombie_position.distance_squared_to(outpost["pos"]) > 34.0 * 34.0:
				continue
			var damage: float = 42.0 if str(zombie.get("kind", "shambler")) == "brute" else 18.0
			outpost["hp"] = maxf(0.0, float(outpost.get("hp", 500.0)) - damage)
			zombie["outpost_attack_cooldown"] = 1.0
			if float(outpost["hp"]) <= 0.0:
				_eject_outpost_shelter(outpost)
				outposts.remove_at(outpost_index)
				message = "FORWARD OUTPOST DESTROYED — SHELTER EVACUATED"
			else:
				outposts[outpost_index] = outpost
				message = "FORWARD OUTPOST UNDER ATTACK"
			message_timer = 1.4
			break
		zombies[zombie_index] = zombie

func _eject_outpost_shelter(outpost: Dictionary) -> void:
	var sheltered: int = maxi(0, int(outpost.get("sheltered", 0)))
	if sheltered <= 0:
		return
	var center: Vector2 = outpost["pos"]
	var ejected: int = 0
	for index in range(sheltered):
		var angle: float = TAU * float(index) / float(maxi(sheltered, 1))
		var candidate: Vector2 = center + Vector2(cos(angle), sin(angle)) * 42.0
		if _is_open_world_position(candidate, 8.0):
			civilians.append(candidate)
			civilian_steering.append({})
			ejected += 1
	lost_count += sheltered - ejected
	if ejected > 0:
		message = "OUTPOST BREACHED — %d CIVILIANS EJECTED" % ejected
		message_timer = 1.5

func _total_sheltered_civilians() -> int:
	var total: int = 0
	for outpost in outposts:
		total += int(outpost.get("sheltered", 0))
	return total

func _shelter_flush_timer_step(delta: float) -> void:
	shelter_flush_timer -= delta
	if shelter_flush_timer > 0.0:
		return
	shelter_flush_timer = 15.0
	for index in range(outposts.size()):
		var sheltered: int = int(outposts[index].get("sheltered", 0))
		if sheltered > 0:
			saved_count += sheltered
			funds += sheltered * 35
			outposts[index]["sheltered"] = 0
			message = "OUTPOST EVACUATION — %d CIVILIANS  +$%d" % [sheltered, sheltered * 35]
			message_timer = 2.0

func _flush_nearby_shelters(position: Vector2) -> void:
	for index in range(outposts.size()):
		if position.distance_to(outposts[index]["pos"]) <= 180.0:
			var sheltered: int = int(outposts[index].get("sheltered", 0))
			if sheltered > 0:
				saved_count += sheltered
				funds += sheltered * 35
				outposts[index]["sheltered"] = 0
				message = "MEDEVAC CLEARED OUTPOST — %d RESCUED" % sheltered
				message_timer = 2.0

func _spawn_refugee_wave() -> void:
	for district in spawn_districts:
		for refugee_index in range(10 + int(wave / 5) * 2):
			var refugee_position := Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
			if _is_open_world_position(refugee_position, 18.0):
				civilians.append(refugee_position)
				civilian_steering.append({})
	message = "REFUGEE CONVOY ENTERING OUTER DISTRICTS"
	message_timer = 3.0

func _update_supply_drops(delta: float) -> void:
	supply_drop_timer -= delta
	if supply_drop_timer <= 0.0:
		supply_drop_timer = 150.0
		var candidate := Vector2(randf_range(120.0, WORLD_SIZE.x - 120.0), randf_range(120.0, WORLD_SIZE.y - 120.0))
		for attempt in range(12):
			if _is_open_world_position(candidate, 32.0):
				break
			candidate = Vector2(randf_range(120.0, WORLD_SIZE.x - 120.0), randf_range(120.0, WORLD_SIZE.y - 120.0))
		supply_crates.append({"pos": candidate})
	for crate_index in range(supply_crates.size() - 1, -1, -1):
		var crate_position: Vector2 = supply_crates[crate_index]["pos"]
		var secured := false
		for squad in units:
			if crate_position.distance_to(squad["pos"]) <= 52.0:
				secured = true
				break
		if secured:
			funds += 120
			supply_crates.remove_at(crate_index)
			message = "TACTICAL SUPPLY SECURED  +$120"
			message_timer = 2.0

func _draw_supply_crates() -> void:
	var view: Rect2 = _camera_view_rect().grow(80.0)
	for crate in supply_crates:
		var crate_position: Vector2 = crate["pos"]
		if view.has_point(crate_position):
			draw_circle(crate_position, 19.0, Color(0.9, 0.72, 0.24, 0.18))
			draw_rect(Rect2(crate_position - Vector2(11.0, 11.0), Vector2(22.0, 22.0)), Color("#d8b65b"))
			draw_line(crate_position + Vector2(-7.0, 0.0), crate_position + Vector2(7.0, 0.0), Color("#fff0b0"), 2.0)

func _save_variant(value: Variant) -> Variant:
	if value is Vector2:
		return {"__vector2": [value.x, value.y]}
	if value is Rect2:
		return {"__rect2": [value.position.x, value.position.y, value.size.x, value.size.y]}
	if value is Dictionary:
		var converted: Dictionary = {}
		for key in value.keys():
			converted[str(key)] = _save_variant(value[key])
		return converted
	if value is Array:
		var converted_array: Array = []
		for item in value:
			converted_array.append(_save_variant(item))
		return converted_array
	return value

func _restore_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has("__vector2"):
			var coordinates: Array = dictionary["__vector2"]
			return Vector2(float(coordinates[0]), float(coordinates[1]))
		if dictionary.has("__rect2"):
			var rect_values: Array = dictionary["__rect2"]
			return Rect2(float(rect_values[0]), float(rect_values[1]), float(rect_values[2]), float(rect_values[3]))
		var restored: Dictionary = {}
		for key in dictionary.keys():
			restored[key] = _restore_variant(dictionary[key])
		return restored
	if value is Array:
		var restored_array: Array = []
		for item in value:
			restored_array.append(_restore_variant(item))
		return restored_array
	return value

func _has_valid_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var save_file := FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return false
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	if not parsed is Dictionary:
		return false
	var state: Dictionary = parsed
	if int(state.get("version", 0)) != 1:
		return false
	if int(state.get("sector_index", -1)) < 0 or int(state.get("sector_index", -1)) > 2:
		return false
	if int(state.get("wave", -1)) < 0:
		return false
	var required_arrays: Array[String] = ["evacuation_zones", "civilians", "zombies", "units", "outposts", "turrets", "barricades"]
	for key in required_arrays:
		if not state.has(key) or not state[key] is Array:
			return false
	var saved_hq: Variant = state.get("primary_hq_position")
	var saved_camera: Variant = state.get("camera_position")
	return saved_hq is Dictionary and saved_hq.has("__vector2") and saved_camera is Dictionary and saved_camera.has("__vector2")

func _save_operation() -> void:
	# Never replace a prior valid campaign with an incomplete HQ-placement state.
	if not campaign_started or game_state == "hq_placement":
		return
	var state: Dictionary = {"version": 1, "sector_index": sector_index, "wave": wave, "funds": funds, "saved_count": saved_count, "lost_count": lost_count, "primary_hq_position": primary_hq_position, "evacuation_zones": evacuation_zones, "civilians": civilians, "zombies": zombies, "units": units, "outposts": outposts, "turrets": turrets, "barricades": barricades, "flares": flares, "medevac": medevac, "camera_position": camera_position, "camera_zoom": camera_zoom, "elapsed": elapsed, "wave_timer": wave_timer, "shelter_flush_timer": shelter_flush_timer, "supply_drop_timer": supply_drop_timer, "supply_crates": supply_crates, "civilian_steering": civilian_steering, "endless_containment": endless_containment, "buildings": buildings, "spawn_districts": spawn_districts, "time_scale_index": time_scale_index, "day_phase": day_phase}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_save_variant(state)))
		file.close()

func _resume_operation() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var state: Dictionary = _restore_variant(parsed)
	_configure_sector(int(state.get("sector_index", 0)))
	sector_index = int(state.get("sector_index", 0))
	wave = int(state.get("wave", 0))
	funds = int(state.get("funds", 300))
	saved_count = int(state.get("saved_count", 0))
	lost_count = int(state.get("lost_count", 0))
	primary_hq_position = state.get("primary_hq_position", Vector2.ZERO)
	evacuation_zones.assign(state.get("evacuation_zones", []))
	civilians.assign(state.get("civilians", []))
	zombies.assign(state.get("zombies", []))
	units.assign(state.get("units", []))
	outposts.assign(state.get("outposts", []))
	turrets.assign(state.get("turrets", []))
	barricades.assign(state.get("barricades", []))
	flares.assign(state.get("flares", []))
	medevac = state.get("medevac", {})
	camera_position = state.get("camera_position", WORLD_SIZE * 0.5)
	camera_zoom = float(state.get("camera_zoom", 0.62))
	elapsed = float(state.get("elapsed", 0.0))
	wave_timer = float(state.get("wave_timer", 180.0))
	shelter_flush_timer = float(state.get("shelter_flush_timer", 15.0))
	supply_drop_timer = float(state.get("supply_drop_timer", 150.0))
	supply_crates.assign(state.get("supply_crates", []))
	civilian_steering.assign(state.get("civilian_steering", []))
	if state.has("buildings"):
		buildings.assign(state["buildings"])
	if state.has("spawn_districts"):
		spawn_districts.assign(state["spawn_districts"])
	time_scale_index = clampi(int(state.get("time_scale_index", 0)), 0, TIME_SCALES.size() - 1)
	day_phase = str(state.get("day_phase", "DAY"))
	endless_containment = bool(state.get("endless_containment", false))
	while civilian_steering.size() < civilians.size():
		civilian_steering.append({})
	campaign_started = true
	manual_paused = false
	lifecycle_paused = false
	game_state = "playing"
	_clamp_camera()
	message = "SAVED OPERATION RESTORED — WAVE %d" % wave
	message_timer = 3.0
	queue_redraw()

func _draw_world_scene() -> void:
	var origin: Vector2 = viewport_size * 0.5 - camera_position * camera_zoom
	draw_set_transform(origin, 0.0, Vector2(camera_zoom, camera_zoom))
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#07110f"))
	_draw_grid()
	_draw_buildings()
	_draw_evac_zone()
	_draw_entities()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_text(value: String, position: Vector2, size: int, color: Color) -> void:
	if screen_font != null:
		draw_string(screen_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
