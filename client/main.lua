local config = require 'config.client'
local sharedConfig = require 'config.shared'
local isLoggedIn = LocalPlayer.state.isLoggedIn
local dutyZone, stashZone, garageZone = nil, nil, nil

VehicleStatus = {}

local closestPlate = nil
local openingDoor = false

-- zone check
local isInsideVehiclePlateZone = false
local plateZones = {}
local plateTargetBoxId = 'plateTarget_'

-- Exports

---@param plate string
---@return table?
local function getVehicleStatusList(plate)
    if VehicleStatus[plate] then
        return VehicleStatus[plate]
    end
end

local function getVehicleStatus(plate, part)
    if VehicleStatus[plate] then
        return VehicleStatus[plate][part]
    end
end

local function setVehicleStatus(plate, part, level)
    TriggerServerEvent("vehiclemod:server:updatePart", plate, part, level)
end

exports('GetVehicleStatusList', getVehicleStatusList)
exports('GetVehicleStatus', getVehicleStatus)
exports('SetVehicleStatus', setVehicleStatus)

-- Functions
local function getDutyLabelText()
    if config.useTarget then
        local text = onDuty and Lang:t("labels.clock_out") or Lang:t("labels.clock_in")
        return text
    else
        local text = onDuty and Lang:t("labels.point_clock_out") or Lang:t("labels.point_clock_in")
        return text
    end
end

local function registerDutyZone()
    local coords = vector3(sharedConfig.locations.duty.x, sharedConfig.locations.duty.y, sharedConfig.locations.duty.z)

    if config.useTarget then
        dutyZone = exports.ox_target:addBoxZone({
            name = 'dutyZoneTarget',
            coords = coords,
            rotation = 340.0,
            size = vec3(3.9, 1.25, 2.3),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa-solid fa-house',
                    type = 'client',
                    event = 'qbx_mechanicjob:client:target:toggleDuty',
                    label = getDutyLabelText(),
                    distance = 1
                },
            },
        })
    else
        dutyZone = lib.zones.box({
            coords = coords,
            rotation = 340.0,
            size = vec3(3.9, 1.25, 2.3),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(getDutyLabelText())
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustPressed(0, 38) then
                    TriggerEvent('qbx_mechanicjob:client:target:toggleDuty')
                    lib.hideTextUI()
                end
            end
        })
    end
end

local function destroyDutyZone()
    if not dutyZone then return end

    dutyZone:remove()
    dutyZone = nil
end

local function registerStashZone()
    local coords = vector3(sharedConfig.locations.stash.x, sharedConfig.locations.stash.y, sharedConfig.locations.stash.z)

    if config.useTarget then
        stashZone = exports.ox_target:addBoxZone({
            name = 'stashZoneTarget',
            coords = coords,
            rotation = 340.0,
            size = vec3(1.15, 1.6, 2.15),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa fa-archive',
                    type = 'client',
                    event = 'qb-mechanicjob:client:target:OpenStash',
                    label = Lang:t('labels.o_stash'),
                    distance = 1
                },
            },
        })
    else
        stashZone = lib.zones.box({
            coords = coords,
            rotation = 340.0,
            size = vec3(1.15, 1.6, 2.15),
            debug = config.debugPoly,
            onEnter = function()
                lib.showTextUI(Lang:t('labels.o_stash'))
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustPressed(0, 38) then
                    TriggerEvent('qb-mechanicjob:client:target:OpenStash')
                    lib.hideTextUI()
                end
            end
        })
    end
end

local function destroyStashZone()
    if not stashZone then return end

    stashZone:remove()
    stashZone = nil
end

local function registerGarageZone()
    local coords = vector3(sharedConfig.locations.garage.x, sharedConfig.locations.garage.y,
        sharedConfig.locations.garage.z)

    if config.useTarget then
        garageZone = exports.ox_target:addBoxZone({
            name = 'stashZoneTarget',
            coords = coords,
            rotation = 340.0,
            size = vec3(16.0, 5.8, 4.0),
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fa fa-archive',
                    type = 'client',
                    event = 'qb-mechanicjob:client:target:OpenStash',
                    label = Lang:t('labels.o_stash'),
                    distance = 1
                },
            },
        })
    else
        garageZone = lib.zones.box({
            coords = coords,
            rotation = 340.0,
            size = vec3(16.0, 5.8, 4.0),
            debug = config.debugPoly,
            onEnter = function()
                if QBX.PlayerData.job.onduty then
                    if cache.vehicle then
                        lib.showTextUI(Lang:t('labels.h_vehicle'))
                    else
                        lib.showTextUI(Lang:t('labels.g_vehicle'))
                    end
                end
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustPressed(0, 38) then
                    if cache.vehicle then
                        DeleteVehicle(cache.vehicle)
                        lib.hideTextUI()
                    else
                        lib.showContext('mechanicVehicles')
                        lib.hideTextUI()
                    end
                end
            end
        })
    end
