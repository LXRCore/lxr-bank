--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-BANK — Client: tellers, blips, the teller page
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local B = LXRBank
local N = Citizen.InvokeNative
local tellers, blips, session = {}, {}, nil

local function toast(key, kind, vars) LXRCore.Notify(Lang:t(key, vars), kind or 'info') end

local function close()
    if not session then return end
    session = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function open(branch)
    if session then return end
    local ok, data, bundle, brand = LXR.RPC.Server('lxr-bank:open', branch.id)
    if not ok then return toast('error.' .. tostring(data), 'error') end
    session = { branch = branch }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data, locale = bundle, brand = brand or LXRCore.Brand, lang = Config.Lang })
end

local function act(name, ...)
    if not session then return { ok = false } end
    local ok, res, extra = LXR.RPC.Server('lxr-bank:' .. name, session.branch.id, ...)
    if not ok then toast('error.' .. tostring(res), 'error', { amount = extra, label = extra }) return { ok = false, why = res } end
    return { ok = true, data = res, extra = extra }
end

RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('deposit', function(d, cb) local r = act('deposit', d.account, d.amount) if r.ok then toast('info.deposited', 'success', { amount = ('%.2f'):format(d.amount or 0) }) end cb(r) end)
RegisterNUICallback('withdraw', function(d, cb) local r = act('withdraw', d.account, d.amount) if r.ok then toast('info.withdrawn', 'success', { amount = ('%.2f'):format(d.amount or 0) }) end cb(r) end)
RegisterNUICallback('draft', function(d, cb) local r = act('draft', d.number, d.amount) if r.ok then toast('info.drafted', 'success', { amount = ('%.2f'):format(d.amount or 0), number = d.number }) end cb(r) end)
RegisterNUICallback('cheque', function(d, cb) local r = act('cheque', d.amount) if r.ok then toast('info.cheque', 'success', { amount = ('%.2f'):format(d.amount or 0) }) end cb(r) end)
RegisterNUICallback('cash', function(d, cb) local r = act('cash', d.slot) if r.ok then toast('info.cashed', 'success', { amount = ('%.2f'):format(r.extra or 0) }) end cb(r) end)
RegisterNUICallback('notes', function(d, cb) local r = act('notes', d.n) cb(r) end)
RegisterNUICallback('society', function(d, cb) local r = act('society', d.book, d.amount) cb(r) end)
RegisterNUICallback('sound', function(d, cb) PlaySoundFrontend(d.name or 'NAV_UP', d.set or 'HUD_SHOP_SOUNDSET', true, 0) cb({}) end)

local function spawnTeller(branch)
    local model = joaat(branch.teller)
    if not IsModelValid(model) then return end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end
    local ped = CreatePed(model, branch.coords.x, branch.coords.y, branch.coords.z - 1.0, branch.heading or 0.0, false, false, false, false)
    N(0x283978A15512B2FE, ped, true)
    SetEntityInvincible(ped, true) SetBlockingOfNonTemporaryEvents(ped, true) FreezeEntityPosition(ped, true) SetEntityCanBeDamaged(ped, false)
    SetModelAsNoLongerNeeded(model)
    tellers[branch.id] = ped
    exports['lxr-interact']:AddEntity('lxr-bank:' .. branch.id, ped, { label = branch.label, distance = Config.Security.promptDistance, options = {
        { label = Lang:t('ui.teller'), key = 'J', onSelect = function() open(branch) end },
    }})
end
local function removeTeller(branch)
    local ped = tellers[branch.id]
    if not ped then return end
    exports['lxr-interact']:Remove('lxr-bank:' .. branch.id)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    tellers[branch.id] = nil
end

CreateThread(function()
    for _, b in ipairs(Config.Branches) do
        if b.blip then
            local blip = N(0x554D9D53F696D002, 1664425300, b.coords.x, b.coords.y, b.coords.z)
            if blip and blip ~= 0 then
                N(0x74F74D3207ED525C, blip, joaat('blip_shop_bank'), true)
                N(0x9CB1A1623062F402, blip, b.label)
                if GetResourceState('lxr-mapcolor') == 'started' then pcall(function() N(0x662D364ABF16DE2F, blip, exports['lxr-mapcolor']:modifier()) end) end
                blips[#blips + 1] = blip
            end
        end
    end
    while true do
        if LocalPlayer.state.isLoggedIn then
            local pos = GetEntityCoords(PlayerPedId())
            for _, b in ipairs(Config.Branches) do
                local d = #(pos - b.coords)
                if d < 60.0 and not tellers[b.id] then spawnTeller(b) elseif d > 80.0 and tellers[b.id] then removeTeller(b) end
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent('lxr:client:unloaded', function() close() for _, b in ipairs(Config.Branches) do removeTeller(b) end end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    close()
    for _, bl in ipairs(blips) do RemoveBlip(bl) end
    for _, b in ipairs(Config.Branches) do removeTeller(b) end
end)

exports('Open', function(id) local b = B.Branch(id) if b then open(b) end end)
exports('IsOpen', function() return session ~= nil end)
