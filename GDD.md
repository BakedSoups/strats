# STRATS — Game Design Document

Updated: 2026-11-13. Engine: Godot 4, GDScript. Platform: desktop, single-player versus AI.

This document records the existing playable implementation and the next design direction. **Current** means present in the source; **Planned** means specified here but not implemented. New costs, timers, limits, and unlocks are starting balance proposals, not validated balance. The builder/camp direction comes from the latest brief; camp roles and numerical values below are proposed interpretations.

## 1. Game identity

A top-down tactical RTS combining territorial control and combined arms with minimalist geometric visuals. Blue fights red across a muted green-gray grid. Units have thick outlines, readable silhouettes, visible projectiles, and simple movement/combat animations. Helicopters remain controllable units with continuously rotating rotors; flame tanks clear infantry and cover at close range.

The player should make three recurring decisions: which territory to contest, which force counters the enemy, and where to invest resources in units, individual upgrades, or infrastructure. Good positioning and preserving veteran units should matter alongside production.

## 2. Current playable baseline

| System | Current implementation |
|---|---|
| Match | Two factions; 500 starting tickets each; victory through ticket drain or destroying the opposing HQ |
| Map | 2600 × 1800 world pixels; two HQs, three VP sectors, four manpower sectors, two oil wells; roads and directional barricades |
| Starting state | Each side starts with 11 units from the combined-arms roster, all four production building types, 900 manpower, and 240 fuel |
| Roster | Riflemen, machine guns, engineers, anti-tank squads, mortars, AT guns, scout cars, battle tanks, flame tanks, attack helicopters, transport helicopters, anti-air vehicles |
| Infantry | Captures sectors; aggregate squad health with decorative squad members; retreat and paid HQ recovery |
| Combat | Automatic targeting, projectiles, mortar splash, suppression, setup and firing arcs, directional cover, vehicle facing armor, flame cones, burning ground and damage over time |
| Aircraft | Independent aerial movement, hovering and animated main/tail rotors; transports carry up to three squads |
| Progression | Seventeen per-unit upgrade resources with costs and prerequisites; three combat veterancy levels |
| AI | Periodic recruitment, capture/contest orders, upgrades, cover orders, damaged-unit retreat, aircraft counters, defensive emplacement construction |
| UI | Menu/pause/end screens; commander/base/unit contextual bottom panel; procedural unit previews and live selection health cards; overhead health bars on all units; selected-base rosters, resource totals, tickets, minimap, and active-unit range |
| Controls | Rebindable arrow-key camera / A fire-in-range / X stop / R retreat defaults; zoom wheel, click/drag selection, queued orders, and control groups |
| Settings | Implemented: saved audio bus levels, window resolution, fullscreen, camera speed, zoom sensitivity, edge scrolling, and unique key bindings; modal menu pauses the match |

### Economy as implemented

| Resource or expense | Current rule |
|---|---|
| Manpower income | Base +1.5/sec; each owned manpower sector +3.5/sec |
| Fuel income | Base +0.5/sec; each owned oil well +2.5/sec |
| Victory drain | Losing side loses 1.4 tickets/sec for each extra VP held by the opponent |
| Recruitment | Full manpower/fuel cost deducted when queued; duration is 5 + fuel cost × 0.055 seconds |
| Upgrades | Full cost deducted immediately; effects apply to the selected unit |
| Building construction | Each option costs 150 manpower / 30 fuel and takes 12 seconds |
| Engineer barricade | 45 manpower; special ability also enables nearby vehicle repair |
| HQ recovery | Up to 16 HP/sec per nearby unit, costing 0.35 manpower per restored HP |

### Current construction limitations

Engineers can add barracks, support works, depots, helipads, and emplacements. Placement is a fixed offset from the engineer. Construction advances automatically without continuous builder attendance. There is no placement preview, footprint validation, cancellation/refund UI, or camp specialization. Selectable building management and producer-specific recruitment are now implemented.

Queues now belong to stable individual building IDs: two depots train concurrently and units spawn at their assigned producer. Clicking a producer filters recruitment to its roster. Destroyed-producer orders currently receive a full refund and cannot spawn units. Queue cancellation, rally points, and the more detailed proposed refund rules remain planned.

The resource HUD shows balances but not income, expense breakdowns, or recent transactions. Automatic HQ spending is particularly hard to interpret.

## 3. Planned core loop: build, expand, contest

