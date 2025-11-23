-- lang/en.lua
-- English texts for the app

local M = {

    -- General
    app_title = "Math Calculator",

    -- Calculator Scene
    calc_title = "Calculator",
    help_calculator = "Enter a task and press '=' or let the app generate a task automatically.\nThe first number may have two digits, the second only one digit, and only two numbers can be combined with one operator. Examples: 3+4 and 12*3\nFor division, the number on the left must be greater than the number on the right.\nEach operation (+ - * /) has its own mini-game.",

    -- Addition Minigame
    add_title = "Addition",
    help_add = "Drag the marbles into the lower field.\nA counter counts along (the triangle in the middle).\nWhen all marbles are inside the lower field, you can read the result from the counter.",

    -- Subtraction Minigame
    sub_title = "Subtraction",
    help_sub = "First drag marbles from the left to the right until all empty spots are filled.\nThen drag the remaining marbles into the lower field.\nWhen all marbles are inside the lower field, you can read the result from the counter.",

    -- Multiplication Minigame
    mul_title = "Multiplication",
    help_mul = "Drag the marbles from the left into the cloning machine.\nThe marble and its clones will automatically fall into the lower field.\nWhen all marbles are inside the lower field, you can read the result from the counter.",

    -- Division Minigame
    div_title = "Division",
    help_div = "Drag the marbles into the lower field.\nA counter counts along (the triangle in the middle).\nWhen all marbles are inside the lower field, you can read the result from the counter.\nIf the division does not work out evenly, the remaining marbles move into the right field, which shows the remainder.",

    -- Errors
    error_div_zero = "Division by zero is not allowed!",

    -- Settings Menu
    settings_title = "Settings",
    settings_language = "Language",
    settings_back = "Back",

    -- Language Names
    lang_de = "German",
    lang_en = "English",
    lang_es = "Spanish",
    lang_fr = "French",
}

return M
