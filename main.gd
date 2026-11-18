extends Node2D

# Containment Protocol - Godot 4.3
# Portrait 720x1280, drawn natively for low-overhead Android rendering.

const VIEW_SIZE := Vector2(720.0, 1280.0)
const BAR_TOP := 1080.0
const EVAC_ZONE := Vector2(360.0, 205.0)
const EVAC_RADIUS := 76.0
const MAX_WAVES := 5

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

func _ready() -> void:
	randomize()
	screen_font = ThemeDB.fallback_font
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
	message = "EVACUATE CIVILIANS. HOLD THE LINE."
	message_timer = 4.0
	for i in range(45):
		civilians.append(Vector2(randf_range(52.0, 668.0), randf_range(510.0, 1030.0)))

func _process(delta: float) -> void:
	if game_state != "playing":
		queue_redraw()
		return

	elapsed += delta
	message_timer = maxf(0.0, message_timer - delta)
	airstrike_timer = maxf(0.0, airstrike_timer - delta)
	wave_timer -= delta

	if wave < MAX_WAVES and wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = 18.0

	# Civilians move steadily toward the extraction zone.
	for i in range(civilians.size() - 1, -1, -1):
		var civilian := civilians[i]
		var direction := (EVAC_ZONE - civilian).normalized()
		civilian += direction * 43.0 * delta
		civilians[i] = civilian
		if civilian.distance_to(EVAC_ZONE) <= EVAC_RADIUS:
			civilians.remove_at(i)
			saved_count += 1
			funds += 25
			message = "CIVILIAN EVACUATED  +$25"
			message_timer = 1.1

	# Zombies choose the nearest civilian. Runners are faster and more aggressive.
	for i in range(zombies.size() - 1, -1, -1):
		var zombie: Dictionary = zombies[i]
		var zpos: Vector2 = zombie["pos"]
		var target := EVAC_ZONE
		var nearest := INF
		for civilian in civilians:
			var distance := zpos.distance_squared_to(civilian)
			if distance < nearest:
				nearest = distance
				target = civilian
		var speed: float = 112.0 if zombie["kind"] == "runner" else 61.0
		zpos += (target - zpos).normalized() * speed * delta

		# Barricades absorb time and slow the horde at the point of contact.
		for wall in barricades:
			if zpos.distance_to(wall) < 27.0:
				zpos -= (target - wall).normalized() * 38.0 * delta
				break
		zombie["pos"] = zpos
		zombies[i] = zombie

		for c_idx in range(civilians.size() - 1, -1, -1):
			if zpos.distance_to(civilians[c_idx]) < 15.0:
				var infected_pos: Vector2 = civilians[c_idx]
				civilians.remove_at(c_idx)
				lost_count += 1
				zombies.append({"pos": infected_pos, "kind": "shambler"})
				message = "CIVILIAN LOST"
				message_timer = 1.4
				break

	# Deployed teams automatically engage targets in range.
	for unit in units:
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - delta)
		if float(unit["cooldown"]) > 0.0 or zombies.is_empty():
			continue
		var unit_pos: Vector2 = unit["pos"]
		var is_sniper: bool = unit["kind"] == "sniper"
		var attack_range := 390.0 if is_sniper else 205.0
		var target_index := -1
		var best_distance := attack_range
		for zi in range(zombies.size()):
			var distance := unit_pos.distance_to(zombies[zi]["pos"])
			if distance < best_distance:
				best_distance = distance
				target_index = zi
		if target_index >= 0:
			zombies.remove_at(target_index)
			unit["cooldown"] = 1.05 if is_sniper else 0.62

	if wave >= MAX_WAVES and zombies.is_empty() and civilians.is_empty():
		game_state = "victory"
		message = "SECTOR SECURED"
	elif civilians.is_empty() and saved_count == 0 and lost_count > 0:
		game_state = "defeat"
		message = "EVACUATION FAILED"

	queue_redraw()

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
	if pos.y >= BAR_TOP:
		var button_width := VIEW_SIZE.x / 4.0
		selected_deployment = clampi(int(pos.x / button_width), 0, 3)
		message = str(DEPLOYMENTS[selected_deployment]["name"]) + " SELECTED"
		message_timer = 1.2
		queue_redraw()
		return
	if pos.y < 270.0:
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
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#07110f"))
	_draw_grid()
	_draw_evac_zone()
	_draw_entities()
	_draw_hud()
	_draw_deployment_bar()
	if airstrike_timer > 0.0:
		draw_arc(airstrike_marker, 112.0, 0.0, TAU, 48, Color(1.0, 0.42, 0.12, airstrike_timer), 4.0)
	if game_state != "playing":
		_draw_end_screen()

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
	for unit in units:
		var p: Vector2 = unit["pos"]
		var sniper: bool = unit["kind"] == "sniper"
		var tint := Color("#6bdc9a") if not sniper else Color("#8ab6ff")
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), tint)
		draw_arc(p, 390.0 if sniper else 205.0, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, 0.10), 1.0)

func _draw_hud() -> void:
	draw_rect(Rect2(18, 18, 684, 126), Color("#0b1b17"))
	_draw_text("CONTAINMENT PROTOCOL", Vector2(34, 52), 23, Color("#e2f4e9"))
	_draw_text("FUNDS  $%d" % funds, Vector2(34, 88), 21, Color("#f4d77b"))
	_draw_text("WAVE %d/%d" % [wave, MAX_WAVES], Vector2(245, 88), 18, Color("#ffad62"))
	_draw_text("SAVED %d   LOST %d   HORDE %d" % [saved_count, lost_count, zombies.size()], Vector2(34, 122), 17, Color("#9cbcaf"))
	if message_timer > 0.0:
		_draw_text(message, Vector2(34, 177), 16, Color("#ffbd76"))

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
