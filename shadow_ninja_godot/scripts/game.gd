extends Node
## Global game data + player state (autoload "G").

const TS := 16
const OLD_SAVE := "user://save.json"   # single-save file from older versions -> moved to slot 1
const SAVE_SLOTS := 5
var slot := 1          # active save slot
var testing := false   # autotest runs write to their own file and never touch real slots

var P: Dictionary = {}          # player save data
var rng := RandomNumberGenerator.new()

const TREES := {"katana": "คาตานะ", "shuriken": "ดาวกระจาย", "ninjutsu": "นินจุตสึ", "item": "ไอเทม"}

# kind: melee | ranged | magic | heal | buff | passive
# pos: [column 0-1 inside its tree, row 0-4], pre: skills that must be learned first (Sinjid-style tree)
# passive "pt": stat (always on) | debuff (chance on hit) | buff (start of battle)
const SKILLS := {
	"slash":   {"tree": "katana", "pos": [0, 0], "pre": [], "name": "ฟันดาบ", "mp": 0, "req": 1, "kind": "melee", "hits": 1, "base": 1.0, "per": 0.15, "fx": "cut", "icon": "cut"},
	"cross":   {"tree": "katana", "pos": [0, 1], "pre": ["slash"], "name": "ฟันกากบาท", "mp": 8, "req": 3, "kind": "melee", "hits": 2, "base": 0.75, "per": 0.1, "fx": "cut", "icon": "counter"},
	"blade_art": {"tree": "katana", "pos": [1, 1], "pre": ["slash"], "name": "วิชาดาบขั้นสูง", "mp": 0, "req": 2, "kind": "passive", "pt": "stat", "icon": "upgrade"},
	"iai":     {"tree": "katana", "pos": [0, 2], "pre": ["cross"], "name": "ไออิ ชักดาบสายฟ้าแลบ", "mp": 15, "req": 6, "kind": "melee", "hits": 1, "base": 2.0, "per": 0.3, "crit": 30, "fx": "slash", "icon": "attack_up"},
	"iron_body": {"tree": "katana", "pos": [1, 2], "pre": ["blade_art"], "name": "กายาเหล็กกล้า", "mp": 0, "req": 5, "kind": "passive", "pt": "stat", "icon": "defense_up"},
	"storm":   {"tree": "katana", "pos": [0, 3], "pre": ["iai"], "name": "พายุใบมีด", "mp": 30, "req": 12, "kind": "melee", "hits": 5, "base": 0.6, "per": 0.08, "fx": "slash", "icon": "magic_weapon"},
	"rend":    {"tree": "katana", "pos": [1, 3], "pre": ["iron_body"], "name": "ฟันทำลายเกราะ", "mp": 0, "req": 8, "kind": "passive", "pt": "debuff", "icon": "downgrade"},
	"battle_cry": {"tree": "katana", "pos": [1, 4], "pre": ["rend"], "name": "โห่ร้องแห่งศึก", "mp": 0, "req": 10, "kind": "passive", "pt": "buff", "icon": "sing"},
	"star":    {"tree": "shuriken", "pos": [0, 0], "pre": [], "name": "ปาดาวกระจาย", "mp": 0, "req": 1, "kind": "ranged", "hits": 1, "base": 0.9, "per": 0.15, "proj": "shuriken", "icon": "shuriken"},
	"kunai":   {"tree": "shuriken", "pos": [0, 1], "pre": ["star"], "name": "คุไนอาบพิษ", "mp": 8, "req": 4, "kind": "ranged", "hits": 1, "base": 0.6, "per": 0.0, "proj": "kunai", "icon": "kunai",
				"status": {"id": "poison", "turns": 3, "pow": "ranged", "base": 0.5, "per": 0.1}},
	"keen_eye": {"tree": "shuriken", "pos": [1, 1], "pre": ["star"], "name": "ตาเหยี่ยว", "mp": 0, "req": 2, "kind": "passive", "pt": "stat", "icon": "vision"},
	"barrage": {"tree": "shuriken", "pos": [0, 2], "pre": ["kunai"], "name": "ฝนดาวกระจาย", "mp": 18, "req": 8, "kind": "ranged", "hits": 4, "base": 0.55, "per": 0.08, "proj": "shuriken", "icon": "explosion"},
	"shadow_step": {"tree": "shuriken", "pos": [1, 2], "pre": ["keen_eye"], "name": "ก้าวย่างเงา", "mp": 0, "req": 6, "kind": "passive", "pt": "stat", "icon": "boot"},
	"bind":    {"tree": "shuriken", "pos": [0, 3], "pre": ["barrage"], "name": "ด้ายเงาตรึงร่าง", "mp": 20, "req": 10, "kind": "ranged", "hits": 1, "base": 0.8, "per": 0.0, "proj": "kunai", "icon": "camouflage",
				"stun": [50, 6]},
	"venom":   {"tree": "shuriken", "pos": [1, 3], "pre": ["shadow_step"], "name": "พิษเข้มข้น", "mp": 0, "req": 9, "kind": "passive", "pt": "debuff", "icon": "death"},
	"ambush":  {"tree": "shuriken", "pos": [1, 4], "pre": ["venom"], "name": "จู่โจมจากเงา", "mp": 0, "req": 11, "kind": "passive", "pt": "buff", "icon": "moon"},
	"fire":    {"tree": "ninjutsu", "pos": [0, 0], "pre": [], "name": "คาถาลูกไฟ", "mp": 10, "req": 2, "kind": "magic", "base": 1.1, "per": 0.18, "fx": "flame", "icon": "fireball",
				"status": {"id": "burn", "turns": 2, "pow": "magic", "base": 0.35, "per": 0.0}},
	"heal":    {"tree": "ninjutsu", "pos": [1, 0], "pre": [], "name": "คาถาฟื้นฟู", "mp": 14, "req": 3, "kind": "heal", "icon": "heal"},
	"clone":   {"tree": "ninjutsu", "pos": [0, 1], "pre": ["fire"], "name": "แยกเงาพันร่าง", "mp": 16, "req": 5, "kind": "buff", "icon": "mist"},
	"chakra_flow": {"tree": "ninjutsu", "pos": [1, 1], "pre": ["heal"], "name": "จักระไหลเวียน", "mp": 0, "req": 4, "kind": "passive", "pt": "stat", "icon": "orb_water"},
	"thunder": {"tree": "ninjutsu", "pos": [0, 2], "pre": ["clone"], "name": "สายฟ้าพิโรธ", "mp": 25, "req": 9, "kind": "magic", "base": 2.0, "per": 0.3, "fx": "thunder", "icon": "thunder", "stun": [25, 0]},
	"hex":     {"tree": "ninjutsu", "pos": [1, 2], "pre": ["chakra_flow"], "name": "คำสาปอ่อนแรง", "mp": 0, "req": 7, "kind": "passive", "pt": "debuff", "icon": "book_darkness"},
	"dragon":  {"tree": "ninjutsu", "pos": [0, 3], "pre": ["thunder"], "name": "มังกรอัคคีทมิฬ", "mp": 45, "req": 15, "kind": "magic", "base": 3.5, "per": 0.4, "fx": "explosion", "icon": "orb_fire",
				"status": {"id": "burn", "turns": 3, "pow": "magic", "base": 0.5, "per": 0.0}},
	"spirit_ward": {"tree": "ninjutsu", "pos": [1, 3], "pre": ["hex"], "name": "ม่านวิญญาณ", "mp": 0, "req": 11, "kind": "passive", "pt": "buff", "icon": "orb_light"},
}
const SKILL_MAX := 5

