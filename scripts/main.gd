extends Node3D

const LANE_X: Array[float] = [-3.2, 0.0, 3.2]
const DODGE_DURATION := 1.8
const DUCK_DURATION := 1.25
const DUCK_DEPTH := 1.05
const ACTION_WINDOW := 12.0
const DEFAULT_SMASH_HIT_GAP := 1.8
const DUCK_VISUAL_SINK := 0.6
var speed := 12.0
var course_length := 180.0
var video_duration := 15.0
var events: Array[Dictionary] = []
var jump_height := 2.2
var lane_smoothness := 9.0
var lane := 1
var dodge_direction := 0
var dodge_time := 0.0
var distance := 0.0
var vertical_offset := 0.0
var jump_time := 0.0
var jumping := false
var ducking := false
var duck_time := 0.0
var duck_offset := 0.0
var finished := false
var camera_rig: Node3D
var camera: Camera3D
var course_root: Node3D
var world_environment: Environment
var sun_light: DirectionalLight3D
var progress_bar: ProgressBar
var distance_label: Label
var action_label: Label
var action_icon: TextureRect
var feedback_label: Label
var flash_overlay: ColorRect
var settings_panel: PanelContainer
var start_position := Vector3(0, 1.7, 4)
var event_index := 0
var action_armed := false
var feedback_time := 0.0
var countdown := 3.0
var smash_sequence_active := false
var smash_sequence_timer := 0.0
var smash_sequence_stage := 0
var active_smash_event: Dictionary = {}
var builder_active := true
var builder_overlay: ColorRect
var duration_spin: SpinBox
var round_checks: Dictionary = {}
var round_option: OptionButton
var active_round := "round_01"
var image_panels_check: CheckButton
var image_panel_events: Array[Dictionary] = []
var theme_option: OptionButton
var active_theme := "Candy"
var layout_option: OptionButton
var active_layout := "Open World"
var density_spin: SpinBox
var obstacle_scale_spin: SpinBox
var smash_actor_scale_spin: SpinBox
var smash_hit_gap_spin: SpinBox
var model_scale_spin: SpinBox
var model_category_option: OptionButton
var model_file_dialog: FileDialog
var custom_model_list: ItemList
var custom_model_prototypes: Array[Node3D] = []
var custom_model_names: Array[String] = []
var custom_model_scales: Array[float] = []
var custom_model_categories: Array[String] = []
var custom_model_paths: Array[String] = []
var custom_animation_paths: Array[String] = []
var custom_library_root: Node3D
var occupied_environment_spots: Array[Dictionary] = []
var surface_textures: Dictionary = {}
var obstacle_model_prototypes: Dictionary = {}
var obstacle_model_next_indices: Dictionary = {}
var round_model_list: ItemList
var round_model_scale_spin: SpinBox
var round_model_entries: Array[Dictionary] = []
var round_model_scales: Dictionary = {}
var round_preview_viewport: SubViewport
var round_preview_root: Node3D
var round_preview_camera: Camera3D
var companion_option: OptionButton
var companion_scale_spin: SpinBox
var companion_root: Node3D
var companion_visual: Node3D
var companion_model_index := -1
var companion_run_time := 0.0
var companion_visual_base_y := 0.0
var companion_size := 1.0
const SURFACE_TILE_SIZE := 1.0

func _ready() -> void:
	build_world()
	build_ui()
	build_builder_ui()
	load_models_from_category_folders()
	refresh_companion_options()
	load_obstacle_models()
	refresh_round_model_list()
	apply_builder_settings()
	builder_overlay.visible = true
	builder_active = true

func build_world() -> void:
	var environment := WorldEnvironment.new()
	world_environment = Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("55baf2")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color.WHITE
	world_environment.ambient_light_energy = 0.38
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.adjustment_enabled = true
	world_environment.adjustment_brightness = 0.92
	world_environment.adjustment_contrast = 1.08
	world_environment.adjustment_saturation = 1.14
	environment.environment = world_environment
	add_child(environment)
	load_background_panorama()
	load_surface_textures()

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-55, -25, 0)
	sun_light.light_energy = 0.72
	sun_light.shadow_enabled = true
	add_child(sun_light)

	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.current = true
	camera_rig.add_child(camera)
	course_root = Node3D.new()
	course_root.name = "GeneratedCourse"
	add_child(course_root)
	custom_library_root = Node3D.new()
	custom_library_root.name = "CustomModelLibrary"
	custom_library_root.visible = false
	add_child(custom_library_root)
	companion_root = Node3D.new()
	companion_root.name = "RunnerCompanion"
	add_child(companion_root)
	companion_root.visible = false

func load_background_panorama() -> void:
	var folder_path := "res://раунды/%s/textures/background" % active_round
	var image_files: Array[String] = []
	for file_name in DirAccess.get_files_at(folder_path):
		if file_name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "hdr", "exr"]:
			image_files.append(file_name)
	image_files.sort()
	if image_files.is_empty():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.sky = null
		return
	var texture := load(folder_path.path_join(image_files[0])) as Texture2D
	if not texture:
		push_warning("Could not load background panorama: %s" % image_files[0])
		return
	var panorama_material := PanoramaSkyMaterial.new()
	panorama_material.panorama = texture
	var panorama_sky := Sky.new()
	panorama_sky.sky_material = panorama_material
	world_environment.sky = panorama_sky
	world_environment.background_mode = Environment.BG_SKY

func load_surface_textures() -> void:
	surface_textures.clear()
	for slot in ["road", "ground"]:
		var folder_path := "res://раунды/%s/textures/%s" % [active_round, slot]
		var image_files: Array[String] = []
		for file_name in DirAccess.get_files_at(folder_path):
			if file_name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
				image_files.append(file_name)
		image_files.sort()
		if image_files.is_empty():
			continue
		var texture := load(folder_path.path_join(image_files[0])) as Texture2D
		if texture:
			surface_textures[slot] = texture

func build_course() -> void:
	for child in course_root.get_children():
		child.queue_free()
	image_panel_events.clear()
	obstacle_model_next_indices.clear()
	var road_color := theme_color("road")
	create_box("Road", Vector3(11, 0.25, course_length + 20), Vector3(0, -0.25, -course_length * 0.5 + 5), road_color)
	for lane_mark in [-1.6, 1.6]:
		create_box("LaneMark", Vector3(0.10, 0.025, course_length), Vector3(lane_mark, 0.02, -course_length * 0.5 + 5), Color(1, 1, 1, 0.65))

	build_theme_environment()

	var colors := [Color("49d765"), Color("3a84ed"), Color("ffca38"), Color("9858e8")]
	for index in range(events.size()):
		var event := events[index]
		var z_position := start_position.z - float(event.distance)
		match str(event.action):
			"JUMP":
				# Block all three lanes so the required action reads as a jump,
				# rather than an obstacle the player could simply dodge around.
				# One event uses three copies of the same model; the next event
				# advances to the next available JUMP variant.
				var jump_variants: Array = obstacle_model_prototypes.get("JUMP", [])
				var jump_variant_index := -1
				if not jump_variants.is_empty():
					jump_variant_index = int(obstacle_model_next_indices.get("JUMP", 0)) % jump_variants.size()
					obstacle_model_next_indices["JUMP"] = jump_variant_index + 1
				for obstacle_lane in range(3):
					create_obstacle(obstacle_lane, z_position, colors[index % colors.size()], "JUMP", 1.5, jump_variant_index)
			"DUCK": create_duck_gate(z_position, colors[index % colors.size()])
			"LEFT", "RIGHT": create_dodge_gate(z_position, str(event.action), colors[index % colors.size()])
			"SMASH": event["targets"] = create_smash_gate(z_position, colors[index % colors.size()])

	create_random_image_panels()

	var finish_z := start_position.z - course_length
	create_box("FinishTop", Vector3(11, 0.55, 0.55), Vector3(0, 5.7, finish_z), Color.WHITE)
	create_box("FinishLeft", Vector3(0.55, 6, 0.55), Vector3(-5.2, 2.8, finish_z), Color.WHITE)
	create_box("FinishRight", Vector3(0.55, 6, 0.55), Vector3(5.2, 2.8, finish_z), Color.WHITE)

func create_random_image_panels() -> void:
	if not image_panels_check or not image_panels_check.button_pressed:
		return
	var folder_path := "res://assets/image_panels"
	var image_files: Array[String] = []
	for file_name in DirAccess.get_files_at(folder_path):
		if file_name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			image_files.append(file_name)
	if image_files.is_empty():
		return
	# Shuffle once and consume each entry once: placement is random, repetition
	# inside one generated round is impossible.
	image_files.shuffle()
	var candidate_times: Array[float] = []
	var candidate_time := 2.0
	while candidate_time < video_duration - 2.0:
		candidate_times.append(candidate_time)
		candidate_time += 8.0
	candidate_times.shuffle()
	var panel_count := mini(image_files.size(), candidate_times.size())
	for index in range(panel_count):
		var texture := load(folder_path.path_join(image_files[index])) as Texture2D
		if not texture:
			continue
		var panel_height := 3.2
		# Span almost the entire 11 m road. Keep the established height so the
		# pose stays readable without turning the panel into an excessively tall
		# wall for the 3:2 source images.
		var panel_width := 10.4
		var panel := MeshInstance3D.new()
		panel.name = "ImagePanel_%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2(panel_width, panel_height)
		panel.mesh = quad
		panel.position = Vector3(0, panel_height * 0.5 + 0.15, start_position.z - candidate_times[index] * speed)
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		panel.material_override = material
		course_root.add_child(panel)
		image_panel_events.append({"distance": candidate_times[index] * speed, "triggered": false})

func create_tree(pos: Vector3, index: int) -> void:
	create_cylinder(Vector3(pos.x, 1.25, pos.z), 0.24, 2.5, Color("f1eee2"))
	var colors := [Color("ef426f"), Color("37cf79"), Color("56aef0"), Color("9639bd")]
	create_sphere(Vector3(pos.x, 3.4, pos.z), 1.45, colors[index % colors.size()])

func theme_color(slot: String) -> Color:
	var themes := {
		"Candy": {"road": Color("f54fa2"), "ground": Color("ff8ed1"), "accent": Color("fff052")},
		"Block World": {"road": Color("626c78"), "ground": Color("63b64b"), "accent": Color("45d06f")},
		"Metro": {"road": Color("555c69"), "ground": Color("2c3441"), "accent": Color("3f94e8")},
	}
	return themes[active_theme][slot]

