class_name ImportedWorldManager
extends RefCounted

const WORLDS_ROOT := "res://миры"
const CONFIG_NAME := "world_config.cfg"
const MODEL_EXTENSIONS := ["glb", "gltf"]

var active_world: Node3D
var active_id := ""
var active_report: Dictionary = {}
var warnings: Array[String] = []

func discover_worlds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(WORLDS_ROOT):
		return result
	var folders: Array[String] = []
	for folder in DirAccess.get_directories_at(WORLDS_ROOT):
		folders.append(folder)
	folders.sort()
	for folder in folders:
		var model_files: Array[String] = []
		var folder_path := WORLDS_ROOT.path_join(folder)
		for file_name in DirAccess.get_files_at(folder_path):
			if file_name.get_extension().to_lower() in MODEL_EXTENSIONS:
				model_files.append(file_name)
		model_files.sort()
		if not model_files.is_empty():
			var config := load_config(folder)
			var configured_file := str(config.get_value("world", "model_file", ""))
			var model_file := configured_file if configured_file in model_files else model_files[0]
			result.append({"id": folder, "model_file": model_file, "path": folder_path.path_join(model_file)})
	return result

func config_path(world_id: String) -> String:
	return WORLDS_ROOT.path_join(world_id).path_join(CONFIG_NAME)

func load_config(world_id: String) -> ConfigFile:
	var config := ConfigFile.new()
	config.load(config_path(world_id))
	return config

func save_config(world_id: String, values: Dictionary) -> Error:
	var config := load_config(world_id)
	for key in values:
		config.set_value("world", key, values[key])
	return config.save(config_path(world_id))

func clear() -> void:
	if is_instance_valid(active_world):
		active_world.queue_free()
	active_world = null
	active_id = ""
	active_report.clear()
	warnings.clear()

