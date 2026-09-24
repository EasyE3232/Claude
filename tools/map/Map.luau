--[[
	Map — the long, linear world: a red-carpet boulevard with the conveyor
	down the middle, 5 gym lots on each side (10 total), hedge walls and a
	gate at each end.

	World axes: the conveyor runs along +Z (from the DROP tunnel at -Z to the
	EXIT tunnel at +Z). Lots face the carpet.
]]

local Geo = require("tools/map/Geo")
local Gym = require("tools/map/Gym")

local Map = {}
local Pal = Geo.Palette
local M = Enum.Material
local rad = math.rad

Map.HALF_X = 170
Map.HALF_Z = 370
Map.LOT_Z = { -240, -120, 0, 120, 240 }
Map.LOT_X = 92 -- gym center distance from the carpet center line
Map.BELT_Z0 = -338
Map.BELT_Z1 = 338
Map.BELT_TOP = 1.0
Map.BELT_WIDTH = 7
Map.CARPET_HALF = 15

local GRASS = Color3.fromRGB(88, 148, 66)
local DIRT = Color3.fromRGB(104, 72, 46)
local CARPET = Color3.fromRGB(165, 18, 30)
local GOLD = Color3.fromRGB(214, 176, 72)

local function lamp(parent, pos, faceDir)
	local pole = Geo.part(parent, "LampPole", Vector3.new(0.5, 14, 0.5), CFrame.new(pos + Vector3.new(0, 7, 0)), Pal.FrameDark, M.Metal)
	local armEnd = pos + Vector3.new(0, 13.6, 0) + faceDir * 3
	Geo.decorate(Geo.beam(parent, "LampArm", pos + Vector3.new(0, 13.6, 0), armEnd, 0.3, Pal.FrameDark, M.Metal))
	local head = Geo.decorate(Geo.part(parent, "LampHead", Vector3.new(1.6, 0.4, 1.6), CFrame.new(armEnd - Vector3.new(0, 0.2, 0)), Color3.fromRGB(255, 240, 210), M.Neon))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 40
	light.Angle = 110
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 236, 205)
	light.Shadows = false
	light.Parent = head
	return pole
end

local function tree(parent, pos, scale)
	scale = scale or 1
	Geo.part(parent, "TreeTrunk", Vector3.new(1.4, 9, 1.4) * scale, CFrame.new(pos + Vector3.new(0, 4.5 * scale, 0)), Color3.fromRGB(92, 64, 44), M.Wood)
	for _, c in ipairs({
		{ Vector3.new(0, 11, 0), 9 },
		{ Vector3.new(2.5, 9.5, 1), 6.5 },
		{ Vector3.new(-2.2, 10, -1.5), 6 },
		{ Vector3.new(0.5, 13.5, -0.5), 6 },
	}) do
		Geo.decorate(Geo.ball(parent, "TreeLeaves", c[2] * scale, CFrame.new(pos + c[1] * scale), Color3.fromRGB(62, 128, 58), M.LeafyGrass))
	end
end

local function tunnel(parent, name, z, dir, label)
	-- dir = +1 when the belt goes INTO it (exit), -1 when the belt comes OUT of it (drop)
	local cf = CFrame.new(0, 0, z)
	local m = Geo.model(parent, name)
	Geo.part(m, "TunnelLeft", Vector3.new(3, 12, 16), cf * CFrame.new(-7.5, 6, 0), Pal.FrameDark, M.Metal)
	Geo.part(m, "TunnelRight", Vector3.new(3, 12, 16), cf * CFrame.new(7.5, 6, 0), Pal.FrameDark, M.Metal)
	Geo.part(m, "TunnelTop", Vector3.new(18, 3, 16), cf * CFrame.new(0, 13.5, 0), Pal.FrameDark, M.Metal)
	Geo.part(m, "TunnelBack", Vector3.new(12, 12, 1), cf * CFrame.new(0, 6, dir * 7.5), Pal.Black, M.SmoothPlastic)
	local face = -dir -- side facing the boulevard
	Geo.decorate(Geo.part(m, "TunnelGlow", Vector3.new(12, 0.4, 0.4), cf * CFrame.new(0, 11.8, face * 8.1), Pal.Accent, M.Neon, { Role = "MapAccent" }))
	local sign = Geo.part(m, "TunnelSign", Vector3.new(16, 3, 0.4), cf * CFrame.new(0, 13.5, face * 8.3), Pal.Black, M.SmoothPlastic)
	Geo.surfaceText(sign, face < 0 and Enum.NormalId.Front or Enum.NormalId.Back, label, { Color = Color3.fromRGB(255, 255, 255), PPS = 20 })
	Geo.decorate(Geo.part(m, "Curtain", Vector3.new(11, 10, 0.2), cf * CFrame.new(0, 6, face * 6), Color3.fromRGB(10, 10, 12), M.Fabric, { Transparency = 0.15 }))
	return m
