-- Generates tools/meshy/PROMPTS.md: a Meshy prompt for every character in the
-- roster (from Characters.luau looks), in the recommended build order.
--   lune run tools/meshy/prompts
local fs = require("@lune/fs")
local L = require("../lib/loader")
local C = L.require("src/ReplicatedStorage/Modules/Characters")
local K = L.require("src/ReplicatedStorage/Modules/Constants")

local NAMED = {
	{ "white", 236, 236, 238 }, { "off-white", 214, 214, 218 }, { "light gray", 196, 198, 204 }, { "gray", 118, 118, 124 },
	{ "charcoal", 52, 52, 58 }, { "dark gray", 72, 72, 78 }, { "dark brown", 58, 40, 28 }, { "sandy blond", 176, 136, 84 }, { "blond", 226, 198, 124 }, { "chestnut brown", 120, 78, 46 }, { "black", 24, 24, 27 }, { "navy", 40, 62, 96 }, { "slate blue", 72, 82, 98 },
	{ "dusty blue", 124, 144, 166 }, { "royal blue", 40, 90, 200 }, { "sky blue", 120, 180, 230 }, { "red", 178, 34, 34 },
	{ "maroon", 110, 30, 40 }, { "pink", 230, 120, 160 }, { "orange", 230, 130, 40 }, { "gold", 222, 200, 122 },
	{ "yellow", 240, 210, 60 }, { "olive green", 100, 110, 60 }, { "forest green", 40, 90, 50 }, { "green", 60, 160, 80 },
	{ "teal", 40, 140, 140 }, { "purple", 110, 60, 160 }, { "brown", 110, 74, 48 }, { "tan", 190, 160, 120 },
	{ "beige", 214, 196, 160 },
}
local function colorName(c)
	if not c then return nil end
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	local best, bd = "gray", math.huge
	for _, n in NAMED do
		local d = (r - n[2]) ^ 2 + (g - n[3]) ^ 2 + (b - n[4]) ^ 2
		if d < bd then best, bd = n[1], d end
	end
	return best
end
local SKIN = { { "very fair", 246, 214, 186 }, { "fair", 234, 190, 152 }, { "tan", 214, 164, 118 }, { "olive", 196, 146, 100 }, { "brown", 150, 100, 64 }, { "dark brown", 104, 68, 44 }, { "deep brown", 107, 63, 42 }, { "light tan", 217, 165, 122 } }
local function skinName(c)
	local r, g, b = c.R * 255, c.G * 255, c.B * 255
	local best, bd = "tan", math.huge
	for _, n in SKIN do local d = (r - n[2]) ^ 2 + (g - n[3]) ^ 2 + (b - n[4]) ^ 2 if d < bd then best, bd = n[1], d end end
	return best
