local _G = getfenv(0)
local witchslayer = _G.object

witchslayer.heroName = "Hero_WitchSlayer"

runfile 'bots/core_herobot.lua'

local tinsert = _G.table.insert

local core, behaviorLib = witchslayer.core, witchslayer.behaviorLib

runfile 'bots/teams/trashteam/utils/predictiveLasthitting.lua'

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

behaviorLib.StartingItems = { "Item_RunesOfTheBlight", "Item_HealthPotion", "2 Item_MinorTotem", "2 Item_MarkOfTheNovice" }
behaviorLib.LaneItems = { "Item_Marchers", "Item_Glowstone", "Item_EnhancedMarchers" }
behaviorLib.MidItems = { "Item_PortalKey", "Item_Intelligence7", "1 Item_Nuke", "Item_Morph", "5 Item_Nuke" }
behaviorLib.LateItems = { "Item_GrimoireOfPower", "Item_PostHaste" }

witchslayer.skills = {}
local skills = witchslayer.skills

core.itemGeoBane = nil
witchslayer.DrainTarget = nil
witchslayer.AdvTargetHero = nil

witchslayer.tSkills = {
  0, 2, 0, 1, 0,
  3, 2, 0, 1, 1,
  3, 2, 1, 2, 4,
  3, 4, 4, 4, 4,
  4, 4, 4, 4, 4
}

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

   if nAddBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
end
-- override combat event trigger function.
local function IsSiege(unit)
  local unitType = unit:GetTypeName()
  return unitType == "Creep_LegionSiege" or unitType == "Creep_HellbourneSiege"
end
local function IsRanged(unit)
  local unitType = unit:GetTypeName()
  return unitType == "Creep_LegionRanged" or unitType == "Creep_HellbourneRanged"
end

local function IsTower(unit)
  local unitType = unit:GetTypeName()
  return unitType == "Creep_LegionRanged" or unitType == "Creep_HellbourneRanged"
end

local function closeToEnemyTowerDist(unit)
  local unitSelf = unit
  local myPos = unitSelf:GetPosition()
  local myTeam = unitSelf:GetTeam()

  local unitsInRange = HoN.GetUnitsInRadius(myPos, 3000, ALIVE + BUILDING)
  for _,unit in pairs(unitsInRange) do
    if unit and not(myTeam == unit:GetTeam()) then
      if unit:GetTypeName() == "Building_HellbourneTower" then
        return Vector3.Distance2D(myPos, unit:GetPosition())
      end
    end
  end
  return 3000
end

local function GetHeroInRange(botBrain, myPos, radius)
  local unitsLocal = HoN.GetUnitsInRadius(myPos, radius, ALIVE + HERO)
  local vihunmq = nil

  for key,unit in pairs(unitsLocal) do
    if unit ~= nil and not (botBrain:GetTeam() == unit:GetTeam()) then
      vihunmq = unit
    end
  end

  if not vihunmq then
    return nil
  end
  return vihunmq
end


witchslayer.oncombateventOld = witchslayer.oncombatevent
witchslayer.oncombatevent = witchslayer.oncombateventOverride


local function heroIsInRange(botBrain,enemyCreep, range)
  local creepPos = enemyCreep:GetPosition()
  local unitsInRange = HoN.GetUnitsInRadius(creepPos, range, ALIVE + HERO)
  for _,unit in pairs(unitsInRange) do
    if unit and not (botBrain:GetTeam() == unit:GetTeam()) then
      witchslayer.AdvTargetHero = unit
      return true
    end
  end
  return false
end

local function shouldWeHarassHero(botBrain)
  local unitSelf = botBrain.core.unitSelf
  local myPos = unitSelf:GetPosition()
  local allyTeam = botBrain:GetTeam()
  local heroes = HoN.GetUnitsInRadius(myPos, 4000, ALIVE+HERO)
  for _,unit in pairs(heroes) do
    if unit and not (allyTeam == unit:GetTeam()) then
      -- core.BotEcho("asdasd: " .. tostring(unit:GetHealthPercent()))
      if unit:GetHealthPercent() < 0.4 then
        return false
      else
        return true
      end
    end
  end
end

local ultiDmg = {0, 500, 650, 850}
local withStaff =  {0, 600, 800, 1025}
local nukeDmg = {0, 60, 130, 200, 260}

