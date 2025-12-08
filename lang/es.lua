-- lang/es.lua
-- Textos en español para la aplicación

local M = {

    -- General
    app_title = "Calculadora de matemáticas",

    -- Calculator Scene
    calc_title = "Calculadora",
    help_calculator = "Introduce una operación y pulsa '=' o deja que la aplicación genere una automáticamente.\nEl primer número puede tener dos cifras, el segundo solo una, y solo se pueden combinar dos números con un operador. Ejemplos: 3+4 y 12*3\nPara la división, el número de la izquierda debe ser mayor que el de la derecha.\nCada operación (+ - * /) tiene su propio minijuego.",

    -- Addition Minigame
    add_title = "Suma",
    help_add = "Arrastra las canicas al campo inferior.\nUn contador va contando (el triángulo en el centro).\nCuando todas las canicas estén en el campo inferior, podrás leer el resultado en el contador.",

    -- Subtraction Minigame
    sub_title = "Resta",
    help_sub = "Primero arrastra canicas de la izquierda a la derecha hasta que todos los huecos estén llenos.\nLuego arrastra las canicas restantes al campo inferior.\nCuando todas las canicas estén en el campo inferior, podrás leer el resultado en el contador.",

    -- Multiplication Minigame
    mul_title = "Multiplicación",
    help_mul = "Arrastra las canicas de la izquierda a la máquina de clonación.\nLa canica y sus clones caerán automáticamente al campo inferior.\nCuando todas las canicas estén en el campo inferior, podrás leer el resultado en el contador.",

    -- Division Minigame
    div_title = "División",
    help_div = "Arrastra las canicas al campo inferior.\nUn contador va contando (el triángulo en el centro).\nCuando todas las canicas estén en el campo inferior, podrás leer el resultado en el contador.\nSi la división no es exacta, las canicas restantes se moverán al campo derecho, donde aparece el resto.",

    -- Errors
    error_div_zero = "¡No se permite dividir entre cero!",

    -- Settings Menu
    settings_title = "Ajustes",
    settings_language = "Idioma",
    settings_back = "Atrás",

    -- Language Names
    lang_de = "Alemán",
    lang_en = "Inglés",
    lang_es = "Español",
    lang_fr = "Francés",

    -- Dividieren: Rest-Anzeige
    div_re_text = "El residuo: ",
}

return M
