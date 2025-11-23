-- scenes/taschenrechner.lua

local Sound = require("sound")
local composer = require("composer")
local scene = composer.newScene()

local layout = require("layout")
local Button = require("ui.button")
local Display = require("ui.display")
local HelpPopup = require("ui.help_popup")
local i18n = require("lang.i18n")

---------------------------------------------------------
-- Interner Zustand des Rechners
---------------------------------------------------------
local leftValue = ""
local operator = ""
local rightValue = ""

local displayObj

local sceneGroupRef  -- wird in scene:create gesetzt

-- Explosion-Sheet vorbereiten
local explosionSheetOptions = {
    width = 90,
    height = 160,
    numFrames = 12,
    sheetContentWidth = 360,
    sheetContentHeight = 480
}

local explosionSheet = graphics.newImageSheet("imgs/boom_12f_90x160px.png", explosionSheetOptions)

local explosionSequenceData = {
    { name = "explode", start = 1, count = 12, time = 800, loopCount = 1 }
}

local function triggerExplosion()
    if not sceneGroupRef then return end

    -- Sprite über allem anzeigen (Mitte des Bildschirms oder Display)
    local spr = display.newSprite(sceneGroupRef, explosionSheet, explosionSequenceData)
    spr.x = display.contentCenterX
    spr.y = display.contentCenterY
    -- Sprite auf volle Bildschirmgröße skalieren
    local screenW = display.contentWidth
    local screenH = display.contentHeight

    spr.xScale = screenW / 90     -- Frame-Breite
    spr.yScale = screenH / 160    -- Frame-Höhe

    -- Sound abspielen
    Sound.playExplosion()

    -- Animation starten
    spr:play()

    -- Nach Ende Animation entfernen
    local function onSpriteEvent(event)
        if event.phase == "ended" then
            spr:removeEventListener("sprite", onSpriteEvent)
            display.remove(spr)

            -- 🔄 Taschenrechner zurücksetzen (AC-Funktion)
            leftValue = ""
            operator = ""
            rightValue = ""
            displayObj:clear()
        end
    end
    spr:addEventListener("sprite", onSpriteEvent)
end

---------------------------------------------------------
-- Hilfsfunktionen für Rechenlogik
---------------------------------------------------------

local function updateDisplay()
    displayObj:setExpression(leftValue, operator, rightValue)
    -- KEIN setResult() mehr hier
end

---------------------------------------------------------
-- Button-Callbacks
---------------------------------------------------------

local function onDigitPressed(d)
    if operator == "" then
        -- linke Seite: max. 2 Ziffern
        if #leftValue >= 2 then
            Sound.playPop()
            return
        end
        leftValue = leftValue .. d
    else
        -- rechte Seite: max. 1 Ziffer
        if #rightValue >= 1 then
            Sound.playPop()
            return
        end

        -- Sonderfall Division: linke Zahl muss >= rechte sein
        if operator == "/" then
            local leftNum  = tonumber(leftValue) or 0
            local rightNum = tonumber(d) or 0      -- rechte Zahl ist einstellig
            if not (leftNum >= rightNum) then
                Sound.playPop()
                return
            end
        end

        rightValue = rightValue .. d
    end
    updateDisplay()
end

local function onOperatorPressed(op)
    if leftValue == "" then
        Sound.playPop()
        return
    end
    if operator ~= "" then
        Sound.playPop()
        return
    end
    operator = op
    updateDisplay()
end

local function onClearPressed()
    leftValue = ""
    operator = ""
    rightValue = ""
    displayObj:clear()
end

local function onDeletePressed()
    if operator == "" then
        leftValue = leftValue:sub(1, -2)
    elseif rightValue == "" then
        operator = ""
    else
        rightValue = rightValue:sub(1, -2)
    end
    updateDisplay()
end

local currentResult = nil  -- oben als lokale Variable

