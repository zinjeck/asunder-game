extends RefCounted
class_name CityCitizenMovementPresentation

# Cosmetic, centralized movement interpolation. This helper reads WorldData but
# never mutates authoritative citizen positions or the spatial index. Its caches
# contain only active or still-transitioning movers, not the whole population.

var last_authoritative_tile_by_citizen_id: Dictionary = {}
var transition_by_citizen_id: Dictionary = {}
var tracked_mover_id_lookup: Dictionary = {}


func initialize() -> void:
	last_authoritative_tile_by_citizen_id.clear()
	transition_by_citizen_id.clear()
	tracked_mover_id_lookup.clear()
	refresh_mover_tracking()


func synchronize(animate_position_changes: bool) -> void:
	var candidate_citizen_id_lookup: Dictionary = {}

	for raw_citizen_id in tracked_mover_id_lookup.keys():
		if typeof(raw_citizen_id) == TYPE_INT:
			candidate_citizen_id_lookup[raw_citizen_id] = true

	for raw_citizen_id in transition_by_citizen_id.keys():
		if typeof(raw_citizen_id) == TYPE_INT:
			candidate_citizen_id_lookup[raw_citizen_id] = true

	for citizen_id in WorldData.get_city_active_mover_ids_snapshot():
		candidate_citizen_id_lookup[citizen_id] = true

	var candidate_citizen_ids: Array = (
		candidate_citizen_id_lookup.keys()
	)
	candidate_citizen_ids.sort()

	for raw_citizen_id in candidate_citizen_ids:
		var citizen_id := int(raw_citizen_id)
		var citizen := WorldData.get_city_citizen_by_id(citizen_id)

		if (
			citizen.is_empty()
			or not bool(citizen.get("alive", false))
		):
			erase_citizen(citizen_id)
			continue

		_synchronize_citizen_position(
			citizen,
			animate_position_changes
		)


func track_mover(citizen_id: int) -> void:
	if citizen_id <= 0:
		return

	var citizen := WorldData.get_city_citizen_by_id(citizen_id)

	if (
		citizen.is_empty()
		or not bool(citizen.get("alive", false))
	):
		erase_citizen(citizen_id)
		return

	var raw_authoritative_tile = citizen.get(
		"city_tile_position",
		WorldData.INVALID_CITY_TILE_POSITION
	)

	if not raw_authoritative_tile is Vector2i:
		erase_citizen(citizen_id)
		return

	if not last_authoritative_tile_by_citizen_id.has(citizen_id):
		last_authoritative_tile_by_citizen_id[citizen_id] = (
			raw_authoritative_tile
		)

	tracked_mover_id_lookup[citizen_id] = true


func refresh_mover_tracking() -> void:
	for citizen_id in WorldData.get_city_active_mover_ids_snapshot():
		track_mover(citizen_id)

	for raw_citizen_id in tracked_mover_id_lookup.keys():
		if typeof(raw_citizen_id) != TYPE_INT:
			tracked_mover_id_lookup.erase(raw_citizen_id)
			continue

		var citizen_id := int(raw_citizen_id)

		if WorldData.city_active_mover_id_lookup.has(citizen_id):
			continue

		if transition_by_citizen_id.has(citizen_id):
			continue

		tracked_mover_id_lookup.erase(citizen_id)
		last_authoritative_tile_by_citizen_id.erase(citizen_id)


func update(delta: float) -> bool:
	if transition_by_citizen_id.is_empty():
		return false

	if not SimulationClock.simulation_active:
		return false

	if SimulationClock.simulation_paused:
		return false

	if delta <= 0.0:
		return false

	var simulation_speed: float = maxf(
		SimulationClock.speed_multiplier,
		0.0
	)

	if simulation_speed <= 0.0:
		return false

	var world_minutes_per_real_second: float = (
		float(SimulationClock.minutes_per_tick)
		/ maxf(
			SimulationClock.real_seconds_per_tick,
			0.001
		)
	)
	var movement_progress_per_tile: float = maxf(
		float(
			WorldData.CITY_CITIZEN_MOVEMENT_PROGRESS_PER_TILE
		),
		1.0
	)
	var visual_state_changed: bool = false

	for raw_citizen_id in transition_by_citizen_id.keys():
		if typeof(raw_citizen_id) != TYPE_INT:
			transition_by_citizen_id.erase(raw_citizen_id)
			tracked_mover_id_lookup.erase(raw_citizen_id)
			visual_state_changed = true
			continue

		var citizen_id := int(raw_citizen_id)
		var raw_transition = transition_by_citizen_id[citizen_id]

		if not raw_transition is Dictionary:
			transition_by_citizen_id.erase(citizen_id)
			_release_mover_if_inactive(citizen_id)
			visual_state_changed = true
			continue

		var transition: Dictionary = raw_transition
		var raw_from_tile = transition.get("from_tile")
		var raw_to_tile = transition.get("to_tile")

		if not (raw_from_tile is Vector2) or not (raw_to_tile is Vector2):
			transition_by_citizen_id.erase(citizen_id)
			_release_mover_if_inactive(citizen_id)
			visual_state_changed = true
			continue

		var tile_distance: float = maxf(
			float(transition.get("tile_distance", 1.0)),
			1.0
		)
		var movement_speed: float = maxf(
			float(
				transition.get(
					"movement_speed_basis_points_per_minute",
					WorldData.DEFAULT_CITIZEN_MOVEMENT_SPEED_PER_MINUTE
				)
			),
			1.0
		)
		var tiles_per_real_second: float = (
			movement_speed
			* world_minutes_per_real_second
			/ movement_progress_per_tile
		)
		var progress: float = clampf(
			float(transition.get("progress", 0.0))
			+ (
				delta
				* simulation_speed
				* tiles_per_real_second
				/ tile_distance
			),
			0.0,
			1.0
		)

		if progress >= 1.0:
			transition_by_citizen_id.erase(citizen_id)
			_release_mover_if_inactive(citizen_id)
		else:
			transition["progress"] = progress
			transition_by_citizen_id[citizen_id] = transition

		visual_state_changed = true

	return visual_state_changed


