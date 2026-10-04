class_name DfActors
## Cut-out vector rigs (hero, pet dragon, mushroom monster) for the hand-drawn style prototype.

const W := Color.WHITE

class Hero extends Node2D:
	signal swung
	const SKIN := Color("#f2c29a")
	const HAIR := Color("#7a4520")
	const TUNIC := Color("#3d6fb0")
	const PANTS := Color("#5b4b3c")
	const BOOT := Color("#6b4226")
	const LEATHER := Color("#8a5a32")
	const STEEL := Color("#cdd6e1")
	const GOLDC := Color("#e8b33a")
	const RED := Color("#c8362e")
	const ZB := 20

	var hip: Node2D
	var torso: Vec.Part
	var head: Vec.Part
	var cape: Vec.Part
	var arm_f: Vec.Part
	var fore_f: Vec.Part
	var sword: Vec.Part
	var arm_b: Vec.Part
	var fore_b: Vec.Part
	var thigh_f: Vec.Part
	var shin_f: Vec.Part
	var thigh_b: Vec.Part
	var shin_b: Vec.Part
	var base := {"arm_f": -0.35, "fore_f": -1.2, "sword": 2.15, "arm_b": 0.6, "fore_b": -0.35,
		"thigh_f": -0.35, "shin_f": 0.3, "thigh_b": 0.3, "shin_b": -0.08}
	var t := 0.0
	var acting := false

	func _init() -> void:
		hip = Node2D.new()
		hip.position = Vector2(0, -82)
		add_child(hip)
		var lb := _leg(Vector2(-7, -2), ZB - 3, true)
		thigh_b = lb[0]
		shin_b = lb[1]
		var lf := _leg(Vector2(6, -2), ZB - 1, false)
		thigh_f = lf[0]
		shin_f = lf[1]
		torso = Vec.part(hip, Vector2.ZERO, ZB)
		torso.add(Vec.capsule(Vector2(4, -58), Vector2(5, -76), 8, 8), SKIN)
		torso.add(Vec.S([-22, -6, 22, -6, 28, 20, 10, 25, -8, 25, -28, 20], 4), TUNIC.darkened(0.12))
		torso.add(Vec.S([-20, 2, 19, 2, 23, -28, 19, -56, 2, -64, -16, -62, -25, -34], 4), TUNIC, Vector2(5, 4))
		torso.add(Vec.R([-14, -60, -5, -62, 20, -9, 11, -5]), LEATHER, Vector2(1, 2), 2.5)
		torso.add(Vec.S([-24, -11, 24, -11, 24, 2, -24, 2], 2), LEATHER, Vector2(1, 2), 2.5)
		torso.add(Vec.S([2, -13, 14, -13, 14, 4, 2, 4], 2), GOLDC, Vector2(1, 2), 2.5)
		cape = Vec.part(torso, Vector2(-10, -60), ZB - 6)
		cape.add(Vec.S([2, -6, 6, 8, -18, 30, -50, 46, -60, 36, -36, 20, -14, 4]), RED.darkened(0.15))
		var scarf := Vec.part(torso, Vector2.ZERO, ZB + 1)
		scarf.add(Vec.S([-17, -64, 4, -71, 19, -65, 17, -53, -2, -56, -17, -51], 4), RED, Vector2(2, 3))
		head = Vec.part(torso, Vector2(4, -68), ZB + 2)
		_head()
		var ab := _arm(Vector2(-9, -54), ZB - 4, true)
		arm_b = ab[0]
		fore_b = ab[1]
		var shield := Vec.part(ab[2], Vector2(4, 0), ZB - 2)
		shield.add(Vec.ellipse(Vector2.ZERO, 23, 25), STEEL, Vector2(3, 4))
		shield.add(Vec.ellipse(Vector2.ZERO, 17, 19), RED.darkened(0.1), Vector2(3, 3), 2.5)
		shield.add(Vec.R([0, -11, 7, 0, 0, 11, -7, 0]), GOLDC, Vector2(1, 2), 2.0)
		var af := _arm(Vector2(6, -54), ZB + 3, false)
		arm_f = af[0]
		fore_f = af[1]
		sword = Vec.part(af[2], Vector2.ZERO, ZB + 4)
		sword.add(Vec.R([-4.5, -10, 4.5, -10, 5.5, -88, 0, -104, -5.5, -88]), STEEL, Vector2(2, 1), 2.5)
		sword.stroke(Vec.R([0, -16, 0, -86]), Color("#8796a8"), 2.0)
		sword.add(Vec.S([-16, -15, 16, -15, 16, -7, -16, -7], 2), GOLDC, Vector2(1, 2), 2.5)
		sword.add(Vec.capsule(Vector2(0, -8), Vector2(0, 11), 3.5, 3.5), LEATHER, Vector2.ZERO, 2.0)
		sword.add(Vec.ellipse(Vector2(0, 15), 5, 5, 16), GOLDC, Vector2(1, 1), 2.0)
		_pose(base)

	func _head() -> void:
		head.add(Vec.S([-20, -10, -22, -34, -8, -54, 14, -54, 28, -40, 30, -24, 28, -14, 22, -4, 10, 0, -8, -2]), SKIN, Vector2(5, 4))
		head.add(Vec.R([-26, -6, -30, -22, -45, -27, -32, -37, -41, -55, -20, -53, -16, -74, 0, -61, 15, -73, 20, -57,
			39, -55, 30, -45, 35, -33, 22, -39, 16, -31, 10, -40, 0, -36, -8, -27, -12, -12]), HAIR, Vector2(4, 5))
		head.add(Vec.ellipse(Vector2(-7, -22), 5, 7, 16), SKIN, Vector2(1, 2), 2.5)
		head.add(Vec.ellipse(Vector2(16, -26), 5.5, 7.5, 20), W, Vector2.ZERO, 2.5)
		head.dot(Vector2(18, -25), 3.4, Color("#3a2a5a"))
		head.dot(Vector2(19, -27), 1.3, W)
		head.stroke(Vec.R([9, -37, 22, -38]), Vec.OUT, 4.0)
		head.stroke(Vec.R([29, -23, 32, -18, 28, -17]), Vec.OUT, 2.0)
		head.stroke(Vec.R([17, -10, 24, -11]), Vec.OUT, 2.5)

	func _leg(pos: Vector2, z: int, back: bool) -> Array:
		var d := 0.22 if back else 0.0
		var th := Vec.part(hip, pos, z)
		th.add(Vec.capsule(Vector2.ZERO, Vector2(0, 40), 12, 10), PANTS.darkened(d))
		var sh := Vec.part(th, Vector2(0, 40), z)
		sh.add(Vec.capsule(Vector2.ZERO, Vector2(0, 34), 10, 9), BOOT.darkened(d))
		sh.add(Vec.S([-11, 27, 4, 27, 20, 35, 21, 44, -11, 44], 3), BOOT.darkened(d), Vector2(2, 3))
		sh.add(Vec.S([-13, 2, 13, 2, 14, 12, -14, 12], 2), LEATHER.darkened(d), Vector2(1, 2), 2.5)
		return [th, sh]

	func _arm(pos: Vector2, z: int, back: bool) -> Array:
		var d := 0.22 if back else 0.0
		var up := Vec.part(torso, pos, z)
		up.add(Vec.capsule(Vector2.ZERO, Vector2(0, 28), 10, 8.5), TUNIC.darkened(d))
		var fo := Vec.part(up, Vector2(0, 28), z)
		fo.add(Vec.capsule(Vector2.ZERO, Vector2(0, 22), 8, 7), SKIN.darkened(d))
		fo.add(Vec.capsule(Vector2(0, 11), Vector2(0, 22), 9.5, 9), LEATHER.darkened(d), Vector2(2, 2))
		var hand := Vec.part(fo, Vector2(0, 30), z + 2)
		hand.add(Vec.ellipse(Vector2.ZERO, 8, 8, 20), SKIN.darkened(d), Vector2(2, 3))
		if not back:
			var pad := Vec.part(up, Vector2.ZERO, z + 1)
			pad.add(Vec.S([-14, -8, 0, -15, 15, -8, 16, 8, 0, 12, -13, 7], 4), STEEL)
			pad.stroke(Vec.R([-10, 2, 12, 2]), Color("#8796a8"), 2.0)
		return [up, fo, hand]

	func _pose(p: Dictionary) -> void:
		arm_f.rotation = p.arm_f
		fore_f.rotation = p.fore_f
		sword.rotation = p.sword
		arm_b.rotation = p.arm_b
		fore_b.rotation = p.fore_b
		thigh_f.rotation = p.thigh_f
		shin_f.rotation = p.shin_f
		thigh_b.rotation = p.thigh_b
		shin_b.rotation = p.shin_b

	func _process(delta: float) -> void:
		t += delta
		cape.rotation = sin(t * 3.4) * 0.1
		if acting: return
		var s := sin(t * 2.6)
		hip.position.y = -82 + s * 1.6
		arm_f.rotation = base.arm_f + s * 0.05
		arm_b.rotation = base.arm_b - s * 0.05
		head.rotation = s * 0.02

	func _to(tw: Tween, node: Node, val: float, d: float) -> void:
		tw.tween_property(node, "rotation", val, d)

	## Lunge dx pixels, wind up overhead, slash down, return
	func attack(dx: float) -> void:
		acting = true
		var home := position.x
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position:x", home + dx, 0.32)
		_to(tw, arm_f, -2.7, 0.32)
		_to(tw, fore_f, -0.5, 0.32)
		_to(tw, sword, 0.6, 0.32)
		_to(tw, torso, -0.08, 0.32)
		_to(tw, thigh_f, -0.75, 0.32)
		_to(tw, shin_f, 0.55, 0.32)
		_to(tw, thigh_b, 0.5, 0.32)
		await tw.finished
		var tw2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_to(tw2, arm_f, -0.2, 0.11)
		_to(tw2, fore_f, -0.3, 0.11)
		_to(tw2, sword, 2.4, 0.11)
		_to(tw2, torso, 0.14, 0.11)
		await tw2.finished
		swung.emit()
		await get_tree().create_timer(0.28).timeout
		var tw3 := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		tw3.tween_property(self, "position:x", home, 0.35)
		for k in base: _to(tw3, get(k), base[k], 0.35)
		_to(tw3, torso, 0.0, 0.35)
		await tw3.finished
		acting = false


