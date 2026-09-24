--[[
	Gym — builds one complete gym lot: a 3-story glass building (like a modern
	fitness club), 6 working machines per floor laid out in two clean rows,
	and a switchback staircase in a stair core. Floors 2 and 3 are closed by a
	gate on the stairs until the owner buys them.

	Plot-local space: origin at the building's floor center (ground level),
	-Z faces the conveyor (the entrance side), +Y up.
	  x in [-W/2, W/2], z in [-D/2, D/2]
	  stair core: x in [26, 38], z in [-20, 20]
]]

local Geo = require("tools/map/Geo")
local Stations = require("tools/map/Stations")
local Specs = require("src/ReplicatedStorage/Modules/Gym/StationSpecs")

local Gym = {}
local Pal = Geo.Palette
local M = Enum.Material
local rad = math.rad

Gym.W = 76
Gym.D = 64
Gym.FLOOR_H = 16
Gym.FLOORS = 3
Gym.FLOOR_Y = 0.4
Gym.H = Gym.FLOOR_H * Gym.FLOORS

local W, D, FH, FY = Gym.W, Gym.D, Gym.FLOOR_H, Gym.FLOOR_Y
local HW, HD = W / 2, D / 2
local CORE_X0, CORE_X1 = 26, 38
local SLAB = 1

-- floor f (1..3) walking surface height
local function floorTop(f)
	return FY + (f - 1) * FH
end
Gym.floorTop = floorTop

-- Two tidy rows of three machines on every floor, all facing the glass front.
local COLS = { -28, -9, 10 }
local ROWS = { -11, 15 }
Gym.LAYOUT = {}
for f = 1, Gym.FLOORS do
	for r, z in ipairs(ROWS) do
		for c, x in ipairs(COLS) do
			local slot = (f - 1) * 6 + (r - 1) * 3 + c
			Gym.LAYOUT[slot] = { x, z, 0, f }
		end
	end
end

local DARK_FRAME = Color3.fromRGB(30, 31, 36)

local function wall(parent, name, size, cf, role, material)
	return Geo.part(parent, name, size, cf, role == "Wall" and Pal.Wall or DARK_FRAME, material or M.Plaster, { Role = role })
end

-- ----------------------------------------------------------------------
-- Slab with an optional rectangular hole (for the stairs)
-- ----------------------------------------------------------------------
local function slab(parent, L, name, top, hole, color, material)
	local y = top - SLAB / 2
	local pieces = {}
	if not hole then
		table.insert(pieces, { -HW, HW, -HD, HD })
	else
		local hx0, hx1, hz0, hz1 = hole[1], hole[2], hole[3], hole[4]
		table.insert(pieces, { -HW, hx0, -HD, HD })
		table.insert(pieces, { hx1, HW, -HD, HD })
		table.insert(pieces, { hx0, hx1, -HD, hz0 })
		table.insert(pieces, { hx0, hx1, hz1, HD })
	end
	for _, p in ipairs(pieces) do
		local x0, x1, z0, z1 = p[1], p[2], p[3], p[4]
		if x1 - x0 > 0.01 and z1 - z0 > 0.01 then
			Geo.part(parent, name, Vector3.new(x1 - x0, SLAB, z1 - z0), L((x0 + x1) / 2, y, (z0 + z1) / 2), color, material)
		end
	end
end

-- ----------------------------------------------------------------------
-- One flight of stairs: invisible walkable ramp + floating steps + stringers
-- ----------------------------------------------------------------------
local function flight(parent, L, x, z0, z1, y0, y1)
	local dir = z1 > z0 and 1 or -1
	local a = L(x, y0 + 0.5, z0).Position
	local b = L(x, y1 + 0.5, z1).Position
	local ramp = Geo.part(parent, "StairRamp", Vector3.new(6, 0.6, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.3, 0), Pal.Black, M.SmoothPlastic, { Transparency = 1 })
	ramp.CastShadow = false
	local steps = math.floor(y1 - y0 + 0.5)
	local run = math.abs(z1 - z0) / steps
	for i = 1, steps do
		local zc = z0 + dir * (i - 0.5) * run
		Geo.decorate(Geo.part(parent, "Step", Vector3.new(6, 0.35, run + 0.1), L(x, y0 + i - 0.17, zc), Color3.fromRGB(58, 60, 66), M.Metal))
		Geo.decorate(Geo.part(parent, "StepNose", Vector3.new(6, 0.08, 0.12), L(x, y0 + i + 0.02, zc - dir * run / 2), Pal.Accent, M.Neon, { Role = "Accent" }))
	end
	for _, s in ipairs({ -1, 1 }) do
		local sa = L(x + s * 3.1, y0 + 0.2, z0).Position
		local sb = L(x + s * 3.1, y1 + 0.2, z1).Position
		Geo.decorate(Geo.beam(parent, "Stringer", sa, sb, 0.35, DARK_FRAME, M.Metal))
		local ha = L(x + s * 3.1, y0 + 3.6, z0).Position
		local hb = L(x + s * 3.1, y1 + 3.6, z1).Position
		Geo.decorate(Geo.tube(parent, "Handrail", ha, hb, 0.16, Pal.Chrome, M.Metal))
		for k = 0, 4 do
			local t = k / 4
			local p = sa:Lerp(sb, t)
			Geo.decorate(Geo.part(parent, "Baluster", Vector3.new(0.1, 3.4, 0.1), CFrame.new(p + Vector3.new(0, 1.7, 0)), Pal.Chrome, M.Metal))
		end
	end
