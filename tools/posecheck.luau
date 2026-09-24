--[[
	Pose check: builds each station + a block rig offline, runs the exercise at
	a few moments, and dumps every part (rig + equipment) to JSON so a render
	script can draw them. Usage: lune run tools/posecheck <Exercise> [times...]
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local loader = require("./lib/loader")
local R = loader.roblox
local CFrame, Vector3 = R.CFrame, R.Vector3

local Stations = loader.require("tools/map/Stations")
local Specs = loader.require("src/ReplicatedStorage/Modules/Gym/StationSpecs")
local RigSolver = loader.require("src/ReplicatedStorage/Modules/Gym/RigSolver")
local Exercises = loader.require("src/ReplicatedStorage/Modules/Gym/Exercises")
local BlockRig = loader.require("src/ReplicatedStorage/Modules/Gym/BlockRig")

local kind = process.args[1] or "BenchPress"
local times = {}
for i = 2, #process.args do
	table.insert(times, tonumber(process.args[i]))
end
if #times == 0 then
	times = { 0.5, 2, 4, 6 }
end

local folder = R.Instance.new("Folder")
local baseCF = CFrame.new(0, 0, 0)
local st = Stations.Build(kind, 1, folder, baseCF)

local rig = BlockRig.Build({ Shirt = R.Color3.fromRGB(220, 60, 60), Pants = R.Color3.fromRGB(60, 90, 220), Skin = R.Color3.fromRGB(250, 205, 160), Scale = Specs.SCALE })
rig.Parent = folder
local hrp = rig.HumanoidRootPart
local riderCF = st.Rider.CFrame
local solver = RigSolver.new(rig)
solver:setRootCFrame(riderCF)

local S = { Base = st.Base.CFrame, Spec = Specs[kind], RestLocal = {} }
for _, m in ipairs(st.Moving:GetChildren()) do
	S.RestLocal[m.Name] = S.Base:ToObjectSpace(m.PrimaryPart.CFrame)
end
local P = Exercises.Params(tonumber(process.env.SEED or "7"), tonumber(process.env.RARITY or "5"))
P.Offset = 0

local function dumpPart(p, cf, list, tag)
	local c = cf or p.CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
	table.insert(list, {
		n = p.Name, tag = tag,
		cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
		s = { p.Size.X, p.Size.Y, p.Size.Z },
		c = { p.Color.R, p.Color.G, p.Color.B },
		t = p.Transparency,
		shape = tostring(p.Shape),
	})
end

local frames = {}
for _, t in ipairs(times) do
	solver:reset()
	local ok, e = pcall(Exercises[kind], solver, S, t, P)
	if not ok then
		error(kind .. " failed at t=" .. t .. ": " .. tostring(e))
	end
	local W = solver:solve()
	local list = {}
	-- equipment: static + moved
	local movedGroups = {}
	for name, cf in pairs(e.Moves) do
		movedGroups[name] = cf
	end
	for _, d in ipairs(st:GetDescendants()) do
		local tier = d:GetAttribute("Tier")
		local order = d:GetAttribute("StackOrder")
		if d:IsA("BasePart") and (d.Transparency < 1 or tier) and not (tier and tier > P.Rarity) then
			local group = d.Parent and d.Parent.Parent == st.Moving and d.Parent or nil
			local cf = nil
			if group and movedGroups[group.Name] and not (order and order > 2 + 2 * P.Rarity) then
				local rel = group.PrimaryPart.CFrame:ToObjectSpace(d.CFrame)
				cf = movedGroups[group.Name] * rel
			end
			if d.Parent == st.Cables and e.Cables[d.Name] then
				local a, b = e.Cables[d.Name][1], e.Cables[d.Name][2]
				local mid = (a + b) / 2
				local dir = (b - a).Unit
				local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
				local zz = dir:Cross(up).Unit
				cf = CFrame.fromMatrix(mid, dir, zz:Cross(dir).Unit, zz)
				local copy = { Name = d.Name, Size = Vector3.new((b - a).Magnitude, 0.05, 0.05), Color = d.Color, Transparency = 0, Shape = d.Shape }
				dumpPart(copy, cf, list, "eq")
			else
				dumpPart(d, cf, list, "eq")
			end
		end
	end
	for name, cf in pairs(W) do
		local p = rig:FindFirstChild(name)
		if p and p.Transparency < 1 then
			dumpPart(p, cf, list, "rig")
		end
	end
	-- joint pivot sanity: distance between limb end targets is reported by caller
	table.insert(frames, { t = t, parts = list })
end
fs.writeFile("build/pose_" .. kind .. ".json", serde.encode("json", { kind = kind, frames = frames }))
print("ok", kind, #frames)
