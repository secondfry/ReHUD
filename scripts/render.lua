local Render = {}

local game = Game()
local itemConfig = Isaac.GetItemConfig()
local sprites = {} -- by collectible id, built on first draw
local clock -- temporary-item badge, built on first draw

local fontTimer = Font()
fontTimer:Load("font/pftempestasevencondensed.fnt")
local fontFloorName = Font()
fontFloorName:Load("font/terminus8.fnt")
local fontFloorNameIntl = Font() -- terminus8 lacks Cyrillic and CJK; lanapixel covers every game language at a similar size
fontFloorNameIntl:Load("font/cjk/lanapixel.fnt")

local MAP_PADDING = 80
local CARD_PADDING_LEFT = 120
local CARD_PADDING_TOP = 30
local TRINKET_PADDING = 70
local HUD_OFFSET_MAX = Vector(20, 12) -- how far the vanilla HUD moves inward at HUD offset 1.0
-- ShopIdle draws the 32x32 item frame with pivot (16, 32) at (0, 8), so it spans (-16, -24) to (16, 8) around the render position.
local ITEM_BOTTOM_RIGHT = Vector(16, 8)

-- Which config flag shows each item type; types not listed are never shown.
local TYPE_FILTER = {
	[ItemType.ITEM_PASSIVE] = "showPassive",
	[ItemType.ITEM_FAMILIAR] = "showFamiliar",
	[ItemType.ITEM_ACTIVE] = "showActive",
}

local function drawTimer(config, screen, hudPad)
	local paused = game:IsPaused() and "Paused!" or ""
	local t = game.TimeCounter -- 30 ticks per second
	local text = string.format("%s %02d:%02d:%02d.%02d", paused,
		t // 108000 % 24, t // 1800 % 60, t // 30 % 60, math.floor(t % 30 * 3.33333))
	local x = screen.X / 2 - fontTimer:GetStringWidth(paused .. " 00:00:00.00") / 2
	fontTimer:DrawStringScaled(text, x, 5 + hudPad.Y, 1, 1, KColor(1, 1, 1, config.transparency), 0, false)
end

-- Slots fill "lines" of `columns` cells: rows under the minimap (position 1) or columns along the bottom (position 2).
local function slotPosition(config, screen, hudPad, size, slot)
	local columns = config.columns
	local line, cell = math.floor(slot / columns), slot % columns
	local firstCell = size / 2 - size * columns + size * cell
	if config.position == 1 then
		return Vector(screen.X - hudPad.X + firstCell, MAP_PADDING + hudPad.Y + size * line)
	end
	return Vector(TRINKET_PADDING + hudPad.X + size * line, screen.Y - hudPad.Y + firstCell)
end

-- Floor name sits just before its first line; the following items shift by `step` to make room.
local function floorNameLayout(config, size, slot)
	if config.position == 1 then
		return Vector(-size / 2, -size / 2 - 2), Vector(0, size / 2)
	end
	if slot == 0 then
		return Vector(2 - size / 2, -size), Vector(0, 0)
	end
	return Vector(2, -size), Vector(size / 2, 0)
end

local function maxDisplay(config, screen, hudPad, size)
	local fillable = config.position == 1
		and screen.Y - 2 * hudPad.Y - MAP_PADDING - CARD_PADDING_TOP
		or screen.X - 2 * hudPad.X - TRINKET_PADDING - CARD_PADDING_LEFT
	return math.floor(fillable / size * config.columns)
end

local function spriteFor(id)
	if sprites[id] then return sprites[id] end
	local sprite = Sprite()
	sprite:Load("gfx/005.100_collectible.anm2", false)
	sprite:Play("ShopIdle")
	sprite:ReplaceSpritesheet(1, itemConfig:GetCollectible(id).GfxFileName)
	sprite:LoadGraphics()
	sprite:Update()
	sprites[id] = sprite
	return sprite
end

local function clockSprite()
	if clock then return clock end
	clock = Sprite()
	clock:Load("gfx/rehud/clock.anm2", true)
	clock:SetFrame("Idle", 0)
	return clock
end

-- Marks a temporary item: clock on top of the item, anchored at its bottom-right corner.
local function drawClock(pos, color, scale)
	local sprite = clockSprite()
	sprite.Color = color
	sprite.Scale = scale
	sprite:Render(pos + ITEM_BOTTOM_RIGHT * scale.X)
end

-- Newest item first.
local function drawItems(config, entries, screen, hudPad)
	local size = 32 * config.spriteScale
	local limit = maxDisplay(config, screen, hudPad, size)
	local color = Color(1, 1, 1, config.transparency)
	local textColor = KColor(1, 1, 1, config.transparency)
	local scale = Vector(config.spriteScale, config.spriteScale)
	local columns = config.columns
	local slot, lastFloor, padding = 0, "", Vector(0, 0)

	for i = #entries, 1, -1 do
		local entry = entries[i]
		if not config[TYPE_FILTER[entry.type]] then goto continue end
		if entry.temporary and not config.showTemporary then goto continue end

		if config.showFloor and entry.floor ~= lastFloor then
			slot = math.ceil(slot / columns) * columns
			if slot >= limit then return end
			local offset, step = floorNameLayout(config, size, slot)
			local pos = slotPosition(config, screen, hudPad, size, slot) + padding + offset
			local font = entry.floor:find("[\128-\255]") and fontFloorNameIntl or fontFloorName
			font:DrawStringScaledUTF8(entry.floor, pos.X, pos.Y, config.textScale, config.textScale, textColor, 0, false)
			lastFloor = entry.floor
			padding = padding + step
		end

		local sprite = spriteFor(entry.id)
		sprite.Color = color
		sprite.Scale = scale
		local pos = slotPosition(config, screen, hudPad, size, slot) + padding
		sprite:Render(pos)
		if entry.temporary then drawClock(pos, color, scale) end
		slot = slot + 1
		if slot >= limit then return end
		::continue::
	end
end

function Render.draw(config, entries)
	if config.disable then return end
	local screen = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
	local hudPad = HUD_OFFSET_MAX * Options.HUDOffset
	if config.showTimer then drawTimer(config, screen, hudPad) end
	if config.showItems then drawItems(config, entries, screen, hudPad) end
end

return Render
