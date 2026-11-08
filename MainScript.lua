vanilla_model.PLAYER:setVisible(false)
vanilla_model.ARMOR:setVisible(false)
vanilla_model.CAPE:setVisible(false)
models.idalia.WORLD.Freecam.DroneCam.DroneLights.Flash:setVisible(false)
avatar:store("patpat.trailColor", "#ff0000")

-- Donator Badge Colour
avatar:setColor(230/255, 0/255, 0/255, "donator")

-- Create variables for things
local aiming = nil
local wasAiming = nil
local SleepEnabled = false

--Configure Custom Sounds
local soundTwilight = sounds["Hit"]
local soundStagger = sounds["Stagger"]
soundTwilight:setSubtitle("§e§lTwilight Hits"):setVolume(0.6)
soundStagger:setSubtitle("§c§lIdalia Staggers"):setVolume(0.6)

-- Config to store ping variables
config:name("Idalia")

-- Shared performance budget. Expensive libraries can use this to yield before
-- Figura reaches its tick/render instruction limits. This follows the same
-- soft-budget approach used by the other high-settings avatar.
PerformanceBudget = PerformanceBudget or {
	tickFraction = 0.80,
	renderFraction = 0.70,
	permissionLevel = "",
	lowPermission = false,
}

local function readBudgetNumber(fn)
	local ok, value = pcall(fn)
	if ok then return tonumber(value) end
	return nil
end

function PerformanceBudget.beginTick()
	local ok, level = pcall(function() return avatar:getPermissionLevel() end)
	PerformanceBudget.permissionLevel = ok and tostring(level or ""):upper() or ""
	PerformanceBudget.lowPermission = PerformanceBudget.permissionLevel ~= "MAX"
end

function PerformanceBudget.tickAllowed(fraction)
	local max = readBudgetNumber(function() return avatar:getMaxTickCount() end) or 0
	if max <= 0 then return true end
	local used = readBudgetNumber(function() return avatar:getCurrentInstructions() end)
	if not used then return true end
	return used < max * (fraction or PerformanceBudget.tickFraction or 0.80)
end

function PerformanceBudget.renderAllowed(fraction)
	local max = readBudgetNumber(function() return avatar:getMaxRenderCount() end) or 0
	if max <= 0 then return true end
	local used = readBudgetNumber(function() return avatar:getRenderCount() end)
	if not used then
		used = readBudgetNumber(function() return avatar:getCurrentInstructions() end)
	end
	if not used then return true end
	return used < max * (fraction or PerformanceBudget.renderFraction or 0.70)
end

-- Valid gear names (Sword shared with the combat controller)
local validSword = {["Twilight"] = true, ["Hero"] = true, ["Guardian"] = true, ["Shield"] = true}
local validStaff = {["Twilight Staff"] = true, ["Novice Spell Book"] = true, ["Mage's Spell Book"] = true, ["Archmage Spell Book"] = true, ["󏀀Shiny Halcyon󏀀"] = true,}
local validRifle = {["Twilight Rifle"] = true}

-- Combat system stuff
local Combat=require("Libraries.CombatSystem")
local BladeTrail=require("Libraries.BladeTrail")

animations.idalia["NormalA 1"]:setPriority(5)
animations.idalia["NormalE 1"]:setPriority(5)
animations.idalia["NormalA 2"]:setPriority(5)
animations.idalia["NormalE 2"]:setPriority(5)
animations.idalia["NormalA 3"]:setPriority(5)
animations.idalia["NormalE 3"]:setPriority(5)

Combat.configure({
    -- This avatar stores its animations under animations.idalia, not animations.model.
    animationRoot = animations.idalia,

    -- Use the exact same sword-name table as the rest of this script.
    validSword = validSword
})

Combat.start()

BladeTrail.configure({
	combat=Combat,

	-- Character 1 trail engine, attached to Idalia's existing authored BladeTrail.
	modelRoot=models.idalia,
	sourcePart=models.idalia.root.Torso.RightArm.RightLowerArm.RightItemPivot.BladeTrail,
	families={Normal=true,Alt=true},

	-- Character 1 / MariaTrail behavior.
	copies=56,
	initialCopies=16,
	buildPerTick=4,
	maxLiveStrips=56,
	lifeTicks=12,
	opacity=.88,
	minMovement=.010,
	segmentLength=.10,
	maxSubdivisions=10,
	maxBakePerCapture=5,
	teleportRejectDistance=4.0,
	tickBudgetFraction=.78,
	captureStopFraction=.90,

	-- Continuous stretched ribbon UV + native emissive fade, like Character 1.
	stretchTexture=true,
	emissive=true,
	trailRenderType="EMISSIVE",
	emissiveTwoSided=true,
	emissiveFadeRGB=true,
	textureFlipSweep=false,
	textureFlipAlong=false,
	ribbonFaceSign=1,

	-- Keep Idalia's authored BladeTrail texture instead of Alba's Trail/TrailAlt textures.
	useTextureOverride=false,
}):start()

