extends Node2D
## Blossom Blade - an original 2D samurai boss-rush with touch controls.
## Slash cuts petals and hurts oni. PARRY the instant a hit lands for big damage.

const W := 1280.0
const H := 720.0
const GROUND := 600.0
const GRAV := 2400.0
const SPEED := 380.0
const JUMP_V := -900.0
const MAX_HP := 5
const BOSS_NAMES := ["Hollow Oni", "Crimson Oni", "Oni Emperor"]
const BOSS_HP := [12, 18, 26]
const BOSS_COLORS := [Color("5b6b8c"), Color("a8323e"), Color("5a3a8a")]

var mode := "title" # title, play, between, win, lose
var timer := 0.0
var lock := 0.0
var clock := 0.0
var shake := 0.0
var boss_i := 0
var p := {}
var b := {}
var shots := []
var waves := []
var fx := []
var petals := []
var touches := {}
var buttons := {}
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	randomize()
	buttons = {
		"left": [Vector2(110, 590), 80.0, "<"],
		"right": [Vector2(290, 590), 80.0, ">"],
		"jump": [Vector2(1085, 420), 65.0, "JUMP"],
		"parry": [Vector2(1010, 560), 70.0, "PARRY"],
		"slash": [Vector2(1160, 560), 80.0, "SLASH"],
	}
	for i in 40:
		petals.append({
			"x": randf() * W, "y": randf() * H,
			"s": randf() * 6.28, "v": randf_range(20.0, 60.0), "r": randf_range(2.0, 5.0),
		})
	_start_run()
	mode = "title"
	lock = 0.3


func _start_run() -> void:
	boss_i = 0
	p = {
		"x": 300.0, "y": GROUND, "vy": 0.0, "face": 1, "hp": MAX_HP,
		"atk": 0.0, "atk_cd": 0.0, "parry": 0.0, "parry_cd": 0.0, "inv": 0.0, "hit": false,
	}
	fx.clear()
	_spawn_boss()
	_set_mode("play")


func _spawn_boss() -> void:
	var hp: int = BOSS_HP[boss_i]
	b = {
		"x": 900.0, "y": GROUND, "w": 120.0, "h": 160.0, "hp": hp, "max": hp,
		"face": -1, "st": "idle", "t": 1.2, "atk": "", "vx": 0.0, "vy": 0.0,
		"n": 0, "hit": false, "col": BOSS_COLORS[boss_i], "name": BOSS_NAMES[boss_i],
	}
	shots.clear()
	waves.clear()
	p.x = 300.0


func _set_mode(m: String) -> void:
	mode = m
	timer = 0.0
	lock = 0.5


# ---------------------------------------------------------------- input

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			if mode != "play":
				_tap_start()
				return
			var a := _button_at(t.position)
			if a != "":
				touches[t.index] = a
				_do_action(a)
		else:
			touches.erase(t.index)
	elif e is InputEventScreenDrag:
		var dr := e as InputEventScreenDrag
		if touches.has(dr.index) and (touches[dr.index] == "left" or touches[dr.index] == "right"):
			var a2 := _button_at(dr.position)
			if a2 == "left" or a2 == "right":
				touches[dr.index] = a2
	elif e is InputEventKey:
		var k := e as InputEventKey
		if not k.pressed or k.echo:
			return
		if mode != "play":
			_tap_start()
			return
		match k.keycode:
			KEY_SPACE, KEY_W, KEY_UP:
				_do_action("jump")
			KEY_Z, KEY_J:
				_do_action("slash")
			KEY_X, KEY_K:
				_do_action("parry")


func _tap_start() -> void:
	if lock > 0.0:
		return
	if mode == "title" or mode == "win" or mode == "lose":
		_start_run()


