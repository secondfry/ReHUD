-- Collected-item list of all given players merged, oldest first. Each entry: { id, floor, type, temporary }.
local Tracker = { entries = {} }

local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: modifier grants (wisps, Zodiac, 3 Dollar Bill) have no cheap change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- GetCollectibleCount() at the last scan and updates since; nil forces a scan

local function add(id, floor, temporary)
	local item = itemConfig:GetCollectible(id)
	if not item then return end
	table.insert(Tracker.entries, { id = id, floor = floor, type = item.Type, temporary = temporary })
end

local function currentFloorName()
	if StageAPI and StageAPI.Loaded and StageAPI.InOverriddenStage() then
		local name = StageAPI.GetCurrentStageDisplayName()
		if name then return name end
	end
	return Game():GetLevel():GetName()
end

-- Whether any player has the item at all, and whether only through modifiers.
local function holding(players, id)
	local held = false
	for _, player in ipairs(players) do
		if player:GetCollectibleNum(id, true) > 0 then return true, false end
		held = held or player:GetCollectibleNum(id, false) > 0
	end
	return held, true
end

-- Due when the total collectible count moved or the fixed cadence elapsed.
local function scanDue(players)
	local count = 0
	for _, player in ipairs(players) do count = count + player:GetCollectibleCount() end
	sinceScan = sinceScan + 1
	if count == lastCount and sinceScan < SCAN_INTERVAL then return false end
	lastCount, sinceScan = count, 0
	return true
end

function Tracker.reset()
	Tracker.entries = {}
	lastCount, sinceScan = nil, 0
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

-- Drops items every player lost and refreshes each kind every update; scans for new ones only when due.
function Tracker.update(players)
	local entries, tracked = Tracker.entries, {}
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local held, temporary = holding(players, entry.id)
		if not held or tracked[entry.id] then
			table.remove(entries, i)
		else
			tracked[entry.id] = true
			entry.temporary = temporary
		end
	end

	if not scanDue(players) then return end

	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		if not tracked[id] and itemConfig:GetCollectible(id) then
			local held, temporary = holding(players, id)
			if held then add(id, floor, temporary) end
		end
	end
end

return Tracker
