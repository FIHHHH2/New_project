with open('Core/CoreUI.luau', 'r', encoding='utf-8') as f:
    text = f.read()

lines = text.splitlines()
for i, l in enumerate(lines):
    if any(k in l for k in ['CreateTab', 'SetTabVisibility', 'MouseButton2', 'InputBegan', 'HideTab', 'right']):
        print(f'{i+1}: {l}')
