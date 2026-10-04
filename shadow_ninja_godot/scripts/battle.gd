extends CanvasLayer
## Turn-based side-view battle with pixel sprites, FX and the chakra ultimate.

signal ended(result: Dictionary)

const GROUND_Y := 410.0
const PX := 330.0
const EX := 950.0
const SCALE := 6.0
const ACT_TABS := ["katana", "shuriken", "ninjutsu", "item"]
# status id: [name, colour, icon under assets/skills, is_buff]
const ST_INFO := {
	"poison": ["พิษ", "#7bd35a", "death", false], "burn": ["ไหม้", "#ff8a3d", "fireball", false],
	"stun": ["มึนงง", "#ffd34d", "thunder", false], "break": ["เกราะแตก", "#ff7a6a", "downgrade", false],
	"weaken": ["อ่อนแรง", "#c08aff", "book_darkness", false], "clone": ["เงาแยกร่าง", "#b9a8ff", "mist", true],
	"might": ["ฮึกเหิม", "#ffb347", "sing", true], "ward": ["ม่านวิญญาณ", "#9fe8ff", "orb_light", true],
	"flee": ["จะหนีใน", "#ffd34d", "boot", false]}
# statuses that just count down (no damage) at their owner's tick
const TIMED := ["break", "weaken", "might", "ward"]

var stage := 0
var src = null
var theme := "forest"
var p := {}
var e := {}
var busy := false
var over := false
var chakra := 0.0
var ult := false
var tab := "katana"
var input_locked := false

var stage_root: Node2D
var log_box: RichTextLabel
var tabs_box: HBoxContainer
var skill_grid: GridContainer
var ult_btn: Button
var chakra_bar: ProgressBar
var info := {}
var flash_rect: ColorRect
var dark_rect: ColorRect
var shake := 0.0

func _ready() -> void:
	layer = 5
	visible = false

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

# ================= setup =================
func start(s: int, source) -> void:
	stage = s
	src = source
	theme = G.MAPS[G.P.map].theme
	if theme == "village": theme = "forest"
	busy = false
	over = false
	chakra = 0.0
	ult = false
	input_locked = false
	G.fix_player()
	var d: Dictionary = G.ENEMIES[s]
	var st := G.enemy_stats(s)
	var elite: bool = typeof(source) == TYPE_DICTIONARY and source.get("elite", false)
	if elite: st = G.elite_stats(st)
	_build()
	p = {"side": "p", "name": G.P.name, "hp": G.P.hp, "max": G.max_hp(), "mp": G.P.mp, "maxmp": G.max_mp(), "st": {}}
	e = {"side": "e", "name": ("★ Elite " + d.name) if elite else d.name, "elite": elite, "rare": d.get("rare", ""), "hp": st.hp, "max": st.hp, "mp": 0, "maxmp": 0, "st": {}, "boss": d.get("boss", false),
		"moves": d.moves, "healed": 0, "atk": st.atk, "def": st.def, "agi": st.agi, "mag": st.mag}
	p.f = _fighter(true, G.CLASSES[G.P.cls].actor, {})
	e.f = _fighter(false, d.actor, d)
	if elite:
		e.f.spr.scale *= 1.25
		e.f.spr.modulate = Color(1.35, 1.05, 0.7)
		var tw: Tween = e.f.spr.create_tween().set_loops()
		tw.tween_property(e.f.spr, "modulate", Color(1.0, 0.8, 1.4), 0.6)
		tw.tween_property(e.f.spr, "modulate", Color(1.35, 1.05, 0.7), 0.6)
	info.p = _info_panel(true, G.CLASSES[G.P.cls].actor)
	info.e = _info_panel(false, d.actor)
	visible = true
	_log("[color=#ffd34d]%s (แนะนำ Lv %d) ขวางทางคุณ![/color]" % [e.name, st.rec])
	if e.rare != "":
		e.st["flee"] = {"t": G.RARE_TURNS, "v": 0}
		_log("[color=#ffd34d]%s! ปราบให้ได้ภายใน %d เทิร์น ไม่งั้นมันจะหนีไป![/color]" % ["สไลม์ทองคำ — ขุมทรัพย์ทองคำ" if e.rare == "gold" else "สไลม์สายรุ้ง — มีคัมภีร์ค่าสถานะ", G.RARE_TURNS])
		if e.rare == "rainbow":
			var tw2: Tween = e.f.spr.create_tween().set_loops()
			for c in ["#ff8a8a", "#ffd36a", "#8aff9a", "#8ad8ff", "#c08aff"]: tw2.tween_property(e.f.spr, "modulate", Color(c), 0.3)
	if elite: _log("[color=#e080ff]มอนสเตอร์ Elite! HP x%d พลัง x%.1f · ทอง x%d · EXP/ของดรอป x%d · มีโอกาสดรอปอุปกรณ์[/color]" % [G.ELITE_HP, G.ELITE_POW, G.ELITE_GOLD, G.ELITE_LOOT])
	if G.pas("battle_cry") > 0:
		p.st["might"] = {"t": 1 + G.pas("battle_cry"), "v": 0}
		_log("[color=#ffb347]โห่ร้องแห่งศึก! ความเสียหาย +25%[/color]")
	if G.pas("spirit_ward") > 0:
		p.st["ward"] = {"t": 1 + G.pas("spirit_ward"), "v": 0}
		_log("[color=#9fe8ff]ม่านวิญญาณปกป้องคุณ! รับความเสียหาย -30%[/color]")
	if G.pas("ambush") > 0:
		chakra = minf(100.0, 15.0 * G.pas("ambush"))
		p["first_crit"] = true
		_log("[color=#b9a8ff]จู่โจมจากเงา! การโจมตีแรกจะคริติคอล[/color]")
	_log("[color=#c9b49a]คีย์ลัด: 1-8 ใช้สกิล · Q/E เปลี่ยนหมวด · R ใช้โอกิ[/color]")
	Sfx.music("boss" if e.boss else "battle")
	_refresh()
	_render_actions()

