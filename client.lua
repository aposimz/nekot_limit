
if Config.vehiclespeedlimiter then
    Citizen.CreateThread(function()
        local inVehicle = false                -- 乗車状態のフラグ
        local cachedVehClass = nil             -- 車両クラスキャッシュ用
        local cachedLimit = nil                -- 制限速度キャッシュ用（m/s）
        local cachedDefaultMaxSpeed = nil      -- デフォルト最高速度キャッシュ用（m/s）

        while true do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then -- 運転席でない場合も追加
                if inVehicle then
                    inVehicle = false
                    cachedVehClass = nil       -- キャッシュをリセット
                    cachedLimit = nil
                    cachedDefaultMaxSpeed = nil
                    print("Exited vehicle. Stopping speed monitoring.")
                end
                Citizen.Wait(500)  -- 乗車していない時用待機時間
            else
                if not inVehicle then
                    inVehicle = true
                    -- 乗車時に車両クラスとデフォルト最高速度をキャッシュ
                    cachedVehClass = GetVehicleClass(vehicle)
                    cachedDefaultMaxSpeed = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")

                    -- ヘリ(15)または飛行機(16)は対象外
                    if cachedVehClass == 15 or cachedVehClass == 16 then
                        print("This vehicle is not subject to speed limits.")
                        goto continue
                    end

                    if cachedVehClass == 18 then
                        cachedLimit = Config.emergencyspeedlimit
                    else
                        cachedLimit = Config.speedlimit
                    end

                    print(string.format("Entered vehicle. Applying speed limit of %.0f km/h...", cachedLimit * 3.6))
                end

                -- ヘリ15または飛行機16ならスキップ
                if cachedVehClass == 15 or cachedVehClass == 16 then
                    Citizen.Wait(500)
                    goto continue
                end

                Citizen.Wait(20)  -- 乗車中用

                local speed = GetEntitySpeed(vehicle)  -- 現在の速度（m/s）

                -- もしキャッシュしたデフォルト最高速度がすでに制限以下なら、何もしない
                if cachedDefaultMaxSpeed <= cachedLimit then
                    goto continue
                end

                -- 現在の速度がキャッシュした制限速度を超えている場合、制限を適用
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
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        print("You are not in a vehicle.")
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        print("You are not in the driver's seat.")
        return
    end

    local defaultSpeed = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel") -- m/s
    local vehClass = GetVehicleClass(vehicle)
    local limit = nil

    if vehClass == 15 or vehClass == 16 then
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
    print(string.format("Default Max Speed (fInitialDriveMaxFlatVel): %.2f m/s (%.2f km/h)", defaultSpeed, defaultSpeed * 3.6))
    print(string.format("Applied Max Speed (limit): %.2f m/s (%.2f km/h)", limit, limit * 3.6))
end, false)