func build_theme_environment() -> void:
	occupied_environment_spots.clear()
	build_custom_base_environment()
	build_category_placeholders()
	spawn_custom_environment_objects()
	if active_layout == "Closed Corridor":
		build_closed_layout_shell()
		build_closed_world_layers()
	else:
		build_open_world_layers()

func build_open_world_layers() -> void:
	# Three readable depth bands: near gameplay framing, mid-sized architecture,
	# and a distant skyline/landmark. They remain structural when custom props
	# are loaded, so imported models never float in an empty field.
	var accent := theme_color("accent")
	var structure := theme_color("road").darkened(0.22)
	if not has_models_in_category("BUILDINGS"):
		var building_spacing := lerpf(48.0, 18.0, map_fullness())
		for index in range(0, int(course_length / building_spacing) + 1):
			var z := -float(index) * building_spacing - 10.0
			var left_height := 1.8 + float(index % 3) * 0.8
			var right_height := 2.2 + float((index + 1) % 3) * 0.7
			create_box("MidTerraceL", Vector3(8.5, left_height, 13.0), Vector3(-17.0, left_height * 0.5 - 0.05, z), structure.lightened(0.05 * float(index % 2)))
			create_box("MidTerraceR", Vector3(8.5, right_height, 13.0), Vector3(17.0, right_height * 0.5 - 0.05, z - 16.0), structure.lightened(0.04 * float((index + 1) % 2)))
			if index % 2 == 0:
				create_box("MidTowerL", Vector3(3.2, 5.5 + float(index % 3), 3.2), Vector3(-20.0, 2.75, z - 7.0), accent.darkened(0.12))
			else:
				create_box("MidTowerR", Vector3(3.2, 6.2, 3.2), Vector3(20.0, 3.1, z - 7.0), accent.darkened(0.08))
	if not has_models_in_category("LANDMARK"):
		build_distant_landmark()

func has_models_in_category(category: String) -> bool:
	return category in custom_model_categories

func build_category_placeholders() -> void:
	# Only a missing layer receives simple placeholders. Loading a model in one
	# category replaces that layer without deleting the other parts of the scene.
	if not has_models_in_category("DECOR"):
		var placeholder_spacing := lerpf(14.0, 4.0, map_fullness())
		for index in range(0, int(course_length / placeholder_spacing) + 1):
			var z := -float(index) * placeholder_spacing - 8.0
			for side in [-1.0, 1.0]:
				# At lower settings alternate the sides; fuller maps populate both.
				if map_fullness() < 0.55 and (index + int((side + 1.0) * 0.5)) % 2 != 0:
					continue
				create_cylinder(Vector3(side * 7.5, 1.35, z), 0.18, 2.7, Color("72533b"))
				create_sphere(Vector3(side * 7.5, 3.25, z), 1.15, theme_color("accent"))
	if not has_models_in_category("CHARACTERS"):
		var character_spacing := lerpf(48.0, 16.0, map_fullness())
		for index in range(1, int(course_length / character_spacing) + 1):
			var z := -float(index) * character_spacing - 5.0
			var side := -1.0 if index % 2 == 0 else 1.0
			create_box("CharacterPlaceholder", Vector3(0.8, 1.8, 0.65), Vector3(side * 9.0, 0.9, z), Color("fff4d0"))
			create_sphere(Vector3(side * 9.0, 2.15, z), 0.42, Color("ffcf9d"))

func build_distant_landmark() -> void:
	var landmark_z := -course_length - 24.0
	var accent := theme_color("accent")
	var body := theme_color("road").darkened(0.28)
	create_box("LandmarkBody", Vector3(14.0, 8.0, 7.0), Vector3(0, 4.0, landmark_z), body)
	create_box("LandmarkTowerL", Vector3(4.0, 13.0, 4.0), Vector3(-7.0, 6.5, landmark_z), accent.darkened(0.08))
	create_box("LandmarkTowerR", Vector3(4.0, 13.0, 4.0), Vector3(7.0, 6.5, landmark_z), accent.darkened(0.08))
	create_box("LandmarkCrown", Vector3(20.0, 1.0, 5.0), Vector3(0, 12.5, landmark_z), accent)

func build_closed_world_layers() -> void:
	# Repeating bays and lights give a tunnel rhythm without placing geometry
	# in the playable three-lane corridor.
	var accent := theme_color("accent")
	var inset := theme_color("road").darkened(0.38)
	for index in range(0, int(course_length / 12.0) + 1):
		var z := -float(index * 12)
		create_box("WallInsetL", Vector3(0.38, 3.4, 7.0), Vector3(-10.1, 2.7, z), inset)
		create_box("WallInsetR", Vector3(0.38, 3.4, 7.0), Vector3(10.1, 2.7, z), inset.lightened(0.04))
		create_box("CeilingLight", Vector3(4.8, 0.12, 1.0), Vector3(0, 6.38, z), accent.lightened(0.22))
		if not has_models_in_category("BUILDINGS"):
			if index % 3 == 1:
				create_box("SideMachineL", Vector3(1.8, 2.8, 2.5), Vector3(-8.7, 1.4, z - 4.5), accent.darkened(0.2))
			else:
				create_box("SideMachineR", Vector3(1.8, 2.8, 2.5), Vector3(8.7, 1.4, z - 4.5), accent.darkened(0.16))

func build_custom_base_environment() -> void:
	# Keep only structural surfaces. Custom models replace all generated
	# decorative trees, buildings, landmarks and side props.
	match active_theme:
		"Candy":
			create_box("CandyGround", Vector3(72, 0.2, course_length + 20), Vector3(0, -0.38, -course_length * 0.5 + 5), theme_color("ground"))
		"Block World":
			create_box("GrassGround", Vector3(72, 0.35, course_length + 20), Vector3(0, -0.42, -course_length * 0.5 + 5), theme_color("ground"))
		"Metro":
			create_box("MetroGround", Vector3(34, 0.3, course_length + 20), Vector3(0, -0.4, -course_length * 0.5 + 5), theme_color("ground"))

func build_candy_environment() -> void:
	create_box("CandyGround", Vector3(72, 0.2, course_length + 20), Vector3(0, -0.38, -course_length * 0.5 + 5), theme_color("ground"))
	for index in range(0, int(course_length / 10.0) + 1):
		var z := -float(index * 10)
		create_tree(Vector3(-7.6, 0, z), index)
		create_tree(Vector3(7.6, 0, z - 5), index + 1)
		if index % 3 == 0:
			create_cylinder(Vector3(-10.5, 1.4, z - 5), 0.22, 2.8, Color.WHITE)
			create_sphere(Vector3(-10.5, 3.25, z - 5), 0.85, theme_color("accent"))
		if index % 4 == 1:
			create_sphere(Vector3(11.5, 2.1, z - 3), 1.8, Color("ff6d84"))
			create_sphere(Vector3(-12.5, 1.6, z - 7), 1.35, Color("75e8ff"))
		if index % 5 == 2:
			create_box("CandyMonument", Vector3(2.6, 5.5, 2.6), Vector3(12.8, 2.55, z), Color("8e55d7"))

func build_block_environment() -> void:
	create_box("GrassGround", Vector3(72, 0.35, course_length + 20), Vector3(0, -0.42, -course_length * 0.5 + 5), theme_color("ground"))
	for index in range(0, int(course_length / 22.0) + 1):
		var z := -float(index * 22)
		var height := 4.0 + float(index % 4) * 1.5
		create_box("BlockBuildingL", Vector3(7, height, 9), Vector3(-10.0, height * 0.5, z), Color("d79055").lightened(float(index % 3) * 0.08))
		create_box("BlockBuildingR", Vector3(7, height + 1, 9), Vector3(10.0, (height + 1) * 0.5, z - 10), Color("5e82bd").lightened(float(index % 2) * 0.1))
		create_box("BlockTrunk", Vector3(0.65, 2.5, 0.65), Vector3(-6.6, 1.25, z - 9), Color("8f613d"))
		create_box("BlockLeaves", Vector3(2.8, 2.4, 2.8), Vector3(-6.6, 3.4, z - 9), Color("3f9b52"))

func build_metro_environment() -> void:
	create_box("MetroGround", Vector3(34, 0.3, course_length + 20), Vector3(0, -0.4, -course_length * 0.5 + 5), theme_color("ground"))
	for index in range(0, int(course_length / 12.0) + 1):
		var z := -float(index * 12)
		create_box("ColumnL", Vector3(0.55, 6.0, 0.8), Vector3(-7.0, 2.8, z), Color("d08355"))
		create_box("ColumnR", Vector3(0.55, 6.0, 0.8), Vector3(7.0, 2.8, z), Color("d08355"))
		create_box("RoofBeam", Vector3(14.5, 0.35, 0.65), Vector3(0, 5.75, z), theme_color("accent"))
	for rail_x in [-3.2, 0.0, 3.2]:
		create_box("Rail", Vector3(0.12, 0.09, course_length), Vector3(rail_x, 0.04, -course_length * 0.5 + 5), Color("c5ced8"))

func build_closed_layout_shell() -> void:
	var wall_left := theme_color("accent").darkened(0.35)
	var wall_right := theme_color("accent").darkened(0.18)
	var ceiling_color := theme_color("road").darkened(0.55)
	create_box("LayoutLeftWall", Vector3(0.65, 7.0, course_length + 10), Vector3(-10.5, 3.15, -course_length * 0.5 + 5), wall_left)
	create_box("LayoutRightWall", Vector3(0.65, 7.0, course_length + 10), Vector3(10.5, 3.15, -course_length * 0.5 + 5), wall_right)
	create_box("LayoutCeiling", Vector3(21.5, 0.45, course_length + 10), Vector3(0, 6.65, -course_length * 0.5 + 5), ceiling_color)
	for index in range(0, int(course_length / 18.0) + 1):
		var z := -float(index * 18)
		create_box("LayoutBeam", Vector3(21.0, 0.28, 0.55), Vector3(0, 6.25, z), theme_color("accent"))

