-- ui/display.lua
-- Display-Modul für den Taschenrechner-Screen
-- Verwendet numbers.png (0–9 in 2 Reihen à 5) und operators.png (+ - * /)

local layout = require("layout")

local Display = {}
Display.__index = Display

------------------------------------------------------------------
-- Konfiguration für das Zahlen-SpriteSheet
------------------------------------------------------------------
-- numbers.png: 1743 x 949, 2 Reihen, 5 Spalten
local DIGIT_SHEET_W  = 1743
local DIGIT_SHEET_H  = 949
local DIGIT_COLS     = 5
local DIGIT_ROWS     = 2
local DIGIT_FRAME_W  = 348            -- 1743 / 5 = 348.6
local DIGIT_FRAME_H  = 474            -- 949 / 2 = 474.5

-- operators.png: 616 x 164, 4 Symbole in einer Reihe
local OP_SHEET_W     = 616
local OP_SHEET_H     = 164
local OP_COLS        = 4
local OP_FRAME_W     = 154           -- 616 / 4 = 154
local OP_FRAME_H     = 164

------------------------------------------------------------------
-- Hilfsfunktion: Sheet für Ziffern + Operatoren erstellen
------------------------------------------------------------------
local function createNumberSheet()
    local options = {
        width              = DIGIT_FRAME_W,
        height             = DIGIT_FRAME_H,
        numFrames          = 10,
        sheetContentWidth  = DIGIT_SHEET_W,
        sheetContentHeight = DIGIT_SHEET_H,
    }
    local sheet = graphics.newImageSheet("imgs/numbers.png", options)
    local seq = {
        { name="digits", start=1, count=10, time=0 }
    }
    return sheet, seq
end

local function createOperatorSheet()
    local options = {
        width              = OP_FRAME_W,
        height             = OP_FRAME_H,
        numFrames          = 4,
        sheetContentWidth  = OP_SHEET_W,
        sheetContentHeight = OP_SHEET_H,
    }
    local sheet = graphics.newImageSheet("imgs/operators.png", options)
    local seq = {
        { name="ops", start=1, count=4, time=0 }
    }
    return sheet, seq
end

