--[[
	GYM WARS — client UI
	HUD, Shop (Clothing / Equipment / Boosters), Rebirth panel, Gym color picker,
	toasts. Everything is built in code (no external assets) and reads state
	from leaderstats + player attributes that the server keeps in sync.
	The client never changes game state itself — it only asks the server.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Constants = require(RS:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = RS:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ======================================================================
-- Style
-- ======================================================================
local PANEL = Color3.fromRGB(20, 22, 30)
local PANEL_2 = Color3.fromRGB(30, 33, 44)
local TEXT = Color3.fromRGB(240, 242, 248)
local SUB = Color3.fromRGB(150, 158, 175)
local GOLD = Color3.fromRGB(244, 201, 58)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(230, 80, 70)
local BLUE = Color3.fromRGB(79, 157, 251)
local PURPLE = Color3.fromRGB(176, 107, 240)
local LOCKED = Color3.fromRGB(70, 74, 88)

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(60, 64, 80)
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.Font or Enum.Font.GothamBold
	l.TextSize = props.TextSize or 14
	l.TextColor3 = props.Color or TEXT
	l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	l.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	l.TextWrapped = props.Wrapped or false
	l.RichText = props.Rich or false
	l.Size = props.Size or UDim2.new(1, 0, 0, 20)
	l.Position = props.Position or UDim2.new(0, 0, 0, 0)
	l.Text = props.Text or ""
	l.Name = props.Name or "Label"
	l.Parent = parent
	return l
end

local function button(parent, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = props.Color or GREEN
	b.Font = Enum.Font.GothamBlack
	b.TextSize = props.TextSize or 14
	b.TextColor3 = props.TextColor or Color3.fromRGB(15, 15, 20)
	b.Size = props.Size or UDim2.new(0, 100, 0, 34)
	b.Position = props.Position or UDim2.new(0, 0, 0, 0)
	b.AnchorPoint = props.Anchor or Vector2.new(0, 0)
	b.Text = props.Text or ""
	b.Name = props.Name or "Button"
	b.Parent = parent
	corner(b, props.Radius or 8)
	return b
end

local function decode(attr, fallback)
	local raw = player:GetAttribute(attr)
	if type(raw) ~= "string" or raw == "" then
		return fallback
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(data) == "table" then
		return data
	end
	return fallback
end

local fmt = Constants.FormatNumber

-- ======================================================================
-- Root
-- ======================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "GymWarsUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- ======================================================================
-- Stats panel (top-left)
-- ======================================================================
local stats = Instance.new("Frame")
stats.Name = "Stats"
stats.Size = UDim2.new(0, 250, 0, 150)
stats.Position = UDim2.new(0, 14, 0, 14)
stats.BackgroundColor3 = PANEL
stats.BackgroundTransparency = 0.08
stats.Parent = gui
corner(stats, 12)
stroke(stats)

local cashLabel = label(stats, {
	Name = "Cash",
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	Color = GREEN,
	Size = UDim2.new(1, -24, 0, 32),
	Position = UDim2.new(0, 12, 0, 8),
	Text = "$0",
})
local incomeLabel = label(stats, {
	Name = "Income",
	TextSize = 13,
	Color = SUB,
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.new(0, 12, 0, 40),
	Text = "+$0/s",
})
local strengthLabel = label(stats, {
	Name = "Strength",
	TextSize = 16,
	Color = TEXT,
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.new(0, 12, 0, 64),
	Text = "Strength: 0",
})
local rebirthLabel = label(stats, {
	Name = "Rebirths",
	TextSize = 14,
	Color = PURPLE,
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.new(0, 12, 0, 88),
	Text = "Rebirths: 0",
})
local rackLabel = label(stats, {
	Name = "Rack",
	TextSize = 14,
	Color = BLUE,
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.new(0, 12, 0, 110),
	Text = "Machines: 0/4",
})

-- Booster timers (under stats)
local boosterBar = Instance.new("Frame")
boosterBar.Name = "Boosters"
boosterBar.Size = UDim2.new(0, 250, 0, 0)
boosterBar.AutomaticSize = Enum.AutomaticSize.Y
boosterBar.Position = UDim2.new(0, 14, 0, 172)
boosterBar.BackgroundTransparency = 1
boosterBar.Parent = gui
local boosterLayout = Instance.new("UIListLayout")
boosterLayout.Padding = UDim.new(0, 6)
boosterLayout.Parent = boosterBar

-- Carrying banner (top-center)
local carryBanner = label(gui, {
	Name = "Carrying",
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	Color = GOLD,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.new(0, 520, 0, 30),
	Position = UDim2.new(0.5, -260, 0, 14),
	Text = "",
})
carryBanner.TextStrokeTransparency = 0.4

local stunBanner = label(gui, {
	Name = "Stunned",
	Font = Enum.Font.GothamBlack,
	TextSize = 34,
	Color = RED,
	XAlign = Enum.TextXAlignment.Center,
	Size = UDim2.new(0, 520, 0, 40),
	Position = UDim2.new(0.5, -260, 0.35, 0),
	Text = "",
})
stunBanner.TextStrokeTransparency = 0.3

-- ======================================================================
-- Menu buttons (right side)
-- ======================================================================
local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.Size = UDim2.new(0, 130, 0, 150)
menu.Position = UDim2.new(1, -144, 0.5, -75)
menu.BackgroundTransparency = 1
menu.Parent = gui
local menuLayout = Instance.new("UIListLayout")
menuLayout.Padding = UDim.new(0, 10)
menuLayout.Parent = menu

local shopBtn = button(menu, { Name = "ShopBtn", Text = "SHOP", Color = GOLD, Size = UDim2.new(1, 0, 0, 42), TextSize = 17 })
local rebirthBtn = button(menu, { Name = "RebirthBtn", Text = "REBIRTH", Color = PURPLE, Size = UDim2.new(1, 0, 0, 42), TextSize = 17, TextColor = TEXT })
local colorBtn = button(menu, { Name = "ColorBtn", Text = "GYM COLOR", Color = BLUE, Size = UDim2.new(1, 0, 0, 42), TextSize = 15, TextColor = TEXT })

-- ======================================================================
-- Generic modal panel
-- ======================================================================
local openPanel = nil

local function makePanel(name, title, width, height)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0, width, 0, height)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = PANEL
	frame.Visible = false
	frame.ZIndex = 5
	frame.Parent = gui
	corner(frame, 14)
	stroke(frame, Color3.fromRGB(80, 86, 105), 2)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(width, height)
	sizeLimit.Parent = frame

	label(frame, {
		Name = "Title",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Size = UDim2.new(1, -70, 0, 40),
		Position = UDim2.new(0, 18, 0, 8),
		Text = title,
	})

	local close = button(frame, {
		Name = "Close",
		Text = "X",
		Color = RED,
		TextColor = TEXT,
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -46, 0, 10),
	})
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
		if openPanel == frame then
			openPanel = nil
		end
	end)
	return frame
end

local function togglePanel(frame, refresh)
	if openPanel and openPanel ~= frame then
		openPanel.Visible = false
	end
	frame.Visible = not frame.Visible
	openPanel = frame.Visible and frame or nil
	if frame.Visible and refresh then
		refresh()
	end
end

-- ======================================================================
-- SHOP
-- ======================================================================
local shop = makePanel("Shop", "GYM SHOP", 620, 460)

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.Size = UDim2.new(1, -36, 0, 36)
tabs.Position = UDim2.new(0, 18, 0, 54)
tabs.BackgroundTransparency = 1
tabs.Parent = shop
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabs

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Size = UDim2.new(1, -36, 1, -110)
list.Position = UDim2.new(0, 18, 0, 98)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local currentTab = "Clothing"
local tabButtons = {}

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function row(order, titleText, subText, rightText)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -8, 0, 58)
	r.BackgroundColor3 = PANEL_2
	r.LayoutOrder = order
	r.Parent = list
	corner(r, 10)
	label(r, {
		Name = "Title",
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		Size = UDim2.new(1, -250, 0, 22),
		Position = UDim2.new(0, 12, 0, 7),
		Text = titleText,
	})
	label(r, {
		Name = "Sub",
		TextSize = 12,
		Color = SUB,
		Size = UDim2.new(1, -250, 0, 20),
		Position = UDim2.new(0, 12, 0, 30),
		Text = subText,
		Rich = true,
	})
	if rightText then
		label(r, {
			Name = "Right",
			TextSize = 12,
			Color = SUB,
			XAlign = Enum.TextXAlignment.Right,
			Size = UDim2.new(0, 110, 0, 58),
			Position = UDim2.new(1, -240, 0, 0),
			Text = rightText,
		})
	end
	return r
