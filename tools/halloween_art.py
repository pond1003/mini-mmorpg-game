"""Original 16x16 pixel art for the Halloween event (jack-o'-lantern, gravestone, candy).
Drawn from character grids so it matches the Ninja Adventure look (dark outline + 3 tones)."""
from PIL import Image

DST = r"C:/Holy/ai cluade/shadow_ninja_godot/assets"
PAL = {
    "K": "#1d1424", "O": "#e8781e", "o": "#b44a12", "Y": "#ffb347", "G": "#5a8a2a", "g": "#2e4f1c",
    "F": "#ffe066", "S": "#8a8aa0", "L": "#b8b8cc", "s": "#5e5e74", "d": "#3e2a1e", "D": "#5e4030",
    "P": "#a453e6", "p": "#6a2aa0",
}

PUMPKIN = [
    "................",
    ".......KKK......",
    "......KGgK......",
    "...KKKKgKKKKK...",
    "..KOYOoOoOOOoK..",
    ".KOYOOoOoOOOOoK.",
    ".KOYKKoOoOKKOoK.",
    ".KOKFFKOoKFFKoK.",
    ".KOOKKOOoOKKOoK.",
    ".KOOOOoKKoOOOoK.",
    ".KOKOoOOOOOoKoK.",
    ".KOOKFKFFKFKOoK.",
    ".KOoOKoKKoKOooK.",
    "..KoOoOoOoOooK..",
    "...KKKKKKKKKK...",
    "................",
]
GRAVE = [
    "................",
    "................",
    ".....KKKKKK.....",
    "....KSSSSSSK....",
    "...KSLSSSSSsK...",
    "...KSLSKKSSsK...",
    "...KSSKKKKSsK...",
    "...KSLSKKSSsK...",
    "...KSSSKKSSsK...",
    "...KSLSSSSSsK...",
    "...KSSSSSSSsK...",
    "...KSSSSSSSsK...",
    "..KKKKKKKKKKKK..",
    ".KdDdDdDdDdDdDK.",
    "..KKKKKKKKKKKK..",
    "................",
]
CANDY = [
    "................",
    "................",
    "................",
    "................",
    ".KK..........KK.",
    "KPPK..KKKK..KPPK",
    "KPpPKKOOYOKKPpPK",
    ".KPPKOOYOOOKPPK.",
    ".KPPKOOOOOoKPPK.",
    "KPpPKKoOOoKKPpPK",
    "KPPK..KKKK..KPPK",
    ".KK..........KK.",
    "................",
    "................",
    "................",
    "................",
]

def draw(grid, path):
    assert all(len(r) == 16 for r in grid), path
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != ".": im.putpixel((x, y), Image.new("RGB", (1, 1), PAL[ch]).getpixel((0, 0)) + (255,))
    im.save(path)

draw(PUMPKIN, f"{DST}/obj/pumpkin.png")
draw(GRAVE, f"{DST}/obj/grave.png")
draw(CANDY, f"{DST}/icons/candy.png")
print("ok")
