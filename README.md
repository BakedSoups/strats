# STRATS — Territory & Steel

A playable single-player tactical RTS for Godot 4.7, written in GDScript. Blue Azure Command fights red Crimson Command on a 2600 × 1800 battlefield. All artwork is generated at runtime from outlined geometric primitives; no external artwork or paid assets are required.

## Run

```bash
./run.sh
```

`run.sh` launches a detached desktop session and writes diagnostic logs to `~/.local/state/strats/`, so closing a tool terminal does not close the game. Running `/usr/local/bin/godot --path .` directly is also supported.

Press **Deploy**. Both factions begin with a mixed force and operational production buildings so the full roster is immediately playable. Capture the three VP rings to drain opposing tickets. Destroying the opposing headquarters also wins.

## Design direction

See [GDD.md](GDD.md) for the current-state audit and the planned engineer-led builder system, specialized camps and troop unlocks, and resource UI with income, cost previews, spending receipts, and reinforcement controls. The GDD separates existing behavior from proposed rules and balance values.

Next work: economy/UI clarity; construction placement and builder attendance; stable building IDs and independent queues; camp progression and forward reinforcement. The builder/camp/economy changes remain planned. Standard settings are implemented; see below.

## Controls

| Input | Action |
|---|---|
| Arrow keys | Pan camera |
| Wheel | Zoom |
| Left click / drag | Select one unit / formation |
| Shift + select | Add to selection |
| Right click | Move; click an enemy to engage |
| Shift + right click | Append waypoint |
| A | Stop movement and fire at valid enemies in weapon range; no click or pursuit |
| X | Stop selected formation |
| R | Retreat and reinforce at HQ |
| Ctrl + 0–9 / 0–9 | Assign / recall control group |
| Minimap click | Reposition camera |
| Escape | Pause / resume menu |

These are the default bindings. Open **Settings** from the main/pause menu or the top-right button to rebind camera movement, fire-in-range, stop, and retreat. Escape and number-group shortcuts remain reserved. Duplicate bindings are rejected.

## Built

- Infantry rifle squads, machine guns, engineers, anti-tank squads, mortars, AT guns, scout cars, battle tanks, flame tanks, attack helicopters, transport helicopters, and anti-air vehicles.
- Continuous combat, swept projectile collision against units, arcing mortar shells, explosions, cone flame damage, fading flame particles, burning ground, and damage over time.
- Directional barricade protection, flanking, frontal/side/rear vehicle armor, suppression, setup delays, firing arcs, ground obstacle detours, separation, and independent aerial movement.
- Individually controlled helicopters with continuously animated main and tail rotors, shadows, bobbing, patrol ability, attack move, retreat, and transport loading/unloading (up to three nearby squads).
- Three victory points, four manpower sectors, two oil wells, capture progress and enemy contesting; infantry capture, vehicles cannot. Territorial income, ticket drain, victory and defeat.
- Headquarters, barracks, support works, vehicle depots, helipads, timed engineer construction, and automatic defensive emplacements. Buildings can be attacked and destroyed.
- FIFO recruitment per individual production building with costs and timers, production-building prerequisites, correct producer spawn locations, and paid healing/reinforcement near HQ. Orders at destroyed producers are refunded in full.
- Contextual bottom panel: commander overview when nothing is selected, base recruitment when a building is selected, and unit portraits, orders, upgrades, and health cards when units are selected. Engineers access construction from their unit panel.
- Seventeen reusable upgrade resources. Costs, stat multipliers, prerequisites, purchased status, and affordability are enforced for both sides. Rocket pods add visible rockets; flame fuel upgrades affect range, burn damage, and sustained firing.
- Three veterancy levels earned through combat, with reload and survivability bonuses separate from purchased upgrades.
- Enemy AI captures and contests sectors, recruits combined arms, buys upgrades, uses cover, retreats damaged units, builds defenses, and responds to aircraft with anti-air recruitment.
- Main menu, pause, minimap, command paths, selection and range outlines, health indicators, resources, match clock, and end screens.

## Contextual command panel

Click empty ground for the **Commander** overview and clickable base list. Click a friendly building on the battlefield (or its overview card) for **Base** management: the vehicle depot offers scout cars, battle tanks, and flame tanks; other producers show their own rosters. Clicking a recruitment card spends the shown resources and trains at that specific building. Duplicate producers run independent queues. Destroyed producers cannot spawn units; their queued costs are refunded.

Select a unit for its large procedural preview, statistics, commands, upgrades, and a scrolling grid of selected-unit previews with live health bars. Select a card to make that unit active. Only the active unit's attack range is drawn, reducing stacked rings. Every deployed unit now has an overhead health bar, including healthy and unselected units.

**Take cover** applies only to infantry in a mixed selection and is disabled for vehicle-only selections. Barricade damage reduction applies only to infantry; vehicles use directional armor and continue to navigate around physical barricades.

## Settings

Open **Settings** from the main menu, pause menu (Esc), or top-right battlefield button. The match pauses while settings are open and resumes only if it was running before. **Apply & Save** commits changes; **Cancel / Back** or Esc discards unapplied changes. Restore defaults changes the preview until applied.

