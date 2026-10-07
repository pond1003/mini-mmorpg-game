extends CanvasLayer
## All overlay UI: title + class select, HUD, dialog, toasts, modals (shop/forge/inn/board/...), menu (stats/skills/bag/quests/bestiary/system).

var main: Node
var root: Control

# hud
var hud: Control
var hud_name: Label
var hud_hp: ProgressBar
var hud_hp_l: Label
var hud_mp: ProgressBar
var hud_mp_l: Label
var hud_exp: ProgressBar
var hud_gold: Label
var hud_boost: Label
var hud_zone: Label
var hud_quest: RichTextLabel
var hud_face: TextureRect
var prompt: Label
var toast_box: VBoxContainer
# dialog
var dialog: Control
var dlg_face: TextureRect
var dlg_name: Label
var dlg_text: Label
var dlg_lines: Array = []
var dlg_i := 0
var dlg_after: Callable
# modal
var modal: Control
var modal_box: VBoxContainer
var modal_panel: PanelContainer
# menu
var menu: Control
var menu_body: VBoxContainer
var menu_tabs: HBoxContainer
var menu_tab := "stats"
var bag_filter := "all"
var bag_sel := ""
var doll_spr: AnimatedSprite2D
# title
var title: Control
var pick_cls := ""

const Updater := preload("res://scripts/updater.gd")
var updater: Node
var update_checked := false

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)
	_build_hud()
	_build_dialog()
	_build_menu()
	_build_modal()
	_build_title()
	updater = Updater.new()
	add_child(updater)
	toast_box = UIKit.vbox(6)
	UIKit.anchor(toast_box, [0.5, 0, 0.5, 0], [-300, 70, 300, 80])
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

func blocking() -> bool:
	return modal.visible or menu.visible or dialog.visible or title.visible

# ================= HUD =================
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var pn := UIKit.panel("nine_path_bg.png", [12, 8, 14, 10])
	pn.position = Vector2(12, 10)
	hud.add_child(pn)
	var hb := UIKit.hbox(10)
	pn.add_child(hb)
	hud_face = UIKit.icon("actors/NinjaRed/face.png", 60)
	hb.add_child(hud_face)
	var v := UIKit.vbox(2)
	hb.add_child(v)
	hud_name = UIKit.label("", 16, UIKit.GOLD, true)
	v.add_child(hud_name)
	hud_hp = UIKit.bar(Color("#d9443a"), 220, 15)
	v.add_child(hud_hp)
	hud_hp_l = UIKit.label("", 12)
	hud_hp_l.position = Vector2(6, -2)
	hud_hp.add_child(hud_hp_l)
	hud_mp = UIKit.bar(Color("#3b82d9"), 220, 12)
	v.add_child(hud_mp)
	hud_mp_l = UIKit.label("", 11)
	hud_mp_l.position = Vector2(6, -3)
	hud_mp.add_child(hud_mp_l)
	hud_exp = UIKit.bar(Color("#8bc34a"), 220, 6)
	v.add_child(hud_exp)
	hud_gold = UIKit.label("", 14, UIKit.GOLD)
	v.add_child(hud_gold)
	hud_boost = UIKit.label("", 14, Color("#9be37a"), true)
	v.add_child(hud_boost)
	hud_zone = UIKit.label("", 22, UIKit.PAPER, true)
	UIKit.anchor(hud_zone, [0, 0, 1, 0], [0, 14, -12, 44])
	hud_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_zone.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_zone.add_theme_constant_override("outline_size", 6)
	hud.add_child(hud_zone)
	var qp := UIKit.panel("nine_path_bg.png", [12, 8, 12, 8])
	qp.position = Vector2(12, 132)
	qp.custom_minimum_size = Vector2(300, 0)
	hud.add_child(qp)
	hud_quest = UIKit.rich(15)
	hud_quest.custom_minimum_size = Vector2(280, 0)
	qp.add_child(hud_quest)
	prompt = UIKit.label("", 20, Color("#ffe9b0"), true)
	UIKit.anchor(prompt, [0, 1, 1, 1], [0, -120, 0, -90])
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 7)
	hud.add_child(prompt)
	var help := UIKit.label("WASD เดิน · Shift วิ่ง · R สลับวิ่งตลอด · E คุย/เปิดหีบ · I เมนู · ชนศัตรูเพื่อต่อสู้", 14, Color(1, 1, 1, 0.75))
	UIKit.anchor(help, [0, 1, 1, 1], [0, -28, -10, -8])
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)
	hud.add_child(help)
	hud.visible = false

func update_hud(zone: String, prompt_text: String) -> void:
	if G.P.is_empty(): return
	G.fix_player()
	hud_face.texture = Sprites.face(G.CLASSES[G.P.cls].actor)
	hud_name.text = "%s   Lv %d  %s" % [G.P.name, G.P.lvl, G.cls().name]
	hud_hp.max_value = G.max_hp()
	hud_hp.value = G.P.hp
	hud_hp_l.text = "HP %d/%d" % [G.P.hp, G.max_hp()]
	hud_mp.max_value = G.max_mp()
	hud_mp.value = G.P.mp
	hud_mp_l.text = "MP %d/%d" % [G.P.mp, G.max_mp()]
	hud_exp.max_value = G.exp_need(G.P.lvl)
	hud_exp.value = G.P.exp
	hud_gold.text = "ทอง %d   EXP %d/%d%s" % [G.P.gold, G.P.exp, G.exp_need(G.P.lvl), "   [มีแต้มเหลือ กด I]" if G.P.sp > 0 or G.P.skp > 0 else ""]
	hud_zone.text = zone
	prompt.text = prompt_text
	hud_boost.visible = G.exp_boost_on()
	if hud_boost.visible:
		hud_boost.text = "★ EXP x%d  เหลือ %s%s" % [G.EXP_BOOST_MUL, G.mmss(G.exp_boost_left()), "  (หยุดเวลา)" if blocking() else ""]
	var q := G.current_quest()
	var t := ""
	if q.is_empty(): t = "[color=#ffd34d]ภารกิจหลักสำเร็จครบแล้ว![/color]"
	elif not G.P.quest.active: t = "[color=#ffd34d]ภารกิจ:[/color] คุยกับผู้ใหญ่บ้านฮิโรชิ"
	else:
		t = "[color=#ffd34d]%s[/color]" % q.title
		for r in G.quest_progress(q): t += "\n· %s %d/%d" % [G.ENEMIES[r.s].name, r.have, r.n]
		if G.quest_done(q): t += "\n[color=#9be37a]✔ กลับไปรายงานผู้ใหญ่บ้าน[/color]"
	if hud_quest.text != t: hud_quest.text = t

# ================= bug report (F8) =================
const BUG_DIR := "user://bug_reports"
var bug_shot: Image

## Grab the screen first (so the report shows what the player saw), then ask for a description
func open_bug_report() -> void:
	if modal.visible and modal_box.has_meta("bug"): return
	await RenderingServer.frame_post_draw
	bug_shot = get_viewport().get_texture().get_image()
	root.move_child(modal, root.get_child_count() - 1)
	var box := open_modal(640)
	box.set_meta("bug", true)
	_title(box, "แจ้งบั๊ก / ปัญหา")
	_center_label(box, "เล่าว่าเกิดอะไรขึ้น ทำอะไรอยู่ก่อนหน้า และคาดว่าควรเป็นแบบไหน", 15, UIKit.MUTED)
	var prev := TextureRect.new()
	prev.texture = ImageTexture.create_from_image(bug_shot)
	prev.custom_minimum_size = Vector2(368, 207)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(prev)
	var attach := CheckBox.new()
	attach.text = "แนบภาพหน้าจอนี้"
	attach.button_pressed = true
	attach.add_theme_color_override("font_color", UIKit.PAPER)
	attach.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(attach)
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(600, 90)
	te.placeholder_text = "เช่น สกิลสายเวทหลุดขอบจอตอนเรียนครบ 5 ตัว"
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.add_theme_stylebox_override("normal", UIKit.flat(Color("#f3e6d0"), Color("#8a6a3a"), 2, 6))
	te.add_theme_stylebox_override("focus", UIKit.flat(Color("#fff6e4"), UIKit.GOLD, 2, 6))
	te.add_theme_color_override("font_color", UIKit.INK)
	te.add_theme_color_override("font_placeholder_color", Color(0.3, 0.22, 0.15, 0.55))
	te.add_theme_font_size_override("font_size", 17)
	box.add_child(te)
	var status := _center_label(box, "", 14, Color("#ff9c8f"))
	_buttons(box, [["ส่งรายงาน", func() -> void:
		if te.text.strip_edges() == "":
			status.text = "พิมพ์รายละเอียดก่อนนะ"
			return
		var where := save_bug_report(te.text.strip_edges(), attach.button_pressed)
		close_modal()
		toast("บันทึกรายงานบั๊กแล้ว ขอบคุณมาก! (%s)" % where.get_file(), Color("#9be37a"))], ["ยกเลิก", close_modal]])
	te.grab_focus.call_deferred()

