-- scenes/subtrahieren.lua
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
local slots   = {}  -- rechte Plätze (empty_spot)
local machine -- CounterMachine-Instanz

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
                machine:swallowMarble(target)
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
    -- Murmeln links spawnen & Slots rechts anzeigen
    -----------------------------------------------------
    spawnMarbles(sceneGroup, leftValue,  leftRect,  "left")
    spawnSlots(sceneGroup, rightValue)

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
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
