extends Node2D

enum ViewMode {
	BIOME,
	ELEVATION,
	TEMPERATURE,
	PRECIPITATION,
	FERTILITY,
	RESOURCES
}

enum RegionCursorState {
	SINGLE_TILE,
	REGION_PLACE,
	REGION_SELECTED
}

var view_mode: ViewMode = ViewMode.BIOME
var settings := MapSettings.new()
var world: WorldData
var generator := WorldGenerator.new()
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/MainMenu.tscn"

var world_start_layer: CanvasLayer
var world_start_background: ColorRect
var world_start_color: Color = Color(0.72, 0.62, 0.45, 1.0)

var world_ui_layer: CanvasLayer
var bottom_button_bar: HBoxContainer
var back_button: Button
var generate_world_button: Button
var play_button: Button

var select_region_button: Button
var select_region_button_size: Vector2 = Vector2(190.0, 38.0)
var select_region_button_top_margin: float = 14.0

var bottom_button_size: Vector2 = Vector2(170.0, 42.0)
var bottom_button_spacing: float = 14.0
var bottom_button_bottom_margin: float = 18.0

var abyss_color: Color = Color.BLACK
var abyss_padding_pixels: float = 20000.0

var hovered_tile := Vector2i(-1, -1)
var hovered_tile_border_color := Color(0.0, 0.55, 1.0, 1.0)
var hovered_tile_border_width := 0.5
var hover_border_line: Line2D

var region_cursor_state: int = RegionCursorState.SINGLE_TILE

var region_size_tiles: int = 9
var region_half_size: int = 4
var region_ocean_ratio_limit: float = 0.90

var selected_region_center := Vector2i(-1, -1)
var selected_region_top_left := Vector2i(-1, -1)

var region_cursor_line: Line2D
var selected_region_line: Line2D

var region_cursor_valid_color := Color(1.0, 0.0, 1.0, 0.95)
var region_cursor_invalid_color := Color(1.0, 0.0, 0.0, 0.95)
var selected_region_border_color := Color(0.0, 1.0, 1.0, 1.0)

var region_cursor_border_width: float = 1.25
var selected_region_border_width: float = 2.0

var debug_mode_enabled: bool = false
var debug_canvas_layer: CanvasLayer
var debug_panel: Panel
var debug_label: Label
var debug_panel_position: Vector2 = Vector2(12.0, 12.0)
var debug_panel_padding: Vector2 = Vector2(12.0, 10.0)
var debug_panel_min_size: Vector2 = Vector2(260.0, 80.0)

func _ready():
	add_to_group("world_renderer")

	RenderingServer.set_default_clear_color(abyss_color)

	create_hover_border_line()
	create_region_selection_lines()
	create_debug_panel()
	create_world_start_background()
	create_world_bottom_buttons()
	create_select_region_button()

	world = null
	print("World screen loaded. Press Generate World.")
	queue_redraw()

func create_hover_border_line():
	hover_border_line = Line2D.new()
	hover_border_line.default_color = hovered_tile_border_color
	hover_border_line.width = hovered_tile_border_width
	hover_border_line.closed = true
	hover_border_line.visible = false
	hover_border_line.z_index = 100

	add_child(hover_border_line)

func create_region_selection_lines() -> void:
	region_cursor_line = Line2D.new()
	region_cursor_line.width = region_cursor_border_width
	region_cursor_line.default_color = region_cursor_valid_color
	region_cursor_line.closed = true
	region_cursor_line.visible = false
	region_cursor_line.z_index = 101
	add_child(region_cursor_line)

	selected_region_line = Line2D.new()
	selected_region_line.width = selected_region_border_width
	selected_region_line.default_color = selected_region_border_color
	selected_region_line.closed = true
	selected_region_line.visible = false
	selected_region_line.z_index = 102
	add_child(selected_region_line)

