RegisterNetEvent('tgiCore:Client:OnPlayerLoaded', function()
    local sleepingData = tgiCore.Callback.Await("tgiann-exit-sleeping:server:onPlayerLoaded")
    debug("onPlayerLoaded", json.encode(sleepingData))
    for _, sleepingPlayer in pairs(sleepingData) do Sleeping:new(sleepingPlayer) end
end)

RegisterNetEvent("tgiann-exit-sleeping:client:sync")
AddEventHandler("tgiann-exit-sleeping:client:sync", function(action, citizenId, data)
    debug("sync", action, citizenId, type(data) == "table" and json.encode(data) or data)
    if action == "new" then
        Sleeping:new(data)
    elseif action == "delete" then
        Sleeping:delete(citizenId)
    elseif action == "setCarrying" then
        local sleepingPlayer = Sleeping.get(citizenId)
        if not sleepingPlayer then return end
        sleepingPlayer:setCarrying(data.carryPlayer, data.netId)
    elseif action == "stopCarrying" then
        local sleepingPlayer = Sleeping.get(citizenId)
        if not sleepingPlayer then return end
        sleepingPlayer:stopCarrying()
    elseif action == "setCoords" then
        local sleepingPlayer = Sleeping.get(citizenId)
        if not sleepingPlayer then return end
        sleepingPlayer:setCoords(data)
    elseif action == "putInVehicle" then
        local sleepingPlayer = Sleeping.get(citizenId)
        if not sleepingPlayer then return end
        sleepingPlayer:putInVehicle(data.vehicleNetId, data.seat)
    elseif action == "outVehicle" then
        local sleepingPlayer = Sleeping.get(citizenId)
        if not sleepingPlayer then return end
        sleepingPlayer:outVehicle()
    end
end)

RegisterNetEvent("tgiann-exit-sleeping:client:TargetCarryAction")
AddEventHandler("tgiann-exit-sleeping:client:TargetCarryAction", function(citizenId)
    local sleepingPlayer = Sleeping.get(citizenId)
    if not sleepingPlayer then return end
    Sleeping.TargetCarryAction(sleepingPlayer)
end)

tgiCore.Callback.Register("tgiann-exit-sleeping:client:stopCarrying", function()
    return Sleeping.StopCarrying()
end)

CreateThread(function()
    while true do
        Wait(250)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for _, sleepingPlayer in pairs(sleepingList) do
            local pedExists = sleepingPlayer.ped and DoesEntityExist(sleepingPlayer.ped)
            local canSpawn = not sleepingPlayer.carrying and not sleepingPlayer.vehicle and #(vector3(sleepingPlayer.playerCoords.x, sleepingPlayer.playerCoords.y, sleepingPlayer.playerCoords.z) - playerCoords) < config.pedSpawnDist

            if not pedExists and canSpawn then
                sleepingPlayer:spawnPed()
            elseif pedExists and not canSpawn then
                sleepingPlayer:deletePed()
            end
        end
    end
end)

AddStateBagChangeHandler("exitSleepingAnim", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local palyer2Anim = config.carryAnimation.player2
    if not value then return StopAnimTask(entity, palyer2Anim.dict, palyer2Anim.anim, 8.0) end
    tgiCore.PlayAnim(entity, palyer2Anim.dict, palyer2Anim.anim, 8.0, 8.0, -1, palyer2Anim.flags)
    debug("exitSleepingAnim", entity)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, sleepingPlayer in pairs(sleepingList) do
        sleepingPlayer:delete()
    end
end)
