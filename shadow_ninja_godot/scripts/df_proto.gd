extends Node2D
## Prototype battle screen in a hand-drawn vector style (DragonFable-inspired, all original art).
## Run: godot --path . res://scenes/df_proto.tscn   (add `-- --shots=<dir>` to save screenshots and quit)

const GROUND := 588.0

var hero: DfActors.Hero
var dragon: DfActors.Dragon
var shroom: DfActors.Shroom
var ehp := 140.0
var ehp_max := 140.0
var ebar: ProgressBar
var busy := false


class Bg extends Node2D:
	func _cloud(c: Vector2, s: float) -> void:
		var bl := [[0, 0, 34], [-36, 8, 24], [38, 8, 26], [-14, -18, 26], [18, -16, 22]]
		for b in bl: draw_circle(c + Vector2(b[0], b[1]) * s, (b[2] + 3) * s, Color("#8fb7d8"))
		for b in bl: draw_circle(c + Vector2(b[0], b[1]) * s, b[2] * s, Color("#fdfdf8"))
		for b in bl: draw_circle(c + Vector2(b[0] - 4, b[1] + 6) * s, b[2] * 0.7 * s, Color("#e4eef6"))

	func _tree(x: float, y: float, s: float, col: Color) -> void:
		Vec.paint(self, Vec.S([x - 7 * s, y, x + 7 * s, y, x + 5 * s, y - 50 * s, x - 5 * s, y - 50 * s], 2), Color("#7a5232"), Vector2(2, 2), 2.5)
		var bl := [[0, -70, 34], [-28, -52, 24], [28, -50, 26], [-14, -92, 24], [16, -88, 22]]
		for b in bl: draw_circle(Vector2(x + b[0] * s, y + b[1] * s), (b[2] + 2.5) * s, Vec.OUT)
		for b in bl: draw_circle(Vector2(x + b[0] * s, y + b[1] * s), b[2] * s, col)
		for b in bl: draw_circle(Vector2(x + (b[0] + 5) * s, y + (b[1] + 6) * s), b[2] * 0.75 * s, col.darkened(0.2))
		for b in bl: draw_circle(Vector2(x + (b[0] - 6) * s, y + (b[1] - 7) * s), b[2] * 0.35 * s, col.lightened(0.18))

	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 600), Vector2(0, 600)]),
			PackedColorArray([Color("#5ea6e0"), Color("#5ea6e0"), Color("#f6e2b0"), Color("#f6e2b0")]))
		draw_circle(Vector2(1010, 140), 90, Color(1, 0.96, 0.7, 0.25))
		draw_circle(Vector2(1010, 140), 50, Color("#fff4c4"))
		_cloud(Vector2(240, 110), 1.1)
		_cloud(Vector2(700, 70), 0.8)
		_cloud(Vector2(1180, 230), 0.7)
		var far := Vec.S([-80, 760, -80, 360, 120, 300, 260, 370, 430, 250, 600, 360, 760, 290, 930, 380, 1100, 280, 1360, 360, 1360, 760], 6)
		Vec.fill(self, far, Color("#9bb2cf"))
		Vec.outline(self, far, Color("#7189ab"), 3.0)
		for p in [[430, 250], [1100, 280], [120, 300]]:
			Vec.fill(self, Vec.R([p[0] - 34, p[1] + 34, p[0], p[1] + 2, p[0] + 34, p[1] + 34, p[0] + 14, p[1] + 26, p[0], p[1] + 40, p[0] - 16, p[1] + 26]), Color("#eef3fa"))
		var hills := Vec.S([-80, 760, -80, 450, 150, 410, 360, 460, 560, 420, 780, 470, 1000, 415, 1360, 460, 1360, 760], 6)
		Vec.paint(self, hills, Color("#86b86a"), Vector2(0, 10), 3.0)
		for tr in [[70, 470, 0.9], [560, 455, 0.75], [640, 470, 0.95], [1180, 470, 1.0], [1050, 455, 0.7]]:
			_tree(tr[0], tr[1], tr[2], Color("#4f9a4a"))
		Vec.paint(self, Vec.R([-10, 560, 1290, 560, 1290, 730, -10, 730]), Color("#c9a46a"), Vector2.ZERO, 0.0)
		for st in [[200, 640, 26, 9], [520, 670, 34, 10], [780, 630, 22, 7], [1080, 680, 30, 9], [380, 700, 20, 6]]:
			Vec.paint(self, Vec.ellipse(Vector2(st[0], st[1]), st[2], st[3]), Color("#b48f58"), Vector2(0, 2), 2.0)
		var g := []
		for i in 34: g.append_array([-10.0 + i * 40.0, 548.0 + sin(i * 0.9) * 5.0])
		for i in range(33, -1, -1):
			var x := -10.0 + i * 40.0
			g.append_array([x + 30.0, 582.0 + (i % 3) * 4.0, x + 20.0, 598.0 + (i % 2) * 6.0, x + 10.0, 582.0])
		Vec.paint(self, Vec.R(g), Color("#6db152"), Vector2(0, 6), 3.0)
		for rk in [[90, 650, 30], [1210, 640, 38], [690, 700, 24]]:
			Vec.paint(self, Vec.S([rk[0] - rk[2], rk[1], rk[0] - rk[2] * 0.6, rk[1] - rk[2] * 0.8, rk[0] + rk[2] * 0.4, rk[1] - rk[2] * 0.9,
				rk[0] + rk[2], rk[1] - rk[2] * 0.2, rk[0] + rk[2] * 0.8, rk[1] + rk[2] * 0.2, rk[0] - rk[2] * 0.7, rk[1] + rk[2] * 0.25], 4),
				Color("#9a9aa6"), Vector2(5, 6), 3.0)


