-- Who the playable characters are: a key per character, the 0-based number he got when first seen (kept for the run), and whether he is swapped out or left the run.
local Roster = {}

local numberOf, nextNumber = {}, 0 -- character number by key, and the next free one

-- Tainted Lazarus's Flip and Esau Jr. put another character (own seed) at the same GetPlayer index and store the old one: his items are frozen like a ghost's, and shown, rather than marked as left.
-- shortcut: a swapped-out character whose active partner later leaves the run stays frozen forever; drop him with his partner if that gets reported.
local swapped, keyAt, lastPlayers = {}, {}, 0 -- swapped-out keys; key by GetPlayer index and player count at the last observe
local left = {} -- keys of players who left the run; their items stay, hidden unless config.showLeft

-- The GetPlayer index shifts when a co-op player leaves; the Sad Onion RNG seed stays the player's for the whole run, saves included (IsaacScript getPlayerIndex).
-- shortcut: a mod calling Next() on that RNG changes the key and his items re-list under the current floor; switch to a sturdier key if that gets reported.
local function playerKey(player)
	return player:GetCollectibleRNG(1):GetSeed()
end

function Roster.reset()
	numberOf, nextNumber = {}, 0
	swapped, keyAt, lastPlayers = {}, {}, 0
	left = {}
end

-- Registers a known character (from a save); a key already known keeps its number.
function Roster.claim(key, number, isSwapped, isLeft)
	if numberOf[key] then return end
	numberOf[key], nextNumber = number, math.max(nextNumber, number + 1)
	swapped[key], left[key] = isSwapped or nil, isLeft or nil
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
		if not numberOf[p.key] then numberOf[p.key], nextNumber = nextNumber, nextNumber + 1 end
		now[p.index] = p.key
	end
	keyAt, lastPlayers = now, #players
	return byKey
end

function Roster.number(key)
	return numberOf[key]
end

-- How many numbers were handed out: the highest number + 1.
function Roster.size()
	return nextNumber
end

function Roster.isSwapped(key)
	return swapped[key] == true
end

-- A known character no longer passed and not swapped out: he left the run.
function Roster.markLeft(key)
	left[key] = true
end

function Roster.isLeft(key)
	return left[key] == true
end

-- Every known character, item-less ones included, so numbers survive a continue.
function Roster.serialize()
	local rows = {}
	for key, number in pairs(numberOf) do
		table.insert(rows, { key = key, number = number, swapped = swapped[key] == true, left = left[key] == true })
	end
	return rows
end

return Roster
