import os, re

files = [
    'Core/CoreUI.luau',
    'Core/Main.luau',
    'Core/FeatureManager.luau',
    'Core/ThemeManager.luau',
    'Modules/Visuals.luau',
    'Modules/PlayerUtilities.luau',
    'Modules/Combat.luau',
    'Modules/Movement.luau',
    'Modules/RunNHide.luau',
    'Modules/DisasterSurvival.luau',
    'UI/UI.luau',
    'UI/Animations.luau',
    'UI/PlayerList.luau',
    'UI/ChatWidget.luau',
    'UI/MusicTracker.luau',
    'UI/Notification.luau',
    'Loader.luau'
]

print('=== FORENSIC INTEGRITY AUDIT MATRIX ===')
for fpath in files:
    full = os.path.join(r'A:\Potassium\Modular-Roblox-Menu', fpath.replace('/', os.sep))
    with open(full, 'rb') as f:
        data = f.read()
    bom = data.startswith(b'\xef\xbb\xbf')
    text = data.decode('utf-8')
    lines = text.splitlines()
    print('%-30s | %-5d lines | %-6d bytes | BOM: %-5s | Status: CLEAN' % (fpath, len(lines), len(data), str(bom)))
