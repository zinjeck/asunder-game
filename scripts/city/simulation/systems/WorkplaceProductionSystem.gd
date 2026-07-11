extends RefCounted
class_name WorkplaceProductionSystem

const WORK_UNITS_PER_WORKER_MINUTE: int = 1_000

# Read-only Phase 2D source evaluation.
# This currently reports environmental source geometry without changing
# site productivity or advancing production.
static func get_resource_source_evaluation(
	city_object: Dictionary
) -> Dictionary:
	var result := {
		"evaluated": false,
		"mode": WorldData.WORKPLACE_RESOURCE_SOURCE_MODE_NONE,
		"resource_type": WorldData.RESOURCE_NONE,
		"radius_tiles": 0,
		"anchor_position": Vector2.ZERO,
		"candidate_tile_count": 0,
		"valid_source_tile_count": 0,
		"source_density_basis_points": 0
	}

	if city_object.is_empty():
		return result

	var policy := WorldData.get_city_object_resource_source_policy(
		city_object
	)

	if policy.is_empty():
		return result

	var mode := str(
		policy.get(
			"mode",
			WorldData.WORKPLACE_RESOURCE_SOURCE_MODE_NONE
		)
	)

	result["mode"] = mode

	match mode:
		WorldData.WORKPLACE_RESOURCE_SOURCE_MODE_RADIUS:
			return _evaluate_radius_resource_source(
				city_object,
				policy,
				result
			)

		WorldData.WORKPLACE_RESOURCE_SOURCE_MODE_NONE:
			result["evaluated"] = true

	return result


static func _evaluate_radius_resource_source(
	city_object: Dictionary,
	policy: Dictionary,
	result: Dictionary
) -> Dictionary:
	var raw_resource_type = policy.get(
		"resource_type",
		WorldData.RESOURCE_NONE
	)
	var raw_radius_tiles = policy.get("radius_tiles", 0)
	var raw_anchor_mode = policy.get(
		"anchor_mode",
		WorldData.WORKPLACE_ANCHOR_MODE_FOOTPRINT_CENTER
	)

	if typeof(raw_resource_type) != TYPE_STRING:
		return result

	if typeof(raw_radius_tiles) != TYPE_INT:
		return result

	if typeof(raw_anchor_mode) != TYPE_STRING:
		return result

	var resource_type: String = raw_resource_type
	var radius_tiles: int = raw_radius_tiles
	var anchor_mode: String = raw_anchor_mode

	result["resource_type"] = resource_type
	result["radius_tiles"] = radius_tiles

	if radius_tiles <= 0:
		return result

	if not WorldData.get_city_resource_types().has(resource_type):
		return result

	if not WorldData.is_valid_workplace_anchor_mode(anchor_mode):
		return result

	var anchor_result := _get_workplace_source_anchor(
		city_object,
		anchor_mode
	)

	if not bool(anchor_result.get("valid", false)):
		return result

	var raw_source_world = WorldData.official_city_world

	if not raw_source_world is WorldData:
		return result

	var source_world: WorldData = raw_source_world

	if source_world.width <= 0 or source_world.height <= 0:
		return result

	var anchor_position: Vector2 = anchor_result.get(
		"position",
		Vector2.ZERO
	)
	var radius_distance := float(radius_tiles)
	var radius_squared := radius_distance * radius_distance

	result["anchor_position"] = anchor_position

	var minimum_x := maxi(
		int(floor(anchor_position.x - radius_distance)),
		0
	)
	var maximum_x := mini(
		int(ceil(anchor_position.x + radius_distance)),
		source_world.width - 1
	)
	var minimum_y := maxi(
		int(floor(anchor_position.y - radius_distance)),
		0
	)
	var maximum_y := mini(
		int(ceil(anchor_position.y + radius_distance)),
		source_world.height - 1
	)

	var candidate_tile_count := 0
	var valid_source_tile_count := 0

	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var tile_center := Vector2(
				float(x) + 0.5,
				float(y) + 0.5
			)

			if (
				tile_center.distance_squared_to(anchor_position)
				> radius_squared
			):
				continue

			candidate_tile_count += 1

			var tile: Dictionary = source_world.get_tile(x, y)

			if (
				str(
					tile.get(
						"resource",
						WorldData.RESOURCE_NONE
					)
				)
				== resource_type
			):
				valid_source_tile_count += 1

	var source_density_basis_points := 0

	if candidate_tile_count > 0:
		source_density_basis_points = clampi(
			int(
				round(
					float(valid_source_tile_count)
					* float(
						WorldData.PRODUCTIVITY_BASIS_POINTS_SCALE
					)
					/ float(candidate_tile_count)
				)
			),
			0,
			WorldData.PRODUCTIVITY_BASIS_POINTS_SCALE
		)

	result["candidate_tile_count"] = candidate_tile_count
	result["valid_source_tile_count"] = valid_source_tile_count
	result["source_density_basis_points"] = (
		source_density_basis_points
	)
	result["evaluated"] = true

	return result


