# GYM WARS — Complete Game Overview (for an AI assistant)

This document explains the Roblox game **Gym Wars** in full detail so another
AI (e.g. ChatGPT) can understand it, help design characters, balance the
economy, write prompts, or brainstorm features. Everything here reflects the
actual current code.

---

## 1. Elevator pitch

Gym Wars is a Roblox tycoon / collector game in the style of **"Steal a
Brainrot"**, but themed around gym culture. Instead of brainrot memes, the
collectibles are **parody bodybuilders and fitness influencers** (e.g.
"Ronnie Curlman", inspired by Ronnie Coleman).

- Influencers **walk out of a teleporter gate** in the wall and stroll down a
  long **red carpet** in a straight line across the map.
- Players **buy** the ones they want as they walk past.
- A bought influencer **walks by itself to the buyer's gym**, climbs the stairs
  if needed, gets on a **gym machine**, and **works out with real animations**
  while earning the owner **passive cash every second**.
- Players can **steal** influencers out of other players' gyms. The victim's
  **front desk worker** NPC chases the stolen influencer and the thief.
- Players upgrade their **3-story gym**, buy **gym clothing**, use **boosters**,
  train their own **Strength**, and **rebirth** for permanent multipliers.

## 2. Core loop

1. Spawn in → get assigned one of 8 gyms (plots). Start with **$100**.
2. Watch the red carpet. Influencers spawn every **3.5 s** (max 20 on the
   carpet at once), walking at WalkSpeed 7 from the south gate to the north gate.
3. Walk up to one, press the ProximityPrompt **"Buy $X"**.
4. It walks to a free machine in your gym and starts earning.
5. Use the cash to buy better influencers, more gym floors (more machines),
   clothing, equipment upgrades and boosters.
6. Steal from others / defend your own gym.
7. Hit the rebirth threshold → rebirth for a permanent income multiplier.

Anything that reaches the north gate without being bought walks into it
and disappears.

## 3. The map

- Square world bounded by **tall walls (30 studs)** on all sides. Ground is
  **grass**, plus the **red carpet** (no concrete anywhere).
- **Red carpet** runs the full length of the map down the middle (south wall
  to north wall), along X = 0.
- **Two wall teleporter gates**, built into the end walls (minimalist/modern,
  matte with a light bar that scans up and down):
  - **South gate — "INFLUENCER DROP"** (blue accent): influencers walk out of it.
  - **North gate — "LAST CHANCE"** (red accent): unbought influencers walk into it and vanish.
