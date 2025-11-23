-- ui/button.lua
local Button = {}
Button.__index = Button

-- parentGroup: z.B. sceneGroup
-- config: { image, width, height, scale, x, y, onTap }
function Button.new(parentGroup, config)
    assert(parentGroup, "Button.new: parentGroup fehlt")

    local self = setmetatable({}, Button)

    self.image    = config.image
    self.width    = config.width
    self.height   = config.height
    self.scale    = config.scale or 1.0
    self.x        = config.x
    self.y        = config.y
    self.onTap    = config.onTap
    self.disabled = false

    -- Gruppe
    local group = display.newGroup()
    parentGroup:insert(group)
    self.group = group

    -- Hintergrundbild
    local w = self.width * self.scale
    local h = self.height * self.scale

    self.bg = display.newImageRect(group, self.image, w, h)
    self.bg.x, self.bg.y = 0, 0

    -- Tap-Listener direkt auf das sichtbare Objekt
    local function tapListener(event)
        if self.disabled then return true end
        if self.onTap then
            self.onTap(self)
        end
        return true
    end
    self.bg:addEventListener("tap", tapListener)

    -- Position (Center)
    group.x = self.x
    group.y = self.y

    return self
end

function Button:highlight(on)
    if not self.bg then return end
    if on then
        transition.to(self.bg, { time = 80, xScale = 1.05, yScale = 1.05 })
    else
        transition.to(self.bg, { time = 80, xScale = 1.00, yScale = 1.00 })
    end
end

function Button:setEnabled(flag)
    self.disabled = not flag
    if flag then
        self.group.alpha = 1.0
    else
        self.group.alpha = 0.35
    end
end

return Button
