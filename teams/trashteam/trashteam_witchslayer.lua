local _G = getfenv(0)
local witchslayer = _G.object

witchslayer.heroName = "Hero_WitchSlayer"

runfile 'bots/core_herobot.lua'

local tinsert = _G.table.insert

local core, behaviorLib = witchslayer.core, witchslayer.behaviorLib

runfile 'bots/teams/trashteam/utils/utils.lua'
--runfile 'bots/teams/trashteam/utils/predictiveLasthittingVesa.lua'
runfile 'bots/teams/trashteam/utils/attackUtils.lua'

witchslayer.bRunLogic         = true
witchslayer.bRunBehaviors    = true
witchslayer.bUpdates         = true
witchslayer.bUseShop         = true

witchslayer.bRunCommands     = true
witchslayer.bMoveCommands     = true
witchslayer.bAttackCommands     = true
witchslayer.bAbilityCommands = true
witchslayer.bOtherCommands     = true

witchslayer.bReportBehavior = true
witchslayer.bDebugUtility = true

witchslayer.logger = {}
witchslayer.logger.bWriteLog = false
witchslayer.logger.bVerboseLog = false


UNIT = 0x0000001
BUILDING = 0x0000002
HERO = 0x0000004
POWERUP = 0x0000008
GADGET = 0x0000010
ALIVE = 0x0000020
CORPSE = 0x0000040

behaviorLib.StartingItems = { "Item_RunesOfTheBlight", "Item_HealthPotion", "2 Item_MinorTotem", "Item_MarkOfTheNovice", "Item_PretendersCrown" }
behaviorLib.LaneItems = { "Item_Marchers","Item_HealthPotion", "Item_Glowstone", "Item_EnhancedMarchers" }
behaviorLib.MidItems = { "Item_Protect", "Item_Intelligence7", "Item_Nuke", "Item_Morph", "4 Item_Nuke" }
behaviorLib.LateItems = { "Item_GrimoireOfPower", "Item_PostHaste" }

witchslayer.skills = {}
local skills = witchslayer.skills

core.itemGeoBane = nil
witchslayer.DrainTarget = nil
witchslayer.UltiTarget = nil
witchslayer.comboFinisher = nil

witchslayer.tSkills = {
  0, 2, 0, 1, 0,
  3, 2, 0, 1, 1,
  3, 2, 1, 2, 4,
  3, 4, 4, 4, 4,
  4, 4, 4, 4, 4
}

local ultiDmg = {0, 500, 650, 850}
local ultiWithStaff =  {0, 600, 800, 1025}
local nukeDmg = {0, 60, 130, 200, 260}


---------------------------------------------------------------
--            SkillBuild override                            --
-- Handles hero skill building. To customize just write own  --
---------------------------------------------------------------
-- @param: none
-- @return: none
function witchslayer:SkillBuildOverride()
  local unitSelf = self.core.unitSelf
  if skills.abilNuke == nil then
    skills.abilNuke = unitSelf:GetAbility(0)
    skills.abilMini = unitSelf:GetAbility(1)
    skills.abilDrain = unitSelf:GetAbility(2)
    skills.abilUltimate = unitSelf:GetAbility(3)
    skills.stats = unitSelf:GetAbility(4)
    skills.taunt = unitSelf:GetAbility(8)
  end
  witchslayer:SkillBuildOld()
end
witchslayer.SkillBuildOld = witchslayer.SkillBuild
witchslayer.SkillBuild = witchslayer.SkillBuildOverride


------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function witchslayer:onthinkOverride(tGameVariables)
  self:onthinkOld(tGameVariables)
  local unitSelf = self.core.unitSelf
  -- custom code here
end
witchslayer.onthinkOld = witchslayer.onthink
witchslayer.onthink = witchslayer.onthinkOverride

local function GetUltiDmg(core) -- witchslayer specific
  local ulti = skills.abilUltimate
  local ultiLevel = ulti:GetLevel()
  if core.ultiStaff then
    return ultiWithStaff[ultiLevel+1]
  end
  return ultiDmg[ultiLevel+1]
