--[[
	Build GymWars.rbxlx
	  lune run tools/build            -> build/GymWars.rbxlx

	Starts from base/GymWars_original.rbxlx (keeps Remotes, settings), replaces
	the old map with the generated linear map, and syncs every script from src/.
]]

local fs = require("@lune/fs")
local loader = require("./lib/loader")
local R = loader.roblox
local Instance, Enum, Color3 = R.Instance, R.Enum, R.Color3

local Map = loader.require("tools/map/Map")

local game = R.deserializePlace(fs.readFile("base/GymWars_original.rbxlx"))
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

-- ----------------------------------------------------------------------
-- Map
-- ----------------------------------------------------------------------
for _, name in ipairs({ "GymWarsMap", "Baseplate", "SpawnLocation", "Influencers" }) do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
Map.Build(workspace)
workspace.StreamingEnabled = false

-- New gyms start as one story: floors 2-3 (and their roofs) wait in
-- ServerStorage until the owner buys them (PlotService moves them in).
local ServerStorage = game:GetService("ServerStorage")
local oldHidden = ServerStorage:FindFirstChild("HiddenGymFloors")
if oldHidden then
	oldHidden:Destroy()
end
local hidden = Instance.new("Folder")
hidden.Name = "HiddenGymFloors"
hidden.Parent = ServerStorage
for _, plot in ipairs(workspace.GymWarsMap.Plots:GetChildren()) do
	local holder = Instance.new("Folder")
	holder.Name = plot.Name
	holder.Parent = hidden
	for _, name in ipairs({ "Floor2", "Floor3", "Roof2", "Roof3" }) do
		local f = plot:FindFirstChild(name)
		if f then
			f.Parent = holder
		end
	end
end

-- ----------------------------------------------------------------------
-- Lighting (Future = real-time lights + shadows, needed for a realistic gym)
-- ----------------------------------------------------------------------
lighting.Technology = Enum.Technology.Future
lighting.ClockTime = 14.5
lighting.Brightness = 2.6
lighting.Ambient = Color3.fromRGB(62, 64, 72)
lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 136)
lighting.EnvironmentDiffuseScale = 1
lighting.EnvironmentSpecularScale = 1
lighting.GlobalShadows = true
lighting.ShadowSoftness = 0.25
for _, child in ipairs(lighting:GetChildren()) do
	child:Destroy()
end
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.28
atmo.Offset = 0.2
atmo.Haze = 1.2
atmo.Glare = 0.4
atmo.Color = Color3.fromRGB(199, 210, 225)
atmo.Decay = Color3.fromRGB(110, 120, 140)
atmo.Parent = lighting
local sky = Instance.new("Sky")
sky.Parent = lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.55
bloom.Size = 24
bloom.Threshold = 1.4
bloom.Parent = lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.08
cc.Saturation = 0.06
cc.Brightness = 0.01
cc.Parent = lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.04
rays.Spread = 0.6
rays.Parent = lighting

-- ----------------------------------------------------------------------
-- Scripts: mirror src/ into the place
-- ----------------------------------------------------------------------
local function clearScripts(container)
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end
clearScripts(SSS)
clearScripts(RS)
clearScripts(StarterPlayer)

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function addScripts(dir, parent)
	for _, entry in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			addScripts(path, ensureFolder(parent, entry))
		elseif entry:match("%.luau$") then
			local base = entry:gsub("%.luau$", "")
			local class = "ModuleScript"
			if base:match("%.server$") then
				class, base = "Script", base:gsub("%.server$", "")
			elseif base:match("%.client$") then
				class, base = "LocalScript", base:gsub("%.client$", "")
			end
			local s = Instance.new(class)
			s.Name = base
			s.Source = fs.readFile(path)
			s.Parent = parent
		end
	end
end

addScripts("src/ReplicatedStorage", RS)
addScripts("src/ServerScriptService", SSS)
addScripts("src/StarterPlayerScripts", StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts"))

-- Remotes used by the game (keep existing, add missing)
local remotes = ensureFolder(RS, "Remotes")
for name, class in pairs({
	Equip = "RemoteFunction",
	Notify = "RemoteEvent",
	Purchase = "RemoteFunction",
	Rebirth = "RemoteFunction",
	SetGymColor = "RemoteEvent",
	DismissFollower = "RemoteEvent",
}) do
	if not remotes:FindFirstChild(name) then
		local r = Instance.new(class)
		r.Name = name
		r.Parent = remotes
	end
end

fs.writeDir("build")
fs.writeFile("build/GymWars.rbxlx", R.serializePlace(game, true))

local parts = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print(("[build] build/GymWars.rbxlx written — %d parts in Workspace"):format(parts))
