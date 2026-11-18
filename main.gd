extends Node2D

# Containment Protocol - Godot 4.3
# Portrait 720x1280, drawn natively for low-overhead Android rendering.

const VIEW_SIZE := Vector2(720.0, 1280.0)
const WORLD_SIZE := Vector2(10400.0, 15200.0)
const BAR_TOP := 1080.0
const EVAC_RADIUS := 76.0
const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.4
const CAMERA_DRAG_THRESHOLD := 14.0
const MINIMAP_SIZE := Vector2(154.0, 190.0)
const MIN_TOUCH_TARGET := 48.0
const HUD_EDGE_PADDING := 18.0
const OUTPOST_COST := 220
const TURRET_COST := 140
const WALL_COST := 75
const OUTPOST_INCOME_INTERVAL := 30.0
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
const MAX_ACTIVE_ZOMBIES := 650
const PENDING_WAVE_SPAWN_INTERVAL := 0.20
const SAVE_VERSION := 3
const OUTPOST_MIN_SIZE := 220.0
const OUTPOST_MAX_SIZE := 760.0
const OUTPOST_SNAP := 20.0
const OUTPOST_WALL_THICKNESS := 18.0
const GATE_COST := 90
const CALL_TO_ARMS_COST := 60
const MILITIA_RANGE := 175.0
const HOSPITAL_REGEN_RADIUS := 160.0
const ARMORY_RADIUS := 180.0
const WAREHOUSE_HOLD_TIME := 4.0

const UNIT_DEPLOYMENTS := [
	{"name": "AIRSTRIKE", "detail": "$300", "cost": 300, "kind": "airstrike"},
	{"name": "FLARE", "detail": "BEACON  $40", "cost": FLARE_COST, "kind": "flare"}
]
const BASE_DEPLOYMENTS := [
	{"name": "OUTPOST", "detail": "$220", "cost": OUTPOST_COST, "kind": "outpost"},
	{"name": "TURRET", "detail": "$140", "cost": TURRET_COST, "kind": "turret"},
	{"name": "WALL", "detail": "$75", "cost": WALL_COST, "kind": "wall"}, {"name": "GATE", "detail": "$90", "cost": GATE_COST, "kind": "gate"}
]

var civilians: Array[Vector2] = []
var zombies: Array[Dictionary] = []
var pending_wave_spawns := 0
var pending_wave_spawn_timer := 0.0
var units: Array[Dictionary] = []
var vehicles: Array[Dictionary] = []
var auto_ops_enabled := true
var highway_segments: Array[Dictionary] = []
var secondary_road_segments: Array[Dictionary] = []
var task_reservations: Dictionary = {}
var world_callouts: Array[Dictionary] = []
var selected_vehicle_index := -1
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
var building_archetypes: Array[Dictionary] = []
var district_regions: Array[Rect2] = []
var district_seed_points: Array[Vector2] = []
var campaign_map_seed: int = 0
var starting_district_index: int = 0
var gates: Array[Dictionary] = []
var warehouse_hold_timers: Dictionary = {}
var outpost_placement_active := false
var outpost_placement_dragging := false
var outpost_placement_start := Vector2.ZERO
var outpost_placement_rect := Rect2(Vector2.ZERO, Vector2(OUTPOST_MIN_SIZE, OUTPOST_MIN_SIZE))
var outpost_placement_kind := "outpost"
var outpost_placement_valid := false
var outpost_placement_gesture_mode := ""
var outpost_placement_anchor := Vector2.ZERO
var scenario_camera_target := WORLD_SIZE * 0.5
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
var safe_insets := Vector4.ZERO
var safe_area_rect := Rect2(Vector2.ZERO, VIEW_SIZE)
var touch_target_size := MIN_TOUCH_TARGET
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
	_refresh_safe_area()
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
	vehicles.clear()
	selected_vehicle_index = -1
	auto_ops_enabled = true
	barricades.clear()
	flares.clear()
	outposts.clear()
	turrets.clear()
	gates.clear()
	building_archetypes.clear()
	warehouse_hold_timers.clear()
	outpost_placement_active = false
	outpost_placement_dragging = false
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
	camera_position = scenario_camera_target
	camera_zoom = 0.62
	command_tab = 0
	manual_paused = false
	lifecycle_paused = false
	funds = [500, 420, 620][sector_index]
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
	for district_index in range(spawn_districts.size()):
		var district: Rect2 = spawn_districts[district_index]
		var civilian_spawn_count: int = _scenario_civilian_count(district_index, 30 + _residential_density_bonus(district))
		for i in range(civilian_spawn_count):
			var spawn_point := Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
			if _is_open_world_position(spawn_point, 18.0):
				civilians.append(spawn_point)
				civilian_steering.append({})
	for district_index in range(spawn_districts.size()):
		var district: Rect2 = spawn_districts[district_index]
		for outbreak_index in range(_scenario_initial_zombie_count(district_index)):
			var outbreak_position := Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
			if _is_open_world_position(outbreak_position, 18.0):
				zombies.append({"pos": outbreak_position, "kind": "shambler", "hp": 30.0, "max_hp": 30.0, "wall_cooldown": 0.0})
	message = "SCOUT THE CITY — SELECT PRIMARY HQ LOCATION"
	message_timer = 6.0
	camera_position = scenario_camera_target
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
	for callout_index in range(world_callouts.size() - 1, -1, -1):
		world_callouts[callout_index]["life"] = float(world_callouts[callout_index].get("life", 0.0)) - delta
		if float(world_callouts[callout_index]["life"]) <= 0.0:
			world_callouts.remove_at(callout_index)
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
	_update_vehicles(sim_delta)
	_update_auto_ops(sim_delta)
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
	_update_building_effects(sim_delta)
	_update_gate_states()
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
			var outpost_rect: Rect2 = outpost.get("rect", Rect2(outpost["pos"] - Vector2(110.0, 110.0), Vector2(220.0, 220.0)))
			var outpost_distance: float = civilian.distance_squared_to(outpost["pos"])
			if outpost_rect.grow(80.0).has_point(civilian) and outpost_distance < nearest_outpost_distance:
				nearest_outpost_distance = outpost_distance
				civilian_safe_target = outpost["pos"]
		var civilian_move_target: Vector2 = _outpost_gate_waypoint(civilian, civilian_safe_target)
		var direction: Vector2 = (civilian_move_target - civilian).normalized()
		var displacement: Vector2 = direction * 43.0 * sim_delta
		var civilian_steer: Dictionary = civilian_steering[i] if i < civilian_steering.size() else {}
		civilian = _move_circle_with_buildings(civilian, displacement, 5.5, sim_delta, civilian_move_target, civilian_steer)
		if i < civilian_steering.size():
			civilian_steering[i] = civilian_steer
		civilians[i] = civilian
		var reached_safe_zone := civilian.distance_to(_nearest_evac_zone(civilian)) <= EVAC_RADIUS
		var reached_outpost_index := -1
		for outpost_index in range(outposts.size()):
			var safe_outpost: Dictionary = outposts[outpost_index]
			var safe_rect: Rect2 = safe_outpost.get("rect", Rect2(safe_outpost["pos"] - Vector2(28.0, 28.0), Vector2(56.0, 56.0)))
			if safe_rect.grow(-24.0).has_point(civilian) and int(safe_outpost.get("sheltered", 0)) < int(safe_outpost.get("capacity", 12)):
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
		zombie["gate_attack_cooldown"] = maxf(0.0, float(zombie.get("gate_attack_cooldown", 0.0)) - sim_delta)
		zombie["building_attack_cooldown"] = maxf(0.0, float(zombie.get("building_attack_cooldown", 0.0)) - sim_delta)
		zombie["unit_attack_cooldown"] = maxf(0.0, float(zombie.get("unit_attack_cooldown", 0.0)) - sim_delta)
		var zpos: Vector2 = zombie["pos"]
		var target_index: int = _find_nearest_entity(civilian_grid, civilians, zpos, 640.0)
		var target: Vector2 = _nearest_evac_zone(zpos)
		if target_index >= 0:
			target = civilians[target_index]
		var siege_building_index: int = int(zombie.get("siege_building", -1))
		if siege_building_index >= 0 and siege_building_index < buildings.size() and not bool(building_archetypes[siege_building_index].get("destroyed", false)) and zpos.distance_to(buildings[siege_building_index].get_center()) <= 300.0:
			target = buildings[siege_building_index].get_center()
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
		zpos = _move_circle_with_buildings(zpos, displacement, 10.0 if zombie_kind == "brute" else 7.0, sim_delta, target, zombie, true)
		var contacted_building_index: int = _building_contact_index(zpos, 22.0)
		if contacted_building_index < 0 and siege_building_index >= 0 and siege_building_index < buildings.size() and zpos.distance_to(buildings[siege_building_index].get_center()) <= 28.0:
			contacted_building_index = siege_building_index
		if contacted_building_index >= 0 and float(zombie.get("building_attack_cooldown", 0.0)) <= 0.0:
			var has_garrison := false
			for garrison_unit in units:
				if bool(garrison_unit.get("garrisoned", false)) and int(garrison_unit.get("garrison_building", -1)) == contacted_building_index:
					has_garrison = true
					break
			if has_garrison:
				var building_state: Dictionary = building_archetypes[contacted_building_index]
				var damage: float = 72.0 if zombie_kind == "brute" else (24.0 if zombie_kind == "runner" else 36.0)
				building_state["hp"] = maxf(0.0, float(building_state.get("hp", 900.0)) - damage)
				zombie["building_attack_cooldown"] = 1.0
				if float(building_state["hp"]) <= 0.0:
					building_state["destroyed"] = true
					building_state["secured"] = false
					for garrison_index in range(units.size()):
						var trapped: Dictionary = units[garrison_index]
						if bool(trapped.get("garrisoned", false)) and int(trapped.get("garrison_building", -1)) == contacted_building_index:
							trapped["garrisoned"] = false
							trapped["garrison_building"] = -1
							trapped["hp"] = maxf(1.0, float(trapped.get("hp", 100.0)) - 25.0)
							trapped["pos"] = zpos + Vector2(randf_range(-36.0, 36.0), randf_range(-36.0, 36.0))
							units[garrison_index] = trapped
					message = "BUILDING BREACHED — GARRISON EXPOSED"
					message_timer = 2.0
				building_archetypes[contacted_building_index] = building_state

		for wall_index in range(barricades.size() - 1, -1, -1):
			var wall: Dictionary = barricades[wall_index]
			var wall_pos: Vector2 = wall["pos"]
			var wall_rect: Rect2 = wall.get("rect", Rect2(wall_pos - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))
			var wall_nearest := Vector2(clampf(zpos.x, wall_rect.position.x, wall_rect.end.x), clampf(zpos.y, wall_rect.position.y, wall_rect.end.y))
			if zpos.distance_to(wall_nearest) < 30.0:
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

		for gate_index in range(gates.size() - 1, -1, -1):
			var gate: Dictionary = gates[gate_index]
			var gate_rect: Rect2 = gate["rect"]
			var gate_nearest := Vector2(clampf(zpos.x, gate_rect.position.x, gate_rect.end.x), clampf(zpos.y, gate_rect.position.y, gate_rect.end.y))
			if zpos.distance_to(gate_nearest) <= 30.0 and float(zombie.get("gate_attack_cooldown", 0.0)) <= 0.0:
				var gate_damage: float = 50.0 if zombie_kind == "brute" else 18.0
				gate["hp"] = maxf(0.0, float(gate.get("hp", 500.0)) - gate_damage)
				zombie["gate_attack_cooldown"] = 1.0
				if float(gate["hp"]) <= 0.0:
					gates.remove_at(gate_index)
					message = "PERIMETER GATE BREACHED"
				else:
					gates[gate_index] = gate
				break

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
		if float(zombie.get("unit_attack_cooldown", 0.0)) <= 0.0:
			for unit_index in range(units.size()):
				var exposed_unit: Dictionary = units[unit_index]
				if bool(exposed_unit.get("garrisoned", false)):
					continue
				if zpos.distance_to(exposed_unit["pos"]) <= 22.0:
					var melee_damage: float = 42.0 if zombie_kind == "brute" else 20.0
					exposed_unit["hp"] = maxf(0.0, float(exposed_unit.get("hp", 100.0)) - melee_damage)
					zombie["unit_attack_cooldown"] = 1.0
					if float(exposed_unit["hp"]) <= 0.0:
						units.remove_at(unit_index)
						if selected_unit_index == unit_index:
							selected_unit_index = -1
						elif selected_unit_index > unit_index:
							selected_unit_index -= 1
						message = "FRIENDLY UNIT LOST"
						message_timer = 1.5
					else:
						units[unit_index] = exposed_unit
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
			if zombies.size() < MAX_ACTIVE_ZOMBIES:
				zombies.append({"pos": infected_pos, "kind": "shambler", "hp": 30.0, "max_hp": 30.0})
			message = "CIVILIAN LOST"
			message_timer = 1.4

	_update_outpost_damage(sim_delta)
	_rebuild_zombie_spatial_grid()
	for outpost_index in range(outposts.size()):
		var outpost: Dictionary = outposts[outpost_index]
		outpost["income_timer"] = float(outpost["income_timer"]) - sim_delta
		if float(outpost["income_timer"]) <= 0.0:
			var income_amount := 15 if int(outpost.get("level", 1)) >= 2 else 10
			funds += income_amount
			outpost["income_timer"] = OUTPOST_INCOME_INTERVAL
			message = "OUTPOST SUPPLY +$%d" % income_amount
			message_timer = 0.8
		outposts[outpost_index] = outpost

	_spawn_pending_wave_spawns(sim_delta)

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
				if _is_near_building_type(turret["pos"], "ARMORY", ARMORY_RADIUS):
					fire_interval /= 1.15
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
		var unit_move_target: Variant = unit.get("move_target", null)
		if not bool(unit.get("garrisoned", false)) and unit_move_target is Vector2:
			var unit_position: Vector2 = unit["pos"]
			var unit_waypoint: Vector2 = _outpost_gate_waypoint(unit_position, unit_move_target)
			if unit_position.distance_to(unit_waypoint) > 12.0:
				var raw_unit_steering: Variant = unit.get("steering", {})
				var unit_steering: Dictionary = raw_unit_steering if raw_unit_steering is Dictionary else {}
				var unit_speed: float = 58.0 if str(unit.get("kind", "")) == "militia" else 52.0
				var unit_displacement: Vector2 = (unit_waypoint - unit_position).normalized() * unit_speed * sim_delta
				unit["pos"] = _move_circle_with_buildings(unit_position, unit_displacement, 8.0, sim_delta, unit_waypoint, unit_steering)
				unit["steering"] = unit_steering
			else:
				unit["move_target"] = null
				unit["manual_order"] = false
		units[unit_index] = unit
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - sim_delta)
		if float(unit["cooldown"]) > 0.0 or zombies.is_empty():
			continue
		var unit_pos: Vector2 = unit["pos"]
		var unit_kind: String = str(unit["kind"])
		var is_sniper: bool = unit_kind == "sniper"
		var is_militia: bool = unit_kind == "militia"
		var attack_range: float = 390.0 if is_sniper else (MILITIA_RANGE if is_militia else 205.0)
		if bool(unit.get("garrisoned", false)):
			attack_range *= 1.35
		var target_index: int = _find_unit_combat_target(unit_pos, attack_range, is_sniper)
		if target_index >= 0:
			var target_pos: Vector2 = zombies[target_index]["pos"]
			var firing_origin: Vector2 = unit_pos
			if bool(unit.get("garrisoned", false)):
				var garrison_building_index: int = int(unit.get("garrison_building", -1))
				if garrison_building_index >= 0 and garrison_building_index < buildings.size():
					var roof: Rect2 = buildings[garrison_building_index]
					var fire_direction: Vector2 = (target_pos - roof.get_center()).normalized()
					var half_extent: Vector2 = roof.size * 0.5
					var horizontal_scale: float = absf(fire_direction.x) / maxf(half_extent.x, 1.0)
					var vertical_scale: float = absf(fire_direction.y) / maxf(half_extent.y, 1.0)
					var edge_scale: float = maxf(horizontal_scale, vertical_scale)
					firing_origin = roof.get_center() + fire_direction / maxf(edge_scale, 0.001) * 0.88
			_add_bullet_tracer(firing_origin, target_pos)
			if bool(unit.get("garrisoned", false)):
				var firing_building_index: int = int(unit.get("garrison_building", -1))
				if firing_building_index >= 0 and firing_building_index < buildings.size():
					var marked_zombie: Dictionary = zombies[target_index]
					marked_zombie["siege_building"] = firing_building_index
					zombies[target_index] = marked_zombie
			var unit_damage: float = 80.0 if is_sniper else (16.0 if is_militia else 35.0)
			var fire_interval: float = 1.05 if is_sniper else (0.85 if is_militia else 0.62)
			if _is_near_building_type(unit_pos, "ARMORY", ARMORY_RADIUS):
				fire_interval /= 1.15
			_damage_zombie(target_index, unit_damage)
			unit["cooldown"] = fire_interval
			muzzle_flashes.append({"pos": firing_origin, "life": 0.10, "max_life": 0.10})
			_queue_sfx("gunfire")
			_rebuild_zombie_spatial_grid()
		units[unit_index] = unit

	if wave >= 30 and zombies.is_empty() and pending_wave_spawns <= 0 and civilians.is_empty() and medevac.is_empty() and _total_sheltered_civilians() == 0 and not endless_containment:
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
	sector_index = clampi(index, 0, 2)
	sector_wave_limit = 30
	match sector_index:
		0:
			sector_name = "Suburban Outskirts"
		1:
			sector_name = "Medical & Urban Core"
		2:
			sector_name = "Industrial Highway"
	_generate_state_map()
	starting_district_index = randi_range(0, maxi(0, district_regions.size() - 1))
	if starting_district_index < district_regions.size():
		scenario_camera_target = district_regions[starting_district_index].get_center()

