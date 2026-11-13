# Stracks — Territory & Steel

A playable geometric tactical RTS for Godot 4.7 / GDScript. Blue Azure Command fights red Crimson Command over territory, supply, fuel, and victory points.

## Run

```bash
./run.sh
```

Click **Deploy / Resume**. The detached launcher keeps the game independent of the tool terminal and writes logs to `~/.local/state/stracks/engine.log`. Direct launch also works: `/usr/local/bin/godot --path .`.

## Resource HUD

Supply, Fuel, and Manpower now have separate icon cards, large values, and distinct accents. Supply/fuel show current gross income per minute; manpower shows used/capacity and free slots, including queued troops. Hover for income sources and deployed/reserved capacity. Victory tickets, VP control, ticket drain, and match time are grouped separately. The reviewed HUD demonstration is `screenshots/resource-hud.mp4`.

When only one friendly base exists, its recruitment roster opens directly in the bottom panel. The bottom controls footer is hidden.

Hover near a barricade with infantry selected to preview cover positions and shield markers. Right-click places the selected infantry in the previewed slots. Infantry near cover show a green shield above their health bar; vehicles never receive this indicator or cover protection. Cover still protects only against shots from the opposite side. Reviewed demonstration: `screenshots/cover-preview.mp4`.

## Unit tools

The bottom panel uses contextual tool cards instead of a generic order grid. Engineers have **Build, Repair, Barricade, and Grenade** cards with costs and cooldowns. Build opens illustrated plans with prices and work times. Repair targets a damaged friendly vehicle or completed building and costs no supply. Barricades cost 45 supply, preview before placement, and rotate with Tab. Right-click/Esc cancels targeting. Advanced Tools increases repair and construction speed by 80%. Transports have separate Load and Unload cards; infantry and commanders show their available abilities. Movement, fire-in-range, stop, and retreat remain available through mouse/keyboard controls.

Reviewed 18-second demonstration: `screenshots/unit-tools.mp4`.

## Current opening and resources

Each faction starts with **one HQ and one engineer**, 1,000 supply, 40 fuel, and 500 victory tickets. There are no prebuilt production facilities or free combined-arms armies.

| Resource | Rule |
|---|---|
| Supply | Shared currency for recruitment, construction, upgrades, abilities, and HQ recovery. Base +120/min; each supply sector +210/min. |
| Fuel | Required for heavy/flame tanks, Heavy Workshop research, and tank upgrades. Base +30/min; each oil well +150/min. Other recruits cost zero fuel. |
| Manpower | Weighted army capacity, displayed as used / 60. Living units and paid recruitment queues reserve capacity; casualties or refunded orders release it. Not a spendable currency. |
| Victory tickets | Hold more of the three VPs to drain opposing tickets. Zero tickets or HQ destruction loses the match. |

Click HQ to train **engineers** or one unique **commander**. Select an engineer, open **Build**, choose a building, and left-click a valid green footprint. Right-click/Esc cancels placement without spending. Build near your HQ or an owned sector; blocked footprints and objective rings are excluded. Construction requires its engineer nearby; leaving or losing the builder pauses work. Select another engineer and right-click the unfinished site to resume it.

| Facility | Supply | Work time | Roster |
|---|---:|---:|---|
| Barracks | 150 | 12s | Riflemen, machine guns, anti-tank squads |
| Support Works | 180 | 14s | Mortars, AT guns, anti-air |
| Vehicle Depot | 220 | 16s | Scout cars, light trucks; heavy/flame tanks after research |
| Helipad | 250 | 18s | Attack and transport helicopters |
| Emplacement | 120 | 20s | Fixed defensive fire |

A depot's **Heavy Workshop** costs 220 supply / 40 fuel and takes 14 seconds. It unlocks tanks for **that depot**. Research and training share its production slot. Separate producers have independent FIFO queues, progress bars, current/next-unit labels, and correct spawn positions. Destroyed producers refund their queued unit costs; completed buildings cannot be sold.

## Commander and grenades

The commander costs 180 supply and 3 manpower, and is recruited from HQ. Buy **Mortar Support** for 180 supply to unlock targeted bombardment. Additional per-commander upgrades increase damage and blast radius. A barrage costs 80 supply, has an 850-pixel cast range and 45-second cooldown, and drops six visible arcing shells.

