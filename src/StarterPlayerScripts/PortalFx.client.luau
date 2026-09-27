--[[
	PortalFx
	Brings the spawn / exit gates to life on each client (parts built by
	tools/map/Portal.luau, tagged with a "PortalFx" attribute):
	  Chase    marquee bulbs running around the sign and up the pillars
	  Pulse    the glowing portal disc breathing
	  Curtain  light-curtain slats shimmering
	  Sweep    searchlights sweeping the sky
]]

local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("GymWarsMap")

local chase, pulse, curtain, sweep = {}, {}, {}, {}
local BULB_ON = Color3.fromRGB(255, 240, 200)
local BULB_OFF = Color3.fromRGB(90, 70, 40)

local function register(p)
	if not p:IsA("BasePart") then
		return
	end
	local fx = p:GetAttribute("PortalFx")
	if fx == "Chase" then
		table.insert(chase, { Part = p, Index = p:GetAttribute("Index") or 0 })
	elseif fx == "Pulse" then
		table.insert(pulse, { Part = p, Light = p:FindFirstChildOfClass("PointLight") })
	elseif fx == "Curtain" then
		table.insert(curtain, { Part = p, Index = p:GetAttribute("Index") or 0 })
	elseif fx == "Sweep" then
		table.insert(sweep, { Part = p, Rest = p.CFrame, Phase = p:GetAttribute("Phase") or 0 })
	end
end

for _, d in ipairs(map:GetDescendants()) do
	register(d)
end
map.DescendantAdded:Connect(register)

local lastStep = -1
RunService.RenderStepped:Connect(function()
	local t = os.clock()

	-- marquee: every third bulb lit, marching along (only update on a step)
	local step = math.floor(t * 7)
	if step ~= lastStep then
		lastStep = step
		for _, b in ipairs(chase) do
			local on = (b.Index + step) % 3 == 0
			b.Part.Color = on and BULB_ON or BULB_OFF
			b.Part.Transparency = on and 0 or 0.35
		end
	end

	for _, p in ipairs(pulse) do
		local k = 0.5 + 0.5 * math.sin(t * 2.2)
		p.Part.Transparency = 0.1 + 0.25 * (1 - k)
		if p.Light then
			p.Light.Brightness = 2 + 2.5 * k
		end
	end

	for _, c in ipairs(curtain) do
		c.Part.Transparency = 0.62 + 0.3 * (0.5 + 0.5 * math.sin(t * 5 + c.Index * 0.8))
	end

	for _, s in ipairs(sweep) do
		local yaw = math.sin(t * 0.6 + s.Phase) * 0.7
		local pitch = 0.12 * math.sin(t * 0.9 + s.Phase)
		s.Part.CFrame = s.Rest * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	end
end)
