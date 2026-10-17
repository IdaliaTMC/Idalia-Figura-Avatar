-- Idalia chat typing controller for Figura
-- elp me its so late my mind says yes but my body, my body wants me to dance haztha hatzha hazata aaaata


local T = {
    started = false,
    open = false,

    -- Normalized position along typingHorizontal (0 = left... or right, 1 = end).
    current = 0.50,
    previous = 0.50,
    target = 0.50,

    queue = {},
    moving = false,
    waitingForPress = false,
    pressEffectFired = false,

    -- Typing tuning ---------------------------------------------------------
    ease = 0.90,
    arrive = 0.072,
    randomMin = 0.01,
    randomMax = 0.99,
    minRandomJump = 0.10,
    maxQueue = 12,

    -- typingHorizontal stays on the selected key until typingPress reaches
    -- this animation time. The particle fires at that SAME release point.
    pressHoldSeconds = 0.50,

    -- Particle tuning ------------------------------------------------------
    pressParticleEnabled = true,
    pressParticleId = "minecraft:enchanted_hit",

    pressParticleScale = 1.0,
    pressParticleColor = vec(1, 0, 0),

    pressParticleOffsetPixels = vec(0, 0, 0),

    pressParticleSpreadPixels = vec(50, 30, 50),

    
    pressParticleVelocity = vec(0, 0, 0),
    pressParticleGravity = 0,
    pressParticlePhysics = false,
    pressParticleLifetime = nil,

    -- Sound tuning ----------------------------------------------------------
    pressSoundEnabled = true,
    pressSoundId = "minecraft:entity.chicken.step",
    pressSoundVolume = 0.35,
    pressSoundPitch = 0.8,

    reverseStartOnClose = true,
}

local function animRoot()
    return animations and animations.idalia
end

local function getAnimations()
    local root = animRoot()
    if not root then return nil, nil, nil end
    return root.typingStart, root.typingHorizontal, root.typingPress
end

local function getParticleEmitter()
    local ok, emitter = pcall(function()
        return models.idalia.root.Body.RightArm.RightAim.RightLowerArm.ParticleEmitter
    end)
    if not ok then return nil end
    return emitter
end

local function clamp01(v)
    return math.max(0, math.min(1, tonumber(v) or 0))
end

local function horizontalLength()
    local _, horizontal = getAnimations()
    if not horizontal then return 0 end
    local ok, length = pcall(function() return horizontal:getLength() end)
    if not ok then return 0 end
    return math.max(0, tonumber(length) or 0)
end

local function applyHorizontal(normalized)
    local _, horizontal = getAnimations()
    if not horizontal then return end

    local length = horizontalLength()
    if length <= 0 then return end

    local t = clamp01(normalized) * length
    pcall(function()
        horizontal:setLoop("HOLD")
        horizontal:setSpeed(0)
        if not horizontal:isPlaying() then horizontal:play() end
        horizontal:setTime(t)
    end)
end

local function playTypingPress()
    local _, _, press = getAnimations()
    if not press then return end

    -- One particle is allowed again for this new press.
    T.pressEffectFired = false

    pcall(function()
        press:stop()
        press:setSpeed(1)
        press:setLoop("ONCE")
        press:setTime(0)
        press:restart()
    end)
end

local function randomSigned(amount)
    amount = tonumber(amount) or 0
    if amount == 0 then return 0 end
    return (math.random() * 2 - 1) * amount
end

