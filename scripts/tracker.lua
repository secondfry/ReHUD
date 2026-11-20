-- Collected-item list of player 0, oldest first. Each entry: { id, floor, type }.
local Tracker = { entries = {} }

local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

local function add(id, floor)
	local item = itemConfig:GetCollectible(id)
	if not item then return end
	table.insert(Tracker.entries, { id = id, floor = floor, type = item.Type })
end

local function currentFloorName()
	if StageAPI and StageAPI.Loaded and StageAPI.InOverriddenStage() then
		local name = StageAPI.GetCurrentStageDisplayName()
		if name then return name end
	end
	return Game():GetLevel():GetName()
end

-- Copies of a not-yet-tracked item the player really owns (ignores wisp/Zodiac/3 Dollar Bill grants).
local function untrackedNum(player, tracked, id)
	if tracked[id] or not itemConfig:GetCollectible(id) then return 0 end
	return player:GetCollectibleNum(id, true)
end

function Tracker.reset()
	Tracker.entries = {}
end

-- Rebuild from the saved parallel arrays; entries whose item no longer exists are dropped.
function Tracker.restore(ids, floors)
	Tracker.reset()
	if type(ids) ~= "table" or type(floors) ~= "table" then return end
	for i, id in ipairs(ids) do
		if type(id) == "number" then add(id, tostring(floors[i] or "")) end
	end
end

function Tracker.serialize()
	local ids, floors = {}, {}
	for i, entry in ipairs(Tracker.entries) do
		ids[i], floors[i] = entry.id, entry.floor
	end
	return ids, floors
end

-- Drops items the player lost, then scans for new ones only when the owned count says some are missing.
function Tracker.update(player)
	local entries = Tracker.entries
	local tracked, ownedCount = {}, 0
	for i = #entries, 1, -1 do
		local id = entries[i].id
		local num = player:GetCollectibleNum(id, true)
		if num == 0 or tracked[id] then
			table.remove(entries, i)
		else
			tracked[id] = true
			ownedCount = ownedCount + num
		end
	end

	local total = player:GetCollectibleCount()
	if ownedCount >= total then return end

	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		local num = untrackedNum(player, tracked, id)
		if num > 0 then
			add(id, floor)
			ownedCount = ownedCount + num
			if ownedCount >= total then return end
		end
	end
end

return Tracker
