--[[
	RigSolver
	Tiny forward-kinematics + analytic two-bone IK solver for R15 rigs.

	Works with both classic Motor6D rigs and Avatar-Joint-Upgrade rigs
	(AnimationConstraint). Every pose is solved in WORLD space, so equipment
	(bars, handles, pedals) can drive the limbs directly: put the hands on the
	bar, move the bar, and the arms follow.

	Usage (client, every RunService.PreSimulation):
		local rig = RigSolver.new(model)
		rig:reset()
		rig:setPelvis(worldCF)             -- LowerTorso world CFrame
		rig:orient("Waist", worldRot)      -- UpperTorso world rotation
		rig:armIK("Left", gripPos, polePos)
		rig:plantFoot("Right", soleCF, polePos)
		rig:apply()                         -- writes joint Transforms
]]

local RigSolver = {}
RigSolver.__index = RigSolver

-- joint name, child part (joint lives in it), parent part
local JOINTS = {
	{ "Root", "LowerTorso", "HumanoidRootPart" },
	{ "Waist", "UpperTorso", "LowerTorso" },
	{ "Neck", "Head", "UpperTorso" },
	{ "LeftShoulder", "LeftUpperArm", "UpperTorso" },
	{ "LeftElbow", "LeftLowerArm", "LeftUpperArm" },
	{ "LeftWrist", "LeftHand", "LeftLowerArm" },
	{ "RightShoulder", "RightUpperArm", "UpperTorso" },
	{ "RightElbow", "RightLowerArm", "RightUpperArm" },
	{ "RightWrist", "RightHand", "RightLowerArm" },
	{ "LeftHip", "LeftUpperLeg", "LowerTorso" },
	{ "LeftKnee", "LeftLowerLeg", "LeftUpperLeg" },
	{ "LeftAnkle", "LeftFoot", "LeftLowerLeg" },
	{ "RightHip", "RightUpperLeg", "LowerTorso" },
	{ "RightKnee", "RightLowerLeg", "RightUpperLeg" },
	{ "RightAnkle", "RightFoot", "RightLowerLeg" },
}
RigSolver.JOINTS = JOINTS

local IDENTITY = CFrame.new()

local function findJoint(part, name)
	local j = part:FindFirstChild(name)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
		return j
	end
	-- some rigs name joints differently; take any animatable joint in the part
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("AnimationConstraint") or child:IsA("Motor6D") then
			return child
		end
	end
	return nil
end

local function jointFrames(j)
	if j:IsA("Motor6D") then
		return j.C0, j.C1
	end
	return j.Attachment0.CFrame, j.Attachment1.CFrame
end

local function rotOnly(cf)
	return cf - cf.Position
end

local function safeUnit(v, fallback)
	local m = v.Magnitude
	if m < 1e-6 then
		return fallback
	end
	return v / m
end

-- ----------------------------------------------------------------------
function RigSolver.new(model)
	local self = setmetatable({}, RigSolver)
	self.Model = model
	self.Parts = {}
	self.J = {} -- [jointName] = { Inst, C0, C1, Part, Parent }
	self.T = {} -- [jointName] = CFrame transform
	self.W = {} -- [partName] = world CFrame (solved)
	self.Dirty = true

	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root, "RigSolver: model has no HumanoidRootPart")
	self.Parts.HumanoidRootPart = root

	for _, def in ipairs(JOINTS) do
		local jointName, partName, parentName = def[1], def[2], def[3]
		local part = model:FindFirstChild(partName)
		if not part then
			error("RigSolver: missing part " .. partName)
		end
		self.Parts[partName] = part
		local inst = findJoint(part, jointName)
		if not inst then
			error("RigSolver: missing joint " .. jointName)
		end
		local c0, c1 = jointFrames(inst)
		self.J[jointName] = { Inst = inst, C0 = c0, C1 = c1, Part = partName, Parent = parentName }
		self.T[jointName] = IDENTITY
	end

	self:_measure()
	return self
end

