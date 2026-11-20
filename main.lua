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
	save.read(ReHUD, config, tracker, isContinued)
	gameStarted = true
end)

ReHUD:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	save.write(ReHUD, config, tracker)
	tracker.reset()
	gameStarted = false
end)

-- Only player 0 is tracked; the callback fires for every player, so act on player 0's own update.
ReHUD:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
	if not gameStarted then return end
	local main = Isaac.GetPlayer(0)
	if not main or GetPtrHash(player) ~= GetPtrHash(main) then return end
	if main:IsCoopGhost() then return end -- keep the list instead of wiping it while player 0 is a ghost
	tracker.update(main)
end)

ReHUD:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	render.draw(config, tracker.entries)
end)

mcm.register(config)
