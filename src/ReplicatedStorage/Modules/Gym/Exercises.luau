--[[
	Exercises
	Procedural, deterministic exercise animation. Every function is a pure
	function of time, so every client computes the same motion from
	workspace:GetServerTimeNow() with no network traffic.

	Each exercise:  Exercises[name](rig, S, t, P) -> E
	  rig : RigSolver (already reset)
	  S   : station context { Base = CFrame, Spec = table, RestLocal = {[name] = CFrame} }
	  t   : seconds since the athlete sat down (plus a per-athlete offset)
	  P   : per-athlete params from Exercises.Params(seed)
	  E   : { Moves = {[movingName] = worldCFrame}, Cables = {[cableName] = {a, b}} }

	Realism comes from: world-space IK (hands stay locked on bars/handles, feet
	stay planted), real set structure (unrack -> reps -> rerack -> rest),
	asymmetric rep tempo (fast lift, slow controlled lowering, pauses), fatigue
	(last reps grind slower), breathing, and per-athlete variation.
]]

local Specs = require(script.Parent.StationSpecs)

local Exercises = {}

local rad = math.rad
local sin, cos, pi = math.sin, math.cos, math.pi
local IDENTITY = CFrame.new()

-- ----------------------------------------------------------------------
-- Math helpers
-- ----------------------------------------------------------------------
local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function smoother(x)
	x = clamp01(x)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function vlerp(a, b, t)
	return a:Lerp(b, t)
end

-- Rotate a station-local CFrame about a pivot point around the local X axis.
local function rotateAboutX(localCF, pivot, angle)
	return CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot) * localCF
end

-- Cheap smooth noise (deterministic)
local function wobble(seed, t, freq)
	return math.noise(seed * 0.173 + 0.5, t * freq, 0.5)
end

-- ----------------------------------------------------------------------
-- Per-athlete variation
-- ----------------------------------------------------------------------
function Exercises.Params(seed)
	seed = seed or 1
	local r = Random.new(seed)
	return {
		Seed = seed,
		Reps = r:NextInteger(7, 11),
		Rest = r:NextNumber(6, 11),
		Tempo = r:NextNumber(0.9, 1.12), -- >1 = slower reps
		Offset = r:NextNumber(0, 40),
		Stride = r:NextNumber(0.95, 1.05),
		Look = r:NextNumber(-1, 1),
	}
end

-- ----------------------------------------------------------------------
-- Set timeline:  setup -> reps -> finish -> rest -> (repeat)
-- ----------------------------------------------------------------------
local function timeline(t, P, setup, rep, finish)
	rep *= P.Tempo
	local total = setup + P.Reps * rep + finish + P.Rest
	local u = t % total
	if u < setup then
		return "setup", u / setup, 0, u
	end
	u -= setup
	if u < P.Reps * rep then
		local i = math.floor(u / rep)
		return "rep", (u - i * rep) / rep, i, u
	end
	u -= P.Reps * rep
	if u < finish then
		return "finish", u / finish, P.Reps, u
	end
	u -= finish
	return "rest", u / P.Rest, 0, u
end

-- One rep: 0 -> 1 -> 0 displacement.
-- f = { out, holdOut, back } fractions (rest of the rep is a pause at 0).
-- Fatigue stretches the working half on the last reps.
local function repCurve(ph, i, n, f, workIsBack)
	local fat = (i / math.max(n - 1, 1)) ^ 3
	local a, b, c = f[1], f[2], f[3]
	if workIsBack then
		c *= 1 + 0.45 * fat
	else
		a *= 1 + 0.45 * fat
	end
	local total = a + b + c
	if total > 0.97 then
		local k = 0.97 / total
		a, b, c = a * k, b * k, c * k
	end
	if ph < a then
		return smoother(ph / a), workIsBack and 0 or 1
	end
	ph -= a
	if ph < b then
		return 1, 0.5
	end
	ph -= b
	if ph < c then
		return 1 - smoother(ph / c), workIsBack and 1 or 0
	end
	return 0, 0
end

local function breathe(t, rate)
	return sin(t * 2 * pi * (rate or 0.28))
end

-- ----------------------------------------------------------------------
-- Pose helpers
-- ----------------------------------------------------------------------
local function toLocal(S, worldPoint)
	return S.Base:PointToObjectSpace(worldPoint)
end

local function shoulderMid(rig)
	return (rig:pivot("LeftShoulder") + rig:pivot("RightShoulder")) / 2
end

-- Place the body so the midpoint between the shoulders lands on `target`.
local function placeByShoulders(rig, target, pelvisRot, waist)
	rig:set("Waist", waist or IDENTITY)
	rig:setPelvis(CFrame.new() * (pelvisRot - pelvisRot.Position))
	local mid = shoulderMid(rig)
	local rot = pelvisRot - pelvisRot.Position
	rig:setPelvis(CFrame.new(target - mid) * rot)
end

-- Relaxed hanging arm (FK). side = "Left"/"Right"
local function relaxArm(rig, side, flex, abduct, elbow, t, seed)
	local s = side == "Left" and -1 or 1
	local sway = wobble(seed or 0, t or 0, 0.3) * 0.04
	rig:set(side .. "Shoulder", CFrame.Angles(flex + sway, 0, 0) * CFrame.Angles(0, 0, s * abduct))
	rig:set(side .. "Elbow", CFrame.Angles(elbow, 0, 0))
	rig:set(side .. "Wrist", IDENTITY)