class Dragon extends Node2D:
	const SC := Color("#3aa57a")
	const BELLY := Color("#f0d27a")
	const WING := Color("#63c8a0")
	const HORN := Color("#f3e9cf")
	var body: Vec.Part
	var neck: Vec.Part
	var head: Vec.Part
	var wing_f: Vec.Part
	var wing_b: Vec.Part
	var tail: Vec.Part
	var home := Vector2.ZERO
	var t := 0.0
	var acting := false

	func _init() -> void:
		tail = Vec.part(self, Vector2(-24, 6), -1)
		tail.add(Vec.taper([0, 0, -22, 8, -44, 4, -60, -10, -70, -26], 12, 3), SC)
		tail.add(Vec.R([-66, -22, -88, -26, -80, -46, -72, -32]), SC.darkened(0.15), Vector2(1, 2), 2.5)
		wing_b = Vec.part(self, Vector2(-2, -16), -2)
		_wing(wing_b, 0.25)
		var lb := Vec.part(self, Vector2(-14, 14), -1)
		lb.add(Vec.capsule(Vector2.ZERO, Vector2(2, 16), 8, 6), SC.darkened(0.2))
		lb.add(Vec.ellipse(Vector2(5, 19), 8, 5, 16), SC.darkened(0.2), Vector2(1, 1), 2.5)
		body = Vec.part(self, Vector2.ZERO, 0)
		for sx in [-22, -10, 2]: body.add(Vec.R([sx - 6, -18, sx, -30, sx + 6, -20]), HORN, Vector2(1, 1), 2.5)
		body.add(Vec.ellipse(Vector2.ZERO, 32, 23), SC, Vector2(5, 6))
		body.add(Vec.S([-14, 10, 4, 4, 22, -4, 27, 6, 10, 20, -10, 20], 4), BELLY, Vector2(2, 3), 2.5)
		for bx in [-2, 8, 17]: body.stroke(Vec.R([bx, 5 - bx * 0.3, bx + 4, 18 - bx * 0.2]), BELLY.darkened(0.3), 2.0)
		var lf := Vec.part(self, Vector2(14, 14), 1)
		lf.add(Vec.capsule(Vector2.ZERO, Vector2(3, 16), 8, 6), SC)
		lf.add(Vec.ellipse(Vector2(6, 19), 8, 5, 16), SC, Vector2(1, 1), 2.5)
		neck = Vec.part(self, Vector2(20, -10), 1)
		neck.add(Vec.taper([0, 8, 8, -10, 11, -26, 16, -36], 13, 9), SC, Vector2(3, 3))
		head = Vec.part(neck, Vector2(16, -38), 2)
		head.add(Vec.R([-8, -8, -28, -24, -24, -29, -2, -15]), HORN.darkened(0.15), Vector2(1, 2), 2.5)
		head.add(Vec.S([-14, 0, -12, -12, 2, -17, 18, -12, 34, -8, 39, -1, 31, 7, 10, 9, -6, 8]), SC, Vector2(4, 4))
		head.add(Vec.R([-4, -12, -20, -32, -15, -34, 4, -15]), HORN, Vector2(1, 2), 2.5)
		head.add(Vec.ellipse(Vector2(8, -5), 5.5, 6.5, 18), W, Vector2.ZERO, 2.5)
		head.add(Vec.ellipse(Vector2(9.5, -4.5), 2.2, 4.5, 14), Color("#c03a1a"), Vector2.ZERO, 0.0)
		head.dot(Vector2(10, -6.5), 1.2, W)
		head.stroke(Vec.R([1, -12, 15, -11]), Vec.OUT, 3.5)
		head.dot(Vector2(34, -3), 1.7, Vec.OUT)
		head.stroke(Vec.R([37, 3, 22, 4, 16, 1]), Vec.OUT, 2.5)
		wing_f = Vec.part(self, Vector2(4, -18), 3)
		_wing(wing_f, 0.0)

	func _wing(p: Vec.Part, d: float) -> void:
		p.add(Vec.R([0, 0, -4, -34, -12, -50, -26, -44, -40, -48, -46, -32, -60, -30, -58, -16, -36, -10, -16, -2]), WING.darkened(d), Vector2(3, 4))
		var bone := SC.darkened(d + 0.2)
		p.stroke(Vec.R([0, 0, -4, -34, -12, -50]), bone, 4.0)
		p.stroke(Vec.R([-4, -34, -40, -48]), bone, 2.5)
		p.stroke(Vec.R([-4, -34, -60, -30]), bone, 2.5)

	func _process(delta: float) -> void:
		t += delta
		position.y = home.y + sin(t * 3.0) * 6.0
		wing_f.rotation = sin(t * 6.0) * 0.35
		wing_b.rotation = sin(t * 6.0 + 0.4) * 0.3
		tail.rotation = sin(t * 2.0) * 0.08
		if not acting: neck.rotation = sin(t * 3.0) * 0.04

	func mouth() -> Vector2:
		return head.to_global(Vector2(40, 2))

	func rear_up() -> void:
		acting = true
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(neck, "rotation", -0.35, 0.25)
		tw.tween_property(neck, "rotation", 0.25, 0.12)
		await tw.finished

	func settle() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(neck, "rotation", 0.0, 0.3)
		await tw.finished
		acting = false


