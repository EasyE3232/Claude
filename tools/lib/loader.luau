--[[
	Minimal Roblox-style module loader for Lune.
	Lets the map builder and tests require the game's own ModuleScripts from
	src/ with `script.Parent.X`-style requires and Roblox datatypes as globals.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local ROOT = "."
local cache = {}

-- Lune has no Random datatype; tiny deterministic stand-in (tests/builder only)
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	return setmetatable({ s = (math.floor(seed or os.clock() * 1e6) % 2147483647) + 1 }, RandomShim)
end
function RandomShim:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function RandomShim:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end
function RandomShim:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

local requireAny
local GAME = nil -- optional fake `game` for offline harnesses

local function makeEnv(dir)
	local env = {}
	for k, v in roblox do
		env[k] = v
	end
	env.Random = RandomShim
	env.script = {
		Parent = setmetatable({}, {
			__index = function(_, n)
				return { __path = dir .. "/" .. n .. ".luau" }
			end,
		}),
	}
	env.require = requireAny
	env.game = GAME
	env.typeof = typeof
	return env
end

function requireAny(ref)
	local path
	if type(ref) == "string" then
		if ref:sub(1, 1) == "@" then
			return require(ref)
		end
		path = ROOT .. "/" .. ref .. ".luau"
	else
		path = ref.__path
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local dir = path:match("^(.*)/[^/]+$")
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = makeEnv(dir) })
	local result = fn()
	cache[path] = result
	return result
end

return {
	require = requireAny,
	roblox = roblox,
	setGame = function(g)
		GAME = g
	end,
	preload = function(ref, value)
		cache[ROOT .. "/" .. ref .. ".luau"] = value
	end,
}
