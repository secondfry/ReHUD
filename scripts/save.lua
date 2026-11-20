-- Mod save file: { config = {...}, items = { ids }, floor = { names }, owner = { character keys }, roster = { { key, number, swapped, left } } }; earlier versions wrote neither owner nor roster.
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

function Save.write(mod, config, ids, floors, owners, rows)
	mod:SaveData(json.encode({ config = config, items = ids, floor = floors, owner = owners, roster = rows }))
end

-- Merges saved settings into `config` and returns the saved item ids, floor names, owners and roster rows (nil if there is no usable save).
function Save.read(mod, config)
	if not mod:HasData() then return end

	local ok, data = pcall(json.decode, mod:LoadData())
	if not ok or type(data) ~= "table" then return end

	mergeConfig(config, data.config)
	return data.items, data.floor, data.owner, data.roster
end

return Save