end

local function plantFeet(rig, S, x, y, z, toeOut, kneeOut)
	local B = S.Base
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local sole = B * CFrame.new(s * x, y, z) * CFrame.Angles(0, -s * (toeOut or 0), 0)
		local hip = rig:pivot(side .. "Hip")
		local pole = hip + B:VectorToWorldSpace(Vector3.new(s * (kneeOut or 0.6), 0.5, -3))
		rig:plantFoot(side, sole, pole)
	end
end

local function standing(rig, S, z, sway, t, seed)
	local d = rig.Dims
	local B = S.Base
	local br = breathe(t)
	rig:setPelvis(B * CFrame.new(sway * wobble(seed, t, 0.15) * 0.08, d.StandPelvisY - 0.04 + br * 0.01, z)
		* CFrame.Angles(0, wobble(seed + 3, t, 0.1) * 0.05, 0))
	rig:set("Waist", CFrame.Angles(-0.02 - br * 0.015, 0, 0))
end

-- hands-on-hips target points (world)
local function hipGrips(rig, S)
	local lt = rig:world("LowerTorso")
	local w = rig.Dims.ShoulderHalfWidth
	return lt * Vector3.new(-(w - 0.25), 0.25, 0.1), lt * Vector3.new(w - 0.25, 0.25, 0.1)
end

local function armsToPoints(rig, S, left, right, poleLocal)
	local B = S.Base
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local sh = rig:pivot(side .. "Shoulder")
		local p = poleLocal or Vector3.new(1.4, -1, 1)
		local pole = sh + B:VectorToWorldSpace(Vector3.new(s * p.X, p.Y, p.Z))
		rig:armIK(side, side == "Left" and left or right, pole)
	end
end

local function standardLook(rig, S, t, P, lookLocal)
	local wander = Vector3.new(P.Look * 2 + wobble(P.Seed, t, 0.07) * 4, wobble(P.Seed + 9, t, 0.05) * 1.5, 0)
	rig:lookAt(S.Base * (lookLocal + wander), 0.8)
end

-- Blend two full poses: evaluate a then b; result = lerp(a, b, alpha).
-- Each pose fn returns an E table.
local function blendPoses(rig, fa, fb, alpha)
	if alpha <= 0 then
		return fa()
	elseif alpha >= 1 then
		return fb()
	end
	local ea = fa()
	local snap = rig:snapshot()
	rig:reset()
	local eb = fb()
	rig:blendFrom(snap, alpha)
	-- blend equipment
	local out = { Moves = {}, Cables = {} }
	for name, cf in pairs(eb.Moves) do
		local from = ea.Moves[name]
		out.Moves[name] = from and from:Lerp(cf, alpha) or cf
	end
	for name, cf in pairs(ea.Moves) do
		if not out.Moves[name] then
			out.Moves[name] = cf
		end
	end
	for name, c in pairs(eb.Cables) do
		local from = ea.Cables[name]
		if from then
			out.Cables[name] = { from[1]:Lerp(c[1], alpha), from[2]:Lerp(c[2], alpha) }
		else
			out.Cables[name] = c
		end
	end
	return out
end

local function E()
	return { Moves = {}, Cables = {} }
end

local function stackMove(S, e, rise, name)
	name = name or "Stack"
	local rest = S.RestLocal[name]
	if rest then
		e.Moves[name] = S.Base * CFrame.new(0, rise, 0) * rest
	end
end

-- ======================================================================
-- TREADMILL — steady run. Feet ride the moving belt during stance.
-- ======================================================================
function Exercises.Treadmill(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base
	local e = E()

	local v = sp.BeltSpeed
	local f = sp.Cadence * P.Stride
	local phase = (t * f) % 1
	local stance = 0.36
	local travel = v * stance / f
	local zLand = sp.PelvisZ - travel * 0.45
	local zOff = zLand + travel

	-- pelvis: lowest at mid-stance, highest in flight
	local bounce = cos(4 * pi * (phase - stance * 0.5))
	local pelvisY = sp.BeltTop + d.StandPelvisY - 0.28 - 0.1 * bounce
	local yaw = rad(7) * cos(2 * pi * phase)
	rig:setPelvis(B * CFrame.new(0, pelvisY, sp.PelvisZ) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rad(-5), 0, 0))
	rig:set("Waist", CFrame.Angles(rad(-7) - 0.02 * bounce, -yaw * 1.7, 0))

	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local ph = side == "Left" and phase or (phase + 0.5) % 1
		local z, lift, pitch
		if ph < stance then
			local u = ph / stance
			z = lerp(zLand, zOff, u)
			lift = 0
			pitch = lerp(rad(4), rad(-22), u * u)
		else
			local u = (ph - stance) / (1 - stance)
			z = lerp(zOff, zLand, smooth(u))
			lift = 1.15 * sin(pi * u ^ 0.75) * (1 - 0.25 * u)
			pitch = lerp(rad(-45), rad(12), smooth(u))
		end
		local raise = pitch < 0 and 0.5 * sin(-pitch) or 0
		local sole = B * CFrame.new(s * 0.42, sp.BeltTop + lift + raise, z) * CFrame.Angles(pitch, 0, 0)
		local hip = rig:pivot(side .. "Hip")
		rig:plantFoot(side, sole, hip + B:VectorToWorldSpace(Vector3.new(s * 0.3, 0, -4)))

		-- arms swing opposite to legs, elbows ~90°
		local swing = cos(2 * pi * ph)
		rig:set(side .. "Shoulder", CFrame.Angles(rad(-5) - swing * rad(38), 0, 0) * CFrame.Angles(0, 0, s * rad(9)))
		rig:set(side .. "Elbow", CFrame.Angles(rad(88) + swing * rad(18), 0, 0))
		rig:set(side .. "Wrist", CFrame.Angles(0, 0, -s * rad(10)))
	end

	rig:lookAt(B * Vector3.new(0, 6.2, -9), 0.9)

	-- belt slats scroll backward under the runner
	local L = sp.BeltLength
	local off = (t * v) % L
	for k = 1, sp.Slats do
		local name = "Slat" .. k
		local rest = S.RestLocal[name]
		if rest then
			local z0 = rest.Position.Z
			local z = ((z0 + L / 2 + off) % L) - L / 2
			e.Moves[name] = B * CFrame.new(0, 0, z - z0) * rest
		end
	end
	return e
