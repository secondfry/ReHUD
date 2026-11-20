-- Collected items per player, oldest first. Each entry: { id, owner, floor, type, temporary }; the same item held by two players is two entries.
local Tracker = { entries = {} }

local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: modifier grants (wisps, Zodiac, 3 Dollar Bill) have no cheap change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- summed GetCollectibleCount() at the last scan and updates since; nil forces a scan

local function add(id, owner, floor, temporary)
	local item = itemConfig:GetCollectible(id)
	if not item then return end
	table.insert(Tracker.entries, { id = id, owner = owner, floor = floor, type = item.Type, temporary = temporary })
end

local function currentFloorName()
	if StageAPI and StageAPI.Loaded and StageAPI.InOverriddenStage() then
		local name = StageAPI.GetCurrentStageDisplayName()
		if name then return name end
	end
	return Game():GetLevel():GetName()
end

-- Whether the player has the item at all, and whether only through modifiers.
local function holding(player, id)
	if player:GetCollectibleNum(id, true) > 0 then return true, false end
	return player:GetCollectibleNum(id, false) > 0, true
end

-- Due when the total collectible count moved or the fixed cadence elapsed.
local function scanDue(players)
	local count = 0
	for _, p in ipairs(players) do count = count + p.player:GetCollectibleCount() end
	sinceScan = sinceScan + 1
	if count == lastCount and sinceScan < SCAN_INTERVAL then return false end
	lastCount, sinceScan = count, 0
	return true
end

function Tracker.reset()
	Tracker.entries = {}
	lastCount, sinceScan = nil, 0
end

-- Rebuild from the saved parallel arrays; entries whose item no longer exists are dropped. Saves without owners predate co-op tracking: player 0.
function Tracker.restore(ids, floors, owners)
	Tracker.reset()
	if type(ids) ~= "table" or type(floors) ~= "table" then return end
	if type(owners) ~= "table" then owners = {} end
	for i, id in ipairs(ids) do
		local owner = owners[i]
		if math.type(owner) ~= "integer" or owner < 0 then owner = 0 end
		if type(id) == "number" then add(id, owner, tostring(floors[i] or "")) end
	end
end

function Tracker.serialize()
	local ids, floors, owners = {}, {}, {}
	for i, entry in ipairs(Tracker.entries) do
		ids[i], floors[i], owners[i] = entry.id, entry.floor, entry.owner
	end
	return ids, floors, owners
end

-- `players`: living players as { index, player }. Entries of anyone not listed (a co-op ghost) stay as they are.
-- Drops items a player lost and refreshes each kind every update; scans for new ones only when due.
function Tracker.update(players)
	local byIndex, tracked = {}, {}
	for _, p in ipairs(players) do
		byIndex[p.index], tracked[p.index] = p.player, {}
	end

	local entries = Tracker.entries
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local player = byIndex[entry.owner]
		if player then
			local held, temporary = holding(player, entry.id)
			if not held or tracked[entry.owner][entry.id] then
				table.remove(entries, i)
			else
				tracked[entry.owner][entry.id] = true
				entry.temporary = temporary
			end
		end
	end

	if not scanDue(players) then return end

	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		if itemConfig:GetCollectible(id) then
			for _, p in ipairs(players) do
				if not tracked[p.index][id] then
					local held, temporary = holding(p.player, id)
					if held then add(id, p.index, floor, temporary) end
				end
			end
		end
	end
end

return Tracker