Infantry can throw **frag grenades** with the bottom-panel button or **G**: 20 supply, 220-pixel range, 18-second cooldown. Press **M** or the mortar button for a commander barrage. Click to target; right-click/Esc cancels. Costs are deducted only on a valid cast; cooldown and range are enforced. Explosions damage enemy ground units and bypass directional infantry cover. Commander upgrades are lost when that commander dies.

## Controls and settings

| Input | Action |
|---|---|
| Arrow keys / wheel | Pan / zoom |
| Left click / drag | Select unit, building, or formation |
| Empty ground | Commander overview and base cards |
| Right click | Movement order; enemy targeting; engineer resume-construction |
| Shift + right click | Queue movement |
| A | Stop movement and fire at valid enemies already in weapon range; no destination or pursuit |
| X / R | Stop / retreat |
| G / M | Target grenade / commander mortar barrage |
| Ctrl + 0–9 / 0–9 | Assign / recall control group |
| Esc | Cancel targeting/placement, or pause menu |

The bottom panel follows commander, base, or unit selection. Base cards include previews, operational state, and roster descriptions. Unit cards show portraits, health, orders, abilities, and individual upgrades. All deployed units have overhead health bars. Only infantry receive barricade protection and Take Cover orders; vehicles use directional armor.

Settings are available from the main/pause menu and top-right button: persistent audio bus levels, resolution/fullscreen, camera speed, zoom sensitivity, edge scrolling, and camera/fire/stop/retreat bindings. Audio assets are not implemented. Accessibility settings are outside the requested scope. G and M are reserved for abilities. Existing preferences migrate from the previous game name.

## Fog, scouting, and transport

Fog has three states: unexplored shroud, dim explored terrain, and currently visible ground. Living units and completed buildings share sight; owned flags reveal a small area. Neutral buildings block ground sight. Aircraft see over them. Loaded troops and dead units contribute no sight.

Enemy units disappear from the battlefield and minimap when no longer spotted. Enemy bases are hidden until seen, then retain only a muted last-known marker; unseen health, production, upgrades, and destruction are not revealed. Auto-fire, indirect targeting, AI artillery/grenade choices, and anti-air recruitment use the same team sight checks. Objective positions/ownership, river banks, and bridge locations remain public strategic information. Area abilities can still be aimed at known terrain without confirming a hidden enemy hit.

| Early vehicle | Supply / Fuel / Manpower | Role |
|---|---|---|
| Scout Car | 200 / 0 / 4 | Armed wheeled recon, speed 175, sight 760; Recon Optics costs 100 supply and extends sight to 950 |
| Light Truck | 140 / 0 / 3 | Fast unarmed transport, speed 180, sight 380, carries two infantry squads |

Both are available at an unupgraded depot. Ordinary infantry sight is around 380–420, so scouts can spot contacts across the estuary for allied weapons. Selected units show their sight statistic; the scout has a sight-range ring. Load/unload with the transport's unit-panel action. Unloaded troops are placed on traversable land or bridge decks. Transport helicopters retain three squad slots and can fly over water. Cargo still counts against manpower. The AI uses scouts and trucks without loading its construction engineer into transports.

## Battlefield and combat

**Estuary Crossing** is a 3200 × 2200 battlefield inspired by the supplied waterfront map, built from procedural geometry rather than copied map imagery. A diagonal estuary separates two street-grid districts. HQs start on opposite banks. The main central bridge carries a victory point; smaller western/eastern bridges provide longer flanking routes. The other victory points lie in plazas on each bank, alongside four supply sectors and two oil wells. Eight neutral building blocks frame the urban streets and waterfront roads.

Water blocks ground movement and construction. Cached AStar paths route infantry, scouts, trucks, and tanks through the three bridge decks; aircraft cross freely. Bridges cannot be obstructed by newly placed buildings. Buildings/barricades obstruct ground movement; neutral structures stop direct ground fire while mortars and grenades arc over them. Neutral buildings are not garrisonable or destructible yet.

The roster includes riflemen, MGs, engineers, anti-tank squads, mortars, AT guns, scout cars, light trucks, heavy and flame tanks, attack/transport helicopters, anti-air, and a commander. Combat includes suppression, setup/arcs, directional cover and armor, visible shells/rockets, flame cones, burning ground, three veterancy levels, and twenty-one individual upgrade definitions. The AI builds from HQ, reserves resources for infrastructure, researches tank access, recruits, captures, retreats, upgrades units, and uses abilities under the same costs, caps, and enemy-visibility rules.