func spawn_custom_environment_objects() -> void:
	if custom_model_prototypes.is_empty():
		return
	var density := density_spin.value if density_spin else 50.0
	spawn_fence_lines()
	for category in ["BUILDINGS", "DECOR", "CHARACTERS", "LANDMARK"]:
		spawn_category(category, density)

func map_fullness() -> float:
	return clampf((density_spin.value if density_spin else 90.0) / 100.0, 0.0, 1.0)

func spawn_fence_lines() -> void:
	var indices := category_model_indices("FENCES")
	if indices.is_empty():
		return
	var fence_x := 6.2
	for side in [-1.0, 1.0]:
		var z := 4.0
		var section_number := 0
		while z > -course_length - 4.0:
			var model_index: int = indices[section_number % indices.size()]
			var prototype := custom_model_prototypes[model_index]
			var source_size: Vector3 = prototype.get_meta("source_size", Vector3.ONE)
			var source_height := maxf(source_size.y, 0.001)
			var fence_scale := 1.45 / source_height * custom_model_scales[model_index]
			var rotate_to_track := source_size.x > source_size.z
			var source_length := source_size.x if rotate_to_track else source_size.z
			var section_length := maxf(source_length * fence_scale * 0.96, 0.5)
			spawn_model_instance(model_index, Vector3(side * fence_x, 0, z), 1.45, PI * 0.5 if rotate_to_track else 0.0, false)
			z -= section_length
			section_number += 1