end

local function actionButton(r, text, color, enabled, onClick)
	local b = button(r, {
		Text = text,
		Color = enabled and color or LOCKED,
		TextColor = enabled and Color3.fromRGB(15, 15, 20) or SUB,
		Size = UDim2.new(0, 116, 0, 38),
		Position = UDim2.new(1, -126, 0.5, 0),
		Anchor = Vector2.new(0, 0.5),
		TextSize = 13,
	})
	b.AutoButtonColor = enabled
	if enabled then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end

local refreshShop -- forward declare

local function stat(name)
	if name == "Cash" then
		return player:GetAttribute("Cash") or 0 -- exact value (leaderboard shows the short text)
	end
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	return v and v.Value or 0
end

local function buildClothing()
	local owned = decode("OwnedClothing", {})
	local equipped = decode("Equipped", {})
	local strength = stat("Strength")
	local cash = stat("Cash")

	for i, item in ipairs(Constants.CLOTHING) do
		local isOwned = owned[item.Id] == true
		local isEquipped = equipped[item.Slot] == item.Id
		local unlocked = strength >= item.Strength
		local sub = string.format("%s  •  <font color=\"#5ADC78\">+%d%% income</font>  •  needs %s Strength",
			item.Slot, math.floor(item.Bonus * 100), fmt(item.Strength))
		local r = row(i, item.Name, sub, isOwned and "OWNED" or ("$" .. fmt(item.Price)))

		if isEquipped then
			actionButton(r, "EQUIPPED", GREEN, false, nil)
		elseif isOwned then
			actionButton(r, "EQUIP", BLUE, true, function()
				Remotes.Equip:InvokeServer(item.Id)
				refreshShop()
			end)
		elseif not unlocked then
			actionButton(r, "LOCKED", LOCKED, false, nil)
		else
			actionButton(r, "BUY", GOLD, cash >= item.Price, function()
				Remotes.Purchase:InvokeServer("Clothing", item.Id)
				refreshShop()
			end)
		end
	end
