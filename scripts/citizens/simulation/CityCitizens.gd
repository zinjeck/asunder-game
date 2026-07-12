extends RefCounted
class_name CityCitizens

# This script owns the intrinsic definition of one citizen record.
# WorldData continues to own the population collection, stable-ID indexes,
# city placement, housing, employment, and other city-level relationships.

const CITY_CITIZEN_SEX_MALE := "male"
const CITY_CITIZEN_SEX_FEMALE := "female"

const DEFAULT_CITIZEN_CARRY_CAPACITY := 10
const DEFAULT_CITIZEN_HUNGER := 100
const DEFAULT_CITIZEN_HAPPINESS := 70
const CITY_CITIZEN_STATE_IDLE := "idle"
const INVALID_CITY_TILE_POSITION := Vector2i(-1, -1)
# High-level citizen state and movement state intentionally remain separate.
# A citizen may later be working, hauling, or eating while its movement state
# independently describes whether it is walking between authoritative tiles.
const CITY_CITIZEN_MOVEMENT_STATE_IDLE := "idle"
const CITY_CITIZEN_MOVEMENT_STATE_MOVING := "moving"
const CITY_CITIZEN_MOVEMENT_STATE_BLOCKED := "blocked"

const CITY_CITIZEN_MOVEMENT_FAILURE_NONE := "none"
const CITY_CITIZEN_MOVEMENT_FAILURE_INVALID_PATH := "invalid_path"
const CITY_CITIZEN_MOVEMENT_FAILURE_NEXT_TILE_BLOCKED := (
	"next_tile_blocked"
)

const CITY_CITIZEN_MOVEMENT_PROGRESS_PER_TILE := 10_000
const DEFAULT_CITIZEN_MOVEMENT_SPEED_PER_MINUTE := 1_000

static var city_citizen_male_name_pool: Array[String] = [
	"Arlen",
	"Tovan",
	"Calen",
	"Ronan",
	"Darian",
	"Kael",
	"Bren",
	"Orin",
	"Levon",
	"Theron",
	"Jarek",
	"Corin",
	"Malric",
	"Edrin",
	"Tomas",
	"Varon",
	"Lucan",
	"Alric",
	"Fenric",
	"Soren",
	"Aldren",
	"Beran",
	"Cedran",
	"Doran",
	"Evren",
	"Garric",
	"Hadren",
	"Ivarn",
	"Joren",
	"Kellan",
	"Merek",
	"Nolan",
	"Odran",
	"Perric",
	"Roder",
	"Stellan",
	"Torren",
	"Ulren",
	"Wystan",
	"Yorick",
]

static var city_citizen_female_name_pool: Array[String] = [
	"Mira",
	"Elia",
	"Sera",
	"Nira",
	"Liora",
	"Kaela",
	"Maris",
	"Elara",
	"Vessa",
	"Talia",
	"Rina",
	"Anya",
	"Selene",
	"Maera",
	"Isolde",
	"Lyra",
	"Vela",
	"Seris",
	"Amara",
	"Coralie",
	"Aveline",
	"Briala",
	"Ceryn",
	"Delara",
	"Eirwen",
	"Fiora",
	"Giselle",
	"Halia",
	"Ilara",
	"Jessamine",
	"Kerra",
	"Lenora",
	"Mirelle",
	"Nerissa",
	"Odelle",
	"Petra",
	"Roselyn",
	"Sabine",
	"Thalia",
	"Ysara",
]
static var city_citizen_unassigned_name_pool: Array[String] = []

static func get_city_citizen_movement_state_types() -> Array[String]:
	return [
		CITY_CITIZEN_MOVEMENT_STATE_IDLE,
		CITY_CITIZEN_MOVEMENT_STATE_MOVING,
		CITY_CITIZEN_MOVEMENT_STATE_BLOCKED
	]

static func is_valid_city_citizen_movement_state(
	movement_state: String
) -> bool:
	return get_city_citizen_movement_state_types().has(
		movement_state
	)


static func get_city_citizen_movement_failure_types() -> Array[String]:
	return [
		CITY_CITIZEN_MOVEMENT_FAILURE_NONE,
		CITY_CITIZEN_MOVEMENT_FAILURE_INVALID_PATH,
		CITY_CITIZEN_MOVEMENT_FAILURE_NEXT_TILE_BLOCKED
	]


static func is_valid_city_citizen_movement_failure(
	failure_reason: String
) -> bool:
	return get_city_citizen_movement_failure_types().has(
		failure_reason
	)


