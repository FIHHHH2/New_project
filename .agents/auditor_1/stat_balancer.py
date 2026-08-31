import os
import glob
import re

ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def check_luau_syntax(file_path):
    with open(file_path, "r", encoding="utf-8") as fp:
        lines = fp.readlines()

    # We will track block depth and parentheses/bracket/brace depth
    # Also verify that every opened block (function, do, while-do, for-do, if-then, repeat-until) is closed properly.
    
    # Let's clean the entire code while preserving newlines
    full_text = "".join(lines)
    
    # 1. Replace multi-line comments --[=[ ... ]=] with newlines
    def repl_comment(m):
        return "\n" * m.group(0).count("\n")
    cleaned = re.sub(r'--\[(=*)\[[\s\S]*?\]\1\]', repl_comment, full_text)
    
    # 2. Replace single line comments
    cleaned = re.sub(r'--[^\n]*', '', cleaned)
    
    # 3. Replace multi-line strings [=[ ... ]=]
    cleaned = re.sub(r'\[(=*)\[[\s\S]*?\]\1\]', '""', cleaned)
    
    # 4. Replace strings
    cleaned = re.sub(r"'(\\.|[^'\\])*'", '""', cleaned)
    cleaned = re.sub(r'"(\\.|[^"\\])*"', '""', cleaned)
    cleaned = re.sub(r'`(\\.|[^`\\])*`', '""', cleaned)
    
    # Check delimiters
    p_diff = cleaned.count("(") - cleaned.count(")")
    b_diff = cleaned.count("[") - cleaned.count("]")
    c_diff = cleaned.count("{") - cleaned.count("}")
    
    # Count Luau ternary `if ... then ... else` expressions:
    # Luau ternary expression pattern: `(?:=|\(|\{|\[|,|\+|-|\*|/|%|\^|#|<|>|~|:|\band\b|\bor\b|\bnot\b|\breturn\b)\s*if\b`
    ternary_matches = len(re.findall(r'(?:[=({[,\+\-\*/%^#<>~:]|\band\b|\bor\b|\bnot\b|\breturn\b)\s*if\b', cleaned))
    
    # Count keywords
    words = re.findall(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', cleaned)
    
    counts = {}
    for w in words:
        counts[w] = counts.get(w, 0) + 1
        
    num_func = counts.get('function', 0)
    num_do = counts.get('do', 0)
    num_then = counts.get('then', 0) # all then (both statement and ternary)
    num_repeat = counts.get('repeat', 0)
    num_until = counts.get('until', 0)
    num_end = counts.get('end', 0)
    
    # In statement if: each statement 'if' has a matching 'end'.
    # Note: 'elseif' has a 'then', but does NOT add an 'end'.
    # In statement if: 1 statement 'if' = 1 'end'.
    # The number of statement 'if's is counts['if'] - ternary_matches.
    # Total block openers = num_func + num_do + (counts.get('if', 0) - ternary_matches)
    # Total block closers = num_end
    
    stmt_if = counts.get('if', 0) - ternary_matches
    expected_ends = num_func + num_do + stmt_if
    end_diff = expected_ends - num_end
    repeat_diff = num_repeat - num_until
    
    return {
        "p": p_diff,
        "b": b_diff,
        "c": c_diff,
        "func": num_func,
        "do": num_do,
        "stmt_if": stmt_if,
        "ternary_if": ternary_matches,
        "end": num_end,
        "end_diff": end_diff,
        "repeat_diff": repeat_diff
    }

files = sorted(glob.glob(os.path.join(ROOT, "**/*.luau"), recursive=True))
print("=== STATISTICAL & STATIC BLOCK BALANCER ===")
for f in files:
    rel = os.path.relpath(f, ROOT)
    res = check_luau_syntax(f)
    print(f"{rel:35} | () {res['p']:+d}, [] {res['b']:+d}, {{}} {res['c']:+d} | func={res['func']}, do={res['do']}, stmt_if={res['stmt_if']}, ternary={res['ternary_if']}, end={res['end']} (diff {res['end_diff']:+d}) | repeat={res['repeat_diff']}")
