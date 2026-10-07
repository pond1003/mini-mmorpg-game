extends Node
## Root controller: switches between title, world and battle, routes signals and input.

const World := preload("res://scripts/world.gd")
const Battle := preload("res://scripts/battle.gd")
const UI := preload("res://scripts/ui.gd")

var world: Node2D
var battle: CanvasLayer
var ui: CanvasLayer
var state := "title"

func _ready() -> void:
	get_window().title = "Shadow Ninja"
	world = World.new()
	add_child(world)
	battle = Battle.new()
	add_child(battle)
	ui = UI.new()
	ui.main = self
	add_child(ui)
	world.battle_requested.connect(_on_battle_requested)
	world.boss_touched.connect(_on_boss)
	world.npc_interact.connect(func(id: String) -> void: ui.npc(id))
	world.toast.connect(func(m: String, c: Color) -> void: ui.toast(m, c))
	world.map_changed.connect(func(id: String) -> void: Sfx.music(G.THEMES[G.MAPS[id].theme].music))
	battle.ended.connect(_on_battle_ended)
	to_title()
	Autotest.maybe_run(self)

func to_title() -> void:
	state = "title"
	world.visible = false
	battle.visible = false
	world.map_id = ""
	ui.show_title()
	Sfx.music("title")

func start_game(fresh := false) -> void:
	ui.hide_title()
	G.fix_player()
	G.ensure_bounties()
	world.visible = true
	world.load_map(G.P.map)
	ui.hud.visible = true
	state = "world"
	if fresh:
		ui.show_dialog("อาจารย์นินจา ไรเดน", "Master", [
			"ตื่นแล้วหรือ %s... เจ้าเลือกเดินบนวิถีแห่ง%s" % [G.P.name, G.cls().name],
			"หมู่บ้านใบไม้กำลังตกอยู่ในอันตราย กองทัพของโชกุนเงา คาเงะโมริ ส่งสมุนมาคุกคามทุกทิศทาง",
			"ไปพบผู้ใหญ่บ้านฮิโรชิ (บ้านขวาสุดแถวบน) เพื่อรับภารกิจแรก",
			"ใช้ WASD เดิน · E คุย · I เปิดเมนู · ทางออกไปป่าไผ่อยู่ทางขวาของหมู่บ้าน"])

func _on_battle_requested(stage: int, src) -> void:
	if state != "world": return
	start_battle(stage, src)

func start_battle(stage: int, src) -> void:
	state = "battle"
	world.visible = false
	ui.hud.visible = false
	battle.start(stage, src)

func _on_boss(stage: int) -> void:
	ui.boss_prompt(stage, func() -> void: start_battle(stage, "boss"), func() -> void: world.inv = 2.5)

func _on_battle_ended(r: Dictionary) -> void:
	battle.input_locked = true
	ui.battle_result(r, func() -> void:
		battle.visible = false
		world.visible = true
		ui.hud.visible = true
		state = "world"
		if r.res == "win" or r.res == "escaped": world.enemy_defeated(r.src)
		ui.announce_achievements(G.check_achievements())
		if G.game_clear_ready(): ui.show_ending.call_deferred()
		if r.res == "lose" or world.map_id != G.P.map: world.load_map(G.P.map)
		else: Sfx.music(G.THEMES[world.theme].music)
		world.inv = 2.0)

func _process(_dt: float) -> void:
	world.paused = state != "world" or ui.blocking()
	_tick_exp_boost(_dt)
	_tick_playtime(_dt)
	if state == "world" and world.map_id != "":
		ui.update_hud(G.MAPS[world.map_id].name, world.prompt_text())

## EXP scroll timer: real seconds, but only while playing (not in menus/shops/dialogs, not when the window is unfocused)
func _tick_playtime(dt: float) -> void:
	if G.P.is_empty() or not (state == "world" or state == "battle") or ui.blocking(): return
	G.P.play_sec = float(G.P.get("play_sec", 0.0)) + dt / maxf(Engine.time_scale, 0.001)

func _tick_exp_boost(dt: float) -> void:
	if not G.exp_boost_on() or not (state == "world" or state == "battle"): return
	if ui.blocking() or not (get_window().has_focus() or G.testing): return
	G.P.exp_boost = maxf(0.0, G.exp_boost_left() - dt / maxf(Engine.time_scale, 0.001))
	if G.P.exp_boost <= 0.0:
		G.save_game()
		ui.toast("ใบเพิ่มค่าประสบการณ์หมดเวลาแล้ว", UIKit.MUTED)

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo: return
	var k: int = ev.physical_keycode
	if k == KEY_F8:
		ui.open_bug_report()
		return
	if state != "world": return
	if ui.dialog.visible:
		if k in [KEY_E, KEY_SPACE, KEY_ENTER]: ui.advance_dialog()
		return
	if k == KEY_ESCAPE:
		if ui.modal.visible: ui.close_modal()
		elif ui.menu.visible: ui.close_menu()
		return
	if ui.modal.visible: return
	if k == KEY_I or k == KEY_TAB:
		if ui.menu.visible: ui.close_menu()
		else: ui.open_menu()
		return
	if ui.menu.visible: return
	if k == KEY_R or k == KEY_CAPSLOCK:
		ui.toggle_autorun()
		return
	if k in [KEY_E, KEY_SPACE, KEY_ENTER]: world.interact()