-- Rig proportions, measured from the joint frames (works for any body scale).
function RigSolver:_measure()
	local J = self.J
	local d = {}
	d.LegUpper = (J.LeftKnee.C0.Position - J.LeftHip.C1.Position).Magnitude
	d.LegLower = (J.LeftAnkle.C0.Position - J.LeftKnee.C1.Position).Magnitude
	d.ArmUpper = (J.LeftElbow.C0.Position - J.LeftShoulder.C1.Position).Magnitude
	d.ArmLower = (J.LeftWrist.C0.Position - J.LeftElbow.C1.Position).Magnitude
	d.WristToGrip = J.LeftWrist.C1.Position.Magnitude
	local foot = self.Parts.LeftFoot
	d.FootHeight = foot.Size.Y
	-- sole (bottom-center of the foot) -> ankle pivot, in foot space
	d.SoleToAnkle = J.LeftAnkle.C1.Position + Vector3.new(0, foot.Size.Y / 2, 0)
	d.HipLocal = { Left = J.LeftHip.C0.Position, Right = J.RightHip.C0.Position }
	d.ShoulderLocal = { Left = J.LeftShoulder.C0.Position, Right = J.RightShoulder.C0.Position }
	d.LegLength = d.LegUpper + d.LegLower
	d.ArmReach = d.ArmUpper + d.ArmLower + d.WristToGrip
	-- LowerTorso-center height above the floor when standing straight
	d.StandPelvisY = -J.LeftHip.C0.Position.Y + d.LegLength + d.SoleToAnkle.Y
	d.PelvisDepth = self.Parts.LowerTorso.Size.Z
	d.ChestDepth = self.Parts.UpperTorso.Size.Z
	d.ShoulderHalfWidth = math.abs(J.LeftShoulder.C0.Position.X)
	d.Scale = d.LegLength / 2.4 -- 1 for a standard-size R15 body
	self.Dims = d
end

-- ----------------------------------------------------------------------
-- Forward kinematics
-- ----------------------------------------------------------------------
function RigSolver:reset()
	for name in pairs(self.T) do
		self.T[name] = IDENTITY
	end
	self.Dirty = true
end

function RigSolver:setRootCFrame(cf)
	-- override where the HumanoidRootPart is (defaults to its real CFrame)
	self.RootCF = cf
	self.Dirty = true
end

function RigSolver:solve()
	if not self.Dirty then
		return self.W
	end
	local W = self.W
	W.HumanoidRootPart = self.RootCF or self.Parts.HumanoidRootPart.CFrame
	for _, def in ipairs(JOINTS) do
		local j = self.J[def[1]]
		W[j.Part] = W[j.Parent] * j.C0 * self.T[def[1]] * j.C1:Inverse()
	end
	self.Dirty = false
	return W
end

function RigSolver:world(partName)
	return self:solve()[partName]
end

-- world position of a joint's pivot
function RigSolver:pivot(jointName)
	local j = self.J[jointName]
	return (self:world(j.Parent) * j.C0).Position
end

function RigSolver:set(jointName, transform)
	self.T[jointName] = transform
	self.Dirty = true
end

-- Rotate a joint so its child part ends up with world rotation `worldRot`.
function RigSolver:orient(jointName, worldRot)
	local j = self.J[jointName]
	local parentCF = self:world(j.Parent)
	self.T[jointName] = rotOnly(parentCF * j.C0):Inverse() * rotOnly(worldRot) * rotOnly(j.C1)
	self.Dirty = true
end

-- Put the LowerTorso exactly at `worldCF` (moves/rotates the whole body).
function RigSolver:setPelvis(worldCF)
	local j = self.J.Root
	local rootCF = self.RootCF or self.Parts.HumanoidRootPart.CFrame
	self.T.Root = (rootCF * j.C0):Inverse() * worldCF * j.C1
	self.Dirty = true
end

-- Rotate the head toward a world point. `limit` = max yaw/pitch in radians.
function RigSolver:lookAt(point, weight, limit)
	weight = weight or 1
	limit = limit or math.rad(60)
	local ut = self:world("UpperTorso")
	local j = self.J.Neck
	local neckPivot = (ut * j.C0).Position
	local localDir = rotOnly(ut):PointToObjectSpace(point - neckPivot)
	if localDir.Magnitude < 1e-3 then
		return
	end
	localDir = localDir.Unit
	local yaw = math.atan2(-localDir.X, -localDir.Z)
	local pitch = math.asin(math.clamp(localDir.Y, -1, 1))
	yaw = math.clamp(yaw, -limit, limit) * weight
	pitch = math.clamp(pitch, -limit * 0.7, limit * 0.7) * weight
	self:set("Neck", CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0))
end

