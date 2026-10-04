extends Node2D
## Overworld: tile ground + y-sorted objects, WASD movement, roaming enemies, NPCs, chests, exits.

signal battle_requested(stage: int, src)
signal boss_touched(stage: int)
signal npc_interact(id: String)
signal toast(msg: String, color: Color)
signal map_changed(map_id: String)

const TS := 16
const VILLAGE_ROWS := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TT......,...........................,.TT",
	"T..........,...........................T",
	"T......................,...............T",
	"T.....,...............................,T",
	"T......................................T",
	"T..,...................................T",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T....=........=........=........=......T",
	"T=======================================",
	"T=======================================",
	"T....,.............=...................T",
	"T..................=...........,.......T",
	"T..................=...................T",
	"T......BBBBB.......=...................T",
	"T......B...B.......=...................T",
	"T......B...B.......=...................T",
	"T......BB.BB.......=...........,.......T",
	"T........=.........=...................T",
	"T........===========...................T",
	"T...,..................................T",
	"TT...........................,.......TTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]
# [object, tile x, tile y] placed by hand in the village
const VILLAGE_OBJ := [
	["house_red", 3, 8], ["house_tan", 12, 8], ["house_3", 21, 8], ["house_brick", 30, 8],
	["torii", 18, 3], ["sakura", 6, 2], ["sakura", 27, 2], ["tree_big", 34, 4], ["tree_autumn", 25, 16], ["sakura", 33, 18],
	["dojo", 8, 16],
]
const VILLAGE_NPCS := [
	{"id": "merchant", "name": "พ่อค้า โทคิจิ", "actor": "OldMan2", "x": 5, "y": 11},
	{"id": "smith", "name": "ช่างตีดาบ กันเท็ตสึ", "actor": "Hunter", "x": 14, "y": 11},
	{"id": "inn", "name": "โรงเตี๊ยม โอฮานะ", "actor": "Woman", "x": 23, "y": 11},
	{"id": "elder", "name": "ผู้ใหญ่บ้าน ฮิโรชิ", "actor": "OldMan3", "x": 32, "y": 11},
	{"id": "master", "name": "อาจารย์นินจา ไรเดน", "actor": "Master", "x": 9, "y": 19},
	{"id": "board", "name": "กระดานค่าหัว", "actor": "", "x": 21, "y": 15},
]
const VILLAGE_WARP := Vector2i(15, 14)   # top-left tile of the 2x2 shrine
const VILLAGE_CHESTS := [
	{"id": "v1", "x": 36, "y": 22, "loot": {"gold": 40, "items": {"potion": 1}}},
	{"id": "v2", "x": 2, "y": 2, "loot": {"items": {"ether": 1, "smoke": 1}}},
]

var map_id := ""
var theme := "village"
var W := 0
var H := 0
var path := []      # [y][x] bool
var solid := []     # [y][x] bool
var spawn_tiles := []
var exits := []     # {x, y, to, kind}
var npcs := []      # {id, name, pos, node}
var chests := []    # {id, pos, loot, node}
var enemies := []   # {stage, node, spr, alive, respawn, t, v, chase}
var boss = null     # {stage, pos, node}
var gen_cache := {}

var ground: TileMapLayer
var ysort: Node2D
var overlay: Node2D
var player: Node2D
var pspr: AnimatedSprite2D
var cam: Camera2D
var font: Font

var paused := false
var inv := 0.0
var gate_t := 0.0
var regen_t := 0.0
var face := "down"
var near = null   # nearest interactable dict
var no_trees := {}  # solid cells that must not get a theme tree (warp shrines)
var night: CanvasModulate
var glow_tex: GradientTexture2D
const TORII_GATE := Vector2i(19, 4)   # village tile under the north torii -> Halloween graveyard
const HALLOWEEN_VILLAGE := [[4, 11], [13, 11], [22, 11], [31, 11], [24, 11], [17, 5], [21, 5], [11, 23], [35, 15], [26, 23], [7, 6], [29, 6]]

func _ready() -> void:
	font = UIKit.font_world()
	ground = TileMapLayer.new()
	ground.tile_set = _make_tileset()
	add_child(ground)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	overlay = Node2D.new()
	overlay.z_index = 50
	add_child(overlay)
	night = CanvasModulate.new()
	night.visible = false
	add_child(night)
	glow_tex = GradientTexture2D.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 0.65, 0.25, 0.9))
	gg.set_color(1, Color(1, 0.4, 0.1, 0.0))
	glow_tex.gradient = gg
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 64
	glow_tex.height = 64
	cam = Camera2D.new()
	cam.zoom = Vector2(3, 3)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 10.0
	add_child(cam)

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TS, TS)
	var src := TileSetAtlasSource.new()
	src.texture = G.tex("tiles/TilesetFloor.png")
	src.texture_region_size = Vector2i(TS, TS)
	for y in 26:
		for x in 22:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	return ts

