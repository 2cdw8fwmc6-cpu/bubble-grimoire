extends RefCounted
## 共通ヘルパー（マテリアル作成・簡易メッシュ・弾けるエフェクト）

static func mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func add_mesh(parent: Node, mesh: Mesh, color: Color, pos := Vector3.ZERO, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, unshaded)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func bubble(parent: Node, r: float, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := add_mesh(parent, sphere(r), Color(0.6, 0.85, 1.0, 0.35), pos)
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(0.25, 0.45, 0.8)
	m.emission_energy_multiplier = 0.6
	return mi


static func pop(parent: Node, pos: Vector3, color: Color, count := 8) -> void:
	for i in count:
		var m := MeshInstance3D.new()
		m.mesh = sphere(0.09)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = color
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mt
		parent.add_child(m)
		m.global_position = pos
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
		var tw := m.create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "global_position", pos + dir * randf_range(0.8, 1.6), 0.45)
		tw.tween_property(mt, "albedo_color:a", 0.0, 0.45)
		tw.chain().tween_callback(m.queue_free)
