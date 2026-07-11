extends Node3D

const LANE_X: Array[float] = [-3.2, 0.0, 3.2]
const COURSE_LENGTH := 180.0
const DODGE_DURATION := 1.8
const DUCK_DURATION := 1.25
const DUCK_DEPTH := 1.05
const ACTION_WINDOW := 12.0
const EVENTS: Array[Dictionary] = [
	{"distance": 32.0, "action": "JUMP"},
	{"distance": 56.0, "action": "RIGHT"},
	{"distance": 80.0, "action": "LEFT"},
	{"distance": 108.0, "action": "DUCK"},
	{"distance": 134.0, "action": "RIGHT"},
	{"distance": 158.0, "action": "LEFT"},
]

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
var ducking := false
var duck_time := 0.0
var duck_offset := 0.0
var finished := false
var camera_rig: Node3D
var camera: Camera3D
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
	create_duck_gate(-104.0, Color("9858e8"))
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

func create_duck_gate(z: float, color: Color) -> void:
	# Верхняя балка оставляет проход только для приседания.
	create_box("DuckGateTop", Vector3(10.5, 1.35, 1.8), Vector3(0, 2.35, z), color)
	create_box("DuckGateLeft", Vector3(0.65, 4.7, 1.8), Vector3(-5.0, 2.1, z), color)
	create_box("DuckGateRight", Vector3(0.65, 4.7, 1.8), Vector3(5.0, 2.1, z), color)

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

func _process(delta: float) -> void:
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

	if countdown > 0.0:
		countdown -= delta
		action_label.text = str(maxi(1, ceili(countdown)))
		if countdown <= 0.0:
			action_label.text = "GO!"
	elif not finished:
		distance += speed * delta
		evaluate_event()
		if distance >= COURSE_LENGTH:
			distance = COURSE_LENGTH
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
	distance_label.text = "%d / %d M" % [int(distance), int(COURSE_LENGTH)]
	if not finished and countdown <= 0.0:
		update_action_hint()
	update_feedback(delta)

func update_action_hint() -> void:
	action_label.text = ""
	action_icon.visible = false
	if event_index < EVENTS.size():
		var event := EVENTS[event_index]
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
		_:
			action_icon.visible = false

func arm_action(action: String) -> void:
	if event_index >= EVENTS.size():
		return
	var event := EVENTS[event_index]
	var gap: float = float(event.distance) - distance
	if gap >= 0.0 and gap <= ACTION_WINDOW and str(event.action) == action:
		action_armed = true

func evaluate_event() -> void:
	if event_index >= EVENTS.size():
		return
	var event := EVENTS[event_index]
	if distance >= float(event.distance):
		show_result(action_armed)
		event_index += 1
		action_armed = false

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
	camera_rig.position = start_position
	if action_label:
		action_label.text = "3"
	if action_icon:
		action_icon.visible = false
	if feedback_label:
		feedback_label.text = ""