# ================= loading =================
func load_map(id: String) -> void:
	map_id = id
	var m: Dictionary = G.MAPS[id]
	theme = m.theme
	for c in ysort.get_children(): c.queue_free()
	for c in overlay.get_children(): c.queue_free()
	ground.clear()
	npcs = []; chests = []; enemies = []; exits = []; spawn_tiles = []; no_trees = {}
	boss = null
	if id == "village": _build_village()
	else: _build_generated(id)
	var hw := G.halloween()
	night.visible = hw
	night.color = Color(0.5, 0.42, 0.66) if id == "graveyard" else Color(0.64, 0.56, 0.8)
	_paint_ground()
	_place_solid_objects()
	_spawn_player()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W * TS
	cam.limit_bottom = H * TS
	cam.position = player.position
	cam.reset_smoothing()
	for e in exits: _add_exit_marker(e)
	map_changed.emit(id)

func _grid(v) -> Array:
	var a := []
	for y in H:
		var r := []
		r.resize(W)
		r.fill(v)
		a.append(r)
	return a

func _build_village() -> void:
	W = 40; H = 26
	path = _grid(false); solid = _grid(false)
	for y in H:
		var row: String = VILLAGE_ROWS[y]
		for x in W:
			var ch := row[x]
			if ch == "=": path[y][x] = true
			elif ch == "T" or ch == "B": solid[y][x] = true
			elif ch == ",": _add_obj(["flower1", "flower2", "grass1"][G.rng.randi() % 3], x, y, false)
	for o in VILLAGE_OBJ: _add_obj(o[0], o[1], o[2], true)
	for n in VILLAGE_NPCS: _add_npc(n)
	for c in VILLAGE_CHESTS: _add_chest(c.id, Vector2i(c.x, c.y), c.loot)
	_add_warp("village", VILLAGE_WARP)
	exits.append({"x": 39, "y": 12, "to": "forest", "kind": "next"})
	exits.append({"x": 39, "y": 13, "to": "forest", "kind": "next"})
	if G.halloween():
		exits.append({"x": TORII_GATE.x, "y": TORII_GATE.y, "to": "graveyard", "kind": "next"})
		for p in HALLOWEEN_VILLAGE: _pumpkin(p[0], p[1])
		_add_npc({"id": "vampire", "name": "เคานต์ดราคุ (อีเวนต์)", "actor": "Vampire", "x": 16, "y": 6})

func _build_generated(id: String) -> void:
	var m: Dictionary = G.MAPS[id]
	var g: Dictionary = _gen(id)
	W = m.w; H = m.h
	path = []; solid = []
	for r in g.path: path.append(r.duplicate())
	for r in g.solid: solid.append(r.duplicate())
	spawn_tiles = g.spawn
	for i in g.chests.size():
		_add_chest("%s_c%d" % [id, i], g.chests[i], m.chests[i])
	exits.append({"x": 0, "y": g.entry, "to": m.prev, "kind": "prev"})
	if m.next != "": exits.append({"x": W - 1, "y": g.exit, "to": m.next, "kind": "next"})
	var decor: Array = G.THEMES[theme].decor
	if decor.size() > 0:
		var R := RandomNumberGenerator.new()
		R.seed = m.seed + 5
		for y in H:
			for x in W:
				if not solid[y][x] and not path[y][x] and R.randf() < 0.05:
					_add_obj(decor[R.randi() % decor.size()], x, y, false)
	for side in ["in", "out"]:
		var wid: String = "%s_%s" % [id, side]
		if G.warp_index(wid) < 0: continue
		var t := warp_tile(wid)
		for yy in range(t.y, t.y + 3):
			for xx in range(t.x, t.x + 2): solid[yy][xx] = false
		_add_warp(wid, t)
	# wandering merchant next to the entrance shrine (the vampire takes that spot in the event zone)
	var mt := Vector2i(7, g.entry - 2)
	for yy in [mt.y, mt.y + 1]:
		for xx in [6, 7, 8]: solid[yy][xx] = false
	if m.get("event", false): _add_npc({"id": "vampire", "name": "เคานต์ดราคุ", "actor": "Vampire", "x": mt.x, "y": mt.y})
	else: _add_npc({"id": "wander", "name": "พ่อค้าเร่ ทานุ", "actor": "MaskGoldRacoon", "x": mt.x, "y": mt.y})
	if G.halloween():
		# jack-o'-lanterns along the trail
		var PR := RandomNumberGenerator.new()
		PR.seed = m.seed + 31
		var placed := 0
		for i in 400:
			var x := PR.randi_range(2, W - 3)
			var y := PR.randi_range(2, H - 3)
			if solid[y][x] or path[y][x] or not (path[y - 1][x] or path[y + 1][x] or path[y][x - 1] or path[y][x + 1]): continue
			_pumpkin(x, y)
			placed += 1
			if placed >= 14: break
	spawn_tiles = spawn_tiles.filter(func(v: Vector2i) -> bool: return not solid[v.y][v.x])
	if not G.P.flags.has("boss%d" % m.boss):
		var bp: Vector2i = g.boss
		var node := _make_actor_node(m.boss)
		node.position = Vector2((bp.x + 0.5) * TS, (bp.y + 0.8) * TS)
		ysort.add_child(node)
		_add_label(node, "★ " + G.ENEMIES[m.boss].name, Color("#ff8f80"), -40 if G.ENEMIES[m.boss].sprite == "boss" else -22)
		boss = {"stage": m.boss, "pos": node.position, "node": node}
	for i in m.count:
		enemies.append(_spawn_enemy(m.enemies[i % m.enemies.size()]))
	# hidden slots for the rare treasure slimes
	for rs in G.RARE_SLIMES:
		var re := _spawn_enemy(rs)
		_hide_rare(re)
		enemies.append(re)
	if G.halloween() and not m.get("event", false):
		for i in 3: enemies.append(_spawn_enemy(G.EVENT_ENEMIES[(i + m.seed) % G.EVENT_ENEMIES.size()]))

