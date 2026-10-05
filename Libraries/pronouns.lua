-- By NikoSolstice
local function inOutCubic(t)
	t = t * 2
	if t < 1 then return 0.5 * t^3 end
	t = t - 2
	return 0.5 * (t^3 + 2)
end

local pronouns = "She/Her/Project Moon Fan"
local ANIM_TIME = 40
local pronounsContainer = models.idalia.root:newPart("_prns"):setPos(0,38,0):newPart("a", "CAMERA")
local pronounsText = pronounsContainer:newText("wa"):scale(1/4):setAlignment("CENTER")
pronounsText:setText(toJson({text=pronouns,color=avatar:getColor()})):shadow(true):setSeeThrough(true)

local nameplate_height_offset = 0
local old_nameplate_height_offset = nameplate_height_offset
local timer = 0
local opacity = 0
local oldpacity = opacity

events.TICK:register(function ()
    if client.isModLoaded("wathe") then return end
    local bounding_box = player:getBoundingBox()
    local aabb = {
        player:getPos() - bounding_box.x_z/2,
        player:getPos() + (bounding_box.x_z/2) + bounding_box._y_
    }
    -- aeronautics and getTargetedEntity are not friends.
    -- this works with freecam, too, so...
    local rc = raycast:aabb(client.getCameraPos(), client.getCameraPos() + client.getCameraDir() * 16, {aabb})
    local viewed = ((rc ~= nil) and (client.getCameraEntity() ~= player)) and client.isHudEnabled()

    
    local dir = viewed and 1 or -1
    timer = math.clamp(timer + dir, 0, ANIM_TIME)
    local txt = { 
        {
            text = "— • ",
            color = avatar:getColor(),
        },""
    }
    if opacity > 0.1 then
        for character in string.gmatch(pronouns, "([%z\1-\127\194-\244][\128-\191]*)") do
            local obf = (math.random() > math.min(0.98,(timer-ANIM_TIME/2)/(ANIM_TIME/2)))
            txt[#txt+1] = {
                text = character:gsub("/", " • "),
                obfuscated = obf,
                font = obf and (math.random() > 0.5 and "minecraft:alt" or "minecraft:illageralt") or "minecraft:default"
            }
        end
    end
    
    txt[#txt+1] = " • —"
    pronounsText:setText(toJson(txt))

    old_nameplate_height_offset = nameplate_height_offset
    nameplate_height_offset = (inOutCubic(math.min(1,timer/(ANIM_TIME/2)))*3)
    oldpacity = opacity
    opacity = inOutCubic(math.max(0,timer-ANIM_TIME/2)/(ANIM_TIME/2))
end)

events.RENDER:register(function (delta, ctx, matrix)
    nameplate.ENTITY:setPos(0,math.lerp(old_nameplate_height_offset, nameplate_height_offset, delta)/16,0)
    local o = math.lerp(oldpacity, opacity, delta)
    pronounsText:setOpacity(o):setVisible(o > 0.1)
end)