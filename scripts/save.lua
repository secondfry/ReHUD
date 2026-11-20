-- Mod save file: { config = {...}, items = { ids }, floor = { names } }, the layout earlier versions wrote.
local json = require("json")

local Save = {}

-- Match the MCM entries; other values break layout maths or menu labels.
local MAX = { columns = 8, position = 2 }

-- The save file is untrusted: unknown keys, wrong types and out-of-range numbers keep the default.
local function mergeConfig(config, saved)
	if type(saved) ~= "table" then return end
	for key, value in pairs(saved) do
		local valid = type(value) == type(config[key])
		if valid and MAX[key] then
			valid = math.type(value) == "integer" and value >= 1 and value <= MAX[key]
		end
		if valid then config[key] = value end
	end
end

function Save.write(mod, config, ids, floors)
	mod:SaveData(json.encode({ config = config, items = ids, floor = floors }))
end

-- Merges saved settings into `config` and returns the saved item ids and floor names (nil if there is no usable save).
function Save.read(mod, config)
	if not mod:HasData() then return end

	local ok, data = pcall(json.decode, mod:LoadData())
	if not ok or type(data) ~= "table" then return end

	mergeConfig(config, data.config)
	return data.items, data.floor
end

return Save