func category_model_indices(category: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(custom_model_categories.size()):
		if custom_model_categories[index] == category:
			result.append(index)
	return result

func spawn_category(category: String, density: float) -> void:
	var indices := category_model_indices(category)
	if indices.is_empty():
		return
	if category == "LANDMARK":
		spawn_model_instance(indices.pick_random(), Vector3(0, 0, -course_length - 24.0), 14.0, 0.0)
		return
	var base_spacing: float = {"BUILDINGS": 42.0, "DECOR": 8.0, "CHARACTERS": 30.0}[category]
	var fullness := clampf(density / 100.0, 0.0, 1.0)
	var spacing := base_spacing * lerpf(1.5, 0.35, fullness)
	var z := -10.0 - randf_range(0.0, spacing)
	while absf(z) < course_length:
		var x_range := Vector2(8.0, 12.0)
		var target_height := 4.0
		var clearance := 3.0
		match category:
			"BUILDINGS":
				x_range = Vector2(14.0, 25.0) if active_layout == "Open World" else Vector2(8.0, 9.0)
				target_height = 9.0 if active_layout == "Open World" else 4.8
				clearance = 8.0 if active_layout == "Open World" else 4.0
			"DECOR":
				x_range = Vector2(7.0, 10.0) if active_layout == "Open World" else Vector2(7.2, 8.7)
				target_height = 4.0
				clearance = 1.8
			"CHARACTERS":
				x_range = Vector2(7.0, 11.0) if active_layout == "Open World" else Vector2(7.2, 8.8)
				target_height = 2.4
				clearance = 2.0
		var side_count := 2 if fullness >= 0.6 else 1
		var first_side := -1.0 if randf() < 0.5 else 1.0
		for side_index in range(side_count):
			var side := first_side if side_index == 0 else -first_side
			var candidate := Vector3.ZERO
			var found_spot := false
			for attempt in range(12):
				candidate = Vector3(side * randf_range(x_range.x, x_range.y), 0, z + randf_range(-spacing * 0.3, spacing * 0.3))
				if is_environment_spot_free(candidate, clearance):
					found_spot = true
					break
			if found_spot:
				occupied_environment_spots.append({"position": candidate, "radius": clearance})
				spawn_model_instance(indices.pick_random(), candidate, target_height, randf_range(-0.35, 0.35))
		z -= spacing * randf_range(0.72, 1.3)

func is_environment_spot_free(candidate: Vector3, radius: float) -> bool:
	for spot in occupied_environment_spots:
		var other: Vector3 = spot.position
		var other_radius: float = spot.radius
		var distance_2d := Vector2(candidate.x, candidate.z).distance_to(Vector2(other.x, other.z))
		if distance_2d < radius + other_radius:
			return false
	return true

func spawn_model_instance(model_index: int, position: Vector3, target_height: float, rotation_y: float, randomize_scale: bool = true) -> void:
	var prototype := custom_model_prototypes[model_index]
	var instance := prototype.duplicate() as Node3D
	if not instance:
		return
	instance.visible = true
	var source_height: float = prototype.get_meta("source_height", 1.0)
	var scale_variation := randf_range(0.9, 1.12) if randomize_scale else 1.0
	var final_scale := target_height / maxf(source_height, 0.001) * custom_model_scales[model_index] * scale_variation
	instance.scale = Vector3.ONE * final_scale
	instance.rotation.y = rotation_y
	position.y = 0.0
	instance.position = position
	course_root.add_child(instance)
	# Imported GLB roots often have an offset pivot or helper nodes below the
	# visible object. Measure the final visible meshes in world space and move
	# the instance until their actual lowest point touches the ground.
	var visible_bottom := calculate_world_mesh_bottom(instance)
	instance.global_position.y -= visible_bottom
	# Keep scenery fully behind the fence. Imported models can have off-centre
	# pivots or wide foundations which otherwise poke through into the road.
	if custom_model_categories[model_index] != "FENCES" and absf(position.x) > 5.5:
		move_instance_behind_fence(instance, signf(position.x))

func move_instance_behind_fence(instance: Node3D, side: float) -> void:
	var bounds := calculate_world_mesh_bounds(instance)
	if bounds.size == Vector3.ZERO:
		return
	const SAFE_FENCE_X := 6.35
	if side > 0.0:
		var inward_edge := bounds.position.x
		if inward_edge < SAFE_FENCE_X:
			instance.global_position.x += SAFE_FENCE_X - inward_edge
	else:
		var inward_edge := bounds.end.x
		if inward_edge > -SAFE_FENCE_X:
			instance.global_position.x -= inward_edge + SAFE_FENCE_X

func calculate_world_mesh_bounds(root: Node3D) -> AABB:
	var combined := AABB(Vector3.ZERO, Vector3.ZERO)
	var has_bounds := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh or not mesh_instance.is_visible_in_tree():
			continue
		var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		combined = combined.merge(world_bounds) if has_bounds else world_bounds
		has_bounds = true
	return combined if has_bounds else AABB(Vector3.ZERO, Vector3.ZERO)

func calculate_world_mesh_bottom(root: Node3D) -> float:
	var bottom := INF
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh or not mesh_instance.is_visible_in_tree():
			continue
		var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		bottom = minf(bottom, world_bounds.position.y)
	return 0.0 if is_inf(bottom) else bottom

func open_model_file_dialog() -> void:
	model_file_dialog.popup_centered_ratio(0.78)

func load_models_from_category_folders() -> void:
	var folders := {
		"CHARACTERS": "res://модели/characters_animals",
		"BUILDINGS": "res://модели/buildings",
		"DECOR": "res://модели/decor",
		"FENCES": "res://модели/fences",
		"LANDMARK": "res://модели/landmark",
	}
	for category in folders:
		var folder_path: String = folders[category]
		for file_name in DirAccess.get_files_at(folder_path):
			if file_name.get_extension().to_lower() not in ["glb", "gltf"]:
				continue
			var resource_path := folder_path.path_join(file_name)
			load_external_model(ProjectSettings.globalize_path(resource_path), category)

func load_obstacle_models() -> void:
	for prototypes in obstacle_model_prototypes.values():
		for prototype in prototypes:
			if is_instance_valid(prototype):
				prototype.queue_free()
	obstacle_model_prototypes.clear()
	load_round_model_scales()
	for action in ["JUMP", "DUCK", "LEFT", "RIGHT", "SMASH"]:
		var folder_path := "res://раунды/%s/%s" % [active_round, action.to_lower()]
		var model_files: Array[String] = []
		for file_name in DirAccess.get_files_at(folder_path):
			if file_name.get_extension().to_lower() in ["glb", "gltf"]:
				model_files.append(file_name)
		model_files.sort()
		var prototypes: Array[Node3D] = []
		for file_name in model_files:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var resource_path := folder_path.path_join(file_name)
			var error := document.append_from_file(ProjectSettings.globalize_path(resource_path), state)
			if error != OK:
				push_warning("Could not load %s obstacle model %s: %s" % [action, file_name, error_string(error)])
				continue
			var generated := document.generate_scene(state)
			if generated is Node3D:
				var prototype := generated as Node3D
				prototype.name = "%sObstaclePrototype_%d" % [action.capitalize(), prototypes.size()]
				prototype.set_meta("round_model_key", "%s/%s" % [action.to_lower(), file_name])
				prototype.visible = false
				custom_library_root.add_child(prototype)
				prototypes.append(prototype)
		if not prototypes.is_empty():
			obstacle_model_prototypes[action] = prototypes

func create_obstacle_visual(action: String, position: Vector3, target_size: Vector3, variant_index: int = -1) -> Node3D:
	if not obstacle_model_prototypes.has(action):
		return null
	var prototypes: Array = obstacle_model_prototypes[action]
	if prototypes.is_empty():
		return null
	var next_index := variant_index
	if next_index < 0:
		next_index = int(obstacle_model_next_indices.get(action, 0)) % prototypes.size()
		obstacle_model_next_indices[action] = next_index + 1
	else:
		next_index %= prototypes.size()
	var prototype := prototypes[next_index] as Node3D
	var instance := prototype.duplicate() as Node3D
	instance.name = "%s_CustomVisual" % action
	instance.visible = true
	course_root.add_child(instance)
	var bounds := calculate_model_bounds(instance)
	if bounds.size == Vector3.ZERO:
		instance.queue_free()
		return null
	var user_scale := obstacle_scale_spin.value if obstacle_scale_spin else 1.0
	if action == "SMASH" and smash_actor_scale_spin:
		user_scale = smash_actor_scale_spin.value
	user_scale *= float(round_model_scales.get(str(prototype.get_meta("round_model_key", "")), 1.0))
	if action == "JUMP":
		# Keep height/depth proportional, but span almost the complete lane so
		# the obstacle cannot be mistaken for a small prop to walk around.
		var profile_scale := minf(target_size.y / maxf(bounds.size.y, 0.001), target_size.z / maxf(bounds.size.z, 0.001))
		instance.scale = Vector3(
			target_size.x / maxf(bounds.size.x, 0.001),
			profile_scale,
			profile_scale
		) * user_scale
	else:
		# Gate-like obstacles must span their complete gameplay area even when
		# the generated model has different source proportions.
		instance.scale = Vector3(
			target_size.x / maxf(bounds.size.x, 0.001),
			target_size.y / maxf(bounds.size.y, 0.001),
			target_size.z / maxf(bounds.size.z, 0.001)
		) * user_scale
	instance.position = position
	var world_bounds := calculate_world_mesh_bounds(instance)
	instance.global_position += Vector3(position.x - world_bounds.get_center().x, -world_bounds.position.y, position.z - world_bounds.get_center().z)
	if action == "DUCK":
		# Sink the gate supports into the road so the overhead beam reads as a
		# genuinely low clearance rather than a decorative arch.
		instance.global_position.y -= DUCK_VISUAL_SINK
	return instance

func load_external_models(paths: PackedStringArray) -> void:
	if custom_model_prototypes.is_empty() and custom_model_list.item_count > 0:
		custom_model_list.clear()
	for path in paths:
		load_external_model(path)

func load_external_model(path: String, category_override: String = "") -> void:
	var normalized_path := path.replace("\\", "/").to_lower()
	if normalized_path in custom_model_paths:
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		custom_model_list.add_item("ERROR: %s" % error_string(error))
		return
	var generated := document.generate_scene(state)
	if not generated is Node3D:
		custom_model_list.add_item("ERROR: model has no 3D root")
		generated.queue_free()
		return
	var prototype := generated as Node3D
	custom_library_root.add_child(prototype)
	var bounds := calculate_model_bounds(prototype)
	prototype.set_meta("source_height", maxf(bounds.size.y, 0.001))
	prototype.set_meta("source_bottom", bounds.position.y)
	prototype.set_meta("source_size", bounds.size)
	prototype.visible = false
	custom_model_prototypes.append(prototype)
	var file_name := path.get_file()
	custom_model_names.append(file_name)
	custom_model_scales.append(model_scale_spin.value)
	var category := category_override if not category_override.is_empty() else model_category_option.get_item_text(model_category_option.selected)
	custom_model_categories.append(category)
	custom_model_paths.append(normalized_path)
	var animation_path := find_paired_animation(path) if category == "CHARACTERS" else ""
	custom_animation_paths.append(animation_path)
	custom_model_list.add_item("[%s]  %s" % [category, file_name])
	var new_index := custom_model_prototypes.size() - 1
	custom_model_list.select(new_index)
	model_scale_spin.value = custom_model_scales[new_index]

func find_paired_animation(model_path: String) -> String:
	var expected_name := model_path.get_file().get_basename().to_lower()
	for sibling_name in DirAccess.get_files_at(model_path.get_base_dir()):
		if sibling_name.get_extension().to_lower() == "fbx" and sibling_name.get_basename().to_lower() == expected_name:
			return ProjectSettings.localize_path(model_path.get_base_dir().path_join(sibling_name))
	return ""

func calculate_model_bounds(root: Node3D) -> AABB:
	var combined := AABB(Vector3.ZERO, Vector3.ZERO)
	var found_mesh := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		var relative_transform := root.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		if found_mesh:
			combined = combined.merge(mesh_bounds)
		else:
			combined = mesh_bounds
			found_mesh = true
	if not found_mesh:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return combined

func remove_selected_custom_model() -> void:
	var selected := custom_model_list.get_selected_items()
	if selected.is_empty() or custom_model_prototypes.is_empty():
		return
	var index := selected[0]
	if index < 0 or index >= custom_model_prototypes.size():
		return
	var prototype := custom_model_prototypes[index]
	custom_model_prototypes.remove_at(index)
	custom_model_names.remove_at(index)
	custom_model_scales.remove_at(index)
	custom_model_categories.remove_at(index)
	custom_model_paths.remove_at(index)
	custom_animation_paths.remove_at(index)
	custom_model_list.remove_item(index)
	prototype.queue_free()
	if custom_model_prototypes.is_empty():
		custom_model_list.add_item("No custom 3D objects added")
		model_scale_spin.value = 1.0
	elif custom_model_list.item_count > 0:
		var next_index := mini(index, custom_model_list.item_count - 1)
		custom_model_list.select(next_index)
		model_scale_spin.value = custom_model_scales[next_index]

func select_custom_model(index: int) -> void:
	if index >= 0 and index < custom_model_scales.size():
		model_scale_spin.set_value_no_signal(custom_model_scales[index])

func update_selected_model_scale(value: float) -> void:
	var selected := custom_model_list.get_selected_items()
	if selected.is_empty():
		return
	var index := selected[0]
	if index >= 0 and index < custom_model_scales.size():
		custom_model_scales[index] = value

func refresh_companion_options() -> void:
	if not companion_option:
		return
	companion_option.clear()
	companion_option.add_item("None")
	companion_option.set_item_metadata(0, -1)
	var preferred_item := -1
	for index in range(custom_model_categories.size()):
		if custom_model_categories[index] == "CHARACTERS":
			companion_option.add_item(custom_model_names[index].get_basename().capitalize())
			companion_option.set_item_metadata(companion_option.item_count - 1, index)
			if index < custom_animation_paths.size() and not custom_animation_paths[index].is_empty():
				preferred_item = companion_option.item_count - 1
	if preferred_item >= 0:
		companion_option.select(preferred_item)
	elif companion_option.item_count > 1:
		companion_option.select(1)

func rebuild_companion() -> void:
	if companion_visual:
		companion_visual.queue_free()
		companion_visual = null
	companion_model_index = int(companion_option.get_selected_metadata()) if companion_option else -1
	if companion_model_index < 0 or companion_model_index >= custom_model_prototypes.size():
		companion_root.visible = false
		return
	companion_visual = instantiate_paired_companion(companion_model_index)
	if not companion_visual:
		companion_visual = custom_model_prototypes[companion_model_index].duplicate()
	companion_root.add_child(companion_visual)
	var bounds := calculate_model_bounds(companion_visual)
	var target_height := 1.55 * companion_size
	var fit_scale := target_height / maxf(bounds.size.y, 0.001) * custom_model_scales[companion_model_index]
	companion_visual.scale = Vector3.ONE * fit_scale
	companion_visual.position = Vector3(-bounds.get_center().x * fit_scale, -bounds.position.y * fit_scale, 0)
	companion_visual_base_y = companion_visual.position.y
	companion_visual.rotation.y = PI
	for animation_player in companion_visual.find_children("*", "AnimationPlayer", true, false):
		var player := animation_player as AnimationPlayer
		var animations := player.get_animation_list()
		if not animations.is_empty():
			var chosen := StringName()
			for animation_name in animations:
				if "run" in String(animation_name).to_lower() or "walk" in String(animation_name).to_lower():
					chosen = animation_name
					break
				if String(animation_name).to_upper() != "RESET" and chosen.is_empty():
					chosen = animation_name
			if not chosen.is_empty():
				var run_animation := player.get_animation(chosen)
				if run_animation:
					remove_companion_root_motion(run_animation)
					run_animation.loop_mode = Animation.LOOP_LINEAR
				player.active = true
				player.play(chosen)
	companion_run_time = 0.0
	companion_root.visible = true

func remove_companion_root_motion(animation: Animation) -> void:
	# Mixamo clips often move the hips forward. The runner's world movement is
	# controlled by code, so that displacement would snap back on every loop.
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var track_path := String(animation.track_get_path(track_index)).to_lower()
		if "hips" not in track_path and "root" not in track_path:
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		var first_position: Vector3 = animation.track_get_key_value(track_index, 0)
		for key_index in range(animation.track_get_key_count(track_index)):
			var position: Vector3 = animation.track_get_key_value(track_index, key_index)
			position.x = first_position.x
			position.z = first_position.z
			animation.track_set_key_value(track_index, key_index, position)

func instantiate_paired_companion(model_index: int) -> Node3D:
	if model_index < 0 or model_index >= custom_animation_paths.size():
		return null
	var animation_path := custom_animation_paths[model_index]
	if animation_path.is_empty():
		return null
	var packed_animation_scene := ResourceLoader.load(animation_path) as PackedScene
	if not packed_animation_scene:
		push_warning("Could not load companion animation: %s" % animation_path)
		return null
	var animated_model := packed_animation_scene.instantiate() as Node3D
	if not animated_model:
		return null
	var color_meshes := custom_model_prototypes[model_index].find_children("*", "MeshInstance3D", true, false)
	var animated_meshes := animated_model.find_children("*", "MeshInstance3D", true, false)
	if color_meshes.is_empty() or animated_meshes.is_empty():
		animated_model.queue_free()
		return null
	for mesh_index in range(animated_meshes.size()):
		var animated_mesh := animated_meshes[mesh_index] as MeshInstance3D
		var color_mesh := color_meshes[mini(mesh_index, color_meshes.size() - 1)] as MeshInstance3D
		if not animated_mesh.mesh or not color_mesh.mesh:
			continue
		for surface_index in range(animated_mesh.mesh.get_surface_count()):
			var color_surface := mini(surface_index, color_mesh.mesh.get_surface_count() - 1)
			var material := color_mesh.get_active_material(color_surface)
			if material:
				animated_mesh.set_surface_override_material(surface_index, material)
	return animated_model

func update_companion(delta: float) -> void:
	if not companion_visual or not companion_root.visible:
		return
	if countdown <= 0.0 and not finished:
		companion_run_time += delta
	var elapsed_run_time := distance / maxf(speed, 0.001)
	if elapsed_run_time >= 10.2:
		companion_root.visible = false
		return
	var side := 2.35
	var forward_offset := -5.2
	if elapsed_run_time > 7.0:
		var overtake_phase := clampf((elapsed_run_time - 7.0) / 2.0, 0.0, 1.0)
		forward_offset = lerpf(-5.2, 3.2, smoothstep(0.0, 1.0, overtake_phase))
		side = lerpf(2.35, 1.6, overtake_phase)
	var companion_progress := distance - forward_offset
	var jump_offset := 0.0
	for event in events:
		if event.action != "JUMP":
			continue
		var jump_distance := maxf(speed * 0.82, 0.001)
		var jump_phase := (companion_progress - (float(event.distance) - 1.5)) / jump_distance
		if jump_phase >= 0.0 and jump_phase <= 1.0:
			jump_offset = sin(jump_phase * PI) * 1.8 * companion_size
			break
	var target := Vector3(camera_rig.position.x + side, jump_offset, camera_rig.position.z + forward_offset)
	companion_root.position = companion_root.position.lerp(target, 1.0 - exp(-7.0 * delta))
	var run_amount := 1.0 if countdown <= 0.0 and not finished else 0.2
	var target_bob := companion_visual_base_y + sin(companion_run_time * 11.0) * 0.07 * run_amount
	companion_visual.position.y = lerpf(companion_visual.position.y, target_bob, minf(delta * 12.0, 1.0))
	companion_visual.rotation.z = sin(companion_run_time * 5.5) * 0.035 * run_amount

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not builder_active:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			builder_active = true
			builder_overlay.visible = true
			get_viewport().set_input_as_handled()

func create_dodge_gate(z: float, action: String, color: Color) -> void:
	# Игрок начинает каждый манёвр из центра. Две полосы перекрыты,
	# поэтому остаётся только коридор в сторону указанного действия.
	var open_lane := 2 if action == "RIGHT" else 0
	# Pick one variant for the event and duplicate that exact model across both
	# blocked lanes. The next LEFT/RIGHT event advances to the next variant.
	var variants: Array = obstacle_model_prototypes.get(action, [])
	var variant_index := -1
	if not variants.is_empty():
		variant_index = int(obstacle_model_next_indices.get(action, 0)) % variants.size()
		obstacle_model_next_indices[action] = variant_index + 1
	for obstacle_lane in range(3):
		if obstacle_lane != open_lane:
			create_obstacle(obstacle_lane, z, color, action, 4.8, variant_index)

func create_duck_gate(z: float, color: Color) -> void:
	# Верхняя балка оставляет проход только для приседания.
	if create_obstacle_visual("DUCK", Vector3(0, 0, z), Vector3(10.5, 4.7, 1.8)):
		return
	create_box("DuckGateTop", Vector3(10.5, 1.35, 1.8), Vector3(0, 2.35, z), color)
	create_box("DuckGateLeft", Vector3(0.65, 4.7, 1.8), Vector3(-5.0, 2.1, z), color)
	create_box("DuckGateRight", Vector3(0.65, 4.7, 1.8), Vector3(5.0, 2.1, z), color)

func create_smash_gate(z: float, color: Color) -> Array[Node3D]:
	# One unified wall mesh. Later its two materials will receive the
	# user-selected intact and cracked image textures.
	var targets: Array[Node3D] = []
	var custom_visual := create_obstacle_visual("SMASH", Vector3(0, 0, z), Vector3(3.2, 4.6, 2.4))
	if custom_visual:
		custom_visual.set_meta("smash_actor", true)
		custom_visual.set_meta("spawn_z", custom_visual.global_position.z)
		targets.append(custom_visual)
		return targets
	var wall := create_box("SmashWall", Vector3(10.5, 4.6, 0.55), Vector3(0, 2.15, z), color)
	var intact_material := make_material(color)
	if ResourceLoader.exists("res://assets/smash_wall/intact.png"):
		intact_material.albedo_texture = load("res://assets/smash_wall/intact.png")
	wall.material_override = intact_material
	var cracked_material := make_material(color.darkened(0.38))
	if ResourceLoader.exists("res://assets/smash_wall/cracked.png"):
		cracked_material.albedo_texture = load("res://assets/smash_wall/cracked.png")
	cracked_material.emission_enabled = true
	cracked_material.emission = Color("ff6a4d")
	cracked_material.emission_energy_multiplier = 0.35
	wall.set_meta("cracked_material", cracked_material)
	targets.append(wall)
	return targets

func create_obstacle(obstacle_lane: int, z: float, color: Color, action: String, height: float, variant_index: int = -1) -> void:
	var body := StaticBody3D.new()
	body.name = "Obstacle_%s" % action
	body.position = Vector3(LANE_X[obstacle_lane], height * 0.5, z)
	body.set_meta("action", action)
	var obstacle_size := Vector3(2.8, 1.35, 1.35) if action == "JUMP" else Vector3(2.55, height, 1.6)
	if action == "JUMP":
		body.position.y = 0.675
	var custom_visual := create_obstacle_visual(action, Vector3(LANE_X[obstacle_lane], 0, z), obstacle_size, variant_index)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%s_Visual" % action
	var mesh := BoxMesh.new()
	mesh.size = obstacle_size
	mesh_instance.mesh = mesh
	var obstacle_material := make_material(color)
	obstacle_material.emission_enabled = true
	obstacle_material.emission = color
	obstacle_material.emission_energy_multiplier = 0.32
	mesh_instance.material_override = obstacle_material
	if not custom_visual:
		body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = obstacle_size
	shape.shape = box
	body.add_child(shape)
	course_root.add_child(body)
func create_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := make_material(color)
	var texture_slot := ""
	if node_name == "Road":
		texture_slot = "road"
	elif node_name.ends_with("Ground"):
		texture_slot = "ground"
	if texture_slot in surface_textures:
		material.albedo_color = Color.WHITE
		material.albedo_texture = surface_textures[texture_slot]
		material.texture_repeat = 1
		# StandardMaterial3D uses UV X/Y. On the horizontal box face, X is the
		# surface width and Y is its length; the third component is not a UV axis.
		material.uv1_scale = Vector3(maxf(size.x / SURFACE_TILE_SIZE, 1.0), maxf(size.z / SURFACE_TILE_SIZE, 1.0), 1.0)
	mesh_instance.material_override = material
	course_root.add_child(mesh_instance)
	return mesh_instance

func create_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	item.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.material_override = make_material(color)
	course_root.add_child(item)

func create_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	item.position = pos
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	item.mesh = mesh
	item.material_override = make_material(color)
	course_root.add_child(item)

func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	return material

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(190, 24)
	progress_bar.size = Vector2(900, 34)
	progress_bar.max_value = course_length
	progress_bar.show_percentage = false
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color("18213f")
	progress_background.border_color = Color("55e8ff")
	progress_background.set_border_width_all(3)
	progress_background.set_corner_radius_all(12)
	progress_bar.add_theme_stylebox_override("background", progress_background)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("ff2fa8")
	progress_fill.border_color = Color("fff052")
	progress_fill.set_border_width_all(3)
	progress_fill.set_corner_radius_all(12)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	layer.add_child(progress_bar)

	distance_label = Label.new()
	distance_label.position = Vector2(540, 66)
	distance_label.size = Vector2(200, 40)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.add_theme_font_size_override("font_size", 25)
	layer.add_child(distance_label)

	action_label = Label.new()
	action_label.position = Vector2(390, 280)
	action_label.size = Vector2(500, 80)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 52)
	action_label.add_theme_color_override("font_color", Color("fff052"))
	action_label.add_theme_constant_override("outline_size", 10)
	action_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12, 0.95))
	layer.add_child(action_label)

	action_icon = TextureRect.new()
	action_icon.position = Vector2(520, 82)
	action_icon.size = Vector2(240, 190)
	action_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	action_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	action_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_icon.visible = false
	layer.add_child(action_icon)

	feedback_label = Label.new()
	feedback_label.position = Vector2(390, 215)
	feedback_label.size = Vector2(500, 90)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 58)
	feedback_label.add_theme_constant_override("outline_size", 11)
	feedback_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.98))
	layer.add_child(feedback_label)

	flash_overlay = ColorRect.new()
	flash_overlay.position = Vector2.ZERO
	flash_overlay.size = Vector2(1280, 720)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.color = Color(0, 0, 0, 0)
	layer.add_child(flash_overlay)
	layer.move_child(flash_overlay, 0)

	var help := Label.new()
	help.position = Vector2(24, 650)
	help.text = "A/← LEFT   D/→ RIGHT   SPACE/W/↑ JUMP   S/↓ DUCK   R RESTART   TAB SETTINGS"
	help.add_theme_font_size_override("font_size", 18)
	help.visible = false
	layer.add_child(help)

	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(28, 110)
	settings_panel.size = Vector2(310, 300)
	settings_panel.visible = false
	layer.add_child(settings_panel)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	settings_panel.add_child(settings)
	var title := Label.new()
	title.text = "PROTOTYPE SETTINGS"
	title.add_theme_font_size_override("font_size", 22)
	settings.add_child(title)
	add_setting(settings, "Speed", 6, 24, speed, func(value): speed = value)
	add_setting(settings, "Jump Height", 1, 4, jump_height, func(value): jump_height = value)
	add_setting(settings, "Lane Smoothness", 3, 16, lane_smoothness, func(value): lane_smoothness = value)
	var button := Button.new()
	button.text = "RESTART COURSE"
	button.pressed.connect(restart)
	settings.add_child(button)
	var hint := Label.new()
	hint.text = "TAB — show/hide panel"
	settings.add_child(hint)