end

-- ======================================================================
-- SPIN BIKE — pedals turn, feet locked to pedals, hips rock.
-- ======================================================================
function Exercises.Bike(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base
	local e = E()

	local rate = sp.Cadence * P.Stride
	-- surge a little every ~20 s (out-of-saddle feel without leaving the saddle)
	local surge = smooth((sin(t * 2 * pi / 22 + P.Offset) - 0.6) / 0.4)
	local theta = 2 * pi * rate * t + surge * 0.6 * sin(t * 0.3)
	local c = sp.CrankCenter
	local r = sp.CrankRadius

	local roll = rad(2.5) * sin(theta)
	rig:setPelvis(B * CFrame.new(0, sp.SaddleTop + d.PelvisDepth / 2 + 0.06, sp.SaddleZ)
		* CFrame.Angles(0, 0, roll) * CFrame.Angles(rad(-18 - 4 * surge), 0, 0))
	rig:set("Waist", CFrame.Angles(rad(-16) - 0.02 * breathe(t, 0.5), 0, -roll * 1.4))

	local pedalPos = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local a = side == "Right" and theta or theta + pi
		local pos = c + Vector3.new(s * sp.PedalX, r * cos(a), -r * sin(a))
		pedalPos[side] = pos
		local ankling = rad(-8) + rad(14) * sin(a + 0.6)
		local sole = B * CFrame.new(pos + Vector3.new(0, 0.09, 0.22)) * CFrame.Angles(ankling, 0, 0)
		local hip = rig:pivot(side .. "Hip")
		rig:plantFoot(side, sole, hip + B:VectorToWorldSpace(Vector3.new(s * 0.25, 0.5, -4)))
	end

	local hb = sp.HandlebarPos
	local jig = wobble(P.Seed, t, 2) * 0.02
	armsToPoints(rig, S,
		B * (hb + Vector3.new(-sp.HandlebarGripX, jig, 0)),
		B * (hb + Vector3.new(sp.HandlebarGripX, -jig, 0)),
		Vector3.new(1.3, -0.6, 1.2))
	rig:lookAt(B * Vector3.new(0, 4.2, -10), 0.9)

	e.Moves.Crank = B * rotateAboutX(S.RestLocal.Crank, c, -theta)
	e.Moves.Flywheel = B * rotateAboutX(S.RestLocal.Flywheel, sp.FlywheelCenter, -theta * 2.6)
	e.Moves.PedalL = B * CFrame.new(pedalPos.Left) * (S.RestLocal.PedalL - S.RestLocal.PedalL.Position)
	e.Moves.PedalR = B * CFrame.new(pedalPos.Right) * (S.RestLocal.PedalR - S.RestLocal.PedalR.Position)
	return e
end

-- ======================================================================
-- BENCH PRESS — unrack, controlled descent, touch, drive, rerack, rest.
-- ======================================================================
function Exercises.BenchPress(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local stage, x, repIdx = timeline(t, P, 1.4, 2.7, 1.3)

	local br = breathe(t, stage == "rest" and 0.45 or 0.3)
	rig:setPelvis(B * CFrame.new(0, sp.PadTop + d.PelvisDepth / 2, sp.PelvisZ) * CFrame.Angles(rad(90), 0, 0))
	rig:set("Waist", CFrame.Angles(rad(5) + br * 0.02, 0, 0))

	local shL = toLocal(S, rig:pivot("LeftShoulder"))
	local shR = toLocal(S, rig:pivot("RightShoulder"))
	local shY, shZ = (shL.Y + shR.Y) / 2, (shL.Z + shR.Z) / 2
	local gx = d.ShoulderHalfWidth + 0.38

	local lock = Vector3.new(0, shY + d.ArmReach * 0.95, shZ - 0.05)
	local chest = Vector3.new(0, shY + d.ChestDepth / 2 + Specs.BARBELL.ShaftDiameter / 2 + 0.08, shZ - 0.5)
	local rack = Vector3.new(0, sp.HookY, sp.HookZ)

	local bar
	local onBar = 1 -- 0 = hands on belly, 1 = hands on bar
	if stage == "rest" then
		bar, onBar = rack, 0
	elseif stage == "setup" or stage == "finish" then
		local k = stage == "setup" and x or 1 - x
		onBar = smooth(k / 0.3)
		local u = smooth((k - 0.3) / 0.7)
		bar = vlerp(rack, lock, u) + Vector3.new(0, 0.22 * sin(pi * u), 0)
	else
		local p, working = repCurve(x, repIdx, P.Reps, { 0.4, 0.06, 0.34 }, true)
		bar = Vector3.new(0, lerp(lock.Y, chest.Y, p), lerp(lock.Z, chest.Z, p ^ 0.8))
		-- tiny grind shake while pressing
		if working == 1 then
			bar += Vector3.new(wobble(P.Seed, t, 7) * 0.012, 0, 0)
		end
	end

	local barCF = B * CFrame.new(bar)
	local restL = B * Vector3.new(-0.45, sp.PadTop + d.ChestDepth + 0.2, sp.PelvisZ + 0.75)
	local restR = B * Vector3.new(0.45, sp.PadTop + d.ChestDepth + 0.2, sp.PelvisZ + 0.75)
	local gripL = restL:Lerp(barCF * Vector3.new(-gx, 0, 0), onBar)
	local gripR = restR:Lerp(barCF * Vector3.new(gx, 0, 0), onBar)
	armsToPoints(rig, S, gripL, gripR, Vector3.new(1.6, -1.6, -0.7))

	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local sole = B * CFrame.new(s * sp.FootX, 0, sp.FootZ) * CFrame.Angles(0, -s * rad(18), 0)
		local hip = rig:pivot(side .. "Hip")
		rig:plantFoot(side, sole, hip + B:VectorToWorldSpace(Vector3.new(s * 0.7, 3, -1.5)))
	end

	if onBar > 0.5 then
		rig:lookAt(barCF.Position, 0.35)
	else
		rig:lookAt(B * Vector3.new(P.Look * 3, 12, sp.PelvisZ + 4), 0.3)
	end

	local e = E()
	e.Moves.Bar = barCF * (S.RestLocal.Bar - S.RestLocal.Bar.Position)
	return e
end

-- ======================================================================
-- DUMBBELL CURLS — alternating, supinating, elbows pinned.
-- ======================================================================
function Exercises.DumbbellCurl(rig, S, t, P)
	local sp = S.Spec
	local stage, x, repIdx = timeline(t, P, 0.8, 3.4, 0.8)

	standing(rig, S, 0, 1, t, P.Seed)
	plantFeet(rig, S, sp.FootX, 0, 0, rad(10), 0.3)

	local curl = { Left = 0, Right = 0 }
	local lean = 0
	if stage == "rep" then
		local half = x < 0.5 and "Left" or "Right"
		local hx = (x % 0.5) / 0.5
		local p = repCurve(hx, repIdx, P.Reps, { 0.34, 0.1, 0.46 }, false)
		curl[half] = p
		lean = p * rad(3)
	end
	rig:set("Waist", CFrame.Angles(-0.02 + lean, 0, 0))

	local e = E()
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local c = curl[side]
		local restSwing = stage == "rest" and wobble(P.Seed + (s > 0 and 5 or 0), t, 0.4) * 0.08 or 0
		rig:set(side .. "Shoulder", CFrame.Angles(rad(3) + rad(16) * c + restSwing, 0, 0) * CFrame.Angles(0, 0, s * rad(9)))
		rig:set(side .. "Elbow", CFrame.Angles(rad(12) + rad(128) * c, 0, 0))
		local sup = rad(25) + rad(65) * smooth(c * 2.2)
		if stage == "rest" then
			sup = rad(5)
		end
		rig:set(side .. "Wrist", CFrame.Angles(0, -s * sup, 0) * CFrame.Angles(-rad(12) * c, 0, 0))
		local hand = rig:world(side .. "Hand")
		e.Moves["Dumbbell" .. (s < 0 and "L" or "R")] = hand * CFrame.new(0, -0.02, 0) * CFrame.Angles(0, pi / 2, 0)
	end

	standardLook(rig, S, t, P, Vector3.new(0, 5, -10))
	return e
end

-- ======================================================================
-- LAT PULLDOWN — reach up, pull to the upper chest, lean back slightly.
-- ======================================================================
function Exercises.LatPulldown(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local stage, x, repIdx = timeline(t, P, 1.3, 2.6, 1.1)
	local p = 0
	if stage == "rep" then
		p = repCurve(x, repIdx, P.Reps, { 0.36, 0.1, 0.44 }, false)
	end

	local lean = rad(6) + rad(14) * p
	rig:setPelvis(B * CFrame.new(0, sp.SeatTop + d.PelvisDepth / 2 + 0.04, sp.SeatZ) * CFrame.Angles(lean * 0.5, 0, 0))
	rig:set("Waist", CFrame.Angles(lean * 0.5 + breathe(t) * 0.015, 0, 0))
	plantFeet(rig, S, 0.75, 0, sp.FootZ, rad(8), 0.4)

	local mid = toLocal(S, shoulderMid(rig))
	local top = Vector3.new(0, mid.Y + d.ArmReach * 0.92, mid.Z - 0.45)
	local bottom = Vector3.new(0, mid.Y + 0.35, mid.Z - d.ChestDepth / 2 - 0.55)
	local rest = Vector3.new(0, sp.BarRestY, sp.BarZ)

	local bar, onBar = rest, 1
	if stage == "rest" then
		onBar = 0
	elseif stage == "setup" or stage == "finish" then
		local k = stage == "setup" and x or 1 - x
		onBar = smooth(k / 0.35)
		bar = vlerp(rest, top, smooth((k - 0.35) / 0.65))
	else
		bar = vlerp(top, bottom, p) + Vector3.new(0, 0, -0.25 * sin(pi * p))
	end

	local barCF = B * CFrame.new(bar)
	local lt = rig:world("LowerTorso")
	local thighL = lt * Vector3.new(-0.55, 0.1, -1.3)
	local thighR = lt * Vector3.new(0.55, 0.1, -1.3)
	armsToPoints(rig, S,
		thighL:Lerp(barCF * Vector3.new(-sp.GripX, 0, 0), onBar),
		thighR:Lerp(barCF * Vector3.new(sp.GripX, 0, 0), onBar),
		Vector3.new(2.2, -1.2, 0.6))

	rig:lookAt(B * Vector3.new(0, 7 - 3 * p, -6), 0.6)

	local e = E()
	e.Moves.Bar = barCF * (S.RestLocal.Bar - S.RestLocal.Bar.Position)
	local rise = math.clamp((sp.BarRestY - bar.Y) * 0.8, 0, 2.6)
	stackMove(S, e, rise)
	e.Cables.Cable1 = { B * sp.PulleyTop, barCF * Vector3.new(0, 0.12, 0) }
	local stackTop = sp.StackPos + Vector3.new(0, sp.StackPlates * sp.PlateHeight + rise, 0)
	e.Cables.Cable2 = { B * stackTop, B * Vector3.new(0, sp.PulleyTop.Y, sp.StackPos.Z) }
	return e
end

-- ======================================================================
-- SQUAT — duck under, unrack, squat to parallel, rerack, step out.
-- ======================================================================
local function squatBody(rig, S, depth, z, t)
	local d = rig.Dims
	local B = S.Base
	local drop = depth * d.LegLength * 0.56
	local back = depth * 0.72
	rig:setPelvis(B * CFrame.new(0, d.StandPelvisY - drop, z + back) * CFrame.Angles(-rad(22) * depth, 0, 0))
	rig:set("Waist", CFrame.Angles(-rad(20) * depth - breathe(t) * 0.01, 0, 0))
end

function Exercises.Squat(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local stage, x, repIdx = timeline(t, P, 2.2, 3.2, 2.0)
	local hook = B * CFrame.new(0, sp.HookY, sp.HookZ)
	local restZ = -0.95

	-- where the body is + how deep
	local z, depth, onBar, barOnBack = 0, 0, 1, 1
	if stage == "rest" then
		z, depth, onBar, barOnBack = restZ, 0, 0, 0
	elseif stage == "setup" or stage == "finish" then
		local k = stage == "setup" and x or 1 - x
		-- 0-0.35 step back under the bar, 0.35-0.55 grab + dip, 0.55-1 stand up with it
		z = lerp(restZ, 0, smooth(k / 0.35))
		onBar = smooth((k - 0.25) / 0.2)
		depth = 0.22 * sin(pi * smooth((k - 0.2) / 0.55)) + 0.12 * (1 - smooth((k - 0.55) / 0.45)) * smooth((k - 0.35) / 0.2)
		barOnBack = smooth((k - 0.5) / 0.35)
	else
		depth = repCurve(x, repIdx, P.Reps, { 0.4, 0.04, 0.36 }, true)
	end

	squatBody(rig, S, depth, z, t)

	-- feet: stepping during setup/finish, planted otherwise
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local footZ = z
		local lift = 0
		if stage == "setup" or stage == "finish" then
			local k = stage == "setup" and x or 1 - x
			local k0 = side == "Left" and 0 or 0.12
			local u = smooth((k - k0) / 0.22)
			footZ = lerp(restZ, 0, u)
			lift = 0.35 * sin(pi * u)
		end
		local sole = B * CFrame.new(s * sp.FootX, lift, footZ) * CFrame.Angles(0, -s * rad(14), 0)
		local hip = rig:pivot(side .. "Hip")
		rig:plantFoot(side, sole, hip + B:VectorToWorldSpace(Vector3.new(s * 1.2, 0.4, -3)))
	end

	local ut = rig:world("UpperTorso")
	local ups = rig.Parts.UpperTorso.Size
	local onBack = ut * CFrame.new(0, ups.Y / 2 - 0.12, d.ChestDepth / 2 + 0.08)
	onBack = CFrame.new(onBack.Position) * (B - B.Position)
	local barCF = hook:Lerp(onBack, barOnBack)

	local gx = d.ShoulderHalfWidth + 0.5
	local hipL, hipR = hipGrips(rig, S)
	armsToPoints(rig, S,
		hipL:Lerp(barCF * Vector3.new(-gx, 0, 0), onBar),
		hipR:Lerp(barCF * Vector3.new(gx, 0, 0), onBar),
		Vector3.new(1.2, -1.6, 1.6))

	rig:lookAt(B * Vector3.new(0, 3.5 - depth * 1.5, -10), 0.7)

	local e = E()
	e.Moves.Bar = barCF * (S.RestLocal.Bar - S.RestLocal.Bar.Position)
	return e
end

-- ======================================================================
-- SEATED CABLE ROW — reach, pull to the belly, squeeze, return.
-- ======================================================================
function Exercises.CableRow(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local stage, x, repIdx = timeline(t, P, 1.4, 2.8, 1.2)
	local p = 0 -- 0 = arms long + leaning forward, 1 = handle at belly
	local onHandle = 1
	local handle
	local reach = 0 -- how far forward the torso leans

	rig:setPelvis(B * CFrame.new(0, sp.SeatTop + d.PelvisDepth / 2 + 0.04, sp.SeatZ))

	local function torso(leanFwd)
		rig:set("Waist", CFrame.Angles(-leanFwd + breathe(t) * 0.012, 0, 0))
		rig:setPelvis(B * CFrame.new(0, sp.SeatTop + d.PelvisDepth / 2 + 0.04, sp.SeatZ) * CFrame.Angles(-leanFwd * 0.6, 0, 0))
	end

	local function extendedHandle()
		local mid = toLocal(S, shoulderMid(rig))
		return Vector3.new(0, mid.Y - 0.55, mid.Z - d.ArmReach * 0.93)
	end
	local function bellyHandle()
		local lt = toLocal(S, rig:world("LowerTorso").Position)
		return Vector3.new(0, lt.Y + 0.75, lt.Z - d.PelvisDepth / 2 - 0.45)
	end

	if stage == "rest" then
		torso(rad(-3))
		handle, onHandle = sp.HandleRest, 0
	elseif stage == "setup" or stage == "finish" then
		local k = stage == "setup" and x or 1 - x
		reach = rad(26) * sin(pi * smooth(k))
		torso(reach)
		onHandle = smooth((k - 0.1) / 0.35)
		handle = vlerp(sp.HandleRest, extendedHandle(), smooth((k - 0.45) / 0.55))
	else
		p = repCurve(x, repIdx, P.Reps, { 0.36, 0.12, 0.42 }, false)
		torso(lerp(rad(20), rad(-6), p))
		handle = vlerp(extendedHandle(), bellyHandle(), p)
	end

	-- feet on the angled foot plate
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local sole = B * CFrame.new(s * 0.62, sp.PlateY, sp.PlateZ + 0.2) * CFrame.Angles(rad(62), 0, 0)
		local hip = rig:pivot(side .. "Hip")
		rig:plantFoot(side, sole, hip + B:VectorToWorldSpace(Vector3.new(s * 0.5, 3, -1)))
	end

	local hCF = B * CFrame.new(handle)
	local lt = rig:world("LowerTorso")
	armsToPoints(rig, S,
		(lt * Vector3.new(-0.6, 0.2, -1.2)):Lerp(hCF * Vector3.new(-0.2, 0.05, 0), onHandle),
		(lt * Vector3.new(0.6, 0.2, -1.2)):Lerp(hCF * Vector3.new(0.2, 0.05, 0), onHandle),
		Vector3.new(0.7, -1.2, 1.8))
	rig:lookAt(B * Vector3.new(0, 3, -10), 0.7)

	local e = E()
	e.Moves.Handle = hCF * (S.RestLocal.Handle - S.RestLocal.Handle.Position)
	local pull = (handle - sp.PulleyExit).Magnitude - (sp.HandleRest - sp.PulleyExit).Magnitude
	local rise = math.clamp(pull * 0.6, 0, 2.6)
	stackMove(S, e, rise)
	e.Cables.Cable1 = { B * sp.PulleyExit, hCF * Vector3.new(0, 0, -0.1) }
	return e
end

-- ======================================================================
-- LEG EXTENSION — knees locked on the pivot, shins sweep the pad up.
-- ======================================================================
function Exercises.LegExtension(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local stage, x, repIdx = timeline(t, P, 0.8, 2.6, 0.8)
	local p = 0
	if stage == "rep" then
		p = repCurve(x, repIdx, P.Reps, { 0.34, 0.14, 0.42 }, false)
	end

	local hip = d.HipLocal.Left
	local pelvisY = sp.PivotY - hip.Y
	local pelvisZ = sp.PivotZ + d.LegUpper - hip.Z
	rig:setPelvis(B * CFrame.new(0, pelvisY, pelvisZ) * CFrame.Angles(rad(4), 0, 0))
	rig:set("Waist", CFrame.Angles(rad(3) - p * rad(3) + breathe(t) * 0.012, 0, 0))

	local knee = lerp(rad(88), rad(6), p)
	if stage == "rest" then
		knee = rad(93) + wobble(P.Seed, t, 0.5) * rad(4)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		rig:set(side .. "Hip", CFrame.Angles(rad(86), 0, 0) * CFrame.Angles(0, 0, s * rad(-3)))
		rig:set(side .. "Knee", CFrame.Angles(-knee, 0, 0))
		rig:set(side .. "Ankle", CFrame.Angles(rad(12) * (1 - p) + rad(6), 0, 0))
	end

	local grip = stage == "rest" and 0.4 or 1
	local lt = rig:world("LowerTorso")
	armsToPoints(rig, S,
		(lt * Vector3.new(-0.6, 0.25, -1.1)):Lerp(B * Vector3.new(-sp.HandleX, sp.SeatTop + 0.35, sp.SeatZ - 0.1), grip),
		(lt * Vector3.new(0.6, 0.25, -1.1)):Lerp(B * Vector3.new(sp.HandleX, sp.SeatTop + 0.35, sp.SeatZ - 0.1), grip),
		Vector3.new(1.5, -0.8, 1.2))
	standardLook(rig, S, t, P, Vector3.new(0, 4.5 - p, -10))

	local e = E()
	local pivot = Vector3.new(0, sp.PivotY, sp.PivotZ)
	e.Moves.Lever = B * rotateAboutX(S.RestLocal.Lever, pivot, rad(90) - knee)
	local backZ = pelvisZ + d.PelvisDepth / 2 + 0.3
	local restBack = S.RestLocal.BackPad
	e.Moves.BackPad = B * CFrame.new(0, 0, backZ - restBack.Position.Z) * restBack
	stackMove(S, e, math.clamp((rad(90) - knee) / rad(84), 0, 1) * 1.8)
	return e
end

-- ======================================================================
-- DEADLIFT — hips hinge, flat back, bar drags up the shins, lockout.
-- ======================================================================
function Exercises.Deadlift(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base
	local floorY = sp.PlatformSize.Y
	local barFloorY = floorY + Specs.BARBELL.PlateDiameter / 2
	local barZ = sp.BarZ

	-- standing shoulder height (for lockout bar height)
	rig:set("Waist", IDENTITY)
	rig:setPelvis(B * CFrame.new(0, floorY + d.StandPelvisY, 0))
	local standShoulderY = toLocal(S, shoulderMid(rig)).Y
	local lockY = standShoulderY - d.ArmReach * 0.99
	rig:reset()

	local function liftPose(p)
		local barY = lerp(barFloorY, lockY, p)
		local hinge = rad(52) * (1 - p) ^ 1.15
		local target = B * Vector3.new(0, barY + d.ArmReach * 0.97 * cos(rad(6) * (1 - p)), barZ - 0.08 * (1 - p))
		placeByShoulders(rig, target, B * CFrame.Angles(-hinge, 0, 0), CFrame.Angles(rad(2) * p, 0, 0))
		plantFeet(rig, S, sp.FootX, floorY, 0, rad(10), 0.9)
		local barCF = B * CFrame.new(0, barY, barZ + 0.0)
		armsToPoints(rig, S, barCF * Vector3.new(-sp.GripX, 0, 0), barCF * Vector3.new(sp.GripX, 0, 0), Vector3.new(0.6, -0.5, 1.5))
		rig:lookAt(B * Vector3.new(0, floorY + 1.2, -7), 0.6)
		local e = E()
		e.Moves.Bar = barCF * (S.RestLocal.Bar - S.RestLocal.Bar.Position)
		return e
	end

	local function restPose()
		standing(rig, S, 0.55, 1, t, P.Seed)
		rig:setPelvis(rig:world("LowerTorso") + B:VectorToWorldSpace(Vector3.new(0, floorY, 0)))
		plantFeet(rig, S, sp.FootX + 0.05, floorY, 0.55, rad(12), 0.5)
		local l, r = hipGrips(rig, S)
		armsToPoints(rig, S, l, r, Vector3.new(1.4, -0.6, 1.2))
		standardLook(rig, S, t, P, Vector3.new(0, 5, -10))
		local e = E()
		e.Moves.Bar = B * CFrame.new(0, barFloorY, barZ) * (S.RestLocal.Bar - S.RestLocal.Bar.Position)
		return e
	end

	local stage, x, repIdx = timeline(t, P, 1.6, 3.4, 1.4)
	if stage == "rest" then
		return restPose()
	elseif stage == "setup" then
		return blendPoses(rig, restPose, function()
			return liftPose(0)
		end, smooth(x))
	elseif stage == "finish" then
		return blendPoses(rig, function()
			return liftPose(0)
		end, restPose, smooth(x))
	end
	local p = repCurve(x, repIdx, P.Reps, { 0.36, 0.1, 0.42 }, false)
	return liftPose(p)
end

-- ======================================================================
-- SEATED DUMBBELL SHOULDER PRESS
-- ======================================================================
function Exercises.ShoulderPress(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local function seat()
		rig:setPelvis(B * CFrame.new(0, sp.SeatTop + d.PelvisDepth / 2 + 0.04, sp.SeatZ) * CFrame.Angles(rad(5), 0, 0))
		rig:set("Waist", CFrame.Angles(rad(4) + breathe(t) * 0.012, 0, 0))
		plantFeet(rig, S, sp.FootX, 0, sp.FootZ, rad(20), 1)
	end

	local function pressPose(p)
		seat()
		local e = E()
		local hands = {}
		for _, side in ipairs({ "Left", "Right" }) do
			local s = side == "Left" and -1 or 1
			local sh = toLocal(S, rig:pivot(side .. "Shoulder"))
			local bottom = Vector3.new(sh.X + s * 0.45, sh.Y + 0.45, sh.Z - 0.35)
			local top = Vector3.new(sh.X - s * 0.35, sh.Y + d.ArmReach * 0.95, sh.Z - 0.2)
			local pos = vlerp(bottom, top, p) + Vector3.new(s * 0.18 * sin(pi * p), 0, 0)
			hands[side] = B * pos
			e.Moves["Dumbbell" .. (s < 0 and "L" or "R")] = B * CFrame.new(pos)
		end
		armsToPoints(rig, S, hands.Left, hands.Right, Vector3.new(2.2, -1.4, 0.4))
		rig:lookAt(B * Vector3.new(0, 5, -10), 0.8)
		return e
	end

	local function restPose()
		seat()
		local e = E()
		local hands = {}
		for _, side in ipairs({ "Left", "Right" }) do
			local s = side == "Left" and -1 or 1
			local knee = toLocal(S, rig:pivot(side .. "Knee"))
			local pos = Vector3.new(knee.X, knee.Y + 0.95, knee.Z + 0.15)
			hands[side] = B * pos
			-- dumbbell stood up on the thigh
			e.Moves["Dumbbell" .. (s < 0 and "L" or "R")] = B * CFrame.new(pos + Vector3.new(0, -0.1, 0)) * CFrame.Angles(0, 0, pi / 2)
		end
		armsToPoints(rig, S, hands.Left, hands.Right, Vector3.new(1.2, -0.5, 1.2))
		standardLook(rig, S, t, P, Vector3.new(0, 5, -10))
		return e
	end

	local stage, x, repIdx = timeline(t, P, 1.2, 2.8, 1.1)
	if stage == "rest" then
		return restPose()
	elseif stage == "setup" then
		return blendPoses(rig, restPose, function()
			return pressPose(0)
		end, smooth(x))
	elseif stage == "finish" then
		return blendPoses(rig, function()
			return pressPose(0)
		end, restPose, smooth(x))
	end
	return pressPose(repCurve(x, repIdx, P.Reps, { 0.34, 0.08, 0.46 }, false))
end

-- ======================================================================
-- PULL-UP (kneeling on the assist pad) — dead hang to chin over bar.
-- ======================================================================
function Exercises.PullUp(rig, S, t, P)
	local sp = S.Spec
	local d = rig.Dims
	local B = S.Base

	local function hangPose(p)
		local hangY = sp.HandleY - d.ArmReach * 0.96
		local topY = sp.HandleY - 0.55
		local y = lerp(hangY, topY, p)
		local target = B * Vector3.new(0, y, sp.HandleZ + 0.35 + 0.15 * p)
		placeByShoulders(rig, target, B * CFrame.Angles(rad(4) + rad(8) * p, 0, 0), CFrame.Angles(rad(3) * p, 0, 0))
		for _, side in ipairs({ "Left", "Right" }) do
			local s = side == "Left" and -1 or 1
			rig:set(side .. "Hip", CFrame.Angles(rad(-6), 0, 0) * CFrame.Angles(0, 0, s * rad(-2)))
			rig:set(side .. "Knee", CFrame.Angles(rad(-92), 0, 0))
			rig:set(side .. "Ankle", CFrame.Angles(rad(-35), 0, 0))
		end
		local hL = B * Vector3.new(-sp.HandleX, sp.HandleY, sp.HandleZ)
		local hR = B * Vector3.new(sp.HandleX, sp.HandleY, sp.HandleZ)
		armsToPoints(rig, S, hL, hR, Vector3.new(2, -1.2, -0.8))
		rig:lookAt(B * Vector3.new(0, sp.HandleY + 1.5 - 2 * p, -6), 0.6)

		local e = E()
		local knee = toLocal(S, (rig:pivot("LeftKnee") + rig:pivot("RightKnee")) / 2)
		local padTop = knee.Y - rig.Parts.LeftLowerLeg.Size.Z / 2 - 0.05
		local rest = S.RestLocal.KneePad
		local padRestTop = S.Spec.PadRestTop or rest.Position.Y
		e.Moves.KneePad = B * CFrame.new(0, padTop - padRestTop, knee.Z - rest.Position.Z) * rest
		stackMove(S, e, math.clamp(padRestTop - padTop, 0, 3))
		return e
	end

	local function restPose()
		standing(rig, S, sp.RestZ, 0.5, t, P.Seed)
		plantFeet(rig, S, 0.7, 0, sp.RestZ, rad(10), 0.4)
		local l, r = hipGrips(rig, S)
		armsToPoints(rig, S, l, r, Vector3.new(1.4, -0.6, 1.2))
		standardLook(rig, S, t, P, Vector3.new(0, 7, -10))
		local e = E()
		e.Moves.KneePad = B * S.RestLocal.KneePad
		stackMove(S, e, 0)
		return e
	end

	local stage, x, repIdx = timeline(t, P, 1.6, 3.1, 1.5)
	if stage == "rest" then
		return restPose()
	elseif stage == "setup" then
		return blendPoses(rig, restPose, function()
			return hangPose(0)
		end, smooth(x))
	elseif stage == "finish" then
		return blendPoses(rig, function()
			return hangPose(0)
		end, restPose, smooth(x))
	end
	return hangPose(repCurve(x, repIdx, P.Reps, { 0.38, 0.1, 0.42 }, false))
end

-- Fallback when an exercise is unknown: stand and breathe.
function Exercises.Idle(rig, S, t, P)
	standing(rig, S, 0, 1, t, P.Seed)
	plantFeet(rig, S, 0.65, 0, 0, rad(8), 0.3)
	relaxArm(rig, "Left", rad(2), rad(6), rad(10), t, P.Seed)
	relaxArm(rig, "Right", rad(2), rad(6), rad(10), t, P.Seed + 1)
	standardLook(rig, S, t, P, Vector3.new(0, 5, -10))
	return E()
end

return Exercises
