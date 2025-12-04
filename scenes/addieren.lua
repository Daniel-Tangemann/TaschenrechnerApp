-- scenes/addieren.lua
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
    },
    right = {
        {618, 380}, {760, 380}, {902, 380},
        {618, 545}, {760, 545}, {902, 545},
        {618, 715}, {760, 715}, {902, 715},
        {618, 890}, {760, 890}, {902, 890},
    }
}

---------------------------------------------------------
-- Lokale Variablen
---------------------------------------------------------
local marbles = {}
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

            -- Schwelle: "über die Hälfte nach unten gezogen"
            local thresholdY = display.contentHeight * 0.5

            if machine and target.y >= thresholdY then
                -- weiter als die Hälfte → Maschine saugt ein
                -- 🔴 hier hängen wir das Balken-Blinken dran
                machine:swallowMarble(target, function()
                    blinkCounterBar()
                end)
            else
                -- nicht weit genug → zurück zum Spawnpoint
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
-- Murmeln erzeugen
-- side = "left" oder "right"
---------------------------------------------------------
local function spawnMarbles(sceneGroup, num, containerRect, side)
    local list = fixedSpawn[side] or {}
    local maxFixed = #list

    for i = 1, num do
        local m = display.newImageRect(
            sceneGroup,
            "imgs/marble.png",
            264 * 0.6,
            266 * 0.6
        )

        if i <= maxFixed then
            -- feste Positionen
            local pos = list[i]
            m.x, m.y = pos[1], pos[2]
        else
            -- zusätzliche Murmeln: in den Zwischenräumen des jeweiligen Bereichs
            local halfW = containerRect.width * 0.5 - 40
            local halfH = containerRect.height * 0.5 - 40
            m.x = containerRect.x + math.random(-halfW, halfW)
            m.y = containerRect.y + math.random(-halfH, halfH)
        end

        -- Spawnposition merken
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

    machine = nil

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
