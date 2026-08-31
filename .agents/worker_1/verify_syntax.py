import re

def check_luau_syntax(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()
    stack = []
    
    # Strip comments and string literals for block checking
    # Regex to tokenize lua blocks
    print(f"Checking {file_path}...")
    
    open_keywords = ["function", "then", "do", "repeat"]
    close_keywords = ["end", "until"]
    
    # Check parenthetical balance
    paren_count = 0
    bracket_count = 0
    brace_count = 0
    
    in_block_comment = False
    
    for i, line in enumerate(lines, 1):
        clean = line.strip()
        if clean.startswith("--[["):
            in_block_comment = True
        if in_block_comment:
            if "]]" in clean:
                in_block_comment = False
            continue
        if clean.startswith("--"):
            continue
            
        # strip line comment
        line_no_comment = line.split("--")[0]
        
        # count brackets
        # basic check ignoring strings
        # remove strings
        no_str = re.sub(r'\"(\\.|[^\"])*\"', '""', line_no_comment)
        no_str = re.sub(r'\'(\\.|[^\'])*\'', "''", no_str)
        
        for ch in no_str:
            if ch == '(': paren_count += 1
            elif ch == ')': paren_count -= 1
            elif ch == '[': bracket_count += 1
            elif ch == ']': bracket_count -= 1
            elif ch == '{': brace_count += 1
            elif ch == '}': brace_count -= 1
            
        if paren_count < 0:
            print(f"Error: unmatched ')' on line {i}")
        if bracket_count < 0:
            print(f"Error: unmatched ']' on line {i}")
        if brace_count < 0:
            print(f"Error: unmatched '}}' on line {i}")

    print(f"Final Counts: Paren={paren_count}, Bracket={bracket_count}, Brace={brace_count}")
    if paren_count == 0 and bracket_count == 0 and brace_count == 0:
        print("PASS: Bracket balancing verified.")
    else:
        print("FAIL: Bracket imbalance detected.")

if __name__ == "__main__":
    check_luau_syntax(r"A:\Potassium\Modular-Roblox-Menu\Core\CoreUI.luau")
