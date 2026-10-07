class_name RichTip
## Keyword colouring for descriptions (HP red, MP blue, EXP green, gold yellow, statuses in their icon colours)
## and tooltip-capable controls whose tooltips render that colour.

const C_HP := "#ff6b5b"
const C_MP := "#5aa0ff"
const C_EXP := "#9be37a"
const C_GOLD := "#ffd34d"
const C_CRIT := "#ffb347"
const STATUS := {"ไหม้": "#ff8a3d", "พิษ": "#7bd35a", "มึนงง": "#ffd34d", "สตั้น": "#ffd34d", "อ่อนแรง": "#c08aff",
	"เกราะแตก": "#ff7a6a", "ฮึกเหิม": "#ffb347", "ม่านวิญญาณ": "#9fe8ff"}
const NUM := "(?:\\s*[+\\-x×]?\\s*\\d[\\d,]*(?:\\.\\d+)?(?:/\\d[\\d,]*)?%?)?"

static var _rx := []

static func _rules() -> Array:
	if _rx.is_empty():
		for pair in [["EXP" + NUM, C_EXP], ["HP" + NUM, C_HP], ["MP" + NUM, C_MP],
				["\\d[\\d,]*\\s*ทอง|ทอง\\s*\\d[\\d,]*", C_GOLD], ["คริ(?:ติคอล)?" + NUM, C_CRIT]]:
			var r := RegEx.new()
			r.compile(pair[0])
			_rx.append([r, pair[1]])
		for k in STATUS:
			var r2 := RegEx.new()
			r2.compile(k)
			_rx.append([r2, STATUS[k]])
	return _rx

## Plain text -> BBCode with coloured keywords (text must not already contain BBCode)
static func colorize(t: String) -> String:
	t = t.replace("[", "[lb]")
	for rule in _rules():
		t = (rule[0] as RegEx).sub(t, "[color=%s]$0[/color]" % rule[1], true)
	return t

## Tooltip body: wraps at ~440px, keeps short tips tight
static func make(for_text: String) -> Control:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", UIKit.font_ui())
	r.add_theme_font_override("bold_font", UIKit.font_bold())
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_color_override("default_color", UIKit.PAPER)
	# size it up front: the tooltip popup is sized from this, before the label wraps
	var f := UIKit.font_ui()
	var w := 0.0
	for line in for_text.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	w = minf(w + 12, 440)
	var h := f.get_multiline_string_size(for_text, HORIZONTAL_ALIGNMENT_LEFT, w - 4, 16).y
	r.custom_minimum_size = Vector2(w, h + 6)
	r.text = colorize(for_text)
	return r

# ---- in-game tooltip overlay (clamped to the visible screen, unlike engine popups) ----
static var _layer: CanvasLayer
static var _panel: PanelContainer
static var _label: RichTextLabel
static var _cur: Control

static func _ensure() -> void:
	if _layer and is_instance_valid(_layer): return
	_layer = CanvasLayer.new()
	_layer.layer = 120
	(Engine.get_main_loop() as SceneTree).root.add_child(_layer)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.sbox("nine_path_bg.png", [5, 5, 5, 5], [16, 10, 16, 12]))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_layer.add_child(_panel)
	_label = make("")
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)

## Called on hover: shows after a short delay if the mouse is still there
static func hover(c: Control) -> void:
	_cur = c
	await c.get_tree().create_timer(0.3).timeout
	if _cur != c or not is_instance_valid(c) or not c.is_visible_in_tree() or c.tooltip_text == "": return
	_ensure()
	var fresh := make(c.tooltip_text)
	_label.custom_minimum_size = fresh.custom_minimum_size
	_label.text = fresh.text
	fresh.free()
	_panel.reset_size()
	_panel.visible = true
	_panel.modulate.a = 0.0
	await c.get_tree().process_frame
	if _cur != c or not is_instance_valid(c): return
	_panel.reset_size()
	var S := UIKit.screen()
	var r := c.get_global_rect()
	var sz := _panel.size
	var pos := Vector2(r.position.x, r.position.y - sz.y - 6)    # above by default (most tips sit low on screen)
	if pos.y < 4: pos.y = r.end.y + 6
	pos.x = clampf(pos.x, 4, S.x - sz.x - 4)
	pos.y = clampf(pos.y, 4, S.y - sz.y - 4)
	_panel.position = pos
	_panel.modulate.a = 1.0

static func unhover(c: Control) -> void:
	if _cur != c: return
	_cur = null
	if _panel and is_instance_valid(_panel): _panel.visible = false

static func hook(c: Control) -> void:
	c.mouse_entered.connect(func() -> void: RichTip.hover(c))
	c.mouse_exited.connect(func() -> void: RichTip.unhover(c))
	c.tree_exiting.connect(func() -> void: RichTip.unhover(c))

class TipButton extends Button:
	func _init() -> void: RichTip.hook(self)
	func _get_tooltip(_p: Vector2) -> String: return ""   # we draw our own

class TipPanel extends PanelContainer:
	func _init() -> void: RichTip.hook(self)
	func _get_tooltip(_p: Vector2) -> String: return ""
