-- scenes/dividieren.lua
local composer       = require("composer")
local scene          = composer.newScene()

local layout         = require("layout")
local Button         = require("ui.button")
local HelpPopup      = require("ui.help_popup")
local i18n           = require("lang.i18n")
local CounterMachine = require("ui.counter_machine")

---------------------------------------------------------
-- Feste Spawn-Positionen für Dividend (linkes Feld)
---------------------------------------------------------
local fixedSpawn = {
    left = {
        {138, 380}, {280, 380}, {422, 380},
        {138, 545}, {280, 545}, {422, 545},
        {138, 715}, {280, 715}, {422, 715},
        {138, 890}, {280, 890}, {422, 890},
    }
}

---------------------------------------------------------
-- Lokale Variablen
---------------------------------------------------------
local marbles        = {}
local machine
local remainderRect
local divisor        = 1
local groupCount     = 0

-- Rest-Logik
local maxRemainder   = 0      -- wie viele Murmeln dürfen im Rest landen
local remainderCount = 0      -- wie viele sind tatsächlich im Rest gelandet

-- Segmentbalken
local segmentBarGroup
local segmentRects = {}

-- Schlucklinie (wird in scene:create dynamisch gesetzt)
local SWALLOW_LINE_Y = 2000

-- Feste Slots für Rest-Murmeln (max. 9)
local restSlots = {}

---------------------------------------------------------
-- Hilfsfunktion: Punkt in Rechteck?
---------------------------------------------------------
local function pointInRect(x, y, rect)
    local hw = rect.width * 0.5
    local hh = rect.height * 0.5
    return  x >= rect.x - hw and x <= rect.x + hw
        and y >= rect.y - hh and y <= rect.y + hh
end

---------------------------------------------------------
-- Segmentbalken aktualisieren
---------------------------------------------------------
local function updateSegmentBar()
    for i, seg in ipairs(segmentRects) do
        if i <= groupCount then
            seg:setFillColor(1, 1, 0.2)
        else
            seg:setFillColor(0.2, 0.2, 0.35)
        end
    end
end

---------------------------------------------------------
-- Letztes Segment kurz blinken lassen
---------------------------------------------------------
local function blinkLastSegment(index)
    local seg = segmentRects[index]
    if not seg then return end

    transition.to(seg, { time = 120, alpha = 0.1 })
    transition.to(seg, { time = 120, delay = 120, alpha = 1 })
end

---------------------------------------------------------
-- Wenn eine Murmel gezählt wurde
---------------------------------------------------------
local function onMarbleCounted()
    groupCount = groupCount + 1

    if groupCount == divisor then
        -- komplette Gruppe voll → 1 zum Quotienten und letzter Balken blinkt
        blinkLastSegment(divisor)
        groupCount = 0
        machine:increment()
    end

    updateSegmentBar()
end

---------------------------------------------------------
-- Murmel in die Maschine einsaugen
---------------------------------------------------------
local function swallowIntoMachine(m)
    if m.removed then return end
    m.removed = true

    transition.to(m, {
        time   = 150,
        x      = machine.group.x + machine.funnelX,
        y      = machine.group.y + machine.funnelY,
        xScale = 0.3,
        yScale = 0.3,
        alpha  = 0,
        onComplete = function()
            if m.removeSelf then m:removeSelf() end
            onMarbleCounted()
        end
    })
end

