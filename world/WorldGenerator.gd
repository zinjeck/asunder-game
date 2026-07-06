extends RefCounted
class_name WorldGenerator

const WORLD_WIDTH := 300
const WORLD_HEIGHT := 220

const SEA_LEVEL := 0.0
const MOUNTAIN_LEVEL := 0.58

var world_seed: int = 0

var continent_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var rainfall_noise := FastNoiseLite.new()


func generate_world(seed_override: int = 0) -> WorldData:
	if seed_override == 0:
		randomize()
		world_seed = randi()
	else:
		world_seed = seed_override

	var world := WorldData.new()
	world.setup(WORLD_WIDTH, WORLD_HEIGHT, world_seed)

	setup_noise()

	generate_elevation(world)
	generate_temperature(world)
	generate_rainfall(world)
	assign_basic_terrain(world)
	assign_biomes(world)

	return world

func assign_biomes(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)

			var terrain: String = tile["terrain"]
			var temperature: float = tile["temperature"]
			var rainfall: float = tile["rainfall"]

			if terrain == WorldData.TERRAIN_WATER:
				tile["biome"] = WorldData.BIOME_OCEAN

			elif terrain == WorldData.TERRAIN_MOUNTAIN:
				tile["biome"] = WorldData.BIOME_MOUNTAIN

			elif temperature >= 0.62:
				if rainfall < 0.24:
					tile["biome"] = WorldData.BIOME_DESERT
				elif rainfall < 0.52:
					tile["biome"] = WorldData.BIOME_PLAIN
				else:
					tile["biome"] = WorldData.BIOME_JUNGLE

			elif temperature <= 0.34:
				if rainfall < 0.45:
					tile["biome"] = WorldData.BIOME_TUNDRA
				else:
					tile["biome"] = WorldData.BIOME_TAIGA

			else:
				if rainfall < 0.42:
					tile["biome"] = WorldData.BIOME_PLAIN
				else:
					tile["biome"] = WorldData.BIOME_FOREST

			world.set_tile(x, y, tile)

func setup_noise():
	continent_noise.seed = world_seed
	continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	continent_noise.frequency = 0.012
	continent_noise.fractal_octaves = 5
	continent_noise.fractal_gain = 0.5
	continent_noise.fractal_lacunarity = 2.0

	detail_noise.seed = world_seed + 9917
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.045
	detail_noise.fractal_octaves = 3
	detail_noise.fractal_gain = 0.45
	detail_noise.fractal_lacunarity = 2.0

	rainfall_noise.seed = world_seed + 42113
	rainfall_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rainfall_noise.frequency = 0.025
	rainfall_noise.fractal_octaves = 4
	rainfall_noise.fractal_gain = 0.5
	rainfall_noise.fractal_lacunarity = 2.0


func generate_elevation(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var continent_value: float = continent_noise.get_noise_2d(x, y)
			var detail_value: float = detail_noise.get_noise_2d(x, y) * 0.25
			var edge_falloff: float = get_edge_falloff(x, y, world.width, world.height)

			var elevation: float = continent_value + detail_value - edge_falloff

			var tile := world.get_tile(x, y)
			tile["elevation"] = elevation
			tile["is_land"] = elevation > SEA_LEVEL
			world.set_tile(x, y, tile)


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


func generate_rainfall(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var noise_value: float = rainfall_noise.get_noise_2d(x, y)
			var rainfall: float = (noise_value + 1.0) / 2.0

			var tile := world.get_tile(x, y)
			tile["rainfall"] = rainfall
			world.set_tile(x, y, tile)


func assign_basic_terrain(world: WorldData):
	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)
			var elevation: float = tile["elevation"]

			if elevation <= SEA_LEVEL:
				tile["terrain"] = WorldData.TERRAIN_WATER
			elif elevation >= MOUNTAIN_LEVEL:
				tile["terrain"] = WorldData.TERRAIN_MOUNTAIN
			else:
				tile["terrain"] = WorldData.TERRAIN_LAND

			world.set_tile(x, y, tile)


func get_temperature_from_latitude(latitude: float) -> float:
	var distance_from_equator: float = absf(latitude - 0.5) * 2.0
	return 1.0 - distance_from_equator


func get_edge_falloff(x: int, y: int, width: int, height: int) -> float:
	var nx: float = absf((float(x) / float(width - 1)) * 2.0 - 1.0)
	var ny: float = absf((float(y) / float(height - 1)) * 2.0 - 1.0)

	var distance_from_center: float = max(nx, ny)

	return pow(distance_from_center, 3.0) * 1.15
