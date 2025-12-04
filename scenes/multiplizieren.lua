-- scenes/multiplizieren.lua
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
local marbles       = {}
local machine       -- CounterMachine-Instanz
local clonerSprite  -- komplette Klonmaschine als Sprite
local cloneCenterX, cloneCenterY  -- Funnel-Zentrum
local multiplier = 1   -- rechte Zahl (Faktor)

-- Balken unter der Maschine
local segmentBarGroup
local counterBar

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

---------------------------------------------------------
-- Balken kurz aufblinken lassen, wenn gezählt wurde
-- + gleichzeitig Klonmaschine-Strahl aktivieren
---------------------------------------------------------
local function blinkCounterBar()
    if not counterBar then return end

    transition.cancel(counterBar)

    -- Strahl an
    setClonerBeamActive(true)

    counterBar:setFillColor(1, 1, 0.2)
    counterBar.alpha = 1

    transition.to(counterBar, {
        time  = 200,
        alpha = 0.7,
        onComplete = function()
            if counterBar then
                counterBar:setFillColor(0.2, 0.2, 0.35)
            end
            -- Strahl wieder aus
            setClonerBeamActive(false)
        end
    })
end

---------------------------------------------------------
-- Murmel in Klonmaschine "einsaugen" und Klone zählen
-- onDone: optionaler Callback (z.B. Balken+Strahl)
---------------------------------------------------------
local function swallowIntoCloner(marble, onDone)
    if not marble or marble.removed then
        return
    end
    marble.removed = true

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
                for i = 1, multiplier do
                    machine:increment()
                end
            end

            if onDone then
                onDone()
            end
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
-- Murmeln erzeugen (links)
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect)
    local list = fixedSpawn.left or {}
    local maxFixed = #list

    for i = 1, num do
        local m = display.newImageRect(
            sceneGroup,
            "imgs/marble.png",
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

        m:addEventListener("touch", marbleTouch)
        marbles[#marbles + 1] = m
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

    -- Funnel-Zentrum relativ zum Sprite (Feintuning evtl. nötig)
    cloneCenterX = clonerSprite.x - clonerSprite.width * 0.25
    cloneCenterY = clonerSprite.y - clonerSprite.height * 0.10

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

    machine      = nil
    clonerSprite = nil

    if segmentBarGroup and segmentBarGroup.removeSelf then
        segmentBarGroup:removeSelf()
    end
    segmentBarGroup = nil
    counterBar      = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
