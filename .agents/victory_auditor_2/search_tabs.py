with open('Core/Main.luau', 'r', encoding='utf-8') as f:
    text = f.read()

import re
lines = text.splitlines()
for i, l in enumerate(lines):
    if 'Tab' in l or 'Combat' in l or 'Visuals' in l or 'PlayerUtilities' in l:
        if any(keyword in l for keyword in ['CreateTab', 'CreateSubTabs', 'subTabs', 'TabGroup', 'AddTab', 'tab', 'Tab']):
            print(f'{i+1}: {l}')