- **Drop Clock board** set into the wall above the drop gate (matte black
  panel, two rows of text): `LEGENDARY 4:32` (word colored gold #FFB02E) and
  `MYTHIC 12:10` (word colored pink #FF3878). Only the word is colored, and
  colors never animate. **There is no on-screen HUD clock** — on purpose.
- **8 gyms**, 4 on each side of the carpet, set back from it (lots at X = ±118).
  Each gym is 56 × 72 studs, up to **3 floors** (16 studs per floor), with a
  sign, a front desk, a personal workout station (heavy bag) for the owner,
  stairs with landings, and a roof that moves up as floors are added.
- NPCs use **fixed walking routes** inside the gyms (yard → door → lobby →
  center aisle → stair foot → landings → next floor → machine) so they always
  use the stairs correctly instead of getting stuck.

## 4. Gym machines (stations)

Every gym has 3 of each machine:

| Floor | Cost | Slots | Machines |
|---|---|---|---|
| 1 | free | 1–12 | Treadmill, Bike, Dumbbell Curl, Shoulder Press |
| 2 | $7,500 | 13–24 | Lat Pulldown, Cable Row, Leg Extension, Pull-Up |
| 3 | $45,000 | 25–33 | Squat, Deadlift, Bench Press |

So max **12 / 24 / 33 influencers** per gym. Influencers use the machines with
procedural animation (hands on bars, feet on pedals, dumbbells in hands, etc.).
Equipment is built at 1.25× real scale so it reads well in Roblox.

## 5. Characters (the collectibles)

### 5.1 Rarities

7 rarities. Odds = percent of all spawns:

| Rarity | Odds | Visual tier |
|---|---|---|
| Common | 70% | gray |
| Uncommon | 22% | green |
| Rare | 6% | blue, outline |
| Epic | 1.6% | purple, outline, aura |
| Legendary | 0.32% | gold, aura, chat announcement |
| Mythic | 0.075% | pink/red, bigger effects |
| G.O.A.T. | 0.005% | the ultimate tier |

Spawn: roll a rarity, then pick a character in that rarity by its
**SpawnWeight** (relative inside that rarity).

**Guaranteed drops (like Steal a Brainrot):** a **Legendary every 5 minutes**
and a **Mythic every 15 minutes** are forced onto the carpet. The wall clock
counts down to them.

### 5.2 Parody rule (strict)

All characters are **parody-inspired Roblox versions, not replicas**: parody
pun names, no real influencer logos, tattoos, copyrighted clothing designs or
branded merch. They are muscular, stylized, slightly exaggerated bodybuilders.

### 5.3 Full roster (40 characters)

Price = cost to buy. Income = cash per second while working out.

| # | Name | Inspired by | Rarity | Price | Income/s |
|---|---|---|---|---|---|
| 1 | Joe Flexer | Joe Fazer | Common | 75 | 1 |
| 2 | Brownie Bulk | Browney | Common | 325 | 5 |
| 3 | Sean Naliftanyj | Sean Nalewanyj | Common | 1.1K | 18 |
| 4 | Omar Iswole | Omar Isuf | Common | 4.25K | 55 |
| 5 | Zac Pumperna | Zac Perna | Common | 13.5K | 130 |
| 6 | Will Tension | Will Tennyson | Uncommon | 28K | 240 |
| 7 | Alex Eubanked | Alex Eubank | Uncommon | 72K | 650 |
| 8 | Jesse Gains West | Jesse James West | Uncommon | 190K | 1.4K |
| 9 | Lexx Large | Lexx Little | Uncommon | 390K | 4K |
| 10 | MattDoesGains | MattDoesFitness | Uncommon | 1.25M | 8.5K |
| 11 | Christian Gainzman | Christian Guzman | Uncommon | 2.8M | 16K |
| 12 | Sam Swolek | Sam Sulek | Uncommon | 7.5M | 55K |
| 13 | Jeff Rippedard | Jeff Nippard | Rare | 18M | 95K |
| 14 | Dr. Mike Gains | Mike Israetel | Rare | 42M | 250K |
| 15 | David Lifted | David Laid | Rare | 95M | 900K |
| 16 | Joey Swollen | Joey Swoll | Rare | 210M | 1.45M |
| 17 | Noel Diesel | Noel Deyzel | Rare | 425M | 4.5M |
| 18 | Bradley Barbell | Bradley Martyn | Rare | 1.2B | 7.5M |
| 19 | Mike O'Gain | Mike O'Hearn | Rare | 2.75B | 22M |
| 20 | Greg Hugecette | Greg Doucette | Epic | 6B | 35M |
| 21 | Ramon Dyno | Ramon Dino | Epic | 11B | 85M |
| 22 | Andrew Jacked Up | Andrew Jacked | Epic | 27B | 145M |
| 23 | Urs Calvesinski | Urs Kalecinski | Epic | 55B | 310M |
| 24 | Eddie Haul | Eddie Hall | Epic | 95B | 450M |
| 25 | Nick Hulker | Nick Walker | Epic | 175B | 800M |
| 26 | Halfthor Boulderson | Hafthor Bjornsson | Epic | 310B | 1.05B |
| 27 | Big Rammy | Big Ramy | Legendary | 480B | 1.15B |
| 28 | Dexter Jackedson | Dexter Jackson | Legendary | 625B | 1.35B |
| 29 | Larry Steels | Larry Wheels | Legendary | 825B | 1.75B |
| 30 | Kevin LeSwole | Kevin Levrone | Legendary | 1.05T | 1.9B |
| 31 | Kai Gains | Kai Greene | Legendary | 1.45T | 2.2B |
| 32 | Dorian Weights | Dorian Yates | Legendary | 1.8T | 2.05B |
| 33 | Phil Beef | Phil Heath | Legendary | 2.4T | 2.45B |
| 34 | Tom Squatz | Tom Platz | Mythic | 3.25T | 2.55B |
| 35 | Flex Wheelie | Flex Wheeler | Mythic | 4.5T | 2.8B |
| 36 | Frank Gain | Frank Zane | Mythic | 6.25T | 2.7B |
| 37 | C-Bulk | Chris Bumstead | Mythic | 8.5T | 3.05B |
| 38 | Jay Cuttler | Jay Cutler | G.O.A.T. | 12T | 3.1B |
| 39 | Ronnie Curlman | Ronnie Coleman | G.O.A.T. | 20T | 3.35B |
| 40 | Arnie Ironberg | Arnold Schwarzenegger | G.O.A.T. | 35T | 3.5B |

Numbers are shown short form: 1K, 1M, 1B, 1T, 1Qa…
A **Mutations** system (Gold ×1.5, Diamond ×2, Radioactive ×3, Galaxy ×5,
Secret ×10) is built into the data but switched off for now.

### 5.4 Only characters with a real 3D model spawn

The game is set to **only spawn characters that have a real 3D model in the
place**. A character with no model never walks the carpet. This lets the roster
grow one model at a time. The first finished model is **Ronnie Curlman** (in
the place as `GoodRonnie`). The 5 Commons have been generated and are being
added next.

## 6. How characters are made (Meshy pipeline)

1. **Concept image:** one simple full-body front-view image per character, in
   the same style as the Ronnie Curlman model: stylized, muscular, Roblox-
   friendly, standing in an A-pose/T-pose, plain background. About **50% are
   shirtless** to show off the physique. Each one must look clearly different
   (body type, hair, skin tone, outfit colors, accessories) and stay a parody
   (no logos/tattoos/brands). Prompts must be **short**.
2. **Meshy AI:** image → 3D model, then rig/animate it, export **FBX**. (If
   Roblox's Auto Setup fails, remesh to about 10k polygons first.)
3. **Roblox Studio:** import the FBX, run **Avatar → Auto Setup** to get an R15
   rig, and **name the model after the character** (e.g. `JoeFlexer`,
   `ZacPumperna`). The game finds it by name automatically.
   - A full R15 rig (15 body parts + Humanoid) fully animates: walk, run,
     workouts.
   - An unrigged mesh still works but rides as a statue on an invisible rig.
4. Per-character fine-tuning is possible, e.g. `GripOffset` (where the
   dumbbells sit in the hands) and `ModelYaw` (which way the model faces).

## 7. NPC animation

- **Walk/run/idle** play on each player's client so they look smooth. They
  blend by speed and use a switchable **Roblox animation pack** (Superhero by
  default; Classic, Confident, Stylish, Rthro, Knight, Ninja, Robot, Toy,
  Cartoony, Mage, Elder and Werewolf are also available). A "bodybuilder
  swagger" keeps the arms out from the body so big arms don't clip.
- **Workouts** are procedural (IK solver): each machine has its own exercise
  motion (curls, presses, rows, squats, treadmill running, cycling…).
- When an influencer is bought on the carpet, it plays a short celebration/flex.

## 8. Buying, stealing and defense

**Influencer states:** OnBelt → Seating (walking to the buyer's machine; the
machine is reserved) → Placed (working out, earning) → Stolen → Returning,
plus Dropped (unowned, standing around, leaves later).

- **Buy:** ProximityPrompt "Buy $X" on carpet influencers. Anyone can buy.
- **Steal:** in someone else's gym, the prompt on a placed influencer reads
  **"Steal"**. The influencer leaves and walks toward a free machine in the
  thief's gym.
- **Front Desk Worker:** each gym has one R15 staff NPC. When a theft starts, it
  chases the stolen influencer anywhere on the map. If it catches them (within
  4.5 studs), the influencer walks back to its original machine, and a nearby
  thief gets **knocked down and stunned for 2 s**. If the influencer reaches the
  thief's machine first, the thief owns it.
- The desk worker's speed is upgradeable (see Equipment).

## 9. Economy and progression

**Income per second** = sum of placed influencers' income
× clothing multiplier (1 + sum of equipped clothing bonuses)
× rebirth multiplier × active boosters.

**Equipment upgrades (levels 1–5):**
- Gym Floors: 1 → 2 → 3 floors (12/24/33 machines), costs $0 / $7.5K / $45K.
- Workout Gain (Strength per rep): 1 / 2 / 4 / 8 / 16.
- Desk Speed (front desk worker speed): 18 / 21 / 24 / 28 / 34.

**Boosters:**
- Protein Shake — ×1.5 income for 5 min — $250.
- Creatine — 2× workout speed — $600.
- Steroids — ×3 income for 5 min — $2,000.

**Strength (personal, permanent):** the owner punches the heavy bag in their gym
(owner only). Each rep gives BaseGain 1 × Workout Gain, with a 0.6 s cooldown.
Strength unlocks the *right to buy* clothing; cash is still needed.

**Clothing (one per slot, each adds to the income multiplier):**

| Item | Slot | Strength needed | Price | Bonus |
|---|---|---|---|---|
| Gray Tee | Top | 0 | 100 | +10% |
| Tank Top | Top | 50 | 500 | +25% |
| Stringer | Top | 200 | 2.5K | +50% |
| Pump Cover | Top | 600 | 10K | +100% |
| Gym Shorts | Bottom | 25 | 300 | +15% |
| Joggers | Bottom | 150 | 2K | +40% |
| Compression Tights | Bottom | 500 | 8K | +80% |
| Wrist Wraps | Accessory | 75 | 800 | +20% |
| Lifting Belt | Accessory | 300 | 4K | +60% |
| Gold Chain | Accessory | 1000 | 25K | +150% |

**Rebirth:** threshold = 10,000 × 2^(number of rebirths). Multiplier =
1 + 9 × (1 − 0.93^n), which approaches ×10. Rebirthing resets **Cash and placed
influencers**. It keeps Strength, Rebirths, owned clothing, equipment levels
and gym color.

**Gym colors:** 8 color presets (e.g. Gold) for walls and accents.

**Saving:** Roblox DataStore `GymWars_v1`.

## 10. Design rules (always follow these)

1. **Parody only:** no real logos, tattoos, copyrighted clothing or merch.
2. **No color-changing effects** anywhere (no rainbow, tint-cycling or flashing colors).
3. **No on-screen HUD clocks.** The drop timers live only on the wall board.
4. Keep the "Steal a Brainrot" feel: a straight walking line on the carpet,
   gates in the walls, guaranteed rare drops on a timer.
5. Visual style: clean, minimalist and modern for the world. The characters
   are big, stylized, exaggerated bodybuilders.

## 11. Technical setup (for code-related help)

- Written in **Luau**. The source lives in a git repo (Rojo-style `src/`
  layout), with a map builder in `tools/map/`, and is built into a `.rbxlx`
  with Lune.
- Key server modules: `BeltService` (spawning, carpet walking, guaranteed
  drops), `InfluencerService` (states, buy/steal), `DefenseService` (front
  desk), `EconomyService`, `ShopService`, `WorkoutService`, `PlotService`,
  `PlayerDataService`, `NpcService`, `GymNav` (routes), `CharacterModels` /
  `CharacterLooks` (finding and attaching 3D models).
- Shared modules: `Characters` (the single source of truth for the roster,
  rarities and odds), `Constants` (economy), `Gym/StationSpecs`,
  `Gym/Exercises`, `Gym/RigSolver`.
- Client scripts: `NpcLocomotion` (walk/run anims), `GymAnimator` (workouts),
  `DropClocks`, `PortalFx`, `CharacterEffects`, `GymWarsClient` (UI).
- **Update workflow:** the owner works in their own Studio place. Every change
  is delivered as **one script pasted into the Studio command bar** that
  updates the scripts and map in place. Nobody swaps place files or copies
  models between files.

## 12. Current status / next steps

- Ronnie Curlman is live as the first real model. The 5 Commons (Joe Flexer,
  Brownie Bulk, Sean Naliftanyj, Omar Iswole, Zac Pumperna) are made in Meshy
  and are being imported.
- Goal: **20–30 Meshy characters** to start, working up the rarity ladder.
- Polishing: walk-animation pack choice, workout animation quality, and
  per-character grip fixes (e.g. Zac's dumbbells).