## Seeded zone generator (ported from the HTML version)
func _gen(id: String) -> Dictionary:
	if gen_cache.has(id): return gen_cache[id]
	var m: Dictionary = G.MAPS[id]
	var R := RandomNumberGenerator.new()
	R.seed = m.seed
	var w: int = m.w
	var h: int = m.h
	var s := []
	var p := []
	for y in h:
		var rs := []; var rp := []
		for x in w:
			rs.append(x == 0 or y == 0 or x == w - 1 or y == h - 1)
			rp.append(false)
		s.append(rs); p.append(rp)
	var clumps: int = G.THEMES[m.theme].clumps
	for i in clumps:
		var cx := R.randi_range(1, w - 2)
		var cy := R.randi_range(1, h - 2)
		var r := 1.0 + R.randf() * 2.6
		for y in range(int(cy - r), int(cy + r) + 1):
			for x in range(int(cx - r), int(cx + r) + 1):
				if x > 0 and y > 0 and x < w - 1 and y < h - 1 and Vector2(x - cx, y - cy).length() < r and R.randf() < 0.8:
					s[y][x] = true
	var entry := R.randi_range(4, h - 5)
	var exit := R.randi_range(4, h - 5)
	var pts := [Vector2i(1, entry), Vector2i(6, entry), Vector2i(int(w * 0.3), R.randi_range(3, h - 4)), Vector2i(int(w * 0.55), R.randi_range(3, h - 4)),
		Vector2i(int(w * 0.78), R.randi_range(3, h - 4)), Vector2i(w - 10, exit), Vector2i(w - 2, exit)]
	var carve := func(x: int, y: int) -> void:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var X := x + dx
				var Y := y + dy
				if X > 0 and Y > 0 and X < w - 1 and Y < h - 1:
					s[Y][X] = false
					if (dx == 0 and dy == 0) or R.randf() < 0.3: p[Y][X] = true
	var walk_to := func(a: Vector2i, b: Vector2i) -> void:
		var x := a.x
		var y := a.y
		while x != b.x or y != b.y:
			carve.call(x, y)
			if x != b.x and (y == b.y or R.randf() < 0.6): x += signi(b.x - x)
			else: y += signi(b.y - y)
		carve.call(x, y)
	for i in pts.size() - 1: walk_to.call(pts[i], pts[i + 1])
	var ends := []
	for i in m.chests.size():
		var from: Vector2i = pts[R.randi_range(2, pts.size() - 3)]
		var to := Vector2i(R.randi_range(3, w - 4), R.randi_range(2, 5) if R.randf() < 0.5 else R.randi_range(h - 6, h - 3))
		walk_to.call(from, to)
		ends.append(to)
	s[entry][0] = false; p[entry][0] = true; p[entry][1] = true
	if m.next != "":
		s[exit][w - 1] = false; p[exit][w - 1] = true
	p[exit][w - 2] = true
	# flood fill from the entrance; unreachable ground becomes solid
	var seen := []
	for y in h:
		var r := []; r.resize(w); r.fill(false); seen.append(r)
	var q := [Vector2i(1, entry)]
	seen[entry][1] = true
	while q.size() > 0:
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and not seen[n.y][n.x] and not s[n.y][n.x]:
				seen[n.y][n.x] = true
				q.append(n)
	var spawn := []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if not s[y][x] and not seen[y][x]: s[y][x] = true
			elif seen[y][x] and x > 6 and x < w - 6: spawn.append(Vector2i(x, y))
	var res := {"solid": s, "path": p, "entry": entry, "exit": exit, "chests": ends, "spawn": spawn, "boss": Vector2i(w - 5, exit)}
	gen_cache[id] = res
	return res

