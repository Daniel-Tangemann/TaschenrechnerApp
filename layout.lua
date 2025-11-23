-- layout.lua
-- Zentrales Layout-Config für den Taschenrechner-Screen

local layout = {}

-- Design-Canvas (deine Gimp-Leinwand)
layout.designWidth  = 1080
layout.designHeight = 1920

---------------------------------------------------------
-- Bildschirm-Display (screen.png)
---------------------------------------------------------
layout.screen = {
    x      = 68,    -- Top-Left im Design
    y      = 96,
    width  = 950,
    height = 576,
    scale  = 1.0,
}

---------------------------------------------------------
-- Zahlen- / Standard-Buttons (btn_key.png)
-- 4 x 4 Grid, Start bei (68, 710), Abstand 72 px
---------------------------------------------------------
layout.buttonsGrid = {
    x         = 68,     -- Top-Left des ersten Buttons
    y         = 710,
    cols      = 4,
    rows      = 4,
    dx        = 50,     -- Abstand Top-Left zu Top-Left horizontal
    dy        = 50,     -- Abstand vertikal
    btnWidth  = 214,
    btnHeight = 205,
    scale     = 190 / 205,  -- ~0.9268
}

---------------------------------------------------------
-- Lange Buttons unten (btn_long.png)
-- 2 Stück nebeneinander, Start bei (68, 1685), Abstand 132 px
---------------------------------------------------------
layout.longButtons = {
    x         = 68,    -- Top-Left des linken Buttons
    y         = 1685,
    width     = 416,
    height    = 193,
    scale     = 1.0,
    gapX      = 132,   -- Abstand zwischen den beiden Top-Lefts
}

---------------------------------------------------------
-- Settings-Icon (settings.png)
---------------------------------------------------------
layout.settingsIcon = {
    x      = 12,      -- Top-Left
    y      = 12,
    size   = 138,     -- width = height = 138
    scale  = 88 / 138 -- ~0.6377
}

---------------------------------------------------------
-- Hilfe-Icon (questionmark.png)
---------------------------------------------------------
layout.helpIcon = {
    x      = 986,     -- Top-Left
    y      = 12,
    size   = 138,
    scale  = 88 / 138
}

---------------------------------------------------------
-- Hilfsfunktionen
-- (Top-Left → Center, Button-Grid-Positionen etc.)
---------------------------------------------------------

-- Allgemein: Top-Left + width/height/scale → Center
function layout.toCenter(entry)
    local scale = entry.scale or 1.0
    local w = entry.width or entry.size or 0
    local h = entry.height or entry.size or 0

    local cx = entry.x + (w * scale) * 0.5
    local cy = entry.y + (h * scale) * 0.5
    return cx, cy
end

-- Speziell für Grid-Buttons (Spalte/Zeile → Center)
-- col, row beginnen bei 1
function layout.getGridButtonCenter(col, row)
    local g = layout.buttonsGrid
    local scale = g.scale or 1.0

    -- alte → falsch
    -- local x = g.x + (col - 1) * g.dx
    -- local y = g.y + (row - 1) * g.dy

    local bw = g.btnWidth  * scale
    local bh = g.btnHeight * scale

    local x = g.x + (col - 1) * (bw + g.dx)
    local y = g.y + (row - 1) * (bh + g.dy)

    local cx = x + bw * 0.5
    local cy = y + bh * 0.5
    return cx, cy
end


-- Center-Positionen der beiden langen Buttons unten
function layout.getLongButtonCenter(index)
    -- index = 1 (links) oder 2 (rechts)
    local lb = layout.longButtons
    local scale = lb.scale or 1.0

    local x = lb.x + (index - 1) * (lb.width + lb.gapX)
    local y = lb.y

    local cx = x + (lb.width  * scale) * 0.5
    local cy = y + (lb.height * scale) * 0.5
    return cx, cy
end

return layout
