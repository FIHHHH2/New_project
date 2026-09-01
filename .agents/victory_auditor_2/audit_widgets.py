import sys, re
sys.stdout.reconfigure(encoding='utf-8')

widgets = {
    'PlayerList': 'UI/PlayerList.luau',
    'ChatWidget': 'UI/ChatWidget.luau',
    'MusicTracker': 'UI/MusicTracker.luau',
    'Notification': 'UI/Notification.luau',
    'UI': 'UI/UI.luau'
}

print('=== WIDGET POLISH & ARCHITECTURE AUDIT ===')

for name, path in widgets.items():
    with open(path, 'r', encoding='utf-8') as f:
        code = f.read()
    
    strokes_2px = len(re.findall(r'Thickness\s*=\s*2(?:\.0)?\b', code))
    theme_reg = len(re.findall(r'UI\.registerThemeElement', code))
    anim_refs = len(re.findall(r'Animations\.\w+|TweenService:Create', code))
    insets = len(re.findall(r'UDim2\.new\(1,\s*-(?:12|14|16|8)', code))
    
    print(f'Widget: {name} ({path})')
    print(f'  - UIStroke 2px references: {strokes_2px}')
    print(f'  - UI.registerThemeElement calls: {theme_reg}')
    print(f'  - Animation / Tween calls: {anim_refs}')
    print(f'  - Topbar / Container Inset geometry matches: {insets}')
    print(f'  - Lines: {len(code.splitlines())}, File Size: {len(code.encode("utf-8"))} bytes')
    print()