# icon: res path under assets/, tint: optional hex
const GEAR := {
	"wood_katana": {"slot": "weapon", "name": "ดาบไม้ฝึกหัด", "atk": 2, "price": 0, "icon": "icons/w_sword.png"},
	"steel_katana": {"slot": "weapon", "name": "คาตานะเหล็กกล้า", "atk": 6, "price": 120, "icon": "icons/w_katana.png"},
	"kage_blade": {"slot": "weapon", "name": "ดาบเงาจันทรา", "atk": 12, "price": 450, "icon": "icons/w_ninjaku.png"},
	"dragon_fang": {"slot": "weapon", "name": "เขี้ยวมังกร", "atk": 20, "price": 1200, "icon": "icons/w_sword2.png"},
	"muramasa": {"slot": "weapon", "name": "มุรามาสะต้องสาป", "atk": 32, "price": 3000, "icon": "icons/w_bigsword.png"},
	"iron_star": {"slot": "throw", "name": "ดาวกระจายเหล็ก", "atk": 2, "price": 0, "icon": "icons/shuriken.png"},
	"steel_kunai": {"slot": "throw", "name": "คุไนเหล็กกล้า", "atk": 6, "price": 150, "icon": "icons/kunai.png"},
	"venom_star": {"slot": "throw", "name": "ดาวพิษงูเห่า", "atk": 11, "price": 500, "icon": "icons/shuriken.png", "tint": "#7dff6a"},
	"phoenix_star": {"slot": "throw", "name": "ดาวกระจายหงส์ไฟ", "atk": 19, "price": 1400, "icon": "icons/shuriken.png", "tint": "#ffa040"},
	"paper_charm": {"slot": "charm", "name": "ยันต์กระดาษ", "atk": 1, "mp": 0, "price": 0, "icon": "icons/scroll.png"},
	"jade_charm": {"slot": "charm", "name": "เครื่องรางหยก", "atk": 5, "mp": 15, "price": 180, "icon": "skills/amulet.png"},
	"spirit_scroll": {"slot": "charm", "name": "คัมภีร์สายฟ้า", "atk": 11, "mp": 35, "price": 600, "icon": "icons/scroll_thunder.png"},
	"dragon_orb": {"slot": "charm", "name": "คัมภีร์มังกรไฟ", "atk": 20, "mp": 60, "price": 1600, "icon": "icons/scroll_fire.png"},
	"cloth": {"slot": "armor", "name": "ชุดผ้าดำ", "def": 1, "hp": 0, "price": 0, "icon": "skills/armor.png", "tint": "#8a8a8a"},
	"leather": {"slot": "armor", "name": "เกราะหนัง", "def": 3, "hp": 20, "price": 100, "icon": "skills/armor.png", "tint": "#c08050"},
	"chain": {"slot": "armor", "name": "เสื้อโซ่ถัก", "def": 6, "hp": 45, "price": 400, "icon": "skills/armor.png", "tint": "#d0d8e8"},
	"shadow_garb": {"slot": "armor", "name": "ชุดนินจาเงา", "def": 10, "hp": 80, "price": 1100, "icon": "skills/armor.png", "tint": "#9070ff"},
	"oni_armor": {"slot": "armor", "name": "เกราะปีศาจ", "def": 15, "hp": 140, "price": 2800, "icon": "skills/armor.png", "tint": "#ff5040"},
	# --- wandering merchant stock: "shop" = zone, "cls" = class lock, "bonus" = extra STR/AGI/INT/VIT, crit/dodge in % ---
	"ronin_blade": {"slot": "weapon", "name": "ดาบโรนินพเนจร", "atk": 9, "bonus": {"str": 2, "agi": 2, "int": 2}, "price": 600, "icon": "icons/w_rapier.png", "shop": "forest", "cls": ["balanced"]},
	"oni_club": {"slot": "weapon", "name": "กระบองยักษ์ป่า", "atk": 11, "bonus": {"str": 3, "vit": 2}, "price": 600, "icon": "icons/w_club.png", "shop": "forest", "cls": ["warrior"]},
	"sage_wand": {"slot": "charm", "name": "คทาฤาษีไผ่", "atk": 9, "mp": 25, "bonus": {"int": 4}, "price": 600, "icon": "icons/w_magicwand.png", "shop": "forest", "cls": ["caster"]},
	"wind_sai": {"slot": "throw", "name": "ไซสายลม", "atk": 9, "bonus": {"agi": 3}, "crit": 3, "price": 600, "icon": "icons/w_sai.png", "shop": "forest", "cls": ["ninja"]},
	"leaf_cloak": {"slot": "armor", "name": "เสื้อคลุมใบไผ่", "def": 4, "hp": 30, "bonus": {"agi": 1}, "dodge": 3, "price": 450, "icon": "skills/armor.png", "tint": "#7ad35a", "shop": "forest"},
	"yeti_lance": {"slot": "weapon", "name": "ทวนเยติ", "atk": 18, "bonus": {"str": 3, "agi": 3, "int": 3}, "price": 1800, "icon": "icons/w_lance.png", "tint": "#cfeaff", "shop": "mountain", "cls": ["balanced"]},
	"frost_axe": {"slot": "weapon", "name": "ขวานน้ำแข็ง", "atk": 22, "bonus": {"str": 5, "vit": 3}, "crit": 3, "price": 1800, "icon": "icons/w_axe.png", "tint": "#9fe8ff", "shop": "mountain", "cls": ["warrior"]},
	"glacier_tome": {"slot": "charm", "name": "ตำราธารน้ำแข็ง", "atk": 20, "mp": 60, "bonus": {"int": 6}, "price": 1800, "icon": "icons/book.png", "tint": "#9fe8ff", "shop": "mountain", "cls": ["caster"]},
	"tengu_star": {"slot": "throw", "name": "ดาวขนนกเท็งงุ", "atk": 19, "bonus": {"agi": 5}, "crit": 5, "price": 1800, "icon": "icons/shuriken.png", "tint": "#c0f0ff", "shop": "mountain", "cls": ["ninja"]},
	"snow_mantle": {"slot": "armor", "name": "เสื้อคลุมหิมะ", "def": 9, "hp": 70, "bonus": {"vit": 3}, "price": 1300, "icon": "skills/armor.png", "tint": "#e8f4ff", "shop": "mountain"},
	"kensei_katana": {"slot": "weapon", "name": "คาตานะเคนเซย์", "atk": 32, "bonus": {"str": 5, "agi": 5, "int": 5}, "crit": 4, "price": 4500, "icon": "icons/w_katana.png", "tint": "#ffd34d", "shop": "castle", "cls": ["balanced"]},
	"warlord_hammer": {"slot": "weapon", "name": "ค้อนขุนศึก", "atk": 38, "bonus": {"str": 8, "vit": 5}, "price": 4500, "icon": "icons/w_hammer.png", "tint": "#ff7060", "shop": "castle", "cls": ["warrior"]},
	"void_scroll": {"slot": "charm", "name": "คัมภีร์ห้วงมืด", "atk": 34, "mp": 100, "bonus": {"int": 9}, "price": 4500, "icon": "icons/scroll_fire.png", "tint": "#b080ff", "shop": "castle", "cls": ["caster"]},
	"shadow_fang": {"slot": "throw", "name": "คุไนเขี้ยวเงา", "atk": 32, "bonus": {"agi": 8}, "crit": 8, "dodge": 4, "price": 4500, "icon": "icons/kunai.png", "tint": "#b080ff", "shop": "castle", "cls": ["ninja"]},
	# Halloween exchange (paid in candy at the vampire)
	"reaper_blade": {"slot": "weapon", "name": "ดาบเคียวยมทูต", "atk": 18, "bonus": {"str": 4}, "crit": 4, "price": 900, "candy": 25, "icon": "icons/w_bigsword.png", "tint": "#b080ff", "shop": "event"},
	"bat_star": {"slot": "throw", "name": "ดาวปีกค้างคาว", "atk": 16, "bonus": {"agi": 4}, "dodge": 3, "price": 900, "candy": 25, "icon": "icons/shuriken.png", "tint": "#9050d0", "shop": "event"},
	"jack_lantern": {"slot": "charm", "name": "โคมฟักทองต้องมนตร์", "atk": 16, "mp": 40, "bonus": {"int": 4}, "price": 900, "candy": 25, "icon": "obj/pumpkin.png", "shop": "event"},
	"phantom_cloak": {"slot": "armor", "name": "ผ้าคลุมภูตพราย", "def": 8, "hp": 70, "bonus": {"vit": 2}, "dodge": 4, "price": 800, "candy": 20, "icon": "skills/armor.png", "tint": "#6a4a9a", "shop": "event"},
	"demon_mail": {"slot": "armor", "name": "เกราะอสูรทมิฬ", "def": 18, "hp": 160, "bonus": {"vit": 5, "str": 2}, "price": 4200, "icon": "skills/armor.png", "tint": "#b04060", "shop": "castle"},
}

