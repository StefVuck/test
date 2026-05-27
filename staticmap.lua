-- staticmap.lua
-- Renders one or more pre-baked map images on a monitor with no train
-- tracking, no zoom, and no modem required.  Designed for secondary
-- displays such as a train schematic or route diagram.
--
-- Deploy alongside the map_*.lua data files listed in MAPS below.
-- If MAPS has more than one entry, tapping the monitor cycles through them.

local MAPS    = { "map_trainmap.lua" }
local REFRESH = 30   -- seconds between redraws (keeps display alive)

-- ---------------------------------------------------------------------------
-- Peripheral setup  (no modem needed for a static display)

local function findFirst(type_)
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == type_ then return side end
  end
end

local monitorSide = findFirst("monitor") or error("no monitor found")
local mon = peripheral.wrap(monitorSide)
mon.setTextScale(0.5)
local CW, CH = mon.getSize()
print(("Monitor: %d x %d chars  ->  %d x %d px"):format(CW, CH, CW, CH * 2))

-- ---------------------------------------------------------------------------
-- Map loading

local function loadMap(path)
  if not fs.exists(path) then return nil end
  local fn = loadfile(path)
  return fn and fn() or nil
end

local maps = {}
for _, f in ipairs(MAPS) do
  local m = loadMap(f)
  if m then
    maps[#maps + 1] = m
    print("Loaded " .. f)
  else
    print("WARNING: could not load " .. f)
  end
end
assert(#maps > 0, "no maps loaded -- check the MAPS list at the top of this file")

local current = 1

-- ---------------------------------------------------------------------------
-- Palette & rendering
-- Uses all 16 CC colour slots (no train marker reservation needed here).

local PALETTE_SLOTS = {
  colors.white, colors.orange, colors.magenta, colors.lightBlue,
  colors.yellow, colors.lime,  colors.pink,    colors.gray,
  colors.lightGray, colors.cyan, colors.purple, colors.blue,
  colors.brown, colors.green, colors.black, colors.red,
}
local HEX_TO_SLOT = {}
for i, slot in ipairs(PALETTE_SLOTS) do HEX_TO_SLOT[i - 1] = slot end

local hexVal = {}
for i = 0, 15 do hexVal[string.format("%x", i)] = i end

local HALF = "\143"

local function render(map)
  -- Apply this map's custom palette
  for idx = 0, 15 do
    local hex = map.palette[idx]
    if hex then mon.setPaletteColour(HEX_TO_SLOT[idx], hex) end
  end

  for cy = 1, CH do
    local pyTop = (cy - 1) * 2
    local pyBot = pyTop + 1
    local chars, fgs, bgs = {}, {}, {}
    for cx = 1, CW do
      local px = cx - 1
      local function pix(y)
        if px < 0 or px >= map.width or y < 0 or y >= map.height then
          return 0
        end
        local i = y * map.width + px + 1
        return hexVal[map.pixels:sub(i, i)] or 0
      end
      chars[cx] = HALF
      fgs[cx]   = colors.toBlit(HEX_TO_SLOT[pix(pyTop)])
      bgs[cx]   = colors.toBlit(HEX_TO_SLOT[pix(pyBot)])
    end
    mon.setCursorPos(1, cy)
    mon.blit(table.concat(chars), table.concat(fgs), table.concat(bgs))
  end
end

-- ---------------------------------------------------------------------------
-- Main loop: render then wait; touch cycles maps, timer triggers refresh

local function main()
  while true do
    render(maps[current])

    local timer = os.startTimer(REFRESH)
    while true do
      local ev, a = os.pullEvent()
      if ev == "timer" and a == timer then
        break                               -- periodic refresh
      elseif ev == "monitor_touch" and #maps > 1 then
        current = (current % #maps) + 1    -- cycle to next map
        break
      end
    end
  end
end

main()