func _build() -> void:
	UIKit.clear(self)
	var th: Dictionary = G.THEMES[theme]
	# sky
	var sky := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(th.sky[0]))
	gr.set_color(1, Color(th.sky[1]))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	sky.texture = gt
	sky.position = Vector2.ZERO
	sky.size = Vector2(1280, GROUND_Y)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.z_index = -3
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(sky)
	# scenery rows (theme trees/rocks)
	var scen := Node2D.new()
	add_child(scen)
	var pool: Array = th.solids
	for row in 2:
		var sc := 3.0 if row == 0 else 4.5
		var y := GROUND_Y - (70.0 if row == 0 else 6.0)
		var x := -40.0 + row * 30
		var i := 0
		while x < 1320:
			var name: String = pool[(i * 7 + row * 3) % pool.size()]
			var t: Texture2D = G.tex("obj/%s.png" % name)
			var sp := Sprite2D.new()
			sp.texture = t
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(x, y - t.get_height() * sc / 2.0)
			sp.modulate = Color(0.5, 0.55, 0.65) if row == 0 else Color(0.85, 0.85, 0.9)
			if row == 1 and x > 200 and x < 1080:
				x += t.get_width() * sc * 0.8
				i += 1
				continue
			scen.add_child(sp)
			x += t.get_width() * sc * (0.75 if row == 0 else 0.9)
			i += 1
	# ground
	var gtile := AtlasTexture.new()
	gtile.atlas = G.tex("tiles/TilesetFloor.png")
	var gc: Vector2i = th.ground[0]
	gtile.region = Rect2(gc.x * 16, gc.y * 16, 16, 16)
	var ground := TextureRect.new()
	ground.texture = gtile
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.position = Vector2(0, GROUND_Y - 40)
	ground.size = Vector2(1280 / 4.0, 120 / 4.0)
	ground.scale = Vector2(4, 4)
	ground.z_index = -1
	if theme == "graveyard": ground.modulate = Color(0.55, 0.45, 0.68)
	add_child(ground)
	scen.z_index = -1
	stage_root = Node2D.new()
	add_child(stage_root)
	dark_rect = ColorRect.new()
	dark_rect.color = Color(0.25, 0, 0, 0)
	dark_rect.size = Vector2(1280, 470)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark_rect)
	# bottom panel
	var bottom := UIKit.panel()
	bottom.position = Vector2(0, 470)
	bottom.size = Vector2(1280, 250)
	add_child(bottom)
	var hb := UIKit.hbox(14)
	bottom.add_child(hb)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.custom_minimum_size = Vector2(560, 210)
	log_box.add_theme_font_size_override("normal_font_size", 16)
	hb.add_child(log_box)
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	var uh := UIKit.hbox(10)
	chakra_bar = UIKit.bar(Color("#ff6a2a"), 200, 14)
	chakra_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ult_btn = UIKit.button("โอกิ: ผนึกพันเงา", use_ult, 16)
	ult_btn.icon = UIKit.scaled("skills/magic_weapon.png", 2)
	uh.add_child(UIKit.label("จักระ", 15, UIKit.MUTED))
	uh.add_child(chakra_bar)
	uh.add_child(ult_btn)
	right.add_child(uh)
	tabs_box = UIKit.hbox(6)
	right.add_child(tabs_box)
	skill_grid = GridContainer.new()
	skill_grid.columns = 2
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 6)
	right.add_child(skill_grid)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.size = Vector2(1280, 720)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

func _fighter(is_p: bool, actor: String, d: Dictionary) -> Dictionary:
	var n := Node2D.new()
	n.position = Vector2(PX if is_p else EX, GROUND_Y)
	stage_root.add_child(n)
	var boss: bool = d.get("sprite", "") == "boss"
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16: pts.append(Vector2(cos(i * TAU / 16) * 44, sin(i * TAU / 16) * 10))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.35)
	if boss: sh.scale = Vector2(2.2, 2.2)
	n.add_child(sh)
	var spr := AnimatedSprite2D.new()
	var sc := SCALE
	var h := 16.0 * SCALE
	if boss:
		spr.sprite_frames = Sprites.boss(actor, d.anim)
		sc = d.bscale
		spr.offset = Vector2(0, -d.anim.idle[2] / 2.0 + d.get("lift", 0))
		h = (d.anim.idle[2] - d.get("lift", 0)) * sc
		spr.play("idle")
	else:
		spr.sprite_frames = Sprites.actor(actor)
		spr.offset = Vector2(0, -8)
		spr.play("idle_right" if is_p else "idle_left")
	spr.scale = Vector2(sc, sc)
	var ghosts := []
	if is_p:
		for gx in [-70, 70]:
			var g := AnimatedSprite2D.new()
			g.sprite_frames = spr.sprite_frames
			g.offset = spr.offset
			g.scale = spr.scale
			g.play("idle_right")
			g.position.x = gx
			g.modulate = Color(0.6, 0.5, 1.0, 0.35)
			g.visible = false
			n.add_child(g)
			ghosts.append(g)
	n.add_child(spr)
	return {"root": n, "spr": spr, "boss": boss, "ghosts": ghosts, "h": h}

