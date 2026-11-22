extends Node3D
## スライムが撃つ「閉じ込めシャボン玉」

const FX := preload("res://scripts/fx.gd")

var direction := Vector3.FORWARD
var speed := 6.5
var life := 2.4
var popped := false


func _ready() -> void:
	add_to_group("bubbles")
	FX.bubble(self, 0.45)


func _physics_process(delta: float) -> void:
	if popped:
		return
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0 or absf(global_position.x) > 12.5 or absf(global_position.z) > 12.5:
		pop()
		return
	var p = get_tree().get_first_node_in_group("player")
	if p != null and p.can_be_hit():
		if global_position.distance_to(p.global_position + Vector3(0, 0.9, 0)) < 0.85:
			p.on_bubble_hit()
			pop()


func pop() -> void:
	if popped:
		return
	popped = true
	remove_from_group("bubbles")
	FX.pop(get_tree().current_scene, global_position, Color(0.75, 0.9, 1.0), 6)
	queue_free()
