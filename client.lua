local userSpeedLimitMps = nil -- ユーザー設定の上限（m/s）
local lastAppliedMax = nil            -- 直近に適用した上限（m/s）
local lastApplyMs = 0                 -- 直近適用時刻（ms）
local engaged = false                 -- 速度制限が今オンかどうか
local manualEngaged = false           -- UIで制限を設定/解除した直後だけ true。自動解除を一時的に防ぐ
local prohibitedActive = false        -- 犯罪利用禁止車両表示フラグ

-- 指定ワードが車種名またはナンバープレートに含まれるか判定
local function isProhibitedVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false end

    local modelHash = GetEntityModel(vehicle)
    local plate = (GetVehicleNumberPlateText(vehicle) or "")

    -- モデル名（スポーン名）での判定（== ハッシュ一致）
    if type(Config.prohibitModelNames) == 'table' and #Config.prohibitModelNames > 0 then
        for _, name in ipairs(Config.prohibitModelNames) do
            local n = tostring(name or "")
            if #n > 0 then
                if GetHashKey(n) == modelHash or GetHashKey(string.lower(n)) == modelHash or GetHashKey(string.upper(n)) == modelHash then
                    return true
                end
            end
        end
    end

    -- ナンバープレートの部分一致
    if type(Config.prohibitPlateWords) == 'table' and #Config.prohibitPlateWords > 0 then
        local plateLower = string.lower(plate)
        for _, word in ipairs(Config.prohibitPlateWords) do
            local needle = string.lower(tostring(word or ""))
            if #needle > 0 and string.find(plateLower, needle, 1, true) then
                return true
            end
        end
    end

    return false
end