func _info_panel(is_p: bool, actor: String) -> Dictionary:
	var pn := UIKit.panel("nine_path_bg.png", [12, 8, 14, 8])
	pn.position = Vector2(16, 12) if is_p else Vector2(1280 - 16 - 420, 12)
	pn.custom_minimum_size = Vector2(420, 0)
	add_child(pn)
	var hb := UIKit.hbox(10)
	pn.add_child(hb)
	var face := UIKit.icon("actors/%s/face.png" % actor, 64)
	hb.add_child(face)
	var v := UIKit.vbox(2)
	hb.add_child(v)
	var name_l := UIKit.label("", 18, UIKit.GOLD, true)
	v.add_child(name_l)
	var hp := UIKit.bar(Color("#d9443a"), 320, 16)
	v.add_child(hp)
	var hp_l := UIKit.label("", 13)
	hp_l.position = Vector2(6, -2)
	hp.add_child(hp_l)
	var mp: ProgressBar = null
	var mp_l: Label = null
	if is_p:
		mp = UIKit.bar(Color("#3b82d9"), 320, 12)
		v.add_child(mp)
		mp_l = UIKit.label("", 11)
		mp_l.position = Vector2(6, -3)
		mp.add_child(mp_l)
	var st := UIKit.hbox(4)
	st.custom_minimum_size = Vector2(0, 30)
	v.add_child(st)
	return {"name": name_l, "hp": hp, "hp_l": hp_l, "mp": mp, "mp_l": mp_l, "st": st, "sig": ""}

func _st_desc(k: String, s: Dictionary) -> String:
	match k:
		"poison", "burn": return "เสีย HP %d ทุกเทิร์น" % s.v
		"stun": return "ขยับไม่ได้ เสียเทิร์นถัดไป"
		"break": return "พลังป้องกัน -40%"
		"weaken": return "พลังโจมตีและเวท -30%"
		"clone": return "เงาแยกร่างรับการโจมตีแทน"
		"might": return "ความเสียหายที่ทำ +25%"
		"ward": return "ความเสียหายที่ได้รับ -30%"
		"flee": return "เมื่อหมดเวลาจะหนีไป และคุณจะไม่ได้อะไรเลย!"
	return ""

## One hoverable icon per status: green frame = buff, red = debuff, number = turns left
func _status_icons(box: HBoxContainer, u: Dictionary) -> void:
	UIKit.clear(box)
	for k in u.st:
		var inf: Array = ST_INFO[k]
		var s: Dictionary = u.st[k]
		var pc := PanelContainer.new()
		var sb := UIKit.flat(Color(0, 0, 0, 0.55), Color("#5fd36a") if inf[3] else Color("#e05a4a"), 2, 4)
		sb.set_content_margin_all(1)
		pc.add_theme_stylebox_override("panel", sb)
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		pc.theme = UIKit.theme()
		var left := ("เหลือ %d ครั้ง" % s.t) if k == "clone" else ("เหลือ %d เทิร์น" % s.t)
		pc.tooltip_text = "%s (%s)\n%s\n%s" % [inf[0], "บัพ" if inf[3] else "ดีบัพ", _st_desc(k, s), left]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(26, 26)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(holder)
		var ic := UIKit.icon("skills/%s.png" % inf[2], 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ic)
		var n := UIKit.label(str(s.t), 12, Color.WHITE, true)
		n.add_theme_constant_override("outline_size", 4)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.position = Vector2(16, 8)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(n)
		box.add_child(pc)

func _refresh() -> void:
	for side in ["p", "e"]:
		var u: Dictionary = p if side == "p" else e
		if u.is_empty() or not info.has(side): continue
		var ip: Dictionary = info[side]
		ip.name.text = u.name + ("   Lv %d" % G.P.lvl if side == "p" else "")
		ip.hp.max_value = u.max
		ip.hp.value = u.hp
		ip.hp_l.text = "HP %d/%d" % [u.hp, u.max]
		if ip.mp:
			ip.mp.max_value = u.maxmp
			ip.mp.value = u.mp
			ip.mp_l.text = "MP %d/%d" % [u.mp, u.maxmp]
		var sig := str(u.st)
		if sig != ip.sig:
			ip.sig = sig
			_status_icons(ip.st, u)
	if p.has("f"):
		for g in p.f.ghosts: g.visible = p.st.has("clone")
	if chakra_bar:
		chakra_bar.value = chakra
		ult_btn.disabled = busy or over or chakra < 100
		ult_btn.modulate = Color(1.3, 1.1, 0.8) if chakra >= 100 and not busy else Color.WHITE

