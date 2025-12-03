-- ui/counter_machine.lua
-- Zählmaschine mit Trichter + mechanischer Zahlenrolle

local CounterMachine = {}
CounterMachine.__index = CounterMachine

-- SpriteSheet-Daten für die Zahlenrolle (dein neues Sheet)
local DIGIT_FRAME_W  = 166
local DIGIT_FRAME_H  = 275
local SHEET_W        = 830
local SHEET_H        = 1100
local DIGIT_FRAMES   = 20   -- 0, Zwischen 0→1, 1, Zwischen 1→2, ..., 9, Zwischen 9→0

-- Sound
local countSound = audio.loadSound("sounds/ding_bop_1.wav")

----------------------------------------------------------------
-- Hilfsfunktion: Basisframe einer Ziffer (0..9)
-- Wir nehmen an: 0 = Frame 1, 1 = Frame 3, ..., 9 = Frame 19
----------------------------------------------------------------
local function digitToBaseFrame(d)
    return d * 2 + 1
end

----------------------------------------------------------------
-- Konstruktor
-- opts: { x, y, scale }
----------------------------------------------------------------
function CounterMachine.new(parentGroup, opts)
    opts = opts or {}

    local self = setmetatable({}, CounterMachine)

    self.group = display.newGroup()
    parentGroup:insert(self.group)

    self.x = opts.x or display.contentCenterX
    self.y = opts.y or display.contentCenterY
    self.group.x, self.group.y = self.x, self.y

    self.scale = opts.scale or 0.6

    ------------------------------------------------------------
    -- Maschinengehäuse
    ------------------------------------------------------------
    self.body = display.newImageRect(
        self.group,
        "imgs/counting_machine.png",
        1024 * self.scale,
        768 * self.scale
    )
    self.body.x, self.body.y = 0, 0

    ------------------------------------------------------------
    -- Zahlenrollen-SpriteSheet
    ------------------------------------------------------------
    local sheetOptions = {
        width              = DIGIT_FRAME_W,
        height             = DIGIT_FRAME_H,
        numFrames          = DIGIT_FRAMES,
        sheetContentWidth  = SHEET_W,
        sheetContentHeight = SHEET_H,
    }

    self.digitSheet = graphics.newImageSheet("imgs/zahlenrolle_spritesheet.png", sheetOptions)
    self.digitSeq   = { { name = "roll", start = 1, count = DIGIT_FRAMES, time = 0 } }

    ------------------------------------------------------------
    -- Drei Digit-Rollen (Hundert / Zehn / Einer)
    ------------------------------------------------------------
    self.digits = {}

    local digitScale = (self.body.height * 0.45) / DIGIT_FRAME_H  -- grob passend skalieren
    local spacing = DIGIT_FRAME_W * digitScale * 0.9

    -- links = Hunderter, Mitte = Zehner, rechts = Einer
    for i = 1, 3 do
        local spr = display.newSprite(self.group, self.digitSheet, self.digitSeq)
        spr.x = (i - 2) * spacing + 90  -- dein Offset
        spr.y = 0 + 30                  -- dein Offset
        spr.xScale, spr.yScale = digitScale, digitScale
        spr:setFrame(1)                 -- zeigt 0
        self.digits[i] = {
            sprite = spr,
            digit  = 0,                  -- aktuelle Ziffer (0..9)
        }
    end

    self.body:toFront()
    ------------------------------------------------------------
    -- Trichter-Treffpunkt (für Murmel-Animation)
    ------------------------------------------------------------
    self.funnelX = 0
    self.funnelY = -self.body.height * 0.35   -- etwas über dem Gehäuse; an dein Asset angepasst

    ------------------------------------------------------------
    -- Zählerwert & Animations-Status
    ------------------------------------------------------------
    self.value       = 0       -- 0..999
    self.isAnimating = false   -- ob gerade eine Inkrement-Animation läuft
    self.queue       = 0       -- wie viele Inkremente warten

    return self
end

----------------------------------------------------------------
-- Rollenanzeige aus den digit-Feldern setzen
----------------------------------------------------------------
function CounterMachine:_applyDigitsToSprites()
    for i = 1, 3 do
        local d   = self.digits[i].digit
        local spr = self.digits[i].sprite
        spr:setFrame(digitToBaseFrame(d))
    end
end