# Elite monsters: random tougher variants roaming the zones
const ELITE_CHANCE := 0.12
const ELITE_HP := 3.0      # HP multiplier
const ELITE_POW := 1.5     # ATK / MAG / DEF multiplier
const ELITE_LOOT := 3      # EXP and drop rolls multiplier
const ELITE_GOLD := 5      # gold multiplier
const GEAR_DROP := 0.03    # chance a normal monster drops equipment
const ELITE_GEAR_DROP := 0.35
const SELL_RATE := 0.4     # gear sells for this share of its price (+15% per forge level)
# equipment that can drop in each zone, by shop price range
const ZONE_GEAR := {"village": [0, 700], "forest": [0, 700], "mountain": [300, 2000], "castle": [1000, 5000], "graveyard": [300, 2000]}

# ================= seasonal event =================
## "auto" = on during October, or forced "on" / "off" from the system menu
func halloween() -> bool:
	var m: String = P.get("halloween", "auto")
	if m == "on": return true
	if m == "off": return false
	return Time.get_date_dict_from_system().month == 10
const SLOTS := ["weapon", "throw", "charm", "armor"]
const SLOTNAME := {"weapon": "ดาบ", "throw": "อาวุธปา", "charm": "เครื่องราง", "armor": "ชุดเกราะ"}

const ITEMS := {
	"potion": {"name": "ยาสมุนไพร", "desc": "ฟื้น HP 60", "price": 20, "hp": 60, "icon": "icons/potion.png"},
	"hipotion": {"name": "ยาหัวใจทอง", "desc": "ฟื้น HP 200", "price": 65, "hp": 200, "icon": "icons/hipotion.png"},
	"ether": {"name": "น้ำจิตวิญญาณ", "desc": "ฟื้น MP 40", "price": 30, "mp": 40, "icon": "icons/ether.png"},
	"elixir": {"name": "น้ำอมฤต", "desc": "ฟื้น HP/MP เต็ม", "price": 250, "hp": 99999, "mp": 99999, "icon": "icons/elixir.png"},
	"bomb": {"name": "ระเบิดเพลิง", "desc": "ความเสียหาย 50+Lv×8 + ไหม้", "price": 45, "battle": true, "icon": "icons/bomb.png"},
	"smoke": {"name": "ตะปูเรือใบ", "desc": "โปรยแล้วหนีการต่อสู้ได้แน่นอน", "price": 35, "battle": true, "icon": "icons/smoke.png"},
	# stat tomes (rainbow slime): permanent +1, kept through stat resets; price 0 = not sold in shops, "sell" = buy-back value
	"tome_str": {"name": "คัมภีร์พลัง", "desc": "STR +1 ถาวร (ไม่หายเมื่อล้างแต้ม)", "price": 0, "sell": 1000, "tome": "str", "icon": "icons/tome_str.png"},
	"tome_agi": {"name": "คัมภีร์ความไว", "desc": "AGI +1 ถาวร (ไม่หายเมื่อล้างแต้ม)", "price": 0, "sell": 1000, "tome": "agi", "icon": "icons/tome_agi.png"},
	"tome_int": {"name": "คัมภีร์ปัญญา", "desc": "INT +1 ถาวร (ไม่หายเมื่อล้างแต้ม)", "price": 0, "sell": 1000, "tome": "int", "icon": "icons/tome_int.png"},
	"tome_vit": {"name": "คัมภีร์ร่างกาย", "desc": "VIT +1 ถาวร (ไม่หายเมื่อล้างแต้ม)", "price": 0, "sell": 1000, "tome": "vit", "icon": "icons/tome_vit.png"},
}
const MATS := {
	"herb": {"name": "สมุนไพรป่า", "price": 6, "icon": "icons/herb.png"},
	"iron": {"name": "แท่งเหล็ก", "price": 8, "icon": "icons/scrap_iron.png"},
	"branch": {"name": "กิ่งไผ่วิญญาณ", "price": 10, "icon": "icons/wolf_pelt.png"},
	"feather": {"name": "ขนนกเท็งงุ", "price": 25, "icon": "icons/tengu_feather.png"},
	"shard": {"name": "อัญมณีเงา", "price": 35, "icon": "icons/shadow_shard.png"},
	"ruby": {"name": "อัญมณีโลหิต", "price": 45, "icon": "icons/oni_horn.png"},
	"candy": {"name": "ลูกอมฟักทอง", "price": 3, "icon": "icons/candy.png"},
}