func _render_actions() -> void:
	UIKit.clear(tabs_box)
	for t in ACT_TABS:
		var tt: String = t
		var b := UIKit.button(G.TREES[t], func() -> void:
			tab = tt
			_render_actions(), 15)
		if t == tab: b.add_theme_stylebox_override("normal", UIKit.sbox("button_hover.png", [4, 3, 4, 3], [14, 6, 14, 7]))
		tabs_box.add_child(b)
	UIKit.clear(skill_grid)
	var dis := busy or over
	var count := 0
	if tab == "item":
		for id in G.ITEMS:
			var n: int = int(G.P.inv.get(id, 0))
			if n <= 0 or G.ITEMS[id].has("tome"): continue
			var iid: String = id
			var b := _action_button(G.ITEMS[id].icon, "%s ×%d" % [G.ITEMS[id].name, n], G.ITEMS[id].desc, func() -> void: use_item(iid))
			b.disabled = dis
			skill_grid.add_child(b)
			count += 1
		var fb := _action_button("skills/camouflage.png", "หลบหนี", "โอกาส %d%%" % (25 if e.boss else 50), flee)
		fb.disabled = dis
		skill_grid.add_child(fb)
	else:
		for id in G.SKILLS:
			var s: Dictionary = G.SKILLS[id]
			var lv: int = int(G.P.skills.get(id, 0))
			if s.tree != tab or lv <= 0 or s.kind == "passive": continue
			var sid: String = id
			var b := _action_button("skills/%s.png" % s.icon, "%s  Lv%d" % [s.name, lv], "MP %d · %s" % [s.mp, G.skill_desc(id, lv)], func() -> void: use_skill(sid))
			b.disabled = dis or p.mp < s.mp
			skill_grid.add_child(b)
			count += 1
		if count == 0:
			skill_grid.add_child(UIKit.label("ยังไม่มีสกิลสายนี้ — เรียนได้ที่อาจารย์ไรเดน หรือเมนู (I)", 15, UIKit.MUTED))
	_refresh()

func _action_button(icon_path: String, title: String, sub: String, cb: Callable) -> Button:
	var b := UIKit.button(title + "\n" + sub, cb, 14)
	b.icon = UIKit.scaled(icon_path, 2)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(325, 50)
	b.clip_text = true
	b.tooltip_text = sub
	return b

func _log(t: String) -> void:
	log_box.append_text(t + "\n")

# ================= player actions =================
func _turn(action: Callable) -> void:
	if busy or over: return
	busy = true
	_render_actions()
	await action.call()
	if await _check_end(): return
	await wait(0.25)
	await _tick(e)
	if await _check_end(): return
	await _enemy_turn()
	if await _check_end(): return
	if e.rare != "" and e.st.has("flee"):
		e.st.flee.t -= 1
		_refresh()
		if e.st.flee.t <= 0:
			over = true
			_log("[color=#ff9c8f]%s หนีไปแล้ว! ไม่ได้อะไรเลย...[/color]" % e.name)
			Sfx.play("miss")
			var tw := create_tween()
			tw.tween_property(e.f.root, "modulate:a", 0.0, 0.5)
			tw.parallel().tween_property(e.f.root, "position:x", e.f.root.position.x + 300, 0.5)
			await wait(0.8)
			_end("escaped")
			return
	await _tick(p)
	if await _check_end(): return
	p.mp = mini(p.maxmp, p.mp + roundi(p.maxmp * G.mp_regen()))
	busy = false
	_render_actions()

func use_skill(id: String) -> void:
	var s: Dictionary = G.SKILLS[id]
	var lv: int = int(G.P.skills.get(id, 0))
	if lv <= 0 or busy or over or p.mp < s.mp: return
	_turn(func() -> void: await _do_skill(id, s, lv))

func _pow(kind: String) -> float:
	return G.ranged_pow() if kind == "ranged" else G.magic_pow() if kind == "magic" else G.melee_pow()

func _do_skill(id: String, s: Dictionary, lv: int) -> void:
	p.mp -= s.mp
	_log("[color=#9fd3ff]%s ใช้ %s![/color]" % [G.P.name, s.name])
	var v := G.skill_value(id, lv)
	match s.kind:
		"melee":
			await melee_hits(s.hits, v, s.get("crit", 0), s.fx)
		"ranged":
			var hit := await ranged_hits(s.hits, v, s.proj)
			if hit and s.has("status"):
				add_status(e, s.status.id, s.status.turns, roundi(_pow(s.status.pow) * (s.status.base + s.status.per * lv)))
			if hit and s.has("stun") and randf() * 100 < s.stun[0] + s.stun[1] * lv: add_status(e, "stun", 1)
		"magic":
			await magic_hit(v, s.fx)
			if s.has("status"): add_status(e, s.status.id, s.status.turns, roundi(_pow(s.status.pow) * (s.status.base + s.status.per * lv)))
			if s.has("stun") and e.hp > 0 and randf() * 100 < s.stun[0]: add_status(e, "stun", 1)
		"heal":
			_fx("heal", p, 5)
			Sfx.play("heal")
			await wait(0.4)
			heal_unit(p, G.heal_amount(lv))
		"buff":
			_fx("smoke", p, 6)
			Sfx.play("buff")
			await wait(0.35)
			add_status(p, "clone", 2 + lv / 2)
			_log("[color=#b9a8ff]เงาแยกร่างล้อมรอบตัวคุณ![/color]")

