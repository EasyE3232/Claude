--[[
	Map — a compact, fair linear world.

	  - 8 gyms, 4 per side, packed along a short red-carpet boulevard
	    (96 studs apart, front doors 25 studs from the carpet).
	  - The conveyor runs along +Z. Influencers don't only come from one end:
	    they drop out of chutes spread along the belt (one upstream of every
	    pair of gyms, plus the main tunnel), taking turns, so no gym is far from
	    where the talent shows up.
	  - Realistic dressing: layered trees with tapered trunks, branches and
	    multi-tone foliage, bushes, rocks, stone walls with hedges, curbed
	    walkways. The ground becomes real Terrain grass at runtime
	    (EnvironmentService), with animated grass blades and clouds.
]]

local Geo = require("tools/map/Geo")
local Gym = require("tools/map/Gym")

local Map = {}
local Pal = Geo.Palette
local M = Enum.Material
local rad = math.rad

Map.LOT_Z = { -144, -48, 48, 144 } -- 96 studs apart (20-stud gaps between gyms)
Map.LOT_X = 72 -- gym center from the carpet center line (front door at 40)
Map.HALF_X = 124
Map.HALF_Z = 226
Map.BELT_Z0 = -204
Map.BELT_Z1 = 204
Map.BELT_TOP = 1.0
Map.BELT_WIDTH = 7
Map.CARPET_HALF = 13

local CARPET = Color3.fromRGB(128, 16, 26)
local BRASS = Color3.fromRGB(176, 146, 86)
local STONE = Color3.fromRGB(118, 114, 108)
local CONCRETE = Color3.fromRGB(168, 166, 160)

-- greens that read as real foliage under Future lighting
local LEAF = {
	Color3.fromRGB(52, 84, 38),
	Color3.fromRGB(64, 98, 44),
	Color3.fromRGB(78, 112, 50),
	Color3.fromRGB(44, 72, 34),
	Color3.fromRGB(92, 118, 56),
}
local BARK = Color3.fromRGB(74, 58, 44)

