--[[
	CharacterModels
	Uses a real, rigged R15 model for a character when one is available,
	checked in this order:

	  1. ServerStorage.CharacterModels.<ModelName>   (a .rbxm dropped into
	     tools/models/ is baked there by the build). Init() also collects any
	     model you placed in the world / ServerStorage / ReplicatedStorage
	     whose name contains a character's name ("RonnieCurlman",
	     "Meshy_AI_Ronnie_Curlman_Darker", ...) and moves it here.
	  2. Characters entry AssetId = <number>          (a Model asset you
	     uploaded; loaded with InsertService, so it must be owned by the
	     game's creator)

	An R15 rig (Humanoid, HumanoidRootPart, the 15 R15 parts) is used as the
	character's body and animates fully. Any other model (a plain imported
	mesh) is used as a "Static" visual riding an invisible rig.
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local Characters = require(game:GetService("ReplicatedStorage").Modules.Characters)

local CharacterModels = {}

local function norm(s)
	return (s:lower():gsub("[^%w]", ""))
end

local function modelsFolder()
	local f = ServerStorage:FindFirstChild("CharacterModels")
	if not f then
		f = Instance.new("Folder")
		f.Name = "CharacterModels"
		f.Parent = ServerStorage
	end
	return f
end

-- Collect hand-placed character models (by name) before anything spawns.
function CharacterModels.Init()
	local folder = modelsFolder()
	local keys = {}
	for _, c in ipairs(Characters.LIST) do
		for _, k in ipairs({ c.ModelName, c.Name, c.DisplayName }) do
			if k and #norm(k) >= 6 then -- short names ("Joe") would match random parts
				table.insert(keys, { norm(k), c })
			end
		end
	end
	-- longest names first so "RonnieCurlman" can't be claimed by a shorter name
	table.sort(keys, function(a, b)
		return #a[1] > #b[1]
	end)
	local found = {}
	local map = workspace:FindFirstChild("GymWarsMap")
	for _, root in ipairs({ workspace, ServerStorage, game:GetService("ReplicatedStorage") }) do
		for _, d in ipairs(root:GetDescendants()) do
			if (d:IsA("Model") or d:IsA("MeshPart")) and not d:GetAttribute("CharacterId") and not d:IsDescendantOf(folder)
				and not (map and d:IsDescendantOf(map)) then
				local n = norm(d.Name)
				for _, kc in ipairs(keys) do
					local c = kc[2]
					if not found[c.ModelName] and n:find(kc[1], 1, true) and not folder:FindFirstChild(c.ModelName) then
						-- skip parts of an already-matched model
						local parentMatched = false
						for _, m in pairs(found) do
							if d:IsDescendantOf(m) then
								parentMatched = true
							end
						end
						if not parentMatched then
							found[c.ModelName] = d
						end
						break
					end
				end
			end
		end
	end
	for modelName, inst in pairs(found) do
		print(("[CharacterModels] using %s for %s"):format(inst:GetFullName(), modelName))
		local holder = inst
		if inst:IsA("MeshPart") then
			holder = Instance.new("Model")
			inst.Parent = holder
		end
		holder.Name = modelName
		holder.Parent = folder -- out of the world: it's a template now
	end
end

local REQUIRED = {
	"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function isRig(m)
	if not (m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")) then
		return false
	end
	for _, n in ipairs(REQUIRED) do
		if not m:FindFirstChild(n) then
			return false
		end
	end
	return true
end

local function findRig(root)
	if isRig(root) then
		return root
	end
	for _, d in ipairs(root:GetDescendants()) do
		if isRig(d) then
			return d
		end
	end
	return nil
end

local assetCache = {} -- [assetId] = rig | false | "loading"

local function fromAsset(id)
	while assetCache[id] == "loading" do
		task.wait()
	end
	if assetCache[id] == nil then
		assetCache[id] = "loading"
		local ok, asset = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		local rig = ok and asset and findRig(asset)
		if not ok then
			warn(("[CharacterModels] couldn't load asset %d: %s"):format(id, tostring(asset)))
		elseif not rig then
			warn(("[CharacterModels] asset %d isn't an R15 rig (run Avatar > Auto Setup on it in Studio and upload the result)"):format(id))
		end
		assetCache[id] = rig or false
	end
	return assetCache[id] or nil
end

function CharacterModels.Template(char)
	local folder = ServerStorage:FindFirstChild("CharacterModels")
	local stored = folder and char.ModelName and folder:FindFirstChild(char.ModelName)
	if stored then
		local rig = findRig(stored)
		if rig then
			return rig, "Rig"
		end
		return stored, "Static"
	end
	if char.AssetId then
		local rig = fromAsset(char.AssetId)
		return rig, rig and "Rig" or nil
	end
	return nil
end

-- Returns (model, kind): kind "Rig" = full R15 body, "Static" = visual only.
function CharacterModels.Build(char, height)
	local template, kind = CharacterModels.Template(char)
	if not template then
		return nil
	end
	local m = template:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or (kind == "Static" and (d:IsA("Humanoid") or d:IsA("JointInstance") or d:IsA("Constraint"))) then
			d:Destroy() -- never run scripts that came with an asset
		end
	end
	local _, size = m:GetBoundingBox()
	if size.Y > 0.1 then
		pcall(function()
			m:ScaleTo(m:GetScale() * height / size.Y)
		end)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = d.Name ~= "HumanoidRootPart"
			if kind == "Static" then
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	end
	return m, kind
end

-- Weld a static visual onto a rig: feet on the ground, centered, facing the
-- rig's front (turn it with the character's ModelYaw, in degrees).
function CharacterModels.AttachStatic(rig, visual, char)
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then
		return
	end
	local cf, size = visual:GetBoundingBox()
	local feetY = hrp.CFrame.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
	local yaw = math.rad(char.ModelYaw or 0)
	local rot = (hrp.CFrame - hrp.CFrame.Position) * CFrame.Angles(0, yaw, 0)
	-- box center goes over the rig, keeping the way you placed the model facing
	local boxInPivot = visual:GetPivot():ToObjectSpace(cf)
	local desiredBox = CFrame.new(hrp.CFrame.Position.X, feetY + size.Y / 2, hrp.CFrame.Position.Z) * rot * (cf - cf.Position)
	visual:PivotTo(desiredBox * boxInPivot:Inverse())
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = hrp
			w.Part1 = d
			w.Parent = d
		end
	end
	visual.Name = "StaticVisual"
	visual.Parent = rig
	for _, p in ipairs(rig:GetChildren()) do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
end

return CharacterModels
