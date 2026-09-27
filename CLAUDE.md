# Gym Wars — working agreement

## How changes are delivered to the owner (IMPORTANT)
The owner works in their own place in Roblox Studio (currently "GymWars (14)")
and does NOT swap place files or copy between Studio windows. Every change
must be delivered as **one command-bar paste**:

1. Make the change in `src/` (and `tools/map/` if the map changes), typecheck,
   build as usual (`lune run tools/build`) and commit/push.
2. Add every changed script to `FILES` in `tools/snippets/make_update.py`.
   Map/geometry changes must ALSO be written as live edits in that script's
   `code` block (the owner's place already has the old map; rebuilding it
   there is not an option). Keep it idempotent: safe to paste twice.
3. `python3 tools/snippets/make_update.py` -> `tools/snippets/update_command.lua`.
4. Test it offline: run the command with Lune against an older build
   (`git show <old-commit>:build/GymWars.rbxlx`), with a correct `CFrame.lookAt`
   injected (Lune's is broken for sloped directions), then run
   `tools/staircheck.luau` / `tools/navcheck.luau` on the patched place.
5. Send `update_command.lua` with SendUserFile and the same short steps:
   stop Play -> open file, Cmd+A, Cmd+C -> paste in the command bar -> Enter
   -> check Output for "GYM WARS UPDATED" -> Cmd+S -> Play.

Small tweaks can be a short one-liner pasted directly in chat instead
(still copy-paste ready, in a code block).
Never ask the owner to paste models between files, save .rbxm files, or open
a new build.

## Owner's place specifics
- Their Ronnie model lives in `ServerStorage.GoodRonnie`;
  `CharacterModels.Init()` picks it up by name. Don't rename/move it.
- `ServerScriptService.StudioMoney` (Studio-only cash) may exist; leave it.
- Conveyor preview: `Characters.PREVIEW = { "RonnieCurlman" }`.

## Tooling notes
- Map builder must use `Geo.lookAt`, never `CFrame.lookAt` (Lune bug).
- Lune has no `Part.Position`; use `part.CFrame.Position` in code that is
  tested offline.
