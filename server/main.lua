tgiCore.VersionCheck('tgiann-core', '4.16.3')

local dataLoaded = false
local entityList = {}

---@param citizenId CitizenId
---@return PlayerSkin | nil
local function getPlayerSkin(citizenId)
    if config.clotheScripts.tgiann_clothing then
        local row = MySQL.single.await('SELECT `model`, `skin` FROM `tgiann_skin` WHERE `citizenid` = ? LIMIT 1', { citizenId })
        if row then
            return {
                model = row.model,
                skin = json.decode(row.skin)
            }
        end
    elseif config.clotheScripts.illenium_appearance then
        local result = MySQL.single.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = 1', { citizenId })
        if result then
            local skin = json.decode(result.skin)
            return {
                model = skin.model and joaat(skin.model) or `mp_m_freemode_01`,
                skin = skin,
            }
        end
    elseif config.clotheScripts.rcore_clothing then
        local skin = exports.rcore_clothing:getSkinByIdentifier(citizenId)
        if skin then
            return {
                model = skin.ped_model,
                skin = skin.skin
            }
        end
    elseif config.framework == "qb" then -- CRM Using same table as qb-clothing
        local row = MySQL.single.await('SELECT `skin`, `model` FROM playerskins WHERE citizenid = ? AND active = ?', { citizenId, 1 })
        if row then
            return {
                model = row.model or `mp_m_freemode_01`,
                skin = row.skin and json.decode(row.skin) or {}
            }
        end
    elseif config.framework == "esx" then -- CRM Using same table as skin
        local row = MySQL.single.await('SELECT `skin`, `sex` FROM users WHERE identifier = ?', { citizenId })
        if row then
            return {
                model = row.sex == "m" and `mp_m_freemode_01` or `mp_f_freemode_01`,
                skin = row.skin and json.decode(row.skin) or {}
            }
        end
    end

    return nil
end

---@param src Src
---@return string | nil
local function getPlayerCitizenId(src)
    local xPlayer = tgiCore.getPlayer(src)
    if not xPlayer then return end
    local citizenId = tgiCore.getCid(xPlayer)
    if not citizenId then return end
    return citizenId
end

---@param src Src
local function playerDropped(src)
    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then return end

    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)

    local citizenId = getPlayerCitizenId(src)
    if not citizenId then return end

    if Sleeping.get(citizenId) then return end

    local playerSkin = getPlayerSkin(citizenId)
    if not playerSkin then return end

    Sleeping:new({
        citizenId = citizenId,
        skinData = playerSkin,
        playerCoords = {
            x = playerCoords.x,
            y = playerCoords.y,
            z = playerCoords.z,
            w = playerHeading
        },
        animationIndex = math.random(1, #config.sleepAnimation),
        carrying = false,
        ped = nil
    })
end

tgiCore.CommandsAdd(config.testCommand.name, "", {}, false, function(source, args)
    local citizenId = getPlayerCitizenId(source)
    local sleepingPlayer = Sleeping.get(citizenId)
    if sleepingPlayer then return sleepingPlayer:delete() end

    playerDropped(source)
end, config.testCommand.perm[config.framework == "esx" and "esx" or "qb"])

AddEventHandler('playerDropped', function()
    playerDropped(source)
end)

tgiCore.Callback.Register("tgiann-exit-sleeping:server:onPlayerLoaded", function(source)
    if not dataLoaded then while not dataLoaded do Wait(100) end end
    local citizenId = getPlayerCitizenId(source)
    if citizenId then
        local sleepingPlayer = Sleeping.get(citizenId)
        if sleepingPlayer then
            sleepingPlayer:delete()
            debug("onPlayerLoaded Delete Sleeping", citizenId)
        end
    end
    return sleepingList
end)

RegisterNetEvent('tgiann-exit-sleeping:server:startCarrying')
AddEventHandler('tgiann-exit-sleeping:server:startCarrying', function(citizenId, netId)
    local sleepingPlayer = Sleeping.get(citizenId)
    if not sleepingPlayer then return end
    sleepingPlayer:setCarrying()
    entityList[citizenId] = netId
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end
    Entity(entity).state:set('exitSleepingAnim', true, true)
    debug("startCarrying", citizenId, netId)
end)

RegisterNetEvent('tgiann-exit-sleeping:server:stopCarrying')
AddEventHandler('tgiann-exit-sleeping:server:stopCarrying', function(citizenId, netId)
    local src = source

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end

    local sleepingPlayer = Sleeping.get(citizenId)
    if not sleepingPlayer then return end

    DeleteEntity(entity)

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local newCoords = {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z,
        w = playerHeading
    }
    sleepingPlayer:setCoords(newCoords)
    debug("stopCarrying", citizenId, netId)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, netId in pairs(entityList) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)

MySQL.ready(function()
    local response = MySQL.query.await('SELECT `sleepData` FROM `tgiann_exit_sleeping` WHERE `unixTime` <= (UNIX_TIMESTAMP() - ?)', { config.sleepingDay * 86400 })
    for i = 1, #response do
        local sleepData = json.decode(response[i].sleepData)
        sleepData.isOld = true
        Sleeping:new(sleepData)
    end
    dataLoaded = true
    debug("MySQL.ready")
end)
