class_name Sprites
## Builds SpriteFrames from the Ninja Adventure sheets.
## Character sheet (64x112): columns = down, up, left, right; rows 0-3 walk, row 4 attack, row 6 col 0 dead.
## Monster sheet (64x64): same columns, rows 0-3 walk.

const DIRS := ["down", "up", "left", "right"]
static var _cache := {}

static func _atlas(t: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = r
	return a

## 4-direction actor (characters & monsters)
static func actor(actor_name: String) -> SpriteFrames:
	if _cache.has(actor_name): return _cache[actor_name]
	var t: Texture2D = G.tex("actors/%s/sheet.png" % actor_name)
	var is_char := t.get_height() > 64
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for d in 4:
		var dn: String = DIRS[d]
		for a in ["idle_", "walk_", "attack_"]:
			sf.add_animation(a + dn)
		sf.set_animation_speed("walk_" + dn, 8)
		sf.set_animation_speed("idle_" + dn, 2)
		sf.set_animation_speed("attack_" + dn, 8)
		sf.set_animation_loop("attack_" + dn, false)
		for f in 4:
			sf.add_frame("walk_" + dn, _atlas(t, Rect2(d * 16, f * 16, 16, 16)))
		sf.add_frame("idle_" + dn, _atlas(t, Rect2(d * 16, 0, 16, 16)))
		if not is_char:
			sf.add_frame("idle_" + dn, _atlas(t, Rect2(d * 16, 16, 16, 16)))
		var arow := 4 if is_char else 1
		sf.add_frame("attack_" + dn, _atlas(t, Rect2(d * 16, arow * 16, 16, 16)))
		sf.add_frame("attack_" + dn, _atlas(t, Rect2(d * 16, arow * 16, 16, 16)))
	sf.add_animation("dead")
	sf.add_frame("dead", _atlas(t, Rect2(0, 96, 16, 16) if is_char else Rect2(0, 0, 16, 16)))
	_cache[actor_name] = sf
	return sf

## Boss built from separate strips: anim = {"idle": [file, fw, fh], ...}
static func boss(actor_name: String, anim: Dictionary) -> SpriteFrames:
	var key := "boss_" + actor_name
	if _cache.has(key): return _cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anim:
		var spec: Array = anim[a]
		var t: Texture2D = G.tex("actors/%s/%s" % [actor_name, spec[0]])
		var fw: int = spec[1]
		var fh: int = spec[2]
		sf.add_animation(a)
		sf.set_animation_speed(a, 8 if a != "idle" else 6)
		sf.set_animation_loop(a, a == "idle")
		for i in int(t.get_width() / fw):
			sf.add_frame(a, _atlas(t, Rect2(i * fw, 0, fw, fh)))
	_cache[key] = sf
	return sf

## One-shot FX strip: frame width = w / n
static func fx(fx_name: String, n: int, speed := 14.0) -> SpriteFrames:
	var key := "fx_%s" % fx_name
	if _cache.has(key): return _cache[key]
	var t: Texture2D = G.tex("fx/%s.png" % fx_name)
	var fw := t.get_width() / n
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", speed)
	for i in n:
		sf.add_frame("default", _atlas(t, Rect2(i * fw, 0, fw, t.get_height())))
	_cache[key] = sf
	return sf

const FX_FRAMES := {"cut": 4, "slash": 4, "explosion": 9, "flame": 8, "heal": 6, "kunai": 10, "shuriken": 10, "shield": 6, "smoke": 6, "spirit": 5, "thunder": 8, "boost": 8}

static func face(actor_name: String) -> Texture2D:
	return G.tex("actors/%s/face.png" % actor_name)

static func icon_rect(path: String, size := 40, tint := "") -> TextureRect:
	var r := TextureRect.new()
	r.texture = G.tex(path)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tint != "": r.modulate = Color(tint)
	return r
