import os
import glob

ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def lex_luau(code):
    n = len(code)
    i = 0
    tokens = []
    
    while i < n:
        # Check comments
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
            
        # Check long strings [=[ ... ]=]
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

        # Check quoted strings
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

        # Identifiers and keywords
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

def parse_blocks(tokens):
    """
    Parses Lua/Luau block hierarchy:
    Block openers:
      - 'function' (unless part of type annotation like ': (a: number) -> ()' or similar, but in Luau type annotations 'function' keyword is rare, usually '(...)->...')
      - 'do'
      - statement 'then' (from statement 'if' / 'elseif')
      - 'repeat'
    Block closers:
      - 'end' (closes function, do, statement-then)
      - 'until' (closes repeat)
    
    Distinguishing statement 'if' from expression 'if':
    In Luau, an 'if' expression is preceded by an operator or open punctuation:
      =, (, {, [, ,, +, -, *, /, %, ^, .., <, >, <=, >=, ==, ~=, and, or, not, return
    In all other cases (start of file, after 'end', 'do', 'then', 'else', 'repeat', 'until', ';'), 'if' is a statement!
    When 'if' is an expression, 'then' and 'else' / 'elseif' are part of the ternary expression, requiring NO 'end'.
    When 'if' is a statement, the 'then' opens a block, and an 'end' closes the whole if-statement.
    """
    stack = []
    
    EXPR_PRECEDERS = {
        '=', '+', '-', '*', '/', '%', '^', '#', '<', '>', '~', ':', ',', ';',
        '(', '{', '[',
        'and', 'or', 'not', 'return'
    }
    
    STATEMENT_START_PRECEDERS = {
        'do', 'then', 'else', 'repeat', 'until', 'end', None
    }
    
    if_stack = [] # tracks whether an 'if' was 'statement' or 'expr'
    
    prev_token = None
    
    for idx, (ttype, tval) in enumerate(tokens):
        if ttype == 'WORD':
            if tval == 'if':
                # Determine if statement or expression
                prev_val = prev_token[1] if prev_token else None
                if prev_val in EXPR_PRECEDERS:
                    if_stack.append('expr')
                else:
                    if_stack.append('statement')
                    
            elif tval == 'then':
                current_if_type = if_stack.pop() if if_stack else 'statement'
                if current_if_type == 'statement':
                    stack.append(('then', idx))
                else:
                    # expression if-then, no block on stack
                    pass
                    
            elif tval == 'function':
                # Check if this is a type definition or real function
                # In Luau type syntax `type F = function()` vs real `function f()` or `function()`
                stack.append(('function', idx))
                
            elif tval == 'do':
                # Check if it is a while/for loop or standalone do block
                stack.append(('do', idx))
                
            elif tval == 'repeat':
                stack.append(('repeat', idx))
                
            elif tval == 'until':
                if not stack or stack[-1][0] != 'repeat':
                    return False, f"Unexpected 'until' at token {idx} (stack: {stack[-3:] if stack else 'empty'})"
                stack.pop()
                
            elif tval == 'end':
                if not stack:
                    return False, f"Unexpected 'end' at token {idx} (empty stack)"
                top = stack.pop()
                # 'end' closes 'function', 'do', or 'then'
                if top[0] not in ('function', 'do', 'then'):
                    return False, f"Mismatched 'end' closing '{top[0]}' at token {idx}"
                    
        prev_token = (ttype, tval)
        
    if stack:
        return False, f"Unclosed blocks on stack: {[s[0] for s in stack]}"
    return True, "All blocks balanced"

files = sorted(glob.glob(os.path.join(ROOT, "**/*.luau"), recursive=True))
print("=== COMPLETE LUAU BLOCK BALANCE AUDIT ===")
all_pass = True
for f in files:
    rel = os.path.relpath(f, ROOT)
    with open(f, 'r', encoding='utf-8') as fp:
        c = fp.read()
    toks = lex_luau(c)
    ok, msg = parse_blocks(toks)
    print(f"[{'PASS' if ok else 'FAIL'}] {rel:35} | {msg}")
    if not ok:
        all_pass = False

print(f"\nFinal Block Balance Status: {'ALL 15 FILES PASS' if all_pass else 'FAIL'}")