local function emitPressParticle()
    if T.pressEffectFired then return end
    T.pressEffectFired = true

    if T.pressParticleEnabled == false then return end

    local emitter = getParticleEmitter()
    if not emitter then return end

    local offset = T.pressParticleOffsetPixels or vec(0, 0, 0)
    local spread = T.pressParticleSpreadPixels or vec(0, 0, 0)

    local localOffsetPixels = vec(
        (tonumber(offset.x) or 0) + randomSigned(spread.x),
        (tonumber(offset.y) or 0) + randomSigned(spread.y),
        (tonumber(offset.z) or 0) + randomSigned(spread.z)
    )

    local okPos, pos = pcall(function()
        -- Figura model coordinates are pixels; convert the local offset to blocks.
        return emitter:partToWorldMatrix():apply(localOffsetPixels / 16)
    end)
    if not okPos or not pos then return end

        -- SOUND --------------------------------------------------------------
    if T.pressSoundEnabled ~= false then
        pcall(function()
            sounds:playSound(
                T.pressSoundId or "minecraft:block.amethyst_block.hit",
                pos,
                tonumber(T.pressSoundVolume) or 0.35,
                tonumber(T.pressSoundPitch) or 1.5,
                false
            )
        end)
    end

    local id = T.pressParticleId or "minecraft:enchanted_hit"
    local scale = math.max(0, tonumber(T.pressParticleScale) or 2.0)
    local color = T.pressParticleColor or vec(1, 0, 0)
    local velocity = T.pressParticleVelocity or vec(0, 0, 0)
    
    -- undead, ffs don't make this into a tuning- I DID IT, THEY SAID I COULDN'T- BUT NOW THEY'RE TUNEABLES AHAHA
    -- configure a single reusable particle definition and spawn it.
    -- optional setters are protected so they cannot interrupt the typing
    -- controller if a Figura version/particle does not support one of them.
    pcall(function()
        local particle = particles[id]

        particle:pos(pos)
        particle:scale(scale)
        particle:color(color)
        particle:velocity(velocity)

        if T.pressParticleGravity ~= nil then
            pcall(function() particle:gravity(T.pressParticleGravity) end)
        end

        if T.pressParticlePhysics ~= nil then
            pcall(function() particle:physics(T.pressParticlePhysics) end)
        end

        if T.pressParticleLifetime ~= nil then
            pcall(function() particle:lifetime(T.pressParticleLifetime) end)
        end

        particle:spawn()
    end)
end

local function pressHoldFinished()
    if not T.waitingForPress then
        return true
    end

    local _, _, press = getAnimations()
    if not press then
        return true
    end

    local ok, time, length, playing = pcall(function()
        return
            tonumber(press:getTime()) or 0,
            tonumber(press:getLength()) or 0,
            press:isPlaying()
    end)

    if not ok then
        return true
    end

    local required = math.max(0, tonumber(T.pressHoldSeconds) or 0.60)

    if length > 0 then
        required = math.min(required, length)
    end

    local finished = time >= required or playing == false

    if finished then
        
        -- so.. i'm trying to make this run side by side of the animation which was also my intend to 
        -- begin with but i might've messed that up in the previous attempt
        emitPressParticle()
        return true
    end

    return false
end

local function openTyping()
    if T.open then return end
    T.open = true
    T.queue = {}
    T.moving = false
    T.waitingForPress = false
    T.pressEffectFired = false
    T.current = 0.50
    T.previous = T.current
    T.target = T.current

    local start, horizontal, press = getAnimations()

    if press then
        pcall(function() press:stop() end)
    end

    if horizontal then
        pcall(function()
            horizontal:stop()
            horizontal:setLoop("HOLD")
            horizontal:setSpeed(0)
            horizontal:setTime(horizontal:getLength() * T.current)
            horizontal:play()
        end)
    end

    if start then
        pcall(function()
            start:stop()
            start:setLoop("HOLD")
            start:setSpeed(1)
            start:setTime(0)
            start:restart()
        end)
    end
end

local function closeTyping()
    if not T.open then return end
    T.open = false
    T.queue = {}
    T.moving = false
    T.waitingForPress = false
    T.pressEffectFired = false

    local start, horizontal, press = getAnimations()

    if press then
        pcall(function() press:stop() end)
    end

    if horizontal then
        pcall(function()
            horizontal:stop()
            horizontal:setSpeed(1)
            horizontal:setTime(0)
        end)
    end

    if start then
        if T.reverseStartOnClose then
            pcall(function()
                local length = math.max(0, tonumber(start:getLength()) or 0)
                local current = tonumber(start:getTime()) or length
                if current <= 0.001 then current = length end

                start:stop()
                start:setLoop("ONCE")
                start:setSpeed(-1)
                start:setTime(math.max(0, math.min(length, current)))
                start:play()
            end)
        else
            pcall(function()
                start:stop()
                start:setSpeed(1)
                start:setTime(0)
            end)
        end
    end
