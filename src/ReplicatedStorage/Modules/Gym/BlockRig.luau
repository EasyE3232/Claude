--[[
	BlockRig
	Builds a standard-proportion R15 rig out of plain Parts + Motor6Ds.
	Used as a fallback when Players:CreateHumanoidModelFromDescriptionAsync is
	unavailable (e.g. offline tests), so the game never ends up without NPCs.
	Built standing on y = 0, facing -Z.
]]

local BlockRig = {}

-- name = { center, size }
local PARTS = {
	HumanoidRootPart = { Vector3.new(0, 3.0, 0), Vector3.new(2, 2, 1) },
	LowerTorso = { Vector3.new(0, 2.95, 0), Vector3.new(2, 0.4, 1) },
	UpperTorso = { Vector3.new(0, 3.95, 0), Vector3.new(2, 1.6, 1) },
	Head = { Vector3.new(0, 5.35, 0), Vector3.new(1.2, 1.2, 1.2) },
	LeftUpperArm = { Vector3.new(-1.5, 4.15, 0), Vector3.new(1, 1.2, 1) },
	LeftLowerArm = { Vector3.new(-1.5, 3.05, 0), Vector3.new(1, 1.0, 1) },
	LeftHand = { Vector3.new(-1.5, 2.38, 0), Vector3.new(1, 0.35, 1) },
	RightUpperArm = { Vector3.new(1.5, 4.15, 0), Vector3.new(1, 1.2, 1) },
	RightLowerArm = { Vector3.new(1.5, 3.05, 0), Vector3.new(1, 1.0, 1) },
	RightHand = { Vector3.new(1.5, 2.38, 0), Vector3.new(1, 0.35, 1) },
	LeftUpperLeg = { Vector3.new(-0.5, 2.15, 0), Vector3.new(1, 1.2, 1) },
	LeftLowerLeg = { Vector3.new(-0.5, 0.95, 0), Vector3.new(1, 1.2, 1) },
	LeftFoot = { Vector3.new(-0.5, 0.15, -0.1), Vector3.new(1, 0.3, 1.2) },
	RightUpperLeg = { Vector3.new(0.5, 2.15, 0), Vector3.new(1, 1.2, 1) },
	RightLowerLeg = { Vector3.new(0.5, 0.95, 0), Vector3.new(1, 1.2, 1) },
	RightFoot = { Vector3.new(0.5, 0.15, -0.1), Vector3.new(1, 0.3, 1.2) },
}

-- joint = { part1, part0, pivot (world, standing) }
local JOINTS = {
	{ "Root", "LowerTorso", "HumanoidRootPart", Vector3.new(0, 2.95, 0) },
	{ "Waist", "UpperTorso", "LowerTorso", Vector3.new(0, 3.15, 0) },
	{ "Neck", "Head", "UpperTorso", Vector3.new(0, 4.75, 0) },
	{ "LeftShoulder", "LeftUpperArm", "UpperTorso", Vector3.new(-1.5, 4.45, 0) },
	{ "LeftElbow", "LeftLowerArm", "LeftUpperArm", Vector3.new(-1.5, 3.55, 0) },
	{ "LeftWrist", "LeftHand", "LeftLowerArm", Vector3.new(-1.5, 2.55, 0) },
	{ "RightShoulder", "RightUpperArm", "UpperTorso", Vector3.new(1.5, 4.45, 0) },
	{ "RightElbow", "RightLowerArm", "RightUpperArm", Vector3.new(1.5, 3.55, 0) },
	{ "RightWrist", "RightHand", "RightLowerArm", Vector3.new(1.5, 2.55, 0) },
	{ "LeftHip", "LeftUpperLeg", "LowerTorso", Vector3.new(-0.5, 2.75, 0) },
	{ "LeftKnee", "LeftLowerLeg", "LeftUpperLeg", Vector3.new(-0.5, 1.55, 0) },
	{ "LeftAnkle", "LeftFoot", "LeftLowerLeg", Vector3.new(-0.5, 0.35, 0) },
	{ "RightHip", "RightUpperLeg", "LowerTorso", Vector3.new(0.5, 2.75, 0) },
	{ "RightKnee", "RightLowerLeg", "RightUpperLeg", Vector3.new(0.5, 1.55, 0) },
	{ "RightAnkle", "RightFoot", "RightLowerLeg", Vector3.new(0.5, 0.35, 0) },
}

function BlockRig.Build(colors)
	colors = colors or {}
	local skin = colors.Skin or Color3.fromRGB(234, 184, 146)
	local shirt = colors.Shirt or Color3.fromRGB(80, 80, 90)
	local pants = colors.Pants or Color3.fromRGB(40, 40, 46)
	local k = colors.Scale or 1

	local model = Instance.new("Model")
	model.Name = "Rig"
	local parts = {}
	for name, def in pairs(PARTS) do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = def[2] * k
		p.CFrame = CFrame.new(def[1] * k)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.Anchored = false
		if name == "HumanoidRootPart" then
			p.Transparency = 1
		elseif name == "UpperTorso" or name == "LowerTorso" then
			p.Color = name == "UpperTorso" and shirt or pants
		elseif name:find("Leg") or name:find("Foot") then
			p.Color = pants
		else
			p.Color = skin
		end
		if name == "Head" then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = model
		parts[name] = p
	end
	for _, j in ipairs(JOINTS) do
		local name, p1, p0, pivot = j[1], parts[j[2]], parts[j[3]], j[4] * k
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = CFrame.new(pivot - p0.CFrame.Position)
		m.C1 = CFrame.new(pivot - p1.CFrame.Position)
		m.Parent = p1
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2 * k
	hum.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = hum
	model.PrimaryPart = parts.HumanoidRootPart
	return model
end

return BlockRig
