extends Node2D

var civilians: Array[Vector2] = []
var zombies: Array[Vector2] = []
var soldiers: Array[Dictionary] = []
var evac_zone := Vector2(360, 140)
var evac_radius := 70.0
var funds := 300
var saved_count := 0
var lost_count := 0

func _ready() -> void:
	randomize()
	for i in range(45):
		civilians.append(Vector2(randf_range(60, 660), randf_range(350, 1150)))
	for i in range(6):
		zombies.append(Vector2(randf_range(60, 660), randf_range(950, 1220)))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		deploy_squad(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		deploy_squad(event.position)

func deploy_squad(pos: Vector2) -> void:
	if funds >= 100 and pos.y > 220:
		funds -= 100
		soldiers.append({"pos": pos, "cooldown": 0.0})

func _process(delta: float) -> void:
	# Move civilians toward Evacuation Zone
	for i in range(civilians.size() - 1, -1, -1):
		var c := civilians[i]
		var dir := (evac_zone - c).normalized()
		c += dir * 48.0 * delta
		civilians[i] = c
		if c.distance_to(evac_zone) < evac_radius:
			civilians.remove_at(i)
			saved_count += 1
			funds += 25

	# Move zombies & infect civilians
	for i in range(zombies.size()):
		var z := zombies[i]
		var target := evac_zone
		var best_dist := 99999.0
		for c in civilians:
			var d := z.distance_to(c)
			if d < best_dist:
				best_dist = d
				target = c
		for s in soldiers:
			var d := z.distance_to(s["pos"])
			if d < best_dist:
				best_dist = d
				target = s["pos"]
		z += (target - z).normalized() * 62.0 * delta
		zombies[i] = z

		for c_idx in range(civilians.size() - 1, -1, -1):
			if z.distance_to(civilians[c_idx]) < 14.0:
				zombies.append(civilians[c_idx])
				civilians.remove_at(c_idx)
				lost_count += 1

	# Soldiers shoot nearby zombies
	for s in soldiers:
		s["cooldown"] = max(0.0, s["cooldown"] - delta)
		if s["cooldown"] <= 0.0 and zombies.size() > 0:
			var nearest_idx := -1
			var nearest_dist := 180.0
			for z_idx in range(zombies.size()):
				var d := s["pos"].distance_to(zombies[z_idx])
				if d < nearest_dist:
					nearest_dist = d
					nearest_idx = z_idx
			if nearest_idx != -1:
				zombies.remove_at(nearest_idx)
				s["cooldown"] = 0.55

	queue_redraw()

func _draw() -> void:
	# Tactical dark radar background
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.05, 0.08, 0.06))
	# Evacuation Zone
	draw_circle(evac_zone, evac_radius, Color(0.1, 0.5, 0.2, 0.35))
	draw_arc(evac_zone, evac_radius, 0, TAU, 32, Color(0.2, 0.9, 0.4), 3.0)
	# Civilians (Blue/White dots)
	for c in civilians:
		draw_circle(c, 6.0, Color(0.4, 0.8, 1.0))
	# Zombies (Red dots)
	for z in zombies:
		draw_circle(z, 7.0, Color(0.95, 0.2, 0.2))
	# Soldiers (Green squares + range ring)
	for s in soldiers:
		draw_rect(Rect2(s["pos"] - Vector2(8, 8), Vector2(16, 16)), Color(0.2, 1.0, 0.4))
		draw_arc(s["pos"], 180.0, 0, TAU, 32, Color(0.2, 1.0, 0.4, 0.15), 1.5)
	# HUD Text
	draw_string(ThemeDB.fallback_font, Vector2(24, 48), "FUNDS: $%d (Tap map to deploy Squad - $100)" % funds, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(24, 82), "SAVED: %d   INFECTED: %d   HORDE: %d" % [saved_count, lost_count, zombies.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 0.9, 0.7))
