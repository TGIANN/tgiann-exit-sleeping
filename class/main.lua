tgiCore = tgiCoreExports.getCore()
LANG = config.langs[config.lang]

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

function Sleeping:setCarrying()
    self.carrying = true
    if IsDuplicityVersion() then -- Server
        TriggerClientEvent('tgiann-exit-sleeping:client:sync', -1, "setCarrying", self.citizenId)
    end
    debug("setCarrying", self.citizenId)
end

-- Client
if not IsDuplicityVersion() then
    local carrying = false

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

    function Sleeping.TargetAction(data)
        if carrying then return end
        carrying = true
        local serverPed = Sleeping.SpawnPed(data, true)
        local netId = 0
        while netId == 0 do
            netId = NetworkGetNetworkIdFromEntity(serverPed)
            Wait(100)
        end
        TriggerServerEvent("tgiann-exit-sleeping:server:startCarrying", data.citizenId, netId)

        local palyer1Anim = config.carryAnimation.player1
        local attach = config.carryAnimation.attach
        local playerPed = PlayerPedId()
        AttachEntityToEntity(serverPed, playerPed, attach[1], attach[2], attach[3], attach[4], attach[5], attach[6], attach[7], false, false, false, false, 2, false)
        tgiCore.PlayAnim(playerPed, palyer1Anim.dict, palyer1Anim.anim, 8.0, 8.0, -1, palyer1Anim.flags)

        tgiCoreExports:OpenKeyHelpMenu({ { icon = "xKey", label = LANG.STOP_CARRYING } })

        while carrying do
            Wait(0)
            if IsControlJustReleased(0, 73) then -- X
                carrying = false
                break
            end
            if not DoesEntityExist(serverPed) then break end
        end

        DetachEntity(serverPed, true, false)
        ClearPedTasks(PlayerPedId())
        tgiCoreExports:CloseKeyHelpMenu()
        TriggerServerEvent("tgiann-exit-sleeping:server:stopCarrying", data.citizenId, netId)
    end

    function Sleeping:spawnPed()
        self.ped = Sleeping.SpawnPed(self, false)
        tgiCoreExports:addLocalEntity(self.ped, {
            options = {
                {
                    name = 'exit-sleeping-move',
                    icon = 'fa-solid up-down-left-right',
                    label = LANG.CARRY,
                    canInteract = function()
                        return not carrying
                    end,
                    action = function()
                        Sleeping.TargetAction(self)
                    end
                },
            },
            distance = 2.5
        })
    end

    function Sleeping:deletePed()
        if self.ped and DoesEntityExist(self.ped) then
            DeleteEntity(self.ped)
            self.ped = nil
        end
    end
end

function debug(...)
    if not config.debug then return end
    print(...)
end