func use_item(id: String) -> void:
	if int(G.P.inv.get(id, 0)) <= 0 or busy or over: return
	_turn(func() -> void:
		G.P.inv[id] = int(G.P.inv[id]) - 1
		var it: Dictionary = G.ITEMS[id]
		_log("[color=#9fd3ff]%s ใช้ %s[/color]" % [G.P.name, it.name])
		if id == "bomb":
			await _projectile(p, e, "icons/bomb.png", false)
			_fx("explosion", e, 6)
			Sfx.play("explosion")
			shake = 16
			deal(e, 50 + G.P.lvl * 8, {"can_crit": false, "raw": true})
			add_status(e, "burn", 2, 10 + G.P.lvl * 2)
		elif id == "smoke":
			_fx("smoke", p, 7)
			Sfx.play("miss")
			_log("[color=#ffd34d]คุณหายตัวไปในกลุ่มควัน![/color]")
			over = true
			await wait(0.6)
			_end("flee")
		else:
			_fx("heal", p, 5)
			Sfx.play("heal")
			await wait(0.3)
			if it.has("hp"): heal_unit(p, it.hp)
			if it.has("mp"): mp_unit(p, it.mp))

func flee() -> void:
	if busy or over: return
	_turn(func() -> void:
		if randf() < (0.25 if e.boss else 0.5):
			_log("[color=#ffd34d]หนีสำเร็จ![/color]")
			over = true
			await wait(0.4)
			_end("flee")
		else:
			_log("[color=#ff9c8f]หนีไม่พ้น![/color]"))

func use_ult() -> void:
	if chakra < 100 or busy or over: return
	_turn(func() -> void:
		chakra = 0
		ult = true
		_log("[color=#ff8a3d]%s ปลดปล่อยโอกิ: ผนึกพันเงา!![/color]" % G.P.name)
		var tw := create_tween()
		tw.tween_property(dark_rect, "color:a", 0.5, 0.25)
		_fx("boost", p, 5)
		Sfx.play("powerup")
		await wait(0.4)
		var pw := (G.melee_pow() + G.ranged_pow() + G.magic_pow()) / 3.0
		for i in 6:
			if e.hp <= 0: break
			var left := i % 2 == 0
			p.f.root.position.x = e.f.root.position.x + (-150.0 if left else 150.0)
			p.f.spr.play("attack_right" if left else "attack_left")
			_fx("slash" if i % 2 else "cut", e, 6)
			Sfx.play("slash")
			deal(e, pw * 1.05, {"crit": G.crit_chance() + 10})
			await wait(0.14)
		p.f.root.position.x = PX
		_play(p, "idle")
		ult = false
		var tw2 := create_tween()
		tw2.tween_property(dark_rect, "color:a", 0.0, 0.3))

# ================= damage core =================
func deal(t: Dictionary, raw: float, opt := {}) -> int:
	var df: float = t.def if t.side == "e" else G.p_def()
	if t.st.has("break"): df *= 0.6
	var dmg := raw * randf_range(0.9, 1.1)
	if not opt.get("raw", false): dmg *= 60.0 / (60.0 + df * 2)
	if t.side == "e" and p.st.has("might"): dmg *= 1.25
	if t.side == "p" and e.st.has("weaken"): dmg *= 0.7
	if t.st.has("ward"): dmg *= 0.7
	var crit := false
	var sure: bool = t.side == "e" and p.get("first_crit", false) and opt.get("can_crit", true)
	if sure: p.first_crit = false
	if opt.get("can_crit", true) and (sure or randf() * 100 < opt.get("crit", 0.0)):
		dmg *= 1.7
		crit = true
	var d := maxi(1, roundi(dmg))
	t.hp = maxi(0, t.hp - d)
	if not ult:
		chakra = minf(100.0, chakra + (d * 70.0 / t.max if t.side == "e" else d * 110.0 / t.max))
	_float(t, ("CRIT! %d" % d) if crit else str(d), Color("#ffd34d") if crit else Color.WHITE, 40 if crit else 32)
	_hit_flash(t)
	shake = 14.0 if crit else 7.0
	Sfx.play("crit" if crit else "hit")
	_refresh()
	return d

func dodge(t: Dictionary) -> bool:
	if t.st.has("clone"):
		t.st.clone.t -= 1
		if t.st.clone.t <= 0: t.st.erase("clone")
		_float(t, "เงาหลบ!", Color("#b9a8ff"), 28)
		Sfx.play("miss")
		_refresh()
		return true
	var atk_agi: float = e.agi if t.side == "p" else G.stat("agi")
	var def_agi: float = G.stat("agi") if t.side == "p" else e.agi
	var ch := clampf(4 + (def_agi - atk_agi) * 0.8, 2, 30)
	if t.side == "p": ch = minf(ch + G.dodge_bonus(), 45)
	if randf() * 100 < ch:
		_float(t, "หลบ!", Color("#9fd3ff"), 28)
		Sfx.play("miss")
		return true
	return false

