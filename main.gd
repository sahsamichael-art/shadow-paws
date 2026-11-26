extends Node2D
## Shadow Paws - kucing bayangan mengumpulkan tulang ikan di kuburan,
## sambil menghindari hantu berjubah merah.
## Kontrol: Panah / WASD, atau tahan klik / sentuh layar untuk bergerak.

const W := 480.0
const H := 900.0
const HUD_H := 60.0

# --- Ukuran frame pada spritesheet ---
const PLAYER_FRAME := Vector2(96, 93)    # 4 kolom x 8 baris
const ENEMY_FRAME := Vector2(106, 144)   # 4 kolom x 4 baris
const PLAYER_SCALE := 0.95
const ENEMY_SCALE := 0.42
const COIN_W := 44.0

# --- Baris animasi pada spritesheet ---
const P_ROW_DOWN := 4
const P_ROW_UP := 5
const P_ROW_RIGHT := 1
const P_ROW_LEFT := 3
const E_ROW_DOWN := 0
const E_ROW_LEFT := 1
const E_ROW_RIGHT := 2
const E_ROW_UP := 3

# --- Gameplay ---
const PLAYER_R := 15.0
const COIN_R := 20.0
const ENEMY_R := 17.0
const SPEED := 230.0
const START_ENEMIES := 3
const MAX_ENEMIES := 10
const START_COINS := 4

enum State { TITLE, PLAY, OVER }

var tex_bg: Texture2D = preload("res://assets/background.png")
var tex_player: Texture2D = preload("res://assets/player_sheet.png")
var tex_enemy: Texture2D = preload("res://assets/entity_sheet.png")
var tex_coin: Texture2D = preload("res://assets/fish_bone.png")

var state := State.TITLE
var player_pos := Vector2(W / 2.0, H * 0.7)
var player_row := P_ROW_DOWN
var player_moving := false
var coins: Array[Vector2] = []
var enemies: Array = []    # {"pos","vel","phase"}
var popups: Array = []     # {"pos","life"}
var score := 0
var best := 0
var lives := 3
var invuln := 0.0
var over_cooldown := 0.0
var t := 0.0


func _ready() -> void:
	randomize()
	reset_game()


func reset_game() -> void:
	player_pos = Vector2(W / 2.0, H * 0.7)
	player_row = P_ROW_DOWN
	coins.clear()
	enemies.clear()
	popups.clear()
	score = 0
	lives = 3
	invuln = 0.0
	for i in START_COINS:
		spawn_coin()
	for i in START_ENEMIES:
		spawn_enemy()


func random_point(margin: float = 36.0) -> Vector2:
	return Vector2(
		randf_range(margin, W - margin),
		randf_range(HUD_H + margin, H - margin))


func spawn_coin() -> void:
	var p := random_point()
	while p.distance_to(player_pos) < 70.0:
		p = random_point()
	coins.append(p)


func spawn_enemy() -> void:
	var p := random_point()
	while p.distance_to(player_pos) < 240.0:
		p = random_point()
	var spd := randf_range(70.0, 110.0) + minf(score * 1.5, 60.0)
	enemies.append({
		"pos": p,
		"vel": Vector2.from_angle(randf() * TAU) * spd,
		"phase": randf() * 4.0,
	})


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _start_pressed() -> bool:
	return _key(KEY_ENTER) or _key(KEY_SPACE) or _key(KEY_R) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _process(delta: float) -> void:
	t += delta
	match state:
		State.TITLE:
			if _start_pressed():
				reset_game()
				state = State.PLAY
		State.PLAY:
			_update_play(delta)
		State.OVER:
			over_cooldown = maxf(0.0, over_cooldown - delta)
			if over_cooldown <= 0.0 and _start_pressed():
				reset_game()
				state = State.PLAY
	queue_redraw()


