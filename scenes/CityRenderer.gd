extends Node2D
class_name CityRenderer

@export_file("*.tscn") var world_scene_path: String = ""

@export var local_tiles_per_world_tile: int = 64
@export var city_tile_size: int = 2

var city_world: WorldData
var city_seed: int = 0
var detail_noise := FastNoiseLite.new()
var fertility_noise := FastNoiseLite.new()
var resource_noise := FastNoiseLite.new()
var biome_warp_noise := FastNoiseLite.new()
var coast_noise := FastNoiseLite.new()
var biome_edge_noise := FastNoiseLite.new()
var camera: Camera2D
var ui_layer: CanvasLayer
var ui_root: Control
var bottom_button_one: Button
var bottom_button_two: Button
var back_button: Button
var resource_bar: Control
var resource_boxes: Array[Panel] = []
var resource_icons: Array[ColorRect] = []
var resource_amount_labels: Array[Label] = []
var build_option_button: Button
var build_option_icon: Panel
var build_cursor_preview: Panel
var is_build_placement_active: bool = false
var hovered_city_tile: Vector2i = Vector2i(-1, -1)
var previous_hovered_city_tile: Vector2i = Vector2i(-1, -1)
var found_city_option_button: Button
var found_city_option_icon: Panel
var found_city_cursor_preview: Panel
var is_found_city_placement_active: bool = false
var hover_tile_outline: Panel
var found_city_placement_overlay: Control
var found_city_placement_panels: Array[Panel] = []


const FOUND_CITY_WIDTH_TILES: int = 2
const FOUND_CITY_HEIGHT_TILES: int = 6

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)

	generate_city_world()
	clear_invalid_old_city_foundation_state()
	create_city_camera()
	create_city_ui()

	queue_redraw()


func generate_city_world() -> void:
	if WorldData.has_active_city_save():
		city_world = WorldData.official_city_world
		city_seed = WorldData.official_city_seed
		print("Loaded existing city world.")
		return

	if not WorldData.has_city_start_region():
		push_error("No selected world region was stored before entering the city screen.")
		return

	var region_size: int = WorldData.city_start_region_size
	var city_width: int = region_size * local_tiles_per_world_tile
	var city_height: int = region_size * local_tiles_per_world_tile

	city_seed = get_city_seed()

	setup_city_noise()

	city_world = WorldData.new()
	city_world.setup(city_width, city_height, city_seed)

	for y in range(city_world.height):
		var row: Array = city_world.tiles[y]

		for x in range(city_world.width):
			var tile: Dictionary = row[x]
			var profile: Dictionary = get_city_source_profile(x, y, region_size)

			copy_city_profile_into_tile(tile, profile, x, y)

			row[x] = tile

	WorldData.store_city_world_save(city_world, city_seed)
	print("Stored official city world.")

func get_city_source_profile(city_x: int, city_y: int, region_size: int) -> Dictionary:
	var source_fx: float = ((float(city_x) + 0.5) / float(city_world.width)) * float(region_size) - 0.5
	var source_fy: float = ((float(city_y) + 0.5) / float(city_world.height)) * float(region_size) - 0.5

	var warp_strength := 0.62

	source_fx += biome_warp_noise.get_noise_2d(city_x, city_y) * warp_strength
	source_fy += biome_warp_noise.get_noise_2d(city_x + 9173, city_y - 4289) * warp_strength

	source_fx = clamp(source_fx, 0.0, float(region_size - 1))
	source_fy = clamp(source_fy, 0.0, float(region_size - 1))

	var x0: int = int(floor(source_fx))
	var y0: int = int(floor(source_fy))
	var x1: int = min(x0 + 1, region_size - 1)
	var y1: int = min(y0 + 1, region_size - 1)

	var tx: float = source_fx - float(x0)
	var ty: float = source_fy - float(y0)

	var w00: float = (1.0 - tx) * (1.0 - ty)
	var w10: float = tx * (1.0 - ty)
	var w01: float = (1.0 - tx) * ty
	var w11: float = tx * ty

	var profile := {
		"elevation": 0.0,
		"temperature": 0.0,
		"precipitation": 0.0,
		"fertility": 0.0,
		"fertility_weight": 0.0,
		"water_weight": 0.0,
		"ocean_weight": 0.0,
		"river_weight": 0.0,
		"mountain_weight": 0.0,
		"biome_weights": {},
		"resource_weights": {}
	}

	accumulate_city_source_sample(profile, WorldData.city_start_tiles[y0][x0], w00)
	accumulate_city_source_sample(profile, WorldData.city_start_tiles[y0][x1], w10)
	accumulate_city_source_sample(profile, WorldData.city_start_tiles[y1][x0], w01)
	accumulate_city_source_sample(profile, WorldData.city_start_tiles[y1][x1], w11)

	if float(profile["fertility_weight"]) > 0.0:
		profile["fertility"] = float(profile["fertility"]) / float(profile["fertility_weight"])
	else:
		profile["fertility"] = -1.0

	return profile