static func has_complete_city_citizen_movement_state(
	citizen: Dictionary
) -> bool:
	return (
		citizen.has("movement_state")
		and citizen.has("movement_path")
		and citizen.has("movement_path_index")
		and citizen.has("movement_progress_basis_points")
		and citizen.has("movement_destination_tile")
		and citizen.has("movement_speed_basis_points_per_minute")
		and citizen.has("movement_failure_reason")
	)


static func reset_city_citizen_movement_state(
	citizen: Dictionary,
	preserve_movement_speed: bool = false
) -> void:
	var movement_speed := (
		DEFAULT_CITIZEN_MOVEMENT_SPEED_PER_MINUTE
	)

	if preserve_movement_speed:
		var stored_movement_speed := int(
			citizen.get(
				"movement_speed_basis_points_per_minute",
				movement_speed
			)
		)

		if stored_movement_speed > 0:
			movement_speed = stored_movement_speed

	citizen["movement_state"] = (
		CITY_CITIZEN_MOVEMENT_STATE_IDLE
	)
	citizen["movement_path"] = []
	citizen["movement_path_index"] = 0
	citizen["movement_progress_basis_points"] = 0
	citizen["movement_destination_tile"] = (
		INVALID_CITY_TILE_POSITION
	)
	citizen["movement_speed_basis_points_per_minute"] = (
		movement_speed
	)
	citizen["movement_failure_reason"] = (
		CITY_CITIZEN_MOVEMENT_FAILURE_NONE
	)

static func normalize_city_citizen_sex(
	citizen_sex: String
) -> String:
	return citizen_sex.strip_edges().to_lower()


static func is_valid_city_citizen_sex(
	citizen_sex: String
) -> bool:
	var normalized_sex := normalize_city_citizen_sex(
		citizen_sex
	)

	return (
		normalized_sex == CITY_CITIZEN_SEX_MALE
		or normalized_sex == CITY_CITIZEN_SEX_FEMALE
	)


static func get_city_citizen_sex_types() -> Array[String]:
	return [
		CITY_CITIZEN_SEX_MALE,
		CITY_CITIZEN_SEX_FEMALE
	]


static func get_city_citizen_sex_display_name(
	citizen_sex: String
) -> String:
	match normalize_city_citizen_sex(citizen_sex):
		CITY_CITIZEN_SEX_MALE:
			return "Male"

		CITY_CITIZEN_SEX_FEMALE:
			return "Female"

	return "Unknown"


static func get_city_citizen_name_pool_for_sex(
	citizen_sex: String
) -> Array[String]:
	match normalize_city_citizen_sex(citizen_sex):
		CITY_CITIZEN_SEX_MALE:
			return city_citizen_male_name_pool.duplicate()

		CITY_CITIZEN_SEX_FEMALE:
			return city_citizen_female_name_pool.duplicate()

	return []


static func city_citizen_name_pools_are_ready() -> bool:
	if city_citizen_male_name_pool.is_empty():
		return false

	if city_citizen_female_name_pool.is_empty():
		return false

	if not city_citizen_unassigned_name_pool.is_empty():
		return false

	var used_name_keys: Dictionary = {}

	for raw_name in city_citizen_male_name_pool:
		var name := str(raw_name)
		var clean_name := name.strip_edges()
		var name_key := clean_name.to_lower()

		if clean_name.is_empty():
			return false

		if clean_name != name:
			return false

		if used_name_keys.has(name_key):
			return false

		used_name_keys[name_key] = CITY_CITIZEN_SEX_MALE

	for raw_name in city_citizen_female_name_pool:
		var name := str(raw_name)
		var clean_name := name.strip_edges()
		var name_key := clean_name.to_lower()

		if clean_name.is_empty():
			return false

		if clean_name != name:
			return false

		if used_name_keys.has(name_key):
			return false

		used_name_keys[name_key] = CITY_CITIZEN_SEX_FEMALE

	return true


static func get_used_city_citizen_name_counts(
	existing_citizens: Array
) -> Dictionary:
	var used_name_counts := {}

	for raw_citizen in existing_citizens:
		if not raw_citizen is Dictionary:
			continue

		var citizen: Dictionary = raw_citizen
		var citizen_name := str(
			citizen.get("name", "")
		).strip_edges()

		if citizen_name.is_empty():
			continue

		used_name_counts[citizen_name] = int(
			used_name_counts.get(citizen_name, 0)
		) + 1

	return used_name_counts