func _update_play(delta: float) -> void:
	# ---- Input ----
	var dir := Vector2.ZERO
	if _key(KEY_LEFT) or _key(KEY_A):
		dir.x -= 1.0
	if _key(KEY_RIGHT) or _key(KEY_D):
		dir.x += 1.0
	if _key(KEY_UP) or _key(KEY_W):
		dir.y -= 1.0
	if _key(KEY_DOWN) or _key(KEY_S):
		dir.y += 1.0
	if dir == Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var to_mouse := get_global_mouse_position() - player_pos
		if to_mouse.length() > 8.0:
			dir = to_mouse.normalized()

	player_moving = dir != Vector2.ZERO
	if player_moving:
		dir = dir.normalized()
		if absf(dir.x) > absf(dir.y):
			player_row = P_ROW_RIGHT if dir.x > 0.0 else P_ROW_LEFT
		else:
			player_row = P_ROW_DOWN if dir.y > 0.0 else P_ROW_UP
		player_pos += dir * SPEED * delta
	player_pos.x = clampf(player_pos.x, PLAYER_R, W - PLAYER_R)
	player_pos.y = clampf(player_pos.y, HUD_H + PLAYER_R, H - PLAYER_R)

	# ---- Musuh ----
	for e in enemies:
		e["pos"] += e["vel"] * delta
		var p: Vector2 = e["pos"]
		var v: Vector2 = e["vel"]
		if p.x < ENEMY_R or p.x > W - ENEMY_R:
			v.x *= -1.0
			p.x = clampf(p.x, ENEMY_R, W - ENEMY_R)
		if p.y < HUD_H + ENEMY_R or p.y > H - ENEMY_R:
			v.y *= -1.0
			p.y = clampf(p.y, HUD_H + ENEMY_R, H - ENEMY_R)
		e["pos"] = p
		e["vel"] = v

	# ---- Ambil tulang ikan ----
	for i in range(coins.size() - 1, -1, -1):
		if coins[i].distance_to(player_pos) < PLAYER_R + COIN_R:
			popups.append({"pos": coins[i], "life": 0.7})
			coins.remove_at(i)
			score += 1
			spawn_coin()
			if score % 4 == 0 and coins.size() < 7:
				spawn_coin()
			if score % 5 == 0 and enemies.size() < MAX_ENEMIES:
				spawn_enemy()

	# ---- Tabrakan ----
	invuln = maxf(0.0, invuln - delta)
	if invuln <= 0.0:
		for e in enemies:
			if e["pos"].distance_to(player_pos) < PLAYER_R + ENEMY_R:
				lives -= 1
				invuln = 1.5
				if lives <= 0:
					state = State.OVER
					best = maxi(best, score)
					over_cooldown = 0.7
				break

	# ---- Popup "+1" ----
	for i in range(popups.size() - 1, -1, -1):
		var pp: Vector2 = popups[i]["pos"]
		pp.y -= 40.0 * delta
		popups[i]["pos"] = pp
		popups[i]["life"] -= delta
		if popups[i]["life"] <= 0.0:
			popups.remove_at(i)


# ------------------------------------------------------------------ DRAW

func _draw_frame(tex: Texture2D, frame: Vector2, col: int, row: int,
		center: Vector2, scale: float, modulate_col: Color = Color.WHITE) -> void:
	var src := Rect2(col * frame.x, row * frame.y, frame.x, frame.y)
	var size := frame * scale
	draw_texture_rect_region(tex, Rect2(center - size / 2.0, size), src, modulate_col)


func _draw_heart(c: Vector2, r: float, filled: bool) -> void:
	var col := Color(1.0, 0.35, 0.5) if filled else Color(0.5, 0.35, 0.6)
	draw_circle(c + Vector2(-r * 0.55, -r * 0.2), r * 0.62, col)
	draw_circle(c + Vector2(r * 0.55, -r * 0.2), r * 0.62, col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 1.12, 0.0),
		c + Vector2(r * 1.12, 0.0),
		c + Vector2(0.0, r * 1.25)]), col)


