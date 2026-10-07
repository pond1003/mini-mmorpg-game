"""Golden / rainbow slime sheets recoloured from the CC0 Slime3 sprite (keeps outline + shading)."""
import os, colorsys
from PIL import Image

SRC = r"C:/Holy/ai cluade/tools/NinjaAdventure/Ninja Adventure - Asset Pack/Actor/Monster/Slime3"
DST = r"C:/Holy/ai cluade/shadow_ninja_godot/assets/actors"

def recolor(im, ramp):
    """Map each non-dark pixel's brightness onto a colour ramp (dark -> light)."""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            if l < 0.22: continue          # keep outline / eyes
            t = min(1.0, (l - 0.22) / 0.7)
            i = min(len(ramp) - 2, int(t * (len(ramp) - 1)))
            f = t * (len(ramp) - 1) - i
            c0, c1 = ramp[i], ramp[i + 1]
            px[x, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3)) + (a,)
    return im

def hexc(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
GOLD = [hexc(c) for c in ["#7a4a08", "#c8860e", "#f2c230", "#fff2a0"]]
PEARL = [hexc(c) for c in ["#8a8aa8", "#c8c8e0", "#f0f0ff", "#ffffff"]]   # tinted in-game with a cycling hue

sheet = [f for f in os.listdir(SRC) if f != "Faceset.png"][0]
for name, ramp in [("GoldSlime", GOLD), ("RainbowSlime", PEARL)]:
    os.makedirs(f"{DST}/{name}", exist_ok=True)
    recolor(Image.open(f"{SRC}/{sheet}"), ramp).save(f"{DST}/{name}/sheet.png")
    recolor(Image.open(f"{SRC}/Faceset.png"), ramp).save(f"{DST}/{name}/face.png")

# stat tome icon: recolour of the book icon per stat
BOOK = r"C:/Holy/ai cluade/shadow_ninja_godot/assets/icons/book.png"
for k, h in {"str": "#e04a3a", "agi": "#3ad06a", "int": "#4a8aff", "vit": "#ffb030"}.items():
    base = hexc(h)
    dark = tuple(int(c * 0.45) for c in base)
    light = tuple(min(255, int(c + (255 - c) * 0.55)) for c in base)
    recolor(Image.open(BOOK), [dark, base, light, (255, 255, 255)]).save(f"{DST}/../icons/tome_{k}.png")
print("ok")

# EXP boost scroll: golden-green recolour of the scroll icon
SCROLL = r"C:/Holy/ai cluade/shadow_ninja_godot/assets/icons/scroll.png"
recolor(Image.open(SCROLL), [hexc("#2a5a1a"), hexc("#5fb83a"), hexc("#c8f070"), hexc("#fff8c0")]).save(f"{DST}/../icons/exp_scroll.png")
print("exp scroll ok")
