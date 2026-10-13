local eventpresent, event = pcall(require, "./event") -- GN's event lib (optional)

local CONFIG = {
	callbacks = {
		player = {
			startPat = {},
			stopPat = {},
			onPat = {function()
	        	animations.idalia.Patpat:play()
	        	if 0.5-math.random() > 2 then
	        		sounds:playSound("entity.cat.ambient", player:getPos(), 0.4)
	        	else
	        		sounds:playSound("entity.cat.stray_ambient", player:getPos(), 0.4)
        		end
        	end}
		},
		skull = {
			startPat = {},
			stopPat = {},
			onPat = {function() animations.idalia.HeadPatPat:play() end}
		},
	},
	whitelist = {
		player = {
			"UndeadReturns",
			"Solicitouss",
			"RedDevelop",
			"ItsBobbyYo",
			"Jueunii",
			"TheEpicMelon_",
			"NikoSolstice",
			"Simon255"
		}, -- "ANYONE"|TABLE
		skull = "FOLLOWS_PLAYER", -- "ANYONE"|"FOLLOWS_PLAYER"|TABLE
		is_blacklist = false, -- boolean
	},
	cooldown = 1, -- 1 pat, per person, per tick
	delay = 3, -- 1 pat every 3 ticks
	sneakToPat = true -- boolean
}

local function call(category, key, ...)
	local should_cancel = false
	if eventpresent then
		for index, value in ipairs(CONFIG.callbacks[category][key]:invoke(...)) do
			should_cancel = (value == false) or should_cancel
		end
	else
		for _, method in pairs(CONFIG.callbacks[category][key]) do
			should_cancel = (method(...) == false) or should_cancel
		end
	end
	return not should_cancel
end

local function skullFormat(uuid, x, y, z)
	return uuid .. ";" .. x .. "," .. y .. "," .. z
end

local function skullUnformat(data)
	return data:match("^([^;]+);(%-?[0-9]+),(%-?[0-9]+),(%-?[0-9]+)$")
end

if eventpresent then
	CONFIG.callbacks.player.startPat = event.new()
	CONFIG.callbacks.player.onPat = event.new()
	CONFIG.callbacks.player.stopPat = event.new()
	CONFIG.callbacks.skull.startPat = event.new()
	CONFIG.callbacks.skull.onPat = event.new()
	CONFIG.callbacks.skull.stopPat = event.new()
end

local current_prompter
local session_id = client.intUUIDToString(client.generateUUID())
local function is_valid_session(id)
	return id == session_id
end

local bind = keybinds:fromVanilla("key.use")
local timers = {}
local skullTimers = {}
local patMethods = {}
local entitycooldowns = {}
local skullCooldowns = {}
local validateMethods = {}

local function maybe_validate(uuid)
	local validate = validateMethods[uuid] and (select(2, pcall(validateMethods[uuid]))) or false
	if not validate then
		patMethods[uuid] = nil
	end
	return validate
end

local function whitelisted(person, key)
	local isUuid = pcall(client.uuidToIntArray, person)

	if isUuid then
		if person == avatar:getUUID() then return true end
		local list = CONFIG.whitelist[key]
		if list == "FOLLOWS_PLAYER" then list = CONFIG.whitelist.player end
		if list == "ANYONE" then return true end
		if type(list) ~= "table" then return false end

		---@diagnostic disable-next-line
		for _, uuid in pairs(list) do
			if pcall(client.uuidToIntArray, uuid) then
				if uuid == person then
					return not CONFIG.whitelist.is_blacklist
				end
			else
				if world.getPlayers()[uuid] then
					if world.getPlayers()[uuid]:getUUID() == person then
						return not CONFIG.whitelist.is_blacklist
					end
				end
			end
		end

		return CONFIG.whitelist.is_blacklist
	else
		return world.getPlayers()[person] and whitelisted(world.getPlayers()[person]:getUUID(), key) or false
	end
