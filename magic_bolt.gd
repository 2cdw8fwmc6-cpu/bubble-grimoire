extends Node3D
## 魔導書から放たれる射撃魔法

const FX := preload("res://scripts/fx.gd")

var direction := Vector3.FORWARD
var damage := 3
var speed := 15.0
var weak := false  # 魔導書が閉じ込められている間は弱体化
var life := 1.6


func _ready() -> void:
	var c := Color(0.55, 0.45, 0.65) if weak else Color(0.6, 0.95, 1.0)
	var r := 0.11 if weak else 0.17
	FX.add_mesh(self, FX.sphere(r), c, Vector3.ZERO, true)
	FX.add_mesh(self, FX.sphere(r * 1.7), Color(c.r, c.g, c.b, 0.3), Vector3.ZERO, true)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0 or absf(global_position.x) > 12.5 or absf(global_position.z) > 12.5:
		queue_free()
		return
	# 敵のシャボン玉は魔法で割れる
	for n in get_tree().get_nodes_in_group("bubbles"):
		var b: Node3D = n
		if global_position.distance_to(b.global_position) < 0.7:
			b.call("pop")
			queue_free()
			return
	for n in get_tree().get_nodes_in_group("slimes"):
		var s: Node3D = n
		if global_position.distance_to(s.global_position + Vector3(0, 0.5, 0)) < 0.8:
			s.call("take_damage", damage)
			FX.pop(get_tree().current_scene, global_position, Color(0.6, 0.95, 1.0), 5)
			queue_free()
			return
