-- Settings page for Mod Config Menu Impure or Pure. ReHUD keeps owning its config and save; MCM only edits the table.
local Mcm = {}

local MOD_NAME, CATEGORY = "ReHUD", "General"
local STEPS = { 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1 } -- size, text size and transparency
local POSITIONS = { "default", "bottom" }
local PLAYERS = { "All", "P1", "P2", "P3", "P4" } -- showPlayer 0..4; the menu counts from 1

local registered = false
local menu -- Impure sets both MCM and ModConfigMenu; Pure only ModConfigMenu

local function indexOf(list, value)
	for i, v in ipairs(list) do
		if v == value then return i end
	end
	return 1
end

-- `invert` is for "disable", which the menu shows as "Show HUD". `info` is the optional help text.
local function addBoolean(config, key, label, invert, info)
	menu.AddSetting(MOD_NAME, CATEGORY, {
		Type = menu.OptionType.BOOLEAN,
		Info = info,
		CurrentSetting = function() return config[key] end,
		Display = function()
			local on = config[key]
			if invert then on = not on end
			return label .. (on and "True" or "False")
		end,
		OnChange = function(value) config[key] = value end,
	})
end

local function addNumber(setting)
	setting.Type = menu.OptionType.NUMBER
	setting.Minimum = 1
	menu.AddSetting(MOD_NAME, CATEGORY, setting)
end

local function addStep(config, key, label)
	addNumber({
		CurrentSetting = function() return indexOf(STEPS, config[key]) end,
		Maximum = #STEPS,
		Display = function() return label .. config[key] end,
		OnChange = function(index) config[key] = STEPS[index] end,
	})
end

-- Safe to call repeatedly: registers once, as soon as MCM is loaded (load order between mods is not guaranteed).
function Mcm.register(config)
	if registered then return end
	-- Impure sets MCM and ModConfigMenu, Pure only ModConfigMenu; skip an unrelated MCM global.
	menu = (MCM and MCM.AddSetting and MCM) or ModConfigMenu
	if not (menu and menu.AddSetting) then return end
	registered = true

	addBoolean(config, "disable", "Show HUD: ", true)
	addStep(config, "spriteScale", "Size: ")
	addBoolean(config, "showTimer", "Show game timer: ")
	addBoolean(config, "showItems", "Show items: ")
	addBoolean(config, "showFloor", "Show floorname: ")
	addStep(config, "textScale", "Text Size: ")
	addNumber({
		CurrentSetting = function() return config.position end,
		Maximum = #POSITIONS,
		Display = function() return "Position: " .. POSITIONS[config.position] end,
		OnChange = function(position)
			config.position = position
			config.columns = position == 1 and 4 or 1
		end,
	})
	addNumber({
		CurrentSetting = function() return config.columns end,
		Maximum = 8,
		Display = function() return (config.position == 1 and "Columns: " or "Rows: ") .. config.columns end,
		OnChange = function(columns) config.columns = columns end,
	})
	addStep(config, "transparency", "Transparency: ")
	menu.AddSpace(MOD_NAME, CATEGORY)
	addBoolean(config, "showPassive", "Show passive items: ")
	addBoolean(config, "showFamiliar", "Show familiar items: ")
	addBoolean(config, "showActive", "Show active items: ")
	addBoolean(config, "showTemporary", "Show temporary items: ", false,
		"Optional: also list items you only hold temporarily, e.g. from Lemegeton wisps, Zodiac or 3 Dollar Bill.")
	addNumber({
		CurrentSetting = function() return config.showPlayer + 1 end,
		Maximum = #PLAYERS,
		Display = function() return "Show items of: " .. PLAYERS[config.showPlayer + 1] end,
		OnChange = function(index) config.showPlayer = index - 1 end,
	})
end

return Mcm
