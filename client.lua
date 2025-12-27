local npcList
local QBCore = exports['qb-core']:GetCoreObject()
local addedTargets = {}
local activeScenes = {}

Citizen.CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local data = QBCore.Functions.GetPlayerData()
        if not data or not data.job or not data.job.name then goto skip end
        if data.job.name ~= "police" then goto skip end

        npcList = GetGamePool('CPed')

        for _, npc in ipairs(npcList) do
            if DoesEntityExist(npc) and not IsPedAPlayer(npc) then
                if not addedTargets[npc] then
                        local dist = #(GetEntityCoords(ped) - GetEntityCoords(npc))
                        if dist < 20.0 then
                            NetworkRegisterEntityAsNetworked(npc)
                            if Config.target == 'qb-target' then
                                exports['qb-target']:AddTargetEntity(npc, {
                                    options = {
                                        {
                                            type = "client",
                                            icon = "fas fa-comment",
                                            label = "Talk to the pedestrian",
                                            action = function(entity)
                                                TriggerEvent('my:ped:interaction', entity)
                                            end,
                                            canInteract = function(entity, distance)
                                                local Player = QBCore.Functions.GetPlayerData()
                                                return Player and Player.job and Player.job.name == 'police'
                                            end
                                        }
                                    },
                                    distance = 2.5
                                })
                                elseif Config.target == 'ox-target' then
                                    exports.ox_target:addLocalEntity(npc, { {
                                        name = 'talk',
                                        label = 'Talk to the pedestrian',
                                        icon = 'fas fa-comment',
                                        distance = 2.5,
                                        canInteract = function(entity)
                                            local Player = QBCore.Functions.GetPlayerData()
                                            return Player and Player.job.name == 'police'
                                        end,
                                        onSelect = function(data)
                                            TriggerEvent('my:ped:interaction', { npc = data.entity })
                                        end
                                    } })
                                end
                            addedTargets[npc] = true
                        end
                    end
                end
            end
        ::skip::
    end
end)

RegisterNetEvent('playSyncedScene')
AddEventHandler('playSyncedScene', function(entity, dict, anim)
    if not DoesEntityExist(entity) then 
        return 
    end

    local coords = GetEntityCoords(entity)
    local rot = GetEntityRotation(entity)

    NetworkRequestControlOfEntity(entity)

    while not NetworkHasControlOfEntity(entity) do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do 
        Wait(100) 
    end

    local scene = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, 2, false, true, 1.0, 0.0, 1.0)

    NetworkAddPedToSynchronisedScene(entity, scene, dict, anim, 16.0, -16.0, -1, 1, 1.0, 0)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    activeScenes[netId] = scene

    NetworkStartSynchronisedScene(scene)
end)

local function StopPedScene(netId)
    local scene = activeScenes[netId]
    local ped = PlayerPedId()
    local entity = NetworkGetEntityFromNetworkId(netId)

    if scene then
        NetworkStopSynchronisedScene(scene)
        activeScenes[netId] = nil
        NetworkRequestControlOfEntity(entity)
        SetBlockingOfNonTemporaryEvents(entity, true)
        TaskTurnPedToFaceEntity(entity, ped, -1)
    end
end

RegisterNetEvent('my:ped:interaction')
AddEventHandler('my:ped:interaction', function(entity)
    local npc = entity
    local jobData = QBCore.Functions.GetPlayerData()
    if jobData.job.name ~= 'police' then
        QBCore.Functions.Notify('You are not police', 'error')
        return
    end

    TriggerEvent('showmenu', { npc = npc })
end)

RegisterNetEvent('showmenu')
AddEventHandler('showmenu', function(data)
    local npc = data.npc
    local netId = NetworkGetNetworkIdFromEntity(npc)
    local test = NetworkGetEntityIsNetworked(npc)
    print(test)
    if not npc or not DoesEntityExist(npc) or IsPedDeadOrDying(npc, true) then return end

    TriggerServerEvent('pedInteraction:request', netId)
end)

RegisterNetEvent('pedInteraction:approved')
AddEventHandler('pedInteraction:approved', function(netId)
    local npc = NetworkGetEntityFromNetworkId(netId)
    if not npc or not DoesEntityExist(npc) then return end
    
    local ped = PlayerPedId()
    SetBlockingOfNonTemporaryEvents(npc, true)
    TaskTurnPedToFaceEntity(npc, ped, -1)

    PlayAmbientSpeech2(npc, "GENERIC_HI", "SPEECH_PARAMS_FORCE")

        local menuItems = {
        { header = "Police Menu", txt = "Interact with Pedestrians", isMenuHeader = true },
        { header = "Check ID-card", txt = "Check the identity of the pedestrian", icon = "fa-solid fa-id-card", params = { event = "npc:showIdCard", args = { npc = npc } } },
        { header = "Frisk the pedestrian", txt = "Check the pedestrian for illegal items", icon = "fas fa-search", params = { event = "npc:inventory", args = { npc = npc } } },
        { header = "Close Menu", txt = "", params = { event = "npc:closeMenu", args = { npc = npc } } }
    }

    exports['qb-menu']:openMenu(menuItems)
end)