end

local function current_session_valid()
	local vars = world.avatarVars()[avatar:getUUID()] or {}
	if vars.PatCubed and vars.PatCubed.session_id then
		return is_valid_session(vars.PatCubed.session_id)
	end
end

local function prompter(uuid)
	if not pcall(client.uuidToIntArray, uuid) then
		for key in pairs(world.avatarVars()) do
			prompter(key)
		end
	end

	local vars = (world.avatarVars()[uuid] or {}).PatCubed
	if not vars then return end
	if vars.protocol and vars.protocol ~= 1 then return end
	local acceptor = vars.acceptor

	pcall(acceptor, {
		player = whitelisted(uuid, "player") and function(time)
			-- fixes an issue where you can hang onto old instances past the avatar lifetime.
			if not current_session_valid() then return false end
			if not whitelisted(uuid, "player") then return false end
			if not entitycooldowns[uuid] then entitycooldowns[uuid] = 0 end
			if entitycooldowns[uuid] > 0 then return false end
			entitycooldowns[uuid] = CONFIG.cooldown

			if not call("player", "onPat", uuid) then
				return false
			end

			if not timers[uuid] then
				if not call("player", "startPat", uuid) then return false end
			end

			timers[uuid] = math.max(timers[uuid] or 0, time)

			return true
		end,
		skull = whitelisted(uuid, "skull") and function(time, x, y, z)
			-- fixes an issue where you can hang onto old instances past the avatar lifetime.
			if not current_session_valid() then return false end
			if not whitelisted(uuid, "skull") then return false end
			if not skullCooldowns[uuid] then skullCooldowns[uuid] = 0 end
			if skullCooldowns[uuid] > 0 then return false end
			skullCooldowns[uuid] = CONFIG.cooldown

			if not call("skull", "onPat", uuid, vectors.vec3(x, y, z)) then
				return false
			end

			local id = skullFormat(uuid, x, y, z)
			if not skullTimers[id] then
				if not call("skull", "startPat", uuid, vectors.vec3(x, y, z)) then return false end
			end

			skullTimers[id] = math.max(skullTimers[id] or 0, time or world.getTime())

			return true
		end,
		validate = current_session_valid
	})
end

--- rawtype(), from auria in code-snippets
---@overload fun(value: any): string
local function rawtype(value)
   local success, err = pcall(rawget, value, "")
   return success and "table" or err:match('table expected, got (%w*)')
end

local function acceptor(tbl)
	assert(current_prompter ~= nil, "Nobody is currently being prompted!")
	assert(rawtype(tbl) == "table", "Argument was not a table!")
	local funcs = {
		skull = rawget(tbl, "skull"),
		player = rawget(tbl, "player")
	}
	if rawtype(funcs.skull) ~= "function" then funcs.skull = nil end
	if rawtype(funcs.player) ~= "function" then funcs.player = nil end
	patMethods[current_prompter] = funcs
	local validate = rawget(tbl, "validate")
	if rawtype(validate) ~= "function" then validate = nil end
	if not validate then
		local vars = world.avatarVars()[current_prompter]
		if vars and vars.PatCubed and vars.PatCubed.validate then
			validate = vars.PatCubed.validate
		end
	end
	validateMethods[current_prompter] = validate
end

