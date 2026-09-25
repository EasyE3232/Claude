--[[
	Poses
	Bodybuilding poses struck on the conveyor. Pure IK targets relative to the
	rig, shared by the client animator and the offline pose renderer.

	  Poses.Apply(rig, name)   -- call after rig:reset() / setRootCFrame
	  Poses.JOINTS             -- joints a pose writes (blend these)
]]

local Poses = {}

Poses.JOINTS = { "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "Waist", "Neck" }

local WAIST = {
	MostMuscular = { -14, 0 },
	Vacuum = { 5, 0 },
	LatSpread = { 3, 0 },
	CrossedArms = { 2, 0 },
	SideChest = { -4, -22 },
	Point = { 4, 12 },
}

local NECK = {
	MostMuscular = { 10, 0 },
	SideChest = { 0, 26 },
	Point = { -6, 10 },
}

function Poses.Apply(rig, name)
	local w = WAIST[name]
	if w then
		rig:set("Waist", CFrame.Angles(math.rad(w[1]), math.rad(w[2]), 0))
	end
	local d = rig.Dims
	local k = d.Scale
	local ut = rig:world("UpperTorso")
	local right, up, fwd = ut.RightVector, ut.UpVector, ut.LookVector
	local head = rig:world("Head").Position
	local lt = rig:world("LowerTorso")
	local chest = ut.Position + fwd * (0.95 * k) - up * (0.45 * k)
	for _, side in ipairs({ "Left", "Right" }) do
		local sgn = side == "Left" and -1 or 1
		local S = rig:pivot(side .. "Shoulder")
		local target, pole
		if name == "DoubleBiceps" then
			target = S + right * sgn * (1.15 * k) + up * (1.05 * k) - fwd * (0.1 * k)
			pole = S + right * sgn * (3 * k) - up * (0.4 * k)
		elseif name == "Vacuum" then
			target = head + right * sgn * (0.45 * k) - fwd * (0.55 * k) + up * (0.15 * k)
			pole = S + right * sgn * (2.5 * k) + up * (1.6 * k)
		elseif name == "MostMuscular" then
			target = ut.Position + fwd * (0.95 * k) - up * (0.75 * k) + right * sgn * (0.25 * k)
			pole = S + right * sgn * (2.6 * k) + fwd * (0.4 * k)
		elseif name == "CrossedArms" then
			-- forearms stacked across the chest, hands tucked by the opposite elbow
			local lift = side == "Left" and 0.12 or -0.02
			target = ut.Position + fwd * (0.85 * k) - up * ((0.35 - lift) * k) - right * sgn * (0.55 * k)
			pole = S + right * sgn * (2.2 * k) + fwd * (1.2 * k) - up * (1.4 * k)
		elseif name == "SideChest" then
			-- torso twisted, lead arm bent at 90, rear hand gripping the lead wrist
			local lead = side == "Right"
			target = chest + right * ((lead and 0.35 or 0.05) * k) - up * ((lead and 0.1 or 0.18) * k)
			pole = S + right * sgn * (1.8 * k) - up * (2 * k) + (lead and fwd * (0.4 * k) or -fwd * (0.6 * k))
		elseif name == "Point" and side == "Right" then
			-- arm stretched out toward the crowd
			target = S + (fwd * 0.8 + up * 0.5 + right * 0.3).Unit * (3.2 * k)
			pole = S - up * (2 * k) + right * (0.8 * k)
		else -- LatSpread (and Point's free arm): fists on the waist, elbows flared
			target = lt * Vector3.new(sgn * (d.ShoulderHalfWidth - 0.25 * k), 0.3 * k, 0.12 * k)
			pole = S + right * sgn * (2.6 * k) - fwd * (1.1 * k)
		end
		rig:armIK(side, target, pole)
	end
	local n = NECK[name]
	if n then
		rig:set("Neck", CFrame.Angles(math.rad(n[1]), math.rad(n[2]), 0))
	end
end

return Poses