end

----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function witchslayer:oncombateventOverride(EventData)
  self:oncombateventOld(EventData)

  -- custom code here
  local nAddBonus = 0
  --witchslayer.eventsLib.printCombatEvent(EventData)
end
witchslayer.oncombateventOld = witchslayer.oncombatevent
witchslayer.oncombatevent = witchslayer.oncombateventOverride
-- override combat event trigger function.
witchslayer.cancelChannel = false
witchslayer.cancelTime = 0

local function DontBreakChannelUtilityOverride(botBrain)
  local utility = 0
  local currentTime = HoN.GetMatchTime()

  if currentTime > botBrain.cancelTime then
    botBrain.cancelChannel = true
    botBrain.cancelTime = 9999999
  end

  if core.unitSelf:IsChanneling() and not botBrain.cancelChannel then
    utility = 100
  else
    botBrain.cancelChannel = false
  end

  if botBrain.bDebugUtility == true and utility ~= 0 then
    core.BotEcho("  DontBreakChannelUtility: ".. tostring(utility))
  end

  return utility
end
witchslayer.DontBreakChannelUtilityOld = behaviorLib.RetreatFromThreatBehavior["Utility"]
behaviorLib.DontBreakChannelBehavior["Utility"] = DontBreakChannelUtilityOverride

-- MAN UP BEHAVIOUR
witchslayer.PussyUtilityOld = behaviorLib.RetreatFromThreatBehavior["Utility"]
local function PussyUtilityOverride(BotBrain)
  local util = witchslayer.PussyUtilityOld(BotBrain)
  return core.Clamp(util, 0, 30) 
end
behaviorLib.RetreatFromThreatBehavior["Utility"] = PussyUtilityOverride

witchslayer.permissionToUseForce = false
witchslayer.PussyHarUtilityOld = behaviorLib.HarassHeroBehavior["Utility"]
local function PussyHarUtilityOverride(BotBrain)
  local util = witchslayer.PussyHarUtilityOld(BotBrain)
  if util < 5 then
    witchslayer.permissionToUseForce = true
  else
    witchslayer.permissionToUseForce = false
  end
  if witchslayer.HarassUtility > 0 then
    if util < witchslayer.HarassUtility then
      util = witchslayer.HarassUtility
    end
    witchslayer.HarassUtility = -5
  end
  return core.Clamp(util, 0, 100) 
end
behaviorLib.HarassHeroBehavior["Utility"] = PussyHarUtilityOverride


local function usefulstuff() -- misc stuff, for reminder of stuff
  local ultiCost = skills.abilUltimate:GetManaCost()
  local nukeCost = skills.abilNuke:GetManaCost()
  local myMana = unitSelf:GetMana()
  nUtil = nUtil * (unitSelf:GetHealthPercent()*0.5 + 0.4)

  local nuke = skills.abilNuke
  local ulti = skills.abilUltimate
  local ultdmg = ultiDmg[ulti:GetLevel()+1]
  local nukedmg = nukeDmg[nuke:GetLevel()+1]
  return
end