func _button_at(pos: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	for k in buttons:
		var c: Vector2 = buttons[k][0]
		var r: float = buttons[k][1]
		var d := pos.distance_to(c)
		if d <= r + 12.0 and d < best_d:
			best = k
			best_d = d
	return best


func _do_action(a: String) -> void:
	match a:
		"jump":
			if p.y >= GROUND - 0.1:
				p.vy = JUMP_V
		"slash":
			if p.atk_cd <= 0.0:
				p.atk = 0.18
				p.atk_cd = 0.3
				p.hit = false
		"parry":
			if p.parry_cd <= 0.0:
				p.parry = 0.22
				p.parry_cd = 0.7


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	clock += delta
	timer += delta
	lock = maxf(0.0, lock - delta)
	shake = maxf(0.0, shake - delta * 30.0)

	if mode == "play":
		_update_player(delta)
	if mode == "play":
		_update_boss(delta)
	if mode == "play":
		_update_shots(delta)
		_update_waves(delta)
	if mode == "between" and timer > 2.4:
		p.hp = mini(MAX_HP, p.hp + 2)
		_spawn_boss()
		mode = "play"

	for f in fx.duplicate():
		f.vy += 900.0 * delta
		f.x += f.vx * delta
		f.y += f.vy * delta
		f.life -= delta
		if f.life <= 0.0:
			fx.erase(f)
	for pt in petals:
		pt.y += pt.v * delta
		pt.x += sin(clock * 0.7 + pt.s) * 30.0 * delta
		if pt.y > H:
			pt.y = -10.0
			pt.x = randf() * W
	queue_redraw()


func _update_player(d: float) -> void:
	var dir := 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir += 1
	for k in touches:
		if touches[k] == "left":
			dir -= 1
		elif touches[k] == "right":
			dir += 1
	dir = clampi(dir, -1, 1)
	var speed_mul := 0.4 if p.atk > 0.0 else 1.0
	if dir != 0 and p.atk <= 0.0:
		p.face = dir
	p.x = clampf(p.x + dir * SPEED * speed_mul * d, 40.0, W - 40.0)
	p.vy += GRAV * d
	p.y += p.vy * d
	if p.y >= GROUND:
		p.y = GROUND
		p.vy = 0.0
	p.atk = maxf(0.0, p.atk - d)
	p.atk_cd = maxf(0.0, p.atk_cd - d)
	p.parry = maxf(0.0, p.parry - d)
	p.parry_cd = maxf(0.0, p.parry_cd - d)
	p.inv = maxf(0.0, p.inv - d)

	if p.atk > 0.0:
		var r := _slash_rect()
		for s in shots.duplicate():
			if s.own == "boss" and Rect2(s.x - s.r, s.y - s.r, s.r * 2.0, s.r * 2.0).intersects(r):
				shots.erase(s)
				_burst(Vector2(s.x, s.y), Color("ff9ec7"), 8)
		if not p.hit and r.intersects(_boss_rect()):
			p.hit = true
			_hurt_boss(2 if b.st == "stun" else 1, Vector2(b.x, b.y - 90.0))


func _slash_rect() -> Rect2:
	if p.face > 0:
		return Rect2(p.x - 10.0, p.y - 95.0, 130.0, 95.0)
	return Rect2(p.x - 120.0, p.y - 95.0, 130.0, 95.0)


func _boss_rect() -> Rect2:
	return Rect2(b.x - b.w * 0.5, b.y - b.h, b.w, b.h)


func _player_rect() -> Rect2:
	return Rect2(p.x - 20.0, p.y - 80.0, 40.0, 80.0)


func _update_boss(d: float) -> void:
	b.t -= d
	var to_p: float = p.x - b.x
	match b.st:
		"idle":
			b.face = 1 if to_p > 0.0 else -1
			if absf(to_p) > 260.0:
				b.x += b.face * 120.0 * d
			if b.t <= 0.0:
				_pick_attack()
		"tele":
			if b.t <= 0.0:
				_begin_attack()
		"atk":
			_run_attack(d)
		"rec":
			if b.t <= 0.0:
				b.st = "idle"
				b.t = maxf(0.35, 0.9 - 0.15 * boss_i)
		"stun":
			b.vy += GRAV * d
			b.y = minf(GROUND, b.y + b.vy * d)
			if b.y >= GROUND:
				b.vy = 0.0
			if b.t <= 0.0:
				b.st = "idle"
				b.t = 0.6
	b.x = clampf(b.x, 70.0, W - 70.0)


func _pick_attack() -> void:
	var opts := ["dash", "petals", "slam"]
	b.atk = opts[randi() % opts.size()]
	b.st = "tele"
	b.hit = false
	b.n = 0
	b.face = 1 if p.x > b.x else -1
	b.t = (0.7 if b.atk == "slam" else 0.55) - 0.05 * boss_i


func _begin_attack() -> void:
	b.st = "atk"
	b.hit = false
	match b.atk:
		"dash":
			b.t = 0.55
			b.vx = b.face * (620.0 + 80.0 * boss_i)
		"petals":
			b.t = 0.0
			b.n = 3 + boss_i
		"slam":
			b.vy = -1100.0
			b.vx = (p.x - b.x) / 0.92
			b.t = 0.0


func _end_attack(rest: float) -> void:
	b.st = "rec"
	b.t = rest
	b.vx = 0.0
	b.vy = 0.0
	b.y = GROUND


func _run_attack(d: float) -> void:
	match b.atk:
		"dash":
			b.x += b.vx * d
			if not b.hit and _boss_rect().intersects(_player_rect()):
				b.hit = true
				_body_hit()
			if b.st == "atk" and (b.t <= 0.0 or b.x <= 70.0 or b.x >= W - 70.0):
				_end_attack(0.8)
		"petals":
			if b.t <= 0.0:
				if b.n > 0:
					var high := randf() < 0.4
					shots.append({
						"x": b.x + b.face * 60.0, "y": GROUND - (130.0 if high else 45.0),
						"vx": b.face * (420.0 + 40.0 * boss_i), "r": 20.0, "own": "boss",
					})
					b.n -= 1
					b.t = 0.35 - 0.03 * boss_i
				else:
					_end_attack(0.9)
		"slam":
			b.x += b.vx * d
			b.vy += GRAV * d
			b.y += b.vy * d
			if b.vy > 0.0 and not b.hit and _boss_rect().intersects(_player_rect()):
				b.hit = true
				_body_hit()
			if b.st == "atk" and b.y >= GROUND:
				var v := 480.0 + 40.0 * boss_i
				waves.append({"x": b.x, "dir": 1, "v": v, "life": 2.0})
				waves.append({"x": b.x, "dir": -1, "v": v, "life": 2.0})
				shake = 14.0
				_end_attack(1.0)


func _body_hit() -> void:
	var res := _hit_player()
	if res == "parried":
		_hurt_boss(3, Vector2(b.x, b.y - 90.0))
		if mode == "play":
			b.st = "stun"
			b.t = 1.4
			b.vx = 0.0


func _update_shots(d: float) -> void:
	for s in shots.duplicate():
		s.x += s.vx * d
		if s.x < -50.0 or s.x > W + 50.0:
			shots.erase(s)
			continue
		var circ := Rect2(s.x - s.r, s.y - s.r, s.r * 2.0, s.r * 2.0)
		if s.own == "boss":
			if circ.intersects(_player_rect()):
				var res := _hit_player()
				if res == "parried":
					s.own = "player"
					s.vx = -s.vx * 1.6
				elif res == "hurt":
					shots.erase(s)
		elif mode == "play" and circ.intersects(_boss_rect()):
			shots.erase(s)
			_hurt_boss(2, Vector2(s.x, s.y))


func _update_waves(d: float) -> void:
	for w in waves.duplicate():
		w.x += w.dir * w.v * d
		w.life -= d
		if w.life <= 0.0 or w.x < -50.0 or w.x > W + 50.0:
			waves.erase(w)
			continue
		var r := Rect2(w.x - 22.0, GROUND - 50.0, 44.0, 50.0)
		if r.intersects(_player_rect()):
			var res := _hit_player()
			if res == "parried":
				waves.erase(w)
				_hurt_boss(2, Vector2(b.x, b.y - 90.0))
			elif res == "hurt":
				waves.erase(w)
		if mode != "play":
			return


## Returns "parried", "hurt" or "none" (player is briefly invulnerable).
func _hit_player() -> String:
	if p.parry > 0.0:
		p.inv = maxf(p.inv, 0.5)
		p.parry_cd = 0.0
		shake = 12.0
		_burst(Vector2(p.x, p.y - 50.0), Color("fff3b0"), 24)
		return "parried"
	if p.inv > 0.0:
		return "none"
	p.hp -= 1
	p.inv = 1.2
	shake = 10.0
	_burst(Vector2(p.x, p.y - 50.0), Color("d6304a"), 16)
	if p.hp <= 0:
		_set_mode("lose")
	return "hurt"


func _hurt_boss(n: int, at: Vector2) -> void:
	b.hp -= n
	shake = maxf(shake, 8.0)
	_burst(at, Color("ffd1e8"), 10)
	if b.hp <= 0:
		_burst(Vector2(b.x, b.y - 80.0), Color("ffd1e8"), 50)
		shots.clear()
		waves.clear()
		boss_i += 1
		if boss_i >= BOSS_NAMES.size():
			_set_mode("win")
		else:
			_set_mode("between")


func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		fx.append({
			"x": at.x, "y": at.y,
			"vx": randf_range(-320.0, 320.0), "vy": randf_range(-450.0, 100.0),
			"life": randf_range(0.3, 0.7), "col": col,
		})


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_set_transform(Vector2(randf_range(-shake, shake), randf_range(-shake, shake)))
	_draw_world()
	draw_set_transform(Vector2.ZERO)
	_draw_hud()


func _draw_world() -> void:
	draw_rect(Rect2(-20, -20, W + 40, H + 40), Color("1b1030"))
	draw_rect(Rect2(-20, 300, W + 40, 300), Color("2b1747"))
	draw_circle(Vector2(1000, 140), 90, Color(0.96, 0.9, 0.78, 0.12))
	draw_circle(Vector2(1000, 140), 66, Color("f6e7c8"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, GROUND), Vector2(180, 380), Vector2(380, 520), Vector2(620, 340),
		Vector2(860, 500), Vector2(1100, 400), Vector2(W + 20, GROUND)]), Color("22123b"))
	# sakura tree
	draw_rect(Rect2(60, 360, 34, 240), Color("2a1a2e"))
	for c in [Vector2(40, 340), Vector2(110, 300), Vector2(170, 360), Vector2(80, 390), Vector2(140, 420)]:
		draw_circle(c, 62, Color(1.0, 0.62, 0.78, 0.85))
	draw_rect(Rect2(-20, GROUND, W + 40, H - GROUND + 20), Color("120a1f"))
	draw_line(Vector2(0, GROUND), Vector2(W, GROUND), Color("6a4a8a"), 3.0)
	for pt in petals:
		draw_circle(Vector2(pt.x, pt.y), pt.r, Color(1.0, 0.7, 0.85, 0.7))

	for w in waves:
		draw_colored_polygon(PackedVector2Array([
			Vector2(w.x - 22, GROUND), Vector2(w.x, GROUND - 50), Vector2(w.x + 22, GROUND)]), Color("ff5a4a"))
	for s in shots:
		var col := Color("ff5a7a") if s.own == "boss" else Color("fff3b0")
		draw_circle(Vector2(s.x, s.y), s.r, col)
		draw_circle(Vector2(s.x, s.y), s.r * 0.5, Color.WHITE)

	if mode != "win":
		_draw_boss()
	_draw_player()

	for f in fx:
		var c: Color = f.col
		c.a = clampf(f.life * 2.0, 0.0, 1.0)
		draw_circle(Vector2(f.x, f.y), 4.0, c)


