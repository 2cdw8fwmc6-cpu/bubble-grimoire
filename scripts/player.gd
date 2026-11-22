extends CharacterBody3D
## 主人公：魔導書で射撃魔法を使う魔法使いの女性

const FX := preload("res://scripts/fx.gd")
const BoltScript := preload("res://scripts/magic_bolt.gd")

signal hp_changed(value: int)
signal mp_changed(value: float, max_value: float)
signal state_changed(text: String)
signal died

const SPEED := 5.5
const MP_MAX := 100.0
const MP_COST := 14.0
const MP_REGEN := 20.0
const REGEN_DELAY := 0.7
const FIRE_INTERVAL := 0.3
const AIM_RANGE := 14.0
const BOOK_TRAP_TIME := 8.0
const BODY_TRAP_TIME := 4.0
const LIMIT := 10.2

var move_input := Vector2.ZERO
var fire_held := false
var hp := 3
var mp := MP_MAX
var dead := false
var book_trapped := false
var book_timer := 0.0
var trapped := false
var trap_timer := 0.0
var invuln := 0.0
var fire_cd := 0.0
var regen_delay := 0.0
var attack_anim := 0.0
var facing := Vector3(0, 0, 1)
var t := 0.0

var model: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var book: Node3D
var book_bubble: MeshInstance3D
var body_bubble: MeshInstance3D


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	_build_model()