end

-- ----------------------------------------------------------------------
-- Glass curtain wall between two corners (a, b in plot-local XZ) for one floor
-- ----------------------------------------------------------------------
local function curtain(parent, L, x0, z0, x1, z1, yBottom, yTop, doorHalf)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local ux, uz = (x1 - x0) / len, (z1 - z0) / len
	local yaw = math.atan2(-uz, ux)
	local function at(t, y)
		return L(x0 + ux * t, y, z0 + uz * t) * CFrame.Angles(0, yaw, 0)
	end
	local h = yTop - yBottom
	if doorHalf then
		local mid = len / 2
		for _, seg in ipairs({ { 0, mid - doorHalf }, { mid + doorHalf, len } }) do
			local sl = seg[2] - seg[1]
			Geo.part(parent, "Glass", Vector3.new(sl, h, 0.25), at((seg[1] + seg[2]) / 2, yBottom + h / 2), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.55 })
		end
		Geo.part(parent, "DoorHeader", Vector3.new(doorHalf * 2, h - 10, 0.6), at(mid, yBottom + 10 + (h - 10) / 2), DARK_FRAME, M.Metal, { Role = "Wall" })
		Geo.decorate(Geo.part(parent, "DoorGlow", Vector3.new(doorHalf * 2, 0.25, 0.7), at(mid, yBottom + 10), Pal.Accent, M.Neon, { Role = "Accent" }))
	else
		Geo.part(parent, "Glass", Vector3.new(len, h, 0.25), at(len / 2, yBottom + h / 2), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.55 })
	end
	local n = math.max(1, math.floor(len / 9.5 + 0.5))
	for k = 0, n do
		local t = k * len / n
		if not doorHalf or math.abs(t - len / 2) > doorHalf + 0.3 then
			Geo.part(parent, "Mullion", Vector3.new(0.45, h, 0.5), at(t, yBottom + h / 2), DARK_FRAME, M.Metal, { Role = "Wall", CanCollide = false })
		end
	end
end