-- 上限制御を解除する共通関数
local function resetMaxSpeedSafe(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local deadline = GetGameTimer() + 500
    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
            Citizen.Wait(0)
        end
    end
    -- ネイティブ既定へ戻す
    SetVehicleMaxSpeed(vehicle, 0.0)
    lastAppliedMax = nil
    engaged = false
end

-- 上限を適用
local function setMaxSpeedSafe(vehicle, capMps)
    if not DoesEntityExist(vehicle) then return false end
    local deadline = GetGameTimer() + 500
    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
            Citizen.Wait(0)
        end
    end
    if NetworkHasControlOfEntity(vehicle) then
        SetEntityMaxSpeed(vehicle, capMps)
        return true
    end
    return false
end

if Config.vehiclespeedlimiter then
    Citizen.CreateThread(function()
        local inVehicle = false
        local cachedVehClass = nil             -- 車両クラスキャッシュ
        local cachedLimit = nil                -- 制限速度キャッシュ（m/s）
        local cachedDefaultMaxSpeed = nil      -- デフォルト最高速度キャッシュ（m/s）

        while true do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
                if inVehicle then
                    -- 降車時にキャッシュをリセット
                    inVehicle = false
                    cachedVehClass = nil
                    cachedLimit = nil
                    cachedDefaultMaxSpeed = nil
					lastAppliedMax = nil
					lastApplyMs = 0
                    engaged = false
                    prohibitedActive = false
                    SendNUIMessage({ action = 'prohibit', show = false })
                    if Config.debug then
                        print("[DEBUG] Exited vehicle. Caches reset.")
                    end
                end
                Citizen.Wait(1000)  -- 非乗車時
            else
                -- 乗車中
                if not inVehicle then
                    inVehicle = true

                    if not DoesEntityExist(vehicle) then
                        if Config.debug then
                            print("[ERROR] Vehicle entity is invalid.")
                        end
                        Citizen.Wait(100)
                    else
                        -- 乗車直後は一度ネイティブ既定へ戻して残留キャップを解除
                        resetMaxSpeedSafe(vehicle)
                        cachedVehClass = GetVehicleClass(vehicle)

                        -- 犯罪利用禁止車両チェック（車種名/ナンバー）
                        prohibitedActive = isProhibitedVehicle(vehicle)
                        if prohibitedActive then
                            SendNUIMessage({ action = 'prohibit', show = true })
                            if Config.debug then
                                print("[DEBUG] Prohibited vehicle detected. Showing banner.")
                            end
                        else
                            SendNUIMessage({ action = 'prohibit', show = false })
                        end

                        -- 除外車両（ヘリ:15、飛行機:16）は対象外
                        if cachedVehClass == 15 or cachedVehClass == 16 then
                            cachedLimit = nil
                            if Config.debug then
                                print("[DEBUG] Exempt vehicle class (" .. tostring(cachedVehClass) .. "). Skipping speed limiter.")
                            end
                        else
                            -- ハンドリングデータ取得
                            local ok, defaultMaxSpeed = pcall(function()
                                return GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
                            end)
                            if (not ok) or defaultMaxSpeed == 0 then
                                if Config.debug then
                                    print("[ERROR] Failed to retrieve handling data. Using fallback value.")
                                end
                                defaultMaxSpeed = 50.0  -- フォールバック（約180km/h）
                            end
                            cachedDefaultMaxSpeed = defaultMaxSpeed

                            -- 緊急車両(18)は別上限
                            if cachedVehClass == 18 then
                                cachedLimit = Config.emergencyspeedlimit
                            else
                                cachedLimit = Config.speedlimit
                            end

                            if Config.debug then
                                print(string.format(
                                    "[DEBUG] Entered vehicle. Class: %d, DefaultMaxSpeed: %.2f m/s (%.2f km/h), Limit: %.2f m/s (%.2f km/h)",
                                    cachedVehClass,
                                    cachedDefaultMaxSpeed, cachedDefaultMaxSpeed * 3.6,
                                    cachedLimit, cachedLimit * 3.6
                                ))
                            end
                        end
                    end
                end

                if cachedLimit then
                    Citizen.Wait(33)  -- 対象車両乗車中は高頻度チェック

                    if DoesEntityExist(vehicle) and cachedDefaultMaxSpeed then
                        local speed = GetEntitySpeed(vehicle)
                        local effectiveLimit = cachedLimit
                        if userSpeedLimitMps and userSpeedLimitMps > 0 then
                            if userSpeedLimitMps < effectiveLimit then
                                effectiveLimit = userSpeedLimitMps
                            end
                            -- 上げ方向の反映が止まらないよう、現在の適用値より大きくなったら即一度だけ適用
                            if (not lastAppliedMax) or lastAppliedMax < effectiveLimit then
                                setMaxSpeedSafe(vehicle, effectiveLimit)
                                lastAppliedMax = effectiveLimit
                                lastApplyMs = GetGameTimer()
                                engaged = true
                            end
                        end
                        -- 速度が上限以上なら制限ON、下限未満になったら制限OFFにする
                        -- 上限と下限に少し差をつけて、ON/OFFが頻繁に切り替わらないようにする
                        local now = GetGameTimer()
                        local thresholdHigh = effectiveLimit                      -- 上限(これ以上で制限ON) [m/s]
                        local thresholdLow = math.max(0.0, effectiveLimit - (3/3.6)) -- 下限(これ未満で制限OFF)。上限より少し低く設定 [m/s]
                        if speed >= thresholdHigh then
                            if (not lastAppliedMax) or lastAppliedMax ~= effectiveLimit or (now - lastApplyMs) >= 250 then
                                setMaxSpeedSafe(vehicle, effectiveLimit)
                                lastAppliedMax = effectiveLimit
                                lastApplyMs = now
                            end
                            engaged = true
                            manualEngaged = false
                        elseif engaged and (not manualEngaged) and speed <= thresholdLow then
                            SetVehicleMaxSpeed(vehicle, 0.0)
                            lastAppliedMax = nil
                            lastApplyMs = now
                            engaged = false
                        end
                    else
                        -- エンティティが無効、もしくはハンドリング未取得時は一時的に待機
                        Citizen.Wait(500)
                    end
                else
                    Citizen.Wait(1200)  -- 対象外時
                end
            end
        end
    end)
end

-- 車両武器の無効化（ドライブバイ等）
if not Config.vehicleweapons then
    Citizen.CreateThread(function()
        local inVehicle = false

        while true do
            local wait = 500
            local playerped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerped, false)

            if vehicle ~= 0 then
                wait = 20
                if not inVehicle then
                    inVehicle = true
                    SetPlayerCanDoDriveBy(PlayerId(), false)
                    if Config.debug then
                        print("[DEBUG] Drive-by disabled.")
                    end
                end

                if DoesVehicleHaveWeapons(vehicle) == 1 then
                    local hasWeapon, weaponHash = GetCurrentPedVehicleWeapon(playerped)
                    if hasWeapon == 1 then
                        DisableVehicleWeapon(true, weaponHash, vehicle, playerped)
                    end
                end
            else
                if inVehicle then
                    inVehicle = false
                    SetPlayerCanDoDriveBy(PlayerId(), true)
                    if Config.debug then
                        print("[DEBUG] Drive-by restored.")
                    end
                end
            end

            Citizen.Wait(wait)
        end
    end)
end