# ---------- 見た目（プリミティブで作った人型。後でglTFモデルに差し替え可能） ----------
func _limb(pos: Vector3, r: float, h: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	model.add_child(pivot)
	FX.add_mesh(pivot, FX.capsule(r, h), color, Vector3(0, -h * 0.5, 0))
	return pivot


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var robe := Color(0.42, 0.25, 0.78)
	var robe_light := Color(0.62, 0.45, 0.92)
	var skin := Color(1.0, 0.85, 0.74)
	var hair := Color(0.97, 0.78, 0.88)
	var gold := Color(1.0, 0.82, 0.3)

	# 脚・スカート・胴
	leg_l = _limb(Vector3(-0.1, 0.36, 0), 0.06, 0.38, skin)
	leg_r = _limb(Vector3(0.1, 0.36, 0), 0.06, 0.38, skin)
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.18
	skirt.bottom_radius = 0.42
	skirt.height = 0.5
	FX.add_mesh(model, skirt, robe, Vector3(0, 0.55, 0))
	FX.add_mesh(model, FX.capsule(0.17, 0.6), robe_light, Vector3(0, 0.92, 0))
	FX.add_mesh(model, FX.sphere(0.05), gold, Vector3(-0.06, 1.12, 0.16))
	FX.add_mesh(model, FX.sphere(0.05), gold, Vector3(0.06, 1.12, 0.16))

	# 腕
	arm_l = _limb(Vector3(-0.24, 1.15, 0), 0.05, 0.42, skin)
	arm_r = _limb(Vector3(0.24, 1.15, 0), 0.05, 0.42, skin)

	# 頭・髪・顔
	FX.add_mesh(model, FX.sphere(0.2), skin, Vector3(0, 1.42, 0))
	FX.add_mesh(model, FX.capsule(0.2, 0.75), hair, Vector3(0, 1.2, -0.1))
	FX.add_mesh(model, FX.sphere(0.21), hair, Vector3(0, 1.46, -0.03))
	for sx in [-1.0, 1.0]:
		FX.add_mesh(model, FX.sphere(0.03), Color.BLACK, Vector3(sx * 0.07, 1.42, 0.18), true)
		FX.add_mesh(model, FX.sphere(0.03), Color(1.0, 0.6, 0.65), Vector3(sx * 0.11, 1.36, 0.16), true)

	# 魔女帽子
	var brim := CylinderMesh.new()
	brim.top_radius = 0.36
	brim.bottom_radius = 0.36
	brim.height = 0.03
	FX.add_mesh(model, brim, robe, Vector3(0, 1.6, 0))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.24
	cone.height = 0.5
	FX.add_mesh(model, cone, robe, Vector3(0, 1.85, -0.02))
	var band := CylinderMesh.new()
	band.top_radius = 0.235
	band.bottom_radius = 0.245
	band.height = 0.05
	FX.add_mesh(model, band, gold, Vector3(0, 1.65, -0.01))

	# 魔導書（右手）
	book = Node3D.new()
	book.position = Vector3(0, -0.42, 0.12)
	book.rotation_degrees = Vector3(-50, 0, 0)
	arm_r.add_child(book)
	FX.add_mesh(book, FX.box(Vector3(0.26, 0.07, 0.34)), Color(0.55, 0.1, 0.3))
	FX.add_mesh(book, FX.box(Vector3(0.1, 0.01, 0.1)), gold, Vector3(0, 0.04, 0))
	book_bubble = FX.bubble(book, 0.32)
	book_bubble.visible = false

	# 全身を包むシャボン玉
	body_bubble = FX.bubble(self, 0.95, Vector3(0, 0.9, 0))
	body_bubble.visible = false


# ---------- メイン処理 ----------
func _physics_process(delta: float) -> void:
	t += delta
	invuln = maxf(invuln - delta, 0.0)
	fire_cd = maxf(fire_cd - delta, 0.0)
	attack_anim = maxf(attack_anim - delta, 0.0)

	if dead:
		if trapped:
			_float(delta)
		_animate(delta, false)
		return

	_regen_mp(delta)

	if book_trapped and not trapped:
		book_timer -= delta
		if book_timer <= 0.0:
			_release_book()

	if trapped:
		_float(delta)
		trap_timer -= delta
		if trap_timer <= 0.0:
			_escape()
		_animate(delta, false)
		return

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * SPEED
	move_and_slide()
	var moving := dir.length() > 0.1
	if moving:
		facing = dir.normalized()
	if fire_held and fire_cd <= 0.0:
		_try_shoot()
	_animate(delta, moving)


func _regen_mp(delta: float) -> void:
	if regen_delay > 0.0:
		regen_delay -= delta
	elif mp < MP_MAX:
		mp = minf(MP_MAX, mp + MP_REGEN * delta)
		mp_changed.emit(mp, MP_MAX)


func _nearest_slime() -> Node3D:
	var best: Node3D = null
	var best_d := AIM_RANGE
	for n in get_tree().get_nodes_in_group("slimes"):
		var s: Node3D = n
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _try_shoot() -> void:
	if mp < MP_COST:
		fire_cd = 0.15
		return
	var dir := facing
	var target := _nearest_slime()
	if target != null:
		dir = target.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized()
		facing = dir
	var b = BoltScript.new()
	b.direction = dir
	b.weak = book_trapped
	b.damage = 1 if book_trapped else 3
	b.speed = 9.0 if book_trapped else 15.0
	get_tree().current_scene.add_child(b)
	b.global_position = global_position + Vector3(0, 0.85, 0) + dir * 0.7
	mp -= MP_COST
	mp_changed.emit(mp, MP_MAX)
	regen_delay = REGEN_DELAY
	fire_cd = FIRE_INTERVAL
	attack_anim = 0.25


# ---------- シャボン玉に閉じ込められる ----------
func can_be_hit() -> bool:
	return not dead and not trapped and invuln <= 0.0


func on_bubble_hit() -> void:
	if not can_be_hit():
		return
	if not book_trapped:
		# 1回目：魔導書だけ閉じ込められて魔法が弱体化
		book_trapped = true
		book_timer = BOOK_TRAP_TIME
		book_bubble.visible = true
		invuln = 0.8
		state_changed.emit("Grimoire trapped! Spells weakened")
	else:
		# 2回目：全身が閉じ込められる
		trapped = true
		trap_timer = BODY_TRAP_TIME
		hp -= 1
		hp_changed.emit(hp)
		body_bubble.visible = true
		book_bubble.visible = false
		if hp <= 0:
			dead = true
			state_changed.emit("")
			died.emit()
		else:
			state_changed.emit("Trapped! Tap fast to escape")


func tap() -> void:
	if trapped and not dead:
		trap_timer -= 0.5


func _float(delta: float) -> void:
	var target_y := 1.6 + sin(t * 2.0) * 0.2
	position.y = lerpf(position.y, target_y, 3.0 * delta)
	position.x = clampf(position.x + sin(t * 0.8) * 0.6 * delta, -LIMIT, LIMIT)
	position.z = clampf(position.z + cos(t * 1.1) * 0.6 * delta, -LIMIT, LIMIT)


func _escape() -> void:
	trapped = false
	body_bubble.visible = false
	position.y = 0.0
	FX.pop(get_tree().current_scene, global_position + Vector3(0, 1.0, 0), Color(0.7, 0.9, 1.0), 12)
	_release_book()
	invuln = 2.0


func _release_book() -> void:
	if book_trapped:
		FX.pop(get_tree().current_scene, book.global_position, Color(0.7, 0.9, 1.0), 6)
	book_trapped = false
	book_bubble.visible = false
	state_changed.emit("")


# ---------- アニメーション ----------
func _animate(delta: float, moving: bool) -> void:
	model.rotation.y = lerp_angle(model.rotation.y, atan2(facing.x, facing.z), 14.0 * delta)
	model.visible = invuln <= 0.0 or trapped or int(t * 20.0) % 2 == 0
	if trapped:
		# 閉じ込められモーション：手足をばたつかせる
		arm_l.rotation = Vector3(0, 0, -0.9 + sin(t * 5.0) * 0.3)
		arm_r.rotation = Vector3(0, 0, 0.9 - sin(t * 5.0 + 1.0) * 0.3)
		leg_l.rotation = Vector3(0.2 * sin(t * 4.0), 0, -0.25)
		leg_r.rotation = Vector3(-0.2 * sin(t * 4.0), 0, 0.25)
		model.position.y = 0.0
		return
	var swing := sin(t * 11.0) * 0.7 if moving else 0.0
	leg_l.rotation = Vector3(swing, 0, 0)
	leg_r.rotation = Vector3(-swing, 0, 0)
	arm_l.rotation = Vector3(-swing * 0.6, 0, -0.08)
	if attack_anim > 0.0:
		arm_r.rotation = Vector3(-1.5, 0, 0.0)  # 魔導書を前に突き出す
	else:
		arm_r.rotation = Vector3(swing * 0.6, 0, 0.08)
	model.position.y = absf(sin(t * 11.0)) * 0.04 if moving else sin(t * 3.0) * 0.01
