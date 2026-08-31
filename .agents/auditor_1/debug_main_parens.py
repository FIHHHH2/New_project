import re

with open(r"A:\Potassium\Modular-Roblox-Menu\Core\Main.luau", "r", encoding="utf-8") as fp:
    lines = fp.readlines()

def clean_line(line):
    # Remove strings
    line = re.sub(r"'(\\.|[^'\\])*'", '""', line)
    line = re.sub(r'"(\\.|[^"\\])*"', '""', line)
    # Remove single line comments
    line = line.split("--")[0]
    return line

stack = []
depth = 0
for idx, line in enumerate(lines, 1):
    cleaned = clean_line(line)
    for ch in cleaned:
        if ch == '(':
            depth += 1
            stack.append((idx, line.strip()))
        elif ch == ')':
            depth -= 1
            if stack:
                stack.pop()
            else:
                print(f"Extra ')' at line {idx}: {line.strip()}")

print(f"Final paren depth in Main.luau: {depth}")