---------------------------------------------------------
-- Touch-Listener für Murmeln
---------------------------------------------------------
local function marbleTouch(event)
    local m = event.target
    if m.removed then return end

    if event.phase == "began" then
        display.getCurrentStage():setFocus(m)
        m.isFocus = true
        m.ox = event.x - m.x
        m.oy = event.y - m.y
        return true

    elseif m.isFocus then

        if event.phase == "moved" then
            m.x = event.x - m.ox
            m.y = event.y - m.oy

        elseif event.phase == "ended" or event.phase == "cancelled" then
            display.getCurrentStage():setFocus(nil)
            m.isFocus = false

            local x, y = m.x, m.y

            -------------------------------------------------
            -- 1) Schlucklinie: Maschine frisst Murmel
            -------------------------------------------------
            if y >= SWALLOW_LINE_Y then
                swallowIntoMachine(m)
                return true
            end

            -------------------------------------------------
            -- 2) Restfeld: maxRemainder begrenzt, feste Slots
            -------------------------------------------------
            if remainderRect and pointInRect(x, y, remainderRect) then
                if remainderCount < maxRemainder then
                    remainderCount = remainderCount + 1

                    -- Slot anhand remainderCount auswählen (1-basiert)
                    local slot = restSlots[remainderCount]
                    if not slot then
                        -- Fallback: Mitte des Restfelds
                        slot = { x = remainderRect.x, y = remainderRect.y }
                    end

                    transition.to(m, {
                        time = 100,
                        x    = slot.x,
                        y    = slot.y,
                        onComplete = function()
                            m:removeEventListener("touch", marbleTouch)
                        end
                    })
                else
                    -- Kein Platz mehr im Rest → zurück zum Spawn
                    transition.to(m, {
                        time = 180,
                        x    = m.spawnX,
                        y    = m.spawnY
                    })
                end
                return true
            end

            -------------------------------------------------
            -- 3) Sonst zurück zum Spawnpunkt
            -------------------------------------------------
            transition.to(m, {
                time = 180,
                x    = m.spawnX,
                y    = m.spawnY
            })
            return true
        end
    end

    return false
end

---------------------------------------------------------
-- Murmeln im linken Feld erzeugen
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, rect)
    local list = fixedSpawn.left
    for i = 1, num do
        local m = display.newImageRect(sceneGroup, "imgs/marble.png", 264 * 0.6, 266 * 0.6)

        if i <= #list then
            m.x, m.y = list[i][1], list[i][2]
        else
            local hw = rect.width * 0.5 - 40
            local hh = rect.height * 0.5 - 40
            m.x = rect.x + math.random(-hw, hw)
            m.y = rect.y + math.random(-hh, hh)
        end

        m.spawnX  = m.x
        m.spawnY  = m.y
        m.removed = false

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
    end
end

---------------------------------------------------------
-- Rest-Slots vorbereiten (max. 9 Slots in 3x3-Gitter)
---------------------------------------------------------
local function computeRestSlots()
    restSlots = {}

    if not remainderRect then return end

    local cx, cy = remainderRect.x, remainderRect.y
    local hw     = remainderRect.width  * 0.25
    local hh     = remainderRect.height * 0.25

    -- 3x3-Raster um die Mitte des Restfelds
    local offsets = {
        { -hw, -hh }, {  0, -hh }, {  hw, -hh },
        { -hw,   0 }, {  0,   0 }, {  hw,   0 },
        { -hw,  hh }, {  0,  hh }, {  hw,  hh },
    }

    for i = 1, 9 do
        local off = offsets[i]
        restSlots[i] = { x = cx + off[1], y = cy + off[2] }
    end
