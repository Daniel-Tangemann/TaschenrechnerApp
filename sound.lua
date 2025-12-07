-- sound.lua
local Sound = {}

-- Sounds einmal laden und wiederverwenden
local popSound       = audio.loadSound("sounds/pop.wav")
local explosionSound = audio.loadSound("sounds/explosion.wav")
local keyBeep = audio.loadSound("sounds/key_beep.wav")
local correct = audio.loadSound("sounds/correct.wav")
local ding = audio.loadSound("sounds/ding.wav")

function Sound.playPop()
    audio.play(popSound)
end

function Sound.playExplosion()
    audio.play(explosionSound)
end

function Sound.playKeyBeep()
    if keyBeep then
        audio.play(keyBeep)
    end
end

function Sound.playCorrect()
    if correct then
        audio.play(correct)
    end
end

function Sound.playDing()
    audio.play(ding)
end

return Sound
