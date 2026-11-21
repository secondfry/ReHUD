-- Who the playable characters are: a key per character, the 0-based number it got when first seen (kept for the run), the player group it belongs to,
-- whether it is swapped out or left the run, and its innate item sets per player type.
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
-- So whatever modifier-only item a character holds while settling, the first SETTLE_UPDATES updates it appears as a player type (run start, Clicker, Lazarus rising), counts as innate.
-- Sets are kept per player type, so an earlier type's innate items do not exempt later grants of them. They are saved, so wisps held at a continue stay temporary;
-- saves without innate sets re-learn on the first update.
-- shortcut: temporary items gained inside a settle second (Eden starting with Zodiac or 3 Dollar Bill, grants within a second around a type change) and on the first load of an older save are taken as innate and lose the clock; track grant sources if that gets reported.
local SETTLE_UPDATES = 30 -- unmeasured margin: innate grants may land a few updates after the character appears
local innateOf, typeOf, settleRemaining = {}, {}, {} -- innate item sets by key then player type (ids as keys); current player type and remaining settle updates by key

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
	innateOf, typeOf, settleRemaining = {}, {}, {}
end

-- Registers a known character (from a save); a key already known keeps its number, and an out-of-range or taken number is refused.
-- A missing or out-of-range group (rows from before groups) gives the character a group of its own, after every real one and ordered by its number.
-- `innate`: parsed innate sets by player type, nil to re-learn.
function Roster.claim(key, number, isSwapped, isLeft, group, innate)
	if numberOf[key] or number > MAX_NUMBER then return end
	for _, taken in pairs(numberOf) do
		if taken == number then return end
	end
	numberOf[key], nextNumber = number, math.max(nextNumber, number + 1)
	swapped[key], left[key], innateOf[key] = isSwapped or nil, isLeft or nil, innate
	if group and group <= MAX_NUMBER then
		nextGroup = math.max(nextGroup, group + 1)
	else
		group = MAX_NUMBER + 1 + number
	end
	groupOf[key] = group
end

-- Counts down the settle window and starts one when the character appears as a player type it has no innate set for.
local function settle(p)
	local key, playerType = p.key, p.player:GetPlayerType()
	settleRemaining[key] = settleRemaining[key] and settleRemaining[key] > 1 and settleRemaining[key] - 1 or nil
	innateOf[key], typeOf[key] = innateOf[key] or {}, playerType
	if innateOf[key][playerType] then return end -- a type seen before (The Forgotten and his Soul) does not settle again
	innateOf[key][playerType], settleRemaining[key] = {}, SETTLE_UPDATES
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
		if not p.ghost then settle(p) end -- a ghost learns once it is back
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

-- Whether a modifier-only item is innate for the character's current type; while it settles, one not already temporary is learned as innate.
function Roster.isInnate(key, id, wasTemporary)
	local set = innateOf[key][typeOf[key]]
	if settleRemaining[key] and not wasTemporary then set[id] = true end
	return set[id] == true
end

function Roster.isSettling(key)
	return settleRemaining[key] ~= nil
end

-- Saved form of a character's innate sets, { { type, ids } }; nil when none were learned. A type still settling is left out, so it settles again after a continue.
local function innateRows(key)
	if not innateOf[key] then return end
	local rows = {}
	for playerType, set in pairs(innateOf[key]) do
		if playerType == typeOf[key] and settleRemaining[key] then goto nextType end
		local ids = {}
		for id in pairs(set) do table.insert(ids, id) end
		table.insert(rows, { type = playerType, ids = ids })
		::nextType::
	end
	return rows
end

-- Every known character, item-less ones included, so numbers survive a continue.
function Roster.serialize()
	local rows = {}
	for key, number in pairs(numberOf) do
		table.insert(rows, { key = key, number = number, group = groupOf[key], swapped = swapped[key] == true, left = left[key] == true, innate = innateRows(key) })
	end
	return rows
end

return Roster