# sprite: char (64x112 sheet) | mon (64x64 sheet) | boss (anim strips)
const ENEMIES := [
	{},
	{"name": "โจรป่า", "sprite": "char", "actor": "CamouflageGreen", "moves": ["hit"], "drops": [["herb", 0.5]]},
	{"name": "ปีศาจไผ่", "sprite": "mon", "actor": "Bamboo", "moves": ["hit", "bite"], "drops": [["branch", 0.6]]},
	{"name": "ซามูไรพเนจร", "sprite": "char", "actor": "Samurai", "moves": ["hit", "heavy"], "drops": [["iron", 0.55]]},
	{"name": "ทานูกิเจ้าเล่ห์", "sprite": "mon", "actor": "Racoon", "moves": ["hit", "star"], "drops": [["iron", 0.3], ["herb", 0.3]]},
	{"name": "ราชันไผ่ยักษ์", "sprite": "boss", "actor": "GiantBamboo", "boss": true, "moves": ["hit", "heavy", "heal"], "drops": [["branch", 1.0, 3]],
		"anim": {"idle": ["idle.png", 62, 62], "attack": ["attack.png", 62, 62], "hit": ["hit.png", 62, 62]}, "bscale": 4.0, "lift": 5},
	{"name": "นินจาเงา", "sprite": "char", "actor": "NinjaDark", "moves": ["hit", "star", "poison"], "drops": [["shard", 0.3], ["iron", 0.3]]},
	{"name": "พระนักรบ", "sprite": "char", "actor": "Monk", "moves": ["hit", "heavy", "heal"], "drops": [["herb", 0.6]]},
	{"name": "หุ่นกลไก", "sprite": "char", "actor": "RobotGrey", "moves": ["hit", "heavy", "stun"], "drops": [["iron", 0.7]]},
	{"name": "เท็งงุ", "sprite": "char", "actor": "Tengu", "moves": ["hit", "fire", "star"], "drops": [["feather", 0.5]]},
	{"name": "ราชาเท็งงุแดง", "sprite": "boss", "actor": "TenguRed", "boss": true, "moves": ["hit", "heavy", "stun", "fire", "heal"], "drops": [["feather", 1.0, 3], ["ruby", 1.0, 2]],
		"anim": {"idle": ["idle.png", 82, 82], "attack": ["attack.png", 82, 82], "hit": ["hit.png", 82, 82]}, "bscale": 4.2, "lift": 24},
	{"name": "นักฆ่าหน้ากาก", "sprite": "char", "actor": "NinjaMasked", "moves": ["hit", "poison", "star"], "drops": [["shard", 0.45]]},
	{"name": "อสูรโครงกระดูก", "sprite": "char", "actor": "SkeletonDemon", "moves": ["hit", "heavy", "drain"], "drops": [["iron", 0.5], ["shard", 0.25]]},
	{"name": "จอมเวทมืด", "sprite": "char", "actor": "SorcererBlack", "moves": ["fire", "poison", "heal"], "drops": [["herb", 0.6], ["feather", 0.2]]},
	{"name": "ปีศาจแดง", "sprite": "char", "actor": "DemonRed", "moves": ["hit", "heavy", "stun", "fire"], "drops": [["ruby", 0.35]]},
	{"name": "โชกุนเงา คาเงะโมริ", "sprite": "boss", "actor": "GiantRedSamurai", "boss": true, "moves": ["hit", "heavy", "fire", "drain", "stun", "heal"], "drops": [["shard", 1.0, 5]],
		"anim": {"idle": ["idle.png", 96, 48], "attack": ["attackleft.png", 96, 96], "hit": ["hit.png", 96, 48]}, "bscale": 3.2, "lift": 4},
	# --- Halloween event yokai (16-20): "auto" = stats scale to the player's level ---
	{"name": "โชจินโอบาเกะ โคมผี", "sprite": "mon", "actor": "LanternRed", "auto": true, "event": true, "moves": ["hit", "fire"], "drops": [["candy", 0.8], ["herb", 0.3]]},
	{"name": "หัวกะโหลกหลอน", "sprite": "mon", "actor": "Skull", "auto": true, "event": true, "moves": ["hit", "bite", "drain"], "drops": [["candy", 0.8], ["iron", 0.3]]},
	{"name": "วิญญาณเร่ร่อน", "sprite": "mon", "actor": "Spirit", "auto": true, "event": true, "moves": ["hit", "drain", "poison"], "drops": [["candy", 0.8], ["shard", 0.15]]},
	{"name": "ค้างคาวแวมไพร์", "sprite": "mon", "actor": "BlueBat", "auto": true, "event": true, "moves": ["hit", "bite", "drain"], "drops": [["candy", 0.8], ["feather", 0.2]]},
	{"name": "ราชาภูตพรายขาว", "sprite": "boss", "actor": "GiantSpirit", "boss": true, "auto": true, "event": true, "moves": ["hit", "drain", "fire", "stun", "heal"],
		"drops": [["candy", 1.0, 12], ["ruby", 0.6]], "anim": {"idle": ["idle.png", 50, 50], "attack": ["idle.png", 50, 50], "hit": ["hit.png", 50, 50]}, "bscale": 4.4, "lift": 2},
	{"name": "สไลม์ทองคำ", "sprite": "mon", "actor": "GoldSlime", "auto": true, "rare": "gold", "hp_turns": 3.5, "atk_mul": 0.35, "def_mul": 1.3,
		"moves": ["bump", "guard", "hide", "heal"], "drops": []},
	{"name": "สไลม์สายรุ้ง", "sprite": "mon", "actor": "RainbowSlime", "auto": true, "rare": "rainbow", "hp_turns": 4.3, "atk_mul": 0.35, "def_mul": 1.5,
		"moves": ["bump", "guard", "hide", "heal"], "drops": []},
]
const EVENT_ENEMIES := [16, 17, 18, 19]
# Rare treasure slimes (21-22): tanky, no real attacks, flee after RARE_TURNS turns
const RARE_SLIMES := [21, 22]
const RARE_TURNS := 10
const RARE_CHANCE := {21: 0.12, 22: 0.06}   # chance per (re)spawn roll of its hidden slot
const RARE_ROLL_SEC := 45.0                  # a missed roll tries again after this long
const STAT_TOMES := {"str": "tome_str", "agi": "tome_agi", "int": "tome_int", "vit": "tome_vit"}

const CLASSES := {
	"balanced": {"name": "สมดุล", "en": "Balanced", "desc": "รอบด้าน ใช้ได้ทั้งดาบ ดาวกระจาย และคาถา", "actor": "NinjaBlue2",
		"base": {"str": 7, "agi": 6, "int": 6, "vit": 6}, "grow": {"str": 1, "agi": 1, "int": 1}, "hp_mul": 1.0, "mp_mul": 1.0, "crit": 0, "skills": {"slash": 1, "star": 1}},
	"warrior": {"name": "นักรบ", "en": "Warrior", "desc": "HP และพลังดาบสูง ทนทาน แต่ MP น้อย", "actor": "SamuraiRed",
		"base": {"str": 10, "agi": 4, "int": 3, "vit": 8}, "grow": {"str": 2, "vit": 1}, "hp_mul": 1.15, "mp_mul": 0.8, "crit": 0, "skills": {"slash": 2, "star": 1}},
	"caster": {"name": "จอมเวท", "en": "Spellcaster", "desc": "พลังเวทและ MP สูงมาก แต่ร่างกายบอบบาง", "actor": "NinjaMageBlack",
		"base": {"str": 3, "agi": 5, "int": 10, "vit": 5}, "grow": {"int": 2, "agi": 1}, "hp_mul": 0.9, "mp_mul": 1.3, "crit": 0, "skills": {"slash": 1, "fire": 1}},
	"ninja": {"name": "นินจา", "en": "Ninja", "desc": "ว่องไว คริติคอลและหลบหลีกสูง เชี่ยวชาญอาวุธปา", "actor": "NinjaRed",
		"base": {"str": 6, "agi": 10, "int": 4, "vit": 5}, "grow": {"agi": 2, "str": 1}, "hp_mul": 1.0, "mp_mul": 1.0, "crit": 5, "skills": {"slash": 1, "star": 2}},
}
const STATS := ["str", "agi", "int", "vit"]

