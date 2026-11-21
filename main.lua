if ReHUD then return end
ReHUD = RegisterMod("ReHUD", 1)

-- include, not require: require caches by module name across every loaded mod.
local config = include("scripts.config")
local tracker = include("scripts.tracker")
local render = include("scripts.render")
local save = include("scripts.save")
local mcm = include("scripts.mcm")

local gameStarted = false

function ReHUD:isActive()
	return not config.disable
end

ReHUD:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
	mcm.register(config)
	local ids, floors, owners, rows, temporaries = save.read(ReHUD, config)
	if isContinued then tracker.restore(ids, floors, owners, rows, temporaries) else tracker.reset() end
	gameStarted = true
end)

ReHUD:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	save.write(ReHUD, config, tracker.serialize())
	gameStarted = false
end)

-- Playable characters only: co-op babies (variant 1; vanilla has no PlayerVariant enum), helpers with a Parent (Strawman Keeper; IsaacScript isChildPlayer)
-- and the Tainted Soul (own seed, same character as Tainted Forgotten, so a solo run counts one) get no number or badge.
local function isCharacter(player)
	if player.Variant ~= 0 then return false end
	if player.Parent then return false end
	return player:GetPlayerType() ~= PlayerType.PLAYER_THESOUL_B
end

-- Every playable character with its GetPlayer index; ghosts are passed, marked, so their items stay listed.
ReHUD:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	if not gameStarted then return end
	local players = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if isCharacter(player) then table.insert(players, { index = i, player = player, ghost = player:IsCoopGhost() }) end
	end
	tracker.update(players)
end)

ReHUD:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	render.draw(config, tracker.ordered(), tracker.characterCount, tracker.leftCount)
end)

mcm.register(config)
