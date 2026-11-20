-- Current settings, initialised to the defaults. Persistence merges saved values over this table in place.
return {
	disable = false,
	spriteScale = 0.5,
	textScale = 0.5,
	columns = 4,
	position = 1, -- 1: under the minimap, 2: along the bottom
	transparency = 0.5,
	showPassive = true,
	showFamiliar = true,
	showTemporary = true, -- items only granted by modifiers (wisps, Zodiac, 3 Dollar Bill)
	showActive = false,
	showTimer = true,
	showItems = true,
	showFloor = true,
	showPlayer = 0, -- whose items to list: 0 all characters, 1..8 that character only
}