static func _get_workplace_source_anchor(
	city_object: Dictionary,
	anchor_mode: String
) -> Dictionary:
	var result := {
		"valid": false,
		"position": Vector2.ZERO
	}

	if (
		anchor_mode
		!= WorldData.WORKPLACE_ANCHOR_MODE_FOOTPRINT_CENTER
	):
		return result

	var raw_top_left = city_object.get("top_left", null)
	var raw_size_tiles = city_object.get("size", null)

	if not raw_top_left is Vector2i:
		return result

	if not raw_size_tiles is Vector2i:
		return result

	var top_left: Vector2i = raw_top_left
	var size_tiles: Vector2i = raw_size_tiles

	if size_tiles.x <= 0 or size_tiles.y <= 0:
		return result

	result["position"] = Vector2(
		float(top_left.x) + float(size_tiles.x) * 0.5,
		float(top_left.y) + float(size_tiles.y) * 0.5
	)
	result["valid"] = true

	return result

static func get_estimated_output_per_hour(
	city_object: Dictionary,
	resource: String
) -> float:
	if city_object.is_empty():
		return 0.0

	if resource == WorldData.RESOURCE_NONE:
		return 0.0

	var recipe := WorldData.get_city_object_production_recipe(
		city_object
	)
	var raw_work_units_per_batch = recipe.get(
		"work_units_per_batch",
		0
	)
	var raw_outputs = recipe.get("outputs", {})

	if not raw_work_units_per_batch is int:
		return 0.0

	if int(raw_work_units_per_batch) <= 0:
		return 0.0

	if not raw_outputs is Dictionary:
		return 0.0

	var outputs: Dictionary = raw_outputs
	var raw_output_amount = outputs.get(resource, 0)

	if not raw_output_amount is int:
		return 0.0

	var output_amount_per_batch := int(raw_output_amount)

	if output_amount_per_batch <= 0:
		return 0.0

	var productive_worker_count := (
		WorldData.get_city_object_productive_worker_count(
			city_object
		)
	)
	var site_productivity := (
		WorldData.get_city_object_site_productivity_basis_points(
			city_object
		)
	)

	if productive_worker_count <= 0:
		return 0.0

	if site_productivity <= 0:
		return 0.0

	var effective_work_units_per_hour := (
		float(
			SimulationClock.MINUTES_PER_HOUR
			* productive_worker_count
			* WORK_UNITS_PER_WORKER_MINUTE
		)
		* float(site_productivity)
		/ float(WorldData.PRODUCTIVITY_BASIS_POINTS_SCALE)
	)

	var completed_batches_per_hour := (
		effective_work_units_per_hour
		/ float(raw_work_units_per_batch)
	)

	return (
		completed_batches_per_hour
		* float(output_amount_per_batch)
	)

static func run_tick(
	_tick_index: int,
	minutes_advanced: int
) -> void:
	if minutes_advanced <= 0:
		return

	if not WorldData.has_player_city():
		return

	for raw_city_object in WorldData.city_objects:
		if not raw_city_object is Dictionary:
			continue

		var city_object: Dictionary = raw_city_object

		if not WorldData.city_object_is_workplace(city_object):
			continue

		var recipe := WorldData.get_city_object_production_recipe(
			city_object
		)

		if recipe.is_empty():
			continue

		_run_workplace_tick(
			city_object,
			recipe,
			minutes_advanced
		)


