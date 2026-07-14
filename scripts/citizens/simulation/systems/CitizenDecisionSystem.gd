extends RefCounted
class_name CitizenDecisionSystem

# Temporary shared schedule for the first autonomous work pass.
# These constants are intentionally centralized so the schedule can later be
# replaced by workplace, profession, household, or policy-driven schedules.
const WORK_SHIFT_START_MINUTE_OF_DAY: int = 8 * 60
const WORK_SHIFT_END_MINUTE_OF_DAY: int = 17 * 60
const SCHEDULED_WORK_TASK_PRIORITY: int = 100

const MAX_DECISIONS_PER_TICK: int = 32
const MAX_RECOVERY_SCANS_PER_TICK: int = 64

static var _pending_decision_ids: Array[int] = []
static var _pending_decision_id_lookup: Dictionary = {}
static var _runtime_initialized: bool = false
static var _work_shift_was_active: bool = false
static var _observed_assignment_version: int = -1
static var _recovery_scan_cursor: int = 0


static func run_tick(
	_tick_index: int,
	minutes_advanced: int
) -> void:
	if minutes_advanced <= 0:
		return

	if (
		WorldData.official_city_world == null
		or not WorldData.player_city_founded
		or WorldData.city_citizens.is_empty()
	):
		reset_runtime_state()
		return

	var work_shift_is_active := is_work_shift_active()

	if not _runtime_initialized:
		_runtime_initialized = true
		_work_shift_was_active = work_shift_is_active
		_observed_assignment_version = (
			WorldData.city_assignment_version
		)

		if work_shift_is_active:
			_queue_all_eligible_workers()
		else:
			_end_scheduled_work_tasks()
	elif work_shift_is_active != _work_shift_was_active:
		_work_shift_was_active = work_shift_is_active

		if work_shift_is_active:
			_queue_all_eligible_workers()
		else:
			_end_scheduled_work_tasks()

	if (
		_observed_assignment_version
		!= WorldData.city_assignment_version
	):
		_observed_assignment_version = (
			WorldData.city_assignment_version
		)

		if work_shift_is_active:
			_queue_all_eligible_workers()

	if not work_shift_is_active:
		_clear_decision_queue()
		return

	_queue_bounded_recovery_candidates()
	_process_decision_queue()


static func reset_runtime_state() -> void:
	_clear_decision_queue()
	_runtime_initialized = false
	_work_shift_was_active = false
	_observed_assignment_version = -1
	_recovery_scan_cursor = 0


static func is_work_shift_active() -> bool:
	var minute_of_day := (
		SimulationClock.get_world_hour() * 60
		+ SimulationClock.get_world_minute()
	)

	return (
		minute_of_day >= WORK_SHIFT_START_MINUTE_OF_DAY
		and minute_of_day < WORK_SHIFT_END_MINUTE_OF_DAY
	)


static func _queue_all_eligible_workers() -> void:
	for raw_citizen in WorldData.city_citizens:
		if not raw_citizen is Dictionary:
			continue

		var citizen: Dictionary = raw_citizen

		if not _citizen_needs_scheduled_work_task(citizen):
			continue

		_queue_citizen_id(
			int(citizen.get("id", -1))
		)

	_pending_decision_ids.sort()


static func _queue_bounded_recovery_candidates() -> void:
	var citizen_count := WorldData.city_citizens.size()

	if citizen_count <= 0:
		_recovery_scan_cursor = 0
		return

	var scan_count := mini(
		citizen_count,
		MAX_RECOVERY_SCANS_PER_TICK
	)

	for _scan_index in range(scan_count):
		var citizen_index := (
			_recovery_scan_cursor % citizen_count
		)
		_recovery_scan_cursor = (
			(_recovery_scan_cursor + 1) % citizen_count
		)

		var raw_citizen = WorldData.city_citizens[
			citizen_index
		]

		if not raw_citizen is Dictionary:
			continue

		var citizen: Dictionary = raw_citizen

		if not _citizen_needs_scheduled_work_task(citizen):
			continue

		_queue_citizen_id(
			int(citizen.get("id", -1))
		)

	_pending_decision_ids.sort()


static func _citizen_needs_scheduled_work_task(
	citizen: Dictionary
) -> bool:
	if not bool(citizen.get("alive", false)):
		return false

	var workplace_id := int(
		citizen.get("job_object_id", -1)
	)

	if workplace_id <= 0:
		return false

	var workplace := WorldData.get_city_object_by_id(
		workplace_id
	)

	if (
		workplace.is_empty()
		or not WorldData.city_object_is_workplace(workplace)
	):
		return false

	var raw_current_task = citizen.get("current_task", {})

	if not raw_current_task is Dictionary:
		return false

	var current_task: Dictionary = raw_current_task

	return (
		str(current_task.get("kind", ""))
		== WorldData.CITY_CITIZEN_TASK_KIND_NONE
	)


static func _queue_citizen_id(citizen_id: int) -> void:
	if citizen_id <= 0:
		return

	if _pending_decision_id_lookup.has(citizen_id):
		return

	_pending_decision_ids.append(citizen_id)
	_pending_decision_id_lookup[citizen_id] = true


static func _process_decision_queue() -> void:
	var processed_count := 0

	while (
		processed_count < MAX_DECISIONS_PER_TICK
		and not _pending_decision_ids.is_empty()
	):
		var citizen_id: int = _pending_decision_ids.pop_front()
		_pending_decision_id_lookup.erase(citizen_id)
		processed_count += 1

		var citizen := WorldData.get_city_citizen_by_id(
			citizen_id
		)

		if not _citizen_needs_scheduled_work_task(citizen):
			continue

		var workplace_id := int(
			citizen.get("job_object_id", -1)
		)

		WorldData.assign_city_citizen_task(
			citizen_id,
			{
				"kind": WorldData.CITY_CITIZEN_TASK_KIND_WORK,
				"source": WorldData.CITY_CITIZEN_TASK_SOURCE_SCHEDULE,
				"priority": SCHEDULED_WORK_TASK_PRIORITY,
				"target_object_id": workplace_id,
				"player_locked": false
			}
		)


static func _end_scheduled_work_tasks() -> void:
	_clear_decision_queue()

	for raw_citizen in WorldData.city_citizens:
		if not raw_citizen is Dictionary:
			continue

		var citizen: Dictionary = raw_citizen
		var raw_current_task = citizen.get("current_task", {})

		if not raw_current_task is Dictionary:
			continue

		var current_task: Dictionary = raw_current_task

		if (
			str(current_task.get("kind", ""))
			!= WorldData.CITY_CITIZEN_TASK_KIND_WORK
		):
			continue

		if (
			str(current_task.get("source", ""))
			!= WorldData.CITY_CITIZEN_TASK_SOURCE_SCHEDULE
		):
			continue

		var citizen_id := int(citizen.get("id", -1))

		if citizen_id <= 0:
			continue

		if WorldData.clear_city_citizen_task(
			citizen_id,
			WorldData.CITY_CITIZEN_TASK_SOURCE_SCHEDULE
		):
			WorldData.cancel_city_citizen_movement(
				citizen_id
			)


static func _clear_decision_queue() -> void:
	_pending_decision_ids.clear()
	_pending_decision_id_lookup.clear()
