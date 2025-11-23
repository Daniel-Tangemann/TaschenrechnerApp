-- lang/i18n.lua
-- Einfaches Internationalisierungs-Modul

local i18n = {
    current = "de",
    strings = {},
    fallback = "de",
}

-- Welche Sprachen es gibt (für Settings-Menü)
i18n.available = {
    "de",
    "en",
    "es",
    "fr",
}

-- Optionale Anzeigenamen für UI
i18n.languageNames = {
    de = "Deutsch",
    en = "English",
    es = "Español",
    fr = "Français",
}

-- Sprache laden
function i18n.load(lang)
    lang = lang or i18n.fallback

    local ok, data = pcall(require, "lang." .. lang)
    if not ok or type(data) ~= "table" then
        -- Fallback auf Deutsch
        local ok2, fallbackData = pcall(require, "lang." .. i18n.fallback)
        if ok2 and type(fallbackData) == "table" then
            i18n.current = i18n.fallback
            i18n.strings = fallbackData
        end
        return
    end

    i18n.current = lang
    i18n.strings = data
end

-- Übersetzung holen
function i18n.t(key)
    if i18n.strings and i18n.strings[key] then
        return i18n.strings[key]
    end
    -- Fallback versuchen
    if i18n.current ~= i18n.fallback then
        local ok, fallbackData = pcall(require, "lang." .. i18n.fallback)
        if ok and fallbackData[key] then
            return fallbackData[key]
        end
    end
    -- Wenn gar nichts gefunden → Key anzeigen
    return "[" .. key .. "]"
end

return i18n
