-- Collected items per player, oldest first. Each entry: { id, owner, number, floor, type, temporary }; the same item held by two players is two entries.
-- `owner` is the player's identity (see playerKey); `number` is his current Isaac.GetPlayer index, ghosts included.
local Tracker = { entries = {}, playerCount = 0 } -- playerCount: players passed to the last update

local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: modifier grants (wisps, Zodiac, 3 Dollar Bill) have no cheap change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- summed GetCollectibleCount() at the last scan and updates since; nil forces a scan

local function add(id, owner, number, floor, temporary)
	local item = itemConfig:GetCollectible(id)
	if not item then return end
	table.insert(Tracker.entries, { id = id, owner = owner, number = number, floor = floor, type = item.Type, temporary = temporary })
end

-- The GetPlayer index shifts when a co-op player leaves; the Sad Onion RNG seed stays the player's for the whole run, saves included (IsaacScript getPlayerIndex).
-- shortcut: a mod calling Next() on that RNG changes the key and his items re-list under the current floor; switch to a sturdier key if that gets reported.
local function playerKey(player)
	return player:GetCollectibleRNG(1):GetSeed()
end

-- A saved integer of at least 0 (integral floats count), else nil.
local function savedInteger(value)
	local n = type(value) == "number" and math.tointeger(value)
	if n and n >= 0 then return n end
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
	local real = player:GetCollectibleNum(id, true)
	return real > 0 or player:GetCollectibleNum(id, false) > 0, real == 0
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
	Tracker.entries, Tracker.playerCount = {}, 0
	lastCount, sinceScan = nil, 0
end

-- Rebuild from the saved parallel arrays; entries whose item no longer exists are dropped.
-- A missing or malformed owner (saves from before co-op tracking) is left unset and becomes whoever is living player 0 on a later update; a bad number shows as P1.
function Tracker.restore(ids, floors, owners, numbers)
	Tracker.reset()
	if type(ids) ~= "table" or type(floors) ~= "table" then return end
	if type(owners) ~= "table" then owners = {} end
	if type(numbers) ~= "table" then numbers = {} end
	for i, id in ipairs(ids) do
		if type(id) ~= "number" then goto continue end
		add(id, savedInteger(owners[i]), savedInteger(numbers[i]) or 0, tostring(floors[i] or ""))
		::continue::
	end
end

function Tracker.serialize()
	local ids, floors, owners, numbers = {}, {}, {}, {}
	for i, entry in ipairs(Tracker.entries) do
		-- false, not nil, for an unresolved owner: the game's json.lua drops nulls from arrays, which would shift later owners.
		ids[i], floors[i], owners[i], numbers[i] = entry.id, entry.floor, entry.owner or false, entry.number
	end
	return ids, floors, owners, numbers
end

-- `players`: players as { index, player, ghost }. A ghost's entries stay as they are; a player not listed left the run, and his items left with him.
-- Drops items a player lost and refreshes each kind every update; scans for new ones only when due.
function Tracker.update(players)
	if #players == 0 then return end -- transient state: read as everyone leaving, it would wipe the list
	Tracker.playerCount = #players
	local byKey, tracked, firstKey = {}, {}, nil
	for _, p in ipairs(players) do
		p.key = playerKey(p.player)
		byKey[p.key], tracked[p.key] = p, {}
		if p.index == 0 and not p.ghost then firstKey = p.key end
	end

	local entries = Tracker.entries
	for i = #entries, 1, -1 do
		local entry = entries[i]
		entry.owner = entry.owner or firstKey
		if not entry.owner then goto continue end -- old save: waits for a living player 0
		local p = byKey[entry.owner]
		if not p then
			table.remove(entries, i)
			goto continue
		end
		entry.number = p.index
		if p.ghost then goto continue end -- frozen
		local held, temporary = holding(p.player, entry.id)
		if not held or tracked[p.key][entry.id] then
			table.remove(entries, i)
			goto continue
		end
		tracked[p.key][entry.id] = true
		entry.temporary = temporary
		::continue::
	end

	if not scanDue(players) then return end

	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		if not itemConfig:GetCollectible(id) then goto nextId end
		for _, p in ipairs(players) do
			if p.ghost or tracked[p.key][id] then goto nextPlayer end
			local held, temporary = holding(p.player, id)
			if held then add(id, p.key, p.index, floor, temporary) end
			::nextPlayer::
		end
		::nextId::
	end
end

return Tracker