end

local function buildEquipment()
	local levels = decode("Equipment", {})
	local cash = stat("Cash")
	for i, id in ipairs(Constants.EQUIPMENT_ORDER) do
		local def = Constants.EQUIPMENT[id]
		local level = levels[id] or 1
		local maxed = level >= #def.Values
		local now = def.Values[level]
		local sub
		if maxed then
			sub = string.format("%s  •  Lv %d (MAX)  •  %s%s", def.Desc, level, fmt(now), def.Unit)
		else
			sub = string.format("%s  •  Lv %d  •  %s → <font color=\"#5ADC78\">%s</font>%s",
				def.Desc, level, fmt(now), fmt(def.Values[level + 1]), def.Unit)
		end
		local cost = not maxed and def.Costs[level + 1] or nil
		local r = row(i, def.Name, sub, maxed and "MAX" or ("$" .. fmt(cost)))
		if maxed then
			actionButton(r, "MAXED", GREEN, false, nil)
		else
			actionButton(r, "UPGRADE", GOLD, cash >= cost, function()
				Remotes.Purchase:InvokeServer("Equipment", id)
				refreshShop()
			end)
		end
	end
end

local function buildBoosters()
	local active = decode("Boosters", {})
	local cash = stat("Cash")
	for i, b in ipairs(Constants.BOOSTERS) do
		local expires = active[b.Id]
		local left = expires and (expires - os.time()) or 0
		local sub = b.Desc
		if left > 0 then
			sub = sub .. string.format("  •  <font color=\"#F4C93A\">ACTIVE %d:%02d</font>", left // 60, left % 60)
		end
		local r = row(i, b.Name, sub, "$" .. fmt(b.Price))
		actionButton(r, left > 0 and "EXTEND" or "BUY", GOLD, cash >= b.Price, function()
			Remotes.Purchase:InvokeServer("Booster", b.Id)
			refreshShop()
		end)
	end
end

refreshShop = function()
	if not shop.Visible then
		return
	end
	clearList()
	for name, b in pairs(tabButtons) do
		b.BackgroundColor3 = (name == currentTab) and GOLD or PANEL_2
		b.TextColor3 = (name == currentTab) and Color3.fromRGB(15, 15, 20) or TEXT
	end
	if currentTab == "Clothing" then
		buildClothing()
	elseif currentTab == "Equipment" then
		buildEquipment()
	else
		buildBoosters()
	end
end

for _, name in ipairs({ "Clothing", "Equipment", "Boosters" }) do
	local b = button(tabs, { Name = name, Text = name:upper(), Color = PANEL_2, TextColor = TEXT, Size = UDim2.new(0, 130, 1, 0) })
	tabButtons[name] = b
	b.MouseButton1Click:Connect(function()
		currentTab = name
		refreshShop()
	end)
end

shopBtn.MouseButton1Click:Connect(function()
	togglePanel(shop, refreshShop)
end)

-- ======================================================================
-- REBIRTH
-- ======================================================================
local rebirthPanel = makePanel("RebirthPanel", "REBIRTH", 460, 330)
local rebirthInfo = label(rebirthPanel, {
	Name = "Info",
	TextSize = 15,
	Wrapped = true,
	Rich = true,
	YAlign = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, -36, 0, 200),
	Position = UDim2.new(0, 18, 0, 56),
	Text = "",
})
local rebirthGo = button(rebirthPanel, {
	Name = "Go",
	Text = "REBIRTH NOW",
	Color = PURPLE,
	TextColor = TEXT,
	Size = UDim2.new(1, -36, 0, 46),
	Position = UDim2.new(0, 18, 1, -62),
	TextSize = 18,
})