func load_world(parent: Node3D, descriptor: Dictionary, course_length: float, overrides: Dictionary = {}) -> Dictionary:
	clear()
	warnings.clear()
	var path := str(descriptor.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return _failure("Файл мира не найден: %s" % path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if error != OK:
		return _failure("Не удалось прочитать GLB/GLTF: %s" % error_string(error))
	var scene := document.generate_scene(state) as Node3D
	if not scene:
		return _failure("GLB/GLTF не содержит корректной 3D-сцены")
	scene.name = "ImportedWorld"
	parent.add_child(scene)
	var raw_report := analyze(scene)
	if not bool(raw_report.get("valid", false)):
		scene.queue_free()
		return raw_report
	var world_id := str(descriptor.get("id", ""))
	var config := load_config(world_id)
	var axis_setting := str(overrides.get("route_axis", config.get_value("world", "route_axis", "auto"))).to_lower()
	var raw_bounds: AABB = raw_report.bounds
	var axis := axis_setting
	if axis not in ["x", "z"]:
		axis = "x" if raw_bounds.size.x >= raw_bounds.size.z else "z"
	var rotation_y := float(overrides.get("rotation_y_degrees", config.get_value("world", "rotation_y_degrees", 0.0)))
	var rotation_x := float(config.get_value("world", "rotation_x_degrees", 0.0))
	var rotation_z := float(config.get_value("world", "rotation_z_degrees", 0.0))
	if axis == "x":
		rotation_y += 90.0
	var start_margin := float(config.get_value("world", "start_margin", 8.0))
	var finish_margin := float(config.get_value("world", "finish_margin", 12.0))
	var available_raw := (raw_bounds.size.x if axis == "x" else raw_bounds.size.z)
	var auto_fit := bool(overrides.get("auto_fit", config.get_value("world", "auto_fit", true)))
	var scale_value := float(config.get_value("world", "uniform_scale", 1.0))
	if auto_fit:
		scale_value = (course_length + start_margin + finish_margin) / maxf(available_raw, 0.001)
		# Sketchfab and DCC exports are often normalized to a handful of units.
		# A generous cap is therefore intentional; the scale stays uniform.
		scale_value = clampf(scale_value, 0.05, 250.0)
	scale_value *= float(overrides.get("scale_multiplier", config.get_value("world", "scale_multiplier", 1.0)))
	scene.scale = Vector3.ONE * scale_value
	scene.rotation_degrees = Vector3(rotation_x, rotation_y, rotation_z)
	var transformed := calculate_visible_bounds(scene)
	# AABB extrema are usually caves/bedrock and tree tops, not the playable
	# surface. Sample transformed mesh vertices once and use a configurable height
	# percentile as the terrain plane.
	var floor_height := float(overrides.get("floor_height", config.get_value("world", "floor_height", 0.0)))
	var surface_percentile := float(config.get_value("world", "surface_percentile", 0.72))
	var surface_height := calculate_height_percentile(scene, surface_percentile)
	var route_offset := _vector3_from_value(overrides.get("route_offset", config.get_value("world", "route_offset", Vector3.ZERO)))
	scene.global_position += Vector3(-transformed.get_center().x, floor_height - surface_height - 0.08, -course_length * 0.5 + 5.0 - transformed.get_center().z) + route_offset
	var final_bounds := calculate_visible_bounds(scene)
	var carve_enabled := bool(config.get_value("world", "carve_route", true))
	var carve_width := float(config.get_value("world", "carve_width", 9.2))
	var carve_height := float(config.get_value("world", "carve_height", 6.2))
	var removed_triangles := 0
	if carve_enabled:
		removed_triangles = carve_route_corridor(scene, carve_width, carve_height, -course_length - 8.0, start_margin)
		if removed_triangles > 0:
			# Bounds are cheap after the one-time mesh rebuild and keep diagnostics exact.
			final_bounds = calculate_visible_bounds(scene)
	var route_available := final_bounds.size.z - start_margin - finish_margin
	if route_available + 0.01 < course_length:
		warnings.append("Мир короче трассы на %.1f м; увеличьте WORLD SCALE или включите Repeat." % (course_length - route_available))
	var extras: Dictionary = {}
	if state.json is Dictionary:
		extras = state.json.get("asset", {}).get("extras", {})
	active_world = scene
	active_id = world_id
	active_report = raw_report.duplicate(true)
	active_report.merge({
		"valid": true, "id": world_id, "path": path, "raw_bounds": raw_bounds,
		"bounds": final_bounds, "axis": axis.to_upper(), "uniform_scale": scale_value,
		"rotation_x": rotation_x, "rotation_y": rotation_y, "rotation_z": rotation_z,
		"surface_height": surface_height, "surface_percentile": surface_percentile, "route_available": route_available,
		"carve_enabled": carve_enabled, "carve_width": carve_width, "carve_height": carve_height,
		"removed_triangles": removed_triangles,
		"safe_corridor_width": float(overrides.get("safe_corridor_width", config.get_value("world", "safe_corridor_width", 14.0))),
		"safe_corridor_height": float(config.get_value("world", "safe_corridor_height", 7.0)),
		"warnings": warnings.duplicate(), "license": extras
	}, true)
	var save_error := save_config(world_id, {
		"model_file": str(descriptor.get("model_file", path.get_file())), "uniform_scale": scale_value,
		"scale_multiplier": float(overrides.get("scale_multiplier", 1.0)), "auto_fit": auto_fit,
		"rotation_y_degrees": float(overrides.get("rotation_y_degrees", 0.0)), "route_axis": axis_setting,
		"route_offset": route_offset, "floor_height": floor_height,
		"safe_corridor_width": active_report.safe_corridor_width,
		"author": str(extras.get("author", config.get_value("world", "author", ""))),
		"license": str(extras.get("license", config.get_value("world", "license", ""))),
		"source": str(extras.get("source", config.get_value("world", "source", ""))),
		"title": str(extras.get("title", config.get_value("world", "title", world_id)))
	})
	if save_error != OK:
		warnings.append("Не удалось сохранить настройки мира: %s" % error_string(save_error))
	return active_report

func analyze(root: Node3D) -> Dictionary:
	var bounds := calculate_visible_bounds(root)
	var mesh_count := 0
	var vertex_count := 0
	var light_count := root.find_children("*", "Light3D", true, false).size()
	var camera_count := root.find_children("*", "Camera3D", true, false).size()
	var animation_count := root.find_children("*", "AnimationPlayer", true, false).size()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		mesh_count += 1
		for surface in range(mesh_instance.mesh.get_surface_count()):
			vertex_count += mesh_instance.mesh.surface_get_array_len(surface)
	if mesh_count == 0 or bounds.size == Vector3.ZERO:
		return _failure("Мир не содержит видимой геометрии")
	return {"valid": true, "bounds": bounds, "min_y": bounds.position.y, "max_y": bounds.end.y,
		"center": bounds.get_center(), "size": bounds.size, "mesh_count": mesh_count,
		"vertex_count": vertex_count, "light_count": light_count, "camera_count": camera_count,
		"animation_count": animation_count, "root_transform": root.transform}

func calculate_visible_bounds(root: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh or not mesh_instance.visible:
			continue
		var world_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		combined = combined.merge(world_bounds) if has_bounds else world_bounds
		has_bounds = true
	return combined if has_bounds else AABB()

func calculate_height_percentile(root: Node3D, percentile: float) -> float:
	var heights := PackedFloat32Array()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh or not mesh_instance.visible:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride := maxi(1, vertices.size() / 4096)
			for index in range(0, vertices.size(), stride):
				heights.append((mesh_instance.global_transform * vertices[index]).y)
	if heights.is_empty():
		return calculate_visible_bounds(root).position.y
	heights.sort()
	var selected := int(clampf(percentile, 0.0, 1.0) * float(heights.size() - 1))
	return heights[selected]

func carve_route_corridor(root: Node3D, width: float, height: float, min_z: float, max_z: float) -> int:
	var removed_total := 0
	var half_width := width * 0.5
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh or not mesh_instance.visible:
			continue
		var source_mesh := mesh_instance.mesh
		var rebuilt := ArrayMesh.new()
		var rebuilt_any_surface := false
		for surface in range(source_mesh.get_surface_count()):
			if source_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays := source_mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var filtered := PackedInt32Array()
			var triangle_count := source_indices.size() / 3 if not source_indices.is_empty() else vertices.size() / 3
			for triangle in range(triangle_count):
				var i0 := source_indices[triangle * 3] if not source_indices.is_empty() else triangle * 3
				var i1 := source_indices[triangle * 3 + 1] if not source_indices.is_empty() else triangle * 3 + 1
				var i2 := source_indices[triangle * 3 + 2] if not source_indices.is_empty() else triangle * 3 + 2
				var a := mesh_instance.global_transform * vertices[i0]
				var b := mesh_instance.global_transform * vertices[i1]
				var c := mesh_instance.global_transform * vertices[i2]
				if _triangle_intersects_route_box(a, b, c, half_width, height, min_z, max_z):
					removed_total += 1
					continue
				filtered.append_array(PackedInt32Array([i0, i1, i2]))
			if filtered.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = filtered
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var new_surface := rebuilt.get_surface_count() - 1
			rebuilt.surface_set_material(new_surface, source_mesh.surface_get_material(surface))
			rebuilt_any_surface = true
		if rebuilt_any_surface:
			mesh_instance.mesh = rebuilt
	return removed_total

func _triangle_intersects_route_box(a: Vector3, b: Vector3, c: Vector3, half_width: float, height: float, min_z: float, max_z: float) -> bool:
	var triangle_min := a.min(b).min(c)
	var triangle_max := a.max(b).max(c)
	return triangle_max.x >= -half_width and triangle_min.x <= half_width \
		and triangle_max.y >= -0.4 and triangle_min.y <= height \
		and triangle_max.z >= min_z and triangle_min.z <= max_z

func _vector3_from_value(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _failure(message: String) -> Dictionary:
	warnings = [message]
	return {"valid": false, "error": message, "warnings": warnings.duplicate()}
