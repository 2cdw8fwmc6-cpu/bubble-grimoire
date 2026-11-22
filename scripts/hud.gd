extends Control
## スマホ用タッチUI：左半分＝仮想スティック、右下＝魔法ボタン。HP/MP表示も担当

signal fire_pressed

const STICK_R := 90.0
const FIRE_R := 85.0
const MAX_HP := 3

var move_vec := Vector2.ZERO
var fire_held := false
var hp := 3
var mp := 100.0
var mp_max := 100.0
var status := ""
var wave_text := ""
var message := ""

var _stick_id := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _fire_id := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _fire_center() -> Vector2:
	return Vector2(size.x - 150.0, size.y - 140.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if e.position.distance_to(_fire_center()) < FIRE_R * 1.5 and _fire_id == -1:
				_fire_id = e.index
				fire_held = true
				fire_pressed.emit()
			elif e.position.x < size.x * 0.55 and _stick_id == -1:
				_stick_id = e.index
				_origin = e.position
				_knob = e.position
			else:
				fire_pressed.emit()
		else:
			if e.index == _fire_id:
				_fire_id = -1
				fire_held = false
			elif e.index == _stick_id:
				_stick_id = -1
				move_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			var v := d.position - _origin
			if v.length() > STICK_R:
				v = v.normalized() * STICK_R
			_knob = _origin + v
			move_vec = v / STICK_R
			if move_vec.length() < 0.15:
				move_vec = Vector2.ZERO


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# 仮想スティック
	var base := _origin if _stick_id != -1 else Vector2(150.0, size.y - 140.0)
	var knob := _knob if _stick_id != -1 else base
	draw_circle(base, STICK_R, Color(1, 1, 1, 0.12))
	draw_arc(base, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(knob, 38.0, Color(1, 1, 1, 0.35))

	# 魔法ボタン（MP不足だと暗くなる）
	var fc := _fire_center()
	var col := Color(0.6, 0.4, 1.0, 0.55 if mp >= 14.0 else 0.2)
	if fire_held and mp >= 14.0:
		col.a = 0.85
	draw_circle(fc, FIRE_R, col)
	draw_arc(fc, FIRE_R, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_string(font, fc + Vector2(-50, 10), "MAGIC", HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color.WHITE)

	# HP（ハート代わりの丸）
	for i in MAX_HP:
		var c := Color(1.0, 0.35, 0.5) if i < hp else Color(0.25, 0.2, 0.3)
		draw_circle(Vector2(40.0 + i * 38.0, 40.0), 14.0, c)

	# MPバー
	draw_rect(Rect2(24, 66, 240, 16), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(24, 66, 240.0 * clampf(mp / mp_max, 0.0, 1.0), 16), Color(0.35, 0.8, 1.0))
	draw_string(font, Vector2(272, 80), "MP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

	# ウェーブ表示・状態表示
	draw_string(font, Vector2(0, 50), wave_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color.WHITE)
	if status != "":
		draw_string(font, Vector2(0, 90), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(1.0, 0.9, 0.4))

	# メッセージ（ゲームオーバー／クリア）
	if message != "":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		var lines := message.split("\n")
		var y := size.y * 0.4
		for l in lines:
			draw_string(font, Vector2(0, y), l, HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color.WHITE)
			y += 64.0
