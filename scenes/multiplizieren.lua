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
local cloneDevice   -- display-Objekt der Klonmaschine
local cloneCenterX, cloneCenterY  -- Funnel-Zentrum
local multiplier = 1   -- rechte Zahl (Faktor)

---------------------------------------------------------
-- Murmel in Klonmaschine "einsaugen" und Klone zählen
---------------------------------------------------------
local function swallowIntoCloner(marble)
    if not marble or marble.removed then
        return
    end
    marble.removed = true

    transition.to(marble, {
        time   = 180,         -- ✏️ ggf. Geschwindigkeit der Einsaug-Animation anpassen
        x      = cloneCenterX,
        y      = cloneCenterY - 40,   -- ✏️ vertikaler Offset im Trichter
        xScale = 0.3,
        yScale = 0.3,
        alpha  = 0.0,
        onComplete = function()
            if marble.removeSelf then
                marble:removeSelf()
            end

            -- Jede Murmel erzeugt "multiplier" Klone → so oft increment
            if machine and multiplier > 0 then
                for i = 1, multiplier do
                    machine:increment()
                end
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

            -- Spawn fallback
            target.spawnX = target.spawnX or target.x
            target.spawnY = target.spawnY or target.y

            -- Abstand zur Klonmaschine (Funnel-Zentrum)
            local dx = target.x - cloneCenterX
            local dy = target.y - cloneCenterY
            local dist2 = dx*dx + dy*dy

            local radius = 260       -- ✏️ Größe der Fangzone rund um den Trichter

            if dist2 <= radius * radius then
                -- In die Maschine
                swallowIntoCloner(target)
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
    marbles = {}

    local params = event.params or {}
    local leftValue  = params.left  or 3
    local rightValue = params.right or 4
    multiplier       = rightValue or 1

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
        text     = i18n.t("mul_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72   -- ✏️ Titelgröße
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
    -- Klonmaschine im rechten Bereich
    -----------------------------------------------------
    local clonerScale = 0.55   -- ✏️ Gesamtgröße der Klonmaschine

    cloneDevice = display.newImageRect(
        sceneGroup,
        "imgs/clonedevice.png",
        898 * clonerScale,
        1188 * clonerScale
    )
    cloneDevice.x = rightRect.x
    cloneDevice.y = rightRect.y + 40

    -- Funnel-Zentrum: etwas links der Maschine, leicht oberhalb der Mitte
    cloneCenterX = cloneDevice.x - cloneDevice.width * 0.35  -- ✏️ horizontale Funnel-Position
    cloneCenterY = cloneDevice.y - cloneDevice.height * 0.10 -- ✏️ vertikale Funnel-Position

    -----------------------------------------------------
    -- Zählmaschine unten
    -----------------------------------------------------
    machine = CounterMachine.new(sceneGroup, {
        x     = display.contentCenterX,
        y     = display.contentHeight * 0.72,  -- ✏️ vertikale Position der Zählmaschine
        scale = 0.8                            -- ✏️ Größe der Zählmaschine
    })
    machine:setValue(0)

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
            HelpPopup.show(sceneGroup, i18n.t("help_mul"))
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
            composer.removeScene("scenes.multiplizieren")
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
    machine = nil
    cloneDevice = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
