-- scenes/subtrahieren.lua
local composer       = require("composer")
local scene          = composer.newScene()

local layout         = require("layout")
local Button         = require("ui.button")
local HelpPopup      = require("ui.help_popup")
local i18n           = require("lang.i18n")
local CounterMachine = require("ui.counter_machine")

---------------------------------------------------------
-- Num-Hints (0–99) aus num_hints.png
---------------------------------------------------------
local numHintSheetOptions = {
    width     = 64,
    height    = 64,
    numFrames = 100,   -- 0..99
}
local numHintSheet = graphics.newImageSheet("imgs/num_hints.png", numHintSheetOptions)

-- Referenzen für die beiden Zahlensprites
local numHintLeft
local numHintRight

---------------------------------------------------------
-- Feste Spawn-Positionen (Canvas 1080 x 1920)
---------------------------------------------------------
local fixedSpawn = {
    left = {
        {138, 380}, {280, 380}, {422, 380},
        {138, 545}, {280, 545}, {422, 545},
        {138, 715}, {280, 715}, {422, 715},
        {280, 890},
    },
    right = {
        {650, 380}, {792, 380}, {934, 380},
        {650, 545}, {792, 545}, {934, 545},
        {650, 715}, {792, 715}, {934, 715},
        {792, 890},
    }
}

---------------------------------------------------------
-- Lokale Variablen
---------------------------------------------------------
local marbles = {}
local slots   = {}  -- rechte Plätze (empty_spot)
local machine          -- CounterMachine-Instanz
local segmentBarGroup  -- Gruppe für den Balken
local counterBar       -- einzelner, voller Balken

---------------------------------------------------------
-- Balken kurz aufblinken lassen, wenn gezählt wurde
---------------------------------------------------------
local function blinkCounterBar()
    if not counterBar then return end

    -- evtl. laufende Animation abbrechen
    transition.cancel(counterBar)

    -- hell machen
    counterBar:setFillColor(1, 1, 0.2)
    counterBar.alpha = 1

    -- wieder abdunkeln
    transition.to(counterBar, {
        time  = 200,
        alpha = 0.7,
        onComplete = function()
            if counterBar then
                counterBar:setFillColor(0.2, 0.2, 0.35)
            end
        end
    })
end

---------------------------------------------------------
-- Slot-Helfer
---------------------------------------------------------
local function areAllSlotsFilled()
    for _, s in ipairs(slots) do
        if not s.occupied then
            return false
        end
    end
    return true
end

local function findNearestFreeSlot(x, y)
    local bestSlot = nil
    local bestDist2 = nil

    for _, s in ipairs(slots) do
        if not s.occupied then
            local dx = x - s.x
            local dy = y - s.y
            local d2 = dx*dx + dy*dy
            if not bestDist2 or d2 < bestDist2 then
                bestDist2 = d2
                bestSlot  = s
            end
        end
    end

    return bestSlot, bestDist2
end

---------------------------------------------------------
-- Touch-Listener für Murmeln
---------------------------------------------------------
local function marbleTouch(event)
    local target = event.target
    if not target or target.removed then
        return false
    end

    -- Murmeln, die in einem Slot eingerastet sind, bleiben dort
    if target.locked then
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

            -- Sicherheitsnetz: falls Spawn nicht gesetzt wurde
            target.spawnX = target.spawnX or target.x
            target.spawnY = target.spawnY or target.y

            ----------------------------------------------------------------
            -- 1. Versuch: in einen freien Slot auf der rechten Seite einrasten
            ----------------------------------------------------------------
            local snapRadius = 120    -- wie nah man sein muss, um zu snappen
            local slot, dist2 = findNearestFreeSlot(target.x, target.y)

            if slot and dist2 and dist2 <= (snapRadius * snapRadius) then
                -- Murmel auf den Slot zentrieren und dort festsetzen
                target.x = slot.x
                target.y = slot.y
                target.spawnX = target.x
                target.spawnY = target.y
                target.locked = true

                slot.occupied = true
                slot.marble   = target
                return true
            end

            ----------------------------------------------------------------
            -- 2. Falls alle Slots voll sind: Murmel kann nach unten in die Maschine
            ----------------------------------------------------------------
            local thresholdY = display.contentHeight * 0.5

            if machine and areAllSlotsFilled() and target.y >= thresholdY then
                -- 🔴 hier hängen wir das Balken-Blinken dran
                machine:swallowMarble(target, function()
                    blinkCounterBar()
                end)
                return true
            else
                -- 3. Ansonsten: zurück zum Spawnpoint
                transition.to(target, {
                    time       = 200,
                    x          = target.spawnX,
                    y          = target.spawnY,
                    transition = easing.outQuad
                })
                return true
            end
        end
    end

    return false
