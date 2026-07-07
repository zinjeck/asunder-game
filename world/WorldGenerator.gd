extends RefCounted
class_name WorldGenerator

var world_seed: int = 0
var rng := RandomNumberGenerator.new()

var continent_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var precipitation_noise := FastNoiseLite.new()
var coastline_noise := FastNoiseLite.new()
var island_noise := FastNoiseLite.new()
var mountain_noise := FastNoiseLite.new()
var open_ocean_cache := {}
var continent_centers: Array[Dictionary] = []
var settings := MapSettings.new()


func generate_world(seed_override: int = 0) -> WorldData:
	if seed_override == 0:
		randomize()
		world_seed = randi()
	else:
		world_seed = seed_override

	rng.seed = world_seed

	var world := WorldData.new()
	world.setup(settings.width, settings.height, world_seed)

	setup_noise()

	generate_elevation(world)
	generate_temperature(world)
	generate_precipitation(world)
	assign_basic_terrain(world)
	assign_biomes(world)
	generate_rivers(world)
	assign_fertility(world)
	assign_resources(world)

	return world

func assign_biomes(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)

			var terrain: String = tile["terrain"]
			var elevation: float = tile["elevation"]
			var temperature: float = tile["temperature"]
			var precipitation: float = tile["precipitation"]
			var mountain_score: float = get_mountain_score(x, y, elevation)

			if terrain == WorldData.TERRAIN_WATER:
				tile["biome"] = WorldData.BIOME_OCEAN

			elif mountain_score > 0.62:
				tile["biome"] = WorldData.BIOME_MOUNTAIN

			elif temperature >= 0.62:
				if precipitation < 0.24:
					tile["biome"] = WorldData.BIOME_DESERT
				elif precipitation < 0.68:
					tile["biome"] = WorldData.BIOME_PLAIN
				else:
					tile["biome"] = WorldData.BIOME_JUNGLE

			elif temperature <= 0.34:
				if precipitation < 0.45:
					tile["biome"] = WorldData.BIOME_TUNDRA
				else:
					tile["biome"] = WorldData.BIOME_TAIGA

			else:
				if precipitation < 0.42:
					tile["biome"] = WorldData.BIOME_PLAIN
				else:
					tile["biome"] = WorldData.BIOME_FOREST

			world.set_tile(x, y, tile)

func get_mountain_score(x: int, y: int, elevation: float) -> float:
	var ridge: float = absf(mountain_noise.get_noise_2d(x, y))
	var elevation_bonus: float = clamp(elevation, 0.0, 1.0) * 0.55

	return ridge + elevation_bonus

func setup_noise():
	setup_continent_centers()

	continent_noise.seed = world_seed
	continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	continent_noise.frequency = 0.004
	continent_noise.fractal_octaves = 3
	continent_noise.fractal_gain = 0.45
	continent_noise.fractal_lacunarity = 2.0

	detail_noise.seed = world_seed + 9917
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.026
	detail_noise.fractal_octaves = 3
	detail_noise.fractal_gain = 0.46
	detail_noise.fractal_lacunarity = 2.15

	coastline_noise.seed = world_seed + 17771
	coastline_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coastline_noise.frequency = 0.085
	coastline_noise.fractal_octaves = 2
	coastline_noise.fractal_gain = 0.55
	coastline_noise.fractal_lacunarity = 2.4

	island_noise.seed = world_seed + 28891
	island_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	island_noise.frequency = 0.021
	island_noise.fractal_octaves = 4
	island_noise.fractal_gain = 0.52
	island_noise.fractal_lacunarity = 2.1

	mountain_noise.seed = world_seed + 73517
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	mountain_noise.frequency = 0.018
	mountain_noise.fractal_octaves = 4
	mountain_noise.fractal_gain = 0.58
	mountain_noise.fractal_lacunarity = 2.25

	precipitation_noise.seed = world_seed + 42113
	precipitation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	precipitation_noise.frequency = 0.025
	precipitation_noise.fractal_octaves = 4
	precipitation_noise.fractal_gain = 0.5
	precipitation_noise.fractal_lacunarity = 2.0

