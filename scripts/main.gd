extends Node3D
## ダンジョンの1部屋：スライムをウェーブ形式で倒すアクション

const FX := preload("res://scripts/fx.gd")
const PlayerScript := preload("res://scripts/player.gd")
const SlimeScript := preload("res://scripts/slime.gd")
const HudScript := preload("res://scripts/hud.gd")

const HALF := 11.0
const WAVES := [2, 3, 5]  # 各ウェーブのスライム数

var player
var hud
var cam: Camera3D
var wave := 0
var alive := 0
var over := false
var over_time := 0.0


func _ready() -> void:
	_build_world()

	player = PlayerScript.new()
	add_child(player)

	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.position = Vector3(0, 10, 8)
	cam.look_at(Vector3(0, 0.8, 0), Vector3.UP)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	layer.add_child(hud)

	player.hp_changed.connect(_on_hp)
	player.mp_changed.connect(_on_mp)
	player.state_changed.connect(_on_status)
	player.died.connect(_on_player_died)
	hud.fire_pressed.connect(_on_tap)
	hud.hp = player.hp

	_next_wave()


func _process(delta: float) -> void:
	# スマホ：仮想スティック／ボタン、PC：矢印キー・WASD(矢印)＋Space
	var mv: Vector2 = hud.move_vec
	if mv == Vector2.ZERO:
		mv = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.move_input = mv
	player.fire_held = hud.fire_held or Input.is_action_pressed("ui_accept")
	if Input.is_action_just_pressed("ui_accept"):
		_on_tap()

	var target: Vector3 = player.position + Vector3(0, 10.0, 8.0)
	cam.position = cam.position.lerp(target, minf(1.0, 5.0 * delta))
	cam.look_at(player.position + Vector3(0, 0.8, 0), Vector3.UP)


# ---------- ステージ ----------
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.05, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.95)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)

	# 床（市松模様）
	_static_box(Vector3(0, -0.25, 0), Vector3(HALF * 2.0 + 2.0, 0.5, HALF * 2.0 + 2.0), Color(0.16, 0.2, 0.32))
	for i in 8:
		for j in 8:
			if (i + j) % 2 == 0:
				var p := Vector3(-10.5 + i * 3.0, 0.01, -10.5 + j * 3.0)
				FX.add_mesh(self, FX.box(Vector3(3.0, 0.02, 3.0)), Color(0.2, 0.26, 0.4), p)

	# 低い壁（カメラの視界を遮らない高さ）
	var wc := Color(0.35, 0.3, 0.5)
	var w := HALF * 2.0 + 2.0
	_static_box(Vector3(0, 0.6, -(HALF + 0.5)), Vector3(w, 1.2, 1.0), wc)
	_static_box(Vector3(0, 0.6, HALF + 0.5), Vector3(w, 1.2, 1.0), wc)
	_static_box(Vector3(-(HALF + 0.5), 0.6, 0), Vector3(1.0, 1.2, w), wc)
	_static_box(Vector3(HALF + 0.5, 0.6, 0), Vector3(1.0, 1.2, w), wc)

	# 柱
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_static_box(Vector3(sx * 5.0, 0.9, sz * 5.0), Vector3(1.2, 1.8, 1.2), Color(0.45, 0.4, 0.6))


func _static_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	FX.add_mesh(sb, FX.box(size), color)
	add_child(sb)


# ---------- ウェーブ進行 ----------
func _next_wave() -> void:
	if over:
		return
	wave += 1
	hud.wave_text = "WAVE %d / %d" % [wave, WAVES.size()]
	var n: int = WAVES[wave - 1]
	for i in n:
		var s = SlimeScript.new()
		s.player = player
		add_child(s)
		s.global_position = _spawn_pos()
		s.died.connect(_on_slime_died)
		alive += 1


func _spawn_pos() -> Vector3:
	var side := 1.0 if randf() < 0.5 else -1.0
	var a := side * randf_range(7.5, 10.0)
	var b := randf_range(-10.0, 10.0)
	return Vector3(a, 0.0, b) if randf() < 0.5 else Vector3(b, 0.0, a)


func _on_slime_died() -> void:
	alive -= 1
	if alive <= 0 and not over:
		if wave >= WAVES.size():
			_finish("ALL CLEAR!\nTap to play again")
		else:
			await get_tree().create_timer(1.5).timeout
			_next_wave()


func _on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	_finish("GAME OVER\nTap to retry")


func _finish(text: String) -> void:
	over = true
	over_time = Time.get_ticks_msec() / 1000.0
	hud.message = text


func _on_tap() -> void:
	if over:
		if Time.get_ticks_msec() / 1000.0 - over_time > 0.8:
			get_tree().reload_current_scene()
	else:
		player.tap()


func _on_hp(v: int) -> void:
	hud.hp = v


func _on_mp(v: float, m: float) -> void:
	hud.mp = v
	hud.mp_max = m


func _on_status(s: String) -> void:
	hud.status = s
