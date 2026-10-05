-- Simplified Figura combat controller using the validSword table supplied by the main script.
--
-- Expected animations under the configured animation root:
--   NormalA 1, NormalE 1, NormalA 2, NormalE 2, ...
--   WeaponBlock (optional)
--
-- A = attack animation
-- E = endlag / ready animation

local C = {
   started = false,
   active = false,
   blocking = false,
   phase = nil,
   step = 1,
   anim = nil,
   blockAnim = nil,
   buffered = false,
   endlagHoldTimer = 0,
   lastSwinging = false,
   lastSwingTime = nil,
   animationRoot = nil,
   validSword = {},
}

local CONTINUE_FRACTION = 0.45
local END_FRACTION = 0.995
local ENDLAG_HOLD_TICKS = 40
local LOOP_START_STEP = 2
local MAX_STEPS = 32
local BLOCK_ANIMATION = "WeaponBlock"


local function root()
   return C.animationRoot or animations.model
end

local function getAnim(phase, step)
   local r = root()
   if not r then return nil end
   return r["Normal" .. phase .. " " .. step]
end

local function itemId(item)
   if not item then return "" end
   return tostring(item.id or ""):lower()
end

local function hasValidSword()
   local item = player:getHeldItem(false)
   if not item then return false end
   return C.validSword[tostring(item:getName() or "")] == true
end

local function isShield(item)
   return itemId(item):find("shield", 1, true) ~= nil
end

function C.hasWeapon()
   return hasValidSword()
end

local function resetAnimation(anim)
   if not anim then return end
   anim:stop()
   anim:setSpeed(1)
   anim:setTime(0)
   anim:setLoop("HOLD")
end

local function playAnimation(anim)
   if not anim then return false end

   local old = C.anim
   resetAnimation(anim)
   anim:restart()
   C.anim = anim

   if old and old ~= anim then
      resetAnimation(old)
   end

   return true
end

function C.cancel()
   resetAnimation(C.anim)
   C.anim = nil
   C.active = false
   C.phase = nil
   C.step = 1
   C.buffered = false
   C.endlagHoldTimer = 0
end

local function nextStep(step)
   local candidate = step + 1

   if candidate <= MAX_STEPS and getAnim("A", candidate) then
      return candidate
   end

   if getAnim("A", LOOP_START_STEP) then
      return LOOP_START_STEP
   end

   return 1
end

local function setAttack(step)
   step = math.max(1, math.floor(tonumber(step) or 1))

   local anim = getAnim("A", step)
   if not anim and step ~= 1 then
      step = 1
      anim = getAnim("A", 1)
   end

   if not anim then
      C.cancel()
      return false
   end

   C.active = true
   C.phase = "A"
   C.step = step
   C.buffered = false
   C.endlagHoldTimer = 0

   if not playAnimation(anim) then
      C.cancel()
      return false
   end

   -- Remote viewers can receive the combat ping before the player entity
   -- is fully loaded. Only play positional audio once player:getPos() is safe.
   if player:isLoaded() then
      sounds:playSound(
         "minecraft:entity.wind_charge.wind_burst",
         player:getPos(),
         0.50,
         0.70,
         false
      )
   end

   return true
end

local function startNextAttack()
   if not host:isHost() or not C.active then return false end

   local step = nextStep(C.step)
   C.buffered = false

   if setAttack(step) then
      pings.portable_combat_play(step)
      return true
   end

   return false
end

local function setEndlag()
   if not C.active then return end

   local anim = getAnim("E", C.step)
   if not anim then
      if C.buffered and host:isHost() and startNextAttack() then
         return
      end
      C.cancel()
      return
   end

   C.phase = "E"
   C.endlagHoldTimer = 0

   if not playAnimation(anim) then
      C.cancel()
   end
end

local function animationFraction(anim)
   if not anim then return 1 end

   local length = anim:getLength()
   if not length or length <= 0 then return 0 end

   return math.max(0, math.min(1, anim:getTime() / length))
end