func melee_hits(n: int, mult: float, crit_bonus: float, fxn: String) -> void:
	await _lunge(p, e)
	for i in n:
		_attack_anim(p)
		if not dodge(e):
			_fx(fxn, e, 5)
			Sfx.play("slash")
			deal(e, G.melee_pow() * mult, {"crit": G.crit_chance() + crit_bonus})
			if e.hp > 0 and randf() * 100 < G.debuff_chance("rend"): add_status(e, "break", 2)
		await wait(0.17 if n > 1 else 0.26)
		if e.hp <= 0: break
	await _return(p)

func ranged_hits(n: int, mult: float, proj: String) -> bool:
	var any := false
	for i in n:
		_attack_anim(p)
		await _projectile(p, e, "icons/%s.png" % proj, proj == "shuriken")
		if not dodge(e):
			_fx(proj, e, 3)
			deal(e, G.ranged_pow() * mult, {"crit": G.crit_chance() + 5})
			if e.hp > 0 and randf() * 100 < G.debuff_chance("venom"): add_status(e, "poison", 3, roundi(G.ranged_pow() * 0.35))
			any = true
		if e.hp <= 0: break
	return any

func magic_hit(mult: float, fxn: String) -> void:
	_attack_anim(p)
	Sfx.play("fire" if fxn == "flame" else "explosion" if fxn == "explosion" else "thunder")
	_fx(fxn, e, 6.0 if fxn != "explosion" else 6.5)
	if fxn == "thunder": _flash(0.45)
	if fxn == "explosion": shake = 18
	await wait(0.35)
	deal(e, G.magic_pow() * mult, {"can_crit": false})
	if e.hp > 0 and randf() * 100 < G.debuff_chance("hex"): add_status(e, "weaken", 2)

func heal_unit(u: Dictionary, n: int) -> void:
	var before: int = u.hp
	u.hp = mini(u.max, u.hp + n)
	var d: int = u.hp - before
	if d > 0:
		_float(u, "+%d" % d, Color("#7dff8a"), 32)
		_log("[color=%s]%s ฟื้น HP %d[/color]" % ["#9fd3ff" if u.side == "p" else "#ff9c8f", u.name, d])
	_refresh()

func mp_unit(u: Dictionary, n: int) -> void:
	var before: int = u.mp
	u.mp = mini(u.maxmp, u.mp + n)
	if u.mp > before: _float(u, "+%d MP" % (u.mp - before), Color("#7fb6ff"), 28)
	_refresh()

func add_status(u: Dictionary, k: String, turns: int, val := 0) -> void:
	if u.hp <= 0: return
	u.st[k] = {"t": turns, "v": val, "fresh": true}
	_float(u, ST_INFO[k][0] + "!", Color(ST_INFO[k][1]), 26)
	_log("[color=#ffd34d]%s ติดสถานะ %s[/color]" % [u.name, ST_INFO[k][0]])
	_refresh()

func _tick(u: Dictionary) -> void:
	for k in TIMED:
		if not u.st.has(k): continue
		if u.st[k].get("fresh", false):
			u.st[k].fresh = false
			continue
		u.st[k].t -= 1
		if u.st[k].t <= 0:
			u.st.erase(k)
			_log("[color=#c9b49a]%s หมดสถานะ %s[/color]" % [u.name, ST_INFO[k][0]])
		_refresh()
	for k in ["poison", "burn"]:
		if not u.st.has(k): continue
		var s: Dictionary = u.st[k]
		u.hp = maxi(0, u.hp - s.v)
		_hit_flash(u)
		_float(u, "-%d" % s.v, Color(ST_INFO[k][1]), 30)
		_log("[color=%s]%s เสีย HP %d จาก%s[/color]" % ["#ff9c8f" if u.side == "p" else "#9fd3ff", u.name, s.v, ST_INFO[k][0]])
		s.t -= 1
		if s.t <= 0: u.st.erase(k)
		_refresh()
		await wait(0.35)