## Verification and proof

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 120
godot --headless --path . --script test/resource_hud.gd
godot --headless --path . --script test/fog_bridge.gd
godot --headless --path . --script test/map_placement.gd
godot --headless --path . --script test/progression.gd
godot --headless --path . --script test/ai_opening.gd
godot --headless --path . --script test/ui_clicks.gd
godot --headless --path . --script test/context_ui.gd
godot --headless --path . --script test/simulation.gd
godot --headless --path . --script test/settings.gd
godot --headless --path . --script test/toolkit.gd
```

Check logs for `SCRIPT ERROR` or `ERROR`, not just exit status. Tests cover HQ restrictions, construction attendance and placement, producer research/queues, supply/fuel/cap accounting, grenades/barrages and cooldowns, map navigation, real viewport clicks, combat, captures, victory, and settings. `test/fixtures.gd` supplies an explicit combined-arms scenario for older regression tests; it does not change the real opening.

The recon 18-second recording is `screenshots/recon-bridge.mp4`, generated by `test/presentation_recon.gd`. It uses a prepared recon patrol on surveyed terrain; normal matches start unexplored outside friendly sight. It shows the bridge layout, scout reveal/retreat, optics, and light-truck delivery. The previous base-building recording is `screenshots/base-building-update.mp4`, generated by `test/presentation_progression.gd`. It shows the HQ opening, construction, commander upgrades, grenades, and a mortar barrage. Older recordings in `screenshots/` show previous iterations.

## Architecture

| Source | Responsibility |
|---|---|
| `scripts/battlefield.gd` | Map, river/bridges, AStar navigation, resources, buildings, and queues |
| `scripts/tool_card.gd` | Contextual tool cards and procedural ability icons |
| `scripts/resource_badge.gd` | Resource-card icons, readable balances, income/capacity details |
| `scripts/battle_vision.gd` | Team sight, building occlusion, fog texture, explored terrain, and last-known bases |
| `scripts/unit.gd` | Unit state, orders, cached routes, abilities, cargo, and upgrades |
| `scripts/unit_spec.gd`, `weapon_spec.gd`, `upgrade_spec.gd` | Reusable combat and upgrade Resources |
| `scripts/building_spec.gd`, `ability_spec.gd` | Building costs/times and ability definitions |
| `scripts/game.gd` | Simulation, production/research, AI, contextual UI, input, and procedural world rendering |
| `scripts/unit_portrait.gd` | Geometric unit and building previews |
| `scripts/game_settings.gd`, `settings_menu.gd` | Preferences and settings UI |
| `data/*.tres` | Configurable unit, weapon, upgrade, building, and ability data |
| `scenes/build.gd` | Validated build-time scene generation |

## Remaining work

Aggregate squad health remains in use. There is no garrisoning, supply-line connectivity, save/load, multiplayer, campaign, or game audio. Forward camps, queue cancellation, research cancellation/refunds, and detailed economy history remain planned. Population cap is fixed at 60; costs and timings need played-match balance testing. Neutral structures are static, not destructible. The integrated simulation/UI script can be split further as the game grows. See [GDD.md](GDD.md) for the current design.

## Asset manifest

All art is procedural runtime geometry; no external artwork or paid generation. The asset-gen skill was inspected; its local generator is unavailable and bitmap assets are unnecessary for this style.

| Asset | Description | In-game size | Source | Cost |
|---|---|---|---|---|
| Infantry/commander | Circle squads, barrels, gold commander ring | 45–55 world px | `scripts/game.gd` | $0 |
| Vehicles | Wheeled scouts/trucks, tracked tanks, rotating turrets, flame nozzles | 64–80 world px | `scripts/game.gd` | $0 |
| Helicopters | Fuselage, animated main/tail rotors, shadow | ~100 world px rotor span | `scripts/game.gd` | $0 |
| Map | Grid, waterfront streets, estuary, three bridges, neutral blocks, points and cover | 3200 × 2200 world px | `scripts/battlefield.gd`, `scripts/game.gd` | $0 |
| Bases | Distinct building symbols and construction/training progress | ~100 × 100 world px | `scripts/game.gd` | $0 |
| Effects | Bullets, shells, grenades, mortar barrages, flames/explosions | 4–190 world px | `scripts/game.gd` | $0 |
| UI | Contextual base/unit cards, portraits, settings | 1440 × 900 logical viewport | `scripts/game.gd`, `scripts/unit_portrait.gd` | $0 |
