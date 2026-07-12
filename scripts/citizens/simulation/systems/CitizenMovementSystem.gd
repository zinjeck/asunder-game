extends RefCounted
class_name CitizenMovementSystem


static func run_tick(
	_tick_index: int,
	minutes_advanced: int
) -> void:
	if minutes_advanced <= 0:
		return

	var city_world: WorldData = WorldData.official_city_world

	if city_world == null:
		return

	var active_mover_ids := (
		WorldData.get_city_active_mover_ids_snapshot()
	)

	if active_mover_ids.is_empty():
		return

	var citizen_updates: Array = []
	var next_active_mover_ids: Array[int] = []

	for citizen_id in active_mover_ids:
		var citizen_index := (
			WorldData.get_city_citizen_index_by_id(
				citizen_id
			)
		)

		if citizen_index < 0:
			continue

		var raw_citizen = WorldData.city_citizens[
			citizen_index
		]

		if not raw_citizen is Dictionary:
			continue

		var citizen: Dictionary = raw_citizen.duplicate(true)
		var raw_current_tile = citizen.get(
			"city_tile_position",
			WorldData.INVALID_CITY_TILE_POSITION
		)

		if not raw_current_tile is Vector2i:
			push_error(
				"Cannot advance citizen "
				+ str(citizen_id)
				+ ": authoritative position is invalid."
			)
			continue

		var current_tile: Vector2i = raw_current_tile

		if not bool(citizen.get("alive", false)):
			CityCitizens.reset_city_citizen_movement_state(
				citizen,
				true
			)
			_append_citizen_update(
				citizen_updates,
				citizen_id,
				citizen,
				current_tile
			)
			continue

		if (
			str(citizen.get("movement_state", ""))
			!= WorldData.CITY_CITIZEN_MOVEMENT_STATE_MOVING
		):
			continue

		var raw_path = citizen.get("movement_path", [])
		var raw_path_index = citizen.get(
			"movement_path_index",
			0
		)
		var raw_progress = citizen.get(
			"movement_progress_basis_points",
			0
		)
		var raw_speed = citizen.get(
			"movement_speed_basis_points_per_minute",
			WorldData.DEFAULT_CITIZEN_MOVEMENT_SPEED_PER_MINUTE
		)
		var raw_destination = citizen.get(
			"movement_destination_tile",
			WorldData.INVALID_CITY_TILE_POSITION
		)

		var basic_state_is_valid := (
			raw_path is Array
			and typeof(raw_path_index) == TYPE_INT
			and typeof(raw_progress) == TYPE_INT
			and typeof(raw_speed) == TYPE_INT
			and raw_destination is Vector2i
		)

		if not basic_state_is_valid:
			_stop_citizen_for_invalid_path(
				citizen,
				raw_destination
			)
			_append_citizen_update(
				citizen_updates,
				citizen_id,
				citizen,
				current_tile
			)
			continue

		var movement_path: Array = raw_path
		var movement_path_index: int = raw_path_index
		var movement_progress: int = raw_progress
		var movement_speed: int = raw_speed
		var movement_destination: Vector2i = raw_destination

		var path_state_is_valid: bool = (
			movement_path.size() >= 2
			and movement_path_index >= 1
			and movement_path_index < movement_path.size()
			and movement_progress >= 0
			and movement_progress
			< WorldData.CITY_CITIZEN_MOVEMENT_PROGRESS_PER_TILE
			and movement_speed > 0
			and movement_path[
				movement_path_index - 1
			] == current_tile
			and movement_path.back() == movement_destination
		)

		if not path_state_is_valid:
			_stop_citizen_for_invalid_path(
				citizen,
				movement_destination
			)
			_append_citizen_update(
				citizen_updates,
				citizen_id,
				citizen,
				current_tile
			)
			continue

		movement_progress += (
			minutes_advanced * movement_speed
		)
		var movement_was_blocked := false

		while (
			movement_progress
			>= WorldData.CITY_CITIZEN_MOVEMENT_PROGRESS_PER_TILE
			and movement_path_index < movement_path.size()
		):
			var raw_next_tile = movement_path[
				movement_path_index
			]

			if not raw_next_tile is Vector2i:
				_set_citizen_movement_blocked(
					citizen,
					movement_destination,
					WorldData.CITY_CITIZEN_MOVEMENT_FAILURE_INVALID_PATH
				)
				movement_was_blocked = true
				break

			var next_tile: Vector2i = raw_next_tile
			var cardinal_distance := (
				absi(next_tile.x - current_tile.x)
				+ absi(next_tile.y - current_tile.y)
			)

			if cardinal_distance != 1:
				_set_citizen_movement_blocked(
					citizen,
					movement_destination,
					WorldData.CITY_CITIZEN_MOVEMENT_FAILURE_INVALID_PATH
				)
				movement_was_blocked = true
				break

			if not WorldData.is_city_tile_walkable_for_citizen(
				city_world,
				next_tile
			):
				_set_citizen_movement_blocked(
					citizen,
					movement_destination,
					WorldData.CITY_CITIZEN_MOVEMENT_FAILURE_NEXT_TILE_BLOCKED
				)
				movement_was_blocked = true
				break

			movement_progress -= (
				WorldData.CITY_CITIZEN_MOVEMENT_PROGRESS_PER_TILE
			)
			current_tile = next_tile
			movement_path_index += 1

		if movement_was_blocked:
			_append_citizen_update(
				citizen_updates,
				citizen_id,
				citizen,
				current_tile
			)
			continue

		if movement_path_index >= movement_path.size():
			CityCitizens.reset_city_citizen_movement_state(
				citizen,
				true
			)
			_append_citizen_update(
				citizen_updates,
				citizen_id,
				citizen,
				current_tile
			)
			continue

		citizen["movement_path_index"] = movement_path_index
		citizen["movement_progress_basis_points"] = (
			movement_progress
		)
		citizen["movement_failure_reason"] = (
			WorldData.CITY_CITIZEN_MOVEMENT_FAILURE_NONE
		)

		next_active_mover_ids.append(citizen_id)
		_append_citizen_update(
			citizen_updates,
			citizen_id,
			citizen,
			current_tile
		)

	var commit_result := (
		WorldData.commit_city_citizen_movement_tick(
			city_world,
			citizen_updates,
			next_active_mover_ids
		)
	)

	if not bool(commit_result.get("success", false)):
		push_error(
			"Citizen movement tick could not be committed."
		)


