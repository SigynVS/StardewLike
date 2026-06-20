# Art assets

The game loads sprites from this folder **if they exist**, and falls back to
procedural colored rectangles when they don't. So you can drop these in one at a
time and watch the game gain art piece by piece — nothing breaks if a file is missing.

## Drop in these PNGs (32×32 recommended, square)

| Filename | What it is |
|----------|-----------|
| `grass.png` | Default ground tile |
| `tilled.png` | Tilled (hoed) soil |
| `watered.png` | Watered soil |
| `tree.png` | Tree obstacle |
| `rock.png` | Rock obstacle |
| `well.png` | Water well structure |
| `board.png` | Quest board structure |
| `mine.png` | Mine entrance |
| `dungeon.png` | Dungeon entrance |
| `player.png` | Player character (single frame for now) |

## Using Sprout Lands

Download the free pack: https://cupnooble.itch.io/sprout-lands-asset-pack

The pack ships as spritesheets and some individual tiles. Easiest path:
crop/export the tile you want from the sheet, save it here under the matching
filename above. Suggested sources from the pack:

- `grass.png` ← Grass tile from the tileset
- `tilled.png` / `watered.png` ← Tilled Dirt tiles
- `well.png` / `board.png` / `tree.png` / `rock.png` ← from the Objects sheet
- `player.png` ← one frame from the Basic Character spritesheet

Anything 32×32 (or square at any size — it's scaled to the tile) works.
Restart the game after adding files and they appear automatically.
