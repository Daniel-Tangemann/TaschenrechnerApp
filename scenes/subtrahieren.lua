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
-- Farbige Murmeln (Farben von Num_Hints, auf 0–1 normalisiert)
---------------------------------------------------------
local marbleColors = {
    ones      = {  9/255,   32.9/255,  91/255 },   -- Einer
    tens      = {  9/255,   87.5/255,  91/255 },   -- Zehner (10–19)
    twenties  = {  9/255,   91/255,    36.5/255 }, -- Zwanziger (20–29)
    thirties  = { 45.1/255, 91/255,    9/255 },    -- Dreißiger (30–39)
    forties   = { 70.6/255, 91/255,    9/255 },    -- Vierziger (40–49)
    fifties   = { 91/255,   91/255,    9/255 },    -- Fünfziger (50–59)
    sixties   = { 89/255,   64.3/255,  9/255 },    -- Sechziger (60–69)
    seventies = { 88.6/255, 38.8/255,  8.6/255 },  -- Siebziger (70–79)
    eighties  = { 91/255,    9/255,    9/255 },    -- Achtziger (80–89)
    nineties  = { 65.9/255, 33.3/255, 76.5/255 },  -- Neunziger (90–99)
}

local darkerOnesColor = {
    marbleColors.ones[1] * 0.6,
    marbleColors.ones[2] * 0.6,
    marbleColors.ones[3] * 0.6,
}

local function getTensColorForValue(v)
    if v < 10 then return nil end
    local bucket = math.floor(v / 10)
    if bucket == 1 then
        return marbleColors.tens
    elseif bucket == 2 then
        return marbleColors.twenties
    elseif bucket == 3 then
        return marbleColors.thirties
    elseif bucket == 4 then
        return marbleColors.forties
    elseif bucket == 5 then
        return marbleColors.fifties
    elseif bucket == 6 then
        return marbleColors.sixties
    elseif bucket == 7 then
        return marbleColors.seventies
    elseif bucket == 8 then
        return marbleColors.eighties
    elseif bucket == 9 then
        return marbleColors.nineties
    else
        return marbleColors.nineties
    end
end

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
-- Vorwärtsdeklaration für Bundle-Tap (wird unten definiert)
---------------------------------------------------------
local onBundleTap

---------------------------------------------------------
-- Balken kurz aufblinken lassen, wenn gezählt wurde
---------------------------------------------------------
local function blinkCounterBar()
    if not counterBar then return end

    transition.cancel(counterBar)

    counterBar:setFillColor(1, 1, 0.2)
    counterBar.alpha = 1

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
            local snapRadius = 120
            local slot, dist2 = findNearestFreeSlot(target.x, target.y)

            if slot and dist2 and dist2 <= (snapRadius * snapRadius) then
                -- Höherwertige Murmel (Bundle) soll NICHT einrasten:
                -- Stattdessen Einermurmeln spawnen und zurückspringen.
                if target.isBundle then
                    -- Einmalig für diesen Drag die echte Tap-Event-Reaktion unterdrücken
                    target.skipNextTap = true
                    -- Manuell die Bundletap-Logik auslösen (spawnt Einermurmeln)
                    onBundleTap({ target = target })

                    transition.to(target, {
                        time       = 200,
                        x          = target.spawnX,
                        y          = target.spawnY,
                        transition = easing.outQuad
                    })
                    return true
                end

                -- Normale Murmel: in Slot einrasten
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
                machine:swallowMarble(target, function()
                    blinkCounterBar()
                end)
                return true
            else
                ----------------------------------------------------------------
                -- 3. Ansonsten: zurück zum Spawnpoint
                ----------------------------------------------------------------
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
-- Bundle-Tap: höherwertige Murmel in Einermurmeln „wechseln“
-- - Bei Tap werden bis zu 9 Einermurmeln gespawnt (insgesamt)
-- - Jede Einermurmel zählt 1 Punkt, dunkleres Blau
-- - countValue der Bundle-Murmel wird entsprechend reduziert
---------------------------------------------------------
onBundleTap = function(event)
    local bundle = event.target
    if not bundle or bundle.removed then
        return true
    end

    -- Wenn der Tap von einem Drag-into-Slot kommt, wird der nächste echte Tap ignoriert.
    if bundle.skipNextTap then
        bundle.skipNextTap = nil
        return true
    end

    local parent = bundle.parent
    if not parent then return true end

    local maxSpawn     = 9
    local spawnedSoFar = bundle.spawnedOnes or 0
    local remaining    = math.floor(bundle.countValue or 0)

    -- Nichts mehr zu holen oder Limit erreicht
    if spawnedSoFar >= maxSpawn or remaining <= 0 then
        return true
    end

    -- Wie viele neue Einermurmeln dürfen wir diesmal erzeugen?
    local canSpawn = math.min(maxSpawn - spawnedSoFar, remaining)

    for i = 1, canSpawn do
        local m = display.newImageRect(
            parent,
            "imgs/grey_marble.png",
            264 * 0.6,
            266 * 0.6
        )

        -- In der Nähe der Bundle-Murmel spawnen
        m.x = bundle.x + math.random(-40, 40)
        m.y = bundle.y + math.random(-40, 40)

        m.spawnX  = m.x
        m.spawnY  = m.y
        m.removed = false
        m.locked  = false

        -- Jede Spawn-Murmel zählt als 1
        m.countValue = 1

        -- etwas dunkleres Blau
        m:setFillColor(darkerOnesColor[1], darkerOnesColor[2], darkerOnesColor[3])

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m

        -- Die Bundle-Murmel verliert entsprechend Wert
        bundle.countValue = (bundle.countValue or 0) - 1
        spawnedSoFar = spawnedSoFar + 1
    end

    bundle.spawnedOnes = spawnedSoFar
    return true