func _draw_boss() -> void:
	var col: Color = b.col
	var top: float = b.y - b.h
	var f: float = b.face
	draw_line(Vector2(b.x + f * 50.0, b.y - 60.0), Vector2(b.x + f * 130.0, b.y - 120.0), Color("3a2a1a"), 14.0)
	draw_circle(Vector2(b.x + f * 130.0, b.y - 120.0), 20.0, Color("2a1c10"))
	draw_rect(Rect2(b.x - b.w * 0.5, top, b.w, b.h), col)
	draw_circle(Vector2(b.x, top - 6.0), 44.0, col.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.x - 34, top - 30), Vector2(b.x - 20, top - 84), Vector2(b.x - 6, top - 38)]), Color("f1e6d0"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.x + 34, top - 30), Vector2(b.x + 20, top - 84), Vector2(b.x + 6, top - 38)]), Color("f1e6d0"))
	draw_circle(Vector2(b.x + f * 10.0 - 14.0, top - 8.0), 6.0, Color("ffd24a"))
	draw_circle(Vector2(b.x + f * 10.0 + 14.0, top - 8.0), 6.0, Color("ffd24a"))
	if b.st == "tele":
		var a := 0.25 + 0.25 * sin(clock * 40.0)
		draw_rect(Rect2(b.x - b.w * 0.5, top, b.w, b.h), Color(1, 1, 1, a))
		draw_string(font, Vector2(b.x - 12.0, top - 100.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("ffd24a"))
	elif b.st == "stun":
		draw_rect(Rect2(b.x - b.w * 0.5, top, b.w, b.h), Color(1.0, 0.9, 0.3, 0.3))
		draw_string(font, Vector2(b.x - 60.0, top - 100.0), "STUNNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ffd24a"))