func _scenario_civilian_count(district_index: int, base_count: int) -> int:
	var multiplier: float = 1.0
	match sector_index:
		0:
			multiplier = 1.45 if district_index == 1 else 0.55
		1:
			multiplier = 1.10 if district_index == 0 or district_index == 3 else 0.65
		2:
			multiplier = 1.15 if district_index == 2 or district_index == 4 else 0.55
	return maxi(8, roundi(float(base_count) * multiplier))

func _scenario_initial_zombie_count(district_index: int) -> int:
	match sector_index:
		0:
			return 7 if district_index == 1 else 3
		1:
			return 14 if district_index == 0 or district_index == 3 else 3
		2:
			return 10 if district_index == 2 else (8 if district_index == 4 else 2)
	return 6

func _generate_state_map() -> void:
	buildings.clear()
	building_archetypes.clear()
	highway_segments.clear()
	secondary_road_segments.clear()
	district_regions.clear()
	spawn_districts.clear()
	district_seed_points.clear()
	campaign_map_seed = randi()
	vehicles.clear()
	highway_segments.clear()
	secondary_road_segments.clear()
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = campaign_map_seed
	for district_index in range(8):
		var district_column: int = district_index % 2
		var district_row: int = floori(float(district_index) / 2.0)
		var seed_point := Vector2((float(district_column) + 0.5) * WORLD_SIZE.x / 2.0 + map_rng.randf_range(-380.0, 380.0), (float(district_row) + 0.5) * WORLD_SIZE.y / 4.0 + map_rng.randf_range(-420.0, 420.0))
		var found_seed := false
		for attempt in range(120):
			var candidate := seed_point + Vector2(map_rng.randf_range(-280.0, 280.0), map_rng.randf_range(-300.0, 300.0))
			var candidate_size := Vector2(3600.0, 2850.0)
			var candidate_region_position := candidate - candidate_size * 0.5
			candidate_region_position.x = clampf(candidate_region_position.x, 0.0, WORLD_SIZE.x - candidate_size.x)
			candidate_region_position.y = clampf(candidate_region_position.y, 0.0, WORLD_SIZE.y - candidate_size.y)
			var candidate_region := Rect2(candidate_region_position, candidate_size)
			var spaced := true
			for existing_region in district_regions:
				if candidate_region.intersects(existing_region):
					spaced = false
					break
			if spaced:
				seed_point = candidate
				found_seed = true
				break
		if not found_seed:
			seed_point = Vector2(map_rng.randf_range(700.0, WORLD_SIZE.x - 700.0), map_rng.randf_range(700.0, WORLD_SIZE.y - 700.0))
		district_seed_points.append(seed_point)
		var region_size := Vector2(3600.0, 2850.0)
		var region_position := seed_point - region_size * 0.5
		region_position.x = clampf(region_position.x, 0.0, WORLD_SIZE.x - region_size.x)
		region_position.y = clampf(region_position.y, 0.0, WORLD_SIZE.y - region_size.y)
		var region := Rect2(region_position, region_size)
		district_regions.append(region)
		spawn_districts.append(region.grow(-150.0))
		var cell_width: float = region.size.x / 4.0
		var cell_height: float = region.size.y / 3.0
		for row in range(3):
			for column in range(4):
				if map_rng.randf() < 0.19:
					continue
				var archetype: String = _building_type_for_district(district_index, row, column)
				var width: float = map_rng.randf_range(230.0, 345.0)
				var height: float = map_rng.randf_range(230.0, 355.0)
				if archetype == "HIGHRISE":
					width = map_rng.randf_range(340.0, 405.0)
					height = map_rng.randf_range(350.0, 420.0)
				var x: float = region.position.x + float(column) * cell_width + (cell_width - width) * 0.5 + map_rng.randf_range(-42.0, 42.0)
				var y: float = region.position.y + float(row) * cell_height + (cell_height - height) * 0.5 + map_rng.randf_range(-48.0, 48.0)
				var rect := Rect2(Vector2(x, y), Vector2(width, height))
				rect.position.x = clampf(rect.position.x, region.position.x + 18.0, region.end.x - rect.size.x - 18.0)
				rect.position.y = clampf(rect.position.y, region.position.y + 18.0, region.end.y - rect.size.y - 18.0)
				var base_hp: float = 1800.0 if archetype == "HIGHRISE" else 900.0
				buildings.append(rect)
				building_archetypes.append({"type": archetype, "district": district_index, "cache_available": archetype == "WAREHOUSE", "cache_hold": 0.0, "hp": base_hp, "max_hp": base_hp, "destroyed": false, "fortified": false, "secured": false, "fortified_outpost_index": -1})
	for road_index in range(3):
		var road_y: float = WORLD_SIZE.y * float(road_index + 1) / 4.0
		highway_segments.append({"from": Vector2(0.0, road_y), "to": Vector2(WORLD_SIZE.x, road_y), "width": 76.0})
	for road_index in range(2):
		var road_x: float = WORLD_SIZE.x * float(road_index + 1) / 3.0
		highway_segments.append({"from": Vector2(road_x, 0.0), "to": Vector2(road_x, WORLD_SIZE.y), "width": 68.0})
	for district_index in range(district_seed_points.size()):
		var center: Vector2 = district_seed_points[district_index]
		var nearest_road_y: float = roundf(center.y / (WORLD_SIZE.y / 4.0)) * (WORLD_SIZE.y / 4.0)
		secondary_road_segments.append({"from": Vector2(center.x, center.y), "to": Vector2(center.x, nearest_road_y), "width": 24.0})
	for vehicle_index in range(6):
		var industrial_region: Rect2 = district_regions[2]
		var humvee_pos: Vector2 = _find_vehicle_spawn_position(map_rng, industrial_region, 34.0, vehicle_index, "humvee")
		vehicles.append({"kind": "humvee", "pos": humvee_pos, "hp": 350.0, "max_hp": 350.0, "active": false, "salvage_timer": 4.0, "salvage_cost": 120, "move_target": null, "onboard": 0, "cooldown": 0.0, "salvage_started": false})
	for helicopter_index in range(3):
		var medical_region: Rect2 = district_regions[3]
		var helicopter_pos: Vector2 = _find_vehicle_spawn_position(map_rng, medical_region, 42.0, helicopter_index, "helicopter")
		vehicles.append({"kind": "helicopter", "pos": helicopter_pos, "hp": 260.0, "max_hp": 260.0, "active": false, "salvage_timer": 4.0, "salvage_cost": 220, "move_target": null, "onboard": 0, "cooldown": 0.0, "salvage_started": false})

func _find_vehicle_spawn_position(map_rng: RandomNumberGenerator, region: Rect2, margin: float, spawn_index: int, kind: String) -> Vector2:
	for attempt in range(80):
		var candidate := Vector2(map_rng.randf_range(region.position.x + margin, region.end.x - margin), map_rng.randf_range(region.position.y + margin, region.end.y - margin))
		if _is_open_world_position(candidate, margin):
			return candidate
	var road_x: float = WORLD_SIZE.x * float((spawn_index % 2) + 1) / 3.0
	var road_y: float = WORLD_SIZE.y * float((spawn_index % 3) + 1) / 4.0
	var fallback := Vector2(road_x + float(spawn_index % 2) * 110.0, road_y + float(spawn_index % 3) * 90.0)
	return Vector2(clampf(fallback.x, margin, WORLD_SIZE.x - margin), clampf(fallback.y, margin, WORLD_SIZE.y - margin))

func _building_type_for_district(district_index: int, row: int, column: int) -> String:
	match district_index:
		0:
			return "HIGHRISE" if (row + column) % 4 == 0 else "RESIDENTIAL"
		1:
			return "RESIDENTIAL" if (row + column) % 3 != 0 else "HIGHRISE"
		2:
			return "ARMORY" if column % 4 == 0 else "WAREHOUSE"
		3:
			return "HOSPITAL" if column % 3 == 0 else "RESIDENTIAL"
		6:
			return "HOSPITAL" if column == 0 else ("HIGHRISE" if row == 1 else "RESIDENTIAL")
		7:
			return "WAREHOUSE" if column % 2 == 0 else "RESIDENTIAL"
		_:
			return "WAREHOUSE" if column % 4 == 0 else "RESIDENTIAL"

func _residential_density_bonus(region: Rect2) -> int:
	var residential_count: int = 0
	for index in range(buildings.size()):
		if _building_type_at(index) == "RESIDENTIAL" and region.intersects(buildings[index]):
			residential_count += 1
	return mini(residential_count * 2, 36)

func _building_type_at(index: int) -> String:
	if index < 0 or index >= building_archetypes.size():
		return "RESIDENTIAL"
	return str(building_archetypes[index].get("type", "RESIDENTIAL"))

func _is_near_building_type(position: Vector2, archetype: String, radius: float) -> bool:
	var radius_squared: float = radius * radius
	for index in range(buildings.size()):
		if _building_type_at(index) != archetype:
			continue
		var nearest := Vector2(clampf(position.x, buildings[index].position.x, buildings[index].end.x), clampf(position.y, buildings[index].position.y, buildings[index].end.y))
		if position.distance_squared_to(nearest) <= radius_squared:
			return true
	return false

func _update_engineer_repairs(delta: float) -> void:
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		if str(unit.get("kind", "")) != "engineer" or bool(unit.get("garrisoned", false)):
			continue
		var repair_target: Vector2 = unit["pos"]
		var best_distance: float = 90.0 * 90.0
		var target_kind: String = ""
		var target_index: int = -1
		for index in range(outposts.size()):
			var distance: float = unit["pos"].distance_squared_to(outposts[index]["pos"])
			if distance <= best_distance and float(outposts[index].get("hp", 0.0)) < float(outposts[index].get("max_hp", 1.0)):
				best_distance = distance
				target_kind = "outpost"
				target_index = index
		for index in range(barricades.size()):
			var distance: float = unit["pos"].distance_squared_to(barricades[index]["pos"])
			if distance <= best_distance and float(barricades[index].get("hp", 0.0)) < float(barricades[index].get("max_hp", 1.0)):
				best_distance = distance
				target_kind = "wall"
				target_index = index
		for index in range(gates.size()):
			var distance: float = unit["pos"].distance_squared_to(gates[index]["pos"])
			if distance <= best_distance and float(gates[index].get("hp", 0.0)) < float(gates[index].get("max_hp", 1.0)):
				best_distance = distance
				target_kind = "gate"
				target_index = index
		for index in range(turrets.size()):
			var distance: float = unit["pos"].distance_squared_to(turrets[index]["pos"])
			if distance <= best_distance and float(turrets[index].get("hp", 0.0)) < float(turrets[index].get("max_hp", 1.0)):
				best_distance = distance
				target_kind = "turret"
				target_index = index
		if target_index < 0:
			continue
		match target_kind:
			"outpost":
				outposts[target_index]["hp"] = minf(float(outposts[target_index]["max_hp"]), float(outposts[target_index]["hp"]) + 8.0 * delta)
			"wall":
				barricades[target_index]["hp"] = minf(float(barricades[target_index]["max_hp"]), float(barricades[target_index]["hp"]) + 8.0 * delta)
			"gate":
				gates[target_index]["hp"] = minf(float(gates[target_index]["max_hp"]), float(gates[target_index]["hp"]) + 8.0 * delta)
			"turret":
				turrets[target_index]["hp"] = minf(float(turrets[target_index]["max_hp"]), float(turrets[target_index]["hp"]) + 8.0 * delta)

func _update_building_effects(delta: float) -> void:
	_update_engineer_repairs(delta)
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var max_hp: float = float(unit.get("max_hp", 100.0))
		if _is_near_building_type(unit["pos"], "HOSPITAL", HOSPITAL_REGEN_RADIUS):
			unit["hp"] = minf(max_hp, float(unit.get("hp", max_hp)) + 2.0 * delta)
		units[unit_index] = unit
	for building_index in range(buildings.size()):
		if _building_type_at(building_index) != "WAREHOUSE":
			continue
		var archetype: Dictionary = building_archetypes[building_index]
		if not bool(archetype.get("cache_available", true)):
			continue
		var center: Vector2 = buildings[building_index].get_center()
		var held := false
		for unit in units:
			if center.distance_to(unit["pos"]) <= 72.0:
				held = true
				break
		var hold_time: float = float(archetype.get("cache_hold", 0.0))
		hold_time = hold_time + delta if held else 0.0
		archetype["cache_hold"] = hold_time
		if hold_time >= WAREHOUSE_HOLD_TIME:
			archetype["cache_available"] = false
			funds += 100
			message = "WAREHOUSE CACHE SECURED +$100"
			message_timer = 2.0
		building_archetypes[building_index] = archetype

func _outpost_gate_waypoint(position: Vector2, destination: Vector2) -> Vector2:
	for outpost_index in range(outposts.size()):
		var outpost_rect: Rect2 = outposts[outpost_index].get("rect", Rect2(outposts[outpost_index]["pos"] - Vector2(110.0, 110.0), Vector2(220.0, 220.0)))
		var starts_inside: bool = outpost_rect.has_point(position)
		var ends_inside: bool = outpost_rect.has_point(destination)
		if starts_inside == ends_inside:
			continue
		var nearest_gate_position := Vector2.ZERO
		var nearest_gate_distance := INF
		for gate in gates:
			if int(gate.get("outpost_index", -1)) != outpost_index or float(gate.get("hp", 0.0)) <= 0.0:
				continue
			var gate_position: Vector2 = gate.get("pos", Vector2.ZERO)
			var distance: float = position.distance_squared_to(gate_position)
			if distance < nearest_gate_distance:
				nearest_gate_distance = distance
				nearest_gate_position = gate_position
		if nearest_gate_distance < INF and position.distance_to(nearest_gate_position) > 24.0:
			return nearest_gate_position
	return destination

func _update_gate_states() -> void:
	for gate_index in range(gates.size()):
		var gate: Dictionary = gates[gate_index]
		var gate_position: Vector2 = gate["pos"]
		var should_open := false
		for unit in units:
			if gate_position.distance_to(unit["pos"]) <= 55.0:
				should_open = true
				break
		if not should_open:
			for civilian in civilians:
				if gate_position.distance_to(civilian) <= 55.0:
					should_open = true
					break
		gate["open"] = should_open
		gates[gate_index] = gate

func _outpost_build_cost(size: Vector2) -> int:
	var wall_segments: int = ceili((2.0 * (size.x + size.y)) / 40.0)
	return OUTPOST_COST + wall_segments * 5

func _snap_outpost_size(size: Vector2) -> Vector2:
	return Vector2(clampf(roundf(size.x / OUTPOST_SNAP) * OUTPOST_SNAP, OUTPOST_MIN_SIZE, OUTPOST_MAX_SIZE), clampf(roundf(size.y / OUTPOST_SNAP) * OUTPOST_SNAP, OUTPOST_MIN_SIZE, OUTPOST_MAX_SIZE))

func _outpost_rect_valid(rect: Rect2) -> bool:
	if rect.position.x < 20.0 or rect.position.y < 20.0 or rect.end.x > WORLD_SIZE.x - 20.0 or rect.end.y > WORLD_SIZE.y - 20.0:
		return false
	var edge: float = OUTPOST_WALL_THICKNESS + 8.0
	var edge_bands: Array[Rect2] = [Rect2(rect.position, Vector2(rect.size.x, edge)), Rect2(rect.position, Vector2(edge, rect.size.y)), Rect2(Vector2(rect.end.x - edge, rect.position.y), Vector2(edge, rect.size.y)), Rect2(Vector2(rect.position.x, rect.end.y - edge), Vector2(rect.size.x, edge))]
	for index in range(buildings.size()):
		var building: Rect2 = buildings[index]
		if not rect.intersects(building) or rect.encloses(building):
			continue
		if _building_type_at(index) == "HIGHRISE":
			for edge_band in edge_bands:
				if edge_band.intersects(building):
					return false
	for outpost in outposts:
		var other_rect: Rect2 = outpost.get("rect", Rect2(outpost["pos"] - Vector2(110.0, 110.0), Vector2(220.0, 220.0)))
		if rect.intersects(other_rect.grow(40.0)):
			return false
	return true

func _begin_outpost_placement(world_position: Vector2, placement_kind: String) -> void:
	outpost_placement_active = true
	outpost_placement_dragging = true
	outpost_placement_gesture_mode = "resize"
	outpost_placement_kind = placement_kind
	outpost_placement_start = world_position
	outpost_placement_anchor = world_position
	outpost_placement_rect = Rect2(world_position, Vector2(OUTPOST_MIN_SIZE, OUTPOST_MIN_SIZE))
	_update_outpost_placement_from_anchor(world_position + Vector2(OUTPOST_MIN_SIZE, OUTPOST_MIN_SIZE))

