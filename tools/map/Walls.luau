--[[
	Walls — the tall stone boundary around the world.

	  Walls.Build(parent, halfX, halfZ, height) -> Folder "WorldWalls"

	A closed rectangle just outside (halfX, halfZ): thick fieldstone wall with a
	slate cap, stepped plinth, buttress pilasters with lanterns, and an ivy
	hedge planted along the inside. Pure Roblox API, shared by the map builder
	and the live command-bar patch.
]]

local Walls = {}

local STONE = Color3.fromRGB(122, 118, 110)
local STONE_DARK = Color3.fromRGB(96, 92, 86)
local CAP = Color3.fromRGB(70, 70, 74)
local IVY = Color3.fromRGB(48, 78, 36)
local LANTERN = Color3.fromRGB(255, 226, 170)

local function part(parent, name, size, cf, color, material, decor)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if decor then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	p.Parent = parent
	return p
end

function Walls.Build(parent, halfX, halfZ, height)
	local f = Instance.new("Folder")
	f.Name = "WorldWalls"
	local H = height or 30
	local T = 4
	local ox, oz = halfX + T / 2, halfZ + T / 2
	-- each side: center, length, and the inward direction
	local sides = {
		{ CFrame.new(-ox, 0, 0), oz * 2 + T, Vector3.new(1, 0, 0) },
		{ CFrame.new(ox, 0, 0), oz * 2 + T, Vector3.new(-1, 0, 0) },
		{ CFrame.new(0, 0, -oz) * CFrame.Angles(0, math.rad(90), 0), ox * 2 + T, Vector3.new(0, 0, 1) },
		{ CFrame.new(0, 0, oz) * CFrame.Angles(0, math.rad(90), 0), ox * 2 + T, Vector3.new(0, 0, -1) },
	}
	for _, sd in ipairs(sides) do
		local cf, len, inward = sd[1], sd[2], sd[3]
		-- local frame: wall runs along Z, thickness along X
		part(f, "WorldWall", Vector3.new(T, H, len), cf * CFrame.new(0, H / 2, 0), STONE, Enum.Material.Cobblestone)
		part(f, "WallPlinth", Vector3.new(T + 1.6, 2.4, len), cf * CFrame.new(0, 1.2, 0), STONE_DARK, Enum.Material.Slate)
		part(f, "WallCap", Vector3.new(T + 1.2, 1.2, len + 1), cf * CFrame.new(0, H + 0.6, 0), CAP, Enum.Material.Slate)
		part(f, "WallCoping", Vector3.new(T + 0.4, 0.6, len), cf * CFrame.new(0, H + 1.5, 0), STONE_DARK, Enum.Material.Slate)
		-- ivy hedge planted along the inside face
		local inX = (cf - cf.Position):PointToObjectSpace(inward).X
		part(f, "WallIvy", Vector3.new(2.4, 5, len - 6), cf * CFrame.new(inX * (T / 2 + 1.5), 2.5, 0), IVY, Enum.Material.LeafyGrass, true)
		-- buttress pilasters with a lantern on top
		local n = math.max(2, math.floor(len / 32))
		for k = 0, n do
			local z = -len / 2 + k * len / n
			local pc = cf * CFrame.new(inX * 1.2, 0, z)
			part(f, "Pilaster", Vector3.new(T + 2.6, H + 3, 5), pc * CFrame.new(0, (H + 3) / 2, 0), STONE_DARK, Enum.Material.Cobblestone)
			part(f, "PilasterCap", Vector3.new(T + 3.4, 1, 5.8), pc * CFrame.new(0, H + 3.5, 0), CAP, Enum.Material.Slate)
			local lamp = part(f, "WallLantern", Vector3.new(1.4, 2, 1.4), pc * CFrame.new(0, H + 5, 0), LANTERN, Enum.Material.Neon, true)
			lamp.CastShadow = false
			if k % 2 == 0 then
				local light = Instance.new("PointLight")
				light.Color = LANTERN
				light.Range = 22
				light.Brightness = 0.9
				light.Parent = lamp
			end
		end
	end
	f.Parent = parent
	return f
end

return Walls
