
if Config.vehiclespeedlimiter then
    Citizen.CreateThread(function()
        local defaultMaxSpeed = {}  -- 車両に設定されているデフォルト最高速度（m/s）
        local inVehicle = false     -- 乗車状態のフラグ
        local cachedVehClass = nil  -- 車両クラスキャッシュ用
        local cachedLimit = nil     -- 制限速度キャッシュ用

        while true do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 then
                if inVehicle then
                    inVehicle = false
                    cachedVehClass = nil  -- キャッシュをリセット
                    cachedLimit = nil
                    print("Exited vehicle. Stopping speed monitoring.")
                end
                Citizen.Wait(500)  -- 乗車していない時用待機時間
            else
                if not inVehicle then
                    inVehicle = true
                    cachedVehClass = GetVehicleClass(vehicle) -- 乗車時に車両クラスと制限速度をキャッシュする
                    -- ヘリ(15)飛行機(16)は対象外
                    if cachedVehClass == 15 or cachedVehClass == 16 then
                        print("This vehicle is not subject to speed limits.")
                        Citizen.Wait(500)
                        goto continue
                    elseif cachedVehClass == 18 then
                        cachedLimit = Config.emergencyspeedlimit
                    else
                        cachedLimit = Config.speedlimit
                    end
                    print(string.format("Entered vehicle. Applying speed limit of %.0f km/h...", cachedLimit * 3.6))
                end

                Citizen.Wait(20)  -- 乗車中は頻繁にチェック

                local speed = GetEntitySpeed(vehicle)  -- 現在の速度（m/s）

                -- 車両のデフォルト最高速度が未取得なら取得する
                if defaultMaxSpeed[vehicle] == nil then
                    defaultMaxSpeed[vehicle] = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
                end

                -- もしデフォルトの最高速度が制限速度以下なら何もしない
                if defaultMaxSpeed[vehicle] <= cachedLimit then
                    goto continue
                end

                -- 現在の走行速度が制限速度を超えている場合、制限を適用する
                if speed >= cachedLimit then
                    SetEntityMaxSpeed(vehicle, cachedLimit)
                end
            end

            ::continue::
        end
    end)
end

-- デバッグ用コマンド: checkSpeedLimits
RegisterCommand("checkSpeedLimits", function(source, args, rawCommand)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        print("You are not in a vehicle.")
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    local defaultSpeed = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel") -- m/s
    local vehClass = GetVehicleClass(vehicle)
    local limit = nil

    if vehClass == 16 or vehClass == 15 then
        print("This vehicle is not subject to speed limits.")
        return
    elseif vehClass == 18 then
        limit = Config.emergencyspeedlimit
    else
        limit = Config.speedlimit
    end

    local vehicleModel = GetEntityModel(vehicle)
    local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
    print(string.format("Vehicle: %s", vehicleName))
    print(string.format("default Max Speed (fInitialDriveMaxFlatVel): %.2f m/s (%.2f km/h)", defaultSpeed, defaultSpeed * 3.6))
    print(string.format("Max Speed (limit): %.2f m/s (%.2f km/h)", limit, limit * 3.6))
end, false)
