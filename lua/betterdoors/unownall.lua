--[[
  This is taken from DarkRPs code to ensure disconnected players do a forced /unownalldoors on disconnect.
  Returns replaced to return nothing in order to prevent halting the event execution on PlayerDisconnected hooks.
]]

function bd_UnOwnAll(ply)
  local amount = 0
  local cost = 0

  local unownables = {}
  for entIndex, ent in pairs(ply.Ownedz or {}) do
    if not IsValid(ent) or not ent:isKeysOwnable() then ply.Ownedz[entIndex] = nil continue end
    table.insert(unownables, ent)
  end

  for _, otherPly in ipairs(player.GetAll()) do
    if ply == otherPly then continue end

    for _, ent in pairs(otherPly.Ownedz or {}) do
      if IsValid(ent) and ent:isKeysOwnedBy(ply) then
        table.insert(unownables, ent)
      end
    end
  end

  for entIndex, ent in pairs(unownables) do
    local bAllowed, _strReason = hook.Call("playerSell" .. (ent:IsVehicle() and "Vehicle" or "Door"), GAMEMODE, ply, ent)

    if bAllowed == false then continue end

    if ent:isMasterOwner(ply) then
      ent:Fire("unlock", "", 0)
    end

    ent:keysUnOwn(ply)
    amount = amount + 1

    local GiveMoneyBack = math.floor((hook.Call("get" .. (ent:IsVehicle() and "Vehicle" or "Door") .. "Cost", GAMEMODE, ply, ent) * 0.666) + 0.5)
    hook.Call("playerKeysSold", GAMEMODE, ply, ent, GiveMoneyBack)
    cost = cost + GiveMoneyBack
  end

  if amount == 0 then return end

  ply:addMoney(math.floor(cost))

  DarkRP.notify(ply, 2, 4, DarkRP.getPhrase("sold_x_doors", amount, DarkRP.formatMoney(math.floor(cost))))
  return
end