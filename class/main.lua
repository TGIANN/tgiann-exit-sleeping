tgiCore = tgiCoreExports.getCore()
LANG = config.langs[config.lang]
local ox_target = exports.ox_target

---@alias Src number
---@alias CitizenId string
---@alias PlayerSkin {model:number, skin:table}
---@alias PlayerCoords {x:number, y:number, z:number, w:number}

---@class Sleeping
---@field playerCoords PlayerCoords
---@field skinData PlayerSkin
---@field citizenId CitizenId
---@field animationIndex number
---@field carrying boolean
---@field ped? number
---@field isOld? boolean
---@field vehicle? { netId: number, seat: number }
---@field netId? number

sleepingList = {}
Sleeping = setmetatable({}, { __index = {} })

---@param citizenId CitizenId
---@return Sleeping
function Sleeping.get(citizenId)
    return sleepingList[citizenId]
end

---@param data Sleeping
---@return Sleeping
function Sleeping:new(data)
    if not data then return end
    if sleepingList[data.citizenId] then return end
    setmetatable(data, self)
    self.__index = self
    if IsDuplicityVersion() then -- Server
        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "new", data.citizenId, data)
        if not data.isOld then
            MySQL.insert.await('INSERT INTO `tgiann_exit_sleeping` (citizenid, sleepData) VALUES (?, ?)', {
                data.citizenId, json.encode(data)
            })
        end
    end
    sleepingList[data.citizenId] = data
    debug("new", data.citizenId, json.encode(data))
    return data
end

function Sleeping:delete(citizenId)
    citizenId = self.citizenId or citizenId
    if sleepingList[citizenId] then
        if IsDuplicityVersion() then -- Server
            TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "delete", citizenId)
            MySQL.query.await('DELETE FROM `tgiann_exit_sleeping` WHERE citizenid = ?', { citizenId })
        else
            local sleepingPlayer = Sleeping.get(citizenId)
            sleepingPlayer:deletePed()
        end
        sleepingList[citizenId] = nil
        debug("delete", citizenId)
    end
end

function Sleeping:setCoords(newCoords)
    self.playerCoords = newCoords
    self.carrying = false
    if IsDuplicityVersion() then -- Server
        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "setCoords", self.citizenId, newCoords)
        if config.framework == "esx" then
            MySQL.update.await('UPDATE users SET position = ? WHERE identifier = ?', { json.encode({ x = newCoords.x, y = newCoords.y, z = newCoords.z }), self.citizenId })
        elseif config.framework == "qb" then
            MySQL.update.await('UPDATE players SET position = ? WHERE citizenid = ?', { json.encode({ x = newCoords.x, y = newCoords.y, z = newCoords.z, w = newCoords.w }), self.citizenId })
        end
    end
    debug("setCoords", self.citizenId, newCoords)
end

---@param src Src
---@param netId number
function Sleeping:setCarrying(src, netId)
    self.carryPlayer = src
    self.carrying = true
    self.netId = netId
    if IsDuplicityVersion() then -- Server
        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "setCarrying", self.citizenId, {
            carryPlayer = self.carryPlayer,
            netId = self.netId,
        })
    end
    debug("setCarrying", self.citizenId, src, netId)
end

function Sleeping:stopCarrying()
    self.netId = nil
    self.carrying = false
    self.carryPlayer = nil
    if IsDuplicityVersion() then -- Server
        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "stopCarrying", self.citizenId)
    end
    debug("stopCarrying", self.citizenId)
end

function Sleeping:putInVehicle(vehicleNetId, seatIndex)
    if not self.netId then return debug("PuInVehicle self.netId is null") end

    self.carrying = false
    self.vehicle = { vehicleNetId = vehicleNetId, seat = seatIndex }

    debug("PutInVehicle", self.citizenId, vehicleNetId, seatIndex)

    if IsDuplicityVersion() then -- Server
        local success = tgiCore.Callback.Await("tgiann-exit-sleeping:client:stopCarrying", self.carryPlayer)
        if not success then return end

        local ped = NetworkGetEntityFromNetworkId(self.netId)
        if not ped or not DoesEntityExist(ped) then return debug("PutInVehicle ped not found") end
        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "putInVehicle", self.citizenId, self.vehicle)
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if not DoesEntityExist(vehicle) then return debug("PutInVehicle vehicle not found") end
        debug("TaskWarpPedIntoVehicle", ped, vehicle, seatIndex)
        SetPedIntoVehicle(ped, vehicle, seatIndex)
        Entity(ped).state:set('exitSleepingAnim', false, true)
    else -- client
        ox_target:addEntity(vehicleNetId, {
            {
                label = LANG.OUT_VEHICLE:format(seatIndex + 1),
                name = "exit-sleeping-out-vehicle" .. (seatIndex),
                icon = "fa-solid fa-right-from-bracket",
                distance = 2.5,
                canInteract = function()
                    return not carrying
                end,
                onSelect = function(targetData)
                    local vehicle = targetData.entity
                    TriggerServerEvent("tgiann-exit-sleeping:server:outVehicle", self.citizenId, NetworkGetNetworkIdFromEntity(vehicle))
                end
            },
        })
    end
end

function Sleeping:outVehicle()
    if IsDuplicityVersion() then -- Server
        if not self.netId then return debug("outVehicle self.netId is null") end

        local ped = NetworkGetEntityFromNetworkId(self.netId)
        if not ped or not DoesEntityExist(ped) then return debug("outVehicle ped not found") end

        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "outVehicle", self.citizenId)
        DeleteEntity(ped)
    else
        ox_target:removeEntity(self.vehicle.vehicleNetId, "exit-sleeping-out-vehicle" .. self.vehicle.seat)
    end
    self.vehicle = nil

    debug("outVehicle", self.citizenId, self.netId)