end
local HAIR = {
	Bald = "bald head", Buzz = "buzz cut", Short = "short neat hair", Fringe = "short hair with a fringe", Shaggy = "shaggy messy hair",
	Curly = "short curly hair", LongCurly = "long curly hair", Wavy = "wavy swept hair", Fluffy = "fluffy voluminous hair",
	Styled = "styled textured hair", Pompadour = "tall pompadour", Floppy = "floppy hair falling over the forehead",
	SweptBack = "slicked swept-back hair", Spiky = "short spiky hair", Tied = "hair tied back in a small bun",
}
local TOP = {
	Tee = "fitted t-shirt", Oversized = "oversized boxy t-shirt", Tank = "tank top", Stringer = "deep-cut gym stringer tank",
	Hoodie = "hoodie", SleevelessHoodie = "sleeveless hoodie", Sleeveless = "sleeveless muscle shirt", Shirtless = "no shirt",
}
local BOTTOM = {
	Joggers = "slim joggers", Sweatpants = "baggy sweatpants", Shorts = "athletic shorts", LongShorts = "long basketball shorts",
	PosingShorts = "bodybuilding posing trunks", FlowingPants = "loose flowing pants",
}
local PROPS = {
	Duffel = "carrying a gym duffel bag", WaterJug = "holding a gallon water jug", Clipboard = "holding a clipboard",
	Tripod = "holding a small camera on a tripod", WristStraps = "wearing lifting wrist straps", WristWraps = "wearing wrist wraps",
	Cap = "wearing a plain baseball cap",
}
local BUILD_BY_RARITY = {
	Common = "fit, lightly muscular regular gym-goer build",
	Uncommon = "athletic, clearly muscular build",
	Rare = "very muscular, broad-shouldered build",
	Epic = "huge bodybuilder physique with big arms and shoulders",
	Legendary = "massive pro bodybuilder physique, wide back, huge arms",
	Mythic = "extreme stage-ready bodybuilder physique, shredded, very wide",
	GOAT = "legendary giant bodybuilder physique, enormous and iconic",
}
local function buildText(ch)
	local b = (ch.Look and ch.Look.Build) or {}
	local parts = { BUILD_BY_RARITY[ch.Rarity] or "muscular build" }
	if (b.Height or 1) >= 1.12 then table.insert(parts, "very tall") end
	if (b.Height or 1) <= 0.92 then table.insert(parts, "short and stocky") end
	if (b.Legs or 0) >= 1.2 then table.insert(parts, "gigantic legs") end
	if (b.Width or 1) >= 1.4 then table.insert(parts, "extremely wide") end
	if (b.Traps or 0) >= 0.8 then table.insert(parts, "huge traps") end
	return table.concat(parts, ", ")
end

local STYLE = "stylized 3D character for a Roblox game, full body, standing in an A-pose with arms slightly away from the body and hands NOT touching the legs, symmetrical, feet flat, facing forward. Clean cartoon-realistic style, bold readable shapes, hand-painted texture, plain background. No logos, no text, no tattoos, no brand marks."

local function prompt(ch)
	local lk = ch.Look or {}
	local bits = {}
	table.insert(bits, buildText(ch) .. ".")
	local hair = lk.Hair and HAIR[lk.Hair.Style] or "short hair"
	local hairColor = lk.Hair and lk.Hair.Style ~= "Bald" and colorName(lk.Hair.Color)
	table.insert(bits, ("%s skin, %s%s."):format(skinName(lk.Skin or Color3.fromRGB(214, 164, 118)), hairColor and (hairColor .. " ") or "", hair))
	if lk.Beard == "Full" then table.insert(bits, "Full beard.")
	elseif lk.Beard == "Large" then table.insert(bits, "Big thick beard.")
	elseif lk.Beard == "Stubble" then table.insert(bits, "Light stubble.")
	else table.insert(bits, "Clean shaven.") end
	if lk.Mustache then table.insert(bits, "Mustache.") end
	local top = lk.Top and TOP[lk.Top.Style] or "a t-shirt"
	local bottom = lk.Bottom and BOTTOM[lk.Bottom.Style] or "shorts"
	local topColor = lk.Top and colorName(lk.Top.Color)
	local bottomColor = lk.Bottom and colorName(lk.Bottom.Color)
	local function an(phrase)
		return (phrase:match("^[aeiou]") and "an " or "a ") .. phrase
	end
	local topPhrase = (topColor and (topColor .. " ") or "") .. top
	local wear
	if lk.Top and lk.Top.Style == "Shirtless" then
		wear = ("Shirtless, wearing %s%s"):format(bottomColor and (bottomColor .. " ") or "", bottom)
	else
		wear = ("Wearing %s and %s%s"):format(an(topPhrase), bottomColor and (bottomColor .. " ") or "", bottom)
	end
	if lk.Bottom and lk.Bottom.Trim then wear ..= (" with %s trim"):format(colorName(lk.Bottom.Trim)) end
	if typeof(lk.Socks) == "Color3" then wear ..= (", %s socks"):format(colorName(lk.Socks))
	elseif type(lk.Socks) == "table" then wear ..= (", tall %s socks%s"):format(colorName(lk.Socks.Color), lk.Socks.Stripes and " with stripes" or "") end
	local shoe = lk.ShoeStyle == "Boots" and "boots" or (lk.ShoeStyle == "HighTop" and "high-top sneakers" or "sneakers")
	if lk.Shoes then wear ..= (", %s %s"):format(colorName(lk.Shoes), shoe) end
	table.insert(bits, wear .. ".")
	for _, g in ipairs(lk.Gear or {}) do
		table.insert(bits, g == "LiftingBelt" and "Leather lifting belt." or (g == "KneeSleeves" and "Knee sleeves." or ""))
	end
	for _, p in ipairs(lk.Props or {}) do
		if PROPS[p] then table.insert(bits, (PROPS[p]:gsub("^%l", string.upper)) .. ".") end
	end
	if ch.Glow then table.insert(bits, "Confident, camera-ready look.") end
	if ch.Chart then table.insert(bits, "Smart, analytical vibe.") end
	local text = table.concat(bits, " ")
	return (text:gsub("^%l", string.upper)):gsub("%. (%l)", function(c) return ". " .. c:upper() end) .. " " .. (STYLE:gsub("^%l", string.upper))
