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
| **Map** | 390 × 940-stud linear field. The conveyor runs down a red-carpet boulevard (velvet ropes, gold trim, street lamps). **8 gym lots**, 4 per side, **220 studs apart** on big tree-filled lawns with park benches. Hedge walls, gates, a DROP tunnel where influencers appear, and an EXIT tunnel. |
| **Gyms** | **3-story glass fitness clubs** (76 × 64, 16-stud floors): dark frame, full-height glass on three sides, floor bands, a rooftop sign. Inside every floor: two tidy rows of 3 machines facing the glass, an aisle runner, a mirror wall with a dumbbell rack, a blue-striped stair-core wall with a floor sign, exposed ducts, and LED strip lighting (real SurfaceLights). The ground floor has the lobby, front desk and heavy bag. |
| **Floors = capacity** | Floor 1 (Cardio & Dumbbells) is free and gives 6 machines. **Floor 2 (Machines)** and **Floor 3 (Power Zone)** are bought in the Shop as the *Gym Floors* upgrade ($7,500 / $45,000) and add 6 machines each. A red gate blocks the stairs until that floor is bought. |
| **18 working stations per gym** | F1: 2 treadmills, spin bike, dumbbell curls, DB shoulder press, bench press. F2: lat pulldown, cable row, chin/dip assist, leg extension, spin bike, treadmill. F3: 2 squat racks, 2 deadlift platforms, 2 bench presses. |
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