-- ----------------------------------------------------------------------
-- Per-floor dressing
-- ----------------------------------------------------------------------
local function dressFloor(decor, model, L, f)
	local y = floorTop(f)
	local ceil = y + FH - SLAB

	-- floor zoning: a runner down the aisle between the two rows + row mats
	Geo.decorate(Geo.part(decor, "AisleRunner", Vector3.new(58, 0.03, 5), L(-9, y + 0.015, 2), Color3.fromRGB(34, 36, 40), M.Rubber))
	for _, z in ipairs({ -4.4, 8.4 }) do
		Geo.decorate(Geo.part(decor, "AisleLine", Vector3.new(58, 0.04, 0.2), L(-9, y + 0.02, z), Color3.fromRGB(70, 100, 130), M.SmoothPlastic, { Role = "AccentDim" }))
	end
	if f == 1 then
		Geo.decorate(Geo.part(decor, "LobbyFloor", Vector3.new(W - 14, 0.03, 12), L(-6, y + 0.015, -25), Color3.fromRGB(210, 205, 196), M.Marble))
	end

	-- mirror wall + rack along the back wall
	local mirror = Geo.part(decor, "Mirror", Vector3.new(58, 7.5, 0.15), L(-8, y + 4.6, HD - 1.3), Color3.fromRGB(205, 212, 220), M.Glass, { Reflectance = 0.55, CanCollide = false })
	mirror.CastShadow = false
	local rackZ = HD - 3.3
	Geo.part(decor, "DumbbellRack", Vector3.new(30, 0.25, 2.4), L(-8, y + 1.7, rackZ), Pal.Frame, M.Metal, { CanCollide = false })
	for _, x in ipairs({ -22.5, -8, 6.5 }) do
		Geo.decorate(Geo.part(decor, "RackLeg", Vector3.new(0.4, 1.7, 2.2), L(x, y + 0.85, rackZ), Pal.FrameDark, M.Metal))
	end
	for i = 0, 9 do
		local cf = L(-21.5 + i * 3, y + 2.1, rackZ)
		local size = 0.45 + (i % 5) * 0.06
		Geo.decorate(Geo.cyl(decor, "RackBellHandle", 0.55, 0.15, cf, Pal.Steel, M.Metal))
		for _, s in ipairs({ -1, 1 }) do
			Geo.decorate(Geo.cyl(decor, "RackBellHead", 0.3, size, cf * CFrame.new(s * 0.42, 0, 0), Pal.Plate, M.Rubber))
		end
	end

	-- stair-core feature wall: blue stripes + floor sign + TV
	for i = 0, 13 do
		local z = 18.5 - i * 2.6
		if not (f == 2 and z > 13.5) and not (f ~= 2 and z < -13.5) then
			Geo.decorate(Geo.part(decor, "StripePanel", Vector3.new(0.2, 9, 1.2), L(CORE_X0 - 0.45, y + 5.5, z), Pal.Accent, M.SmoothPlastic, { Role = "Accent" }))
		end
	end
	local sign = Geo.decorate(Geo.part(decor, "FloorSign", Vector3.new(0.2, 2.2, 16), L(CORE_X0 - 0.5, y + 11.6, f == 2 and -4 or 4), Pal.Black, M.SmoothPlastic))
	Geo.surfaceText(sign, Enum.NormalId.Left, "FLOOR " .. f .. "  ·  " .. Specs.FLOOR_NAMES[f], { Color = Color3.fromRGB(235, 242, 255), PPS = 24 })

	-- ceiling: black panel, ducts, LED fixtures with real light
	Geo.decorate(Geo.part(decor, "Ceiling", Vector3.new(W - 1, 0.1, D - 1), L(0, ceil - 0.06, 0), Pal.Ceiling, M.SmoothPlastic))
	for _, z in ipairs({ -14, 12 }) do
		Geo.decorate(Geo.tube(decor, "Duct", L(-HW + 2, ceil - 1.5, z).Position, L(CORE_X0 - 1, ceil - 1.5, z).Position, 1.8, Pal.Duct, M.Foil))
	end
	for _, z in ipairs({ -20, -2, 16 }) do
		local fx = Geo.decorate(Geo.part(decor, "LEDStrip", Vector3.new(56, 0.18, 0.5), L(-8, ceil - 0.25, z), Pal.LED, M.Neon))
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 18
		light.Angle = 150
		light.Brightness = 1.3
		light.Color = Color3.fromRGB(235, 242, 255)
		light.Shadows = false
		light.Parent = fx
	end
end

