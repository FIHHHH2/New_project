import os
import glob

ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def lex_luau(code):
    n = len(code)
    i = 0
    tokens = []
    
    while i < n:
        # Comments
        if i + 1 < n and code[i:i+2] == '--':
            i += 2
            if i < n and code[i] == '[':
                eq_count = 0
                j = i + 1
                while j < n and code[j] == '=':
                    eq_count += 1
                    j += 1
                if j < n and code[j] == '[':
                    close_tag = ']' + ('=' * eq_count) + ']'
                    close_pos = code.find(close_tag, j + 1)
                    if close_pos != -1:
                        i = close_pos + len(close_tag)
                        continue
                    else:
                        i = n
                        continue
            end_nl = code.find('\n', i)
            if end_nl != -1:
                i = end_nl + 1
            else:
                i = n
            continue
            
        # Long strings
        if code[i] == '[':
            eq_count = 0
            j = i + 1
            while j < n and code[j] == '=':
                eq_count += 1
                j += 1
            if j < n and code[j] == '[':
                close_tag = ']' + ('=' * eq_count) + ']'
                close_pos = code.find(close_tag, j + 1)
                if close_pos != -1:
                    tokens.append(('STRING', code[i:close_pos+len(close_tag)]))
                    i = close_pos + len(close_tag)
                    continue
                else:
                    tokens.append(('STRING', code[i:]))
                    i = n
                    continue

        # Quoted strings
        if code[i] in ("'", '"', '`'):
            quote = code[i]
            j = i + 1
            while j < n:
                if code[j] == '\\':
                    j += 2
                    continue
                if code[j] == quote:
                    j += 1
                    break
                j += 1
            tokens.append(('STRING', code[i:j]))
            i = j
            continue

        # Words
        if code[i].isalpha() or code[i] == '_':
            j = i + 1
            while j < n and (code[j].isalnum() or code[j] == '_'):
                j += 1
            tokens.append(('WORD', code[i:j]))
            i = j
            continue

        ch = code[i]
        if ch in '()[]{}':
            tokens.append(('PUNCT', ch))
        elif ch in '=+-*/%^#<>~:,.;':
            tokens.append(('OP', ch))
        i += 1
        
    return tokens

def parse_lua_blocks(tokens):
    """
    Proper Lua block stack:
    - 'if' (statement) pushes 'if'. An 'end' pops 'if'. 'elseif' and 'else' stay within current 'if'.
    - 'if' (expression, e.g. `x = if a then b else c`) does NOT push 'if'.
    - 'do' (from `do`, `while ... do`, `for ... do`) pushes 'do'. An 'end' pops 'do'.
    - 'function' pushes 'function' (unless in type annotations). An 'end' pops 'function'.
    - 'repeat' pushes 'repeat'. An 'until' pops 'repeat'.
    """
    stack = []
    
    # In Luau, determining if `if` is statement vs expression:
    # If the token right before `if` is a statement delimiter or block start/end:
    # (None, 'end', 'do', 'then', 'else', 'repeat', 'until', ';')
    # THEN `if` is a STATEMENT.
    # Otherwise (e.g. after '=', '(', '{', '[', ',', '+', '-', '*', '/', 'and', 'or', 'not', 'return', etc.)
    # it is an EXPRESSION.
    
    STATEMENT_PREV = {None, 'end', 'do', 'then', 'else', 'repeat', 'until', ';'}
    
    prev_tok = None
    
    for idx, (ttype, tval) in enumerate(tokens):
        if ttype == 'WORD':
            if tval == 'if':
                prev_val = prev_tok[1] if prev_tok else None
                if prev_val in STATEMENT_PREV:
                    stack.append(('if', idx))
                else:
                    # if-expression (ternary)
                    pass
            elif tval == 'elseif':
                # stays in current 'if', no stack push/pop
                pass
            elif tval == 'else':
                # stays in current 'if', no stack push/pop
                pass
            elif tval == 'then':
                # no stack push/pop
                pass
            elif tval == 'do':
                # 'do' starts a block (standalone 'do', 'while ... do', 'for ... do')
                stack.append(('do', idx))
            elif tval == 'function':
                # In Luau, check if preceded by 'type' (e.g. `type Handler = function`)
                prev_val = prev_tok[1] if prev_tok else None
                if prev_val != 'type':
                    stack.append(('function', idx))
            elif tval == 'repeat':
                stack.append(('repeat', idx))
            elif tval == 'until':
                if not stack or stack[-1][0] != 'repeat':
                    return False, f"Unexpected 'until' at token {idx} '{tval}', top of stack: {stack[-1] if stack else 'empty'}"
                stack.pop()
            elif tval == 'end':
                if not stack:
                    return False, f"Unexpected 'end' at token {idx} '{tval}' (stack is empty)"
                top = stack.pop()
                if top[0] not in ('if', 'do', 'function'):
                    return False, f"Mismatched 'end' at token {idx}, expected to close '{top[0]}'"
                    
        prev_tok = (ttype, tval)
        
    if stack:
        return False, f"Unclosed blocks: {[s[0] for s in stack]}"
    return True, "All blocks perfectly balanced"

files = sorted(glob.glob(os.path.join(ROOT, "**/*.luau"), recursive=True))
print("=== PRECISE LUAU PARSER BLOCK BALANCE ===")
all_pass = True
for f in files:
    rel = os.path.relpath(f, ROOT)
    with open(f, 'r', encoding='utf-8') as fp:
        c = fp.read()
    toks = lex_luau(c)
    ok, msg = parse_lua_blocks(toks)
    print(f"[{'PASS' if ok else 'FAIL'}] {rel:35} | {msg}")
    if not ok:
        all_pass = False

print(f"\nExact Block Result: {'ALL PASS' if all_pass else 'FAIL'}")