# ================= enemy AI =================
func _enemy_turn() -> void:
	if e.st.has("stun"):
		e.st.erase("stun")
		_log("[color=#ffd34d]%s มึนงง ขยับไม่ได้![/color]" % e.name)
		_float(e, "Zzz", Color("#ffd34d"), 30)
		_refresh()
		await wait(0.5)
		return
	var specials := []
	for m in e.moves:
		if m != "hit" and m != "heal": specials.append(m)
	var mv := "hit"
	if "heal" in e.moves and e.hp < e.max * (0.45 if e.rare != "" else 0.3) and randf() < 0.45 and e.healed < (3 if e.rare != "" else 2):
		mv = "heal"
		e.healed += 1
	elif specials.size() > 0 and (not "hit" in e.moves or randf() < (0.45 if e.boss else 0.32)):
		mv = specials.pick_random()
	match mv:
		"hit": await _e_melee(1.0, "โจมตี")
		"bump": await _e_melee(1.0, "เด้งกระแทกเบาๆ")
		"guard":
			_log("[color=#ff9c8f]%s หดตัวแข็งเป็นเกราะ![/color]" % e.name)
			_fx("shield", e, 5)
			Sfx.play("buff")
			await wait(0.4)
			add_status(e, "ward", 2)
		"hide":
			_log("[color=#ff9c8f]%s ทำตัวลื่นไหล เตรียมหลบ![/color]" % e.name)
			_fx("smoke", e, 5)
			Sfx.play("miss")
			await wait(0.4)
			add_status(e, "clone", 1)
		"bite": await _e_melee(1.3, "ฟาดอย่างดุร้าย")
		"heavy": await _e_melee(1.6, "ใช้ท่าโจมตีหนัก")
		"star":
			_log("[color=#ff9c8f]%s ปาอาวุธลับ![/color]" % e.name)
			for i in 2:
				_attack_anim(e)
				await _projectile(e, p, "icons/shuriken.png", true)
				if not dodge(p):
					_fx("shuriken", p, 3)
					deal(p, e.atk * 0.65, {"crit": 4})
		"poison":
			_log("[color=#ff9c8f]%s ปาเข็มพิษ![/color]" % e.name)
			_attack_anim(e)
			await _projectile(e, p, "icons/kunai.png", false)
			if not dodge(p):
				deal(p, e.atk * 0.6, {"can_crit": false})
				add_status(p, "poison", 3, roundi(e.mag * 0.45))
		"fire":
			_log("[color=#ff9c8f]%s ร่ายคาถาไฟ![/color]" % e.name)
			_attack_anim(e)
			Sfx.play("fire")
			_fx("flame", p, 6)
			await wait(0.4)
			deal(p, e.mag * 1.5, {"can_crit": false})
			add_status(p, "burn", 2, roundi(e.mag * 0.35))
		"stun":
			_log("[color=#ff9c8f]%s ทุบพื้นสะเทือน![/color]" % e.name)
			_attack_anim(e)
			shake = 18
			_fx("smoke", p, 6)
			Sfx.play("explosion")
			await wait(0.3)
			if not dodge(p):
				deal(p, e.atk * 0.9, {"can_crit": false})
				if randf() < 0.5: add_status(p, "stun", 1)
		"drain":
			_log("[color=#ff9c8f]%s ดูดพลังชีวิต![/color]" % e.name)
			_attack_anim(e)
			_fx("spirit", p, 6)
			_flash(0.3)
			Sfx.play("magic")
			await wait(0.4)
			var d := deal(p, e.mag * 1.3, {"can_crit": false})
			heal_unit(e, roundi(d * 0.6))
		"heal":
			_log("[color=#ff9c8f]%s ฟื้นฟูตัวเอง[/color]" % e.name)
			_fx("heal", e, 6)
			Sfx.play("heal")
			await wait(0.45)
			heal_unit(e, roundi(e.max * (0.12 if e.rare != "" else 0.22)))
	if p.st.has("stun") and p.hp > 0:
		p.st.erase("stun")
		await wait(0.4)
		_log("[color=#ffd34d]%s มึนงง เสียเทิร์น![/color]" % G.P.name)
		_refresh()
		await _tick(e)
		if e.hp <= 0 or p.hp <= 0: return
		await _enemy_turn()

func _e_melee(mult: float, what: String) -> void:
	_log("[color=#ff9c8f]%s %s![/color]" % [e.name, what])
	await _lunge(e, p)
	_attack_anim(e)
	if not dodge(p):
		_fx("cut", p, 5)
		Sfx.play("slash")
		deal(p, e.atk * mult, {"crit": 8 if e.boss else 4})
	await wait(0.28)
	await _return(e)

# ================= end =================
func _check_end() -> bool:
	if over: return true
	if e.hp <= 0:
		over = true
		_die(e)
		_log("[color=#ffd34d]%s พ่ายแพ้![/color]" % e.name)
		await wait(0.9)
		_end("win")
		return true
	if p.hp <= 0:
		over = true
		_die(p)
		_log("[color=#ff9c8f]%s ล้มลง...[/color]" % G.P.name)
		await wait(0.9)
		_end("lose")
		return true
	return false

func _end(res: String) -> void:
	_render_actions()
	G.P.hp = p.hp
	G.P.mp = p.mp
	var d: Dictionary = G.ENEMIES[stage]
	var r := {"res": res, "stage": stage, "src": src, "lines": [], "lv": 0, "exp": 0, "first_boss": false, "lost": 0, "elite": e.get("elite", false)}
	if res == "win":
		var st := G.enemy_stats(stage)
		var rolls := 1
		if r.elite:
			st = G.elite_stats(st)
			rolls = G.ELITE_LOOT
		G.P.kills[str(stage)] = int(G.P.kills.get(str(stage), 0)) + 1
		G.P.wins += 1
		if d.get("boss", false):
			r.first_boss = not G.P.flags.has("boss%d" % stage)
			G.P.flags["boss%d" % stage] = true
		var loot := {"gold": st.gold, "mats": {}, "items": {}}
		if e.rare == "gold": loot.gold = randi_range(5000, 10000)
		if e.rare == "rainbow": loot.items[G.STAT_TOMES.values().pick_random()] = 1
		for i in rolls:
			for dr in d.drops:
				if randf() < dr[1]: loot.mats[dr[0]] = int(loot.mats.get(dr[0], 0)) + (dr[2] if dr.size() > 2 else 1)
			if randf() < 0.25:
				var it: String = ["potion", "potion", "ether", "hipotion", "bomb"].pick_random()
				loot.items[it] = int(loot.items.get(it, 0)) + 1
		if not d.get("boss", false) and e.rare == "" and randf() < (G.ELITE_GEAR_DROP if r.elite else G.GEAR_DROP):
			var gid := G.random_drop_gear()
			if gid != "": loot["gear"] = gid
		r.lines = G.add_loot(loot)
		r.exp = st.exp
		r.lv = G.gain_exp(st.exp)
		Sfx.play("win")
	elif res == "lose":
		r.lost = int(G.P.gold * 0.1)
		G.P.gold -= r.lost
		G.P.hp = G.max_hp()
		G.P.mp = G.max_mp()
		var inn: Vector2i = G.MAPS.village.inn
		G.P.map = "village"
		G.P.x = (inn.x + 0.5) * 16
		G.P.y = (inn.y + 0.5) * 16
		Sfx.play("lose")
	G.save_game()
	ended.emit(r)