# ================= painting =================
const AUTOTILE := {0: Vector2i(3, 3), 4: Vector2i(3, 0), 1: Vector2i(3, 2), 5: Vector2i(3, 1), 2: Vector2i(0, 3), 8: Vector2i(2, 3), 10: Vector2i(1, 3),
	6: Vector2i(0, 0), 12: Vector2i(2, 0), 14: Vector2i(1, 0), 7: Vector2i(0, 1), 15: Vector2i(1, 1), 13: Vector2i(2, 1),
	3: Vector2i(0, 2), 11: Vector2i(1, 2), 9: Vector2i(2, 2)}

func _is_path(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H: return false
	return path[y][x]

func _paint_ground() -> void:
	var th: Dictionary = G.THEMES[theme]
	var gl: Array = th.ground
	var base: Vector2i = th.path
	for y in H:
		for x in W:
			var c: Vector2i
			if path[y][x]:
				var mask := (1 if _is_path(x, y - 1) else 0) | (2 if _is_path(x + 1, y) else 0) | (4 if _is_path(x, y + 1) else 0) | (8 if _is_path(x - 1, y) else 0)
				c = base + AUTOTILE[mask]
			else:
				c = gl[(x * 7 + y * 13 + x * y) % gl.size()]
			ground.set_cell(Vector2i(x, y), 0, c)

func _add_obj(name: String, tx: int, ty: int, with_foot: bool) -> Node2D:
	var t: Texture2D = G.tex("obj/%s.png" % name)
	var n := Node2D.new()
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	n.add_child(s)
	var tw := int(t.get_width() / TS)
	var th := int(t.get_height() / TS)
	n.position = Vector2(tx * TS, (ty + th) * TS)
	s.position = Vector2(0, -t.get_height())
	if not with_foot:
		n.position.y -= 4   # decor sorts behind actors on the same tile
	ysort.add_child(n)
	if with_foot:
		var f: Array = G.OBJ_FOOT.get(name, [0, th - 1, tw, 1])
		for yy in range(f[1], f[1] + f[3]):
			for xx in range(f[0], f[0] + f[2]):
				var X := tx + xx
				var Y := ty + yy
				if X >= 0 and Y >= 0 and X < W and Y < H: solid[Y][X] = true
	return n

## Every solid cell without a hand-placed object gets a tree/rock from the theme pool.
func _place_solid_objects() -> void:
	var covered := _grid(false)
	# cells already covered by hand-placed footprints (village)
	if map_id == "village":
		for o in VILLAGE_OBJ:
			var t: Texture2D = G.tex("obj/%s.png" % o[0])
			var f: Array = G.OBJ_FOOT.get(o[0], [0, int(t.get_height() / TS) - 1, int(t.get_width() / TS), 1])
			for yy in range(f[1], f[1] + f[3]):
				for xx in range(f[0], f[0] + f[2]):
					var X: int = o[1] + xx
					var Y: int = o[2] + yy
					if X < W and Y < H: covered[Y][X] = true
	var pool: Array = G.THEMES[theme].solids
	for y in H:
		for x in W:
			if not solid[y][x] or covered[y][x] or no_trees.has(Vector2i(x, y)): continue
			var name: String
			if map_id == "village":
				name = "bush_green" if VILLAGE_ROWS[y][x] == "B" else ["tree_round", "tree_oak", "tree_round"][(x * 3 + y) % 3]
			else:
				name = pool[(x * 31 + y * 17 + x * y * 7) % pool.size()]
			var t: Texture2D = G.tex("obj/%s.png" % name)
			var tw := int(t.get_width() / TS)
			var n := Node2D.new()
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.position = Vector2(-t.get_width() / 2.0, -t.get_height())
			n.add_child(s)
			n.position = Vector2(x * TS + tw * TS / 2.0, (y + 1) * TS)
			if tw == 2 and x + 1 < W and solid[y][x + 1] and not covered[y][x + 1]:
				covered[y][x + 1] = true
			elif tw == 2:
				n.position.x = x * TS + TS / 2.0
			covered[y][x] = true
			ysort.add_child(n)

# ================= actors =================
func _make_actor_node(stage_or_actor) -> Node2D:
	var n := Node2D.new()
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12: pts.append(Vector2(cos(i * TAU / 12) * 6, sin(i * TAU / 12) * 2.2))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.35)
	n.add_child(shadow)
	var spr := AnimatedSprite2D.new()
	spr.name = "spr"
	if typeof(stage_or_actor) == TYPE_INT:
		var e: Dictionary = G.ENEMIES[stage_or_actor]
		if e.sprite == "boss":
			spr.sprite_frames = Sprites.boss(e.actor, e.anim)
			spr.play("idle")
			spr.scale = Vector2(0.62, 0.62)
			spr.offset = Vector2(0, -e.anim.idle[2] / 2.0 + e.get("lift", 0))
			shadow.scale = Vector2(2.4, 2.4)
		else:
			spr.sprite_frames = Sprites.actor(e.actor)
			spr.play("idle_down")
			spr.offset = Vector2(0, -7)
	else:
		spr.sprite_frames = Sprites.actor(stage_or_actor)
		spr.play("idle_down")
		spr.offset = Vector2(0, -7)
	n.add_child(spr)
	return n

