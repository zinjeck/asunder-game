extends RefCounted
class_name CityActivityLocationResolver

const WorkplaceProductionSystemScript = preload(
	"res://scripts/city/simulation/systems/WorkplaceProductionSystem.gd"
)

const CARDINAL_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]
# This resolver answers only:
# "Which tiles are legal candidate locations for this activity?"
#
# It does not assign tasks, choose schedules, move citizens, reserve tiles,
# produce resources, or render anything.

static func get_work_activity_tiles(
	city_world: WorldData,
	workplace: Dictionary
) -> Array[Vector2i]:
	var activity_tiles: Array[Vector2i] = []

	if (
		city_world == null
		or workplace.is_empty()
		or not WorldData.city_object_is_workplace(workplace)
	):
		return activity_tiles

	var location_policy := (
		WorldData.get_city_object_work_location_policy(
			workplace
		)
	)
	var location_mode := str(
		location_policy.get(
			"mode",
			WorldData.WORKPLACE_WORK_LOCATION_MODE_NONE
		)
	)

	match location_mode:
		WorldData.WORKPLACE_WORK_LOCATION_MODE_RESOURCE_SOURCE_TILES:
			activity_tiles = _get_resource_source_zone_tiles(
				city_world,
				workplace
			)

		WorldData.WORKPLACE_WORK_LOCATION_MODE_LINKED_TILES:
			activity_tiles = _get_exterior_access_tiles(
				city_world,
				workplace
			)

		WorldData.WORKPLACE_WORK_LOCATION_MODE_WORKSTATIONS:
			activity_tiles = _get_exterior_access_tiles(
				city_world,
				workplace
			)

		WorldData.WORKPLACE_WORK_LOCATION_MODE_EXPLICIT_POINTS:
			activity_tiles = _get_exterior_access_tiles(
				city_world,
				workplace
			)

		WorldData.WORKPLACE_WORK_LOCATION_MODE_FOOTPRINT:
			# Contextual interior traversal has not been enabled yet.
			activity_tiles = _get_exterior_access_tiles(
				city_world,
				workplace
			)

		_:
			activity_tiles = _get_exterior_access_tiles(
				city_world,
				workplace
			)

	activity_tiles = _filter_activity_tiles_by_policy(
		city_world,
		activity_tiles,
		location_policy
	)

	_sort_and_deduplicate_tiles(activity_tiles)
	return activity_tiles

static func _get_resource_source_zone_tiles(
	city_world: WorldData,
	workplace: Dictionary
) -> Array[Vector2i]:
	var activity_tiles: Array[Vector2i] = []
	var source_evaluation := (
		WorkplaceProductionSystemScript
		.get_resource_source_evaluation(
			workplace,
			city_world
		)
	)
	var raw_zone_tiles = source_evaluation.get(
		"zone_tiles",
		[]
	)

	if not raw_zone_tiles is Array:
		return activity_tiles

	for raw_tile in raw_zone_tiles:
		if raw_tile is Vector2i:
			activity_tiles.append(raw_tile)

	return activity_tiles


static func _filter_activity_tiles_by_policy(
	city_world: WorldData,
	candidate_tiles: Array[Vector2i],
	location_policy: Dictionary
) -> Array[Vector2i]:
	var filtered_tiles: Array[Vector2i] = []
	var standing_tile_requirement := str(
		location_policy.get(
			"standing_tile_requirement",
			""
		)
	)
	var adjacency_mode := str(
		location_policy.get(
			"adjacency_mode",
			WorldData.WORKPLACE_WORK_LOCATION_ADJACENCY_NONE
		)
	)
	var adjacent_terrain := str(
		location_policy.get("adjacent_terrain", "")
	)

	for candidate_tile in candidate_tiles:
		if (
			standing_tile_requirement
			== WorldData.WORKPLACE_WORK_LOCATION_TILE_REQUIREMENT_WALKABLE
			and not WorldData.is_city_tile_walkable_for_citizen(
				city_world,
				candidate_tile
			)
		):
			continue

		if (
			adjacency_mode
			== WorldData.WORKPLACE_WORK_LOCATION_ADJACENCY_CARDINAL_TERRAIN
			and not _tile_cardinally_borders_terrain(
				city_world,
				candidate_tile,
				adjacent_terrain
			)
		):
			continue

		filtered_tiles.append(candidate_tile)

	return filtered_tiles


