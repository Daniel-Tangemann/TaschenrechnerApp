-- scenes/multiplizieren.lua
local composer       = require("composer")
local scene          = composer.newScene()

local layout         = require("layout")
local Button         = require("ui.button")
local HelpPopup      = require("ui.help_popup")
local i18n           = require("lang.i18n")
local CounterMachine = require("ui.counter_machine")
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
    }
}

---------------------------------------------------------
-- Lokale Variablen
---------------------------------------------------------
local marbles       = {}
local machine       -- CounterMachine-Instanz
local clonerSprite  -- komplette Klonmaschine als Sprite
local cloneCenterX, cloneCenterY  -- Funnel-Zentrum
local multiplier = 1   -- rechte Zahl (Faktor)

-- Balken unter der Maschine
local segmentBarGroup
local counterBar

-- Beam-Loop-Animation
local clonerAnimTimer      = nil
local clonerAnimLoopActive = false

-- Hand-Tutorial (horizontal links -> rechts)
local swipeHand
local tutorialActive = false
local swipeStartX, swipeEndX, swipeY

-- Ergebnis / Win-Zoom
local targetResult = 0
local solved = false
local machineStartX, machineStartY, machineStartScale
local machineSolvedAnimating = false
local solvedListenerAdded = false

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
-- Klonmaschinen-Sprite: idle / beam
---------------------------------------------------------
local function setClonerBeamActive(active)
    if not clonerSprite then return end
    if active then
        clonerSprite:setFrame(2)  -- Strahl-Frame
    else
        clonerSprite:setFrame(1)  -- Idle-Frame
    end
end

local function stopClonerBeamLoop()
    if clonerAnimTimer then
        timer.cancel(clonerAnimTimer)
        clonerAnimTimer = nil
    end
    clonerAnimLoopActive = false
    setClonerBeamActive(false)
end

local function startClonerBeamLoop(totalSteps, stepDelay)
    stopClonerBeamLoop()

    if not clonerSprite then return end
    if not totalSteps or totalSteps <= 0 then return end

    clonerAnimLoopActive = true
    local steps  = 0
    local delay  = stepDelay or 40

    clonerAnimTimer = timer.performWithDelay(delay, function(e)
        if not clonerSprite then
            stopClonerBeamLoop()
            return
        end

        -- Idle ↔ Strahl toggeln
        if clonerSprite.frame == 1 then
            clonerSprite:setFrame(2)
        else
            clonerSprite:setFrame(1)
        end

        steps = steps + 1
        if steps >= totalSteps then
            stopClonerBeamLoop()
        end
    end, 0)
end

---------------------------------------------------------
-- Balken kurz aufblinken lassen, wenn gezählt wurde
-- (Beam wird nur beeinflusst, wenn keine Loop läuft)
---------------------------------------------------------
local function blinkCounterBar()
    if not counterBar then return end

    transition.cancel(counterBar)

    -- nur kurz Strahl an/aus, wenn gerade keine Dauer-Loop läuft
    if not clonerAnimLoopActive then
        setClonerBeamActive(true)
    end

    counterBar:setFillColor(1, 1, 0.2)
    counterBar.alpha = 1

    transition.to(counterBar, {
        time  = 200,
        alpha = 0.7,
        onComplete = function()
            if counterBar then
                counterBar:setFillColor(0.2, 0.2, 0.35)
            end
            if not clonerAnimLoopActive then
                setClonerBeamActive(false)
            end
        end
    })
end

---------------------------------------------------------
-- Vorwärtsdeklaration für Win-Animation
---------------------------------------------------------
local function onSolved() end

---------------------------------------------------------
-- Ergebnis-Polling (wie bei Add/Sub)
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
-- Murmel in Klonmaschine "einsaugen" und Produkt zählen
-- onDone: optionaler Callback (z.B. Balken)
---------------------------------------------------------
local function swallowIntoCloner(marble, onDone)
    if not marble or marble.removed then
        return
    end
    marble.removed = true
    stopSwipeTutorial()  -- Spieler hat verstanden → Tutorial ausblenden

    transition.to(marble, {
        time   = 180,
        x      = cloneCenterX,
        y      = cloneCenterY - 40,
        xScale = 0.3,
        yScale = 0.3,
        alpha  = 0.0,
        onComplete = function()
            if marble.removeSelf then
                marble:removeSelf()
            end

            if machine and multiplier > 0 then
                local baseValue = marble.countValue or 1
                if baseValue < 0 then baseValue = 0 end
                local total = baseValue * multiplier

                if total > 0 then
                    local stepDelay = 40

                    -- Beam-Loop für die gesamte Zählzeit starten
                    startClonerBeamLoop(total, stepDelay)

                    if machine.incrementMany then
                        machine:incrementMany(total, stepDelay)
                    else
                        -- Fallback: alles “auf einen Schlag”
                        for _ = 1, total do
                            machine:increment()
                        end
                    end
                end
            end

            if onDone then
                onDone()
            end
        end
    })
end