RegisterNetEvent('npc:inventory')
AddEventHandler('npc:inventory', function(data)
    local npc = data.npc
    if not npc or not DoesEntityExist(npc) then return end

    local netId = NetworkGetNetworkIdFromEntity(npc)
    local entity = NetworkGetEntityFromNetworkId(netId)
    TriggerEvent('playSyncedScene', entity, "nm@hands", "hands_up")
    TriggerServerEvent('addinventory', netId)
end)

RegisterNetEvent('addmenu')
AddEventHandler('addmenu', function(isIllegal, npcItems, netId)
    local npc = NetworkGetEntityFromNetworkId(netId)
    if isIllegal then
        table.insert(npcItems, {
            header = "Back",
            txt = "Return to the main menu",
            params = { event = "arrestmenu", args = { npc = npc } }
        })
    else
        table.insert(npcItems, {
            header = "Back",
            txt = "Return to the main menu",
            params = { event = "showmenu", args = { npc = npc } }
        })
    end
    exports['qb-menu']:openMenu(npcItems)
end)

RegisterNetEvent('arrestmenu')
AddEventHandler('arrestmenu', function(data)
    local npc = data.npc
    local netId = NetworkGetNetworkIdFromEntity(npc)
    if not npc or not DoesEntityExist(npc) then return end

    StopPedScene(netId)

    local menuItems = {
        { header = "Police Menu", txt = "Interact with Pedestrians", isMenuHeader = true },
        { header = "Frisk the pedestrian", txt = "Search the pedestrian for illegal items", icon = "fas fa-search", params = { event = "npc:inventory", args = { npc = npc } } },
        { header = "Arrest", txt = "Arrest the pedestrian", icon = "fa-solid fa-handcuffs", params = { event = "npc:arrest", args = { npc = npc } } },
    }

    exports['qb-menu']:openMenu(menuItems)
end)

RegisterNetEvent('npc:showIdCard')
AddEventHandler('npc:showIdCard', function(data)
    local npc = data.npc
    if not npc or not DoesEntityExist(npc) then return end

    local netId = NetworkGetNetworkIdFromEntity(npc)
    local ped = PlayerPedId()
    local gender = IsPedMale(npc) and "MALE" or "FEMALE"

    local mugshot = RegisterPedheadshot(npc)
    while not IsPedheadshotReady(mugshot) do Wait(10) end
    local mugshotname = GetPedheadshotTxdString(mugshot)
    RequestStreamedTextureDict(mugshotname, false)

    TriggerServerEvent("GetPedInfo", netId, ped, mugshot, mugshotname, gender)
end)

RegisterNetEvent('addname')
AddEventHandler('addname', function(netId, mugshot, mugshotname, showingId, firstname, lastname, gender)
    Citizen.CreateThread(function()
        while showingId do
            Wait(0)
            local dict = "idcard"
            local tex = "ID-card"
            
            RequestStreamedTextureDict(dict, true)
            while not HasStreamedTextureDictLoaded(dict) do Wait(0) end

            DrawSprite(dict, tex, 0.80, 0.40, 0.35, 0.42, 0.0, 255, 255, 255, 255)

            if HasStreamedTextureDictLoaded(mugshotname) then
                DrawSprite(mugshotname, mugshotname, 0.69, 0.42, 0.12, 0.31, 0.0, 255, 255, 255, 255)
                DrawSprite(mugshotname, mugshotname, 0.87, 0.48, 0.04, 0.095, 0.0, 255, 255, 255, 255)
            end

            DrawText2D(0.78, 0.37, firstname, 0.4, 4, 0, 0, 0, 255, false)
            DrawText2D(0.81, 0.52, gender, 0.35, 4, 0, 0, 0, 255, false)
            DrawText2D(0.78, 0.345, lastname, 0.35, 4, 0, 0, 0, 255, false)

            if IsControlJustReleased(0, 194) then 
                showingId = false 
            end
        end

        if mugshot and mugshot > 0 then UnregisterPedheadshot(mugshot) end
        if mugshotname then SetStreamedTextureDictAsNoLongerNeeded(mugshotname) end

        TriggerEvent('showmenu', { npc = NetworkGetEntityFromNetworkId(netId) })
    end)
end)

