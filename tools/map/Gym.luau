--[[
	Gym — builds one complete gym lot: a glass fitness club that GROWS.

	  Floor 1 (free)   Cardio & Dumbbells : 3 treadmills, 3 bikes, 3 curl stations, 3 shoulder press
	  Floor 2 (bought) Machines           : 3 lat pulldowns, 3 cable rows, 3 leg extensions, 3 pull-up
	  Floor 3 (bought) Power Zone         : 3 squat racks, 3 deadlift platforms, 3 bench presses

	Everything that belongs to floor N (slab, glass, stairs up to it, machines,
	lights) lives in the folder FloorN, and each roof height lives in RoofN.
	PlotService keeps FloorN / RoofN hidden (in ServerStorage) until the owner
	buys that floor, so the building visibly gets taller.

	Layout: the front door lines up with a clear center aisle (x -10..-2) that
	runs straight to the back wall. Machines sit in groups of three on either
	side of it. The stair core is on the right (x 26..38); a side aisle
	(x 20..26) connects it to every floor.

	Plot-local space: origin at the building's floor center (ground level),
	-Z faces the conveyor (the entrance side), +Y up.
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
Gym.AISLE_X = -6 -- center of the entrance aisle (the door lines up with it)

local W, D, FH, FY = Gym.W, Gym.D, Gym.FLOOR_H, Gym.FLOOR_Y
local HW, HD = W / 2, D / 2
local CORE_X0, CORE_X1 = 26, 38
local SLAB = 1
local AX = Gym.AISLE_X

local function floorTop(f)
	return FY + (f - 1) * FH
end
Gym.floorTop = floorTop

-- ----------------------------------------------------------------------
-- Layout: each group = 3 identical machines side by side.
-- ----------------------------------------------------------------------
local LEFT = { -32.5, -23.5, -14.5 } -- left of the aisle
local RIGHT = { 1.5, 9, 16.5 } -- right of the aisle
local WIDE = { -27, -8.5, 10 } -- full-width rows for the big power equipment

-- per floor, in the same order as StationSpecs.FLOOR_GROUPS
local GROUP_PLACES = {
	{ -- floor 1
		{ LEFT, -8, 0 }, -- treadmills facing the glass
		{ RIGHT, -8, 0 }, -- bikes facing the glass
		{ LEFT, 18, 180 }, -- curls facing the mirror
		{ RIGHT, 18, 180 }, -- shoulder press facing the mirror
	},
	{ -- floor 2
		{ LEFT, -16, 0 }, -- lat pulldowns
		{ RIGHT, -16, 0 }, -- cable rows
		{ LEFT, 14, 0 }, -- leg extensions
		{ RIGHT, 14, 0 }, -- pull-up / dip assist
	},
	{ -- floor 3
		{ WIDE, -19, 0 }, -- squat racks
		{ WIDE, 0, 0 }, -- deadlift platforms
		{ WIDE, 18, 0 }, -- bench presses
	},
}

Gym.LAYOUT = {} -- [slot] = { x, z, yaw, floor, kind }
do
	local slot = 0
	for f, groups in ipairs(Specs.FLOOR_GROUPS) do
		for g, kind in ipairs(groups) do
			local place = GROUP_PLACES[f][g]
			for _, x in ipairs(place[1]) do
				slot += 1
				assert(Specs.SLOT_EXERCISES[slot] == kind, "layout/spec mismatch at slot " .. slot)
				Gym.LAYOUT[slot] = { x, place[2], place[3], f, kind }
			end
		end
	end
end

local DARK_FRAME = Color3.fromRGB(30, 31, 36)
local GLASS = Color3.fromRGB(170, 200, 220)

-- ----------------------------------------------------------------------
-- Helpers
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

-- One flight of stairs: invisible walkable ramp + floating steps + stringers
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
		Geo.decorate(Geo.tube(parent, "Handrail", L(x + s * 3.1, y0 + 3.6, z0).Position, L(x + s * 3.1, y1 + 3.6, z1).Position, 0.16, Pal.Chrome, M.Metal))
		for k = 0, 4 do
			local p = sa:Lerp(sb, k / 4)
			Geo.decorate(Geo.part(parent, "Baluster", Vector3.new(0.1, 3.4, 0.1), CFrame.new(p + Vector3.new(0, 1.7, 0)), Pal.Chrome, M.Metal))
		end
	end
end

-- Glass curtain wall from (x0,z0) to (x1,z1) for one floor. doorAt = distance
-- along the wall of the door's center (nil = no door).
local function curtain(parent, L, x0, z0, x1, z1, yBottom, yTop, doorAt, doorHalf)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local ux, uz = (x1 - x0) / len, (z1 - z0) / len
	local yaw = math.atan2(-uz, ux)
	local function at(t, y)
		return L(x0 + ux * t, y, z0 + uz * t) * CFrame.Angles(0, yaw, 0)
	end
	local h = yTop - yBottom
	local segs = { { 0, len } }
	if doorAt then
		segs = { { 0, doorAt - doorHalf }, { doorAt + doorHalf, len } }
		Geo.part(parent, "DoorHeader", Vector3.new(doorHalf * 2, h - 10, 0.6), at(doorAt, yBottom + 10 + (h - 10) / 2), DARK_FRAME, M.Metal, { Role = "Wall" })
		Geo.decorate(Geo.part(parent, "DoorGlow", Vector3.new(doorHalf * 2, 0.25, 0.7), at(doorAt, yBottom + 10), Pal.Accent, M.Neon, { Role = "Accent" }))
		for _, s in ipairs({ -1, 1 }) do
			Geo.part(parent, "DoorFrame", Vector3.new(0.6, 10, 0.7), at(doorAt + s * doorHalf, yBottom + 5), DARK_FRAME, M.Metal, { Role = "Wall" })
		end
	end
	for _, seg in ipairs(segs) do
		local sl = seg[2] - seg[1]
		if sl > 0.05 then
			Geo.part(parent, "Glass", Vector3.new(sl, h, 0.25), at((seg[1] + seg[2]) / 2, yBottom + h / 2), GLASS, M.Glass, { Transparency = 0.55 })
		end
	end
	local n = math.max(1, math.floor(len / 9.5 + 0.5))
	for k = 0, n do
		local t = k * len / n
		if not doorAt or math.abs(t - doorAt) > doorHalf + 0.3 then
			Geo.part(parent, "Mullion", Vector3.new(0.45, h, 0.5), at(t, yBottom + h / 2), DARK_FRAME, M.Metal, { Role = "Wall", CanCollide = false })
		end
	end
end

local function coreWall(parent, L, f, z0, z1)
	local h = FH - SLAB
	Geo.part(parent, "CoreWall", Vector3.new(0.6, h, z1 - z0), L(CORE_X0, floorTop(f) + h / 2, (z0 + z1) / 2), Color3.fromRGB(22, 23, 27), M.Plaster)
end

-- The building envelope for one floor (glass, frame, back wall, bands)
local function floorShell(parent, L, f)
	local y0 = floorTop(f) + (f == 1 and 0 or 0.5)
	local y1 = floorTop(f) + FH - SLAB - 0.5
	curtain(parent, L, -HW, -HD, HW, -HD, y0, y1, f == 1 and (HW + AX) or nil, 6)
	curtain(parent, L, -HW, HD - 1, -HW, -HD, y0, y1)
	curtain(parent, L, HW, -HD, HW, HD - 1, y0, y1)
	local wallName = f == 1 and "WallBack" or ("WallBack" .. f)
	Geo.part(f == 1 and parent.Parent or parent, wallName, Vector3.new(W, FH, 1), L(0, floorTop(f) - SLAB + FH / 2 + (f == 1 and SLAB / 2 or 0), HD - 0.5), Pal.Wall, M.Plaster, { Role = "Wall" })
	for _, c in ipairs({ { -HW, -HD }, { HW, -HD }, { -HW, HD }, { HW, HD } }) do
		Geo.part(parent, "CornerColumn", Vector3.new(1.6, FH, 1.6), L(c[1], floorTop(f) - (f == 1 and FY or SLAB) + FH / 2, c[2]), DARK_FRAME, M.Metal, { Role = "Wall" })
	end
	if f > 1 then
		local y = floorTop(f) - SLAB / 2
		Geo.part(parent, "BandFront", Vector3.new(W + 1, 2, 1), L(0, y, -HD), DARK_FRAME, M.Metal, { Role = "Wall" })
		Geo.part(parent, "BandLeft", Vector3.new(1, 2, D + 1), L(-HW, y, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
		Geo.part(parent, "BandRight", Vector3.new(1, 2, D + 1), L(HW, y, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
	end
end

-- Roof sitting on top of floor `level` (only one roof is shown at a time)
local function roof(parent, L, level)
	local top = floorTop(level) + FH
	slab(parent, L, "RoofSlab", top, nil, Color3.fromRGB(40, 41, 46), M.Concrete)
	Geo.part(parent, "RoofEdge", Vector3.new(W + 3, 1.6, D + 3), L(0, top + 0.3, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(parent, "SignLeg", Vector3.new(0.5, 2, 0.5), L(s * 18, top + 1.2, -HD + 1.6), DARK_FRAME, M.Metal)
	end
	Geo.decorate(Geo.part(parent, "SignGlow", Vector3.new(45, 0.3, 1), L(0, top + 1.35, -HD + 1.2), Pal.LED, M.Neon))
	-- rooftop AC units
	for i, x in ipairs({ -24, -12 }) do
		Geo.part(parent, "ACUnit", Vector3.new(6, 3, 5), L(x, top + 2.6, 18 - i * 2), Color3.fromRGB(150, 152, 156), M.Metal)
	end
end

local function dressFloor(parent, L, f)
	local y = floorTop(f)
	local ceil = y + FH - SLAB

	-- clear walkways
	if f == 3 then
		Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(58, 0.03, 6), L(-9, y + 0.015, -27.5), Color3.fromRGB(34, 36, 40), M.Rubber))
		for _, z in ipairs({ -9.5, 9.5 }) do
			Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(58, 0.03, 4), L(-9, y + 0.015, z), Color3.fromRGB(34, 36, 40), M.Rubber))
		end
	else
		local z0 = f == 1 and -19 or -HD + 0.5
		Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(8, 0.03, HD - 1.5 - z0), L(AX, y + 0.015, (z0 + HD - 1.5) / 2), Color3.fromRGB(34, 36, 40), M.Rubber))
		for _, s in ipairs({ -1, 1 }) do
			Geo.decorate(Geo.part(parent, "AisleLine", Vector3.new(0.2, 0.04, HD - 1.5 - z0), L(AX + s * 4, y + 0.02, (z0 + HD - 1.5) / 2), Color3.fromRGB(70, 100, 130), M.SmoothPlastic, { Role = "AccentDim" }))
		end
		-- cross aisle between the front and back groups
		local cz = f == 1 and 6.5 or -1
		Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(58, 0.03, 4), L(-9, y + 0.016, cz), Color3.fromRGB(34, 36, 40), M.Rubber))
	end
	-- side aisle to the stairs
	Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(5.4, 0.03, D - 3), L(23, y + 0.015, 0), Color3.fromRGB(34, 36, 40), M.Rubber))
	if f == 1 then
		Geo.decorate(Geo.part(parent, "LobbyFloor", Vector3.new(W - 14, 0.03, 12), L(-6, y + 0.018, -25), Color3.fromRGB(210, 205, 196), M.Marble))
	end

	-- mirror wall + dumbbell rack along the back wall (rack sits either side of the aisle end)
	local mirror = Geo.part(parent, "Mirror", Vector3.new(58, 7.5, 0.15), L(-8, y + 4.6, HD - 1.3), Color3.fromRGB(205, 212, 220), M.Glass, { Reflectance = 0.55, CanCollide = false })
	mirror.CastShadow = false
	local rackZ = HD - 3.3
	for _, seg in ipairs({ { -34, -12 }, { 0, 18 } }) do
		local cx, len = (seg[1] + seg[2]) / 2, seg[2] - seg[1]
		Geo.part(parent, "DumbbellRack", Vector3.new(len, 0.25, 2.4), L(cx, y + 1.7, rackZ), Pal.Frame, M.Metal, { CanCollide = false })
		for _, x in ipairs({ seg[1] + 0.5, cx, seg[2] - 0.5 }) do
			Geo.decorate(Geo.part(parent, "RackLeg", Vector3.new(0.4, 1.7, 2.2), L(x, y + 0.85, rackZ), Pal.FrameDark, M.Metal))
		end
		local n = math.floor(len / 3)
		for i = 0, n - 1 do
			local cf = L(seg[1] + 1.5 + i * 3, y + 2.1, rackZ)
			local size = 0.45 + (i % 5) * 0.06
			Geo.decorate(Geo.cyl(parent, "RackBellHandle", 0.55, 0.15, cf, Pal.Steel, M.Metal))
			for _, s in ipairs({ -1, 1 }) do
				Geo.decorate(Geo.cyl(parent, "RackBellHead", 0.3, size, cf * CFrame.new(s * 0.42, 0, 0), Pal.Plate, M.Rubber))
			end
		end
	end

	-- stair-core feature wall: blue stripes + floor sign
	for i = 0, 13 do
		local z = 18.5 - i * 2.6
		if not (f == 2 and z > 13.5) and not (f ~= 2 and z < -13.5) then
			Geo.decorate(Geo.part(parent, "StripePanel", Vector3.new(0.2, 9, 1.2), L(CORE_X0 - 0.45, y + 5.5, z), Pal.Accent, M.SmoothPlastic, { Role = "Accent" }))
		end
	end
	local sign = Geo.decorate(Geo.part(parent, "FloorSign", Vector3.new(0.2, 2.2, 16), L(CORE_X0 - 0.5, y + 11.6, f == 2 and -4 or 4), Pal.Black, M.SmoothPlastic))
	Geo.surfaceText(sign, Enum.NormalId.Left, "FLOOR " .. f .. "  ·  " .. Specs.FLOOR_NAMES[f], { Color = Color3.fromRGB(235, 242, 255), PPS = 24 })

	-- ceiling: black panel, ducts, LED fixtures with real light
	Geo.decorate(Geo.part(parent, "Ceiling", Vector3.new(W - 1, 0.1, D - 1), L(0, ceil - 0.06, 0), Pal.Ceiling, M.SmoothPlastic))
	for _, z in ipairs({ -14, 12 }) do
		Geo.decorate(Geo.tube(parent, "Duct", L(-HW + 2, ceil - 1.5, z).Position, L(CORE_X0 - 1, ceil - 1.5, z).Position, 1.8, Pal.Duct, M.Foil))
	end
	for _, z in ipairs({ -20, -2, 16 }) do
		local fx = Geo.decorate(Geo.part(parent, "LEDStrip", Vector3.new(56, 0.18, 0.5), L(-8, ceil - 0.25, z), Pal.LED, M.Neon))
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

	local floors = {}
	for f = 1, Gym.FLOORS do
		floors[f] = Geo.folder(model, "Floor" .. f)
		floors[f]:SetAttribute("Floor", f)
	end
	local roofs = {}
	for f = 1, Gym.FLOORS do
		roofs[f] = Geo.folder(model, "Roof" .. f)
		roofs[f]:SetAttribute("Level", f)
	end

	-- ================= floor 1 (always there) =================
	local floor = Geo.part(model, "Floor", Vector3.new(W, FY, D), L(0, FY / 2, 0), Pal.RubberFloor, M.Rubber)
	model.PrimaryPart = floor
	floorShell(floors[1], L, 1)
	coreWall(floors[1], L, 1, -17.5, 20)
	Geo.part(floors[1], "Canopy", Vector3.new(16, 0.5, 6), L(AX, 11, -HD - 3), DARK_FRAME, M.Metal, { CanCollide = false })
	Geo.decorate(Geo.part(floors[1], "CanopyLight", Vector3.new(15, 0.1, 0.3), L(AX, 10.7, -HD - 5.8), Pal.LED, M.Neon))
	Geo.decorate(Geo.part(floors[1], "EntryMat", Vector3.new(10, 0.04, 5), L(AX, FY + 0.02, -HD + 3.5), Color3.fromRGB(20, 20, 22), M.Carpet))

	-- ================= floor 2 (bought) =================
	slab(floors[2], L, "Slab2", floorTop(2), { CORE_X0, CORE_X0 + 6, -16, 16 }, Pal.RubberFloor, M.Rubber)
	floorShell(floors[2], L, 2)
	flight(floors[2], L, CORE_X0 + 3.2, -16, 16, floorTop(1), floorTop(2))
	Geo.part(floors[2], "CoreGlass", Vector3.new(0.25, FH - SLAB, 33.5), L(CORE_X0 + 6.3, floorTop(1) + (FH - SLAB) / 2, -0.75), GLASS, M.Glass, { Transparency = 0.6 })
	Geo.part(floors[2], "CoreWall", Vector3.new(CORE_X1 - CORE_X0 - 6.3, FH - SLAB, 0.6), L((CORE_X0 + 6.3 + CORE_X1) / 2, floorTop(1) + (FH - SLAB) / 2, -17.5), Color3.fromRGB(22, 23, 27), M.Plaster)
	coreWall(floors[2], L, 2, -20, 14)
	Geo.part(floors[2], "StairGlass", Vector3.new(0.25, FH - SLAB, 33.5), L(CORE_X0 + 6, floorTop(2) + (FH - SLAB) / 2, 0.75), GLASS, M.Glass, { Transparency = 0.6 })

	-- ================= floor 3 (bought) =================
	slab(floors[3], L, "Slab3", floorTop(3), { CORE_X0 + 6, CORE_X1, -16, 16 }, Pal.RubberFloor, M.Rubber)
	floorShell(floors[3], L, 3)
	flight(floors[3], L, CORE_X0 + 8.8, 16, -16, floorTop(2), floorTop(3))
	coreWall(floors[3], L, 3, -14, 20)
	Geo.part(floors[3], "StairRail", Vector3.new(0.25, 3.6, 32), L(CORE_X0 + 6, floorTop(3) + 1.8, 0), GLASS, M.Glass, { Transparency = 0.5 })
	Geo.part(floors[3], "StairRail", Vector3.new(6, 3.6, 0.25), L(CORE_X0 + 9, floorTop(3) + 1.8, 16), GLASS, M.Glass, { Transparency = 0.5 })

	for f = 1, Gym.FLOORS do
		dressFloor(floors[f], L, f)
		roof(roofs[f], L, f)
	end

	-- rooftop sign (PlotService lifts it onto whichever roof is showing)
	local sign = Geo.part(model, "Sign", Vector3.new(44, 7, 0.8), L(0, floorTop(1) + FH + 5, -HD + 1.2), Pal.Accent, M.SmoothPlastic, { Role = "Accent", CanCollide = false })
	sign.CastShadow = false
	sign:SetAttribute("FloorHeight", FH)

	-- ================= ground-floor gameplay parts =================
	local desk = Geo.part(model, "FrontDesk", Vector3.new(10, 3.4, 2.6), L(-24, FY + 1.7, -25), Pal.Accent, M.SmoothPlastic, { Role = "Accent" })
	Geo.part(floors[1], "DeskTop", Vector3.new(10.4, 0.2, 3), desk.CFrame * CFrame.new(0, 1.8, 0), Pal.White, M.Marble, { CanCollide = false })
	local monitor = Geo.part(floors[1], "DeskMonitor", Vector3.new(1.4, 0.9, 0.1), desk.CFrame * CFrame.new(1.5, 2.45, 0.3) * CFrame.Angles(0, rad(180), 0), Pal.Black, M.SmoothPlastic, { CanCollide = false })
	Geo.decorate(Geo.part(floors[1], "DeskScreen", Vector3.new(1.25, 0.75, 0.02), monitor.CFrame * CFrame.new(0, 0, -0.06), Pal.Screen, M.Neon))
	Geo.decorate(Geo.part(model, "DeskSpawn", Vector3.new(1, 1, 1), L(-24, 3, -22.4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	Geo.decorate(Geo.part(model, "PlotSpawn", Vector3.new(1, 1, 1), L(AX, 4, -26), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))

	-- owner's heavy bag ("Do a Rep" station)
	local bagCF = L(16, FY + 4.6, -25)
	Geo.decorate(Geo.part(floors[1], "BagChain", Vector3.new(0.1, FH - 9.6, 0.1), L(16, FY + (FH - SLAB + 8.6) / 2 + 0.5, -25), Pal.Steel, M.Metal))
	local bag = Geo.part(model, "WorkoutStation", Vector3.new(5.6, 2.2, 2.2), bagCF * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(150, 30, 34), M.Leather)
	bag.Shape = Enum.PartType.Cylinder
	Geo.decorate(Geo.cyl(floors[1], "BagBand", 0.4, 2.25, bagCF * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, rad(90)), Pal.Black, M.Leather))

	-- whole-building volume (a follower stepping inside is "home")
	Geo.decorate(Geo.part(model, "GymZone", Vector3.new(W - 2, Gym.H - 1, D - 2), L(0, FY + Gym.H / 2, 0), Pal.Black, M.SmoothPlastic, { Transparency = 1, CanCollide = false }))

	-- ================= stations =================
	for f = 1, Gym.FLOORS do
		Geo.folder(floors[f], "Stations")
	end
	for slot, pos in ipairs(Gym.LAYOUT) do
		local cf = L(pos[1], floorTop(pos[4]), pos[2]) * CFrame.Angles(0, rad(pos[3]), 0)
		local st = Stations.Build(pos[5], slot, floors[pos[4]].Stations, cf)
		st:SetAttribute("Floor", pos[4])
	end

	return model
end

return Gym