static func _append_citizen_update(
	citizen_updates: Array,
	citizen_id: int,
	citizen: Dictionary,
	final_tile: Vector2i
) -> void:
	citizen_updates.append({
		"citizen_id": citizen_id,
		"citizen": citizen,
		"final_tile": final_tile
	})


static func _stop_citizen_for_invalid_path(
	citizen: Dictionary,
	raw_destination
) -> void:
	if (
		raw_destination is Vector2i
		and raw_destination
		!= WorldData.INVALID_CITY_TILE_POSITION
	):
		_set_citizen_movement_blocked(
			citizen,
			raw_destination,
			WorldData.CITY_CITIZEN_MOVEMENT_FAILURE_INVALID_PATH
		)
		return

	CityCitizens.reset_city_citizen_movement_state(
		citizen,
		true
	)


static func _set_citizen_movement_blocked(
	citizen: Dictionary,
	destination_tile: Vector2i,
	failure_reason: String
) -> void:
	citizen["movement_state"] = (
		WorldData.CITY_CITIZEN_MOVEMENT_STATE_BLOCKED
	)
	citizen["movement_path"] = []
	citizen["movement_path_index"] = 0
	citizen["movement_progress_basis_points"] = 0
	citizen["movement_destination_tile"] = destination_tile
	citizen["movement_failure_reason"] = failure_reason