end

local function destroyGarageZone()
    if not garageZone then return end

    garageZone:remove()
    garageZone = nil
end

local function destroyVehiclePlateZone(id)
    if plateZones[id] then
        plateZones[id]:destroy()
        plateZones[id] = nil
    end
end

local function registerVehiclePlateZone(id, plate)
    local coords = plate.coords
    local boxData = plate.boxData
    local plateZone = BoxZone:Create(coords.xyz, boxData.length, boxData.width, {
        name = plateTargetBoxId .. id,
        heading = boxData.heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 3.0,
        debugPoly = boxData.debugPoly
    })

    plateZones[id] = plateZone

    plateZone:onPlayerInOut(function (isPointInside)
        if isPointInside and QBX.PlayerData.job.onduty then
            if plate.AttachedVehicle then
                lib.showTextUI(Lang:t('labels.o_menu'), {
                    position = 'left'
                })
            elseif cache.vehicle then
                lib.showTextUI(Lang:t('labels.work_v'), {
                    position = 'left'
                })
            end
        else
            lib.hideTextUI()
        end

        isInsideVehiclePlateZone = isPointInside
    end)
end

local function setVehiclePlateZones()
    if #sharedConfig.plates > 0 then
        for i = 1, #sharedConfig.plates do
            local plate = sharedConfig.plates[i]
            registerVehiclePlateZone(i, plate)
        end
    else
        print('No vehicle plates configured')
    end
end

local function setClosestPlate()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local closestDist = nil

    for i = 1, #sharedConfig.plates do
        local plate = sharedConfig.plates[i]
        local distance = #(pos - plate.coords.xyz)
        if not current or distance < closestDist then
            closestDist = distance
            current = i
        end
    end
    closestPlate = current
end

local function scrapAnim(time)
    time = time / 1000
    lib.requestAnimDict('mp_car_bomb')
    TaskPlayAnim(cache.ped, "mp_car_bomb", "car_bomb_mechanic" ,3.0, 3.0, -1, 16, 0, false, false, false)
    openingDoor = true
    CreateThread(function()
        repeat
            TaskPlayAnim(cache.ped, "mp_car_bomb", "car_bomb_mechanic", 3.0, 3.0, -1, 16, 0, false, false, false)
            Wait(2000)
            time -= 2
            if time <= 0 then
                openingDoor = false
                StopAnimTask(cache.ped, "mp_car_bomb", "car_bomb_mechanic", 1.0)
            end
        until not openingDoor
    end)
end

local function round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 1) .. "f", num))
end

local function sendStatusMessage(statusList)
    if not statusList then return end
    TriggerEvent('chat:addMessage', {
        template = '<div class="chat-message normal"><div class="chat-message-body"><strong>{0}:</strong><br><br> <strong>'.. config.partLabels.engine ..' (engine):</strong> {1} <br><strong>'.. config.partLabels.body ..' (body):</strong> {2} <br><strong>'.. config.partLabels.radiator ..' (radiator):</strong> {3} <br><strong>'.. config.partLabels.axle ..' (axle):</strong> {4}<br><strong>'.. config.partLabels.brakes ..' (brakes):</strong> {5}<br><strong>'.. config.partLabels.clutch ..' (clutch):</strong> {6}<br><strong>'.. config.partLabels.fuel ..' (fuel):</strong> {7}</div></div>',
        args = {Lang:t('labels.veh_status'), round(statusList.engine) .. "/" .. sharedConfig.maxStatusValues.engine .. " ("..exports.ox_inventory:Items()['advancedrepairkit'].label..")", round(statusList.body) .. "/" .. sharedConfig.maxStatusValues.body .. " ("..exports.ox_inventory:Items()[sharedConfig.repairCost.body].label..")", round(statusList.radiator) .. "/" .. sharedConfig.maxStatusValues.radiator .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.radiator].label..")", round(statusList.axle) .. "/" .. sharedConfig.maxStatusValues.axle .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.axle].label..")", round(statusList.brakes) .. "/" .. sharedConfig.maxStatusValues.brakes .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.brakes].label..")", round(statusList.clutch) .. "/" .. sharedConfig.maxStatusValues.clutch .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.clutch].label..")", round(statusList.fuel) .. "/" .. sharedConfig.maxStatusValues.fuel .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.fuel].label..")"}
    })