witchslayer.HarassUtility = -5
local function CustomHarassUtilityFnOverride(hero)
  -- LOL tää funktio saiki ton vastustajan sankarin wtf
  local unitSelf = core.unitSelf
  local distToEneTo = closeToEnemyTowerDist(unitSelf)
  local modifier = 0
  if distToEneTo < 750 then
    core.BotEcho("WTF")
    modifier = 50
  end

  local nUtil = 0
  local nTargetDistance = Vector3.Distance2D(unitSelf:GetPosition(), hero:GetPosition())
  local attackRange = unitSelf:GetAttackRange()
  local unitsInRange = AmountOfCreepsInRange(unitSelf, unitSelf:GetPosition(), 400)
  if nTargetDistance < attackRange and unitsInRange < 4 then
    nUtil = nUtil + 50
  end


  if skills.abilNuke:CanActivate() then
    nUtil = nUtil + 7*skills.abilNuke:GetLevel()
  end
  local heroHealth = hero:GetHealth()
  local myHealth = unitSelf:GetHealth()
  local heroPHealth = hero:GetHealthPercent()
  local myPHealth = unitSelf:GetHealthPercent()
  local eHeroPos = hero:GetPosition()
  local myPos = unitSelf:GetPosition()
  local nuke = skills.abilNuke
  local ulti = skills.abilUltimate
  local mini = skills.abilMini
  if myPos.z-eHeroPos.z > 80 then
    nUtil = nUtil + 20
  end
  if eHeroPos.z-myPos.z > 80 then
    nUtil = nUtil - 20
  end
  if heroPHealth > myPHealth and not ulti:CanActivate() then
    nUtil = nUtil * 0.9
  elseif heroPHealth > myPHealth*2 and not ulti:CanActivate()then
    nUtil = nUtil * 0.7
  elseif heroPHealth <= myPHealth and heroPHealth > 0.2 then
    nUtil = nUtil * 1.3
  end
  if heroPHealth < 0.3 and not (nuke:CanActivate() or mini:CanActivate() or ulti:CanActivate()) then
    nUtil = 0
  end
  local nukedmg = nukeDmg[nuke:GetLevel()+1]
  local ultiCost = skills.abilUltimate:GetManaCost()
  local nukeCost = skills.abilNuke:GetManaCost()
  local myMana = unitSelf:GetMana()
  local nuke = skills.abilNuke
  local nukeRange = nuke:GetRange()+800
  local nTargetDistanceSq = Vector3.Distance2D(myPos, eHeroPos)
  if nTargetDistanceSq < nukeRange and nuke:CanActivate() then
    nUtil = nUtil + 20
  end

  if core.CanSeeUnit(witchslayer, hero) then
    local targetMA = GetArmorMultiplier(hero, true)
    if  heroHealth < targetMA*(GetUltiDmg(core)+(nukedmg*1.5)) and myMana > ultiCost + nukeCost and skills.abilUltimate:CanActivate() and skills.abilNuke:CanActivate() then
      nUtil = 70
    end
    if hero:IsStunned() or hero:IsPerplexed() or hero:IsSilenced() then
      nUtil = 70
      modifier = modifier*0.4 -- GO IN!?
    end
  end
  if nUtil < 0 then 
    core.BotEcho("WTF MAN")
  end
  if unitSelf:GetLevel() < 6 then
    nUtil = nUtil * 0.5
  end
  if AmountOfCreepsInRange(unitSelf, myPos, 300, true) < 1 then
    nUtil = nUtil * 0.6
  end
  if witchslayer.bDebugUtility == true and utility ~= 0 then
     core.BotEcho("  HarassUtility: " .. tostring(nUtil))
  end
  witchslayer.HarassUtility = core.Clamp(nUtil-modifier, 0, 70)
  return core.Clamp(nUtil-modifier, 0, 100) -- Never be more important than 70
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

witchslayer.stunTime = 0

local function CanUseCC()
  local matchTime = HoN.GetMatchTime()
  if matchTime - witchslayer.stunTime > 500 then
    witchslayer.stunTime = 0
    return true
  end
  return false
end