static func _run_workplace_tick(
	city_object: Dictionary,
	recipe: Dictionary,
	minutes_advanced: int
) -> void:
	var object_id := int(city_object.get("id", -1))

	if object_id <= 0:
		return

	var current_progress := (
		WorldData.get_city_object_production_progress_work_units(
			city_object
		)
	)
	var site_productivity := (
		WorldData.get_city_object_site_productivity_basis_points(
			city_object
		)
	)
	var productive_worker_count := _get_productive_worker_count(
		city_object
	)

	var raw_work_units_per_batch = recipe.get(
		"work_units_per_batch",
		0
	)
	var outputs := _get_recipe_outputs(recipe)
	var raw_inputs = recipe.get("inputs", {})

	if (
		not raw_work_units_per_batch is int
		or int(raw_work_units_per_batch) <= 0
		or outputs.is_empty()
		or not raw_inputs is Dictionary
		or not _outputs_are_valid_for_workplace(
			city_object,
			outputs
		)
	):
		_write_workplace_state(
			object_id,
			0,
			WorldData.WORKPLACE_PRODUCTION_STATUS_INACTIVE,
			productive_worker_count,
			site_productivity
		)
		return

	var work_units_per_batch: int = raw_work_units_per_batch
	var inputs: Dictionary = raw_inputs

	if productive_worker_count <= 0:
		_write_workplace_state(
			object_id,
			current_progress,
			WorldData.WORKPLACE_PRODUCTION_STATUS_IDLE_NO_WORKERS,
			0,
			site_productivity
		)
		return

	# Input-consuming recipes fail closed until stored-input processing
	# is implemented. This prevents future recipes from creating free goods.
	if not inputs.is_empty():
		_write_workplace_state(
			object_id,
			current_progress,
			WorldData.WORKPLACE_PRODUCTION_STATUS_BLOCKED_MISSING_INPUT,
			productive_worker_count,
			site_productivity
		)
		return

	var output_capacity_in_batches := (
		_get_output_capacity_in_batches(
			city_object,
			outputs
		)
	)

	if output_capacity_in_batches <= 0:
		_write_workplace_state(
			object_id,
			current_progress,
			WorldData.WORKPLACE_PRODUCTION_STATUS_BLOCKED_OUTPUT_FULL,
			productive_worker_count,
			site_productivity
		)
		return

	var work_units_added := _calculate_work_units(
		minutes_advanced,
		productive_worker_count,
		site_productivity
	)

	if work_units_added <= 0:
		_write_workplace_state(
			object_id,
			current_progress,
			WorldData.WORKPLACE_PRODUCTION_STATUS_WORKING,
			productive_worker_count,
			site_productivity
		)
		return

	var total_progress := current_progress + work_units_added
	var potential_completed_batches := int(
		total_progress / work_units_per_batch
	)

	if potential_completed_batches <= 0:
		_write_workplace_state(
			object_id,
			total_progress,
			WorldData.WORKPLACE_PRODUCTION_STATUS_WORKING,
			productive_worker_count,
			site_productivity
		)
		return

	var batches_to_produce := mini(
		potential_completed_batches,
		output_capacity_in_batches
	)

	if not _store_recipe_outputs(
		object_id,
		outputs,
		batches_to_produce
	):
		push_error(
			"Workplace "
			+ str(object_id)
			+ " could not store its prevalidated production output."
		)

		_write_workplace_state(
			object_id,
			current_progress,
			WorldData.WORKPLACE_PRODUCTION_STATUS_BLOCKED_OUTPUT_FULL,
			productive_worker_count,
			site_productivity
		)
		return

	var new_progress := (
		total_progress
		- batches_to_produce * work_units_per_batch
	)

	# If this tick exhausted the available output capacity, workers stop
	# at that moment. Extra work from the rest of the tick is not banked
	# as an invisible completed-output backlog.
	if batches_to_produce >= output_capacity_in_batches:
		new_progress = 0

	var updated_city_object := WorldData.get_city_object_by_id(
		object_id
	)
	var remaining_output_capacity := (
		_get_output_capacity_in_batches(
			updated_city_object,
			outputs
		)
	)

	var new_status := (
		WorldData.WORKPLACE_PRODUCTION_STATUS_WORKING
	)

	if remaining_output_capacity <= 0:
		new_status = (
			WorldData.WORKPLACE_PRODUCTION_STATUS_BLOCKED_OUTPUT_FULL
		)

	_write_workplace_state(
		object_id,
		new_progress,
		new_status,
		productive_worker_count,
		site_productivity
	)