end

-- Client
if not IsDuplicityVersion() then
    local carrying = false
    local carryData = { serverPed = nil, citizenId = nil, netId = nil }

    function Sleeping.SetPedClothing(ped, skinData)
        if not skinData then return end
        if config.clotheScripts.tgiann_clothing then
            exports["tgiann-clothing"]:LoadPedClothing(skinData, ped)
        elseif config.clotheScripts.rcore_clothing then
            exports.rcore_clothing:setPedSkin(ped, skinData)
        elseif config.clotheScripts.crm_appearance then
            exports['crm-appearance']:crm_set_ped_appearance(ped, skinData)
        elseif config.clotheScripts.illenium_appearance then
            exports['illenium-appearance']:setPedAppearance(ped, skinData)
        elseif config.framework == "qb" then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', skinData, ped)
        end
    end

    function Sleeping.SpawnPed(data, isServer)
        local model = data.skinData.model
        local skinData = data.skinData.skin
        local coords = data.playerCoords
        tgiCore.RequestModel(model)
        local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1, coords.w, isServer, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)
        if not isServer then
            local animation = config.sleepAnimation[data.animationIndex]
            tgiCore.PlayAnim(ped, animation.dict, animation.anim, 8.0, 8.0, -1, animation.flags)
        end
        Sleeping.SetPedClothing(ped, skinData)
        return ped
    end

    function Sleeping.GetFreeSeatIndex(vehicle)
        local seatAmount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
        for i = 0, seatAmount - 1 do
            if IsVehicleSeatFree(vehicle, i) then
                return i
            end
        end
        return false
    end

    function Sleeping.TargetCarryAction(data)
        if carrying then return end
        carrying = true

        if carryData.netId then
            carryData.serverPed = NetworkGetEntityFromNetworkId(carryData.netId)
        else
            carryData.serverPed = Sleeping.SpawnPed(data, true)
        end

        carryData.netId = 0
        carryData.citizenId = data.citizenId
        while carryData.netId == 0 do
            carryData.netId = NetworkGetNetworkIdFromEntity(carryData.serverPed)
            Wait(100)
        end
        TriggerServerEvent("tgiann-exit-sleeping:server:startCarrying", carryData.citizenId, carryData.netId)

        local palyer1Anim = config.carryAnimation.player1
        local attach = config.carryAnimation.attach
        local playerPed = PlayerPedId()
        SetPedRelationshipGroupHash(carryData.serverPed, joaat("PLAYER"))
        AttachEntityToEntity(carryData.serverPed, playerPed, attach[1], attach[2], attach[3], attach[4], attach[5], attach[6], attach[7], false, false, false, false, 2, false)
        tgiCore.PlayAnim(playerPed, palyer1Anim.dict, palyer1Anim.anim, 8.0, 8.0, -1, palyer1Anim.flags)

        ox_target:addGlobalVehicle({
            {
                label = LANG.PUT_IN_VEHICLE,
                name = "exit-sleeping-put-in-vehicle",
                icon = "fa-solid fa-right-to-bracket",
                distance = 2.5,
                canInteract = function()
                    return carrying
                end,
                onSelect = function(targetData)
                    local vehicle = targetData.entity
                    local seatIndex = Sleeping.GetFreeSeatIndex(vehicle)
                    if not seatIndex then return end
                    TriggerServerEvent("tgiann-exit-sleeping:server:putInVehicle", carryData.citizenId, NetworkGetNetworkIdFromEntity(vehicle), seatIndex)
                end
            },
        })
        tgiCoreExports:OpenKeyHelpMenu({ { icon = "xKey", label = LANG.STOP_CARRYING } })

        while carrying do
            Wait(0)
            if IsControlJustReleased(0, 73) then -- X
                Sleeping.StopCarrying(true)
                break
            end
            if not DoesEntityExist(carryData.serverPed) then
                Sleeping.StopCarrying(true)
                break
            end
        end
    end

    function Sleeping.StopCarrying(updateServer)
        if not carrying then return end
        carrying = false
        DetachEntity(carryData.serverPed, true, false)
        ClearPedTasks(PlayerPedId())
        tgiCoreExports:CloseKeyHelpMenu()
        ox_target:removeGlobalVehicle("exit-sleeping-put-in-vehicle")
        if updateServer then TriggerServerEvent("tgiann-exit-sleeping:server:stopCarrying", carryData.citizenId, carryData.netId) end
        carryData = { serverPed = nil, citizenId = nil, netId = nil }
        return true
    end

    function Sleeping:spawnPed()
        self.ped = Sleeping.SpawnPed(self, false)
        ox_target:addLocalEntity(self.ped, {
            {
                label = LANG.CARRY,
                name = 'exit-sleeping-move',
                icon = 'fa-solid fa-up-down-left-right',
                distance = 2.5,
                canInteract = function()
                    return not carrying
                end,
                onSelect = function()
                    Sleeping.TargetCarryAction(self)
                end
            },
        })
    end

    function Sleeping:deletePed()
        if self.ped and DoesEntityExist(self.ped) then
            DeleteEntity(self.ped)
            self.ped = nil
        end
    end
else -- Server
    function Sleeping:updateSql()
        MySQL.update.await('UPDATE tgiann_exit_sleeping SET sleepData = ? WHERE citizenid = ?', { json.encode(self), self.citizenId })
        debug("Updated SQL Data", self.citizenId)
    end
end

function debug(...)
    if not config.debug then return end
    print(...)
end