func accumulate_city_source_sample(profile: Dictionary, source_tile: Dictionary, weight: float) -> void:
	if weight <= 0.0:
		return

	var source_biome: String = str(source_tile["biome"])
	var source_resource: String = str(source_tile["resource"])
	var source_terrain: String = str(source_tile["terrain"])

	profile["elevation"] = float(profile["elevation"]) + float(source_tile["elevation"]) * weight
	profile["temperature"] = float(profile["temperature"]) + float(source_tile["temperature"]) * weight
	profile["precipitation"] = float(profile["precipitation"]) + float(source_tile["precipitation"]) * weight

	var source_fertility: float = float(source_tile["fertility"])

	if source_fertility >= 0.0:
		profile["fertility"] = float(profile["fertility"]) + source_fertility * weight
		profile["fertility_weight"] = float(profile["fertility_weight"]) + weight

	add_weight_to_dictionary(profile["biome_weights"], source_biome, weight)
	add_weight_to_dictionary(profile["resource_weights"], source_resource, weight)

	if source_terrain == WorldData.TERRAIN_WATER:
		profile["water_weight"] = float(profile["water_weight"]) + weight

	if source_biome == WorldData.BIOME_OCEAN:
		profile["ocean_weight"] = float(profile["ocean_weight"]) + weight

	if source_biome == WorldData.BIOME_RIVER:
		profile["river_weight"] = float(profile["river_weight"]) + weight

	if source_biome == WorldData.BIOME_MOUNTAIN:
		profile["mountain_weight"] = float(profile["mountain_weight"]) + weight


func add_weight_to_dictionary(weights: Dictionary, key: String, amount: float) -> void:
	if not weights.has(key):
		weights[key] = 0.0

	weights[key] = float(weights[key]) + amount

func get_city_seed() -> int:
	var center: Vector2i = WorldData.city_start_region_center

	var seed_value: int = int(WorldData.city_start_world_seed)
	seed_value += int(center.x * 73856093)
	seed_value += int(center.y * 19349663)
	seed_value += int(WorldData.city_start_region_size * 83492791)

	return seed_value

func copy_city_profile_into_tile(tile: Dictionary, profile: Dictionary, city_x: int, city_y: int) -> void:
	var local_detail: float = detail_noise.get_noise_2d(city_x, city_y) * 0.030
	var local_fertility_detail: float = fertility_noise.get_noise_2d(city_x, city_y) * 7.0

	var water_weight: float = float(profile["water_weight"])
	var ocean_weight: float = float(profile["ocean_weight"])
	var river_weight: float = float(profile["river_weight"])

	var coastline_threshold: float = 0.50 + coast_noise.get_noise_2d(city_x, city_y) * 0.18
	var river_threshold: float = 0.40 + coast_noise.get_noise_2d(city_x + 5000, city_y - 5000) * 0.10

	var becomes_river: bool = river_weight > river_threshold
	var becomes_water: bool = water_weight > coastline_threshold or becomes_river

	tile["elevation"] = float(profile["elevation"]) + local_detail
	tile["temperature"] = float(profile["temperature"])
	tile["precipitation"] = float(profile["precipitation"])

	if becomes_water:
		tile["terrain"] = WorldData.TERRAIN_WATER
		tile["is_land"] = false
		tile["fertility"] = -1.0

		if becomes_river and river_weight >= ocean_weight:
			tile["biome"] = WorldData.BIOME_RIVER
		else:
			tile["biome"] = WorldData.BIOME_OCEAN

	else:
		var land_biome: String = get_dominant_land_biome(profile["biome_weights"], city_x, city_y)

		tile["biome"] = land_biome
		tile["is_land"] = true

		if land_biome == WorldData.BIOME_MOUNTAIN:
			tile["terrain"] = WorldData.TERRAIN_MOUNTAIN
		else:
			tile["terrain"] = WorldData.TERRAIN_LAND

		var profile_fertility: float = float(profile["fertility"])

		if profile_fertility >= 0.0:
			tile["fertility"] = clamp(profile_fertility + local_fertility_detail, 0.0, 100.0)
		else:
			tile["fertility"] = 0.0

	tile["resource"] = get_city_resource_from_profile(profile, city_x, city_y, str(tile["biome"]), str(tile["terrain"]))


func get_dominant_land_biome(biome_weights: Dictionary, city_x: int, city_y: int) -> String:
	var best_biome := WorldData.BIOME_PLAIN
	var best_score := -99999.0

	for biome_key in biome_weights.keys():
		var biome := str(biome_key)

		if biome == WorldData.BIOME_OCEAN:
			continue

		if biome == WorldData.BIOME_RIVER:
			continue

		var score: float = float(biome_weights[biome_key])
		score += get_biome_boundary_bias(biome, city_x, city_y)

		if score > best_score:
			best_score = score
			best_biome = biome

	return best_biome


func get_biome_boundary_bias(biome: String, city_x: int, city_y: int) -> float:
	var offset: int = get_biome_noise_offset(biome)
	var noise_value: float = biome_edge_noise.get_noise_2d(city_x + offset, city_y - offset)

	return noise_value * 0.075

func get_biome_noise_offset(biome: String) -> int:
	match biome:
		WorldData.BIOME_MOUNTAIN:
			return 1000

		WorldData.BIOME_HILLS:
			return 2000

		WorldData.BIOME_DESERT:
			return 3000

		WorldData.BIOME_PLAIN:
			return 4000

		WorldData.BIOME_FOREST:
			return 5000

		WorldData.BIOME_TUNDRA:
			return 6000

		WorldData.BIOME_TAIGA:
			return 7000

		WorldData.BIOME_JUNGLE:
			return 8000

	return 9000