Start with an HQ, one engineer squad, and one rifle squad. Build an infantry camp, capture income sectors, then choose support, ground armor, or aviation investment. Expand with vulnerable forward camps to shorten reinforcement travel. Preserve squads and upgrade individual units while fighting over the three VPs.

Keep the present fully deployed start as a separate **Sandbox / Combined-Arms Demo** option. Normal skirmish uses the builder opening so infrastructure choices matter. Starting resources should cover an infantry camp and an additional rifle squad; tune the exact reserve through opening playtests.

Continue using manpower and fuel. Do not introduce wood, ore, or a separate currency for every camp. Victory tickets remain a match condition, not spendable money.

## 4. Planned builders and construction

Engineers are the builder troop; avoid adding a second worker unit with the same role. They can fight and capture, but are vulnerable and must spend time constructing instead of fighting.

Construction interaction:

1. Select engineers and choose **Build** in the bottom panel.
2. Choose a camp or defense. Its card shows purpose, exact resource costs, time, footprint, and prerequisites.
3. Show a world-space placement ghost. Green means valid; red means blocked, with a reason. Left-click places; right-click or Escape cancels placement without spending.
4. A valid placement reserves the footprint and deducts its full cost once. The engineer travels to the site and constructs within 90 world pixels.
5. Construction advances only while its assigned engineer is alive, in range, and not retreating or suppressed. Moving away pauses work. Another engineer may take over; builders do not stack speed in the first version.
6. Completion activates the building, its production queue, rally point, and minimap marker.

Placement requires owned, uncontested territory, a reachable site, no overlap with buildings or barricades, and no overlap with objective capture rings or HQ safe zones. Build footprints participate in ground pathfinding; aircraft fly over them. Placement and spending validation must happen together so double-clicks cannot create duplicate charges or overlapping foundations.

Use distinct construction states: **Planned → Travelling → Building → Paused → Complete**, plus **Cancelled** and **Destroyed**. The selected builder and site display progress, remaining work time, and any pause reason. Remaining time excludes travel and is recalculated from build speed. Advanced Tools accelerates both repair and construction.

Cancel an unfinished structure for 100% of its unbuilt portion plus 50% of its built portion. For progress p, refund = cost × (1 − 0.5p), rounded down independently per resource. Destruction returns nothing. Completed buildings cannot be sold in the first version.

Split engineer **Build**, **Repair**, and **Barricade** into explicit actions. Repair must not accidentally buy a barricade. Repairs are targeted, stop at full health, and show their resource policy before activation.

## 5. Planned camps and troop access

Camps are specialized military production/support sites, reusing the existing troop roster. They do not create income by themselves. Captured territory remains the source of economic growth.

| Site | Role / available troops | Prerequisite | Proposed cost: manpower / fuel | Work time |
|---|---|---|---|---|
| HQ | Engineers; main retreat and reinforcement destination | Starting structure | Starting structure | — |
| Infantry Camp | Riflemen, machine guns, anti-tank squads | HQ | 150 / 0 | 15 sec |
| Support Camp | Mortars, AT guns, anti-air vehicles | Infantry Camp | 180 / 20 | 20 sec |
| Vehicle Camp | Scout cars; battle tanks and flame tanks after Heavy Workshop upgrade | Infantry Camp | 220 / 45 | 25 sec |
| Aviation Camp | Transport helicopters; attack helicopters after Armament Bay upgrade | Vehicle Camp | 250 / 65 | 30 sec |
| Forward Camp | Local paid infantry reinforcement; optional retreat destination; no unit production | Infantry Camp; owned sector | 160 / 10 | 18 sec |
| Defensive Emplacement | Fixed ground fire with directional coverage; vulnerable to flank, mortar, and flame attacks | Infantry Camp | 120 / 10 | 15 sec |
| Barricade | Directional infantry cover | Engineers | 45 / 0 | 6 sec |

Proposed camp upgrades: **Heavy Workshop**, 120 manpower / 40 fuel / 20 sec; **Armament Bay**, 120 manpower / 35 fuel / 20 sec. These belong to an individual camp and unlock its advanced roster. Unit upgrades remain individual purchases and survive loss of the production camp.

Retain existing unit prices initially. Show each troop's role, strong/weak matchups, producer, cost, training time, and any camp upgrade requirement in its recruitment card. Do not add more combat unit types until the existing roster has clear roles.

