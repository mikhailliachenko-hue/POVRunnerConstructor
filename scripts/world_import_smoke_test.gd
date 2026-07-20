extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var manager := ImportedWorldManager.new()
	var worlds := manager.discover_worlds()
	if worlds.is_empty():
		push_error("WORLD_SMOKE: no worlds found")
		quit(2)
		return
	var root := Node3D.new()
	get_root().add_child(root)
	var report := manager.load_world(root, worlds[0], 720.0, {"auto_fit": true})
	if not bool(report.get("valid", false)):
		push_error("WORLD_SMOKE: %s" % report.get("error", "unknown error"))
		quit(3)
		return
	if float(report.get("route_available", 0.0)) < 719.0:
		push_error("WORLD_SMOKE: route does not fit: %.2f" % float(report.get("route_available", 0.0)))
		quit(4)
		return
	print("WORLD_SMOKE_OK bounds=%s raw=%s axis=%s scale=%.5f route=%.2f meshes=%d vertices=%d" % [
		str(report.bounds), str(report.raw_bounds), str(report.axis), float(report.uniform_scale),
		float(report.route_available), int(report.mesh_count), int(report.vertex_count)])
	quit(0)
