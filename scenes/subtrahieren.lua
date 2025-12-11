-- scenes/subtrahieren.lua
local composer       = require("composer")
local scene          = composer.newScene()

local layout         = require("layout")
local Button         = require("UI.button")
local HelpPopup      = require("UI.help_popup")
local i18n           = require("lang.i18n")
local CounterMachine = require("UI.counter_machine")
local Sound          = require("sound")

---------------------------------------------------------
-- Num-Hints (0–99) aus num_hints.png
---------------------------------------------------------
local numHintSheetOptions = {
    width     = 64,
    height    = 64,
    numFrames = 100,   -- 0..99
}
local numHintSheet = graphics.newImageSheet("imgs/num_hints.png", numHintSheetOptions)

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

local spawnMarbleColor = { 0.05, 0.10, 0.25 }       -- dunkleres Blau für Spawn-Murmeln

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
local x1 = 120
local delta = 155
local x2 = x1+delta
local x3 = x2+delta
local x4 = 650
local x5 = x4+delta
local x6 = x5+delta

local fixedSpawn = {
    left = {
        {x1, 380}, {x2, 380}, {x3, 380},
        {x1, 545}, {x2, 545}, {x3, 545},
        {x1, 715}, {x2, 715}, {x3, 715},
        {x2, 890},
    },
    right = {
        {x4, 380}, {x5, 380}, {x6, 380},
        {x4, 545}, {x5, 545}, {x6, 545},
        {x4, 715}, {x5, 715}, {x6, 715},
        {x5, 890},
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

-- Ergebnis-Erkennung
local targetResult = 0
local solved       = false

-- Hand-Tutorial (nur horizontal: links -> rechts)
local swipeHand
local tutorialActive = false
local swipeStartX, swipeEndX, swipeY

-- Maschinen-Position/Skalierung für Win-Animation
local machineStartX, machineStartY, machineStartScale
local machineSolvedAnimating = false

---------------------------------------------------------
-- Hand-Tutorial starten / stoppen
---------------------------------------------------------
local function stopSwipeTutorial()
    tutorialActive = false
    if swipeHand then
        transition.cancel(swipeHand)
        swipeHand.alpha = 0
    end
end

local function startSwipeTutorial(parentGroup)
    if tutorialActive then return end
    if not swipeStartX or not swipeEndX or not swipeY then
        return -- Sicherheitsnetz
    end

    tutorialActive = true

    if not swipeHand then
        swipeHand = display.newImageRect(parentGroup, "imgs/Hand.png", 339, 450)
        swipeHand.anchorX = 0.5
        swipeHand.anchorY = 0.5
        swipeHand.xScale  = 0.5
        swipeHand.yScale  = 0.5
        swipeHand.rotation = 0   -- Finger zeigt nach rechts
        swipeHand.alpha   = 0
    else
        parentGroup:insert(swipeHand)
    end

    local function playNext()
        if not tutorialActive or not swipeHand then return end

        swipeHand.x = swipeStartX
        swipeHand.y = swipeY
        swipeHand.alpha = 1

        transition.to(swipeHand, {
            time       = 800,
            x          = swipeEndX,
            transition = easing.outQuad,
            onComplete = function()
                if not tutorialActive or not swipeHand then return end
                transition.to(swipeHand, {
                    time = 300,
                    alpha = 0,
                    onComplete = function()
                        if tutorialActive then
                            timer.performWithDelay(500, playNext)
                        end
                    end
                })
            end
        })
    end

    playNext()
end

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
-- Eine Einer-Murmel aus einer Bündel-Murmel spawnen
---------------------------------------------------------
local function spawnOneFromBundle(bundleMarble)
    if not bundleMarble or bundleMarble.removed then
        return
    end

    bundleMarble.spawnedOnes    = bundleMarble.spawnedOnes or 0
    bundleMarble.remainingValue = bundleMarble.remainingValue or bundleMarble.totalValue or 0

    if bundleMarble.remainingValue <= 0 then
        return
    end

    if bundleMarble.spawnedOnes >= 9 then
        return
    end

    bundleMarble.spawnedOnes    = bundleMarble.spawnedOnes + 1
    bundleMarble.remainingValue = bundleMarble.remainingValue - 1

    local parent = bundleMarble.parent
    if not parent then return end

    local m = display.newImageRect(
        parent,
        "imgs/grey_marble.png",
        264 * 0.6,
        266 * 0.6
    )

    local dx = math.random(-40, 40)
    local dy = math.random(30, 80)

    m.x = bundleMarble.x + dx
    m.y = bundleMarble.y + dy

    m.spawnX  = m.x
    m.spawnY  = m.y
    m.removed = false
    m.locked  = false
    m.side    = "left"
    m.countValue = 1  -- zählt als 1

    m:setFillColor(spawnMarbleColor[1], spawnMarbleColor[2], spawnMarbleColor[3])

    -- 🔽 Z-ORDER FIX: neue Einer-Murmel unter der Maschine einsortieren
    if machine and machine.group and parent == machine.group.parent then
        -- Index der Maschine im Parent suchen
        local idx
        for i = 1, parent.numChildren do
            if parent[i] == machine.group then
                idx = i
                break
            end
        end

        if idx then
            -- m auf denselben Index setzen → Maschine rutscht eins nach vorne,
            -- bleibt also über m
            parent:insert(idx, m)
        end
    end

    m:addEventListener("touch", function(ev)
        return _G.sub_m_arbleTouch and _G.sub_m_arbleTouch(ev) or false
    end)

    marbles[#marbles + 1] = m
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

            target.spawnX = target.spawnX or target.x
            target.spawnY = target.spawnY or target.y

            ------------------------------------------------
            -- 1) Prüfen, ob Murmel in die Maschine darf
            --    (nur wenn alle Slots voll sind & weit genug unten)
            ------------------------------------------------
            local thresholdY = display.contentHeight * 0.5

            if machine and areAllSlotsFilled() and target.y >= thresholdY then
                if target.isBundle then
                    local remaining = target.remainingValue or target.totalValue or 0
                    if remaining < 0 then remaining = 0 end
                    target.countValue = remaining
                end

                stopSwipeTutorial()
                machine:swallowMarble(target, function()
                    blinkCounterBar()
                end)
                return true
            end

            ------------------------------------------------
            -- 2) Bündel-Murmel: Eine-Murmel spawnen + zurückspringen
            ------------------------------------------------
            if target.isBundle then
                spawnOneFromBundle(target)
                transition.to(target, {
                    time       = 180,
                    x          = target.spawnX,
                    y          = target.spawnY,
                    transition = easing.outQuad
                })
                return true
            end

            ----------------------------------------------------------------
            -- 3) Normale Einer-Murmel: zuerst versuchen einzurasten
            ----------------------------------------------------------------
            local snapRadius = 120
            local slot, dist2 = findNearestFreeSlot(target.x, target.y)

            if slot and dist2 and dist2 <= (snapRadius * snapRadius) then
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
            -- 4) Ansonsten: zurück zum Spawnpunkt
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

    return false