end

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view

    marbles        = {}
    segmentRects   = {}
    remainderCount = 0
    groupCount     = 0

    local params     = event.params or {}
    local leftValue  = params.left  or 10
    local rightValue = params.right or 3
    divisor          = rightValue
    if divisor < 1 then divisor = 1 end

    maxRemainder = leftValue % divisor  -- mathematisch korrekter Rest

    -----------------------------------------------------
    -- Hintergrund
    -----------------------------------------------------
    local back = display.newImageRect(sceneGroup, "imgs/divi_backgr.png", 1080, 1920)
    back.x, back.y = display.contentCenterX, display.contentCenterY

    -----------------------------------------------------
    -- Banner / Titel
    -----------------------------------------------------
    local banner = display.newImageRect(sceneGroup, "imgs/banner.png", 788 * 0.7, 206 * 0.7)
    banner.x, banner.y = display.contentCenterX, 120

    display.newText({
        parent   = sceneGroup,
        text     = i18n.t("div_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72
    })

    -----------------------------------------------------
    -- Obere Bereiche: Dividend links, Rest rechts
    -----------------------------------------------------
    local topY  = display.contentCenterY - 320
    local areaW = display.contentWidth * 0.44
    local areaH = 700

    local leftRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.25,
        topY,
        areaW,
        areaH,
        32
    )
    leftRect:setFillColor(0.1, 0.15, 0.3, 0.85)

    remainderRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.75,
        topY,
        areaW,
        areaH,
        32
    )
    remainderRect:setFillColor(0.15, 0.1, 0.25, 0.85)

    -----------------------------------------------------
    -- Rest-Slots vorberechnen
    -----------------------------------------------------
    computeRestSlots()

    -----------------------------------------------------
    -- Murmeln spawnen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue, leftRect)

    -----------------------------------------------------
    -- Zählmaschine unten
    -----------------------------------------------------
    machine = CounterMachine.new(sceneGroup, {
        x     = display.contentCenterX,
        y     = display.contentHeight * 0.72,
        scale = 0.8
    })
    machine:setValue(0)

    -----------------------------------------------------
    -- Schlucklinie dynamisch aus Trichterposition
    -----------------------------------------------------
    local fx, fy = machine.group:localToContent(machine.funnelX, machine.funnelY)
    SWALLOW_LINE_Y = fy + 80   -- etwas unterhalb des Funnel-Eingangs

    -----------------------------------------------------
    -- Segmentbalken unter den Rollen (mit deinen Werten)
    -----------------------------------------------------
    segmentBarGroup = display.newGroup()
    sceneGroup:insert(segmentBarGroup)

    local bodyW = machine.body.width
    local bodyH = machine.body.height

    local barWidth  = bodyW * 0.6        -- deine funktionierenden Werte
    local barHeight = bodyH * 0.08
    local barX      = machine.group.x + bodyW * 0.1
    local barY      = machine.group.y + bodyH * 0.36

    -- Hintergrund des Balkens
    local barBg = display.newRoundedRect(segmentBarGroup, barX, barY, barWidth, barHeight, 10)
    barBg:setFillColor(0, 0, 0, 0.6)

    -- Segmente entsprechend dem Divisor
    local segCount = divisor
    local gap      = 4
    local segW     = (barWidth - gap * (segCount - 1)) / segCount

    for i = 1, segCount do
        local x = barX - barWidth * 0.5 + segW * 0.5 + (i - 1) * (segW + gap)
        local seg = display.newRoundedRect(segmentBarGroup, x, barY, segW, barHeight, 8)
        seg:setFillColor(0.2, 0.2, 0.35)
        segmentRects[#segmentRects + 1] = seg
    end

    updateSegmentBar()

    -----------------------------------------------------
    -- Hilfe-Button
    -----------------------------------------------------
    local hx, hy = layout.toCenter(layout.helpIcon)
    Button.new(sceneGroup, {
        image  = "imgs/questionmark.png",
        width  = layout.helpIcon.size,
        height = layout.helpIcon.size,
        scale  = layout.helpIcon.scale,
        x      = hx,
        y      = hy,
        onTap  = function()
            HelpPopup.show(sceneGroup, i18n.t("help_div"))
        end
    })

    -----------------------------------------------------
    -- Zurück-Button
    -----------------------------------------------------
    local backBtn = Button.new(sceneGroup, {
        image  = "imgs/btn_long_alt.png",
        width  = layout.longButtons.width,
        height = layout.longButtons.height,
        scale  = layout.longButtons.scale,
        x      = display.contentCenterX,
        y      = display.contentHeight - 120,
        onTap  = function()
            composer.gotoScene("scenes.taschenrechner", {
                effect = "slideRight",
                time   = 300,
                params = { reset = true }
            })
            composer.removeScene("scenes.dividieren")
        end
    })

    local arrow = display.newImageRect(
        sceneGroup,
        "imgs/arrow.png",
        1125 * 0.3,
        194 * 0.5
    )
    arrow.x = backBtn.group.x 
    arrow.y = backBtn.group.y
end

---------------------------------------------------------
function scene:destroy(event)
    for i = #marbles, 1, -1 do
        local m = marbles[i]
        if m.removeSelf then m:removeSelf() end
        marbles[i] = nil
    end
    marbles = {}

    if segmentBarGroup and segmentBarGroup.removeSelf then
        segmentBarGroup:removeSelf()
    end
    segmentBarGroup = nil
    segmentRects    = {}
    restSlots       = {}
end

scene:addEventListener("create", scene)
scene:addEventListener("destroy", scene)

return scene
