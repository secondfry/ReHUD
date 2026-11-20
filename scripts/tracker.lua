-- Collected items per character, oldest first. Each entry: { id, owner, number, floor, type, temporary }; the same item held by two characters is two entries.
-- `owner` is the character's identity (see playerKey); `number` is the 0-based character number he got when first seen, kept for the run.
local Tracker = { entries = {}, characterCount = 0 } -- characterCount: characters with a list at the last update (present players and swapped-out characters)

local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: modifier grants (wisps, Zodiac, 3 Dollar Bill) have no cheap change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- summed GetCollectibleCount() at the last scan and updates since; nil forces a scan
local numberOf, nextNumber = {}, 0 -- character number by owner key, and the next free one

-- Tainted Lazarus's Flip and Esau Jr. put another character (own seed) at the same GetPlayer index and store the old one: his items are frozen like a ghost's, not removed as departed.
-- shortcut: a swapped-out character whose active partner later leaves the run stays frozen forever; drop him with his partner if that gets reported.
local swapped, keyAt, lastPlayers = {}, {}, 0 -- swapped-out owner keys; owner key by GetPlayer index and player count at the last update

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
	Tracker.entries, Tracker.characterCount = {}, 0
	lastCount, sinceScan = nil, 0
	numberOf, nextNumber = {}, 0
	swapped, keyAt, lastPlayers = {}, {}, 0
end

-- Rebuild from the saved parallel arrays; entries whose item no longer exists are dropped.
-- A missing or malformed owner (saves from before co-op tracking) is left unset and becomes whoever is living player 0 on a later update; a bad number shows as character 1.
function Tracker.restore(ids, floors, owners, numbers, swaps)
	Tracker.reset()
	if type(ids) ~= "table" or type(floors) ~= "table" then return end
	if type(owners) ~= "table" then owners = {} end
	if type(numbers) ~= "table" then numbers = {} end
	if type(swaps) ~= "table" then swaps = {} end
	for i, id in ipairs(ids) do
		if type(id) ~= "number" then goto continue end
		local owner, number = savedInteger(owners[i]), savedInteger(numbers[i]) or 0
		add(id, owner, number, tostring(floors[i] or ""))
		if not owner then goto continue end -- unset owners take their number once resolved
		numberOf[owner] = numberOf[owner] or number
		nextNumber = math.max(nextNumber, number + 1)
		if swaps[i] == true then swapped[owner] = true end
		::continue::
	end
end

function Tracker.serialize()
	local ids, floors, owners, numbers, swaps = {}, {}, {}, {}, {}
	for i, entry in ipairs(Tracker.entries) do
		-- false, not nil, for an unresolved owner: the game's json.lua drops nulls from arrays, which would shift later owners.
		ids[i], floors[i], owners[i], numbers[i], swaps[i] = entry.id, entry.floor, entry.owner or false, entry.number, swapped[entry.owner] == true
	end
	return ids, floors, owners, numbers, swaps
end

-- `players`: players as { index, player, ghost }, by index. A ghost's entries stay as they are; a player not listed left the run (unless he was swapped out), and his items left with him.
-- Drops items a player lost and refreshes each kind every update; scans for new ones only when due.
function Tracker.update(players)
	if #players == 0 then return end -- transient state: read as everyone leaving, it would wipe the list
	local byKey, tracked, firstKey, known = {}, {}, nil, {}
	for _, p in ipairs(players) do
		p.key = playerKey(p.player)
		byKey[p.key], tracked[p.key] = p, {}
		if p.index == 0 and not p.ghost then firstKey = p.key end
	end

	-- A swap keeps the player count and puts a new or swapped-out character at the index of one no longer passed; runs every update, so keyAt is one frame old.
	local sameCount, now = #players == lastPlayers, {}
	for _, p in ipairs(players) do
		local old = keyAt[p.index]
		if sameCount and old and not byKey[old] and (not numberOf[p.key] or swapped[p.key]) then swapped[old] = true end
		swapped[p.key] = nil -- back in play: resumes
		if not numberOf[p.key] then numberOf[p.key], nextNumber = nextNumber, nextNumber + 1 end
		known[numberOf[p.key]] = true
		now[p.index] = p.key
	end
	keyAt, lastPlayers = now, #players

	local entries = Tracker.entries
	for i = #entries, 1, -1 do
		local entry = entries[i]
		if not entry.owner and firstKey then entry.owner, entry.number = firstKey, numberOf[firstKey] end
		if not entry.owner then goto continue end -- old save: waits for a living player 0
		local p = byKey[entry.owner]
		if not p and swapped[entry.owner] then
			known[entry.number] = true
			goto continue
		end
		if not p then
			table.remove(entries, i)
			goto continue
		end
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
	local count = 0
	for _ in pairs(known) do count = count + 1 end
	Tracker.characterCount = count

	if not scanDue(players) then return end

	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		if not itemConfig:GetCollectible(id) then goto nextId end
		for _, p in ipairs(players) do
			if p.ghost or tracked[p.key][id] then goto nextPlayer end
			local held, temporary = holding(p.player, id)
			if held then add(id, p.key, numberOf[p.key], floor, temporary) end
			::nextPlayer::
		end
		::nextId::
	end
end

return Tracker
