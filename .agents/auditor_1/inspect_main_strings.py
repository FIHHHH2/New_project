with open(r"A:\Potassium\Modular-Roblox-Menu\Core\Main.luau", "r", encoding="utf-8") as fp:
    lines = fp.readlines()

for idx, line in enumerate(lines, 1):
    # Check for escaped quotes or unusual strings
    if '\\"' in line or "\\'" in line or "`" in line or "[[" in line:
        print(f"Line {idx}: {line.strip()}")
