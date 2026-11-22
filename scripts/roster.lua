-- Who the playable characters are: a key per character, the 0-based number it got when first seen (kept for the run), the player group it belongs to,
-- whether it is swapped out or left the run, and its innate item counts per player type. Roster.observe also returns the characters that merged into another of their group.
local Roster = {}

local numberOf, nextNumber = {}, 0 -- character number by key, and the next free one
local MAX_NUMBER = 63 -- sanity cap for saved character and group numbers, far above any real roster
-- shortcut: a run with 64+ characters has the later ones refused on restore, so their items go to player 0; raise the cap if that gets reported.
-- A player group is one human: Jacob & Esau, both Tainted Lazarus forms and an Esau Jr. form share their human's ControllerIndex (keyboard -2 reads as 4294967294).
-- Groups are numbered first seen like characters; groupFor maps a ControllerIndex to its group and is relearned from present characters after a continue.
local groupOf, groupFor, nextGroup = {}, {}, 0

-- Tainted Lazarus's Flip and Esau Jr. put another character at the same GetPlayer index and store the old one: a Flip's other form has its own seed, Esau Jr.'s form a new one, the presser's other form's (a stored Dead form or a Birthright twin), after a Continue the presser's own once its original was lost, or, from a third fresh copy, an earlier form's (in-game 2026-11-21 and 2026-11-22), and a Flip of an Esau Jr. form keeps its seed. The stored character's items are frozen like a ghost's, and shown, rather than marked as left.
-- When a player leaves, the player's swapped-out forms leave too: nobody is left to swap them back (see Roster.markLeft).
-- A character that vanishes, not swapped out, while another living one of its group is still present (a ghost cannot use Clicker), and its group has fewer members than at the last update, is a character who left, not a player: it merged into that one
-- (Clicker turning Jacob & Esau into one character moves Esau's owned items to it, in-game 2026-11-21). It is forgotten, and observe returns it so the tracker moves its items.
-- Tainted Lazarus's two forms are partners (partnerOf). A stored form whose partner in play stops being its other form merges into it like Esau:
-- Clicker and ChangePlayerType out of Tainted Lazarus, or into the stored form's own type, gave the partner both forms' items, and the old form never returns (in-game 2026-11-21).
-- An Esau Jr. swap links the stored character with the live one it swapped with (esauJrForm, both ways): the stored one never merges, and stays listed until the run ends (user decision 2026-11-22):
-- each Esau Jr. copy keeps the character it last swapped out, wherever the copy lies, and the engine never frees one of its four slots (in-game 2026-11-22), so a count of 0 or a lost copy says nothing.
-- Soul of Jacob and Esau's Esau (type 20 with a Parent) is temporary: once he is not passed, he is forgotten with his items (user decision 2026-11-22).
local swapped, keyAt, lastPlayers = {}, {}, 0 -- swapped-out keys; key by GetPlayer index and player count at the last observe
local left = {} -- keys of players who left the run; their items stay, hidden unless the menu shows them
local TAINTED_LAZARUS = { [PlayerType.PLAYER_LAZARUS_B] = true, [PlayerType.PLAYER_LAZARUS2_B] = true }

-- The one Tainted Lazarus type saved innate rows show, for saves without a type.
local function lazarusRow(innate)
	if not innate then return end
	local a, b = innate[PlayerType.PLAYER_LAZARUS_B], innate[PlayerType.PLAYER_LAZARUS2_B]
	if a and not b then return PlayerType.PLAYER_LAZARUS_B end
	if b and not a then return PlayerType.PLAYER_LAZARUS2_B end
end

-- Innate items: vanilla Lua counts them, like wisp, Zodiac and 3 Dollar Bill grants, only in GetCollectibleNum(id, false), and cannot ask the engine which is which.
-- So the copies a character holds the first SETTLE_UPDATES updates it appears as a player type (run start, Clicker, Lazarus rising) that are neither owned,
-- nor its item wisps, nor its Zodiac item count as innate (the tracker attributes those). Counts are kept per player type, so an earlier type's innate items
-- do not exempt later grants of them. They are saved, so grants held at a continue keep the clock; saves without innate counts re-learn on the first update.
-- shortcut: known limits (accepted): a 3 Dollar Bill grant inside a settle second (Eden's start, around Clicker, Lazarus rising, a co-op join, an older save's first load) is learned as innate for that type, so that item shows no clock while 3 Dollar Bill grants it to that type; and item wisps whose familiar does not point at the settling character (mod wisps without a Player; an old form's wisps after a first Flip or Esau Jr. swap, unchecked) count as innate. Read the engine's innate list (REPENTOGON's HasInnateCollectible) if that gets reported.
local SETTLE_UPDATES = 30 -- unmeasured margin: innate grants may land a few updates after the character appears
local innateOf, typeOf, settleRemaining = {}, {}, {} -- innate copy counts by key, player type, then id; current player type and remaining settle updates by key
local esauJrForm = {} -- by stored key, the live character the stored one swapped places with through Esau Jr. (either way)
local partnerOf = {} -- the other form by key, both ways, for Tainted Lazarus forms: the one record of which two forms are one Tainted Lazarus
local summoned = {} -- keys of Soul of Jacob and Esau's Esaus

-- The GetPlayer index shifts when a co-op player leaves; the Sad Onion RNG seed stays the player's for the whole run, saves included (IsaacScript getPlayerIndex).
-- shortcut: a mod calling Next() on that RNG changes the key only across a Continue (within a session the GetData tag below holds it), and that character's items then re-list under the current floor; switch to a sturdier key if that gets reported.
-- Characters can share one seed around Esau Jr. (a form on its presser's Dead form's seed, a third copy's form on an earlier form's seed, Birthright on a form, a form's Flip; in-game 2026-11-22),
-- so each character carries its key in a namespaced GetData() tag, which follows it through Esau Jr. storage within a session (in-game 2026-11-22). The first character of a seed keys by the seed;
-- one whose seed is already tagged this session is another character and takes the seed plus a multiple of SEED_SPAN (seeds are 32-bit), so a saved key still names its seed.
-- Whether a tag stays with its character through a Tainted Lazarus Flip, or with each Birthright twin apart, is unobserved; the same-seed Flip and twin cases rely on it.
-- The tag holds a token renewed by Roster.reset, so a tag from an earlier run or session never counts (whether one survives a new run is unobserved).
-- shortcut: Exit & Continue wipes GetData (in-game 2026-11-22), so after a Continue each character takes its seed's first key not tagged since, in the order they play, with no RNG or item matching (user decision 2026-11-22): same-seed characters may take each other's rows, each listing the live one's copies under the current floor, until each has played again; prefer the row of the character playing at the save if that gets reported.
local SEED_SPAN = 1 << 32
local session, tagged = {}, {} -- this session's tag token; keys handed out this session
local function playerKey(player)
	local seed, data = player:GetCollectibleRNG(1):GetSeed(), player:GetData()
	if type(data) ~= "table" then return seed end -- after a Mods-menu Lua reset GetData returns a number until restart
	local tag = data.ReHUD_key
	if tag and tag.session == session then return tag.key end
	local key = seed
	while tagged[key] do key = key + SEED_SPAN end
	tagged[key], data.ReHUD_key = true, { session = session, key = key }
	return key
end

function Roster.reset()
	session, tagged, summoned = {}, {}, {}
	numberOf, nextNumber = {}, 0
	swapped, keyAt, lastPlayers = {}, {}, 0
	left = {}
	groupOf, groupFor, nextGroup = {}, {}, 0
	innateOf, typeOf, settleRemaining = {}, {}, {}
	partnerOf, esauJrForm = {}, {}
end

-- Registers a known character (from a save); a key already known keeps its number, and an out-of-range or taken number is refused.
-- A missing or out-of-range group (rows from before groups) gives the character a group of its own, after every real one and ordered by its number.
-- `innate`: parsed innate counts by player type, nil to re-learn. `playerType`: nil in saves before it was saved; a stored form's single Tainted Lazarus innate row stands in.
-- `partner`: the other Tainted Lazarus form's key; `esauJr`: the substitute for an Esau Jr. original; `isSummoned`: a Soul of Jacob and Esau's Esau.
function Roster.claim(key, number, isSwapped, isLeft, group, innate, playerType, partner, esauJr, isSummoned)
	if numberOf[key] or number > MAX_NUMBER then return end
	for _, taken in pairs(numberOf) do
		if taken == number then return end
	end
	numberOf[key], nextNumber = number, math.max(nextNumber, number + 1)
	swapped[key], left[key], innateOf[key] = isSwapped or nil, isLeft or nil, innate
	typeOf[key] = playerType or (isSwapped and lazarusRow(innate)) or nil
	partnerOf[key], esauJrForm[key], summoned[key] = partner, isSwapped and esauJr or nil, isSummoned or nil
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
	if partnerOf[key] then partnerOf[partnerOf[key]] = nil end
	partnerOf[key], esauJrForm[key], summoned[key] = nil, nil, nil
end

-- Fallback for pairs no Flip recorded (observe records the Flip itself): links each unpaired Tainted Lazarus form to the first unpaired one of the other type
-- in its group, oldest number first. That covers both forms appearing at once (Birthright before the first Flip) and saves without `partner`.
-- shortcut: in a save without esauJr (2.7 and 2.8 test builds), this fallback pairs a stored Esau Jr. original with its form once that form flips, so the form's flip back, Clicker or ChangePlayerType out merges the original into it. Drop this fallback once those saves are gone.
local function pairForms()
	local forms = {}
	for key in pairs(numberOf) do
		if not left[key] and not partnerOf[key] and not esauJrForm[key] and TAINTED_LAZARUS[typeOf[key]] then table.insert(forms, key) end
	end
	table.sort(forms, function(a, b) return numberOf[a] < numberOf[b] end)
	for i, a in ipairs(forms) do
		for j = i + 1, #forms do
			local b = forms[j]
			if not partnerOf[a] and not partnerOf[b] and groupOf[a] == groupOf[b] and typeOf[a] ~= typeOf[b] then partnerOf[a], partnerOf[b] = b, a end
		end
	end
end

-- The partner in play that stored form `key` merges into: one no longer its other form.
local function absorber(key, byKey)
	if esauJrForm[key] then return end
	local partner = partnerOf[key]
	local p = partner and byKey[partner]
	if not p or p.ghost then return end
	local t = typeOf[partner]
	if TAINTED_LAZARUS[t] and t ~= typeOf[key] then return end
	return partner
end

-- Key of the first living one of `players` in the group.
local function presentIn(players, group)
	for _, p in ipairs(players) do
		if groupOf[p.key] == group and not p.ghost then return p.key end
	end
end

local function holdsEsauJr(player)
	return player:GetCollectibleNum(CollectibleType.COLLECTIBLE_ESAU_JR, true) > 0
end

-- Merges each stored Tainted Lazarus form whose partner is no longer its other form into `merged`.
local function resolveStored(byKey, merged)
	for key in pairs(swapped) do
		local into = absorber(key, byKey)
		if into then
			merged[key] = into
			forget(key)
		end
	end
end

-- Sets `p.key` on each of `players` ({ index, player, ghost }), numbers newcomers and marks swaps; returns the players by key,
-- and the keys of characters merged this update, each with the key it merged into.
-- Must run every update: a swap is told from a leave by comparing with the previous update.
function Roster.observe(players)
	pairForms() -- by the types of the last update, so a crossing this update still finds its partner
	local byKey = {}
	for _, p in ipairs(players) do
		p.key = playerKey(p.player)
		byKey[p.key] = p
	end

	-- A swap keeps the player count and puts a new or swapped-out character at the index of one no longer passed.
	local sameCount, now = #players == lastPlayers, {}
	for _, p in ipairs(players) do
		local old = keyAt[p.index]
		local t = p.player:GetPlayerType()
		local esauJrReturn = old and esauJrForm[p.key] == old
		-- Esau Jr.'s new form keeps the presser's type and holds Esau Jr. on its first update (in-game 2026-11-22); a press or return can also send away a Birthright twin, so the count may drop.
		local esauJrNew = old and not numberOf[p.key] and t == typeOf[old] and holdsEsauJr(p.player)
		if old and not byKey[old] and (esauJrReturn or esauJrNew or (sameCount and (not numberOf[p.key] or swapped[p.key]))) then
			swapped[old] = true
			if esauJrReturn or (t == typeOf[old] and holdsEsauJr(p.player)) then
				esauJrForm[old] = p.key
			end
			-- shortcut: the partner is set once, while Flip partners change around Esau Jr. (Lazarus Jr. flips to Dead Lazarus; once Dead Lazarus uses Esau Jr., Flip switches Dead Lazarus Jr. and Lazarus Jr., in-game 2026-11-22), so a later partner can merge a stored form into the wrong one on Clicker; follow the observed Flip pairs if that gets reported.
			if not numberOf[p.key] and not partnerOf[old] and TAINTED_LAZARUS[t] and TAINTED_LAZARUS[typeOf[old]] and t ~= typeOf[old] then partnerOf[old], partnerOf[p.key] = p.key, old end -- Flip: the new form is the presser's partner
		end
		swapped[p.key], left[p.key], esauJrForm[p.key] = nil, nil, nil -- back in play: resumes
		if p.player.Parent and p.player:GetPlayerType() == PlayerType.PLAYER_ESAU then summoned[p.key] = true end
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
	for key in pairs(summoned) do
		if not byKey[key] and not swapped[key] then forget(key) end -- also one saved but gone after a Continue
	end
	local inBefore = {}
	for _, key in pairs(before) do inBefore[key] = true end
	for _, old in pairs(before) do
		if byKey[old] or swapped[old] or not numberOf[old] then goto nextOld end
		-- shortcut: a Flip or Esau Jr. swap in the same update as another group's count change (a co-op leave, or a Clicker merge or split) is not seen as a swap, so the swapped-out form reads as left (items kept, hidden) until it plays again; compare counts per group if that gets reported.
		local partner = partnerOf[old]
		-- Birthright lost: Flip stores the other form again; or an Esau Jr. swap stored its twin with it (in play last update, stored this one), not a long-stored partner of a leaver
		if byKey[partner] or (swapped[partner] and inBefore[partner]) then
			swapped[old] = true
			if typeOf[partner] == typeOf[old] then esauJrForm[old] = partner end -- Esau Jr. can take the other form's seed
			goto nextOld
		end
		-- shortcut: a Strawman Keeper vanishing while its group plays on (unobserved; its ControllerIndex is unchecked) reads as a merge, so its owned items move to that character; give helpers their own leave rule if that gets reported.
		merged[old] = (lost[groupOf[old]] or 0) > 0 and presentIn(players, groupOf[old]) or nil -- a group that kept its count swapped, so a co-op leave beside it stays a leave
		if merged[old] then forget(old) else Roster.markLeft(old) end -- also catches a leaver without items
		::nextOld::
	end
	resolveStored(byKey, merged)
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
		if groupOf[other] == group then swapped[other], left[other], esauJrForm[other] = nil, true, nil end
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
		table.insert(rows, { key = key, number = number, group = groupOf[key], swapped = swapped[key] == true, left = left[key] == true, innate = innateRows(key), type = typeOf[key], partner = partnerOf[key], esauJr = esauJrForm[key], summoned = summoned[key] })
	end
	return rows
end

return Roster