func create_debug_panel() -> void:
	debug_canvas_layer = CanvasLayer.new()
	debug_canvas_layer.layer = 100
	add_child(debug_canvas_layer)

	debug_panel = Panel.new()
	debug_panel.position = debug_panel_position
	debug_panel.visible = false
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.68)
	panel_style.border_color = Color(0.0, 0.55, 1.0, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)

	debug_panel.add_theme_stylebox_override("panel", panel_style)
	debug_canvas_layer.add_child(debug_panel)

	debug_label = Label.new()
	debug_label.position = debug_panel_padding
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	debug_label.clip_text = false
	debug_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 1.0))
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.text = "DEBUG MENU"

	debug_panel.add_child(debug_label)
	fit_debug_panel_to_text()

func toggle_debug_mode() -> void:
	debug_mode_enabled = not debug_mode_enabled

	if debug_panel != null:
		debug_panel.visible = debug_mode_enabled

	update_debug_panel_text()

	if debug_mode_enabled:
		print("Debug mode: ON")
	else:
		print("Debug mode: OFF")


func update_debug_panel_text() -> void:
	if not debug_mode_enabled:
		return

	if debug_label == null:
		return

	debug_label.text = get_hovered_tile_debug_text()
	fit_debug_panel_to_text()

func fit_debug_panel_to_text() -> void:
	if debug_panel == null:
		return

	if debug_label == null:
		return

	var label_size: Vector2 = debug_label.get_combined_minimum_size()
	var panel_size: Vector2 = label_size + debug_panel_padding * 2.0

	if panel_size.x < debug_panel_min_size.x:
		panel_size.x = debug_panel_min_size.x

	if panel_size.y < debug_panel_min_size.y:
		panel_size.y = debug_panel_min_size.y

	debug_panel.size = panel_size
	debug_label.position = debug_panel_padding
	debug_label.size = label_size


func get_hovered_tile_debug_text() -> String:
	if world == null:
		return "DEBUG MODE\nWorld: not generated"

	if hovered_tile.x < 0 or hovered_tile.y < 0:
		return (
			"DEBUG MENU\n"
			+ "View: " + get_view_mode_name() + "\n"
			+ "Seed: " + str(world.seed) + "\n"
			+ "\n"
			+ "Cursor: Abyss\n"
			+ "Tile: none\n"
		)

	var tile: Dictionary = world.get_tile(hovered_tile.x, hovered_tile.y)

	var elevation: float = float(tile["elevation"])
	var temperature: float = float(tile["temperature"])
	var precipitation: float = float(tile["precipitation"])
	var fertility: float = float(tile["fertility"])
	var terrain: String = str(tile["terrain"])
	var biome: String = str(tile["biome"])
	var resource: String = str(tile["resource"])
	var is_land: bool = bool(tile["is_land"])
	var is_river: bool = biome == WorldData.BIOME_RIVER
	var is_coastal: bool = is_tile_coastal(hovered_tile.x, hovered_tile.y)

	var fertility_text: String = "N/A"
	if fertility >= 0.0:
		fertility_text = "%.1f" % fertility

	return (
		"DEBUG TILE INSPECTOR\n"
		+ "View: " + get_view_mode_name() + "\n"
		+ "Seed: " + str(world.seed) + "\n"
		+ "\n"
		+ "Tile: " + str(hovered_tile.x) + ", " + str(hovered_tile.y) + "\n"
		+ "Terrain: " + terrain + "\n"
		+ "Biome: " + biome + "\n"
		+ "Resource: " + resource + "\n"
		+ "\n"
		+ "Elevation: " + "%.3f" % elevation + "\n"
		+ "Temperature: " + "%.3f" % temperature + "\n"
		+ "Precipitation: " + "%.3f" % precipitation + "\n"
		+ "Fertility: " + fertility_text + "\n"
		+ "\n"
		+ "Land: " + bool_to_yes_no(is_land) + "\n"
		+ "River: " + bool_to_yes_no(is_river) + "\n"
		+ "Coastal: " + bool_to_yes_no(is_coastal)
	)


