import os, sys, re
sys.stdout.reconfigure(encoding='utf-8')

# Let's write a tokenizer and scope parser for Luau that understands:
# - function ... end
# - if ... then ... elseif ... else ... end (statement)
# - if ... then ... else ... (expression - Luau ternary)
# - do ... end
# - for ... do ... end
# - while ... do ... end
# - repeat ... until ...

KEYWORDS = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
    'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while'
}

def tokenize(code):
    tokens = []
    # Strip comments and multiline comments
    code = re.sub(r'--\[\[.*?\]\]', '', code, flags=re.DOTALL)
    code = re.sub(r'--\[=\[.*?\]=\]', '', code, flags=re.DOTALL)
    
    lines = code.splitlines()
    for line_no, line in enumerate(lines, 1):
        # strip line comment
        line = re.sub(r'--.*$', '', line)
        # tokenize strings, identifiers, symbols
        pos = 0
        while pos < len(line):
            if line[pos].isspace():
                pos += 1
                continue
            
            # String literals
            if line[pos] in ('\"', '\''):
                quote = line[pos]
                pos += 1
                start = pos
                while pos < len(line):
                    if line[pos] == '\\':
                        pos += 2
                        continue
                    if line[pos] == quote:
                        pos += 1
                        break
                    pos += 1
                tokens.append(('STRING', line[start:pos-1], line_no))
                continue
            
            # Identifiers / keywords
            if line[pos].isalpha() or line[pos] == '_':
                start = pos
                while pos < len(line) and (line[pos].isalnum() or line[pos] == '_'):
                    pos += 1
                word = line[start:pos]
                if word in KEYWORDS:
                    tokens.append(('KEYWORD', word, line_no))
                else:
                    tokens.append(('IDENT', word, line_no))
                continue
            
            # Number literals
            if line[pos].isdigit():
                start = pos
                while pos < len(line) and (line[pos].isalnum() or line[pos] in '._xX'):
                    pos += 1
                tokens.append(('NUMBER', line[start:pos], line_no))
                continue
            
            # Symbols
            tokens.append(('SYMBOL', line[pos], line_no))
            pos += 1
            
    return tokens

def parse_luau_scopes(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        code = f.read()
        
    tokens = tokenize(code)
    stack = []
    i = 0
    while i < len(tokens):
        tok_type, tok_val, line_no = tokens[i]
        
        if tok_type == 'KEYWORD':
            if tok_val == 'function':
                stack.append(('function', line_no))
            elif tok_val == 'do':
                # check if preceded by while/for
                stack.append(('do', line_no))
            elif tok_val == 'repeat':
                stack.append(('repeat', line_no))
            elif tok_val == 'if':
                # Check if this is an if-expression (ternary) or if-statement
                # In Luau: if preceded by '=', 'return', '(', '{', ',', '+', '-', '*', '/', 'then', 'else', 'local x =' -> expression
                # Let's check token before 'if'
                prev_tok = tokens[i-1] if i > 0 else None
                is_expr = False
                if prev_tok:
                    p_type, p_val, _ = prev_tok
                    if p_val in ('=', '==', '~=', '<', '>', '<=', '>=', '(', '{', ',', 'then', 'else', 'return', '+', '-', '*', '/', '..', 'and', 'or', 'not'):
                        is_expr = True
                if not is_expr:
                    stack.append(('if_stmt', line_no))
            elif tok_val == 'until':
                if stack and stack[-1][0] == 'repeat':
                    stack.pop()
                else:
                    return False, f'Unmatched "until" at line {line_no} (stack: {stack[-3:]})'
            elif tok_val == 'end':
                if not stack:
                    return False, f'Extra "end" at line {line_no}'
                top_scope, top_line = stack.pop()
                # 'end' closes function, do, if_stmt
                if top_scope not in ('function', 'do', 'if_stmt'):
                    return False, f'Mismatched "end" at line {line_no} for scope {top_scope} from line {top_line}'
        i += 1
        
    if stack:
        return False, f'Unclosed scopes: {stack}'
    return True, 'OK'

print('=== VALIDATING LUAU LEXICAL SCOPING ON ALL 17 FILES ===')
for root, dirs, files in os.walk('.'):
    if '.git' in root or '.agents' in root:
        continue
    for f in sorted(files):
        if f.endswith('.luau'):
            fp = os.path.join(root, f)
            ok, msg = parse_luau_scopes(fp)
            print(f'{fp:<35} : {"VALID" if ok else "ERROR: " + msg}')
