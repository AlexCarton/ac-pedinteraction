local QBCore = exports['qb-core']:GetCoreObject()
local activeInteractions = {}
local npcInventories = {}
local npcNames = {}
local npcIllegal = {}
local npcLocks = {}

local function validatePedNetId(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity then return false end
    if not DoesEntityExist(entity) then return false end
    if IsPedAPlayer(entity) then return false end
    return true
end

function QBCore.Functions.HasItem(item)
    local p = promise.new()
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(result) p:resolve(result) end, item)
    return Citizen.Await(p)
end

RegisterNetEvent('pedInteraction:request')
AddEventHandler('pedInteraction:request', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end

    if activeInteractions[src] then
      TriggerClientEvent('npc:closeMenu', src, { npc = NetworkGetEntityFromNetworkId(netId) })
    end

    if npcLocks[netId] and npcLocks[netId] ~= src then
        TriggerClientEvent('QBCore:Notify', src, 'This pedestrian is already being interacted with.', 'error')
        return
    end

    activeInteractions[src] = netId
    npcLocks[netId] = src
    TriggerClientEvent('pedInteraction:approved', src, netId)
end)

RegisterNetEvent('addinventory')
AddEventHandler('addinventory', function(netId)
    local src = source

    if not validatePedNetId(netId) then return end

    if not npcInventories[netId] then
        npcInventories[netId] = {}
        for i = 1, 5 do
            local item = Config.inventoryItems[math.random(#Config.inventoryItems)]
            table.insert(npcInventories[netId], item)
        end
    end

    local npcItems = {}
    local illegal = false

    for _, item in ipairs(npcInventories[netId]) do
        table.insert(npcItems, {
            header = item.name .. " x" .. item.qty .. (item.legal and "" or " (illegal)"),
            txt = "",
            isMenuHeader = true
        })
        if item.legal == false then illegal = true end
    end

    npcIllegal[netId] = illegal
    TriggerClientEvent('addmenu', src, illegal, npcItems, netId)
end)

RegisterNetEvent("GetPedInfo")
AddEventHandler("GetPedInfo", function(netId, ped, mugshot, mugshotname, gender)
    local src = source

    if not validatePedNetId(netId) then return end

    if not npcNames[netId] then
        local firstName
        local lastName = Config.lastNames[math.random(#Config.lastNames)]
        if gender == "MALE" then
            firstName = Config.malefirstNames[math.random(#Config.malefirstNames)]
        else
            firstName = Config.femalefirstNames[math.random(#Config.femalefirstNames)]
        end
        npcNames[netId] = { firstname = firstName, lastname = lastName, gender = gender }
    end

    local firstname = npcNames[netId].firstname
    local lastname = npcNames[netId].lastname
    local gender = npcNames[netId].gender
    TriggerClientEvent('addname', src, netId, mugshot, mugshotname, true, firstname, lastname, gender)
end)

RegisterNetEvent('additem:qb')
AddEventHandler('additem:qb', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if activeInteractions[src] ~= netId then return end
    if Player.PlayerData.job.name == "police" then
        if npcIllegal[netId] then
            Player.Functions.AddItem('weapon_stungun', 1)
        end
    end
end)

RegisterNetEvent('additem:ox')
AddEventHandler('additem:ox', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if activeInteractions[src] ~= netId then return end
    if Player.PlayerData.job.name == "police" then
        if npcIllegal[netId] then
            exports.ox_inventory:AddItem(src, 'weapon_stungun', 1)
        end
    end
end)

RegisterNetEvent('arrestnpc')
AddEventHandler('arrestnpc', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not validatePedNetId(netId) then return end

    if activeInteractions[src] ~= netId then return end
    if Player.PlayerData.job.name == "police" then
        if npcIllegal[netId] then
            if Config.inventory == 'ox-inventory' then
                activeInteractions[src] = nil
                npcLocks[netId] = nil
                exports.ox_inventory:RemoveItem(src, 'weapon_stungun', 1)
                TriggerClientEvent('deletenpc', src, netId)
            else 
                activeInteractions[src] = nil
                npcLocks[netId] = nil
                exports['qb-inventory']:RemoveItem(src, 'weapon_stungun', 1, false, 'qb-inventory:removeweapon')
                TriggerClientEvent('deletenpc', src, netId)
            end
        end
    end
end)

RegisterNetEvent('exitclearance')
AddEventHandler('exitclearance', function(netId)
    local src = source

    if activeInteractions[src] == netId then
        activeInteractions[src] = nil
        npcLocks[netId] = nil
        TriggerClientEvent('Cleartasks', src, netId)
    end
end)
