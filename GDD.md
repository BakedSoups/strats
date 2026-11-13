# Stracks — Game Design Document

Current direction: 2026-11-13. Godot 4 / GDScript; geometric top-down RTS. This revision incorporates the player's latest economy, HQ opening, commander, and grenade requests and supersedes earlier manpower-as-currency proposals.

## Pillars

Territory funds production. Preserving and upgrading troops matters. Infantry take cover and objectives; vehicles provide force; aircraft provide mobility. A readable contextual panel shows the commander overview, selected base, or selected unit. Thick outlines, flat colors, blue/red teams, and visible projectiles keep the battlefield readable.

## Implemented opening

Each side starts with HQ and one engineer, 1,000 supply, 40 fuel, 500 tickets. HQ trains only engineers and one unique commander. Players must construct Barracks, Support Works, Vehicle Depot, and Helipad to access their rosters. Engineers build defenses as well. The AI follows the same opening and pays the same costs.

Construction uses a validated placement ghost, spends supply only on a valid placement, and advances while an assigned engineer is nearby and not suppressed/retreating. Moving away or losing that engineer pauses it. Another engineer can resume an incomplete site by right-clicking it. Advanced Tools increases construction and repair speed. Construction takes 12/14/16/18 seconds for the four production facilities, excluding travel.

## Economy

| Resource | Function |
|---|---|
| Supply | Universal spending currency for troops, buildings, upgrades, abilities, and HQ recovery |
| Fuel | Additional tank/research/tank-upgrade cost; other recruits cost no fuel |
| Manpower | Weighted occupied army capacity, not money; 60 cap, including paid queued troops |
| Victory tickets | Match condition, separate from the three economic resources |

Supply income: +120/min base, +210/min per owned supply sector. Fuel: +30/min base, +150/min per oil well. Casualties free manpower; troops in transports still occupy it. Queued recruitment reserves capacity immediately to prevent overbooking. Destroying a producer refunds its queued troops and releases their reserved capacity. Unit death does not refund supply/fuel already spent.

Initial manpower weights: engineers 2; rifle/AT squads and commander 3; MGs, mortars, AT guns, scout cars, anti-air 4; helicopters 5; heavy/flame tanks 6. Tune against played matches.

## Facilities and progression

| Facility | Supply | Roster / function |
|---|---:|---|
| HQ | Starting structure | Engineers, unique commander, paid recovery |
| Barracks | 150 | Riflemen, MGs, anti-tank squads |
| Support Works | 180 | Mortars, AT guns, anti-air |
| Vehicle Depot | 220 | Scout cars and light trucks; heavy/flame tanks require this depot's Heavy Workshop |
| Helipad | 250 | Attack and transport helicopters |
| Emplacement | 120 | Fixed defensive fire |

Heavy Workshop costs 220 supply / 40 fuel and takes 14 seconds in that depot's production slot. It is purchased once per depot and does not unlock other depots. Tank recruitment consumes supply, fuel, and manpower capacity. Buildings have separate queues, correct producer-specific spawns, training bars, remaining times, and next-unit labels.

## Commander development and infantry abilities

HQ recruits one living/queued commander at a time, for 180 supply / 3 manpower. The commander is a controllable infantry unit with a distinctive gold ring. Purchased upgrades belong to that commander and are lost on death.

| Upgrade | Supply | Effect |
|---|---:|---|
| Mortar Support | 180 | Unlock targeted mortar barrages |
| Heavy Bombardment | 120 | +35% barrage damage; requires Mortar Support |
| Expanded Barrage | 120 | +30% blast radius; requires Mortar Support |

Mortar barrage: 80 supply, 850 range, 45-second cooldown, six staggered arcing shells, ground area damage that bypasses directional infantry cover. No instant free squads are spawned by this ability.

Infantry grenades: 20 supply, 220 range, 18-second cooldown, arcing throw and area blast. Grenades and barrages damage enemy ground units; aircraft are unaffected. Grenades are useful against clustered squads and cover; damage against armored vehicles is reduced. Commander upgrades improve the barrage separately from its normal weapon.

Buttons and G/M hotkeys enter targeting; left click casts a valid target, right click/Esc cancels. Invalid or cancelled casts spend nothing. Cooldowns and costs prevent repeat-click abuse. The AI uses the same ability checks.

## Map: Estuary Crossing

3200 × 2200, inspired by the player's supplied waterfront layout. A diagonal estuary separates two urban banks. The largest bridge is central and holds a VP. Two narrower side crossings create flanking alternatives, so losing the center does not seal the map. Two further VPs sit in north/south bank plazas. Four supply sectors and two oil wells have rotationally balanced placements. HQs and construction yards sit on opposite banks; eight city blocks form street parcels and waterfront sight barriers.

Water is impassable to ground units. AStar navigation respects shore clearance and traversable bridge decks; aircraft ignore the water. Placement validation rejects river sites and bridge obstructions. Unloading searches for safe land/bridge positions. No external map tiles or real-world scale accuracy are claimed.

## Implemented fog and reconnaissance

Both factions share sight among living deployed units and operational buildings. Ground sight is blocked by neutral buildings; aircraft see over them. Owned flags give limited local vision. Explored terrain persists after scouts leave, while enemies disappear from world/minimap when no longer seen. Enemy buildings retain only last-known position/type markers until revisited; unseen changes are not exposed. Loaded troops cannot reveal the map from inside transports.

