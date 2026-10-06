# Audit Log

## 2026-10-06
- (earlier) — ย้ายโฟลเดอร์เซฟ `%APPDATA%\Godot\app_userdata\Shadow Ninja` ไป `%OneDrive%\GameSaves\Shadow Ninja` แล้วสร้าง junction กลับมาที่เดิม; backup ไว้ที่ `%USERPROFILE%\ShadowNinja_save_backup_2026-10-06` (hash ตรงกัน)
- (earlier) — สร้าง `TODO.md` (concept เกรดอุปกรณ์ + กาชา, งานรอทำ) และบันทึกความจำ "ขอดู To do"
- 09:24 — สร้าง audit log นี้ (ผู้ใช้อนุมัติ)
- 09:24 — เริ่มโหลด Godot 4.7.2 export templates (1.28 GB) ลง scratchpad
- 09:24 — เช็ก repo ก่อนเปิดเป็น public: ไม่เจอ secret, asset เป็น CC0/OFL; commit history มีอีเมล 2 อัน
- 09:26 — ติดตั้ง export templates ที่ `%APPDATA%\Godot\export_templates\4.7.2.stable` (ลบไฟล์ .tpz แล้ว)
- 09:30 — เพิ่ม `config/version="1.0.0"`, `export_presets.cfg` (Windows, exe + pck แยก), `Export.bat`, `Release.bat`
- 09:30 — เพิ่ม `scripts/updater.gd` + เชื่อม UI (เลขเวอร์ชันหน้า title, เช็กอัปเดตตอนเปิดเกม, ปุ่มในเมนูระบบ)
- 09:35 — ทดสอบ: parse ผ่าน, export ได้ zip 53 MB, exe เปิดได้, is_newer 7/7, autotest --shots ผ่าน (เซฟจริงไม่ถูกแตะ)
- 09:35 — อัปเดต README + TODO
- 09:50 — หน้า title: ล็อกปุ่มเริ่มเกมระหว่างเช็กอัปเดตครั้งแรก (สูงสุด 8 วิ) + แก้ timeout ตอนโหลด .pck (ไม่จำกัดเวลา); export ใหม่ + autotest ผ่าน
- 09:50 — เพิ่ม TODO: ระบบอัปเดตตัว exe
- 09:55 — ระบบอัปเดต exe: updater.gd ใช้ manifest.json (engine + sha256), โหลด exe เฉพาะเมื่อ engine ต่าง; Release.bat แนบ exe + manifest; เพิ่ม env SHADOW_NINJA_UPDATE_API สำหรับทดสอบ
- 09:56 — แก้บั๊ก Release.bat ไม่เปลี่ยน config/version (quote ใน PowerShell) — เจอจากการทดสอบ
- 09:58 — ทดสอบครบวงจรกับเซิร์ฟเวอร์จำลองในเครื่อง: check/404/download/sha256/สลับ exe+pck/เปิดเกมใหม่ ผ่าน
- 10:00 — เสียงเพลง + เสียงประกอบ ค่าเริ่มต้นเป็นปิด (game.gd new_player, sfx.gd, ui.gd); เซฟเดิมไม่ถูกแก้
- 10:02 — export v1.0.0 ใหม่ + autotest 38 ภาพผ่าน; ลบ export/release ที่ใช้ทดสอบ
- 10:10 — ปรับสูตรฮีล (ผู้ใช้เลือกสูตร C): heal = (5% maxHP + INT×0.5) × เลเวลสกิล; sim caster ก่อน/หลัง: แพ้ 0 ทั้งคู่, จำนวนไฟต์ 70→73; export ใหม่
