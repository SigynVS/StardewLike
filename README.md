# StardewLike

A Stardew Valley–style farming + combat game built in **Godot 4.6 / GDScript**.

Everything renders procedurally (no external art assets yet), so the project runs
immediately on `F5` with zero setup — colored tiles stand in for sprites while the
game logic is built out.

## Features

- **Farming loop** — till soil, plant seeds, water, sleep to grow, harvest
- **3 crops** with seasonal planting windows (Parsnip, Potato, Cauliflower)
- **Day / clock / season cycle** — time flows 6 AM–2 AM; pass out if you stay up too late; 7-day seasons
- **Energy & stamina** — tool use costs energy; sleep to recover
- **Economy** — buy seeds, sell crops, reinvest toward a $1000 goal
- **Obstacles** — trees and rocks with collision you can clear
- **Well** — refill your watering can
- **Quest board** — 19 missions tracked with auto-payout rewards
- **Combat** — Mines (endless descent, mine ore) and a Dungeon (cleared-floor combat with a payout); sword combat vs. enemies with HP/AI
- **Save / load** — full progress persisted to `user://savegame.json`
- **Title screen** with New Game / Continue

## Controls

| Action | Key |
|--------|-----|
| Move | WASD / Arrows |
| Use tool | E / Space |
| Switch tool | Q |
| Select seed | 1 / 2 / 3 |
| Buy seed | B |
| Clear obstacle | C |
| Refill water (at well) | R |
| Quest board (near it) | T |
| Enter mine / dungeon (near it) | G |
| Sleep | Enter |
| Menu | Esc |

## Running

Open the project in **Godot 4.6** and press **F5**.

## Roadmap

- Swap procedural rectangles for sprite art (Sprout Lands)
- NPCs / villagers, fishing, sound
