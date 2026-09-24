--[[ Dump parts of the built place to JSON for tools/render_map.py
     lune run tools/mapview <mode>   mode = map | gym ]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local loader = require("./lib/loader")
local R = loader.roblox
local game = R.deserializePlace(fs.readFile("build/GymWars.rbxlx"))
local ws = game:GetService("Workspace")
local mode = process.args[1] or "map"
local skip = mode == "gymfull" and {} or { Roof = true, Parapet = true, LEDStrip = true, Duct = true, DuctBand = true, Hanger = true, TV = true, TVScreen = true,
	WallLeftTop = true, FrontHeader = true, Sign = true, SignGlow = true, Canopy = true, CanopyLight = true, TreeLeaves = true,
	GymZone = true, CoveLight = true, BagChain = true, WallLogo = true }
local list = {}
local root = (mode == "gym" or mode == "gymfull") and ws.GymWarsMap.Plots.Plot5 or ws
local inv = (mode == "gym" or mode == "gymfull") and root.Floor.CFrame:Inverse() or R.CFrame.new()
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") and p.Transparency < 0.95 and not ((mode == "gym" or mode == "gymfull") and skip[p.Name]) and not (mode == "map" and (p.Name == "Roof" or p.Name == "Parapet" or p.Name == "TreeLeaves" or p.Name == "Ground")) then
		local c = inv * p.CFrame
		local x, y, z, a, b, cc, d, e, f, g, h, i = c:GetComponents()
		table.insert(list, { n = p.Name, tag = "eq", cf = { x, y, z, a, b, cc, d, e, f, g, h, i }, s = { p.Size.X, p.Size.Y, p.Size.Z },
			c = { p.Color.R, p.Color.G, p.Color.B }, t = p.Transparency, shape = tostring(p.Shape) })
	end
end
fs.writeFile("build/pose_" .. mode .. ".json", serde.encode("json", { kind = mode, frames = { { t = 0, parts = list } } }))
print(#list)