-- ----------------------------------------------------------------------
function Gym.Build(parent, plotId, plotCF)
	local model = Instance.new("Model")
	model.Name = "Plot" .. plotId
	model:SetAttribute("PlotId", plotId)
	model.Parent = parent

	local function L(x, y, z)
		return plotCF * CFrame.new(x, y, z)
	end
	local decor = Geo.folder(model, "Decor")
	local shell = Geo.folder(model, "Shell")

	-- ================= structure =================
	local floor = Geo.part(model, "Floor", Vector3.new(W, FY, D), L(0, FY / 2, 0), Pal.RubberFloor, M.Rubber)
	model.PrimaryPart = floor
	slab(shell, L, "Slab2", floorTop(2), { CORE_X0, CORE_X0 + 6, -16, 16 }, Pal.RubberFloor, M.Rubber)
	slab(shell, L, "Slab3", floorTop(3), { CORE_X0 + 6, CORE_X1, -16, 16 }, Pal.RubberFloor, M.Rubber)
	local roofTop = FY + Gym.H
	slab(shell, L, "Roof", roofTop, nil, Color3.fromRGB(40, 41, 46), M.Concrete)
	-- roof overhang + parapet
	Geo.part(shell, "RoofEdge", Vector3.new(W + 3, 1.6, D + 3), L(0, roofTop + 0.3, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
	-- floor bands around the perimeter (the dark frame lines in the reference)
	for f = 2, Gym.FLOORS do
		local y = floorTop(f) - SLAB / 2
		Geo.part(shell, "BandFront", Vector3.new(W + 1, 2, 1), L(0, y, -HD), DARK_FRAME, M.Metal, { Role = "Wall" })
		Geo.part(shell, "BandLeft", Vector3.new(1, 2, D + 1), L(-HW, y, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
		Geo.part(shell, "BandRight", Vector3.new(1, 2, D + 1), L(HW, y, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
	end
	-- corner columns
	for _, c in ipairs({ { -HW, -HD }, { HW, -HD }, { -HW, HD }, { HW, HD } }) do
		Geo.part(shell, "CornerColumn", Vector3.new(1.6, Gym.H, 1.6), L(c[1], FY + Gym.H / 2, c[2]), DARK_FRAME, M.Metal, { Role = "Wall" })
	end
	-- solid back wall (the mirror side)
	wall(model, "WallBack", Vector3.new(W, Gym.H, 1), L(0, FY + Gym.H / 2, HD - 0.5), "Wall")
	-- glass on the front and both sides, floor by floor
	for f = 1, Gym.FLOORS do
		local y0 = floorTop(f) + (f == 1 and 0 or 0.5)
		local y1 = floorTop(f) + FH - SLAB - 0.5
		curtain(shell, L, -HW, -HD, HW, -HD, y0, y1, f == 1 and 6 or nil)
		curtain(shell, L, -HW, HD - 1, -HW, -HD, y0, y1)
		curtain(shell, L, HW, -HD, HW, HD - 1, y0, y1)
	end
	-- names PlotService recolors
	local leftMarker = Geo.decorate(Geo.part(model, "WallLeft", Vector3.new(0.2, 0.2, 0.2), L(-HW, 0.1, 0), DARK_FRAME, M.Metal, { Transparency = 1 }))
	leftMarker.CastShadow = false
	local rightMarker = Geo.decorate(Geo.part(model, "WallRight", Vector3.new(0.2, 0.2, 0.2), L(HW, 0.1, 0), DARK_FRAME, M.Metal, { Transparency = 1 }))
	rightMarker.CastShadow = false

	-- rooftop sign facing the red carpet
	local sign = Geo.part(model, "Sign", Vector3.new(44, 7, 0.8), L(0, roofTop + 5, -HD + 1.2), Pal.Accent, M.SmoothPlastic, { Role = "Accent", CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(decor, "SignLeg", Vector3.new(0.5, 2, 0.5), L(s * 18, roofTop + 1.2, -HD + 1.6), DARK_FRAME, M.Metal)
	end
	Geo.decorate(Geo.part(decor, "SignGlow", Vector3.new(45, 0.3, 1), L(0, roofTop + 1.35, -HD + 1.2), Pal.LED, M.Neon))
	sign.CastShadow = false
	-- canopy over the door
	Geo.part(decor, "Canopy", Vector3.new(16, 0.5, 6), L(0, 11, -HD - 3), DARK_FRAME, M.Metal, { CanCollide = false })
	Geo.decorate(Geo.part(decor, "CanopyLight", Vector3.new(15, 0.1, 0.3), L(0, 10.7, -HD - 5.8), Pal.LED, M.Neon))
	Geo.decorate(Geo.part(decor, "EntryMat", Vector3.new(10, 0.04, 5), L(0, FY + 0.02, -HD + 3.5), Color3.fromRGB(20, 20, 22), M.Carpet))

	-- ================= stair core =================
	local core = Geo.folder(model, "StairCore")
	flight(core, L, CORE_X0 + 3.2, -16, 16, floorTop(1), floorTop(2))
	flight(core, L, CORE_X0 + 8.8, 16, -16, floorTop(2), floorTop(3))
	-- core partition walls (x = 26) with a doorway on each floor
	local function coreWall(f, z0, z1)
		local y = floorTop(f)
		local h = FH - SLAB
		Geo.part(core, "CoreWall", Vector3.new(0.6, h, z1 - z0), L(CORE_X0, y + h / 2, (z0 + z1) / 2), Color3.fromRGB(22, 23, 27), M.Plaster)
	end
	coreWall(1, -17.5, 20)
	coreWall(2, -20, 14)
	coreWall(3, -14, 20)
	-- glass between flight 2 and the stairwell drop on floor 2, rail on floor 3
	Geo.part(core, "StairGlass", Vector3.new(0.25, FH - SLAB, 33.5), L(CORE_X0 + 6, floorTop(2) + (FH - SLAB) / 2, 0.75), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.6 })
	Geo.part(core, "StairRail", Vector3.new(0.25, 3.6, 32), L(CORE_X0 + 6, floorTop(3) + 1.8, 0), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.5 })
	Geo.part(core, "StairRail", Vector3.new(6, 3.6, 0.25), L(CORE_X0 + 9, floorTop(3) + 1.8, 16), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.5 })

	-- floor 1: seal the space beside flight 1 so the gate is the only way up
	Geo.part(core, "CoreGlass", Vector3.new(0.25, FH - SLAB, 33.5), L(CORE_X0 + 6.3, floorTop(1) + (FH - SLAB) / 2, -0.75), Color3.fromRGB(170, 200, 220), M.Glass, { Transparency = 0.6 })
	Geo.part(core, "CoreWall", Vector3.new(CORE_X1 - CORE_X0 - 6.3, FH - SLAB, 0.6), L((CORE_X0 + 6.3 + CORE_X1) / 2, floorTop(1) + (FH - SLAB) / 2, -17.5), Color3.fromRGB(22, 23, 27), M.Plaster)

	-- floor gates (closed until the owner buys that floor)
	local gates = Geo.folder(model, "FloorGates")
	for f, g in ipairs({ { CORE_X0 + 3.2, -17.5, floorTop(1) }, { CORE_X0 + 8.8, 17.5, floorTop(2) } }) do
		local floorNum = f + 1
		local gate = Geo.part(gates, "Gate" .. floorNum, Vector3.new(6, 9, 0.4), L(g[1], g[3] + 4.5, g[2]), Color3.fromRGB(230, 60, 70), M.Neon, { Transparency = 0.35, CastShadow = false })
		gate:SetAttribute("Floor", floorNum)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			Geo.surfaceText(gate, face, "FLOOR " .. floorNum .. "\nLOCKED\nBuy it in the Shop", { Name = "GateText", PPS = 30 })
		end
	end

	-- ================= floors =================
	for f = 1, Gym.FLOORS do
		dressFloor(decor, model, L, f)
	end

	-- ================= ground-floor gameplay parts =================
	local desk = Geo.part(model, "FrontDesk", Vector3.new(10, 3.4, 2.6), L(-24, FY + 1.7, -25), Pal.Accent, M.SmoothPlastic, { Role = "Accent" })
	Geo.part(decor, "DeskTop", Vector3.new(10.4, 0.2, 3), desk.CFrame * CFrame.new(0, 1.8, 0), Pal.White, M.Marble, { CanCollide = false })
	local monitor = Geo.part(decor, "DeskMonitor", Vector3.new(1.4, 0.9, 0.1), desk.CFrame * CFrame.new(1.5, 2.45, 0.3) * CFrame.Angles(0, rad(180), 0), Pal.Black, M.SmoothPlastic, { CanCollide = false })
	Geo.decorate(Geo.part(decor, "DeskScreen", Vector3.new(1.25, 0.75, 0.02), monitor.CFrame * CFrame.new(0, 0, -0.06), Pal.Screen, M.Neon))
	Geo.decorate(Geo.part(model, "DeskSpawn", Vector3.new(1, 1, 1), L(-24, 3, -22.4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	Geo.decorate(Geo.part(model, "PlotSpawn", Vector3.new(1, 1, 1), L(0, 4, -26), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))

	-- owner's heavy bag ("Do a Rep" station)
	local bagCF = L(16, FY + 4.6, -25)
	Geo.decorate(Geo.part(decor, "BagChain", Vector3.new(0.1, FH - 9.6, 0.1), L(16, FY + (FH - SLAB + 8.6) / 2 + 0.5, -25), Pal.Steel, M.Metal))
	local bag = Geo.part(model, "WorkoutStation", Vector3.new(5.6, 2.2, 2.2), bagCF * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(150, 30, 34), M.Leather)
	bag.Shape = Enum.PartType.Cylinder
	Geo.decorate(Geo.cyl(decor, "BagBand", 0.4, 2.25, bagCF * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, rad(90)), Pal.Black, M.Leather))

	-- whole-building volume (a follower stepping inside is "home")
	Geo.decorate(Geo.part(model, "GymZone", Vector3.new(W - 2, Gym.H - 1, D - 2), L(0, FY + Gym.H / 2, 0), Pal.Black, M.SmoothPlastic, { Transparency = 1, CanCollide = false }))

	-- ================= stations =================
	local stations = Geo.folder(model, "Stations")
	for slot, pos in ipairs(Gym.LAYOUT) do
		local kind = Specs.SLOT_EXERCISES[slot]
		local cf = L(pos[1], floorTop(pos[4]), pos[2]) * CFrame.Angles(0, rad(pos[3]), 0)
		local st = Stations.Build(kind, slot, stations, cf)
		st:SetAttribute("Floor", pos[4])
	end

	return model
end

return Gym