end

---------------------------------------------------------
-- Murmeln erzeugen (links, mit Farbkodierung + countValue)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect, side)
    local list = fixedSpawn[side] or {}
    local maxFixed = #list

    -- Helper zum Erzeugen einer farbigen Murmel mit Wert
    local function createColoredMarble(x, y, color, countValue, isBundle)
        local m = display.newImageRect(
            sceneGroup,
            "imgs/grey_marble.png",
            264 * 0.6,
            266 * 0.6
        )

        m.x, m.y = x, y
        m.spawnX = x
        m.spawnY = y
        m.removed = false
        m.locked  = false

        m.countValue = countValue or 1  -- Wert, den die Murmel im Zähler repräsentiert

        if color then
            m:setFillColor(color[1], color[2], color[3])
        end

        if isBundle then
            m.isBundle    = true
            m.spawnedOnes = 0
            m:addEventListener("tap", onBundleTap)
        end

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
        return m
    end

    if side == "left" then
        -- Zahl in Einer + eine „Bündel“-Murmel auf Position 10
        local ones      = num % 10
        local tensColor = getTensColorForValue(num)

        -- Einer-Murmeln: Positionen 1..9 (falls vorhanden)
        local numOnes = math.min(ones, math.max(0, maxFixed - 1))
        for i = 1, numOnes do
            local pos = list[i]
            createColoredMarble(pos[1], pos[2], marbleColors.ones, 1, false)
        end

        -- Bündel-Murmel auf Position 10, falls num >= 10
        if tensColor and maxFixed >= 10 then
            local pos       = list[10]
            local tensValue = num - ones  -- z.B. 24 → 20
            if tensValue < 1 then
                tensValue = 1
            end
            createColoredMarble(pos[1], pos[2], tensColor, tensValue, true)
        end
    else
        -- Falls wir später doch rechts Murmeln brauchen würden:
        for i = 1, num do
            local x, y
            if i <= maxFixed then
                local pos = list[i]
                x, y = pos[1], pos[2]
            else
                local halfW = containerRect.width * 0.5 - 40
                local halfH = containerRect.height * 0.5 - 40
                x = containerRect.x + math.random(-halfW, halfW)
                y = containerRect.y + math.random(-halfH, halfH)
            end
            createColoredMarble(x, y, marbleColors.ones, 1, false)
        end
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
    local leftValue  = params.left  or 24
    local rightValue = params.right or 8
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
        788 *0.7,
        206 *0.7
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

    -- linke Zahl (Minuend)
    numHintLeft = display.newSprite(sceneGroup, numHintSheet, { start = leftFrame, count = 1 })
    numHintLeft.x = leftRect.x
    numHintLeft.y = leftRect.y - (areaHeightTop * 0.5) - 40
    numHintLeft.xScale = 1.6
    numHintLeft.yScale = 1.6
    numHintLeft:setFrame(leftFrame)

    -- rechte Zahl (Subtrahend)
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
        image  = "imgs/questionmark.png",
        width  = layout.helpIcon.size,
        height = layout.helpIcon.size,
        scale  = layout.helpIcon.scale,
        x      = hx,
        y      = hy,
        playSound = false,
        onTap  = function()
            HelpPopup.show(sceneGroup, i18n.t("help_sub"))
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
        playSound = false,
        onTap  = function()
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
