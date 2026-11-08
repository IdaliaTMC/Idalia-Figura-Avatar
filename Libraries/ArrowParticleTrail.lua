-- Swordslash arrow trail 
-- I overcomplicated this to begin with..
-- distance from center, like in blockbench its 32 units but i dunno how much that is in blocks..
-- this looks like its the correct offset
local TRAIL_OFFSET = 1.6
local SLASH_ANGLE = math.rad(45 - 70)

function events.arrow_render(delta, arrow)
    local velocity = arrow:getVelocity()
    if velocity:length() <= 0.0001 then return true end

    local pos = arrow:getPos(delta)
    local forward = velocity:normalized()

    local side = forward:crossed(vec(0, 1, 0))

    if side:length() <= 0.0001 then
        side = forward:crossed(vec(1, 0, 0))
    end

    side = side:normalized()
    local up = side:crossed(forward):normalized()

    local offset =
        (side * math.cos(SLASH_ANGLE)
        + up * math.sin(SLASH_ANGLE))
        * TRAIL_OFFSET

    particles["minecraft:end_rod"]
        :pos(pos + offset)
        :scale(1)
        :color(1, 1, 0)
        :spawn()

    particles["minecraft:end_rod"]
        :pos(pos - offset)
        :scale(1)
        :color(1, 1, 0)
        :spawn()
end