## Writes user://bug_reports/<time>/report.json (+ screenshot.png); returns the folder path
func save_bug_report(text: String, with_shot: bool) -> String:
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").replace("-", "")
	var dir := "%s%s/%s" % [BUG_DIR, "_test" if G.testing else "", stamp]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var b = main.battle
	var info := {
		"text": text, "time": Time.get_datetime_string_from_system(false, true),
		"version": ProjectSettings.get_setting("application/config/version", "dev"), "engine": Engine.get_version_info().string,
		"os": OS.get_name(), "window": str(get_window().size), "state": main.state, "slot": G.slot, "screenshot": with_shot,
	}
	if not G.P.is_empty():
		info["player"] = {"name": G.P.name, "cls": G.P.cls, "lvl": G.P.lvl, "hp": "%d/%d" % [G.P.hp, G.max_hp()], "mp": "%d/%d" % [G.P.mp, G.max_mp()],
			"gold": G.P.gold, "map": G.P.map, "pos": [roundi(G.P.x), roundi(G.P.y)], "skills": G.P.skills, "eq": G.P.eq}
	if main.state == "battle" and not b.e.is_empty():
		info["battle"] = {"stage": b.stage, "enemy": b.e.name, "enemy_hp": "%d/%d" % [b.e.hp, b.e.max], "tab": b.tab,
			"log": b.log_box.get_parsed_text().strip_edges().split("\n").slice(-20)}
	var f := FileAccess.open(dir + "/report.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(info, "  "))
	if with_shot and bug_shot: bug_shot.save_png(dir + "/screenshot.png")
	return ProjectSettings.globalize_path(dir)

# ================= ending + achievements =================
func announce_achievements(ids: Array) -> void:
	for id in ids:
		Sfx.play("level")
		toast("★ ปลดล็อกความสำเร็จ: %s" % G.ACHIEVEMENTS[id][0], UIKit.GOLD)

## Shown once per character when the shogun is down and the main story is done
func show_ending() -> void:
	if not G.game_clear_ready(): return
	G.P.cleared = true
	G.P.cleared_at = Time.get_datetime_string_from_system(false, true)
	var fresh := G.check_achievements()
	G.save_game()
	Sfx.play("win")
	Sfx.music("victory")
	root.move_child(modal, root.get_child_count() - 1)
	var box := open_modal(640)
	_title(box, "★ จบเกม ★", UIKit.GOLD)
	_center_label(box, "โชกุนเงา คาเงะโมริ ล้มลงแล้ว ปราสาทเงาสลายไปพร้อมรุ่งอรุณ\nหมู่บ้านใบไม้กลับมาสงบสุข และชื่อของ %s จะถูกเล่าขานต่อไป" % G.P.name, 17)
	var secs := int(G.P.get("play_sec", 0.0))
	_center_label(box, "สาย%s · Lv %d · ชนะ %d ครั้ง · แพ้ %d ครั้ง · เวลาเล่น %d:%02d ชม." % [G.cls().name, G.P.lvl, int(G.P.wins), int(G.P.get("deaths", 0)), secs / 3600, (secs / 60) % 60], 16, UIKit.MUTED)
	if fresh.size() > 0:
		box.add_child(UIKit.label("ความสำเร็จที่ปลดล็อก", 18, UIKit.GOLD, true))
		for id in fresh: row(box, "skills/upgrade.png", "★ " + G.ACHIEVEMENTS[id][0], G.ACHIEVEMENTS[id][1], [])
	_center_label(box, "จะทำอะไรต่อ? เกมยังเล่นต่อได้ ล่าค่าหัว สไลม์หายาก และตีอาวุธ +10 ได้ตามใจ", 15, UIKit.MUTED)
	_buttons(box, [["วาร์ปกลับหมู่บ้าน", func() -> void:
		close_modal()
		main.world.warp_to("village")], ["บันทึกและกลับหน้าหลัก", func() -> void:
		G.save_game()
		close_modal()
		main.to_title()], ["เล่นต่อที่นี่", func() -> void:
		close_modal()
		Sfx.music(G.THEMES[main.world.theme].music)]])

func _ach_rows(box: Container) -> void:
	box.add_child(UIKit.label("ปลดล็อกแล้ว %s (นับรวมทุกช่องเซฟ)" % G.ach_count(), 16, UIKit.MUTED))
	for id in G.ach_visible():
		var a: Array = G.ACHIEVEMENTS[id]
		var got: Dictionary = G.achievements.get(id, {})
		var sub: String = a[1]
		if not got.is_empty():
			sub += " · โดย %s (%s) %s" % [got.get("name", "?"), G.CLASSES.get(got.get("cls", ""), G.CLASSES.balanced).name, got.get("time", "")]
		row(box, "skills/upgrade.png" if not got.is_empty() else "skills/scroll.png", ("★ " if not got.is_empty() else "") + a[0] + ("" if not got.is_empty() else "  (ยังไม่ปลดล็อก)"), sub, [], "" if not got.is_empty() else "#555555")

func open_achievements() -> void:
	root.move_child(modal, root.get_child_count() - 1)
	var box := open_modal(680)
	_title(box, "ความสำเร็จ")
	_ach_rows(box)
	_buttons(box, [["ปิด", close_modal]])

func toast(msg: String, col := Color.WHITE) -> void:
	var pn := UIKit.panel("nine_path_bg.png", [16, 6, 16, 6])
	pn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := UIKit.label(msg, 18, col)
	pn.add_child(l)
	toast_box.add_child(pn)
	var tw := pn.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(pn, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pn.queue_free)

# ================= dialog =================
func _build_dialog() -> void:
	dialog = Control.new()
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dialog)
	var box := UIKit.panel("nine_path_bg.png", [16, 14, 20, 14])
	UIKit.anchor(box, [0.5, 1, 0.5, 1], [-530, -180, 530, -30])
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.custom_minimum_size = Vector2(1060, 150)
	dialog.add_child(box)
	var hb := UIKit.hbox(18)
	box.add_child(hb)
	var fp := PanelContainer.new()
	fp.add_theme_stylebox_override("panel", UIKit.sbox("FacesetBox.png", [6, 6, 6, 6], [10, 10, 10, 10], 2))
	hb.add_child(fp)
	dlg_face = UIKit.icon("actors/Master/face.png", 96)
	fp.add_child(dlg_face)
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	dlg_name = UIKit.label("", 20, UIKit.GOLD, true)
	v.add_child(dlg_name)
	dlg_text = UIKit.label("", 21)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(880, 60)
	v.add_child(dlg_text)
	var hint := UIKit.label("[E / Space / คลิก] ต่อไป", 13, UIKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: advance_dialog())
	dialog.visible = false

func show_dialog(name: String, actor: String, lines: Array, after := Callable()) -> void:
	dlg_lines = lines
	dlg_i = 0
	dlg_after = after
	dlg_name.text = name
	dlg_face.texture = Sprites.face(actor) if actor != "" else G.tex("obj/notice.png")
	dlg_text.text = lines[0]
	dialog.visible = true

func advance_dialog() -> void:
	if not dialog.visible: return
	Sfx.play("ui")
	dlg_i += 1
	if dlg_i < dlg_lines.size():
		dlg_text.text = dlg_lines[dlg_i]
		return
	dialog.visible = false
	if dlg_after.is_valid(): dlg_after.call()