func add_setting(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, initial: float, callback: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.1
	slider.value = initial
	slider.value_changed.connect(callback)
	parent.add_child(slider)

func build_builder_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	builder_overlay = ColorRect.new()
	builder_overlay.color = Color(0.035, 0.055, 0.10, 0.97)
	builder_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(builder_overlay)

	var panel := PanelContainer.new()
	panel.position = Vector2(245, 18)
	panel.size = Vector2(790, 684)
	builder_overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = 750
	scroll.add_child(content)

	var heading := Label.new()
	heading.text = "POV RUNNER BUILDER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("fff052"))
	content.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Build one custom round — then record it and create the next one"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	var round_row := HBoxContainer.new()
	round_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(round_row)
	var round_label := Label.new()
	round_label.text = "ROUND CONTENT   "
	round_label.add_theme_font_size_override("font_size", 20)
	round_row.add_child(round_label)
	round_option = OptionButton.new()
	var round_names: Array[String] = []
	for folder_name in DirAccess.get_directories_at("res://раунды"):
		round_names.append(folder_name)
	round_names.sort()
	for folder_name in round_names:
		round_option.add_item(folder_name.replace("_", " ").capitalize())
		round_option.set_item_metadata(round_option.item_count - 1, folder_name)
	round_option.custom_minimum_size = Vector2(210, 42)
	round_option.item_selected.connect(on_round_content_selected)
	round_row.add_child(round_option)

	var image_panels_row := HBoxContainer.new()
	image_panels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(image_panels_row)
	image_panels_check = CheckButton.new()
	image_panels_check.text = "RANDOM IMAGE PANELS"
	image_panels_check.button_pressed = true
	image_panels_check.add_theme_font_size_override("font_size", 20)
	image_panels_row.add_child(image_panels_check)

	var duration_row := HBoxContainer.new()
	duration_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(duration_row)
	var duration_label := Label.new()
	duration_label.text = "VIDEO DURATION (SECONDS)   "
	duration_label.add_theme_font_size_override("font_size", 20)
	duration_row.add_child(duration_label)
	duration_spin = SpinBox.new()
	duration_spin.min_value = 12
	duration_spin.max_value = 180
	duration_spin.step = 1
	duration_spin.value = 60
	duration_spin.custom_minimum_size = Vector2(130, 42)
	duration_row.add_child(duration_spin)

	var theme_row := HBoxContainer.new()
	theme_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(theme_row)
	var theme_label := Label.new()
	theme_label.text = "ENVIRONMENT THEME   "
	theme_label.add_theme_font_size_override("font_size", 20)
	theme_row.add_child(theme_label)
	theme_option = OptionButton.new()
	theme_option.add_item("Candy")
	theme_option.add_item("Block World")
	theme_option.add_item("Metro")
	theme_option.custom_minimum_size = Vector2(210, 42)
	theme_row.add_child(theme_option)

	var layout_row := HBoxContainer.new()
	layout_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(layout_row)
	var layout_label := Label.new()
	layout_label.text = "WORLD LAYOUT   "
	layout_label.add_theme_font_size_override("font_size", 20)
	layout_row.add_child(layout_label)
	layout_option = OptionButton.new()
	layout_option.add_item("Open World")
	layout_option.add_item("Closed Corridor")
	layout_option.custom_minimum_size = Vector2(210, 42)
	layout_row.add_child(layout_option)

	var density_row := HBoxContainer.new()
	density_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(density_row)
	var density_label := Label.new()
	density_label.text = "MAP FULLNESS   "
	density_label.add_theme_font_size_override("font_size", 20)
	density_row.add_child(density_label)
	density_spin = SpinBox.new()
	density_spin.min_value = 0
	density_spin.max_value = 100
	density_spin.step = 5
	density_spin.value = 100
	density_spin.suffix = "%"
	density_spin.custom_minimum_size = Vector2(130, 42)
	density_row.add_child(density_spin)

	var obstacle_scale_row := HBoxContainer.new()
	obstacle_scale_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(obstacle_scale_row)
	var obstacle_scale_label := Label.new()
	obstacle_scale_label.text = "OBSTACLE MODEL SCALE   "
	obstacle_scale_label.add_theme_font_size_override("font_size", 20)
	obstacle_scale_row.add_child(obstacle_scale_label)
	obstacle_scale_spin = SpinBox.new()
	obstacle_scale_spin.min_value = 0.25
	obstacle_scale_spin.max_value = 3.0
	obstacle_scale_spin.step = 0.05
	obstacle_scale_spin.value = 1.0
	obstacle_scale_spin.custom_minimum_size = Vector2(130, 42)
	obstacle_scale_row.add_child(obstacle_scale_spin)

	var smash_actor_scale_row := HBoxContainer.new()
	smash_actor_scale_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(smash_actor_scale_row)
	var smash_actor_scale_label := Label.new()
	smash_actor_scale_label.text = "SMASH CHARACTER SIZE   "
	smash_actor_scale_label.add_theme_font_size_override("font_size", 20)
	smash_actor_scale_row.add_child(smash_actor_scale_label)
	smash_actor_scale_spin = SpinBox.new()
	smash_actor_scale_spin.min_value = 0.35
	smash_actor_scale_spin.max_value = 3.0
	smash_actor_scale_spin.step = 0.05
	smash_actor_scale_spin.value = 1.0
	smash_actor_scale_spin.custom_minimum_size = Vector2(130, 42)
	smash_actor_scale_row.add_child(smash_actor_scale_spin)

	var smash_hit_gap_row := HBoxContainer.new()
	smash_hit_gap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(smash_hit_gap_row)
	var smash_hit_gap_label := Label.new()
	smash_hit_gap_label.text = "SMASH HIT DISTANCE   "
	smash_hit_gap_label.add_theme_font_size_override("font_size", 20)
	smash_hit_gap_row.add_child(smash_hit_gap_label)
	smash_hit_gap_spin = SpinBox.new()
	smash_hit_gap_spin.min_value = 0.2
	smash_hit_gap_spin.max_value = 8.0
	smash_hit_gap_spin.step = 0.1
	smash_hit_gap_spin.value = DEFAULT_SMASH_HIT_GAP
	smash_hit_gap_spin.suffix = " m"
	smash_hit_gap_spin.custom_minimum_size = Vector2(130, 42)
	smash_hit_gap_row.add_child(smash_hit_gap_spin)

	var companion_row := HBoxContainer.new()
	companion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(companion_row)
	var companion_label := Label.new()
	companion_label.text = "RUNNING COMPANION   "
	companion_label.add_theme_font_size_override("font_size", 20)
	companion_row.add_child(companion_label)
	companion_option = OptionButton.new()
	companion_option.add_item("None")
	companion_option.set_item_metadata(0, -1)
	companion_option.custom_minimum_size = Vector2(260, 42)
	companion_row.add_child(companion_option)
	var companion_scale_label := Label.new()
	companion_scale_label.text = "   SIZE"
	companion_row.add_child(companion_scale_label)
	companion_scale_spin = SpinBox.new()
	companion_scale_spin.min_value = 0.35
	companion_scale_spin.max_value = 3.0
	companion_scale_spin.step = 0.05
	companion_scale_spin.value = 1.0
	companion_scale_spin.custom_minimum_size = Vector2(105, 42)
	companion_row.add_child(companion_scale_spin)

	var model_row := HBoxContainer.new()
	model_row.alignment = BoxContainer.ALIGNMENT_CENTER
	model_row.add_theme_constant_override("separation", 12)
	content.add_child(model_row)
	var category_label := Label.new()
	category_label.text = "OBJECT TYPE"
	model_row.add_child(category_label)
	model_category_option = OptionButton.new()
	model_category_option.add_item("CHARACTERS")
	model_category_option.add_item("BUILDINGS")
	model_category_option.add_item("DECOR")
	model_category_option.add_item("FENCES")
	model_category_option.add_item("LANDMARK")
	model_category_option.custom_minimum_size = Vector2(175, 44)
	model_row.add_child(model_category_option)
	var add_model_button := Button.new()
	add_model_button.text = "ADD MODELS"
	add_model_button.custom_minimum_size = Vector2(165, 44)
	add_model_button.pressed.connect(open_model_file_dialog)
	model_row.add_child(add_model_button)
	var remove_model_button := Button.new()
	remove_model_button.text = "REMOVE SELECTED"
	remove_model_button.custom_minimum_size = Vector2(150, 44)
	remove_model_button.pressed.connect(remove_selected_custom_model)
	model_row.add_child(remove_model_button)
	var scale_label := Label.new()
	scale_label.text = "SCALE"
	model_row.add_child(scale_label)
	model_scale_spin = SpinBox.new()
	model_scale_spin.min_value = 0.05
	model_scale_spin.max_value = 20.0
	model_scale_spin.step = 0.05
	model_scale_spin.value = 1.0
	model_scale_spin.custom_minimum_size = Vector2(115, 42)
	model_scale_spin.value_changed.connect(update_selected_model_scale)
	model_row.add_child(model_scale_spin)

	custom_model_list = ItemList.new()
	custom_model_list.custom_minimum_size = Vector2(0, 58)
	custom_model_list.add_item("No custom 3D objects added")
	custom_model_list.item_selected.connect(select_custom_model)
	content.add_child(custom_model_list)

	var round_models_title := Label.new()
	round_models_title.text = "ROUND MODELS — INDIVIDUAL SIZE"
	round_models_title.add_theme_font_size_override("font_size", 21)
	content.add_child(round_models_title)
	var round_models_box := HBoxContainer.new()
	round_models_box.add_theme_constant_override("separation", 12)
	content.add_child(round_models_box)
	var round_models_left := VBoxContainer.new()
	round_models_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_models_box.add_child(round_models_left)
	round_model_list = ItemList.new()
	round_model_list.custom_minimum_size = Vector2(470, 170)
	round_model_list.item_selected.connect(select_round_model)
	round_models_left.add_child(round_model_list)
	var round_scale_row := HBoxContainer.new()
	round_scale_row.alignment = BoxContainer.ALIGNMENT_CENTER
	round_models_left.add_child(round_scale_row)
	var round_scale_label := Label.new()
	round_scale_label.text = "SELECTED MODEL SIZE   "
	round_scale_row.add_child(round_scale_label)
	round_model_scale_spin = SpinBox.new()
	round_model_scale_spin.min_value = 0.1
	round_model_scale_spin.max_value = 5.0
	round_model_scale_spin.step = 0.05
	round_model_scale_spin.value = 1.0
	round_model_scale_spin.custom_minimum_size = Vector2(120, 42)
	round_model_scale_spin.value_changed.connect(update_selected_round_model_scale)
	round_scale_row.add_child(round_model_scale_spin)
	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(250, 210)
	preview_container.stretch = true
	round_models_box.add_child(preview_container)
	round_preview_viewport = SubViewport.new()
	round_preview_viewport.size = Vector2i(500, 420)
	round_preview_viewport.own_world_3d = true
	round_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	round_preview_viewport.transparent_bg = false
	preview_container.add_child(round_preview_viewport)
	round_preview_root = Node3D.new()
	round_preview_viewport.add_child(round_preview_root)
	round_preview_camera = Camera3D.new()
	round_preview_camera.position = Vector3(0, 1.4, 5.0)
	round_preview_camera.current = true
	round_preview_viewport.add_child(round_preview_camera)
	var preview_light := DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-35, -25, 0)
	preview_light.light_energy = 1.4
	round_preview_viewport.add_child(preview_light)
	model_file_dialog = FileDialog.new()
	model_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	model_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	model_file_dialog.filters = PackedStringArray(["*.glb, *.gltf ; glTF 3D Models"])
	model_file_dialog.files_selected.connect(load_external_models)
	builder_overlay.add_child(model_file_dialog)

	create_round_selector(content, "MOVEMENTS IN THIS ROUND", round_checks, ["JUMP"])

	var note := Label.new()
	note.text = "The builder automatically spaces obstacles and keeps the route passable."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("a8b7d8"))
	content.add_child(note)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "FULLSCREEN PLAY — FOR RECORDING"
	fullscreen_button.custom_minimum_size = Vector2(0, 58)
	fullscreen_button.add_theme_font_size_override("font_size", 22)
	fullscreen_button.pressed.connect(start_fullscreen_round)
	content.add_child(fullscreen_button)
	var play_button := Button.new()
	play_button.text = "BUILD & PLAY"
	play_button.custom_minimum_size = Vector2(0, 58)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.pressed.connect(apply_builder_settings)
	content.add_child(play_button)

