-- scenes/dividieren.lua
local composer       = require("composer")
local scene          = composer.newScene()

local layout         = require("layout")
local Button         = require("UI.button")
local HelpPopup      = require("UI.help_popup")
local i18n           = require("lang.i18n")
local CounterMachine = require("UI.counter_machine")
local Sound          = require("sound")

---------------------------------------------------------
-- Animationsparameter
-- Wie lange die Animation pro "Einheit" dauern soll (ms),
-- wenn eine höherwertige Murmel gezählt wird.
---------------------------------------------------------
local UNIT_COUNT_DELAY = 120  -- nach Bedarf anpassbar

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
-- Feste Spawn-Positionen für Dividend (linkes Feld)
---------------------------------------------------------
local fixedSpawn = {
    left = {
        {138, 380}, {280, 380}, {422, 380},
        {138, 545}, {280, 545}, {422, 545},
        {138, 715}, {280, 715}, {422, 715},
        {280, 890},
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
local maxRemainderUnits = 0  -- wie viele "Einheiten" dürfen im Rest landen (Dividend % Divisor)
local remainderUnits    = 0  -- tatsächliche Einheiten im Rest
local remainderCount    = 0  -- Anzahl der Rest-Murmeln (für Slot-Auswahl)
local remainderText          -- Rest-Anzeige

-- Segmentbalken
local segmentBarGroup
local segmentRects = {}

-- Schlucklinie (wird in scene:create dynamisch gesetzt)
local SWALLOW_LINE_Y = 2000

-- Feste Slots für Rest-Murmeln (max. 9)
local restSlots = {}

-- Zähl-Queue für animiertes Hochzählen
local pendingUnits    = 0
local isCountingUnits = false

-- Double-Tap-Status
local doubleTapUsed = false

-- Sieg / Zoom-Animation
local quotientTarget   = 0
local remainderTarget  = 0
local solved           = false
local machineStartX    = 0
local machineStartY    = 0
local machineStartScale = 1
local machineSolvedAnimating = false
local solvedListenerAdded    = false

-- Hand-Tutorial: vertikal (wie Addieren) + horizontal (wie Subtrahieren)
local swipeHand
local tutorialActive      = false
local swipeVertX          -- x für vertikale Geste
local swipeVertStartY     -- y-Start (oben)
local swipeVertEndY       -- y-Ziel (unten, in Richtung Maschine)
local swipeHorzStartX     -- horizontaler Start (links)
local swipeHorzEndX       -- horizontaler Endpunkt (rechts)
local swipeHorzY          -- konstantes y für horizontale Geste

-- Vorwärts-Deklarationen
local marbleTouch
local onSolved
local enterFrameListener

---------------------------------------------------------
-- Hand-Tutorial: stoppen
---------------------------------------------------------
local function stopSwipeTutorial()
    tutorialActive = false
    if swipeHand then
        transition.cancel(swipeHand)
        swipeHand.alpha = 0
    end
end

---------------------------------------------------------
-- Hand-Tutorial: starten (linke Geste wie Addieren,
-- rechte Geste wie Subtrahieren, abwechselnd)
---------------------------------------------------------
local function startSwipeTutorial(parentGroup)
    if tutorialActive then return end

    local modes = {}

    if swipeVertX and swipeVertStartY and swipeVertEndY then
        modes[#modes + 1] = "vertical"
    end
    if swipeHorzStartX and swipeHorzEndX and swipeHorzY then
        modes[#modes + 1] = "horizontal"
    end

    if #modes == 0 then
        return
    end

    tutorialActive = true

    if not swipeHand then
        swipeHand = display.newImageRect(parentGroup, "imgs/Hand.png", 339, 450)
        swipeHand.anchorX = 0.5
        swipeHand.anchorY = 0.5
        swipeHand.xScale  = 0.5
        swipeHand.yScale  = 0.5
        swipeHand.alpha   = 0
    else
        parentGroup:insert(swipeHand)
    end

    local idx = 1

    local function playNext()
        if not tutorialActive or not swipeHand then return end

        local mode = modes[idx]
        idx = (idx % #modes) + 1

        if mode == "vertical" then
            swipeHand.rotation = 180  -- Finger nach unten
            swipeHand.x = swipeVertX
            swipeHand.y = swipeVertStartY
            swipeHand.alpha = 1

            transition.to(swipeHand, {
                time       = 800,
                y          = swipeVertEndY,
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
        else
            swipeHand.rotation = 0    -- Finger nach rechts
            swipeHand.x = swipeHorzStartX
            swipeHand.y = swipeHorzY
            swipeHand.alpha = 1

            transition.to(swipeHand, {
                time       = 800,
                x          = swipeHorzEndX,
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
    end

    playNext()
end

---------------------------------------------------------
-- Hilfsfunktion: Murmel programmatisch ins Restfeld verschieben
---------------------------------------------------------
local function moveMarbleToRest(m, unitsOverride)
    if m.removed or not remainderRect then return false end

    local units = unitsOverride or tonumber(m.countValue) or 1
    if units < 1 then units = 1 end

    -- Sicherheitscheck: Rest darf mathematischen Rest nicht überschreiten
    if remainderUnits + units > maxRemainderUnits then
        return false
    end

    remainderUnits = remainderUnits + units
    remainderCount = remainderCount + 1

    local slot = restSlots[remainderCount] or { x = remainderRect.x, y = remainderRect.y }

    m.inRemainder = true

    transition.to(m, {
        time = 150,
        x    = slot.x,
        y    = slot.y,
        onComplete = function()
            m.inRemainder = true
            m:removeEventListener("touch", marbleTouch)
        end
    })

    return true
end

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
-- Ein "Einheits-Schritt" im Divisionsprozess
-- (füllt ein Segment, ggf. komplette Gruppe → Counter + Blink)
---------------------------------------------------------
local function processOneUnit()
    if pendingUnits <= 0 then
        isCountingUnits = false
        return
    end

    pendingUnits = pendingUnits - 1

    groupCount = groupCount + 1

    -- 🔊 Key-Beep NUR für „Zwischen“-Segmente,
    --    also wenn die Gruppe noch NICHT voll ist:
    if groupCount < divisor then
        Sound.playDing()
    end

    if groupCount == divisor then
        -- komplette Gruppe voll → 1 zum Quotienten und letzter Balken blinkt
        blinkLastSegment(divisor)
        groupCount = 0
        machine:increment()
    end

    updateSegmentBar()

    if pendingUnits > 0 then
        timer.performWithDelay(UNIT_COUNT_DELAY, processOneUnit)
    else
        isCountingUnits = false
    end
end

---------------------------------------------------------
-- Wenn eine Murmel (mit Wert amount) gezählt wurde
-- → Einheiten werden nacheinander animiert abgearbeitet
---------------------------------------------------------
local function onMarbleCounted(amount)
    amount = amount or 1
    if amount < 1 then amount = 1 end

    pendingUnits = pendingUnits + amount

    if not isCountingUnits then
        isCountingUnits = true
        processOneUnit()
    end
end

---------------------------------------------------------
-- Murmel in die Maschine einsaugen
---------------------------------------------------------
local function swallowIntoMachine(m)
    if m.removed then return end
    m.removed = true

    stopSwipeTutorial()  -- Spieler hat verstanden

    local units = tonumber(m.countValue) or 1
    if units < 1 then units = 1 end

    transition.to(m, {
        time   = 150,
        x      = machine.group.x + machine.funnelX,
        y      = machine.group.y + machine.funnelY,
        xScale = 0.3,
        yScale = 0.3,
        alpha  = 0,
        onComplete = function()
            if m.removeSelf then m:removeSelf() end
            -- Einheiten werden über die animierte Queue abgearbeitet
            onMarbleCounted(units)
        end
    })
end

---------------------------------------------------------
-- Sieg-Logik: prüfen, ob Aufgabe gelöst ist
---------------------------------------------------------
local function checkSolved()
    if solved or not machine then
        return
    end

    local currentQ = machine.value or 0

    -- Quotient und Rest müssen stimmen
    if currentQ ~= quotientTarget then
        return
    end
    if remainderUnits ~= remainderTarget then
        if groupCount ~= remainderTarget then
            return
        end
    end

    -- Keine "freien" Murmeln mehr: alles ist entweder entfernt oder im Rest
    for _, m in ipairs(marbles) do
        if m and (not m.removed) and (not m.inRemainder) then
            return
        end
    end

    -- Rest-Text setzen
    if remainderText then
        remainderText.text = i18n.t("div_re_text") .. tostring(remainderTarget) -- here
    end

    solved = true
    onSolved()
end

function enterFrameListener()
    checkSolved()
end

---------------------------------------------------------
-- Wenn Aufgabe gelöst: Maschine in die Mitte zoomen
-- + Segmentbalken mit Magic Numbers mitbewegen
---------------------------------------------------------
function onSolved()
    stopSwipeTutorial()
    Sound.playCorrect()     -- ✅ Correct-Sound, einmal beim Lösen
    if machineSolvedAnimating or not machine or not machine.group then
        return
    end
    machineSolvedAnimating = true

    local targetX     = display.contentCenterX
    local targetY     = display.contentCenterY + 40
    local baseScale   = machineStartScale or machine.group.xScale or 1
    local targetScale = baseScale * 1.2

    -- Maschine bewegen & skalieren
    transition.to(machine.group, {
        time       = 700,
        x          = targetX,
        y          = targetY,
        xScale     = targetScale,
        yScale     = targetScale,
        transition = easing.outQuad
    })

    -- Balkengruppe mit Magic Numbers nachziehen (hacky, aber hübsch)
    if segmentBarGroup then
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
-- Touch-Listener für Murmeln
---------------------------------------------------------
function marbleTouch(event)
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
            local units = tonumber(m.countValue) or 1
            if units < 1 then units = 1 end

            -------------------------------------------------
            -- 1) Schlucklinie: Maschine frisst Murmel
            -------------------------------------------------
            if y >= SWALLOW_LINE_Y then
                swallowIntoMachine(m)
                return true
            end

            -------------------------------------------------
            -- 2) Restfeld: maxRemainderUnits begrenzt, feste Slots
            -------------------------------------------------
            if remainderRect and pointInRect(x, y, remainderRect) then
                if remainderUnits + units <= maxRemainderUnits then
                    remainderUnits = remainderUnits + units
                    remainderCount = remainderCount + 1

                    local slot = restSlots[remainderCount]
                    if not slot then
                        slot = { x = remainderRect.x, y = remainderRect.y }
                    end

                    m.inRemainder = true
                    stopSwipeTutorial()  -- auch Rest-Aktion stoppt Tutorial

                    transition.to(m, {
                        time = 100,
                        x    = slot.x,
                        y    = slot.y,
                        onComplete = function()
                            m.inRemainder = true
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
-- Murmeln im linken Feld erzeugen (mit Bündel-Murmel)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, rect)
    local list = fixedSpawn.left
    local maxFixed = #list

    -- Helper: farbige Murmel mit Wert
    local function createColoredMarble(x, y, color, countValue)
        local m = display.newImageRect(sceneGroup, "imgs/grey_marble.png", 264 * 0.6, 266 * 0.6)

        m.x, m.y = x, y
        m.spawnX = x
        m.spawnY = y
        m.removed = false
        m.countValue = countValue or 1
        m.inRemainder = false

        if color then
            m:setFillColor(color[1], color[2], color[3])
        end

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
        return m
    end

    -- Zahl in Einer + eine „Bündel“-Murmel auf Position 10 zerlegen
    local ones      = num % 10
    local tensColor = getTensColorForValue(num)

    -- Einer-Murmeln (immer Wert 1): Positionen 1..9
    local numOnes = math.min(ones, math.max(0, maxFixed - 1))
    for i = 1, numOnes do
        local pos = list[i]
        createColoredMarble(pos[1], pos[2], marbleColors.ones, 1)
    end

    -- Bündel-Murmel auf Position 10, falls num >= 10
    if tensColor and maxFixed >= 10 then
        local pos       = list[10]
        local tensValue = num - ones  -- z.B. 24 → 20
        if tensValue < 1 then
            tensValue = 1
        end
        createColoredMarble(pos[1], pos[2], tensColor, tensValue)
    end
end

---------------------------------------------------------
-- Double-Tap auf Num-Hint: automatisch teilen
---------------------------------------------------------
local function onNumHintDoubleTap(event)
    -- Wir reagieren nur auf echtes Doppeltippen
    if event.numTaps ~= 2 then
        return true
    end

    -- Nur einmal pro Szene ausführen
    if doubleTapUsed then
        return true
    end
    doubleTapUsed = true

    stopSwipeTutorial()

    -- Wie viele Einheiten sollen insgesamt im Rest liegen?
    local targetRemainder = maxRemainderUnits
    if targetRemainder < 0 then targetRemainder = 0 end

    -- Wieviel Rest ist schon manuell gelegt?
    local currentRemainder = remainderUnits or 0
    local neededRemainder  = targetRemainder - currentRemainder

    if neededRemainder < 0 then
        neededRemainder = 0
    end

    -- Kandidaten sammeln: Einer-Murmeln, die noch nicht entfernt
    -- und noch nicht im Rest liegen, sowie alle übrigen.
    local ones = {}
    local others = {}

    for _, m in ipairs(marbles) do
        if m and (not m.removed) and (not m.inRemainder) then
            local units = tonumber(m.countValue) or 1
            if units == 1 then
                table.insert(ones, m)
            else
                table.insert(others, m)
            end
        end
    end

    -- Falls wir nicht genug Einer-Murmeln für den Rest haben,
    -- brechen wir lieber ab, statt Unsinn zu animieren.
    if neededRemainder > #ones then
        doubleTapUsed = false
        return true
    end

    -------------------------------------------------
    -- 1) Genau so viele Einer-Murmeln in den Rest legen,
    --    wie der mathematische Rest noch braucht.
    -------------------------------------------------
    local assigned = 0
    for i = 1, #ones do
        if assigned >= neededRemainder then
            break
        end
        local m = ones[i]
        local ok = moveMarbleToRest(m, 1)
        if ok then
            assigned = assigned + 1
        end
    end

    -------------------------------------------------
    -- 2) Alle übrigen Murmeln (einschließlich nicht
    --    verwendeter Einer) durch die Maschine laufen lassen.
    -------------------------------------------------
    for _, m in ipairs(marbles) do
        if m and (not m.removed) and (not m.inRemainder) then
            swallowIntoMachine(m)
        end
    end

    return true
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

    marbles           = {}
    segmentRects      = {}
    remainderUnits    = 0
    remainderCount    = 0
    groupCount        = 0
    pendingUnits      = 0
    isCountingUnits   = false
    solved            = false
    machineSolvedAnimating = false
    solvedListenerAdded    = false
    doubleTapUsed     = false

    local params     = event.params or {}
    local leftValue  = params.left  or 10
    local rightValue = params.right or 3
    divisor          = rightValue
    if divisor < 1 then divisor = 1 end

    maxRemainderUnits = leftValue % divisor  -- mathematisch korrekter Rest
    quotientTarget    = math.floor(leftValue / divisor)
    remainderTarget   = maxRemainderUnits

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
    numHintLeft.y = leftRect.y - (areaH * 0.5) - 40
    numHintLeft.xScale = 1.6
    numHintLeft.yScale = 1.6
    numHintLeft:setFrame(leftFrame)

    numHintRight = display.newSprite(sceneGroup, numHintSheet, { start = rightFrame, count = 1 })
    numHintRight.x = remainderRect.x
    numHintRight.y = remainderRect.y - (areaH * 0.5) - 40
    numHintRight.xScale = 1.6
    numHintRight.yScale = 1.6
    numHintRight:setFrame(rightFrame)

    -- Double-Tap-Listener hinzufügen (auf beide Hints)
    numHintLeft:addEventListener("tap", onNumHintDoubleTap)
    numHintRight:addEventListener("tap", onNumHintDoubleTap)

    -----------------------------------------------------
    -- Rest-Slots vorberechnen
    -----------------------------------------------------
    computeRestSlots()

    -----------------------------------------------------
    -- Rest-Text 
    -----------------------------------------------------
    remainderText = display.newText({
        parent   = sceneGroup,
        text     = i18n.t("div_re_text"), -- here
        x        = 540,
        y        = 1550,
        font     = native.systemFontBold,
        fontSize = 120,
        align    = "center",
        width    = areaW * 0.8,
    })
    -----------------------------------------------------
    -- Murmeln spawnen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue, leftRect)

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

    -- Koordinaten für Hand-Animation:
    -- Links (wie Addieren): vertikal nach unten
    swipeVertX      = swipe_hint_90_a.x
    swipeVertStartY = swipe_hint_90_a.y - 40
    -- End-Y gibt es später, wenn Maschine erstellt ist

    -- Rechts (wie Subtrahieren): horizontal von links nach rechts
    swipeHorzStartX = display.contentCenterX - 200
    swipeHorzEndX   = display.contentCenterX + 200
    swipeHorzY      = display.contentCenterY - 200

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

    -- End-Y für vertikale Hand (wie bei Addieren)
    swipeVertEndY = machine.group.y - bodyH * 0.2

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
        playSound = false,
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
        playSound = false,
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

    -----------------------------------------------------
    -- Ergebnis-Listener + Hand-Tutorial aktivieren
    -----------------------------------------------------
    Runtime:addEventListener("enterFrame", enterFrameListener)
    solvedListenerAdded = true

    startSwipeTutorial(sceneGroup)
end

---------------------------------------------------------
function scene:destroy(event)
    if solvedListenerAdded then
        Runtime:removeEventListener("enterFrame", enterFrameListener)
        solvedListenerAdded = false
    end

    stopSwipeTutorial()

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

    machine = nil
    remainderRect = nil

    if swipeHand and swipeHand.removeSelf then
        swipeHand:removeSelf()
    end
    swipeHand = nil

    numHintLeft  = nil
    numHintRight = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("destroy", scene)

return scene
