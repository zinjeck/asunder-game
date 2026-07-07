extends RefCounted
class_name WorldData

const TERRAIN_WATER := "water"
const TERRAIN_LAND := "land"
const TERRAIN_MOUNTAIN := "mountain"

const BIOME_OCEAN := "ocean"
const BIOME_MOUNTAIN := "mountain"
const BIOME_DESERT := "desert"
const BIOME_PLAIN := "plain"
const BIOME_FOREST := "forest"
const BIOME_TUNDRA:= "tundra"
const BIOME_TAIGA := "taiga"
const BIOME_JUNGLE := "jungle"
const BIOME_RIVER := "river"

const RESOURCE_NONE := "none"
const RESOURCE_IRON := "iron"
const RESOURCE_COAL := "coal"
const RESOURCE_GOLD := "gold"
const RESOURCE_FISH := "fish"

var width: int
var height: int
var seed: int
var tiles := []


func setup(new_width: int, new_height: int, new_seed: int):
	width = new_width
	height = new_height
	seed = new_seed
	tiles.clear()

	for y in range(height):
		var row := []
#THE TILE DICTIONARY \/ \/ \/ \/ \/
		for x in range(width):
			row.append({
				"fertility": -1.0,
				"elevation": 0.0,
				"temperature": 0.0,
				"precipitation": 0.0,
				"terrain": TERRAIN_WATER,
				"biome": BIOME_OCEAN,
				"resource": RESOURCE_NONE,
				"is_land": false
			})

		tiles.append(row)


func get_tile(x: int, y: int) -> Dictionary:
	return tiles[y][x]


func set_tile(x: int, y: int, data: Dictionary):
	tiles[y][x] = data