-- Character 2's old trail used BladeTrailEyes templates. The Character 1 system does not.
pcall(function() models.idalia.BladeTrailEyes:setVisible(false) end)

-- Animation Settings
animations.idalia.HoloMenu_Idle:setPlaying(true)
animations.idalia.Drone:setPlaying(true)

animations.idalia.Sleep:setPriority(1)
animations.idalia.Sleep2:setPriority(2)
animations.idalia.Stagger:setPriority(5)
animations.idalia.WeaponBlock:setPriority(6)
animations.idalia.Sitting:setPriority(5)

animations.idalia.twilightIdle:setSpeed(0.3)

-- Copy sword to use on the back
local backSword = models.idalia.ItemTwilight:copy("BackTwilight"):setParentType("MODEL"):moveTo(models.idalia.root.Torso.Body):setPos(14,36,1):setRot(0,0,135):setScale(0.95)

-- Set render types
models.idalia.root:setPrimaryRenderType("TRANSLUCENT_CULL")
models.idalia.Skull:setPrimaryRenderType("TRANSLUCENT_CULL")
models.idalia.WORLD:setPrimaryRenderType("TRANSLUCENT_CULL")
models.idalia.ItemStaff.Lamp.Cage:setPrimaryRenderType("TRANSLUCENT_CULL")
models.idalia.ItemTwilight.guard:setPrimaryRenderType("TRANSLUCENT_CULL")
backSword:setPrimaryRenderType("CUTOUT")
backSword.guard:setPrimaryRenderType("TRANSLUCENT_CULL")
models.idalia.root.Torso.Body.Coat.LowerCoat:setPrimaryRenderType("TRANSLUCENT")
models.idalia.ItemTwilight.blade.eyes2:setPrimaryRenderType("EMISSIVE_SOLID")
models.idalia.Arrow:setPrimaryRenderType("CUTOUT_EMISSIVE_SOLID")
models.idalia.root.Torso.Body.Wings.RightWingPivot.RightWingEyes:setPrimaryRenderType("EMISSIVE")
models.idalia.root.Torso.Body.Wings.LeftWingPivot.LeftWingEyes:setPrimaryRenderType("EMISSIVE")
models.idalia.WORLD.Freecam.DroneCam.DroneLights:setPrimaryRenderType("EMISSIVE_SOLID")
models.idalia.root.Torso.PivotHead.Head.Eyes.Irises:setPrimaryRenderType("EMISSIVE_SOLID")

-- Dependancies
local squapi = require("Libraries.SquAPI")
local squassets = require("Libraries.SquAPI_modules.SquAssets")
local dronezAPI = require("Libraries.dronezAPI")
local runLater = require("Libraries.runLater")
local TypingSystem = require("Libraries.typing")
local JustLean3 = require("Libraries.just-lean-3")
TypingSystem.start()

-- Just Lean 3 stuff 
local root = models.idalia.root
local torsopart = root.Torso
local leftarm = torsopart.LeftArm
local rightarm = torsopart.RightArm
local model_head = torsopart.PivotHead.Head
local leftleg = root.LeftLeg
local rightleg = root.RightLeg
local jl3settings = JustLean3.settings

local torso = JustLean3.lean:new(3, torsopart, 0.5, vec(0,12,0), true, {{-25,25},{-22.5,22.5}}, vec(0.95,0.5,1), true, false, "smooth", true) --Torso
local head = JustLean3.head:new(3, model_head, 0.75, true, {{-90,90},{-45,45}}, vec(0.95, 0.95, 0.25), torso) --Head
local left_arm = JustLean3.arms:new(1, leftarm, 0.5, true, vec(0.2,1,0.2))
local right_arm = JustLean3.arms:new(2, rightarm, 0.5, true, vec(0.2,1,0.2))
local left_leg = JustLean3.legs:new(1, leftleg, 0.5, true, vec(1, 0.5, 0.1), true)
local right_leg = JustLean3.legs:new(2, rightleg, 0.5, true, vec(1, 0.5, 0.1), true)