const MAIN_QUESTS := [
	{"title": "โจรป่าลอบปล้น", "need": {1: 3}, "reward": {"gold": 80, "exp": 60, "items": {"potion": 2}},
		"talk": ["ช่วงนี้โจรป่าออกปล้นชาวบ้านที่ผ่านป่าไผ่ทางตะวันออก", "เจ้าช่วยไปจัดการโจรป่าสัก 3 คนได้ไหม?"]},
	{"title": "ป่าไผ่คลุ้มคลั่ง", "need": {2: 3, 3: 1}, "reward": {"gold": 120, "exp": 120, "items": {"ether": 2}},
		"talk": ["ปีศาจไผ่ในป่าเริ่มดุร้ายผิดปกติ และมีซามูไรพเนจรเดินเตร็ดเตร่", "กำจัดปีศาจไผ่ 3 ตัวและซามูไรพเนจร 1 คน"]},
	{"title": "ทานูกิจอมป่วน", "need": {4: 3}, "reward": {"gold": 150, "exp": 200, "items": {"hipotion": 1, "bomb": 2}},
		"talk": ["พวกทานูกิแปลงกายมาขโมยข้าวของชาวบ้าน", "ไล่พวกมันกลับไปซะ 3 ตัว"]},
	{"title": "ราชันไผ่ยักษ์", "need": {5: 1}, "reward": {"gold": 300, "exp": 350, "items": {"elixir": 1}},
		"talk": ["ต้นเหตุของความวุ่นวายคือราชันไผ่ยักษ์ที่ตื่นขึ้นท้ายป่า", "ปราบมันแล้วทางสู่ยอดเขาหิมะจะเปิด"]},
	{"title": "วัดบนยอดเขา", "need": {6: 2, 7: 2}, "reward": {"gold": 400, "exp": 500, "items": {"hipotion": 2}},
		"talk": ["ข่าวลือว่าวัดบนเขาถูกนินจาเงายึดไปแล้ว", "ปราบนินจาเงา 2 คน และพระนักรบที่ถูกสะกดจิต 2 รูป"]},
	{"title": "กลไกและปีศาจ", "need": {8: 2, 9: 2}, "reward": {"gold": 550, "exp": 700, "items": {"elixir": 1}},
		"talk": ["หุ่นกลไกและเท็งงุบุกลงมาจากยอดเขา", "ทำลายหุ่นกลไก 2 ตัว และเท็งงุ 2 ตน"]},
	{"title": "ราชาเท็งงุแดง", "need": {10: 1}, "reward": {"gold": 900, "exp": 1000, "items": {"elixir": 2}},
		"talk": ["ราชาเท็งงุแดงเฝ้าทางสู่ปราสาทเงาอยู่บนยอดเขา", "มันแข็งแกร่งมาก เตรียมตัวให้พร้อมก่อนไป"]},
	{"title": "เงาในปราสาท", "need": {11: 2, 12: 2}, "reward": {"gold": 1000, "exp": 1400, "items": {"hipotion": 3}},
		"talk": ["ปราสาทเงาเต็มไปด้วยนักฆ่าและอสูร", "ปราบนักฆ่าหน้ากาก 2 และอสูรโครงกระดูก 2"]},
	{"title": "ปีศาจสุดท้าย", "need": {13: 2, 14: 2}, "reward": {"gold": 1300, "exp": 1800, "items": {"elixir": 2}},
		"talk": ["ผู้รับใช้คนสนิทของโชกุนคือจอมเวทมืดและปีศาจแดง", "ปราบให้สิ้นซาก ก่อนเผชิญหน้ากับนาย"]},
	{"title": "โชกุนเงา", "need": {15: 1}, "reward": {"gold": 3000, "exp": 3000, "items": {"elixir": 3}},
		"talk": ["ถึงเวลาแล้ว... โชกุนเงา คาเงะโมริ รออยู่ในห้องบัลลังก์", "ชะตากรรมของหมู่บ้านอยู่ในมือเจ้า"]},
]

# ground: list of floor atlas coords, path: autotile block origin in TilesetFloor
const THEMES := {
	"village": {"ground": [Vector2i(0, 12), Vector2i(0, 12), Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12)], "path": Vector2i(0, 7),
		"solids": ["tree_round", "tree_oak", "bush_green"], "decor": ["flower1", "flower2", "grass1", "grass2"], "music": "village"},
	"forest": {"ground": [Vector2i(11, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12), Vector2i(14, 12)], "path": Vector2i(11, 7),
		"solids": ["bamboo", "bamboo", "bamboo", "tree_pine", "bush_green2", "rock_brown"], "decor": ["grass1", "grass2", "grass3", "flower3"], "music": "forest",
		"sky": ["#2c3a30", "#8a9a5a"], "clumps": 70},
	"mountain": {"ground": [Vector2i(0, 19), Vector2i(0, 19), Vector2i(1, 19), Vector2i(2, 19), Vector2i(3, 19)], "path": Vector2i(0, 14),
		"solids": ["pine_snow", "pine_snow2", "pine_snow", "boulder_snow", "bush_snow", "rock_grey"], "decor": [], "music": "mountain",
		"sky": ["#1b2440", "#9fb0c8"], "clumps": 75},
	"castle": {"ground": [Vector2i(11, 19), Vector2i(11, 19), Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19)], "path": Vector2i(11, 14),
		"solids": ["pillar", "pillar", "rock_grey", "tree_dead", "statue4"], "decor": [], "music": "castle",
		"sky": ["#1e0e0c", "#c4521e"], "clumps": 65},
	"graveyard": {"ground": [Vector2i(11, 19), Vector2i(11, 19), Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19)], "path": Vector2i(11, 14),
		"solids": ["tree_dead", "grave", "grave", "tree_dead", "rock_grey", "pillar"], "decor": ["pumpkin", "grave"], "music": "graveyard",
		"sky": ["#120a1e", "#6a2a6a"], "clumps": 55},
}

# object sprites: size in tiles is read from the texture; foot = solid footprint [x, y, w, h] in tiles from top-left
const OBJ_FOOT := {
	"house_red": [0, 1, 4, 2], "house_tan": [0, 1, 4, 2], "house_3": [0, 1, 4, 2], "house_brick": [0, 1, 4, 2],
	"torii": [0, 1, 1, 1], "sakura": [1, 2, 1, 1], "tree_big": [1, 2, 1, 1], "tree_autumn": [1, 2, 1, 1], "tree_snow_big": [1, 2, 1, 1],
	"statue1": [0, 2, 2, 1], "statue3": [0, 2, 2, 1], "dojo": [0, 0, 0, 0],
}

const MAPS := {
	"village": {"name": "หมู่บ้านใบไม้", "theme": "village", "w": 40, "h": 26, "safe": true,
		"spawn": Vector2i(20, 13), "inn": Vector2i(23, 13), "from_next": Vector2i(38, 13)},
	"forest": {"name": "ป่าไผ่มรณะ", "theme": "forest", "seed": 1337, "w": 50, "h": 30, "enemies": [1, 2, 3, 4], "count": 10, "boss": 5, "prev": "village", "next": "mountain",
		"chests": [{"gold": 80}, {"items": {"potion": 3}}, {"gear": "steel_kunai"}, {"items": {"ether": 2}, "mats": {"herb": 2}}, {"items": {"bomb": 2}}]},
	"mountain": {"name": "ยอดเขาหิมะ", "theme": "mountain", "seed": 777, "w": 54, "h": 32, "enemies": [6, 7, 8, 9], "count": 11, "boss": 10, "prev": "forest", "next": "castle",
		"chests": [{"gold": 250}, {"gear": "jade_charm"}, {"items": {"hipotion": 2}}, {"mats": {"feather": 2}, "items": {"bomb": 2}}, {"gear": "chain"}]},
	"castle": {"name": "ปราสาทเงา", "theme": "castle", "seed": 4242, "w": 56, "h": 32, "enemies": [11, 12, 13, 14], "count": 12, "boss": 15, "prev": "mountain", "next": "",
		"chests": [{"gold": 600}, {"gear": "shadow_garb"}, {"items": {"elixir": 1}}, {"mats": {"shard": 3, "ruby": 1}}, {"gear": "venom_star"}]},
	# Halloween event zone, reached through the north torii of the village
	"graveyard": {"name": "สุสานโยไค", "theme": "graveyard", "seed": 1031, "w": 46, "h": 28, "enemies": EVENT_ENEMIES, "count": 10, "boss": 20, "prev": "village", "next": "",
		"event": true, "chests": [{"mats": {"candy": 6}}, {"items": {"elixir": 1}}, {"gold": 300}]},
}

