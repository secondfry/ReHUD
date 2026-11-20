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
	mcm.register(config, tracker.knownCharacters)
	local ids, floors, owners, numbers, rows = save.read(ReHUD, config)
	if isContinued then tracker.restore(ids, floors, owners, numbers, rows) else tracker.reset() end
	gameStarted = true
end)

ReHUD:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	save.write(ReHUD, config, tracker.serialize())
	gameStarted = false
end)

-- Each player is passed with his GetPlayer index; co-op babies (variant 1) are skipped.
ReHUD:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	if not gameStarted then return end
	local players = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		-- 0, not PlayerVariant.PLAYER: vanilla has no PlayerVariant enum; co-op babies are variant 1.
		-- Ghosts are marked so their items stay listed under the floors they were found on.
		-- Helpers with a Parent (the Strawman Keeper; IsaacScript isChildPlayer) are skipped like babies: no number or badge of their own.
		-- The Tainted Soul is a separate entry with its own seed but the same person as Tainted Forgotten: skipped too, so a solo run counts one character.
		if player.Variant == 0 and not player.Parent and player:GetPlayerType() ~= PlayerType.PLAYER_THESOUL_B then table.insert(players, { index = i, player = player, ghost = player:IsCoopGhost() }) end
	end
	tracker.update(players)
end)

ReHUD:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	render.draw(config, tracker.entries, tracker.characterCount, tracker.leftCount)
end)

mcm.register(config, tracker.knownCharacters)