------------------------------------------------------------------
-- Konstruktor
------------------------------------------------------------------
function Display.new(parentGroup)
    local self = setmetatable({}, Display)

    local cfg = layout.screen
    local cx, cy = layout.toCenter(cfg)

    -- Obergruppe für alles im Display
    self.group = display.newGroup()
    parentGroup:insert(self.group)
    self.group.x, self.group.y = cx, cy

    --------------------------------------------------------
    -- Hintergrund (screen.png)
    --------------------------------------------------------
    local w = cfg.width * (cfg.scale or 1.0)
    local h = cfg.height * (cfg.scale or 1.0)

    self.bg = display.newImageRect(self.group, "imgs/screen.png", w, h)
    self.bg.x, self.bg.y = 0, 0

    --------------------------------------------------------
    -- Ziffern- und Operator-Sprites
    --------------------------------------------------------
    -- Feintuning der Operator-Positionen (pro Frame)
    -- Frames: 1="+", 2="*", 3="-", 4="/"
    self.opOffsets = {
        [1] = -5,   -- + 
        [2] = -2,   -- ×
        [3] = 0,   -- -
        [4] = 7,   -- ÷
    }

    local numberSheet, numberSeq = createNumberSheet()
    local opSheet, opSeq = createOperatorSheet()

    self.digitSheet   = numberSheet
    self.digitSeqData = numberSeq
    self.opSheet      = opSheet
    self.opSeqData    = opSeq

    -- Ziel: max. 4 „Slots“: [D1][D2][OP][D3]
    -- Wir nehmen 3 Ziffern-Sprites + 1 Operator-Sprite.

    -- Ziffern skalieren wir relativ zur Display-Höhe:
    local digitScale = (h * 0.45) / DIGIT_FRAME_H    -- ~45% der Display-Höhe
    self.digitScale = digitScale

    local glyphW = DIGIT_FRAME_W * digitScale
    local slotSpacing = glyphW * 1.05

    -- Wir definieren 4 Slot-X-Positionen:
    -- [Slot1][Slot2][Slot3][Slot4] = [D1][D2][OP][D3]
    local yPos  = -h * 0.05

    local shiftX = 0   -- ggf. nach links/rechts schieben

    local slotX = {
        -1.5 * slotSpacing + shiftX,
        -0.5 * slotSpacing + shiftX,
        0.5 * slotSpacing + shiftX,
        1.5 * slotSpacing + shiftX,
    }

    self.slotX = slotX
    self.slotY = yPos

    --------------------------------------------------------
    -- Platzhalter (graue 8-8-Operator-8) im Hintergrund
    --------------------------------------------------------
    self.placeholderGroup = display.newGroup()
    self.group:insert(self.placeholderGroup)  -- kommt direkt vor Ziffern/Operatoren

    self.placeholderDigits = {}

    local function makeDigitPlaceholder(slotIndex)
        local spr = display.newSprite(self.placeholderGroup, self.digitSheet, self.digitSeqData)
        spr.x = slotX[slotIndex]
        spr.y = yPos
        spr.xScale, spr.yScale = digitScale, digitScale
        -- 8 → Frame 9 (0..9 → 1..10)
        spr:setFrame(8 + 1)
        spr:setFillColor(1, 1, 1, 0.18)  -- hell & leicht transparent
        self.placeholderDigits[#self.placeholderDigits + 1] = spr
    end

    -- D1, D2, D3 als 8
    makeDigitPlaceholder(1)
    makeDigitPlaceholder(2)
    makeDigitPlaceholder(4)

    --------------------------------------------------------
    -- Operator-Platzhalter: dezentes Grau-Rechteck
    --------------------------------------------------------
    local opPlaceholderRect = display.newRoundedRect(
        self.placeholderGroup,
        slotX[3],
        yPos,
        OP_FRAME_W,   -- Breite etwa passend zu einer Ziffer
        OP_FRAME_H,   -- Höhe passend
        20                                   -- leichte Rundung
    )

    -- dezentes Grau, wie die Ziffern-Platzhalter
    opPlaceholderRect:setFillColor(0, 0, 1, 0.18)
    self.opPlaceholderRect = opPlaceholderRect



    --------------------------------------------------------
    -- Aktive Ziffern- und Operator-Sprites (liegen über den Platzhaltern)
    --------------------------------------------------------
    self.digitSprites = {}

    -- D1 (links)
    local spr1 = display.newSprite(self.group, self.digitSheet, self.digitSeqData)
    spr1.x = slotX[1]
    spr1.y = yPos
    spr1.xScale, spr1.yScale = digitScale, digitScale
    spr1.isVisible = false
    self.digitSprites[1] = spr1

    -- D2 (mittlere linke)
    local spr2 = display.newSprite(self.group, self.digitSheet, self.digitSeqData)
    spr2.x = slotX[2]
    spr2.y = yPos
    spr2.xScale, spr2.yScale = digitScale, digitScale
    spr2.isVisible = false
    self.digitSprites[2] = spr2

    -- D3 (rechte Ziffer, nach dem Operator)
    local spr3 = display.newSprite(self.group, self.digitSheet, self.digitSeqData)
    spr3.x = slotX[4]   -- wichtig: Slot 4!
    spr3.y = yPos
    spr3.xScale, spr3.yScale = digitScale, digitScale
    spr3.isVisible = false
    self.digitSprites[3] = spr3

    -- Operator-Sprite in Slot 3
    self.opSprite = display.newSprite(self.group, self.opSheet, self.opSeqData)
    self.opSprite.baseX = slotX[3]   -- speichern die Grundposition
    self.opSprite.y     = yPos
    self.opSprite.x     = self.opSprite.baseX   -- initial

    -- Operator-Skalierung
    local opScale = self.digitScale * 2
    self.opSprite.xScale = opScale
    self.opSprite.yScale = opScale
    self.opSprite.isVisible = false

    --------------------------------------------------------
    -- Optionale Textanzeige für Fehler / Debug (klein)
    --------------------------------------------------------
    self.errorText = display.newText({
        parent   = self.group,
        text     = "",
        x        = 0,
        y        = h * 0.25,
        font     = native.systemFontBold,
        fontSize = 48,
        align    = "center",
        width    = w * 0.8,
    })
    self.errorText:setFillColor(1, 0.2, 0.2)
    self.errorText.isVisible = false

    return self
end

------------------------------------------------------------------
-- interne Helfer zum Setzen von Ziffern / Operator
------------------------------------------------------------------
local function setDigitSprite(self, index, digitChar)
    local spr = self.digitSprites[index]
    if not spr then return end

    if not digitChar or digitChar == "" then
        spr.isVisible = false
        return
    end

    local d = tonumber(digitChar)
    if not d or d < 0 or d > 9 then
        spr.isVisible = false
        return
    end

    spr:setFrame(d + 1)   -- Frames 1..10 entsprechen 0..9
    spr.isVisible = true
end

local function setOperatorSprite(self, opChar)
    if not self.opSprite then return end
    if not opChar or opChar == "" then
        self.opSprite.isVisible = false
        return
    end

    local frameIndex = nil
    if opChar == "+" then frameIndex = 1 end
    if opChar == "*" then frameIndex = 2 end
    if opChar == "-" then frameIndex = 3 end
    if opChar == "/" then frameIndex = 4 end

    if frameIndex then
        self.opSprite:setFrame(frameIndex)
        self.opSprite.isVisible = true

        -- X-Offset anwenden
        local off = self.opOffsets[frameIndex] or 0
        self.opSprite.x = self.opSprite.baseX + off
    else
        self.opSprite.isVisible = false
    end

end

------------------------------------------------------------------
-- API: Ausdruck setzen
-- left: String, max. 2 Ziffern
-- op:   "+", "-", "*", "/"
-- right:String, max. 1 Ziffer
------------------------------------------------------------------
function Display:setExpression(left, op, right)
    left  = left  or ""
    op    = op    or ""
    right = right or ""

    -- Fehlertext ausblenden, wenn wir normalen Ausdruck setzen
    self.errorText.isVisible = false

    -- Alle aktiven Sprites ausblenden
    setDigitSprite(self, 1, nil)
    setDigitSprite(self, 2, nil)
    setDigitSprite(self, 3, nil)
    setOperatorSprite(self, nil)

    -- Linke Zahl: max. 2 Ziffern
    if #left == 1 then
        -- „_ d“
        setDigitSprite(self, 1, nil)
        setDigitSprite(self, 2, left:sub(1,1))
    elseif #left >= 2 then
        -- „d1 d2“
        setDigitSprite(self, 1, left:sub(-2,-2))
        setDigitSprite(self, 2, left:sub(-1))
    end

    -- Operator
    if op ~= "" then
        setOperatorSprite(self, op)
    end

    -- Rechte Zahl: max. 1 Ziffer
    if #right >= 1 then
        setDigitSprite(self, 3, right:sub(-1))
    end
end

------------------------------------------------------------------
-- Ergebnis-API (derzeit ungenutzt)
------------------------------------------------------------------
function Display:setResult(resultStr)
    -- momentan NICHT genutzt – Ergebnis bleibt intern
end

------------------------------------------------------------------
-- Alles zurücksetzen (AC)
------------------------------------------------------------------
function Display:clear()
    self.errorText.isVisible = false
    setDigitSprite(self, 1, nil)
    setDigitSprite(self, 2, nil)
    setDigitSprite(self, 3, nil)
    setOperatorSprite(self, nil)
end

------------------------------------------------------------------
-- Fehlerzustand (z.B. Division durch 0)
------------------------------------------------------------------
function Display:setError(msg)
    setDigitSprite(self, 1, nil)
    setDigitSprite(self, 2, nil)
    setDigitSprite(self, 3, nil)
    setOperatorSprite(self, nil)

    self.errorText.text = msg or "ERR"
    self.errorText.isVisible = true
end

function Display:clearError()
    self.errorText.isVisible = false
end

return Display
