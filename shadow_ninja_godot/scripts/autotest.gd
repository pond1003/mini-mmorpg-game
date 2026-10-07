class_name Autotest
## Dev-only: `godot -- --shots=<dir>` walks through the main screens, saves PNGs and quits.
## `godot -- --sim=<class>` plays the whole game with a bot at high speed and prints a summary.

static func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name): return a.split("=", true, 1)[1]
	return ""

static func maybe_run(main: Node) -> void:
	if _arg("shots") != "" or _arg("sim") != "" or _arg("res") != "": G.testing = true
	var res := _arg("res")
	if res != "": _res(main, res)
	var shots := _arg("shots")
	if shots != "": _shots(main, shots)
	var sim := _arg("sim")
	if sim != "": _sim(main, sim)

static func _snap(main: Node, dir: String, name: String) -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("shot ", name)

static func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)

static func _wait(main: Node, t: float) -> void:
	await main.get_tree().create_timer(t).timeout

static func _shots(main: Node, dir: String) -> void:
	var ui = main.ui
	await _wait(main, 0.5)
	await _snap(main, dir, "01_title")
	# save slots (test files only): two characters, list, overwrite prompt, load
	for k in range(1, G.SAVE_SLOTS + 1): G.delete_save(k)
	for pair in [[1, "อาคาเนะ", "caster"], [3, "ไดสุเกะ", "warrior"]]:
		G.slot = pair[0]
		G.P = G.new_player(pair[1], pair[2])
		G.P.lvl = 4 * pair[0]
		G.save_game()
	print("slots used=", range(1, 6).filter(func(k): return G.has_save(k)), " first free=", G.first_free_slot())
	ui.show_title()
	ui.show_slots("load")
	await _wait(main, 0.3)
	await _snap(main, dir, "01b_slots_load")
	ui.show_slots("new", 3)
	await _wait(main, 0.3)
	await _snap(main, dir, "01c_slots_new")
	G.load_game(3)
	print("loaded slot=", G.slot, " name=", G.P.name, " lvl=", G.P.lvl)
	ui.show_class_select()
	await _wait(main, 0.3)
	await _snap(main, dir, "02_class")
	G.P = G.new_player("ซินจิด", "ninja")
	G.P.owned.append_array(["steel_katana", "kage_blade", "jade_charm", "chain", "venom_star"])
	G.P.up["kage_blade"] = 3
	G.P.inv = {"potion": 5, "hipotion": 2, "ether": 3, "elixir": 1, "bomb": 2, "smoke": 1}
	G.P.mats = {"herb": 7, "iron": 12, "feather": 2, "shard": 5}
	G.P.skills["kunai"] = 2
	G.P.skills["fire"] = 1
	G.P.lvl = 6
	main.start_game(true)
	await _wait(main, 0.6)
	await _snap(main, dir, "03_village_dialog")
	while ui.dialog.visible: ui.advance_dialog()
	G.P.x = 23.5 * 16
	G.P.y = 13.5 * 16
	main.world.load_map("village")
	await _wait(main, 0.6)
	await _snap(main, dir, "04_village")
	# real keyboard input: walk right with D, then talk to the elder with E
	var x0: float = main.world.player.position.x
	_key(KEY_D, true)
	await _wait(main, 0.8)
	_key(KEY_D, false)
	print("walk dx=", main.world.player.position.x - x0)
	# auto-run toggle with R, same walk should cover more ground
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _wait(main, 0.1)
	main.world.player.position = Vector2(23.5 * 16, 13.5 * 16)
	await _wait(main, 0.1)
	x0 = main.world.player.position.x
	_key(KEY_D, true)
	await _wait(main, 0.8)
	_key(KEY_D, false)
	print("autorun=", G.P.autorun, " run dx=", main.world.player.position.x - x0)
	_key(KEY_R, true)
	_key(KEY_R, false)
	main.world.player.position = Vector2(32.5 * 16, 12.6 * 16)
	await _wait(main, 0.2)
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _wait(main, 0.3)
	print("dialog open=", ui.dialog.visible, " text=", ui.dlg_text.text)
	await _snap(main, dir, "04b_elder")
	for i in 4:
		_key(KEY_E, true)
		_key(KEY_E, false)
		await _wait(main, 0.1)
	print("quest active=", G.P.quest.active, " dlg=", ui.dialog.visible, " modal=", ui.modal.visible)
	while ui.dialog.visible: ui.advance_dialog()
	_key(KEY_I, true)
	_key(KEY_I, false)
	await _wait(main, 0.2)
	print("menu open=", ui.menu.visible)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _wait(main, 0.1)
	for m in ["forest", "mountain", "castle"]:
		G.P.map = m
		var g: Dictionary = main.world._gen(m)
		G.P.x = 3.5 * 16
		G.P.y = (g.entry + 0.5) * 16
		main.world.load_map(m)
		main.world.inv = 5.0
		await _wait(main, 0.6)
		await _snap(main, dir, "05_" + m)
	# warp shrines: walk-up activation, menu, paid teleport back to the village
	G.P.map = "forest"
	main.world.load_map("forest")
	var ws: Vector2i = main.world.warp_tile("forest_out")
	main.world.player.position = Vector2((ws.x + 1) * 16, (ws.y + 2.7) * 16)
	await _wait(main, 0.4)
	print("warp forest_out on=", G.warp_on("forest_out"), " near=", main.world.near.get("id", "") if main.world.near else "")
	G.P.gold = 500
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _wait(main, 0.4)
	await _snap(main, dir, "05b_warp_menu")
	ui.close_modal()
	ui.open_warp("forest_out")
	var g0: int = G.P.gold
	main.world.warp_to("village")
	G.P.gold -= G.warp_cost("forest_out", "village")
	await _wait(main, 0.5)
	print("warped map=", main.world.map_id, " pos=", main.world.player.position, " blocked=", main.world._blocked(main.world.player.position), " paid=", g0 - G.P.gold)
	ui.close_modal()
	await _snap(main, dir, "05c_warp_village")
	# wandering merchant + class gear
	G.P.map = "forest"
	main.world.load_map("forest")
	var mer: Dictionary = {}
	for n in main.world.npcs:
		if n.id == "wander": mer = n
	main.world.player.position = mer.pos + Vector2(0, 12)
	await _wait(main, 0.3)
	print("merchant near=", main.world.near.get("id", "") if main.world.near else "", " blocked=", main.world._blocked(main.world.player.position))
	G.P.gold = 5000
	ui.open_wander()
	await _wait(main, 0.4)
	await _snap(main, dir, "05d_wander_shop")
	ui.close_modal()
	var agi0 := G.stat("agi")
	var cr0 := G.crit_chance()
	G.P.owned.append_array(["wind_sai", "oni_club"])
	ui._bag_primary("gear", "wind_sai")
	ui._bag_primary("gear", "oni_club")
	print("equip wind_sai agi ", agi0, "->", G.stat("agi"), " crit ", cr0, "->", G.crit_chance(), " | oni_club equipped=", G.P.eq.weapon == "oni_club")
	# elite: force one in the world, then fight it
	var el: Dictionary = main.world.enemies[0]
	el.elite = true
	el.spr.scale = Vector2(1.3, 1.3)
	el.spr.modulate = Color(1.35, 1.05, 0.7)
	main.world.player.position = el.node.position + Vector2(-30, 0)
	await _wait(main, 0.3)
	await _snap(main, dir, "05e_elite_world")
	var nst := G.enemy_stats(el.stage)
	main.world.inv = 5.0
	main.start_battle(el.stage, el)
	await _wait(main, 0.6)
	print("elite battle name=", main.battle.e.name, " hp=", main.battle.e.max, " (normal ", nst.hp, ") atk=", main.battle.e.atk, " (normal ", nst.atk, ")")
	await _snap(main, dir, "05f_elite_battle")
	var gold0: int = G.P.gold
	main.battle.e.hp = 0
	await main.battle._check_end()
	await _wait(main, 0.4)
	print("elite reward gold=", G.P.gold - gold0, " (normal ", nst.gold, ")")
	await _snap(main, dir, "05g_elite_win")
	ui.close_modal()
	main.battle.visible = false
	main.state = "world"
	G.P.map = "forest"
	main.world.load_map("forest")
	main.start_battle(3, null)
	await _wait(main, 0.6)
	await _snap(main, dir, "06_battle")
	var bt = main.battle
	bt.add_status(bt.e, "poison", 3, 14)
	bt.add_status(bt.e, "break", 2)
	bt.add_status(bt.p, "might", 3)
	bt.add_status(bt.p, "ward", 2)
	await _wait(main, 0.3)
	var ic: Control = bt.info.e.st.get_child(1)
	var mv := InputEventMouseMotion.new()
	mv.position = ic.get_global_rect().get_center()
	mv.global_position = mv.position
	Input.parse_input_event(mv)
	await _wait(main, 1.2)
	await _snap(main, dir, "06b_status_tip")
	main.battle.use_skill("slash")
	await _wait(main, 0.55)
	await _snap(main, dir, "07_battle_hit")
	await _wait(main, 3.0)
	main.battle.visible = false
	G.P.map = "castle"
	main.start_battle(15, "boss")
	await _wait(main, 0.6)
	await _snap(main, dir, "08_boss")
	main.battle.visible = false
	G.P.map = "mountain"
	main.start_battle(10, "boss")
	await _wait(main, 0.6)
	await _snap(main, dir, "09_boss2")
	main.battle.visible = false
	main.state = "world"
	G.P.map = "village"
	main.world.load_map("village")
	main.world.visible = true
	ui.hud.visible = true
	ui.open_menu("bag")
	await _wait(main, 0.4)
	await _snap(main, dir, "10_bag")
	# selling: single piece, bulk by grade, forge price check
	G.P.owned.append_array(["leather", "steel_kunai", "wind_sai", "frost_axe"])
	ui.bag_sel = "gear:steel_katana"
	ui.render_menu()
	await _wait(main, 0.3)
	await _snap(main, dir, "10b_bag_sell")
	var gold_s: int = G.P.gold
	var got := G.sell_gear("steel_katana")
	print("sell steel_katana +", got, " gold ", gold_s, "->", G.P.gold, " owned=", "steel_katana" in G.P.owned)
	print("sell equipped refused=", G.sell_gear(G.P.eq.weapon) == 0)
	var grade1: Array = ui._gear_of_grade(1)
	ui._confirm_bulk_sell(1)
	await _wait(main, 0.3)
	await _snap(main, dir, "10c_bulk_sell")
	print("bulk grade1 ids=", grade1)
	ui.close_modal()
	for gname in ["muramasa", "kage_blade"]:
		var rq := G.forge_req(gname)
		print("forge ", gname, " +", rq.u, " cost ", rq.gold)
	G.P.map = "forest"
	var drops := {}
	for i in 200: drops[G.random_drop_gear()] = true
	print("forest drop pool=", drops.keys())
	G.P.map = "village"
	ui.open_shop("sell")
	await _wait(main, 0.3)
	await _snap(main, dir, "10d_shop_sell")
	ui.close_modal()
	# ---- Halloween event ----
	G.P.halloween = "on"
	G.P.map = "village"
	G.P.x = 19.5 * 16
	G.P.y = 7.5 * 16
	main.world.load_map("village")
	await _wait(main, 0.5)
	await _snap(main, dir, "14_hw_village")
	_key(KEY_W, true)
	await _wait(main, 1.2)
	_key(KEY_W, false)
	await _wait(main, 0.4)
	print("torii -> map=", main.world.map_id, " blocked=", main.world._blocked(main.world.player.position))
	main.world.inv = 5.0
	await _snap(main, dir, "15_hw_graveyard")
	var hw_n := 0
	for en in main.world.enemies: hw_n += 1 if G.ENEMIES[en.stage].get("event", false) else 0
	print("graveyard enemies=", main.world.enemies.size(), " event=", hw_n, " boss=", main.world.boss != null)
	G.P.lvl = 12
	main.start_battle(17, null)
	await _wait(main, 0.6)
	print("auto yokai lvl12: rec=", G.enemy_stats(17).rec, " hp=", main.battle.e.max)
	await _snap(main, dir, "16_hw_battle")
	main.battle.visible = false
	main.state = "world"
	main.start_battle(20, "boss")
	await _wait(main, 0.6)
	await _snap(main, dir, "17_hw_boss")
	main.battle.visible = false
	main.state = "world"
	G.P.mats["candy"] = 30
	ui.open_event_shop()
	await _wait(main, 0.4)
	await _snap(main, dir, "18_hw_shop")
	ui.close_modal()
	G.P.map = "forest"
	main.world.load_map("forest")
	hw_n = 0
	for en in main.world.enemies: hw_n += 1 if G.ENEMIES[en.stage].get("event", false) else 0
	print("forest event yokai=", hw_n)
	# ---- battle action panel with 5+ skills (caster tree) must stay on screen ----
	G.P.skills.merge({"fire": 5, "heal": 5, "clone": 1, "thunder": 1, "dragon": 1}, true)
	main.start_battle(17, null)
	await _wait(main, 0.5)
	main.battle.tab = "ninjutsu"
	main.battle._render_actions()
	await _wait(main, 0.3)
	var last: Control = main.battle.skill_grid.get_child(main.battle.skill_grid.get_child_count() - 1)
	var sc: ScrollContainer = main.battle.skill_grid.get_parent()
	print("ninjutsu buttons=", main.battle.skill_grid.get_child_count(), " scroll box bottom=", sc.get_global_rect().end.y, " (screen 720)")
	await _snap(main, dir, "18f_many_skills")
	sc.ensure_control_visible(last)
	await _wait(main, 0.3)
	await _snap(main, dir, "18g_many_skills_scrolled")
	# icon view + hover + drag-to-reorder
	var bt2 = main.battle
	G.P.skill_view = "icons"
	bt2._render_actions()
	await _wait(main, 0.3)
	print("icon view order=", bt2.ordered_skills("ninjutsu"))
	await _snap(main, dir, "18i_icon_view")
	var ib: Control = bt2.skill_grid.get_child(2)
	var mv2 := InputEventMouseMotion.new()
	mv2.position = ib.get_global_rect().get_center()
	mv2.global_position = mv2.position
	Input.parse_input_event(mv2)
	await _wait(main, 1.2)
	await _snap(main, dir, "18j_icon_tooltip")
	# real mouse drag: 5th icon onto the 1st
	var src_c: Vector2 = bt2.skill_grid.get_child(4).get_global_rect().get_center()
	var dst_c: Vector2 = bt2.skill_grid.get_child(0).get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = src_c
	press.global_position = src_c
	Input.parse_input_event(press)
	await main.get_tree().process_frame
	for i in 12:
		var m := InputEventMouseMotion.new()
		m.position = src_c.lerp(dst_c, (i + 1) / 12.0)
		m.global_position = m.position
		m.relative = (dst_c - src_c) / 12.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await main.get_tree().process_frame
	print("dragging mid=", main.get_viewport().gui_is_dragging(), " src disabled=", (bt2.skill_grid.get_child(4) as Button).disabled, " busy=", bt2.busy, " src_c=", src_c, " dst_c=", dst_c)
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = dst_c
	rel.global_position = dst_c
	Input.parse_input_event(rel)
	await _wait(main, 0.3)
	print("after drag order=", bt2.ordered_skills("ninjutsu"), " saved=", G.P.get("skill_order", {}))
	await _snap(main, dir, "18k_icon_reordered")
	G.P.skill_view = "list"
	bt2._render_actions()
	await _wait(main, 0.2)
	print("list view first button=", (bt2.skill_grid.get_child(0) as Button).text.get_slice("
", 0))
	main.battle.visible = false
	main.state = "world"
	# ---- bug report (F8) during a battle ----
	main.start_battle(17, null)
	await _wait(main, 0.5)
	_key(KEY_F8, true)
	_key(KEY_F8, false)
	await _wait(main, 0.5)
	var te: TextEdit = null
	for c in ui.modal_box.get_children():
		if c is TextEdit: te = c
	print("bug dialog open=", ui.modal.visible, " has textedit=", te != null)
	te.text = "ทดสอบรายงานบั๊ก: สกิลหลุดขอบจอ"
	await _snap(main, dir, "18h_bug_report")
	var where: String = ui.save_bug_report(te.text, true)
	ui.close_modal()
	print("bug saved to ", where, " json=", FileAccess.file_exists(where + "/report.json"), " png=", FileAccess.file_exists(where + "/screenshot.png"))
	print(FileAccess.get_file_as_string(where + "/report.json").substr(0, 300))
	main.battle.visible = false
	main.state = "world"
	# ---- EXP boost scroll ----
	G.P.gold = 3000
	ui.open_shop("buy")
	await _wait(main, 0.3)
	await _snap(main, dir, "18a_shop_exp_scroll")
	ui._buy("exp_scroll", 1)
	ui.close_modal()
	print("bought scroll inv=", G.P.inv.get("exp_scroll", 0), " gold=", G.P.gold)
	ui._bag_primary("item", "exp_scroll")
	print("boost left=", G.exp_boost_left(), " focus=", main.get_window().has_focus())
	await _wait(main, 2.0)
	var after_play := G.exp_boost_left()
	ui.open_menu("bag")
	await _wait(main, 2.0)
	var after_menu := G.exp_boost_left()
	await _snap(main, dir, "18c_exp_bag")
	ui.close_menu()
	print("boost after 2s play=", after_play, " after 2s in menu=", after_menu)
	main.start_battle(17, null)
	await _wait(main, 0.5)
	var ex0: int = G.enemy_stats(17).exp
	var exp_before: int = G.P.exp
	main.battle.e.hp = 0
	await main.battle._check_end()
	await _wait(main, 0.4)
	print("boosted battle exp base=", ex0, " gained=", G.P.exp - exp_before, " (lvl may have changed)")
	await _snap(main, dir, "18d_exp_win")
	main.ui.close_modal()
	main.battle.visible = false
	main.state = "world"
	await _wait(main, 0.3)
	await _snap(main, dir, "18e_exp_hud")
	G.P.exp_boost = 0.0
	# ---- game clear: final quest current + shogun down -> ending, achievements ----
	var f0 := FileAccess.open(G.ach_path(), FileAccess.WRITE)
	f0.store_string("{}")
	f0 = null
	G.load_achievements()
	G.P.quest.i = G.MAIN_QUESTS.size() - 1
	G.P.quest.active = true
	G.P.quest.base = G.P.kills.duplicate()
	G.P.erase("cleared")
	G.P.flags.erase("boss15")
	G.P.deaths = 0
	print("clear ready before boss=", G.game_clear_ready())
	main.start_battle(15, "boss")
	await _wait(main, 0.5)
	main.battle.e.hp = 0
	await main.battle._check_end()
	await _wait(main, 0.4)
	print("clear ready after boss=", G.game_clear_ready())
	for c in ui.modal_box.get_children():
		if c is HBoxContainer:
			for bb in c.get_children():
				if bb is Button and bb.text == "ไปต่อ": bb.pressed.emit()
	await _wait(main, 0.6)
	print("ending shown=", ui.modal.visible, " cleared=", G.P.get("cleared", false), " achievements=", G.achievements.keys())
	await _snap(main, dir, "18l_ending")
	ui.close_modal()
	ui.open_achievements()
	await _wait(main, 0.4)
	await _snap(main, dir, "18m_achievements")
	ui.close_modal()
	print("clear again ready=", G.game_clear_ready())
	G.P.map = "village"
	main.world.load_map("village")
	# ---- defeat: back to the inn with 1% HP/MP ----
	main.start_battle(17, null)
	await _wait(main, 0.5)
	var lost_gold: int = G.P.gold
	main.battle.p.hp = 0
	await main.battle._check_end()
	await _wait(main, 0.4)
	print("defeat hp=", G.P.hp, "/", G.max_hp(), " mp=", G.P.mp, "/", G.max_mp(), " map=", G.P.map, " gold lost=", lost_gold - G.P.gold)
	await _snap(main, dir, "18b_defeat")
	main.ui.close_modal()
	main.battle.visible = false
	main.state = "world"
	G.fix_player()
	print("after fix_player hp=", G.P.hp)
	G.P.map = "graveyard"
	main.world.load_map("graveyard")
	# ---- rare slimes ----
	main.start_battle(22, null)
	await _wait(main, 0.7)
	print("rainbow hp=", main.battle.e.max, " flee=", main.battle.e.st.flee.t)
	await _snap(main, dir, "19_rainbow_battle")
	main.battle.e.st.flee.t = 1
	main.battle.use_skill("slash")
	var t0 := Time.get_ticks_msec()
	while main.battle.visible and not main.ui.modal.visible and Time.get_ticks_msec() - t0 < 8000: await main.get_tree().process_frame
	await _wait(main, 0.3)
	await _snap(main, dir, "20_rainbow_escaped")
	main.ui.close_modal()
	main.battle.visible = false
	main.state = "world"
	main.start_battle(21, null)
	await _wait(main, 0.5)
	var gs: int = G.P.gold
	main.battle.e.hp = 0
	await main.battle._check_end()
	await _wait(main, 0.4)
	print("gold slime reward=", G.P.gold - gs)
	await _snap(main, dir, "21_gold_win")
	main.ui.close_modal()
	main.battle.visible = false
	main.state = "world"
	G.P.inv["tome_agi"] = 2
	var a0 := G.stat("agi")
	ui._bag_primary("item", "tome_agi")
	var a1 := G.stat("agi")
	G.P.gold = 10000
	G.reset_stats()
	print("tome agi ", a0, "->", a1, " after stat reset tome=", G.P.tome, " stat agi=", G.stat("agi"))
	ui.bag_sel = "item:tome_agi"
	ui.open_menu("bag")
	await _wait(main, 0.3)
	await _snap(main, dir, "22_tome_bag")
	ui.close_menu()
	main.world.go_map("village", "prev")
	G.P.halloween = "off"
	main.world.load_map("village")
	print("off: torii exit=", main.world.exits.size(), " night=", main.world.night.visible)
	G.P.lvl = 12
	G.P.skp = 3
	G.P.skills.merge({"cross": 2, "blade_art": 3, "iai": 1, "keen_eye": 2, "heal": 1, "chakra_flow": 1}, true)
	ui.skill_sel = "iron_body"
	G.P.gold = 2000
	for k in G.STATS: G.P[k] = G.class_stats()[k]
	G.P.str += 4
	G.P.vit += 2
	G.P.sp = 0
	var sk0 := G.skill_spent()
	G.reset_skills()
	print("skill reset: refunded=", sk0, " skp=", G.P.skp, " skills=", G.P.skills, " gold=", G.P.gold)
	var st0 := G.free_spent()
	G.reset_stats()
	print("stat reset: refunded=", st0, " sp=", G.P.sp, " str=", G.P.str, " gold=", G.P.gold)
	G.P.skills.merge({"cross": 2, "blade_art": 3, "iai": 1, "keen_eye": 2, "heal": 1, "chakra_flow": 1}, true)
	ui.open_menu("skills")
	await _wait(main, 0.3)
	ui._reset_from_menu("skills")
	await _wait(main, 0.3)
	await _snap(main, dir, "11a_reset_confirm")
	ui.close_modal()
	ui.open_menu("skills")
	await _wait(main, 0.3)
	await _snap(main, dir, "11_skills")
	ui.close_menu()
	ui.open_shop("gear")
	await _wait(main, 0.3)
	await _snap(main, dir, "12_shop")
	ui.open_forge()
	await _wait(main, 0.3)
	await _snap(main, dir, "13_forge")
	main.get_tree().quit()

## Bot playthrough at high time scale. Returns summary via print.
static func _sim(main: Node, cls: String) -> void:
	Engine.time_scale = 12.0
	G.P = G.new_player("bot", cls)
	G.P.music = false
	G.P.sfx = false
	main.start_game(false)
	var b = main.battle
	var mainstat: String = {"balanced": "str", "warrior": "str", "caster": "int", "ninja": "agi"}[cls]
	var order: Array = {"balanced": ["cross", "blade_art", "fire", "heal", "iai", "iron_body", "clone", "thunder", "storm", "rend", "battle_cry", "slash"],
		"warrior": ["cross", "blade_art", "iai", "iron_body", "heal", "rend", "storm", "battle_cry", "slash"],
		"caster": ["fire", "heal", "chakra_flow", "clone", "thunder", "hex", "spirit_ward", "dragon"],
		"ninja": ["kunai", "keen_eye", "barrage", "shadow_step", "bind", "venom", "ambush", "heal", "star"]}[cls]
	var slot: String = {"str": "weapon", "agi": "throw", "int": "charm"}[mainstat]
	var total := 0
	var losses := 0
	var out := []
	for z in ["forest", "mountain", "castle"]:
		G.P.map = z
		var zz: Dictionary = G.MAPS[z]
		var n := 0
		var bt := 0
		while not G.P.flags.has("boss%d" % zz.boss) and total < 400:
			var stage: int
			if G.P.lvl >= G.enemy_stats(zz.boss).rec - 1 or n > 70:
				stage = zz.boss
				bt += 1
			else:
				stage = zz.enemies[randi() % zz.enemies.size()]
				n += 1
			total += 1
			G.P.hp = G.max_hp()
			G.P.mp = G.max_mp()
			main.start_battle(stage, null)
			var res := [""]
			var cb := func(r: Dictionary) -> void: res[0] = r.res
			b.ended.connect(cb, CONNECT_ONE_SHOT)
			var turns := 0
			while res[0] == "" and turns < 200:
				await main.get_tree().process_frame
				if b.busy or b.over: continue
				turns += 1
				if b.chakra >= 100: b.use_ult()
				elif b.p.hp < b.p.max * 0.35 and (int(G.P.inv.get("hipotion", 0)) > 0 or int(G.P.inv.get("potion", 0)) > 0):
					b.use_item("hipotion" if int(G.P.inv.get("hipotion", 0)) > 0 else "potion")
				elif b.p.hp < b.p.max * 0.5 and G.P.skills.has("heal") and b.p.mp >= 14: b.use_skill("heal")
				else:
					var best := ""
					for id in G.P.skills:
						if id in ["heal", "clone"] or G.SKILLS[id].kind == "passive" or b.p.mp < G.SKILLS[id].mp: continue
						if best == "" or G.SKILLS[id].mp > G.SKILLS[best].mp: best = id
					b.use_skill(best)
			while res[0] == "": await main.get_tree().process_frame
			if res[0] != "win": losses += 1
			main.ui.close_modal()
			b.visible = false
			main.state = "world"
			if res[0] == "lose": G.P.map = z
			while G.P.sp > 0:
				G.P[mainstat] += 1
				G.P.sp -= 1
			for id in order:
				while G.skill_block(id) == "":
					G.P.skills[id] = int(G.P.skills.get(id, 0)) + 1
					G.P.skp -= 1
			for id in G.GEAR:
				var g: Dictionary = G.GEAR[id]
				if g.price > 0 and (g.slot == slot or g.slot == "armor") and g.price <= G.P.gold * 0.6 and not id in G.P.owned:
					G.P.gold -= g.price
					G.P.owned.append(id)
					G.P.eq[g.slot] = id
			while G.P.gold > 200 and int(G.P.inv.get("hipotion", 0)) < 4:
				G.P.inv["hipotion"] = int(G.P.inv.get("hipotion", 0)) + 1
				G.P.gold -= 65
			while G.P.gold > 60 and int(G.P.inv.get("potion", 0)) < 5:
				G.P.inv["potion"] = int(G.P.inv.get("potion", 0)) + 1
				G.P.gold -= 20
		var rr := []
		for rs in G.RARE_SLIMES:
			var won := 0
			for k in 4:
				if await _bot_fight(main, rs) == "win": won += 1
			rr.append("%s %d/4" % [G.ENEMIES[rs].actor, won])
		out.append("%s: fights=%d bossTries=%d lvl=%d rare[%s]" % [z, n, bt, G.P.lvl, ", ".join(rr)])
	print("SIM %s | %s | losses=%d total=%d" % [cls, " | ".join(out), losses, total])
	main.get_tree().quit()

## One full battle driven by the bot policy; returns "win" / "lose" / "escaped" / "flee"
static func _bot_fight(main: Node, stage: int) -> String:
	var b = main.battle
	G.P.hp = G.max_hp()
	G.P.mp = G.max_mp()
	var gold0: int = G.P.gold
	var inv0: Dictionary = G.P.inv.duplicate()
	main.start_battle(stage, null)
	var res := [""]
	var cb := func(r: Dictionary) -> void: res[0] = r.res
	b.ended.connect(cb, CONNECT_ONE_SHOT)
	while res[0] == "":
		await main.get_tree().process_frame
		if b.busy or b.over: continue
		if b.chakra >= 100: b.use_ult()
		else:
			var best := ""
			for id in G.P.skills:
				if id in ["heal", "clone"] or G.SKILLS[id].kind == "passive" or b.p.mp < G.SKILLS[id].mp: continue
				if best == "" or G.SKILLS[id].mp > G.SKILLS[best].mp: best = id
			b.use_skill(best)
	main.ui.close_modal()
	b.visible = false
	main.state = "world"
	G.P.gold = gold0
	G.P.inv = inv0
	return res[0]


# ================= responsive check =================
## Visible Controls (UI + battle layers) that stick out of the screen; ScrollContainers clip their children
static func _overflow(main: Node) -> Array:
	var S := UIKit.screen()
	var scr := Rect2(Vector2.ZERO, S).grow(1.0)
	var bad := []
	for top in [main.ui, main.battle]:
		if not top.visible: continue
		var stack := [top]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			for c in n.get_children(): stack.append(c)
			if not (n is Control) or not (n as Control).is_visible_in_tree(): continue
			var c: Control = n
			var r := c.get_global_rect()
			if r.size.x < 1 or r.size.y < 1: continue
			var clip := scr
			var a := c.get_parent()
			while a:
				if a is Control and (a as Control).clip_contents: clip = clip.intersection((a as Control).get_global_rect())
				a = a.get_parent()
			if clip.size.x <= 0 or clip.size.y <= 0: continue
			r = r.intersection(clip) if clip != scr else r
			if not scr.encloses(r):
				bad.append("%s %s" % [str(c.get_path()).replace("/root/Main/", ""), str(r)])
	return bad

static func _check(main: Node, dir: String, tag: String, issues: Array) -> void:
	await _wait(main, 0.35)
	var bad := _overflow(main)
	for b in bad: issues.append("%s: %s" % [tag, b])
	await _snap(main, dir, tag)

static func _res(main: Node, dir: String) -> void:
	var ui = main.ui
	var sizes := [Vector2i(1280, 720), Vector2i(1448, 794), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(800, 600), Vector2i(1366, 768)]
	var issues := []
	G.P = G.new_player("ทดสอบจอ", "caster")
	G.P.lvl = 25
	G.P.gold = 99999
	G.P.skills.merge({"fire": 5, "heal": 5, "clone": 1, "thunder": 1, "dragon": 5, "chakra_flow": 2, "hex": 1}, true)
	G.P.inv = {"potion": 5, "hipotion": 3, "ether": 4, "elixir": 2, "bomb": 3, "smoke": 1, "exp_scroll": 1}
	G.P.owned.append_array(["steel_katana", "kage_blade", "jade_charm", "chain", "venom_star", "sage_wand"])
	G.P.exp_boost = 600.0
	for sz in sizes:
		main.get_window().size = sz
		await _wait(main, 0.5)
		var tag := "%dx%d" % [sz.x, sz.y]
		var S := UIKit.screen()
		print("window ", tag, " -> screen ", S)
		main.to_title()
		await _check(main, dir, tag + "_01_title", issues)
		ui.show_slots("load")
		await _check(main, dir, tag + "_02_slots", issues)
		ui.show_class_select()
		await _check(main, dir, tag + "_03_class", issues)
		main.start_game(false)
		G.P.map = "village"
		G.P.x = 20.5 * 16
		G.P.y = 13.5 * 16
		main.world.load_map("village")
		await _check(main, dir, tag + "_04_world", issues)
		ui.talk_elder()
		await _check(main, dir, tag + "_05_dialog", issues)
		while ui.dialog.visible: ui.advance_dialog()
		ui.close_modal()
		for t in ["stats", "skills", "bag", "quests", "beast", "sys"]:
			ui.open_menu(t)
			await _check(main, dir, tag + "_06_menu_" + t, issues)
		ui.close_menu()
		ui.open_shop("buy")
		await _check(main, dir, tag + "_07_shop", issues)
		ui.open_forge()
		await _check(main, dir, tag + "_08_forge", issues)
		ui.close_modal()
		for view in ["list", "icons"]:
			G.P.skill_view = view
			main.start_battle(15, "boss")
			await _wait(main, 0.4)
			main.battle.tab = "ninjutsu"
			main.battle._render_actions()
			await _check(main, dir, tag + "_09_battle_" + view, issues)
			# hover the last skill: the tooltip must stay on screen
			# right-most fully visible button (list view scrolls, so use the top row there)
			var lastb: Control = main.battle.skill_grid.get_child(1 if view == "list" else main.battle.skill_grid.get_child_count() - 1)
			var hm := InputEventMouseMotion.new()
			hm.position = main.get_viewport().get_final_transform() * lastb.get_global_rect().get_center()   # window pixels
			hm.global_position = hm.position
			Input.parse_input_event(hm)
			await _wait(main, 0.7)
			var tp = RichTip._panel
			if tp == null or not tp.visible: issues.append("%s_%s: tooltip did not show" % [tag, view])
			elif not Rect2(Vector2.ZERO, UIKit.screen()).grow(1).encloses(tp.get_global_rect()): issues.append("%s_%s: tooltip off-screen %s" % [tag, view, tp.get_global_rect()])
			await _snap(main, dir, tag + "_09b_tip_" + view)
			main.battle.tab = "item"
			main.battle._render_actions()
			await _check(main, dir, tag + "_10_items_" + view, issues)
			main.battle.visible = false
			main.state = "world"
		ui.open_bug_report()
		await _check(main, dir, tag + "_11_bug", issues)
		ui.close_modal()
	print("RES issues=", issues.size())
	for i in issues: print("  ", i)
	main.get_tree().quit()