-- Make player bounce while moving
local onGround = false
local bounce = squapi.bounceWalk:new(
    models.idalia.root,    --model
    0.0     --(1) bounceMultiplier
)

-- Punishing bird that follows player
animations.idalia.BirbIdle:play()
local droneObject = dronezAPI.new(models.idalia.WORLD.Birb)
	:setLocalOffset(0,0.3,0)
	:setTopSpeed(2)
    :setAcceleration(0.12)
	:setBrakeMultiplier(1)
	:setWarpThreshold(48)
	:setAquireWaitTime(math.huge)
	:setTargetPosFunction(dronezAPI.targetFunctions.followEntity)
	:setTargetRotFunction(dronezAPI.targetFunctions.lookAt)

-- Birb punch shenanigans
local lastBiteTime = 0
function droneObject.dronePunched(droneObj, interactor)
	if interactor:getName() ~= "IdaliaTMC" then
		droneObj.targetEntity = interactor
		if (world.getTime() - lastBiteTime) > 35 --[[20 = 1s]] then
			animations.idalia.BirbBite:play()
			lastBiteTime = world.getTime()
			sounds:playSound("minecraft:entity.ender_dragon.hurt", droneObj.pos, 0.15, 1.5)
			sounds:playSound("minecraft:entity.ender_dragon.growl", droneObj.pos, 0.3, 2)
			runLater(15, function() sounds:playSound("minecraft:entity.evoker_fangs.attack", droneObj.pos, 0.3, 1) end)
		end
	end
	return 0
end

-- Ear physics
squapi.ear:new(
    models.idalia.root.Torso.PivotHead.Head.LeftEar, --leftEar
    models.idalia.root.Torso.PivotHead.Head.RightEar, --(nil) rightEar
    0.5, --(1) rangeMultiplier
    true, --(false) horizontalEars
    1, --(2) bendStrength
    nil, --(true) doEarFlick
    nil, --(400) earFlickChance
    nil, --(0.1) earStiffness
    nil  --(0.8) earBounce
)

-- Scarf physics
local SwingingPhysics = require("Libraries.swinging_physics")
local swingOnBody = SwingingPhysics.swingOnBody

swingOnBody(models.idalia.root.Torso.Body.scarf, 90, {-20,10,-50,50,-50,50})
swingOnBody(models.idalia.root.Torso.Body.scarf2, 90, {-20,10,-50,50,-50,50})

swingOnBody(models.idalia.root.Torso.Body.scarf.bone3, 90, {-30,5,-5,5,-5,5})
swingOnBody(models.idalia.root.Torso.Body.scarf2.bone5, 90, {-30,5,-5,5,-5,5})

swingOnBody(models.idalia.root.Torso.Body.scarf.bone3.bone4, 90, {-5,2,-2,2,-2,2})
swingOnBody(models.idalia.root.Torso.Body.scarf2.bone5.bone6, 90, {-5,2,-2,2,-2,2})

swingOnBody(models.idalia.root.Torso.Body.Coat.LowerCoat, 90, {-30,5,-5,5,-5,5})

-- Toggling HoloMenu
function pings.holoMenu(state)
	--save value so we know not to sync again
	MenuState = state
	if player:isLoaded() then
		--hide/show holomenu
		if state then
			animations.idalia.HoloMenu_Disapear:stop()
			animations.idalia.HoloMenu_Appear:play()
		else
			animations.idalia.HoloMenu_Disapear:play()
			animations.idalia.HoloMenu_Appear:stop()
		end
	end
end

-- Flight Toggle
function pings.flight(state)
	FlightState = state
    animations.idalia.Flight:setPlaying(state)
	models.idalia.root.Torso.Body.Wings:setVisible(state)
end

function pings.chat(state)
	ChatState = state
    vanilla_model.RIGHT_ITEM:setVisible(not state)
end

------------------------------------------------------------------------------- ACTION WHEEL THINGS ------------------------------------------------
local mainPage = action_wheel:newPage()
action_wheel:setPage(mainPage)

-- Eep toggle
function pings.ToggleSleep(state)
    SleepEnabled = state
    models.idalia.EepEffect:setVisible(state)
    animations.idalia.Sleep:setPlaying(state)
    config:save("Sleep", state)
	if state then
		JustLean3:disable()
	else
		JustLean3:enable()
	end
end