# ================= visuals =================
func _play(u: Dictionary, base: String) -> void:
	var spr: AnimatedSprite2D = u.f.spr
	if u.f.boss:
		var a := base if spr.sprite_frames.has_animation(base) else "idle"
		spr.play(a)
	else:
		if base == "walk" or base == "idle" or base == "attack":
			spr.play(base + "_" + ("right" if u.side == "p" else "left"))

func _attack_anim(u: Dictionary) -> void:
	_play(u, "attack")
	var t := 0.7 if u.f.boss else 0.3
	get_tree().create_timer(t).timeout.connect(func() -> void:
		if is_instance_valid(u.f.spr) and u.hp > 0 and not (u.side == "p" and ult): _play(u, "idle"))

func _lunge(a: Dictionary, t: Dictionary) -> void:
	_play(a, "walk")
	var dir := signf(t.f.root.position.x - a.f.root.position.x)
	var gap := 150.0 + (90.0 if t.f.boss or a.f.boss else 0.0)
	var tw := create_tween()
	tw.tween_property(a.f.root, "position:x", t.f.root.position.x - dir * gap, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

func _return(a: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_property(a.f.root, "position:x", PX if a.side == "p" else EX, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if a.hp > 0: _play(a, "idle")

func _center(u: Dictionary) -> Vector2:
	return u.f.root.position + Vector2(0, -u.f.h * 0.5)

func _fx(name: String, u: Dictionary, sc: float) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Sprites.fx(name, Sprites.FX_FRAMES[name])
	a.scale = Vector2(sc, sc)
	a.position = _center(u)
	a.flip_h = u.side == "p"
	a.z_index = 10
	stage_root.add_child(a)
	a.play("default")
	a.animation_finished.connect(a.queue_free)

func _projectile(from: Dictionary, to: Dictionary, icon_path: String, spin: bool) -> void:
	Sfx.play("throw")
	var s := Sprite2D.new()
	s.texture = G.tex(icon_path)
	s.scale = Vector2(3.5, 3.5)
	var a := _center(from) + Vector2(60 if from.side == "p" else -60, 0)
	var b := _center(to)
	s.position = a
	s.z_index = 10
	if not spin: s.rotation = (b - a).angle() + PI / 2
	if not spin and icon_path.ends_with("bomb.png"): s.rotation = 0
	stage_root.add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "position", b, 0.28)
	if spin: tw.tween_property(s, "rotation", TAU * 2 * (1 if from.side == "p" else -1), 0.28)
	await tw.finished
	s.queue_free()

func _float(u: Dictionary, text: String, col: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font_bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.size = Vector2(300, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = u.f.root.position + Vector2(-150 + randf_range(-30, 30), -u.f.h - 50)
	l.z_index = 20
	stage_root.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func _hit_flash(u: Dictionary) -> void:
	var spr: AnimatedSprite2D = u.f.spr
	spr.modulate = Color(5, 5, 5)
	if not u.f.boss and u.hp > 0:
		spr.play("idle_" + ("right" if u.side == "p" else "left"))
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color.WHITE, 0.2)

func _flash(a: float) -> void:
	flash_rect.color.a = a
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.35)

func _die(u: Dictionary) -> void:
	var spr: AnimatedSprite2D = u.f.spr
	if not u.f.boss and spr.sprite_frames.has_animation("dead"): spr.play("dead")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(spr, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_property(u.f.root, "position:y", u.f.root.position.y + 10, 0.8)

func _process(dt: float) -> void:
	if not visible or stage_root == null: return
	if shake > 0:
		stage_root.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake *= 0.85
		if shake < 0.5:
			shake = 0
			stage_root.position = Vector2.ZERO

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or input_locked or busy or over: return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var btns := skill_grid.get_children().filter(func(c): return c is Button)
			var i := k - KEY_1
			if i < btns.size() and not btns[i].disabled: btns[i].pressed.emit()
		elif k == KEY_Q or k == KEY_E:
			var i := ACT_TABS.find(tab)
			tab = ACT_TABS[(i + (1 if k == KEY_E else 3)) % 4]
			_render_actions()
		elif k == KEY_R:
			use_ult()
