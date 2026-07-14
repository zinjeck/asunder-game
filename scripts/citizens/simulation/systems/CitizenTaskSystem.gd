extends RefCounted
class_name CitizenTaskSystem

const CityNavigationSystemScript = preload(
	"res://scripts/city/simulation/systems/CityNavigationSystem.gd"
)
const CityActivityLocationResolverScript = preload(
	"res://scripts/city/simulation/systems/CityActivityLocationResolver.gd"
)
const MAX_WORK_PATH_REQUESTS_PER_TICK: int = 1
const MAX_WORK_PATH_EXPANDED_NODES: int = 10_000


static func run_tick(
	tick_index: int,
	minutes_advanced: int
) -> void:
	if minutes_advanced <= 0:
		return

	var city_world: WorldData = WorldData.official_city_world

	if city_world == null:
		return

	var active_task_ids := (
		WorldData.get_city_active_task_ids_snapshot()
	)

	if active_task_ids.is_empty():
		return

	var path_requests_remaining := (
		MAX_WORK_PATH_REQUESTS_PER_TICK
	)

	for citizen_id in active_task_ids:
		var citizen := WorldData.get_city_citizen_by_id(
			citizen_id
		)

		if citizen.is_empty():
			continue

		if not bool(citizen.get("alive", false)):
			_clear_invalid_task(citizen_id)
			continue

		var current_task := (
			WorldData.get_city_citizen_current_task(
				citizen_id
			)
		)

		match str(current_task.get("kind", "")):
			WorldData.CITY_CITIZEN_TASK_KIND_WORK:
				path_requests_remaining = (
					_advance_work_task(
						city_world,
						citizen_id,
						citizen,
						current_task,
						path_requests_remaining,
						tick_index
					)
				)

			WorldData.CITY_CITIZEN_TASK_KIND_NONE:
				_clear_invalid_task(citizen_id)

			_:
				_clear_invalid_task(citizen_id)

