extends Node3D

const LANE_X: Array[float] = [-3.2, 0.0, 3.2]
const DODGE_DURATION := 1.8
const DUCK_DURATION := 1.25
const DUCK_DEPTH := 1.05
const ACTION_WINDOW := 12.0
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
var theme_option: OptionButton
var active_theme := "Candy"

func _ready() -> void:
	build_world()
	build_ui()
	build_builder_ui()
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
	world_environment.ambient_light_energy = 0.75
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world_environment
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

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

func build_course() -> void:
	for child in course_root.get_children():
		child.queue_free()
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
			"JUMP": create_obstacle(1, z_position, colors[index % colors.size()], "JUMP", 1.5)
			"DUCK": create_duck_gate(z_position, colors[index % colors.size()])
			"LEFT", "RIGHT": create_dodge_gate(z_position, str(event.action), colors[index % colors.size()])
			"SMASH": event["targets"] = create_smash_gate(z_position, colors[index % colors.size()])

	var finish_z := start_position.z - course_length
	create_box("FinishTop", Vector3(11, 0.55, 0.55), Vector3(0, 5.7, finish_z), Color.WHITE)
	create_box("FinishLeft", Vector3(0.55, 6, 0.55), Vector3(-5.2, 2.8, finish_z), Color.WHITE)
	create_box("FinishRight", Vector3(0.55, 6, 0.55), Vector3(5.2, 2.8, finish_z), Color.WHITE)

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
	match active_theme:
		"Candy": build_candy_environment()
		"Block World": build_block_environment()
		"Metro": build_metro_environment()

func build_candy_environment() -> void:
	create_box("CandyGround", Vector3(42, 0.2, course_length + 20), Vector3(0, -0.38, -course_length * 0.5 + 5), theme_color("ground"))
	create_box("LeftRail", Vector3(0.3, 0.45, course_length), Vector3(-5.8, 0.65, -course_length * 0.5 + 5), Color("fff4d2"))
	create_box("RightRail", Vector3(0.3, 0.45, course_length), Vector3(5.8, 0.65, -course_length * 0.5 + 5), Color("fff4d2"))
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
	create_box("GrassGround", Vector3(46, 0.35, course_length + 20), Vector3(0, -0.42, -course_length * 0.5 + 5), theme_color("ground"))
	for index in range(0, int(course_length / 22.0) + 1):
		var z := -float(index * 22)
		var height := 4.0 + float(index % 4) * 1.5
		create_box("BlockBuildingL", Vector3(7, height, 9), Vector3(-10.0, height * 0.5, z), Color("d79055").lightened(float(index % 3) * 0.08))
		create_box("BlockBuildingR", Vector3(7, height + 1, 9), Vector3(10.0, (height + 1) * 0.5, z - 10), Color("5e82bd").lightened(float(index % 2) * 0.1))
		create_box("BlockTrunk", Vector3(0.65, 2.5, 0.65), Vector3(-6.6, 1.25, z - 9), Color("8f613d"))
		create_box("BlockLeaves", Vector3(2.8, 2.4, 2.8), Vector3(-6.6, 3.4, z - 9), Color("3f9b52"))

func build_metro_environment() -> void:
	create_box("MetroGround", Vector3(34, 0.3, course_length + 20), Vector3(0, -0.4, -course_length * 0.5 + 5), theme_color("ground"))
	create_box("LeftWall", Vector3(1.0, 6.5, course_length), Vector3(-9.5, 3.0, -course_length * 0.5 + 5), Color("7b5039"))
	create_box("RightWall", Vector3(1.0, 6.5, course_length), Vector3(9.5, 3.0, -course_length * 0.5 + 5), Color("345466"))
	create_box("Ceiling", Vector3(20, 0.5, course_length), Vector3(0, 6.35, -course_length * 0.5 + 5), Color("242a34"))
	for index in range(0, int(course_length / 12.0) + 1):
		var z := -float(index * 12)
		create_box("ColumnL", Vector3(0.55, 6.0, 0.8), Vector3(-7.0, 2.8, z), Color("d08355"))
		create_box("ColumnR", Vector3(0.55, 6.0, 0.8), Vector3(7.0, 2.8, z), Color("d08355"))
		create_box("RoofBeam", Vector3(14.5, 0.35, 0.65), Vector3(0, 5.75, z), theme_color("accent"))
	for rail_x in [-3.2, 0.0, 3.2]:
		create_box("Rail", Vector3(0.12, 0.09, course_length), Vector3(rail_x, 0.04, -course_length * 0.5 + 5), Color("c5ced8"))

func create_dodge_gate(z: float, action: String, color: Color) -> void:
	# Игрок начинает каждый манёвр из центра. Две полосы перекрыты,
	# поэтому остаётся только коридор в сторону указанного действия.
	var open_lane := 2 if action == "RIGHT" else 0
	for obstacle_lane in range(3):
		if obstacle_lane != open_lane:
			create_obstacle(obstacle_lane, z, color, action, 4.8)

