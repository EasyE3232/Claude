-- Offline preview of CharacterLooks: lune run tools/lookcheck <CharacterName>... -> build/looks.json
-- (BlockRig stands in for the real R15 avatar, so proportions are approximate)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local loader = require("./lib/loader")
local R = loader.roblox
local Vector3, CFrame = R.Vector3, R.CFrame
local BlockRig = loader.require("src/ReplicatedStorage/Modules/Gym/BlockRig")

local function ref(path)
	return setmetatable({}, { __index = function(_, n)
		if n == "__path" then return "./" .. path .. ".luau" end
		return ref(path .. "/" .. n)
	end })
end
loader.setGame({ GetService = function(_, name)
	return ref("src/" .. name)
end })
loader.preload("src/ServerScriptService/NpcService", {
	GROUP_NPC = "NPC",
	CreateRig = function(o)
		local m = BlockRig.Build({ Skin = o.Skin, Shirt = o.Shirt, Pants = o.Pants })
		local w, h, d = o.Width or 1, o.Height or 1, o.Depth or 1
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local pos = p.CFrame.Position
				p.Size = Vector3.new(p.Size.X * w, p.Size.Y * h, p.Size.Z * d)
				p.CFrame = CFrame.new(pos.X * w, pos.Y * h, pos.Z * d)
			end
		end
		return m
	end,
})
local Characters = loader.require("src/ReplicatedStorage/Modules/Characters")
local Looks = loader.require("src/ServerScriptService/CharacterLooks")
local out = {}
for _, name in process.args do
	local model = Looks.Build(Characters.Get(name))
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local x, y, z, a, b, c, e, f, g, h, i, j = p.CFrame:GetComponents()
			table.insert(list, { n = p.Name, cf = { x, y, z, a, b, c, e, f, g, h, i, j }, s = { p.Size.X, p.Size.Y, p.Size.Z },
				c = { p.Color.R, p.Color.G, p.Color.B }, t = 0, shape = mesh and "Ellipsoid" or tostring(p.Shape) })
		end
	end
	table.insert(out, { t = name, parts = list })
end
fs.writeFile("build/looks.json", serde.encode("json", out))
