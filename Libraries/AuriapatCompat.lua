return function(CONFIG)
	local entityCooldowns, skullCooldowns, whitelisted, call, timers, skullTimers, skullFormat =
		CONFIG.compat.entityCooldowns, CONFIG.compat.skullCooldowns, CONFIG.compat.whitelisted, CONFIG.compat.call, CONFIG.compat.timers, CONFIG.compat.skullTimers, CONFIG.compat.skullFormat

	local function entityPat(uuid)
		if not whitelisted(uuid, "player") then return false end
		if not entityCooldowns[uuid] then entityCooldowns[uuid] = 0 end
		if entityCooldowns[uuid] > 0 then return false end
		entityCooldowns[uuid] = CONFIG.cooldown

		if not call("player", "onPat", uuid) then
			return false
		end

		if not timers[uuid] then
			if not call("player", "startPat", uuid) then return false end
		end

		timers[uuid] = math.max(timers[uuid] or 0, 15)

		return true
	end

	local function skullPat(uuid, x, y, z)
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

		skullTimers[id] = math.max(skullTimers[id] or 0, 15)

		return true
	end

	local patTarget
	avatar:store("patpat.confirm", function()
		local target = patTarget
		patTarget = nil
		return target
	end)

	avatar:store("patpat", function(uuid, mode, x, y, z)
		local vars = world.avatarVars()[uuid] or {}
		if not vars["patpat.confirm"] then return false end
		if vars["patpat.confirm"]() ~= avatar:getUUID() then return false end

		if mode == 1 then
			return entityPat(uuid)
		elseif mode == 2 then
			return skullPat(uuid, x, y, z)
		end
	end)

	function pings.AURIA_PAT(uuid, y, z)
		local x = uuid

		if type(uuid) == "number" then
			local block = world.getBlockState(x, y, z)
			local nbt = block:getEntityData() or {}
			local owner = nbt.SkullOwner or {}
			uuid = client.intUUIDToString(table.unpack(owner.Id or {0, 0, 0, 0}))

			patTarget = uuid
			local vars = world.avatarVars()[uuid] or {}
			local ok, should_swing = pcall(vars.patpat, avatar:getUUID(), 2, x, y, z)
			if ok and (should_swing ~= false) then host:swingArm() end
			patTarget = nil
		else
			patTarget = uuid
			local vars = world.avatarVars()[uuid] or {}
			local ok, should_swing = pcall(vars.patpat, avatar:getUUID(), 1)
			if ok and (should_swing ~= false) then host:swingArm() end
			patTarget = nil
		end
	end

	table.insert(CONFIG.callbacks.compat.patOther, function(useBlock, uuid, block)
		if useBlock then
			local pos = block:getPos()
			pings.AURIA_PAT(pos.x, pos.y, pos.z)
		else
			pings.AURIA_PAT(uuid)
		end
	end)
end