func create_duck_gate(z: float, color: Color) -> void:
	# Верхняя балка оставляет проход только для приседания.
	create_box("DuckGateTop", Vector3(10.5, 1.35, 1.8), Vector3(0, 2.35, z), color)
	create_box("DuckGateLeft", Vector3(0.65, 4.7, 1.8), Vector3(-5.0, 2.1, z), color)
	create_box("DuckGateRight", Vector3(0.65, 4.7, 1.8), Vector3(5.0, 2.1, z), color)

func create_smash_gate(z: float, color: Color) -> Array[MeshInstance3D]:
	# One unified wall mesh. Later its two materials will receive the
	# user-selected intact and cracked image textures.
	var targets: Array[MeshInstance3D] = []
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

func create_obstacle(obstacle_lane: int, z: float, color: Color, action: String, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Obstacle_%s" % action
	body.position = Vector3(LANE_X[obstacle_lane], height * 0.5, z)
	body.set_meta("action", action)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.55, height, 1.6)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
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
	mesh_instance.material_override = make_material(color)
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
	panel.position = Vector2(275, 55)
	panel.size = Vector2(730, 610)
	builder_overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)

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

	create_round_selector(content, "MOVEMENTS IN THIS ROUND", round_checks, ["JUMP"])

	var note := Label.new()
	note.text = "The builder automatically spaces obstacles and keeps the route passable."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("a8b7d8"))
	content.add_child(note)
	var play_button := Button.new()
	play_button.text = "BUILD & PLAY"
	play_button.custom_minimum_size = Vector2(0, 58)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.pressed.connect(apply_builder_settings)
	content.add_child(play_button)

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

func apply_builder_settings() -> void:
	video_duration = duration_spin.value
	active_theme = theme_option.get_item_text(theme_option.selected)
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
	restart()
	builder_active = false
	builder_overlay.visible = false

func apply_theme_environment() -> void:
	match active_theme:
		"Candy":
			world_environment.background_color = Color("55baf2")
			world_environment.ambient_light_color = Color("fff5f7")
		"Block World":
			world_environment.background_color = Color("75b9ee")
			world_environment.ambient_light_color = Color("e8f3ff")
		"Metro":
			world_environment.background_color = Color("18202b")
			world_environment.ambient_light_color = Color("9db4d1")

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
	update_feedback(delta)

func update_action_hint() -> void:
	action_label.text = ""
	action_icon.visible = false
	if event_index < events.size():
		var event := events[event_index]
		var gap: float = float(event.distance) - distance
		if gap > 0.0 and gap < 18.0:
			action_label.text = str(event.action)
			set_action_icon(str(event.action))

func set_action_icon(action: String) -> void:
	match action:
		"JUMP":
			action_icon.texture = load("res://assets/action_icons/jump.png")
			action_icon.visible = true
		"DUCK":
			action_icon.texture = load("res://assets/action_icons/duck.png")
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
	if str(event.action) == "SMASH" and distance >= float(event.distance) - 3.0:
		begin_smash_sequence(event)
	elif distance >= float(event.distance):
		if str(event.action) != "SMASH":
			show_result(action_armed)
			event_index += 1
			action_armed = false

func begin_smash_sequence(event: Dictionary) -> void:
	smash_sequence_active = true
	smash_sequence_timer = 0.0
	smash_sequence_stage = 0
	active_smash_event = event
	action_label.text = "SMASH 2X"
	set_action_icon("SMASH")
	action_label.pivot_offset = action_label.size * 0.5
	action_icon.pivot_offset = action_icon.size * 0.5

func update_smash_sequence(delta: float) -> void:
	smash_sequence_timer += delta
	var pulse := 1.0 + sin(smash_sequence_timer * TAU * 2.2) * 0.085
	action_label.scale = Vector2.ONE * pulse
	action_icon.scale = Vector2.ONE * pulse
	if smash_sequence_stage == 0 and smash_sequence_timer >= 0.55:
		smash_sequence_stage = 1
		apply_cracked_smash_texture(active_smash_event)
		play_sfx("SMASH")
	elif smash_sequence_stage == 1 and smash_sequence_timer >= 1.35:
		smash_sequence_stage = 2
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
			target.queue_free()

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
	player.stream = synthesize_sfx(kind)
	player.volume_db = -7.0
	# Параметр сохраняем для будущего AudioEffectPanner. У обычного
	# AudioStreamPlayer в Godot 4.7 свойства balance нет.
	player.set_meta("requested_pan", pan)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

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
	if action_label:
		action_label.text = "3"
	if action_icon:
		action_icon.visible = false
	if feedback_label:
		feedback_label.text = ""