static func make_random_city_citizen_first_name(
	citizen_sex: String,
	citizen_number: int,
	name_seed: int,
	existing_citizens: Array
) -> String:
	var normalized_sex := normalize_city_citizen_sex(
		citizen_sex
	)

	if not is_valid_city_citizen_sex(normalized_sex):
		return ""

	var source_name_pool := get_city_citizen_name_pool_for_sex(
		normalized_sex
	)

	if source_name_pool.is_empty():
		return ""

	var used_name_counts := get_used_city_citizen_name_counts(
		existing_citizens
	)
	var available_names: Array[String] = []

	for raw_name in source_name_pool:
		var candidate_name := str(raw_name).strip_edges()

		if candidate_name.is_empty():
			continue

		if used_name_counts.has(candidate_name):
			continue

		available_names.append(candidate_name)

	var candidate_pool: Array[String] = available_names

	# Names may repeat after every unique name in the appropriate
	# pool has been used. Family names can solve this later.
	if candidate_pool.is_empty():
		candidate_pool = source_name_pool

	if candidate_pool.is_empty():
		return ""

	var resolved_citizen_number := citizen_number

	if resolved_citizen_number <= 0:
		resolved_citizen_number = existing_citizens.size() + 1

	var sex_seed_offset := 0

	if normalized_sex == CITY_CITIZEN_SEX_MALE:
		sex_seed_offset = 104_729
	else:
		sex_seed_offset = 130_363

	var rng := RandomNumberGenerator.new()
	var population_number := existing_citizens.size()

	rng.seed = int(
		abs(
			name_seed * 1_000_003
			+ resolved_citizen_number * 9_176
			+ population_number * 6_113
			+ sex_seed_offset
			+ 1_337
		)
	)

	var random_index := rng.randi_range(
		0,
		candidate_pool.size() - 1
	)

	return str(candidate_pool[random_index]).strip_edges()


static func make_city_citizen(
	values: Dictionary
) -> Dictionary:
	var citizen_id := int(values.get("id", -1))

	if citizen_id <= 0:
		push_error(
			"Cannot create city citizen without a valid positive ID."
		)
		return {}

	var normalized_sex := normalize_city_citizen_sex(
		str(values.get("sex", ""))
	)

	if not is_valid_city_citizen_sex(normalized_sex):
		push_error(
			"Cannot create city citizen with invalid sex '"
			+ str(values.get("sex", ""))
			+ "'."
		)
		return {}

	var existing_citizens: Array = []
	var raw_existing_citizens = values.get(
		"existing_citizens",
		[]
	)

	if raw_existing_citizens is Array:
		existing_citizens = raw_existing_citizens

	var citizen_name := str(
		values.get("display_name", "")
	).strip_edges()

	if citizen_name.is_empty():
		citizen_name = make_random_city_citizen_first_name(
			normalized_sex,
			citizen_id,
			int(values.get("name_seed", 12345)),
			existing_citizens
		)

	if citizen_name.is_empty():
		push_error(
			"Cannot create "
			+ normalized_sex
			+ " citizen because its name pool "
			+ "contains no usable names."
		)
		return {}

	var allowed_name_pool := get_city_citizen_name_pool_for_sex(
		normalized_sex
	)

	if not allowed_name_pool.has(citizen_name):
		push_error(
			"Cannot assign name '"
			+ citizen_name
			+ "' to "
			+ normalized_sex
			+ " citizen because it is absent "
			+ "from that sex's name pool."
		)
		return {}

	var city_tile_position := INVALID_CITY_TILE_POSITION
	var raw_city_tile_position = values.get(
		"city_tile_position",
		INVALID_CITY_TILE_POSITION
	)

	if raw_city_tile_position is Vector2i:
		city_tile_position = raw_city_tile_position

	var inventory: Dictionary = {}
	var raw_inventory = values.get("inventory", {})

	if raw_inventory is Dictionary:
		inventory = raw_inventory.duplicate(true)

	var citizen := {
		"id": citizen_id,
		"name": citizen_name,
		"sex": normalized_sex,
		"alive": true,
		"hunger": DEFAULT_CITIZEN_HUNGER,
		"happiness": DEFAULT_CITIZEN_HAPPINESS,
		"home_object_id": -1,
		"job_object_id": -1,
		"state": CITY_CITIZEN_STATE_IDLE,
		"city_tile_position": city_tile_position,
		"carry_capacity": DEFAULT_CITIZEN_CARRY_CAPACITY,
		"inventory": inventory
	}

	reset_city_citizen_movement_state(citizen)
	return citizen