func setup_city_noise() -> void:
	detail_noise.seed = city_seed
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.055
	detail_noise.fractal_octaves = 4
	detail_noise.fractal_gain = 0.50
	detail_noise.fractal_lacunarity = 2.0

	fertility_noise.seed = city_seed + 4111
	fertility_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fertility_noise.frequency = 0.075
	fertility_noise.fractal_octaves = 3
	fertility_noise.fractal_gain = 0.55
	fertility_noise.fractal_lacunarity = 2.0

	resource_noise.seed = city_seed + 9221
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.105
	resource_noise.fractal_octaves = 3
	resource_noise.fractal_gain = 0.50
	resource_noise.fractal_lacunarity = 2.0

	biome_warp_noise.seed = city_seed + 1771
	biome_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_warp_noise.frequency = 0.026
	biome_warp_noise.fractal_octaves = 3
	biome_warp_noise.fractal_gain = 0.52
	biome_warp_noise.fractal_lacunarity = 2.0

	coast_noise.seed = city_seed + 2887
	coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coast_noise.frequency = 0.060
	coast_noise.fractal_octaves = 4
	coast_noise.fractal_gain = 0.52
	coast_noise.fractal_lacunarity = 2.0

	biome_edge_noise.seed = city_seed + 6397
	biome_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_edge_noise.frequency = 0.050
	biome_edge_noise.fractal_octaves = 3
	biome_edge_noise.fractal_gain = 0.50
	biome_edge_noise.fractal_lacunarity = 2.0

func get_city_resource_from_profile(
	profile: Dictionary,
	city_x: int,
	city_y: int,
	biome: String,
	terrain: String
) -> String:
	var resource_weights: Dictionary = profile["resource_weights"]

	var best_resource := WorldData.RESOURCE_NONE
	var best_weight := 0.0

	for resource_key in resource_weights.keys():
		var resource := str(resource_key)

		if resource == WorldData.RESOURCE_NONE:
			continue

		var weight: float = float(resource_weights[resource_key])

		if weight > best_weight:
			best_weight = weight
			best_resource = resource

	if best_resource == WorldData.RESOURCE_NONE:
		return WorldData.RESOURCE_NONE

	if best_resource == WorldData.RESOURCE_FISH and terrain != WorldData.TERRAIN_WATER:
		return WorldData.RESOURCE_NONE

	if best_resource == WorldData.RESOURCE_GOLD:
		if biome != WorldData.BIOME_HILLS and biome != WorldData.BIOME_MOUNTAIN:
			return WorldData.RESOURCE_NONE

	if best_resource != WorldData.RESOURCE_FISH and terrain == WorldData.TERRAIN_WATER:
		return WorldData.RESOURCE_NONE

	var noise_value: float = (resource_noise.get_noise_2d(city_x, city_y) + 1.0) * 0.5
	var spawn_chance: float = clamp(best_weight * 0.55, 0.025, 0.42)

	if noise_value > 1.0 - spawn_chance:
		return best_resource

	return WorldData.RESOURCE_NONE

func create_city_camera() -> void:
	if city_world == null:
		return

	camera = StrategyCamera2D.new()
	camera.max_zoom = 12.0

	add_child(camera)

	camera.configure_for_map(
		city_world.width,
		city_world.height,
		city_tile_size,
		not WorldData.has_city_camera_state
	)

	if WorldData.has_city_camera_state:
		camera.position = WorldData.city_camera_position
		camera.zoom = WorldData.city_camera_zoom
		camera.clamp_camera_to_map_bounds()

	camera.make_current()

func store_current_city_camera_state() -> void:
	if camera == null:
		return

	WorldData.city_camera_position = camera.position
	WorldData.city_camera_zoom = camera.zoom
	WorldData.has_city_camera_state = true

func create_city_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)

	create_bottom_city_buttons()
	create_found_city_option_button()
	create_build_option_button()
	create_resource_bar()
	create_back_button()
	create_build_cursor_preview()
	create_found_city_cursor_preview()
	create_city_tile_hover_visual()
	create_found_city_placement_visual()

	get_viewport().size_changed.connect(update_city_ui_layout)
	update_city_ui_layout()
	update_resource_bar_values()
	update_found_city_button_state()

func create_bottom_city_buttons() -> void:
	bottom_button_one = Button.new()
	bottom_button_one.text = "1"
	bottom_button_one.focus_mode = Control.FOCUS_NONE
	bottom_button_one.custom_minimum_size = Vector2(58.0, 58.0)
	bottom_button_one.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(bottom_button_one)
	bottom_button_one.pressed.connect(on_found_city_button_pressed)

	bottom_button_two = Button.new()
	bottom_button_two.text = "2"
	bottom_button_two.focus_mode = Control.FOCUS_NONE
	bottom_button_two.custom_minimum_size = Vector2(58.0, 58.0)
	bottom_button_two.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(bottom_button_two)
	bottom_button_two.pressed.connect(on_build_menu_button_pressed)

