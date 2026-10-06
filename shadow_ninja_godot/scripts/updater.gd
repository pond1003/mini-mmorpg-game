extends Node
## Patch updater for the exported Windows build. Each GitHub Release carries ShadowNinja.pck, ShadowNinja.exe
## and manifest.json ({"engine": "4.7.2.stable", "pck_sha256": ..., "exe_sha256": ...}). Normally only the .pck
## is downloaded; the .exe too when the release was built with a different Godot version. Files are swapped
## by a small script after the game exits, because the running game keeps its own .exe/.pck open.

const RELEASES_API := "https://api.github.com/repos/pond1003/mini-mmorpg-game/releases/latest"
const API_ENV := "SHADOW_NINJA_UPDATE_API"   # optional override, e.g. a local server for testing
const PCK_ASSET := "ShadowNinja.pck"
const EXE_ASSET := "ShadowNinja.exe"
const MANIFEST_ASSET := "manifest.json"
const HEADERS := ["User-Agent: ShadowNinja-Updater", "Accept: application/vnd.github+json"]

var http: HTTPRequest
var busy := false
var exe_path := OS.get_executable_path()   # the files next to it get replaced (tests point it elsewhere)

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)

## Only the exported game updates itself (ui.gd also skips it while G.testing)
func enabled() -> bool: return OS.has_feature("template")

func version() -> String: return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## Engine build this game runs on, same format as Godot's export_templates folder ("4.7.2.stable")
static func engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d.%s" % [v.major, v.minor, v.patch, v.status]

## true when version a ("1.2.10" / "v1.2.10") is newer than b
static func is_newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y: return x > y
	return false

## -> {"ok", "error", "newer", "version", "notes", "need_exe", "size" (bytes to download), "urls": {asset: url}, "manifest"}
func check(timeout_s := 30.0) -> Dictionary:
	if busy: return {"ok": false, "error": "กำลังทำงานอยู่"}
	busy = true
	http.timeout = timeout_s
	var info := await _check()
	busy = false
	return info

func _check() -> Dictionary:
	var api := OS.get_environment(API_ENV)
	var r := await _fetch(api if api != "" else RELEASES_API)
	if r.code == 404: return {"ok": false, "error": "ยังไม่มี release ให้อัปเดต (หรือ repo ยังเป็น private)"}
	if r.code != 200: return {"ok": false, "error": "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (%s)" % r.why}
	var d = JSON.parse_string(r.body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY: return {"ok": false, "error": "ข้อมูล release อ่านไม่ได้"}
	var info := {"ok": true, "error": "", "newer": false, "version": str(d.get("tag_name", "")).trim_prefix("v"),
		"notes": str(d.get("body", "")), "need_exe": false, "size": 0, "urls": {}, "sizes": {}, "manifest": {}}
	for a in d.get("assets", []):
		info.urls[a.get("name", "")] = a.get("browser_download_url", "")
		info.sizes[a.get("name", "")] = int(a.get("size", 0))
	if not is_newer(info.version, version()): return info
	for k in [PCK_ASSET, EXE_ASSET, MANIFEST_ASSET]:
		if not info.urls.has(k): return {"ok": false, "error": "release v%s ไม่ครบ (ไม่มี %s)" % [info.version, k]}
	var m := await _fetch(info.urls[MANIFEST_ASSET])
	if m.code != 200: return {"ok": false, "error": "โหลด manifest ไม่ได้ (%s)" % m.why}
	var man = JSON.parse_string(m.body.get_string_from_utf8())
	if typeof(man) != TYPE_DICTIONARY or str(man.get("pck_sha256", "")).length() != 64 or str(man.get("exe_sha256", "")).length() != 64:
		return {"ok": false, "error": "manifest ของ release v%s ไม่ถูกต้อง" % info.version}
	info.manifest = man
	info.need_exe = str(man.get("engine", "")) != engine()
	info.size = info.sizes[PCK_ASSET] + (info.sizes[EXE_ASSET] if info.need_exe else 0)
	info.newer = true
	return info

## Downloads + verifies <name>.pck.new (and <name>.exe.new when needed) next to the exe. Returns "" on success, else an error message.
func download(info: Dictionary) -> String:
	if busy: return "กำลังทำงานอยู่"
	busy = true
	http.timeout = 0.0   # no cap: the files can take a while on a slow connection
	var err := await _download_verified(info.urls[PCK_ASSET], _pck_path() + ".new", info.manifest.pck_sha256)
	if err == "" and info.need_exe:
		err = await _download_verified(info.urls[EXE_ASSET], exe_path + ".new", info.manifest.exe_sha256)
		if err != "": DirAccess.remove_absolute(_pck_path() + ".new")
	busy = false
	return err

func _download_verified(url: String, dest: String, sha: String) -> String:
	http.download_file = dest
	var r := await _fetch(url)
	http.download_file = ""
	if r.code != 200:
		DirAccess.remove_absolute(dest)
		return "ดาวน์โหลดไม่สำเร็จ (%s) · ถ้าเกมอยู่ในโฟลเดอร์ที่เขียนไม่ได้ ให้ย้ายไปไว้ที่อื่น" % r.why
	if FileAccess.get_sha256(dest) != sha.to_lower():
		DirAccess.remove_absolute(dest)
		return "ไฟล์ที่โหลดมาเสียหาย (sha256 ไม่ตรง) · ลองใหม่อีกครั้ง"
	return ""

## Quit, then (once this process is gone) move the .new files into place and relaunch.
## If the exe can't be replaced, the pck is left alone too so the old exe/pck pair stays consistent.
func restart_into_patch() -> void:
	var exe := exe_path.replace("/", "\\")
	var pck := _pck_path().replace("/", "\\")
	var pid := OS.get_process_id()
	var bat := ProjectSettings.globalize_path("user://apply_patch.bat")
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		push_error("updater: cannot write %s (%d)" % [bat, FileAccess.get_open_error()])
		return
	f.store_string("\r\n".join(PackedStringArray([
		"@echo off",
		":wait",
		"tasklist /fi \"PID eq %d\" /nh | find \"%d\" >nul && (timeout /t 1 /nobreak >nul & goto wait)" % [pid, pid],
		"if exist \"%s.new\" move /y \"%s.new\" \"%s\" >nul || (del \"%s.new\" & goto launch)" % [exe, exe, exe, pck],
		"move /y \"%s.new\" \"%s\" >nul" % [pck, pck],
		":launch",
		"start \"\" \"%s\"" % exe,
		""])))
	f.close()
	OS.create_process("cmd.exe", ["/c", bat])
	get_tree().quit()

func _pck_path() -> String: return exe_path.get_basename() + ".pck"

## -> {"code": HTTP status or -1, "why": short reason for messages, "body": PackedByteArray}
func _fetch(url: String) -> Dictionary:
	var e := http.request(url, HEADERS)
	if e != OK: return {"code": -1, "why": "request error %d" % e, "body": PackedByteArray()}
	var res: Array = await http.request_completed
	if res[0] != HTTPRequest.RESULT_SUCCESS: return {"code": -1, "why": "network error %d" % res[0], "body": PackedByteArray()}
	return {"code": res[1], "why": "HTTP %d" % res[1], "body": res[3]}