function pings.PAT(uuid, y, z)
	local x = uuid

	if type(uuid) == "number" then
		local block = world.getBlockState(x, y, z)
		local nbt = block:getEntityData() or {}
		local owner = nbt.SkullOwner or {}
		uuid = client.intUUIDToString(table.unpack(owner.Id or {0, 0, 0, 0}))

		local vars = world.avatarVars()[uuid] or {}
		if (not maybe_validate(uuid)) and vars.PatCubed then
			current_prompter = uuid
			pcall(vars.PatCubed and vars.PatCubed.prompter, avatar:getUUID())
			current_prompter = nil
		end

		if patMethods[uuid] and patMethods[uuid].skull then
			local ok, should_swing = pcall(patMethods[uuid].skull, world.getTime() + math.max(CONFIG.delay * 2.5, 8), x, y, z)
			-- explicit check for !false, for backwards compatibility
			if ok and (should_swing ~= false) then host:swingArm() end
		end
	else
		local vars = world.avatarVars()[uuid] or {}
		if (not maybe_validate(uuid)) and vars.PatCubed then
			current_prompter = uuid
			pcall(vars.PatCubed and vars.PatCubed.prompter, avatar:getUUID())
			current_prompter = nil
		end

		if patMethods[uuid] and patMethods[uuid].player then
			local ok, should_swing = pcall(patMethods[uuid].player, math.max(CONFIG.delay * 2.5, 8))
			-- explicit check for !false, for backwards compatibility
			if ok and (should_swing ~= false) then host:swingArm() end
		end
	end
end
events.TICK:register(function()
	for uuid, time in pairs(entitycooldowns) do
		entitycooldowns[uuid] = time - 1
	end
end, "PatCubed.TickCooldown")

local patTimer = 0
events.TICK:register(function()
	for uuid, time in pairs(timers) do
		timers[uuid] = time - 1
		if timers[uuid] <= 0 then
			call("player", "stopPat", uuid)
			timers[uuid] = nil
		end
	end

	if not bind:isPressed() then
		patTimer = 0
		return
	end
	if patTimer > 0 then
		patTimer = patTimer - 1
		return
	end
	patTimer = CONFIG.delay

	if (not CONFIG.sneakToPat) or player:isSneaking() or player:getVehicle() then
		local startPos = player:getPos():add(0, player:getEyeHeight(), 0):add(renderer:getEyeOffset())
		local endPos = startPos + player:getLookDir() * 5
		local block, blockPos = raycast:block(startPos, endPos, "OUTLINE")
		local entity, entityPos = raycast:entity(startPos, endPos, function(e) return e ~= player end)
		local uuid = entity and entity:getUUID()

		-- length² is cheaper to compute, as it avoids a sqrt call
		local blockCloser = not entity or (block and (entityPos - startPos):lengthSquared() > (blockPos - startPos):lengthSquared())

		if blockCloser then
			local nbt = block:getEntityData() or {}
			local owner = nbt.SkullOwner or {}
			uuid = client.intUUIDToString(table.unpack(owner.Id or {0, 0, 0, 0}))
		end

		local vars = world.avatarVars()[uuid] or {}
		if (not maybe_validate(uuid)) and vars.PatCubed then
			current_prompter = uuid
			pcall(vars.PatCubed and vars.PatCubed.prompter, avatar:getUUID())
			current_prompter = nil
		end

		if blockCloser or not entity then
			if not patMethods[uuid] or not patMethods[uuid].skull then return end

			local pos = block:getPos()
			pings.PAT(pos.x, pos.y, pos.z)
		else
			if not patMethods[uuid] or not patMethods[uuid].player then return end

			pings.PAT(uuid)
		end
	end
end, "PatCubed.Tick")

local last_time = world.getTime()
events.SKULL_RENDER:register(function()
	local worldTime = world.getTime()
	for data, time in pairs(skullTimers) do
		local uuid, x, y, z = skullUnformat(data)
		if time < worldTime then
			call("skull", "startPat", uuid, x, y, z)
			skullTimers[data] = nil
		end
	end
	if last_time ~= worldTime then
		local diff = worldTime-last_time
		if diff > 0 then
			for key, value in pairs(skullCooldowns) do
				skullCooldowns[key] = value - diff
			end
			last_time = worldTime
		end
	end
end, "PatCubed.SkullRender")

avatar:store("PatCubed", {
	prompter = prompter,
	acceptor = acceptor,
	session_id = session_id,
	validate = current_session_valid,
	protocol = 1
})

return CONFIG