end

-- ----------------------------------------------------------------------
function Map.Build(workspace)
	local root = Instance.new("Folder")
	root.Name = "GymWarsMap"
	root.Parent = workspace
	local env = Geo.folder(root, "Environment")

	-- ground
	Geo.part(env, "Ground", Vector3.new(Map.HALF_X * 2 + 40, 4, Map.HALF_Z * 2 + 40), CFrame.new(0, -2, 0), GRASS, M.Grass)

	-- dirt border + hedge wall around the whole field (with gates at both ends)
	local hx, hz = Map.HALF_X, Map.HALF_Z
	for _, s in ipairs({ -1, 1 }) do
		Geo.decorate(Geo.part(env, "DirtBorder", Vector3.new(10, 0.1, hz * 2), CFrame.new(s * (hx - 5), 0.05, 0), DIRT, M.Ground))
		Geo.part(env, "WallBase", Vector3.new(4, 2, hz * 2 + 4), CFrame.new(s * (hx + 2), 1, 0), Color3.fromRGB(96, 96, 100), M.Cobblestone)
		Geo.part(env, "Hedge", Vector3.new(4, 9, hz * 2 + 4), CFrame.new(s * (hx + 2), 6.5, 0), Color3.fromRGB(58, 118, 52), M.LeafyGrass)
	end
	local gateHalf = 26
	for _, sz in ipairs({ -1, 1 }) do
		Geo.decorate(Geo.part(env, "DirtBorder", Vector3.new(hx * 2 - 20, 0.1, 10), CFrame.new(0, 0.05, sz * (hz - 5)), DIRT, M.Ground))
		for _, sx in ipairs({ -1, 1 }) do
			local len = hx - gateHalf + 4
			local cx = sx * (gateHalf + len / 2)
			Geo.part(env, "WallBase", Vector3.new(len, 2, 4), CFrame.new(cx, 1, sz * (hz + 2)), Color3.fromRGB(96, 96, 100), M.Cobblestone)
			Geo.part(env, "Hedge", Vector3.new(len, 9, 4), CFrame.new(cx, 6.5, sz * (hz + 2)), Color3.fromRGB(58, 118, 52), M.LeafyGrass)
			-- gate pillars
			Geo.part(env, "GatePillar", Vector3.new(4, 16, 4), CFrame.new(sx * gateHalf, 8, sz * (hz + 2)), Color3.fromRGB(40, 40, 44), M.Slate)
			Geo.decorate(Geo.ball(env, "GateLamp", 2.4, CFrame.new(sx * gateHalf, 17, sz * (hz + 2)), Color3.fromRGB(255, 236, 200), M.Neon))
		end
		local arch = Geo.part(env, "GateArch", Vector3.new(gateHalf * 2 + 4, 3, 4), CFrame.new(0, 17.5, sz * (hz + 2)), Color3.fromRGB(40, 40, 44), M.Slate)
		Geo.surfaceText(arch, sz < 0 and Enum.NormalId.Back or Enum.NormalId.Front, "GYM WARS", { Color = GOLD, PPS = 16 })
	end

	-- red carpet boulevard
	local carpetLen = hz * 2 - 20
	Geo.part(env, "RedCarpet", Vector3.new(Map.CARPET_HALF * 2, 0.12, carpetLen), CFrame.new(0, 0.06, 0), CARPET, M.Carpet)
	for _, s in ipairs({ -1, 1 }) do
		Geo.decorate(Geo.part(env, "CarpetTrim", Vector3.new(0.7, 0.14, carpetLen), CFrame.new(s * (Map.CARPET_HALF + 0.35), 0.07, 0), GOLD, M.Foil))
	end

	-- velvet ropes along the carpet (gaps at every lot walkway)
	local ropes = Geo.folder(env, "VelvetRopes")
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (Map.CARPET_HALF - 1)
		local prev = nil
		for z = -hz + 30, hz - 30, 14 do
			local nearLot = false
			for _, lz in ipairs(Map.LOT_Z) do
				if math.abs(z - lz) < 9 then
					nearLot = true
				end
			end
			if nearLot then
				prev = nil
			else
				local base = Vector3.new(x, 0, z)
				Geo.part(ropes, "Stanchion", Vector3.new(0.3, 3.2, 0.3), CFrame.new(base + Vector3.new(0, 1.6, 0)), GOLD, M.Foil, { CanCollide = false })
				Geo.decorate(Geo.cyl(ropes, "StanchionBase", 0.2, 1.2, CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, rad(90)), GOLD, M.Foil))
				Geo.decorate(Geo.ball(ropes, "StanchionTop", 0.5, CFrame.new(base + Vector3.new(0, 3.3, 0)), GOLD, M.Foil))
				if prev then
					local a, b = prev + Vector3.new(0, 2.9, 0), base + Vector3.new(0, 2.9, 0)
					local mid = (a + b) / 2 - Vector3.new(0, 0.6, 0)
					Geo.decorate(Geo.tube(ropes, "Rope", a, mid, 0.18, Color3.fromRGB(130, 12, 24), M.Fabric))
					Geo.decorate(Geo.tube(ropes, "Rope", mid, b, 0.18, Color3.fromRGB(130, 12, 24), M.Fabric))
				end
				prev = base
			end
		end
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
		Geo.decorate(Geo.part(belt, "BeltGlow", Vector3.new(0.25, 0.1, beltLen), CFrame.new(s * (hxb + 0.5), 1.45, beltMid), Pal.Accent, M.Neon, { Role = "MapAccent" }))
		Geo.part(belt, s < 0 and "RailLeft" or "RailRight", Vector3.new(0.3, 0.6, beltLen), CFrame.new(s * (hxb + 0.85), 1.7, beltMid), Pal.Chrome, M.Metal, { Reflectance = 0.1 })
	end
	Geo.decorate(Geo.part(belt, "BeltStart", Vector3.new(1, 1, 1), CFrame.new(0, Map.BELT_TOP + 3, Map.BELT_Z0 + 4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	Geo.decorate(Geo.part(belt, "BeltEnd", Vector3.new(1, 1, 1), CFrame.new(0, Map.BELT_TOP + 3, Map.BELT_Z1 - 4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	-- scrolling chevrons (moved by the client so the belt visibly runs)
	local chev = Geo.folder(belt, "Chevrons")
	local spacing = 8
	local n = 0
	for z = Map.BELT_Z0 + 2, Map.BELT_Z1 - 2, spacing do
		n += 1
		local m = Geo.model(chev, "Chevron")
		local cf = CFrame.new(0, Map.BELT_TOP + 0.02, z)
		local a = Geo.decorate(Geo.part(m, "A", Vector3.new(2.6, 0.04, 0.45), cf * CFrame.new(-1.05, 0, 0) * CFrame.Angles(0, rad(-35), 0), Color3.fromRGB(60, 60, 66), M.SmoothPlastic, { CastShadow = false }))
		Geo.decorate(Geo.part(m, "B", Vector3.new(2.6, 0.04, 0.45), cf * CFrame.new(1.05, 0, 0) * CFrame.Angles(0, rad(35), 0), Color3.fromRGB(60, 60, 66), M.SmoothPlastic, { CastShadow = false }))
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
		for _, z in ipairs(Map.LOT_Z) do
			id += 1
			local center = Vector3.new(side * Map.LOT_X, 0, z)
			local cf = CFrame.lookAt(center, Vector3.new(0, 0, z))
			Gym.Build(plots, id, cf)

			-- walkway from the carpet to the door + lamps + lot pad
			local doorX = side * (Map.LOT_X - Gym.D / 2)
			local walkLen = math.abs(doorX) - Map.CARPET_HALF - 0.7
			local walkX = side * (Map.CARPET_HALF + 0.7 + walkLen / 2)
			Geo.part(env, "Walkway", Vector3.new(walkLen, 0.1, 12), CFrame.new(walkX, 0.05, z), Color3.fromRGB(150, 150, 152), M.Pavement)
			for _, dz in ipairs({ -8.5, 8.5 }) do
				lamp(env, Vector3.new(side * (Map.CARPET_HALF + 8), 0, z + dz), Vector3.new(-side, 0, 0))
			end
			-- lot concrete apron around the building
			Geo.decorate(Geo.part(env, "LotApron", Vector3.new(Gym.D + 8, 0.06, Gym.W + 8), CFrame.new(side * Map.LOT_X, 0.03, z), Color3.fromRGB(120, 120, 124), M.Concrete))
		end
		-- trees between lots
		for i = 1, #Map.LOT_Z - 1 do
			local zMid = (Map.LOT_Z[i] + Map.LOT_Z[i + 1]) / 2
			for _, x in ipairs({ 58, 92, 126 }) do
				tree(env, Vector3.new(side * x, 0, zMid + (x % 3) * 2), 1 + (x % 5) * 0.05)
			end
		end
		for _, zEnd in ipairs({ -310, 310 }) do
			for _, x in ipairs({ 60, 110, 150 }) do
				tree(env, Vector3.new(side * x, 0, zEnd), 1.1)
			end
		end
	end

	-- spawn plaza by the drop tunnel
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(28, 0.5, -330)
	spawn.Color = GOLD
	spawn.Material = M.Foil
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	return root
end

return Map
