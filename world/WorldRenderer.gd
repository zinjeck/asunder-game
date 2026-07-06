extends Node2D

enum ViewMode {
	BIOME,
	ELEVATION,
	TEMPERATURE,
	RAINFALL,
	FERTILITY,
	RESOURCES
}

var view_mode: ViewMode = ViewMode.BIOME
var settings := MapSettings.new()
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
			
		elif event.keycode == KEY_5:
			view_mode = ViewMode.RESOURCES
			print("View: Resources")
			queue_redraw()
			
		elif event.keycode == KEY_6:
			view_mode = ViewMode.FERTILITY
			print("View: Fertility")
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
					x * settings.tile_size,
					y * settings.tile_size,
					settings.tile_size,
					settings.tile_size
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

		ViewMode.FERTILITY:
			return get_fertility_overlay_color(tile)

		ViewMode.RESOURCES:
			return get_resource_overlay_color(tile)

	return Color.MAGENTA

func get_fertility_overlay_color(tile: Dictionary) -> Color:
	var biome: String = tile["biome"]

	if biome == WorldData.BIOME_OCEAN:
		return get_biome_color(tile).darkened(0.65)

	if biome == WorldData.BIOME_RIVER:
		return Color(0.0, 0.85, 1.0)

	var base_color := get_biome_color(tile).darkened(0.45)
	var fertility: float = tile["fertility"]

	var fertility_color := Color(
		1.0 - fertility / 100.0,
		fertility / 100.0,
		0.08
	)

	return base_color.lerp(fertility_color, 0.75)

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

		WorldData.BIOME_RIVER:
			return Color(0.0, 0.45, 0.95)
	
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
	var biome: String = tile["biome"]

	if biome == WorldData.BIOME_OCEAN:
		return get_biome_color(tile).darkened(0.45)

	if biome == WorldData.BIOME_RIVER:
		return get_biome_color(tile)

	var base_color := get_biome_color(tile).darkened(0.45)
	var temperature: float = tile["temperature"]

	var temperature_color := Color(
		temperature,
		0.10,
		1.0 - temperature
	)

	return base_color.lerp(temperature_color, 0.70)


func get_rainfall_color(tile: Dictionary) -> Color:
	var biome: String = tile["biome"]

	if biome == WorldData.BIOME_OCEAN:
		return get_biome_color(tile).darkened(0.45)

	if biome == WorldData.BIOME_RIVER:
		return get_biome_color(tile)

	var base_color := get_biome_color(tile).darkened(0.45)
	var rainfall: float = tile["rainfall"]

	var rainfall_color := Color(
		0.08,
		rainfall,
		1.0 - rainfall
	)

	return base_color.lerp(rainfall_color, 0.70)
	
func get_resource_overlay_color(tile: Dictionary) -> Color:
	var base_color := get_biome_color(tile)
	var resource: String = tile["resource"]

	if resource == WorldData.RESOURCE_NONE:
		return base_color.darkened(0.55)

	if resource == WorldData.RESOURCE_FISH:
		return Color(0.82, 0.42, 0.95)

	if resource == WorldData.RESOURCE_COAL:
		return Color(0.02, 0.02, 0.02)

	if resource == WorldData.RESOURCE_IRON:
		return Color(0.73, 0.64, 0.48)

	if resource == WorldData.RESOURCE_GOLD:
		return Color(0.93, 0.74, 0.22)

	return Color.MAGENTA
