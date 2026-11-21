-- Who the playable characters are: a key per character, the 0-based number it got when first seen (kept for the run), the player group it belongs to,
-- whether it is swapped out or left the run, and its innate item counts per player type, and which characters merged into another of their group (see Roster.observe).
local Roster = {}

local numberOf, nextNumber = {}, 0 -- character number by key, and the next free one
local MAX_NUMBER = 63 -- sanity cap for saved character and group numbers, far above any real roster
-- shortcut: a run with 64+ characters has the later ones refused on restore, so their items go to player 0; raise the cap if that gets reported.
-- A player group is one human: Jacob & Esau, both Tainted Lazarus forms and an Esau Jr. form share their human's ControllerIndex (keyboard -2 reads as 4294967294).
-- Groups are numbered first seen like characters; groupFor maps a ControllerIndex to its group and is relearned from present characters after a continue.
local groupOf, groupFor, nextGroup = {}, {}, 0

-- Tainted Lazarus's Flip and Esau Jr. put another character (own seed) at the same GetPlayer index and store the old one: that character's items are frozen like a ghost's, and shown, rather than marked as left.
-- When a player leaves, the player's swapped-out forms leave too: nobody is left to swap them back (see Roster.markLeft).
-- A character that vanishes, not swapped out, while another living one of its group is still present (a ghost cannot use Clicker), and its group has fewer members than at the last update, is a character who left, not a player: it merged into that one
-- (Clicker turning Jacob & Esau into one character moves Esau's owned items to it, in-game 2026-11-21). It is forgotten, and observe returns it so the tracker moves its items.
-- A swapped-out Tainted Lazarus form whose group now plays a former Tainted Lazarus form as another character merges into it like Esau: Clicker and ChangePlayerType out of Tainted Lazarus gave the new character both forms' items (in-game 2026-11-21). Should the engine drop them (the wiki's claim for Clicker), the moved copies leave once the survivor settles.
-- shortcut: Esau Jr. used by Tainted Lazarus, then Clicker on the Esau Jr. form, merges the stored original form too, so its items go and it returns renumbered; tell the Flip partner from an Esau Jr. original if that gets reported.
-- shortcut: after a continue a swapped-out form's type is unknown until it plays again, so it stays swapped (a Tainted Lazarus form is told by its saved innate rows); save the type if that gets reported.
local swapped, keyAt, lastPlayers = {}, {}, 0 -- swapped-out keys; key by GetPlayer index and player count at the last observe
local left = {} -- keys of players who left the run; their items stay, hidden unless the menu shows them
local TAINTED_LAZARUS = { [PlayerType.PLAYER_LAZARUS_B] = true, [PlayerType.PLAYER_LAZARUS2_B] = true }