func get_view_mode_name() -> String:
	match view_mode:
		ViewMode.BIOME:
			return "Biome"
		ViewMode.ELEVATION:
			return "Elevation"
		ViewMode.TEMPERATURE:
			return "Temperature"
		ViewMode.PRECIPITATION:
			return "Precipitation"
		ViewMode.FERTILITY:
			return "Fertility"
		ViewMode.RESOURCES:
			return "Resources"

	return "Unknown"


func bool_to_yes_no(value: bool) -> String:
	if value:
		return "Yes"

	return "No"


func is_tile_coastal(tile_x: int, tile_y: int) -> bool:
	if world == null:
		return false

	var tile: Dictionary = world.get_tile(tile_x, tile_y)

	if str(tile["terrain"]) == WorldData.TERRAIN_WATER:
		return false

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for direction: Vector2i in directions:
		var neighbor_x: int = tile_x + direction.x
		var neighbor_y: int = tile_y + direction.y

		if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= world.width or neighbor_y >= world.height:
			continue

		var neighbor: Dictionary = world.get_tile(neighbor_x, neighbor_y)

		if str(neighbor["terrain"]) == WorldData.TERRAIN_WATER:
			return true

	return false

func _process(_delta):
	update_hovered_tile()

func update_hovered_tile() -> void:
	if world == null:
		hide_all_cursor_lines()
		return

	var new_hovered_tile: Vector2i = get_mouse_tile()

	if new_hovered_tile == hovered_tile:
		return

	hovered_tile = new_hovered_tile
	update_cursor_visuals()

	if has_method("update_debug_panel_text"):
		call("update_debug_panel_text")

func get_mouse_tile() -> Vector2i:
	var mouse_world_position: Vector2 = get_global_mouse_position()

	var tile_x: int = int(floor(mouse_world_position.x / float(settings.tile_size)))
	var tile_y: int = int(floor(mouse_world_position.y / float(settings.tile_size)))

	if tile_x < 0 or tile_y < 0:
		return Vector2i(-1, -1)

	if world != null:
		if tile_x >= world.width or tile_y >= world.height:
			return Vector2i(-1, -1)

	return Vector2i(tile_x, tile_y)

func update_hover_border_line() -> void:
	if hover_border_line == null:
		return

	if region_cursor_state == RegionCursorState.REGION_PLACE:
		hover_border_line.visible = false
		return

	if hovered_tile.x < 0 or hovered_tile.y < 0:
		hover_border_line.visible = false
		return

	var x: float = float(hovered_tile.x * settings.tile_size)
	var y: float = float(hovered_tile.y * settings.tile_size)
	var s: float = float(settings.tile_size)

	set_line_to_rect(
		hover_border_line,
		Rect2(Vector2(x, y), Vector2(s, s))
	)

	hover_border_line.default_color = hovered_tile_border_color
	hover_border_line.width = hovered_tile_border_width
	hover_border_line.visible = true

func update_cursor_visuals() -> void:
	if region_cursor_state == RegionCursorState.REGION_PLACE:
		if hover_border_line != null:
			hover_border_line.visible = false

		update_region_cursor_line()
	else:
		if region_cursor_line != null:
			region_cursor_line.visible = false

		update_hover_border_line()


func update_region_cursor_line() -> void:
	if region_cursor_line == null:
		return

	if hovered_tile.x < 0 or hovered_tile.y < 0:
		region_cursor_line.visible = false
		return

	var region_top_left: Vector2i = get_region_top_left_from_center(hovered_tile)
	var region_rect: Rect2 = get_region_rect(region_top_left)

	var valid_region: bool = is_region_valid(region_top_left)

	if valid_region:
		region_cursor_line.default_color = region_cursor_valid_color
	else:
		region_cursor_line.default_color = region_cursor_invalid_color

	region_cursor_line.width = region_cursor_border_width
	set_line_to_rect(region_cursor_line, region_rect)
	region_cursor_line.visible = true


