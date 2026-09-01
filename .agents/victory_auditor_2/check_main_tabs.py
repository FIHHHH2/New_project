import os
import re

with open('Core/Main.luau', 'r', encoding='utf-8') as f:
    text = f.read()

tabs = re.findall(r'(\w+)\s*=\s*CoreUI:CreateTab\(\s*["\']([^"\']+)["\']', text)
print('=== MAIN TABS ===')
for var, name in tabs:
    print(f'  {var} -> "{name}"')

print('\n=== SUB TABS ===')
subtabs = re.findall(r'(\w+)\s*=\s*CoreUI:CreateSubTabs\(\s*(\w+),\s*\{([^}]+)\}\)', text)
for var, parent, sublist in subtabs:
    clean_sublist = [s.strip().strip('"\'') for s in sublist.split(',') if s.strip()]
    print(f'  {var} on {parent} -> {clean_sublist}')

print('\n=== RIGHT CLICK TAB HIDING & SETTINGS SYNC ===')
has_right_click = 'MouseButton2Click' in text or 'MouseButton2Down' in text or 'RightClick' in text or 'HideTab' in text or 'HiddenTabs' in text
print(f'  Right click / Tab hiding references found: {has_right_click}')

hide_refs = re.findall(r'.*(?:HideTab|hiddenTab|HiddenTabs|MouseButton2Click|RestoreTab).*', text, re.IGNORECASE)
for h in hide_refs[:10]:
    print('   ', h.strip())

