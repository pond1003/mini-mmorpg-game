extends Node
## Sound effects + looping music (autoload "Sfx").

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cur := ""
var _streams := {}

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -12
	add_child(_music)

func _stream(path: String) -> AudioStream:
	if not _streams.has(path): _streams[path] = load(path)
	return _streams[path]

func play(name: String, pitch := 1.0) -> void:
	if Engine.time_scale > 2.0 or not G.P.get("sfx", true): return
	for p in _players:
		if not p.playing:
			p.stream = _stream("res://assets/sfx/%s.wav" % name)
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
			p.play()
			return

func music(name: String) -> void:
	if name == _cur: return
	_cur = name
	if not G.P.get("music", true) or name == "":
		_music.stop()
		return
	var s: AudioStream = _stream("res://assets/music/%s.ogg" % name)
	if s is AudioStreamOggVorbis: s.loop = true
	_music.stream = s
	_music.play()

func refresh_music() -> void:
	var n := _cur
	_cur = ""
	music(n)
