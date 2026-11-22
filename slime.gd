extends CharacterBody3D
## スライム：近づいて予備動作（予測線）のあと、閉じ込めシャボン玉を発射する

const FX := preload("res://scripts/fx.gd")
const BubbleScript := preload("res://scripts/bubble_shot.gd")

signal died

const WINDUP := 1.1
const AIM_LEN := 14.0

var hp := 6
var player
var state := "move"
var timer := 0.0
var cooldown := 1.5
var aim_dir := Vector3.FORWARD
var t := 0.0
var speed := 1.7
var flash := 0.0
var body: Node3D
var aim_pivot: Node3D
var line: MeshInstance3D


func _ready() -> void:
	add_to_group("slimes")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	cooldown = randf_range(1.0, 2.5)
	t = randf() * 10.0

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.5
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)

	body = Node3D.new()
	add_child(body)
	FX.add_mesh(body, FX.sphere(0.5), Color(0.35, 0.9, 0.5, 0.85), Vector3(0, 0.5, 0))
	for sx in [-1.0, 1.0]:
		FX.add_mesh(body, FX.sphere(0.09), Color.WHITE, Vector3(sx * 0.18, 0.62, 0.4), true)
		FX.add_mesh(body, FX.sphere(0.045), Color.BLACK, Vector3(sx * 0.18, 0.62, 0.47), true)

	aim_pivot = Node3D.new()
	aim_pivot.position = Vector3(0, 0.05, 0)
	add_child(aim_pivot)
	line = FX.add_mesh(aim_pivot, FX.box(Vector3(0.16, 0.03, AIM_LEN)), Color(1.0, 0.5, 0.8, 0.5), Vector3(0, 0, AIM_LEN * 0.5 + 0.5), true)
	line.visible = false


func _physics_process(delta: float) -> void:
	t += delta
	var k := 1.0 + sin(t * 6.0) * 0.06
	if player == null or player.dead:
		line.visible = false
		_apply_squash(k, delta)
		return

	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else Vector3.FORWARD

	match state:
		"move":
			cooldown -= delta
			body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), 6.0 * delta)
			var v := Vector3.ZERO
			if dist > 6.0:
				v = dir * speed
			elif dist < 3.5:
				v = -dir * speed * 0.6
			velocity = v
			move_and_slide()
			if cooldown <= 0.0 and dist < 13.0:
				state = "windup"
				timer = WINDUP
				aim_dir = dir
				aim_pivot.rotation.y = atan2(dir.x, dir.z)
				body.rotation.y = atan2(dir.x, dir.z)
				line.visible = true
		"windup":
			velocity = Vector3.ZERO
			timer -= delta
			k = 1.0 - 0.35 * (1.0 - timer / WINDUP)
			var lm := line.material_override as StandardMaterial3D
			lm.albedo_color.a = 0.3 + 0.3 * absf(sin(t * 14.0))
			if timer <= 0.0:
				_fire()
				line.visible = false
				state = "recover"
				timer = 0.7
		"recover":
			timer -= delta
			k = lerpf(1.0, 1.3, clampf(timer / 0.7, 0.0, 1.0))
			if timer <= 0.0:
				state = "move"
				cooldown = randf_range(2.0, 3.5)
	_apply_squash(k, delta)


func _apply_squash(k: float, delta: float) -> void:
	if flash > 0.0:
		flash -= delta
		k = 0.75
	body.scale = Vector3(2.0 - k, k, 2.0 - k)


func _fire() -> void:
	var b = BubbleScript.new()
	b.direction = aim_dir
	get_tree().current_scene.add_child(b)
	b.global_position = Vector3(global_position.x, 0.9, global_position.z) + aim_dir * 0.7


func take_damage(d: int) -> void:
	hp -= d
	flash = 0.15
	if hp <= 0:
		FX.pop(get_tree().current_scene, global_position + Vector3(0, 0.5, 0), Color(0.4, 0.95, 0.55), 12)
		remove_from_group("slimes")
		died.emit()
		queue_free()