func create_back_button() -> void:
	back_button = Button.new()
	back_button.text = "Back"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.custom_minimum_size = Vector2(68.0, 50.0)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal_style := create_flat_ui_style(
		Color(0.85, 0.05, 0.03, 0.95),
		Color(0.35, 0.00, 0.00, 1.0),
		2
	)

	var hover_style := create_flat_ui_style(
		Color(1.0, 0.10, 0.08, 0.95),
		Color(0.45, 0.00, 0.00, 1.0),
		2
	)

	var pressed_style := create_flat_ui_style(
		Color(0.60, 0.02, 0.02, 0.95),
		Color(0.20, 0.00, 0.00, 1.0),
		2
	)

	back_button.add_theme_stylebox_override("normal", normal_style)
	back_button.add_theme_stylebox_override("hover", hover_style)
	back_button.add_theme_stylebox_override("pressed", pressed_style)
	back_button.add_theme_color_override("font_color", Color.WHITE)
	back_button.add_theme_color_override("font_hover_color", Color.WHITE)
	back_button.add_theme_color_override("font_pressed_color", Color.WHITE)

	ui_root.add_child(back_button)

	back_button.pressed.connect(on_back_button_pressed)

func on_found_city_button_pressed() -> void:
	if found_city_option_button == null:
		return

	var should_open := not found_city_option_button.visible

	close_build_menu()
	cancel_build_placement()

	if should_open:
		found_city_option_button.visible = true
		layout_found_city_option_button(get_viewport_rect().size)
		found_city_option_button.move_to_front()
	else:
		cancel_found_city_placement()
		found_city_option_button.visible = false

	update_found_city_button_state()

func update_found_city_button_state() -> void:
	if bottom_button_one != null:
		bottom_button_one.disabled = false
		bottom_button_one.text = "1"

	if found_city_option_button == null:
		return

	if WorldData.has_player_city_foundation():
		found_city_option_button.disabled = true
		found_city_option_button.text = "✓"

		if found_city_option_icon != null:
			found_city_option_icon.visible = false
	else:
		found_city_option_button.disabled = false
		found_city_option_button.text = ""

		if found_city_option_icon != null:
			found_city_option_icon.visible = true
	if bottom_button_one != null:
		bottom_button_one.disabled = false
		bottom_button_one.text = "1"

	if found_city_option_button == null:
		return

	if WorldData.has_player_city():
		found_city_option_button.disabled = true
		found_city_option_button.text = "✓"

		if found_city_option_icon != null:
			found_city_option_icon.visible = false
	else:
		found_city_option_button.disabled = false
		found_city_option_button.text = ""

		if found_city_option_icon != null:
			found_city_option_icon.visible = true

func can_build_here() -> bool:
	return WorldData.can_build_in_city()

func create_resource_bar() -> void:
	resource_bar = Control.new()
	resource_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(resource_bar)

	resource_boxes.clear()
	resource_icons.clear()
	resource_amount_labels.clear()

	var resource_order := get_city_resource_order()

	for i in range(resource_order.size()):
		var resource: String = resource_order[i]

		var box := Panel.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var box_style := create_flat_ui_style(
			Color(0.08, 0.08, 0.08, 0.82),
			Color(0.85, 0.85, 0.85, 0.95),
			1
		)

		box.add_theme_stylebox_override("panel", box_style)
		resource_bar.add_child(box)
		resource_boxes.append(box)

		var icon := ColorRect.new()
		icon.color = get_resource_color(resource)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		resource_icons.append(icon)

		var amount_label := Label.new()
		amount_label.text = "0"
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_label.add_theme_color_override("font_color", Color.WHITE)
		amount_label.add_theme_font_size_override("font_size", 12)
		box.add_child(amount_label)
		resource_amount_labels.append(amount_label)

	for i in range(4):
		var box := Panel.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style := create_flat_ui_style(
			Color(0.08, 0.08, 0.08, 0.82),
			Color(0.85, 0.85, 0.85, 0.95),
			1
		)

		box.add_theme_stylebox_override("panel", style)

		resource_bar.add_child(box)
		resource_boxes.append(box)

func get_city_resource_order() -> Array[String]:
	return [
		WorldData.RESOURCE_FISH,
		WorldData.RESOURCE_COAL,
		WorldData.RESOURCE_IRON,
		WorldData.RESOURCE_GOLD
	]

func update_resource_bar_values() -> void:
	var resource_order := get_city_resource_order()

	for i in range(resource_amount_labels.size()):
		if i >= resource_order.size():
			continue

		var resource: String = resource_order[i]
		var amount := WorldData.get_city_resource_amount(resource)

		resource_amount_labels[i].text = str(amount)

