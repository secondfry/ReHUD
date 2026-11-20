-- Mod save file: { config = {...}, items = { ids }, floor = { names }, owner = { player indexes } }; earlier versions wrote no owner.
local json = require("json")

local Save = {}

-- Integer settings and their { min, max }: match the MCM entries; other values break layout maths or menu labels.
local RANGE = { columns = { 1, 8 }, position = { 1, 2 }, showPlayer = { 0, 4 } }

-- The save file is untrusted: unknown keys, wrong types and out-of-range numbers keep the default.
local function mergeConfig(config, saved)
	if type(saved) ~= "table" then return end
	for key, value in pairs(saved) do
		local valid, range = type(value) == type(config[key]), RANGE[key]
		if valid and range then
			valid = math.type(value) == "integer" and value >= range[1] and value <= range[2]
		end
		if valid then config[key] = value end
	end
end

function Save.write(mod, config, ids, floors, owners)
	mod:SaveData(json.encode({ config = config, items = ids, floor = floors, owner = owners }))
end

-- Merges saved settings into `config` and returns the saved item ids, floor names and owners (nil if there is no usable save).
function Save.read(mod, config)
	if not mod:HasData() then return end

	local ok, data = pcall(json.decode, mod:LoadData())
	if not ok or type(data) ~= "table" then return end

	mergeConfig(config, data.config)
	return data.items, data.floor, data.owner
end

return Save