end

---------------------------------------------------------
-- Murmeln erzeugen (links)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect, side)
    local list = fixedSpawn[side] or {}
    local maxFixed = #list

    for i = 1, num do
        local m = display.newImageRect(
            sceneGroup,
            "imgs/grey_marble.png",
            264 * 0.6,
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
        m.locked  = false

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
    end
end

---------------------------------------------------------
-- Slots (empty_spot) erzeugen (rechts)
---------------------------------------------------------
local function spawnSlots(sceneGroup, num)
    slots = {}

    local list = fixedSpawn.right
    local maxFixed = #list

    local count = math.min(num, maxFixed)
    for i = 1, count do
        local pos = list[i]
        local spotImg = display.newImageRect(
            sceneGroup,
            "imgs/empty_spot.png",
            274 * 0.6,
            274 * 0.6
        )
        spotImg.x = pos[1]
        spotImg.y = pos[2]

        slots[#slots + 1] = {
            x        = pos[1],
            y        = pos[2],
            display  = spotImg,
            occupied = false,
            marble   = nil,
        }
    end
end

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    marbles = {}
    slots   = {}

    local params = event.params or {}
    local leftValue  = params.left  or 9
    local rightValue = params.right or 3
    -- Ergebnis wäre leftValue - rightValue, aber hier nur Info

    -----------------------------------------------------
    -- Background
    -----------------------------------------------------
    local backgr = display.newImageRect(
        sceneGroup,
        "imgs/subt_backgr.png",
        1080,
        1920
    )
    backgr.x = display.contentCenterX
    backgr.y = display.contentCenterY

    -----------------------------------------------------
    -- Banner / Titel oben
    -----------------------------------------------------
    local banner = display.newImageRect(
        sceneGroup,
        "imgs/banner.png",
        788 * 0.7,
        206 * 0.7
    )
    banner.x = display.contentCenterX
    banner.y = 120

    local title = display.newText({
        parent   = sceneGroup,
        text     = i18n.t("sub_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72
    })

    -----------------------------------------------------
    -- Zwei obere Bereiche: links Murmeln, rechts Slots
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

    local rightRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.75,
        topY,
        areaWidth,
        areaHeightTop,
        32
    )
    rightRect:setFillColor(0.1, 0.15, 0.3, 0.85)

    -----------------------------------------------------
    -- Num-Hints (Zahlen 0..99 über den Bereichen, statisch)
    -----------------------------------------------------
    local function clampToHintRange(v)
        if v < 0 then return 0 end
        if v > 99 then return 99 end
        return v
    end

    local leftFrame  = clampToHintRange(leftValue)  + 1
    local rightFrame = clampToHintRange(rightValue) + 1

    -- linke Zahl (Anzahl Start-Murmeln)
    numHintLeft = display.newSprite(sceneGroup, numHintSheet, { start = leftFrame, count = 1 })
    numHintLeft.x = leftRect.x
    numHintLeft.y = leftRect.y - (areaHeightTop * 0.5) - 40
    numHintLeft.xScale = 1.6
    numHintLeft.yScale = 1.6
    numHintLeft:setFrame(leftFrame)

    -- rechte Zahl (Anzahl Slots / abzuziehende Murmeln)
    numHintRight = display.newSprite(sceneGroup, numHintSheet, { start = rightFrame, count = 1 })
    numHintRight.x = rightRect.x
    numHintRight.y = rightRect.y - (areaHeightTop * 0.5) - 40
    numHintRight.xScale = 1.6
    numHintRight.yScale = 1.6
    numHintRight:setFrame(rightFrame)

    -----------------------------------------------------
    -- Murmeln links spawnen & Slots rechts anzeigen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue,  leftRect,  "left")
    spawnSlots(sceneGroup, rightValue)

    -----------------------------------------------------
    -- Swipe Hints
    -----------------------------------------------------
    local swipe_hint_90_a = display.newImageRect( 
        sceneGroup, 
        "imgs/swipe_hint.png", 
        423, 
        215 
    )
    swipe_hint_90_a.x = display.contentCenterX-200
    swipe_hint_90_a.y = display.contentCenterY
    swipe_hint_90_a.xScale = 0.5
    swipe_hint_90_a.yScale = 0.5
    swipe_hint_90_a.rotation = 90

    local swipe_hint_0_b = display.newImageRect( 
        sceneGroup, 
        "imgs/swipe_hint.png", 
        423, 
        215 
    )
    swipe_hint_0_b.x = display.contentCenterX
    swipe_hint_0_b.y = display.contentCenterY-200
    swipe_hint_0_b.xScale = 0.5
    swipe_hint_0_b.yScale = 0.5
    swipe_hint_0_b.rotation = 0

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
    -- Voller Balken unter den Rollen (nicht segmentiert)
    -- (logisch wie Divisor = 1)
    -----------------------------------------------------
    segmentBarGroup = display.newGroup()
    sceneGroup:insert(segmentBarGroup)

    local bodyW = machine.body.width
    local bodyH = machine.body.height

    local barWidth  = bodyW * 0.6
    local barHeight = bodyH * 0.08
    local barX      = machine.group.x + bodyW * 0.1
    local barY      = machine.group.y + bodyH * 0.36

    -- Hintergrund
    local barBg = display.newRoundedRect(segmentBarGroup, barX, barY, barWidth, barHeight, 10)
    barBg:setFillColor(0, 0, 0, 0.6)

    -- eigentlicher Balken
    counterBar = display.newRoundedRect(segmentBarGroup, barX, barY, barWidth - 6, barHeight - 6, 8)
    counterBar:setFillColor(0.2, 0.2, 0.35)
    counterBar.alpha = 0.7

    -----------------------------------------------------
    -- Hilfe-Button (Fragezeichen oben rechts)
    -----------------------------------------------------
    local hx, hy = layout.toCenter(layout.helpIcon)
    Button.new(sceneGroup, {
        image     = "imgs/questionmark.png",
        width     = layout.helpIcon.size,
        height    = layout.helpIcon.size,
        scale     = layout.helpIcon.scale,
        x         = hx,
        y         = hy,
        playSound = false,
        onTap     = function()
            HelpPopup.show(sceneGroup, i18n.t("help_sub"))
        end
    })

    -----------------------------------------------------
    -- Zurück-Button unten
    -----------------------------------------------------
    local backBtn = Button.new(sceneGroup, {
        image     = "imgs/btn_long_alt.png",
        width     = layout.longButtons.width,
        height    = layout.longButtons.height,
        scale     = layout.longButtons.scale,
        x         = display.contentCenterX,
        y         = display.contentHeight - 120,
        playSound = false,
        onTap     = function()
            composer.gotoScene("scenes.taschenrechner", {
                effect = "slideRight",
                time   = 300,
                params = { reset = true }
            })
            composer.removeScene("scenes.subtrahieren")
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

    for i = #slots, 1, -1 do
        local s = slots[i]
        if s.display and s.display.removeSelf then
            s.display:removeSelf()
        end
        slots[i] = nil
    end
    slots   = {}
    machine = nil

    if segmentBarGroup and segmentBarGroup.removeSelf then
        segmentBarGroup:removeSelf()
    end
    segmentBarGroup = nil
    counterBar      = nil

    -- Referenzen auf Num-Hints aufräumen
    numHintLeft  = nil
    numHintRight = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