func create_flat_ui_style(fill_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	return style

func update_city_ui_layout() -> void:
	if ui_root == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	layout_bottom_buttons(viewport_size)
	layout_found_city_option_button(viewport_size)
	layout_build_option_button(viewport_size)
	layout_resource_bar(viewport_size)
	layout_back_button(viewport_size)

func layout_bottom_buttons(viewport_size: Vector2) -> void:
	if bottom_button_one == null or bottom_button_two == null:
		return

	var button_size := 58.0
	var gap := 0.0

	var total_width := button_size * 2.0 + gap
	var start_x := viewport_size.x * 0.5 - total_width * 0.5
	var y := viewport_size.y - button_size - 24.0

	bottom_button_one.position = Vector2(start_x, y)
	bottom_button_one.size = Vector2(button_size, button_size)

	bottom_button_two.position = Vector2(start_x + button_size + gap, y)
	bottom_button_two.size = Vector2(button_size, button_size)


func layout_resource_bar(viewport_size: Vector2) -> void:
	if resource_bar == null:
		return

	var box_width := 52.0
	var box_height := 50.0
	var box_count := 4
	var total_width := box_width * float(box_count)

	resource_bar.position = Vector2(viewport_size.x - total_width, 0.0)
	resource_bar.size = Vector2(total_width, box_height)

	for i in range(resource_boxes.size()):
		var box := resource_boxes[i]
		box.position = Vector2(float(i) * box_width, 0.0)
		box.size = Vector2(box_width, box_height)

		if i < resource_icons.size():
			var icon := resource_icons[i]
			icon.position = Vector2(box_width * 0.5 - 8.0, 7.0)
			icon.size = Vector2(16.0, 16.0)

		if i < resource_amount_labels.size():
			var label := resource_amount_labels[i]
			label.position = Vector2(0.0, 25.0)
			label.size = Vector2(box_width, 20.0)


func layout_back_button(viewport_size: Vector2) -> void:
	if back_button == null:
		return

	var button_size := Vector2(68.0, 50.0)

	back_button.position = Vector2(
		viewport_size.x - button_size.x - 12.0,
		viewport_size.y - button_size.y - 12.0
	)

	back_button.size = button_size

func on_back_button_pressed() -> void:
	store_current_city_camera_state()
	
	var return_path := WorldData.official_world_scene_path

	if return_path.is_empty():
		return_path = WorldData.city_return_world_scene_path

	if return_path.is_empty():
		return_path = world_scene_path

	if return_path.is_empty():
		push_error("World scene path is empty.")
		return

	var error: Error = get_tree().change_scene_to_file(return_path)

	if error != OK:
		push_error("Could not load world scene: " + return_path)

func get_city_tile_color(tile: Dictionary) -> Color:
	var base_color: Color = get_biome_color(tile)
	var resource: String = str(tile["resource"])

	if resource == WorldData.RESOURCE_NONE:
		return base_color

	return base_color.lerp(get_resource_color(resource), 0.55)


func get_biome_color(tile: Dictionary) -> Color:
	var biome: String = str(tile["biome"])

	match biome:
		WorldData.BIOME_OCEAN:
			return Color(0.05, 0.16, 0.36)

		WorldData.BIOME_RIVER:
			return Color(0.08, 0.34, 0.82)

		WorldData.BIOME_MOUNTAIN:
			return Color(0.45, 0.42, 0.38)

		WorldData.BIOME_HILLS:
			return Color(0.46, 0.31, 0.16)

		WorldData.BIOME_DESERT:
			return Color(0.86, 0.72, 0.36)

		WorldData.BIOME_PLAIN:
			return Color(0.36, 0.65, 0.25)

		WorldData.BIOME_FOREST:
			return Color(0.10, 0.42, 0.16)

		WorldData.BIOME_TUNDRA:
			return Color(0.64, 0.72, 0.68)

		WorldData.BIOME_TAIGA:
			return Color(0.20, 0.38, 0.32)

		WorldData.BIOME_JUNGLE:
			return Color(0.02, 0.36, 0.09)

	return Color.MAGENTA


func get_resource_color(resource: String) -> Color:
	if resource == WorldData.RESOURCE_FISH:
		return Color(0.82, 0.42, 0.95)

	if resource == WorldData.RESOURCE_COAL:
		return Color(0.02, 0.02, 0.02)

	if resource == WorldData.RESOURCE_IRON:
		return Color(0.73, 0.64, 0.48)

	if resource == WorldData.RESOURCE_GOLD:
		return Color(0.93, 0.74, 0.22)

	return Color.MAGENTA

func create_build_option_button() -> void:
	build_option_button = Button.new()
	build_option_button.text = ""
	build_option_button.focus_mode = Control.FOCUS_NONE
	build_option_button.custom_minimum_size = Vector2(58.0, 58.0)
	build_option_button.mouse_filter = Control.MOUSE_FILTER_STOP
	build_option_button.visible = false

	ui_root.add_child(build_option_button)
	build_option_button.pressed.connect(on_build_option_button_pressed)

	build_option_icon = Panel.new()
	build_option_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := create_flat_ui_style(
		Color(0.55, 0.55, 0.55, 1.0),
		Color(0.18, 0.18, 0.18, 1.0),
		1
	)

	build_option_icon.add_theme_stylebox_override("panel", icon_style)
	build_option_button.add_child(build_option_icon)

func create_found_city_option_button() -> void:
	found_city_option_button = Button.new()
	found_city_option_button.text = ""
	found_city_option_button.focus_mode = Control.FOCUS_NONE
	found_city_option_button.custom_minimum_size = Vector2(58.0, 58.0)
	found_city_option_button.mouse_filter = Control.MOUSE_FILTER_STOP
	found_city_option_button.visible = false

	ui_root.add_child(found_city_option_button)
	found_city_option_button.pressed.connect(on_found_city_option_button_pressed)

	found_city_option_icon = Panel.new()
	found_city_option_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := create_flat_ui_style(
		Color(0.86, 0.84, 0.76, 1.0),
		Color(0.32, 0.30, 0.24, 1.0),
		1
	)

	found_city_option_icon.add_theme_stylebox_override("panel", icon_style)
	found_city_option_button.add_child(found_city_option_icon)

func layout_build_option_button(_viewport_size: Vector2) -> void:
	if build_option_button == null or bottom_button_two == null:
		return

	var button_size := 58.0
	var gap := 6.0

	build_option_button.position = Vector2(
		bottom_button_two.position.x,
		bottom_button_two.position.y - button_size - gap
	)

	build_option_button.size = Vector2(button_size, button_size)

	if build_option_icon != null:
		build_option_icon.position = Vector2(21.0, 21.0)
		build_option_icon.size = Vector2(16.0, 16.0)

func layout_found_city_option_button(_viewport_size: Vector2) -> void:
	if found_city_option_button == null or bottom_button_one == null:
		return

	var button_size := 58.0
	var gap := 6.0

	found_city_option_button.position = Vector2(
		bottom_button_one.position.x,
		bottom_button_one.position.y - button_size - gap
	)

	found_city_option_button.size = Vector2(button_size, button_size)

	if found_city_option_icon != null:
		found_city_option_icon.position = Vector2(22.0, 8.0)
		found_city_option_icon.size = Vector2(14.0, 42.0)

func on_found_city_option_button_pressed() -> void:
	if WorldData.has_player_city():
		update_found_city_button_state()
		return

	if is_found_city_placement_active:
		cancel_found_city_placement()
	else:
		start_found_city_placement()

func start_found_city_placement() -> void:
	close_build_menu()
	cancel_build_placement()

	is_found_city_placement_active = true

	if found_city_cursor_preview != null:
		found_city_cursor_preview.visible = false

	update_found_city_placement_visual()
	print("Found-city placement preview started.")

func cancel_found_city_placement() -> void:
	is_found_city_placement_active = false

	if found_city_cursor_preview != null:
		found_city_cursor_preview.visible = false

	if found_city_placement_overlay != null:
		found_city_placement_overlay.visible = false

func create_found_city_cursor_preview() -> void:
	found_city_cursor_preview = Panel.new()
	found_city_cursor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	found_city_cursor_preview.visible = false

	var preview_style := create_flat_ui_style(
		Color(0.86, 0.84, 0.76, 0.28),
		Color(0.32, 0.30, 0.24, 0.55),
		1
	)
	
	found_city_cursor_preview.add_theme_stylebox_override("panel", preview_style)
	ui_root.add_child(found_city_cursor_preview)

func update_found_city_cursor_preview_position() -> void:
	if found_city_cursor_preview == null:
		return

	var zoom_scale := 1.0

	if camera != null:
		zoom_scale = camera.zoom.x

	var preview_size := Vector2(
		float(FOUND_CITY_WIDTH_TILES * city_tile_size) * zoom_scale,
		float(FOUND_CITY_HEIGHT_TILES * city_tile_size) * zoom_scale
	)

	var mouse_position := get_viewport().get_mouse_position()

	found_city_cursor_preview.size = preview_size
	found_city_cursor_preview.position = mouse_position - preview_size * 0.5

func close_build_menu() -> void:
	if build_option_button != null:
		build_option_button.visible = false


func close_found_city_menu() -> void:
	if found_city_option_button != null:
		found_city_option_button.visible = false

func on_build_menu_button_pressed() -> void:
	if not WorldData.has_player_city():
		print("Build menu blocked: found a city first.")
		return

	if build_option_button == null:
		print("Build menu blocked: build option button does not exist.")
		return

	var should_open := not build_option_button.visible

	close_found_city_menu()
	cancel_found_city_placement()

	if should_open:
		build_option_button.visible = true
		build_option_button.disabled = false
		build_option_button.size = Vector2(58.0, 58.0)

		layout_build_option_button(get_viewport_rect().size)
		build_option_button.move_to_front()

		if build_option_icon != null:
			build_option_icon.visible = true
			build_option_icon.position = Vector2(21.0, 21.0)
			build_option_icon.size = Vector2(16.0, 16.0)

		print("Build menu opened at: ", build_option_button.position, " size: ", build_option_button.size)
	else:
		cancel_build_placement()
		build_option_button.visible = false
		print("Build menu closed.")

func on_build_option_button_pressed() -> void:
	if is_build_placement_active:
		cancel_build_placement()
	else:
		start_build_placement()
		
func start_build_placement() -> void:
	is_build_placement_active = true

	if build_cursor_preview != null:
		build_cursor_preview.visible = true

	print("Build placement preview started.")
	update_build_cursor_preview_position()


func cancel_build_placement() -> void:
	is_build_placement_active = false

	if build_cursor_preview != null:
		build_cursor_preview.visible = false

	print("Build placement preview canceled.")

func create_build_cursor_preview() -> void:
	build_cursor_preview = Panel.new()
	build_cursor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_cursor_preview.visible = false

	var preview_style := create_flat_ui_style(
		Color(0.55, 0.55, 0.55, 0.85),
		Color(0.18, 0.18, 0.18, 0.95),
		1
	)

	build_cursor_preview.add_theme_stylebox_override("panel", preview_style)
	ui_root.add_child(build_cursor_preview)

func update_build_cursor_preview_position() -> void:
	if build_cursor_preview == null:
		return

	var preview_size := Vector2(12.0, 12.0)
	var mouse_position := get_viewport().get_mouse_position()

	build_cursor_preview.size = preview_size
	build_cursor_preview.position = mouse_position - preview_size * 0.5

func _process(_delta: float) -> void:
	update_hovered_city_tile()
	update_city_hover_visual()
	update_found_city_placement_visual()

	if is_build_placement_active:
		update_build_cursor_preview_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if is_build_placement_active:
				cancel_build_placement()
				close_build_menu()
				get_viewport().set_input_as_handled()
				return

			if is_found_city_placement_active:
				cancel_found_city_placement()
				close_found_city_menu()
				get_viewport().set_input_as_handled()
				return

			if build_option_button != null and build_option_button.visible:
				close_build_menu()
				get_viewport().set_input_as_handled()
				return

			if found_city_option_button != null and found_city_option_button.visible:
				close_found_city_menu()
				get_viewport().set_input_as_handled()
				return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_found_city_placement_active:
				place_found_city_at_mouse()
				get_viewport().set_input_as_handled()
	
func place_found_city_at_mouse() -> void:
	if city_world == null:
		return

	if WorldData.has_player_city():
		cancel_found_city_placement()
		update_found_city_button_state()
		return

	var top_left_tile := get_found_city_top_left_tile_from_mouse()
	if top_left_tile == Vector2i(-1, -1):
		return
	
	WorldData.found_player_city(
		"First City",
		city_seed,
		Vector2i(city_world.width, city_world.height),
		top_left_tile,
		Vector2i(FOUND_CITY_WIDTH_TILES, FOUND_CITY_HEIGHT_TILES)
	)

	cancel_found_city_placement()
	update_found_city_button_state()

	if found_city_option_button != null:
		found_city_option_button.visible = true

	print("Founded city at: ", top_left_tile)
	print("City data: ", WorldData.player_city_data)

	queue_redraw()

func get_found_city_top_left_tile_from_mouse() -> Vector2i:
	if city_world == null:
		return Vector2i(-1, -1)

	var center_tile := get_city_tile_under_mouse()

	if center_tile == Vector2i(-1, -1):
		return Vector2i(-1, -1)

	var top_left := Vector2i(
		center_tile.x - int(FOUND_CITY_WIDTH_TILES / 2),
		center_tile.y - int(FOUND_CITY_HEIGHT_TILES / 2)
	)

	top_left.x = clamp(top_left.x, 0, city_world.width - FOUND_CITY_WIDTH_TILES)
	top_left.y = clamp(top_left.y, 0, city_world.height - FOUND_CITY_HEIGHT_TILES)

	return top_left

func _draw() -> void:
	if city_world == null:
		return

	for y in range(city_world.height):
		for x in range(city_world.width):
			var tile: Dictionary = city_world.get_tile(x, y)
			var color: Color = get_city_tile_color(tile)

			draw_rect(
				Rect2(
					float(x * city_tile_size),
					float(y * city_tile_size),
					float(city_tile_size),
					float(city_tile_size)
				),
				color,
				true
			)
			
	draw_player_city_foundation()

func draw_hovered_city_tile_highlight() -> void:
	if hovered_city_tile == Vector2i(-1, -1):
		return

	if is_found_city_placement_active:
		return

	var rect := Rect2(
		float(hovered_city_tile.x * city_tile_size),
		float(hovered_city_tile.y * city_tile_size),
		float(city_tile_size),
		float(city_tile_size)
	)

	draw_rect(rect, Color(0.0, 1.0, 1.0, 0.95), false, 1.0)

func draw_found_city_placement_highlight() -> void:
	if not is_found_city_placement_active:
		return

	if city_world == null:
		return

	var top_left := get_found_city_top_left_tile_from_mouse()

	if top_left == Vector2i(-1, -1):
		return

	var total_rect := Rect2(
		float(top_left.x * city_tile_size),
		float(top_left.y * city_tile_size),
		float(FOUND_CITY_WIDTH_TILES * city_tile_size),
		float(FOUND_CITY_HEIGHT_TILES * city_tile_size)
	)

	draw_rect(total_rect, Color(0.86, 0.84, 0.76, 0.28), true)
	draw_rect(total_rect, Color(0.32, 0.30, 0.24, 0.95), false, 1.0)

	for y in range(FOUND_CITY_HEIGHT_TILES):
		for x in range(FOUND_CITY_WIDTH_TILES):
			var tile_rect := Rect2(
				float((top_left.x + x) * city_tile_size),
				float((top_left.y + y) * city_tile_size),
				float(city_tile_size),
				float(city_tile_size)
			)

			draw_rect(tile_rect, Color(1.0, 1.0, 1.0, 0.35), false, 1.0)

func draw_player_city_foundation() -> void:
	if not WorldData.has_player_city_foundation():
		return

	var top_left: Vector2i = WorldData.player_city_foundation_top_left
	var size_tiles: Vector2i = WorldData.player_city_foundation_size

	var rect := Rect2(
		float(top_left.x * city_tile_size),
		float(top_left.y * city_tile_size),
		float(size_tiles.x * city_tile_size),
		float(size_tiles.y * city_tile_size)
	)

	draw_rect(rect, Color(0.86, 0.84, 0.76, 0.55), true)
	draw_rect(rect, Color(0.32, 0.30, 0.24, 0.95), false, 1.0)

func clear_invalid_old_city_foundation_state() -> void:
	if not WorldData.player_city_founded:
		return

	if WorldData.has_player_city_foundation():
		return

	print("Clearing old city-founded state with no placed foundation.")
	WorldData.reset_player_city_state()

func get_city_tile_under_mouse() -> Vector2i:
	if city_world == null:
		return Vector2i(-1, -1)

	var mouse_world_position: Vector2 = get_global_mouse_position()

	var tile_x := int(floor(mouse_world_position.x / float(city_tile_size)))
	var tile_y := int(floor(mouse_world_position.y / float(city_tile_size)))

	if tile_x < 0 or tile_y < 0 or tile_x >= city_world.width or tile_y >= city_world.height:
		return Vector2i(-1, -1)

	return Vector2i(tile_x, tile_y)


func update_hovered_city_tile() -> void:
	previous_hovered_city_tile = hovered_city_tile
	hovered_city_tile = get_city_tile_under_mouse()

func create_city_tile_hover_visual() -> void:
	hover_tile_outline = Panel.new()
	hover_tile_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tile_outline.visible = false

	var style := create_flat_ui_style(
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 1.0, 1.0, 0.95),
		1
	)

	hover_tile_outline.add_theme_stylebox_override("panel", style)
	ui_root.add_child(hover_tile_outline)