end

local function unattachVehicle()
    DoScreenFadeOut(150)
    Wait(150)
    local plate = sharedConfig.plates[closestPlate]
    FreezeEntityPosition(plate.AttachedVehicle, false)
    SetEntityCoords(plate.AttachedVehicle, plate.coords.x, plate.coords.y, plate.coords.z, false, false, false, false)
    SetEntityHeading(plate.AttachedVehicle, plate.coords.w)
    TaskWarpPedIntoVehicle(cache.ped, plate.AttachedVehicle, -1)
    Wait(500)
    DoScreenFadeIn(250)

    plate.AttachedVehicle = nil
    TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', false, closestPlate)

    destroyVehiclePlateZone(closestPlate)
    registerVehiclePlateZone(closestPlate, plate)
end

local function checkStatus()
    local plate = GetPlate(sharedConfig.plates[closestPlate].AttachedVehicle)
    sendStatusMessage(VehicleStatus[plate])
end

local function repairPart(part)
    exports.scully_emotemenu:playEmoteByCommand('mechanic')
    if lib.progressBar({
        duration = math.random(5000, 10000),
        label = Lang:t('labels.progress_bar') .. string.lower(config.partLabels[part]),
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        }
    }) then
        exports.scully_emotemenu:cancelEmote()
        TriggerServerEvent('qb-vehicletuning:server:CheckForItems', part)
        SetTimeout(250, function()
            OpenVehicleStatusMenu()
        end)
    else
        exports.scully_emotemenu:cancelEmote()
        exports.qbx_core:Notify(Lang:t('notifications.rep_canceled'), "error")
    end
end

local function openPartMenu(data)
    local partName = data.name
    local part = data.parts
    local options = {
        {
            title = partName,
            description = Lang:t('parts_menu.repair_op')..exports.ox_inventory:Items()[sharedConfig.repairCostAmount[part].item].label.." "..sharedConfig.repairCostAmount[part].costs.."x",
            onSelect = function()
                repairPart(part)
            end,
        },
    }

    lib.registerContext({
        id = 'part',
        title = Lang:t('parts_menu.menu_header'),
        options = options,
        menu = 'vehicleStatus',
    })

    lib.showContext('part')
end

function OpenVehicleStatusMenu()
    local plate = GetPlate(sharedConfig.plates[closestPlate].AttachedVehicle)
    if not VehicleStatus[plate] then return end

    local options = {}

    for partName, label in pairs(config.partLabels) do
        if math.ceil(VehicleStatus[plate][partName]) ~= sharedConfig.maxStatusValues[partName] then
            local percentage = math.ceil(VehicleStatus[plate][partName])
            if percentage > 100 then
                percentage = math.ceil(VehicleStatus[plate][partName]) / 10
            end
            options[#options+1] = {
                title = label,
                description = "Status: " .. percentage .. ".0% / 100.0%",
                onSelect = function()
                    openPartMenu({
                        name = label,
                        parts = partName
                    })
                end,
                arrow = true,
            }
        else
            local percentage = math.ceil(sharedConfig.maxStatusValues[partName])
            if percentage > 100 then
                percentage = math.ceil(sharedConfig.maxStatusValues[partName]) / 10
            end
            options[#options+1] = {
                title = label,
                description = Lang:t('parts_menu.status') .. percentage .. ".0% / 100.0%",
                onSelect = OpenVehicleStatusMenu,
                arrow = true,
            }
        end
    end

    lib.registerContext({
        id = 'vehicleStatus',
        title = Lang:t('labels.status'),
        options = options,
    })

    lib.showContext('vehicleStatus')
end

local function resetClosestVehiclePlate()
    destroyVehiclePlateZone(closestPlate)
    registerVehiclePlateZone(closestPlate, sharedConfig.plates[closestPlate])
end