Auto-targeting requires a currently spotted target. Mortars may use allied spotting; AI grenade/barrage targets and anti-air counters use actual observed enemies. Objective ownership/locations and crossing geography remain public. Player area bombardment may target terrain, but does not reveal hidden enemies by itself.

Scout Car: 200 supply / 0 fuel / 4 manpower, 760 sight, 175 speed, light weapon. Recon Optics is a per-unit 100-supply upgrade to 950 sight. It remains vulnerable to armor and AT weapons.

Light Truck: 140 supply / 0 fuel / 3 manpower, 380 sight, 180 speed, two infantry squad slots, unarmed. Available from a basic depot. It moves troops across roads/bridges but cannot capture objectives itself. Loading sacrifices the passengers' sight and firepower until unloading. The AI keeps construction engineers out of troop transports.

## Combat and roster

Riflemen, MGs, engineers, anti-tank squads, mortars, AT guns, scout cars, light trucks, heavy tanks, flame tanks, attack helicopters, transport helicopters, anti-air, and commander. Squads currently share aggregate health. Three veterancy levels reward combat separately from twenty-one purchasable upgrade definitions.

MG setup, arcs, and suppression control approaches. Mortars bypass cover. Tanks are vulnerable on their flanks/rear. Flame tanks use short cone attacks, burn effects, and temporary fire zones. Helicopters retain spinning rotors while moving, hovering, or firing; transports carry up to three squads. Infantry capture; hostile presence contests; vehicles cannot capture. Holding more VPs drains enemy tickets; losing HQ also loses the match.

A is **fire in range**: stop selected movement and engage valid enemies already in weapon range, respecting eligibility, sight, setup, and reload. It does not request a destination or chase. Arrow keys pan; right click moves. These defaults avoid the previous A/camera conflict. Reserve G/M for abilities.

## Interface

Persistent top bar: separate Supply, Fuel, and Manpower icon cards with large balances, gross income/minute, free army slots, and breakdown tooltips. Tickets, VP control, drain rate, and time occupy a separate match-status group. Point labels show their real supply/fuel income and ownership, with compact overview labels. Minimap shows units, objectives, neutral blocks, and bases. World health bars show all units.

The bottom is contextual. With only one friendly base, show its recruitment roster directly without an intermediate base-selection card. Hide the controls footer. Commander overview offers polished base cards with portraits, state, and role. A selected base has its own framed identity card, roster, cost/capacity tooltips, construction/research/training progress, current unit and next queued unit. Selecting a unit shows its large portrait, health/statistics, contextual tool cards, upgrades, and live selection cards. Generic movement/order buttons are replaced by mouse and keyboard controls. Engineer cards are Build, Repair, Barricade, and Grenade; Build opens illustrated plans with costs/work times. Repair targets damaged friendly vehicles or completed buildings for free. Barricades cost 45 supply, preview their footprint, and rotate with Tab. Advanced Tools improves both repair and construction speed by 80%. Transports show separate Load and Unload cards; commanders show grenade and mortar abilities. Cards expose costs, cooldowns, and unavailable reasons. Ineligible/locked actions remain explained in tooltips.

Settings: saved volume bus levels, resolution/fullscreen, camera speed, zoom sensitivity, edge scrolling, and key bindings. Audio content is not yet present. Accessibility options are excluded by request. Main, pause, victory, and defeat menus remain available.

## Next priorities and known limits

Balance the HQ opening, capture timing, fuel gating, manpower weights, commander survivability, and grenade/barrage value through played matches. Add garrisoning, separate soldier reinforcement/healing/vehicle servicing, and supply-line cutoffs after the base loop is stable. Forward Camps, cancellation/refund controls, economy history, save/load, and difficulty settings remain planned. No additional resource currencies are planned.

Neutral blocks are not destructible and there is no multiplayer/campaign. The manpower cap is fixed. The current first builder is provided to prevent an empty-start deadlock. Enemy AI uses simple priorities with an infrastructure reserve rather than coordinated tactical planning.

## Acceptance checks

- Real skirmish starts with HQ and engineer only; HQ cannot train line combat troops.
- All four facilities must be constructed, with valid placement and assigned engineers.
- Each depot enforces its own Heavy Workshop gate and research cost/timer.
- Supply/fuel/capacity costs match the UI; queues reserve manpower and deaths release it.
- Ability casts enforce unlock, range, cost, cooldown, ground target eligibility, and cancellation.
- Ground routes avoid buildings and water, cross each bridge, and unload troops onto safe ground.
- Fog hides enemy units/HQs and their minimap presence, preserves explored terrain and last-known structures, blocks ground sight at buildings, and excludes loaded troops.
- The scout sees farther than infantry and its optics apply to actual shared targeting. The truck carries two squads without bypassing costs or capacity.
- Base/unit/upgrade clicks cannot free an actively dispatching button.
- AI builds all four facilities, recruits and upgrades without negative resources or capacity overrun.
- Existing combat, cover, capture, recruitment, upgrades, transport, and victory remain playable.
- Verify the running game and review an 18-second gameplay recording; source tests alone are insufficient.

Cover feedback: hovering near barricades previews infantry positions before issuing movement; right-click uses those same slots. Infantry in cover display green overhead shields. Vehicles receive neither cover slots nor shields. Damage reduction applies only across the barricade, so flanking bypasses protection.
