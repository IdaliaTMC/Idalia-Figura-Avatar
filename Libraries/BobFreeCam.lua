-- By BobIsBilly
local module = {}

local freecam = models.idalia.WORLD.Freecam
freecam:setPrimaryRenderType("CUTOUT_CULL")

local nametagHolder = freecam:newPart("nametagHolder", "Camera")

local nametag = nametagHolder:newText("nametag"):background(true):setAlignment("CENTER"):pos(0, 15, 0)
	:scale(0.5)

local lastTime = client.getSystemTime()

freecamPos = vec(0, 0, 0)
local freecamRot = vec(0, 0)
local freecamIsVisible = false

module.returnPos = vec(0, 0, 0)
module.isVisible = false

events.render:register(function()
	if not player:isLoaded() then return end

	local now = client.getSystemTime()
	local dt = (now - lastTime) / 1000
	lastTime = now

	local t = 1 - math.exp(-10 * dt)

	freecam:setVisible(freecamIsVisible)

	freecam:setPos(math.lerp(freecam:getPos(), freecamPos, t))

	freecam:setOffsetRot(math.lerpAngle(freecam:getOffsetRot().x, -freecamRot.x, t),
		math.lerpAngle(freecam:getOffsetRot().y, -freecamRot.y, t), 0)

	nametag:setText("Idalia's K Corp Drone")
end, "client-render")

local isSending = false
local once = true

events.tick:register(function()
	if not host:isHost() then return end

	if world.getTime() % 3 == 0 and isSending and (freecamPos ~= (client.getCameraPos() * 100):floor() / 100 * 16 or freecamRot ~= vec((client.getCameraRot()):floor().x, (client.getCameraRot()):floor().y, 0)) then
		local pos = (client.getCameraPos() * 100):floor()
		local rot = (client.getCameraRot().xy):floor()
		pings.freecam(pos.x, pos.y, pos.z, rot.x, rot.y, true)
		once = true
	elseif once == true and isSending == false then
		pings.freecam()
		once = false
	end

	if client.getCameraEntity():getName() ~= avatar:getEntityName() then
		isSending = true
	else
		isSending = false
	end

	if world.getTime() % 70 == 0 then
		local pos = (client.getCameraPos() * 100):floor()
		local rot = (client.getCameraRot().xy):floor()

		if client.getCameraEntity():getName() == avatar:getEntityName() then
			pings.syncFreecam()
		else
			pings.syncFreecam(pos.x, pos.y, pos.z, rot.x, rot.y,
				client.getCameraEntity():getName() ~= avatar:getEntityName())
		end
	end
end, "ping-handler")

function pings.freecam(x, y, z, yaw, pitch, isVisible)
	if not player:isLoaded() then return end

	if x == nil then
		x, y, z = 0, 0, 0

		yaw, pitch = 0, 0
	end

	freecamPos = vec(x, y, z) / 100 * 16

	freecamRot = vec(yaw, pitch, 0)

	freecamIsVisible = isVisible

	module.returnPos = vec(x, y, z) / 100
	module.isVisible = isVisible
end

function pings.syncFreecam(x, y, z, yaw, pitch, isVisible)
	if not player:isLoaded() then return end

	if x == nil then
		x, y, z = 0, 0, 0

		yaw, pitch = 0, 0
	end

	freecamPos = vec(x, y, z) / 100 * 16

	freecamRot = vec(yaw, pitch, 0)

	freecamIsVisible = isVisible
end

return module