func update_selected_region_line() -> void:
	if selected_region_line == null:
		return

	if selected_region_top_left.x < 0 or selected_region_top_left.y < 0:
		selected_region_line.visible = false
		return

	var region_rect: Rect2 = get_region_rect(selected_region_top_left)

	selected_region_line.default_color = selected_region_border_color
	selected_region_line.width = selected_region_border_width
	set_line_to_rect(selected_region_line, region_rect)
	selected_region_line.visible = true


func hide_all_cursor_lines() -> void:
	if hover_border_line != null:
		hover_border_line.visible = false

	if region_cursor_line != null:
		region_cursor_line.visible = false

	if selected_region_line != null:
		selected_region_line.visible = false


func set_line_to_rect(line: Line2D, rect: Rect2) -> void:
	line.points = PackedVector2Array([
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y)
	])

func get_region_top_left_from_center(center_tile: Vector2i) -> Vector2i:
	return Vector2i(
		center_tile.x - region_half_size,
		center_tile.y - region_half_size
	)


func get_region_rect(region_top_left: Vector2i) -> Rect2:
	var x: float = float(region_top_left.x * settings.tile_size)
	var y: float = float(region_top_left.y * settings.tile_size)
	var size_pixels: float = float(region_size_tiles * settings.tile_size)

	return Rect2(
		Vector2(x, y),
		Vector2(size_pixels, size_pixels)
	)


func is_region_inside_world(region_top_left: Vector2i) -> bool:
	if world == null:
		return false

	if region_top_left.x < 0 or region_top_left.y < 0:
		return false

	if region_top_left.x + region_size_tiles > world.width:
		return false

	if region_top_left.y + region_size_tiles > world.height:
		return false

	return true


func is_region_valid(region_top_left: Vector2i) -> bool:
	if not is_region_inside_world(region_top_left):
		return false

	var ocean_ratio: float = get_region_ocean_ratio(region_top_left)

	return ocean_ratio <= region_ocean_ratio_limit

func has_selected_region() -> bool:
	return selected_region_top_left.x >= 0 and selected_region_top_left.y >= 0

func get_region_ocean_ratio(region_top_left: Vector2i) -> float:
	var ocean_tiles: int = count_region_ocean_tiles(region_top_left)
	var total_tiles: int = region_size_tiles * region_size_tiles

	if total_tiles <= 0:
		return 1.0

	return float(ocean_tiles) / float(total_tiles)


func count_region_ocean_tiles(region_top_left: Vector2i) -> int:
	var ocean_tiles: int = 0

	for y_offset in range(region_size_tiles):
		for x_offset in range(region_size_tiles):
			var tile_x: int = region_top_left.x + x_offset
			var tile_y: int = region_top_left.y + y_offset

			var tile: Dictionary = world.get_tile(tile_x, tile_y)

			if is_ocean_region_tile(tile):
				ocean_tiles += 1

	return ocean_tiles


func is_ocean_region_tile(tile: Dictionary) -> bool:
	var biome: String = str(tile["biome"])

	if biome == WorldData.BIOME_OCEAN:
		return true

	return false

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event

		var is_debug_toggle_key: bool = (
			key_event.keycode == KEY_QUOTELEFT
			or key_event.physical_keycode == KEY_QUOTELEFT
			or key_event.unicode == 96
			or key_event.unicode == 126
		)

		if is_debug_toggle_key:
			toggle_debug_mode()
			return

		if event.keycode == KEY_1:
			view_mode = ViewMode.BIOME
			print("View: Biome")
			update_debug_panel_text()
			queue_redraw()

		elif event.keycode == KEY_2:
			view_mode = ViewMode.ELEVATION
			print("View: Elevation")
			update_debug_panel_text()
			queue_redraw()

		elif event.keycode == KEY_3:
			view_mode = ViewMode.TEMPERATURE
			print("View: Temperature")
			update_debug_panel_text()
			queue_redraw()

		elif event.keycode == KEY_4:
			view_mode = ViewMode.PRECIPITATION
			print("View: Precipitation")
			update_debug_panel_text()
			queue_redraw()

		elif event.keycode == KEY_5:
			view_mode = ViewMode.RESOURCES
			print("View: Resources")
			update_debug_panel_text()
			queue_redraw()

		elif event.keycode == KEY_6:
			view_mode = ViewMode.FERTILITY
			print("View: Fertility")
			update_debug_panel_text()
			queue_redraw()

