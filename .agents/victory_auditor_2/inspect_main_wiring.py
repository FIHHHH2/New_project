import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('Core/Main.luau', 'r', encoding='utf-8') as f:
    text = f.read()

lines = text.splitlines()

def print_section(title, start_line, end_line):
    print(f'=== {title} (Lines {start_line}-{end_line}) ===')
    for i in range(start_line-1, min(end_line, len(lines))):
        print(f'{i+1}: {lines[i]}')

print_section('COMBAT WIRING', 529, 650)
print_section('PLAYER UTILITIES WIRING', 480, 528)
print_section('VISUALS WIRING', 874, 1014)