func start_fullscreen_round() -> void:
	apply_builder_settings()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func create_round_selector(parent: VBoxContainer, title_text: String, target: Dictionary, defaults: Array[String]) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 21)
	parent.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	parent.add_child(row)
	for action in ["JUMP", "LEFT", "RIGHT", "DUCK", "SMASH"]:
		var check := CheckButton.new()
		check.text = action
		check.button_pressed = action in defaults
		check.add_theme_font_size_override("font_size", 18)
		row.add_child(check)
		target[action] = check

func selected_actions(checks: Dictionary) -> Array[String]:
	var selected: Array[String] = []
	for action in ["JUMP", "LEFT", "RIGHT", "DUCK", "SMASH"]:
		var check: CheckButton = checks[action]
		if check.button_pressed:
			selected.append(action)
	if selected.is_empty():
		selected.append("JUMP")
	return selected

func on_round_content_selected(index: int) -> void:
	active_round = str(round_option.get_item_metadata(index))
	load_obstacle_models()
	refresh_round_model_list()

func round_model_settings_path() -> String:
	return "res://раунды/%s/model_settings.cfg" % active_round

func load_round_model_scales() -> void:
	round_model_scales.clear()
	var config := ConfigFile.new()
	if config.load(round_model_settings_path()) != OK:
		return
	for key in config.get_section_keys("scales"):
		round_model_scales[key] = float(config.get_value("scales", key, 1.0))

