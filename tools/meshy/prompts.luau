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
	Common = "fit gym-goer (the least muscular tier, but still the same chunky stylized proportions)",
	Uncommon = "clearly muscular and athletic",
	Rare = "very muscular with big shoulders and arms",
	Epic = "huge, heavily muscled bodybuilder",
	Legendary = "massive pro bodybuilder, wide back, enormous arms",
	Mythic = "extreme stage-ready bodybuilder, shredded and very wide",
	GOAT = "legendary giant bodybuilder, the most massive and iconic tier",
}
local LEVEL = { Common = "COMMON", Uncommon = "UNCOMMON", Rare = "RARE", Epic = "EPIC", Legendary = "LEGENDARY", Mythic = "MYTHIC", GOAT = "G.O.A.T." }
local function hex(c)
	return c and ("#%02X%02X%02X"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) or nil
end
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

-- the look of the Ronnie Curlman sheet / model
local STYLE = "Same art style as the attached Ronnie Curlman sheet: stylized 3D render of a hyper-muscular figure with exaggerated heroic proportions like a premium collectible action figure (huge rounded shoulders and traps, big chest and arms, chunky fists, thick sturdy legs, slightly large head), realistic-cartoon face with the person's likeness from the attached photo (follow the photo for face, hair and beard if they differ from the notes below), smooth painted skin with bold muscle shading, dark gym background with warm golden spotlights."
local SHEET = "Layout exactly like the Ronnie sheet: big hero render top-left with the NAME in gold block letters, a small gold crown and '%s LEVEL' under it; two face close-ups on the right (front and 3/4); a row of FRONT / SIDE / BACK full-body turnaround views in a neutral A-pose with arms slightly away from the body and hands NOT touching the legs; a row of 4 pose examples; and a stats box at the bottom with a small blocky Roblox-style figure. No real logos, brand names, merch or tattoos."

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
	local looks = table.concat(bits, " ")
	looks = looks:gsub("^%l", string.upper):gsub("%. (%l)", function(c) return ". " .. c:upper() end)
	return looks
end

local function statsBox(ch)
	local lk = ch.Look or {}
	local r = C.GetRarity(ch.Rarity)
	local lines = {
		("Name: %s"):format(ch.DisplayName),
		("ModelName: %s"):format(ch.ModelName),
		("Rarity: %s"):format(r.DisplayName),
		("Cost: $%s"):format(K.FormatNumber(ch.Price)),
		("Income: $%s/s"):format(K.FormatNumber(ch.IncomePerSecond)),
		("Inspired By: %s (parody)"):format(ch.InspiredBy),
	}
	if lk.Skin then table.insert(lines, ("Skin Tone: %s"):format(hex(lk.Skin))) end
	if lk.Top then table.insert(lines, ("Top: %s %s, %s"):format(colorName(lk.Top.Color), TOP[lk.Top.Style] or lk.Top.Style, hex(lk.Top.Color))) end
	if lk.Bottom then table.insert(lines, ("Bottom: %s %s, %s"):format(colorName(lk.Bottom.Color), BOTTOM[lk.Bottom.Style] or lk.Bottom.Style, hex(lk.Bottom.Color))) end
	return table.concat(lines, "; ")
end

local function sheetPrompt(ch)
	local look = prompt(ch)
	return ("Create a character sheet for \"%s\", a parody of %s for my Roblox game Gym Wars. %s Look: %s Stats box: %s. %s"):format(
		ch.DisplayName, ch.InspiredBy, STYLE, look, statsBox(ch), SHEET:format(LEVEL[ch.Rarity] or ch.Rarity:upper()))
end

local function meshyPrompt(ch)
	return ("%s, stylized 3D game character in the style of a premium collectible action figure: exaggerated heroic proportions, huge rounded shoulders, big arms, chunky fists, thick legs, slightly large head, realistic-cartoon face. %s Full body, A-pose, arms slightly away from the body, hands not touching the legs, symmetrical, feet flat. No logos, no text, no tattoos."):format(
		ch.DisplayName, prompt(ch))
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
w("# Gym Wars: character prompts (Ronnie Curlman style)")
w()
w("Every character is made the same way Ronnie was: a **character sheet** first, then **Meshy Image to 3D** from it.")
w("That keeps all 40 in the exact same style as Ronnie. Ronnie Curlman is done.")
w()
w("## For each character")
w("1. **ChatGPT (image):** attach **(a)** your reference photo of the real person and **(b)** the Ronnie Curlman sheet image (style guide), then paste the **Sheet prompt**.")
w("2. **Meshy → Image to 3D:** crop the sheet to the **FRONT** full-body view (plain background if you can) and upload it.")
w("   Settings: **A-pose**, symmetry **on**, ~**10,000** polygons, texture **on** (PBR). Export **FBX**.")
w("   No good sheet? Use the **Meshy text prompt** in Text to 3D instead.")
w("3. **Studio:** Avatar → **Import 3D** → **Auto Setup** → rename to the **Name in game** → drop in **ServerStorage** → Play.")
w()
w("Muscle size goes up with rarity (Common = fit gym-goer ... G.O.A.T. = giant), but the proportions and art style stay Ronnie's.")
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
			w("**Sheet prompt** (ChatGPT, attach photo + Ronnie sheet):")
			w()
			w("```")
			w(sheetPrompt(ch))
			w("```")
			w()
			w("**Meshy text prompt** (fallback):")
			w()
			w("```")
			w(meshyPrompt(ch))
			w("```")
			w()
		end
	end
end
fs.writeFile("tools/meshy/PROMPTS.md", table.concat(out, "\n"))
print(n .. " prompts written")