-- Eep syncing
function pings.syncStates(_sleepEnabled)
    if SleepEnabled ~= _sleepEnabled then
        SleepEnabled = _sleepEnabled
        models.idalia.EepEffect:setVisible(_sleepEnabled)
        animations.idalia.Sleep:setPlaying(_sleepEnabled)
    end
end

-- Eep stop when moved
function ToggleSleep(state)
    if state then
        if not (player:getPose() == "SLEEPING" or player:isCrouching() or player:getVelocity().xz:length() > 0.05) then
            pings.ToggleSleep(true)
        else
            SleepAction:setToggled(false)
        end
    else
        pings.ToggleSleep(false)
    end
end

-- Eep action wheel
SleepAction = mainPage:newAction()
    :title("The Eeper")
    :toggleTitle("No eeping")
    :item("black_bed")
    :toggleItem("barrier")
    :setOnToggle(ToggleSleep)
SleepAction:setToggled(SleepEnabled)

-- Stagger toggle
function pings.Stagger(state)
    animations.idalia.Stagger:setPlaying(state)
	if state == true and player:isLoaded() then
		soundStagger:setPos(player:getPos()):play()
	end
	if state then
		JustLean3:disable()
	else
		JustLean3:enable()
	end
end

-- Stagger action wheel
Stagger = mainPage:newAction()
    :title("Stagger")
    :toggleTitle("Stop Stagger")
    :item("yellow_wool")
    :toggleItem("red_wool")
    :setOnToggle(pings.Stagger)

-- Fixer License pull out Toggle
function pings.License(state)
	animations.idalia.ShowLicense:setPlaying(state)
	models.idalia.root.Torso.RightArm.RightLowerArm.License:setVisible(state)
end

License = mainPage:newAction()
	:title("License")
	:toggleTitle("Stop License")
	:item("minecraft:globe_banner_pattern")
	:toggleItem("barrier")
	:setOnToggle(pings.License)

-- SillyPlugin flight toggle
function FlightToggle(state)
	silly:setFly(state)
end

if silly then
	if silly:cheatsEnabled() then
		FlightToggle = mainPage:newAction()
 		   :title("Cannot Fly")
 		   :toggleTitle("Can Fly")
 		   :item("feather")
 	 	   :toggleItem("elytra")
 		   :setOnToggle(FlightToggle)
	end
end

-- Eep syncing
function events.entity_init()
    local sleepInit = config:load("Sleep")
    
    if sleepInit ~= nil and SleepEnabled ~= sleepInit then
        SleepEnabled = sleepInit
        models.idalia.EepEffect:setVisible(SleepEnabled)
        animations.idalia.Sleep:setPlaying(SleepEnabled)
        SleepAction:setToggled(SleepEnabled)
    end
end

-- Freecam flash
function pings.screenshot()
	models.idalia.WORLD.Freecam.DroneCam.DroneLights.Flash:setVisible(true)
	animations.idalia.DroneFlash:play()
	if player:isLoaded() then 
		sounds:playSound("minecraft:block.piston.extend", freecamPos, 1, 2, false)
	end
	runLater(20, function() models.idalia.WORLD.Freecam.DroneCam.DroneLights.Flash:setVisible(false) end)
end
local screenshotKey = keybinds:newKeybind("Screenshot", "key.keyboard.f2")
screenshotKey.press = pings.screenshot

-- Fixer License text
local licensePicture = models.idalia.root.Torso.RightArm.RightLowerArm.License:newText("LicensePicture")
local licenseText = models.idalia.root.Torso.RightArm.RightLowerArm.License:newText("LicenseText")
licensePicture:setText(":@idalia:"):setScale(0.13):setOutline(true):setPos(-1.5,2.5,-0.05)
licenseText:setText("§cName: Idalia\nGender: Female\n\nGrade: The Scarlet Justice\nOffice: Birdwatch Office\n\nSworn to protect those she\ncares for at any cost")
	:setScale(0.035):setOutline(true):setPos(2.5,2.4,-0.05)

-------------------------------------------------------------------------------------------ITEM RENDER EVENT--------------------------------------------------
function events.item_render(item, context)
    -- If valid Sword name, hold Twilight
    if validSword[item:getName()] or item.id == "minecraft:bow" then
        if context:find("FIRST") then
            return models.idalia.ItemTwilight:setPos(0,4,0):setScale(0.6)
        else
            return models.idalia.ItemTwilight:setPos(0,1,0):setScale(1)
        end
    end
	
	-- If valid Staff name, Hold the Staff Alteration
	if validStaff[item:getName()] then
        if aiming == true and context:find("THIRD") then
			return models.idalia.ItemStaff:setRot(-10,-7,0):setScale(1.3)
		elseif context:find("FIRST") then
			return models.idalia.ItemStaff:setRot(0,0,0):setScale(0.9)
		else
			return models.idalia.ItemStaff:setRot(30,0,0):setScale(1.3)
		end
    end
