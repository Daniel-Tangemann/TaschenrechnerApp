-- scenes/addieren.lua
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
    width              = 64,
    height             = 64,
    numFrames          = 100,   -- 0..99
    sheetContentWidth  = 640,
    sheetContentHeight = 640,
}
local numHintSheet = graphics.newImageSheet("imgs/num_hints.png", numHintSheetOptions)

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
-- Farbige Murmeln (wie bei den Num_Hints, normalisiert)
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
-- Lokale Variablen
---------------------------------------------------------
local marbles = {}
local machine          -- CounterMachine-Instanz
local segmentBarGroup  -- Gruppe für den Balken
local counterBar       -- einzelner, voller Balken

-- Ergebnis-Erkennung
local targetResult = 0
local solved       = false
local rootGroup
local resultPopupGroup
local solvedListenerAdded = false

-- Hand-Tutorial
local swipeHand
local tutorialActive = false
local swipeStartLeftX, swipeStartRightX, swipeStartY
local swipeEndY

-- Maschinen-Position/Skalierung für Win-Animation
local machineStartX, machineStartY, machineStartScale
local machineSolvedAnimating = false

---------------------------------------------------------
-- Hilfsfunktionen: Ergebnis-Popup
---------------------------------------------------------
local function showResultPopup()
    if resultPopupGroup or not rootGroup then
        return
    end

    resultPopupGroup = display.newGroup()
    rootGroup:insert(resultPopupGroup)

    local overlay = display.newRoundedRect(
        resultPopupGroup,
        display.contentCenterX,
        display.contentCenterY,
        display.contentWidth * 0.8,
        display.contentHeight * 0.4,
        32
    )
    overlay:setFillColor(0, 0, 0, 0.8)

    display.newText({
        parent   = resultPopupGroup,
        text     = tostring(targetResult),
        x        = display.contentCenterX,
        y        = display.contentCenterY,
        font     = native.systemFontBold,
        fontSize = 100,
        align    = "center"
    })

    -- Tap zum Schließen (bis deine finalen Assets da sind)
    overlay:addEventListener("tap", function()
        if resultPopupGroup and resultPopupGroup.removeSelf then
            resultPopupGroup:removeSelf()
        end
        resultPopupGroup = nil
        return true
    end)
end