- Master, music, and effects volume (bus levels are functional; there is no game audio yet).
- Window resolutions: 1280×800, 1440×900, 1600×900, and 1920×1080; fullscreen/windowed switching. The logical battlefield/UI size remains 1440×900 with aspect-preserving letterboxing.
- Camera pan speed, zoom sensitivity, and optional edge scrolling at battlefield boundaries.
- Unique key bindings for camera directions, fire-in-range, stop, and retreat. Defaults are arrow keys / A / X / R, so A engages in-range targets without panning or ordering movement. Untouched older WASD/Q default bindings migrate automatically; custom bindings are preserved. Escape cancels key capture; unsupported or duplicate keys explain their rejection.
- Preferences persist in Godot's `user://settings.cfg` and survive restarting the game or starting a new operation. Invalid saved values are clamped and invalid binding sets revert to defaults.

Accessibility settings are excluded from this milestone. Audio assets, graphical quality presets, and save/load remain future work.

## Architecture

| File | Responsibility |
|---|---|
| `scripts/unit_portrait.gd` | Procedural infantry, vehicle, helicopter, and building previews for the contextual panel |
| `scripts/game_settings.gd`, `scripts/settings_menu.gd` | Persistent preferences, display/audio application, input bindings, and modal settings UI |
| `scripts/unit_spec.gd`, `data/unit_*.tres` | Configurable unit statistics and weapon references |
| `scripts/weapon_spec.gd`, `data/weapon_*.tres` | Projectile speed, splash, setup, arcs, burning |
| `scripts/upgrade_spec.gd`, `data/upgrade_*.tres` | Reusable per-unit upgrade definitions and prerequisites |
| `scripts/unit.gd` | Unit state, queued orders, stats, cargo, upgrades |
| `scripts/battlefield.gd` | Terrain, sectors, cover, routing, income, queues |
| `scripts/game.gd` | Combat simulation, strategic AI, input, procedural rendering, and UI integration |
| `scenes/build.gd` | Build-time main scene generator |
| `test/simulation.gd` | Deterministic gameplay assertions |
| `test/presentation.gd` | Deterministic 18-second gameplay presentation |

## Validation and proof

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 120
godot --headless --path . --script test/simulation.gd
godot --headless --path . --script test/settings.gd
godot --headless --path . --script test/context_ui.gd
```

Simulation assertions cover resource deductions, nonrepeatable upgrades and prerequisites, capture, ticket drain, recruitment, flame cone inclusion/exclusion and burn, transport, building construction, suppression, directional armor, projectile flight layers, 60 seconds of combat/AI, and victory.

Settings checks additionally cover persistence, corrupt-value validation, binding conflicts, audio mute, apply/cancel/defaults, paused gameplay, and updated command labels/input. `test/display_settings.gd` checks all four resolutions and fullscreen switching in a graphical session. A reviewed 18-second settings demonstration is `screenshots/settings-demo.mp4`.

Context UI checks cover real depot clicks, roster filtering, independent producer queues/spawns, infantry-only cover orders/protection, A stationary engagement, and destroyed-producer refunds. The reviewed 18-second demonstration is `screenshots/context-demo.mp4`.

The gameplay recording is `screenshots/strats-gameplay.mp4` (18 seconds, 1440 × 900, 30 fps). Its scripted presentation positions existing armies for a skirmish and orders them into battle, purchases a flame range upgrade, switches to a helicopter, and recruits a tank. It uses the same combat simulation as normal play.

## Remaining refinements / practical limits

This is a compact playable implementation, not a production-scale Company of Heroes simulation. Squads use aggregate health with decorative squad members rather than independently simulated soldiers. Ground routing uses local barricade detours and separation, not a global navigation mesh. AI uses periodic heuristics rather than coordinated tactical planning. Production buildings begin operational; engineers can add more. There is no fog of war, save/load, multiplayer, campaign, or audio. Balance and prolonged-match path congestion need playtesting. The integrated simulation/render/UI script can be split further as the game grows.

## Asset manifest

The asset-gen skill was inspected. Its local generator is not installed; bitmap generation is unnecessary for the requested primitive art. All assets below are generated directly by the runtime renderer, with zero external generation cost.

| Name | Description | In-game size | Source | Cost |
|---|---|---|---|---|
| Infantry squads | Outlined circles with gun barrels and two squad markers | ~45 × 45 world px | `scripts/game.gd` | $0 procedural |
| Ground vehicles | Rectangular hulls, tracks, circular independent turrets | ~84 × 56 world px | `scripts/game.gd` | $0 procedural |
| Helicopters | Rounded fuselage, cockpit, main/tail rotors and shadow | ~100 × 94 world px rotor span | `scripts/game.gd` | $0 procedural |
| Battlefield | Muted grid, roads, capture rings, production buildings and barricades | 2600 × 1800 world px | `scripts/game.gd`, `scripts/battlefield.gd` | $0 procedural |
| Combat effects | Bullets, shells, rockets, flames, impact rings, burning ground | 4–190 world px | `scripts/game.gd` | $0 procedural |
| Interface and previews | Contextual panels, procedural unit portraits, and built-in font labels | 1440 × 900 viewport | `scripts/game.gd` | $0 procedural |

### Stability fixes

Panel rebuilds remove old controls immediately and defer their destruction until after input dispatch. This avoids deleting a base/unit/upgrade button during its own click signal. `test/ui_clicks.gd` dispatches real viewport mouse events through these transitions and checks repeated base selection; inspect its log for engine/script errors as well as its exit code.