# ================= texture cache =================
var _tex := {}
func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load("res://assets/" + path)
	return _tex[path]

# ================= player =================
func new_player(pname: String, cls: String) -> Dictionary:
	var C: Dictionary = CLASSES[cls]
	var s: Vector2i = MAPS.village.spawn
	var p := {"ver": 3, "name": pname, "cls": cls, "lvl": 1, "exp": 0, "gold": 60, "sp": 0, "skp": 1,
		"skills": C.skills.duplicate(), "inv": {"potion": 3, "ether": 1}, "mats": {}, "up": {},
		"owned": ["wood_katana", "iron_star", "paper_charm", "cloth"],
		"eq": {"weapon": "wood_katana", "throw": "iron_star", "charm": "paper_charm", "armor": "cloth"},
		"hp": -1, "mp": -1, "map": "village", "x": (s.x + 0.5) * TS, "y": (s.y + 0.5) * TS,
		"kills": {}, "flags": {}, "opened": {}, "quest": {"i": 0, "active": false, "base": {}}, "bounties": [],
		"music": true, "sfx": true, "autorun": false, "wins": 0}
	for k in C.base: p[k] = C.base[k]
	return p

func cls() -> Dictionary: return CLASSES.get(P.get("cls", "balanced"), CLASSES.balanced)

func gstat(id: String) -> Dictionary:
	var g: Dictionary = GEAR[id]
	var u: int = int(P.up.get(id, 0))
	return {"atk": roundi(g.get("atk", 0) * (1 + 0.12 * u) + u) if g.get("atk", 0) else 0,
		"def": roundi(g.get("def", 0) * (1 + 0.12 * u) + u) if g.get("def", 0) else 0,
		"hp": int(g.get("hp", 0)) + (8 * u if g.slot == "armor" else 0),
		"mp": int(g.get("mp", 0)) + (4 * u if g.slot == "charm" else 0)}

func gname(id: String) -> String:
	var u: int = int(P.up.get(id, 0))
	return GEAR[id].name + (" +%d" % u if u > 0 else "")

func gear(slot: String) -> Dictionary: return gstat(P.eq[slot])

## Attribute including equipped gear bonuses
func stat(k: String) -> int:
	var n: int = int(P[k]) + int(P.get("tome", {}).get(k, 0))
	for slot in SLOTS: n += int(GEAR[P.eq[slot]].get("bonus", {}).get(k, 0))
	return n

## Read a stat tome: +1 forever to its stat
func use_tome(id: String) -> void:
	if int(P.inv.get(id, 0)) <= 0: return
	var k: String = ITEMS[id].tome
	P.inv[id] = int(P.inv[id]) - 1
	if not P.has("tome"): P.tome = {}
	P.tome[k] = int(P.tome.get(k, 0)) + 1
	fix_player()
	save_game()

func gear_extra(k: String) -> float:
	var n := 0.0
	for slot in SLOTS: n += GEAR[P.eq[slot]].get(k, 0)
	return n

func gear_sell_price(id: String) -> int:
	return maxi(5, roundi(GEAR[id].price * SELL_RATE * (1 + 0.15 * int(P.up.get(id, 0)))))

## Sell an owned, unequipped piece; returns gold gained (0 if not allowed)
func sell_gear(id: String) -> int:
	if not id in P.owned or id in P.eq.values(): return 0
	var g := gear_sell_price(id)
	while id in P.owned: P.owned.erase(id)
	P.up.erase(id)
	P.gold += g
	return g

## Random equipment from the current zone's price band (any class, so it can also be sold)
func random_drop_gear() -> String:
	var band: Array = ZONE_GEAR.get(P.map, [0, 700])
	var pool := []
	for id in GEAR:
		var pr: int = GEAR[id].price
		if pr > 0 and pr >= band[0] and pr <= band[1] and GEAR[id].get("shop", "") != "event": pool.append(id)
	return pool.pick_random() if pool.size() > 0 else ""

func can_equip(id: String) -> bool: return not GEAR[id].has("cls") or P.cls in GEAR[id].cls

func elite_stats(st: Dictionary) -> Dictionary:
	var o := st.duplicate()
	o.hp = roundi(st.hp * ELITE_HP)
	for k in ["atk", "mag", "def"]: o[k] = roundi(st[k] * ELITE_POW)
	o.exp = st.exp * ELITE_LOOT
	o.gold = st.gold * ELITE_GOLD
	o.rec = st.rec + 3
	return o
func max_hp() -> int: return roundi((60 + stat("vit") * 10 + P.lvl * 8 + gear("armor").hp) * cls().hp_mul * (1 + 0.05 * pas("iron_body")))
func max_mp() -> int: return roundi((25 + stat("int") * 5 + P.lvl * 2 + gear("charm").mp) * cls().mp_mul * (1 + 0.08 * pas("chakra_flow")))
func p_def() -> int: return roundi(stat("vit") * 0.8 + gear("armor").def * 2 + 2 * pas("iron_body"))
func melee_pow() -> float: return (stat("str") * 2 + gear("weapon").atk * 1.5 + P.lvl) * (1 + 0.08 * pas("blade_art"))
func ranged_pow() -> float: return (stat("agi") * 1.8 + gear("throw").atk * 1.5 + P.lvl) * (1 + 0.05 * pas("keen_eye"))
func magic_pow() -> float: return stat("int") * 2.3 + gear("charm").atk * 1.5 + P.lvl
func crit_chance() -> float: return 5 + stat("agi") * 0.4 + cls().crit + 2 * pas("keen_eye") + gear_extra("crit")
func dodge_bonus() -> float: return 3.0 * pas("shadow_step") + gear_extra("dodge")
func mp_regen() -> float: return 0.04 + 0.01 * pas("chakra_flow")

## learned level of a skill (0 = not learned); used for passive bonuses
func pas(id: String) -> int: return int(P.get("skills", {}).get(id, 0))

## chance (%) for an on-hit debuff passive to trigger
func debuff_chance(id: String) -> float:
	var lv := pas(id)
	if lv <= 0: return 0.0
	return {"rend": 10 + 6 * lv, "venom": 10 + 6 * lv, "hex": 12 + 6 * lv}[id]

