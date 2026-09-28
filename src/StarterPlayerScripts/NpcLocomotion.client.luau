--[[
	NpcLocomotion
	Walk / run / idle for every NPC (influencers, front desk), played on this
	client so it's smooth every frame (the server only moves them). Models are
	flagged by the server with the "Loco" attribute (false while working out).

	  - An animation pack for everyone, chosen with the workspace attribute
	    "NpcAnimPack" (Superhero by default; see PACKS). Change it any time,
	    even while playing, and every NPC switches. Or set your own clips with
	    NpcIdleAnim / NpcWalkAnim / NpcRunAnim (rbxassetid://...). If a pack
	    can't load, everyone falls back to Classic.
	  - "NpcArmSpread" attribute scales the swagger (1 = default, 0 = off)
	  - Walk/run blended and speed-matched to how fast they move
	  - Bodybuilder swagger: arms carried out from the body (more for bigger
	    rarities) so big arms don't clip through the lats and thighs
]]

local RunService = game:GetService("RunService")

local ContentProvider = game:GetService("ContentProvider")

-- Roblox's own animation packs (idle, walk, run)
local PACKS = {
	Classic = { 507766388, 507777826, 507767714 },
	Superhero = { 616111295, 616122287, 616117076 },
	Confident = { 1069977950, 1070017263, 1070001516 },
	Stylish = { 616136790, 616146177, 616140816 },
	Rthro = { 2510196951, 2510202577, 2510198475 },
	Knight = { 657595757, 657552124, 657564596 },
	Ninja = { 656117400, 656121766, 656118852 },
	Robot = { 616088211, 616095330, 616091570 },
	Toy = { 782841498, 782843345, 782842708 },
	Cartoony = { 742637544, 742640026, 742638842 },
	Mage = { 707742142, 707897309, 707861613 },
	Elder = { 845397899, 845403856, 845386501 },
	Werewolf = { 1083195517, 1083178339, 1083216690 },
}
local DEFAULT_PACK = "Superhero"

local CLIPS = nil -- { Idle, Walk, Run } asset ids in use (nil while resolving)

local function packIds(name)
	local p = PACKS[name] or PACKS[DEFAULT_PACK]
	local ids = { Idle = "rbxassetid://" .. p[1], Walk = "rbxassetid://" .. p[2], Run = "rbxassetid://" .. p[3] }
	-- custom clips override the pack
	for key, attr in pairs({ Idle = "NpcIdleAnim", Walk = "NpcWalkAnim", Run = "NpcRunAnim" }) do
		local custom = workspace:GetAttribute(attr)
		if type(custom) == "string" and custom ~= "" then
			ids[key] = custom:match("^rbxassetid://") and custom or ("rbxassetid://" .. custom)
		end
	end
	return ids
end

-- Preload the chosen clips once; if any fail, everyone uses Classic.
local function resolve()
	local name = workspace:GetAttribute("NpcAnimPack") or DEFAULT_PACK
	local ids = packIds(name)
	local anims, failed = {}, false
	for _, id in pairs(ids) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		table.insert(anims, a)
	end
	pcall(function()
		ContentProvider:PreloadAsync(anims, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then
				failed = true
			end
		end)
	end)
	if failed then
		warn(("[NpcLocomotion] animation pack '%s' didn't load, using Classic"):format(tostring(name)))
		local c = PACKS.Classic
		ids = { Idle = "rbxassetid://" .. c[1], Walk = "rbxassetid://" .. c[2], Run = "rbxassetid://" .. c[3] }
	else
		print(("[NpcLocomotion] animation pack: %s"):format(tostring(name)))
	end
	return ids
end

local rigs = {} -- [model] = state

local function loadSet(animator, ids)
	local tracks = {}
	for key, id in pairs(ids) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok or not track then
			return nil
		end
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Core
		tracks[key] = track
	end
	return tracks
end

local function stopAll(state)
	if state.Tracks then
		for _, t in pairs(state.Tracks) do
			t:Stop(0.25)
		end
	end
end

local function findJoint(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == name and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then
			return d
		end
	end
	return nil
end

-- returns true once the model is being animated (false = try again later)
local function track(model)
	if rigs[model] then
		return true
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then
		return false
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		-- a local Animator animates it on this screen just the same
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	if not CLIPS then
		return false -- still resolving the pack; the sweep will retry
	end
	local tracks = loadSet(animator, CLIPS)
	if not tracks then
		return false
	end
	local state = { Model = model, Humanoid = hum, Root = root, Weights = { 1, 0, 0 }, Tracks = tracks }
	rigs[model] = state
	state.LeftShoulder = findJoint(model, "LeftShoulder")
	state.RightShoulder = findJoint(model, "RightShoulder")
	-- arms out a little for regular guys, a lot for the mass monsters
	local rarity = model:GetAttribute("Rarity") or 1
	state.Spread = math.rad(4 + 2 * rarity)
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
	return true
end

-- Pick up every NPC: on spawn, and in a sweep every second (so a model
-- whose parts or flag arrive late is never missed).
local function consider(inst)
	if inst:IsA("Model") and inst:GetAttribute("Loco") ~= nil and not rigs[inst] then
		track(inst)
	end
end

-- influencers live in workspace.Influencers, front-desk staff in each plot
local function sweep()
	local folder = workspace:FindFirstChild("Influencers")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			consider(m)
		end
	end
	local map = workspace:FindFirstChild("GymWarsMap")
	local plots = map and map:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			for _, m in ipairs(plot:GetChildren()) do
				if m:IsA("Model") then
					consider(m)
				end
			end
		end
	end
end

-- load (or reload) the pack, then (re)apply it to every NPC
local function applyPack()
	CLIPS = nil
	local ids = resolve()
	for model, state in pairs(rigs) do
		stopAll(state)
		for _, t in pairs(state.Tracks or {}) do
			t:Destroy()
		end
		rigs[model] = nil
	end
	CLIPS = ids
	sweep()
end
task.spawn(applyPack)
for _, attr in ipairs({ "NpcAnimPack", "NpcIdleAnim", "NpcWalkAnim", "NpcRunAnim" }) do
	workspace:GetAttributeChangedSignal(attr):Connect(function()
		task.spawn(applyPack)
	end)
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		task.defer(consider, d)
	elseif d:IsA("Humanoid") and d.Parent then
		task.defer(consider, d.Parent)
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		sweep()
	end
end)

-- Blend walk/run by ground speed (mirrors Roblox's Animate script)
RunService.Heartbeat:Connect(function(dt)
	for model, state in pairs(rigs) do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local tracks = state.Tracks
		if not tracks then
			continue
		end
		local active = model:GetAttribute("Loco") ~= false and not state.Root.Anchored
		if not active then
			if state.Playing then
				stopAll(state)
				state.Playing = false
			end
			continue
		end
		if not state.Playing then
			for _, t in pairs(tracks) do
				t:Play(0.25, 0.001, 1)
			end
			state.Playing = true
		end
		local v = state.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local speed = v.Magnitude
		local heightScale = math.max(state.Humanoid.HipHeight / 2, 0.5)
		local rs = speed * 1.25 / 16 / heightScale
		local wIdle, wWalk, wRun, warp = 0, 0, 0, 1
		if speed < 0.6 then
			wIdle = 1
		elseif rs <= 0.5 then
			wWalk, warp = 1, rs / 0.5
		elseif rs < 1 then
			local f = (rs - 0.5) / 0.5
			wWalk, wRun = 1 - f, f
		else
			wRun, warp = 1, rs
		end
		local k = math.clamp(dt * 8, 0, 1)
		local w = state.Weights
		w[1] += (wIdle - w[1]) * k
		w[2] += (wWalk - w[2]) * k
		w[3] += (wRun - w[3]) * k
		tracks.Idle:AdjustWeight(math.max(w[1], 0.001), 0.1)
		tracks.Walk:AdjustWeight(math.max(w[2], 0.001), 0.1)
		tracks.Run:AdjustWeight(math.max(w[3], 0.001), 0.1)
		tracks.Idle:AdjustSpeed(model:GetAttribute("IdleSpeed") or 1)
		tracks.Walk:AdjustSpeed(math.max(warp, 0.1))
		tracks.Run:AdjustSpeed(math.max(warp, 0.1))
	end
end)

-- Swagger layer: after the Animator has posed the rig, carry the arms out.
RunService.PreSimulation:Connect(function()
	for model, state in pairs(rigs) do
		if state.Playing and model:GetAttribute("Loco") ~= false then
			local a = state.Spread * (workspace:GetAttribute("NpcArmSpread") or 1)
			if state.LeftShoulder then
				state.LeftShoulder.Transform = state.LeftShoulder.Transform * CFrame.Angles(0, 0, -a)
			end
			if state.RightShoulder then
				state.RightShoulder.Transform = state.RightShoulder.Transform * CFrame.Angles(0, 0, a)
			end
		end
	end
end)
