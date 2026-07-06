extends Node2D

const TILE_SIZE := 8

enum ViewMode {
	BIOME,
	ELEVATION,
	TEMPERATURE,
	RAINFALL
}

var view_mode: ViewMode = ViewMode.BIOME

var world: WorldData
var generator := WorldGenerator.new()


func _ready():
	world = generator.generate_world()
	print("Generated world seed: ", world.seed)
	queue_redraw()


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			view_mode = ViewMode.BIOME
			print("View: Biome")
			queue_redraw()

		elif event.keycode == KEY_2:
			view_mode = ViewMode.ELEVATION
			print("View: Elevation")
			queue_redraw()

		elif event.keycode == KEY_3:
			view_mode = ViewMode.TEMPERATURE
			print("View: Temperature")
			queue_redraw()

		elif event.keycode == KEY_4:
			view_mode = ViewMode.RAINFALL
			print("View: Rainfall")
			queue_redraw()


func _draw():
	if world == null:
		return

	for y in range(world.height):
		for x in range(world.width):
			var tile := world.get_tile(x, y)
			var color := get_tile_color(tile)

			draw_rect(
				Rect2(
					x * TILE_SIZE,
					y * TILE_SIZE,
					TILE_SIZE,
					TILE_SIZE
				),
				color
			)


func get_tile_color(tile: Dictionary) -> Color:
	match view_mode:
		ViewMode.BIOME:
			return get_biome_color(tile)

		ViewMode.ELEVATION:
			return get_elevation_color(tile)

		ViewMode.TEMPERATURE:
			return get_temperature_color(tile)

		ViewMode.RAINFALL:
			return get_rainfall_color(tile)

	return Color.MAGENTA


func get_biome_color(tile: Dictionary) -> Color:
	var biome: String = tile["biome"]
	var elevation: float = tile["elevation"]

	match biome:
		WorldData.BIOME_OCEAN:
			if elevation < -0.35:
				return Color(0.01, 0.05, 0.28)
			return Color(0.0, 0.18, 0.65)

		WorldData.BIOME_MOUNTAIN:
			return Color(0.45, 0.42, 0.38)

		WorldData.BIOME_DESERT:
			return Color(0.86, 0.72, 0.36)

		WorldData.BIOME_PLAIN:
			return Color(0.18, 0.62, 0.20)

		WorldData.BIOME_FOREST:
			return Color(0.03, 0.32, 0.08)

		WorldData.BIOME_TUNDRA:
			return Color(0.58, 0.72, 0.58)

		WorldData.BIOME_TAIGA:
			return Color(0.05, 0.25, 0.16)

		WorldData.BIOME_JUNGLE:
			return Color(0.00, 0.45, 0.12)

	return Color.MAGENTA


func get_elevation_color(tile: Dictionary) -> Color:
	var elevation: float = tile["elevation"]
	var value: float = clamp((elevation + 1.0) / 2.0, 0.0, 1.0)

	return Color(value, value, value)


func get_temperature_color(tile: Dictionary) -> Color:
	var temperature: float = tile["temperature"]

	return Color(temperature, 0.1, 1.0 - temperature)


func get_rainfall_color(tile: Dictionary) -> Color:
	var rainfall: float = tile["rainfall"]

	return Color(0.05, rainfall, 1.0 - rainfall)