## "" if a point can go into this skill now, otherwise the reason it's blocked
func skill_block(id: String) -> String:
	var s: Dictionary = SKILLS[id]
	if int(P.skills.get(id, 0)) >= SKILL_MAX: return "เลเวลสูงสุดแล้ว"
	if P.lvl < s.req: return "ต้องการ Lv %d" % s.req
	for q in s.pre:
		if int(P.skills.get(q, 0)) <= 0: return "ต้องเรียน %s ก่อน" % SKILLS[q].name
	if P.skp <= 0: return "แต้มสกิลไม่พอ"
	return ""
func exp_need(l: int) -> int: return int(floor(30 * pow(l, 1.5)))

func fix_player() -> void:
	if P.hp < 0 or P.hp > max_hp(): P.hp = max_hp()
	if P.mp < 0 or P.mp > max_mp(): P.mp = max_mp()

func skill_value(id: String, lv: int) -> float:
	var s: Dictionary = SKILLS[id]
	return s.get("base", 1.0) + s.get("per", 0.0) * lv

func pct(x: float) -> String: return "%d%%" % roundi(x * 100)

func skill_desc(id: String, lv: int) -> String:
	lv = max(1, lv)
	var s: Dictionary = SKILLS[id]
	match id:
		"blade_art": return "พลังดาบ +%d%%" % (8 * lv)
		"iron_body": return "HP สูงสุด +%d%% · ป้องกัน +%d" % [5 * lv, 2 * lv]
		"rend": return "ฟันโดนมีโอกาส %d%% ทำลายเกราะศัตรู (ป้องกัน -40%%, 2 เทิร์น)" % (10 + 6 * lv)
		"battle_cry": return "เริ่มต่อสู้ด้วยสถานะฮึกเหิม (ความเสียหาย +25%%) %d เทิร์น" % (1 + lv)
		"keen_eye": return "คริติคอล +%d%% · พลังปา +%d%%" % [2 * lv, 5 * lv]
		"shadow_step": return "โอกาสหลบการโจมตี +%d%%" % (3 * lv)
		"venom": return "ปาโดนมีโอกาส %d%% ทำให้ศัตรูติดพิษ 3 เทิร์น" % (10 + 6 * lv)
		"ambush": return "เริ่มต่อสู้พร้อมจักระ %d%% · การโจมตีแรกคริติคอลแน่นอน" % (15 * lv)
		"chakra_flow": return "MP สูงสุด +%d%% · ฟื้น MP ทุกเทิร์น %d%%" % [8 * lv, 4 + lv]
		"hex": return "เวทโดนมีโอกาส %d%% สาปศัตรูให้อ่อนแรง (พลังโจมตี -30%%, 2 เทิร์น)" % (12 + 6 * lv)
		"spirit_ward": return "เริ่มต่อสู้ด้วยม่านวิญญาณ (รับความเสียหาย -30%%) %d เทิร์น" % (1 + lv)
		"heal": return "ฟื้น HP %d" % heal_amount(lv)
		"clone": return "หลบการโจมตี %d ครั้งถัดไป" % (2 + lv / 2)
	var t := ""
	var v := skill_value(id, lv)
	match s.kind:
		"melee": t = ("ฟัน %d ครั้ง ครั้งละ %s" % [s.hits, pct(v)]) if s.hits > 1 else "ฟัน %s ของพลังดาบ" % pct(v)
		"ranged": t = ("ปา %d ครั้ง ครั้งละ %s" % [s.hits, pct(v)]) if s.hits > 1 else "ปา %s ของพลังปา" % pct(v)
		"magic": t = "เวท %s ของพลังเวท" % pct(v)
	if s.has("crit"): t += " · คริ +%d%%" % s.crit
	if s.has("status"):
		var st: Dictionary = s.status
		t += " · %s %d เทิร์น" % ["พิษ" if st.id == "poison" else "ไหม้", st.turns]
	if s.has("stun"): t += " · สตั้น %d%%" % (s.stun[0] + s.stun[1] * lv)
	return t

func heal_amount(lv: int) -> int: return roundi((stat("int") * 4 + 25) * (1 + 0.2 * lv))

func enemy_stats(stage: int) -> Dictionary:
	var b: bool = ENEMIES[stage].get("boss", false)
	# event yokai match the player's level
	var s: int = clampi(roundi(P.get("lvl", 1) / 1.45) + (1 if b else 0), 1, 18) if ENEMIES[stage].get("auto", false) else stage
	var hm: float = ENEMIES[stage].get("hp_mul", 1.0)
	var am: float = ENEMIES[stage].get("atk_mul", 1.0)
	var dm: float = ENEMIES[stage].get("def_mul", 1.0)
	var o := {"hp": roundi((40 + 32 * s + 5.5 * s * s) * (1.8 if b else 1.0) * hm), "atk": roundi((9 + 4 * s + 0.12 * s * s) * (1.2 if b else 1.0) * am),
		"def": roundi((1 + 1.6 * s) * dm), "agi": 3 + s, "mag": roundi((8 + 4 * s) * (1.2 if b else 1.0) * am),
		"exp": roundi((22 + 14 * s + 1.4 * s * s) * (2.5 if b else 1.0)), "gold": roundi((18 + 14 * s) * (2.5 if b else 1.0)),
		"rec": max(1, roundi(s * 1.45))}
	# treasure slimes: HP = this many turns of the player's best hit, so they feel the same at every level
	if ENEMIES[stage].has("hp_turns"):
		var pw: float = maxf(melee_pow(), maxf(ranged_pow(), magic_pow()))
		o.hp = roundi(pw * 1.6 * ENEMIES[stage].hp_turns)
	return o

func add_loot(l: Dictionary) -> Array:
	var out := []
	if l.get("gold", 0) > 0:
		P.gold += l.gold
		out.append("%d ทอง" % l.gold)
	for k in l.get("items", {}):
		P.inv[k] = int(P.inv.get(k, 0)) + l.items[k]
		out.append("%s ×%d" % [ITEMS[k].name, l.items[k]])
	for k in l.get("mats", {}):
		P.mats[k] = int(P.mats.get(k, 0)) + l.mats[k]
		out.append("%s ×%d" % [MATS[k].name, l.mats[k]])
	if l.has("gear"):
		var gid: String = l.gear
		if gid in P.owned:
			var g := gear_sell_price(gid)
			P.gold += g
			out.append("★ %s (มีแล้ว ขายได้ %d ทอง)" % [GEAR[gid].name, g])
		else:
			P.owned.append(gid)
			out.append("★ " + GEAR[gid].name)
	return out

func gain_exp(n: int) -> int:
	P.exp += n
	var up := 0
	while P.exp >= exp_need(P.lvl):
		P.exp -= exp_need(P.lvl)
		P.lvl += 1
		for k in cls().grow: P[k] += cls().grow[k]
		P.sp += 1
		P.skp += 1
		up += 1
	if up > 0:
		P.hp = max_hp()
		P.mp = max_mp()
	return up

func class_stats() -> Dictionary:
	var o: Dictionary = cls().base.duplicate()
	for k in cls().grow: o[k] += cls().grow[k] * (P.lvl - 1)
	return o

func free_spent() -> int:
	var o := class_stats()
	var n := 0
	for k in STATS: n += max(0, P[k] - o[k])
	return n

## skill points put in beyond the class's starting skills
func skill_spent() -> int:
	var start: Dictionary = cls().skills
	var n := 0
	for id in P.skills: n += maxi(0, int(P.skills[id]) - int(start.get(id, 0)))
	return n