func create_found_city_placement_visual() -> void:
	found_city_placement_overlay = Control.new()
	found_city_placement_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	found_city_placement_overlay.visible = false
	found_city_placement_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(found_city_placement_overlay)

	found_city_placement_panels.clear()

	for y in range(FOUND_CITY_HEIGHT_TILES):
		for x in range(FOUND_CITY_WIDTH_TILES):
			var panel := Panel.new()
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var style := create_flat_ui_style(
				Color(0.86, 0.84, 0.76, 0.28),
				Color(1.0, 1.0, 1.0, 0.45),
				1
			)

			panel.add_theme_stylebox_override("panel", style)
			found_city_placement_overlay.add_child(panel)
			found_city_placement_panels.append(panel)

func city_world_position_to_screen(world_position: Vector2) -> Vector2:
	if camera == null:
		return world_position

	var viewport_size: Vector2 = get_viewport_rect().size

	return Vector2(
		(world_position.x - camera.position.x) * camera.zoom.x + viewport_size.x * 0.5,
		(world_position.y - camera.position.y) * camera.zoom.y + viewport_size.y * 0.5
	)


func city_tile_rect_to_screen_rect(top_left_tile: Vector2i, size_tiles: Vector2i) -> Rect2:
	var world_top_left := Vector2(
		float(top_left_tile.x * city_tile_size),
		float(top_left_tile.y * city_tile_size)
	)

	var world_bottom_right := Vector2(
		float((top_left_tile.x + size_tiles.x) * city_tile_size),
		float((top_left_tile.y + size_tiles.y) * city_tile_size)
	)

	var screen_top_left := city_world_position_to_screen(world_top_left)
	var screen_bottom_right := city_world_position_to_screen(world_bottom_right)

	return Rect2(screen_top_left, screen_bottom_right - screen_top_left)

