-- Mod save file: { config = {...}, items = { ids }, floor = { names } }, the layout earlier versions wrote.
local json = require("json")

local Save = {}

function Save.write(mod, config, tracker)
	local ids, floors = tracker.serialize()
	mod:SaveData(json.encode({ config = config, items = ids, floor = floors }))
end

-- Settings always carry over; the item list only when the run is continued.
function Save.read(mod, config, tracker, isContinued)
	tracker.reset()
	if not mod:HasData() then return end

	local ok, data = pcall(json.decode, mod:LoadData())
	if not ok or type(data) ~= "table" then return end

	if type(data.config) == "table" then
		for key, value in pairs(data.config) do
			if type(value) == type(config[key]) then config[key] = value end -- skips unknown keys and wrong types
		end
	end
	if isContinued then tracker.restore(data.items, data.floor) end
end

return Save