func setup_continent_centers():
	continent_centers.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var continent_count := rng.randi_range(3, 5)

	var slots := [
		Vector2(0.22, 0.24),
		Vector2(0.50, 0.22),
		Vector2(0.78, 0.25),
		Vector2(0.28, 0.70),
		Vector2(0.58, 0.66),
		Vector2(0.82, 0.70)
	]

	for i in range(slots.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var temp: Vector2 = slots[i]
		slots[i] = slots[swap_index]
		slots[swap_index] = temp

	for i in range(continent_count):
		var slot: Vector2 = slots[i]

		var position := Vector2(
			settings.width * clamp(slot.x + rng.randf_range(-0.08, 0.08), 0.14, 0.86),
			settings.height * clamp(slot.y + rng.randf_range(-0.08, 0.08), 0.14, 0.86)
		)

		continent_centers.append(create_continent(position, rng))

func add_ocean_gap_continents(rng: RandomNumberGenerator):
	var extra_count := rng.randi_range(1, 2)
	var added := 0
	var attempts := 0

	while added < extra_count and attempts < 80:
		attempts += 1

		var position := Vector2(
			rng.randf_range(settings.width * 0.12, settings.width * 0.88),
			rng.randf_range(settings.height * 0.12, settings.height * 0.88)
		)

		if not is_far_from_existing_continents(position):
			continue

		continent_centers.append(create_small_continent(position, rng))
		added += 1

func is_far_from_existing_continents(position: Vector2) -> bool:
	for continent in continent_centers:
		var existing_position: Vector2 = continent["position"]

		if position.distance_to(existing_position) < settings.width * 0.26:
			return false

	return true

func create_small_continent(position: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var lobes := []
	var lobe_count := rng.randi_range(4, 6)

	for l in range(lobe_count):
		lobes.append({
			"offset": Vector2(
				rng.randf_range(-settings.width * 0.10, settings.width * 0.10),
				rng.randf_range(-settings.height * 0.09, settings.height * 0.09)
			),
			"radius_x": rng.randf_range(settings.width * 0.050, settings.width * 0.115),
			"radius_y": rng.randf_range(settings.height * 0.050, settings.height * 0.115),
			"strength": rng.randf_range(0.46, 0.72),
			"angle": rng.randf_range(0.0, TAU)
		})

	return {
		"position": position,
		"lobes": lobes
	}

func generate_elevation(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var continent_core: float = get_continent_center_bias(x, y)
			var large_shape: float = continent_noise.get_noise_2d(x, y) * 0.14 * continent_core
			var regional_shape: float = detail_noise.get_noise_2d(x, y) * 0.11
			var coastline_breakup: float = get_coastline_breakup(x, y, continent_core)
			var island_value: float = get_island_value(x, y, continent_core)
			var edge_falloff: float = get_edge_falloff(x, y, world.width, world.height)

			var elevation: float = continent_core + large_shape + regional_shape + coastline_breakup + island_value - edge_falloff - 0.14

			var tile := world.get_tile(x, y)
			tile["elevation"] = elevation
			tile["is_land"] = elevation > settings.sea_level
			world.set_tile(x, y, tile)

func get_continent_center_bias(x: int, y: int) -> float:
	var strongest_bias := 0.0
	var position := Vector2(x, y)

	for continent in continent_centers:
		var continent_position: Vector2 = continent["position"]
		var lobes: Array = continent["lobes"]
		var continent_bias := 0.0

		for lobe in lobes:
			var lobe_center: Vector2 = continent_position + lobe["offset"]
			var radius_x: float = lobe["radius_x"]
			var radius_y: float = lobe["radius_y"]
			var strength: float = lobe["strength"]
			var angle: float = lobe["angle"]

			var offset := position - lobe_center
			var cos_a := cos(angle)
			var sin_a := sin(angle)

			var rotated_x := offset.x * cos_a - offset.y * sin_a
			var rotated_y := offset.x * sin_a + offset.y * cos_a

			var dx: float = absf(rotated_x) / radius_x
			var dy: float = absf(rotated_y) / radius_y

			var distance: float = pow(pow(dx, 1.35) + pow(dy, 1.35), 1.0 / 1.35)

			var bias: float = clamp(1.0 - distance, 0.0, 1.0)
			bias = pow(bias, 1.18) * strength

			continent_bias += bias

		strongest_bias = max(strongest_bias, continent_bias)

	return clamp(strongest_bias, 0.0, 1.05)

func get_coastline_breakup(x: int, y: int, continent_core: float) -> float:
	var noise_value: float = coastline_noise.get_noise_2d(x, y)

	if continent_core > 0.62:
		return noise_value * 0.025

	if continent_core > 0.18:
		return noise_value * 0.18

	return noise_value * 0.045

func get_island_value(x: int, y: int, continent_core: float) -> float:
	if continent_core > 0.14:
		return 0.0

	var value: float = island_noise.get_noise_2d(x, y)

	if value > 0.50:
		return (value - 0.50) * 1.35

	return 0.0

func get_edge_falloff(x: int, y: int, width: int, height: int) -> float:
	var nx: float = absf((float(x) / float(width - 1)) * 2.0 - 1.0)
	var ny: float = absf((float(y) / float(height - 1)) * 2.0 - 1.0)

	var distance_from_center: float = max(nx, ny)

	return pow(distance_from_center, 7.0) * 0.95

func generate_temperature(world: WorldData):
	for y in range(world.height):
		var latitude: float = float(y) / float(world.height - 1)

		for x in range(world.width):
			var elevation: float = world.get_tile(x, y)["elevation"]
			var base_temperature: float = get_temperature_from_latitude(latitude)

			var elevation_cooling: float = max(elevation, 0.0) * 0.35
			var temperature: float = clamp(base_temperature - elevation_cooling, 0.0, 1.0)

			var tile := world.get_tile(x, y)
			tile["temperature"] = temperature
			world.set_tile(x, y, tile)


func generate_precipitation(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var noise_value: float = precipitation_noise.get_noise_2d(x, y)
			var precipitation: float = (noise_value + 1.0) / 2.0

			var tile := world.get_tile(x, y)
			tile["precipitation"] = precipitation
			world.set_tile(x, y, tile)


func assign_basic_terrain(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)
			var elevation: float = tile["elevation"]

			if elevation <= settings.sea_level:
				tile["terrain"] = WorldData.TERRAIN_WATER
			elif elevation >= settings.mountain_level:
				tile["terrain"] = WorldData.TERRAIN_MOUNTAIN
			else:
				tile["terrain"] = WorldData.TERRAIN_LAND

			world.set_tile(x, y, tile)


func get_temperature_from_latitude(latitude: float) -> float:
	var distance_from_equator: float = absf(latitude - 0.5) * 2.0
	return 1.0 - distance_from_equator

func assign_resources(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)

			tile["resource"] = WorldData.RESOURCE_NONE

			if is_coastal_water(world, x, y):
				if rng.randf() < 0.28:
					tile["resource"] = WorldData.RESOURCE_FISH

			elif is_mountain_or_near_mountain(world, x, y):
				var roll := rng.randf()

				if roll < 0.001:
					tile["resource"] = WorldData.RESOURCE_GOLD
				elif roll < 0.020:
					tile["resource"] = WorldData.RESOURCE_IRON
				elif roll < 0.052:
					tile["resource"] = WorldData.RESOURCE_COAL

			elif tile["terrain"] != WorldData.TERRAIN_WATER:
				var scattered_roll := rng.randf()

				if scattered_roll < 0.003:
					tile["resource"] = WorldData.RESOURCE_IRON
				elif scattered_roll < 0.008:
					tile["resource"] = WorldData.RESOURCE_COAL

			world.set_tile(x, y, tile)


func is_coastal_water(world: WorldData, x: int, y: int) -> bool:
	var tile := world.get_tile(x, y)

	if tile["terrain"] != WorldData.TERRAIN_WATER:
		return false

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx := x + ox
			var ny := y + oy

			if nx < 0 or ny < 0 or nx >= world.width or ny >= world.height:
				continue

			var neighbor := world.get_tile(nx, ny)

			if neighbor["terrain"] == WorldData.TERRAIN_LAND or neighbor["terrain"] == WorldData.TERRAIN_MOUNTAIN:
				return true

	return false


func is_mountain_or_near_mountain(world: WorldData, x: int, y: int) -> bool:
	var tile := world.get_tile(x, y)

	if tile["terrain"] == WorldData.TERRAIN_WATER:
		return false

	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var nx := x + ox
			var ny := y + oy

			if nx < 0 or ny < 0 or nx >= world.width or ny >= world.height:
				continue

			var neighbor := world.get_tile(nx, ny)

			if neighbor["biome"] == WorldData.BIOME_MOUNTAIN:
				return true

	return false

func generate_rivers(world: WorldData):
	open_ocean_cache.clear()

	var max_rivers := rng.randi_range(10, 16)
	var attempts := 0
	var created := 0

	while created < max_rivers and attempts < 50000:
		attempts += 1

		var x := rng.randi_range(0, world.width - 1)
		var y := rng.randi_range(0, world.height - 1)
		var tile := world.get_tile(x, y)

		if tile["terrain"] == WorldData.TERRAIN_WATER:
			continue

		if tile["biome"] == WorldData.BIOME_MOUNTAIN:
			continue

		if tile["biome"] == WorldData.BIOME_DESERT:
			continue

		var valley_source := is_mountain_valley_source(world, x, y)

		if valley_source:
			if tile["elevation"] < 0.12:
				continue

			if rng.randf() > 0.90:
				continue
		else:
			if tile["elevation"] < 0.28:
				continue

			if rng.randf() > 0.18:
				continue

		if carve_river(world, x, y):
			created += 1

	print("Rivers created: ", created, " target: ", max_rivers, " attempts: ", attempts)
	
func is_mountain_valley_source(world: WorldData, x: int, y: int) -> bool:
	var tile := world.get_tile(x, y)

	if tile["biome"] == WorldData.BIOME_MOUNTAIN:
		return false

	if tile["terrain"] == WorldData.TERRAIN_WATER:
		return false

	var mountain_count := 0
	var land_passage_count := 0

	for oy in range(-2, 3):
		for ox in range(-2, 3):
			if ox == 0 and oy == 0:
				continue

			var nx := x + ox
			var ny := y + oy

			if nx < 0 or ny < 0 or nx >= world.width or ny >= world.height:
				continue

			var neighbor := world.get_tile(nx, ny)

			if neighbor["biome"] == WorldData.BIOME_MOUNTAIN:
				mountain_count += 1
			elif neighbor["terrain"] != WorldData.TERRAIN_WATER:
				land_passage_count += 1

	return mountain_count >= 3 and land_passage_count >= 5

func is_valid_river_mouth(world: WorldData, x: int, y: int) -> bool:
	var start := Vector2i(x, y)

	if open_ocean_cache.has(start):
		return open_ocean_cache[start]

	var result := ocean_body_reaches_map_edge(world, start)
	open_ocean_cache[start] = result

	return result

func ocean_body_reaches_map_edge(world: WorldData, start: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var visited := {}

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()

		if visited.has(current):
			continue

		visited[current] = true

		if current.x <= 0 or current.y <= 0 or current.x >= world.width - 1 or current.y >= world.height - 1:
			return true

		var tile := world.get_tile(current.x, current.y)

		if tile["biome"] != WorldData.BIOME_OCEAN:
			continue

		var neighbors := [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]

		for neighbor in neighbors:
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= world.width or neighbor.y >= world.height:
				continue

			if visited.has(neighbor):
				continue

			var neighbor_tile := world.get_tile(neighbor.x, neighbor.y)

			if neighbor_tile["biome"] == WorldData.BIOME_OCEAN:
				queue.append(neighbor)

	return false

func create_continent(position: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var lobes := []
	var lobe_count := rng.randi_range(6, 9)

	for l in range(lobe_count):
		lobes.append({
			"offset": Vector2(
				rng.randf_range(-settings.width * 0.17, settings.width * 0.17),
				rng.randf_range(-settings.height * 0.15, settings.height * 0.15)
			),
			"radius_x": rng.randf_range(settings.width * 0.075, settings.width * 0.18),
			"radius_y": rng.randf_range(settings.height * 0.075, settings.height * 0.19),
			"strength": rng.randf_range(0.50, 0.86),
			"angle": rng.randf_range(0.0, TAU)
		})

	return {
		"position": position,
		"lobes": lobes
	}

func carve_river(world: WorldData, start_x: int, start_y: int) -> bool:
	var x := start_x
	var y := start_y
	var path: Array[Vector2i] = []
	var max_length := 500
	var ocean_direction := get_nearest_map_edge_direction(world, x, y)
	var reached_valid_water := false

	for i in range(max_length):
		if x < 0 or y < 0 or x >= world.width or y >= world.height:
			return false

		var current_position := Vector2i(x, y)

		if current_position in path:
			return false

		var tile := world.get_tile(x, y)

		if tile["biome"] == WorldData.BIOME_OCEAN:
			if is_valid_river_mouth(world, x, y):
				reached_valid_water = true
				break
			else:
				return false

		if tile["biome"] == WorldData.BIOME_RIVER:
			reached_valid_water = true
			break

		path.append(current_position)

		var next: Vector2i = get_river_neighbor(world, x, y, ocean_direction)

		if next == Vector2i(-1, -1):
			return false

		x = next.x
		y = next.y

	if reached_valid_water == false:
		return false

	if path.size() < 8:
		return false

	for point in path:
		var river_tile := world.get_tile(point.x, point.y)

		if river_tile["biome"] == WorldData.BIOME_OCEAN:
			continue

		river_tile["terrain"] = WorldData.TERRAIN_WATER
		river_tile["biome"] = WorldData.BIOME_RIVER
		river_tile["fertility"] = -1.0

		world.set_tile(point.x, point.y, river_tile)

	return true

func get_nearest_map_edge_direction(world: WorldData, x: int, y: int) -> Vector2i:
	var left_distance := x
	var right_distance := world.width - 1 - x
	var top_distance := y
	var bottom_distance := world.height - 1 - y

	var best_distance := left_distance
	var direction := Vector2i(-1, 0)

	if right_distance < best_distance:
		best_distance = right_distance
		direction = Vector2i(1, 0)

	if top_distance < best_distance:
		best_distance = top_distance
		direction = Vector2i(0, -1)

	if bottom_distance < best_distance:
		direction = Vector2i(0, 1)

	return direction

func get_river_neighbor(world: WorldData, x: int, y: int, ocean_direction: Vector2i) -> Vector2i:
	var best_position := Vector2i(-1, -1)
	var best_score := 999999.0

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx := x + ox
			var ny := y + oy

			if nx < 0 or ny < 0 or nx >= world.width or ny >= world.height:
				continue

			var neighbor := world.get_tile(nx, ny)

			if neighbor["biome"] == WorldData.BIOME_OCEAN:
				if is_valid_river_mouth(world, nx, ny):
					return Vector2i(nx, ny)
				else:
					continue

			var elevation_score: float = neighbor["elevation"] * 10.0
			var mountain_penalty := 0.0
			var direction_bonus := 0.0
			var meander_noise := rng.randf_range(-5.0, 5.0)

			if neighbor["biome"] == WorldData.BIOME_MOUNTAIN:
				mountain_penalty = 45.0

			if ox == ocean_direction.x and oy == ocean_direction.y:
				direction_bonus = -6.0

			if ox != 0 and oy != 0:
				meander_noise -= 1.5

			var score: float = elevation_score + mountain_penalty + direction_bonus + meander_noise

			if score < best_score:
				best_score = score
				best_position = Vector2i(nx, ny)

	return best_position

func assign_fertility(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)

			if tile["biome"] == WorldData.BIOME_OCEAN or tile["biome"] == WorldData.BIOME_RIVER:
				tile["fertility"] = -1.0
				world.set_tile(x, y, tile)
				continue

			var precipitation: float = tile["precipitation"]
			var biome: String = tile["biome"]

			var fertility := 0.0

			match biome:
				WorldData.BIOME_JUNGLE:
					fertility = 60.0 + precipitation * 30.0

				WorldData.BIOME_FOREST:
					fertility = 45.0 + precipitation * 20.0

				WorldData.BIOME_PLAIN:
					fertility = 42.0 + precipitation * 22.0

				WorldData.BIOME_TAIGA:
					fertility = 35.0 + precipitation * 18.0

				WorldData.BIOME_TUNDRA:
					fertility = 5.0 + precipitation * 25.0

				WorldData.BIOME_DESERT:
					fertility = precipitation * 28.0

				WorldData.BIOME_MOUNTAIN:
					fertility = precipitation * 22.0

			if is_near_river(world, x, y):
				if biome == WorldData.BIOME_PLAIN or biome == WorldData.BIOME_FOREST or biome == WorldData.BIOME_JUNGLE:
					fertility += 28.0
				else:
					fertility += 12.0

			if is_near_mountain_biome(world, x, y):
				if biome == WorldData.BIOME_PLAIN or biome == WorldData.BIOME_FOREST or biome == WorldData.BIOME_JUNGLE:
					fertility += 5.0

			tile["fertility"] = clamp(fertility, 0.0, 100.0)
			world.set_tile(x, y, tile)


func is_near_river(world: WorldData, x: int, y: int) -> bool:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx := x + ox
			var ny := y + oy

			if nx < 0 or ny < 0 or nx >= world.width or ny >= world.height:
				continue

			if world.get_tile(nx, ny)["biome"] == WorldData.BIOME_RIVER:
				return true

	return false


func is_near_mountain_biome(world: WorldData, x: int, y: int) -> bool:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx := x + ox
			var ny := y + oy

			if nx < 0 or ny < 0 or nx >= world.width or ny >= world.height:
				continue

			if world.get_tile(nx, ny)["biome"] == WorldData.BIOME_MOUNTAIN:
				return true

	return false