func _draw_player() -> void:
	if p.inv > 0.0 and int(clock * 20.0) % 2 == 0:
		return
	var f: float = p.face
	var x: float = p.x
	var y: float = p.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - f * 10.0, y - 64.0), Vector2(x - f * 60.0, y - 52.0 + sin(clock * 10.0) * 6.0),
		Vector2(x - f * 10.0, y - 52.0)]), Color("d6304a"))
	draw_rect(Rect2(x - 18.0, y - 70.0, 36.0, 70.0), Color("e8e3f5"))
	draw_rect(Rect2(x - 18.0, y - 34.0, 36.0, 10.0), Color("3a2f5a"))
	draw_circle(Vector2(x, y - 84.0), 16.0, Color("f2d7c0"))
	draw_rect(Rect2(x - 18.0, y - 104.0, 36.0, 12.0), Color("1a1226"))
	if p.atk > 0.0:
		var frac: float = 1.0 - p.atk / 0.18
		var a0 := -1.1
		var a1 := -1.1 + 2.2 * frac
		var cen := Vector2(x, y - 45.0)
		if f > 0.0:
			draw_arc(cen, 95.0, a0, a1, 20, Color.WHITE, 8.0)
		else:
			draw_arc(cen, 95.0, PI - a1, PI - a0, 20, Color.WHITE, 8.0)
	else:
		draw_line(Vector2(x - f * 14.0, y - 20.0), Vector2(x + f * 30.0, y - 4.0), Color("cfd6e6"), 4.0)
	if p.parry > 0.0:
		draw_circle(Vector2(x, y - 48.0), 62.0, Color(0.5, 0.9, 1.0, 0.2))
		draw_arc(Vector2(x, y - 48.0), 62.0, 0.0, TAU, 32, Color("7fe3ff"), 6.0)


