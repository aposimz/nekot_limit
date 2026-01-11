Config = {}

Config.vehiclespeedlimiter = true -- 速度制限するか

-- m/s 指定（例: 200km/h = 200 / 3.6 = 55.56）
-- ※必ず小数点付きで指定してください（例: 84.00）。もしくは「km/h / 3.6」の式でも可
Config.speedlimit = 221 / 3.6 -- 一般車両の上限
Config.emergencyspeedlimit = 271 / 3.6 -- 緊急車両(18)用の上限

Config.vehicleweapons = false -- false で車両武器（ドライブバイ等）を無効化
Config.debug = false -- デバッグログの出力を有効化

-- 犯罪利用禁止 判定の設定
-- 1) 車両モデル指定：モデル名（スポーン名）
Config.prohibitModelNames = { "annihilator", "tug", "raidengrb" }

-- 2) ナンバープレートの部分一致ワード。例: { "GANG", "TEST" }
--    大文字/小文字は無視（部分一致）
Config.prohibitPlateWords = { "WCAT", "XXX" }

-- ヘリ(15)・飛行機(16)は対象外
--[[ 車両クラス一覧
0: Compacts
1: Sedans
2: SUVs
3: Coupes
4: Muscle
5: Sports Classics
6: Sports
7: Super
8: Motorcycles
9: Off-road
10: Industrial
11: Utility
12: Vans
13: Cycles
14: Boats
15: Helicopters (速度制限対象外)
16: Planes (速度制限対象外)
17: Service
18: Emergency
19: Military
20: Commercial
21: Trains
]]