-- Innate items: vanilla Lua counts them, like wisp, Zodiac and 3 Dollar Bill grants, only in GetCollectibleNum(id, false), and cannot ask the engine which is which.
-- So the copies a character holds the first SETTLE_UPDATES updates it appears as a player type (run start, Clicker, Lazarus rising) that are neither owned,
-- nor its item wisps, nor its Zodiac item count as innate (the tracker attributes those). Counts are kept per player type, so an earlier type's innate items
-- do not exempt later grants of them. They are saved, so grants held at a continue keep the clock; saves without innate counts re-learn on the first update.
-- shortcut: known limits (accepted): a 3 Dollar Bill grant inside a settle second (Eden's start, around Clicker, Lazarus rising, a co-op join, an older save's first load) is learned as innate for that type, so that item shows no clock while 3 Dollar Bill grants it to that type; and item wisps whose familiar does not point at the settling character (mod wisps without a Player; an old form's wisps after a first Flip or Esau Jr. swap, unchecked) count as innate. Read the engine's innate list (REPENTOGON's HasInnateCollectible) if that gets reported.
local SETTLE_UPDATES = 30 -- unmeasured margin: innate grants may land a few updates after the character appears
local innateOf, typeOf, settleRemaining = {}, {}, {} -- innate copy counts by key, player type, then id; current player type and remaining settle updates by key

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
-- `innate`: parsed innate counts by player type, nil to re-learn.
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

-- Counts down the settle window and starts one when the character appears as a player type it has no innate counts for.
local function settle(p)
	local key, playerType = p.key, p.player:GetPlayerType()
	settleRemaining[key] = settleRemaining[key] and settleRemaining[key] > 1 and settleRemaining[key] - 1 or nil
	innateOf[key], typeOf[key] = innateOf[key] or {}, playerType
	if innateOf[key][playerType] then return end -- a type seen before (The Forgotten and his Soul) does not settle again
	innateOf[key][playerType], settleRemaining[key] = {}, SETTLE_UPDATES
end

local function forget(key)
	numberOf[key], groupOf[key], swapped[key], left[key] = nil, nil, nil, nil
	innateOf[key], typeOf[key], settleRemaining[key] = nil, nil, nil
end

-- Settled as a Tainted Lazarus form at some point: its innate counts (saved too) have a row for one.
local function settledAsLazarus(key)
	return innateOf[key] ~= nil and (innateOf[key][PlayerType.PLAYER_LAZARUS_B] or innateOf[key][PlayerType.PLAYER_LAZARUS2_B]) ~= nil
end

-- A Tainted Lazarus form turned into another character (Clicker, ChangePlayerType): it settled as one and is none now.
local function wasLazarus(key)
	return not TAINTED_LAZARUS[typeOf[key]] and settledAsLazarus(key)
end

-- A Tainted Lazarus form; after a continue a swapped-out form's type is unknown, so the types it settled as tell.
local function isLazarus(key)
	if typeOf[key] then return TAINTED_LAZARUS[typeOf[key]] end
	return settledAsLazarus(key)
end

-- Key of the first living one of `players` in the group that passes `test`, if given.
local function presentIn(players, group, test)
	for _, p in ipairs(players) do
		if groupOf[p.key] == group and not p.ghost and (not test or test(p.key)) then return p.key end
	end
end

-- Sets `p.key` on each of `players` ({ index, player, ghost }), numbers newcomers and marks swaps; returns the players by key,
-- and the keys of characters merged this update, each with the key it merged into.
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
	local before, merged, lost = keyAt, {}, {} -- lost: members each group has fewer than at the last observe
	keyAt, lastPlayers = now, #players
	for _, key in pairs(before) do lost[groupOf[key]] = (lost[groupOf[key]] or 0) + 1 end
	for _, p in ipairs(players) do lost[groupOf[p.key]] = (lost[groupOf[p.key]] or 0) - 1 end
	for _, old in pairs(before) do
		if byKey[old] or swapped[old] then goto nextOld end
		-- shortcut: a Flip or Esau Jr. swap in the same update as another group's count change (a co-op leave, or a Clicker merge or split) is not seen as a swap, so the swapped-out form reads as left (items kept, hidden) until it plays again; compare counts per group if that gets reported.
		merged[old] = (lost[groupOf[old]] or 0) > 0 and presentIn(players, groupOf[old]) or nil -- a group that kept its count swapped, so a co-op leave beside it stays a leave
		if merged[old] and TAINTED_LAZARUS[typeOf[old]] and TAINTED_LAZARUS[typeOf[merged[old]]] then
			swapped[old], merged[old] = true, nil -- Birthright lost: Flip stores the other form again
		elseif merged[old] then forget(old) else Roster.markLeft(old) end -- also catches a leaver without items
		::nextOld::
	end
	for key in pairs(swapped) do
		local into = isLazarus(key) and presentIn(players, groupOf[key], wasLazarus)
		if into then merged[key] = into; forget(key) end
	end
	return byKey, merged
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

-- Innate copies of the item for the character's current type; while it settles, `unexplained` (copies the tracker could not attribute) raises the count.
function Roster.innate(key, id, unexplained)
	local counts = innateOf[key][typeOf[key]]
	if settleRemaining[key] and unexplained and unexplained > (counts[id] or 0) then counts[id] = unexplained end
	return counts[id] or 0
end

function Roster.isSettling(key)
	return settleRemaining[key] ~= nil
end

-- Saved form of a character's innate counts, { { type, ids } } with an id once per copy; nil when none were learned. A type still settling is left out, so it settles again after a continue.
local function innateRows(key)
	if not innateOf[key] then return end
	local rows = {}
	for playerType, counts in pairs(innateOf[key]) do
		if playerType == typeOf[key] and settleRemaining[key] then goto nextType end
		local ids = {}
		for id, n in pairs(counts) do
			for _ = 1, n do table.insert(ids, id) end
		end
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