func _text(t: String, y: float, size: int, col: Color = Color.WHITE) -> void:
	draw_string(font, Vector2(0.0, y), t, HORIZONTAL_ALIGNMENT_CENTER, W, size, col)


func _draw_hud() -> void:
	for i in MAX_HP:
		var c := Color("e0405a") if i < p.hp else Color("3a2438")
		draw_circle(Vector2(50.0 + i * 40.0, 44.0), 14.0, c)
	if mode == "play" or mode == "between" or mode == "lose":
		draw_rect(Rect2(340, 30, 600, 18), Color("2a1c3a"))
		var frac := clampf(float(b.hp) / float(b.max), 0.0, 1.0)
		draw_rect(Rect2(340, 30, 600.0 * frac, 18), Color("ff7a9a"))
		draw_string(font, Vector2(340.0, 24.0), "%s  (%d/3)" % [b.name, mini(boss_i + 1, 3)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f6e7c8"))
	for k in buttons:
		var c: Vector2 = buttons[k][0]
		var r: float = buttons[k][1]
		var held: bool = touches.values().has(k)
		draw_circle(c, r, Color(1, 1, 1, 0.28 if held else 0.1))
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
		draw_string(font, c + Vector2(-r, 10.0), buttons[k][2], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 26, Color(1, 1, 1, 0.8))

	if mode == "title":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		_text("BLOSSOM BLADE", 270, 84, Color("ffb3d1"))
		_text("Slash to cut petals and hurt the oni.", 350, 30)
		_text("PARRY the moment a hit lands for huge damage and a stun!", 392, 30)
		_text("Tap to start", 500, 40, Color("ffd24a"))
	elif mode == "between":
		_text("Oni sealed!", 320, 70, Color("ffb3d1"))
		_text("Next: %s  (+2 health)" % BOSS_NAMES[mini(boss_i, 2)], 380, 32)
	elif mode == "win":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		_text("ALL ONI SEALED", 300, 78, Color("ffb3d1"))
		_text("Tap to play again", 400, 40, Color("ffd24a"))
	elif mode == "lose":
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		_text("DEFEATED", 300, 78, Color("ff5a7a"))
		_text("Tap to try again", 400, 40, Color("ffd24a"))
