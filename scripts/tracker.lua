-- Collected items per character, oldest first. Each entry: { id, owner, number, left, floor, type, temporary }; the same item held by two characters is two entries.
-- `owner` is the character's key and `number` his character number (see roster.lua); `left` marks the items of a player who left the run.
-- At the last update: characterCount counts present players and swapped-out characters with a list, leftCount players who left with a list.
local Tracker = { entries = {}, characterCount = 0, leftCount = 0 }

local roster = include("scripts.roster")
Tracker.knownCharacters = roster.size -- character numbers handed out this run, for the menu's player filter
local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: modifier grants (wisps, Zodiac, 3 Dollar Bill) have no cheap change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- summed GetCollectibleCount() at the last scan and updates since; nil forces a scan

local function add(id, owner, number, floor, temporary)
	local item = itemConfig:GetCollectible(id)
	if not item then return end
	local entry = { id = id, owner = owner, number = number, floor = floor, type = item.Type, temporary = temporary }
	table.insert(Tracker.entries, entry)
	return entry
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

local function size(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
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
	Tracker.entries, Tracker.characterCount, Tracker.leftCount = {}, 0, 0
	lastCount, sinceScan = nil, 0
	roster.reset()
end

-- Rebuild from the saved parallel arrays and roster rows ({ key, number, swapped, left }); entries whose item no longer exists are dropped.
-- Saves without a roster number characters by their items' saved numbers. A missing or malformed owner (saves from before co-op tracking) is left unset
-- and becomes whoever is living player 0 on a later update; a bad number shows as character 1.
function Tracker.restore(ids, floors, owners, numbers, rows)
	Tracker.reset()
	if type(rows) == "table" then
		for _, row in ipairs(rows) do
			if type(row) ~= "table" then goto nextRow end
			local key, number = savedInteger(row.key), savedInteger(row.number)
			if key and number then roster.claim(key, number, row.swapped == true, row.left == true) end
			::nextRow::
		end
	end
	if type(ids) ~= "table" or type(floors) ~= "table" then return end
	if type(owners) ~= "table" then owners = {} end
	if type(numbers) ~= "table" then numbers = {} end
	for i, id in ipairs(ids) do
		if type(id) ~= "number" then goto continue end
		local owner, number = savedInteger(owners[i]), savedInteger(numbers[i]) or 0
		if owner then roster.claim(owner, number) end -- unset owners take their number once resolved
		local entry = add(id, owner, owner and roster.number(owner) or number, tostring(floors[i] or ""))
		if entry then entry.left = roster.isLeft(owner) or nil end
		::continue::
	end
end

function Tracker.serialize()
	local ids, floors, owners, numbers = {}, {}, {}, {}
	for i, entry in ipairs(Tracker.entries) do
		-- false, not nil, for an unresolved owner: the game's json.lua drops nulls from arrays, which would shift later owners.
		ids[i], floors[i], owners[i], numbers[i] = entry.id, entry.floor, entry.owner or false, entry.number
	end
	return ids, floors, owners, numbers, roster.serialize()
end

-- `players`: players as { index, player, ghost }, by index. A ghost's and a swapped-out character's entries stay as they are; any other player not listed left the run, and his entries stay too, marked left.
-- Drops items a player lost and refreshes each kind every update; scans for new ones only when due.
function Tracker.update(players)
	if #players == 0 then return end -- transient state: read as everyone leaving, it would wipe the list
	local byKey, tracked, firstKey, known, gone = roster.observe(players), {}, nil, {}, {}
	for _, p in ipairs(players) do
		tracked[p.key], known[roster.number(p.key)] = {}, true
		if p.index == 0 and not p.ghost then firstKey = p.key end
	end

	local entries = Tracker.entries
	for i = #entries, 1, -1 do
		local entry = entries[i]
		if not entry.owner and firstKey then entry.owner, entry.number = firstKey, roster.number(firstKey) end
		if not entry.owner then goto continue end -- old save: waits for a living player 0
		local p = byKey[entry.owner]
		if not p and roster.isSwapped(entry.owner) then
			known[entry.number] = true
			goto continue
		end
		if not p then
			roster.markLeft(entry.owner)
			entry.left, gone[entry.number] = true, true
			goto continue
		end
		entry.left = nil -- back in the run
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
	Tracker.characterCount, Tracker.leftCount = size(known), size(gone)

	if not scanDue(players) then return end

	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		if not itemConfig:GetCollectible(id) then goto nextId end
		for _, p in ipairs(players) do
			if p.ghost or tracked[p.key][id] then goto nextPlayer end
			local held, temporary = holding(p.player, id)
			if held then add(id, p.key, roster.number(p.key), floor, temporary) end
			::nextPlayer::
		end
		::nextId::
	end
end

return Tracker
