extends RefCounted

const WORK_UNITS_PER_WORKER_MINUTE: int = 1000
const PRODUCTIVITY_BASIS_POINTS_SCALE: int = 10000

const STATUS_INACTIVE := "inactive"
const STATUS_IDLE_NO_WORKERS := "idle_no_workers"
const STATUS_WORKING := "working"
const STATUS_BLOCKED_OUTPUT_FULL := "blocked_output_full"
const STATUS_BLOCKED_MISSING_INPUT := "blocked_missing_input"


static func run_tick(
	city_object_records: Array,
	citizen_records: Array,
	citizen_index_by_id: Dictionary,
	object_definitions: Dictionary,
	_tick_index: int,
	minutes_advanced: int
) -> Array:
	var production_results := []

	if minutes_advanced <= 0:
		return production_results

	for raw_city_object in city_object_records:
		if not raw_city_object is Dictionary:
			continue

		var city_object: Dictionary = raw_city_object
		var production_result := _make_workplace_production_result(
			city_object,
			citizen_records,
			citizen_index_by_id,
			object_definitions,
			minutes_advanced
		)

		if not production_result.is_empty():
			production_results.append(production_result)

	return production_results


static func _make_workplace_production_result(
	city_object: Dictionary,
	citizen_records: Array,
	citizen_index_by_id: Dictionary,
	object_definitions: Dictionary,
	minutes_advanced: int
) -> Dictionary:
	var object_id := int(city_object.get("id", -1))
	var object_type := str(city_object.get("type", ""))
	var raw_definition = object_definitions.get(object_type, {})

	if object_id < 0 or not raw_definition is Dictionary:
		return {}

	var definition: Dictionary = raw_definition

	if not (
		bool(city_object.get("is_workplace", false))
		or bool(definition.get("is_workplace", false))
	):
		return {}

	var raw_recipe = definition.get("production_recipe", {})

	if not raw_recipe is Dictionary:
		return {}

	var recipe: Dictionary = raw_recipe

	if recipe.is_empty():
		return {}

	var saved_progress := maxi(
		int(city_object.get("production_progress_work_units", 0)),
		0
	)
	var productive_worker_count := _count_productive_workers(
		city_object,
		citizen_records,
		citizen_index_by_id
	)

	if productive_worker_count <= 0:
		return _make_runtime_result(
			object_id,
			saved_progress,
			STATUS_IDLE_NO_WORKERS,
			0
		)

	var work_units_per_batch := int(
		recipe.get("work_units_per_batch", 0)
	)
	var raw_outputs = recipe.get("outputs", {})
	var raw_inputs = recipe.get("inputs", {})

	if (
		work_units_per_batch <= 0
		or not raw_outputs is Dictionary
		or not raw_inputs is Dictionary
	):
		return _make_runtime_result(
			object_id,
			saved_progress,
			STATUS_INACTIVE,
			productive_worker_count
		)

	var outputs: Dictionary = raw_outputs
	var inputs: Dictionary = raw_inputs

	if not _outputs_are_valid_for_workplace(
		definition,
		outputs
	):
		return _make_runtime_result(
			object_id,
			saved_progress,
			STATUS_INACTIVE,
			productive_worker_count
		)

	# Input-consuming recipes remain safely blocked until generic input
	# reservation and consumption are introduced.
	if not inputs.is_empty():
		return _make_runtime_result(
			object_id,
			saved_progress,
			STATUS_BLOCKED_MISSING_INPUT,
			productive_worker_count
		)

	# Completed batches are never retained invisibly as progress.
	var progress_work_units := mini(
		saved_progress,
		work_units_per_batch - 1
	)
	var output_capacity_batches := _get_output_capacity_batches(
		city_object,
		definition,
		outputs
	)

	if output_capacity_batches <= 0:
		return _make_runtime_result(
			object_id,
			progress_work_units,
			STATUS_BLOCKED_OUTPUT_FULL,
			productive_worker_count
		)

	var site_productivity_basis_points := maxi(
		int(city_object.get(
			"site_productivity_basis_points",
			PRODUCTIVITY_BASIS_POINTS_SCALE
		)),
		0
	)
	var work_units_earned := _calculate_work_units(
		productive_worker_count,
		minutes_advanced,
		site_productivity_basis_points
	)

	if work_units_earned <= 0:
		return _make_runtime_result(
			object_id,
			progress_work_units,
			STATUS_INACTIVE,
			productive_worker_count
		)

	var work_units_until_output_blocks := (
		output_capacity_batches * work_units_per_batch
		- progress_work_units
	)
	var applied_work_units := mini(
		work_units_earned,
		maxi(work_units_until_output_blocks, 0)
	)
	var total_progress_work_units := (
		progress_work_units
		+ applied_work_units
	)
	var completed_batches := int(
		total_progress_work_units / work_units_per_batch
	)
	var remaining_progress_work_units := (
		total_progress_work_units
		- completed_batches * work_units_per_batch
	)
	var remaining_output_capacity := (
		output_capacity_batches
		- completed_batches
	)
	var production_status := STATUS_WORKING

	if (
		applied_work_units < work_units_earned
		or remaining_output_capacity <= 0
	):
		production_status = STATUS_BLOCKED_OUTPUT_FULL

	var result := _make_runtime_result(
		object_id,
		remaining_progress_work_units,
		production_status,
		productive_worker_count
	)

	if completed_batches > 0:
		result["completed_batches"] = completed_batches
		result["outputs"] = outputs.duplicate(true)
		result["work_units_per_batch"] = work_units_per_batch
		result["total_progress_work_units"] = (
			total_progress_work_units
		)

	return result