-- -- デバッグ用コマンド: checkSpeedLimits
-- RegisterCommand("checkSpeedLimits", function()
--     local ped = PlayerPedId()
--     local vehicle = GetVehiclePedIsIn(ped, false)

--     if vehicle == 0 then
--         print("You are not in a vehicle.")
--         return
--     end

--     if GetPedInVehicleSeat(vehicle, -1) ~= ped then
--         print("You are not in the driver's seat.")
--         return
--     end

--     if not DoesEntityExist(vehicle) then
--         print("Vehicle entity is invalid.")
--         return
--     end

--     local ok, defaultSpeed = pcall(function()
--         return GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
--     end)
--     if (not ok) or (not defaultSpeed) or defaultSpeed <= 0 then
--         defaultSpeed = 50.0
--     end

--     local vehClass = GetVehicleClass(vehicle)
--     local limit = nil

--     if vehClass == 15 or vehClass == 16 then
--         print("This vehicle is not subject to speed limits.")
--         return
--     elseif vehClass == 18 then
--         limit = Config.emergencyspeedlimit
--     else
--         limit = Config.speedlimit
--     end

--     local currentSpeed = GetEntitySpeed(vehicle)
--     local userLimit = (userSpeedLimitMps and userSpeedLimitMps > 0) and userSpeedLimitMps or nil
--     local effectiveCap = limit
--     if userLimit and userLimit < effectiveCap then
--         effectiveCap = userLimit
--     end
--     local vehicleModel = GetEntityModel(vehicle)
--     local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)

--     print(string.format("Vehicle: %s (Class: %d)", vehicleName, vehClass))
--     print(string.format("Configured Class Limit: %.2f m/s (%.2f km/h)", limit, limit * 3.6))
--     if userLimit then
--         print(string.format("User Limit: %.2f m/s (%.2f km/h)", userLimit, userLimit * 3.6))
--     else
--         print("User Limit: (none)")
--     end
--     print(string.format("Effective Cap (min): %.2f m/s (%.2f km/h)", effectiveCap, effectiveCap * 3.6))
--     if currentSpeed >= 0.1 then
--         print(string.format("Current Speed: %.2f m/s (%.2f km/h)", currentSpeed, currentSpeed * 3.6))
--     end

-- end, false)

-- 速度制限UIを開く関数
local function openSpeedLimitUI()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        print("You must be driving a vehicle to use /speedlimit.")
        return
    end

    local vehClass = GetVehicleClass(vehicle)
    -- ヘリ(15)/飛行機(16)はUIを使えなくする
    if vehClass == 15 or vehClass == 16 then
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName("この車両（ヘリ/飛行機）は速度制限の対象外です。")
        EndTextCommandThefeedPostTicker(false, false)
        return
    end
    local maxLimit = (vehClass == 18) and Config.emergencyspeedlimit or Config.speedlimit
    local currentKmh
    if userSpeedLimitMps and userSpeedLimitMps > 0 then
        currentKmh = math.floor((userSpeedLimitMps * 3.6) + 0.5)
    else
        currentKmh = math.floor((maxLimit * 3.6) + 0.5)
    end

    SendNUIMessage({ action = 'open', maxKmh = maxLimit * 3.6, currentKmh = currentKmh })
    SetNuiFocus(true, true)
end

-- /speedlimit コマンド: UIを開く
RegisterCommand("speedlimit", function()
    openSpeedLimitUI()
end, false)

-- ラジアルメニュー用のイベント
RegisterNetEvent('nekot-limit2:openUI')
AddEventHandler('nekot-limit2:openUI', function()
    openSpeedLimitUI()
end)

-- NUI : 適用
RegisterNUICallback('applySpeedLimit', function(data, cb)
    local kmh = tonumber(data and data.kmh) or 0
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        cb({ ok = false })
        return
    end

    local vehClass = GetVehicleClass(vehicle)
    local hardMax = (vehClass == 18) and Config.emergencyspeedlimit or Config.speedlimit
    local mps = math.max(0.0, math.min(hardMax, kmh / 3.6))

    userSpeedLimitMps = (mps > 0) and mps or nil
    if Config.debug then
        print(string.format("[DEBUG] userSpeedLimitMps set to: %s m/s (%.2f km/h)", tostring(userSpeedLimitMps), (userSpeedLimitMps or 0) * 3.6))
    end

    if DoesEntityExist(vehicle) then
        resetMaxSpeedSafe(vehicle)
        local effectiveCap = (userSpeedLimitMps and userSpeedLimitMps > 0) and math.min(hardMax, userSpeedLimitMps) or hardMax
        if setMaxSpeedSafe(vehicle, effectiveCap) then
            lastAppliedMax = effectiveCap
            lastApplyMs = GetGameTimer()
            engaged = true
            manualEngaged = true
        end
    end

    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- NUI : リセット
RegisterNUICallback('clearSpeedLimit', function(_, cb)
    userSpeedLimitMps = nil
    if Config.debug then
        print("[DEBUG] userSpeedLimitMps cleared")
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        resetMaxSpeedSafe(vehicle)
        local vehClass = GetVehicleClass(vehicle)
        local hardMax = (vehClass == 18) and Config.emergencyspeedlimit or Config.speedlimit
        if setMaxSpeedSafe(vehicle, hardMax) then
            lastAppliedMax = hardMax
            lastApplyMs = GetGameTimer()
            engaged = true
            manualEngaged = true
        end
    end
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- NUI : 閉じる
RegisterNUICallback('close', function(_, cb)
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

CreateThread(function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then
        resetMaxSpeedSafe(vehicle)
    end
end)
