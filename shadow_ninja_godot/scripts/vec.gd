class_name Vec
## Hand-drawn vector style helpers: flat colour + cel shade + highlight + thick dark outline, drawn with _draw().

const OUT := Color("#24161e")

## Catmull-Rom point
static func cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)

static func pts(flat: Array) -> Array:
	var o := []
	for i in range(0, flat.size(), 2): o.append(Vector2(flat[i], flat[i + 1]))
	return o

## Raw (sharp-cornered) polygon from a flat [x, y, x, y ...] list
static func R(flat: Array) -> PackedVector2Array:
	return PackedVector2Array(pts(flat))

## Smooth closed shape through a flat [x, y ...] list
static func S(flat: Array, seg := 5) -> PackedVector2Array:
	return smooth(pts(flat), seg)

static func smooth(p: Array, seg := 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := p.size()
	for i in n:
		for s in seg:
			out.append(cr(p[(i - 1 + n) % n], p[i], p[(i + 1) % n], p[(i + 2) % n], float(s) / seg))
	return out

static func ellipse(c: Vector2, rx: float, ry: float, n := 30) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		o.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return o

## Rounded limb from a to b with end radii ra/rb
static func capsule(a: Vector2, b: Vector2, ra: float, rb: float, n := 10) -> PackedVector2Array:
	var ang := (b - a).angle()
	var o := PackedVector2Array()
	for i in n + 1: o.append(a + Vector2.from_angle(ang + PI * 0.5 + PI * float(i) / n) * ra)
	for i in n + 1: o.append(b + Vector2.from_angle(ang - PI * 0.5 + PI * float(i) / n) * rb)
	return o

## Tapered tube along a smoothed spine (tails, necks)
static func taper(flat: Array, r0: float, r1: float, seg := 5) -> PackedVector2Array:
	var sp := pts(flat)
	var n := sp.size()
	var line := PackedVector2Array()
	for i in n - 1:
		for s in seg:
			line.append(cr(sp[maxi(i - 1, 0)], sp[i], sp[i + 1], sp[mini(i + 2, n - 1)], float(s) / seg))
	line.append(sp[n - 1])
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var m := line.size()
	for i in m:
		var nrm := (line[mini(i + 1, m - 1)] - line[maxi(i - 1, 0)]).normalized().orthogonal()
		var r := lerpf(r0, r1, float(i) / (m - 1))
		left.append(line[i] + nrm * r)
		right.append(line[i] - nrm * r)
	right.reverse()
	left.append_array(right)
	return left

static func shifted(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p: o.append(v + d)
	return o

static func fill(ci: CanvasItem, p: PackedVector2Array, col: Color) -> void:
	if p.size() >= 3 and Geometry2D.triangulate_polygon(p).size() > 0:
		ci.draw_colored_polygon(p, col)

static func outline(ci: CanvasItem, p: PackedVector2Array, col: Color, w: float) -> void:
	var o := p.duplicate()
	o.append(p[0])
	ci.draw_polyline(o, col, w, true)

## Fill + shade crescent (light from upper-left) + rim highlight + outline
static func paint(ci: CanvasItem, p: PackedVector2Array, col: Color, shade := Vector2(4, 5), w := 3.0) -> void:
	fill(ci, p, col)
	if shade != Vector2.ZERO:
		for part in Geometry2D.clip_polygons(p, shifted(p, -shade)): fill(ci, part, col.darkened(0.24))
		for part in Geometry2D.clip_polygons(p, shifted(p, shade * 0.45)): fill(ci, part, col.lightened(0.2))
	if w > 0.0: outline(ci, p, OUT, w)

## A rigid cut-out piece; rotate/move the node to animate
class Part extends Node2D:
	var layers: Array = []

	func add(p: PackedVector2Array, col: Color, shade := Vector2(4, 5), w := 3.0) -> Part:
		layers.append([0, p, col, shade, w])
		queue_redraw()
		return self

	func stroke(p: PackedVector2Array, col := Color("#24161e"), w := 3.0) -> Part:
		layers.append([1, p, col, Vector2.ZERO, w])
		queue_redraw()
		return self

	func dot(c: Vector2, r: float, col: Color) -> Part:
		layers.append([2, c, col, Vector2.ZERO, r])
		queue_redraw()
		return self

	func _draw() -> void:
		for L in layers:
			match L[0]:
				0: Vec.paint(self, L[1], L[2], L[3], L[4])
				1: draw_polyline(L[1], L[2], L[4], true)
				2: draw_circle(L[1], L[4], L[2])

static func part(parent: Node, pos := Vector2.ZERO, z := 0) -> Part:
	var p := Part.new()
	p.position = pos
	p.z_as_relative = false
	p.z_index = z
	parent.add_child(p)
	return p