---------------------------------------------------------
-- Hand-Tutorial: starten / stoppen
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
    if not swipeStartLeftX or not swipeStartRightX or not swipeStartY or not swipeEndY then
        return -- Sicherheitsnetz, falls Koordinaten noch nicht gesetzt
    end

    tutorialActive = true

    if not swipeHand then
        swipeHand = display.newImageRect(parentGroup, "imgs/Hand.png", 339, 450)
        swipeHand.anchorX = 0.5
        swipeHand.anchorY = 0.5
        swipeHand.xScale  = 0.5
        swipeHand.yScale  = 0.5
        swipeHand.rotation = 180   -- Finger zeigt nach unten
        swipeHand.alpha   = 0
    else
        parentGroup:insert(swipeHand)
    end

    local paths = {
        { x = swipeStartLeftX },
        { x = swipeStartRightX },
    }
    local idx = 1

    local function playNext()
        if not tutorialActive or not swipeHand or not machine then return end

        local p = paths[idx]
        idx = (idx % #paths) + 1

        swipeHand.x = p.x
        swipeHand.y = swipeStartY
        swipeHand.alpha = 1

        transition.to(swipeHand, {
            time = 800,
            y = swipeEndY,
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
-- Murmel → Maschine schicken
---------------------------------------------------------
local function swallowMarbleIntoMachine(marble)
    if not machine or not marble or marble.removed then
        return
    end
    stopSwipeTutorial()  -- Tutorial ausblenden, sobald der Spieler mitspielt
    machine:swallowMarble(marble, blinkCounterBar)
end

---------------------------------------------------------
-- Wenn Aufgabe gelöst: Maschine in die Mitte zoomen
---------------------------------------------------------
local function onSolved()
    stopSwipeTutorial()

    if machineSolvedAnimating or not machine or not machine.group then
        return
    end
    machineSolvedAnimating = true

    -------------------------------------------------------
    -- Zielpositionen der Maschine
    -------------------------------------------------------
    local targetX = display.contentCenterX
    local targetY = display.contentCenterY + 40
    local targetScale = machineStartScale * 1.2

    -------------------------------------------------------
    -- Verschiebung berechnen
    -------------------------------------------------------
    local dx = targetX - machineStartX
    local dy = targetY - machineStartY

    -------------------------------------------------------
    -- Maschine bewegen & skalieren
    -------------------------------------------------------
    transition.to(machine.group, {
        time       = 700,
        x          = targetX,
        y          = targetY,
        xScale     = targetScale,
        yScale     = targetScale,
        transition = easing.outQuad
    })

    -------------------------------------------------------
    -- Balkengruppe exakt gleich bewegen & skalieren
    -------------------------------------------------------
    if segmentBarGroup then
        transition.to(segmentBarGroup, {
            time       = 700,
            x          = -targetX +450, --segmentBarGroup.x0 + dx,
            y          = -targetY +342, --segmentBarGroup.y0 + dy,
            xScale     = targetScale,
            yScale     = targetScale,
            transition = easing.outQuad
        })
    end
end

---------------------------------------------------------
-- Ergebnis-Polling (robust, unabhängig vom Callback)
---------------------------------------------------------
local function checkSolved()
    if solved or not machine then
        return
    end

    local current = machine.value or 0
    if current == targetResult then
        solved = true
        onSolved()
        -- showResultPopup()  -- fällt weg
    end
end

local function enterFrameListener()
    checkSolved()
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

            target.spawnX = target.spawnX or target.x
            target.spawnY = target.spawnY or target.y

            local thresholdY = display.contentHeight * 0.5

            if machine and target.y >= thresholdY then
                swallowMarbleIntoMachine(target)
            else
                transition.to(target, {
                    time       = 200,
                    x          = target.spawnX,
                    y          = target.spawnY,
                    transition = easing.outQuad
                })
            end

            return true
        end
    end

    return false
end

---------------------------------------------------------
-- Double-Tap-Handler: schickt Murmeln im Radius in den Counter
---------------------------------------------------------
local function makeDoubleTapHandler(side)
    local radius = 300
    local r2     = radius * radius

    return function(event)
        if event.numTaps and event.numTaps >= 2 then
            if not machine then
                return true
            end

            local tapX, tapY = event.x, event.y

            for _, m in ipairs(marbles) do
                if m and not m.removed and m.side == side then
                    local dx = m.x - tapX
                    local dy = m.y - tapY
                    local dist2 = dx*dx + dy*dy
                    if dist2 <= r2 then
                        swallowMarbleIntoMachine(m)
                    end
                end
            end

            return true
        end

        return true
    end
end

---------------------------------------------------------
-- Murmeln erzeugen
-- side = "left" oder "right"
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect, side)
    local list = fixedSpawn[side] or {}
    local maxFixed = #list

    local function createMarble(x, y, color, countValue)
        local m = display.newImageRect(
            sceneGroup,
            "imgs/grey_marble.png",
            264 * 0.6,
            266 * 0.6
        )

        m.x, m.y   = x, y
        m.spawnX   = x
        m.spawnY   = y
        m.removed  = false
        m.side     = side
        m.countValue = countValue or 1

        if color then
            m:setFillColor(color[1], color[2], color[3])
        end

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
        return m
    end

    local ones      = num % 10
    local tensColor = getTensColorForValue(num)

    -- Einer-Murmeln
    local numOnes = math.min(ones, math.max(0, maxFixed - 1))
    for i = 1, numOnes do
        local pos = list[i]
        createMarble(pos[1], pos[2], marbleColors.ones, 1)
    end

    -- Bündel-Murmel (z.B. 20, 30, 40...) auf Slot 10
    if tensColor and maxFixed >= 10 then
        local pos       = list[10]
        local bundleVal = num - ones
        if bundleVal < 1 then bundleVal = 1 end
        createMarble(pos[1], pos[2], tensColor, bundleVal)
    end
end

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    rootGroup        = sceneGroup
    marbles = {}
    solved  = false
    resultPopupGroup   = nil
    solvedListenerAdded = false

    local params = event.params or {}
    local leftValue  = params.left  or 3
    local rightValue = params.right or 4
    targetResult     = leftValue + rightValue

    -----------------------------------------------------
    -- Background
    -----------------------------------------------------
    local backgr = display.newImageRect(
        sceneGroup,
        "imgs/add_backgr.png",
        1080,
        1920
    )
    backgr.x = display.contentCenterX
    backgr.y = display.contentCenterY

    -----------------------------------------------------
    -- Swipe Hints
    -----------------------------------------------------
    local swipe_hint_90_a = display.newImageRect(
        sceneGroup,
        "imgs/swipe_hint.png",
        423,
        215
    )
    swipe_hint_90_a.x = display.contentCenterX+200
    swipe_hint_90_a.y = display.contentCenterY-100
    swipe_hint_90_a.xScale = 0.5
    swipe_hint_90_a.yScale = 0.5
    swipe_hint_90_a.rotation = 90

    local swipe_hint_90_b = display.newImageRect(
        sceneGroup,
        "imgs/swipe_hint.png",
        423,
        215
    )
    swipe_hint_90_b.x = display.contentCenterX-200
    swipe_hint_90_b.y = display.contentCenterY-100
    swipe_hint_90_b.xScale = 0.5
    swipe_hint_90_b.yScale = 0.5
    swipe_hint_90_b.rotation = 90

    -- Koordinaten für die Hand-Animation merken
    swipeStartRightX = swipe_hint_90_a.x
    swipeStartLeftX  = swipe_hint_90_b.x
    swipeStartY      = swipe_hint_90_a.y - 40
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
        text     = i18n.t("add_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72
    })

    -----------------------------------------------------
    -- Zwei obere Bereiche für die Ausgangsmengen
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
    -- Double-Tap: links & rechts (jeweils nur eigene Murmeln)
    -----------------------------------------------------
    leftRect:addEventListener("tap",      makeDoubleTapHandler("left"))
    numHintLeft:addEventListener("tap",   makeDoubleTapHandler("left"))
    rightRect:addEventListener("tap",     makeDoubleTapHandler("right"))
    numHintRight:addEventListener("tap",  makeDoubleTapHandler("right"))

    -----------------------------------------------------
    -- Murmeln oben spawnen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue,  leftRect,  "left")
    spawnMarbles(sceneGroup, rightValue, rightRect, "right")

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

    -- diese beiden neuen Zeilen:
    segmentBarGroup.x0 = 0
    segmentBarGroup.y0 = 0
    segmentBarGroup.scale0 = 1

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

    swipeEndY = machine.group.y - bodyH * 0.2

    -----------------------------------------------------
    -- Hilfe-Button (Fragezeichen oben rechts)
    -----------------------------------------------------
    local hx, hy = layout.toCenter(layout.helpIcon)
    Button.new(sceneGroup, {
        image      = "imgs/questionmark.png",
        width      = layout.helpIcon.size,
        height     = layout.helpIcon.size,
        scale      = layout.helpIcon.scale,
        x          = hx,
        y          = hy,
        playSound  = false,
        onTap      = function()
            HelpPopup.show(sceneGroup, i18n.t("help_add"))
        end
    })

    -----------------------------------------------------
    -- Zurück-Button unten
    -----------------------------------------------------
    local backBtn = Button.new(sceneGroup, {
        image      = "imgs/btn_long_alt.png",
        width      = layout.longButtons.width,
        height     = layout.longButtons.height,
        scale      = layout.longButtons.scale,
        x          = display.contentCenterX,
        y          = display.contentHeight - 120,
        playSound  = false,
        onTap      = function()
            composer.gotoScene("scenes.taschenrechner", {
                effect = "slideRight",
                time   = 300,
                params = { reset = true }
            })
            composer.removeScene("scenes.addieren")
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
    solvedListenerAdded = true

    -- Hand-Tutorial starten
    startSwipeTutorial(sceneGroup)
end

function scene:show(event)
end

function scene:hide(event)
end

function scene:destroy(event)
    if solvedListenerAdded then
        Runtime:removeEventListener("enterFrame", enterFrameListener)
        solvedListenerAdded = false
    end

    for i = #marbles, 1, -1 do
        local m = marbles[i]
        if m.removeSelf then
            m:removeSelf()
        end
        marbles[i] = nil
    end
    marbles = {}

    machine = nil

    if segmentBarGroup and segmentBarGroup.removeSelf then
        segmentBarGroup:removeSelf()
    end
    segmentBarGroup = nil
    counterBar      = nil

    numHintLeft  = nil
    numHintRight = nil

    if resultPopupGroup and resultPopupGroup.removeSelf then
        resultPopupGroup:removeSelf()
    end
    resultPopupGroup = nil

    stopSwipeTutorial()
    if swipeHand and swipeHand.removeSelf then
        swipeHand:removeSelf()
    end
    swipeHand = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
