--[[
	DropClocks
	Counts down the guaranteed drops on the clock board in the wall above the
	drop gate (tools/map/ClockBoard.luau): a Legendary every 5 minutes, a
	Mythic every 15. Times come from the server (workspace attributes
	GuaranteeLegendaryAt / GuaranteeMythicAt, in server time).
]]

local RunService = game:GetService("RunService")

local ROWS = {
	{ Name = "Legendary", Word = "LEGENDARY", Hex = "#FFB02E", Attr = "GuaranteeLegendaryAt" },
	{ Name = "Mythic", Word = "MYTHIC", Hex = "#FF3878", Attr = "GuaranteeMythicAt" },
}

local map = workspace:WaitForChild("GymWarsMap")

local function labels()
	local out = {}
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Name == "Clock" then
			for _, row in ipairs(ROWS) do
				local l = d:FindFirstChild(row.Name)
				if l then
					table.insert(out, { Label = l, Row = row })
				end
			end
		end
	end
	return out
end

local function fmt(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local list = labels()
map.DescendantAdded:Connect(function(d)
	if d:IsA("SurfaceGui") and d.Name == "Clock" then
		task.defer(function()
			list = labels()
		end)
	end
end)

local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.2 then
		return
	end
	accum = 0
	local now = workspace:GetServerTimeNow()
	for _, e in ipairs(list) do
		local at = workspace:GetAttribute(e.Row.Attr)
		local left = at and (at - now) or nil
		local time = left and (left <= 0.5 and "NOW" or fmt(left)) or "--:--"
		e.Label.Text = ('<font color="%s">%s</font>   %s'):format(e.Row.Hex, e.Row.Word, time)
	end
end)