func _text(font: Font, pos: Vector2, s: String, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		width: float = -1.0, col: Color = Color.WHITE) -> void:
	draw_string_outline(font, pos, s, align, width, size, 6, Color(0.05, 0.02, 0.12))
	draw_string(font, pos, s, align, width, size, col)


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Latar
	draw_texture_rect(tex_bg, Rect2(0, 0, W, H), false)

	if state == State.TITLE:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		_text(font, Vector2(0, 300), "SHADOW PAWS", 52, HORIZONTAL_ALIGNMENT_CENTER, W, Color(1.0, 0.85, 0.3))
		_draw_frame(tex_player, PLAYER_FRAME, int(t * 6.0) % 4, P_ROW_DOWN, Vector2(W / 2.0, 410), 2.2)
		_text(font, Vector2(0, 520), "Kumpulkan tulang ikan,", 22, HORIZONTAL_ALIGNMENT_CENTER, W)
		_text(font, Vector2(0, 552), "hindari hantu berjubah merah!", 22, HORIZONTAL_ALIGNMENT_CENTER, W)
		_text(font, Vector2(0, 620), "Panah / WASD, atau tahan klik / sentuh layar", 16, HORIZONTAL_ALIGNMENT_CENTER, W, Color(0.8, 0.8, 1.0))
		if int(t * 2.0) % 2 == 0:
			_text(font, Vector2(0, 700), "Tekan Enter / Space / Klik untuk mulai", 20, HORIZONTAL_ALIGNMENT_CENTER, W, Color(1.0, 0.85, 0.3))
		return

	# Tulang ikan (melayang naik-turun)
	var coin_size := Vector2(COIN_W, COIN_W * tex_coin.get_height() / float(tex_coin.get_width()))
	for c in coins:
		var bob := sin(t * 4.0 + c.x * 0.05) * 3.0
		var sc := 1.0 + 0.06 * sin(t * 5.0 + c.y * 0.05)
		var sz := coin_size * sc
		draw_circle(c + Vector2(0, bob), 20.0, Color(1.0, 1.0, 1.0, 0.10))   # kilau halus
		draw_texture_rect(tex_coin, Rect2(c + Vector2(0, bob) - sz / 2.0, sz), false)

	# Musuh (urutkan berdasarkan y agar tumpang tindih terlihat benar)
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for e in sorted:
		var v: Vector2 = e["vel"]
		var row := E_ROW_DOWN
		if absf(v.x) > absf(v.y):
			row = E_ROW_RIGHT if v.x > 0.0 else E_ROW_LEFT
		else:
			row = E_ROW_DOWN if v.y > 0.0 else E_ROW_UP
		var frame := int((t + e["phase"]) * 6.0) % 4
		draw_circle(e["pos"] + Vector2(0, 24), 14.0, Color(0, 0, 0, 0.25))     # bayangan
		_draw_frame(tex_enemy, ENEMY_FRAME, frame, row, e["pos"], ENEMY_SCALE)

	# Pemain: kucing hitam sangat gelap, jadi diberi aura terang agar mudah terlihat
	if state == State.PLAY or state == State.TITLE:
		var blink_hidden := invuln > 0.0 and int(t * 14.0) % 2 == 0
		if not blink_hidden:
			var pulse := 1.0 + 0.08 * sin(t * 5.0)
			draw_circle(player_pos, 34.0 * pulse, Color(0.75, 0.6, 1.0, 0.10))
			draw_circle(player_pos, 24.0 * pulse, Color(0.85, 0.75, 1.0, 0.16))
			draw_circle(player_pos + Vector2(0, 18), 14.0, Color(0, 0, 0, 0.30))
			var pf := int(t * 9.0) % 4 if player_moving else 0
			_draw_frame(tex_player, PLAYER_FRAME, pf, player_row, player_pos, PLAYER_SCALE)

	# Popup +1
	for p in popups:
		var a := clampf(p["life"] / 0.7, 0.0, 1.0)
		_text(font, p["pos"] + Vector2(-14, -20), "+1", 22, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Color(1.0, 0.9, 0.4, a))

	# HUD
	draw_rect(Rect2(0, 0, W, HUD_H), Color(0.06, 0.03, 0.14, 0.82))
	draw_rect(Rect2(0, HUD_H - 2, W, 2), Color(0.55, 0.4, 0.9, 0.9))
	_text(font, Vector2(16, 38), "Skor: %d" % score, 22)
	for i in 3:
		_draw_heart(Vector2(W / 2.0 - 30.0 + i * 30.0, 30.0), 9.0, i < lives)
	_text(font, Vector2(0, 38), "Terbaik: %d" % best, 18, HORIZONTAL_ALIGNMENT_RIGHT, W - 16.0, Color(0.85, 0.85, 1.0))

	# Game over
	if state == State.OVER:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.65))
		_text(font, Vector2(0, 380), "GAME OVER", 54, HORIZONTAL_ALIGNMENT_CENTER, W, Color(1.0, 0.4, 0.45))
		_text(font, Vector2(0, 440), "Skor akhir: %d" % score, 28, HORIZONTAL_ALIGNMENT_CENTER, W)
		_text(font, Vector2(0, 480), "Terbaik: %d" % best, 20, HORIZONTAL_ALIGNMENT_CENTER, W, Color(0.85, 0.85, 1.0))
		if over_cooldown <= 0.0 and int(t * 2.0) % 2 == 0:
			_text(font, Vector2(0, 560), "Enter / Space / Klik untuk main lagi", 20, HORIZONTAL_ALIGNMENT_CENTER, W, Color(1.0, 0.85, 0.3))