func _ready() -> void:
	var bg := Bg.new()
	bg.z_as_relative = false
	bg.z_index = -100
	add_child(bg)
	for sh in [[360, 150], [190, 70], [930, 190]]:
		Vec.part(self, Vector2(sh[0], GROUND + 2), -90).add(Vec.ellipse(Vector2.ZERO, sh[1] * 0.42, 11), Color(0, 0, 0, 0.22), Vector2.ZERO, 0.0)
	dragon = DfActors.Dragon.new()
	dragon.position = Vector2(190, 400)
	dragon.home = dragon.position
	dragon.scale = Vector2(1.15, 1.15)
	add_child(dragon)
	hero = DfActors.Hero.new()
	hero.position = Vector2(360, GROUND)
	hero.scale = Vector2(1.3, 1.3)
	add_child(hero)
	shroom = DfActors.Shroom.new()
	shroom.position = Vector2(930, GROUND)
	shroom.scale = Vector2(-1.45, 1.45)
	add_child(shroom)
	hero.swung.connect(_on_swing)
	_ui()
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): dir = a.split("=", true, 1)[1]
	if dir != "": _shots(dir)


func _panel(pos: Vector2, w: float) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := UIKit.flat(Color("#2d1f2b"), Color("#e0aa48"), 3, 12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.custom_minimum_size = Vector2(w, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	$UI.add_child(p)
	return v


func _bar(col: Color, val: float, txt: String) -> ProgressBar:
	var b := UIKit.bar(col, 260, 20)
	b.add_theme_stylebox_override("background", UIKit.flat(Color("#120b10"), Vec.OUT, 2, 6))
	b.add_theme_stylebox_override("fill", UIKit.flat(col, Color(0, 0, 0, 0), 0, 6))
	b.value = val
	var l := UIKit.label(txt, 14)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Vec.OUT)
	b.add_child(l)
	return b


func _ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var v := _panel(Vector2(20, 16), 300)
	v.add_child(UIKit.label("ฮีโร่  Lv 12", 20, UIKit.GOLD, true))
	v.add_child(_bar(Color("#d8433a"), 82, "HP 164 / 200"))
	v.add_child(_bar(Color("#3f7fd8"), 60, "MP 54 / 90"))
	var e := _panel(Vector2(940, 16), 300)
	e.add_child(UIKit.label("เห็ดพิโรธ  Lv 10", 20, Color("#ff9a7a"), true))
	ebar = _bar(Color("#d8433a"), 100, "HP 140 / 140")
	e.add_child(ebar)
	var bp := PanelContainer.new()
	var sb := UIKit.flat(Color(0.12, 0.07, 0.1, 0.85), Color("#e0aa48"), 3, 14)
	sb.set_content_margin_all(10)
	bp.add_theme_stylebox_override("panel", sb)
	bp.position = Vector2(250, 640)
	var h := UIKit.hbox(10)
	bp.add_child(h)
	ui.add_child(bp)
	for b in [["โจมตี", _attack], ["มังกรพ่นไฟ", _breath], ["สกิล", _soon], ["ไอเทม", _soon], ["หนี", _soon]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(140, 46)
		btn.add_theme_font_override("font", UIKit.font_bold())
		btn.add_theme_font_size_override("font_size", 20)
		var n := UIKit.flat(Color("#7a3b22"), Color("#f0c060"), 3, 10)
		n.shadow_color = Color(0, 0, 0, 0.4)
		n.shadow_size = 3
		var hv := UIKit.flat(Color("#a8522c"), Color("#ffe08a"), 3, 10)
		btn.add_theme_stylebox_override("normal", n)
		btn.add_theme_stylebox_override("hover", hv)
		btn.add_theme_stylebox_override("pressed", UIKit.flat(Color("#5a2a18"), Color("#f0c060"), 3, 10))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color("#fff2d6"))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_constant_override("outline_size", 4)
		btn.add_theme_color_override("font_outline_color", Vec.OUT)
		btn.pressed.connect(b[1])
		h.add_child(btn)


func _attack() -> void:
	if busy: return
	busy = true
	await hero.attack(400)
	busy = false


func _on_swing() -> void:
	var fx := Vec.part(self, shroom.position + Vector2(-30, -110), 80)
	var arc := PackedVector2Array()
	for i in 21: arc.append(Vector2.from_angle(lerpf(-2.3, 0.7, i / 20.0)) * 90.0)
	for i in range(20, -1, -1):
		var a := lerpf(-2.3, 0.7, i / 20.0)
		arc.append(Vector2.from_angle(a) * (90.0 - 26.0 * sin((i / 20.0) * PI)) + Vector2(10, 6))
	fx.add(arc, Color(1, 1, 1, 0.95), Vector2.ZERO, 0.0)
	fx.stroke(arc.slice(0, 21), Color("#9fdcff"), 4.0)
	fx.scale = Vector2(0.7, 0.7)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(1.15, 1.15), 0.25)
	tw.tween_property(fx, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(fx.queue_free)
	_damage(randi_range(28, 36))


func _breath() -> void:
	if busy: return
	busy = true
	await dragon.rear_up()
	var from := dragon.mouth()
	var to := shroom.position + Vector2(0, -90)
	for i in 14:
		var f := Vec.part(self, from, 70)
		var r := randf_range(22, 32)
		var blob := []
		for k in 8:
			var rr := r * randf_range(0.75, 1.15)
			blob.append_array([cos(k * TAU / 8) * rr, sin(k * TAU / 8) * rr])
		f.add(Vec.S(blob, 4), Color("#ff8a2a"), Vector2(3, 4), 2.5)
		f.add(Vec.ellipse(Vector2(-2, -2), r * 0.45, r * 0.4, 16), Color("#ffe066"), Vector2.ZERO, 0.0)
		f.scale = Vector2(0.4, 0.4)
		var tw := f.create_tween().set_parallel(true)
		tw.tween_property(f, "position", to + Vector2(randf_range(-40, 40), randf_range(-40, 40)), 0.45).set_delay(i * 0.05)
		tw.tween_property(f, "scale", Vector2(2.0, 2.0), 0.45).set_delay(i * 0.05)
		tw.tween_property(f, "rotation", randf_range(-2, 2), 0.45).set_delay(i * 0.05)
		tw.tween_property(f, "modulate:a", 0.0, 0.2).set_delay(0.3 + i * 0.05)
		tw.chain().tween_callback(f.queue_free)
	await get_tree().create_timer(0.5).timeout
	_damage(randi_range(40, 52), Color("#ffb347"))
	await dragon.settle()
	busy = false


func _soon() -> void:
	_float_text("ต้นแบบ: ยังไม่ได้ทำ", hero.position + Vector2(0, -260), Color.WHITE, 24)


func _damage(n: int, col := Color("#ffe25a")) -> void:
	shroom.hit()
	ehp = maxf(ehp - n, 0.0)
	if ehp <= 0.0: ehp = ehp_max
	ebar.value = ehp / ehp_max * 100.0
	(ebar.get_child(0) as Label).text = "HP %d / %d" % [ehp, ehp_max]
	_float_text(str(n), shroom.position + Vector2(-20, -200), col, 52)


func _float_text(s: String, pos: Vector2, col: Color, size: int) -> void:
	var l := UIKit.label(s, size, col, true)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Vec.OUT)
	l.position = pos
	l.z_as_relative = false
	l.z_index = 90
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 60, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


func _shots(dir: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await Autotest._snap(self, dir, "df_01_idle")
	_attack()
	await get_tree().create_timer(0.30).timeout
	await Autotest._snap(self, dir, "df_02_windup")
	await get_tree().create_timer(0.12).timeout
	await Autotest._snap(self, dir, "df_03_slash")
	await get_tree().create_timer(1.2).timeout
	_breath()
	await get_tree().create_timer(0.62).timeout
	await Autotest._snap(self, dir, "df_04_breath")
	get_tree().quit()