end

-- globaler Verweis für Spawn-Murmeln
_G.sub_m_arbleTouch = marbleTouch

---------------------------------------------------------
-- Double-Tap-Handler (nur über linken Num-Hint)
---------------------------------------------------------
local function makeDoubleTapHandler(radius)
    local lastTapTime = 0
    local doubleTapThreshold = 250  -- ms

    return function(event)
        local now = system.getTimer()
        local isDouble = (now - lastTapTime) <= doubleTapThreshold
        lastTapTime = now

        if not isDouble then
            return true
        end

        if not machine then
            return true
        end

        local tapX, tapY = event.x, event.y
        local r2 = radius * radius

        for _, m in ipairs(marbles) do
            if m and not m.removed and not m.locked and m.side == "left" then
                local dx = m.x - tapX
                local dy = m.y - tapY
                local dist2 = dx*dx + dy*dy
                if dist2 <= r2 then
                    if m.isBundle then
                        -- statt direkt zu zählen → Eine-Murmel spawnen
                        spawnOneFromBundle(m)
                    else
                        if not areAllSlotsFilled() then
                            -- in den nächsten freien Slot setzen
                            local freeSlot = nil
                            for _, s in ipairs(slots) do
                                if not s.occupied then
                                    freeSlot = s
                                    break
                                end
                            end

                            if freeSlot then
                                freeSlot.occupied = true
                                freeSlot.marble   = m
                                m.locked = true
                                transition.to(m, {
                                    time = 150,
                                    x    = freeSlot.x,
                                    y    = freeSlot.y
                                })
                            else
                                -- Fallback: zurück zum Spawn
                                transition.to(m, {
                                    time = 180,
                                    x    = m.spawnX,
                                    y    = m.spawnY
                                })
                            end
                        else
                            -- alle Slots sind voll → Murmel in die Maschine
                            stopSwipeTutorial()
                            machine:swallowMarble(m, function()
                                blinkCounterBar()
                            end)
                        end
                    end
                end
            end
        end

        return true
    end
