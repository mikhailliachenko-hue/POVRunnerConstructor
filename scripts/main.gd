extends Node3D

const LANE_X: Array[float] = [-3.2, 0.0, 3.2]
const COURSE_LENGTH := 180.0
const DODGE_DURATION := 1.35

var speed := 12.0
var jump_height := 2.2
var lane_smoothness := 9.0
var lane := 1
var dodge_direction := 0
var dodge_time := 0.0
var distance := 0.0
var vertical_offset := 0.0
var jump_time := 0.0
var jumping := false
var finished := false
var camera_rig: Node3D
var camera: Camera3D
var progress_bar: ProgressBar
var distance_label: Label
var action_label: Label
var settings_panel: PanelContainer
var start_position := Vector3(0, 1.7, 4)

func _ready() -> void:
	build_world()
	build_course()
	build_ui()
	restart()

func build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("55baf2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
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

func build_course() -> void:
	create_box("Road", Vector3(11, 0.25, COURSE_LENGTH + 20), Vector3(0, -0.25, -COURSE_LENGTH * 0.5 + 5), Color("f54fa2"))
	for lane_mark in [-1.6, 1.6]:
		create_box("LaneMark", Vector3(0.10, 0.025, COURSE_LENGTH), Vector3(lane_mark, 0.02, -COURSE_LENGTH * 0.5 + 5), Color(1, 1, 1, 0.65))

	for z in range(0, 19):
		var world_z := -float(z * 10)
		create_tree(Vector3(-7.2, 0, world_z), z)
		create_tree(Vector3(7.2, 0, world_z), z + 1)

	create_obstacle(1, -28.0, Color("49d765"), "JUMP", 1.5)
	create_dodge_gate(-52.0, "RIGHT", Color("3a84ed"))
	create_dodge_gate(-76.0, "LEFT", Color("ffca38"))
	create_obstacle(1, -104.0, Color("9858e8"), "JUMP", 1.5)
	create_dodge_gate(-130.0, "RIGHT", Color("35d4cf"))
	create_dodge_gate(-154.0, "LEFT", Color("f06b42"))

	create_box("FinishTop", Vector3(11, 0.55, 0.55), Vector3(0, 5.7, -COURSE_LENGTH), Color.WHITE)
	create_box("FinishLeft", Vector3(0.55, 6, 0.55), Vector3(-5.2, 2.8, -COURSE_LENGTH), Color.WHITE)
	create_box("FinishRight", Vector3(0.55, 6, 0.55), Vector3(5.2, 2.8, -COURSE_LENGTH), Color.WHITE)

func create_tree(pos: Vector3, index: int) -> void:
	create_cylinder(Vector3(pos.x, 1.25, pos.z), 0.24, 2.5, Color("f1eee2"))
	var colors := [Color("ef426f"), Color("37cf79"), Color("56aef0"), Color("9639bd")]
	create_sphere(Vector3(pos.x, 3.4, pos.z), 1.45, colors[index % colors.size()])

func create_dodge_gate(z: float, action: String, color: Color) -> void:
	# Игрок начинает каждый манёвр из центра. Две полосы перекрыты,
	# поэтому остаётся только коридор в сторону указанного действия.
	var open_lane := 2 if action == "RIGHT" else 0
	for obstacle_lane in range(3):
		if obstacle_lane != open_lane:
			create_obstacle(obstacle_lane, z, color, action, 4.8)

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
	add_child(body)

func create_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	add_child(mesh_instance)

func create_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	item.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	item.mesh = mesh
	item.material_override = make_material(color)
	add_child(item)

func create_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var item := MeshInstance3D.new()
	item.position = pos
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	item.mesh = mesh
	item.material_override = make_material(color)
	add_child(item)

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
	progress_bar.max_value = COURSE_LENGTH
	progress_bar.show_percentage = false
	layer.add_child(progress_bar)

	distance_label = Label.new()
	distance_label.position = Vector2(540, 66)
	distance_label.size = Vector2(200, 40)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.add_theme_font_size_override("font_size", 25)
	layer.add_child(distance_label)

	action_label = Label.new()
	action_label.position = Vector2(390, 125)
	action_label.size = Vector2(500, 80)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 52)
	action_label.add_theme_color_override("font_color", Color("fff052"))
	layer.add_child(action_label)

	var help := Label.new()
	help.position = Vector2(24, 650)
	help.text = "A / ←  ВЛЕВО     D / →  ВПРАВО     SPACE / W / ↑  ПРЫЖОК     R  ЗАНОВО     TAB  НАСТРОЙКИ"
	help.add_theme_font_size_override("font_size", 18)
	layer.add_child(help)

	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(28, 110)
	settings_panel.size = Vector2(310, 300)
	layer.add_child(settings_panel)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	settings_panel.add_child(settings)
	var title := Label.new()
	title.text = "НАСТРОЙКИ ПРОТОТИПА"
	title.add_theme_font_size_override("font_size", 22)
	settings.add_child(title)
	add_setting(settings, "Скорость", 6, 24, speed, func(value): speed = value)
	add_setting(settings, "Высота прыжка", 1, 4, jump_height, func(value): jump_height = value)
	add_setting(settings, "Плавность полос", 3, 16, lane_smoothness, func(value): lane_smoothness = value)
	var button := Button.new()
	button.text = "ПЕРЕЗАПУСТИТЬ ТРАССУ"
	button.pressed.connect(restart)
	settings.add_child(button)
	var hint := Label.new()
	hint.text = "TAB — скрыть/показать панель"
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

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("move_left") and not finished and dodge_direction == 0:
		dodge_direction = -1
		dodge_time = 0.0
	if Input.is_action_just_pressed("move_right") and not finished and dodge_direction == 0:
		dodge_direction = 1
		dodge_time = 0.0
	if Input.is_action_just_pressed("jump") and not jumping and not finished:
		jumping = true
		jump_time = 0.0
	if Input.is_key_pressed(KEY_R):
		restart()
	if Input.is_key_pressed(KEY_TAB) and not get_meta("tab_down", false):
		settings_panel.visible = not settings_panel.visible
		set_meta("tab_down", true)
	if not Input.is_key_pressed(KEY_TAB):
		set_meta("tab_down", false)

	if not finished:
		distance += speed * delta
		if distance >= COURSE_LENGTH:
			distance = COURSE_LENGTH
			finished = true
			action_label.text = "ФИНИШ!"

	if jumping:
		jump_time += delta
		var duration := 0.85
		var phase := clampf(jump_time / duration, 0.0, 1.0)
		vertical_offset = sin(phase * PI) * jump_height
		if phase >= 1.0:
			jumping = false
			vertical_offset = 0.0

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
	camera_rig.position.y = start_position.y + vertical_offset + sin(distance * 1.3) * 0.035
	camera_rig.position.z = start_position.z - distance
	progress_bar.value = distance
	distance_label.text = "%d / %d М" % [int(distance), int(COURSE_LENGTH)]
	if not finished:
		update_action_hint()

func update_action_hint() -> void:
	var events := [[28.0, "JUMP"], [52.0, "RIGHT"], [76.0, "LEFT"], [104.0, "JUMP"], [130.0, "RIGHT"], [154.0, "LEFT"]]
	action_label.text = ""
	for event in events:
		var gap: float = event[0] - distance
		if gap > 0.0 and gap < 18.0:
			action_label.text = event[1]
			break

func restart() -> void:
	lane = 1
	dodge_direction = 0
	dodge_time = 0.0
	distance = 0.0
	vertical_offset = 0.0
	jumping = false
	finished = false
	camera_rig.position = start_position
	if action_label:
		action_label.text = "3… 2… 1… GO!"
