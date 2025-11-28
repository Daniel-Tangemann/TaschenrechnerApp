-- scenes/dividieren.lua
local composer       = require("composer")
local scene          = composer.newScene()

local layout         = require("layout")
local Button         = require("ui.button")
local HelpPopup      = require("ui.help_popup")
local i18n           = require("lang.i18n")
local CounterMachine = require("ui.counter_machine")

---------------------------------------------------------
-- Feste Spawn-Positionen (Canvas 1080 x 1920)
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
local machine        -- CounterMachine-Instanz
local remainderRect  -- Bereich für den Teilungsrest
local cloneCenterX, cloneCenterY  -- Funnel-Zentrum der Maschine (unterer Trichter)
local divisor        = 1    -- rechte Zahl (Teiler)
local groupCount     = 0    -- wie viele Murmeln wurden in der aktuellen Gruppe geschluckt?

-- Segmentbalken
local segmentBarGroup
local segmentRects = {}

---------------------------------------------------------
-- kleine Hilfsfunktion
---------------------------------------------------------
local function pointInRect(x, y, rect)
    local halfW = rect.width * 0.5
    local halfH = rect.height * 0.5
    return  x >= rect.x - halfW and x <= rect.x + halfW and
            y >= rect.y - halfH and y <= rect.y + halfH
end

---------------------------------------------------------
-- Segmentbalken aktualisieren
---------------------------------------------------------
local function updateSegmentBar()
    if not segmentRects or #segmentRects == 0 then return end

    for i, seg in ipairs(segmentRects) do
        if i <= groupCount then
            seg:setFillColor(0.9, 0.9, 0.2)   -- ✏️ Farbe "aktives" Segment
        else
            seg:setFillColor(0.2, 0.2, 0.3)   -- ✏️ Farbe "inaktiv"
        end
    end
end

---------------------------------------------------------
-- wenn eine Murmel komplett geschluckt ist
---------------------------------------------------------
local function onMarbleCounted()
    if divisor <= 0 then return end

    groupCount = groupCount + 1
    if groupCount >= divisor then
        -- Eine volle Gruppe: Quotient +1
        groupCount = 0
        if machine then
            machine:increment()
        end
    end
    updateSegmentBar()
end

---------------------------------------------------------
-- Murmel in Maschine einsaugen
---------------------------------------------------------
local function swallowIntoMachine(marble)
    if not marble or marble.removed then
        return
    end
    marble.removed = true

    transition.to(marble, {
        time   = 180,     -- ✏️ Dauer der Einsaug-Animation
        x      = cloneCenterX,
        y      = cloneCenterY,
        xScale = 0.3,
        yScale = 0.3,
        alpha  = 0.0,
        onComplete = function()
            if marble.removeSelf then
                marble:removeSelf()
            end
            onMarbleCounted()
        end
    })
end

---------------------------------------------------------
-- Touch-Listener für Murmeln
---------------------------------------------------------
local function marbleTouch(event)
    local target = event.target
    if not target or target.removed then
        return false
    end

    if event.phase == "began" then
        display.getCurrentStage():setFocus(target)
        target.isFocus = true
        target.touchOffsetX = event.x - target.x
        target.touchOffsetY = event.y - target.y
        return true

    elseif target.isFocus then
        if event.phase == "moved" then
            target.x = event.x - target.touchOffsetX
            target.y = event.y - target.touchOffsetY

        elseif event.phase == "ended" or event.phase == "cancelled" then
            display.getCurrentStage():setFocus(nil)
            target.isFocus = false

            -- Spawn fallback
            target.spawnX = target.spawnX or target.x
            target.spawnY = target.spawnY or target.y

            local x, y = target.x, target.y

            -------------------------------------------------
            -- 1) In den unteren Trichter? → Maschine schluckt
            -------------------------------------------------
            local dx = x - cloneCenterX
            local dy = y - cloneCenterY
            local dist2 = dx*dx + dy*dy
            local radius = 260        -- ✏️ Größe der Fangzone des unteren Trichters

            if dist2 <= radius * radius then
                swallowIntoMachine(target)
                return true
            end

            -------------------------------------------------
            -- 2) Im Rest-Feld? → dort ablegen und "sperren"
            -------------------------------------------------
            if remainderRect and pointInRect(x, y, remainderRect) then
                -- Snap etwas in die Mitte des Restfeldes
                transition.to(target, {
                    time = 120,
                    x = remainderRect.x,       -- ✏️ ggf. etwas zufällige Position im Restfeld
                    y = remainderRect.y,
                    onComplete = function()
                        target:removeEventListener("touch", marbleTouch)
                    end
                })
                return true
            end

            -------------------------------------------------
            -- 3) Sonst zurück zum Spawn
            -------------------------------------------------
            transition.to(target, {
                time       = 200,
                x          = target.spawnX,
                y          = target.spawnY,
                transition = easing.outQuad
            })
            return true
        end
    end

    return false
end