local function refreshRebirth()
	local rebirths = stat("Rebirths")
	local cash = stat("Cash")
	local threshold = Constants.RebirthThreshold(rebirths)
	local nowMult = Constants.RebirthMultiplier(rebirths)
	local nextMult = Constants.RebirthMultiplier(rebirths + 1)
	local ready = cash >= threshold
	rebirthInfo.Text = string.format(
		"Cost: <b>$%s</b>  (you have $%s)\n\nIncome multiplier: <b>x%.2f</b> → <font color=\"#B06BF0\"><b>x%.2f</b></font>\n\n"
			.. "<font color=\"#E6504A\">RESETS:</font> Cash, influencers on your rack\n"
			.. "<font color=\"#5ADC78\">KEEPS FOREVER:</font> Strength, clothing, equipment, gym color",
		fmt(threshold),
		fmt(cash),
		nowMult,
		nextMult
	)
	rebirthGo.BackgroundColor3 = ready and PURPLE or LOCKED
	rebirthGo.TextColor3 = ready and TEXT or SUB
	rebirthGo.Text = ready and "REBIRTH NOW" or ("NEED $" .. fmt(threshold))
end

rebirthGo.MouseButton1Click:Connect(function()
	local rebirths = stat("Rebirths")
	if stat("Cash") < Constants.RebirthThreshold(rebirths) then
		return
	end
	Remotes.Rebirth:InvokeServer()
	refreshRebirth()
end)

rebirthBtn.MouseButton1Click:Connect(function()
	togglePanel(rebirthPanel, refreshRebirth)
end)

-- ======================================================================
-- GYM COLOR
-- ======================================================================
local colorPanel = makePanel("ColorPanel", "GYM COLOR", 440, 250)
local grid = Instance.new("Frame")
grid.Name = "Grid"
grid.Size = UDim2.new(1, -36, 1, -70)
grid.Position = UDim2.new(0, 18, 0, 58)
grid.BackgroundTransparency = 1
grid.Parent = colorPanel
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 92, 0, 78)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local swatchStrokes = {}
for i, preset in ipairs(Constants.GYM_COLORS) do
	local sw = Instance.new("TextButton")
	sw.Name = preset.Name
	sw.LayoutOrder = i
	sw.Text = ""
	sw.BackgroundColor3 = preset.Wall
	sw.AutoButtonColor = true
	sw.Parent = grid
	corner(sw, 10)
	swatchStrokes[i] = stroke(sw, Color3.fromRGB(60, 64, 80), 2)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, -16, 0, 12)
	accent.Position = UDim2.new(0, 8, 0, 8)
	accent.BackgroundColor3 = preset.Accent
	accent.Parent = sw
	corner(accent, 6)

	label(sw, {
		TextSize = 13,
		Font = Enum.Font.GothamBlack,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -26),
		Text = preset.Name,
	})

	sw.MouseButton1Click:Connect(function()
		Remotes.SetGymColor:FireServer(i)
	end)