function DrawText2D(x, y, text, scale, font, r, g, b, a, center)
    text = tostring(text)
    SetTextFont(font or 4)
    SetTextScale(scale or 0.35, scale or 0.35)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    if center then SetTextCentre(true) end
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('npc:arrest')
AddEventHandler('npc:arrest', function(data)
    local npc = data.npc
    if not npc or not DoesEntityExist(npc) then return end

    local ped = PlayerPedId()
    local pednetId = NetworkGetNetworkIdFromEntity(ped)
    local stungun = GetHashKey('WEAPON_STUNGUN')
    local arrestScenario = math.random(1, 2)
    local netId = NetworkGetNetworkIdFromEntity(npc)
    local entity = NetworkGetEntityFromNetworkId(netId)

    RequestAnimDict('missminuteman_1ig_2')
    while not HasAnimDictLoaded('missminuteman_1ig_2') do
        Wait(100)
    end

    if arrestScenario == 1 then
        ClearPedTasksImmediately(npc)
        TriggerEvent("playSyncedScene", entity, "missminuteman_1ig_2", "handsup_base")
        Wait(750)
        DoScreenFadeOut(500)
        Wait(800)
        TriggerServerEvent('arrestnpc', netId)
        Wait(100)
        Wait(100)
        StopPedScene(netId)
        StopPedScene(pednetId)
        Wait(500)
        DoScreenFadeIn(500)
        return
    end

    if Config.inventory == 'qb-inventory' then
        TriggerServerEvent('additem:qb', netId)
    else
        TriggerServerEvent('additem:ox', netId)
    end

    if IsPedMale(npc) then
        BeginTextCommandPrint('STRING')
        AddTextComponentString('Do not let the ~y~suspect~s~ escape! Use your stun gun to stop him.')
        EndTextCommandPrint(7000, false)
    else
        BeginTextCommandPrint('STRING')
        AddTextComponentString('Do not let the ~y~suspect~s~ escape! Use your stun gun to stop her.')
        EndTextCommandPrint(7000, false)
    end

    NetworkRequestControlOfEntity(npc)
    Wait(100)
    TaskSmartFleePed(npc, ped, 600.0, -1, true, false)

    Citizen.CreateThread(function()
        local arrested = false
        local animated = false

        while not arrested do
            Wait(0)

            local pedCoords = GetEntityCoords(ped)
            local npcCoords = GetEntityCoords(npc)
            local dist = #(npcCoords - pedCoords)

            if HasPedBeenDamagedByWeapon(npc, stungun, 0) and not animated then
                animated = true
                ClearPedTasksImmediately(npc)
                NetworkRequestControlOfEntity(npc)
                SetPedConfigFlag(npc, 249, true)
                SetEntityAsMissionEntity(npc, true, true)
                Wait(50)
                TriggerEvent('playSyncedScene', entity, "missminuteman_1ig_2", "handsup_base")
                SetBlockingOfNonTemporaryEvents(npc, true)
                FreezeEntityPosition(npc, true)
            end

            if animated and dist < 5.0 and HasPedBeenDamagedByWeapon(npc, stungun, 0) then
                AddTextEntry('pedinteraction', 'Press ~INPUT_CONTEXT~ to arrest the pedestrian')
                BeginTextCommandDisplayHelp('pedinteraction')
                EndTextCommandDisplayHelp(0, false, false, -1)
            end

            if IsControlJustReleased(0, 38) and dist < 5.0 and HasPedBeenDamagedByWeapon(npc, stungun, 0) then
                Wait(500)
                DoScreenFadeOut(500)
                Wait(800)
                TriggerServerEvent('arrestnpc', netId)
                Wait(100)
                Wait(100)
                StopPedScene(netId)
                StopPedScene(pednetId)
                Wait(500)
                DoScreenFadeIn(500)
                arrested = true
            end
        end
    end)
end)

RegisterNetEvent('npc:closeMenu')
AddEventHandler('npc:closeMenu', function(data)
    local npc = data.npc
    local netId = NetworkGetNetworkIdFromEntity(npc)

    if npc and DoesEntityExist(npc) then 
        TriggerServerEvent('exitclearance', netId)
    end
end)

RegisterNetEvent('Cleartasks')
AddEventHandler('Cleartasks', function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(entity) and IsEntityAPed(entity) then
        ClearPedTasks(entity)
    end
end)

RegisterNetEvent('deletenpc')
AddEventHandler('deletenpc', function(netId)
    local npc = NetworkGetEntityFromNetworkId(netId)
    if npc and DoesEntityExist(npc) then 
        DeleteEntity(npc) 
    end
end)