local function HarassHeroExecuteOverride(botBrain)

  local unitTarget = behaviorLib.heroTarget
  if unitTarget == nil then
    return witchslayer.harassExecuteOld(botBrain)
  end

  local unitSelf = core.unitSelf
  local nTargetDistanceSq = Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition())
  local targetDirection = Vector3.Normalize(unitTarget:GetPosition()- unitSelf:GetPosition())*100 + unitSelf:GetPosition()
  --core.DrawDebugArrow(unitSelf:GetPosition(), targetDirection, "silver")
  local nLastHarassUtility = behaviorLib.lastHarassUtil

  local bActionTaken = false

  local nuke = skills.abilNuke
  local ulti = skills.abilUltimate
  local mini = skills.abilMini
  local ultiCost = skills.abilUltimate:GetManaCost()
  local ultiLevel = ulti:GetLevel()
  if ultiLevel == 0 or not ulti:CanActivate() then
    ultiCost = 0
  end
  local nukeCost = skills.abilNuke:GetManaCost()
  local miniCost = mini:GetManaCost()
  local myMana = unitSelf:GetMana()
  local drain = skills.abilDrain
  local ultiLevel = ulti:GetLevel()
  local ultdmg = ultiDmg[ulti:GetLevel()+1]
  local nukedmg = nukeDmg[nuke:GetLevel()+1]
  local speed = botBrain.core.speedBoots
  local taunt = skills.taunt
  if speed and speed:CanActivate() then
    core.OrderItemClamp(botBrain, unitSelf, speed)
  end
  botBrain.currentStunDur = 0

	if core.CanSeeUnit(botBrain, unitTarget) then
    if drain:CanActivate() and (ultiCost-myMana > 0) or (nukeCost-myMana > 0) and (unitTarget:IsStunned()or unitTarget:IsPerplexed()) and ultiLevel > 0 then
      botBrain.cancelTime = HoN.GetMatchTime() + 1000
      local nRange = drain:GetRange()
      if nTargetDistanceSq < nRange then
        bActionTaken = core.OrderAbilityEntity(botBrain, drain, unitTarget)
      end
    end
    if nuke:CanActivate() and myMana-nukeCost > ultiCost and not (unitTarget:IsStunned() or unitTarget:IsPerplexed()) and CanUseCC() then
      local nRange = nuke:GetRange()
      if nTargetDistanceSq < nRange then
        witchslayer.stunTime = HoN.GetMatchTime()
        bActionTaken = core.OrderAbilityEntity(botBrain, nuke, unitTarget)
      elseif nTargetDistanceSq < nRange+150 then
        witchslayer.stunTime = HoN.GetMatchTime()
        bActionTaken = core.OrderAbilityPosition(botBrain, nuke, targetDirection)
      end
    end
    if taunt and taunt:IsReady() and taunt:CanActivate() then
      core.BotEcho("taunt")
      bActionTaken = core.OrderAbilityEntity(botBrain, taunt, unitTarget)
    end
    if mini:CanActivate() and myMana-miniCost > ultiCost and not (unitTarget:IsStunned() or unitTarget:IsPerplexed()) and CanUseCC() then
      local nRange = mini:GetRange()
      if nTargetDistanceSq < nRange then
        witchslayer.stunTime = HoN.GetMatchTime()
        bActionTaken = core.OrderAbilityEntity(botBrain, mini, unitTarget)
      end
    end
    if core.itemCodex and core.itemCodex:CanActivate() then
      local nRange = core.itemCodex:GetRange()
      if nTargetDistanceSq < nRange then
        bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, core.itemCodex, unitTarget)
      end
    end
    if core.sheepStick and core.sheepStick:CanActivate() and not (unitTarget:IsStunned() or unitTarget:IsPerplexed()) and CanUseCC() then
      local nRange = core.sheepStick:GetRange()
      if nTargetDistanceSq < nRange then
        witchslayer.stunTime = HoN.GetMatchTime()
        bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, core.sheepStick, unitTarget)
      end
    end
    if botBrain.permissionToUseForce and ulti:CanActivate() then
      local nRange = ulti:GetRange()
      if nTargetDistanceSq < nRange then
        bActionTaken = core.OrderAbilityEntity(botBrain, ulti, unitTarget)
      end
    end
  end

  if not bActionTaken then
    return witchslayer.harassExecuteOld(botBrain)
  end
end
witchslayer.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function IllusionsAlert(botBrain, target) -- returns true if there are multiple of same targets
  return false
end

local function targetHasNullStone(botBrain, target) -- returns true if target has nullstone effect
  return false
end

local function targetHasShrunkenActive(target) -- returns true if target has shrunken activated
  return target:HasState("State_Item3E")
end


--- MY BEHAVIOURS ONLY AFTER THIS POINT ---