end

---------------------------------------------------------
-- Murmeln erzeugen (links, mit Bündel-Murmel + Farben)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect, side)
    local list = fixedSpawn[side] or {}
    local maxFixed = #list

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
        m.side    = side
        m.countValue = countValue or 1
        m.isBundle   = isBundle or false

        if color then
            m:setFillColor(color[1], color[2], color[3])
        end

        if m.isBundle then
            m.totalValue     = m.countValue or 0
            m.remainingValue = m.totalValue
            m.spawnedOnes    = 0
        end

        m:addEventListener("touch", marbleTouch)

        if m.isBundle then
            m:addEventListener("tap", function()
                spawnOneFromBundle(m)
                return true
            end)
        end

        marbles[#marbles + 1] = m
        return m
    end

    if side == "left" then
        local ones      = num % 10
        local tensColor = getTensColorForValue(num)

        -- Einer-Murmeln (immer Wert 1): Positionen 1..9
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
-- Wenn Aufgabe gelöst: Maschine in die Mitte zoomen
---------------------------------------------------------
local function onSolved()
    stopSwipeTutorial()
    Sound.playCorrect()     -- ✅ Correct-Sound, einmal beim Lösen
    if machineSolvedAnimating or not machine or not machine.group then
        return
    end
    machineSolvedAnimating = true

    local targetX = display.contentCenterX
    local targetY = display.contentCenterY + 40
    local targetScale = machineStartScale * 1.2

    local dx = targetX - machineStartX
    local dy = targetY - machineStartY

    -- Maschine bewegen & skalieren
    transition.to(machine.group, {
        time       = 700,
        x          = targetX,
        y          = targetY,
        xScale     = targetScale,
        yScale     = targetScale,
        transition = easing.outQuad
    })

    -- Balkengruppe mit Magic Numbers justieren & skalieren
    if segmentBarGroup then
        -- NOTE: Magic Numbers zum Ausrichten des Balkens relativ zur Maschine.
        -- -targetX + 450 und -targetY + 342 sind empirisch bestimmte Offsets,
        -- damit der Balken beim Zoom mit der Maschine deckungsgleich bleibt.
        transition.to(segmentBarGroup, {
            time       = 700,
            x          = -targetX + 450,
            y          = -targetY + 342,
            xScale     = targetScale,
            yScale     = targetScale,
            transition = easing.outQuad
        })
    end
end

---------------------------------------------------------
-- Ergebnis-Polling
---------------------------------------------------------
local function checkSolved()
    if solved or not machine then
        return
    end

    local current = machine.value or 0
    if current == targetResult then
        solved = true
        onSolved()
    end
end

local function enterFrameListener()
    checkSolved()
end

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    marbles = {}
    slots   = {}
    solved  = false
    machineSolvedAnimating = false

    local params = event.params or {}
    local leftValue  = params.left  or 9
    local rightValue = params.right or 3
    targetResult     = leftValue - rightValue

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

    display.newText({
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
    -- Num-Hints über den Bereichen
    -----------------------------------------------------
    local function clampToHintRange(v)
        if v < 0 then return 0 end
        if v > 99 then return 99 end
        return v
    end

    local leftFrame  = clampToHintRange(leftValue)  + 1
    local rightFrame = clampToHintRange(rightValue) + 1

    numHintLeft = display.newSprite(sceneGroup, numHintSheet, { start = leftFrame, count = 1 })
    numHintLeft.x = leftRect.x
    numHintLeft.y = leftRect.y - (areaHeightTop * 0.5) - 40
    numHintLeft.xScale = 1.6
    numHintLeft.yScale = 1.6
    numHintLeft:setFrame(leftFrame)

    numHintRight = display.newSprite(sceneGroup, numHintSheet, { start = rightFrame, count = 1 })
    numHintRight.x = rightRect.x
    numHintRight.y = rightRect.y - (areaHeightTop * 0.5) - 40
    numHintRight.xScale = 1.6
    numHintRight.yScale = 1.6
    numHintRight:setFrame(rightFrame)

    -----------------------------------------------------
    -- Double-Tap: NUR auf dem linken Num-Hint
    -----------------------------------------------------
    local hintRadius = 1000
    numHintLeft:addEventListener("tap", makeDoubleTapHandler(hintRadius))

    -----------------------------------------------------
    -- Murmeln links spawnen & Slots rechts anzeigen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue,  leftRect,  "left")
    spawnSlots(sceneGroup, rightValue)

    -----------------------------------------------------
    -- Swipe Hints (optisch, aber Hand läuft separat)
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
    -- Koordinaten für die Hand-Animation (nur horizontal)
    -----------------------------------------------------
    swipeStartX = display.contentCenterX - 200
    swipeEndX   = display.contentCenterX + 200
    swipeY      = display.contentCenterY - 200

    -----------------------------------------------------
    -- Zählmaschine unten
    -----------------------------------------------------
    machine = CounterMachine.new(sceneGroup, {
        x     = display.contentCenterX,
        y     = display.contentHeight * 0.72,
        scale = 0.8
    })
    machine:setValue(0)

    machineStartX     = machine.group.x
    machineStartY     = machine.group.y
    machineStartScale = machine.group.xScale or 1

    -----------------------------------------------------
    -- Voller Balken unter den Rollen (nicht segmentiert)
    -----------------------------------------------------
    segmentBarGroup = display.newGroup()
    sceneGroup:insert(segmentBarGroup)

    local bodyW = machine.body.width
    local bodyH = machine.body.height

    local barWidth  = bodyW * 0.6
    local barHeight = bodyH * 0.08
    local barX      = machine.group.x + bodyW * 0.1
    local barY      = machine.group.y + bodyH * 0.36

    local barBg = display.newRoundedRect(segmentBarGroup, barX, barY, barWidth, barHeight, 10)
    barBg:setFillColor(0, 0, 0, 0.6)

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

    -----------------------------------------------------
    -- Ergebnis-Listener aktivieren
    -----------------------------------------------------
    Runtime:addEventListener("enterFrame", enterFrameListener)

    -----------------------------------------------------
    -- Hand-Tutorial starten
    -----------------------------------------------------
    startSwipeTutorial(sceneGroup)
end

function scene:show(event)
end

function scene:hide(event)
end

function scene:destroy(event)
    Runtime:removeEventListener("enterFrame", enterFrameListener)

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

    stopSwipeTutorial()
    if swipeHand and swipeHand.removeSelf then
        swipeHand:removeSelf()
    end
    swipeHand = nil

    numHintLeft  = nil
    numHintRight = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
