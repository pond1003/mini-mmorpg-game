"""Copy the subset of Ninja Adventure (CC0) assets the game uses into the Godot project."""
import os, shutil
from PIL import Image
SRC = r"C:/Holy/ai cluade/tools/NinjaAdventure/Ninja Adventure - Asset Pack"
DST = r"C:/Holy/ai cluade/shadow_ninja_godot/assets"

def cp(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copyfile(src, dst)

CHARS = ["NinjaBlue2","SamuraiRed","NinjaMageBlack","NinjaRed",            # player classes
         "OldMan2","OldMan3","Hunter","Woman","Master","MaskGoldRacoon","Vampire",                    # NPCs
         "CamouflageGreen","Samurai","NinjaDark","Monk","RobotGrey","Tengu",
         "NinjaMasked","SkeletonDemon","SorcererBlack","DemonRed"]
MONSTERS = ["Bamboo","Racoon","LanternRed","Skull","Spirit","BlueBat"]
BOSSES = ["GiantBamboo","TenguRed","GiantRedSamurai","GiantSpirit"]
for n in CHARS:
    d=f"{SRC}/Actor/Character/{n}"; sheet=[f for f in os.listdir(d) if f.endswith(".png") and f!="Faceset.png"][0]
    cp(f"{d}/{sheet}", f"{DST}/actors/{n}/sheet.png")
    cp(f"{SRC}/Actor/Character/{n}/Faceset.png", f"{DST}/actors/{n}/face.png")
for n in MONSTERS:
    cp(f"{SRC}/Actor/Monster/{n}/SpriteSheet.png", f"{DST}/actors/{n}/sheet.png")
    cp(f"{SRC}/Actor/Monster/{n}/Faceset.png", f"{DST}/actors/{n}/face.png")
for n in BOSSES:
    for f in os.listdir(f"{SRC}/Actor/Boss/{n}"):
        if f.endswith(".png"): cp(f"{SRC}/Actor/Boss/{n}/{f}", f"{DST}/actors/{n}/{'face.png' if f=='Faceset.png' else f.lower()}")

for t in ["TilesetFloor","TilesetNature","TilesetHouse"]:
    cp(f"{SRC}/Backgrounds/Tilesets/{t}.png", f"{DST}/tiles/{t}.png")

# multi-tile objects cropped to single sprites: name -> (sheet, tx, ty, tw, th)
OBJ = {
  "tree_round":("TilesetNature",0,0,2,2),"tree_pine":("TilesetNature",2,0,2,2),"tree_dead":("TilesetNature",4,0,2,2),
  "tree_oak":("TilesetNature",6,0,2,2),"pine_snow":("TilesetNature",8,0,2,2),"pine_snow2":("TilesetNature",10,0,2,2),
  "bush_snow":("TilesetNature",12,0,2,2),"bush_pink":("TilesetNature",14,0,2,2),"bush_green":("TilesetNature",16,0,2,2),
  "bush_green2":("TilesetNature",18,0,2,2),"stump":("TilesetNature",0,8,2,2),"bamboo":("TilesetNature",11,8,1,2),
  "rock_brown":("TilesetNature",13,8,2,2),"rock_grey":("TilesetNature",16,8,2,2),"rock_small":("TilesetNature",15,9,1,1),
  "boulder_blue":("TilesetNature",0,12,2,2),"boulder_snow":("TilesetNature",2,12,2,2),
  "sakura":("TilesetNature",0,18,3,3),"tree_big":("TilesetNature",3,18,3,3),"tree_snow_big":("TilesetNature",6,18,3,3),"tree_autumn":("TilesetNature",9,18,3,3),
  "flower1":("TilesetNature",0,11,1,1),"flower2":("TilesetNature",1,11,1,1),"flower3":("TilesetNature",2,11,1,1),
  "grass1":("TilesetNature",0,10,1,1),"grass2":("TilesetNature",1,10,1,1),"grass3":("TilesetNature",4,10,1,1),
  "house_red":("TilesetHouse",0,0,4,3),"house_tan":("TilesetHouse",4,0,4,3),"house_3":("TilesetHouse",8,0,4,3),"house_brick":("TilesetHouse",12,0,4,3),
  "torii":("TilesetHouse",0,5,3,2),"dojo":("TilesetHouse",4,4,2,1),"hut":("TilesetHouse",3,8,3,2),"igloo":("TilesetHouse",3,11,3,3),
  "statue1":("TilesetHouse",1,15,2,3),"statue2":("TilesetHouse",3,15,2,2),"statue3":("TilesetHouse",1,19,2,3),"statue4":("TilesetHouse",3,19,2,2),
  "pillar":("TilesetHouse",0,19,1,3),"notice":("TilesetHouse",3,3,1,1),
}
for name,(sheet,tx,ty,tw,th) in OBJ.items():
    im = Image.open(f"{SRC}/Backgrounds/Tilesets/{sheet}.png").convert("RGBA")
    c = im.crop((tx*16,ty*16,(tx+tw)*16,(ty+th)*16)); os.makedirs(f"{DST}/obj",exist_ok=True); c.save(f"{DST}/obj/{name}.png")

FX = {"cut":"Attack/Cut","slash":"Attack/SlashCurved","explosion":"Elemental/Explosion","thunder":"Elemental/Thunder",
      "flame":"Elemental/Flam","spirit":"Magic/Spirit","shuriken":"Projectile/Shuriken","kunai":"Projectile/Kunai",
      "smoke":"Smoke/Smoke","boost":"Magic/Boost"}
for k,v in FX.items(): cp(f"{SRC}/FX/{v}/SpriteSheet.png", f"{DST}/fx/{k}.png")
cp(f"{SRC}/FX/Magic/Circle/SpriteSheetSpark.png", f"{DST}/fx/heal.png")
cp(f"{SRC}/FX/Magic/Shield/SpriteSheetBlue.png", f"{DST}/fx/shield.png")

ICONS = {"potion":"Items/Potion/LifePot.png","hipotion":"Items/Potion/Heart.png","ether":"Items/Potion/WaterPot.png","elixir":"Items/Potion/MilkPot.png",
  "bomb":"Items/Projectile/Bomb.png","smoke":"Items/Projectile/Caltrop.png","shuriken":"Items/Projectile/Shuriken.png","kunai":"Items/Projectile/Kunai.png",
  "herb":"Items/Resource/Grass.png","scrap_iron":"Items/Resource/BarIron.png","wolf_pelt":"Items/Resource/Branch.png","tengu_feather":"Items/Resource/feather.png",
  "shadow_shard":"Items/Resource/GemPurple.png","oni_horn":"Items/Resource/GemRed.png","gold":"Items/Treasure/GoldCoin.png",
  "chest":"Items/Treasure/LittleTreasureChest.png","chest_big":"Items/Treasure/BigTreasureChest.png",
  "scroll":"Items/Scroll/Scroll.png","scroll_fire":"Items/Scroll/ScrollFire.png","scroll_thunder":"Items/Scroll/ScrollThunder.png","book":"Items/Object/Book.png"}
for k,v in ICONS.items(): cp(f"{SRC}/{v}", f"{DST}/icons/{k}.png")
for w in ["Katana","Sword","Sword2","BigSword","Ninjaku","Sai","Rapier","Club","Axe","Lance","Hammer","MagicWand"]:
    d=f"{SRC}/Items/Weapons/{w}"
    for f in os.listdir(d):
        if f=="Sprite.png": cp(f"{d}/{f}", f"{DST}/icons/w_{w.lower()}.png")
SK = {"Cut":"cut","AttackUpgrade":"attack_up","Fireball":"fireball","Heal":"heal","Mist":"mist","Explosion":"explosion",
      "BookThunder":"thunder","Camouflage":"camouflage","Counter":"counter","MagicWeapon":"magic_weapon","OrbFire":"orb_fire","DefenseUpgrade":"defense_up",
      "Upgrade":"upgrade","Downgrade":"downgrade","Vision":"vision","Death":"death","OrbWater":"orb_water","BookDarkness":"book_darkness","OrbLight":"orb_light"}
for k,v in SK.items(): cp(f"{SRC}/Ui/Skill Icon/Spell/{k}.png", f"{DST}/skills/{v}.png")
for k in ["Shuriken","Kunai","Armor","Amulet","Scroll","Guard","Boot"]: cp(f"{SRC}/Ui/Skill Icon/Items & Weapon/{k}.png", f"{DST}/skills/{k.lower()}.png")
cp(f"{SRC}/Ui/Skill Icon/Job & Action/Potion.png", f"{DST}/skills/potion.png")
cp(f"{SRC}/Ui/Skill Icon/Job & Action/Sing.png", f"{DST}/skills/sing.png")
cp(f"{SRC}/Ui/Skill Icon/Meteo/Moon.png", f"{DST}/skills/moon.png")

for f in os.listdir(f"{SRC}/Ui/Theme/Theme Wood"):
    if f.endswith(".png"): cp(f"{SRC}/Ui/Theme/Theme Wood/{f}", f"{DST}/ui/{f}")
for f in ["DialogBoxFaceset.png","FacesetBox.png","DialogueBoxSimple.png"]: cp(f"{SRC}/Ui/Dialog/{f}", f"{DST}/ui/{f}")
cp(f"{SRC}/Ui/Font/NormalFont.ttf", f"{DST}/fonts/NormalFont.ttf")

MUSIC = {"village":"4 - Village.ogg","forest":"37 - Dark Forest.ogg","mountain":"19 - Ascension.ogg","castle":"10 - Dark Castle.ogg",
         "battle":"17 - Fight.ogg","boss":"34  - Fight.ogg","title":"1 - Adventure Begin.ogg","victory":"8 - End Theme.ogg","graveyard":"14 - Curse.ogg"}
for k,v in MUSIC.items(): cp(f"{SRC}/Audio/Musics/{v}", f"{DST}/music/{k}.ogg")
SFX = {"hit":"Hit & Impact/Hit2.wav","crit":"Hit & Impact/Impact3.wav","slash":"Whoosh & Slash/Slash.wav","throw":"Whoosh & Slash/Whoosh.wav",
  "miss":"Whoosh & Slash/Whoosh2.wav","fire":"Elemental/Fireball.wav","explosion":"Elemental/Explosion.wav","thunder":"Magic & Skill/Magic3.wav",
  "magic":"Magic & Skill/Magic1.wav","heal":"Magic & Skill/Heal.wav","buff":"Magic & Skill/Spirit.wav","coin":"Bonus/Coin.wav","ui":"Menu/Move1.wav",
  "accept":"Menu/Accept.wav","cancel":"Menu/Cancel.wav","alert":"Alert/Alert.wav","powerup":"Bonus/PowerUp1.wav"}
for k,v in SFX.items(): cp(f"{SRC}/Audio/Sounds/{v}", f"{DST}/sfx/{k}.wav")
for k,v in {"level":"LevelUp1.wav","win":"Success1.wav","lose":"GameOver.wav"}.items(): cp(f"{SRC}/Audio/Jingles/{v}", f"{DST}/sfx/{k}.wav")
print("ok")