function C.requestAttack()
   if not host:isHost() or not player:isLoaded() or C.blocking then return end
   if not hasValidSword() then return end

   if not C.active then
      if setAttack(1) then
         pings.portable_combat_play(1)
      end
      return
   end

   C.buffered = true

   if C.phase == "E" and animationFraction(C.anim) >= CONTINUE_FRACTION then
      startNextAttack()
   end
end

-- Remote viewers receive the attack step through this ping.
function pings.portable_combat_play(step)
   if host:isHost() then return end
   setAttack(tonumber(step) or 1)
end

local function updateCombo()
   if not C.active then return end

   -- Cancel immediately if a valid sword is no longer held.
   if not hasValidSword() then
      C.cancel()
      return
   end

   local finished = animationFraction(C.anim) >= END_FRACTION

   if C.phase == "A" then
      if finished then setEndlag() end
      return
   end

   if C.phase == "E" then
      if C.buffered and host:isHost() and animationFraction(C.anim) >= CONTINUE_FRACTION then
         startNextAttack()
         return
      end

      if finished then
         if C.buffered and host:isHost() then
            startNextAttack()
            return
         end

         -- Keep combat active while the endlag animation is holding its last frame.
         C.endlagHoldTimer = C.endlagHoldTimer + 1
         if C.endlagHoldTimer >= ENDLAG_HOLD_TICKS then
            C.cancel()
         end
      else
         C.endlagHoldTimer = 0
      end
   end
end

local function wantsBlock()
   if not hasValidSword() then return false end
   if not isShield(player:getHeldItem(true)) then return false end
   if not player:isUsingItem() then return false end

   local active = player:getActiveItem()
   local activeId = itemId(active)
   return activeId == "" or isShield(active)
end

local function updateBlock()
   local wanted = wantsBlock()
   if wanted == C.blocking then return end

   if wanted then
      local r = root()
      local anim = r and r[BLOCK_ANIMATION] or nil
      if not anim then return end

      if C.active then C.cancel() end
      resetAnimation(anim)
      anim:restart()
      C.blockAnim = anim
      C.blocking = true
   else
      resetAnimation(C.blockAnim)
      C.blocking = false
   end
end

local function detectSwing()
   if not host:isHost() or not player:isLoaded() then return end

   local swinging = player:isSwingingArm() == true
   local swingTime = tonumber(player:getSwingTime()) or 0
   local newSwing = false

   if swinging then
      if not C.lastSwinging then
         newSwing = true
      elseif C.lastSwingTime ~= nil and swingTime < C.lastSwingTime then
         newSwing = true
      end
   end

   C.lastSwinging = swinging
   C.lastSwingTime = swingTime

   if newSwing then
      C.requestAttack()
   end
end

local function tick()
   if not player:isLoaded() then
      C.cancel()
      resetAnimation(C.blockAnim)
      C.blocking = false
      C.lastSwinging = false
      C.lastSwingTime = nil
      return
   end

   updateBlock()
   detectSwing()
   updateCombo()
end

-- Configuration supplied by the avatar's main script.
function C.configure(options)
   options = options or {}

   if options.animationRoot then
      C.animationRoot = options.animationRoot
   end

   if type(options.validSword) == "table" then
      C.validSword = options.validSword
   end

   return C
end

function C.isAnimationActive()
   return C.active or C.blocking
end

function C.isBlocking()
   return C.blocking
end

function C.getPhase()
   return C.active and C.phase or nil
end

function C.getFamily()
   return C.active and "Normal" or nil
end

function C.getStep()
   return C.active and C.step or nil
end

-- Current combat animation time in seconds. BladeTrail uses this for
-- per-animation trail timing without needing to know the animation table.
function C.getAnimationTime()
   if not C.active or not C.anim then return nil end
   local ok, value = pcall(function() return C.anim:getTime() end)
   if not ok then return nil end
   return tonumber(value)
end

function C.start()
   if C.started then return C end
   C.started = true
   events.TICK:register(tick, "twilight_combat")
   return C
end

return C
