# Gym Wars

Roblox game: claim influencers off a red-carpet conveyor, lead them to your gym,
and they train on real, working equipment to earn you Cash. Steal from other
gyms, and dodge their front desk.

**Open `build/GymWars.rbxlx` in Roblox Studio.** For the best look, turn on
*Game Settings → Security → Enable Studio Access to API Services* so saving works,
and play-test with **Graphics Quality 8+**. Future lighting is enabled.

## What's in the place

| Area | What it is |
|---|---|
| **Map** | Compact: a 264 × 356-stud grass field, **8 slim gyms** (4 per side) 76 studs apart along a red-carpet conveyor fed by a single drop tunnel, with front doors 20 studs from the carpet. Layered broadleaf and pine trees, bushes, rocks, stone walls with hedges, curbed walkways, modern street lamps and dynamic clouds. Lighting uses Future + the *Realistic* lighting style with tuned atmosphere, bloom, color grading and subtle depth of field. |
| **Gyms** | Slim glass fitness clubs that **grow a story each time you buy a floor** (56 wide × 72 deep, 16-stud floors), with a **U-shaped corner staircase** (open wood treads, black steel stringers, cable railings, a landing halfway up): dark frame, full-height glass, floor bands, a rooftop sign that rides up to the newest roof. The front door lines up with a **clear center aisle** straight to the back wall, and a cross aisle leads to the stairs. Each floor has a mirror wall with dumbbell racks and a floor sign, ducts, and LED strip lighting. |
| **Floors = capacity** | Floor 1 (Cardio & Dumbbells, 12 machines) is free. **Floor 2 (Machines, +12)** and **Floor 3 (Power Zone, +9)** are the *Gym Floors* shop upgrade ($7,500 / $45,000). Unbought floors, and the stairs up to them, don't exist in the world: they wait in `ServerStorage.HiddenGymFloors` until bought. |
| **3 of each machine (33 per gym)** | Groups of 3 side by side. F1: treadmills, spin bikes, dumbbell-curl stations, DB shoulder press. F2: lat pulldowns, cable rows, leg extensions, chin/dip assist. F3: squat racks, deadlift platforms, bench presses. |
| **Big equipment** | Machines are built 1.25× real proportions (`StationSpecs.SCALE`), and influencers are scaled to match. |
| **Rarer = heavier** | Rarity sets the load: bars carry 1 (Common) to 5 (Legendary) colored bumper plates per side, dumbbells grow extra plates, and more of each weight stack gets lifted. Heavier lifters do fewer, slower, grindier reps with visible bar shake, and rest longer. |
| **Influencers** | Real R15 avatars (`CreateHumanoidModelFromDescriptionAsync`), dressed in their rarity color, bulkier at higher rarities, sparkles on Epic and Legendary. They ride the conveyor physically and do emotes (wave, cheer, dance). |
| **Claiming** | Hold **E** on one. They hop off the belt and **walk behind you at 11 speed while you move at 18**, pathfinding around walls. Once they step inside your gym, they walk to the next open machine and start training. Press **X** to let go. |
| **Stealing** | Lure a training influencer out of someone else's gym. That gym's front desk worker (a real R15 NPC) runs after you and pathfinds anywhere on the map. If you're caught, you get tackled and the influencer walks back to its machine. |

## How the realistic motion works

Motion is procedural and runs on every client, with no uploaded animation assets:

* **`RigSolver`** does forward kinematics plus analytic two-bone IK on the R15
  joints, in world space. The equipment drives the body: the bar moves and the
  hands stay locked to it, the pedals turn and the feet stay on them, the belt
  runs and the feet plant on it during stance. It supports both `Motor6D` rigs
  and the new Avatar Joint Upgrade `AnimationConstraint` rigs.
* **`Exercises`** builds each workout the way a real set goes: setup and
  unrack, then reps with realistic tempo (fast lift, slower controlled
  lowering, pauses at top and bottom), then rerack, then rest. Rest is
  breathing, looking around, and hands on hips or thighs. The last reps grind
  slower (fatigue). Each athlete gets a seeded variation in rep count, tempo,
  rest length and gaze.
