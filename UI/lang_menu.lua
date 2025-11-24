-- ui/lang_menu.lua
-- Einfaches Dropdown mit Flaggen zur Sprachauswahl

local Button = require("ui.button")
local i18n   = require("lang.i18n")

local LangMenu = {}

-- interne Referenz, damit immer nur ein Menü offen ist
local currentMenuGroup = nil

-- Flaggen sind 900 x 600 px
local FLAG_W = 900
local FLAG_H = 600

-- Flaggen-Konfiguration
local flags = {
    { lang = "de", image = "imgs/DE.png" },
    { lang = "en", image = "imgs/EN.png" },
    { lang = "es", image = "imgs/ES.png" },
    { lang = "fr", image = "imgs/FR.png" },
}

local function closeMenu()
    if currentMenuGroup then
        currentMenuGroup:removeSelf()
        currentMenuGroup = nil
    end
end

-- parentGroup: z.B. sceneGroup
-- anchorX, anchorY: Position des Settings-Buttons
function LangMenu.toggle(parentGroup, anchorX, anchorY)
    -- Wenn schon offen → schließen
    if currentMenuGroup then
        closeMenu()
        return
    end

    local group = display.newGroup()
    parentGroup:insert(group)
    currentMenuGroup = group

    ------------------------------------------------
    -- Klick außerhalb schließt das Menü
    ------------------------------------------------
    local overlay = display.newRect(
        group,
        display.contentCenterX,
        display.contentCenterY,
        display.actualContentWidth,
        display.actualContentHeight
    )
    overlay.isVisible = false
    overlay.isHitTestable = true
    overlay:addEventListener("tap", function()
        closeMenu()
        return true
    end)

    ------------------------------------------------
    -- Hintergrund der Dropdown-Box
    ------------------------------------------------
    local itemHeight = 130
    local paddingX  = 30
    local paddingY  = 20

    -- Flaggen-Skalierung: ca. 70% der Item-Höhe
    local flagScale = (itemHeight * 0.7) / FLAG_H
    local flagWidth = FLAG_W * flagScale

    local boxWidth  = flagWidth + paddingX * 2
    local boxHeight = #flags * itemHeight + paddingY * 2

    local box = display.newRoundedRect(
        group,
        anchorX,
        anchorY + boxHeight * 0.5 + 20,
        boxWidth,
        boxHeight,
        24
    )
    box:setFillColor(0, 0, 0, 0.8)

    ------------------------------------------------
    -- Flaggen-Buttons
    ------------------------------------------------
    local baseY = box.y - boxHeight * 0.5 + paddingY + itemHeight * 0.5

    for i, cfg in ipairs(flags) do
        local y = baseY + (i - 1) * itemHeight

        local btn = Button.new(group, {
            image  = cfg.image,
            width  = FLAG_W,
            height = FLAG_H,
            scale  = flagScale,
            x      = box.x,
            y      = y,
            onTap  = function()
                -- Sprache umstellen
                i18n.load(cfg.lang)
                -- Menü schließen
                closeMenu()
                return true
            end
        })

        -- Aktive Sprache leicht hervorheben
        if i18n.current == cfg.lang then
            btn.group.alpha = 1.0
        else
            btn.group.alpha = 0.6
        end
    end
end

return LangMenu
