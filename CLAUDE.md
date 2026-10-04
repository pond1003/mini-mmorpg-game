# Notes for Claude

- **Always reply to the user in Thai.** The user iterates feature by feature (references: Sinjid: Shadow of the Warrior, DragonFable). Never use art/data copied from those games — only CC0 / self-made assets.
- Main project: `shadow_ninja_godot/` (Godot 4.7.2, GDScript, gl_compatibility, 1280x720, everything built in code; `scenes/main.tscn` is just a root with `scripts/main.gd`).
- Godot binary is not in git: expect `tools/godot/Godot_v4.7.2-stable_win64.exe` and `_console.exe` (see README).

## Code map (`shadow_ninja_godot/scripts/`)
- `game.gd` (autoload `G`): all data (SKILLS tree w/ `pos`/`pre`, passives, GEAR incl. wandering-merchant/event items, ITEMS incl. stat tomes, ENEMIES 1-15 story, 16-20 Halloween yokai, 21-22 rare slimes, MAPS, THEMES, WARPS) + player state `P`, stat formulas (`stat()` adds gear + tome bonuses), save slots.
- `world.gd`: top-down map (TileMapLayer + y-sorted sprites, seeded zone generator), enemies/elites/rare slimes, NPCs, warp shrines, Halloween decor.
- `battle.gd`: turn-based battle, statuses (`ST_INFO`, hover icons), passives, elite/rare logic, rewards.
- `ui.gd`: HUD, dialogs, modals, menu (stats, skill tree, MMORPG bag, quests, bestiary, system), shops, forge, title + save-slot screens.
- `vec.gd`, `df_actors.gd`, `df_proto.gd`: DragonFable-style vector prototype (`Proto_Vector.bat`), not used by the main game yet.
- `autotest.gd`: test harness.

## Testing
- Screenshots walkthrough: `Godot_v4.7.2-stable_win64_console.exe --path shadow_ninja_godot -- --shots=<dir>`
- Full bot playthrough: `... --path shadow_ninja_godot -- --sim=<ninja|warrior|caster|balanced>` (prints `SIM ...` summary incl. rare-slime win rates)
- Parse check: `... --headless --path shadow_ninja_godot --import`
- **Tests must never touch the user's real saves**: autotest sets `G.testing`, so saves go to `user://test_save_N.json` instead of `save_N.json`. Keep it that way.

## Assets
`tools/build_assets.py` copies from the Ninja Adventure pack (`tools/NinjaAdventure/`, not in git — re-download from itch.io); `tools/halloween_art.py` and `tools/rare_slimes.py` generate the self-made sprites.