func _draw():
	if world == null:
		return

	draw_abyss_background()

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

func draw_abyss_background() -> void:
	var map_width: float = float(world.width * settings.tile_size)
	var map_height: float = float(world.height * settings.tile_size)

	var abyss_rect: Rect2 = Rect2(
		Vector2(-abyss_padding_pixels, -abyss_padding_pixels),
		Vector2(
			map_width + abyss_padding_pixels * 2.0,
			map_height + abyss_padding_pixels * 2.0
		)
	)

	draw_rect(
		abyss_rect,
		abyss_color,
		true
	)

func get_tile_color(tile: Dictionary) -> Color:
	match view_mode:
		ViewMode.BIOME:
			return get_biome_color(tile)

		ViewMode.ELEVATION:
			return get_elevation_color(tile)

		ViewMode.TEMPERATURE:
			return get_temperature_color(tile)

		ViewMode.PRECIPITATION:
			return get_precipitation_color(tile)

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


func get_precipitation_color(tile: Dictionary) -> Color:
	var biome: String = tile["biome"]

	if biome == WorldData.BIOME_OCEAN:
		return get_biome_color(tile).darkened(0.45)

	if biome == WorldData.BIOME_RIVER:
		return get_biome_color(tile)

	var base_color := get_biome_color(tile).darkened(0.45)
	var precipitation: float = tile["precipitation"]

	var precipitation_color := Color(
		0.08,
		precipitation,
		1.0 - precipitation
	)

	return base_color.lerp(precipitation_color, 0.70)
	
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

func create_world_bottom_buttons() -> void:
	world_ui_layer = CanvasLayer.new()
	world_ui_layer.layer = 90
	add_child(world_ui_layer)

	bottom_button_bar = HBoxContainer.new()
	bottom_button_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_button_bar.add_theme_constant_override("separation", int(bottom_button_spacing))

	var total_width: float = bottom_button_size.x * 3.0 + bottom_button_spacing * 2.0
	var total_height: float = bottom_button_size.y

	bottom_button_bar.anchor_left = 0.5
	bottom_button_bar.anchor_right = 0.5
	bottom_button_bar.anchor_top = 1.0
	bottom_button_bar.anchor_bottom = 1.0

	bottom_button_bar.offset_left = -total_width * 0.5
	bottom_button_bar.offset_right = total_width * 0.5
	bottom_button_bar.offset_top = -(total_height + bottom_button_bottom_margin)
	bottom_button_bar.offset_bottom = -bottom_button_bottom_margin

	world_ui_layer.add_child(bottom_button_bar)

	back_button = create_world_action_button(
		"Back",
		Color(1.0, 0.25, 0.25, 0.32),
		Color(1.0, 0.38, 0.38, 0.48),
		Color(1.0, 0.18, 0.18, 0.62)
	)

	generate_world_button = create_world_action_button(
		"Generate World",
		Color(0.15, 0.45, 1.0, 0.32),
		Color(0.25, 0.58, 1.0, 0.48),
		Color(0.08, 0.32, 0.85, 0.62)
	)

	play_button = create_world_action_button(
		"Play",
		Color(0.25, 1.0, 0.35, 0.32),
		Color(0.40, 1.0, 0.48, 0.48),
		Color(0.15, 0.78, 0.24, 0.62)
	)

	bottom_button_bar.add_child(back_button)
	bottom_button_bar.add_child(generate_world_button)
	bottom_button_bar.add_child(play_button)

	back_button.pressed.connect(on_back_button_pressed)
	generate_world_button.pressed.connect(on_generate_world_button_pressed)
	play_button.pressed.connect(on_play_button_pressed)
	
	set_play_button_region_ready(false)

