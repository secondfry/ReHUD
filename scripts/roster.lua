-- Who the playable characters are: a key per character, the 0-based number it got when first seen (kept for the run; a temporary character's only while present; shared by twins, told apart by their twin letter), the player group it belongs to,
-- whether it is swapped out or left the run, and its innate item counts per player type. Roster.observe also returns the characters that merged into another of their group.
local Roster = {}

local numberOf, nextNumber = {}, 0 -- character number by key, and the next free one
local MAX_NUMBER = 63 -- sanity cap for saved character and group numbers, far above any real roster
-- shortcut: a run with 64+ characters has the later ones refused on restore, so their items go to player 0; raise the cap if that gets reported.
-- A player group is one human: Jacob & Esau, both Tainted Lazarus forms and an Esau Jr. form share their human's ControllerIndex (keyboard -2 reads as 4294967294).
-- Groups are numbered first seen like characters; groupFor maps a ControllerIndex to its group and is relearned from present characters after a continue.
local groupOf, groupFor, nextGroup = {}, {}, 0

-- Tainted Lazarus's Flip and Esau Jr. put another character at the same GetPlayer index and store the old one. The stored character's items are frozen like a ghost's, and shown, rather than marked as left.
-- A Flip's other form has its own seed. Esau Jr.'s form gets a new seed, or the presser's other form's (a stored Dead form or a Birthright twin), or after a Continue the presser's own once its original was lost,
-- or, from a third fresh copy, an earlier form's (in-game 2026-11-21 and 2026-11-22). A form on the Dead form's seed flipped to type 38 on that seed (in-game 2026-11-22); a fresh-seed form's Flip is unobserved.
-- When a player leaves, the player's swapped-out forms leave too: nobody is left to swap them back (see Roster.markLeft).
-- A character can vanish, not swapped out, while its group has fewer members than at the last update and another living one of it is still present (a ghost cannot use Clicker).
-- That is a character who left, not a player: it merged into that one (Clicker turning Jacob & Esau into one character moves Esau's owned items to it, in-game 2026-11-21).
-- It is forgotten, and observe returns it so the tracker moves its items.
-- Tainted Lazarus's two forms are partners (partnerOf). A stored form whose partner in play stops being its other form merges into it like Esau:
-- Clicker and ChangePlayerType out of Tainted Lazarus, or into the stored form's own type, gave the partner both forms' items, and the old form never returns (in-game 2026-11-21).
-- An Esau Jr. swap links the stored character with the live one it swapped with (esauJrForm, both ways): the stored one never merges, and stays listed until the run ends (user decision 2026-11-22):
-- each Esau Jr. copy keeps the character it last swapped out, wherever the copy lies, and the engine never frees one of its four slots (in-game 2026-11-22), so a count of 0 or a lost copy says nothing.
-- Soul of Jacob and Esau's Esau (type 20 with a Parent) is a temporary character: once he is not passed, he is forgotten with his items (user decision 2026-11-22),
-- and his character number is free again (CONTEXT.md: a temporary character has one only while present).
local swapped, keyAt, lastPlayers = {}, {}, 0 -- swapped-out keys; key by GetPlayer index and player count at the last observe
local left = {} -- keys of players who left the run; their items stay, hidden unless the menu shows them
local TAINTED_LAZARUS = { [PlayerType.PLAYER_LAZARUS_B] = true, [PlayerType.PLAYER_LAZARUS2_B] = true }

-- The one Tainted Lazarus type saved innate rows show, for saves without a type.
local function savedLazarusType(innate)
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
-- Twins (CONTEXT.md Duo, Twin; user decisions 2026-11-23): the two characters of a duo share one character number and carry a twin letter, Jacob and Tainted Lazarus a, Esau and Dead Tainted Lazarus b.
-- A newcomer joins as twin a character of its group playing the other type of its duo that holds its number alone: Esau beside Jacob (run start, Clicker into Jacob and Esau),
-- a Dead form by Flip or Birthright beside its Tainted Lazarus. A Tainted Lazarus first seen alone reserves its number and letter for the Dead form's first Flip.
-- An Esau Jr. character is a new character with its own number and no letter, also an Esau Jr. character of Tainted Lazarus: its observed Flip partners (the original's Dead form,
-- a Dead Lazarus Jr.) are characters with their own numbers (in-game 2026-11-22); only a Flip that brings a new character (unobserved for an Esau Jr. character) makes it a duo.
-- A merge (Clicker, ChangePlayerType) leaves the survivor alone with the plain number, and a later twin joins it again. The Forgotten and his Soul are one character, no duo.
local twinLetter = {} -- "a" or "b" by key; nil for a character outside a duo, or merged out of one
local DUO_TYPE = { [PlayerType.PLAYER_JACOB] = PlayerType.PLAYER_ESAU, [PlayerType.PLAYER_ESAU] = PlayerType.PLAYER_JACOB,
	[PlayerType.PLAYER_LAZARUS_B] = PlayerType.PLAYER_LAZARUS2_B, [PlayerType.PLAYER_LAZARUS2_B] = PlayerType.PLAYER_LAZARUS_B }
local function letterFor(playerType)
	return (playerType == PlayerType.PLAYER_ESAU or playerType == PlayerType.PLAYER_LAZARUS2_B) and "b" or "a"
end

-- The GetPlayer index shifts when a co-op player leaves; the Sad Onion RNG seed stays the player's for the whole run, saves included (IsaacScript getPlayerIndex).
-- shortcut: a mod calling Next() on that RNG changes the key only across a Continue (within a session the GetData tag below holds it), and that character's items then re-list under the current floor; switch to a sturdier key if that gets reported.
-- Characters can share one seed around Esau Jr. (a form on its presser's Dead form's seed, a third copy's form on an earlier form's seed, Birthright on a form; in-game 2026-11-22).
-- A form on the Dead form's seed flipped to type 38 on that seed (in-game 2026-11-22); a fresh-seed form's Flip is unobserved.
-- so each character carries its key in a namespaced GetData() tag, which follows it through Esau Jr. storage within a session (in-game 2026-11-22). The first character of a seed keys by the seed;
-- one whose seed is already tagged this session is another character and takes the seed plus a multiple of SEED_SPAN (seeds are 32-bit), so a saved key still names its seed.
-- Whether a tag stays with its character through a Tainted Lazarus Flip, or with each Birthright twin apart, is unobserved; the same-seed Flip and twin cases rely on it.
-- The tag holds a token renewed by Roster.reset, so a tag from an earlier run or session never counts (whether one survives a new run is unobserved).
-- Exit & Continue wipes GetData (in-game 2026-11-22), and every character comes back with its own items (in-game 2026-11-22), so after a Continue a character takes the saved key
-- on its seed whose owned items at the save equal its GetCollectibleNum(id, true) counts: the only such key, else the only one of those saved with its player type (user decision 2026-11-23).
-- Failing that, the first character playing on a seed takes the key saved as live (not stored, not left) on it,
-- keeping its character N (user decision 2026-11-22): the game brings back the character playing at the save.
-- A saved stored key not yet handed out waits for its own character: a fresh Esau Jr. form on its seed (a newcomer holding Esau Jr. in its presser's place) is a new character
-- with a new character N, unless the key's saved Esau Jr. link is that presser (user decision 2026-11-22); a Flip or any other arrival may take it.
-- ReHUD saves only on exit (MC_PRE_GAME_EXIT), so after a crash the character numbers are those of the last exit; what the game restores after a crash is unobserved.
-- shortcut: matching leaves the rule above to decide for characters on one seed with identical owned items and type, items changed shortly before exit (the save holds the last scan),
-- and a returning character whose items are not yet in place on its first update (unobserved, pending an in-game check); two characters may then swap character numbers,
-- or one returning through an Esau Jr. copy whose saved link names another gets a new character N; check the items' timing in game if that gets reported.
local SEED_SPAN = 1 << 32
local session, tagged = {}, {} -- this session's tag token; keys handed out this session
local liveAtSave = {} -- by seed, the keys of the saved rows that were live at the save
local ownedAtSave = {} -- by saved key, its owned item counts by id at the save (Roster.remember)
local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

local function holdsEsauJr(player)
	return player:GetCollectibleNum(CollectibleType.COLLECTIBLE_ESAU_JR, true) > 0
end

-- Esau Jr.'s new form keeps the presser's type and holds Esau Jr. on its first update (in-game 2026-11-22); so does a stored character it brings back.
local function esauJrPress(player, old)
	return player:GetPlayerType() == typeOf[old] and holdsEsauJr(player)
end

local function ownsExactly(player, counts)
	for id = 1, maxCollectibleID do
		if itemConfig:GetCollectible(id) and player:GetCollectibleNum(id, true) ~= (counts[id] or 0) then return false end
	end
	return true
end

-- The saved key on `seed`, not yet handed out, whose owned items at the save equal the player's: the only one, else the only one of those saved with the player's type.
local function matchByItems(player, seed)
	local equal, sameType = {}, {}
	for key, counts in pairs(ownedAtSave) do
		if key % SEED_SPAN == seed and not tagged[key] and ownsExactly(player, counts) then
			table.insert(equal, key)
			if typeOf[key] == player:GetPlayerType() then table.insert(sameType, key) end
		end
	end
	if #equal == 1 then return equal[1] end
	if #sameType == 1 then return sameType[1] end
end

-- `old`: the key at the player's GetPlayer index last update, the one a swap replaces.
local function playerKey(player, old)
	local seed, data = player:GetCollectibleRNG(1):GetSeed(), player:GetData()
	if type(data) ~= "table" then return seed end -- after a Mods-menu Lua reset GetData returns a number until restart
	local tag = data.ReHUD_key
	if tag and tag.session == session then return tag.key end
	local key = matchByItems(player, seed)
	if not key then
		key = seed
		for _, live in ipairs(liveAtSave[seed] or {}) do
			if not tagged[live] then key = live break end
		end
		local fresh = esauJrPress(player, old)
		while tagged[key] or (fresh and swapped[key] and esauJrForm[key] ~= old) do key = key + SEED_SPAN end -- an untagged swapped key is a saved stored one
	end
	tagged[key], data.ReHUD_key = true, { session = session, key = key }
	return key
end

function Roster.reset()
	session, tagged, summoned, liveAtSave, ownedAtSave = {}, {}, {}, {}, {}
	numberOf, nextNumber = {}, 0
	swapped, keyAt, lastPlayers = {}, {}, 0
	left = {}
	groupOf, groupFor, nextGroup = {}, {}, 0
	innateOf, typeOf, settleRemaining = {}, {}, {}
	partnerOf, esauJrForm, twinLetter = {}, {}, {}
end

-- Registers a known character (from a save); a key already known keeps its number, and an out-of-range or taken number is refused.
-- A missing or out-of-range group (rows from before groups) gives the character a group of its own, after every real one and ordered by its number.
-- `row`: a validated saved row, fields as Roster.serialize writes them; key and number are integers of at least 0, swapped, left and summoned booleans, the rest may be nil.
-- `innate`: parsed innate counts by player type, nil to re-learn. `type`: nil in saves before it was saved; a stored form's single Tainted Lazarus innate row stands in.
-- `partner`: the other Tainted Lazarus form's key; `esauJr`: the substitute for an Esau Jr. original; `summoned`: a Soul of Jacob and Esau's Esau.
-- `twin`: the twin letter, "a" or "b"; a number is shared only by two rows with different letters. Saves before twin letters have none: their twins keep the numbers
-- they had and show no letter until the run ends; a twin first appearing after the Continue (a Dead form's first Flip, Clicker into Jacob and Esau) is numbered by the twin rules.
function Roster.claim(row)
	local key, number, group = row.key, row.number, row.group
	if numberOf[key] or number > MAX_NUMBER then return end
	for other, taken in pairs(numberOf) do
		if taken == number and not (row.twin and twinLetter[other] and twinLetter[other] ~= row.twin) then return end
	end
	numberOf[key], twinLetter[key] = number, row.twin
	if not row.summoned then nextNumber = math.max(nextNumber, number + 1) end -- a temporary character's number is free once he goes
	swapped[key], left[key], innateOf[key] = row.swapped or nil, row.left or nil, row.innate
	typeOf[key] = row.type or (row.swapped and savedLazarusType(row.innate)) or nil
	partnerOf[key], esauJrForm[key], summoned[key] = row.partner, row.swapped and row.esauJr or nil, row.summoned or nil
	if not row.swapped and not row.left then
		local seed = key % SEED_SPAN
		liveAtSave[seed] = liveAtSave[seed] or {}
		table.insert(liveAtSave[seed], key)
	end
	if group and group <= MAX_NUMBER then
		nextGroup = math.max(nextGroup, group + 1)
	else
		group = MAX_NUMBER + 1 + number
	end
	groupOf[key] = group
end

-- Records each claimed character's owned item counts at the save, for matching after a Continue: its copies without a clock minus its innate ones for its saved type.
-- `unclocked`: copies without a clock by key, then id; false for a character holding a copy of unknown kind (saves before 2.8). That one gets no counts,
-- and neither does one without innate counts for its saved type (saved while settling, or saves without type or innate).
function Roster.remember(unclocked)
	for key in pairs(numberOf) do
		local innate = innateOf[key] and typeOf[key] and innateOf[key][typeOf[key]]
		if unclocked[key] ~= false and innate then
			local counts = {}
			for id, n in pairs(unclocked[key] or {}) do
				if n > (innate[id] or 0) then counts[id] = n - (innate[id] or 0) end
			end
			ownedAtSave[key] = counts
		end
	end
end

-- Counts down the settle window and starts one when the character appears as a player type it has no innate counts for.
local function settle(key, playerType)
	settleRemaining[key] = settleRemaining[key] and settleRemaining[key] > 1 and settleRemaining[key] - 1 or nil
	innateOf[key] = innateOf[key] or {}
	if innateOf[key][playerType] then return end -- a type seen before (The Forgotten and his Soul) does not settle again
	innateOf[key][playerType], settleRemaining[key] = {}, SETTLE_UPDATES
end

-- Whether no other character holds `key`'s character number.
local function alone(key)
	for other, n in pairs(numberOf) do
		if other ~= key and n == numberOf[key] then return false end
	end
	return true
end

-- Clears every record of `key` and its partner's link to it; esauJrForm links to it stay on purpose (absorber skips linked keys, an Esau Jr. return matches only keys in play, and a saved link is restored only for stored rows).
-- A twin left alone by it (a merge) loses its letter.
local function forget(key)
	local number = numberOf[key]
	numberOf[key], twinLetter[key] = nil, nil
	for other, n in pairs(numberOf) do
		if n == number and alone(other) then twinLetter[other] = nil end
	end
	groupOf[key], swapped[key], left[key] = nil, nil, nil
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

local STORED, LEFT = "stored", "left"
-- What became of `old`, in play last update and gone now unstored: STORED, LEFT, or the key it merged into. `lost`: members each group has fewer than last update.
local function vanished(old, byKey, players, inBefore, lost)
	-- shortcut: a Flip or Esau Jr. swap in the same update as another group's count change (a co-op leave, or a Clicker merge or split) is not seen as a swap, so the swapped-out form reads as left (items kept, hidden) until it plays again; compare counts per group if that gets reported.
	local partner = partnerOf[old]
	-- Birthright lost: Flip stores the other form again; or an Esau Jr. swap stored its twin with it (in play last update, stored this one), not a long-stored partner of a leaver
	if byKey[partner] or (swapped[partner] and inBefore[partner]) then return STORED end
	-- A group that kept its count swapped, so a co-op leave beside it stays a leave.
	-- shortcut: a Strawman Keeper vanishing while its group plays on (unobserved; its ControllerIndex is unchecked) reads as a merge, so its owned items move to that character; give helpers their own leave rule if that gets reported.
	return (lost[groupOf[old]] or 0) > 0 and presentIn(players, groupOf[old]) or LEFT
end

-- Stores `old`, no longer passed, when `p` (of type `t`) took its index by a swap rather than a join after a leave.
local function storeSwapped(p, old, t, sameCount)
	local esauJrReturn = esauJrForm[p.key] == old
	-- A press or return can also send away a Birthright twin, so the count may drop.
	local pressed = esauJrPress(p.player, old)
	local esauJrNew = pressed and not numberOf[p.key]
	-- A stored character returning with Esau Jr. swapped too, whatever the count does (a Birthright pair coming back raises it; design guard, unobserved).
	local storedReturn = swapped[p.key] and (sameCount or holdsEsauJr(p.player))
	if not (esauJrReturn or esauJrNew or storedReturn or (sameCount and not numberOf[p.key])) then return end
	swapped[old] = true
	if esauJrReturn or pressed then esauJrForm[old] = p.key end
	-- shortcut: the partner is set once, while Flip partners change around Esau Jr. (Lazarus Jr. flips to Dead Lazarus; once Dead Lazarus uses Esau Jr., Flip switches Dead Lazarus Jr. and Lazarus Jr., in-game 2026-11-22), so a later partner can merge a stored form into the wrong one on Clicker; follow the observed Flip pairs if that gets reported.
	if not numberOf[p.key] and not partnerOf[old] and TAINTED_LAZARUS[t] and TAINTED_LAZARUS[typeOf[old]] and t ~= typeOf[old] then partnerOf[old], partnerOf[p.key] = p.key, old end -- Flip: the new form is the presser's partner
end

-- A new character's number: a temporary character takes the lowest number nobody holds now; any other the next number, skipping those temporary characters hold.
local function numberFor(temporary)
	local held = {}
	for _, n in pairs(numberOf) do held[n] = true end
	local n = temporary and 0 or nextNumber
	while held[n] do n = n + 1 end
	if not temporary then nextNumber = n + 1 end
	return n
end

-- The character newcomer `p` (type `t`, group `group`) joins as twin, see twinLetter: `old` (the one it swapped with, a Flip) first, else one in play this update.
local function twinFor(p, t, group, old, players)
	local want = DUO_TYPE[t]
	if not want or summoned[p.key] or esauJrPress(p.player, old) then return end
	local function fits(key, keyType)
		return key ~= p.key and numberOf[key] and not summoned[key] and keyType == want and groupOf[key] == group and alone(key)
	end
	if old and fits(old, typeOf[old]) then return old end
	for _, q in ipairs(players) do
		if fits(q.key, q.player:GetPlayerType()) then return q.key end
	end
end

-- Numbers newcomer `p`: as a twin, or with a number of its own (a Tainted Lazarus not made by Esau Jr. reserving it for its Dead form).
local function numberNewcomer(p, t, old, players)
	local twin = twinFor(p, t, groupOf[p.key], old, players)
	if twin then
		numberOf[p.key], twinLetter[p.key], twinLetter[twin] = numberOf[twin], letterFor(t), letterFor(DUO_TYPE[t])
		return
	end
	numberOf[p.key] = numberFor(summoned[p.key])
	if TAINTED_LAZARUS[t] and not esauJrPress(p.player, old) then twinLetter[p.key] = letterFor(t) end
end

-- Sets `p.key` on each of `players` ({ index, player, ghost }), numbers newcomers and marks swaps; returns the players by key,
-- and the keys of characters merged this update, each with the key it merged into.
-- Must run every update: a swap is told from a leave by comparing with the previous update.
function Roster.observe(players)
	pairForms() -- by the types of the last update, so a crossing this update still finds its partner
	local byKey = {}
	for _, p in ipairs(players) do
		p.key = playerKey(p.player, keyAt[p.index])
		byKey[p.key] = p
	end

	-- A swap keeps the player count and puts a new or swapped-out character at the index of one no longer passed.
	local sameCount, now = #players == lastPlayers, {}
	for _, p in ipairs(players) do
		local old = keyAt[p.index]
		local t = p.player:GetPlayerType()
		if old and not byKey[old] then storeSwapped(p, old, t, sameCount) end
		swapped[p.key], left[p.key], esauJrForm[p.key] = nil, nil, nil -- back in play: resumes
		if p.player.Parent and t == PlayerType.PLAYER_ESAU then summoned[p.key] = true end
		local controller = p.player.ControllerIndex
		if not numberOf[p.key] then
			groupOf[p.key] = groupFor[controller] or nextGroup
			if groupOf[p.key] == nextGroup then nextGroup = nextGroup + 1 end
			numberNewcomer(p, t, old, players)
		end
		groupFor[controller] = groupFor[controller] or groupOf[p.key]
		now[p.index] = p.key
		if not p.ghost then -- a ghost learns once it is back
			typeOf[p.key] = t
			settle(p.key, t)
		end
	end
	local before, merged, lost, inBefore = keyAt, {}, {}, {} -- lost: members each group has fewer than at the last observe
	keyAt, lastPlayers = now, #players
	for _, key in pairs(before) do
		lost[groupOf[key]], inBefore[key] = (lost[groupOf[key]] or 0) + 1, true
	end
	for _, p in ipairs(players) do lost[groupOf[p.key]] = (lost[groupOf[p.key]] or 0) - 1 end
	for key in pairs(summoned) do
		if not byKey[key] and not swapped[key] then forget(key) end -- also one saved but gone after a Continue
	end
	for _, old in pairs(before) do
		local fate = numberOf[old] and not byKey[old] and not swapped[old] and vanished(old, byKey, players, inBefore, lost)
		if fate == STORED then
			swapped[old] = true
			if typeOf[partnerOf[old]] == typeOf[old] then esauJrForm[old] = partnerOf[old] end -- Esau Jr. can take the other form's seed
		elseif fate == LEFT then
			Roster.markLeft(old) -- also catches a leaver without items
		elseif fate then
			merged[old] = fate
			forget(old)
		end
	end
	resolveStored(byKey, merged)
	return byKey, merged
end

function Roster.number(key)
	return numberOf[key]
end

function Roster.letter(key)
	return twinLetter[key]
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
		table.insert(rows, { key = key, number = number, group = groupOf[key], swapped = swapped[key] == true, left = left[key] == true, innate = innateRows(key), type = typeOf[key], partner = partnerOf[key], esauJr = esauJrForm[key], summoned = summoned[key], twin = twinLetter[key] })
	end
	return rows
end

return Roster