local function spawnListVehicle(vehType)
    local coords = {
        x = sharedConfig.locations.garage.x,
        y = sharedConfig.locations.garage.y,
        z = sharedConfig.locations.garage.z,
        w = sharedConfig.locations.garage.w,
    }

    local netId = lib.callback.await('qbx_mechanicjob:server:spawnVehicle', false, vehType, coords, Lang:t('labels.mech_plate')..tostring(math.random(1000, 9999)), true)
    local timeout = 100
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end
    local veh = NetToVeh(netId)
    if veh == 0 then
        exports.qbx_core:Notify(Lang:t('error.cant_spawn_vehicle'), 'error')
        return
    end
    local vehClass = GetVehicleClass(veh)
    if vehClass == 12 then
        SetVehicleLivery(veh, 2)
    end
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleFuelLevel(veh, 100.0)
    TaskWarpPedIntoVehicle(cache.ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    CurrentPlate = GetPlate(veh)
end

-- Events

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    if QBX.PlayerData.job.onduty and QBX.PlayerData.type == 'mechanic' then
        TriggerServerEvent("QBCore:ToggleDuty")
    end
    lib.callback('qb-vehicletuning:server:GetAttachedVehicle', false, function(plates)
        for k, v in pairs(plates) do
            sharedConfig.plates[k].AttachedVehicle = v.AttachedVehicle
        end
    end)

    lib.callback('qb-vehicletuning:server:GetDrivingDistances', false, function(retval)
        DrivingDistance = retval
    end)
end)

RegisterNetEvent('qbx_mechanicjob:client:target:toggleDuty', function()
    onDuty = not onDuty

    if onDuty then
        exports.qbx_core:Notify(Lang:t("notifications.you_have_been_clocked_in"), 'success')
    else
        exports.qbx_core:Notify(Lang:t("notifications.you_have_clocked_out"), 'error')
    end
end)

RegisterNetEvent('qb-vehicletuning:client:SetAttachedVehicle', function(veh, key)
    if veh ~= false then
        sharedConfig.plates[key].AttachedVehicle = veh
    else
        sharedConfig.plates[key].AttachedVehicle = nil
    end
end)

RegisterNetEvent('qb-vehicletuning:client:RepaireeePart', function(part)
    local veh = sharedConfig.plates[closestPlate].AttachedVehicle
    local plate = GetPlate(veh)
    if part == "engine" then
        SetVehicleEngineHealth(veh, sharedConfig.maxStatusValues[part])
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", sharedConfig.maxStatusValues[part])
    elseif part == "body" then
        local enhealth = GetVehicleEngineHealth(veh)
        local realFuel = GetVehicleFuelLevel(veh)
        SetVehicleBodyHealth(veh, sharedConfig.maxStatusValues[part])
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", sharedConfig.maxStatusValues[part])
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, enhealth)
        if GetVehicleFuelLevel(veh) ~= realFuel then
            SetVehicleFuelLevel(veh, realFuel)
        end
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, part, sharedConfig.maxStatusValues[part])
    end
    exports.qbx_core:Notify(Lang:t('notifications.partrep', {value = config.partLabels[part]}))
end)

RegisterNetEvent('vehiclemod:client:setVehicleStatus', function(plate, status)
    VehicleStatus[plate] = status
end)

RegisterNetEvent('vehiclemod:client:getVehicleStatus', function()
    if cache.vehicle then
        exports.qbx_core:Notify(Lang:t('notifications.outside'), "error")
        return
    end
    local veh = GetVehiclePedIsIn(cache.ped, true)
    if not veh or veh == 0 then
        exports.qbx_core:Notify(Lang:t('notifications.veh_first'), "error")
        return
    end

    local vehpos = GetEntityCoords(veh)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - vehpos) >= 5.0 then
        exports.qbx_core:Notify(Lang:t('notifications.not_close'), "error")
        return
    end
    if IsThisModelABicycle(GetEntityModel(veh)) then
        exports.qbx_core:Notify(Lang:t('notifications.not_valid'), "error")
        return
    end
    local plate = GetPlate(veh)
    if not VehicleStatus[plate] then
        exports.qbx_core:Notify(Lang:t('notifications.uknown'), "error")
        return
    end

    sendStatusMessage(VehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:client:fixEverything', function()
    local veh = cache.vehicle
    if not veh then
        exports.qbx_core:Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        exports.qbx_core:Notify(Lang:t('notifications.wrong_seat'), "error")
    end

    local plate = GetPlate(veh)
    TriggerServerEvent("vehiclemod:server:fixEverything", plate)
end)

RegisterNetEvent('vehiclemod:client:setPartLevel', function(part, level)
    local veh = cache.vehicle
    if not veh then
        exports.qbx_core:Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        exports.qbx_core:Notify(Lang:t('notifications.wrong_seat'), "error")
        return
    end

    local plate = GetPlate(veh)
    if part == "engine" then
        SetVehicleEngineHealth(veh, level)
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", GetVehicleEngineHealth(veh))
    elseif part == "body" then
        SetVehicleBodyHealth(veh, level)
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", GetVehicleBodyHealth(veh))
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, part, level)
    end
end)