end

local DONE = { RonnieCurlman = true }
local function byWeight(list)
	table.sort(list, function(a, b) return a.SpawnWeight > b.SpawnWeight end)
	return list
end
local function ofRarity(r)
	local out = {}
	for _, c in ipairs(C.LIST) do if c.Rarity == r and not DONE[c.Name] then table.insert(out, c) end end
	return byWeight(out)
end
local legend, myth = ofRarity("Legendary"), ofRarity("Mythic")
local batches = {
	{ "Batch 1: fill the carpet (Commons spawn 70% of the time)", ofRarity("Common") },
	{ "Batch 2: make the clocks drop something (1 Legendary + 1 Mythic)", { table.remove(legend, 1), table.remove(myth, 1) } },
	{ "Batch 3: Uncommons (22% of spawns)", ofRarity("Uncommon") },
	{ "Batch 4: Rares", ofRarity("Rare") },
	{ "Batch 5: Epics", ofRarity("Epic") },
	{ "Batch 6: the rest of the Legendaries", legend },
	{ "Batch 7: the rest of the Mythics + G.O.A.T.s", (function() local t = myth for _, c in ipairs(ofRarity("GOAT")) do table.insert(t, c) end return t end)() },
}

local out = {}
local function w(s) table.insert(out, s or "") end
w("# Gym Wars: Meshy prompts")
w()
w("One prompt per character, in the order to make them. Ronnie Curlman is done.")
w("Copy a prompt into Meshy **Text to 3D**, or better, make a sheet image first and use **Image to 3D**.")
w("When a model is in your place, name it exactly like the **Name in game** line, e.g. `JoeFlexer`.")
w()
w("## Meshy settings (every character)")
w("- Mode: Text to 3D (or Image to 3D from a front-view sheet)")
w("- Pose: **A-pose** · Symmetry: **on** · Topology: triangle · Target polycount: **~10,000**")
w("- Texture: on (PBR) · Export: **FBX**")
w("- Check before export: arms away from the body, hands not touching the thighs, feet flat")
w()
w("## In Studio (per character)")
w("1. **Avatar tab → Import 3D** → pick the FBX")
w("2. **Avatar → Auto Setup** on it (makes it walk and work out properly)")
w("3. Rename it to the **Name in game** below and drop it in **ServerStorage**")
w("4. Press Play: it walks the carpet automatically")
w()
local n = 0
for _, b in ipairs(batches) do
	if #b[2] > 0 then
		w("## " .. b[1])
		w()
		for _, ch in ipairs(b[2]) do
			n += 1
			local r = C.GetRarity(ch.Rarity)
			w(("### %d. %s · %s"):format(n, ch.DisplayName, r.DisplayName))
			w(("Name in game: `%s` · Price $%s · earns +$%s/s"):format(ch.ModelName, K.FormatNumber(ch.Price), K.FormatNumber(ch.IncomePerSecond)))
			w()
			w("```")
			w(prompt(ch))
			w("```")
			w()
		end
	end
end
fs.writeFile("tools/meshy/PROMPTS.md", table.concat(out, "\n"))
print(n .. " prompts written")
