include("unownall.lua")

--[[### Declare reused variables and functions ###]]--
local bd_filename = "betterdoors/" .. game.GetMap() .. ".json"

-- Load existing data from file, if available
local bd_doorData = util.JSONToTable(file.Read(bd_filename) or "{}")

-- Saves data to file
local function bd_saveData()
  if !file.Exists(bd_filename, "DATA") then
    -- Create garrysmod/data/betterdoors directory
    file.CreateDir("betterdoors")
  end
  file.Write(bd_filename, util.TableToJSON(bd_doorData, true))
end

-- Get the door that's looked at and check for privilege
local function getDoor(ply)
  local door = ply:GetEyeTrace().Entity

  if !ply:IsSuperAdmin() then
    DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("no_privilege"))
    return nil
  end

  if !door:isDoor() then
    DarkRP.notify(ply, 1, 4, "You must look at a door")
    return nil
  end
  return door
end

-- Returns true if the door is ownable and has no assigned teams / groups
function isDoorOverwritten(door)
  return door:getKeysDoorGroup() != nil or door:getKeysDoorTeams() != nil or door:getKeysNonOwnable() != nil
end

--[[### Define chat commands ###]]--
DarkRP.defineChatCommand("setgroup", function(ply, argStr)
  local door = getDoor(ply)
  if door == nil then return "" end

  local group = string.Replace(string.Trim(argStr), "\"", "")
  if group == "" or group == nil then
    -- Remove door group
    bd_doorData[door:MapCreationID()] = nil
    bd_saveData()

    DarkRP.notify(ply, 0, 4, "Group removed")
    return ""
  elseif #group > 32 then
    DarkRP.notify(ply, 1, 4, "Invalid group name (1-32 characters)")
    return ""
  end

  bd_doorData[door:MapCreationID()] = group
  bd_saveData()

  DarkRP.notify(ply, 0, 4, "Group set")
  return ""
end)
DarkRP.defineChatCommand("getgroup", function(ply, argStr)
  local door = getDoor(ply)
  if door == nil then return "" end

  if bd_doorData[door:MapCreationID()] == nil then
    DarkRP.notify(ply, 0, 4, "That door is in no group")
  else
    DarkRP.notify(ply, 0, 4, "That door is in the group \"" .. bd_doorData[door:MapCreationID()] .. "\"")
  end
  return ""
end)
DarkRP.defineChatCommand("listgroups", function(ply, argStr)
  if !ply:IsSuperAdmin() then
    DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("no_privilege"))
    return ""
  end

  local allGroups = {}
  for doorMapID, doorGroup in pairs(bd_doorData) do
    if allGroups[doorGroup] == nil then
      allGroups[doorGroup] = 1
    else
      allGroups[doorGroup] = allGroups[doorGroup] + 1
    end
  end

  if table.Count(allGroups) == 0 then
    DarkRP.notify(ply, 1, 4, "No door group on this map")
  else
    ply:ChatPrint("Groups on " .. game.GetMap() .. ":")
    for doorMapID, doorGroup in pairs(allGroups) do
      ply:ChatPrint(doorMapID .. " (" .. doorGroup .. ")")
    end
    ply:ChatPrint("Found " .. table.Count(allGroups) .. ((table.Count(allGroups) == 1) and " group" or " groups") .. " in total")
  end
  return ""
end)

--[[### Implement functionality ###]]--
-- OWNER
hook.Add("playerBuyDoor", "bd_playerBoughtDoor", function(ply, buyingDoor, cost)
  local group = bd_doorData[buyingDoor:MapCreationID()]
  if group == nil then
    -- Door is not in a group, don't intervene
    return
  end

  -- Buy other group doors, that are availabe
  local to_buy = {}
  local total_cost = 0
  for doorMapID, doorGroup in pairs(bd_doorData) do
    if doorGroup == group then
      local door = ents.GetMapCreatedEntity(doorMapID)
      if isDoorOverwritten(door) then continue end -- Skip if door is overwritten in some way
      if door:getDoorOwner() != nil and !door:isKeysAllowedToOwn(ply) then continue end -- Skip if not allowed to own

      table.insert(to_buy, door)
      total_cost = total_cost + hook.Call("getDoorCost", GAMEMODE, ply, door) --math.floor((hook.Call("getDoorCost", GAMEMODE, ply, door) * 0.666) + 0.5)
      -- if door:getDoorOwner() == nil then
      --   door:keysOwn(ply)
      -- elseif door:isKeysAllowedToOwn(ply) then
      --   door:addKeysDoorOwner(ply)
      -- end
    end
  end
  if #to_buy <= 1 then return end -- No other door in group, don't intervene

  -- Can the player afford?
  if !ply:canAfford(total_cost) then
    DarkRP.notify(ply, 1, 4, "You can not afford these doors!")
  else
    ply:addMoney(-total_cost)
    for k, door in pairs(to_buy) do
      if door:getDoorOwner() == nil then
        door:keysOwn(ply)
      else
        door:addKeysDoorOwner(ply)
      end
    end
    DarkRP.notify(ply, 0, 4, "You have bought " .. #to_buy .. " doors for " .. DarkRP.formatMoney(total_cost) .. "!")
  end
  return false
end)
hook.Add("playerSellDoor", "bd_playerSellDoor", function(ply, sellingDoor, cost)
  local group = bd_doorData[sellingDoor:MapCreationID()]
  if group == nil then
    -- Door is not in a group, don't intervene
    return
  end

  -- Sell other group doors, that are availabe
  local total_sold = 0
  local total_refund = 0
  for doorMapID, doorGroup in pairs(bd_doorData) do
    if doorGroup == group then
      local door = ents.GetMapCreatedEntity(doorMapID)
      if isDoorOverwritten(door) then continue end -- Skip if door is overwritten in some way

      local coOwners = door:getKeysCoOwners()

      if door:isMasterOwner(ply) then
        -- Remove ownage from other door
        total_sold = total_sold + 1
        total_refund = total_refund + hook.Call("getDoorCost", GAMEMODE, ply, door) * 0.666 + 0.5
        door:keysUnOwn(ply)
        if coOwners != nil then
          -- Make co-owner owner
          for k, v in pairs(coOwners) do
            if Player(k):IsPlayer() then
              door:keysOwn(Player(k))
              break
            end
          end
        else
          -- Noone owns the door anymore
          door:keysUnLock()
        end
      elseif door:isKeysOwnedBy(ply) then
        -- Remove co-ownage from other door
        total_sold = total_sold + 1
        total_refund = total_refund + math.floor((hook.Call("getDoorCost", GAMEMODE, ply, door) * 0.666) + 0.5)
        door:keysUnOwn(ply)
      end
    end
  end
  if total_sold == 1 then return end -- No other door in group, don't intervene
  if total_sold < 1 then return false end -- Prevent money duplication with /sellalldoors

  -- Refund money
  ply:addMoney(math.floor(total_refund))
  DarkRP.notify(ply, 0, 4, DarkRP.getPhrase("sold_x_doors", total_sold, DarkRP.formatMoney(math.floor(total_refund))))
  return false
end)

-- Enables enheriting when Owner disconnects (simulates /sellalldoors)
hook.Add("PlayerDisconnected", "bd_PlayerDisconnected", bd_UnOwnAll)

-- CO-OWNERS
hook.Add("onAllowedToOwnAdded", "bd_onAllowedToOwnAdded", function(ply, addOwnDoor, target)
  local group = bd_doorData[addOwnDoor:MapCreationID()]
  if group == nil then
    -- Door is not in a group, don't intervene
    return
  end

  -- Add Co-Owner to other group doors, that are availabe
  for doorMapID, doorGroup in pairs(bd_doorData) do
    if doorGroup == group then
      local door = ents.GetMapCreatedEntity(doorMapID)
      if isDoorOverwritten(door) then continue end -- Skip if door is overwritten in some way

      door:addKeysAllowedToOwn(target)
    end
  end
end)
hook.Add("onAllowedToOwnRemoved", "bd_onAllowedToOwnRemoved", function(ply, remOwnDoor, target)
  local group = bd_doorData[remOwnDoor:MapCreationID()]
  if group == nil then
    -- Door is not in a group, don't intervene
    return
  end

  -- Remove Co-Owner from other group doors, that are availabe
  for doorMapID, doorGroup in pairs(bd_doorData) do
    if doorGroup == group then
      door = ents.GetMapCreatedEntity(doorMapID)
      if isDoorOverwritten(door) then continue end -- Skip if door is overwritten in some way

      door:removeKeysAllowedToOwn(target)
      door:removeKeysDoorOwner(target)
    end
  end
end)