# ================= modal =================
func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(cc)
	modal_panel = UIKit.panel("nine_path_bg.png", [26, 20, 26, 20])
	cc.add_child(modal_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(600, 0)
	modal_panel.add_child(sc)
	modal_box = UIKit.vbox(10)
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(modal_box)
	modal.visible = false

func open_modal(width := 600) -> VBoxContainer:
	UIKit.clear(modal_box)
	var sc: ScrollContainer = modal_panel.get_child(0)
	sc.custom_minimum_size = Vector2(width, 0)
	modal.visible = true
	await_resize.call_deferred()
	return modal_box

func await_resize() -> void:
	var sc: ScrollContainer = modal_panel.get_child(0)
	sc.custom_minimum_size.y = mini(int(modal_box.get_combined_minimum_size().y), 560)
	# wrapped labels only know their real height after one layout pass
	await get_tree().process_frame
	sc.custom_minimum_size.y = mini(int(modal_box.get_combined_minimum_size().y), 560)
	modal_panel.reset_size()

func close_modal() -> void:
	modal.visible = false

func _title(box: VBoxContainer, t: String, col := UIKit.GOLD) -> void:
	var l := UIKit.label(t, 26, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

func _center_label(box: Container, t: String, size := 18, col := UIKit.PAPER) -> Label:
	var l := UIKit.label(t, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

func _buttons(box: Container, defs: Array) -> HBoxContainer:
	var hb := UIKit.hbox(10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	for d in defs:
		var b := UIKit.button(d[0], d[1])
		if d.size() > 2: b.disabled = d[2]
		hb.add_child(b)
	box.add_child(hb)
	return hb

func message(t: String, lines: Array, col := UIKit.GOLD, after := Callable()) -> void:
	var box := open_modal(560)
	_title(box, t, col)
	for l in lines: _center_label(box, l)
	_buttons(box, [["ตกลง", func() -> void:
		close_modal()
		if after.is_valid(): after.call()]])

func row(box: Container, icon_path: String, title: String, sub: String, btns: Array, tint := "") -> HBoxContainer:
	var hb := UIKit.hbox(12)
	if icon_path != "":
		var bg := PanelContainer.new()
		bg.add_theme_stylebox_override("panel", UIKit.sbox("inventory_cell.png", [4, 4, 4, 4], [4, 4, 4, 4], 3))
		bg.add_child(UIKit.icon(icon_path, 36, tint))
		hb.add_child(bg)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(title, 18))
	if sub != "":
		var s := UIKit.rich(14)
		s.add_theme_color_override("default_color", UIKit.MUTED)
		s.text = RichTip.colorize(sub)
		v.add_child(s)
	hb.add_child(v)
	for d in btns:
		var b := UIKit.button(d[0], d[1], 16)
		if d.size() > 2: b.disabled = d[2]
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(b)
	box.add_child(hb)
	return hb

# ================= battle result / boss =================
func battle_result(r: Dictionary, done: Callable) -> void:
	var box := open_modal(560)
	if r.res == "win":
		_title(box, "ชัยชนะ!")
		if r.get("elite", false): _center_label(box, "★ ปราบ Elite สำเร็จ! ทอง x%d · EXP x%d" % [G.ELITE_GOLD, G.ELITE_LOOT], 19, Color("#e080ff"))
		Sfx.play("coin")
		_center_label(box, ("EXP +%d  (ใบเพิ่มค่าประสบการณ์ x%d)" % [r.exp, G.EXP_BOOST_MUL]) if r.get("boost", false) else "EXP +%d" % r.exp)
		_center_label(box, "\n".join(r.lines))
		if r.lv > 0:
			Sfx.play("level")
			_center_label(box, "เลเวลอัป! Lv %d (+%d แต้มอิสระ, +%d แต้มสกิล) · HP/MP ฟื้นเต็ม" % [G.P.lvl, r.lv, r.lv], 18, UIKit.GOLD)
		var q := G.current_quest()
		if not q.is_empty() and G.P.quest.active and G.quest_done(q):
			_center_label(box, "ภารกิจ \"%s\" สำเร็จ! กลับไปรายงานผู้ใหญ่บ้าน" % q.title, 17, Color("#9be37a"))
		if r.first_boss:
			var nxt := ""
			for m in G.MAPS:
				if G.MAPS[m].get("boss", 0) == r.stage: nxt = G.MAPS[m].next
			if nxt != "": _center_label(box, "ทางไปยัง %s เปิดแล้ว!" % G.MAPS[nxt].name, 19, UIKit.GOLD)
			else: _center_label(box, "คุณปราบโชกุนเงาได้แล้ว! หมู่บ้านใบไม้กลับมาสงบสุข\nเกมยังเล่นต่อได้ — ล่าค่าหัวและตีอาวุธ +10 ให้ครบ!", 19, UIKit.GOLD)
	elif r.res == "escaped":
		_title(box, "มันหนีไปแล้ว!", Color("#ffd34d"))
		_center_label(box, "ตีไม่ทันภายใน %d เทิร์น เลยไม่ได้อะไรเลย... ลองเตรียมสกิลแรงๆ แล้วมาใหม่" % G.RARE_TURNS)
	elif r.res == "lose":
		_title(box, "พ่ายแพ้...", Color("#ff8f80"))
		_center_label(box, "คุณฟื้นขึ้นที่โรงเตี๊ยมในหมู่บ้าน เสียทอง %d
เหลือ HP %d / MP %d (1%%) — พักโรงเตี๊ยม ใช้ยา หรือรอให้ฟื้นเองในหมู่บ้าน" % [r.lost, G.P.hp, G.P.mp])
		_center_label(box, "ลองอัปค่าสถานะ เรียนสกิล ตีอาวุธ หรือซื้ออุปกรณ์ใหม่", 15, UIKit.MUTED)
	else:
		done.call()
		close_modal()
		return
	_buttons(box, [["ไปต่อ", func() -> void:
		close_modal()
		done.call()]])

func boss_prompt(stage: int, fight: Callable, back: Callable) -> void:
	var st := G.enemy_stats(stage)
	var box := open_modal(560)
	var face := UIKit.icon("actors/%s/face.png" % G.ENEMIES[stage].actor, 96)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(face)
	_title(box, G.ENEMIES[stage].name, Color("#ff8f80"))
	_center_label(box, "\"เจ้าผ่านทางนี้ไปไม่ได้!\"")
	_center_label(box, "HP %d · ATK %d · แนะนำ Lv %d (คุณ Lv %d)" % [st.hp, st.atk, st.rec, G.P.lvl], 16, UIKit.MUTED)
	_buttons(box, [["ท้าสู้!", func() -> void:
		close_modal()
		fight.call()], ["ถอยก่อน", func() -> void:
		close_modal()
		back.call()]])

# ================= NPCs =================
func npc(id: String) -> void:
	match id:
		"merchant": show_dialog("พ่อค้า โทคิจิ", "OldMan2", ["ยินดีต้อนรับ! ของดีราคาถูกทั้งนั้น"], func() -> void: open_shop("buy"))
		"smith": show_dialog("ช่างตีดาบ กันเท็ตสึ", "Hunter", ["อาวุธดีต้องผ่านไฟและค้อนนับพันครั้ง", "เอาวัตถุดิบมา ข้าจะตีให้คมกว่าเดิม"], open_forge)
		"inn": open_inn()
		"master": show_dialog("อาจารย์นินจา ไรเดน", "Master", ["วิถีนินจาคือการฝึกฝนไม่สิ้นสุด", "จะเรียนวิชาใหม่ หรือจะล้างพลังเพื่อเริ่มฝึกใหม่?"], open_master)
		"elder": talk_elder()
		"board": open_board()
		"vampire": show_dialog("เคานต์ดราคุ", "Vampire", ["คืนแห่งวิญญาณมาเยือนแล้ว... เหล่าโยไคออกเพ่นพ่านทุกพื้นที่", "นำลูกอมฟักทองจากพวกมันมาแลกของวิเศษกับข้าสิ", "ประตูโทริอิทางเหนือของหมู่บ้านจะพาเจ้าไปสุสานโยไค ที่นั่นมีราชาภูตพรายขาวรออยู่"], open_event_shop)
		"wander": show_dialog("พ่อค้าเร่ ทานุ", "MaskGoldRacoon", ["เฮ้! นักเดินทาง ข้าแบกของหายากมาถึงกลางดงมอนสเตอร์เลยนะ", "อุปกรณ์เฉพาะสายของเจ้า หาซื้อในหมู่บ้านไม่ได้หรอก"], open_wander)
	if id.begins_with("warp:"): open_warp(id.substr(5))

const EVENT_ITEMS := {"hipotion": 2, "elixir": 6, "bomb": 2}

func open_event_shop() -> void:
	var have: int = int(G.P.mats.get("candy", 0))
	var box := open_modal(720)
	_title(box, "ร้านแลกของเคานต์ดราคุ   ลูกอม %d" % have, Color("#e0a0ff"))
	_center_label(box, "ล่าโยไคที่โผล่ช่วงเทศกาลเพื่อเก็บลูกอมฟักทอง · อุปกรณ์ใส่ได้ทุกสาย", 15, UIKit.MUTED)
	for id in G.GEAR:
		var g: Dictionary = G.GEAR[id]
		if g.get("shop", "") != "event": continue
		var own: bool = id in G.P.owned
		var gid: String = id
		var cost: int = g.candy
		row(box, g.icon, g.name, "%s · %s" % [G.SLOTNAME[g.slot], gear_desc(id)], [["มีแล้ว" if own else "ลูกอม %d" % cost, func() -> void:
			if int(G.P.mats.get("candy", 0)) < cost or gid in G.P.owned: return
			G.P.mats["candy"] = int(G.P.mats.candy) - cost
			G.P.owned.append(gid)
			G.save_game()
			Sfx.play("coin")
			toast("ได้รับ %s! (สวมใส่ได้ในกระเป๋า)" % g.name, Color("#e0a0ff"))
			open_event_shop(), own or have < cost]], g.get("tint", ""))
	for id in EVENT_ITEMS:
		var it: Dictionary = G.ITEMS[id]
		var cost: int = EVENT_ITEMS[id]
		var iid: String = id
		row(box, it.icon, "%s  (มี %d)" % [it.name, int(G.P.inv.get(id, 0))], it.desc, [["ลูกอม %d" % cost, func() -> void:
			if int(G.P.mats.get("candy", 0)) < cost: return
			G.P.mats["candy"] = int(G.P.mats.candy) - cost
			G.P.inv[iid] = int(G.P.inv.get(iid, 0)) + 1
			G.save_game()
			Sfx.play("coin")
			open_event_shop(), have < cost]])
	_buttons(box, [["ปิด", close_modal]])

const WANDER_ITEMS := ["hipotion", "ether", "elixir"]
const WANDER_MARKUP := 1.5

func open_wander() -> void:
	var zone: String = G.P.map
	var box := open_modal(720)
	_title(box, "ร้านพ่อค้าเร่ทานุ (%s)   ทอง %d" % [G.MAPS[zone].name, G.P.gold])
	_center_label(box, "ของหายากประจำพื้นที่ · อุปกรณ์เฉพาะสาย %s และของทั่วไป" % G.cls().name, 15, UIKit.MUTED)
	box.add_child(UIKit.label("อุปกรณ์หายาก", 17, UIKit.GOLD))
	for id in G.GEAR:
		var g: Dictionary = G.GEAR[id]
		if g.get("shop", "") != zone or not G.can_equip(id): continue
		var own: bool = id in G.P.owned
		var gid: String = id
		row(box, g.icon, g.name + ("  [เฉพาะสาย %s]" % G.cls().name if g.has("cls") else ""), "%s · %s" % [G.SLOTNAME[g.slot], gear_desc(id)],
			[["มีแล้ว" if own else "%d ทอง" % g.price, func() -> void:
				if G.P.gold < g.price or gid in G.P.owned: return
				G.P.gold -= g.price
				G.P.owned.append(gid)
				G.P.eq[g.slot] = gid
				G.fix_player()
				G.save_game()
				Sfx.play("coin")
				toast("สวมใส่ %s แล้ว" % g.name, UIKit.GOLD)
				open_wander(), own or G.P.gold < g.price]], g.get("tint", ""))
	box.add_child(UIKit.label("เสบียงกลางป่า (แพงกว่าในหมู่บ้าน)", 17, UIKit.GOLD))
	for id in WANDER_ITEMS:
		var it: Dictionary = G.ITEMS[id]
		var price := roundi(it.price * WANDER_MARKUP)
		var iid: String = id
		row(box, it.icon, "%s  (มี %d)" % [it.name, int(G.P.inv.get(id, 0))], it.desc, [["%d ทอง" % price, func() -> void:
			if G.P.gold < price: return
			G.P.gold -= price
			G.P.inv[iid] = int(G.P.inv.get(iid, 0)) + 1
			G.save_game()
			Sfx.play("coin")
			open_wander(), G.P.gold < price]])
	_buttons(box, [["ปิด", close_modal]])

func open_warp(here: String) -> void:
	var box := open_modal(640)
	_title(box, "ศาลวาร์ป   ทอง %d" % G.P.gold, Color("#9fe8ff"))
	_center_label(box, "วาร์ปไปศาลที่เปิดใช้แล้ว · ยิ่งไกลยิ่งแพง (%d ทองต่อช่วง)" % G.WARP_STEP, 15, UIKit.MUTED)
	for w in G.WARPS:
		var wid: String = w.id
		var on := G.warp_on(wid)
		var cost := G.warp_cost(here, wid)
		var sub := "อยู่ที่นี่" if wid == here else ("วาร์ปได้" if on else "ยังไม่ได้เปิดใช้ — เดินไปแตะศาลนี้ก่อน")
		var label := "อยู่ที่นี่" if wid == here else ("%d ทอง" % cost if on else "ล็อก")
		row(box, "obj/statue2.png", G.warp_name(wid), sub, [[label, func() -> void:
			if G.P.gold < cost: return
			G.P.gold -= cost
			close_modal()
			main.world.warp_to(wid), wid == here or not on or G.P.gold < cost]], "" if on else "#777777")
	_buttons(box, [["ปิด", close_modal]])

func talk_elder() -> void:
	var q := G.current_quest()
	var n := "ผู้ใหญ่บ้าน ฮิโรชิ"
	if q.is_empty():
		show_dialog(n, "OldMan3", ["เจ้าคือวีรบุรุษของหมู่บ้านใบไม้!", "ไปล่าค่าหัวที่กระดานหรือฝึกฝนต่อได้ตามใจเลย"])
	elif not G.P.quest.active:
		var lines: Array = q.talk.duplicate()
		lines.append("รับภารกิจ: " + q.title)
		show_dialog(n, "OldMan3", lines, func() -> void:
			G.P.quest.active = true
			G.P.quest.base = G.P.kills.duplicate()
			G.save_game()
			Sfx.play("accept")
			toast("รับภารกิจ: " + q.title, UIKit.GOLD))
	elif G.quest_done(q):
		show_dialog(n, "OldMan3", ["ยอดเยี่ยมมาก! เจ้าทำสำเร็จแล้ว", "นี่คือรางวัลของเจ้า"], func() -> void:
			var lines := G.add_loot({"gold": q.reward.gold, "items": q.reward.items})
			var lv := G.gain_exp(q.reward.exp)
			G.P.quest.i += 1
			G.P.quest.active = false
			G.save_game()
			Sfx.play("level" if lv > 0 else "coin")
			var extra := ["EXP +%d" % q.reward.exp, "\n".join(lines)]
			if lv > 0: extra.append("เลเวลอัป! Lv %d" % G.P.lvl)
			message("ภารกิจสำเร็จ!", [q.title] + extra, UIKit.GOLD, func() -> void:
				if G.game_clear_ready(): show_ending()
				else: talk_elder()))
	else:
		var prog := []
		for r in G.quest_progress(q): prog.append("%s %d/%d" % [G.ENEMIES[r.s].name, r.have, r.n])
		show_dialog(n, "OldMan3", ["ภารกิจ \"%s\" ยังไม่สำเร็จ" % q.title, " · ".join(prog)])

func open_inn() -> void:
	var cost: int = 5 + G.P.lvl * 3
	var box := open_modal(520)
	box.add_child(_face_center("Woman"))
	_title(box, "โรงเตี๊ยม โอฮานะ")
	_center_label(box, "\"พักผ่อนสักคืนไหมคะ? ค่าห้อง %d ทองค่ะ\"" % cost)
	_center_label(box, "ฟื้น HP/MP เต็ม และบันทึกเกม", 15, UIKit.MUTED)
	_buttons(box, [["พักผ่อน (%d ทอง)" % cost, func() -> void:
		G.P.gold -= cost
		G.P.hp = G.max_hp()
		G.P.mp = G.max_mp()
		G.save_game()
		Sfx.play("heal")
		message("หลับสบาย...", ["HP/MP ฟื้นเต็มแล้ว · บันทึกเกมแล้ว"]), G.P.gold < cost], ["ไว้ก่อน", close_modal]])

func _face_center(actor: String) -> Control:
	var f := UIKit.icon("actors/%s/face.png" % actor, 80)
	f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return f

func open_master() -> void:
	var used := G.free_spent()
	var cost: int = 50 * G.P.lvl
	var box := open_modal(560)
	box.add_child(_face_center("Master"))
	_title(box, "อาจารย์ไรเดน")
	_center_label(box, "แต้มอิสระ %d · แต้มสกิล %d" % [G.P.sp, G.P.skp])
	_buttons(box, [["เรียนวิชา (สกิล)", func() -> void:
		close_modal()
		open_menu("skills")], ["อัปค่าสถานะ", func() -> void:
		close_modal()
		open_menu("stats")]])
	_center_label(box, "ล้างแต้มค่าสถานะ (คืน %d แต้ม) ราคา %d ทอง" % [used, cost], 15, UIKit.MUTED)
	var sk_used := G.skill_spent()
	var sk_cost := G.skill_reset_cost()
	_center_label(box, "ล้างแต้มสกิล (คืน %d แต้ม) ราคา %d ทอง" % [sk_used, sk_cost], 15, UIKit.MUTED)
	_buttons(box, [["ล้างค่าสถานะ", func() -> void:
		_confirm_reset("stats", open_master), G.P.gold < cost or used == 0], ["ล้างสกิล", func() -> void:
		_confirm_reset("skills", open_master), G.P.gold < sk_cost or sk_used == 0], ["ปิด", close_modal]])

## Confirm dialog for paid resets; back() reopens whatever screen asked
func _confirm_reset(what: String, back: Callable) -> void:
	var stats := what == "stats"
	var n := G.free_spent() if stats else G.skill_spent()
	var cost := G.stat_reset_cost() if stats else G.skill_reset_cost()
	var box := open_modal(520)
	_title(box, "ล้างแต้มค่าสถานะ" if stats else "ล้างแต้มสกิล")
	_center_label(box, ("คืนแต้มอิสระ %d แต้ม ค่าสถานะกลับเป็นค่าพื้นฐานของสาย" if stats else "คืนแต้มสกิล %d แต้ม สกิลกลับเป็นสกิลเริ่มต้นของสาย") % n)
	_center_label(box, "ราคา %d ทอง  (มี %d ทอง)" % [cost, G.P.gold], 17, UIKit.GOLD)
	_buttons(box, [["ยืนยัน", func() -> void:
		if G.P.gold < cost or n == 0: return
		if stats: G.reset_stats()
		else: G.reset_skills()
		Sfx.play("magic")
		toast("ล้างแต้มแล้ว ได้คืน %d แต้ม" % n, UIKit.GOLD)
		back.call(), G.P.gold < cost or n == 0], ["ยกเลิก", back]])

func _reset_from_menu(what: String) -> void:
	menu.visible = false
	_confirm_reset(what, func() -> void:
		close_modal()
		open_menu(what))

# ---------- shop ----------
func open_shop(tab: String) -> void:
	var box := open_modal(680)
	_title(box, "ร้านค้าโทคิจิ   ทอง %d" % G.P.gold)
	var tabs := [["ยา/ไอเทม", "buy"], ["อุปกรณ์", "gear"], ["ขายของ", "sell"]]
	var hb := UIKit.hbox(8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	for t in tabs:
		var tt: String = t[1]
		var b := UIKit.button(t[0], func() -> void: open_shop(tt), 16)
		if tt == tab: b.add_theme_stylebox_override("normal", UIKit.sbox("button_hover.png", [4, 3, 4, 3], [14, 6, 14, 7]))
		hb.add_child(b)
	box.add_child(hb)
	if tab == "buy":
		for id in G.ITEMS:
			var it: Dictionary = G.ITEMS[id]
			if it.price <= 0: continue
			var iid: String = id
			row(box, it.icon, "%s  (มี %d)" % [it.name, int(G.P.inv.get(id, 0))], it.desc,
				[["%d ทอง" % it.price, func() -> void: _buy(iid, 1), G.P.gold < it.price], ["×5", func() -> void: _buy(iid, 5), G.P.gold < it.price * 5]])
	elif tab == "gear":
		for slot in G.SLOTS:
			box.add_child(UIKit.label(G.SLOTNAME[slot], 17, UIKit.GOLD))
			for id in G.GEAR:
				var g: Dictionary = G.GEAR[id]
				if g.slot != slot or g.price == 0 or g.has("shop"): continue
				var own: bool = id in G.P.owned
				var gid: String = id
				row(box, g.icon, g.name, gear_desc(id), [["มีแล้ว" if own else "%d ทอง" % g.price, func() -> void:
					G.P.gold -= g.price
					G.P.owned.append(gid)
					G.P.eq[g.slot] = gid
					G.fix_player()
					G.save_game()
					Sfx.play("coin")
					toast("สวมใส่ %s แล้ว" % g.name, UIKit.GOLD)
					open_shop("gear"), own or G.P.gold < g.price]], g.get("tint", ""))
	else:
		var any := false
		for id in G.STAT_TOMES.values():
			var tn: int = int(G.P.inv.get(id, 0))
			if tn <= 0: continue
			any = true
			var tid: String = id
			row(box, G.ITEMS[id].icon, "%s  (มี %d)" % [G.ITEMS[id].name, tn], G.ITEMS[id].desc, [["ขาย %d ทอง" % G.ITEMS[id].sell, func() -> void:
				_sell_tome(tid)
				open_shop("sell")]])
		for id in G.P.owned.duplicate():
			if id in G.P.eq.values(): continue
			any = true
			var g: Dictionary = G.GEAR[id]
			var gid: String = id
			row(box, g.icon, G.gname(id), gear_desc(id), [["ขาย %d ทอง" % G.gear_sell_price(id), func() -> void:
				G.sell_gear(gid)
				G.save_game()
				Sfx.play("coin")
				open_shop("sell")]], g.get("tint", ""))
		for id in G.MATS:
			var n: int = int(G.P.mats.get(id, 0))
			if n <= 0: continue
			any = true
			var m: Dictionary = G.MATS[id]
			var mid: String = id
			row(box, m.icon, "%s ×%d" % [m.name, n], "ขายได้ %d ทอง/ชิ้น" % m.price,
				[["ขาย 1", func() -> void: _sell(mid, 1)], ["ขายหมด", func() -> void: _sell(mid, 999)]])
		if not any: _center_label(box, "ไม่มีวัตถุดิบ — ได้จากการปราบศัตรู", 16, UIKit.MUTED)
	_buttons(box, [["ปิด", close_modal]])

func _buy(id: String, n: int) -> void:
	var it: Dictionary = G.ITEMS[id]
	if G.P.gold < it.price * n: return
	G.P.gold -= it.price * n
	G.P.inv[id] = int(G.P.inv.get(id, 0)) + n
	G.save_game()
	Sfx.play("coin")
	open_shop("buy")

func _sell(id: String, n: int) -> void:
	n = mini(n, int(G.P.mats.get(id, 0)))
	G.P.mats[id] = int(G.P.mats[id]) - n
	G.P.gold += G.MATS[id].price * n
	G.save_game()
	Sfx.play("coin")
	open_shop("sell")

func gear_desc(id: String) -> String:
	var g: Dictionary = G.GEAR[id]
	var s := G.gstat(id)
	var t: String
	match g.slot:
		"weapon": t = "พลังดาบ +%d" % s.atk
		"throw": t = "พลังปา +%d" % s.atk
		"charm": t = "พลังเวท +%d · MP +%d" % [s.atk, s.mp]
		_: t = "ป้องกัน +%d · HP +%d" % [s.def, s.hp]
	for k in g.get("bonus", {}): t += " · %s +%d" % [k.to_upper(), g.bonus[k]]
	if g.has("crit"): t += " · คริ +%d%%" % g.crit
	if g.has("dodge"): t += " · หลบ +%d%%" % g.dodge
	if g.has("cls"):
		var names := []
		for c in g.cls: names.append(G.CLASSES[c].name)
		t += " · เฉพาะสาย " + ", ".join(names)
	return t

# ---------- forge ----------
func open_forge(msg := "") -> void:
	var box := open_modal(700)
	_title(box, "โรงตีดาบกันเท็ตสึ   ทอง %d" % G.P.gold)
	_center_label(box, "ตีเสริมอุปกรณ์ที่สวมใส่อยู่ · ถ้าล้มเหลวจะเสียทองและวัตถุดิบ แต่ระดับไม่ลด", 14, UIKit.MUTED)
	if msg != "": _center_label(box, msg, 19, UIKit.GOLD)
	for slot in G.SLOTS:
		var id: String = G.P.eq[slot]
		var r := G.forge_req(id)
		var sub := gear_desc(id)
		if r.is_empty():
			row(box, G.GEAR[id].icon, "%s: %s" % [G.SLOTNAME[slot], G.gname(id)], sub + "\nตีถึงขีดสุด +10 แล้ว!", [], G.GEAR[id].get("tint", ""))
			continue
		var cur := int(G.P.up.get(id, 0))
		G.P.up[id] = cur + 1
		var after := gear_desc(id)
		G.P.up[id] = cur
		if cur == 0: G.P.up.erase(id)
		var need := []
		for k in r.mats: need.append("%s %d/%d" % [G.MATS[k].name, int(G.P.mats.get(k, 0)), r.mats[k]])
		var gid := id
		row(box, G.GEAR[id].icon, "%s: %s" % [G.SLOTNAME[slot], G.gname(id)],
			"%s → %s\nต้องใช้ %d ทอง · %s · สำเร็จ %d%%" % [sub, after, r.gold, " · ".join(need), r.chance],
			[["ตี +%d" % (r.u + 1), func() -> void: _forge(gid), not G.can_forge(r)]], G.GEAR[id].get("tint", ""))
	_buttons(box, [["ปิด", close_modal]])

func _forge_done_check() -> void:
	announce_achievements(G.check_achievements())

func _forge(id: String) -> void:
	var r := G.forge_req(id)
	if not G.can_forge(r): return
	G.P.gold -= r.gold
	for k in r.mats: G.P.mats[k] = int(G.P.mats[k]) - r.mats[k]
	var msg: String
	if randf() * 100 < r.chance:
		G.P.up[id] = r.u + 1
		G.fix_player()
		Sfx.play("powerup")
		msg = "สำเร็จ! " + G.gname(id)
	else:
		Sfx.play("lose")
		msg = "ล้มเหลว... อุปกรณ์ยังคงเป็น +%d" % r.u
	G.save_game()
	open_forge(msg)
	_forge_done_check()

# ---------- bounty board ----------
func open_board() -> void:
	G.ensure_bounties()
	var box := open_modal(640)
	_title(box, "กระดานค่าหัว")
	_center_label(box, "ทำได้ไม่จำกัด · นับเฉพาะศัตรูที่ปราบหลังติดประกาศ", 14, UIKit.MUTED)
	for i in G.P.bounties.size():
		var b: Dictionary = G.P.bounties[i]
		var done := G.bounty_done(b)
		var what: String
		var ic: String
		if b.type == "kill":
			what = "ปราบ %s" % G.ENEMIES[int(b.s)].name
			ic = "actors/%s/face.png" % G.ENEMIES[int(b.s)].actor
		else:
			what = "ส่งมอบ %s" % G.MATS[b.m].name
			ic = G.MATS[b.m].icon
		var bi: int = i
		row(box, ic, "%s  %d/%d" % [what, G.bounty_have(b), b.n], "รางวัล %d ทอง · EXP %d" % [b.gold, b.exp],
			[["รับรางวัล", func() -> void: _claim(bi), not done], ["เปลี่ยน (20)", func() -> void:
				G.P.gold -= 20
				G.P.bounties[bi] = G.gen_bounty()
				G.save_game()
				open_board(), G.P.gold < 20]])
	_buttons(box, [["ปิด", close_modal]])

func _claim(i: int) -> void:
	var b: Dictionary = G.P.bounties[i]
	if not G.bounty_done(b): return
	if b.type == "mat": G.P.mats[b.m] = int(G.P.mats[b.m]) - b.n
	G.P.gold += b.gold
	var lv := G.gain_exp(b.exp)
	G.P.bounties.remove_at(i)
	G.ensure_bounties()
	G.save_game()
	Sfx.play("coin")
	toast("ได้รับ %d ทอง · EXP %d%s" % [b.gold, b.exp, " · เลเวลอัป!" if lv > 0 else ""], UIKit.GOLD)
	open_board()

# ================= menu (I) =================
func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var pn := UIKit.panel("nine_path_bg.png", [22, 16, 22, 16])
	UIKit.anchor(pn, [0.5, 0.5, 0.5, 0.5], [-600, -336, 600, 336])
	menu.add_child(pn)
	var v := UIKit.vbox(10)
	pn.add_child(v)
	menu_tabs = UIKit.hbox(8)
	v.add_child(menu_tabs)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1150, 580)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	menu_body = UIKit.vbox(10)
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(menu_body)
	menu.visible = false

func open_menu(tab := "") -> void:
	if tab != "": menu_tab = tab
	menu.visible = true
	Sfx.play("ui")
	render_menu()

func close_menu() -> void:
	menu.visible = false

func render_menu() -> void:
	UIKit.clear(menu_tabs)
	for t in [["stats", "สถานะ"], ["skills", "สกิล"], ["bag", "กระเป๋า"], ["quests", "ภารกิจ"], ["beast", "สมุดศัตรู"], ["sys", "ระบบ"]]:
		var tt: String = t[0]
		var b := UIKit.button(t[1], func() -> void:
			menu_tab = tt
			render_menu(), 17)
		if tt == menu_tab: b.add_theme_stylebox_override("normal", UIKit.sbox("button_hover.png", [4, 3, 4, 3], [14, 6, 14, 7]))
		menu_tabs.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_tabs.add_child(sp)
	menu_tabs.add_child(UIKit.label("ทอง %d" % G.P.gold, 18, UIKit.GOLD))
	menu_tabs.add_child(UIKit.button("ปิด (I/Esc)", close_menu, 16))
	UIKit.clear(menu_body)
	doll_spr = null
	G.fix_player()
	match menu_tab:
		"stats": _menu_stats()
		"skills": _menu_skills()
		"bag": _menu_bag()
		"quests": _menu_quests()
		"beast": _menu_beast()
		"sys": _menu_sys()

func _menu_stats() -> void:
	var hb := UIKit.hbox(40)
	menu_body.add_child(hb)
	var left := UIKit.vbox(6)
	left.custom_minimum_size = Vector2(560, 0)
	hb.add_child(left)
	var th := UIKit.hbox(16)
	left.add_child(th)
	th.add_child(UIKit.label("ค่าสถานะ  (แต้มอิสระเหลือ %d)" % G.P.sp, 22, UIKit.GOLD, true))
	var rs := UIKit.button("ล้างแต้ม (%d ทอง)" % G.stat_reset_cost(), func() -> void: _reset_from_menu("stats"), 15)
	rs.disabled = G.free_spent() == 0 or G.P.gold < G.stat_reset_cost()
	th.add_child(rs)
	var grow := []
	for k in G.cls().grow: grow.append("%s +%d" % [k.to_upper(), G.cls().grow[k]])
	left.add_child(UIKit.label("สาย %s (%s) · ทุกเลเวลได้ %s อัตโนมัติ + แต้มอิสระ 1" % [G.cls().name, G.cls().en, ", ".join(grow)], 15, UIKit.MUTED))
	var info := {"str": ["STR พลัง", "เพิ่มพลังโจมตีดาบ", "skills/attack_up.png"], "agi": ["AGI ความไว", "เพิ่มพลังปา คริติคอล และการหลบ", "skills/shuriken.png"],
		"int": ["INT ปัญญา", "เพิ่มพลังเวท MP และการฟื้นฟู", "skills/orb_fire.png"], "vit": ["VIT ร่างกาย", "เพิ่ม HP และพลังป้องกัน", "skills/defense_up.png"]}
	for k in G.STATS:
		var kk: String = k
		var tb: int = int(G.P.get("tome", {}).get(k, 0))
		var gb: int = G.stat(k) - int(G.P[k]) - tb
		var extra := ""
		if gb != 0: extra += "  (+%d อุปกรณ์)" % gb
		if tb != 0: extra += "  (+%d คัมภีร์)" % tb
		row(left, info[k][2], "%s   %d%s" % [info[k][0], G.P[k], extra], info[k][1],
			[["+1", func() -> void: _add_stat(kk, 1), G.P.sp < 1], ["+5", func() -> void: _add_stat(kk, 5), G.P.sp < 5]])
	var right := UIKit.vbox(6)
	hb.add_child(right)
	right.add_child(UIKit.label("ค่าต่อสู้", 22, UIKit.GOLD, true))
	for pair in [["HP", "%d/%d" % [G.P.hp, G.max_hp()]], ["MP", "%d/%d" % [G.P.mp, G.max_mp()]], ["พลังดาบ", str(roundi(G.melee_pow()))],
			["พลังปา", str(roundi(G.ranged_pow()))], ["พลังเวท", str(roundi(G.magic_pow()))], ["ป้องกัน", str(G.p_def())],
			["คริติคอล", "%.1f%%" % G.crit_chance()], ["ชนะทั้งหมด", str(G.P.wins)], ["เลเวล", "%d  (EXP %d/%d)" % [G.P.lvl, G.P.exp, G.exp_need(G.P.lvl)]]]:
		var r := UIKit.hbox(10)
		var a := UIKit.label(pair[0], 18, UIKit.MUTED)
		a.custom_minimum_size = Vector2(160, 0)
		r.add_child(a)
		r.add_child(UIKit.label(pair[1], 18))
		right.add_child(r)

func _add_stat(k: String, n: int) -> void:
	n = mini(n, G.P.sp)
	if n < 1: return
	G.P[k] += n
	G.P.sp -= n
	if k == "vit": G.P.hp += n * 10
	if k == "int": G.P.mp += n * 5
	G.save_game()
	Sfx.play("accept")
	render_menu()

## Prerequisite lines behind the skill-tree nodes
class TreeLines extends Control:
	var lines: Array = []
	func _draw() -> void:
		for l in lines: draw_line(l[0], l[1], l[2], 4.0, true)

const KIND_TXT := {"melee": "สกิลโจมตี · ระยะประชิด", "ranged": "สกิลโจมตี · ระยะไกล", "magic": "สกิลโจมตี · เวทมนตร์",
	"heal": "สกิลฟื้นฟู", "buff": "สกิลบัพตัวเอง (กดใช้)"}
const PT_TXT := {"stat": "Passive · เพิ่มค่าสถานะถาวร", "debuff": "Passive · ติดดีบัพให้ศัตรูเมื่อโจมตีโดน", "buff": "Passive · บัพตัวเองตอนเริ่มต่อสู้"}
const NODE := 60
const COL_W := 112
const ROW_H := 92
var skill_sel := "slash"

func _skill_node(id: String) -> Button:
	var s: Dictionary = G.SKILLS[id]
	var lv: int = int(G.P.skills.get(id, 0))
	var block := G.skill_block(id)
	var passive: bool = s.kind == "passive"
	var b := RichTip.TipButton.new()
	b.custom_minimum_size = Vector2(NODE, NODE)
	b.size = Vector2(NODE, NODE)
	b.icon = UIKit.scaled("skills/%s.png" % s.icon, 2)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	var border := Color("#5a4636")
	if lv > 0: border = UIKit.GOLD
	elif block == "": border = Color("#6fdc6f")
	var r := NODE / 2 if passive else 8
	var bg := Color("#2e2140") if passive else Color("#2a1a12")
	var sel := 4 if id == skill_sel else 3
	b.add_theme_stylebox_override("normal", UIKit.flat(bg, Color.WHITE if id == skill_sel else border, sel, r))
	b.add_theme_stylebox_override("hover", UIKit.flat(bg.lightened(0.15), Color.WHITE, 3, r))
	b.add_theme_stylebox_override("pressed", UIKit.flat(bg, Color.WHITE, 4, r))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if lv == 0 and block != "" and block != "แต้มสกิลไม่พอ": b.modulate = Color(0.5, 0.5, 0.5)
	b.tooltip_text = "%s  Lv %d/%d\n%s" % [s.name, lv, G.SKILL_MAX, G.skill_desc(id, maxi(lv, 1))]
	var l := UIKit.label("%d/%d" % [lv, G.SKILL_MAX], 13, UIKit.GOLD if lv > 0 else Color.WHITE, true)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = Vector2(NODE - 30, NODE - 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		skill_sel = id
		render_menu())
	return b

func _menu_skills() -> void:
	if not G.SKILLS.has(skill_sel): skill_sel = "slash"
	var head := UIKit.hbox(20)
	menu_body.add_child(head)
	head.add_child(UIKit.label("ต้นไม้สกิล", 22, UIKit.GOLD, true))
	head.add_child(UIKit.label("แต้มสกิลเหลือ %d  (ได้ 1 แต้มทุกเลเวล)" % G.P.skp, 18, Color("#9be37a") if G.P.skp > 0 else UIKit.MUTED))
	var rs := UIKit.button("ล้างแต้มสกิล (%d ทอง)" % G.skill_reset_cost(), func() -> void: _reset_from_menu("skills"), 15)
	rs.disabled = G.skill_spent() == 0 or G.P.gold < G.skill_reset_cost()
	head.add_child(rs)
	menu_body.add_child(UIKit.label("■ สกิลกดใช้   ● Passive   กรอบเขียว = เรียนได้   กรอบทอง = เรียนแล้ว   ·   ล้างแต้มได้ที่นี่หรือที่อาจารย์ไรเดน", 15, UIKit.MUTED))
	var hb := UIKit.hbox(14)
	menu_body.add_child(hb)
	for tree in ["katana", "shuriken", "ninjutsu"]:
		var col := PanelContainer.new()
		var sb := UIKit.flat(Color(0, 0, 0, 0.28), Color("#5a4636"), 2, 10)
		sb.set_content_margin_all(8)
		col.add_theme_stylebox_override("panel", sb)
		hb.add_child(col)
		var v := UIKit.vbox(6)
		col.add_child(v)
		var t := UIKit.label(G.TREES[tree], 20, UIKit.GOLD, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var canvas := TreeLines.new()
		canvas.custom_minimum_size = Vector2(COL_W + NODE + 40, ROW_H * 4 + NODE + 8)
		v.add_child(canvas)
		for id in G.SKILLS:
			var s: Dictionary = G.SKILLS[id]
			if s.tree != tree: continue
			var at := Vector2(20 + s.pos[0] * COL_W, 4 + s.pos[1] * ROW_H)
			for q in s.pre:
				var qs: Dictionary = G.SKILLS[q]
				var from := Vector2(20 + qs.pos[0] * COL_W, 4 + qs.pos[1] * ROW_H) + Vector2(NODE, NODE) / 2
				var lit: bool = int(G.P.skills.get(q, 0)) > 0
				canvas.lines.append([from, at + Vector2(NODE, NODE) / 2, UIKit.GOLD if lit else Color("#4a3a2c")])
			var n := _skill_node(id)
			n.position = at
			canvas.add_child(n)
		canvas.queue_redraw()
	hb.add_child(_skill_detail(skill_sel))

func _skill_detail(id: String) -> Control:
	var s: Dictionary = G.SKILLS[id]
	var lv: int = int(G.P.skills.get(id, 0))
	var block := G.skill_block(id)
	var pc := PanelContainer.new()
	var sb := UIKit.flat(Color(0, 0, 0, 0.35), Color("#8a6a3a"), 2, 10)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(330, 0)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(8)
	pc.add_child(v)
	var top := UIKit.hbox(12)
	v.add_child(top)
	top.add_child(UIKit.icon("skills/%s.png" % s.icon, 64))
	var tv := UIKit.vbox(2)
	top.add_child(tv)
	var nm := UIKit.label(s.name, 22, UIKit.GOLD, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(220, 0)
	tv.add_child(nm)
	tv.add_child(UIKit.label("เลเวล %d / %d" % [lv, G.SKILL_MAX], 17))
	var kind: String = PT_TXT[s.pt] if s.kind == "passive" else KIND_TXT[s.kind]
	v.add_child(UIKit.label(kind + ("" if s.kind == "passive" else "  ·  MP %d" % s.mp), 15, Color("#b9a8ff") if s.kind == "passive" else Color("#9fd3ff")))
	var r := UIKit.rich(16)
	r.custom_minimum_size = Vector2(300, 0)
	var txt := ""
	if lv > 0: txt += "[color=#ffd34d]ตอนนี้:[/color] %s\n" % RichTip.colorize(G.skill_desc(id, lv))
	if lv < G.SKILL_MAX: txt += "[color=#9be37a]%s:[/color] %s\n" % ["เลเวลถัดไป" if lv > 0 else "เมื่อเรียน", RichTip.colorize(G.skill_desc(id, lv + 1))]
	txt += "\n[color=#c9b49a]เงื่อนไข[/color]\n"
	txt += "%s เลเวลผู้เล่น %d\n" % ["[color=#7dff8a]✔[/color]" if G.P.lvl >= s.req else "[color=#ff7a6a]✘[/color]", s.req]
	for q in s.pre:
		var ok: bool = int(G.P.skills.get(q, 0)) > 0
		txt += "%s เรียน %s\n" % ["[color=#7dff8a]✔[/color]" if ok else "[color=#ff7a6a]✘[/color]", G.SKILLS[q].name]
	r.text = txt
	v.add_child(r)
	var btn := UIKit.button(("อัปเลเวล" if lv > 0 else "เรียนสกิล") + "  (ใช้ 1 แต้ม)", func() -> void:
		if G.skill_block(id) != "": return
		G.P.skills[id] = lv + 1
		G.P.skp -= 1
		G.fix_player()
		G.save_game()
		Sfx.play("magic")
		render_menu(), 18)
	btn.disabled = block != ""
	v.add_child(btn)
	if block != "": v.add_child(UIKit.label(block, 15, Color("#ff9c8f")))
	return pc

func _menu_quests() -> void:
	var q := G.current_quest()
	menu_body.add_child(UIKit.label("ภารกิจหลัก", 22, UIKit.GOLD, true))
	if q.is_empty(): menu_body.add_child(UIKit.label("ทำภารกิจหลักครบทั้งหมดแล้ว!", 18, Color("#9be37a")))
	elif not G.P.quest.active: menu_body.add_child(UIKit.label("คุยกับผู้ใหญ่บ้านฮิโรชิ (บ้านขวาสุดแถวบน) เพื่อรับภารกิจ \"%s\"" % q.title, 18))
	else:
		menu_body.add_child(UIKit.label(q.title, 20))
		var t := UIKit.label(" ".join(q.talk), 15, UIKit.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		menu_body.add_child(t)
		for r in G.quest_progress(q):
			row(menu_body, "actors/%s/face.png" % G.ENEMIES[r.s].actor, "%s  %d/%d" % [G.ENEMIES[r.s].name, r.have, r.n], "", [])
		menu_body.add_child(UIKit.label("รางวัล %d ทอง · EXP %d" % [q.reward.gold, q.reward.exp], 16, UIKit.GOLD))
	menu_body.add_child(UIKit.label("ภารกิจหลักที่ทำสำเร็จ %d/%d" % [G.P.quest.i, G.MAIN_QUESTS.size()], 15, UIKit.MUTED))
	menu_body.add_child(UIKit.label("ค่าหัว (รับรางวัลที่กระดานกลางหมู่บ้าน)", 22, UIKit.GOLD, true))
	G.ensure_bounties()
	for b in G.P.bounties:
		var what: String = ("ปราบ " + G.ENEMIES[int(b.s)].name) if b.type == "kill" else ("ส่งมอบ " + G.MATS[b.m].name)
		menu_body.add_child(UIKit.label("· %s  %d/%d" % [what, G.bounty_have(b), b.n], 17))

func _menu_beast() -> void:
	menu_body.add_child(UIKit.label("สมุดบันทึกศัตรู", 22, UIKit.GOLD, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	menu_body.add_child(grid)
	for s in range(1, G.ENEMIES.size()):
		var e: Dictionary = G.ENEMIES[s]
		var k: int = int(G.P.kills.get(str(s), 0))
		var st := G.enemy_stats(s)
		var zone := ""
		for m in G.MAPS:
			if s in G.MAPS[m].get("enemies", []) or G.MAPS[m].get("boss", 0) == s: zone = G.MAPS[m].name
		var drops := []
		for d in e.drops: drops.append(G.MATS[d[0]].name)
		var pn := UIKit.panel("nine_path_bg_2.png", [12, 10, 12, 10])
		pn.custom_minimum_size = Vector2(370, 0)
		var hb := UIKit.hbox(10)
		pn.add_child(hb)
		var face := UIKit.icon("actors/%s/face.png" % e.actor, 56)
		if k == 0: face.modulate = Color(0, 0, 0, 0.8)
		hb.add_child(face)
		var v := UIKit.vbox(0)
		hb.add_child(v)
		v.add_child(UIKit.label(("★ " if e.get("boss", false) else "") + (e.name if k > 0 else "???"), 17, UIKit.PAPER, true))
		var info := ("HP %d · ATK %d · DEF %d\nดรอป: %s\n" % [st.hp, st.atk, st.def, ", ".join(drops)]) if k > 0 else ""
		var l := UIKit.label(info + "%s · ปราบแล้ว %d" % [zone, k], 13, UIKit.MUTED)
		v.add_child(l)
		grid.add_child(pn)

func toggle_autorun() -> void:
	G.P.autorun = not G.P.get("autorun", false)
	G.save_game()
	toast("วิ่งอัตโนมัติ: เปิด" if G.P.autorun else "วิ่งอัตโนมัติ: ปิด", UIKit.GOLD)

func _menu_sys() -> void:
	menu_body.add_child(UIKit.label("ระบบ", 22, UIKit.GOLD, true))
	row(menu_body, "", "ความสำเร็จ", "ปลดล็อกแล้ว " + G.ach_count(), [["ดู", func() -> void:
		close_menu()
		open_achievements()]])
	row(menu_body, "", "เพลงประกอบ", "", [["เปิด" if G.P.get("music", false) else "ปิด", func() -> void:
		G.P.music = not G.P.get("music", false)
		G.save_game()
		Sfx.refresh_music()
		render_menu()]])
	row(menu_body, "", "เสียงประกอบ", "", [["เปิด" if G.P.get("sfx", false) else "ปิด", func() -> void:
		G.P.sfx = not G.P.get("sfx", false)
		G.save_game()
		render_menu()]])
	var hm: String = G.P.get("halloween", "auto")
	row(menu_body, "", "เทศกาลฮาโลวีน", "อัตโนมัติ = เปิดเฉพาะเดือนตุลาคม · ตอนนี้%s" % ("เปิดอยู่" if G.halloween() else "ปิดอยู่"),
		[[{"auto": "อัตโนมัติ", "on": "เปิด", "off": "ปิด"}[hm], func() -> void:
			G.P.halloween = {"auto": "on", "on": "off", "off": "auto"}[hm]
			if G.P.map == "graveyard" and not G.halloween(): main.world.go_map("village", "prev")
			else: main.world.load_map(G.P.map)
			G.save_game()
			render_menu()]])
	row(menu_body, "", "วิ่งอัตโนมัติ", "กด R หรือ Caps Lock เพื่อสลับ · กด Shift ค้างเพื่อเดินช้าชั่วคราว", [["เปิด" if G.P.get("autorun", false) else "ปิด", func() -> void:
		toggle_autorun()
		render_menu()]])
	row(menu_body, "", "บันทึกเกม", "บันทึกอัตโนมัติเมื่อเปลี่ยนพื้นที่/จบการต่อสู้/พักโรงเตี๊ยม", [["บันทึก", func() -> void:
		G.save_game()
		toast("บันทึกแล้ว", Color("#9be37a"))]])
	row(menu_body, "", "อัปเดตเกม", "เวอร์ชัน v%s%s" % [updater.version(), "" if _can_update() else " · เช็กได้เฉพาะตัวเกมที่ export แล้ว"],
		[["เช็กอัปเดต", func() -> void:
			close_menu()
			_check_update(true), not _can_update()]])
	row(menu_body, "", "แจ้งบั๊ก (F8)", "แนบภาพหน้าจอ + ข้อความ เก็บไว้ในโฟลเดอร์ bug_reports ข้างไฟล์เซฟ", [["แจ้งบั๊ก", func() -> void:
		close_menu()
		open_bug_report.call_deferred()], ["เปิดโฟลเดอร์", func() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUG_DIR))
		OS.shell_open(ProjectSettings.globalize_path(BUG_DIR))]])
	row(menu_body, "", "เปลี่ยนตัวละคร", "บันทึกช่อง %d แล้วกลับหน้าแรกเพื่อเลือกเซฟอื่น" % G.slot, [["กลับหน้าแรก", func() -> void:
		G.save_game()
		close_menu()
		main.to_title()]])
	row(menu_body, "", "ลบเซฟช่อง %d และกลับหน้าแรก" % G.slot, "ไม่สามารถกู้คืนได้ · เซฟช่องอื่นไม่ได้รับผลกระทบ", [["ลบเซฟ", func() -> void:
		close_menu()
		var box := open_modal(480)
		_title(box, "ลบเซฟจริงหรือ?", Color("#ff8f80"))
		_buttons(box, [["ลบ", func() -> void:
			G.delete_save()
			close_modal()
			main.to_title()], ["ยกเลิก", close_modal]])]])
	menu_body.add_child(UIKit.label("ปุ่มควบคุม", 20, UIKit.GOLD))
	var c := UIKit.label("WASD / ลูกศร = เดิน · Shift = วิ่ง · R / Caps Lock = สลับวิ่งตลอด · F8 = แจ้งบั๊ก · E / Space = คุย/เปิดหีบ · I / Tab = เมนู · Esc = ปิด\nในการต่อสู้: 1-8 = ใช้สกิล/ไอเทม · Q / E = เปลี่ยนหมวด · R = โอกิ", 16)
	menu_body.add_child(c)
	menu_body.add_child(UIKit.label("เครดิต", 20, UIKit.GOLD))
	menu_body.add_child(UIKit.label("ภาพ เสียง และเพลง: Ninja Adventure Asset Pack โดย Pixel-boy & AAA (CC0)\nฟอนต์: Kanit โดย Cadson Demak (SIL Open Font License)\nสร้างด้วย Godot Engine", 15, UIKit.MUTED))

# ---------- bag (MMORPG-style) ----------
const RARITY := [["ธรรมดา", "#b8b8b8"], ["ดี", "#5fd35f"], ["หายาก", "#4a9bff"], ["มหากาพย์", "#c070ff"], ["ตำนาน", "#ff9d2e"]]
const ITEM_RAR := {"potion": 0, "ether": 0, "hipotion": 1, "bomb": 1, "smoke": 1, "elixir": 3, "exp_scroll": 2, "tome_str": 4, "tome_agi": 4, "tome_int": 4, "tome_vit": 4}
const MAT_RAR := {"herb": 0, "iron": 0, "branch": 0, "feather": 1, "shard": 2, "ruby": 2}

func _rarity(t: String, id: String) -> int:
	if t == "gear":
		var pr: int = G.GEAR[id].price
		return 0 if pr == 0 else 1 if pr < 200 else 2 if pr < 700 else 3 if pr < 2000 else 4
	return ITEM_RAR.get(id, 0) if t == "item" else MAT_RAR.get(id, 0)

func _bag_entries() -> Array:
	var eqd: Array = G.P.eq.values()
	var out := []
	if bag_filter in ["all", "gear"]:
		for id in G.P.owned:
			if not id in eqd: out.append({"t": "gear", "id": id, "n": 1})
	if bag_filter in ["all", "item"]:
		for id in G.ITEMS:
			if int(G.P.inv.get(id, 0)) > 0: out.append({"t": "item", "id": id, "n": int(G.P.inv[id])})
	if bag_filter in ["all", "mat"]:
		for id in G.MATS:
			if int(G.P.mats.get(id, 0)) > 0: out.append({"t": "mat", "id": id, "n": int(G.P.mats[id])})
	return out

func _entry_icon(en: Dictionary) -> Array:
	if en.t == "gear": return [G.GEAR[en.id].icon, G.GEAR[en.id].get("tint", "")]
	if en.t == "item": return [G.ITEMS[en.id].icon, ""]
	return [G.MATS[en.id].icon, ""]

func _entry_name(en: Dictionary) -> String:
	if en.t == "gear": return G.gname(en.id)
	if en.t == "item": return G.ITEMS[en.id].name
	return G.MATS[en.id].name

func _tip(en: Dictionary, equipped := false) -> String:
	var r: Array = RARITY[_rarity(en.t, en.id)]
	var t := "%s\n[%s] " % [_entry_name(en), r[0]]
	if en.t == "gear":
		var g: Dictionary = G.GEAR[en.id]
		t += G.SLOTNAME[g.slot] + (" · สวมใส่อยู่" if equipped else "") + "\n" + gear_desc(en.id)
		if not equipped:
			var cur := G.gstat(G.P.eq[g.slot])
			var mine := G.gstat(en.id)
			var k := "def" if g.slot == "armor" else "atk"
			var d: int = mine[k] - cur[k]
			if d != 0: t += "  (%s%d เทียบกับที่ใส่)" % ["▲" if d > 0 else "▼", absi(d)]
			t += "\nดับเบิลคลิก / คลิกขวา / ลากไปช่องอุปกรณ์ = สวมใส่"
		if g.price > 0: t += "\nมูลค่า %d ทอง" % g.price
	elif en.t == "item":
		var it: Dictionary = G.ITEMS[en.id]
		if it.has("tome"): t += "คัมภีร์ค่าสถานะ\n%s\nดับเบิลคลิก / คลิกขวา = อ่าน\nขายได้ %d ทอง · มี %d" % [it.desc, it.sell, en.n]
		else: t += "ไอเทม\n%s\n%s\nราคา %d ทอง · มี %d" % [it.desc, "ใช้ได้ในการต่อสู้เท่านั้น" if it.get("battle", false) else "ดับเบิลคลิก / คลิกขวา = ใช้", it.price, en.n]
	else:
		var src := []
		for e in G.ENEMIES:
			if e.is_empty(): continue
			for d in e.drops:
				if d[0] == en.id: src.append(e.name)
		t += "วัตถุดิบ\nใช้ตีเสริมอุปกรณ์ หรือส่งค่าหัว\nดรอปจาก: %s\nขายได้ %d ทอง/ชิ้น · มี %d" % [", ".join(src), G.MATS[en.id].price, en.n]
	return t

func _slot(en, equipped := false, eq_slot := "") -> PanelContainer:
	var pn := RichTip.TipPanel.new()
	pn.custom_minimum_size = Vector2(64, 64)
	var style := UIKit.sbox("inventory_cell.png", [4, 4, 4, 4], [6, 6, 6, 6], 4)
	if en != null:
		style.modulate_color = Color(RARITY[_rarity(en.t, en.id)][1]).lerp(Color.WHITE, 0.35)
		if bag_sel == en.t + ":" + en.id and not equipped: style.modulate_color = Color("#fff3a0")
	pn.add_theme_stylebox_override("panel", style)
	if en == null: return pn
	var ic := _entry_icon(en)
	var tr := UIKit.icon(ic[0], 48, ic[1])
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_child(tr)
	if en.n > 1:
		var c := UIKit.label(str(en.n), 15, Color.WHITE, true)
		c.add_theme_color_override("font_outline_color", Color.BLACK)
		c.add_theme_constant_override("outline_size", 5)
		c.size_flags_horizontal = Control.SIZE_SHRINK_END
		c.size_flags_vertical = Control.SIZE_SHRINK_END
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pn.add_child(c)
	if en.t == "gear" and int(G.P.up.get(en.id, 0)) > 0:
		var u := UIKit.label("+%d" % int(G.P.up[en.id]), 14, UIKit.GOLD, true)
		u.add_theme_color_override("font_outline_color", Color.BLACK)
		u.add_theme_constant_override("outline_size", 5)
		u.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		u.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		u.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pn.add_child(u)
	pn.tooltip_text = _tip(en, equipped)
	var e2: Dictionary = en
	if equipped:
		pn.set_drag_forwarding(Callable(), func(_p, data) -> bool:
			return typeof(data) == TYPE_DICTIONARY and data.get("t", "") == "gear" and G.GEAR[data.id].slot == eq_slot,
			func(_p, data) -> void: _bag_primary("gear", data.id))
	else:
		pn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_RIGHT or ev.double_click: _bag_primary(e2.t, e2.id)
				elif ev.button_index == MOUSE_BUTTON_LEFT:
					bag_sel = e2.t + ":" + e2.id
					Sfx.play("ui")
					render_menu.call_deferred())
		if en.t == "gear":
			pn.set_drag_forwarding(func(_p) -> Variant:
				var prev := UIKit.icon(ic[0], 48, ic[1])
				pn.set_drag_preview(prev)
				return e2, Callable(), Callable())
	return pn

func _sell_tome(id: String) -> void:
	if int(G.P.inv.get(id, 0)) <= 0: return
	G.P.inv[id] = int(G.P.inv[id]) - 1
	G.P.gold += int(G.ITEMS[id].sell)
	G.save_game()
	Sfx.play("coin")
	toast("ขาย %s ได้ %d ทอง" % [G.ITEMS[id].name, G.ITEMS[id].sell], UIKit.GOLD)

func _bag_primary(t: String, id: String) -> void:
	if t == "item" and G.ITEMS[id].has("boost"):
		G.use_exp_boost()
		Sfx.play("powerup")
		toast("ใช้ใบเพิ่มค่าประสบการณ์: EXP x%d เหลือ %s" % [G.EXP_BOOST_MUL, G.mmss(G.exp_boost_left())], Color("#9be37a"))
		render_menu.call_deferred()
		return
	if t == "item" and G.ITEMS[id].has("tome"):
		var k: String = G.ITEMS[id].tome
		G.use_tome(id)
		Sfx.play("powerup")
		toast("อ่าน %s: %s +1 ถาวร!" % [G.ITEMS[id].name, k.to_upper()], UIKit.GOLD)
		render_menu.call_deferred()
		return
	if t == "gear" and not G.can_equip(id):
		toast("สวมใส่ไม่ได้ — อุปกรณ์นี้เป็นของสายอาชีพอื่น", Color("#ff8f80"))
		return
	if t == "gear":
		G.P.eq[G.GEAR[id].slot] = id
		G.fix_player()
		G.save_game()
		Sfx.play("accept")
		toast("สวมใส่ " + G.gname(id), UIKit.GOLD)
		bag_sel = ""
	elif t == "item":
		var it: Dictionary = G.ITEMS[id]
		if it.get("battle", false):
			toast("ใช้ได้ในการต่อสู้เท่านั้น", Color("#ff8f80"))
			return
		if it.has("hp") and not it.has("mp") and G.P.hp >= G.max_hp():
			toast("HP เต็มอยู่แล้ว", UIKit.MUTED)
			return
		G.P.inv[id] = int(G.P.inv[id]) - 1
		if it.has("hp"): G.P.hp = mini(G.max_hp(), G.P.hp + it.hp)
		if it.has("mp"): G.P.mp = mini(G.max_mp(), G.P.mp + it.mp)
		G.save_game()
		Sfx.play("heal")
		toast("ใช้ " + it.name, Color("#9be37a"))
	else:
		return
	render_menu.call_deferred()

func _menu_bag() -> void:
	var hb := UIKit.hbox(18)
	menu_body.add_child(hb)
	# --- paper doll ---
	var doll := UIKit.panel("nine_path_bg_2.png", [16, 12, 16, 12])
	doll.custom_minimum_size = Vector2(360, 0)
	hb.add_child(doll)
	var dv := UIKit.vbox(8)
	doll.add_child(dv)
	var nm := UIKit.label("%s  Lv %d · %s" % [G.P.name, G.P.lvl, G.cls().name], 18, UIKit.PAPER, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(nm)
	var body := UIKit.hbox(10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_child(body)
	var lcol := UIKit.vbox(10)
	var rcol := UIKit.vbox(10)
	for s in ["weapon", "throw"]: lcol.add_child(_eq_slot(s))
	for s in ["charm", "armor"]: rcol.add_child(_eq_slot(s))
	body.add_child(lcol)
	var stagec := Control.new()
	stagec.custom_minimum_size = Vector2(140, 180)
	doll_spr = AnimatedSprite2D.new()
	doll_spr.sprite_frames = Sprites.actor(G.CLASSES[G.P.cls].actor)
	doll_spr.play("walk_down")
	doll_spr.speed_scale = 0.6
	doll_spr.scale = Vector2(7, 7)
	doll_spr.position = Vector2(70, 92)
	stagec.add_child(doll_spr)
	body.add_child(stagec)
	body.add_child(rcol)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 22)
	for s in ["HP %d/%d" % [G.P.hp, G.max_hp()], "MP %d/%d" % [G.P.mp, G.max_mp()], "ดาบ %d" % roundi(G.melee_pow()), "ปา %d" % roundi(G.ranged_pow()),
			"เวท %d" % roundi(G.magic_pow()), "ป้องกัน %d" % G.p_def()]:
		stats.add_child(UIKit.label(s, 15, UIKit.PAPER))
	dv.add_child(stats)
	# --- grid ---
	var side := UIKit.vbox(8)
	hb.add_child(side)
	var top := UIKit.hbox(8)
	side.add_child(top)
	for f in [["all", "ทั้งหมด"], ["gear", "อุปกรณ์"], ["item", "ไอเทม"], ["mat", "วัตถุดิบ"]]:
		var ff: String = f[0]
		var b := UIKit.button(f[1], func() -> void:
			bag_filter = ff
			bag_sel = ""
			render_menu(), 15)
		if ff == bag_filter: b.add_theme_stylebox_override("normal", UIKit.sbox("button_hover.png", [4, 3, 4, 3], [14, 6, 14, 7]))
		top.add_child(b)
	var list := _bag_entries()
	var main_row := UIKit.hbox(14)
	side.add_child(main_row)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	main_row.add_child(grid)
	var n := maxi(30, int(ceil(list.size() / 6.0)) * 6)
	for i in n: grid.add_child(_slot(list[i] if i < list.size() else null))
	var det := UIKit.panel("nine_path_bg_2.png", [14, 12, 14, 12])
	det.custom_minimum_size = Vector2(300, 200)
	det.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_row.add_child(det)
	var dvb := UIKit.vbox(8)
	det.add_child(dvb)
	var sel = null
	for en in list:
		if en.t + ":" + en.id == bag_sel: sel = en
	if sel == null:
		var l := UIKit.label("คลิกที่ไอเทมเพื่อดูรายละเอียด\n\nดับเบิลคลิก / คลิกขวา = ใช้หรือสวมใส่\nลากอุปกรณ์ไปวางที่ช่องข้างตัวละครได้", 15, UIKit.PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(270, 0)
		dvb.add_child(l)
	else:
		var ic := _entry_icon(sel)
		dvb.add_child(UIKit.icon(ic[0], 64, ic[1]))
		var tl := UIKit.label(_tip(sel), 15, UIKit.PAPER)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(270, 0)
		dvb.add_child(tl)
		var s2: Dictionary = sel
		if sel.t == "gear":
			var hb2 := UIKit.hbox(8)
			dvb.add_child(hb2)
			hb2.add_child(UIKit.button("สวมใส่", func() -> void: _bag_primary(s2.t, s2.id)))
			hb2.add_child(UIKit.button("ขาย %d ทอง" % G.gear_sell_price(sel.id), func() -> void:
				var g := G.sell_gear(s2.id)
				if g <= 0: return
				bag_sel = ""
				G.save_game()
				Sfx.play("coin")
				toast("ขาย %s ได้ %d ทอง" % [G.GEAR[s2.id].name, g], UIKit.GOLD)
				render_menu()))
		elif sel.t == "item" and G.ITEMS[sel.id].has("tome"):
			var hb3 := UIKit.hbox(8)
			dvb.add_child(hb3)
			hb3.add_child(UIKit.button("อ่าน (+1 ถาวร)", func() -> void: _bag_primary(s2.t, s2.id)))
			hb3.add_child(UIKit.button("ขาย %d ทอง" % G.ITEMS[sel.id].sell, func() -> void:
				_sell_tome(s2.id)
				render_menu()))
		elif sel.t == "item" and not G.ITEMS[sel.id].get("battle", false): dvb.add_child(UIKit.button("ใช้", func() -> void: _bag_primary(s2.t, s2.id)))
	side.add_child(UIKit.label("%d/%d ช่อง" % [list.size(), n], 14, UIKit.MUTED))
	# bulk sell unequipped gear by grade
	var sr := UIKit.hbox(6)
	side.add_child(sr)
	sr.add_child(UIKit.label("ขายอุปกรณ์ทั้งหมดตามเกรด:", 14, UIKit.MUTED))
	for gi in RARITY.size():
		var ids := _gear_of_grade(gi)
		var b := UIKit.button("%s (%d)" % [RARITY[gi][0], ids.size()], func() -> void: _confirm_bulk_sell(gi), 14)
		b.add_theme_color_override("font_color", Color(RARITY[gi][1]).darkened(0.45))
		b.disabled = ids.is_empty()
		sr.add_child(b)

## Unequipped owned gear of one rarity grade
func _gear_of_grade(gi: int) -> Array:
	var out := []
	for id in G.P.owned:
		if not id in G.P.eq.values() and not id in out and _rarity("gear", id) == gi: out.append(id)
	return out

func _confirm_bulk_sell(gi: int) -> void:
	var ids := _gear_of_grade(gi)
	if ids.is_empty(): return
	var total := 0
	var names := []
	for id in ids:
		total += G.gear_sell_price(id)
		names.append(G.gname(id))
	menu.visible = false
	var box := open_modal(560)
	_title(box, "ขายอุปกรณ์เกรด%s" % RARITY[gi][0], Color(RARITY[gi][1]))
	_center_label(box, "%d ชิ้น (ไม่รวมที่สวมใส่อยู่): %s" % [ids.size(), ", ".join(names)], 15, UIKit.PAPER)
	_center_label(box, "ได้รับ %d ทอง" % total, 20, UIKit.GOLD)
	_buttons(box, [["ขายทั้งหมด", func() -> void:
		var got := 0
		for id in ids: got += G.sell_gear(id)
		G.save_game()
		Sfx.play("coin")
		toast("ขายอุปกรณ์ %d ชิ้น ได้ %d ทอง" % [ids.size(), got], UIKit.GOLD)
		close_modal()
		open_menu("bag")], ["ยกเลิก", func() -> void:
		close_modal()
		open_menu("bag")]])

func _eq_slot(slot: String) -> Control:
	var v := UIKit.vbox(2)
	var s := _slot({"t": "gear", "id": G.P.eq[slot], "n": 1}, true, slot)
	v.add_child(s)
	var l := UIKit.label(G.SLOTNAME[slot], 13, UIKit.PAPER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v

# ================= title / class select =================
func _build_title() -> void:
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	title.visible = false

func show_title() -> void:
	hud.visible = false
	menu.visible = false
	dialog.visible = false
	modal.visible = false
	title.visible = true
	UIKit.clear(title)
	var bg := ColorRect.new()
	bg.color = Color("#141018")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(bg)
	# parade of actors along the bottom
	var parade_box := Control.new()
	UIKit.anchor(parade_box, [0.5, 1, 0.5, 1], [-640, -80, 640, -80])
	parade_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(parade_box)
	var parade := Node2D.new()
	parade_box.add_child(parade)
	var cast := ["NinjaRed", "NinjaBlue2", "SamuraiRed", "NinjaMageBlack", "Master", "Tengu", "NinjaDark", "Samurai", "Monk", "DemonRed"]
	for i in cast.size():
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Sprites.actor(cast[i])
		a.play("walk_right")
		a.scale = Vector2(5, 5)
		a.position = Vector2(80 + i * 125, 0)
		parade.add_child(a)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_bottom = -120
	title.add_child(cc)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var t := UIKit.label("忍  SHADOW NINJA", 64, UIKit.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("#5a1a10"))
	t.add_theme_constant_override("outline_size", 14)
	v.add_child(t)
	_center_label(v, "RPG นินจาเทิร์นเบส · ดาบคาตานะ · ดาวกระจาย · นินจุตสึ", 20, UIKit.MUTED)
	var b1 := UIKit.button("เริ่มเกมใหม่", func() -> void: show_slots("new"), 22)
	var b2 := UIKit.button("เล่นต่อ", func() -> void: show_slots("load"), 22)
	b2.disabled = not G.any_save()
	var b3 := UIKit.button("ความสำเร็จ " + G.ach_count(), open_achievements, 22)
	var hb := UIKit.hbox(14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(b1)
	hb.add_child(b2)
	hb.add_child(b3)
	v.add_child(hb)
	var ver := UIKit.label("v" + updater.version(), 14, UIKit.MUTED)
	UIKit.anchor(ver, [1, 0, 1, 0], [-160, 8, -12, 30])
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_child(ver)
	if _can_update() and not update_checked:
		# hold the start buttons until the first update check answers (or times out)
		update_checked = true
		b1.disabled = true
		b2.disabled = true
		var st := _center_label(v, "กำลังตรวจสอบอัปเดต...", 16, UIKit.MUTED)
		await _check_update(false)
		if is_instance_valid(st):
			st.queue_free()
			b1.disabled = false
			b2.disabled = not G.any_save()

func _can_update() -> bool: return updater.enabled() and not G.testing

## Ask GitHub for a newer patch; verbose=false (title screen) only shows a dialog when there is one
func _check_update(verbose: bool) -> void:
	var info: Dictionary = await updater.check(30.0 if verbose else 8.0)
	if not verbose and not title.visible: return
	if not info.ok:
		if verbose: message("เช็กอัปเดตไม่ได้", [info.error], Color("#ff8f80"))
		return
	if not info.newer:
		if verbose: message("เป็นเวอร์ชันล่าสุดแล้ว", ["v%s" % updater.version()])
		return
	var box := open_modal(560)
	_title(box, "มี patch ใหม่ v%s" % info.version)
	_center_label(box, "เวอร์ชันปัจจุบัน v%s · ขนาดดาวน์โหลด %.1f MB" % [updater.version(), info.size / 1048576.0], 16, UIKit.MUTED)
	if info.need_exe: _center_label(box, "รอบนี้อัปเดตตัวเกม (exe) ด้วย จึงใช้เวลาโหลดนานกว่าปกติ", 16, Color("#ffd34d"))
	var notes: String = info.notes.strip_edges()
	if notes != "": _center_label(box, notes.left(600), 16)
	_buttons(box, [["อัปเดตเลย", func() -> void: _apply_update(info)], ["ภายหลัง", close_modal]])

func _apply_update(info: Dictionary) -> void:
	var box := open_modal(480)
	_title(box, "กำลังดาวน์โหลด patch...")
	_center_label(box, "เกมจะปิดแล้วเปิดใหม่เองเมื่อเสร็จ", 16, UIKit.MUTED)
	var err: String = await updater.download(info)
	if err != "":
		message("อัปเดตไม่สำเร็จ", [err], Color("#ff8f80"))
		return
	G.save_game()
	updater.restart_into_patch()

## Save-slot list. mode "load" = continue a character, "new" = pick a slot for a new one
func show_slots(mode: String, confirm := -1) -> void:
	UIKit.clear(title)
	var bg := ColorRect.new()
	bg.color = Color("#141018")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(cc)
	var v := UIKit.vbox(10)
	v.custom_minimum_size = Vector2(860, 0)
	cc.add_child(v)
	var t := UIKit.label("เลือกช่องเซฟ — เล่นต่อ" if mode == "load" else "เลือกช่องเซฟสำหรับตัวละครใหม่", 30, UIKit.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for s in range(1, G.SAVE_SLOTS + 1):
		var info := G.slot_info(s)
		var ss: int = s
		var pn := UIKit.panel("nine_path_bg.png", [14, 10, 14, 10])
		v.add_child(pn)
		var hb := UIKit.hbox(14)
		pn.add_child(hb)
		var face_path := "actors/%s/face.png" % G.CLASSES.get(info.get("cls", ""), G.CLASSES.balanced).actor
		var ic := UIKit.icon(face_path if not info.is_empty() else "icons/scroll.png", 56)
		if info.is_empty(): ic.modulate = Color(1, 1, 1, 0.35)
		hb.add_child(ic)
		var tv := UIKit.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(tv)
		if info.is_empty():
			tv.add_child(UIKit.label("ช่อง %d — ว่าง" % s, 20, UIKit.MUTED, true))
		elif info.get("broken", false):
			tv.add_child(UIKit.label("ช่อง %d — ไฟล์เสีย" % s, 20, Color("#ff8f80"), true))
		else:
			var cn: String = G.CLASSES.get(info.cls, G.CLASSES.balanced).name
			tv.add_child(UIKit.label("ช่อง %d · %s  ·  สาย%s  Lv %d%s" % [s, info.name, cn, info.lvl, "   ★ จบเกมแล้ว" if info.cleared else ""], 20, UIKit.GOLD, true))
			tv.add_child(UIKit.label("%s · ทอง %d · บันทึกล่าสุด %s" % [G.MAPS.get(info.map, G.MAPS.village).name, info.gold, info.saved_at], 15, UIKit.MUTED))
		var btns := UIKit.hbox(8)
		hb.add_child(btns)
		if confirm == s:
			btns.add_child(UIKit.label("แน่ใจ?", 16, Color("#ff8f80")))
			btns.add_child(UIKit.button("ลบ" if mode == "load" else "เขียนทับ", func() -> void:
				if mode == "load":
					G.delete_save(ss)
					if G.any_save(): show_slots("load")
					else: show_title()
				else:
					G.slot = ss
					show_class_select(), 16))
			btns.add_child(UIKit.button("ยกเลิก", func() -> void: show_slots(mode), 16))
		elif mode == "load":
			var lb := UIKit.button("เล่น", func() -> void:
				if G.load_game(ss): main.start_game(), 17)
			lb.disabled = info.is_empty() or info.get("broken", false)
			btns.add_child(lb)
			var db := UIKit.button("ลบ", func() -> void: show_slots(mode, ss), 16)
			db.disabled = info.is_empty()
			btns.add_child(db)
		else:
			btns.add_child(UIKit.button("สร้างที่นี่" if info.is_empty() else "เขียนทับ...", func() -> void:
				if info.is_empty():
					G.slot = ss
					show_class_select()
				else: show_slots(mode, ss), 17))
	var back := UIKit.button("กลับ", show_title, 18)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)

func show_class_select() -> void:
	UIKit.clear(title)
	var bg := ColorRect.new()
	bg.color = Color("#141018")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(bg)
	var v := UIKit.vbox(14)
	UIKit.anchor(v, [0.5, 0.5, 0.5, 0.5], [-600, -335, 600, 335])
	title.add_child(v)
	var t := UIKit.label("เลือกสายของคุณ", 34, UIKit.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var name_row := UIKit.hbox(10)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_child(UIKit.label("ชื่อนินจา", 20))
	var le := LineEdit.new()
	le.text = "ซินจิด"
	le.max_length = 14
	le.custom_minimum_size = Vector2(260, 0)
	name_row.add_child(le)
	v.add_child(name_row)
	var cards := UIKit.hbox(16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cards)
	var start_btn := UIKit.button("เริ่มผจญภัย", func() -> void:
		var nm := le.text.strip_edges()
		G.P = G.new_player(nm if nm != "" else "ซินจิด", pick_cls)
		G.save_game()
		main.start_game(true), 22)
	start_btn.disabled = true
	var card_nodes := []
	for id in G.CLASSES:
		var C: Dictionary = G.CLASSES[id]
		if C.get("hidden", false): continue
		var pn := UIKit.panel("nine_path_bg.png", [14, 12, 14, 12])
		pn.custom_minimum_size = Vector2(280, 440)
		var cv := UIKit.vbox(6)
		pn.add_child(cv)
		var stagec := Control.new()
		stagec.custom_minimum_size = Vector2(250, 150)
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Sprites.actor(C.actor)
		a.play("idle_down")
		a.scale = Vector2(8, 8)
		a.position = Vector2(125, 80)
		stagec.add_child(a)
		cv.add_child(stagec)
		var nl := UIKit.label("%s  (%s)" % [C.name, C.en], 22, UIKit.GOLD, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nl)
		var dl := UIKit.label(C.desc, 15, UIKit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.custom_minimum_size = Vector2(250, 44)
		cv.add_child(dl)
		var sg := GridContainer.new()
		sg.columns = 2
		sg.add_theme_constant_override("h_separation", 30)
		for k in G.STATS: sg.add_child(UIKit.label("%s  %d" % [k.to_upper(), C.base[k]], 16))
		sg.add_child(UIKit.label("HP ×%s" % C.hp_mul, 16))
		sg.add_child(UIKit.label("MP ×%s" % C.mp_mul, 16))
		cv.add_child(sg)
		var grow := []
		for k in C.grow: grow.append("%s +%d" % [k.to_upper(), C.grow[k]])
		var sk := []
		for s in C.skills: sk.append(G.SKILLS[s].name)
		var gl := UIKit.label("เลเวลอัป: %s\nสกิลเริ่ม: %s" % [", ".join(grow), ", ".join(sk)], 14, UIKit.MUTED)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.custom_minimum_size = Vector2(250, 0)
		cv.add_child(gl)
		var cid: String = id
		var pick := UIKit.button("เลือก", func() -> void:
			pick_cls = cid
			start_btn.disabled = false
			for c in card_nodes:
				c[0].modulate = Color(1.15, 1.1, 0.95) if c[1] == cid else Color(0.7, 0.7, 0.7)
				c[2].play("walk_down" if c[1] == cid else "idle_down"), 18)
		cv.add_child(pick)
		cards.add_child(pn)
		card_nodes.append([pn, id, a])
	var hb := UIKit.hbox(14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(start_btn)
	hb.add_child(UIKit.button("กลับ", show_title, 22))
	v.add_child(hb)

func hide_title() -> void:
	title.visible = false
	UIKit.clear(title)
