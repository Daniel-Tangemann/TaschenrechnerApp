-- ui/button.lua
-- Generischer Button mit optionalem Text-Label

local Sound = require("sound")  -- 🔊 Soundmodul einbinden

local Button = {}
Button.__index = Button

-- parentGroup: Anzeigegruppe, in die der Button eingesetzt wird
-- opts:
--   image        = Pfad zur Button-Grafik
--   width        = Basisbreite des Bildes
--   height       = Basishöhe des Bildes
--   scale        = Skalierungsfaktor (optional, default 1)
--   x, y         = Position des Button-Gruppenmittelpunkts
--   onTap        = Callback-Funktion bei Tap
--   label        = optionaler Text auf dem Button
--   font         = Schriftart (optional)
--   fontSize     = Schriftgröße (optional)
--   labelOffsetY = vertikaler Offset fürs Label (optional)
--   labelColor   = {r,g,b} (optional)
--   playSound    = true/false (optional, default true)
function Button.new(parentGroup, opts)
    opts = opts or {}

    local self = setmetatable({}, Button)

    -- Obergruppe des Buttons
    local group = display.newGroup()
    parentGroup:insert(group)
    self.group = group

    ----------------------------------------------------
    -- Bild (Button-Hintergrund)
    ----------------------------------------------------
    local img = display.newImageRect(
        group,
        opts.image,
        opts.width,
        opts.height
    )
    img.x, img.y = 0, 0

    local scale = opts.scale or 1.0
    img.xScale = scale
    img.yScale = scale

    -- Effektive Breite/Höhe nach Skalierung merken
    self.width  = opts.width  * scale
    self.height = opts.height * scale
    self.image  = img

    -- Position der Gruppe (damit alles zusammen verschoben wird)
    group.x = opts.x or 0
    group.y = opts.y or 0

    ----------------------------------------------------
    -- Optionales Label
    ----------------------------------------------------
    self.label = nil
    if opts.label then
        local font       = opts.font or native.systemFontBold
        local fontSize   = opts.fontSize or 64
        local offsetY    = opts.labelOffsetY or 0
        local textColor  = opts.labelColor or { 1, 1, 1 }

        local lbl = display.newText({
            parent   = group,
            text     = opts.label,
            x        = 0,
            y        = offsetY,
            font     = font,
            fontSize = fontSize,
            align    = "center",
            width    = self.width * 0.8,
        })
        lbl:setFillColor(textColor[1], textColor[2], textColor[3])

        self.label = lbl
    end

    ----------------------------------------------------
    -- Tap-Interaktion (einfach & zuverlässig)
    ----------------------------------------------------
    if opts.onTap then
        -- Standard: Sound abspielen, außer explizit deaktiviert
        local playSound = (opts.playSound ~= false)

        local function onTap(event)
            if playSound then
                Sound.playKeyBeep()
            end
            opts.onTap()
            return true
        end

        img:addEventListener("tap", onTap)
        self._tapListener = onTap
    end

    return self
end

return Button
