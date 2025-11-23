-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

local composer = require("composer")
local i18n = require("lang.i18n")
i18n.load("de")  -- oder aus Settings

-- Erste Szene: Taschenrechner
composer.gotoScene("scenes.taschenrechner")