func get_visual_tile_position(citizen: Dictionary) -> Vector2:
	var raw_authoritative_tile = citizen.get(
		"city_tile_position",
		WorldData.INVALID_CITY_TILE_POSITION
	)

	if not raw_authoritative_tile is Vector2i:
		return Vector2(-1.0, -1.0)

	var authoritative_tile: Vector2i = raw_authoritative_tile
	var fallback_position: Vector2 = Vector2(
		float(authoritative_tile.x),
		float(authoritative_tile.y)
	)
	var citizen_id := int(citizen.get("id", -1))

	if not transition_by_citizen_id.has(citizen_id):
		return fallback_position

	var raw_transition = transition_by_citizen_id[citizen_id]

	if not raw_transition is Dictionary:
		return fallback_position

	var transition: Dictionary = raw_transition
	var raw_from_tile = transition.get("from_tile")
	var raw_to_tile = transition.get("to_tile")

	if not (raw_from_tile is Vector2) or not (raw_to_tile is Vector2):
		return fallback_position

	var from_tile: Vector2 = raw_from_tile
	var to_tile: Vector2 = raw_to_tile
	var progress: float = clampf(
		float(transition.get("progress", 0.0)),
		0.0,
		1.0
	)

	return from_tile.lerp(to_tile, progress)


func get_transitioning_citizen_ids_snapshot() -> Array[int]:
	var citizen_ids: Array[int] = []

	for raw_citizen_id in transition_by_citizen_id.keys():
		if typeof(raw_citizen_id) != TYPE_INT:
			continue

		citizen_ids.append(int(raw_citizen_id))

	citizen_ids.sort()
	return citizen_ids


func _synchronize_citizen_position(
	citizen: Dictionary,
	animate_position_change: bool
) -> void:
	var citizen_id := int(citizen.get("id", -1))
	var raw_authoritative_tile = citizen.get(
		"city_tile_position",
		WorldData.INVALID_CITY_TILE_POSITION
	)

	if citizen_id <= 0:
		return

	if not raw_authoritative_tile is Vector2i:
		erase_citizen(citizen_id)
		return

	var authoritative_tile: Vector2i = raw_authoritative_tile

	if not last_authoritative_tile_by_citizen_id.has(citizen_id):
		last_authoritative_tile_by_citizen_id[citizen_id] = (
			authoritative_tile
		)
		transition_by_citizen_id.erase(citizen_id)
		_release_mover_if_inactive(citizen_id)
		return

	var raw_previous_authoritative_tile = (
		last_authoritative_tile_by_citizen_id[citizen_id]
	)

	if not raw_previous_authoritative_tile is Vector2i:
		last_authoritative_tile_by_citizen_id[citizen_id] = (
			authoritative_tile
		)
		transition_by_citizen_id.erase(citizen_id)
		_release_mover_if_inactive(citizen_id)
		return

	var previous_authoritative_tile: Vector2i = (
		raw_previous_authoritative_tile
	)

	if previous_authoritative_tile == authoritative_tile:
		_release_mover_if_inactive(citizen_id)
		return

	var visual_from_tile: Vector2 = Vector2(
		float(previous_authoritative_tile.x),
		float(previous_authoritative_tile.y)
	)

	if transition_by_citizen_id.has(citizen_id):
		visual_from_tile = get_visual_tile_position(citizen)
	var visual_to_tile: Vector2 = Vector2(
		float(authoritative_tile.x),
		float(authoritative_tile.y)
	)

	last_authoritative_tile_by_citizen_id[citizen_id] = (
		authoritative_tile
	)

	if not animate_position_change:
		transition_by_citizen_id.erase(citizen_id)
		_release_mover_if_inactive(citizen_id)
		return

	var tile_distance: float = (
		absf(visual_to_tile.x - visual_from_tile.x)
		+ absf(visual_to_tile.y - visual_from_tile.y)
	)

	if tile_distance <= 0.0:
		transition_by_citizen_id.erase(citizen_id)
		_release_mover_if_inactive(citizen_id)
		return

	var movement_speed := maxi(
		int(
			citizen.get(
				"movement_speed_basis_points_per_minute",
				WorldData.DEFAULT_CITIZEN_MOVEMENT_SPEED_PER_MINUTE
			)
		),
		1
	)

	transition_by_citizen_id[citizen_id] = {
		"from_tile": visual_from_tile,
		"to_tile": visual_to_tile,
		"progress": 0.0,
		"tile_distance": maxf(tile_distance, 1.0),
		"movement_speed_basis_points_per_minute": (
			movement_speed
		)
	}
	tracked_mover_id_lookup[citizen_id] = true


func erase_citizen(citizen_id: int) -> void:
	last_authoritative_tile_by_citizen_id.erase(citizen_id)
	transition_by_citizen_id.erase(citizen_id)
	tracked_mover_id_lookup.erase(citizen_id)


func _release_mover_if_inactive(citizen_id: int) -> void:
	if WorldData.city_active_mover_id_lookup.has(citizen_id):
		return

	if transition_by_citizen_id.has(citizen_id):
		return

	tracked_mover_id_lookup.erase(citizen_id)
	last_authoritative_tile_by_citizen_id.erase(citizen_id)
