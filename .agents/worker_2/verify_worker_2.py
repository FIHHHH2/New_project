import re

def verify_main_luau():
    path = r"A:\Potassium\Modular-Roblox-Menu\Core\Main.luau"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()
    print(f"Total lines in Main.luau: {len(lines)}")
    
    # 1. Bracket and parenthesis balancing
    paren = 0
    bracket = 0
    brace = 0
    in_block_comment = False

    for i, line in enumerate(lines, 1):
        clean = line.strip()
        if clean.startswith("--[[") or clean.startswith("--[=["):
            in_block_comment = True
        if in_block_comment:
            if "]]" in clean or "]=]" in clean:
                in_block_comment = False
            continue
        if clean.startswith("--"):
            continue
            
        line_no_comment = line.split("--")[0]
        # Remove strings
        no_str = re.sub(r'\"(\\.|[^\"])*\"', '""', line_no_comment)
        no_str = re.sub(r'\'(\\.|[^\'])*\'', "''", no_str)
        
        for ch in no_str:
            if ch == '(': paren += 1
            elif ch == ')': paren -= 1
            elif ch == '[': bracket += 1
            elif ch == ']': bracket -= 1
            elif ch == '{': brace += 1
            elif ch == '}': brace -= 1
            
        if paren < 0 or bracket < 0 or brace < 0:
            print(f"Balancing issue on line {i}: paren={paren}, bracket={bracket}, brace={brace}")
            return False

    print(f"Balancing counts: paren={paren}, bracket={bracket}, brace={brace}")
    if paren != 0 or bracket != 0 or brace != 0:
        print("FAIL: Bracket/paren mismatch")
        return False
    else:
        print("PASS: Bracket and parenthesis balancing clean.")

    # 2. Check Combat features and bindings
    expected_toggles = [
        "silent_aim",
        "wall_bang",
        "target_head",
        "track_teammates",
        "trigger_bot",
        "aim_tracking",
        "aim_always",
        "fov_circle",
        "expand_hitboxes"
    ]
    expected_sliders = [
        "FOV Radius",
        "Hit Chance %",
        "Aim Smoothing",
        "Hitbox Size"
    ]

    for toggle in expected_toggles:
        if f'"{toggle}"' not in content:
            print(f"FAIL: Missing toggle {toggle}")
            return False
        else:
            print(f"PASS: Found toggle '{toggle}'")

    for slider in expected_sliders:
        if f'"{slider}"' not in content:
            print(f"FAIL: Missing slider {slider}")
            return False
        else:
            print(f"PASS: Found slider '{slider}'")

    if 'CreateSubTabs(combatTab, { "Aim Assistance", "Hitbox Modifiers" })' not in content and 'CreateSubTabs(combatTab, {"Aim Assistance", "Hitbox Modifiers"})' not in content and 'combatSubTabs["Aim Assistance"]' not in content:
        print("FAIL: CreateSubTabs call not found in Main.luau")
        return False

    print("PASS: All Combat sub-tab controls and bindings verified.")
    return True

if __name__ == "__main__":
    verify_main_luau()
