class_name UIKit
## Shared fonts, pixel nine-patch styles (Ninja Adventure "Theme Wood", scaled x3) and widget helpers.

const PX := 3   # UI pixel scale
const INK := Color("#2a1a12")
const PAPER := Color("#f3e6d0")
const GOLD := Color("#ffd34d")
const MUTED := Color("#c9b49a")

static var _fonts := {}
static var _tex := {}
static var _theme: Theme

static func font_ui() -> Font:
	if not _fonts.has("ui"): _fonts["ui"] = load("res://assets/fonts/Kanit-Regular.ttf")
	return _fonts["ui"]

static func font_bold() -> Font:
	if not _fonts.has("bold"): _fonts["bold"] = load("res://assets/fonts/Kanit-Medium.ttf")
	return _fonts["bold"]

## MSDF copy so small text stays crisp under the x3 world camera
static func font_world() -> Font:
	if not _fonts.has("world"):
		var f: FontFile = (load("res://assets/fonts/Kanit-Medium.ttf") as FontFile).duplicate()
		f.multichannel_signed_distance_field = true
		_fonts["world"] = f
	return _fonts["world"]

static func scaled(path: String, s := PX) -> ImageTexture:
	var key := "%s@%d" % [path, s]
	if not _tex.has(key):
		var img: Image = G.tex(path).get_image()
		if img.is_compressed(): img.decompress()
		img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]

static func sbox(path: String, m: Array, pad: Array = [10, 8, 10, 8], s := PX) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = scaled("ui/" + path, s)
	b.texture_margin_left = m[0] * s
	b.texture_margin_top = m[1] * s
	b.texture_margin_right = m[2] * s
	b.texture_margin_bottom = m[3] * s
	b.content_margin_left = pad[0]
	b.content_margin_top = pad[1]
	b.content_margin_right = pad[2]
	b.content_margin_bottom = pad[3]
	return b

static func flat(col: Color, border := Color.TRANSPARENT, bw := 0, radius := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(radius)
	return b

static func theme() -> Theme:
	if _theme: return _theme
	var t := Theme.new()
	t.default_font = font_ui()
	t.default_font_size = 19
	var bn := sbox("button_normal.png", [4, 3, 4, 3], [14, 6, 14, 7])
	var bh := sbox("button_hover.png", [4, 3, 4, 3], [14, 6, 14, 7])
	var bp := sbox("button_disabled.png", [4, 3, 4, 3], [14, 7, 14, 6])
	var bd := sbox("button_disabled.png", [4, 3, 4, 3], [14, 6, 14, 7])
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.95, 0.88, 0.75, 0.5))
	t.set_constant("h_separation", "Button", 8)
	var panel := sbox("nine_path_bg.png", [5, 5, 5, 5], [18, 14, 18, 14])
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", PAPER)
	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_font("normal_font", "RichTextLabel", font_ui())
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	t.set_stylebox("panel", "TooltipPanel", sbox("nine_path_bg.png", [5, 5, 5, 5], [12, 8, 12, 8]))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font_size("font_size", "TooltipLabel", 16)
	t.set_stylebox("scroll", "VScrollBar", flat(Color(0, 0, 0, 0.3)))
	t.set_stylebox("grabber", "VScrollBar", flat(Color("#c08050")))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color("#e0a070")))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(Color("#e0a070")))
	t.set_stylebox("normal", "LineEdit", sbox("DialogueBoxSimple.png", [6, 6, 6, 6], [12, 6, 12, 6], 2))
	t.set_color("font_color", "LineEdit", INK)
	_theme = t
	return t

static var _tip_theme: Theme

## Theme with only the tooltip look, for controls that keep their own button style
static func tip_theme() -> Theme:
	if _tip_theme: return _tip_theme
	var t := Theme.new()
	t.set_stylebox("panel", "TooltipPanel", sbox("nine_path_bg.png", [5, 5, 5, 5], [12, 8, 12, 8]))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font("font", "TooltipLabel", font_ui())
	t.set_font_size("font_size", "TooltipLabel", 16)
	_tip_theme = t
	return t

## Visible game area in UI units (at least 1280x720; grows with the window's aspect ratio)
static func screen() -> Vector2:
	return (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size

## Anchor a control: a = [left, top, right, bottom] anchors (0..1), o = matching pixel offsets
static func anchor(c: Control, a: Array, o: Array) -> void:
	c.anchor_left = a[0]
	c.anchor_top = a[1]
	c.anchor_right = a[2]
	c.anchor_bottom = a[3]
	c.offset_left = o[0]
	c.offset_top = o[1]
	c.offset_right = o[2]
	c.offset_bottom = o[3]

# ---------- widgets ----------
static func label(text: String, size := 19, col := PAPER, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold: l.add_theme_font_override("font", font_bold())
	return l

static func rich(size := 17) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	return r

static func button(text: String, cb: Callable, size := 18, rich_tip := false) -> Button:
	var b: Button = RichTip.TipButton.new() if rich_tip else Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		cb.call())
	return b

static func panel(style := "nine_path_bg.png", pad: Array = [18, 14, 18, 14]) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(style, [5, 5, 5, 5], pad))
	return p

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func bar(col: Color, w := 240, h := 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_stylebox_override("background", flat(Color(0, 0, 0, 0.6), Color("#1a1210"), 2))
	b.add_theme_stylebox_override("fill", flat(col, Color(0, 0, 0, 0), 0))
	return b

static func icon(path: String, size := 32, tint := "") -> TextureRect:
	var r := TextureRect.new()
	r.texture = G.tex(path)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tint != "": r.modulate = Color(tint)
	return r

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
