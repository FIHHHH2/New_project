import os
import glob
from exact_lexer import lex_luau

ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def verify_file_balance(path):
    with open(path, "r", encoding="utf-8") as fp:
        code = fp.read()
    tokens = lex_luau(code)
    
    parens = 0
    brackets = 0
    braces = 0
    
    func_cnt = 0
    do_cnt = 0
    if_cnt = 0
    elseif_cnt = 0
    ternary_if_cnt = 0
    end_cnt = 0
    repeat_cnt = 0
    until_cnt = 0
    
    # In Luau ternary `local x = if a then b else c`:
    # 'if' is preceded by an assignment '=', open bracket '(', '{', '[', comma ',', math/logic op '+', '-', '*', '/', '%', '^', '#', '<', '>', '~', ':', 'and', 'or', 'not', 'return'.
    # Note: 'else' is NOT an expression preceder because `else if` in Lua is a nested if-statement requiring an `end`!
    # Also 'then if' is a nested if-statement requiring an `end`!
    EXPR_PRECEDERS = {
        '=', '(', '{', '[', ',', '+', '-', '*', '/', '%', '^', '#', '<', '>', '~', ':',
        'and', 'or', 'not', 'return'
    }
    
    for idx, (ttype, tval) in enumerate(tokens):
        if tval == '(': parens += 1
        elif tval == ')': parens -= 1
        elif tval == '[': brackets += 1
        elif tval == ']': brackets -= 1
        elif tval == '{': braces += 1
        elif tval == '}': braces -= 1
        
        if ttype == 'IDENT':
            if tval == 'function':
                func_cnt += 1
            elif tval == 'do':
                do_cnt += 1
            elif tval == 'repeat':
                repeat_cnt += 1
            elif tval == 'until':
                until_cnt += 1
            elif tval == 'end':
                end_cnt += 1
            elif tval == 'elseif':
                elseif_cnt += 1
            elif tval == 'if':
                prev_tok = tokens[idx-1] if idx > 0 else None
                if prev_tok and prev_tok[1] in EXPR_PRECEDERS:
                    ternary_if_cnt += 1
                else:
                    if_cnt += 1
                    
    openers_requiring_end = func_cnt + do_cnt + if_cnt
    diff = openers_requiring_end - end_cnt
    repeat_diff = repeat_cnt - until_cnt
    
    is_valid = (parens == 0 and brackets == 0 and braces == 0 and diff == 0 and repeat_diff == 0)
    
    return {
        "valid": is_valid,
        "parens": parens,
        "brackets": brackets,
        "braces": braces,
        "func": func_cnt,
        "do": do_cnt,
        "stmt_if": if_cnt,
        "elseif": elseif_cnt,
        "ternary_if": ternary_if_cnt,
        "openers": openers_requiring_end,
        "ends": end_cnt,
        "diff": diff,
        "repeat_diff": repeat_diff
    }

files = sorted(glob.glob(os.path.join(ROOT, "**/*.luau"), recursive=True))
print(f"=== INDEPENDENT STATIC ANALYSIS MATRIX ({len(files)} LUAU FILES) ===")
all_pass = True
for f in files:
    rel = os.path.relpath(f, ROOT)
    res = verify_file_balance(f)
    status = "PASS" if res["valid"] else "FAIL"
    if not res["valid"]:
        all_pass = False
    print(f"[{status}] {rel:35} | () {res['parens']:+d}, [] {res['brackets']:+d}, {{}} {res['braces']:+d} | Openers: {res['openers']:3d} (func={res['func']:2d}, do={res['do']:2d}, if={res['stmt_if']:2d}, ternary={res['ternary_if']:2d}) == Ends: {res['ends']:3d} (diff: {res['diff']:+d}) | Repeat/Until: {res['repeat_diff']:+d}")

print("=" * 80)
print(f"OVERALL BALANCE INTEGRITY: {'100% PERFECT PASS' if all_pass else 'FAIL'}")
print("=" * 80)