---------------------------------------------------------
-- Wenn Aufgabe gelöst: Maschine nach oben in die Mitte zoomen
-- + Balken mit Magic Numbers justieren (hacky, aber hübsch)
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
    local targetScale = (machineStartScale or machine.group.xScale or 1) * 1.2

    -- Maschine bewegen & skalieren
    transition.to(machine.group, {
        time       = 700,
        x          = targetX,
        y          = targetY,
        xScale     = targetScale,
        yScale     = targetScale,
        transition = easing.outQuad
    })

    -- Balkengruppe mitbewegen & mitskalieren (Magic Numbers)
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
-- Touch-Listener für Murmeln (drag in die Klonmaschine)
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

            -- Sicherheitsnetz
            target.spawnX = target.spawnX or target.x
            target.spawnY = target.spawnY or target.y

            -- Abstand zur Klonmaschine (Funnel-Zentrum)
            local dx = target.x - cloneCenterX
            local dy = target.y - cloneCenterY
            local dist2 = dx*dx + dy*dy
            local radius = 260   -- Fangradius

            if dist2 <= radius * radius then
                -- In die Maschine + Balken/Strahl
                swallowIntoCloner(target, blinkCounterBar)
            else
                -- Zurück zum Spawn
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
-- Double-Tap-Handler:
-- schickt alle Murmeln im Radius in die Klonmaschine
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
            if m and not m.removed and m.side == "left" then
                local dx = m.x - tapX
                local dy = m.y - tapY
                local dist2 = dx*dx + dy*dy
                if dist2 <= r2 then
                    swallowIntoCloner(m, blinkCounterBar)
                end
            end
        end

        return true
    end
end

---------------------------------------------------------
-- Murmeln erzeugen (links, mit Bündel-Murmel + Farben)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect)
    local list = fixedSpawn.left or {}
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
        m.side    = "left"
        m.countValue = countValue or 1
        m.isBundle   = isBundle or false

        if color then
            m:setFillColor(color[1], color[2], color[3])
        end

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
        return m
    end

    -- Zahl in Einer + eine „Bündel“-Murmel auf Position 10
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

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    marbles = {}

    local params = event.params or {}
    local leftValue  = params.left  or 3
    local rightValue = params.right or 4
    multiplier       = rightValue or 1

    targetResult           = leftValue * rightValue
    solved                 = false
    machineSolvedAnimating = false
    solvedListenerAdded    = false

    -----------------------------------------------------
    -- Background
    -----------------------------------------------------
    local backgr = display.newImageRect(
        sceneGroup,
        "imgs/multi_backgr.png",
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
        text     = i18n.t("mul_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72
    })

    -----------------------------------------------------
    -- Zwei obere Bereiche: links Murmeln, rechts Klonmaschine
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
    -- Double-Tap: auf linkem Bereich UND linkem Num-Hint
    -----------------------------------------------------
    local tapRadius = 1000
    local doubleTapHandler = makeDoubleTapHandler(tapRadius)
    leftRect:addEventListener("tap", doubleTapHandler)
    numHintLeft:addEventListener("tap", doubleTapHandler)

    -----------------------------------------------------
    -- Murmeln links spawnen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue, leftRect)

    -----------------------------------------------------
    -- Klonmaschine als Sprite (Multiplikator_Spritesheet)
    -- Sheet: 800 x 640, 2 Frames nebeneinander → 400 x 640 pro Frame
    -----------------------------------------------------
    local clonerSheetOptions = {
        width              = 400,
        height             = 640,
        numFrames          = 2,
        sheetContentWidth  = 800,
        sheetContentHeight = 640,
    }
    local clonerSheet = graphics.newImageSheet("imgs/Multiplikator_Spritesheet.png", clonerSheetOptions)

    clonerSprite = display.newSprite(sceneGroup, clonerSheet, {
        name  = "all",
        start = 1,
        count = 2,
        time  = 0
    })
    clonerSprite:setFrame(1)  -- idle

    -- Skalierung an rechten Bereich anpassen
    local targetHeight = areaHeightTop * 0.9
    local scale = targetHeight / 640
    clonerSprite.xScale = scale
    clonerSprite.yScale = scale

    clonerSprite.x = rightRect.x
    clonerSprite.y = rightRect.y + 40

    -- Funnel-Zentrum relativ zum Sprite (Feintuning bei Bedarf)
    cloneCenterX = clonerSprite.x - clonerSprite.width * 0.25
    cloneCenterY = clonerSprite.y - clonerSprite.height * 0.10

    -----------------------------------------------------
    -- Swipe Hint (optisch)
    -----------------------------------------------------
    local swipe_hint_0_b = display.newImageRect( 
        sceneGroup, 
        "imgs/swipe_hint.png", 
        423, 
        215 
    )
    swipe_hint_0_b.x = display.contentCenterX-200
    swipe_hint_0_b.y = display.contentCenterY-100
    swipe_hint_0_b.xScale = 0.5
    swipe_hint_0_b.yScale = 0.5
    swipe_hint_0_b.rotation = 0

    -----------------------------------------------------
    -- Koordinaten für die Hand-Animation (wie Subtrahieren)
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
    -- Voller Balken unter den Rollen (wie Divisor = 1)
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
        image      = "imgs/questionmark.png",
        width      = layout.helpIcon.size,
        height     = layout.helpIcon.size,
        scale      = layout.helpIcon.scale,
        x          = hx,
        y          = hy,
        playSound  = false,
        onTap      = function()
            HelpPopup.show(sceneGroup, i18n.t("help_mul"))
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
            composer.removeScene("scenes.multiplizieren")
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
    -- Ergebnis-Listener / Hand-Tutorial aktivieren
    -----------------------------------------------------
    Runtime:addEventListener("enterFrame", enterFrameListener)
    solvedListenerAdded = true

    startSwipeTutorial(sceneGroup)
end

function scene:show(event)
end

function scene:hide(event)
end

function scene:destroy(event)
    stopClonerBeamLoop()
    stopSwipeTutorial()

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

    machine      = nil
    clonerSprite = nil

    if segmentBarGroup and segmentBarGroup.removeSelf then
        segmentBarGroup:removeSelf()
    end
    segmentBarGroup = nil
    counterBar      = nil

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