Every completed production camp has its own FIFO queue and rally point. Duplicate camps provide additional production capacity at additional cost. Cap forward camps at two per faction initially; tune other building limits through playtesting.

Selecting a camp opens its health, state, roster, queue, rally action, and local upgrades in the bottom panel. Training cannot start in unfinished, destroyed, or missing-prerequisite camps. If a prerequisite is lost after training starts, that paid order can finish at its surviving producer; future orders remain locked until the prerequisite returns.

Unstarted training orders can be cancelled for a full refund. Cancelling an in-progress order returns 75% of its cost. Destroying its producer loses the active order without refund and refunds unstarted orders in full; it never spawns units at a dead camp or silently transfers orders. Show the loss and refunds in the resource log.

Forward Camps reinforce friendly infantry within 160 world pixels at the documented manpower rate. They cannot train replacements, repair aircraft, or create free units. Enemy ground units within that radius contest the camp and pause reinforcement. A retreat destination must be completed, friendly, uncontested, and reachable; fall back to HQ if it becomes invalid.

## 6. Planned resource UI: explain every cost

The player should always be able to answer: **What do I own, how fast am I earning it, what just spent it, and what will this action cost?**

### Persistent top bar

Show separate resource blocks with a distinct symbol, full name, available balance, and signed net income per minute. Keep tickets visually separate. Use labels and symbols as well as color.

Example layout:

```text
MANPOWER  340   +240/min       FUEL  85   +30/min
AZURE 420   •   CRIMSON 365    VP CONTROL 2–1   Enemy −84 tickets/min
```

These numbers illustrate presentation, not starting values. Income uses the actual economy: manpower starts at +90/min, with +210/min per manpower sector; fuel starts at +30/min, with +150/min per oil well. Ticket drain is shown only for the side currently losing tickets.

Hover or focus a resource to see gross income by source, active recurring expenses, net rate, and money already spent on queued orders. Queue commitments are historical allocation information, not a second deduction from the available balance. Show short-lived expenses such as healing as “Reinforcement spending now: −X/min”; do not count one-time purchases as permanent upkeep.

### Build, train, upgrade, and repair cards

Every spending action shows full resource names, exact cost, duration or rate, and result. Zero fuel costs remain visible as `0 Fuel` where comparison helps. Affordable and missing amounts are shown per resource; for example, `Fuel: 20 / 45 — need 25 more`.

Disabled cards explain **why**: insufficient resources, prerequisite missing, no engineer selected, invalid placement, camp incomplete, or producer destroyed. Hover/focus details remain available on disabled controls. Show a projected balance before confirmation: `After purchase: 190 Manpower / 40 Fuel`.

For queues, display producer name, active progress, waiting order, paid cost, cancel action, and exact refund preview. A placement ghost keeps its cost visible next to the cursor. Selecting a construction site displays invested cost and cancel refund.

### Spending feedback and recurring costs

Each successful transaction produces a short receipt, such as `−150 Manpower · Infantry Camp`, and enters a collapsible recent-transactions list. Refunds are positive entries with their reason. Rejected or cancelled placement creates no transaction. Purchasing once must generate exactly one debit.

HQ/Forward Camp panels expose **Auto-reinforce ON/OFF**. Show the current recovery price and estimated full recovery cost for selected units. Default ON preserves current retreat behavior; the player can stop spending immediately. Keep free engineer field repair as the initial rule and label it `0 resources · engineer time`; paid HQ recovery remains 0.35 manpower/HP until infantry and vehicle recovery are separated during balance work.

Use one economy transaction service for player and AI purchases, cancellations, refunds, and reinforcement. UI reads the same cost definitions as the simulation. All construction sites, units, and orders keep stable IDs so receipts and refunds identify the right purchase.

## 7. Recommended additions, in priority order

