extends SceneTree

const OUTPUT_DIR := "res://раунды/round_02/_source/previews/immersion"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene := load("res://main.tscn") as PackedScene
	var game := scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	for index in range(game.round_option.item_count):
		if str(game.round_option.get_item_metadata(index)) == "round_02":
			game.round_option.select(index)
			game.on_round_content_selected(index)
			break
	game.duration_spin.value = 60.0
	game.apply_builder_settings()
	game.builder_overlay.visible = false
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = false
	await _settle_frames(12)
	var samples := [
		{"name": "route_00_start", "distance": 0.0, "x": 0.0, "height": 0.0},
		{"name": "route_25_left", "distance": 180.0, "x": -3.2, "height": 0.0},
		{"name": "route_50_center", "distance": 360.0, "x": 0.0, "height": 0.0},
		{"name": "route_75_right", "distance": 540.0, "x": 3.2, "height": 0.0},
		{"name": "route_50_jump", "distance": 360.0, "x": 0.0, "height": 2.2},
	]
	var captured: Array[Image] = []
	for sample in samples:
		game.distance = float(sample.distance)
		game.camera_rig.position = Vector3(float(sample.x), game.start_position.y + float(sample.height), game.start_position.z - float(sample.distance))
		await _settle_frames(4)
		var image := game.get_viewport().get_texture().get_image()
		captured.append(image.duplicate())
		var path := OUTPUT_DIR.path_join("%s.png" % str(sample.name))
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("VISUAL_TEST: could not save %s: %s" % [path, error_string(error)])
			quit(2)
			return
		print("VISUAL_TEST_SAVED %s" % path)
	var sheet := Image.create(1158 * 2, 633 * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("111722"))
	for index in range(captured.size()):
		sheet.blit_rect(captured[index], Rect2i(0, 0, 1158, 633), Vector2i((index % 2) * 1158, int(index / 2) * 633))
	var sheet_path := OUTPUT_DIR.path_join("route_contact_sheet.png")
	var sheet_error := sheet.save_png(ProjectSettings.globalize_path(sheet_path))
	if sheet_error != OK:
		push_error("VISUAL_TEST: could not save contact sheet: %s" % error_string(sheet_error))
		quit(3)
		return
	print("VISUAL_TEST_SAVED %s" % sheet_path)
	print("ROUND_02_VISUAL_TEST_OK")
	quit(0)

func _settle_frames(count: int) -> void:
	for index in range(count):
		await process_frame