end

-------------------------------------------------------------------------------------------SKULL RENDER EVENT--------------------------------------------------
-- Make the player skull be a plush, and just a beret when worn. Sensitive for Figura Plaza to make it just a beret at all times except when placed, to better indicate it is wearable.
local ip = client:getServerData().ip
local validPlushRightMode ={
	FIRST_PERSON_RIGHT_HAND = true,
	THIRD_PERSON_RIGHT_HAND = true
}
local validPlushLeftMode = {
	FIRST_PERSON_LEFT_HAND = true,
	THIRD_PERSON_LEFT_HAND = true
}
local plush = models.idalia.Skull
local plushBeret = models.idalia.Skull.beret
local plushBody = models.idalia.Skull.plush
if ip == "plaza.figuramc.org" then
	function events.skull_render(_,_,_,_,mode)
	    if mode == "BLOCK" then
			plushBody:setVisible(true)
			plushBeret:setPos(0,0,0):setScale(1)
			plush:setRot(0,0,0)
		elseif validPlushRightMode[mode] then
			plushBody:setVisible(true)
			plushBeret:setPos(0,0,0):setScale(1)
			plush:setRot(0,-60,0)
		elseif validPlushLeftMode[mode] then
			plushBody:setVisible(true)
			plushBeret:setPos(0,0,0):setScale(1)
			plush:setRot(0,60,0)
		else
			plushBody:setVisible(false)
			plushBeret:setPos(-0.37,-8.9,0.3):setScale(0.87)
			plush:setRot(0,0,0)
		end
	end
else
	function events.skull_render(_,_,_,_,mode)
    	if mode == "HEAD" then
			plushBody:setVisible(false)
			plushBeret:setPos(-0.37,-8.9,0.3):setScale(0.87)
			plush:setRot(0,0,0)
		elseif validPlushRightMode[mode] then
			plushBody:setVisible(true)
			plushBeret:setPos(0,0,0):setScale(1)
			plush:setRot(0,-60,0)
		elseif validPlushLeftMode[mode] then
			plushBody:setVisible(true)
			plushBeret:setPos(0,0,0):setScale(1)
			plush:setRot(0,60,0)
		else
			plushBody:setVisible(true)
			plushBeret:setPos(0,0,0):setScale(1)
			plush:setRot(0,0,0)
		end
	end
end
-------------------------------------------------------------------------------------------RENDER EVENT--------------------------------------------------
function events.render(delta, context)
    -- Keep a final safety margin for the main render callback itself.
    if not PerformanceBudget.renderAllowed(0.92) then return end
		
    -- Use bounce walk only on ground
    if player:isOnGround() and not onGround then
        onGround = true
        bounce.bounceMultiplier = 0.75
    elseif not player:isOnGround() and onGround then
        onGround = false
        bounce.bounceMultiplier = 0.0
    end
end

-------------------------------------------------------------------------------------------OTHER EVENTS-----------------------------------------------
function events.on_play_sound(id, pos, volume, pitch, loop, category, path)
    if not path or not pos then return end
    if id ~= "minecraft:entity.arrow.shoot" then return end
    if category ~= "PLAYERS" and category ~= "PLAYER" then return end

    if (pos - player:getPos()):lengthSquared() <= 0.64 then
        return true
    end
end