static func _make_runtime_result(
	object_id: int,
	progress_work_units: int,
	production_status: String,
	productive_worker_count: int
) -> Dictionary:
	return {
		"object_id": object_id,
		"progress_work_units": maxi(progress_work_units, 0),
		"production_status": production_status,
		"productive_worker_count": maxi(
			productive_worker_count,
			0
		)
	}


static func _count_productive_workers(
	city_object: Dictionary,
	citizen_records: Array,
	citizen_index_by_id: Dictionary
) -> int:
	var object_id := int(city_object.get("id", -1))
	var raw_worker_ids = city_object.get("assigned_worker_ids", [])

	if object_id < 0 or not raw_worker_ids is Array:
		return 0

	var productive_worker_count := 0
	var seen_worker_ids: Dictionary = {}

	for raw_worker_id in raw_worker_ids:
		var worker_id := int(raw_worker_id)

		if worker_id < 0 or seen_worker_ids.has(worker_id):
			continue

		seen_worker_ids[worker_id] = true

		if _city_citizen_is_productive_worker(
			worker_id,
			object_id,
			citizen_records,
			citizen_index_by_id
		):
			productive_worker_count += 1

	return productive_worker_count


static func _city_citizen_is_productive_worker(
	citizen_id: int,
	workplace_id: int,
	citizen_records: Array,
	citizen_index_by_id: Dictionary
) -> bool:
	if not citizen_index_by_id.has(citizen_id):
		return false

	var citizen_index := int(citizen_index_by_id[citizen_id])

	if citizen_index < 0 or citizen_index >= citizen_records.size():
		return false

	var raw_citizen = citizen_records[citizen_index]

	if not raw_citizen is Dictionary:
		return false

	var citizen: Dictionary = raw_citizen

	if int(citizen.get("id", -1)) != citizen_id:
		return false

	if not bool(citizen.get("alive", true)):
		return false

	return int(citizen.get("job_object_id", -1)) == workplace_id


static func _outputs_are_valid_for_workplace(
	definition: Dictionary,
	outputs: Dictionary
) -> bool:
	if outputs.is_empty():
		return false

	var raw_storage_resources = definition.get(
		"storage_resources",
		[]
	)

	if not raw_storage_resources is Array:
		return false

	var storage_resources: Array = raw_storage_resources

	for raw_resource in outputs.keys():
		var raw_output_amount = outputs[raw_resource]
		var resource := str(raw_resource)

		if not raw_output_amount is int:
			return false

		if int(raw_output_amount) <= 0:
			return false

		if not storage_resources.has(resource):
			return false

	return int(
		definition.get("storage_capacity_per_resource", 0)
	) > 0


static func _get_output_capacity_batches(
	city_object: Dictionary,
	definition: Dictionary,
	outputs: Dictionary
) -> int:
	var storage_capacity := int(
		definition.get("storage_capacity_per_resource", 0)
	)

	if storage_capacity <= 0:
		return 0

	var raw_stored_resources = city_object.get(
		"stored_resources",
		{}
	)

	if not raw_stored_resources is Dictionary:
		return 0

	var stored_resources: Dictionary = raw_stored_resources
	var capacity_batches := -1

	for raw_resource in outputs.keys():
		var resource := str(raw_resource)
		var output_amount := int(outputs[raw_resource])
		var stored_amount := maxi(
			int(stored_resources.get(resource, 0)),
			0
		)
		var free_space := maxi(
			storage_capacity - stored_amount,
			0
		)
		var resource_capacity_batches := int(
			free_space / output_amount
		)

		if capacity_batches < 0:
			capacity_batches = resource_capacity_batches
		else:
			capacity_batches = mini(
				capacity_batches,
				resource_capacity_batches
			)

	return maxi(capacity_batches, 0)


static func _calculate_work_units(
	productive_worker_count: int,
	minutes_advanced: int,
	site_productivity_basis_points: int
) -> int:
	if (
		productive_worker_count <= 0
		or minutes_advanced <= 0
		or site_productivity_basis_points <= 0
	):
		return 0

	# Personal productivity remains 100% until citizen-specific modifiers
	# are introduced.
	var base_work_units := (
		productive_worker_count
		* minutes_advanced
		* WORK_UNITS_PER_WORKER_MINUTE
	)

	return int(
		(
			base_work_units
			* site_productivity_basis_points
		)
		/ PRODUCTIVITY_BASIS_POINTS_SCALE
	)
