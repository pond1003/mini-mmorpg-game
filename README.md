# mini-mmorpg-game
my own mini mmorpg power by cluade AI

**Shadow Ninja** — เกม RPG นินจาเทิร์นเบสแบบ pixel art ได้แรงบันดาลใจจาก *Sinjid: Shadow of the Warrior* สร้างด้วย Godot 4

## เล่นเกม
1. ดาวน์โหลด **Godot 4.7.2 (Windows, standard)** จาก https://godotengine.org/download/archive/
2. แตกไฟล์ไว้ที่ `tools/godot/` ให้มีไฟล์ `tools/godot/Godot_v4.7.2-stable_win64.exe`
3. ดับเบิลคลิก `shadow_ninja_godot/Play.bat`

หรือเปิด Godot แล้ว Import โฟลเดอร์ `shadow_ninja_godot`

## แจกเกม / ออก patch
- `Export.bat` → `export/ShadowNinja_win64.zip` (แตก zip แล้วเปิด `ShadowNinja.exe` ได้เลย) · ต้องมี export templates 4.7.2 ใน `%APPDATA%\Godot\export_templates\4.7.2.stable\`
- `Release.bat 1.0.1 "สิ่งที่เปลี่ยน"` → ตั้งเวอร์ชัน, build, สร้าง GitHub Release (`ShadowNinja.pck` + `ShadowNinja.exe` + `manifest.json` + zip ใน `export/release/`)
- เกมที่ export แล้วจะเช็ก release ล่าสุดตอนเปิด (และปุ่ม "เช็กอัปเดต" ในเมนูระบบ) แล้วโหลด `.pck` ใหม่ให้เอง และโหลด `.exe` ด้วยเฉพาะเมื่อ `engine` ใน manifest ไม่ตรงกับเวอร์ชัน Godot ของเกม · repo ต้องเป็น public
- ทดสอบกับเซิร์ฟเวอร์ในเครื่อง: ตั้ง env `SHADOW_NINJA_UPDATE_API` เป็น URL ของ JSON ที่หน้าตาเหมือน GitHub `releases/latest`

## มีอะไรในเกม
- 4 สายอาชีพ, เดิน WASD (วิ่งอัตโนมัติ R), แมพหมู่บ้าน + 3 พื้นที่ + สุสานอีเวนต์ฮาโลวีน
- ต่อสู้เทิร์นเบส สกิล 3 สาย + passive แบบต้นไม้สกิล Sinjid, บัพ/ดีบัพพร้อมไอคอน, โอกิ
- กระเป๋าแบบ MMORPG, ร้านค้า, พ่อค้าเร่, ตีบวก +10, ขายของตามเกรด, ศาลวาร์ป
- มอนสเตอร์ Elite, สไลม์ทอง/สไลม์รุ้ง, คัมภีร์ค่าสถานะ, ภารกิจหลัก + ค่าหัว
- เซฟได้ 5 ช่อง (`%APPDATA%\Godot\app_userdata\Shadow Ninja\save_N.json`)

## โครงสร้าง
| โฟลเดอร์ | |
|---|---|
| `shadow_ninja_godot/` | โปรเจกต์ Godot (โค้ดใน `scripts/`, ภาพ/เสียงใน `assets/`) |
| `tools/*.py` | สคริปต์เตรียม asset (คัดลอกจากแพ็ก, วาด pixel art ฮาโลวีน, ย้อมสีสไลม์) |
| `sinjid/` | เวอร์ชัน HTML รุ่นแรก (`python -m http.server` แล้วเปิด index.html) |

## เครดิต
- ภาพ เสียง เพลง: [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) โดย Pixel-boy & AAA — **CC0**
- ฟอนต์: [Kanit](https://fonts.google.com/specimen/Kanit) — SIL Open Font License
- ฟักทอง ป้ายหลุมศพ ลูกอม สไลม์ทอง/รุ้ง คัมภีร์: วาด/ย้อมสีเองด้วย `tools/*.py`