-- ----------------------------------------------------------------------
-- Realistic vegetation (built from parts, randomized per instance)
-- ----------------------------------------------------------------------
local function leafBall(parent, r, center, size)
	local p = Geo.ball(parent, "Leaves", size, CFrame.new(center), LEAF[r:NextInteger(1, #LEAF)], M.LeafyGrass)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Broadleaf tree: tapered, slightly leaning trunk, a few branches, and a
-- crown made of many overlapping foliage clusters in several greens.
local function tree(parent, pos, scale, seed)
	local r = Random.new(seed)
	local m = Geo.model(parent, "Tree")
	scale = scale or 1
	local segs = 4
	local base = pos
	local lean = Vector3.new(r:NextNumber(-0.25, 0.25), 0, r:NextNumber(-0.25, 0.25))
	local radius = 0.95 * scale
	-- root flare
	Geo.cyl(m, "RootFlare", 0.9 * scale, radius * 3.1, CFrame.new(base + Vector3.new(0, 0.3 * scale, 0)) * CFrame.Angles(0, 0, rad(90)), BARK, M.Wood)
	local top = base
	for i = 1, segs do
		local h = (3.2 - i * 0.25) * scale
		local nextTop = top + Vector3.new(0, h, 0) + lean * scale * 0.6
		local d = radius * 2 * (1 - (i - 1) * 0.17)
		Geo.tube(m, "Trunk", top, nextTop + (nextTop - top).Unit * 0.2, d, BARK, M.Wood)
		top = nextTop
	end
	local crownCenter = top + Vector3.new(0, 2.6 * scale, 0)
	-- branches
	local branches = r:NextInteger(4, 6)
	local tips = {}
	for b = 1, branches do
		local a = (b / branches) * math.pi * 2 + r:NextNumber(-0.3, 0.3)
		local startP = top - Vector3.new(0, r:NextNumber(0.6, 2.4) * scale, 0)
		local len = r:NextNumber(3.2, 4.8) * scale
		local dir = Vector3.new(math.cos(a), r:NextNumber(0.55, 0.9), math.sin(a)).Unit
		local tip = startP + dir * len
		Geo.decorate(Geo.tube(m, "Branch", startP, tip, radius * 0.7, BARK, M.Wood))
		table.insert(tips, tip)
	end
	-- foliage clusters at branch tips + crown
	for _, tip in ipairs(tips) do
		for _ = 1, 3 do
			leafBall(m, r, tip + Vector3.new(r:NextNumber(-1.2, 1.2), r:NextNumber(-0.5, 1.4), r:NextNumber(-1.2, 1.2)) * scale, r:NextNumber(3.4, 5) * scale)
		end
	end
	for _ = 1, 6 do
		local off = Vector3.new(r:NextNumber(-2.2, 2.2), r:NextNumber(-0.8, 2.6), r:NextNumber(-2.2, 2.2)) * scale
		leafBall(m, r, crownCenter + off, r:NextNumber(4.5, 6.2) * scale)
	end
	return m
end

-- Conifer: straight trunk, foliage in drooping tiers that get smaller toward the top
local function pine(parent, pos, scale, seed)
	local r = Random.new(seed)
	local m = Geo.model(parent, "Pine")
	scale = scale or 1
	local height = r:NextNumber(15, 19) * scale
	Geo.tube(m, "Trunk", pos, pos + Vector3.new(0, height, 0), 1.1 * scale, Color3.fromRGB(70, 52, 40), M.Wood)
	local tiers = 7
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local y = height * (0.22 + 0.72 * t)
		local rad0 = (6.2 - 5.0 * t) * scale
		local color = Color3.fromRGB(34 + r:NextInteger(0, 10), 60 + r:NextInteger(0, 12), 38 + r:NextInteger(0, 8))
		-- each tier = a few flattened, overlapping blobs (reads as a cone of boughs)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + i
			local c = pos + Vector3.new(math.cos(a) * rad0 * 0.35, y, math.sin(a) * rad0 * 0.35)
			local p = Geo.part(m, "Boughs", Vector3.new(rad0 * 1.4, 1.8 * scale, rad0 * 1.4), CFrame.new(c) * CFrame.Angles(0, a, rad(r:NextNumber(-8, 8))), color, M.LeafyGrass)
			p.Shape = Enum.PartType.Ball
			Geo.decorate(p)
		end
	end
	Geo.decorate(Geo.ball(m, "Tip", 1.8 * scale, CFrame.new(pos + Vector3.new(0, height + 0.4, 0)), Color3.fromRGB(38, 64, 40), M.LeafyGrass))
	return m
end

local function bush(parent, pos, scale, seed)
	local r = Random.new(seed)
	local m = Geo.model(parent, "Bush")
	for _ = 1, r:NextInteger(4, 6) do
		local s = r:NextNumber(2.2, 3.4) * scale
		leafBall(m, r, pos + Vector3.new(r:NextNumber(-1.6, 1.6) * scale, s * 0.35, r:NextNumber(-1.6, 1.6) * scale), s)
	end
	return m
end

local function rock(parent, pos, scale, seed)
	local r = Random.new(seed)
	local p = Geo.part(parent, "Rock", Vector3.new(r:NextNumber(2, 3.4), r:NextNumber(1, 1.8), r:NextNumber(1.8, 3)) * scale,
		CFrame.new(pos + Vector3.new(0, 0.35 * scale, 0)) * CFrame.Angles(rad(r:NextNumber(-12, 12)), rad(r:NextNumber(0, 180)), rad(r:NextNumber(-12, 12))),
		Color3.fromRGB(104 + r:NextInteger(0, 20), 102 + r:NextInteger(0, 18), 98 + r:NextInteger(0, 14)), M.Rock)
	p.Shape = Enum.PartType.Ball
	return p
end

local function lamp(parent, pos, faceDir)
	local m = Geo.model(parent, "StreetLamp")
	Geo.cyl(m, "Base", 0.6, 1.3, CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, rad(90)), Pal.FrameDark, M.Metal)
	Geo.tube(m, "Pole", pos, pos + Vector3.new(0, 13.6, 0), 0.45, Pal.FrameDark, M.Metal)
	local armEnd = pos + Vector3.new(0, 13.6, 0) + faceDir * 3
	Geo.decorate(Geo.tube(m, "Arm", pos + Vector3.new(0, 13.6, 0), armEnd, 0.3, Pal.FrameDark, M.Metal))
	Geo.decorate(Geo.part(m, "Housing", Vector3.new(2, 0.35, 1), CFrame.lookAt(armEnd, armEnd + faceDir), Pal.FrameDark, M.Metal))
	local lens = Geo.decorate(Geo.part(m, "Lens", Vector3.new(1.7, 0.08, 0.8), CFrame.lookAt(armEnd - Vector3.new(0, 0.2, 0), armEnd - Vector3.new(0, 0.2, 0) + faceDir), Color3.fromRGB(255, 244, 222), M.Neon))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 36
	light.Angle = 115
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 236, 205)
	light.Shadows = false
	light.Parent = lens
	return m
end

-- stone wall with a trimmed hedge on top
local function wallRun(parent, a, b)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	Geo.part(parent, "StoneWall", Vector3.new(3, 3, len), cf + Vector3.new(0, 1.5, 0), STONE, M.Cobblestone)
	Geo.part(parent, "WallCap", Vector3.new(3.6, 0.5, len), cf + Vector3.new(0, 3.25, 0), Color3.fromRGB(140, 136, 128), M.Slate)
	Geo.part(parent, "Hedge", Vector3.new(3, 5, len), cf + Vector3.new(0, 6, 0), Color3.fromRGB(50, 80, 38), M.LeafyGrass)
end

local function chute(parent, z, label)
	local m = Geo.model(parent, "DropChute")
	local h = 16
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(m, "ChuteLeg", Vector3.new(0.8, h, 0.8), CFrame.new(s * 6.5, h / 2, z), Pal.FrameDark, M.Metal)
	end
	Geo.part(m, "ChuteBeam", Vector3.new(14, 1.2, 1.6), CFrame.new(0, h, z), Pal.FrameDark, M.Metal)
	-- the tube influencers drop out of
	local tube = Geo.cyl(m, "Tube", 7, 5, CFrame.new(0, h - 3.5, z) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(200, 215, 230), M.Glass, { Transparency = 0.5, CanCollide = false })
	tube.CastShadow = false
	Geo.decorate(Geo.cyl(m, "TubeRim", 0.4, 5.4, CFrame.new(0, h - 7, z) * CFrame.Angles(0, 0, rad(90)), Pal.Accent, M.Neon, { Role = "MapAccent" }))
	local sign = Geo.part(m, "ChuteSign", Vector3.new(12, 2.2, 0.3), CFrame.new(0, h + 1.8, z), Pal.Black, M.SmoothPlastic, { CanCollide = false })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		Geo.surfaceText(sign, face, label, { PPS = 20, Color = Color3.fromRGB(255, 255, 255) })
	end
	local point = Geo.decorate(Geo.part(m, "DropPoint", Vector3.new(1, 1, 1), CFrame.new(0, Map.BELT_TOP + 8.5, z), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	point:SetAttribute("DropPoint", true)
	return m
end

local function tunnel(parent, name, z, dir, label)
	local cf = CFrame.new(0, 0, z)
	local m = Geo.model(parent, name)
	Geo.part(m, "TunnelLeft", Vector3.new(3, 12, 14), cf * CFrame.new(-7.5, 6, 0), Pal.FrameDark, M.Concrete)
	Geo.part(m, "TunnelRight", Vector3.new(3, 12, 14), cf * CFrame.new(7.5, 6, 0), Pal.FrameDark, M.Concrete)
	Geo.part(m, "TunnelTop", Vector3.new(18, 3, 14), cf * CFrame.new(0, 13.5, 0), Pal.FrameDark, M.Concrete)
	Geo.part(m, "TunnelBack", Vector3.new(12, 12, 1), cf * CFrame.new(0, 6, dir * 6.5), Pal.Black, M.SmoothPlastic)
	local face = -dir
	Geo.decorate(Geo.part(m, "TunnelGlow", Vector3.new(12, 0.3, 0.3), cf * CFrame.new(0, 11.8, face * 7.1), Pal.Accent, M.Neon, { Role = "MapAccent" }))
	local sign = Geo.part(m, "TunnelSign", Vector3.new(16, 3, 0.4), cf * CFrame.new(0, 13.5, face * 7.3), Pal.Black, M.SmoothPlastic)
	Geo.surfaceText(sign, face < 0 and Enum.NormalId.Front or Enum.NormalId.Back, label, { Color = Color3.fromRGB(255, 255, 255), PPS = 20 })
	Geo.decorate(Geo.part(m, "Curtain", Vector3.new(11, 10, 0.2), cf * CFrame.new(0, 6, face * 5.5), Color3.fromRGB(10, 10, 12), M.Fabric, { Transparency = 0.15 }))
	return m
end

-- ----------------------------------------------------------------------
function Map.Build(workspace)
	local root = Instance.new("Folder")
	root.Name = "GymWarsMap"
	root.Parent = workspace
	local env = Geo.folder(root, "Environment")
	local nature = Geo.folder(env, "Nature")
	local hx, hz = Map.HALF_X, Map.HALF_Z

	-- ground (Studio edit view only; replaced by Terrain grass when the server starts)
	local ground = Geo.part(env, "Ground", Vector3.new(hx * 2 + 60, 4, hz * 2 + 60), CFrame.new(0, -2, 0), Color3.fromRGB(96, 122, 62), M.Grass)
	ground:SetAttribute("EditOnly", true)

	-- stone + hedge boundary with a gate at each end
	local gateHalf = 20
	for _, s in ipairs({ -1, 1 }) do
		wallRun(env, Vector3.new(s * (hx + 1.5), 0, -hz - 1.5), Vector3.new(s * (hx + 1.5), 0, hz + 1.5))
		for _, sz in ipairs({ -1, 1 }) do
			wallRun(env, Vector3.new(s * gateHalf, 0, sz * (hz + 1.5)), Vector3.new(s * (hx + 1.5), 0, sz * (hz + 1.5)))
			Geo.part(env, "GatePillar", Vector3.new(4, 12, 4), CFrame.new(s * gateHalf, 6, sz * (hz + 1.5)), STONE, M.Cobblestone)
			Geo.part(env, "PillarCap", Vector3.new(4.8, 0.8, 4.8), CFrame.new(s * gateHalf, 12.4, sz * (hz + 1.5)), Color3.fromRGB(140, 136, 128), M.Slate)
			Geo.decorate(Geo.part(env, "PillarLamp", Vector3.new(1.4, 1.8, 1.4), CFrame.new(s * gateHalf, 13.7, sz * (hz + 1.5)), Color3.fromRGB(255, 238, 205), M.Neon))
		end
	end

	-- red carpet boulevard with a slim brass edge and a concrete promenade either side
	local carpetLen = hz * 2 - 16
	Geo.part(env, "RedCarpet", Vector3.new(Map.CARPET_HALF * 2, 0.12, carpetLen), CFrame.new(0, 0.06, 0), CARPET, M.Carpet)
	for _, s in ipairs({ -1, 1 }) do
		Geo.decorate(Geo.part(env, "CarpetEdge", Vector3.new(0.3, 0.14, carpetLen), CFrame.new(s * (Map.CARPET_HALF + 0.15), 0.07, 0), BRASS, M.Metal))
		Geo.part(env, "Promenade", Vector3.new(6, 0.1, carpetLen), CFrame.new(s * (Map.CARPET_HALF + 3.3), 0.05, 0), CONCRETE, M.Pavement)
		Geo.part(env, "Curb", Vector3.new(0.5, 0.3, carpetLen), CFrame.new(s * (Map.CARPET_HALF + 6.55), 0.15, 0), Color3.fromRGB(190, 188, 182), M.Concrete)
	end

	-- ================= conveyor =================
	local belt = Geo.folder(root, "Belt")
	local beltLen = Map.BELT_Z1 - Map.BELT_Z0
	local beltMid = (Map.BELT_Z0 + Map.BELT_Z1) / 2
	local track = Geo.part(belt, "BeltTrack", Vector3.new(Map.BELT_WIDTH, Map.BELT_TOP, beltLen), CFrame.new(0, Map.BELT_TOP / 2, beltMid), Pal.Belt, M.Rubber)
	track:SetAttribute("Conveyor", true)
	for _, s in ipairs({ -1, 1 }) do
		local hxb = Map.BELT_WIDTH / 2
		Geo.part(belt, "BeltSkirt", Vector3.new(1, 1.4, beltLen), CFrame.new(s * (hxb + 0.5), 0.7, beltMid), Pal.FrameDark, M.Metal)
		Geo.decorate(Geo.part(belt, "BeltGlow", Vector3.new(0.2, 0.08, beltLen), CFrame.new(s * (hxb + 0.5), 1.43, beltMid), Pal.Accent, M.Neon, { Role = "MapAccent" }))
		Geo.part(belt, s < 0 and "RailLeft" or "RailRight", Vector3.new(0.3, 0.6, beltLen), CFrame.new(s * (hxb + 0.85), 1.7, beltMid), Pal.Chrome, M.Metal, { Reflectance = 0.1 })
	end
	Geo.decorate(Geo.part(belt, "BeltStart", Vector3.new(1, 1, 1), CFrame.new(0, Map.BELT_TOP + 3, Map.BELT_Z0 + 4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	Geo.decorate(Geo.part(belt, "BeltEnd", Vector3.new(1, 1, 1), CFrame.new(0, Map.BELT_TOP + 3, Map.BELT_Z1 - 4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	local startPoint = Geo.decorate(Geo.part(belt, "DropPoint", Vector3.new(1, 1, 1), CFrame.new(0, Map.BELT_TOP + 3, Map.BELT_Z0 + 5), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	startPoint:SetAttribute("DropPoint", true)
	-- chutes: one just upstream of every pair of gyms
	for i, z in ipairs(Map.LOT_Z) do
		chute(belt, z - 30, "DROP ZONE " .. i)
	end

	local chev = Geo.folder(belt, "Chevrons")
	local spacing = 8
	local n = 0
	for z = Map.BELT_Z0 + 2, Map.BELT_Z1 - 2, spacing do
		n += 1
		local m = Geo.model(chev, "Chevron")
		local cf = CFrame.new(0, Map.BELT_TOP + 0.02, z)
		local a = Geo.decorate(Geo.part(m, "A", Vector3.new(2.6, 0.04, 0.4), cf * CFrame.new(-1.05, 0, 0) * CFrame.Angles(0, rad(-35), 0), Color3.fromRGB(56, 56, 60), M.SmoothPlastic, { CastShadow = false }))
		Geo.decorate(Geo.part(m, "B", Vector3.new(2.6, 0.04, 0.4), cf * CFrame.new(1.05, 0, 0) * CFrame.Angles(0, rad(35), 0), Color3.fromRGB(56, 56, 60), M.SmoothPlastic, { CastShadow = false }))
		m.PrimaryPart = a
	end
	chev:SetAttribute("Spacing", spacing)
	chev:SetAttribute("Z0", Map.BELT_Z0 + 2)
	chev:SetAttribute("Length", n * spacing)

	tunnel(belt, "DropTunnel", Map.BELT_Z0 - 2, -1, "INFLUENCER DROP")
	tunnel(belt, "ExitTunnel", Map.BELT_Z1 + 2, 1, "LAST CHANCE")

	-- ================= lots =================
	local plots = Geo.folder(root, "Plots")
	local id = 0
	for _, side in ipairs({ -1, 1 }) do
		for li, z in ipairs(Map.LOT_Z) do
			id += 1
			local center = Vector3.new(side * Map.LOT_X, 0, z)
			Gym.Build(plots, id, CFrame.lookAt(center, Vector3.new(0, 0, z)))

			-- curbed walkway from the promenade to the door (the door is offset to the aisle)
			local doorZ = z - side * Gym.AISLE_X
			local x0 = Map.CARPET_HALF + 6.8
			local x1 = Map.LOT_X - Gym.D / 2
			local walkLen = x1 - x0
			Geo.part(env, "Walkway", Vector3.new(walkLen, 0.1, 10), CFrame.new(side * (x0 + walkLen / 2), 0.05, doorZ), CONCRETE, M.Pavement)
			for _, dz in ipairs({ -5.25, 5.25 }) do
				Geo.part(env, "WalkCurb", Vector3.new(walkLen, 0.3, 0.5), CFrame.new(side * (x0 + walkLen / 2), 0.15, doorZ + dz), Color3.fromRGB(190, 188, 182), M.Concrete)
			end
			-- planting beds along the building front
			for _, dz in ipairs({ -26, -15, 15, 26 }) do
				bush(nature, Vector3.new(side * (x1 - 3), 0, doorZ + dz), 1, id * 31 + dz)
			end
			lamp(env, Vector3.new(side * (x0 + 2), 0, doorZ - 8), Vector3.new(-side, 0, 0))
			lamp(env, Vector3.new(side * (x0 + 2), 0, doorZ + 8), Vector3.new(-side, 0, 0))
			-- a tree or two in the side yards between gyms
			if li < #Map.LOT_Z then
				local zMid = (z + Map.LOT_Z[li + 1]) / 2
				tree(nature, Vector3.new(side * (Map.LOT_X - 20), 0, zMid), 0.85, id * 7)
				bush(nature, Vector3.new(side * (Map.LOT_X + 8), 0, zMid + 3), 0.9, id * 11)
				tree(nature, Vector3.new(side * (Map.LOT_X + 26), 0, zMid - 2), 0.8, id * 13)
			end
		end

		-- behind the gyms: a belt of pines and broadleaf trees against the wall
		local r = Random.new(side > 0 and 5 or 9)
		for z = -hz + 12, hz - 12, 17 do
			local x = side * r:NextNumber(hx - 14, hx - 7)
			if r:NextNumber() < 0.55 then
				pine(nature, Vector3.new(x, 0, z + r:NextNumber(-4, 4)), r:NextNumber(0.85, 1.15), math.floor(z * 3 + side * 101))
			else
				tree(nature, Vector3.new(x, 0, z + r:NextNumber(-4, 4)), r:NextNumber(0.8, 1.05), math.floor(z * 5 + side * 77))
			end
			if r:NextNumber() < 0.4 then
				rock(nature, Vector3.new(side * r:NextNumber(hx - 22, hx - 16), 0, z + r:NextNumber(-6, 6)), r:NextNumber(0.8, 1.6), math.floor(z + side * 13))
			end
		end
		-- the plazas at both ends
		for _, sz in ipairs({ -1, 1 }) do
			for k = 1, 3 do
				tree(nature, Vector3.new(side * (30 + k * 24), 0, sz * (hz - 16)), 0.9, k * 41 + (sz > 0 and 7 or 0) + side * 3)
			end
			bush(nature, Vector3.new(side * 24, 0, sz * (hz - 10)), 1.1, sz * 17 + side)
		end
	end

	-- spawn plaza by the drop tunnel
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(30, 0.2, -hz + 22)
	spawn.Color = Color3.fromRGB(150, 148, 142)
	spawn.Material = M.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	return root
end

return Map
