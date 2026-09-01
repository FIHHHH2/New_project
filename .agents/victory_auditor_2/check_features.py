import re

with open('Modules/Visuals.luau', 'r', encoding='utf-8') as f:
    vis_code = f.read()

with open('Modules/PlayerUtilities.luau', 'r', encoding='utf-8') as f:
    pu_code = f.read()

with open('Modules/Combat.luau', 'r', encoding='utf-8') as f:
    com_code = f.read()

with open('Core/Main.luau', 'r', encoding='utf-8') as f:
    main_code = f.read()

print('=== VISUALS CHECKS ===')
print('BoxOutline in Visuals.luau:', 'BoxOutline' in vis_code)
print('TracerOrigin in Visuals.luau:', 'TracerOrigin' in vis_code or 'TracersOrigin' in vis_code)
print('DistanceTag in Visuals.luau:', 'DistanceTag' in vis_code or 'Distance' in vis_code)
print('ChamsFillColor / ChamsOutlineColor in Visuals.luau:', 'ChamsFillColor' in vis_code or 'ChamsOutlineColor' in vis_code)

print('\n=== PLAYER UTILITIES CHECKS ===')
print('ServerHop in PlayerUtilities.luau:', 'serverHop' in pu_code or 'ServerHop' in pu_code)
print('Rejoin in PlayerUtilities.luau:', 'rejoin' in pu_code or 'Rejoin' in pu_code)
print('CopyGameInfo in PlayerUtilities.luau:', 'copyGameInfo' in pu_code or 'copyPlaceId' in pu_code or 'copyJobId' in pu_code)
print('AntiAFK in PlayerUtilities.luau:', 'antiAFK' in pu_code or 'startAntiAFK' in pu_code or 'AntiAFK' in pu_code)
print('ClickTeleport in PlayerUtilities.luau:', 'clickTeleport' in pu_code or 'ClickTeleport' in pu_code or 'enableClickTeleport' in pu_code)

print('\n=== COMBAT REFINEMENTS CHECKS ===')
print('FOVCircle Color customizer:', 'FOVColor' in com_code or 'FovColor' in com_code or 'CircleColor' in com_code)
print('TriggerBot Delay:', 'TriggerBotDelay' in com_code or 'triggerBotDelay' in com_code or 'TriggerDelay' in com_code)
print('Wallbang Thickness:', 'WallbangThickness' in com_code or 'wallbangThickness' in com_code or 'WallbangTolerance' in com_code or 'MaxWallThickness' in com_code)

print('\n=== EXPOSURE IN MAIN.LUAU ===')
for feat in ['BoxOutline', 'TracerOrigin', 'DistanceTag', 'ChamsFillColor', 'ChamsOutlineColor',
             'serverHop', 'rejoin', 'copyGameId', 'copyJobId', 'antiAFK', 'clickTeleport',
             'TriggerBotDelay', 'WallbangThickness', 'FovColor', 'FOVColor']:
    found = feat.lower() in main_code.lower()
    print(f'  {feat} exposed in Main.luau: {found}')
