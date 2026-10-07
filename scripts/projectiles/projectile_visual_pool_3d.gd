extends Node3D
class_name ProjectileVisualPool3D

# Renderer for the logical bullets.
#
# Correction brief, section 2 point 1/2: this pool no longer invents decorative
# bolts that scroll past the camera with no shooter and no target. It draws the
# exact bullet array owned by ProjectileManager3D, one MultiMesh instance per
# logical bullet, elongated along that bullet's velocity so its direction of
# travel is readable in a freeze frame. Unused slots are cut off with
# visible_instance_count - parking them off-screen smears garbage geometry in the
# compatibility renderer.

var pool_label := "projectile_pool"
var active := false
var bolt_size := Vector2(0.32, 1.6)
var rendered_count := 0

var multimesh := MultiMesh.new()
var instance_node := MultiMeshInstance3D.new()
var debug_marker: MeshInstance3D
var debug_marker_enabled := false


func setup_bound(label: String, texture: Texture2D, tint: Color, count: int, size: Vector2, emission_energy: float) -> void:
	pool_label = label
	name = "ProjectileVisualPool3D_" + label
	bolt_size = size

	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = max(0, count)

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(tint.r, tint.g, tint.b, 1.0)
	material.emission_texture = texture
	material.emission_energy_multiplier = emission_energy
	# Bullets are the highest readability tier, but they still respect depth so they
	# cannot smear over the whole frame when they pass the camera.
	material.render_priority = 4

	instance_node = MultiMeshInstance3D.new()
	instance_node.name = "BatchedBoltMultimesh_" + label
	instance_node.multimesh = multimesh
	instance_node.material_override = material
	# The multimesh AABB is only refreshed when instance_count changes, so a
	# generous custom AABB keeps live bullets from being frustum-culled.
	instance_node.custom_aabb = AABB(Vector3(-260.0, -260.0, -260.0), Vector3(520.0, 520.0, 520.0))
	instance_node.extra_cull_margin = 64.0
	add_child(instance_node)

	if debug_marker_enabled:
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(1.2, 1.2, 1.2)
		debug_marker = MeshInstance3D.new()
		debug_marker.name = "BulletProbeMarker_" + label
		debug_marker.mesh = marker_mesh
		var marker_mat := StandardMaterial3D.new()
		marker_mat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
		marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debug_marker.material_override = marker_mat
		debug_marker.visible = false
		add_child(debug_marker)

	multimesh.visible_instance_count = 0
	active = multimesh.instance_count > 0


func render_bullets(bullets: Array) -> void:
	if not active:
		return
	var drawn := 0
	var limit: int = multimesh.instance_count
	for i in range(bullets.size()):
		if drawn >= limit:
			break
		var bullet: Dictionary = bullets[i]
		if not bool(bullet.get("active", false)):
			continue
		_write_bullet(drawn, bullet.get("pos", Vector3.ZERO), bullet.get("vel", Vector3(0.0, 0.0, -1.0)))
		drawn += 1
	multimesh.visible_instance_count = drawn
	rendered_count = drawn
	if debug_marker != null:
		debug_marker.visible = drawn > 0
		if drawn > 0:
			for bullet_value in bullets:
				var probe: Dictionary = bullet_value
				if bool(probe.get("active", false)):
					debug_marker.position = probe.get("pos", Vector3.ZERO)
					break


func clear_pool() -> void:
	if not active:
		return
	multimesh.visible_instance_count = 0
	rendered_count = 0


func get_pool_count() -> int:
	return multimesh.instance_count if active else 0


func _write_bullet(index: int, pos: Vector3, vel: Vector3) -> void:
	var dir := Vector3(vel.x, 0.0, vel.z)
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	var y_axis := dir * bolt_size.y
	var x_axis := Vector3(dir.z, 0.0, -dir.x) * bolt_size.x
	var z_axis := Vector3(0.0, -1.0, 0.0)
	# Transform3D's four-vector constructor takes basis COLUMNS, which is what the
	# quad needs: local X across the bolt, local Y along travel, local Z the normal.
	multimesh.set_instance_transform(index, Transform3D(x_axis, y_axis, z_axis, pos))
