-- sound.lua
local Sound = {}

-- Sounds einmal laden und wiederverwenden
local popSound       = audio.loadSound("sounds/pop.wav")
local explosionSound = audio.loadSound("sounds/explosion.wav")
local keyBeep = audio.loadSound("sounds/key_beep.wav")

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

return Sound