local function GetManaUtility(botBrain)
  -- use only if no heroes nearby
  --core.BotEcho("ManaUtility calc")
  local unitSelf = botBrain.core.unitSelf
  local drainMana = skills.abilDrain
  local util = 0
  local modifier = 0
  local myPos = unitSelf:GetPosition()
  local _,lol = HoN.GetUnitsInRadius(myPos, 1000, ALIVE + HERO, true)
  local enemyHeros = core.NumberElements(lol.EnemyHeroes)
  if drainMana:CanActivate() and enemyHeros < 1 then
    local myMana = unitSelf:GetMana()
    local ultiCost = skills.abilUltimate:GetManaCost()
    local nukeCost = skills.abilNuke:GetManaCost()
    local miniCost = skills.abilMini:GetManaCost()
    local manaAfterSkills = myMana - ultiCost - nukeCost - miniCost
    if not (manaAfterSkills > 0)  then
      local distToEneTo = closeToEnemyTowerDist(unitSelf)
      if distToEneTo < 850 then
        modifier = 80
      end

      local drainRange = skills.abilDrain:GetRange()
      local allUnitsMax = HoN.GetUnitsInRadius(myPos, drainRange, ALIVE + UNIT)
      local potentialCreep = nil
      for _,unit in pairs(allUnitsMax) do
        if unit and not (botBrain:GetTeam() == unit:GetTeam()) then
          if unit:GetMana() > 200 then
            potentialCreep = unit
          end
        end
      end
      if potentialCreep then
        witchslayer.DrainTarget = potentialCreep
        util = 25
      end
    end
  end
  util = util - modifier
  if botBrain.bDebugUtility == true and utility ~= 0 then
     core.BotEcho("  GetManaUtility: " .. tostring(util))
  end
  return util
end

local function GetManaExecute(botBrain)
  local unitSelf = botBrain.core.unitSelf
  local targetCreep = witchslayer.DrainTarget
  local manaDrain = skills.abilDrain
  botBrain.cancelTime = HoN.GetMatchTime() + 5000
  return core.OrderAbilityEntity(botBrain, manaDrain, targetCreep)
end

local GetManaBehavior = {}
GetManaBehavior["Utility"] = GetManaUtility
GetManaBehavior["Execute"] = GetManaExecute
GetManaBehavior["Name"] = "DrainMana"
tinsert(behaviorLib.tBehaviors, GetManaBehavior)

local function EiMihinkaanUtility(botBrain) -- fix Ulti on certain targets (shrunken/nullstone)
                                            -- also serious weakness against illusions, FUCK. Geomen too strong.
  --core.BotEcho("ManaUtility calc")
  local unitSelf = botBrain.core.unitSelf
  local ulti = skills.abilUltimate
  local ultiLevel = ulti:GetLevel()
  if ultiLevel < 1 then
    return 0
  end
  local range = ulti:GetRange()
  local util = 0
  local ultdmg = GetUltiDmg(botBrain.core)
  local ownTeam = botBrain:GetTeam()
  local ownMoveSpeed = unitSelf:GetMoveSpeed()
  local myPos = unitSelf:GetPosition()
  if ulti:CanActivate() then
    local unitsInRange = HoN.GetUnitsInRadius(myPos, range+200, ALIVE + HERO)
    for _,unit in pairs(unitsInRange) do
      if unit and not (ownTeam == unit:GetTeam()) and core.CanSeeUnit(botBrain, unit) and not targetHasShrunkenActive(unit) then
        local nTargetDistance = Vector3.Distance2D(myPos, unit:GetPosition())
        local targetArmor = GetArmorMultiplier(unit,true)
        local targetHealth = unit:GetHealth()
        if targetHealth < ultdmg*targetArmor then
          if nTargetDistance < range then
            util = 100
            witchslayer.UltiTarget = unit
            break
          elseif nTargetDistance > range and ownMoveSpeed > unit:GetMoveSpeed() then
            util = 100
            witchslayer.UltiTarget = unit
          end
        end
      end
    end
  end
  if witchslayer.comboFinisher then
    util = 100
    witchslayer.comboFinisher = false
  end
  if botBrain.bDebugUtility == true and utility ~= 0 then
     core.BotEcho("  EiMihinkäänUtility: " .. tostring(util))
  end
  return util
end

