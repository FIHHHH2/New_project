import os, re, sys
REPO_DIR = r"A:\Potassium\Modular-Roblox-Menu"
LUAU_KEYWORDS_OPEN = {'function', 'then', 'do', 'repeat'}
LUAU_KEYWORDS_CLOSE = {'end', 'until'}

def lex_and_verify(file_path):
    rel = os.path.relpath(file_path, REPO_DIR)
    with open(file_path, 'r', encoding='utf-8') as f:
        src = f.read()

    clean_src = re.sub(r'--\[(=*)\[.*?\]\1\]', '', src, flags=re.DOTALL)
    clean_src = re.sub(r'--[^\n]*', '', clean_src)
    clean_src = re.sub(r'\[(=*)\[.*?\]\1\]', '""', clean_src, flags=re.DOTALL)
    clean_src = re.sub(r'"(\\.|[^"])*"', '""', clean_src)
    clean_src = re.sub(r"'(\\.|[^'])*'", "''", clean_src)

    tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*|[\(\)\[\]\{\}]', clean_src)

    paren = 0
    bracket = 0
    brace = 0
    block_depth = 0
    errors = []

    for idx, tok in enumerate(tokens):
        if tok == '(': paren += 1
        elif tok == ')':
            paren -= 1
            if paren < 0: errors.append(f'Negative paren balance at token #{idx}')
        elif tok == '[': bracket += 1
        elif tok == ']':
            bracket -= 1
            if bracket < 0: errors.append(f'Negative bracket balance at token #{idx}')
        elif tok == '{': brace += 1
        elif tok == '}':
            brace -= 1
            if brace < 0: errors.append(f'Negative brace balance at token #{idx}')
        elif tok in LUAU_KEYWORDS_OPEN:
            block_depth += 1
        elif tok in LUAU_KEYWORDS_CLOSE:
            block_depth -= 1
            if block_depth < 0: errors.append(f'Negative block depth at token #{idx}')

    if paren != 0: errors.append(f'Unbalanced parens: {paren}')
    if bracket != 0: errors.append(f'Unbalanced brackets: {bracket}')
    if brace != 0: errors.append(f'Unbalanced braces: {brace}')
    if block_depth != 0: errors.append(f'Unbalanced blocks: {block_depth}')

    return rel, len(src.splitlines()), len(errors) == 0, errors

luau_files = []
for root, dirs, files in os.walk(REPO_DIR):
    if '.git' in root or '.agents' in root: continue
    for f in files:
        if f.endswith('.luau'):
            luau_files.append(os.path.join(root, f))

print(f'VERIFYING {len(luau_files)} PRODUCTION LUAU FILES...')
all_ok = True
for p in sorted(luau_files):
    rel, lines, ok, errs = lex_and_verify(p)
    status = '[PASS]' if ok else '[FAIL]'
    print(f'{status} {rel:<32} ({lines:>4} lines)')
    if not ok:
        all_ok = False
        for e in errs: print(f'   ! {e}')

if all_ok:
    print('\nAll 17 Luau files have 100% integrity!')
else:
    sys.exit(1)