end

local function refreshColors()
	local current = player:GetAttribute("GymColor") or 1
	for i, s in pairs(swatchStrokes) do
		s.Color = (i == current) and GOLD or Color3.fromRGB(60, 64, 80)
		s.Thickness = (i == current) and 3 or 2
	end
end

colorBtn.MouseButton1Click:Connect(function()
	togglePanel(colorPanel, refreshColors)
end)

-- ======================================================================
-- TOASTS
-- ======================================================================
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.new(0, 440, 0, 300)
toastHolder.Position = UDim2.new(0.5, -220, 0, 52)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local toastColors = { info = GOLD, success = GREEN, fail = RED }
local toastCount = 0

local function toast(text, kind)
	toastCount += 1
	local color = toastColors[kind] or TEXT
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 40)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.05
	f.LayoutOrder = toastCount
	f.Parent = toastHolder
	corner(f, 8)
	stroke(f, color, 1.5)
	local l = label(f, {
		TextSize = 14,
		Color = color,
		Wrapped = true,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		Text = text,
	})
	-- keep the stack short
	local frames = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 5 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	task.delay(3.5, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.32)
			f:Destroy()
		end
	end)
end

Remotes.Notify.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		toast(tostring(payload.Text or ""), payload.Kind)
	end
end)

-- ======================================================================
-- HUD refresh
-- ======================================================================
local function refreshBoosters()
	for _, c in ipairs(boosterBar:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local active = decode("Boosters", {})
	for _, b in ipairs(Constants.BOOSTERS) do
		local expires = active[b.Id]
		local left = expires and (expires - os.time()) or 0
		if left > 0 then
			local l = label(boosterBar, {
				TextSize = 13,
				Font = Enum.Font.GothamBlack,
				Color = GOLD,
				Size = UDim2.new(1, 0, 0, 26),
				Text = string.format("  %s  %d:%02d", b.Name:upper(), left // 60, left % 60),
			})
			l.BackgroundTransparency = 0.15
			l.BackgroundColor3 = PANEL
			corner(l, 8)
		end
	end
end

local function refreshHUD()
	cashLabel.Text = "$" .. fmt(stat("Cash"))
	local perSec = player:GetAttribute("IncomePerSec") or 0
	local mult = player:GetAttribute("IncomeMultiplier") or 1
	incomeLabel.Text = string.format("+$%s/s   (x%.2f multiplier)", fmt(perSec), mult)
	strengthLabel.Text = "Strength: " .. fmt(stat("Strength"))
	rebirthLabel.Text = string.format("Rebirths: %d   (next at $%s)", stat("Rebirths"), fmt(Constants.RebirthThreshold(stat("Rebirths"))))
	rackLabel.Text = string.format("Machines: %d/%d", player:GetAttribute("RackUsed") or 0, player:GetAttribute("RackSlots") or 0)

	local carrying = player:GetAttribute("Carrying")
	carryBanner.Text = (carrying and carrying ~= "") and (carrying:upper() .. " IS HEADING TO YOUR GYM!") or ""
	stunBanner.Text = player:GetAttribute("Stunned") and "KNOCKED DOWN!" or ""
end

local function refreshAll()
	refreshHUD()
	refreshBoosters()
	if shop.Visible then
		refreshShop()
	end
	if rebirthPanel.Visible then
		refreshRebirth()
	end
	if colorPanel.Visible then
		refreshColors()
	end
end

-- leaderstats
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	for _, name in ipairs({ "Strength", "Rebirths" }) do
		local v = ls:WaitForChild(name)
		v.Changed:Connect(refreshHUD)
	end
	refreshAll()
end)

player.AttributeChanged:Connect(function(attr)
	if attr == "Boosters" then
		refreshBoosters()
	end
	if attr == "OwnedClothing" or attr == "Equipped" or attr == "Equipment" or attr == "Boosters" then
		if shop.Visible then
			refreshShop()
		end
	end
	if attr == "GymColor" and colorPanel.Visible then
		refreshColors()
	end
	refreshHUD()
end)

-- 1-second loop for countdowns and button affordability
task.spawn(function()
	while true do
		task.wait(1)
		refreshBoosters()
		if shop.Visible then
			refreshShop()
		end
		if rebirthPanel.Visible then
			refreshRebirth()
		end
	end
end)

refreshHUD()
