-- Settings page for Mod Config Menu Impure. ReHUD keeps owning its config and save; MCM only edits the table.
local Mcm = {}

local MOD, CATEGORY = "ReHUD", "General"
local STEPS = { 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1 } -- size, text size and transparency
local POSITIONS = { "default", "bottom" }

local registered = false

local function indexOf(list, value)
	for i, v in ipairs(list) do
		if v == value then return i end
	end
	return 1
end

-- `invert` is for "disable", which the menu shows as "Show HUD".
local function addBoolean(config, key, label, invert)
	MCM.AddSetting(MOD, CATEGORY, {
		Type = MCM.OptionType.BOOLEAN,
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
	setting.Type = MCM.OptionType.NUMBER
	setting.Minimum = 1
	MCM.AddSetting(MOD, CATEGORY, setting)
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
	if registered or not MCM then return end
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
	MCM.AddSpace(MOD, CATEGORY)
	addBoolean(config, "showPassive", "Show passive items: ")
	addBoolean(config, "showFamiliar", "Show familiar items: ")
end

return Mcm