---------------------------------------------------------
-- Murmeln erzeugen (links)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect)
    local list = fixedSpawn.left or {}
    local maxFixed = #list

    for i = 1, num do
        local m = display.newImageRect(
            sceneGroup,
            "imgs/marble.png",
            264 * 0.6,   -- ✏️ Murmelgröße
            266 * 0.6
        )

        if i <= maxFixed then
            local pos = list[i]
            m.x, m.y = pos[1], pos[2]
        else
            local halfW = containerRect.width * 0.5 - 40
            local halfH = containerRect.height * 0.5 - 40
            m.x = containerRect.x + math.random(-halfW, halfW)
            m.y = containerRect.y + math.random(-halfH, halfH)
        end

        m.spawnX = m.x
        m.spawnY = m.y
        m.removed = false

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
    end
end

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    marbles          = {}
    segmentRects     = {}
    groupCount       = 0

    local params = event.params or {}
    local leftValue  = params.left  or 10
    local rightValue = params.right or 3
    divisor          = rightValue or 1

    if divisor < 1 then divisor = 1 end

    -----------------------------------------------------
    -- Banner / Titel oben
    -----------------------------------------------------
    local banner = display.newImageRect(
        sceneGroup,
        "imgs/banner.png",
        layout.screen.width * 0.9,
        layout.screen.height * 0.12
    )
    banner.x = display.contentCenterX
    banner.y = 120

    local title = display.newText({
        parent   = sceneGroup,
        text     = i18n.t("div_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72       -- ✏️ Titelgröße
    })

    -----------------------------------------------------
    -- Zwei obere Bereiche: links Dividend, rechts Restfeld
    -----------------------------------------------------
    local topY          = display.contentCenterY - 320
    local areaWidth     = display.contentWidth * 0.44
    local areaHeightTop = 700

    local leftRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.25,
        topY,
        areaWidth,
        areaHeightTop,
        32
    )
    leftRect:setFillColor(0.1, 0.15, 0.3, 0.85)

    remainderRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.75,
        topY,
        areaWidth,
        areaHeightTop,
        32
    )
    remainderRect:setFillColor(0.15, 0.10, 0.25, 0.85)  -- ✏️ Farbe Restfeld

    -----------------------------------------------------
    -- Murmeln links spawnen (Dividend)
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue, leftRect)

    -----------------------------------------------------
    -- Zählmaschine unten
    -----------------------------------------------------
    machine = CounterMachine.new(sceneGroup, {
        x     = display.contentCenterX,
        y     = display.contentHeight * 0.72,  -- ✏️ vertikale Position
        scale = 0.8                            -- ✏️ Größe der Zählmaschine
    })
    machine:setValue(0)

    -- Funnel-Zentrum ungefähr in der Mitte des oberen Trichters der Maschine
    cloneCenterX = machine.group.x
    cloneCenterY = machine.group.y - machine.body.height * 0.45  -- ✏️ Position des unteren Trichters

    -----------------------------------------------------
    -- Segmentbalken über der Maschine
    -----------------------------------------------------
    segmentBarGroup = display.newGroup()
    sceneGroup:insert(segmentBarGroup)

    local segCount = math.max(1, divisor)
    local barWidth  = machine.body.width * 0.6   -- ✏️ Breite des Balkens relativ zur Maschine
    local barHeight = 26                         -- ✏️ Höhe des Balkens
    local barX      = machine.group.x
    local barY      = machine.group.y - machine.body.height * 0.1  -- ✏️ vertikale Position des Balkens

    local gap       = 4                          -- ✏️ Abstand zwischen Segmenten
    local segWidth  = (barWidth - (segCount - 1) * gap) / segCount

    -- Hintergrund des Balkens
    local barBg = display.newRoundedRect(
        segmentBarGroup,
        barX,
        barY,
        barWidth + 8,
        barHeight + 8,
        8
    )
    barBg:setFillColor(0, 0, 0, 0.6)

    for i = 1, segCount do
        local x = barX - barWidth * 0.5 + segWidth * 0.5 + (i - 1) * (segWidth + gap)
        local seg = display.newRoundedRect(
            segmentBarGroup,
            x,
            barY,
            segWidth,
            barHeight,
            6
        )
        seg:setFillColor(0.2, 0.2, 0.3)
        segmentRects[#segmentRects + 1] = seg
    end

    updateSegmentBar()

    -----------------------------------------------------
    -- Hilfe-Button (Fragezeichen oben rechts)
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
    -- Zurück-Button unten
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
        669 * 0.2,
        267 * 0.2
    )
    arrow.x = backBtn.group.x - backBtn.width * 0.15
    arrow.y = backBtn.group.y
end

function scene:show(event)
end

function scene:hide(event)
end

function scene:destroy(event)
    for i = #marbles, 1, -1 do
        local m = marbles[i]
        if m.removeSelf then
            m:removeSelf()
        end
        marbles[i] = nil
    end
    marbles = {}

    if segmentBarGroup and segmentBarGroup.removeSelf then
        segmentBarGroup:removeSelf()
    end
    segmentBarGroup = nil
    segmentRects = {}

    machine       = nil
    remainderRect = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