func save_round_model_scales() -> void:
	var config := ConfigFile.new()
	for key in round_model_scales:
		config.set_value("scales", key, float(round_model_scales[key]))
	var error := config.save(round_model_settings_path())
	if error != OK:
		push_warning("Could not save round model sizes: %s" % error_string(error))

func refresh_round_model_list() -> void:
	if not round_model_list:
		return
	round_model_list.clear()
	round_model_entries.clear()
	for action in ["JUMP", "DUCK", "LEFT", "RIGHT", "SMASH"]:
		for prototype in obstacle_model_prototypes.get(action, []):
			var key := str(prototype.get_meta("round_model_key", ""))
			round_model_entries.append({"action": action, "prototype": prototype, "key": key})
			round_model_list.add_item("[%s]  %s   × %.2f" % [action, key.get_file(), float(round_model_scales.get(key, 1.0))])
	if round_model_entries.is_empty():
		round_model_list.add_item("No GLB/GLTF models in %s" % active_round)
		clear_round_model_preview()
		return
	round_model_list.select(0)
	select_round_model(0)

func select_round_model(index: int) -> void:
	if index < 0 or index >= round_model_entries.size():
		return
	var entry := round_model_entries[index]
	var prototype := entry.get("prototype") as Node3D
	if not is_instance_valid(prototype):
		refresh_round_model_list()
		return
	round_model_scale_spin.set_value_no_signal(float(round_model_scales.get(entry.key, 1.0)))
	show_round_model_preview(prototype, float(round_model_scales.get(entry.key, 1.0)))

func update_selected_round_model_scale(value: float) -> void:
	var selected := round_model_list.get_selected_items()
	if selected.is_empty() or selected[0] >= round_model_entries.size():
		return
	var index := selected[0]
	var entry := round_model_entries[index]
	var prototype := entry.get("prototype") as Node3D
	if not is_instance_valid(prototype):
		refresh_round_model_list()
		return
	round_model_scales[entry.key] = value
	round_model_list.set_item_text(index, "[%s]  %s   × %.2f" % [entry.action, str(entry.key).get_file(), value])
	save_round_model_scales()
	show_round_model_preview(prototype, value)

func clear_round_model_preview() -> void:
	if not round_preview_root:
		return
	for child in round_preview_root.get_children():
		child.queue_free()

func show_round_model_preview(prototype: Node3D, individual_scale: float) -> void:
	clear_round_model_preview()
	if not is_instance_valid(prototype):
		return
	var visual := prototype.duplicate() as Node3D
	visual.visible = true
	round_preview_root.add_child(visual)
	var bounds := calculate_model_bounds(visual)
	var fit_scale := 2.6 / maxf(maxf(bounds.size.x, bounds.size.y), maxf(bounds.size.z, 0.001))
	visual.scale = Vector3.ONE * fit_scale * individual_scale
	visual.position = -bounds.get_center() * visual.scale
	round_preview_camera.look_at(Vector3.ZERO, Vector3.UP)

func apply_builder_settings() -> void:
	video_duration = duration_spin.value
	companion_size = companion_scale_spin.value
	if round_option and round_option.item_count > 0:
		active_round = str(round_option.get_item_metadata(round_option.selected))
	load_obstacle_models()
	refresh_round_model_list()
	load_surface_textures()
	load_background_panorama()
	active_theme = theme_option.get_item_text(theme_option.selected)
	active_layout = layout_option.get_item_text(layout_option.selected)
	apply_theme_environment()
	course_length = video_duration * speed
	events.clear()
	var chosen_actions := selected_actions(round_checks)
	var event_time := 4.0
	var action_index := 0
	while event_time < video_duration - 2.0:
		var action := chosen_actions[action_index % chosen_actions.size()]
		action_index += 1
		events.append({"distance": event_time * speed, "action": action})
		event_time += 4.0
	progress_bar.max_value = course_length
	build_course()
	rebuild_companion()
	restart()
	builder_active = false
	builder_overlay.visible = false

func apply_theme_environment() -> void:
	match active_theme:
		"Candy":
			world_environment.background_color = Color("55baf2")
			world_environment.ambient_light_color = Color("fff5f7")
			world_environment.ambient_light_energy = 0.36
			sun_light.light_energy = 0.70
		"Block World":
			world_environment.background_color = Color("75b9ee")
			world_environment.ambient_light_color = Color("e8f3ff")
			world_environment.ambient_light_energy = 0.34
			sun_light.light_energy = 0.76
		"Metro":
			world_environment.background_color = Color("18202b")
			world_environment.ambient_light_color = Color("9db4d1")
			world_environment.ambient_light_energy = 0.24
			sun_light.light_energy = 0.55

func _process(delta: float) -> void:
	if builder_active:
		return
	if Input.is_action_just_pressed("move_left") and not finished and countdown <= 0.0 and dodge_direction == 0:
		dodge_direction = -1
		dodge_time = 0.0
		arm_action("LEFT")
		play_sfx("DODGE", -0.55)
	if Input.is_action_just_pressed("move_right") and not finished and countdown <= 0.0 and dodge_direction == 0:
		dodge_direction = 1
		dodge_time = 0.0
		arm_action("RIGHT")
		play_sfx("DODGE", 0.55)
	if Input.is_action_just_pressed("jump") and not jumping and not finished and countdown <= 0.0:
		jumping = true
		jump_time = 0.0
		arm_action("JUMP")
		play_sfx("JUMP")
	if Input.is_action_just_pressed("duck") and not ducking and not jumping and not finished and countdown <= 0.0:
		ducking = true
		duck_time = 0.0
		arm_action("DUCK")
		play_sfx("DUCK")
	if Input.is_key_pressed(KEY_R):
		restart()

	if smash_sequence_active:
		update_smash_sequence(delta)
		if smash_sequence_active and smash_event_has_actor(active_smash_event):
			distance = minf(distance + speed * delta, course_length)
	elif countdown > 0.0:
		countdown -= delta
		action_label.text = str(maxi(1, ceili(countdown)))
		if countdown <= 0.0:
			action_label.text = "GO!"
	elif not finished:
		distance += speed * delta
		evaluate_event()
		if distance >= course_length:
			distance = course_length
			finished = true
			action_label.text = "FINISH!"
			action_icon.visible = false

	if jumping:
		jump_time += delta
		var duration := 0.85
		var phase := clampf(jump_time / duration, 0.0, 1.0)
		vertical_offset = sin(phase * PI) * jump_height
		if phase >= 1.0:
			jumping = false
			vertical_offset = 0.0
			play_sfx("LAND")

	if ducking:
		duck_time += delta
		var duck_phase := clampf(duck_time / DUCK_DURATION, 0.0, 1.0)
		duck_offset = sin(duck_phase * PI) * DUCK_DEPTH
		if duck_phase >= 1.0:
			ducking = false
			duck_offset = 0.0

	var target_x := 0.0
	if dodge_direction != 0:
		dodge_time += delta
		var dodge_phase := clampf(dodge_time / DODGE_DURATION, 0.0, 1.0)
		# Синус даёт плавный уход из центра, короткий проход сбоку и возврат.
		target_x = sin(dodge_phase * PI) * LANE_X[1 + dodge_direction]
		if dodge_phase >= 1.0:
			dodge_direction = 0
			dodge_time = 0.0
			target_x = 0.0
	camera_rig.position.x = lerpf(camera_rig.position.x, target_x, 1.0 - exp(-lane_smoothness * delta))
	camera_rig.position.y = start_position.y + vertical_offset - duck_offset + sin(distance * 1.3) * 0.035
	camera_rig.position.z = start_position.z - distance
	progress_bar.value = distance
	distance_label.text = "%d / %d M" % [int(distance), int(course_length)]
	if not finished and countdown <= 0.0:
		update_action_hint()
	update_smash_actors()
	update_image_panels()
	update_feedback(delta)
	update_companion(delta)

func update_image_panels() -> void:
	for panel_event in image_panel_events:
		if not bool(panel_event.triggered) and distance >= float(panel_event.distance):
			panel_event.triggered = true
			show_result(true)