# ================= warp shrines =================
# side: "in" = by the zone entrance, "out" = before the boss / exit
const WARPS := [
	{"id": "village", "map": "village", "side": ""},
	{"id": "forest_in", "map": "forest", "side": "in"}, {"id": "forest_out", "map": "forest", "side": "out"},
	{"id": "mountain_in", "map": "mountain", "side": "in"}, {"id": "mountain_out", "map": "mountain", "side": "out"},
	{"id": "castle_in", "map": "castle", "side": "in"}, {"id": "castle_out", "map": "castle", "side": "out"},
]
const WARP_STEP := 20   # gold per shrine of distance along the route

func warp_index(id: String) -> int:
	for i in WARPS.size():
		if WARPS[i].id == id: return i
	return -1

func warp_name(id: String) -> String:
	var w: Dictionary = WARPS[warp_index(id)]
	return "ศาล" + MAPS[w.map].name + {"": "", "in": " (ทางเข้า)", "out": " (ก่อนถึงบอส)"}[w.side]

func warp_on(id: String) -> bool: return id == "village" or P.get("warps", {}).has(id)

func warp_cost(from: String, to: String) -> int: return WARP_STEP * absi(warp_index(from) - warp_index(to))

func stat_reset_cost() -> int: return 50 * P.lvl
func skill_reset_cost() -> int: return 60 * P.lvl

func reset_stats() -> void:
	if free_spent() == 0 or P.gold < stat_reset_cost(): return
	P.gold -= stat_reset_cost()
	P.sp += free_spent()
	var o := class_stats()
	for k in STATS: P[k] = o[k]
	fix_player()
	save_game()

func reset_skills() -> void:
	if skill_spent() == 0 or P.gold < skill_reset_cost(): return
	P.gold -= skill_reset_cost()
	P.skp += skill_spent()
	P.skills = cls().skills.duplicate()
	fix_player()
	save_game()

# ================= quests =================
func quest_progress(q: Dictionary) -> Array:
	var out := []
	for s in q.need:
		var have: int
		if ENEMIES[s].get("boss", false): have = 1 if P.flags.has("boss%d" % s) else 0
		else: have = int(P.kills.get(str(s), 0)) - int(P.quest.base.get(str(s), 0))
		out.append({"s": s, "n": q.need[s], "have": clampi(have, 0, q.need[s])})
	return out

func quest_done(q: Dictionary) -> bool:
	for r in quest_progress(q):
		if r.have < r.n: return false
	return true

func current_quest() -> Dictionary:
	return MAIN_QUESTS[P.quest.i] if P.quest.i < MAIN_QUESTS.size() else {}

# ================= bounties =================
func unlocked_stages() -> Array:
	var s: Array = MAPS.forest.enemies.duplicate()
	if P.flags.has("boss5"): s.append_array(MAPS.mountain.enemies)
	if P.flags.has("boss10"): s.append_array(MAPS.castle.enemies)
	return s

func gen_bounty() -> Dictionary:
	var ss := unlocked_stages()
	var s: int = ss[rng.randi() % ss.size()]
	var st := enemy_stats(s)
	if rng.randf() < 0.65:
		var n := 3 + rng.randi() % 4
		return {"type": "kill", "s": s, "n": n, "base": int(P.kills.get(str(s), 0)), "gold": roundi(st.gold * n * 0.9), "exp": roundi(st.exp * n * 0.6)}
	var drops: Array = ENEMIES[s].drops
	var m: String = drops[rng.randi() % drops.size()][0]
	var n2 := 3 + rng.randi() % 3
	return {"type": "mat", "m": m, "n": n2, "gold": roundi(MATS[m].price * n2 * 3), "exp": roundi(st.exp * n2 * 0.4)}

func ensure_bounties() -> void:
	while P.bounties.size() < 3: P.bounties.append(gen_bounty())

func bounty_have(b: Dictionary) -> int:
	if b.type == "kill": return mini(b.n, int(P.kills.get(str(int(b.s)), 0)) - int(b.base))
	return mini(b.n, int(P.mats.get(b.m, 0)))

func bounty_done(b: Dictionary) -> bool: return bounty_have(b) >= b.n

# ================= forge =================
func forge_req(id: String) -> Dictionary:
	var u: int = int(P.up.get(id, 0))
	var g: Dictionary = GEAR[id]
	if u >= 10: return {}
	var m := {}
	if u < 3: m["iron"] = u + 1
	elif u < 6:
		m["iron"] = 2
		m["herb" if g.slot == "charm" else "branch"] = u - 1
	elif u < 8:
		m["feather"] = u - 4
		m["ruby"] = 1
	else:
		m["shard"] = u - 6
		m["ruby"] = 2
	var chance := [100, 100, 100, 95, 90, 85, 75, 65, 55, 45]
	return {"u": u, "gold": roundi((20 + max(40, g.price) * 0.08) * (u + 1) * (1 + u * 0.1)), "mats": m, "chance": chance[u]}

func can_forge(r: Dictionary) -> bool:
	if r.is_empty() or P.gold < r.gold: return false
	for k in r.mats:
		if int(P.mats.get(k, 0)) < r.mats[k]: return false
	return true

# ================= save =================
func save_path(s := -1) -> String:
	return "user://%s_%d.json" % ["test_save" if testing else "save", slot if s < 0 else s]

func save_game() -> void:
	if P.is_empty(): return
	P["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(P))
	else: push_error("save failed: %s (%d)" % [save_path(), FileAccess.get_open_error()])

func has_save(s := -1) -> bool: return FileAccess.file_exists(save_path(s))

func any_save() -> bool:
	for s in range(1, SAVE_SLOTS + 1):
		if has_save(s): return true
	return false

## Short summary of a slot for the save list ({} when empty or unreadable)
func slot_info(s: int) -> Dictionary:
	if not has_save(s): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path(s)))
	if typeof(d) != TYPE_DICTIONARY: return {"broken": true}
	return {"name": d.get("name", "?"), "cls": d.get("cls", "balanced"), "lvl": int(d.get("lvl", 1)), "map": d.get("map", "village"),
		"gold": int(d.get("gold", 0)), "saved_at": d.get("saved_at", "")}

func first_free_slot() -> int:
	for s in range(1, SAVE_SLOTS + 1):
		if not has_save(s): return s
	return -1

func load_game(s := -1) -> bool:
	if s > 0: slot = s
	if not has_save(): return false
	var f := FileAccess.open(save_path(), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return false
	var base := new_player(d.get("name", "ซินจิด"), d.get("cls", "balanced") if CLASSES.has(d.get("cls", "")) else "balanced")
	for k in d: base[k] = d[k]
	# JSON turns ints into floats; normalise the numeric fields we do integer maths on
	for k in ["lvl", "exp", "gold", "sp", "skp", "hp", "mp", "wins", "str", "agi", "int", "vit"]: base[k] = int(base[k])
	for dk in ["skills", "inv", "mats", "up", "kills"]:
		for k in base[dk]: base[dk][k] = int(base[dk][k])
	base.quest.i = int(base.quest.i)
	if not MAPS.has(base.map): base.map = "village"
	P = base
	return true

func delete_save(s := -1) -> void:
	if has_save(s): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path(s)))

func _ready() -> void:
	rng.randomize()
	# keep a save from the single-slot version
	if FileAccess.file_exists(OLD_SAVE) and not FileAccess.file_exists("user://save_1.json"):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_SAVE), ProjectSettings.globalize_path("user://save_1.json"))
