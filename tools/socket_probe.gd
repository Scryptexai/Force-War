extends SceneTree

# Reads weapon socket world positions straight out of a GLB file, by name, with
# exactly the lookup the game uses. Used by tools/verify_socket_reexport_invariance.sh
# to prove that moving an Empty in Blender and re-exporting moves the fire point
# with no code change.
#
#   godot --headless --script tools/socket_probe.gd -- <path-to.glb> [names...]

func _find(node: Node, wanted: String) -> Node3D:
	if node.name == wanted and node is Node3D:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _initialize() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.is_empty():
		printerr("usage: socket_probe.gd -- <path.glb> [socket names]")
		quit(2)
		return
	var path: String = argv[0]
	var names: Array = []
	for i in range(1, argv.size()):
		names.append(argv[i])
	if names.is_empty():
		names = ["MZ_Gun_L", "MZ_Gun_R", "HP_L1", "HP_L2", "HP_L3", "HP_R1", "HP_R2", "HP_R3", "EX_C"]

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error: int = doc.append_from_file(path, state)
	if error != OK:
		printerr("failed to read %s (%d)" % [path, error])
		quit(3)
		return
	var scene: Node = doc.generate_scene(state)
	var result: Dictionary = {}
	for socket_name in names:
		var node := _find(scene, str(socket_name))
		if node == null:
			result[str(socket_name)] = null
			continue
		# The generated scene is not inside the SceneTree, so the world transform
		# is composed by walking the parents instead of asking for it.
		var world := Transform3D()
		var walk: Node = node
		while walk != null and walk is Node3D:
			world = (walk as Node3D).transform * world
			walk = walk.get_parent()
		var origin: Vector3 = world.origin
		result[str(socket_name)] = [
			snappedf(origin.x, 0.0001),
			snappedf(origin.y, 0.0001),
			snappedf(origin.z, 0.0001)
		]
	print(JSON.stringify(result))
	quit(0)
