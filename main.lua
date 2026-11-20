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

-- Only player 0 is tracked.
ReHUD:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	if not gameStarted then return end
	local player = Isaac.GetPlayer(0)
	if player:IsCoopGhost() then return end -- keep the list instead of wiping it while player 0 is a ghost
	tracker.update(player)
end)

ReHUD:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	render.draw(config, tracker.entries)
end)

mcm.register(config)
