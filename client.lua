
if Config.vehiclespeedlimiter then
    Citizen.CreateThread(function()
        local defaultMaxSpeed = {}  -- 車両に設定されているデフォルト最高速度（m/s）
        local inVehicle = false     -- 乗車状態のフラグ

        while true do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 then
                if inVehicle then
                    inVehicle = false
                    print("Exited vehicle. Stopping speed monitoring.")
                end
                Citizen.Wait(500)  -- 乗車していない時用待機時間
            else
                if not inVehicle then
                    inVehicle = true
                    print("Entered vehicle. Applying speed limit...")
                end
                Citizen.Wait(20)  -- 乗車中用

                local speed = GetEntitySpeed(vehicle)  -- 現在の速度（m/s）
                local vehClass = GetVehicleClass(vehicle)
                local limit = nil

                -- ヘリ(15)飛行機(16)は対象外
                if vehClass == 15 or vehClass == 16 then
                    goto continue
                elseif vehClass == 18 then
                    limit = Config.emergencyspeedlimit  -- 緊急車両用制限速度（m/s）
                else
                    limit = Config.speedlimit  -- 通常車両用制限速度（m/s）
                end

                -- 車両のデフォルト最高速度が未取得なら取得する
                if defaultMaxSpeed[vehicle] == nil then
                    defaultMaxSpeed[vehicle] = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
                end

                -- もしデフォルトの最高速度が制限速度以下なら、何もしない
                if defaultMaxSpeed[vehicle] <= limit then
                    goto continue
                end

                -- 現在の走行速度が制限速度を超えている場合、制限速度を適用する
                if speed >= limit then
                    SetEntityMaxSpeed(vehicle, limit)
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
        limit = Config.emergencyclassSpeedlimit
    else
        limit = Config.speedlimit
    end

    local vehicleModel = GetEntityModel(vehicle)
    local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
    print(string.format("Vehicle: %s", vehicleName))
    print(string.format("default Max Speed (fInitialDriveMaxFlatVel): %.2f m/s (%.2f km/h)", defaultSpeed, defaultSpeed * 3.6))
    print(string.format("Max Speed (limit): %.2f m/s (%.2f km/h)", limit, limit * 3.6))
end, false)