func _add_label(parent: Node2D, text: String, col: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 5)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 8)
	l.position = Vector2(-40, y)
	l.z_index = 40
	parent.add_child(l)
	return l

func _add_npc(n: Dictionary) -> void:
	var node: Node2D
	var pos := Vector2((n.x + 0.5) * TS, (n.y + 0.8) * TS)
	if n.actor == "":
		node = Node2D.new()
		var s := Sprite2D.new()
		s.texture = G.tex("obj/notice.png")
		s.offset = Vector2(0, -8)
		node.add_child(s)
	else:
		node = _make_actor_node(n.actor)
	node.position = pos
	ysort.add_child(node)
	_add_label(node, n.name, Color("#ffe9b0"), -26)
	var mark := _add_label(node, "", Color("#ffd34d"), -34)
	mark.add_theme_font_size_override("font_size", 9)
	npcs.append({"id": n.id, "name": n.name, "pos": pos, "node": node, "mark": mark})

## Top-left tile of a warp shrine; the row under it is always walkable corridor
func warp_tile(wid: String) -> Vector2i:
	var w: Dictionary = G.WARPS[G.warp_index(wid)]
	if w.map == "village": return VILLAGE_WARP
	var g := _gen(w.map)
	if w.side == "in": return Vector2i(3, g.entry - 3)
	return Vector2i(int(G.MAPS[w.map].w) - 10, g.exit - 3)