func update_action_hint() -> void:
	action_label.text = ""
	action_icon.visible = false
	if event_index < events.size():
		var event := events[event_index]
		var gap: float = float(event.distance) - distance
		if gap > 0.0 and gap < 18.0:
			action_label.text = str(event.action)
			set_action_icon(str(event.action))

func update_smash_actors() -> void:
	# Static models still feel alive: as their event approaches they move a few
	# metres towards the runner. Animated variants can replace this fallback later.
	for event in events:
		if str(event.action) != "SMASH" or not event.has("targets"):
			continue
		var approach := clampf((18.0 - (float(event.distance) - distance)) / 18.0, 0.0, 1.0)
		approach = approach * approach * (3.0 - 2.0 * approach)
		for target in event.targets:
			if is_instance_valid(target) and target.has_meta("smash_actor") and not target.has_meta("smash_falling"):
				target.global_position.z = float(target.get_meta("spawn_z")) + approach * 3.2

func set_action_icon(action: String) -> void:
	match action:
		"JUMP":
			action_icon.texture = load("res://assets/action_icons/jump.png")
			action_icon.visible = true
		"DUCK":
			action_icon.texture = load("res://assets/action_icons/duck.png")
			action_icon.visible = true
		"LEFT":
			action_icon.texture = load("res://assets/action_icons/left.png")
			action_icon.visible = true
		"RIGHT":
			action_icon.texture = load("res://assets/action_icons/right.png")
			action_icon.visible = true
		"SMASH":
			action_icon.texture = load("res://assets/action_icons/smash.png")
			action_icon.visible = true
		_:
			action_icon.visible = false

func arm_action(action: String) -> void:
	if event_index >= events.size():
		return
	var event := events[event_index]
	var gap: float = float(event.distance) - distance
	if gap >= 0.0 and gap <= ACTION_WINDOW and str(event.action) == action:
		action_armed = true

func evaluate_event() -> void:
	if event_index >= events.size():
		return
	var event := events[event_index]
	if str(event.action) == "SMASH" and smash_event_is_in_hit_range(event):
		begin_smash_sequence(event)
	elif distance >= float(event.distance):
		if str(event.action) != "SMASH":
			show_result(action_armed)
			event_index += 1
			action_armed = false

func smash_event_is_in_hit_range(event: Dictionary) -> bool:
	# Character hits use the model's actual rear surface, not its origin. This
	# keeps every selected size at arm's length without letting the camera clip in.
	if smash_event_has_actor(event):
		for target in event.targets:
			if is_instance_valid(target) and target.has_meta("smash_actor"):
				var bounds := calculate_world_mesh_bounds(target)
				var surface_gap := camera_rig.global_position.z - bounds.end.z
				var hit_gap := smash_hit_gap_spin.value if smash_hit_gap_spin else DEFAULT_SMASH_HIT_GAP
				return surface_gap <= hit_gap
	# The procedural wall keeps its original close-range timing.
	return distance >= float(event.distance) - 3.0

func begin_smash_sequence(event: Dictionary) -> void:
	smash_sequence_active = true
	smash_sequence_timer = 0.0
	smash_sequence_stage = 0
	active_smash_event = event
	action_label.text = "SMASH" if smash_event_has_actor(event) else "SMASH 2X"
	set_action_icon("SMASH")
	action_label.pivot_offset = action_label.size * 0.5
	action_icon.pivot_offset = action_icon.size * 0.5

func update_smash_sequence(delta: float) -> void:
	smash_sequence_timer += delta
	var pulse := 1.0 + sin(smash_sequence_timer * TAU * 2.2) * 0.085
	action_label.scale = Vector2.ONE * pulse
	action_icon.scale = Vector2.ONE * pulse
	var first_hit_time := 0.08 if smash_event_has_actor(active_smash_event) else 0.55
	if smash_sequence_stage == 0 and smash_sequence_timer >= first_hit_time:
		smash_sequence_stage = 1
		if smash_event_has_actor(active_smash_event):
			complete_smash_sequence()
		else:
			apply_cracked_smash_texture(active_smash_event)
			play_sfx("SMASH")
	elif smash_sequence_stage == 1 and smash_sequence_timer >= 1.35:
		smash_sequence_stage = 2
		complete_smash_sequence()

func smash_event_has_actor(event: Dictionary) -> bool:
	if not event.has("targets"):
		return false
	for target in event.targets:
		if is_instance_valid(target) and target.has_meta("smash_actor"):
			return true
	return false

func complete_smash_sequence() -> void:
	break_smash_targets(active_smash_event)
	play_sfx("SMASH")
	show_result(true)
	event_index += 1
	action_armed = false
	smash_sequence_active = false
	active_smash_event = {}
	action_label.scale = Vector2.ONE
	action_icon.scale = Vector2.ONE

func apply_cracked_smash_texture(event: Dictionary) -> void:
	if not event.has("targets"):
		return
	for target in event.targets:
		if is_instance_valid(target) and target.has_meta("cracked_material"):
			target.material_override = target.get_meta("cracked_material")

func break_smash_targets(event: Dictionary) -> void:
	if not event.has("targets"):
		return
	for target in event.targets:
		if is_instance_valid(target):
			if target.has_meta("smash_actor"):
				fall_smash_actor(target)
			else:
				target.queue_free()

func fall_smash_actor(target: Node3D) -> void:
	target.set_meta("smash_falling", true)
	var tween := target.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Tip the model away from the player and let it drop instead of disappearing.
	tween.tween_property(target, "rotation:x", target.rotation.x - PI * 0.5, 0.65)
	tween.tween_property(target, "position:y", target.position.y - 1.25, 0.65)
	tween.tween_property(target, "position:z", target.position.z - 1.4, 0.65)
	tween.chain().tween_interval(0.35)
	tween.chain().tween_callback(target.queue_free)

func show_result(success: bool) -> void:
	# Пропуск не наказывается: для фитнес-ролика оставляем только
	# позитивное подкрепление за выполненное движение.
	if not success:
		return
	feedback_time = 1.25
	feedback_label.text = "NICE!"
	feedback_label.add_theme_color_override("font_color", Color("60f08a"))
	flash_overlay.color = Color(0.15, 1.0, 0.35, 0.13)
	play_sfx("NICE")

func play_sfx(kind: String, pan: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "SFX_%s" % kind
	player.stream = load_project_sfx(kind)
	if not player.stream:
		player.stream = synthesize_sfx(kind)
	player.volume_db = -7.0
	# Параметр сохраняем для будущего AudioEffectPanner. У обычного
	# AudioStreamPlayer в Godot 4.7 свойства balance нет.
	player.set_meta("requested_pan", pan)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func load_project_sfx(kind: String) -> AudioStream:
	var folder_path := "res://assets/sounds/%s" % kind.to_lower()
	var audio_files: Array[String] = []
	for file_name in DirAccess.get_files_at(folder_path):
		if file_name.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
			audio_files.append(file_name)
	if audio_files.is_empty():
		return null
	audio_files.sort()
	var stream := load(folder_path.path_join(audio_files.pick_random()))
	return stream as AudioStream

func synthesize_sfx(kind: String) -> AudioStreamWAV:
	# Временные оригинальные эффекты генерируются математически и не
	# содержат сторонних аудиофайлов. Позже эти слоты примут WAV/OGG.
	var sample_rate := 22050
	var duration := 0.22
	var start_frequency := 260.0
	var end_frequency := 520.0
	var noise_amount := 0.05
	match kind:
		"JUMP":
			duration = 0.24
			start_frequency = 240.0
			end_frequency = 680.0
			noise_amount = 0.03
		"LAND":
			duration = 0.18
			start_frequency = 150.0
			end_frequency = 62.0
			noise_amount = 0.20
		"DODGE":
			duration = 0.30
			start_frequency = 720.0
			end_frequency = 190.0
			noise_amount = 0.28
		"DUCK":
			duration = 0.26
			start_frequency = 560.0
			end_frequency = 115.0
			noise_amount = 0.16
		"NICE":
			duration = 0.32
			start_frequency = 520.0
			end_frequency = 920.0
			noise_amount = 0.01
		"SMASH":
			duration = 0.34
			start_frequency = 185.0
			end_frequency = 48.0
			noise_amount = 0.38

	var sample_count := int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var progress := float(index) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / float(sample_rate)
		var envelope := pow(1.0 - progress, 2.0) * minf(1.0, progress * 28.0)
		var tonal := sin(phase)
		if kind == "NICE":
			tonal = sin(phase) * 0.72 + sin(phase * 1.5) * 0.28
		var noise := randf_range(-1.0, 1.0) * noise_amount
		var sample := clampf((tonal * (1.0 - noise_amount) + noise) * envelope, -1.0, 1.0)
		pcm.encode_s16(index * 2, int(sample * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream

func update_feedback(delta: float) -> void:
	if feedback_time <= 0.0:
		return
	feedback_time -= delta
	var alpha := clampf(feedback_time / 1.25, 0.0, 1.0)
	feedback_label.modulate.a = alpha
	flash_overlay.color.a *= 0.90
	if feedback_time <= 0.0:
		feedback_label.text = ""
		feedback_label.modulate.a = 1.0
		flash_overlay.color = Color(0, 0, 0, 0)

func restart() -> void:
	lane = 1
	dodge_direction = 0
	dodge_time = 0.0
	distance = 0.0
	vertical_offset = 0.0
	jumping = false
	ducking = false
	duck_time = 0.0
	duck_offset = 0.0
	finished = false
	event_index = 0
	action_armed = false
	feedback_time = 0.0
	countdown = 3.0
	smash_sequence_active = false
	smash_sequence_timer = 0.0
	smash_sequence_stage = 0
	active_smash_event = {}
	if action_label:
		action_label.scale = Vector2.ONE
	if action_icon:
		action_icon.scale = Vector2.ONE
	camera_rig.position = start_position
	if companion_root:
		companion_root.position = Vector3(start_position.x + 2.35, 0.0, start_position.z - 5.2)
		companion_run_time = 0.0
		companion_root.visible = companion_visual != null and companion_model_index >= 0
	if action_label:
		action_label.text = "3"
	if action_icon:
		action_icon.visible = false
	if feedback_label:
		feedback_label.text = ""