func set_play_button_region_ready(is_ready: bool) -> void:
	if play_button == null:
		return

	play_button.disabled = not is_ready

	if is_ready:
		play_button.add_theme_stylebox_override(
			"normal",
			create_world_button_style(Color(0.25, 1.0, 0.35, 0.32))
		)
		play_button.add_theme_stylebox_override(
			"hover",
			create_world_button_style(Color(0.40, 1.0, 0.48, 0.48))
		)
		play_button.add_theme_stylebox_override(
			"pressed",
			create_world_button_style(Color(0.15, 0.78, 0.24, 0.62))
		)
		play_button.add_theme_color_override("font_color", Color.WHITE)
	else:
		var grey_style: StyleBoxFlat = create_world_button_style(Color(0.35, 0.35, 0.35, 0.30))

		play_button.add_theme_stylebox_override("normal", grey_style)
		play_button.add_theme_stylebox_override("hover", grey_style)
		play_button.add_theme_stylebox_override("pressed", grey_style)
		play_button.add_theme_stylebox_override("disabled", grey_style)

		play_button.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
		play_button.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.75, 1.0))

func create_world_action_button(
	button_text: String,
	normal_color: Color,
	hover_color: Color,
	pressed_color: Color
) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = bottom_button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal_style: StyleBoxFlat = create_world_button_style(normal_color)
	var hover_style: StyleBoxFlat = create_world_button_style(hover_color)
	var pressed_style: StyleBoxFlat = create_world_button_style(pressed_color)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", normal_style)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)

	return button


