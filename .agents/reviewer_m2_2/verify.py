import os
import glob

base = r'A:\Potassium\Modular-Roblox-Menu'
luau_files = glob.glob(os.path.join(base, '**', '*.luau'), recursive=True)

print(f'Total Luau files found: {len(luau_files)}')
for path in sorted(luau_files):
    rel = os.path.relpath(path, base)
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    first_line = lines[0].strip() if lines else ''
    is_strict = (first_line == '--!strict')
    print(f'{rel:35} | Lines: {len(lines):4} | --!strict: {is_strict}')
