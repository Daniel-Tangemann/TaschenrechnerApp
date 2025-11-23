-- ui/help_popup.lua
-- Einfache Hilfe-Sprechblase mit dynamischer Größe

local HelpPopup = {}

function HelpPopup.show(parentGroup, text)
    text = text or "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus."

    -- Overlay-Gruppe
    local group = display.newGroup()
    parentGroup:insert(group)

    -- Halbtransparenter Hintergrund, der Klicks abfängt
    local overlay = display.newRect(
        group,
        display.contentCenterX,
        display.contentCenterY,
        display.actualContentWidth,
        display.actualContentHeight
    )
    overlay:setFillColor(0, 0, 0, 0.35)

    -- Text vorerst bei (0,0), später im Bubble-Center
    local maxWidth = display.contentWidth * 0.7
    local txt = display.newText({
        parent   = group,
        text     = text,
        x        = 0,
        y        = 0,
        width    = maxWidth,
        font     = native.systemFont,
        fontSize = 40,
        align    = "center"
    })
    txt:setFillColor(1, 1, 1)

    -- Dynamische Sprechblasen-Größe
    local paddingX = 40
    local paddingY = 30

    local bubbleWidth  = txt.width  + paddingX * 2
    local bubbleHeight = txt.height + paddingY * 2

    local bubble = display.newRoundedRect(group, 0, 0, bubbleWidth, bubbleHeight, 32)
    bubble:setFillColor(0.1, 0.1, 0.3, 0.95)

    -- Text vor Bubble zeichnen
    txt:toFront()

    -- Gesamte Bubble (Text + Rect) zentrieren
    local bubbleGroup = display.newGroup()
    group:insert(bubbleGroup)
    bubbleGroup.x = display.contentCenterX
    bubbleGroup.y = display.contentCenterY - 100  -- bisschen höher als Mitte

    bubbleGroup:insert(bubble)
    bubbleGroup:insert(txt)
    bubble.x, bubble.y = 0, 0
    txt.x, txt.y = 0, 0

    -- Schließen-Funktion
    local function close()
        display.remove(group)
    end

    -- Klick auf Overlay oder Bubble schließt
    overlay:addEventListener("tap", function() close(); return true end)
    bubble:addEventListener("tap", function() close(); return true end)
    txt:addEventListener("tap", function() close(); return true end)

    return group
end

return HelpPopup