end

local function enqueueTarget(value)
    value = math.max(T.randomMin, math.min(T.randomMax, tonumber(value) or 0.5))

    if #T.queue >= T.maxQueue then
        table.remove(T.queue, 1)
    end

    T.queue[#T.queue + 1] = value
end

function pings.idalia_typing_state(open)
    if open == true then
        openTyping()
    else
        closeTyping()
    end
end

function pings.idalia_typing_target(value)
    if not T.open then openTyping() end
    enqueueTarget(value)
end

local lastRandomTarget = 0.50

-- Local deterministic RNG for typing only.
local typingRandomSecond = nil
local typingRandomState = 1
local typingRandomSerial = 0

local function worldSecond()
    local ok, ticks = pcall(function() return world.getTime() end)
    ticks = ok and tonumber(ticks) or 0
    return math.floor((ticks or 0) / 20)
end

local function reseedTypingRandom()
    local second = worldSecond()
    if second ~= typingRandomSecond then
        typingRandomSecond = second
        typingRandomSerial = 0

        typingRandomState = (second * 1103515245 + 12345) % 2147483648
        if typingRandomState == 0 then typingRandomState = 1 end
    end
end

local function typingRandom()
    reseedTypingRandom()
    typingRandomSerial = typingRandomSerial + 1

    typingRandomState = (
        typingRandomState * 1103515245
        + 12345
        + typingRandomSerial * 1013904223
    ) % 2147483648

    return typingRandomState / 2147483648
end

local function randomTarget()
    local lo = T.randomMin
    local hi = T.randomMax
    local value = lo + (hi - lo) * typingRandom()

    for _ = 1, 5 do
        if math.abs(value - lastRandomTarget) >= T.minRandomJump then break end
        value = lo + (hi - lo) * typingRandom()
    end

    lastRandomTarget = value
    return value
end

local function tickController()
    T.previous = T.current

    if not T.open then return end

    -- This is intentionally the original controller flow.
    if T.waitingForPress then
        if not pressHoldFinished() then
            return
        end

        T.waitingForPress = false
    end

    -- snappy snap with the fingies and such- 
    -- first ease step happens immediately in this same tick.
    if not T.moving then
        local nextTarget = table.remove(T.queue, 1)
        if nextTarget == nil then return end

        T.target = nextTarget
        T.moving = true
    end

    local difference = T.target - T.current
    T.current = T.current + difference * T.ease

    if math.abs(T.target - T.current) <= T.arrive then
        T.current = T.target
        T.previous = T.current
        T.moving = false

        T.waitingForPress = true
        playTypingPress()
    end
end

local lastHostChatState = false

local function hostStateTick()
    if not host:isHost() then return end

    local open = host:isChatOpen() == true
    if open ~= lastHostChatState then
        lastHostChatState = open
        pings.idalia_typing_state(open)
    end
end

local function onCharacterTyped(character)
    if not host:isHost() then return end
    if not host:isChatOpen() then return end
    if type(character) ~= "string" or character == "" then return end

    pings.idalia_typing_target(randomTarget())
end

function T.start()
    if T.started then return T end
    T.started = true

    events.TICK:register(hostStateTick, "idalia_typing_chat_state")
    events.TICK:register(tickController, "idalia_typing_controller")

    events.RENDER:register(function(delta)
        if not T.open then return end
        local d = math.max(0, math.min(1, tonumber(delta) or 0))
        applyHorizontal(T.previous + (T.current - T.previous) * d)
    end, "idalia_typing_horizontal_render")

    events.CHAR_TYPED:register(onCharacterTyped, "idalia_typing_character")

    return T
end

return T