local function CustomHarassUtilityFnOverride(hero)
  -- LOL tää funktio saiki ton vastustajan sankarin wtf
  local unitSelf = core.unitSelf
  local distToEneTo = closeToEnemyTowerDist(unitSelf)
  core.BotEcho("Distance to tower is " .. tostring(distToEneTo))
  local modifier = 0
  if distToEneTo < 650 then
    modifier = 80
  end

  local nUtil = 0

  if skills.abilNuke:CanActivate() then
    nUtil = nUtil + 7*skills.abilNuke:GetLevel()
  end

  local ultiCost = skills.abilUltimate:GetManaCost()
  local nukeCost = skills.abilNuke:GetManaCost()
  local myMana = unitSelf:GetMana()
  if myMana > ultiCost + nukeCost*1.5 then
    nUtil = nUtil + 10
  end
  nUtil = nUtil * (unitSelf:GetHealthPercent()*0.5 + 0.4)

  if myMana-nukeCost < nukeCost + ultiCost and (not skills.abilUltimate:CanActivate() or skills.abilUltimate:GetLevel() < 1) then
    nUtil = nUtil*0.5
  end
  local nuke = skills.abilNuke
  local ulti = skills.abilUltimate
  local ultdmg = ultiDmg[ulti:GetLevel()+1]
  local nukedmg = nukeDmg[nuke:GetLevel()+1]
  local magicReduc = hero:GetMagicArmor()
  magicReduc = 1 - (magicReduc*0.06)/(1+0.06*magicReduc)
  if myMana - ultiCost > 0 and hero:GetHealth() < ultdmg*magicReduc and ulti:CanActivate() then
    return 100
  end
  if myMana - nukeCost > 0 and hero:GetHealth() < nukedmg*magicReduc and nuke:CanActivate() then
    return 100
  end
  return nUtil-modifier
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

local function HarassHeroExecuteOverride(botBrain)

  local unitTarget = behaviorLib.heroTarget
  if unitTarget == nil then
    return witchslayer.harassExecuteOld(botBrain)
  end

  local unitSelf = core.unitSelf
  local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
  local nLastHarassUtility = behaviorLib.lastHarassUtil

  local bActionTaken = false
  local magicReduc = unitTarget:GetMagicArmor()
  magicReduc = 1 - (magicReduc*0.06)/(1+0.06*magicReduc)

  local nuke = skills.abilNuke
  local ulti = skills.abilUltimate
  local mini = skills.abilMini
  local ultiCost = skills.abilUltimate:GetManaCost()
  local nukeCost = skills.abilNuke:GetManaCost()
  local myMana = unitSelf:GetMana()
  local ultdmg = ultiDmg[ulti:GetLevel()+1]
  local nukedmg = nukeDmg[nuke:GetLevel()+1]

	if core.CanSeeUnit(botBrain, unitTarget) then
    if ulti:CanActivate() and hero:GetHealth() < ultdmg*magicReduc then
      local nRange = ulti:GetRange()
      if nTargetDistanceSq < nRange*nRange then
        bActionTaken = core.OrderAbilityEntity(botBrain, ulti, unitTarget)
      end
    elseif mini:CanActivate() and myMana-mini:GetManaCost() > ultiCost + nukeCost then
      local nRange = mini:GetRange()
      if nTargetDistanceSq < (nRange*nRange) then
        bActionTaken = core.OrderAbilityEntity(botBrain, mini, unitTarget)
      end
    elseif nuke:CanActivate() then
      local nRange = nuke:GetRange()
      if nTargetDistanceSq < (nRange*nRange) then
        bActionTaken = core.OrderAbilityEntity(botBrain, nuke, unitTarget)
      end
    end
  end

  if not bActionTaken then
    return witchslayer.harassExecuteOld(botBrain)
  end
end
witchslayer.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


local function GetManaUtility(botBrain)
  --core.BotEcho("ManaUtility calc")
  local drainMana = skills.abilDrain
  local util = 0
  local modifier = 0
  if drainMana:CanActivate() then
    local unitSelf = botBrain.core.unitSelf
    local myMana = unitSelf:GetMana()
    local ultiCost = skills.abilUltimate:GetManaCost()
    local nukeCost = skills.abilNuke:GetManaCost()
    local miniCost = skills.abilMini:GetManaCost()
    local manaAfterSkills = myMana - ultiCost - nukeCost - miniCost
    if not manaAfterSkills > 0  then
      local distToEneTo = closeToEnemyTowerDist(unitSelf)
      if distToEneTo < 750 then
        modifier = 80
      end

      local drainRange = skills.abilDrain:GetRange()
      local myPos = unitSelf:GetPosition()
      local allUnitsMax = HoN.GetUnitsInRadius(myPos, drainRange, ALIVE + UNIT)
      local potentialCreep = nil
      for _,unit in pairs(allUnitsMax) do
        if unit and not (botBrain:GetTeam() == unit:GetTeam()) then
          if IsRanged(unit) then
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
  return core.OrderAbilityEntity(botBrain, manaDrain, targetCreep)
end

local GetManaBehavior = {}
GetManaBehavior["Utility"] = GetManaUtility
GetManaBehavior["Execute"] = GetManaExecute
GetManaBehavior["Name"] = "DrainMana"
tinsert(behaviorLib.tBehaviors, GetManaBehavior)