## Glowing jack-o'-lantern decoration (not solid)
func _pumpkin(x: int, y: int) -> void:
	var n := _add_obj("pumpkin", x, y, false)
	var gl := Sprite2D.new()
	gl.texture = glow_tex
	gl.position = Vector2(8, -8)
	gl.scale = Vector2(1.5, 1.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gl.material = mat
	gl.z_index = -1
	n.add_child(gl)
	var tw := gl.create_tween().set_loops()
	tw.tween_property(gl, "modulate:a", 0.55, 0.9 + randf() * 0.4)
	tw.tween_property(gl, "modulate:a", 1.0, 0.9 + randf() * 0.4)

func _add_warp(wid: String, t: Vector2i) -> void:
	var node := Node2D.new()
	var s := Sprite2D.new()
	s.texture = G.tex("obj/statue2.png")
	s.centered = false
	s.position = Vector2(-TS, -2 * TS)
	node.add_child(s)
	node.position = Vector2((t.x + 1) * TS, (t.y + 2) * TS)
	ysort.add_child(node)
	for xx in [t.x, t.x + 1]:
		solid[t.y + 1][xx] = true
		no_trees[Vector2i(xx, t.y + 1)] = true
	var on := G.warp_on(wid)
	s.modulate = Color.WHITE if on else Color(0.5, 0.5, 0.55)
	_add_label(node, "ศาลวาร์ป", Color("#9fe8ff") if on else Color("#9a9a9a"), -42)
	var mark := _add_label(node, "", Color("#ffd34d"), -50)
	npcs.append({"id": "warp:" + wid, "name": G.warp_name(wid), "pos": node.position, "node": node, "mark": mark, "warp": wid, "spr": s})

## Teleport to a shrine (gold is paid by the UI)
func warp_to(wid: String) -> void:
	var w: Dictionary = G.WARPS[G.warp_index(wid)]
	var t := warp_tile(wid)
	G.P.map = w.map
	G.P.x = (t.x + 1) * TS
	G.P.y = (t.y + 2.7) * TS
	face = "down"
	load_map(w.map)
	inv = 1.5
	G.save_game()
	Sfx.play("powerup")
	toast.emit("วาร์ปถึง " + G.warp_name(wid), Color("#9fe8ff"))

func _add_chest(id: String, t: Vector2i, loot: Dictionary) -> void:
	var node := Node2D.new()
	var s := Sprite2D.new()
	s.texture = G.tex("icons/chest.png")
	s.offset = Vector2(0, -6)
	node.add_child(s)
	node.position = Vector2((t.x + 0.5) * TS, (t.y + 0.8) * TS)
	if G.P.opened.has(id): s.modulate = Color(0.45, 0.45, 0.45)
	ysort.add_child(node)
	chests.append({"id": id, "pos": node.position, "loot": loot, "node": node, "spr": s})

func _spawn_player() -> void:
	player = _make_actor_node(G.CLASSES[G.P.cls].actor)
	pspr = player.get_node("spr")
	player.position = Vector2(G.P.x, G.P.y)
	ysort.add_child(player)
	if _blocked(player.position):
		var s: Vector2i = G.MAPS.village.spawn
		player.position = Vector2((s.x + 0.5) * TS, (s.y + 0.5) * TS) if map_id == "village" else _safe_spawn()

func _safe_spawn() -> Vector2:
	var e: Dictionary = exits[0]
	return Vector2((e.x + 1.6) * TS, (e.y + 0.5) * TS)

func _spawn_enemy(stage: int) -> Dictionary:
	var node := _make_actor_node(stage)
	ysort.add_child(node)
	var e := {"stage": stage, "node": node, "spr": node.get_node("spr"), "alive": true, "respawn": 0.0, "t": 0.0, "v": Vector2.ZERO, "chase": false}
	e.label = _add_label(node, "Lv%d" % G.enemy_stats(stage).rec, Color.WHITE, -24)
	_place_enemy(e)
	_roll_elite(e)
	return e

## Each (re)spawn has a small chance to be an Elite: bigger, glowing, tougher, more loot
## Rare slimes live in a slot that only shows up now and then
func _hide_rare(e: Dictionary) -> void:
	e.alive = false
	e.node.visible = false
	e.respawn = Time.get_ticks_msec() / 1000.0 + G.RARE_ROLL_SEC

func _roll_elite(e: Dictionary) -> void:
	if G.ENEMIES[e.stage].has("rare"):
		e.elite = false
		if G.ENEMIES[e.stage].rare == "gold": e.spr.modulate = Color(1.15, 1.1, 0.9)
		return
	e.elite = randf() < G.ELITE_CHANCE
	var spr: AnimatedSprite2D = e.spr
	spr.scale = Vector2(1.3, 1.3) if e.elite else Vector2.ONE
	spr.modulate = Color(1.35, 1.05, 0.7) if e.elite else Color.WHITE

func _place_enemy(e: Dictionary) -> void:
	for i in 60:
		var s: Vector2i = spawn_tiles[G.rng.randi() % spawn_tiles.size()]
		var p := Vector2((s.x + 0.5) * TS, (s.y + 0.5) * TS)
		if p.distance_to(player.position if player else Vector2.ZERO) > TS * 8:
			e.node.position = p
			return
	e.node.position = Vector2(W * TS / 2.0, H * TS / 2.0)

func _add_exit_marker(e: Dictionary) -> void:
	var m := Node2D.new()
	m.position = Vector2((e.x + 0.5) * TS, (e.y + 0.5) * TS)
	var arrow := "◀" if e.x == 0 else "▶"
	_add_label(m, arrow + " " + G.MAPS[e.to].name, Color("#ffd34d"), -14)
	overlay.add_child(m)

# ================= collision =================
func _solid_at(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= W or ty >= H: return true
	return solid[ty][tx]

func _blocked(p: Vector2, ignore_npc := false) -> bool:
	for c in [Vector2(-4.5, -3), Vector2(4.5, -3), Vector2(-4.5, 2), Vector2(4.5, 2)]:
		var q: Vector2 = p + c
		if _solid_at(int(floor(q.x / TS)), int(floor(q.y / TS))): return true
	if not ignore_npc:
		for n in npcs:
			if abs(p.x - n.pos.x) < 10 and abs(p.y - n.pos.y) < 6: return true
		for c in chests:
			if abs(p.x - c.pos.x) < 10 and abs(p.y - c.pos.y) < 6: return true
	return false

func _move(n: Node2D, d: Vector2, ignore_npc := false) -> void:
	if d.x != 0 and not _blocked(n.position + Vector2(d.x, 0), ignore_npc): n.position.x += d.x
	if d.y != 0 and not _blocked(n.position + Vector2(0, d.y), ignore_npc): n.position.y += d.y

static func dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y): return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"

# ================= update =================
func _process(dt: float) -> void:
	if map_id == "" or player == null: return
	if inv > 0: inv -= dt
	if gate_t > 0: gate_t -= dt
	player.modulate.a = 0.5 if inv > 0 and int(Time.get_ticks_msec() / 80) % 2 == 0 else 1.0
	if paused:
		pspr.play("idle_" + face)
		return
	# --- player movement ---
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
	# auto-run toggle (R / Caps Lock): Shift then switches to the other speed
	var run: bool = Input.is_physical_key_pressed(KEY_SHIFT) != bool(G.P.get("autorun", false))
	if v != Vector2.ZERO:
		v = v.normalized()
		face = dir_name(v)
		_move(player, v * (95.0 if run else 62.0) * dt)
		pspr.play("walk_" + face)
		pspr.speed_scale = 1.6 if run else 1.0
	else:
		pspr.play("idle_" + face)
	cam.position = player.position
	G.P.x = player.position.x
	G.P.y = player.position.y
	# --- exits ---
	var tx := int(floor(player.position.x / TS))
	var ty := int(floor(player.position.y / TS))
	for e in exits:
		if e.x == tx and e.y == ty:
			var m: Dictionary = G.MAPS[map_id]
			if e.kind == "next" and m.has("boss") and not G.P.flags.has("boss%d" % m.boss):
				player.position.x -= TS * 0.6
				if gate_t <= 0:
					toast.emit("ทางถูกผนึก — ต้องปราบ %s ก่อน" % G.ENEMIES[m.boss].name, Color("#ff8f80"))
					gate_t = 2.0
			else:
				go_map(e.to, e.kind)
				return
	# --- regen ---
	regen_t += dt
	if regen_t >= 1.0:
		regen_t = 0.0
		G.fix_player()
		var r := 3 if G.MAPS[map_id].get("safe", false) else 1
		G.P.hp = mini(G.max_hp(), G.P.hp + int(ceil(G.max_hp() * 0.005 * r)))
		G.P.mp = mini(G.max_mp(), G.P.mp + int(ceil(G.max_mp() * 0.01 * r)))
	# --- enemies ---
	var now := Time.get_ticks_msec() / 1000.0
	for e in enemies:
		var n: Node2D = e.node
		if not e.alive:
			if now > e.respawn:
				if G.ENEMIES[e.stage].has("rare") and randf() >= G.RARE_CHANCE[e.stage]:
					_hide_rare(e)
					continue
				_place_enemy(e)
				_roll_elite(e)
				e.alive = true
				n.visible = true
			continue
		var to_p: Vector2 = player.position - n.position
		var d := to_p.length()
		var ev := Vector2.ZERO
		var rare: String = G.ENEMIES[e.stage].get("rare", "")
		if rare != "" and d < TS * 5:
			ev = -to_p.normalized() * 42.0   # treasure slimes run away
			e.chase = false
		elif d < TS * 5 and inv <= 0:
			ev = to_p.normalized() * 50.0
			e.chase = true
		else:
			e.chase = false
			e.t -= dt
			if e.t <= 0:
				e.t = randf_range(1.0, 2.6)
				e.v = Vector2.ZERO if randf() < 0.35 else Vector2.from_angle(randf() * TAU) * 26.0
			ev = e.v
		var spr: AnimatedSprite2D = e.spr
		if ev != Vector2.ZERO:
			_move(n, ev * dt, true)
			spr.play("walk_" + dir_name(ev))
		else:
			spr.play("idle_down")
		var rec: int = G.enemy_stats(e.stage).rec
		if G.ENEMIES[e.stage].has("rare"):
			var gold: bool = G.ENEMIES[e.stage].rare == "gold"
			e.label.add_theme_color_override("font_color", Color("#ffd34d") if gold else Color.from_hsv(fmod(now * 0.5, 1.0), 0.6, 1.0))
			e.label.text = "★ " + G.ENEMIES[e.stage].name
			if not gold: spr.modulate = Color.from_hsv(fmod(now * 0.5, 1.0), 0.45, 1.0)
		elif e.elite:
			e.label.add_theme_color_override("font_color", Color("#e080ff"))
			e.label.text = ("! " if e.chase else "") + "★Elite Lv%d" % (rec + 3)
		else:
			e.label.add_theme_color_override("font_color", _danger_color(e.stage))
			e.label.text = ("! " if e.chase else "") + "Lv%d" % rec
		if d < 11 and inv <= 0:
			battle_requested.emit(e.stage, e)
			return
	if boss and inv <= 0 and player.position.distance_to(boss.pos) < 22:
		inv = 1.2
		boss_touched.emit(boss.stage)
		return
	# --- nearest interactable ---
	near = null
	var best := 22.0
	for o in npcs + chests:
		if o.has("loot") and G.P.opened.has(o.id): continue
		var dd: float = player.position.distance_to(o.pos)
		if dd < best:
			best = dd
			near = o
	for n in npcs:
		n.mark.text = _npc_marker(n.id)
		# walking up to a dormant shrine wakes it up (free)
		if n.has("warp") and not G.warp_on(n.warp) and player.position.distance_to(n.pos) < 34:
			if not G.P.has("warps"): G.P.warps = {}
			G.P.warps[n.warp] = true
			n.spr.modulate = Color.WHITE
			G.save_game()
			Sfx.play("powerup")
			toast.emit("เปิดใช้ %s แล้ว! วาร์ปมาที่นี่ได้ทุกเมื่อ" % n.name, Color("#9fe8ff"))

func _danger_color(stage: int) -> Color:
	var diff: int = G.enemy_stats(stage).rec - G.P.lvl
	if diff >= 3: return Color("#ff5a4a")
	if diff >= 1: return Color("#ffb347")
	return Color("#9be37a")

func _npc_marker(id: String) -> String:
	if id.begins_with("warp:"): return ""
	if id == "elder":
		var q := G.current_quest()
		if q.is_empty(): return ""
		if not G.P.quest.active: return "!"
		return "?" if G.quest_done(q) else ""
	if id == "board":
		G.ensure_bounties()
		for b in G.P.bounties:
			if G.bounty_done(b): return "?"
	return ""

func interact() -> void:
	if paused or near == null: return
	var o: Dictionary = near
	if o.has("loot"):
		G.P.opened[o.id] = true
		var lines := G.add_loot(o.loot)
		o.spr.modulate = Color(0.45, 0.45, 0.45)
		G.save_game()
		toast.emit("เปิดหีบสมบัติ: " + ", ".join(lines), Color("#ffd34d"))
		Sfx.play("coin")
		near = null
		return
	npc_interact.emit(o.id)

func go_map(to: String, kind: String) -> void:
	G.P.map = to
	var m: Dictionary = G.MAPS[to]
	if to == "village" and map_id == "graveyard":
		G.P.x = (TORII_GATE.x + 0.5) * TS
		G.P.y = (TORII_GATE.y + 1.6) * TS
		face = "down"
	elif to == "village":
		var s: Vector2i = m.from_next
		G.P.x = (s.x + 0.5) * TS
		G.P.y = (s.y + 0.5) * TS
	else:
		var g: Dictionary = _gen(to)
		if kind == "next":
			G.P.x = 1.6 * TS
			G.P.y = (g.entry + 0.5) * TS
			face = "right"
		else:
			G.P.x = (m.w - 1.6) * TS
			G.P.y = (g.exit + 0.5) * TS
			face = "left"
	load_map(to)
	inv = 1.5
	G.save_game()
	toast.emit(m.name, Color("#ffd34d"))

func enemy_defeated(src) -> void:
	if typeof(src) == TYPE_STRING and src == "boss":
		if boss:
			boss.node.queue_free()
			boss = null
		return
	if typeof(src) == TYPE_DICTIONARY:
		src.alive = false
		src.node.visible = false
		src.respawn = Time.get_ticks_msec() / 1000.0 + (G.RARE_ROLL_SEC * 2 if G.ENEMIES[src.stage].has("rare") else 30.0)

func prompt_text() -> String:
	if near == null or paused: return ""
	if near.has("loot"): return "[E] เปิดหีบสมบัติ"
	if near.has("warp"): return "[E] ใช้ศาลวาร์ป"
	return "[E] %s %s" % ["อ่าน" if near.id == "board" else "คุยกับ", near.name]