-------------------------------------------------------------------------------------------TICK EVENT--------------------------------------------------
function events.tick()
	PerformanceBudget.beginTick()

    --Detect Container open or AFK for HoloMenu
	if host:isHost() then
		if (host:isContainerOpen() or not client:isWindowFocused() or host:getScreen() == "net.minecraft.class_433") ~= MenuState then
			pings.holoMenu(host:isContainerOpen() and not SleepEnabled or not client:isWindowFocused() and not SleepEnabled or host:getScreen() == "net.minecraft.class_433" and not SleepEnabled)
		end
	end
	
	--Flight detection for flight anim
	if host:isHost() then
		if (host:isFlying()) ~= FlightState then
			pings.flight(host:isFlying())
		end
	end

	--Chat open detection
	if host:isHost() then
		if (host:isChatOpen()) ~= ChatState then
			pings.chat(host:isChatOpen())
		end
	end

    -- Detect various things for animations
    local item = player:getHeldItem()
    local swordOut = validSword[item:getName()] or item.id == "minecraft:bow"
    local staffOut = validStaff[item:getName()]
	local headRot = vanilla_model.HEAD:getOriginRot()
	aiming = player:getActiveItem():getUseAction() == "BOW"
	local emptyOffhand = player:getHeldItem(true).id == "minecraft:air" or player:getHeldItem(true).id == "minecraft:shield"
	local emptyMainhand = player:getHeldItem().id == "minecraft:air"
	local crouching = player:getPose() == "CROUCHING"
	
	-- Play animations in certain scenarios
	models.idalia.root.Torso.PivotHead.Head.HoloMenu:setVisible(MenuState or (animations.idalia.HoloMenu_Disapear:isPlaying() and animations.idalia.HoloMenu_Disapear:getTime() < 0.46))
	animations.idalia.Charging:setPlaying(swordOut and aiming)
	animations.idalia.Idle:setPlaying(
		emptyOffhand
		and not MenuState
		and not SleepEnabled
		and not player:isVisuallySwimming()
		and not crouching
	)
	animations.idalia.CrouchIdle:setPlaying(crouching
		and emptyOffhand
		and not MenuState
		and not SleepEnabled
		and not player:isVisuallySwimming()
	)
	vanilla_model.LEFT_ITEM:setVisible(not emptyOffhand)
	animations.idalia.FlightIdle:setPlaying(FlightState and emptyMainhand)
	if player:getVehicle() ~= nil then
		animations.idalia.Sitting:setPlaying(true)
		animations.idalia.SittingArm:setPlaying(not ChatState)
	else
		animations.idalia.Sitting:setPlaying(false)
		animations.idalia.SittingArm:setPlaying(false)
	end
	
	-- Birb Bite recolour and targetting
	if animations.idalia.BirbBite:isPlaying() then
		models.idalia.WORLD.Birb:setColor(150 / 255, 0 / 255, 0/255)
	else
		models.idalia.WORLD.Birb:setColor(255 / 255, 255 / 255, 255 / 255)
		droneObject.targetEntity = player
	end
	
	-- Blinking
	if math.random(150) == 1 then
		animations.idalia.Blink:play()
	end
	
	-- Animate the Eep effect
	local time = world.getTime()
	models.idalia.EepEffect.Eep:setUV(math.floor(time/6)/6,0)
	models.idalia.EepEffect2.Eep:setUV(math.floor(time/6)/6,0)
	models.idalia.ItemStaff.Lamp.Cage.Fire:setUV(math.floor(time/3)/8,0)
	models.idalia.ItemStaff.Lamp.Cage.Fire2:setUV(math.floor(time/3)/8,0)
	
	-- handle Bow animation
	if wasAiming and not aiming then
		animations.idalia.Fire:play()
		sounds:playSound("minecraft:entity.wind_charge.wind_burst", player:getPos(), 0.5, 0.7, false)
	end
	wasAiming = aiming
	
    -- Toggle Twilight on back if holding Twilight
    backSword:setVisible(not swordOut and not staffOut)
	
	-- Idle weapons holding animations
	animations.idalia.twilightIdle:setPlaying(swordOut and not Combat.isAnimationActive())

    -- If holding Twilight, detect targeted Entity
    local entity = nil
	local entityPos = nil
    if player:getTargetedEntity(5) and player:getSwingTime() == 1 and swordOut == true then
        entity, entityPos = player:getTargetedEntity()
    end
    
    -- Play Hit sound when striking with Twilight
    if entity then
        soundTwilight:setPos(entityPos):play()
    end

	-- Toggle Eep when laying on a bed
    local isSleeping = player:getPose() == "SLEEPING"
    models.idalia.EepEffect2:setVisible(isSleeping)
    animations.idalia.Sleep2:setPlaying(isSleeping)
    
	-- Stop eep when moved
    if SleepEnabled and (isSleeping or player:isCrouching() or player:getVelocity().xz:length() > 0.05) then
        SleepAction:setToggled(false)
        pings.ToggleSleep(false)
    end
    
    -- Sync action wheel states every 5 seconds
    if host:isHost() then
        if world.getTime() % 100 == 0 then
            pings.syncStates(SleepEnabled)
        end
    end

	-- Death sound
	if player:isLoaded() then
		if player:getDeathTime() == 1 then
			soundStagger:setPos(player:getPos()):play()
		end
	end
end