local function EiMihinkaanExecute(botBrain)
  local unitSelf = botBrain.core.unitSelf
  local targetHero = witchslayer.UltiTarget
  local ulti = skills.abilUltimate
  local speed = botBrain.core.speedBoots
  core.AllChat("EI MIHINKÄÄN")
  if speed and speed:CanActivate() then
    core.OrderItemClamp(botBrain, unitSelf, speed)
  end
  return core.OrderAbilityEntity(botBrain, ulti, targetHero)
end

local EiMihinkaanBehavior = {}
EiMihinkaanBehavior["Utility"] = EiMihinkaanUtility
EiMihinkaanBehavior["Execute"] = EiMihinkaanExecute
EiMihinkaanBehavior["Name"] = "EiMihinkaan"
tinsert(behaviorLib.tBehaviors, EiMihinkaanBehavior)


local function ComboUtility(botBrain)
  --core.BotEcho("ManaUtility calc")
  local unitSelf = botBrain.core.unitSelf
  local ulti = skills.abilUltimate
  local ultiLevel = ulti:GetLevel()
  local range = ulti:GetRange()
  local util = 0
  local ultdmg = ultiDmg[ultiLevel+1]
  local ownTeam = botBrain:GetTeam()
  local ownMoveSpeed = unitSelf:GetMoveSpeed()
  local myPos = unitSelf:GetPosition()

  if botBrain.bDebugUtility == true and utility ~= 0 then
     core.BotEcho("  ComboUtility: " .. tostring(util))
  end
  return util
end

local function ComboExecute(botBrain)
  local unitSelf = botBrain.core.unitSelf
  local targetHero = witchslayer.UltiTarget
  local ulti = skills.abilUltimate
  return core.OrderAbilityEntity(botBrain, ulti, targetHero)
end

-- NOT READY FOR DAYLIGHT, BROKEN TO CORE
--local ComboBehavior = {}
--ComboBehavior["Utility"] = ComboUtility
--ComboBehavior["Execute"] = ComboExecute
--ComboBehavior["Name"] = "ComboTime"
--tinsert(behaviorLib.tBehaviors, ComboBehavior)


--find items from inventory and puts them in core.xxxx location, check function for more
local function funcFindItemsOverride(botBrain)
  local bUpdated = witchslayer.FindItemsOld(botBrain)

  if core.itemRing ~= nil and not core.itemRing:IsValid() then
    core.itemRing = nil
  end
  if core.itemCodex ~= nil and not core.itemCodex:IsValid() then
    core.itemCodex = nil
  end
  if core.sheepStick ~= nil and not core.sheepStick:IsValid() then
    core.sheepStick = nil
  end
  if core.speedBoots ~= nil and not core.speedBoots:IsValid() then
    core.speedBoots = nil
  end
  if core.ultiStaff ~= nil and not core.ultiStaff:IsValid() then
    core.ultiStaff = nil
  end

  if bUpdated then
    --only update if we need to
    if core.itemRing and core.itemCodex and core.sheepStick and core.ultiStaff and core.speedBoots then
      return
    end

    local inventory = core.unitSelf:GetInventory(true)
    for slot = 1, 12, 1 do
      local curItem = inventory[slot]
      if curItem then
        if core.itemRing == nil and curItem:GetName() == "Item_Replenish" then
          core.itemRing = core.WrapInTable(curItem)
          --Echo("Saving astrolabe")
        elseif core.itemCodex == nil and curItem:GetName() == "Item_Nuke" then
          core.itemCodex = core.WrapInTable(curItem)
        elseif core.sheepStick == nil and curItem:GetName() == "Item_Morph" then
          core.sheepStick = core.WrapInTable(curItem)
        elseif core.speedBoots == nil and curItem:GetName() == "Item_EnhancedMarchers" then
          core.speedBoots = core.WrapInTable(curItem)
        elseif core.ultiStaff == nil and curItem:GetName() == "Item_Intelligence7" then
          core.ultiStaff = core.WrapInTable(curItem)
        end
      end
    end
  end
end
witchslayer.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