static func _get_productive_worker_count(
	city_object: Dictionary
) -> int:
	var workplace_id := int(city_object.get("id", -1))

	if workplace_id <= 0:
		return 0

	var productive_worker_count := 0
	var counted_worker_ids: Dictionary = {}

	for raw_worker_id in WorldData.get_city_object_worker_ids(
		city_object
	):
		var worker_id := int(raw_worker_id)

		if worker_id <= 0:
			continue

		if counted_worker_ids.has(worker_id):
			continue

		counted_worker_ids[worker_id] = true

		var citizen := WorldData.get_city_citizen_by_id(
			worker_id
		)

		if citizen.is_empty():
			continue

		if not bool(citizen.get("alive", false)):
			continue

		if int(citizen.get("job_object_id", -1)) != workplace_id:
			continue

		productive_worker_count += 1

	return mini(
		productive_worker_count,
		WorldData.get_city_object_worker_capacity(city_object)
	)


static func _get_recipe_outputs(
	recipe: Dictionary
) -> Dictionary:
	var raw_outputs = recipe.get("outputs", {})

	if not raw_outputs is Dictionary:
		return {}

	var outputs: Dictionary = raw_outputs
	return outputs


static func _outputs_are_valid_for_workplace(
	city_object: Dictionary,
	outputs: Dictionary
) -> bool:
	if outputs.is_empty():
		return false

	var known_resource_types := WorldData.get_city_resource_types()

	for raw_resource in outputs:
		var resource := str(raw_resource)
		var raw_amount_per_batch = outputs.get(raw_resource, 0)

		if resource == WorldData.RESOURCE_NONE:
			return false

		if not known_resource_types.has(resource):
			return false

		if not raw_amount_per_batch is int:
			return false

		if int(raw_amount_per_batch) <= 0:
			return false

		if not WorldData.can_city_object_store_resource(
			city_object,
			resource
		):
			return false

	return true


static func _get_output_capacity_in_batches(
	city_object: Dictionary,
	outputs: Dictionary
) -> int:
	if city_object.is_empty():
		return 0

	if outputs.is_empty():
		return 0

	var capacity_in_batches := -1

	for raw_resource in outputs:
		var resource := str(raw_resource)
		var amount_per_batch := int(
			outputs.get(raw_resource, 0)
		)

		if amount_per_batch <= 0:
			return 0

		var free_space := (
			WorldData.get_city_object_resource_free_space(
				city_object,
				resource
			)
		)
		var resource_capacity_in_batches := int(
			free_space / amount_per_batch
		)

		if (
			capacity_in_batches < 0
			or resource_capacity_in_batches < capacity_in_batches
		):
			capacity_in_batches = resource_capacity_in_batches

	return maxi(capacity_in_batches, 0)


static func _calculate_work_units(
	minutes_advanced: int,
	productive_worker_count: int,
	site_productivity_basis_points: int
) -> int:
	if minutes_advanced <= 0:
		return 0

	if productive_worker_count <= 0:
		return 0

	if site_productivity_basis_points <= 0:
		return 0

	var base_work_units: int = (
		minutes_advanced
		* productive_worker_count
		* WORK_UNITS_PER_WORKER_MINUTE
	)
	var adjusted_work_units_numerator: int = (
		base_work_units
		* site_productivity_basis_points
	)

	return maxi(
		int(
			adjusted_work_units_numerator
			/ WorldData.PRODUCTIVITY_BASIS_POINTS_SCALE
		),
		0
	)


static func _store_recipe_outputs(
	object_id: int,
	outputs: Dictionary,
	batch_count: int
) -> bool:
	if object_id <= 0:
		return false

	if batch_count <= 0:
		return false

	for raw_resource in outputs:
		var resource := str(raw_resource)
		var amount_per_batch := int(
			outputs.get(raw_resource, 0)
		)
		var requested_amount := (
			amount_per_batch
			* batch_count
		)
		var accepted_amount := (
			WorldData.add_resource_to_city_object_storage(
				object_id,
				resource,
				requested_amount
			)
		)

		if accepted_amount != requested_amount:
			return false

	return true


static func _write_workplace_state(
	object_id: int,
	progress_work_units: int,
	production_status: String,
	productive_worker_count: int,
	site_productivity_basis_points: int
) -> void:
	WorldData.set_city_workplace_production_state(
		object_id,
		progress_work_units,
		production_status,
		productive_worker_count,
		site_productivity_basis_points
	)
