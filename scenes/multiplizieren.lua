-- scenes/taschenrechner.lua  (Template, in anderen Dateien wiederverwenden)
local composer = require("composer")

-- Namen nur für Debug / Titelanzeige
local sceneName = "Multiplizieren"
local scene = composer.newScene()

-------------------------------------------------
-- scene:create
-------------------------------------------------
function scene:create(event)
    local sceneGroup = self.view

    -- Hintergrund (Platzhalter)
    local bg = display.newRect(
        sceneGroup,
        display.contentCenterX,
        display.contentCenterY,
        display.actualContentWidth,
        display.actualContentHeight
    )
    bg:setFillColor(0.1, 0.1, 0.1)  -- dunkles Grau als Platzhalter

    -- Titel (Platzhalter)
    local title = display.newText({
        parent = sceneGroup,
        text   = sceneName,
        x      = display.contentCenterX,
        y      = 60,
        font   = native.systemFontBold,
        fontSize = 32
    })
end

-------------------------------------------------
-- scene:show
-------------------------------------------------
function scene:show(event)
    local phase = event.phase
    if (phase == "will") then
        -- Szene ist gleich sichtbar (Animationen vorbereiten etc.)
    elseif (phase == "did") then
        -- Szene ist jetzt sichtbar (Listener starten usw.)
    end
end

-------------------------------------------------
-- scene:hide
-------------------------------------------------
function scene:hide(event)
    local phase = event.phase
    if (phase == "will") then
        -- Szene wird gleich ausgeblendet (Timer/Runtime-Listener stoppen)
    elseif (phase == "did") then
        -- Szene ist komplett weg
    end
end

-------------------------------------------------
-- scene:destroy
-------------------------------------------------
function scene:destroy(event)
    local sceneGroup = self.view
    -- Aufräumen, falls nötig (Audio dispose, Runtime Listener etc.)
end

-------------------------------------------------
-- Event-Listener registrieren
-------------------------------------------------
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene
