-- lang/fr.lua
-- Textes français pour l'application

local M = {

    -- General
    app_title = "Calculatrice mathématique",

    -- Calculator Scene
    calc_title = "Calculatrice",
    help_calculator = "Saisis une opération puis appuie sur '=' ou laisse l'application en générer une automatiquement.\nLe premier nombre peut avoir deux chiffres, le second seulement un, et deux nombres ne peuvent être combinés qu'avec un seul opérateur. Exemples : 3+4 et 12*3\nPour la division, le nombre de gauche doit être plus grand que celui de droite.\nChaque opération (+ - * /) possède son propre mini-jeu.",

    -- Addition Minigame
    add_title = "Addition",
    help_add = "Fais glisser les billes dans la zone inférieure.\nUn compteur compte (le triangle au centre).\nLorsque toutes les billes sont dans la zone inférieure, tu peux lire le résultat sur le compteur.",

    -- Subtraction Minigame
    sub_title = "Soustraction",
    help_sub = "Commence par faire glisser des billes de gauche à droite jusqu'à ce que toutes les cases vides soient remplies.\nEnsuite, fais glisser les billes restantes dans la zone inférieure.\nLorsque toutes les billes sont dans la zone inférieure, tu peux lire le résultat sur le compteur.",

    -- Multiplication Minigame
    mul_title = "Multiplication",
    help_mul = "Fais glisser les billes de gauche dans la machine à clonage.\nLa bille et ses clones tomberont automatiquement dans la zone inférieure.\nLorsque toutes les billes sont dans la zone inférieure, tu peux lire le résultat sur le compteur.",

    -- Division Minigame
    div_title = "Division",
    help_div = "Fais glisser les billes dans la zone inférieure.\nUn compteur compte (le triangle au centre).\nLorsque toutes les billes sont dans la zone inférieure, tu peux lire le résultat sur le compteur.\nSi la division n'est pas exacte, les billes restantes iront dans la zone de droite, où s'affiche le reste.",

    -- Errors
    error_div_zero = "La division par zéro n'est pas autorisée.",

    -- Settings Menu
    settings_title = "Paramètres",
    settings_language = "Langue",
    settings_back = "Retour",

    -- Language Names
    lang_de = "Allemand",
    lang_en = "Anglais",
    lang_es = "Espagnol",
    lang_fr = "Français",

    -- Dividieren: Rest-Anzeige
    div_re_text = "Le reste: ",
}

return M
