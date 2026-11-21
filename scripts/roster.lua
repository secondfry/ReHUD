-- Who the playable characters are: a key per character, the 0-based number it got when first seen (kept for the run), the player group it belongs to,
-- and whether it is swapped out or left the run.
local Roster = {}

local numberOf, nextNumber = {}, 0 -- character number by key, and the next free one
local MAX_NUMBER = 63 -- sanity cap for saved character and group numbers, far above any real roster
-- shortcut: a run with 64+ characters has the later ones refused on restore, so their items go to player 0; raise the cap if that gets reported.
-- A player group is one human: Jacob & Esau, both Tainted Lazarus forms and an Esau Jr. form share their human's ControllerIndex (keyboard -2 reads as 4294967294).
-- Groups are numbered first seen like characters; groupFor maps a ControllerIndex to its group and is relearned from present characters after a continue.
local groupOf, groupFor, nextGroup = {}, {}, 0

-- Tainted Lazarus's Flip and Esau Jr. put another character (own seed) at the same GetPlayer index and store the old one: that character's items are frozen like a ghost's, and shown, rather than marked as left.
-- When a player leaves, the player's swapped-out forms leave too: nobody is left to swap them back (see Roster.markLeft).
local swapped, keyAt, lastPlayers = {}, {}, 0 -- swapped-out keys; key by GetPlayer index and player count at the last observe
local left = {} -- keys of players who left the run; their items stay, hidden unless the menu shows them

-- Innate items: vanilla Lua counts them, like wisp, Zodiac and 3 Dollar Bill grants, only in GetCollectibleNum(id, false), and cannot ask the engine which is which.
-- So whatever modifier-only item a character holds while settling (first SETTLE_UPDATES updates after it is first seen or changes type, e.g. by Clicker) counts as innate.
-- The set is saved, so wisps held at a continue stay temporary; saves from before it re-learn on the first update.
-- shortcut: temporary items gained during a settle second (Eden starting with Zodiac or 3 Dollar Bill, a wisp right after Clicker) are taken as innate and lose the clock; track their sources if that gets reported.
local SETTLE_UPDATES = 30 -- innate grants may land a few updates after the character appears
local innateOf, typesOf, settleLeft = {}, {}, {} -- innate item set, player types seen (since load) and remaining settle updates by key

-- A saved id list as a set; nil when malformed, so it is re-learned.
local function idSet(list)
	if type(list) ~= "table" or (next(list) ~= nil and #list == 0) then return end
	local set = {}
	for _, id in ipairs(list) do
		id = type(id) == "number" and math.tointeger(id)
		if id then set[id] = true end
	end
	return set
end

-- The GetPlayer index shifts when a co-op player leaves; the Sad Onion RNG seed stays the player's for the whole run, saves included (IsaacScript getPlayerIndex).
-- shortcut: a mod calling Next() on that RNG changes the key and that character's items re-list under the current floor; switch to a sturdier key if that gets reported.
local function playerKey(player)
	return player:GetCollectibleRNG(1):GetSeed()
end

function Roster.reset()
	numberOf, nextNumber = {}, 0
	swapped, keyAt, lastPlayers = {}, {}, 0
	left = {}
	groupOf, groupFor, nextGroup = {}, {}, 0
	innateOf, typesOf, settleLeft = {}, {}, {}
end

-- Registers a known character (from a save); a key already known keeps its number, and an out-of-range or taken number is refused.
-- A missing or out-of-range group (rows from before groups) gives the character a group of its own, after every real one and ordered by its number.
function Roster.claim(key, number, isSwapped, isLeft, group, innate)
	if numberOf[key] or number > MAX_NUMBER then return end
	for _, taken in pairs(numberOf) do
		if taken == number then return end
	end
	numberOf[key], nextNumber = number, math.max(nextNumber, number + 1)
	swapped[key], left[key], innateOf[key] = isSwapped or nil, isLeft or nil, idSet(innate)
	if group and group <= MAX_NUMBER then
		nextGroup = math.max(nextGroup, group + 1)
	else
		group = MAX_NUMBER + 1 + number
	end
	groupOf[key] = group
end

-- Sets `p.key` on each of `players` ({ index, player, ghost }), numbers newcomers and marks swaps; returns the players by key.
-- Must run every update: a swap is told from a leave by comparing with the previous update.
function Roster.observe(players)
	local byKey = {}
	for _, p in ipairs(players) do
		p.key = playerKey(p.player)
		byKey[p.key] = p
	end

	-- A swap keeps the player count and puts a new or swapped-out character at the index of one no longer passed.
	local sameCount, now = #players == lastPlayers, {}
	for _, p in ipairs(players) do
		local old = keyAt[p.index]
		if sameCount and old and not byKey[old] and (not numberOf[p.key] or swapped[p.key]) then swapped[old] = true end
		swapped[p.key], left[p.key] = nil, nil -- back in play: resumes
		local controller = p.player.ControllerIndex
		if not numberOf[p.key] then
			numberOf[p.key], nextNumber = nextNumber, nextNumber + 1
			groupOf[p.key] = groupFor[controller] or nextGroup
			if groupOf[p.key] == nextGroup then nextGroup = nextGroup + 1 end
		end
		groupFor[controller] = groupFor[controller] or groupOf[p.key]
		now[p.index] = p.key
		if not p.ghost then -- a ghost learns once it is back
			local playerType, seen = p.player:GetPlayerType(), typesOf[p.key]
			settleLeft[p.key] = settleLeft[p.key] and settleLeft[p.key] > 1 and settleLeft[p.key] - 1 or nil
			-- only a type this key has not had: switching back and forth (The Forgotten and his Soul) does not settle again
			if not innateOf[p.key] or (seen and not seen[playerType]) then settleLeft[p.key] = SETTLE_UPDATES end
			innateOf[p.key], typesOf[p.key] = innateOf[p.key] or {}, seen or {}
			typesOf[p.key][playerType] = true
		end
	end
	local before = keyAt
	keyAt, lastPlayers = now, #players
	for _, old in pairs(before) do
		if not byKey[old] and not swapped[old] then Roster.markLeft(old) end -- also catches a leaver without items
	end
	return byKey
end

function Roster.number(key)
	return numberOf[key]
end

function Roster.group(key)
	return groupOf[key]
end

function Roster.isSwapped(key)
	return swapped[key] == true
end

-- A known character no longer passed and not swapped out has left the run. With no character of the same player still present,
-- that player's swapped-out forms leave too.
function Roster.markLeft(key)
	left[key] = true
	local group = groupOf[key]
	for _, present in pairs(keyAt) do
		if groupOf[present] == group then return end
	end
	for other in pairs(swapped) do
		if groupOf[other] == group then swapped[other], left[other] = nil, true end
	end
end

function Roster.isLeft(key)
	return left[key] == true
end

-- The character's innate item set (ids as keys), filled by the tracker while the character settles.
function Roster.innate(key)
	return innateOf[key]
end

function Roster.isSettling(key)
	return settleLeft[key] ~= nil
end

-- Every known character, item-less ones included, so numbers survive a continue.
function Roster.serialize()
	local rows = {}
	for key, number in pairs(numberOf) do
		local innate = innateOf[key] and {} -- nil for a restored character not seen since: re-learned like an old save
		for id in pairs(innateOf[key] or {}) do table.insert(innate, id) end
		table.insert(rows, { key = key, number = number, group = groupOf[key], swapped = swapped[key] == true, left = left[key] == true, innate = innate })
	end
	return rows
end

return Roster