func _begin_outpost_resize(world_position: Vector2) -> void:
	var corners: Array[Vector2] = [outpost_placement_rect.position, Vector2(outpost_placement_rect.end.x, outpost_placement_rect.position.y), outpost_placement_rect.end, Vector2(outpost_placement_rect.position.x, outpost_placement_rect.end.y)]
	var nearest_corner_index := 0
	var nearest_distance := INF
	for corner_index in range(corners.size()):
		var distance: float = world_position.distance_squared_to(corners[corner_index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_corner_index = corner_index
	var opposite_corners: Array[Vector2] = [outpost_placement_rect.end, Vector2(outpost_placement_rect.position.x, outpost_placement_rect.end.y), outpost_placement_rect.position, Vector2(outpost_placement_rect.end.x, outpost_placement_rect.position.y)]
	outpost_placement_anchor = opposite_corners[nearest_corner_index]
	outpost_placement_dragging = true
	outpost_placement_gesture_mode = "resize"
	_update_outpost_placement_from_anchor(corners[nearest_corner_index])

func _update_outpost_placement(world_position: Vector2) -> void:
	_update_outpost_placement_from_anchor(world_position)

func _update_outpost_placement_from_anchor(world_position: Vector2) -> void:
	var delta: Vector2 = world_position - outpost_placement_anchor
	var size: Vector2 = _snap_outpost_size(Vector2(absf(delta.x), absf(delta.y)))
	var top_left := Vector2(minf(world_position.x, outpost_placement_anchor.x), minf(world_position.y, outpost_placement_anchor.y))
	outpost_placement_rect = Rect2(top_left, size)
	var cost: int = _outpost_build_cost(size)
	outpost_placement_valid = _outpost_rect_valid(outpost_placement_rect) and funds >= cost and (outpost_placement_kind == "hq" or outposts.size() < OUTPOST_MAX_COUNT + 1)
	queue_redraw()

func _confirm_outpost_placement() -> void:
	var size: Vector2 = outpost_placement_rect.size
	var cost: int = _outpost_build_cost(size)
	if not outpost_placement_valid or funds < cost:
		message = "OUTPOST FOOTPRINT BLOCKED OR INSUFFICIENT FUNDS"
		message_timer = 1.5
		return
	var center: Vector2 = outpost_placement_rect.get_center()
	if outpost_placement_kind == "hq":
		primary_hq_position = center
		evacuation_zones.clear()
		evacuation_zones.append(center)
		var hq_capacity: int = maxi(12, roundi(size.x * size.y / 18000.0))
		var hq_fortified_count: int = _fortify_enclosed_buildings(outpost_placement_rect, 0)
		outposts.append({"pos": center, "rect": outpost_placement_rect, "income_timer": OUTPOST_INCOME_INTERVAL, "safe_radius": minf(size.x, size.y) * 0.42, "vision_radius": 300.0, "command_radius": OUTPOST_COMMAND_RADIUS, "hp": 1200.0, "max_hp": 1200.0, "level": 1, "capacity": hq_capacity + hq_fortified_count * 8, "sheltered": 0, "fortified_buildings": _fortified_building_indices(0)})
		_create_outpost_perimeter(outpost_placement_rect, 0)
		campaign_started = true
		game_state = "playing"
		wave_timer = 1.0
	else:
		var capacity: int = maxi(12, roundi(size.x * size.y / 18000.0))
		var new_outpost_index: int = outposts.size()
		var fortified_count: int = _fortify_enclosed_buildings(outpost_placement_rect, new_outpost_index)
		outposts.append({"pos": center, "rect": outpost_placement_rect, "income_timer": OUTPOST_INCOME_INTERVAL, "safe_radius": minf(size.x, size.y) * 0.42, "vision_radius": 260.0, "command_radius": OUTPOST_COMMAND_RADIUS, "hp": 900.0, "max_hp": 900.0, "level": 1, "capacity": capacity + fortified_count * 8, "sheltered": 0, "fortified_buildings": _fortified_building_indices(new_outpost_index)})
		_create_outpost_perimeter(outpost_placement_rect, outposts.size() - 1)
	funds -= cost
	outpost_placement_active = false
	outpost_placement_dragging = false
	message = "CUSTOM OUTPOST ESTABLISHED — $%d" % cost
	message_timer = 2.5
	_save_operation()
	queue_redraw()

func _fortified_building_indices(outpost_index: int) -> Array[int]:
	var indices: Array[int] = []
	for building_index in range(building_archetypes.size()):
		if bool(building_archetypes[building_index].get("fortified", false)) and int(building_archetypes[building_index].get("fortified_outpost_index", -1)) == outpost_index:
			indices.append(building_index)
	return indices

func _fortify_enclosed_buildings(rect: Rect2, outpost_index: int) -> int:
	var count: int = 0
	var indices: Array[int] = []
	for building_index in range(buildings.size()):
		if not rect.encloses(buildings[building_index]):
			continue
		var state: Dictionary = building_archetypes[building_index]
		if bool(state.get("fortified", false)):
			continue
		state["fortified"] = true
		state["secured"] = true
		state["fortified_outpost_index"] = outpost_index
		state["hp"] = float(state.get("max_hp", 900.0))
		building_archetypes[building_index] = state
		indices.append(building_index)
		count += 1
	if outpost_index >= 0 and outpost_index < outposts.size():
		outposts[outpost_index]["fortified_buildings"] = indices
	return count

func _create_outpost_perimeter(rect: Rect2, outpost_index: int) -> void:
	var thickness: float = OUTPOST_WALL_THICKNESS
	var gate_width: float = 60.0
	var gate_rect := Rect2(Vector2(rect.position.x + rect.size.x * 0.5 - gate_width * 0.5, rect.end.y - thickness * 0.5), Vector2(gate_width, thickness))
	var wall_rects: Array[Rect2] = [Rect2(rect.position, Vector2(rect.size.x, thickness)), Rect2(rect.position, Vector2(thickness, rect.size.y)), Rect2(Vector2(rect.end.x - thickness, rect.position.y), Vector2(thickness, rect.size.y)), Rect2(Vector2(rect.position.x, rect.end.y - thickness), Vector2((rect.size.x - gate_width) * 0.5, thickness)), Rect2(Vector2(rect.position.x + (rect.size.x + gate_width) * 0.5, rect.end.y - thickness), Vector2((rect.size.x - gate_width) * 0.5, thickness))]
	for wall_rect in wall_rects:
		barricades.append({"pos": wall_rect.get_center(), "rect": wall_rect, "hp": 650.0, "max_hp": 650.0, "kind": "perimeter", "outpost_index": outpost_index})
	gates.append({"pos": gate_rect.get_center(), "rect": gate_rect, "hp": 500.0, "max_hp": 500.0, "open": false, "outpost_index": outpost_index})

func _snap_turret_to_outpost(position: Vector2) -> Vector2:
	var best_position: Vector2 = position
	var best_distance: float = 72.0 * 72.0
	for outpost in outposts:
		var rect: Rect2 = outpost.get("rect", Rect2(outpost["pos"] - Vector2(110.0, 110.0), Vector2(220.0, 220.0)))
		var candidates: Array[Vector2] = [Vector2(clampf(position.x, rect.position.x, rect.end.x), rect.position.y), Vector2(clampf(position.x, rect.position.x, rect.end.x), rect.end.y), Vector2(rect.position.x, clampf(position.y, rect.position.y, rect.end.y)), Vector2(rect.end.x, clampf(position.y, rect.position.y, rect.end.y)), rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for candidate in candidates:
			var distance: float = position.distance_squared_to(candidate)
			if distance < best_distance:
				best_distance = distance
				best_position = candidate
	return best_position

func _try_place_gate(position: Vector2) -> bool:
	if funds < GATE_COST:
		return false
	for outpost_index in range(outposts.size()):
		var rect: Rect2 = outposts[outpost_index]["rect"]
		var nearest := Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
		if nearest.distance_to(position) > 32.0:
			continue
		for wall_index in range(barricades.size() - 1, -1, -1):
			var wall: Dictionary = barricades[wall_index]
			if int(wall.get("outpost_index", -1)) != outpost_index:
				continue
			var wall_rect: Rect2 = wall.get("rect", Rect2(wall["pos"] - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))
			var wall_point := Vector2(clampf(nearest.x, wall_rect.position.x, wall_rect.end.x), clampf(nearest.y, wall_rect.position.y, wall_rect.end.y))
			if wall_point.distance_to(nearest) > 24.0:
				continue
			barricades.remove_at(wall_index)
			var gate_rect: Rect2
			if wall_rect.size.x >= wall_rect.size.y:
				gate_rect = Rect2(Vector2(nearest.x - 30.0, wall_rect.position.y), Vector2(60.0, wall_rect.size.y))
				var left_width: float = gate_rect.position.x - wall_rect.position.x
				var right_start: float = gate_rect.end.x
				var right_width: float = wall_rect.end.x - right_start
				if left_width > 8.0:
					var left_rect := Rect2(wall_rect.position, Vector2(left_width, wall_rect.size.y))
					barricades.append({"pos": left_rect.get_center(), "rect": left_rect, "hp": float(wall["hp"]), "max_hp": float(wall["max_hp"]), "kind": "perimeter", "outpost_index": outpost_index})
				if right_width > 8.0:
					var right_rect := Rect2(Vector2(right_start, wall_rect.position.y), Vector2(right_width, wall_rect.size.y))
					barricades.append({"pos": right_rect.get_center(), "rect": right_rect, "hp": float(wall["hp"]), "max_hp": float(wall["max_hp"]), "kind": "perimeter", "outpost_index": outpost_index})
			else:
				gate_rect = Rect2(Vector2(wall_rect.position.x, nearest.y - 30.0), Vector2(wall_rect.size.x, 60.0))
				var top_height: float = gate_rect.position.y - wall_rect.position.y
				var bottom_start: float = gate_rect.end.y
				var bottom_height: float = wall_rect.end.y - bottom_start
				if top_height > 8.0:
					var top_rect := Rect2(wall_rect.position, Vector2(wall_rect.size.x, top_height))
					barricades.append({"pos": top_rect.get_center(), "rect": top_rect, "hp": float(wall["hp"]), "max_hp": float(wall["max_hp"]), "kind": "perimeter", "outpost_index": outpost_index})
				if bottom_height > 8.0:
					var bottom_rect := Rect2(Vector2(wall_rect.position.x, bottom_start), Vector2(wall_rect.size.x, bottom_height))
					barricades.append({"pos": bottom_rect.get_center(), "rect": bottom_rect, "hp": float(wall["hp"]), "max_hp": float(wall["max_hp"]), "kind": "perimeter", "outpost_index": outpost_index})
			gates.append({"pos": gate_rect.get_center(), "rect": gate_rect, "hp": 500.0, "max_hp": 500.0, "open": false, "outpost_index": outpost_index})
			funds -= GATE_COST
			_save_operation()
			return true
	return false


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

func _building_index_at(position: Vector2) -> int:
	for index in range(buildings.size()):
		if bool(building_archetypes[index].get("destroyed", false)):
			continue
		if buildings[index].has_point(position):
			return index
	return -1

func _garrison_unit(unit_index: int, building_index: int, manual_order: bool = true) -> void:
	if unit_index < 0 or unit_index >= units.size() or building_index < 0 or building_index >= buildings.size():
		return
	var state: Dictionary = building_archetypes[building_index]
	if bool(state.get("destroyed", false)):
		message = "BUILDING DESTROYED — GARRISON UNAVAILABLE"
		message_timer = 1.4
		return
	var garrison_count: int = 0
	for existing_unit in units:
		if bool(existing_unit.get("garrisoned", false)) and int(existing_unit.get("garrison_building", -1)) == building_index:
			garrison_count += 1
	var capacity: int = 8 if _building_type_at(building_index) == "HIGHRISE" else 4
	if not bool(units[unit_index].get("garrisoned", false)) and garrison_count >= capacity:
		message = "BUILDING GARRISON FULL — %d/%d" % [garrison_count, capacity]
		message_timer = 1.5
		return
	var unit: Dictionary = units[unit_index]
	unit["garrisoned"] = true
	unit["garrison_building"] = building_index
	unit["manual_order"] = manual_order
	unit["ai_task"] = "GARRISON"
	unit["pos"] = buildings[building_index].get_center()
	unit.erase("move_target")
	units[unit_index] = unit
	selected_unit_index = unit_index
	message = "UNIT GARRISONED — +35% RANGE / 360° FIRE"
	message_timer = 1.8
	queue_redraw()

func _exit_unit_garrison(unit_index: int, destination: Vector2) -> void:
	if unit_index < 0 or unit_index >= units.size():
		return
	var unit: Dictionary = units[unit_index]
	var exit_position: Vector2 = destination
	if bool(unit.get("garrisoned", false)) and not _is_valid_street_position(exit_position):
		var building_index: int = int(unit.get("garrison_building", -1))
		if building_index >= 0 and building_index < buildings.size():
			var center: Vector2 = buildings[building_index].get_center()
			var found := false
			for radius in [48.0, 72.0, 100.0, 132.0]:
				for angle_index in range(8):
					var angle: float = TAU * float(angle_index) / 8.0
					var candidate: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
					if _is_valid_street_position(candidate):
						exit_position = candidate
						found = true
						break
				if found:
					break
	unit["garrisoned"] = false
	unit["garrison_building"] = -1
	unit["pos"] = exit_position
	unit.erase("move_target")
	units[unit_index] = unit

func _building_contact_index(position: Vector2, distance_limit: float) -> int:
	for index in range(buildings.size()):
		if bool(building_archetypes[index].get("destroyed", false)):
			continue
		var building: Rect2 = buildings[index]
		var nearest := Vector2(clampf(position.x, building.position.x, building.end.x), clampf(position.y, building.position.y, building.end.y))
		if position.distance_to(nearest) <= distance_limit:
			return index
	return -1

func _move_circle_with_buildings(origin: Vector2, displacement: Vector2, radius: float, delta: float, target: Vector2 = Vector2.ZERO, steering: Dictionary = {}, block_gates_for_hostiles: bool = false) -> Vector2:
	var position: Vector2 = origin
	var remaining: Vector2 = displacement
	var lock_time: float = maxf(0.0, float(steering.get("lock_time", 0.0)) - delta)
	steering["lock_time"] = lock_time
	var locked_tangent: Vector2 = steering.get("tangent", Vector2.ZERO)
	if lock_time > 0.0 and locked_tangent.length_squared() > 0.001:
		remaining = locked_tangent.normalized() * displacement.length()
	for iteration in range(2):
		var candidate: Vector2 = position + remaining
		for building_index in range(buildings.size()):
			if bool(building_archetypes[building_index].get("destroyed", false)):
				continue
			var building: Rect2 = buildings[building_index]
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
		for wall in barricades:
			if float(wall.get("hp", 1.0)) <= 0.0:
				continue
			var wall_rect: Rect2 = wall.get("rect", Rect2(wall["pos"] - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))
			var closest_wall := Vector2(clampf(candidate.x, wall_rect.position.x, wall_rect.end.x), clampf(candidate.y, wall_rect.position.y, wall_rect.end.y))
			var wall_offset: Vector2 = candidate - closest_wall
			if wall_offset.length() < radius:
				var wall_normal: Vector2 = wall_offset.normalized() if wall_offset.length_squared() > 0.001 else Vector2.UP
				candidate = closest_wall + wall_normal * radius
		for gate in gates:
			if float(gate.get("hp", 0.0)) <= 0.0:
				continue
			if bool(gate.get("open", false)) and not block_gates_for_hostiles:
				continue
			var gate_rect: Rect2 = gate["rect"]
			var closest_gate := Vector2(clampf(candidate.x, gate_rect.position.x, gate_rect.end.x), clampf(candidate.y, gate_rect.position.y, gate_rect.end.y))
			var gate_offset: Vector2 = candidate - closest_gate
			if gate_offset.length() < radius:
				var gate_normal: Vector2 = gate_offset.normalized() if gate_offset.length_squared() > 0.001 else Vector2.UP
				candidate = closest_gate + gate_normal * radius
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
	var visible_rect: Rect2 = _camera_view_rect().grow(120.0)
	for index in range(buildings.size()):
		var building: Rect2 = buildings[index]
		if not visible_rect.intersects(building):
			continue
		var archetype: String = _building_type_at(index)
		var state: Dictionary = building_archetypes[index]
		var fill: Color = Color("#263746")
		var edge: Color = Color("#829db5")
		var tag: String = "RES"
		match archetype:
			"HOSPITAL":
				fill = Color("#40232b")
				edge = Color("#e45b70")
				tag = "HOSP"
			"ARMORY":
				fill = Color("#40321d")
				edge = Color("#e6b44e")
				tag = "ARMORY"
			"WAREHOUSE":
				fill = Color("#3b3025")
				edge = Color("#c58b4d")
				tag = "SUPPLY"
			"HIGHRISE":
				fill = Color("#1d2e3c")
				edge = Color("#55c8d8")
				tag = "TOWER"
		if bool(state.get("destroyed", false)):
			fill = Color("#171c20")
			edge = Color("#596268")
		draw_rect(building, fill)
		draw_rect(building, edge, false, 5.0 if archetype == "HIGHRISE" else 3.0)
		if archetype == "HIGHRISE":
			draw_rect(building.grow(-10.0), Color("#8be4ed", 0.72), false, 2.0)
			for window_index in range(1, 4):
				var window_x: float = building.position.x + building.size.x * float(window_index) / 4.0
				draw_line(Vector2(window_x, building.position.y + 15.0), Vector2(window_x, building.end.y - 15.0), Color("#7189a5"), 2.0)
		elif archetype == "HOSPITAL":
			var center: Vector2 = building.get_center() + Vector2(0.0, -42.0)
			draw_rect(Rect2(center - Vector2(20.0, 6.0), Vector2(40.0, 12.0)), Color("#fff4f5"))
			draw_rect(Rect2(center - Vector2(6.0, 20.0), Vector2(12.0, 40.0)), Color("#fff4f5"))
		elif archetype == "ARMORY":
			draw_line(building.position + Vector2(20.0, 20.0), building.end - Vector2(20.0, 20.0), edge, 5.0)
		elif archetype == "WAREHOUSE":
			for stripe in range(1, 4):
				var stripe_x: float = building.position.x + building.size.x * float(stripe) / 4.0
				draw_line(Vector2(stripe_x, building.position.y + 18.0), Vector2(stripe_x, building.end.y - 18.0), edge, 3.0)
			if bool(state.get("cache_available", false)):
				var cache_center: Vector2 = building.get_center()
				draw_rect(Rect2(cache_center - Vector2(14.0, 14.0), Vector2(28.0, 28.0)), Color("#d8b65b"))
				_draw_text("$100", cache_center + Vector2(-15.0, 5.0), 13, Color("#fff0b0"))
		if archetype != "HOSPITAL":
			for vent_index in range(3):
				var vent_pos: Vector2 = building.position + Vector2(26.0 + float(vent_index) * 34.0, 30.0)
				draw_rect(Rect2(vent_pos, Vector2(16.0, 12.0)), Color("#17221f"))
				draw_rect(Rect2(vent_pos, Vector2(16.0, 12.0)), edge, false, 1.5)
		if archetype == "HOSPITAL":
			var pad_center: Vector2 = building.get_center() + Vector2(building.size.x * 0.25, building.size.y * 0.24)
			draw_circle(pad_center, 30.0, Color("#283a3a"))
			draw_circle(pad_center, 30.0, Color("#b6d7d2"), false, 2.0)
			_draw_text("H", pad_center + Vector2(-9.0, 9.0), 24, Color("#e8f7f2"))
		var tag_size: int = 18 if building.size.x > 300.0 else 15
		var tag_width: float = screen_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tag_size).x if screen_font != null else 70.0
		if screen_font != null:
			draw_string(screen_font, Vector2(building.get_center().x - tag_width * 0.5, building.get_center().y + 6.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tag_size, Color("#f5f8f2"))
		if bool(state.get("fortified", false)):
			draw_rect(building.grow(-7.0), Color("#53e89b"), false, 4.0)

func _next_unit_id() -> int:
	var highest_id: int = 0
	for existing_unit in units:
		highest_id = maxi(highest_id, int(existing_unit.get("id", 0)))
	return highest_id + 1

func _best_recruitment_outpost() -> int:
	var best_index: int = -1
	var best_discount: bool = false
	for index in range(outposts.size()):
		if int(outposts[index].get("sheltered", 0)) <= 0:
			continue
		var discounted: bool = _is_near_building_type(outposts[index]["pos"], "ARMORY", ARMORY_RADIUS)
		if best_index < 0 or (discounted and not best_discount):
			best_index = index
			best_discount = discounted
	return best_index

func _outpost_recruit_spawn(outpost_index: int, fallback: Vector2) -> Vector2:
	if outpost_index < 0 or outpost_index >= outposts.size():
		return fallback + Vector2(28.0, 0.0)
	for gate in gates:
		if int(gate.get("outpost_index", -1)) == outpost_index:
			return gate["rect"].get_center() + Vector2(0.0, 20.0)
	return outposts[outpost_index]["pos"] + Vector2(0.0, 118.0)

func _recruit_unit(kind: String) -> void:
	if kind != "infantry" and kind != "sniper" and kind != "engineer":
		return
	var source_index: int = _best_recruitment_outpost()
	if source_index < 0:
		message = "REQUIRES 1 SHELTERED SETTLER IN AN OUTPOST"
		message_timer = 2.0
		return
	var base_cost: int = 60 if kind == "infantry" else (110 if kind == "sniper" else 85)
	var discounted: bool = _is_near_building_type(outposts[source_index]["pos"], "ARMORY", ARMORY_RADIUS)
	var cost: int = roundi(float(base_cost) * (0.75 if discounted else 1.0))
	if funds < cost:
		message = "RECRUITMENT REQUIRES $%d" % cost
		message_timer = 1.5
		return
	var spawn_position: Vector2 = _outpost_recruit_spawn(source_index, outposts[source_index]["pos"])
	outposts[source_index]["sheltered"] = maxi(0, int(outposts[source_index].get("sheltered", 0)) - 1)
	units.append({"id": _next_unit_id(), "pos": spawn_position, "kind": kind, "cooldown": 0.1, "hp": 100.0, "max_hp": 100.0, "garrisoned": false, "garrison_building": -1, "move_target": null, "manual_order": false, "ai_task": "", "steering": {}})
	funds -= cost
	selected_unit_index = units.size() - 1
	message = "%s RECRUITED — $%d" % [kind.to_upper(), cost]
	message_timer = 2.0
	_save_operation()

func _ai_button_rect() -> Rect2:
	return Rect2(Vector2(safe_insets.x + 390.0, safe_insets.y + 196.0), Vector2(140.0, touch_target_size))

func _recruit_button_rect(index: int) -> Rect2:
	return Rect2(Vector2(safe_insets.x + 390.0, safe_insets.y + 196.0 + float(index + 1) * (touch_target_size + 6.0)), Vector2(140.0, touch_target_size))

func _engineer_button_rect() -> Rect2:
	return Rect2(Vector2(safe_insets.x + 390.0, safe_insets.y + 196.0 + 3.0 * (touch_target_size + 6.0)), Vector2(140.0, touch_target_size))

func _salvage_button_rect() -> Rect2:
	return Rect2(Vector2(safe_insets.x + 390.0, safe_insets.y + 196.0 + 4.0 * (touch_target_size + 6.0)), Vector2(140.0, touch_target_size))

func _find_unit_combat_target(position: Vector2, attack_range: float, sniper: bool) -> int:
	if sniper:
		var special_index: int = -1
		var special_distance: float = attack_range * attack_range
		for index in range(zombies.size()):
			var zombie: Dictionary = zombies[index]
			if str(zombie.get("kind", "")) != "brute" and str(zombie.get("kind", "")) != "spitter":
				continue
			var distance: float = position.distance_squared_to(zombie["pos"])
			if distance <= special_distance:
				special_distance = distance
				special_index = index
		if special_index >= 0:
			return special_index
	return _find_nearest_zombie(position, attack_range)

func _update_auto_ops(delta: float) -> void:
	if delta <= 0.0 or not auto_ops_enabled:
		return
	var reserved_civilians: Array[Vector2] = []
	var reserved_caches: Array[int] = []
	var reserved_crates: Array[int] = []
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		if bool(unit.get("garrisoned", false)) or bool(unit.get("manual_order", false)):
			continue
		var position: Vector2 = unit["pos"]
		var task: String = str(unit.get("ai_task", ""))
		var move_target: Variant = unit.get("move_target", null)
		if bool(unit.get("carrying_civilian", false)):
			var destination_outpost: int = _nearest_outpost_index(position)
			if destination_outpost >= 0:
				var gate_position: Vector2 = _nearest_outpost_gate_position(destination_outpost, position)
				if position.distance_to(gate_position) <= 32.0:
					var shelter_capacity: int = int(outposts[destination_outpost].get("capacity", 20))
					outposts[destination_outpost]["sheltered"] = mini(shelter_capacity, int(outposts[destination_outpost].get("sheltered", 0)) + 1)
					unit["carrying_civilian"] = false
					unit["move_target"] = null
					unit["ai_task"] = ""
					world_callouts.append({"pos": gate_position, "text": "CIVILIAN SECURED", "life": 1.8})
				else:
					unit["move_target"] = gate_position
					unit["ai_task"] = "ESCORT"
			units[unit_index] = unit
			continue
		if move_target is Vector2 and position.distance_to(move_target) > 22.0:
			if task == "ESCORT":
				var reserved_position: Vector2 = unit.get("ai_target_pos", move_target)
				reserved_civilians.append(reserved_position)
			elif task == "SCAVENGE":
				reserved_caches.append(int(unit.get("ai_target_index", -1)))
			elif task == "SUPPLY":
				reserved_crates.append(int(unit.get("ai_target_index", -1)))
			continue
		if task == "ESCORT":
			var civilian_pickup := _nearest_civilian_to(position, 34.0)
			if civilian_pickup >= 0:
				civilians.remove_at(civilian_pickup)
				if civilian_pickup < civilian_steering.size():
					civilian_steering.remove_at(civilian_pickup)
				_rebuild_spatial_grid(civilian_grid, civilians)
				unit["carrying_civilian"] = true
				unit["move_target"] = null
				unit["ai_task"] = "ESCORT"
				units[unit_index] = unit
				continue
		if task == "SCAVENGE":
			var cache_index: int = int(unit.get("ai_target_index", -1))
			if cache_index >= 0 and cache_index < buildings.size():
				var cache_state: Dictionary = building_archetypes[cache_index]
				if bool(cache_state.get("cache_available", false)) and position.distance_to(buildings[cache_index].get_center()) <= 72.0:
					cache_state["cache_available"] = false
					building_archetypes[cache_index] = cache_state
					funds += 100
					world_callouts.append({"pos": buildings[cache_index].get_center(), "text": "+$100", "life": 2.0})
					unit["ai_task"] = ""
					unit["move_target"] = null
					units[unit_index] = unit
					continue
		if task == "SUPPLY":
			var crate_index: int = int(unit.get("ai_target_index", -1))
			if crate_index >= 0 and crate_index < supply_crates.size() and position.distance_to(supply_crates[crate_index]["pos"]) <= 30.0:
				funds += 80
				world_callouts.append({"pos": supply_crates[crate_index]["pos"], "text": "+$80", "life": 2.0})
				supply_crates.remove_at(crate_index)
				unit["ai_task"] = ""
				unit["move_target"] = null
				units[unit_index] = unit
				continue
		unit["ai_task"] = ""
		unit["move_target"] = null
		var next_task := ""
		var next_target := position
		if str(unit.get("kind", "")) == "infantry" and float(unit.get("hp", 100.0)) / maxf(float(unit.get("max_hp", 100.0)), 1.0) < 0.25:
			var retreat_index: int = _nearest_outpost_index(position)
			if retreat_index >= 0:
				next_target = _nearest_outpost_gate_position(retreat_index, position)
				next_task = "RETREAT"
		if next_task.is_empty() and str(unit.get("kind", "")) == "engineer":
			var repair_position: Vector2 = _nearest_damaged_structure(position, 650.0)
			if repair_position != Vector2.INF:
				next_target = repair_position
				next_task = "REPAIR"
		if next_task.is_empty():
			var rescue_index: int = _nearest_unreserved_civilian(position, 500.0, reserved_civilians)
			if rescue_index >= 0:
				next_target = civilians[rescue_index]
				next_task = "ESCORT"
				unit["ai_target_pos"] = next_target
				reserved_civilians.append(next_target)
		if next_task.is_empty():
			var warehouse_index: int = _nearest_unreserved_warehouse(position, 500.0, reserved_caches)
			if warehouse_index >= 0:
				next_target = buildings[warehouse_index].get_center()
				next_task = "SCAVENGE"
				unit["ai_target_index"] = warehouse_index
				reserved_caches.append(warehouse_index)
		if next_task.is_empty():
			var crate_index: int = _nearest_unreserved_crate(position, 420.0, reserved_crates)
			if crate_index >= 0:
				next_target = supply_crates[crate_index]["pos"]
				next_task = "SUPPLY"
				unit["ai_target_index"] = crate_index
				reserved_crates.append(crate_index)
		if next_task.is_empty() and _zombies_nearby(position, 260.0):
			var shelter_index: int = _nearest_intact_building(position, 180.0)
			if shelter_index >= 0 and _building_garrison_count(shelter_index) < (8 if _building_type_at(shelter_index) == "HIGHRISE" else 4):
				_garrison_unit(unit_index, shelter_index, false)
				continue
		if not next_task.is_empty() and position.distance_to(next_target) > 24.0:
			unit["move_target"] = next_target
			unit["ai_task"] = next_task
		units[unit_index] = unit

func _nearest_outpost_gate_position(outpost_index: int, from_position: Vector2) -> Vector2:
	var best_position: Vector2 = outposts[outpost_index]["pos"]
	var best_distance: float = INF
	for gate in gates:
		if int(gate.get("outpost_index", -1)) != outpost_index or float(gate.get("hp", 0.0)) <= 0.0:
			continue
		var gate_position: Vector2 = gate["pos"]
		var distance: float = from_position.distance_squared_to(gate_position)
		if distance < best_distance:
			best_distance = distance
			best_position = gate_position
	return best_position

func _nearest_civilian_to(position: Vector2, radius: float) -> int:
	var best_index := -1
	var best_distance: float = radius * radius
	for index in range(civilians.size()):
		var distance: float = position.distance_squared_to(civilians[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _nearest_unreserved_civilian(position: Vector2, radius: float, reserved: Array[Vector2]) -> int:
	var best_index := -1
	var best_distance: float = radius * radius
	for index in range(civilians.size()):
		var candidate: Vector2 = civilians[index]
		var taken := false
		for reserved_position in reserved:
			if candidate.distance_squared_to(reserved_position) <= 42.0 * 42.0:
				taken = true
				break
		if taken:
			continue
		var distance: float = position.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _nearest_unreserved_warehouse(position: Vector2, radius: float, reserved: Array[int]) -> int:
	var best_index := -1
	var best_distance: float = radius * radius
	for index in range(buildings.size()):
		if _building_type_at(index) != "WAREHOUSE" or index in reserved or not bool(building_archetypes[index].get("cache_available", false)):
			continue
		var distance: float = position.distance_squared_to(buildings[index].get_center())
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _nearest_unreserved_crate(position: Vector2, radius: float, reserved: Array[int]) -> int:
	var best_index := -1
	var best_distance: float = radius * radius
	for index in range(supply_crates.size()):
		if index in reserved:
			continue
		var distance: float = position.distance_squared_to(supply_crates[index]["pos"])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _nearest_damaged_structure(position: Vector2, radius: float) -> Vector2:
	var best_position := Vector2.INF
	var best_distance: float = radius * radius
	for structure in outposts:
		if float(structure.get("hp", 0.0)) >= float(structure.get("max_hp", 1.0)):
			continue
		var distance: float = position.distance_squared_to(structure["pos"])
		if distance < best_distance:
			best_distance = distance
			best_position = structure["pos"]
	for structure in barricades:
		if float(structure.get("hp", 0.0)) >= float(structure.get("max_hp", 1.0)):
			continue
		var distance: float = position.distance_squared_to(structure["pos"])
		if distance < best_distance:
			best_distance = distance
			best_position = structure["pos"]
	for structure in gates:
		if float(structure.get("hp", 0.0)) >= float(structure.get("max_hp", 1.0)):
			continue
		var distance: float = position.distance_squared_to(structure["pos"])
		if distance < best_distance:
			best_distance = distance
			best_position = structure["pos"]
	for structure in turrets:
		if float(structure.get("hp", 0.0)) >= float(structure.get("max_hp", 1.0)):
			continue
		var distance: float = position.distance_squared_to(structure["pos"])
		if distance < best_distance:
			best_distance = distance
			best_position = structure["pos"]
	return best_position


	if delta <= 0.0 or not auto_ops_enabled:
		return
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		if bool(unit.get("garrisoned", false)) or bool(unit.get("manual_order", false)):
			continue
		var current_target: Variant = unit.get("move_target", null)
		if current_target is Vector2:
			if unit["pos"].distance_to(current_target) > 20.0:
				continue
			unit["move_target"] = null
			unit["ai_task"] = ""
		var position: Vector2 = unit["pos"]
		var task: String = ""
		var target: Vector2 = position
		if str(unit.get("kind", "")) == "infantry" and float(unit.get("hp", 100.0)) / maxf(float(unit.get("max_hp", 100.0)), 1.0) < 0.25:
			var retreat_index: int = _nearest_outpost_index(position)
			if retreat_index >= 0:
				target = outposts[retreat_index]["pos"]
				task = "RETREAT"
		if task.is_empty():
			var rescue_index: int = _nearest_unescorted_civilian(position, 500.0)
			var safe_outpost_index: int = _nearest_outpost_index(position)
			if rescue_index >= 0 and safe_outpost_index >= 0:
				target = civilians[rescue_index]
				task = "RESCUE"
		if task.is_empty():
			var crate_index: int = _nearest_supply_crate(position, 420.0)
			if crate_index >= 0:
				target = supply_crates[crate_index]["pos"]
				task = "SCAVENGE"
		if task.is_empty() and _zombies_nearby(position, 260.0):
			var shelter_index: int = _nearest_intact_building(position, 180.0)
			if shelter_index >= 0 and _building_garrison_count(shelter_index) < (8 if _building_type_at(shelter_index) == "HIGHRISE" else 4):
				_garrison_unit(unit_index, shelter_index)
				continue
		if not task.is_empty() and position.distance_to(target) > 24.0:
			unit["move_target"] = target
			unit["ai_task"] = task
			units[unit_index] = unit

func _nearest_outpost_index(position: Vector2) -> int:
	var best: int = -1
	var best_distance: float = INF
	for index in range(outposts.size()):
		var distance: float = position.distance_squared_to(outposts[index]["pos"])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

func _nearest_unescorted_civilian(position: Vector2, radius: float) -> int:
	var best: int = -1
	var best_distance: float = radius * radius
	for index in range(civilians.size()):
		var distance: float = position.distance_squared_to(civilians[index])
		if distance <= best_distance:
			best_distance = distance
			best = index
	return best

func _nearest_supply_crate(position: Vector2, radius: float) -> int:
	var best: int = -1
	var best_distance: float = radius * radius
	for index in range(supply_crates.size()):
		var distance: float = position.distance_squared_to(supply_crates[index]["pos"])
		if distance <= best_distance:
			best_distance = distance
			best = index
	return best

func _zombies_nearby(position: Vector2, radius: float) -> bool:
	for zombie in zombies:
		if position.distance_squared_to(zombie["pos"]) <= radius * radius:
			return true
	return false

func _nearest_intact_building(position: Vector2, radius: float) -> int:
	var best: int = -1
	var best_distance: float = radius * radius
	for index in range(buildings.size()):
		if bool(building_archetypes[index].get("destroyed", false)):
			continue
		var distance: float = position.distance_squared_to(buildings[index].get_center())
		if distance <= best_distance:
			best_distance = distance
			best = index
	return best

func _building_garrison_count(building_index: int) -> int:
	var count: int = 0
	for unit in units:
		if bool(unit.get("garrisoned", false)) and int(unit.get("garrison_building", -1)) == building_index:
			count += 1
	return count

func _unit_near_vehicle_kind(position: Vector2, kind: String, radius: float) -> bool:
	for unit in units:
		if str(unit.get("kind", "")) == kind and not bool(unit.get("garrisoned", false)) and unit["pos"].distance_to(position) <= radius:
			return true
	return false

func _salvage_nearest_vehicle() -> void:
	var best_index: int = -1
	var best_distance: float = 75.0 * 75.0
	for index in range(vehicles.size()):
		if bool(vehicles[index].get("active", false)):
			continue
		for unit in units:
			if not bool(unit.get("garrisoned", false)):
				var distance: float = unit["pos"].distance_squared_to(vehicles[index]["pos"])
				if distance <= best_distance:
					best_distance = distance
					best_index = index
	if best_index < 0:
		message = "SQUAD MUST HOLD WITHIN 75M OF VEHICLE"
		message_timer = 1.8
		return
	var vehicle: Dictionary = vehicles[best_index]
	if funds < int(vehicle.get("salvage_cost", 0)):
		message = "SALVAGE REQUIRES $%d" % int(vehicle.get("salvage_cost", 0))
		message_timer = 1.5
		return
	var engineer_salvage: bool = _unit_near_vehicle_kind(vehicle["pos"], "engineer", 75.0)
	var salvage_duration: float = 2.0 if engineer_salvage else 4.0
	vehicle["salvage_started"] = true
	vehicle["salvage_duration"] = salvage_duration
	vehicle["salvage_timer"] = salvage_duration
	vehicles[best_index] = vehicle
	message = "ENGINEER SALVAGE — HOLD 2.0S" if engineer_salvage else "SALVAGE CREW DEPLOYED — HOLD 4.0S"
	message_timer = 1.8

func _update_vehicles(delta: float) -> void:
	for index in range(vehicles.size()):
		var vehicle: Dictionary = vehicles[index]
		var position: Vector2 = vehicle["pos"]
		var helicopter: bool = str(vehicle.get("kind", "")) == "helicopter"
		if not bool(vehicle.get("active", false)):
			if bool(vehicle.get("salvage_started", false)):
				var holding_unit: bool = false
				var engineer_present: bool = false
				for unit in units:
					if bool(unit.get("garrisoned", false)) or unit["pos"].distance_to(position) > 75.0:
						continue
					holding_unit = true
					if str(unit.get("kind", "")) == "engineer":
						engineer_present = true
				if holding_unit:
					vehicle["salvage_timer"] = maxf(0.0, float(vehicle.get("salvage_timer", 4.0)) - delta * (2.0 if engineer_present else 1.0))
					if float(vehicle["salvage_timer"]) <= 0.0 and funds >= int(vehicle.get("salvage_cost", 0)):
						funds -= int(vehicle.get("salvage_cost", 0))
						vehicle["active"] = true
						vehicle["salvage_started"] = false
						message = "VEHICLE RESTORED"
						message_timer = 2.0
						world_callouts.append({"pos": position, "text": "RESTORED", "life": 2.2})
				else:
					vehicle["salvage_timer"] = float(vehicle.get("salvage_duration", 4.0))
		else:
			var target_value: Variant = vehicle.get("move_target", null)
			if int(vehicle.get("onboard", 0)) > 0 and (not target_value is Vector2):
				var nearest_outpost: int = _nearest_outpost_index(position)
				if nearest_outpost >= 0:
					vehicle["move_target"] = _nearest_outpost_gate_position(nearest_outpost, position)
					target_value = vehicle["move_target"]
			if target_value is Vector2:
				var target: Vector2 = target_value
				var speed: float = 280.0 if helicopter else 145.0
				var displacement: Vector2 = (target - position).normalized() * speed * delta
				var next_position: Vector2 = position + displacement
				if helicopter or _is_valid_street_position(next_position):
					position = next_position
					vehicle["pos"] = position
				if position.distance_to(target) <= 24.0:
					vehicle["move_target"] = null
					if int(vehicle.get("onboard", 0)) > 0:
						var nearest_outpost: int = _nearest_outpost_index(position)
						if nearest_outpost >= 0 and position.distance_to(_nearest_outpost_gate_position(nearest_outpost, position)) <= 55.0:
						var rescued: int = int(vehicle["onboard"])
						vehicle["onboard"] = 0
						saved_count += rescued
						funds += rescued * 35
						world_callouts.append({"pos": position, "text": "+$%d" % (rescued * 35), "life": 2.0})
						message = "VEHICLE EVACUATION — %d CIVILIANS" % rescued
						message_timer = 2.0
			var pickup_count: int = int(vehicle.get("onboard", 0))
			if pickup_count < 6:
				for civilian_index in range(civilians.size() - 1, -1, -1):
					if position.distance_to(civilians[civilian_index]) <= (62.0 if helicopter else 42.0):
						civilians.remove_at(civilian_index)
						if civilian_index < civilian_steering.size():
							civilian_steering.remove_at(civilian_index)
						pickup_count += 1
						if pickup_count >= 6:
							break
				vehicle["onboard"] = pickup_count
			if not helicopter:
				for zombie_index in range(zombies.size() - 1, -1, -1):
					if position.distance_to(zombies[zombie_index]["pos"]) <= 34.0 and speed >= 90.0:
						var hit_zombie: Dictionary = zombies[zombie_index]
						hit_zombie["pos"] = position + (hit_zombie["pos"] - position).normalized() * 46.0
					hit_zombie["hp"] = float(hit_zombie.get("hp", 30.0)) - 45.0
						if float(hit_zombie["hp"]) <= 0.0:
							zombies.remove_at(zombie_index)
						else:
							zombies[zombie_index] = hit_zombie
			vehicle["cooldown"] = maxf(0.0, float(vehicle.get("cooldown", 0.0)) - delta)
			if float(vehicle["cooldown"]) <= 0.0:
				var target_zombie: int = _find_nearest_zombie(position, 260.0)
				if target_zombie >= 0:
					var zombie_target: Vector2 = zombies[target_zombie]["pos"]
					var side_offset: Vector2 = (zombie_target - position).normalized().orthogonal() * (12.0 if helicopter else 0.0)
					_add_bullet_tracer(position + side_offset, zombie_target)
					if helicopter:
						_add_bullet_tracer(position - side_offset, zombie_target)
					_damage_zombie(target_zombie, 28.0 if helicopter else 32.0)
					vehicle["cooldown"] = 0.28 if helicopter else 0.35
		vehicles[index] = vehicle


	for index in range(vehicles.size()):
		var vehicle: Dictionary = vehicles[index]
		var position: Vector2 = vehicle["pos"]
		if not bool(vehicle.get("active", false)):
			if bool(vehicle.get("salvage_started", false)):
				var held: bool = false
				for unit in units:
					if not bool(unit.get("garrisoned", false)) and unit["pos"].distance_to(position) <= 75.0:
						held = true
						break
				if held:
					vehicle["salvage_timer"] = maxf(0.0, float(vehicle.get("salvage_timer", 4.0)) - delta)
					if float(vehicle["salvage_timer"]) <= 0.0 and funds >= int(vehicle.get("salvage_cost", 0)):
						funds -= int(vehicle.get("salvage_cost", 0))
						vehicle["active"] = true
						vehicle["salvage_started"] = false
						message = "VEHICLE RESTORED — PLAYER CONTROL ENABLED"
						message_timer = 2.0
				else:
					vehicle["salvage_timer"] = 4.0
		else:
			var target_value: Variant = vehicle.get("move_target", null)
			if target_value is Vector2:
				var target: Vector2 = target_value
				var speed: float = 250.0 if str(vehicle.get("kind", "")) == "helicopter" else 145.0
				var step: float = speed * delta
				position = position.move_toward(target, step)
				vehicle["pos"] = position
				if position.distance_to(target) <= 8.0:
					vehicle["move_target"] = null
				vehicle["cooldown"] = maxf(0.0, float(vehicle.get("cooldown", 0.0)) - delta)
				if float(vehicle["cooldown"]) <= 0.0:
					var target_zombie: int = _find_nearest_zombie(position, 230.0)
					if target_zombie >= 0:
						_add_bullet_tracer(position, zombies[target_zombie]["pos"])
						_damage_zombie(target_zombie, 24.0 if str(vehicle.get("kind", "")) == "helicopter" else 32.0)
						vehicle["cooldown"] = 0.35
		vehicles[index] = vehicle

func _spawn_wave() -> void:
	wave += 1
	var escalation_phase: int = int(float(wave - 1) / 6.0) + 1
	# Escalate through the 30-wave campaign; endless mode grows more slowly
	# after the campaign ceiling so entity counts remain bounded on mobile.
	var phase_multiplier: float = minf(1.0 + float(escalation_phase - 1) * 0.25, 3.0)
	var count: int = mini(roundi(float(18 + wave * 8) * phase_multiplier), 900)
	pending_wave_spawns += count
	_spawn_pending_wave_spawns(0.0, true)
	if wave % 5 == 0:
		_spawn_refugee_wave()
	message = "PHASE %d — HORDE WAVE %d INBOUND" % [ceili(float(wave) / 6.0), wave]
	message_timer = 3.0


func _spawn_pending_wave_spawns(delta: float, fill_available: bool = false) -> void:
	if pending_wave_spawns <= 0:
		pending_wave_spawn_timer = 0.0
		return
	if spawn_districts.is_empty():
		return
	if fill_available:
		while pending_wave_spawns > 0 and zombies.size() < MAX_ACTIVE_ZOMBIES:
			if not _spawn_one_wave_zombie():
				break
			pending_wave_spawns -= 1
		pending_wave_spawn_timer = PENDING_WAVE_SPAWN_INTERVAL if pending_wave_spawns > 0 else 0.0
		return
	pending_wave_spawn_timer = maxf(0.0, pending_wave_spawn_timer - delta)
	if pending_wave_spawn_timer > 0.0 or zombies.size() >= MAX_ACTIVE_ZOMBIES:
		return
	if not _spawn_one_wave_zombie():
		pending_wave_spawn_timer = PENDING_WAVE_SPAWN_INTERVAL
		return
	pending_wave_spawns -= 1
	pending_wave_spawn_timer = PENDING_WAVE_SPAWN_INTERVAL if pending_wave_spawns > 0 else 0.0

func _spawn_one_wave_zombie() -> bool:
	if zombies.size() >= MAX_ACTIVE_ZOMBIES or spawn_districts.is_empty():
		return false
	var district: Rect2 = spawn_districts[randi_range(0, spawn_districts.size() - 1)]
	var spawn_point := Vector2.ZERO
	var found_open_spawn := false
	for attempt in range(16):
		spawn_point = Vector2(randf_range(district.position.x, district.end.x), randf_range(district.position.y, district.end.y))
		if _is_open_world_position(spawn_point, 18.0):
			found_open_spawn = true
			break
	if not found_open_spawn:
		return false
	var roll: float = randf()
	var kind: String = "shambler"
	var brute_chance: float = clampf(0.08 + float(wave) * 0.008, 0.08, 0.32)
	var spitter_chance: float = clampf(0.10 + float(wave) * 0.006, 0.10, 0.28)
	var runner_chance: float = clampf(0.16 + float(wave) * 0.006, 0.16, 0.34)
	if wave >= 2 and roll < brute_chance:
		kind = "brute"
	elif wave >= 2 and roll < brute_chance + spitter_chance:
		kind = "spitter"
	elif roll < brute_chance + spitter_chance + runner_chance:
		kind = "runner"
	var hp: float = 30.0
	if kind == "runner":
		hp = 25.0
	elif kind == "brute":
		hp = 180.0 + float(wave) * 15.0
	elif kind == "spitter":
		hp = 42.0 + float(wave) * 4.0
	zombies.append({"pos": spawn_point, "kind": kind, "hp": hp, "max_hp": hp, "wall_cooldown": 0.0})
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touch_points[touch.index] = touch.position
			if touch_points.size() == 1:
				var touch_world: Vector2 = _screen_to_world(touch.position)
				var can_start_placement: bool = not outpost_placement_active and ((game_state == "hq_placement" and touch.position.y < _safe_bottom_y(touch_target_size + 126.0)) or (game_state == "playing" and touch.position.y > safe_insets.y + 520.0 and touch.position.y < _safe_bottom_y(260.0) and command_tab == 1 and selected_deployment < BASE_DEPLOYMENTS.size() and str(BASE_DEPLOYMENTS[selected_deployment]["kind"]) == "outpost"))
				if can_start_placement:
					_begin_outpost_placement(touch_world, "hq" if game_state == "hq_placement" else "outpost")
				elif outpost_placement_active:
					if outpost_placement_rect.grow(maxf(24.0, touch_target_size * 0.5 / maxf(camera_zoom, 0.01))).has_point(touch_world):
						_begin_outpost_resize(touch_world)
					elif (game_state == "hq_placement" and touch.position.y >= _safe_bottom_y(touch_target_size + 126.0)) or (game_state == "playing" and touch.position.y >= _safe_bottom_y(260.0) and touch.position.y <= _safe_bottom_y(260.0 - touch_target_size)):
						outpost_placement_gesture_mode = ""
						outpost_placement_dragging = false
					else:
						outpost_placement_gesture_mode = "pan"
						outpost_placement_dragging = true
				else:
					outpost_placement_gesture_mode = ""
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
				if outpost_placement_active and outpost_placement_dragging:
					outpost_placement_dragging = false
					outpost_placement_gesture_mode = ""
				elif touch_points.size() == 1 and not multi_touch_gesture and not camera_dragging and camera_drag_distance < CAMERA_DRAG_THRESHOLD:
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
			if outpost_placement_active and outpost_placement_dragging and outpost_placement_gesture_mode == "resize":
				_update_outpost_placement_from_anchor(_screen_to_world(drag.position))
				return
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
				var mouse_world: Vector2 = _screen_to_world(mouse.position)
				var can_start_placement: bool = not outpost_placement_active and ((game_state == "hq_placement" and mouse.position.y < _safe_bottom_y(touch_target_size + 126.0)) or (game_state == "playing" and mouse.position.y > safe_insets.y + 520.0 and mouse.position.y < _safe_bottom_y(260.0) and command_tab == 1 and selected_deployment < BASE_DEPLOYMENTS.size() and str(BASE_DEPLOYMENTS[selected_deployment]["kind"]) == "outpost"))
				if can_start_placement:
					_begin_outpost_placement(mouse_world, "hq" if game_state == "hq_placement" else "outpost")
				elif outpost_placement_active:
					if outpost_placement_rect.grow(maxf(24.0, touch_target_size * 0.5 / maxf(camera_zoom, 0.01))).has_point(mouse_world):
						_begin_outpost_resize(mouse_world)
					elif (game_state == "hq_placement" and mouse.position.y >= _safe_bottom_y(touch_target_size + 126.0)) or (game_state == "playing" and mouse.position.y >= _safe_bottom_y(260.0) and mouse.position.y <= _safe_bottom_y(260.0 - touch_target_size)):
						outpost_placement_gesture_mode = ""
						outpost_placement_dragging = false
					else:
						outpost_placement_gesture_mode = "pan"
						outpost_placement_dragging = true
				camera_drag_origin = mouse.position
				camera_drag_distance = 0.0
				camera_dragging = false
			elif outpost_placement_active and outpost_placement_dragging:
				outpost_placement_dragging = false
				outpost_placement_gesture_mode = ""
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
		if outpost_placement_active and outpost_placement_dragging and outpost_placement_gesture_mode == "resize":
			_update_outpost_placement_from_anchor(_screen_to_world(motion.position))
		elif camera_dragging:
			camera_position -= motion.relative / camera_zoom
			_clamp_camera()
			queue_redraw()

func _handle_tap(pos: Vector2) -> void:
	if game_state == "title":
		var title_pos: Vector2 = pos - safe_area_rect.position
		var title_size: Vector2 = _safe_viewport_size()
		if title_pos.y >= title_size.y * 0.63 and _has_valid_save():
			_resume_operation()
		else:
			game_state = "sector_select"
		queue_redraw()
		return
	if game_state == "hq_placement":
		if outpost_placement_active and pos.y >= _safe_bottom_y(touch_target_size + 6.0) and pos.y <= viewport_size.y - safe_insets.w:
			if pos.x < safe_insets.x + (viewport_size.x - safe_insets.x - safe_insets.z) * 0.5:
				_confirm_outpost_placement()
			else:
				outpost_placement_active = false
				outpost_placement_dragging = false
			queue_redraw()
			return
		if pos.y >= _safe_bottom_y(touch_target_size + 126.0):
			return
		_begin_outpost_placement(_screen_to_world(pos), "hq")
		outpost_placement_dragging = false
		queue_redraw()
		return
	if game_state == "sector_select":
		var title_pos: Vector2 = pos - safe_area_rect.position
		var title_size: Vector2 = _safe_viewport_size()
		if title_pos.y >= title_size.y * 0.44 and title_pos.y < title_size.y * 0.80:
			var selected_sector := clampi(int((title_pos.y - title_size.y * 0.44) / (title_size.y * 0.12)), 0, 2)
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
	if outpost_placement_active and pos.y >= _safe_bottom_y(260.0) and pos.y <= _safe_bottom_y(260.0 - touch_target_size):
		if pos.x < safe_insets.x + (viewport_size.x - safe_insets.x - safe_insets.z) * 0.5:
			_confirm_outpost_placement()
		else:
			outpost_placement_active = false
			outpost_placement_dragging = false
		queue_redraw()
		return
	if _ai_button_rect().has_point(pos):
		auto_ops_enabled = not auto_ops_enabled
		message = "AUTO-OPS ENABLED" if auto_ops_enabled else "UNITS HOLD POSITION"
		message_timer = 1.5
		queue_redraw()
		return
	if _recruit_button_rect(0).has_point(pos):
		_recruit_unit("infantry")
		queue_redraw()
		return
	if _recruit_button_rect(1).has_point(pos):
		_recruit_unit("sniper")
		queue_redraw()
		return
	if _engineer_button_rect().has_point(pos):
		_recruit_unit("engineer")
		queue_redraw()
		return
	if _salvage_button_rect().has_point(pos):
		_salvage_nearest_vehicle()
		queue_redraw()
		return
	if manual_paused or lifecycle_paused:
		if pos.x >= viewport_size.x * 0.2 and pos.x <= viewport_size.x * 0.8 and pos.y >= viewport_size.y * 0.52 and pos.y <= viewport_size.y * 0.68:
			manual_paused = false
			lifecycle_paused = false
		queue_redraw()
		return
	var minimap_rect := Rect2(Vector2(viewport_size.x - safe_insets.z - MINIMAP_SIZE.x - HUD_EDGE_PADDING, safe_insets.y + HUD_EDGE_PADDING), MINIMAP_SIZE)
	if minimap_rect.has_point(pos):
		var local := (pos - minimap_rect.position) / minimap_rect.size
		camera_position = Vector2(local.x * WORLD_SIZE.x, local.y * WORLD_SIZE.y)
		_clamp_camera()
		queue_redraw()
		return
	var zoom_x: float = viewport_size.x - safe_insets.z - 112.0
	var zoom_top: float = safe_insets.y + 220.0
	var zoom_bottom_top: float = zoom_top + touch_target_size + 6.0
	if pos.x >= zoom_x and pos.x <= zoom_x + 94.0 and pos.y >= zoom_top and pos.y <= zoom_top + touch_target_size:
		_zoom_camera(1.18, viewport_size * 0.5)
		return
	if pos.x >= zoom_x and pos.x <= zoom_x + 94.0 and pos.y >= zoom_bottom_top and pos.y <= zoom_bottom_top + touch_target_size:
		_zoom_camera(0.85, viewport_size * 0.5)
		return
	var hud_left: float = safe_insets.x + HUD_EDGE_PADDING
	var hud_top: float = safe_insets.y + HUD_EDGE_PADDING
	if pos.x >= hud_left and pos.x <= hud_left + 172.0 and pos.y >= hud_top + 196.0 and pos.y <= hud_top + 196.0 + touch_target_size:
		time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()
		queue_redraw()
		return
	var sfx_top: float = hud_top + 196.0 + touch_target_size + 6.0
	if pos.x >= hud_left and pos.x <= hud_left + 172.0 and pos.y >= sfx_top and pos.y <= sfx_top + touch_target_size:
		sfx_enabled = not sfx_enabled
		if not sfx_enabled:
			audio_queue.clear()
			audio_effect = ""
		queue_redraw()
		return
	if Rect2(Vector2(safe_insets.x + DIAGNOSTIC_BUTTON.position.x, safe_insets.y + DIAGNOSTIC_BUTTON.position.y), Vector2(DIAGNOSTIC_BUTTON.size.x, touch_target_size)).has_point(pos):
		diagnostics_enabled = not diagnostics_enabled
		queue_redraw()
		return
	if not selected_structure_type.is_empty() and pos.y >= _structure_action_top() + 42.0 and pos.y <= _structure_action_top() + 42.0 + touch_target_size:
		if pos.x >= safe_insets.x + 24.0 and pos.x <= safe_insets.x + 190.0:
			_repair_selected_structure()
			return
		if pos.x >= safe_insets.x + 204.0 and pos.x <= safe_insets.x + 370.0:
			_upgrade_selected_structure()
			return
	var bar_top: float = _safe_bottom_y(_deployment_panel_height())
	var safe_left: float = safe_insets.x
	var safe_width: float = viewport_size.x - safe_insets.x - safe_insets.z
	if pos.y >= bar_top and pos.x >= safe_left and pos.x <= safe_left + safe_width:
		if pos.y <= bar_top + touch_target_size:
			command_tab = 1 - command_tab
			selected_deployment = 0
			queue_redraw()
			return
		var choices: Array = UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS
		var button_width: float = safe_width / float(choices.size())
		selected_deployment = clampi(int((pos.x - safe_left) / button_width), 0, choices.size() - 1)
		message = str(choices[selected_deployment]["name"]) + " SELECTED"
		message_timer = 1.2
		queue_redraw()
		return
	if pos.y < safe_insets.y + 270.0:
		return
	var world_pos := _screen_to_world(pos)
	if selected_vehicle_index >= 0 and selected_vehicle_index < vehicles.size() and bool(vehicles[selected_vehicle_index].get("active", false)):
		vehicles[selected_vehicle_index]["move_target"] = world_pos
		selected_vehicle_index = -1
		message = "VEHICLE DESTINATION SET"
		message_timer = 1.3
		return
	for vehicle_index in range(vehicles.size()):
		if world_pos.distance_to(vehicles[vehicle_index]["pos"]) <= 48.0 and bool(vehicles[vehicle_index].get("active", false)):
			selected_vehicle_index = vehicle_index
			selected_unit_index = -1
			message = "VEHICLE SELECTED — TAP DESTINATION"
			message_timer = 1.6
			return
	var tapped_building: int = _building_index_at(world_pos)
	if selected_unit_index >= 0 and selected_unit_index < units.size():
		if tapped_building >= 0:
			_garrison_unit(selected_unit_index, tapped_building)
			return
		var selected_is_garrisoned: bool = bool(units[selected_unit_index].get("garrisoned", false))
		if selected_is_garrisoned:
			_exit_unit_garrison(selected_unit_index, world_pos)
			if _is_valid_street_position(world_pos):
				units[selected_unit_index]["move_target"] = world_pos
			message = "UNIT EXITED GARRISON"
			message_timer = 1.5
			selected_unit_index = -1
			queue_redraw()
			return
		if _is_valid_street_position(world_pos):
			_exit_unit_garrison(selected_unit_index, world_pos)
			units[selected_unit_index]["move_target"] = world_pos
			units[selected_unit_index]["manual_order"] = true
			message = "SQUAD REPOSITIONED"
			message_timer = 1.2
			selected_unit_index = -1
			queue_redraw()
			return
	if tapped_building >= 0:
		for garrison_index in range(units.size()):
			if bool(units[garrison_index].get("garrisoned", false)) and int(units[garrison_index].get("garrison_building", -1)) == tapped_building:
				selected_unit_index = garrison_index
				message = "GARRISON UNIT SELECTED — TAP STREET TO EXIT"
				message_timer = 1.8
				queue_redraw()
				return
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
	if kind == "outpost":
		if outposts.size() >= OUTPOST_MAX_COUNT + 1:
			message = "FORWARD OUTPOST LIMIT REACHED (6)"
			message_timer = 1.5
			return
		_begin_outpost_placement(world_pos, "outpost")
		outpost_placement_dragging = false
		queue_redraw()
		return
	if kind == "gate":
		if _try_place_gate(world_pos):
			message = "PERIMETER GATE INSTALLED"
			message_timer = 1.5
		else:
			message = "GATE MUST SNAP TO AN OUTPOST WALL — $90"
			message_timer = 1.5
		queue_redraw()
		return
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
		"infantry", "sniper", "engineer":
			_recruit_unit(kind)
			return
		"turret":
			world_pos = _snap_turret_to_outpost(world_pos)
			turrets.append({"pos": world_pos, "hp": 250.0, "max_hp": 250.0, "cooldown": 0.1, "level": 1, "range": TURRET_RANGE, "vision_radius": TURRET_RANGE, "damage": 22.0, "fire_interval": 0.18})
		"wall":
			barricades.append({"pos": world_pos, "hp": 400.0, "max_hp": 400.0})
		"gate":
			pass
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
		draw_set_transform(safe_area_rect.position, 0.0, Vector2.ONE)
		_draw_title_screen()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if game_state == "hq_placement":
		var hq_hint := "DRAG TO SIZE THE STATE HQ PERIMETER" if outpost_placement_active else "DRAG ON AN OPEN STREET TO DESIGN HQ"
		_draw_world_scene()
		if outpost_placement_active:
			var hq_origin: Vector2 = viewport_size * 0.5 - camera_position * camera_zoom
			draw_set_transform(hq_origin, 0.0, Vector2(camera_zoom, camera_zoom))
			_draw_placement_preview()
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var hq_panel_top: float = _safe_bottom_y(touch_target_size + 126.0)
		draw_rect(Rect2(safe_insets.x, hq_panel_top, viewport_size.x - safe_insets.x - safe_insets.z, viewport_size.y - hq_panel_top), Color("#071713", 0.96))
		_draw_text("SELECT HQ LOCATION", Vector2(safe_insets.x + 24.0, hq_panel_top + 24.0), 20, Color("#e8fff0"))
		_draw_text(hq_hint, Vector2(safe_insets.x + 24.0, hq_panel_top + 48.0), 13, Color("#a9c8b7"))
		if outpost_placement_active:
			_draw_text("%.0f x %.0f  COST $%d  SHELTER %d  %s" % [outpost_placement_rect.size.x, outpost_placement_rect.size.y, _outpost_build_cost(outpost_placement_rect.size), maxi(12, roundi(outpost_placement_rect.size.x * outpost_placement_rect.size.y / 18000.0)), "VALID" if outpost_placement_valid else "BLOCKED"], Vector2(safe_insets.x + 24.0, hq_panel_top + 76.0), 12, Color("#e8fff0"))
			_draw_outpost_placement_hud(_safe_bottom_y(touch_target_size + 6.0))
		return
	var shake_offset := Vector2.ZERO
	if shake_timer > 0.0:
		shake_offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	var world_transform_origin := viewport_size * 0.5 - camera_position * camera_zoom + shake_offset
	draw_set_transform(world_transform_origin, 0.0, Vector2(camera_zoom, camera_zoom))
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#07110f"))
	_draw_grid()
	_draw_roads()
	_draw_evac_zone()
	_draw_buildings()
	for district_index in range(district_regions.size()):
		var district_rect: Rect2 = district_regions[district_index]
		if _camera_view_rect().intersects(district_rect):
			var district_labels: Array[String] = ["URBAN CORE", "SUBURBS", "INDUSTRIAL ZONE", "MEDICAL DISTRICT", "RURAL HIGHWAYS", "LOGISTICS HUB", "CIVIC CENTER", "OUTER CORRIDOR"]
			var district_label: String = district_labels[district_index] if district_index < district_labels.size() else "REGIONAL DISTRICT"
			_draw_text(district_label, Vector2(70.0, district_rect.position.y + 62.0), 24, Color(0.45, 0.75, 0.62, 0.6))
	_draw_fog()
	_draw_entities()
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
	if outpost_placement_active:
		_draw_outpost_placement_hud(_safe_bottom_y(260.0))
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

func _draw_roads() -> void:
	var visible_rect: Rect2 = _camera_view_rect().grow(100.0)
	for segment in highway_segments:
		var road_from: Vector2 = segment["from"]
		var road_to: Vector2 = segment["to"]
		var width: float = float(segment.get("width", 64.0))
		var bounds := Rect2(Vector2(minf(road_from.x, road_to.x), minf(road_from.y, road_to.y)), Vector2(absf(road_to.x - road_from.x), absf(road_to.y - road_from.y))).grow(width * 0.5)
		if not visible_rect.intersects(bounds):
			continue
		draw_line(road_from, road_to, Color("#182522"), width + 10.0)
		draw_line(road_from, road_to, Color("#303a37"), width)
		if absf(road_to.x - road_from.x) > absf(road_to.y - road_from.y):
			var line_y1: float = road_from.y - 7.0
			var line_y2: float = road_from.y + 7.0
			draw_line(Vector2(road_from.x, line_y1), Vector2(road_to.x, line_y1), Color("#d8bd63"), 2.0)
			draw_line(Vector2(road_from.x, line_y2), Vector2(road_to.x, line_y2), Color("#d8bd63"), 2.0)
		else:
			var line_x1: float = road_from.x - 7.0
			var line_x2: float = road_from.x + 7.0
			draw_line(Vector2(line_x1, road_from.y), Vector2(line_x1, road_to.y), Color("#d8bd63"), 2.0)
			draw_line(Vector2(line_x2, road_from.y), Vector2(line_x2, road_to.y), Color("#d8bd63"), 2.0)
	for segment in secondary_road_segments:
		var road_from: Vector2 = segment["from"]
		var road_to: Vector2 = segment["to"]
		var width: float = float(segment.get("width", 24.0))
		var bounds := Rect2(Vector2(minf(road_from.x, road_to.x), minf(road_from.y, road_to.y)), Vector2(absf(road_to.x - road_from.x), absf(road_to.y - road_from.y))).grow(width * 0.5)
		if visible_rect.intersects(bounds):
			draw_line(road_from, road_to, Color("#222e2a"), width + 5.0)
			draw_line(road_from, road_to, Color("#3a4640"), width)

func _draw_dashed_circle(center: Vector2, radius: float, tint: Color, segments: int) -> void:
	for segment in range(0, segments, 2):
		var start_angle := TAU * float(segment) / float(segments)
		var end_angle := TAU * float(segment + 1) / float(segments)
		var start_point := center + Vector2(cos(start_angle), sin(start_angle)) * radius
		var end_point := center + Vector2(cos(end_angle), sin(end_angle)) * radius
		draw_line(start_point, end_point, tint, 2.0)

func _draw_evac_zone() -> void:
	var visible_rect: Rect2 = _camera_view_rect().grow(400.0)
	for zone in evacuation_zones:
		if not visible_rect.has_point(zone):
			continue
		draw_circle(zone, EVAC_RADIUS, Color(0.05, 0.55, 0.25, 0.18))
		draw_arc(zone, EVAC_RADIUS, 0.0, TAU, 48, Color("#48e58b"), 3.0)
		draw_arc(zone, EVAC_RADIUS - 12.0, 0.0, TAU, 48, Color(0.28, 0.85, 0.55, 0.35), 1.0)
		var zone_label: String = "PRIMARY HQ" if zone.distance_squared_to(primary_hq_position) < 1.0 else "FORWARD SAFE ZONE"
		_draw_text(zone_label, zone + Vector2(-45.0, 5.0), 13, Color("#8cf5b5"))
	for outpost in outposts:
		if not visible_rect.has_point(outpost["pos"]):
			continue
		draw_circle(outpost["pos"], float(outpost["safe_radius"]), Color(0.10, 0.65, 0.32, 0.035))
		draw_arc(outpost["pos"], float(outpost["vision_radius"]), 0.0, TAU, 48, Color(0.25, 0.85, 0.48, 0.16), 1.0)
		_draw_dashed_circle(outpost["pos"], OUTPOST_COMMAND_RADIUS, Color(0.35, 0.88, 0.55, 0.34), 48)

func _draw_title_screen() -> void:
	var title_size: Vector2 = _safe_viewport_size()
	draw_rect(Rect2(title_size.x * 0.06, title_size.y * 0.08, title_size.x * 0.88, title_size.y * 0.84), Color(0.02, 0.07, 0.055, 0.96))
	draw_rect(Rect2(title_size.x * 0.06, title_size.y * 0.08, title_size.x * 0.88, title_size.y * 0.84), Color("#4d7964"), false, 2.0)
	_draw_text("CONTAINMENT", Vector2(title_size.x * 0.14, title_size.y * 0.26), 42, Color("#e4f6e9"))
	_draw_text("PROTOCOL", Vector2(title_size.x * 0.29, title_size.y * 0.30), 42, Color("#79e7a4"))
	_draw_text("TACTICAL EVACUATION COMMAND", Vector2(title_size.x * 0.17, title_size.y * 0.35), 18, Color("#a9c8b7"))
	if game_state == "title":
		draw_rect(Rect2(title_size.x * 0.19, title_size.y * 0.51, title_size.x * 0.62, 100.0), Color("#1d4935"))
		draw_rect(Rect2(title_size.x * 0.19, title_size.y * 0.51, title_size.x * 0.62, 100.0), Color("#75e6a0"), false, 3.0)
		_draw_text("TAP TO SELECT SECTOR", Vector2(title_size.x * 0.27, title_size.y * 0.56), 22, Color("#f0fff5"))
		if _has_valid_save():
			draw_rect(Rect2(title_size.x * 0.14, title_size.y * 0.66, title_size.x * 0.72, 78.0), Color("#294c3c"))
			draw_rect(Rect2(title_size.x * 0.14, title_size.y * 0.66, title_size.x * 0.72, 78.0), Color("#e4c66d"), false, 2.0)
			_draw_text("RESUME SAVED OPERATION", Vector2(title_size.x * 0.19, title_size.y * 0.71), 18, Color("#fff4c7"))
	else:
		_draw_text("SELECT OPERATIONAL SECTOR", Vector2(title_size.x * 0.19, title_size.y * 0.42), 22, Color("#d8eee0"))
		var names: Array[String] = ["01  SUBURBAN OUTSKIRTS", "02  MEDICAL & URBAN CORE", "03  INDUSTRIAL HIGHWAY"]
		var details: Array[String] = ["BALANCED CASH / CIVILIANS  •  30 WAVES", "HOSPITALS + HIGHRISES / HIGH PRESSURE", "WAREHOUSE + ARMORY CHOKEPOINTS"]
		for index in range(3):
			var y := title_size.y * 0.44 + float(index) * title_size.y * 0.12
			draw_rect(Rect2(title_size.x * 0.10, y, title_size.x * 0.80, 96.0), Color("#18352a"))
			draw_rect(Rect2(title_size.x * 0.10, y, title_size.x * 0.80, 96.0), Color("#69b98a"), false, 2.0)
			_draw_text(names[index], Vector2(title_size.x * 0.14, y + 38.0), 20, Color("#e8fff0"))
			_draw_text(details[index], Vector2(title_size.x * 0.14, y + 70.0), 13, Color("#a9c8b7"))
	_draw_text("ANDROID TACTICAL RESPONSE UNIT", Vector2(title_size.x * 0.21, title_size.y * 0.86), 15, Color("#648675"))

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
		var wall_rect: Rect2 = wall.get("rect", Rect2(wall_pos - Vector2(15.0, 15.0), Vector2(30.0, 30.0)))
		if not visible_rect.intersects(wall_rect):
			continue
		var wall_hp: float = float(wall["hp"]) / float(wall["max_hp"])
		draw_rect(wall_rect, Color("#9b8b70", 0.85))
		draw_rect(wall_rect, Color("#cbb99a", 0.35 + 0.65 * wall_hp), false, 2.5)
	for gate in gates:
		var gate_rect: Rect2 = gate["rect"]
		if visible_rect.intersects(gate_rect):
			draw_rect(gate_rect, Color("#5ad88b") if bool(gate.get("open", false)) else Color("#d8ad62"))
			draw_rect(gate_rect, Color("#eaf7db"), false, 2.0)
	for crate in supply_crates:
		if visible_rect.has_point(crate["pos"]):
			draw_circle(crate["pos"], 18.0, Color(0.9, 0.72, 0.24, 0.2))
			draw_rect(Rect2(crate["pos"] - Vector2(11.0, 11.0), Vector2(22.0, 22.0)), Color("#d8b65b"))
			draw_line(crate["pos"] + Vector2(-7.0, 0.0), crate["pos"] + Vector2(7.0, 0.0), Color("#fff0b0"), 2.0)
	for outpost in outposts:
		var outpost_rect: Rect2 = outpost.get("rect", Rect2(outpost["pos"] - Vector2(110.0, 110.0), Vector2(220.0, 220.0)))
		if visible_rect.intersects(outpost_rect):
			draw_rect(outpost_rect, Color("#43d77a", 0.08))
			draw_rect(outpost_rect, Color("#43d77a"), false, 3.0)
			draw_rect(Rect2(outpost["pos"] - Vector2(15.0, 15.0), Vector2(30.0, 30.0)), Color("#43d77a"))
	for turret in turrets:
		if visible_rect.has_point(turret["pos"]):
			draw_rect(Rect2(turret["pos"] - Vector2(11.0, 11.0), Vector2(22.0, 22.0)), Color("#e2bb63"))
	for building_index in range(buildings.size()):
		var state: Dictionary = building_archetypes[building_index]
		if bool(state.get("destroyed", false)):
			continue
		if not visible_rect.intersects(buildings[building_index]):
			continue
		var count: int = 0
		for garrison_unit in units:
			if bool(garrison_unit.get("garrisoned", false)) and int(garrison_unit.get("garrison_building", -1)) == building_index:
				count += 1
		if count > 0 and visible_rect.intersects(buildings[building_index]):
			var roof: Rect2 = buildings[building_index]
			draw_rect(roof.grow(-7.0), Color("#4de6a5"), false, 5.0)
			var roof_range: float = 390.0 if _building_type_at(building_index) == "HIGHRISE" else 276.75
			draw_arc(roof.get_center(), roof_range, 0.0, TAU, 48, Color("#4de6a5", 0.18), 2.0)
			var first_x: float = roof.get_center().x - float(count - 1) * 10.0
			for pip in range(count):
				draw_circle(Vector2(first_x + float(pip) * 20.0, roof.position.y + 30.0), 6.0, Color("#63f4cb"))
	for vehicle_index in range(vehicles.size()):
		var vehicle: Dictionary = vehicles[vehicle_index]
		var vehicle_pos: Vector2 = vehicle["pos"]
		if not visible_rect.has_point(vehicle_pos):
			continue
		var aircraft: bool = str(vehicle.get("kind", "")) == "helicopter"
		var vehicle_color := Color("#73c9d6") if aircraft else Color("#b6a36a")
		if aircraft:
			draw_line(vehicle_pos + Vector2(-28.0, -24.0), vehicle_pos + Vector2(28.0, 24.0), vehicle_color, 4.0)
			draw_line(vehicle_pos + Vector2(-28.0, 24.0), vehicle_pos + Vector2(28.0, -24.0), vehicle_color, 4.0)
			draw_line(vehicle_pos + Vector2(-42.0, 0.0), vehicle_pos + Vector2(42.0, 0.0), Color("#d6f6f7"), 3.0)
			draw_line(vehicle_pos + Vector2(-48.0, -30.0), vehicle_pos + Vector2(48.0, -30.0), Color("#d6f6f7"), 3.0)
			draw_line(vehicle_pos + Vector2(-48.0, -34.0), vehicle_pos + Vector2(48.0, -34.0), Color("#d6f6f7"), 2.0)
		else:
			draw_rect(Rect2(vehicle_pos - Vector2(25.0, 14.0), Vector2(50.0, 28.0)), vehicle_color)
			draw_rect(Rect2(vehicle_pos - Vector2(12.0, 9.0), Vector2(24.0, 18.0)), Color("#26352e"))
			if day_phase == "NIGHT":
				draw_line(vehicle_pos + Vector2(25.0, -8.0), vehicle_pos + Vector2(72.0, -24.0), Color(1.0, 0.92, 0.58, 0.28), 8.0)
				draw_line(vehicle_pos + Vector2(25.0, 8.0), vehicle_pos + Vector2(72.0, 24.0), Color(1.0, 0.92, 0.58, 0.28), 8.0)
		var health_ratio: float = clampf(float(vehicle.get("hp", 0.0)) / maxf(float(vehicle.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
		draw_rect(Rect2(vehicle_pos + Vector2(-24.0, -25.0), Vector2(48.0 * health_ratio, 4.0)), Color("#67e89b"))
		if not bool(vehicle.get("active", false)):
			var salvage_remaining: float = float(vehicle.get("salvage_timer", 4.0))
			_draw_text("SALVAGE $%d  %.1fS" % [int(vehicle.get("salvage_cost", 0)), salvage_remaining], vehicle_pos + Vector2(-48.0, -34.0), 10, Color("#f4d77b"))
		else:
			_draw_text("ONBOARD %d/6" % int(vehicle.get("onboard", 0)), vehicle_pos + Vector2(-34.0, 38.0), 10, Color("#b8f1df"))
	for unit_index in range(units.size()):
		var unit: Dictionary = units[unit_index]
		var p: Vector2 = unit["pos"]
		if bool(unit.get("garrisoned", false)) or not visible_rect.has_point(p):
			continue
		var unit_kind: String = str(unit["kind"])
		var sniper: bool = unit_kind == "sniper"
		var engineer: bool = unit_kind == "engineer"
		var militia: bool = unit_kind == "militia"
		var tint := Color("#e0b66c") if engineer else (Color("#c6d46b") if militia else (Color("#6bdc9a") if not sniper else Color("#8ab6ff")))
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), tint)
		if militia:
			_draw_text("M", p + Vector2(-4.0, 4.0), 11, Color("#1b2410"))
		elif engineer:
			_draw_text("E", p + Vector2(-4.0, 4.0), 11, Color("#1b2410"))
		var task_label: String = str(unit.get("ai_task", ""))
		if not task_label.is_empty():
			_draw_text(task_label, p + Vector2(-25.0, -15.0), 9, Color("#b5f3d2"))
		draw_arc(p, (390.0 if sniper else (MILITIA_RANGE if militia else 205.0)) * _night_vision_multiplier(), 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.10), 1.0)
		if unit_index == selected_unit_index:
			draw_arc(p, 24.0, 0.0, TAU, 32, Color("#fff28a"), 3.0)
	for tracer in bullet_tracers:
		if not visible_rect.has_point(tracer["from"]) and not visible_rect.has_point(tracer["to"]):
			continue
		var alpha: float = clampf(float(tracer["life"]) / float(tracer["max_life"]), 0.0, 1.0)
		draw_line(tracer["from"], tracer["to"], Color(1.0, 0.88, 0.48, alpha), 2.0)
	for callout_index in range(world_callouts.size() - 1, -1, -1):
		var callout: Dictionary = world_callouts[callout_index]
		if visible_rect.has_point(callout["pos"]):
			_draw_text(str(callout["text"]), callout["pos"] + Vector2(-24.0, -38.0), 14, Color("#ffe28a"))
	for flash in muzzle_flashes:
		if not visible_rect.has_point(flash["pos"]):
			continue
		var alpha: float = clampf(float(flash["life"]) / float(flash["max_life"]), 0.0, 1.0)
		draw_circle(flash["pos"], 8.0 * alpha, Color(1.0, 0.78, 0.35, alpha))

func _draw_minimap() -> void:
	var minimap_rect := Rect2(Vector2(viewport_size.x - safe_insets.z - MINIMAP_SIZE.x - HUD_EDGE_PADDING, safe_insets.y + HUD_EDGE_PADDING), MINIMAP_SIZE)
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
	var zoom_x: float = viewport_size.x - safe_insets.z - 112.0
	var zoom_top: float = safe_insets.y + 220.0
	var zoom_bottom_top: float = zoom_top + touch_target_size + 6.0
	draw_rect(Rect2(Vector2(zoom_x, zoom_top), Vector2(94.0, touch_target_size)), Color("#183329"))
	draw_rect(Rect2(Vector2(zoom_x, zoom_top), Vector2(94.0, touch_target_size)), Color("#6ccf91"), false, 2.0)
	_draw_text("ZOOM +", Vector2(zoom_x + 11.0, zoom_top + touch_target_size * 0.62), 14, Color("#e5f8eb"))
	draw_rect(Rect2(Vector2(zoom_x, zoom_bottom_top), Vector2(94.0, touch_target_size)), Color("#183329"))
	draw_rect(Rect2(Vector2(zoom_x, zoom_bottom_top), Vector2(94.0, touch_target_size)), Color("#6ccf91"), false, 2.0)
	_draw_text("ZOOM -", Vector2(zoom_x + 11.0, zoom_bottom_top + touch_target_size * 0.62), 14, Color("#e5f8eb"))

func _draw_hud() -> void:
	var hud_left: float = safe_insets.x + HUD_EDGE_PADDING
	var hud_top: float = safe_insets.y + HUD_EDGE_PADDING
	draw_rect(Rect2(hud_left, hud_top, 390.0, 160.0), Color("#0b1b17", 0.94))
	_draw_text("CONTAINMENT PROTOCOL", Vector2(hud_left + 16.0, hud_top + 34.0), 22, Color("#e2f4e9"))
	_draw_text("FUNDS  $%d" % funds, Vector2(hud_left + 16.0, hud_top + 70.0), 21, Color("#f4d77b"))
	_draw_text("SECTOR %02d  WAVE %d/%d" % [sector_index + 1, wave, sector_wave_limit], Vector2(hud_left + 16.0, hud_top + 104.0), 15, Color("#ffad62"))
	_draw_text("SAVED %d  LOST %d  HORDE %d/%d" % [saved_count, lost_count, zombies.size(), MAX_ACTIVE_ZOMBIES], Vector2(hud_left + 16.0, hud_top + 124.0), 13, Color("#9cbcaf"))
	_draw_text("%s  |  %s" % [day_phase, "ENDLESS" if endless_containment else "CAMPAIGN"], Vector2(hud_left + 16.0, hud_top + 144.0), 12, Color("#a9c8b7"))
	if message_timer > 0.0:
		_draw_text(message, Vector2(hud_left + 16.0, hud_top + 164.0), 14, Color("#ffbd76"))
	draw_rect(Rect2(hud_left, hud_top + 196.0, 172.0, touch_target_size), Color("#183329"))
	draw_rect(Rect2(hud_left, hud_top + 196.0, 172.0, touch_target_size), Color("#6ccf91"), false, 2.0)
	_draw_text("TIME  " + TIME_LABELS[time_scale_index], Vector2(hud_left + 15.0, hud_top + 196.0 + touch_target_size * 0.62), 17, Color("#e5f8eb"))
	var sfx_top: float = hud_top + 196.0 + touch_target_size + 6.0
	draw_rect(Rect2(hud_left, sfx_top, 172.0, touch_target_size), Color("#183329"))
	draw_rect(Rect2(hud_left, sfx_top, 172.0, touch_target_size), Color("#6ccf91") if sfx_enabled else Color("#8b6262"), false, 2.0)
	_draw_text("[SFX: ON]" if sfx_enabled else "[SFX: OFF]", Vector2(hud_left + 15.0, sfx_top + touch_target_size * 0.62), 16, Color("#e5f8eb"))
	var ai_rect := _ai_button_rect()
	draw_rect(ai_rect, Color("#183329"))
	draw_rect(ai_rect, Color("#6ccf91") if auto_ops_enabled else Color("#8b6262"), false, 2.0)
	_draw_text("[AI: %s]" % ("AUTO-OPS" if auto_ops_enabled else "HOLD POSITION"), ai_rect.position + Vector2(8.0, touch_target_size * 0.62), 12, Color("#e5f8eb"))
	var inf_rect := _recruit_button_rect(0)
	var sniper_rect := _recruit_button_rect(1)
	for recruit_rect in [inf_rect, sniper_rect]:
		draw_rect(recruit_rect, Color("#183329"))
		draw_rect(recruit_rect, Color("#6ccf91"), false, 2.0)
	_draw_text("[RECRUIT INF]", inf_rect.position + Vector2(7.0, touch_target_size * 0.62), 12, Color("#e5f8eb"))
	_draw_text("[RECRUIT SNIPER]", sniper_rect.position + Vector2(7.0, touch_target_size * 0.62), 11, Color("#e5f8eb"))
	var engineer_rect := _engineer_button_rect()
	draw_rect(engineer_rect, Color("#183329"))
	draw_rect(engineer_rect, Color("#6ccf91"), false, 2.0)
	_draw_text("[RECRUIT ENG]", engineer_rect.position + Vector2(7.0, touch_target_size * 0.62), 12, Color("#e5f8eb"))
	var salvage_rect := _salvage_button_rect()
	draw_rect(salvage_rect, Color("#3a3420"))
	draw_rect(salvage_rect, Color("#e4c66d"), false, 2.0)
	_draw_text("[SALVAGE]", salvage_rect.position + Vector2(10.0, touch_target_size * 0.62), 13, Color("#fff4c7"))
	var diagnostic_rect := Rect2(Vector2(safe_insets.x + DIAGNOSTIC_BUTTON.position.x, safe_insets.y + DIAGNOSTIC_BUTTON.position.y), Vector2(DIAGNOSTIC_BUTTON.size.x, touch_target_size))
	draw_rect(diagnostic_rect, Color("#183329"))
	draw_rect(diagnostic_rect, Color("#6ccf91") if diagnostics_enabled else Color("#49645a"), false, 2.0)
	_draw_text("DIAG", diagnostic_rect.position + Vector2(20.0, 32.0), 16, Color("#e5f8eb"))
	if diagnostics_enabled:
		var entity_count := civilians.size() + zombies.size() + units.size() + barricades.size() + outposts.size() + turrets.size() + flares.size()
		draw_rect(Rect2(safe_insets.x + 210.0, safe_insets.y + 274.0, 210.0, 52.0), Color("#0b1b17", 0.94))
		_draw_text("FPS %d | ENT %d" % [fps_sample_value, entity_count], Vector2(safe_insets.x + 220.0, safe_insets.y + 306.0), 14, Color("#a9c8b7"))

func _draw_outpost_placement_hud(top: float) -> void:
	var confirm_color: Color = Color("#245a3c") if outpost_placement_valid else Color("#5a292b")
	var safe_left: float = safe_insets.x + HUD_EDGE_PADDING
	var safe_width: float = viewport_size.x - safe_insets.x - safe_insets.z - HUD_EDGE_PADDING * 2.0
	var half_width: float = safe_width * 0.5
	draw_rect(Rect2(safe_left, top, half_width - 6.0, touch_target_size), confirm_color)
	draw_rect(Rect2(safe_left, top, half_width - 6.0, touch_target_size), Color("#72d69a") if outpost_placement_valid else Color("#ff6868"), false, 2.0)
	_draw_text("[CONFIRM BUILD ($%d)]" % _outpost_build_cost(outpost_placement_rect.size), Vector2(safe_left + 10.0, top + touch_target_size * 0.62), 14, Color("#f0fff5"))
	var cancel_left: float = safe_left + half_width + 6.0
	draw_rect(Rect2(cancel_left, top, half_width - 6.0, touch_target_size), Color("#472a2a"))
	draw_rect(Rect2(cancel_left, top, half_width - 6.0, touch_target_size), Color("#d77b7b"), false, 2.0)
	_draw_text("[CANCEL]", Vector2(cancel_left + 36.0, top + touch_target_size * 0.62), 16, Color("#fff0f0"))

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
	var action_top: float = _structure_action_top()
	var action_panel_height: float = touch_target_size + 52.0
	draw_rect(Rect2(safe_insets.x + 18.0, action_top, 380.0, action_panel_height), Color("#0b1b17", 0.96))
	_draw_text("%s  HP %d/%d" % [structure_label, roundi(structure_hp), roundi(structure_max_hp)], Vector2(safe_insets.x + 30.0, action_top + 24.0), 14, Color("#dcefe4"))
	draw_rect(Rect2(safe_insets.x + 24.0, action_top + 42.0, 166.0, touch_target_size), Color("#254538"))
	draw_rect(Rect2(safe_insets.x + 24.0, action_top + 42.0, 166.0, touch_target_size), Color("#72d69a"), false, 2.0)
	_draw_text("REPAIR $40", Vector2(safe_insets.x + 40.0, action_top + 42.0 + touch_target_size * 0.62), 16, Color("#f0fff5"))
	if can_upgrade:
		var level := 1
		if selected_structure_type == "outpost":
			level = int(outposts[selected_structure_index].get("level", 1))
		else:
			level = int(turrets[selected_structure_index].get("level", 1))
		if level < 2:
			draw_rect(Rect2(safe_insets.x + 204.0, action_top + 42.0, 166.0, touch_target_size), Color("#3a3420"))
			draw_rect(Rect2(safe_insets.x + 204.0, action_top + 42.0, 166.0, touch_target_size), Color("#e4c66d"), false, 2.0)
			_draw_text("UPGRADE $150", Vector2(safe_insets.x + 213.0, action_top + 42.0 + touch_target_size * 0.62), 15, Color("#fff4c7"))

func _draw_deployment_bar() -> void:
	var panel_height: float = _deployment_panel_height()
	var top: float = _safe_bottom_y(panel_height)
	var safe_left: float = safe_insets.x
	var safe_width: float = viewport_size.x - safe_insets.x - safe_insets.z
	draw_rect(Rect2(safe_left, top, safe_width, panel_height), Color("#0b1715"))
	draw_line(Vector2(safe_left, top), Vector2(safe_left + safe_width, top), Color("#45665a"), 2.0)
	var half_width: float = safe_width * 0.5
	draw_rect(Rect2(safe_left, top, half_width, touch_target_size), Color("#254538") if command_tab == 0 else Color("#12251f"))
	draw_rect(Rect2(safe_left + half_width, top, half_width, touch_target_size), Color("#254538") if command_tab == 1 else Color("#12251f"))
	_draw_text("UNITS & STRIKES", Vector2(safe_left + 28.0, top + touch_target_size * 0.62), 16, Color("#e8fff0"))
	_draw_text("BUILD BASE", Vector2(safe_left + half_width + 42.0, top + touch_target_size * 0.62), 16, Color("#e8fff0"))
	var choices: Array = UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS
	var button_width: float = safe_width / float(choices.size())
	var cards_top: float = top + touch_target_size + 6.0
	var card_height: float = panel_height - touch_target_size - 6.0
	for i in range(choices.size()):
		var x: float = safe_left + float(i) * button_width
		var selected := i == selected_deployment
		draw_rect(Rect2(x + 3.0, cards_top, button_width - 6.0, card_height), Color("#254538") if selected else Color("#12251f"))
		draw_rect(Rect2(x + 3.0, cards_top, button_width - 6.0, card_height), Color("#72d69a") if selected else Color("#29443a"), false, 2.0)
		var deployment: Dictionary = choices[i]
		_draw_text(str(deployment["name"]), Vector2(x + 8.0, cards_top + card_height * 0.27), 13, Color("#e8fff0") if selected else Color("#b2c7bc"))
		var detail := str(deployment["detail"])
		if str(deployment["kind"]) == "outpost":
			detail = "$%d" % _deployment_cost("outpost")
		_draw_text(detail, Vector2(x + 8.0, cards_top + card_height * 0.52), 12, Color("#f0cc77"))
		_draw_text("TAP MAP", Vector2(x + 8.0, cards_top + card_height * 0.78), 10, Color("#8da99a"))

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
			outpost["capacity"] = maxi(20, int(outpost.get("capacity", 12)))
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
	if outpost_placement_active:
		var footprint_color: Color = Color("#55ef91") if outpost_placement_valid else Color("#ff5d62")
		draw_rect(outpost_placement_rect, Color(footprint_color.r, footprint_color.g, footprint_color.b, 0.14))
		draw_rect(outpost_placement_rect, footprint_color, false, 5.0)
		var handle_radius: float = touch_target_size * 0.5 / maxf(camera_zoom, 0.01)
		var handle_points: Array[Vector2] = [outpost_placement_rect.position, Vector2(outpost_placement_rect.end.x, outpost_placement_rect.position.y), outpost_placement_rect.end, Vector2(outpost_placement_rect.position.x, outpost_placement_rect.end.y)]
		for handle_point in handle_points:
			draw_circle(handle_point, handle_radius, Color(footprint_color.r, footprint_color.g, footprint_color.b, 0.18))
			draw_arc(handle_point, handle_radius, 0.0, TAU, 24, footprint_color, 3.0)
		return
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
	if kind == "outpost" and outposts.size() >= OUTPOST_MAX_COUNT + 1:
		valid = false
	if kind == "gate":
		valid = funds >= GATE_COST
		var tint := Color(0.2, 1.0, 0.48, 0.18) if valid else Color(1.0, 0.18, 0.2, 0.20)
	var line_tint := Color("#56f58f") if valid else Color("#ff555d")
	draw_circle(preview_position, radius, tint)
	draw_arc(preview_position, radius, 0.0, TAU, 56, line_tint, 2.5)
	draw_circle(preview_position, 5.0, Color(line_tint.r, line_tint.g, line_tint.b, 0.8))

func _deployment_cost(kind: String) -> int:
	if kind == "outpost":
		return _outpost_build_cost(outpost_placement_rect.size)
	return int((UNIT_DEPLOYMENTS if command_tab == 0 else BASE_DEPLOYMENTS)[selected_deployment]["cost"])

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
			if zombies.size() < MAX_ACTIVE_ZOMBIES:
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
	_refresh_safe_area()
	_clamp_camera()
	queue_redraw()

func _refresh_safe_area() -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var display_safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if DisplayServer.get_name() == "headless" or screen_size.x <= 0 or screen_size.y <= 0 or display_safe_area.size.x <= 0 or display_safe_area.size.y <= 0:
		safe_insets = Vector4.ZERO
		safe_area_rect = Rect2(Vector2.ZERO, viewport_size)
		return
	var safe_left_px: int = clampi(display_safe_area.position.x, 0, screen_size.x)
	var safe_top_px: int = clampi(display_safe_area.position.y, 0, screen_size.y)
	var safe_right_px: int = clampi(screen_size.x - display_safe_area.end.x, 0, screen_size.x)
	var safe_bottom_px: int = clampi(screen_size.y - display_safe_area.end.y, 0, screen_size.y)
	var viewport_scale: Vector2 = viewport_size / Vector2(screen_size)
	var screen_dpi: int = maxi(DisplayServer.screen_get_dpi(), 160)
	touch_target_size = maxf(MIN_TOUCH_TARGET, 48.0 * float(screen_dpi) / 160.0 * maxf(viewport_scale.x, viewport_scale.y))
	safe_insets = Vector4(float(safe_left_px) * viewport_scale.x, float(safe_top_px) * viewport_scale.y, float(safe_right_px) * viewport_scale.x, float(safe_bottom_px) * viewport_scale.y)
	var max_horizontal_inset: float = viewport_size.x * 0.20
	var max_vertical_inset: float = viewport_size.y * 0.20
	safe_insets.x = minf(safe_insets.x, max_horizontal_inset)
	safe_insets.y = minf(safe_insets.y, max_vertical_inset)
	safe_insets.z = minf(safe_insets.z, max_horizontal_inset)
	safe_insets.w = minf(safe_insets.w, max_vertical_inset)
	safe_area_rect = Rect2(Vector2(safe_insets.x, safe_insets.y), Vector2(maxf(1.0, viewport_size.x - safe_insets.x - safe_insets.z), maxf(1.0, viewport_size.y - safe_insets.y - safe_insets.w)))

func _safe_viewport_size() -> Vector2:
	return safe_area_rect.size

func _safe_bottom_y(panel_height: float) -> float:
	return maxf(safe_insets.y, viewport_size.y - safe_insets.w - panel_height)

func _deployment_panel_height() -> float:
	return maxf(200.0, touch_target_size + 146.0)

func _structure_action_top() -> float:
	return safe_insets.y + maxf(STRUCTURE_ACTION_TOP, HUD_EDGE_PADDING + 196.0 + 3.0 * (touch_target_size + 6.0))

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
			var outpost_rect: Rect2 = outpost.get("rect", Rect2(outpost["pos"] - Vector2(34.0, 34.0), Vector2(68.0, 68.0)))
			if not outpost_rect.grow(-20.0).has_point(zombie_position):
				continue
			var damage: float = 42.0 if str(zombie.get("kind", "shambler")) == "brute" else 18.0
			outpost["hp"] = maxf(0.0, float(outpost.get("hp", 500.0)) - damage)
			zombie["outpost_attack_cooldown"] = 1.0
			if float(outpost["hp"]) <= 0.0:
				_eject_outpost_shelter(outpost)
				for wall_index in range(barricades.size() - 1, -1, -1):
					if int(barricades[wall_index].get("outpost_index", -1)) == outpost_index:
						barricades.remove_at(wall_index)
				for gate_index in range(gates.size() - 1, -1, -1):
					if int(gates[gate_index].get("outpost_index", -1)) == outpost_index:
						gates.remove_at(gate_index)
				outposts.remove_at(outpost_index)
				for remaining_wall in barricades:
					var wall_outpost_index: int = int(remaining_wall.get("outpost_index", -1))
					if wall_outpost_index > outpost_index:
						remaining_wall["outpost_index"] = wall_outpost_index - 1
				for remaining_gate in gates:
					var gate_outpost_index: int = int(remaining_gate.get("outpost_index", -1))
					if gate_outpost_index > outpost_index:
						remaining_gate["outpost_index"] = gate_outpost_index - 1
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
	if value is Vector2i:
		return {"__vector2i": [value.x, value.y]}
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
		if dictionary.has("__vector2i"):
			var integer_coordinates: Array = dictionary["__vector2i"]
			return Vector2i(int(integer_coordinates[0]), int(integer_coordinates[1]))
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
	if int(state.get("version", 0)) < 2 or int(state.get("version", 0)) > SAVE_VERSION:
		return false
	if int(state.get("sector_index", -1)) < 0 or int(state.get("sector_index", -1)) > 2:
		return false
	if int(state.get("wave", -1)) < 0:
		return false
	var save_version: int = int(state.get("version", 0))
	if save_version < 2 or save_version > SAVE_VERSION:
		return false
	var required_arrays: Array[String] = ["evacuation_zones", "civilians", "zombies", "units", "outposts", "turrets", "barricades", "gates", "building_archetypes", "district_regions", "zombie_grid_serialized", "civilian_grid_serialized"]
	for key in required_arrays:
		if not state.has(key) or not state[key] is Array:
			return false
	var saved_hq: Variant = state.get("primary_hq_position")
	var saved_camera: Variant = state.get("camera_position")
	return saved_hq is Dictionary and saved_hq.has("__vector2") and saved_camera is Dictionary and saved_camera.has("__vector2")

func _serialize_spatial_grid(grid: Dictionary) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for key in grid.keys():
		var bucket: Array = grid[key]
		if bucket.is_empty():
			continue
		var cell: Vector2i = key
		serialized.append({"cell": cell, "indices": bucket.duplicate()})
	return serialized

func _restore_spatial_grid(grid: Dictionary, serialized: Array) -> void:
	grid.clear()
	for entry in serialized:
		if not entry is Dictionary:
			continue
		var cell_value: Variant = entry.get("cell", Vector2i.ZERO)
		var indices: Variant = entry.get("indices", [])
		if cell_value is Vector2i and indices is Array:
			grid[cell_value] = indices.duplicate()

func _save_operation() -> void:
	# Never replace a prior valid campaign with an incomplete HQ-placement state.
	if not campaign_started or game_state == "hq_placement":
		return
	var state: Dictionary = {"version": SAVE_VERSION, "campaign_map_seed": campaign_map_seed, "starting_district_index": starting_district_index, "district_seed_points": district_seed_points, "sector_index": sector_index, "wave": wave, "funds": funds, "saved_count": saved_count, "lost_count": lost_count, "primary_hq_position": primary_hq_position, "evacuation_zones": evacuation_zones, "civilians": civilians, "zombies": zombies, "units": units, "vehicles": vehicles, "auto_ops_enabled": auto_ops_enabled, "highway_segments": highway_segments, "secondary_road_segments": secondary_road_segments, "world_callouts": world_callouts, "outposts": outposts, "turrets": turrets, "barricades": barricades, "flares": flares, "medevac": medevac, "camera_position": camera_position, "camera_zoom": camera_zoom, "elapsed": elapsed, "wave_timer": wave_timer, "shelter_flush_timer": shelter_flush_timer, "supply_drop_timer": supply_drop_timer, "supply_crates": supply_crates, "civilian_steering": civilian_steering, "endless_containment": endless_containment, "buildings": buildings, "spawn_districts": spawn_districts, "building_archetypes": building_archetypes, "district_regions": district_regions, "gates": gates, "warehouse_hold_timers": warehouse_hold_timers, "zombie_grid_serialized": _serialize_spatial_grid(zombie_grid), "civilian_grid_serialized": _serialize_spatial_grid(civilian_grid), "time_scale_index": time_scale_index, "day_phase": day_phase, "pending_wave_spawns": pending_wave_spawns, "pending_wave_spawn_timer": pending_wave_spawn_timer}
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
	campaign_map_seed = int(state.get("campaign_map_seed", campaign_map_seed))
	starting_district_index = clampi(int(state.get("starting_district_index", starting_district_index)), 0, maxi(0, district_regions.size() - 1))
	if state.has("district_seed_points"):
		district_seed_points.assign(state["district_seed_points"])
	wave = int(state.get("wave", 0))
	funds = int(state.get("funds", 300))
	saved_count = int(state.get("saved_count", 0))
	lost_count = int(state.get("lost_count", 0))
	primary_hq_position = state.get("primary_hq_position", Vector2.ZERO)
	evacuation_zones.assign(state.get("evacuation_zones", []))
	civilians.assign(state.get("civilians", []))
	zombies.assign(state.get("zombies", []))
	units.assign(state.get("units", []))
	vehicles.assign(state.get("vehicles", []))
	if state.has("highway_segments"):
		highway_segments.assign(state["highway_segments"])
	if state.has("secondary_road_segments"):
		secondary_road_segments.assign(state["secondary_road_segments"])
	if state.has("world_callouts"):
		world_callouts.assign(state["world_callouts"])
	if int(state.get("version", SAVE_VERSION)) == 2:
		vehicles.clear()
		for unit_index in range(units.size()):
			var migrated_unit: Dictionary = units[unit_index]
			migrated_unit["manual_order"] = bool(migrated_unit.get("manual_order", false))
			migrated_unit["ai_task"] = str(migrated_unit.get("ai_task", ""))
			units[unit_index] = migrated_unit
	auto_ops_enabled = bool(state.get("auto_ops_enabled", true))
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
	if state.has("building_archetypes"):
		building_archetypes.assign(state["building_archetypes"])
	for building_index in range(building_archetypes.size()):
		var building_state: Dictionary = building_archetypes[building_index]
		var default_hp: float = 1800.0 if str(building_state.get("type", "")) == "HIGHRISE" else 900.0
		building_state["hp"] = float(building_state.get("hp", default_hp))
		building_state["max_hp"] = float(building_state.get("max_hp", default_hp))
		building_state["destroyed"] = bool(building_state.get("destroyed", false))
		building_state["fortified"] = bool(building_state.get("fortified", false))
		building_state["secured"] = bool(building_state.get("secured", false))
		building_archetypes[building_index] = building_state
	if state.has("district_regions"):
		district_regions.assign(state["district_regions"])
	if state.has("gates"):
		gates.assign(state["gates"])
	if state.has("warehouse_hold_timers"):
		warehouse_hold_timers = state["warehouse_hold_timers"]
	if state.has("zombie_grid_serialized"):
		_restore_spatial_grid(zombie_grid, state["zombie_grid_serialized"])
	if state.has("civilian_grid_serialized"):
		_restore_spatial_grid(civilian_grid, state["civilian_grid_serialized"])
	pending_wave_spawns = maxi(0, int(state.get("pending_wave_spawns", 0)))
	if zombies.size() > MAX_ACTIVE_ZOMBIES:
		pending_wave_spawns += zombies.size() - MAX_ACTIVE_ZOMBIES
		zombies.resize(MAX_ACTIVE_ZOMBIES)
	pending_wave_spawn_timer = maxf(0.0, float(state.get("pending_wave_spawn_timer", 0.0)))
	time_scale_index = clampi(int(state.get("time_scale_index", 0)), 0, TIME_SCALES.size() - 1)
	day_phase = str(state.get("day_phase", "DAY"))
	endless_containment = bool(state.get("endless_containment", false))
	while civilian_steering.size() < civilians.size():
		civilian_steering.append({})
	_rebuild_zombie_spatial_grid()
	_rebuild_spatial_grid(civilian_grid, civilians)
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
	_draw_roads()
	_draw_buildings()
	for district_index in range(district_regions.size()):
		var district_rect: Rect2 = district_regions[district_index]
		if _camera_view_rect().intersects(district_rect):
			var district_labels: Array[String] = ["URBAN CORE", "SUBURBS", "INDUSTRIAL ZONE", "MEDICAL DISTRICT", "RURAL HIGHWAYS", "LOGISTICS HUB", "CIVIC CENTER", "OUTER CORRIDOR"]
			var district_label: String = district_labels[district_index] if district_index < district_labels.size() else "REGIONAL DISTRICT"
			_draw_text(district_label, Vector2(70.0, district_rect.position.y + 62.0), 24, Color(0.45, 0.75, 0.62, 0.6))
	_draw_evac_zone()
	_draw_entities()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_text(value: String, position: Vector2, size: int, color: Color) -> void:
	if screen_font != null:
		draw_string(screen_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
