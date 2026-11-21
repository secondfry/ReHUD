-- Collected items per character, oldest first. Each entry: { id, owner, number, left, floor, type, temporary }; the same item held by two characters is two entries.
-- `owner` is the character's key and `number` its character number (see roster.lua); `left` marks the items of a player who left the run.
-- At the last update: characterCount counts present players and swapped-out characters with a list, leftCount players who left with a list.
local Tracker = { entries = {}, characterCount = 0, leftCount = 0 }

local roster = include("scripts.roster")
local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: modifier grants (wisps, Zodiac, 3 Dollar Bill) have no cheap change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- summed GetCollectibleCount() at the last scan and updates since; nil forces a scan
local ordered -- display order of the entries, rebuilt by Tracker.ordered() after any change; nil means stale

local function add(id, owner, number, floor, temporary)
	local item = itemConfig:GetCollectible(id)
	if not item then return end
	local entry = { id = id, owner = owner, number = number, floor = floor, type = item.Type, temporary = temporary }
	table.insert(Tracker.entries, entry)
	ordered = nil
	return entry
end

-- A saved integer of at least 0 (integral floats count), else nil.
local function savedInteger(value)
	local n = type(value) == "number" and math.tointeger(value)
	if n and n >= 0 then return n end
end

-- Saved innate sets ({ { type, ids } }) by player type; nil when anything is malformed, so the character re-learns.
local function savedInnate(rows)
	if type(rows) ~= "table" then return end
	local sets = {}
	for _, row in pairs(rows) do
		local playerType = type(row) == "table" and savedInteger(row.type)
		if not playerType or type(row.ids) ~= "table" then return end
		local set = {}
		for _, id in pairs(row.ids) do
			id = savedInteger(id)
			if not id then return end
			set[id] = true
		end
		sets[playerType] = set
	end
	return sets
end

local function currentFloorName()
	if StageAPI and StageAPI.Loaded and StageAPI.InOverriddenStage() then
		local name = StageAPI.GetCurrentStageDisplayName()
		if name then return name end
	end
	return Game():GetLevel():GetName()
end

-- Whether the player `p` has the item at all, and whether only through temporary modifiers (innate items: see roster.lua).
local function holding(p, id, wasTemporary)
	if p.player:GetCollectibleNum(id, true) > 0 then return true, false end
	if p.player:GetCollectibleNum(id, false) == 0 then return false end
	return true, not roster.isInnate(p.key, id, wasTemporary)
end

local function size(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

-- Due when the total collectible count moved, the fixed cadence elapsed or a character is settling.
local function scanDue(players)
	local count, settling = 0, false
	for _, p in ipairs(players) do
		count = count + p.player:GetCollectibleCount()
		settling = settling or (not p.ghost and roster.isSettling(p.key))
	end
	sinceScan = sinceScan + 1
	if count == lastCount and sinceScan < SCAN_INTERVAL and not settling then return false end
	lastCount, sinceScan = count, 0
	return true
end

function Tracker.reset()
	Tracker.entries, Tracker.characterCount, Tracker.leftCount = {}, 0, 0
	lastCount, sinceScan, ordered = nil, 0, nil
	roster.reset()
end

-- Rebuild from the saved parallel arrays and roster rows ({ key, number, group, swapped, left, innate = { { type, ids } } }); entries whose item no longer exists are dropped.
-- An owner that is missing (saves from before co-op tracking), malformed or without a valid roster row is left unset
-- and goes to whoever is living player 0 on a later update; until then the items show as character 1.
function Tracker.restore(ids, floors, owners, rows)
	Tracker.reset()
	if type(rows) == "table" then
		for _, row in ipairs(rows) do
			if type(row) ~= "table" then goto nextRow end
			local key, number = savedInteger(row.key), savedInteger(row.number)
			if key and number then roster.claim(key, number, row.swapped == true, row.left == true, savedInteger(row.group), savedInnate(row.innate)) end
			::nextRow::
		end
	end
	if type(ids) ~= "table" or type(floors) ~= "table" then return end
	if type(owners) ~= "table" then owners = {} end
	for i, id in ipairs(ids) do
		if type(id) ~= "number" then goto continue end
		local owner = savedInteger(owners[i])
		if owner and not roster.number(owner) then owner = nil end -- no roster row: loads like an old save
		local entry = add(id, owner, owner and roster.number(owner) or 0, tostring(floors[i] or ""))
		if entry then entry.left = roster.isLeft(owner) or nil end
		::continue::
	end
end

function Tracker.serialize()
	local ids, floors, owners = {}, {}, {}
	for i, entry in ipairs(Tracker.entries) do
		-- false, not nil, for an unresolved owner: the game's json.lua drops nulls from arrays, which would shift later owners.
		ids[i], floors[i], owners[i] = entry.id, entry.floor, entry.owner or false
	end
	return ids, floors, owners, roster.serialize()
end

-- `players`: players as { index, player, ghost }, by index. A ghost's and a swapped-out character's entries stay as they are; any other player not listed left the run, and that player's entries stay too, marked left.
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
		if not entry.owner and firstKey then entry.owner, entry.number, ordered = firstKey, roster.number(firstKey), nil end
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
		local held, temporary = holding(p, entry.id, entry.temporary)
		if not held or tracked[p.key][entry.id] then
			table.remove(entries, i)
			ordered = nil
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
			local held, temporary = holding(p, id)
			if held then add(id, p.key, roster.number(p.key), floor, temporary) end
			::nextPlayer::
		end
		::nextId::
	end
end

-- Entries in the order the HUD lists them, oldest first like `entries` (the HUD reads backwards): floors as collected, and within each run of one floor,
-- read newest first, by player group, then character number, then newest item. Cached, since it is drawn every frame.
function Tracker.ordered()
	if ordered then return ordered end
	local entries, position = Tracker.entries, {}
	for i, entry in ipairs(entries) do position[entry] = i end
	local first, floorStart = {}, 1
	for i, entry in ipairs(entries) do
		if i > 1 and entry.floor ~= entries[i - 1].floor then floorStart = i end
		first[entry] = floorStart
	end
	local function rank(entry) return roster.group(entry.owner) or 0, entry.number end
	ordered = {}
	for i, entry in ipairs(entries) do ordered[i] = entry end
	table.sort(ordered, function(a, b)
		if first[a] ~= first[b] then return first[a] < first[b] end
		local groupA, numberA = rank(a)
		local groupB, numberB = rank(b)
		if groupA ~= groupB then return groupA > groupB end -- reversed: the HUD reads from the end
		if numberA ~= numberB then return numberA > numberB end
		return position[a] < position[b]
	end)
	return ordered
end

return Tracker
