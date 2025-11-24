-- scenes/addieren.lua
local composer   = require("composer")
local scene      = composer.newScene()

local layout     = require("layout")
local Button     = require("ui.button")
local HelpPopup  = require("ui.help_popup")
local i18n       = require("lang.i18n")

---------------------------------------------------------
-- Lokale Variablen
---------------------------------------------------------
local marbles = {}
local bottomRect
local counterText

---------------------------------------------------------
-- Hilfsfunktion: Prüfen, ob ein Punkt in einem Rechteck ist
---------------------------------------------------------
local function pointInRect(x, y, rect)
    local halfW = rect.width * 0.5
    local halfH = rect.height * 0.5
    return  x >= rect.x - halfW and x <= rect.x + halfW and
            y >= rect.y - halfH and y <= rect.y + halfH
end

---------------------------------------------------------
-- Zähler aktualisieren (wie viele Murmeln sind unten?)
---------------------------------------------------------
local function updateCounter()
    local count = 0
    for _, m in ipairs(marbles) do
        if m.inBottom then
            count = count + 1
        end
    end
    if counterText then
        counterText.text = tostring(count)
    end
end

---------------------------------------------------------
-- Touch-Listener für Murmeln
---------------------------------------------------------
local function marbleTouch(event)
    local target = event.target

    if event.phase == "began" then
        display.getCurrentStage():setFocus(target)
        target.isFocus = true
        target.touchOffsetX = event.x - target.x
        target.touchOffsetY = event.y - target.y
        target:toFront()
        return true

    elseif target.isFocus then
        if event.phase == "moved" then
            target.x = event.x - target.touchOffsetX
            target.y = event.y - target.touchOffsetY
        elseif event.phase == "ended" or event.phase == "cancelled" then
            display.getCurrentStage():setFocus(nil)
            target.isFocus = false

            -- Ist die Murmel im unteren Feld?
            if pointInRect(target.x, target.y, bottomRect) then
                target.inBottom = true
            else
                target.inBottom = false
            end

            updateCounter()
        end
        return true
    end

    return false
end

---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    marbles = {}

    local params = event.params or {}
    local leftValue  = params.left  or 3
    local rightValue = params.right or 4
    local total      = params.result or (leftValue + rightValue) -- aktuell nur Info

    -----------------------------------------------------
    -- Hintergrund / Banner oben
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
        text     = i18n.t("add_title"),
        x        = banner.x,
        y        = banner.y,
        font     = native.systemFontBold,
        fontSize = 72
    })

    -----------------------------------------------------
    -- Drei Bereiche: links oben, rechts oben, unten
    -----------------------------------------------------
    local topY      = display.contentCenterY - 250
    local bottomY   = display.contentCenterY + 300
    local areaWidth = display.contentWidth * 0.35
    local areaHeightTop = 260
    local areaHeightBottom = 280

    local leftRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.25,
        topY,
        areaWidth,
        areaHeightTop,
        32
    )
    leftRect:setFillColor(0.1, 0.15, 0.3, 0.8)

    local rightRect = display.newRoundedRect(
        sceneGroup,
        display.contentWidth * 0.75,
        topY,
        areaWidth,
        areaHeightTop,
        32
    )
    rightRect:setFillColor(0.1, 0.15, 0.3, 0.8)

    bottomRect = display.newRoundedRect(
        sceneGroup,
        display.contentCenterX,
        bottomY,
        display.contentWidth * 0.8,
        areaHeightBottom,
        32
    )
    bottomRect:setFillColor(0.1, 0.25, 0.35, 0.9)

    -----------------------------------------------------
    -- Zähler (counter.png + Text)
    -----------------------------------------------------
    local counterImg = display.newImageRect(
        sceneGroup,
        "imgs/counter.png",
        429 * 0.9,
        256 * 0.9
    )
    counterImg.x = display.contentCenterX
    counterImg.y = bottomY - areaHeightBottom * 0.5 - 120

    counterText = display.newText({
        parent   = sceneGroup,
        text     = "0",
        x        = counterImg.x,
        y        = counterImg.y + 10,
        font     = native.systemFontBold,
        fontSize = 72,
        align    = "center",
        width    = counterImg.width * 0.7
    })

    -----------------------------------------------------
    -- Murmeln erzeugen (links + rechts)
    -----------------------------------------------------
    local function spawnMarbles(num, containerRect)
        local created = {}
        for i = 1, num do
            local m = display.newImageRect(
                sceneGroup,
                "imgs/marble.png",
                264 * 0.6,
                266 * 0.6
            )

            -- zufällige Position innerhalb des Rechtecks
            local halfW = containerRect.width * 0.5 - 40
            local halfH = containerRect.height * 0.5 - 40
            m.x = containerRect.x + math.random(-halfW, halfW)
            m.y = containerRect.y + math.random(-halfH, halfH)

            m.inBottom = false
            m:addEventListener("touch", marbleTouch)

            marbles[#marbles + 1] = m
            created[#created + 1] = m
        end
        return created
    end

    spawnMarbles(leftValue, leftRect)
    spawnMarbles(rightValue, rightRect)

    updateCounter()

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
            HelpPopup.show(sceneGroup, i18n.t("help_add"))
        end
    })

    -----------------------------------------------------
    -- Zurück-Button (unten)
    -----------------------------------------------------
    local backBtn = Button.new(sceneGroup, {
        image  = "imgs/btn_long_alt.png",
        width  = layout.longButtons.width,
        height = layout.longButtons.height,
        scale  = layout.longButtons.scale,
        x      = display.contentCenterX,
        y      = display.contentHeight - 150,
        onTap = function()
            composer.gotoScene("scenes.taschenrechner", {
                effect = "slideRight",
                time = 300,
                params = { reset = true, from = "addieren" }   -- <<< wichtig
            })
        end
    })

    -- Pfeil auf den Zurück-Button
    local arrow = display.newImageRect(
        sceneGroup,
        "imgs/arrow.png",
        669 * 0.2,
        267 * 0.2
    )
    arrow.x = backBtn.group.x - backBtn.width * 0.15
    arrow.y = backBtn.group.y
end

function scene:show(event) end
function scene:hide(event) end

function scene:destroy(event)
    marbles = {}
    bottomRect = nil
    counterText = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