class Shroom extends Node2D:
	const CAP := Color("#d4473d")
	const STEM := Color("#f1e3c4")
	const ZB := 40
	var body: Vec.Part
	var t := 0.0

	func _init() -> void:
		var fb := Vec.part(self, Vector2(-16, -6), ZB - 2)
		fb.add(Vec.ellipse(Vector2.ZERO, 15, 8, 20), STEM.darkened(0.2), Vector2(2, 2))
		var ab := Vec.part(self, Vector2(-28, -38), ZB - 1)
		ab.add(Vec.capsule(Vector2.ZERO, Vector2(-14, 14), 7, 6), STEM.darkened(0.2))
		body = Vec.part(self, Vector2.ZERO, ZB)
		body.add(Vec.S([-28, -6, 28, -6, 34, -34, 26, -70, -26, -70, -34, -34], 4), STEM, Vector2(6, 4))
		body.add(Vec.ellipse(Vector2(0, -66), 44, 8, 26), Color("#b99a72"), Vector2.ZERO, 2.5)
		body.add(Vec.ellipse(Vector2(1, -46), 6, 8, 18), W, Vector2.ZERO, 2.5)
		body.add(Vec.ellipse(Vector2(18, -46), 5.5, 7.5, 18), W, Vector2.ZERO, 2.5)
		body.dot(Vector2(3, -44), 3.2, Vec.OUT)
		body.dot(Vector2(19.5, -44), 3.0, Vec.OUT)
		body.stroke(Vec.R([-6, -57, 8, -52]), Vec.OUT, 4.0)
		body.stroke(Vec.R([13, -52, 25, -57]), Vec.OUT, 4.0)
		body.add(Vec.R([-1, -30, 21, -30, 17, -19, 3, -19]), Color("#5a1a1a"), Vector2.ZERO, 2.5)
		body.add(Vec.R([2, -30, 6, -30, 4, -25]), W, Vector2.ZERO, 0.0)
		body.add(Vec.R([14, -30, 18, -30, 16, -25]), W, Vector2.ZERO, 0.0)
		var ff := Vec.part(self, Vector2(16, -6), ZB + 1)
		ff.add(Vec.ellipse(Vector2.ZERO, 15, 8, 20), STEM.darkened(0.08), Vector2(2, 2))
		var af := Vec.part(body, Vector2(30, -36), ZB + 1)
		af.add(Vec.capsule(Vector2.ZERO, Vector2(14, 12), 7, 6), STEM, Vector2(2, 2))
		var cap := Vec.part(body, Vector2(0, -68), ZB + 2)
		cap.add(Vec.S([-62, 6, -54, -30, -22, -54, 20, -54, 54, -30, 62, 6, 30, 12, 0, 14, -30, 12]), CAP, Vector2(7, 9))
		cap.add(Vec.ellipse(Vector2(-30, -20), 10, 8, 20), W, Vector2(0, 2), 2.5)
		cap.add(Vec.ellipse(Vector2(8, -38), 12, 7, 20), W, Vector2(0, 2), 2.5)
		cap.add(Vec.ellipse(Vector2(36, -12), 8, 7, 20), W, Vector2(0, 2), 2.5)
		cap.add(Vec.ellipse(Vector2(-4, -8), 6, 5, 16), W, Vector2(0, 2), 2.5)

	func _process(delta: float) -> void:
		t += delta
		var s := sin(t * 3.2)
		body.scale = Vector2(1.0 + s * 0.035, 1.0 - s * 0.035)

	func hit() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(2.4, 2.4, 2.4), 0.05)
		tw.tween_property(self, "modulate", Color.WHITE, 0.18)
		var x := position.x
		var tw2 := create_tween()
		for i in 4: tw2.tween_property(self, "position:x", x + (10 if i % 2 == 0 else -10), 0.04)
		tw2.tween_property(self, "position:x", x, 0.04)