RegisterNetEvent('vehiclemod:client:repairPart', function(part, level, needAmount)

    -- FIXME: if ped is in a vehicle then we tell them they aren't in a vehicle? Something is wrong here.
    if cache.vehicle then
        exports.qbx_core:Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end
    local veh = GetVehiclePedIsIn(cache.ped, true)
    if not veh or veh == 0 then
        exports.qbx_core:Notify(Lang:t('notifications.veh_first'), "error")
        return
    end

    local vehpos = GetEntityCoords(veh)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - vehpos) >= 5.0 then
        exports.qbx_core:Notify(Lang:t('notifications.not_close'), "error")
        return
    end
    if IsThisModelABicycle(GetEntityModel(veh)) then
        exports.qbx_core:Notify(Lang:t('notifications.not_valid'), "error")
        return
    end
    local plate = GetPlate(veh)
    if not VehicleStatus[plate] or not VehicleStatus[plate][part] then
        exports.qbx_core:Notify(Lang:t('notifications.not_part'), "error")
        return
    end

    local lockpickTime = (1000 * level)
    if part == "body" then
        lockpickTime = lockpickTime / 10
    end
    scrapAnim(lockpickTime)
    if lib.progressBar({
        duration = lockpickTime,
        label = Lang:t('notifications.progress_bar'),
        canCancel = true,
        anim = {
            dict = 'mp_car_bomb',
            clip = 'car_bomb_mechanic',
            flag = 16,
        }
    }) then
        openingDoor = false
        ClearPedTasks(cache.ped)
        if part == "body" then
            local enhealth = GetVehicleEngineHealth(veh)
            SetVehicleBodyHealth(veh, GetVehicleBodyHealth(veh) + level)
            SetVehicleFixed(veh)
            SetVehicleEngineHealth(veh, enhealth)
            TriggerServerEvent("vehiclemod:server:updatePart", plate, part, GetVehicleBodyHealth(veh))
            TriggerServerEvent("qb-mechanicjob:server:removePart", part, needAmount)
        elseif part ~= "engine" then
            TriggerServerEvent("vehiclemod:server:updatePart", plate, part, getVehicleStatus(plate, part) + level)
            TriggerServerEvent("qb-mechanicjob:server:removePart", part, level)
        end
    else
        openingDoor = false
        ClearPedTasks(cache.ped)
        exports.qbx_core:Notify(Lang:t('notifications.process_canceled'), "error")
    end
end)

AddEventHandler('qb-mechanicjob:client:target:OpenStash', function ()
    exports.ox_inventory:openInventory('stash', {id='mechanicstash'})
end)

-- Threads
local function createBlip()
    local blip = AddBlipForCoord(sharedConfig.locations.main.x, sharedConfig.locations.main.y, sharedConfig.locations.main.z)
    SetBlipSprite(blip, 446)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Lang:t('labels.job_blip'))
    EndTextCommandSetBlipName(blip)
end

CreateThread(function()
    while true do
        Wait(1000)
        local wait = UpdatePartHealth()
        Wait(wait)
    end
end)


--- STATIC MENUS

local function registerLiftMenu()
    local options = {
        {
            title = Lang:t('lift_menu.header_vehdc'),
            description = Lang:t('lift_menu.desc_vehdc'),
            onSelect = unattachVehicle,
        },
        {
            title = Lang:t('lift_menu.header_stats'),
            description = Lang:t('lift_menu.desc_stats'),
            onSelect = checkStatus,
        },
        {
            title = Lang:t('lift_menu.header_parts'),
            description = Lang:t('lift_menu.desc_parts'),
            arrow = true,
            onSelect = OpenVehicleStatusMenu,
        },
    }
    lib.registerContext({
        id = 'lift',
        title = Lang:t('lift_menu.header_menu'),
        onExit = resetClosestVehiclePlate,
        options = options,
    })
end

local function registerVehicleListMenu()
    local options = {}
    for k,v in pairs(config.vehicles) do
        options[#options+1] = {
            title = v,
            description = Lang:t('labels.vehicle_title', {value = v}),
            onSelect = function()
                spawnListVehicle(k)
            end,
        }
    end

    lib.registerContext({
        id = 'mechanicVehicles',
        title = Lang:t('labels.vehicle_list'),
        options = options,
    })
end

registerLiftMenu()
registerVehicleListMenu()

local function init()
    if QBX.PlayerData.job.name == 'mechanic' then
        createBlip()
        registerGarageZone()
        registerDutyZone()
        registerStashZone()
        setVehiclePlateZones()
    end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    destroyDutyZone()
    destroyStashZone()
    destroyGarageZone()
    init()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    init()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

CreateThread(function()
    if not isLoggedIn then return end
    init()
end)