* The **equipment moves with the athlete**: weight stacks rise with cable
  travel, cables stretch between pulleys and handles, the leg-extension lever
  rotates with the shin, the adjustable back pad fits each body, the assist
  pad follows the knees, the crank, flywheel and pedals spin, and treadmill
  slats scroll at belt speed.
* Everything is a pure function of `workspace:GetServerTimeNow()`, so every
  player sees the same rep with zero network traffic. Joint transforms are
  written in `RunService.PreSimulation`, which runs after the Animator, so
  procedural poses win. Poses blend in over 0.9 s when an athlete hops on.
* Walking, running and idle use Roblox's own default R15 animations, blended
  by ground speed the same way the default Animate script does it.

`tools/posecheck.luau` + `tools/render_pose.py` render any exercise offline
(side, front, top and 3/4 views) so you can tune poses without Studio.

## Tuning

Everything lives in `src/ReplicatedStorage/Modules/Constants.luau`:
`NPC.FollowSpeed` (escort pace), `BELT.Speed/SpawnInterval/MaxOnBelt`,
rarities, prices, floor costs (`EQUIPMENT.Floors`) and so on. To give an influencer a real Roblox avatar, add it
to `Constants.INFLUENCER_AVATARS` (`["Joey Swool"] = <UserId>`). Equipment
dimensions are in `Gym/StationSpecs.luau`. Both the map builder and the
animations read them, so machines and bodies always line up.

## Building the place from source

```
lune run tools/build          # -> build/GymWars.rbxlx
```

The build starts from `base/GymWars_original.rbxlx` (the original place),
replaces the map with the generated one (`tools/map/`), and syncs every script
from `src/`. It needs [Lune](https://github.com/lune-org/lune) 0.10+.

Type-check: `python3 tools/sourcemap.py && luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src/`

## Research notes

* **Procedural animation:** set `Motor6D.Transform` / `AnimationConstraint.Transform`
  during `RunService.PreSimulation`. The Animator overwrites transforms each frame
  only while tracks are playing, and does so before PreSimulation.
  ([Roblox creator-docs: Motor6D](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Motor6D.yaml),
  [AnimationConstraint](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/AnimationConstraint.yaml),
  [DevForum: Animation overriding Motor6D.Transform](https://devforum.roblox.com/t/animation-overriding-motor6dtransform/3630180))
* **Avatar Joint Upgrade:** new experiences get `AnimationConstraint` joints
  instead of Motor6D. C0/C1 become read-only aliases of the attachments.
  Evaluate procedural animation on the client and sync through attributes,
  which is exactly what `GymAnimator` does.
* **R15 NPC rigs:** `Players:CreateHumanoidModelFromDescriptionAsync` adds an
  `Animate` LocalScript, which doesn't run on NPCs, so we remove it and drive an
  `Animator` from the server.
  ([DevForum: CreateHumanoidModelFromDescription models don't animate](https://devforum.roblox.com/t/create-humanoid-model-from-description-models-dont-play-their-animations-why/2153001))
* **Default R15 animation IDs** (idle 507766388, walk 507777826, run 507767714)
  ([DevForum list](https://devforum.roblox.com/t/list-of-the-default-r15-animation-ids/140425)).
* **Realistic interiors in Roblox:** Future lighting with real
  SurfaceLights/SpotLights, PBR-ish built-in materials (Rubber, Leather, Plaster,
  Foil, Carpet, WoodPlanks, DiamondPlate), Atmosphere, Bloom and ColorCorrection,
  real-world proportions (1 m ≈ 3 studs for a 5.5-stud avatar), and dense set
  dressing. For even more fidelity, swap equipment for MeshParts with
  SurfaceAppearance (PBR textures) using the same part names and Moving/Cables
  structure.