func update_city_hover_visual() -> void:
	if hover_tile_outline == null:
		return

	if hovered_city_tile == Vector2i(-1, -1):
		hover_tile_outline.visible = false
		return

	if is_found_city_placement_active:
		hover_tile_outline.visible = false
		return

	var rect := city_tile_rect_to_screen_rect(
		hovered_city_tile,
		Vector2i(1, 1)
	)

	hover_tile_outline.visible = true
	hover_tile_outline.position = rect.position
	hover_tile_outline.size = rect.size
	hover_tile_outline.move_to_front()

func update_found_city_placement_visual() -> void:
	if found_city_placement_overlay == null:
		return

	if not is_found_city_placement_active:
		found_city_placement_overlay.visible = false
		return

	var top_left := get_found_city_top_left_tile_from_mouse()

	if top_left == Vector2i(-1, -1):
		found_city_placement_overlay.visible = false
		return

	found_city_placement_overlay.visible = true
	found_city_placement_overlay.move_to_front()

	var panel_index := 0

	for y in range(FOUND_CITY_HEIGHT_TILES):
		for x in range(FOUND_CITY_WIDTH_TILES):
			if panel_index >= found_city_placement_panels.size():
				return

			var tile_position := Vector2i(top_left.x + x, top_left.y + y)

			var rect := city_tile_rect_to_screen_rect(
				tile_position,
				Vector2i(1, 1)
			)

			var panel := found_city_placement_panels[panel_index]
			panel.visible = true
			panel.position = rect.position
			panel.size = rect.size

			panel_index += 1