local function onEqualsPressed()
    if leftValue == "" or operator == "" or rightValue == "" then
        Sound.playPop()
        return
    end

    if operator == "/" and tonumber(rightValue) == 0 then
        displayObj:setError("ERR")
        triggerExplosion()
        return
    end

    local a = tonumber(leftValue)
    local b = tonumber(rightValue)
    local r = 0

    if operator == "+" then r = a + b end
    if operator == "-" then r = a - b end
    if operator == "*" then r = a * b end
    if operator == "/" then r = a / b end

    currentResult = r       -- Ergebnis nur intern merken
    -- NICHT: displayObj:setResult(r)

    -- Werte ggf. an die Minispiel-Scene übergeben:
    local params = {
        left  = a,
        right = b,
        op    = operator,
        result = r,
    }

    if operator == "+" then composer.gotoScene("scenes.addieren", { params = params }) end
    if operator == "-" then composer.gotoScene("scenes.subtrahieren", { params = params }) end
    if operator == "*" then composer.gotoScene("scenes.multiplizieren", { params = params }) end
    if operator == "/" then composer.gotoScene("scenes.dividieren", { params = params }) end
end

---------------------------------------------------------
-- Scene UI erstellen
---------------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view
    sceneGroupRef = sceneGroup
    -----------------------------------------------------
    -- Display
    -----------------------------------------------------
    displayObj = Display.new(sceneGroup)
    displayObj:clear()

    -----------------------------------------------------
    -- 4×4 Zahlen- und Operator-Buttons
    -----------------------------------------------------

    local symbols = {
        "7","8","9","AC",
        "4","5","6","DEL",
        "1","2","3","/",
        "0","+","-","*"
    }

    local index = 1
    for row = 1,4 do
        for col = 1,4 do
            local label = symbols[index]
            index = index + 1

            local cx, cy = layout.getGridButtonCenter(col, row)

            local btn = Button.new(sceneGroup, {
                image  = "imgs/btn_key.png",
                width  = layout.buttonsGrid.btnWidth,
                height = layout.buttonsGrid.btnHeight,
                scale  = layout.buttonsGrid.scale,
                x      = cx,
                y      = cy,
                onTap = function()
                    if tonumber(label) ~= nil then
                        onDigitPressed(label)
                    elseif label == "AC" then
                        onClearPressed()
                    elseif label == "DEL" then
                        onDeletePressed()
                    else
                        onOperatorPressed(label)
                    end
                end
            })
        end
    end

    -----------------------------------------------------
    -- Lange Buttons unten (= und Zufall)
    -----------------------------------------------------
    local cx1, cy1 = layout.getLongButtonCenter(1)
    Button.new(sceneGroup, {
        image  = "imgs/btn_long.png",
        width  = layout.longButtons.width,
        height = layout.longButtons.height,
        scale  = layout.longButtons.scale,
        x      = cx1,
        y      = cy1,
        onTap = onEqualsPressed
    })

    local cx2, cy2 = layout.getLongButtonCenter(2)
    Button.new(sceneGroup, {
        image  = "imgs/btn_long.png",
        width  = layout.longButtons.width,
        height = layout.longButtons.height,
        scale  = layout.longButtons.scale,
        x      = cx2,
        y      = cy2,
        onTap = function()
            -- Zufalls-Aufgabe (Hook)
            print("RANDOM TASK")
        end
    })

    -----------------------------------------------------
    -- Settings Icon
    -----------------------------------------------------
    local sx, sy = layout.toCenter(layout.settingsIcon)
    Button.new(sceneGroup, {
        image  = "imgs/settings.png",
        width  = layout.settingsIcon.size,
        height = layout.settingsIcon.size,
        scale  = layout.settingsIcon.scale,
        x      = sx,
        y      = sy,
        onTap = function()
            composer.gotoScene("scenes.settings")
        end
    })

    -----------------------------------------------------
    -- Hilfe Icon
    -----------------------------------------------------
    local hx, hy = layout.toCenter(layout.helpIcon)
    Button.new(sceneGroup, {
        image  = "imgs/questionmark.png",
        width  = layout.helpIcon.size,
        height = layout.helpIcon.size,
        scale  = layout.helpIcon.scale,
        x      = hx,
        y      = hy,
        onTap = function()
            HelpPopup.show(sceneGroupRef, i18n.t("help_calculator"))
        end
    })
end

function scene:show(event) end
function scene:hide(event) end
function scene:destroy(event) end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