static func _tile_cardinally_borders_terrain(
	city_world: WorldData,
	tile_position: Vector2i,
	required_terrain: String
) -> bool:
	if required_terrain.is_empty():
		return false

	for neighbor_offset in CARDINAL_NEIGHBOR_OFFSETS:
		var neighbor_tile := tile_position + neighbor_offset

		if not city_world.is_in_bounds(
			neighbor_tile.x,
			neighbor_tile.y
		):
			continue

		var tile_data: Dictionary = city_world.get_tile(
			neighbor_tile.x,
			neighbor_tile.y
		)

		if (
			str(tile_data.get("terrain", ""))
			== required_terrain
		):
			return true

	return false

static func choose_work_activity_tile(
	activity_tiles: Array[Vector2i],
	current_tile: Vector2i,
	previous_target_tile: Vector2i,
	citizen_id: int,
	workplace_id: int,
	choice_sequence: int,
	minimum_relocation_distance: int,
	avoid_previous_target: bool
) -> Vector2i:
	if activity_tiles.is_empty():
		return WorldData.INVALID_CITY_TILE_POSITION

	var preferred_tiles: Array[Vector2i] = []
	var fallback_tiles: Array[Vector2i] = []

	for candidate_tile in activity_tiles:
		if candidate_tile == current_tile:
			continue

		if (
			avoid_previous_target
			and candidate_tile == previous_target_tile
		):
			continue

		fallback_tiles.append(candidate_tile)

		var distance := (
			absi(candidate_tile.x - current_tile.x)
			+ absi(candidate_tile.y - current_tile.y)
		)

		if distance >= minimum_relocation_distance:
			preferred_tiles.append(candidate_tile)

	var selection_pool := preferred_tiles

	if selection_pool.is_empty():
		selection_pool = fallback_tiles

	if selection_pool.is_empty():
		# Staying in place is valid when no alternative exists.
		if activity_tiles.has(current_tile):
			return current_tile

		# The previous point may be the only reachable candidate.
		selection_pool = activity_tiles.duplicate()

	var deterministic_value := _make_deterministic_choice_value(
		citizen_id,
		workplace_id,
		choice_sequence
	)
	var selected_index := posmod(
		deterministic_value,
		selection_pool.size()
	)

	return selection_pool[selected_index]


static func _make_deterministic_choice_value(
	citizen_id: int,
	workplace_id: int,
	choice_sequence: int
) -> int:
	var value := citizen_id * 73_856_093
	value ^= workplace_id * 19_349_663
	value ^= choice_sequence * 83_492_791

	return value & 0x7fffffff

static func _get_exterior_access_tiles(
	city_world: WorldData,
	workplace: Dictionary
) -> Array[Vector2i]:
	var activity_tiles: Array[Vector2i] = []

	for raw_tile in WorldData.get_city_object_access_tiles(
		city_world,
		workplace
	):
		if not raw_tile is Vector2i:
			continue

		activity_tiles.append(raw_tile)

	return activity_tiles


static func _sort_and_deduplicate_tiles(
	activity_tiles: Array[Vector2i]
) -> void:
	var unique_tiles: Dictionary = {}

	for tile_position in activity_tiles:
		unique_tiles[tile_position] = true

	activity_tiles.clear()

	for raw_tile in unique_tiles.keys():
		if raw_tile is Vector2i:
			activity_tiles.append(raw_tile)

	activity_tiles.sort_custom(
		func(first_tile: Vector2i, second_tile: Vector2i) -> bool:
			if first_tile.y != second_tile.y:
				return first_tile.y < second_tile.y

			return first_tile.x < second_tile.x
	)
