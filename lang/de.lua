-- lang/de.lua
-- Deutsche Texte für die App

local M = {

    -- Allgemein
    app_title = "Mathe-Taschenrechner",

    -- Taschenrechner-Szene
    calc_title = "Taschenrechner",
    help_calculator = "Gib eine Aufgabe ein und drücke auf '=' oder lass dir eine Aufgabe automatisch generieren.\nDie erste Zahl kann zweistellig sein, die zweite nur einstellig und nur zwei Zahlen werden über ein Rechenzeichen verbunden. Beispiele: 3+4 und 12*3\nBei Division (geteilt durch) muss die linke Zahl größer sein als die Rechte.\nFür jede Rechenoperation (+ - * /) gibt es ein Minispiel.",

    -- Addieren-Minigame
    add_title = "Addieren",
    help_add = "Ziehe die Murmeln in das untere Feld.\nein Zähler zählt mit (das Dreieck in der Mitte).\nWenn alle Murmeln unten drin sind kannst du das Ergebnis am Zähler ablesen.",

    -- Subtrahieren-Minigame
    sub_title = "Subtrahieren",
    help_sub = "Ziehe zunächst Murmeln von links nach rechts bis alle leeren Plätze aufgebraucht sind.\nDann zieh die übrigen Murmeln in das untere Feld.\nWenn alle Murmeln unten drin sind kannst du das Ergebnis am Zähler ablesen.",

    -- Multiplizieren-Minigame
    mul_title = "Multiplizieren",
    help_mul = "Ziehe die Murmeln von links nach rechts in die Klonmaschiene\nDie Murmel und ihre Klone fallen dann automatisch in das untere Feld.\nWenn alle Murmeln unten drin sind kannst du das Ergebnis am Zähler ablesen.",

    -- Dividieren-Minigame
    div_title = "Dividieren",
    help_div = "Ziehe die Murmeln in das untere Feld.\nein Zähler zählt mit (das Dreieck in der Mitte).\nWenn alle Murmeln unten drin sind kannst du das Ergebnis am Zähler ablesen.\nWenn die Rechnung nicht genau aufgeht, wandern die übrigen Murmeln in das Rechte Feld, wo der Teilungsrest ist.",

    -- Fehlermeldungen
    error_div_zero = "Durch Null teilen ist nicht erlaubt!",

    -- Settings-Menü
    settings_title = "Einstellungen",
    settings_language = "Sprache",
    settings_back = "Zurück",

    -- Sprachnamen (falls du sie im UI anzeigen willst)
    lang_de = "Deutsch",
    lang_en = "Englisch",
    lang_es = "Spanisch",
    lang_fr = "Französisch",

    -- Dividieren: Rest-Anzeige
    div_re_text = "Rest: ",
}

return M