| Priority | Addition | Why it belongs next |
|---|---|---|
| P0 | Selectable buildings, per-building queues, cancellation/refunds, rally points | Makes camps functional and prevents lost or duplicated spending |
| P0 | Placement validation and ground navigation around building footprints | A builder system needs reachable sites and exits that cannot be blocked accidentally |
| P0 | Explicit engineer actions and persistent builder/site assignment | Makes construction and repair controllable and understandable |
| P0 | Resource income breakdown, transaction receipts, and recurring-spend toggles | Explains the new economic decisions rather than only displaying totals |
| P1 | Supply/population cap with visible per-unit weights | Prevents unlimited armies and gives manpower purchases an army-size constraint; tune after camp costs |
| P1 | Fog of war and visible scouting information | Gives scouts and helicopters a stronger information role; AI should use the same visibility rules |
| P1 | Separate reinforcement, infantry healing, vehicle repair, and aircraft servicing | Current aggregate HP recovery hides different logistical roles and costs |
| P1 | Short tutorial/objective prompts | Teach build → capture → recruit → counter → upgrade → retreat in a few minutes |
| Done | Reconcile camera and command hotkeys | Implemented settings and remapping; defaults now use A fire-in-range and X stop alongside arrow-key camera movement |
| P2 | Supply connections between owned sectors and HQ | Could make cutoffs and Forward Camps strategically meaningful; defer until basic camps are readable and fun |
| P2 | AI difficulty settings and match statistics | Support balance testing and explain losses through income, losses, upgrades, and sector control |
| P2 | Save/load and settings persistence | Useful once the longer infrastructure-driven match loop stabilizes |

Avoid adding factions, extra resource currencies, or more tank variants during this milestone. First establish distinct choices among the units already present. Supply connections are a later experiment, not a prerequisite for the first camp implementation.

### Settings scope

Implemented standard settings: master/music/effects volume, resolution, fullscreen/windowed mode, camera speed, zoom sensitivity, edge scrolling, and key rebinding. Settings save between sessions. Audio controls already adjust the Master, Music, and Effects buses; audio content remains to be added.

Accessibility options are excluded from the planned settings scope per the user's direction. Do not add a separate accessibility menu or accessibility-specific settings in this milestone.

## 8. Implementation plan and acceptance criteria

**Milestone 1 — Economy clarity:** introduce shared cost/transaction definitions; show balances, rates, cost previews, blocked reasons, and receipts; expose automatic recovery spending. Existing gameplay remains playable.

**Milestone 2 — Builder foundation:** add BuildingSpec resources, persistent building/site IDs, explicit engineer commands, placement ghosts, valid footprints, builder attendance, progress, pause/resume, cancellation, and refunds. Replace production-type queues with producer IDs and handle destruction before enabling camp expansion.

**Milestone 3 — Camp progression:** add the normal skirmish opening, camp-specific rosters, two local unlock upgrades, rally points, and Forward Camp reinforcement. Keep the full-roster sandbox. AI builds and spends under the same rules; it must obtain the same camps and unlocks before recruiting advanced units.

**Milestone 4 — Playtest:** check opening timings, infantry counters, air/armor timing, forward-camp vulnerability, economic readability, and movement congestion. Adjust numerical proposals using repeated played matches.

Acceptance checks:

- An invalid placement spends nothing; one valid placement creates one site and one debit.
- Builders travel to sites; leaving, suppression, death, and retreat pause work; replacement builders resume it.
- Footprints cannot overlap objectives/buildings, block required exits, or create unreachable work sites.
- Construction, cancellation, completion, and destruction each apply exactly one correct resource outcome.
- Every camp trains only its listed troops and enforces its prerequisites for both player and AI.
- Separate camps train concurrently; one camp preserves FIFO order; producer destruction never creates a phantom spawn.
- Every cost, refund, balance, rate, and disabled-state explanation agrees with the simulation.
- Reinforcement stops when disabled, contested, unaffordable, or complete; it never drives balances negative.
- Existing selection, orders, combat, upgrades, helicopters, transports, capture, and victory still function.
- A played builder-opening match and a reviewed 15–20 second capture demonstrate placement, building, recruitment, and understandable spending.

## 9. Scope boundaries

The new milestone covers builder gameplay, camp progression, and resource readability. Multiplayer, a campaign, individual soldier simulation, new factions, and additional combat rosters remain outside this milestone. Existing aggregate squads and geometric artwork can support this iteration.

The standard settings menu, contextual commander/base/unit panel, procedural previews, infantry-only cover commands, A fire-in-range defaults, and individual-producer queues are implemented. Builder, camp progression, and expanded resource UI rules remain planned. See README.md for running the current build, validation commands, architecture, and the asset manifest.

### A command clarification

A now stops selected units and engages valid enemies already in their weapon range, respecting targeting eligibility, firing arcs, setup, and reload. It does not ask for a destination or pursue targets outside range. Right-click remains the movement command. The internal saved action identifier is retained for compatibility with existing key bindings.
