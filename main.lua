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
	local ids, floors = save.read(ReHUD, config)
	if isContinued then tracker.restore(ids, floors) else tracker.reset() end
	gameStarted = true
end)

ReHUD:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	save.write(ReHUD, config, tracker.serialize())
	gameStarted = false
end)

-- Every living player's items share one list; co-op babies (variant 1) are skipped.
ReHUD:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	if not gameStarted then return end
	local players = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		-- 0, not PlayerVariant.PLAYER: vanilla has no PlayerVariant enum; co-op babies are variant 1.
		if player.Variant == 0 and not player:IsCoopGhost() then table.insert(players, player) end
	end
	if #players == 0 then return end -- keep the list instead of wiping it while everyone is a ghost
	tracker.update(players)
end)

ReHUD:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	render.draw(config, tracker.entries)
end)

mcm.register(config)
