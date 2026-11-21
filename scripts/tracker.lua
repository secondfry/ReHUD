-- Collected item copies per character, oldest first. Each entry: { id, owner, number, left, floor, type, temporary } is one copy: two copies of an item
-- (owned twice, owned plus innate, owned plus a wisp) are two entries, and the same item held by two characters is two entries too.
-- `owner` is the character's key and `number` its character number (see roster.lua); `left` marks the items of a player who left the run.
-- At the last update: characterCount counts present players and swapped-out characters with a list, leftCount players who left with a list.
local Tracker = { entries = {}, characterCount = 0, leftCount = 0 }

local roster = include("scripts.roster")
local itemConfig = Isaac.GetItemConfig()
local maxCollectibleID = itemConfig:GetCollectibles().Size - 1 -- includes modded items

-- shortcut: 3 Dollar Bill grants have no change signal, so a full scan also runs every SCAN_INTERVAL updates; hook grant callbacks if the delay shows.
local SCAN_INTERVAL = 30
local lastCount, sinceScan = nil, 0 -- scan trigger value at the last scan and updates since; nil forces a scan
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

-- Saved innate counts ({ { type, ids } }, an id listed once per innate copy; 2.6 saves list each id once) by player type; nil when anything is malformed, so the character re-learns.
local function savedInnate(rows)
	if type(rows) ~= "table" then return end
	local byType = {}
	for _, row in pairs(rows) do
		local playerType = type(row) == "table" and savedInteger(row.type)
		if not playerType or type(row.ids) ~= "table" then return end
		local counts = {}
		for _, id in pairs(row.ids) do
			id = savedInteger(id)
			if not id then return end
			counts[id] = (counts[id] or 0) + 1
		end
		byType[playerType] = counts
	end
	return byType
end

local function currentFloorName()
	if StageAPI and StageAPI.Loaded and StageAPI.InOverriddenStage() then
		local name = StageAPI.GetCurrentStageDisplayName()
		if name then return name end
	end
	return Game():GetLevel():GetName()
end

-- While a character settles, its item wisps by id (`p.wisps`) and its Zodiac item (`p.zodiac`), so innate learning leaves them out.
-- Owners are matched by GetPtrHash only: a wisp's Player may be a removed entity, and methods on one crash natively.
local function attribute(players, wisps)
	local byHash = {}
	for _, p in ipairs(players) do
		p.wisps, p.zodiac = nil, nil
		if not p.ghost and roster.isSettling(p.key) then
			p.wisps, p.zodiac = {}, p.player:GetZodiacEffect()
			byHash[GetPtrHash(p.player)] = p.wisps
		end
	end
	if not next(byHash) then return end
	for _, e in ipairs(wisps) do
		local familiar = e:ToFamiliar()
		local owner = familiar and familiar.Player
		local own = owner and byHash[GetPtrHash(owner)]
		if own then own[e.SubType] = (own[e.SubType] or 0) + 1 end
	end
end

-- Copies of the item the player `p` holds, as { without a clock (owned, innate), with one (wisps, Zodiac, 3 Dollar Bill) }; innate copies: see roster.lua.
-- The learned innate count is capped by what the engine still grants, so a stale count draws no phantom icon.
local function copies(p, id)
	local owned = p.player:GetCollectibleNum(id, true)
	local extra = math.max(p.player:GetCollectibleNum(id, false) - owned, 0)
	local unexplained = p.wisps and extra - (p.wisps[id] or 0) - (id == p.zodiac and 1 or 0)
	local innate = math.min(roster.innate(p.key, id, unexplained), extra)
	return { owned + innate, extra - innate }
end

local function size(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

-- Due when the trigger value moved, the fixed cadence elapsed or a character is settling. The value sums GetCollectibleCount() (which ignores wisps
-- and innate copies), the wisp count and the Zodiac ids, so a new wisp or Zodiac item lists on the update it appears.
local function scanDue(players, wispCount)
	local count, settling = wispCount, false
	for _, p in ipairs(players) do
		count = count + p.player:GetCollectibleCount() + p.player:GetZodiacEffect()
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
-- A missing `temporary` (saves before 2.7) leaves the kind unknown: the first update fills copies without a clock first.
function Tracker.restore(ids, floors, owners, rows, temporaries)
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
	if type(temporaries) ~= "table" then temporaries = {} end
	for i, id in ipairs(ids) do
		if type(id) ~= "number" then goto continue end
		local owner = savedInteger(owners[i])
		if owner and not roster.number(owner) then owner = nil end -- no roster row: loads like an old save
		local temporary = temporaries[i]
		if type(temporary) ~= "boolean" then temporary = nil end
		local entry = add(id, owner, owner and roster.number(owner) or 0, tostring(floors[i] or ""), temporary)
		if entry then entry.left = roster.isLeft(owner) or nil end
		::continue::
	end
end

function Tracker.serialize()
	local ids, floors, owners, temporaries = {}, {}, {}, {}
	for i, entry in ipairs(Tracker.entries) do
		-- false, not nil, for an unresolved owner or kind: the game's json.lua drops nulls from arrays, which would shift later values.
		ids[i], floors[i], owners[i], temporaries[i] = entry.id, entry.floor, entry.owner or false, entry.temporary == true
	end
	return ids, floors, owners, roster.serialize(), temporaries
end

-- `players`: players as { index, player, ghost }, by index. A ghost's and a swapped-out character's entries stay as they are; any other player not listed left the run, and that player's entries stay too, marked left.
-- Drops copies a player lost and refreshes each copy's kind every update; scans for new ones only when due.
function Tracker.update(players)
	if #players == 0 then return end -- transient state: read as everyone leaving, it would wipe the list
	local byKey, free, firstKey, known, gone = roster.observe(players), {}, nil, {}, {}
	local wisps = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ITEM_WISP)
	attribute(players, wisps)
	for _, p in ipairs(players) do
		free[p.key], known[roster.number(p.key)] = {}, true
		if p.index == 0 and not p.ghost then firstKey = p.key end
	end
	-- Copies of each kind not yet matched to an entry this update, by key then id.
	local function slots(p, id)
		local byId = free[p.key]
		byId[id] = byId[id] or copies(p, id)
		return byId[id]
	end

	-- Newest first, so when a kind has fewer copies than entries the oldest entries of that kind go.
	-- shortcut: vanilla cannot tell which copy was lost, so the oldest icon of that kind leaves; track copies by source if that reads wrong.
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
		local slot = slots(p, entry.id)
		local kind = entry.temporary and 2 or 1
		if entry.temporary == nil and slot[1] == 0 then kind = 2 end -- unknown kind (older save): fills copies without a clock first
		if slot[kind] == 0 then
			table.remove(entries, i)
			ordered = nil
			goto continue
		end
		slot[kind], entry.temporary = slot[kind] - 1, kind == 2
		::continue::
	end
	Tracker.characterCount, Tracker.leftCount = size(known), size(gone)

	if not scanDue(players, #wisps) then return end

	-- shortcut: copies found by one scan (a reroll, a continue, wisps of several items at once) list in item-id order, not the order obtained; hook pickup callbacks if that gets reported.
	local floor = currentFloorName()
	for id = 1, maxCollectibleID do
		if not itemConfig:GetCollectible(id) then goto nextId end
		for _, p in ipairs(players) do
			if p.ghost then goto nextPlayer end
			local slot = slots(p, id)
			for _ = 1, slot[1] do add(id, p.key, roster.number(p.key), floor, false) end
			for _ = 1, slot[2] do add(id, p.key, roster.number(p.key), floor, true) end
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