-- ----------------------------------------------------------------------
-- Two-bone IK
-- ----------------------------------------------------------------------
-- hingeSign: +1 for arms (elbow bends forward), -1 for legs (knee bends back)
function RigSolver:_twoBone(upperName, lowerName, endName, target, pole, hingeSign, endRot)
	local U, L, E = self.J[upperName], self.J[lowerName], self.J[endName]
	local parentCF = self:world(U.Parent)
	local S = (parentCF * U.C0).Position

	local v1 = L.C0.Position - U.C1.Position -- upper bone, in upper-part space
	local v2 = E.C0.Position - L.C1.Position -- lower bone, in lower-part space
	local l1, l2 = v1.Magnitude, v2.Magnitude

	local toT = target - S
	local dir = safeUnit(toT, Vector3.new(0, -1, 0))
	local dist = math.clamp(toT.Magnitude, math.abs(l1 - l2) + 1e-3, (l1 + l2) * 0.9995)

	local toPole = pole - S
	local bend = toPole - dir * toPole:Dot(dir)
	bend = safeUnit(bend, safeUnit(dir:Cross(Vector3.new(1, 0, 0)), Vector3.new(0, 0, -1)))

	local a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(l1 * l1 - a * a, 0))
	local elbow = S + dir * a + bend * h
	local tip = S + dir * dist

	local n = bend:Cross(dir).Unit -- bend-plane normal (hinge axis, world)
	local hingeLocal = Vector3.new(hingeSign, 0, 0)

	local function boneRotation(localBone, worldBone)
		local b = localBone.Unit
		local hl = safeUnit(hingeLocal - b * hingeLocal:Dot(b), Vector3.new(0, 0, 1))
		local mLocal = CFrame.fromMatrix(Vector3.zero, b, hl, b:Cross(hl))
		local wb = safeUnit(worldBone, dir)
		local wn = safeUnit(n - wb * n:Dot(wb), n)
		local mWorld = CFrame.fromMatrix(Vector3.zero, wb, wn, wb:Cross(wn))
		return mWorld * mLocal:Inverse()
	end

	local rU = boneRotation(v1, elbow - S)
	local upperCF = CFrame.new(S) * rU * CFrame.new(-U.C1.Position)
	self.T[upperName] = (parentCF * U.C0):Inverse() * upperCF * U.C1

	local rL = boneRotation(v2, tip - elbow)
	local lowerCF = CFrame.new(elbow) * rL * CFrame.new(-L.C1.Position)
	self.T[lowerName] = (upperCF * L.C0):Inverse() * lowerCF * L.C1

	if endRot then
		self.T[endName] = rotOnly(lowerCF * E.C0):Inverse() * rotOnly(endRot) * rotOnly(E.C1)
	else
		self.T[endName] = IDENTITY
	end
	self.Dirty = true
	return elbow, tip
end

-- Put a hand's grip point (≈ palm center) on `grip`.
function RigSolver:armIK(side, grip, pole, handRot)
	local wristName = side .. "Wrist"
	local d = self.Dims
	local wrist
	if handRot then
		wrist = grip + rotOnly(handRot) * self.J[wristName].C1.Position
	else
		local S = self:pivot(side .. "Shoulder")
		wrist = grip - safeUnit(grip - S, Vector3.new(0, -1, 0)) * d.WristToGrip
	end
	local elbow, tip = self:_twoBone(side .. "Shoulder", side .. "Elbow", wristName, wrist, pole, 1, handRot)
	if not handRot then
		-- second pass: re-aim the wrist along the solved forearm
		local fore = safeUnit(tip - elbow, Vector3.new(0, -1, 0))
		wrist = grip - fore * d.WristToGrip
		self:_twoBone(side .. "Shoulder", side .. "Elbow", wristName, wrist, pole, 1, nil)
	end
end

-- Put a foot's sole (bottom-center) at `soleCF` (position + orientation).
function RigSolver:plantFoot(side, soleCF, pole)
	local ankle = (soleCF * CFrame.new(self.Dims.SoleToAnkle)).Position
	self:_twoBone(side .. "Hip", side .. "Knee", side .. "Ankle", ankle, pole, -1, soleCF)
end

-- Put a foot's ankle pivot at `ankle` and let the foot follow the shin.
function RigSolver:legIK(side, ankle, pole, footRot)
	self:_twoBone(side .. "Hip", side .. "Knee", side .. "Ankle", ankle, pole, -1, footRot)
end

-- ----------------------------------------------------------------------
-- Output
-- ----------------------------------------------------------------------
function RigSolver:apply()
	for name, j in pairs(self.J) do
		j.Inst.Transform = self.T[name]
	end
end

-- Blend every joint from a snapshot `from` (table of transforms) toward the
-- current pose by alpha. Root is blended in world space by the caller.
function RigSolver:snapshot()
	local s = {}
	for name, t in pairs(self.T) do
		s[name] = t
	end
	return s
end

function RigSolver:blendFrom(snapshot, alpha)
	if alpha >= 1 then
		return
	end
	for name, t in pairs(self.T) do
		local from = snapshot[name]
		if from then
			self.T[name] = from:Lerp(t, alpha)
		end
	end
	self.Dirty = true
end

return RigSolver
