-- sound.lua
local Sound = {}

-- Sounds einmal laden und wiederverwenden
local popSound       = audio.loadSound("sounds/pop.wav")
local explosionSound = audio.loadSound("sounds/explosion.wav")

function Sound.playPop()
    audio.play(popSound)
end

function Sound.playExplosion()
    audio.play(explosionSound)
end

return Sound
