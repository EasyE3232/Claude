--[[
	CharacterModels
	Uses a real, rigged R15 model for a character when one is available,
	checked in this order:

	  1. ServerStorage.CharacterModels.<ModelName>   (a .rbxm dropped into
	     tools/models/ is baked there by the build)
	  2. Characters entry AssetId = <number>          (a Model asset you
	     uploaded; loaded with InsertService, so it must be owned by the
	     game's creator)

	The model must be an R15 rig (Humanoid, HumanoidRootPart and the 15 R15
	joints). Studio's Avatar > Auto Setup turns a Meshy mesh into exactly
	that. Anything else falls back to the baked mesh / part-built look.
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local CharacterModels = {}

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
	local rig = stored and findRig(stored)
	if rig then
		return rig
	end
	if stored then
		warn("[CharacterModels] " .. char.ModelName .. " isn't an R15 rig")
	end
	if char.AssetId then
		return fromAsset(char.AssetId)
	end
	return nil
end

-- Returns a fresh copy sized to `height` studs tall, or nil.
function CharacterModels.Build(char, height)
	local template = CharacterModels.Template(char)
	if not template then
		return nil
	end
	local m = template:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") then
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
		end
	end
	return m
end

return CharacterModels
