--[[
	Gym — builds one complete gym lot: a slim glass fitness club that GROWS.

	  Floor 1 (free)   Cardio & Dumbbells : 3 treadmills, 3 bikes, 3 curl stations, 3 shoulder press
	  Floor 2 (bought) Machines           : 3 lat pulldowns, 3 cable rows, 3 leg extensions, 3 pull-up
	  Floor 3 (bought) Power Zone         : 3 squat racks, 3 deadlift platforms, 3 bench presses

	Everything that belongs to floor N (slab, glass, the stairs up to it,
	machines, lights) lives in the folder FloorN, and each roof height lives
	in RoofN. PlotService keeps FloorN / RoofN hidden (in ServerStorage) until
	the owner buys that floor, so the building visibly gets taller.

	Stairs: a U-shaped switchback in the back-right corner (open risers, wood
	treads, black steel stringers, cable railings): half a flight up to a
	landing against the back wall, then the second half turns back.

	Layout: the front door lines up with a clear center aisle that runs
	straight to the back wall; machines sit in groups of three either side.

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

Gym.W = 56 -- frontage (along the carpet)
Gym.D = 72 -- depth
Gym.FLOOR_H = 16
Gym.FLOORS = 3
Gym.FLOOR_Y = 0.4
Gym.H = Gym.FLOOR_H * Gym.FLOORS
Gym.AISLE_X = 0 -- entrance aisle center (the door lines up with it)

local W, D, FH, FY = Gym.W, Gym.D, Gym.FLOOR_H, Gym.FLOOR_Y
local HW, HD = W / 2, D / 2
local SLAB = 1
local AX = Gym.AISLE_X

-- stair corner (back-right): two 5-wide flights side by side + a landing
local FLIGHT_W = 5
local STAIR_X0 = HW - 1 - FLIGHT_W * 2 -- 17
local STAIR_X1 = HW - 1 -- 27
local LANDING_D = 5
local RUN = 15
local STAIR_Z1 = HD - 1 -- back wall face (35)
local LANDING_Z0 = STAIR_Z1 - LANDING_D -- 30
local STAIR_Z0 = LANDING_Z0 - RUN -- 15 (front edge of the stair corner)
Gym.STAIR = { X0 = STAIR_X0, X1 = STAIR_X1, Z0 = STAIR_Z0, Z1 = STAIR_Z1 }

local function floorTop(f)
	return FY + (f - 1) * FH
end
Gym.floorTop = floorTop

-- ----------------------------------------------------------------------
-- Layout: each group = 3 identical machines side by side.
-- ----------------------------------------------------------------------
local LEFT = { -22.5, -15.5, -8.5 }
local RIGHT = { 8.5, 15.5, 22.5 }
local WIDE = { -19, 0, 19 }

local GROUP_PLACES = {
	{ -- floor 1 (lobby at the front)
		{ LEFT, -14, 0 }, -- treadmills facing the glass
		{ RIGHT, -14, 0 }, -- bikes facing the glass
		{ LEFT, 8, 180 }, -- curls facing the mirror
		{ RIGHT, 8, 180 }, -- shoulder press facing the mirror
	},
	{ -- floor 2
		{ LEFT, -20, 0 }, -- lat pulldowns
		{ RIGHT, -20, 0 }, -- cable rows
		{ LEFT, 6, 0 }, -- leg extensions
		{ RIGHT, 6, 0 }, -- pull-up / dip assist
	},
	{ -- floor 3
		{ WIDE, -26, 0 }, -- squat racks
		{ WIDE, -8, 0 }, -- deadlift platforms
		{ WIDE, 9, 0 }, -- bench presses
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
local STEEL_BLACK = Color3.fromRGB(24, 24, 27)
local TREAD_WOOD = Color3.fromRGB(196, 158, 108)

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

-- Horizontal cable railing between two floor-level points (a, b in world),
-- 3.4 tall, following any slope between them.
local function cableRail(parent, a, b, posts)
	posts = posts or math.max(2, math.floor((b - a).Magnitude / 4) + 1)
	for k = 0, posts - 1 do
		local p = a:Lerp(b, k / (posts - 1))
		Geo.decorate(Geo.part(parent, "RailPost", Vector3.new(0.18, 3.5, 0.18), CFrame.new(p + Vector3.new(0, 1.75, 0)), STEEL_BLACK, M.Metal))
	end
	Geo.tube(parent, "RailTop", a + Vector3.new(0, 3.5, 0), b + Vector3.new(0, 3.5, 0), 0.2, STEEL_BLACK, M.Metal)
	for h = 0.7, 2.9, 0.55 do
		Geo.decorate(Geo.tube(parent, "RailCable", a + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0), 0.05, Color3.fromRGB(150, 152, 158), M.Metal))
	end
end

-- One flight: invisible walkable ramp + open-riser wood treads + black
-- stringers + a cable railing on the open side(s).
local function flight(parent, L, x, z0, z1, y0, y1, railSides)
	local dir = z1 > z0 and 1 or -1
	local a = L(x, y0 + 0.5, z0).Position
	local b = L(x, y1 + 0.5, z1).Position
	local ramp = Geo.part(parent, "StairRamp", Vector3.new(FLIGHT_W, 0.6, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.3, 0), Pal.Black, M.SmoothPlastic, { Transparency = 1 })
	ramp.CastShadow = false
	local steps = math.floor(y1 - y0 + 0.5)
	local run = math.abs(z1 - z0) / steps
	for i = 1, steps do
		local zc = z0 + dir * (i - 0.5) * run
		Geo.decorate(Geo.part(parent, "Tread", Vector3.new(FLIGHT_W - 0.4, 0.3, run * 0.92), L(x, y0 + i - 0.15, zc), TREAD_WOOD, M.WoodPlanks))
	end
	for _, s in ipairs({ -1, 1 }) do
		local sa = L(x + s * (FLIGHT_W / 2 - 0.1), y0 + 0.1, z0).Position
		local sb = L(x + s * (FLIGHT_W / 2 - 0.1), y1 + 0.1, z1).Position
		Geo.decorate(Geo.beam(parent, "Stringer", sa, sb, 0.3, STEEL_BLACK, M.Metal)).Size = Vector3.new((sb - sa).Magnitude, 1.2, 0.25)
		if railSides and railSides[s] then
			cableRail(parent, sa + Vector3.new(0, 0.5, 0), sb + Vector3.new(0, 0.5, 0), 5)
		end
	end
end

-- Full floor-to-floor stair: flight up to the landing, landing, flight back.
local function switchback(parent, L, fromFloor)
	local y0 = floorTop(fromFloor)
	local yMid = y0 + FH / 2
	local y1 = y0 + FH
	local xA = STAIR_X0 + FLIGHT_W / 2 -- first flight (inner, toward the room)
	local xB = STAIR_X1 - FLIGHT_W / 2 -- second flight (against the side glass)
	flight(parent, L, xA, STAIR_Z0, LANDING_Z0, y0, yMid, { [-1] = true })
	-- landing platform against the back wall
	local land = Geo.part(parent, "Landing", Vector3.new(FLIGHT_W * 2, 0.5, LANDING_D), L((STAIR_X0 + STAIR_X1) / 2, yMid + 0.25, (LANDING_Z0 + STAIR_Z1) / 2), TREAD_WOOD, M.WoodPlanks)
	Geo.decorate(Geo.part(parent, "LandingEdge", Vector3.new(FLIGHT_W * 2, 1, 0.3), L((STAIR_X0 + STAIR_X1) / 2, yMid - 0.3, LANDING_Z0 + 0.15), STEEL_BLACK, M.Metal))
	land.CastShadow = true
	cableRail(parent, L(STAIR_X0 + 0.1, yMid + 0.5, LANDING_Z0).Position, L(STAIR_X0 + 0.1, yMid + 0.5, STAIR_Z1 - 0.3).Position, 3)
	-- steel posts holding the landing
	for _, x in ipairs({ STAIR_X0 + 0.3, STAIR_X1 - 0.3 }) do
		Geo.part(parent, "LandingPost", Vector3.new(0.35, FH / 2, 0.35), L(x, y0 + FH / 4, LANDING_Z0 + 0.3), STEEL_BLACK, M.Metal)
	end
	flight(parent, L, xB, LANDING_Z0, STAIR_Z0, yMid, y1, { [-1] = true })
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

-- Roof sitting on top of floor `level` (only one roof is shown at a time).
-- On floors 2+ it also carries the railing that closes off the stair opening
-- (the next floor's stairs would start there once it's bought).
local function roof(parent, L, level)
	local top = floorTop(level) + FH
	slab(parent, L, "RoofSlab", top, nil, Color3.fromRGB(40, 41, 46), M.Concrete)
	Geo.part(parent, "RoofEdge", Vector3.new(W + 3, 1.6, D + 3), L(0, top + 0.3, 0), DARK_FRAME, M.Metal, { Role = "Wall" })
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(parent, "SignLeg", Vector3.new(0.5, 2, 0.5), L(s * 15, top + 1.2, -HD + 1.6), DARK_FRAME, M.Metal)
	end
	Geo.decorate(Geo.part(parent, "SignGlow", Vector3.new(40, 0.3, 1), L(0, top + 1.35, -HD + 1.2), Pal.LED, M.Neon))
	for i, x in ipairs({ -16, -6 }) do
		Geo.part(parent, "ACUnit", Vector3.new(6, 3, 5), L(x, top + 2.6, 20 - i * 2), Color3.fromRGB(150, 152, 156), M.Metal)
	end
	if level > 1 then
		local y = floorTop(level)
		cableRail(parent, L(STAIR_X0, y, STAIR_Z0).Position, L(STAIR_X0 + FLIGHT_W, y, STAIR_Z0).Position, 2)
	end
end

local function dressFloor(parent, L, f)
	local y = floorTop(f)
	local ceil = y + FH - SLAB
	local aisleColor = Color3.fromRGB(34, 36, 40)

	-- clear walkways
	if f == 3 then
		for _, z in ipairs({ -32.5, -17, 1 }) do
			Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(W - 3, 0.03, 4), L(0, y + 0.015, z), aisleColor, M.Rubber))
		end
	else
		local z0 = f == 1 and -24 or -HD + 0.5
		Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(8, 0.03, HD - 1.5 - z0), L(AX, y + 0.015, (z0 + HD - 1.5) / 2), aisleColor, M.Rubber))
		for _, s in ipairs({ -1, 1 }) do
			Geo.decorate(Geo.part(parent, "AisleLine", Vector3.new(0.2, 0.04, HD - 1.5 - z0), L(AX + s * 4, y + 0.02, (z0 + HD - 1.5) / 2), Color3.fromRGB(70, 100, 130), M.SmoothPlastic, { Role = "AccentDim" }))
		end
		local cz = f == 1 and -3 or -8
		Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(W - 3, 0.03, 4), L(0, y + 0.016, cz), aisleColor, M.Rubber))
	end
	-- path from the aisle to the stairs
	Geo.decorate(Geo.part(parent, "Aisle", Vector3.new(STAIR_X1 - 4, 0.03, 4), L((4 + STAIR_X1) / 2, y + 0.017, STAIR_Z0 - 2.5), aisleColor, M.Rubber))
	if f == 1 then
		Geo.decorate(Geo.part(parent, "LobbyFloor", Vector3.new(W - 3, 0.03, 11), L(0, y + 0.018, -30), Color3.fromRGB(210, 205, 196), M.Marble))
	end

	-- mirror wall + dumbbell racks on the back wall (left of the stairs, around the aisle end)
	local mirror = Geo.part(parent, "Mirror", Vector3.new(STAIR_X0 + HW - 2, 7.5, 0.15), L((-HW + 1 + STAIR_X0 - 1) / 2, y + 4.6, HD - 1.3), Color3.fromRGB(205, 212, 220), M.Glass, { Reflectance = 0.55, CanCollide = false })
	mirror.CastShadow = false
	local rackZ = HD - 3.3
	for _, seg in ipairs({ { -26, -6 }, { 6, 15 } }) do
		local cx, len = (seg[1] + seg[2]) / 2, seg[2] - seg[1]
		Geo.part(parent, "DumbbellRack", Vector3.new(len, 0.25, 2.4), L(cx, y + 1.7, rackZ), Pal.Frame, M.Metal, { CanCollide = false })
		for _, x in ipairs({ seg[1] + 0.5, cx, seg[2] - 0.5 }) do
			Geo.decorate(Geo.part(parent, "RackLeg", Vector3.new(0.4, 1.7, 2.2), L(x, y + 0.85, rackZ), Pal.FrameDark, M.Metal))
		end
		for i = 0, math.floor(len / 3) - 1 do
			local cf = L(seg[1] + 1.5 + i * 3, y + 2.1, rackZ)
			local size = 0.45 + (i % 5) * 0.06
			Geo.decorate(Geo.cyl(parent, "RackBellHandle", 0.55, 0.15, cf, Pal.Steel, M.Metal))
			for _, s in ipairs({ -1, 1 }) do
				Geo.decorate(Geo.cyl(parent, "RackBellHead", 0.3, size, cf * CFrame.new(s * 0.42, 0, 0), Pal.Plate, M.Rubber))
			end
		end
	end
	-- floor sign + accent strip above the mirror
	local sign = Geo.decorate(Geo.part(parent, "FloorSign", Vector3.new(26, 2.4, 0.2), L(-8, y + 10.6, HD - 1.15), Pal.Black, M.SmoothPlastic))
	Geo.surfaceText(sign, Enum.NormalId.Front, "FLOOR " .. f .. "  ·  " .. Specs.FLOOR_NAMES[f], { Color = Color3.fromRGB(235, 242, 255), PPS = 24 })
	Geo.decorate(Geo.part(parent, "AccentStrip", Vector3.new(STAIR_X0 + HW - 2, 0.3, 0.2), L((-HW + 1 + STAIR_X0 - 1) / 2, y + 8.9, HD - 1.15), Pal.Accent, M.Neon, { Role = "Accent" }))

	-- ceiling: black panel, ducts, LED fixtures with real light
	Geo.decorate(Geo.part(parent, "Ceiling", Vector3.new(W - 1, 0.1, D - 1), L(0, ceil - 0.06, 0), Pal.Ceiling, M.SmoothPlastic))
	for _, x in ipairs({ -14, 8 }) do
		Geo.decorate(Geo.tube(parent, "Duct", L(x, ceil - 1.5, -HD + 2).Position, L(x, ceil - 1.5, STAIR_Z0 - 2).Position, 1.8, Pal.Duct, M.Foil))
	end
	for _, x in ipairs({ -18, 0, 18 }) do
		local fx = Geo.decorate(Geo.part(parent, "LEDStrip", Vector3.new(0.5, 0.18, 54), L(x, ceil - 0.25, -6), Pal.LED, M.Neon))
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

	local hole = { STAIR_X0, STAIR_X1 + 1, STAIR_Z0, HD }

	-- ================= floor 1 (always there) =================
	local floor = Geo.part(model, "Floor", Vector3.new(W, FY, D), L(0, FY / 2, 0), Pal.RubberFloor, M.Rubber)
	model.PrimaryPart = floor
	floorShell(floors[1], L, 1)
	Geo.part(floors[1], "Canopy", Vector3.new(16, 0.5, 6), L(AX, 11, -HD - 3), DARK_FRAME, M.Metal, { CanCollide = false })
	Geo.decorate(Geo.part(floors[1], "CanopyLight", Vector3.new(15, 0.1, 0.3), L(AX, 10.7, -HD - 5.8), Pal.LED, M.Neon))
	Geo.decorate(Geo.part(floors[1], "EntryMat", Vector3.new(10, 0.04, 5), L(AX, FY + 0.02, -HD + 3.5), Color3.fromRGB(20, 20, 22), M.Carpet))

	-- ================= floors 2 and 3 (bought): slab + envelope + the stairs up to them =================
	for f = 2, Gym.FLOORS do
		slab(floors[f], L, "Slab" .. f, floorTop(f), hole, Pal.RubberFloor, M.Rubber)
		floorShell(floors[f], L, f)
		switchback(floors[f], L, f - 1)
		-- rail along the open side of the stairwell on this floor
		cableRail(floors[f], L(STAIR_X0, floorTop(f), STAIR_Z0 + 0.2).Position, L(STAIR_X0, floorTop(f), HD - 1.2).Position)
	end

	for f = 1, Gym.FLOORS do
		dressFloor(floors[f], L, f)
		roof(roofs[f], L, f)
	end

	-- rooftop sign (PlotService lifts it onto whichever roof is showing)
	local sign = Geo.part(model, "Sign", Vector3.new(40, 7, 0.8), L(0, floorTop(1) + FH + 5, -HD + 1.2), Pal.Accent, M.SmoothPlastic, { Role = "Accent", CanCollide = false })
	sign.CastShadow = false
	sign:SetAttribute("FloorHeight", FH)

	-- ================= ground-floor gameplay parts =================
	local desk = Geo.part(model, "FrontDesk", Vector3.new(10, 3.4, 2.6), L(-17, FY + 1.7, -30), Pal.Accent, M.SmoothPlastic, { Role = "Accent" })
	Geo.part(floors[1], "DeskTop", Vector3.new(10.4, 0.2, 3), desk.CFrame * CFrame.new(0, 1.8, 0), Pal.White, M.Marble, { CanCollide = false })
	local monitor = Geo.part(floors[1], "DeskMonitor", Vector3.new(1.4, 0.9, 0.1), desk.CFrame * CFrame.new(1.5, 2.45, 0.3) * CFrame.Angles(0, rad(180), 0), Pal.Black, M.SmoothPlastic, { CanCollide = false })
	Geo.decorate(Geo.part(floors[1], "DeskScreen", Vector3.new(1.25, 0.75, 0.02), monitor.CFrame * CFrame.new(0, 0, -0.06), Pal.Screen, M.Neon))
	Geo.decorate(Geo.part(model, "DeskSpawn", Vector3.new(1, 1, 1), L(-17, 3, -27.4), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	Geo.decorate(Geo.part(model, "PlotSpawn", Vector3.new(1, 1, 1), L(AX, 4, -30), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))

	-- owner's heavy bag ("Do a Rep" station)
	local bagCF = L(17, FY + 4.6, -30)
	Geo.decorate(Geo.part(floors[1], "BagChain", Vector3.new(0.1, FH - 9.6, 0.1), L(17, FY + (FH - SLAB + 8.6) / 2 + 0.5, -30), Pal.Steel, M.Metal))
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