----------------------------------------------------------------
-- eine Rolle von alter Ziffer zu neuer drehen
-- wheelIndex: 1 = Hunderter, 2 = Zehner, 3 = Einer
-- newDigit: neue Ziffer 0..9 (wir gehen davon aus, dass es immer +1 ist)
----------------------------------------------------------------
function CounterMachine:_spinWheelOnce(wheelIndex, newDigit, onComplete)
    local wheel    = self.digits[wheelIndex]
    local spr      = wheel.sprite
    local oldDigit = wheel.digit or 0

    if oldDigit == newDigit then
        if onComplete then onComplete() end
        return
    end

    local baseFrame = digitToBaseFrame(oldDigit)
    local midFrame  = baseFrame + 1
    local nextBase  = digitToBaseFrame(newDigit)

    -- Halb-Frame
    spr:setFrame(midFrame)

    timer.performWithDelay(40, function()
        -- neue Ziffer einrasten lassen
        wheel.digit = newDigit
        spr:setFrame(nextBase)

        if onComplete then onComplete() end
    end)
end

----------------------------------------------------------------
-- um 1 erhöhen (mit mechanischer Animation und Carry-Logik)
----------------------------------------------------------------
function CounterMachine:increment()
    if self.isAnimating then
        self.queue = (self.queue or 0) + 1
        return
    end

    self.isAnimating = true

    local old = self.value or 0
    local new = (old + 1) % 1000
    self.value = new

    local oldOnes     = old % 10
    local oldTens     = math.floor(old / 10)   % 10
    local oldHundreds = math.floor(old / 100)  % 10

    local newOnes     = new % 10
    local newTens     = math.floor(new / 10)   % 10
    local newHundreds = math.floor(new / 100)  % 10

    local function finish()
        if countSound then
            audio.play(countSound)
        end
        self.isAnimating = false

        if self.queue and self.queue > 0 then
            self.queue = self.queue - 1
            self:increment()
        end
    end

    local function animHundreds()
        if oldHundreds ~= newHundreds then
            self:_spinWheelOnce(1, newHundreds, finish)
        else
            finish()
        end
    end

    local function animTens()
        if oldTens ~= newTens then
            self:_spinWheelOnce(2, newTens, animHundreds)
        else
            animHundreds()
        end
    end

    -- Einer-Rolle immer animieren
    self:_spinWheelOnce(3, newOnes, animTens)
end

----------------------------------------------------------------
-- Wert hart setzen (ohne Animation)
----------------------------------------------------------------
function CounterMachine:setValue(n)
    n = math.max(0, math.min(999, math.floor(n or 0)))
    self.value = n

    local ones     = n % 10
    local tens     = math.floor(n / 10) % 10
    local hundreds = math.floor(n / 100) % 10

    self.digits[3].digit = ones
    self.digits[2].digit = tens
    self.digits[1].digit = hundreds

    self:_applyDigitsToSprites()
end

----------------------------------------------------------------
-- Prüfen, ob ein Punkt in der Fangzone des Trichters liegt
-- (großzügiger Bereich um den Trichter herum, auch etwas darunter)
----------------------------------------------------------------
function CounterMachine:isInFunnelArea(x, y)
    -- Mittelpunkt des Trichters in Weltkoordinaten
    local fx = self.group.x + self.funnelX
    local fy = self.group.y + self.funnelY

    -- Breite / Höhe der Fangzone relativ zum Maschinen-Gehäuse
    local halfWidth   = (self.body.width * 0.4)  -- seitlich recht großzügig
    local aboveHeight = (self.body.height * 0.3) -- wie weit nach oben
    local belowHeight = (self.body.height * 0.35) -- wie weit nach unten

    local dx = x - fx
    local dy = y - fy

    return math.abs(dx) <= halfWidth
       and dy >= -aboveHeight
       and dy <= belowHeight
end


----------------------------------------------------------------
-- eine Murmel "schlucken"
-- marble: display-Objekt der Murmel
-- onDone: optionaler Callback nach dem Zählen
----------------------------------------------------------------
function CounterMachine:swallowMarble(marble, onDone)
    if not marble or marble.removed then
        return
    end

    marble.removed = true

    transition.to(marble, {
        time     = 180,
        x        = self.group.x + self.funnelX,
        y        = self.group.y + self.funnelY,
        xScale   = 0.3,
        yScale   = 0.3,
        alpha    = 0.0,
        onComplete = function()
            if marble.removeSelf then
                marble:removeSelf()
            end

            -- Zähler inkrementieren
            self:increment()

            if onDone then
                onDone()
            end
        end
    })
end

return CounterMachine