func create_world_button_style(background_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = Color(1.0, 1.0, 1.0, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0

	return style


func on_back_button_pressed() -> void:
	if main_menu_scene_path.is_empty():
		push_error("Main menu scene path is empty.")
		return

	var error: Error = get_tree().change_scene_to_file(main_menu_scene_path)

	if error != OK:
		push_error("Could not load main menu scene: " + main_menu_scene_path)

func create_select_region_button() -> void:
	if world_ui_layer == null:
		return

	select_region_button = Button.new()
	select_region_button.text = "Select Region"
	select_region_button.custom_minimum_size = select_region_button_size
	select_region_button.focus_mode = Control.FOCUS_NONE
	select_region_button.mouse_filter = Control.MOUSE_FILTER_STOP
	select_region_button.visible = false

	select_region_button.anchor_left = 0.5
	select_region_button.anchor_right = 0.5
	select_region_button.anchor_top = 0.0
	select_region_button.anchor_bottom = 0.0

	select_region_button.offset_left = -select_region_button_size.x * 0.5
	select_region_button.offset_right = select_region_button_size.x * 0.5
	select_region_button.offset_top = select_region_button_top_margin
	select_region_button.offset_bottom = select_region_button_top_margin + select_region_button_size.y

	var normal_style: StyleBoxFlat = create_world_button_style(Color(0.05, 0.05, 0.08, 0.35))
	var hover_style: StyleBoxFlat = create_world_button_style(Color(0.25, 0.05, 0.35, 0.55))
	var pressed_style: StyleBoxFlat = create_world_button_style(Color(0.55, 0.0, 0.65, 0.70))

	select_region_button.add_theme_stylebox_override("normal", normal_style)
	select_region_button.add_theme_stylebox_override("hover", hover_style)
	select_region_button.add_theme_stylebox_override("pressed", pressed_style)
	select_region_button.add_theme_stylebox_override("focus", normal_style)

	select_region_button.add_theme_color_override("font_color", Color.WHITE)
	select_region_button.add_theme_color_override("font_hover_color", Color.WHITE)
	select_region_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	select_region_button.add_theme_font_size_override("font_size", 17)

	world_ui_layer.add_child(select_region_button)

	select_region_button.pressed.connect(on_select_region_button_pressed)


func on_select_region_button_pressed() -> void:
	if world == null:
		return

	region_cursor_state = RegionCursorState.REGION_PLACE
	update_cursor_visuals()

	print("Region selection mode enabled.")

func on_generate_world_button_pressed() -> void:
	hovered_tile = Vector2i(-1, -1)
	region_cursor_state = RegionCursorState.SINGLE_TILE
	clear_selected_region()

	if hover_border_line != null:
		hover_border_line.visible = false

	if region_cursor_line != null:
		region_cursor_line.visible = false

	world = generator.generate_world()
	print("Generated world seed: ", world.seed)

	if world_start_background != null:
		world_start_background.visible = false

	if select_region_button != null:
		select_region_button.visible = true

	set_play_button_region_ready(false)

	if has_method("update_debug_panel_text"):
		call("update_debug_panel_text")

	queue_redraw()


func on_play_button_pressed() -> void:
	if not has_selected_region():
		print("Play blocked: select a starting region first.")
		return

	print("Play button pressed with selected region centered at: ", selected_region_center)
	print("No gameplay action assigned yet.")

func create_world_start_background() -> void:
	world_start_layer = CanvasLayer.new()
	world_start_layer.layer = 80
	add_child(world_start_layer)

	world_start_background = ColorRect.new()
	world_start_background.color = world_start_color
	world_start_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	world_start_background.anchor_left = 0.0
	world_start_background.anchor_top = 0.0
	world_start_background.anchor_right = 1.0
	world_start_background.anchor_bottom = 1.0

	world_start_background.offset_left = 0.0
	world_start_background.offset_top = 0.0
	world_start_background.offset_right = 0.0
	world_start_background.offset_bottom = 0.0

	world_start_layer.add_child(world_start_background)

func _unhandled_input(event: InputEvent) -> void:
	if world == null:
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			handle_left_mouse_click()

		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			handle_right_mouse_click()

func handle_left_mouse_click() -> void:
	if region_cursor_state != RegionCursorState.REGION_PLACE:
		return

	if hovered_tile.x < 0 or hovered_tile.y < 0:
		return

	var region_top_left: Vector2i = get_region_top_left_from_center(hovered_tile)

	if not is_region_valid(region_top_left):
		print("Invalid region: too much ocean/river or outside map.")
		return

	selected_region_center = hovered_tile
	selected_region_top_left = region_top_left

	region_cursor_state = RegionCursorState.REGION_SELECTED

	if region_cursor_line != null:
		region_cursor_line.visible = false

	update_selected_region_line()
	update_cursor_visuals()
	set_play_button_region_ready(true)

	print("Selected region centered at tile: ", selected_region_center)


func handle_right_mouse_click() -> void:
	if has_selected_region():
		clear_selected_region()

		region_cursor_state = RegionCursorState.REGION_PLACE
		update_cursor_visuals()
		set_play_button_region_ready(false)

		print("Region deselected. Region cursor restored.")
		return

	if region_cursor_state == RegionCursorState.REGION_PLACE:
		region_cursor_state = RegionCursorState.SINGLE_TILE

		if region_cursor_line != null:
			region_cursor_line.visible = false

		update_cursor_visuals()
		set_play_button_region_ready(false)

		print("Region selection cancelled.")

func clear_selected_region() -> void:
	selected_region_center = Vector2i(-1, -1)
	selected_region_top_left = Vector2i(-1, -1)

	if selected_region_line != null:
		selected_region_line.visible = false