static func _advance_work_task(
	city_world: WorldData,
	citizen_id: int,
	citizen: Dictionary,
	current_task: Dictionary,
	path_requests_remaining: int,
	tick_index: int
) -> int:
	var workplace_id := int(
		current_task.get("target_object_id", -1)
	)
	var workplace := WorldData.get_city_object_by_id(
		workplace_id
	)

	if (
		workplace_id <= 0
		or workplace.is_empty()
		or not WorldData.city_object_is_workplace(workplace)
		or int(citizen.get("job_object_id", -1)) != workplace_id
	):
		_clear_invalid_task(citizen_id)
		return path_requests_remaining
	var movement_policy := (
		WorldData.get_city_object_work_movement_policy(
			workplace
		)
	)
	var workplace_movement_mode := str(
		movement_policy.get(
			"mode",
			WorldData.WORKPLACE_MOVEMENT_MODE_NONE
		)
	)
	var dwell_min_minutes := maxi(
		int(movement_policy.get("dwell_min_minutes", 0)),
		0
	)
	var dwell_max_minutes := maxi(
		int(
			movement_policy.get(
				"dwell_max_minutes",
				dwell_min_minutes
			)
		),
		dwell_min_minutes
	)
	var maximum_relocations_per_task := maxi(
		int(
			movement_policy.get(
				"maximum_relocations_per_task",
				0
			)
		),
		0
	)
	var minimum_relocation_distance := maxi(
		int(
			movement_policy.get(
				"minimum_relocation_distance",
				0
			)
		),
		0
	)
	var avoid_previous_target := bool(
		movement_policy.get(
			"avoid_previous_target",
			false
		)
	)
	var activity_tiles := (
		CityActivityLocationResolverScript
		.get_work_activity_tiles(
			city_world,
			workplace
		)
	)
	var raw_current_tile = citizen.get(
		"city_tile_position",
		WorldData.INVALID_CITY_TILE_POSITION
	)

	if not raw_current_tile is Vector2i:
		_set_work_task_blocked(citizen_id)
		return path_requests_remaining

	var current_tile: Vector2i = raw_current_tile
	var task_phase := str(
		current_task.get(
			"phase",
			WorldData.CITY_CITIZEN_TASK_PHASE_NONE
		)
	)
	var relocation_count := maxi(
		int(current_task.get("relocation_count", 0)),
		0
	)
	var movement_state := str(
		citizen.get(
			"movement_state",
			WorldData.CITY_CITIZEN_MOVEMENT_STATE_IDLE
		)
	)

	match task_phase:
		WorldData.CITY_CITIZEN_TASK_PHASE_PENDING:
			if activity_tiles.is_empty():
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if activity_tiles.has(current_tile):
				if (
					movement_state
					!= WorldData.CITY_CITIZEN_MOVEMENT_STATE_IDLE
				):
					WorldData.cancel_city_citizen_movement(
						citizen_id
					)

				if not _begin_work_activity_dwell(
					citizen_id,
					workplace_id,
					current_tile,
					current_task.get(
						"previous_target_tile",
						WorldData.INVALID_CITY_TILE_POSITION
					),
					tick_index,
					dwell_min_minutes,
					dwell_max_minutes,
					relocation_count,
					maximum_relocations_per_task
				):
					_set_work_task_blocked(citizen_id)

				return path_requests_remaining

			if (
				movement_state
				== WorldData.CITY_CITIZEN_MOVEMENT_STATE_MOVING
			):
				return path_requests_remaining

			if (
				movement_state
				== WorldData.CITY_CITIZEN_MOVEMENT_STATE_BLOCKED
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if path_requests_remaining <= 0:
				return path_requests_remaining

			path_requests_remaining -= 1

			var path_result := (
				CityNavigationSystemScript
				.find_path_to_any_city_tile(
					city_world,
					current_tile,
					activity_tiles,
					MAX_WORK_PATH_EXPANDED_NODES
				)
			)

			if not bool(path_result.get("success", false)):
				_set_work_task_blocked(citizen_id)
				push_warning(
					"Citizen "
					+ str(citizen_id)
					+ " could not reach workplace "
					+ str(workplace_id)
					+ ": "
					+ str(path_result.get("status", "unknown"))
				)
				return path_requests_remaining

			var raw_path = path_result.get("path", [])

			if not raw_path is Array:
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			var movement_path: Array = raw_path
			var raw_selected_destination = path_result.get(
				"destination_tile",
				WorldData.INVALID_CITY_TILE_POSITION
			)

			if not raw_selected_destination is Vector2i:
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			var selected_destination: Vector2i = (
				raw_selected_destination
			)

			if not activity_tiles.has(selected_destination):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if not WorldData.set_city_citizen_task_activity_state(
				citizen_id,
				selected_destination
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if movement_path.size() <= 1:
				WorldData.set_city_citizen_task_phase(
					citizen_id,
					WorldData.CITY_CITIZEN_TASK_PHASE_PERFORMING
				)
				return path_requests_remaining

			if not WorldData.assign_city_citizen_movement_order(
				citizen_id,
				movement_path
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			WorldData.set_city_citizen_task_phase(
				citizen_id,
				WorldData.CITY_CITIZEN_TASK_PHASE_TRAVELING
			)

		WorldData.CITY_CITIZEN_TASK_PHASE_TRAVELING:
			if (
				movement_state
				== WorldData.CITY_CITIZEN_MOVEMENT_STATE_BLOCKED
			):
				_set_work_task_blocked(citizen_id)
			elif (
				movement_state
				== WorldData.CITY_CITIZEN_MOVEMENT_STATE_IDLE
			):
				var target_tile: Vector2i = current_task.get(
					"target_tile",
					WorldData.INVALID_CITY_TILE_POSITION
				)

				if (
					activity_tiles.has(current_tile)
					and current_tile == target_tile
				):
					var previous_target_tile: Vector2i = (
						current_task.get(
							"previous_target_tile",
							WorldData.INVALID_CITY_TILE_POSITION
						)
					)

					if not _begin_work_activity_dwell(
						citizen_id,
						workplace_id,
						current_tile,
						previous_target_tile,
						tick_index,
						dwell_min_minutes,
						dwell_max_minutes,
						relocation_count,
						maximum_relocations_per_task
					):
						_set_work_task_blocked(citizen_id)
				else:
					_set_work_task_blocked(citizen_id)

		WorldData.CITY_CITIZEN_TASK_PHASE_PERFORMING:
			if not WorldData.is_city_citizen_attending_workplace(
				citizen_id,
				workplace_id,
				city_world
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if (
				workplace_movement_mode
				!= WorldData.WORKPLACE_MOVEMENT_MODE_MOVE_BETWEEN_WORK_POINTS
			):
				return path_requests_remaining

			if relocation_count >= maximum_relocations_per_task:
				return path_requests_remaining

			var next_action_world_minute := int(
				current_task.get(
					"next_action_world_minute",
					WorldData
					.INVALID_CITY_CITIZEN_TASK_ACTION_WORLD_MINUTE
				)
			)

			if (
				next_action_world_minute
				== WorldData
				.INVALID_CITY_CITIZEN_TASK_ACTION_WORLD_MINUTE
			):
				if not _begin_work_activity_dwell(
					citizen_id,
					workplace_id,
					current_tile,
					current_task.get(
						"previous_target_tile",
						WorldData.INVALID_CITY_TILE_POSITION
					),
					tick_index,
					dwell_min_minutes,
					dwell_max_minutes,
					relocation_count,
					maximum_relocations_per_task
				):
					_set_work_task_blocked(citizen_id)

				return path_requests_remaining

			if (
				SimulationClock.absolute_world_minutes
				< next_action_world_minute
			):
				return path_requests_remaining

			if path_requests_remaining <= 0:
				return path_requests_remaining

			var previous_target_tile: Vector2i = (
				current_task.get(
					"previous_target_tile",
					WorldData.INVALID_CITY_TILE_POSITION
				)
			)
			var departing_tile := current_tile
			var new_target_tile := (
				CityActivityLocationResolverScript
				.choose_work_activity_tile(
					activity_tiles,
					current_tile,
					previous_target_tile,
					citizen_id,
					workplace_id,
					tick_index,
					minimum_relocation_distance,
					avoid_previous_target
				)
			)

			if (
				new_target_tile
				== WorldData.INVALID_CITY_TILE_POSITION
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if new_target_tile == current_tile:
				if not _begin_work_activity_dwell(
					citizen_id,
					workplace_id,
					current_tile,
					previous_target_tile,
					tick_index,
					dwell_min_minutes,
					dwell_max_minutes,
					relocation_count + 1,
					maximum_relocations_per_task
				):
					_set_work_task_blocked(citizen_id)

				return path_requests_remaining

			path_requests_remaining -= 1

			var relocation_path_result := (
				CityNavigationSystemScript
				.find_path_to_any_city_tile(
					city_world,
					current_tile,
					[new_target_tile],
					MAX_WORK_PATH_EXPANDED_NODES
				)
			)

			if not bool(
				relocation_path_result.get("success", false)
			):
				if not _begin_work_activity_dwell(
					citizen_id,
					workplace_id,
					current_tile,
					previous_target_tile,
					tick_index,
					dwell_min_minutes,
					dwell_max_minutes,
					relocation_count,
					maximum_relocations_per_task
				):
					_set_work_task_blocked(citizen_id)

				return path_requests_remaining

			var raw_relocation_path = (
				relocation_path_result.get("path", [])
			)

			if not raw_relocation_path is Array:
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			var relocation_path: Array = raw_relocation_path

			if relocation_path.size() <= 1:
				if not _begin_work_activity_dwell(
					citizen_id,
					workplace_id,
					current_tile,
					previous_target_tile,
					tick_index,
					dwell_min_minutes,
					dwell_max_minutes,
					relocation_count + 1,
					maximum_relocations_per_task
				):
					_set_work_task_blocked(citizen_id)

				return path_requests_remaining

			if not WorldData.set_city_citizen_task_activity_state(
				citizen_id,
				new_target_tile,
				departing_tile,
				WorldData
				.INVALID_CITY_CITIZEN_TASK_ACTION_WORLD_MINUTE,
				relocation_count + 1
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			if not WorldData.assign_city_citizen_movement_order(
				citizen_id,
				relocation_path
			):
				_set_work_task_blocked(citizen_id)
				return path_requests_remaining

			WorldData.set_city_citizen_task_phase(
				citizen_id,
				WorldData.CITY_CITIZEN_TASK_PHASE_TRAVELING
			)

		WorldData.CITY_CITIZEN_TASK_PHASE_BLOCKED:
			pass

		_:
			_set_work_task_blocked(citizen_id)

	return path_requests_remaining

static func _get_deterministic_dwell_minutes(
	citizen_id: int,
	workplace_id: int,
	choice_sequence: int,
	minimum_minutes: int,
	maximum_minutes: int
) -> int:
	if maximum_minutes <= minimum_minutes:
		return minimum_minutes

	var range_size := maximum_minutes - minimum_minutes + 1
	var deterministic_value := citizen_id * 73_856_093
	deterministic_value ^= workplace_id * 19_349_663
	deterministic_value ^= choice_sequence * 83_492_791
	deterministic_value &= 0x7fffffff

	return (
		minimum_minutes
		+ posmod(deterministic_value, range_size)
	)


static func _begin_work_activity_dwell(
	citizen_id: int,
	workplace_id: int,
	target_tile: Vector2i,
	previous_target_tile: Vector2i,
	choice_sequence: int,
	dwell_min_minutes: int,
	dwell_max_minutes: int,
	relocation_count: int,
	maximum_relocations_per_task: int
) -> bool:
	var next_action_world_minute := (
		WorldData.INVALID_CITY_CITIZEN_TASK_ACTION_WORLD_MINUTE
	)

	if relocation_count < maximum_relocations_per_task:
		var dwell_minutes := _get_deterministic_dwell_minutes(
			citizen_id,
			workplace_id,
			choice_sequence,
			dwell_min_minutes,
			dwell_max_minutes
		)
		next_action_world_minute = (
			SimulationClock.absolute_world_minutes
			+ dwell_minutes
		)

	if not WorldData.set_city_citizen_task_activity_state(
		citizen_id,
		target_tile,
		previous_target_tile,
		next_action_world_minute,
		relocation_count
	):
		return false

	return WorldData.set_city_citizen_task_phase(
		citizen_id,
		WorldData.CITY_CITIZEN_TASK_PHASE_PERFORMING
	)

static func _set_work_task_blocked(citizen_id: int) -> void:
	WorldData.set_city_citizen_task_phase(
		citizen_id,
		WorldData.CITY_CITIZEN_TASK_PHASE_BLOCKED
	)

static func _clear_invalid_task(citizen_id: int) -> void:
	WorldData.clear_city_citizen_task(
		citizen_id,
		WorldData.CITY_CITIZEN_TASK_SOURCE_PLAYER
	)
	WorldData.cancel_city_citizen_movement(citizen_id)
