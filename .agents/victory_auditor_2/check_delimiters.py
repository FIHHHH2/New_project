import os, sys, re
sys.stdout.reconfigure(encoding='utf-8')

REPO_DIR = r'A:\Potassium\Modular-Roblox-Menu'

def analyze_luau_syntax(file_path):
    rel = os.path.relpath(file_path, REPO_DIR)
    with open(file_path, 'r', encoding='utf-8') as f:
        src = f.read()

    # Strip multi-line comments
    clean = re.sub(r'--\[(=*)\[.*?\]\1\]', '', src, flags=re.DOTALL)
    # Strip single line comments
    clean = re.sub(r'--[^\n]*', '', clean)
    # Strip multiline strings
    clean = re.sub(r'\[(=*)\[.*?\]\1\]', '""', clean, flags=re.DOTALL)
    # Strip strings
    clean = re.sub(r'"(\\.|[^"])*"', '""', clean)
    clean = re.sub(r"'(\\.|[^'])*'", "''", clean)

    tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*|[^\s\w]', clean)
    
    p_balance = 0
    b_balance = 0
    c_balance = 0
    for tok in tokens:
        if tok == '(': p_balance += 1
        elif tok == ')': p_balance -= 1
        elif tok == '[': b_balance += 1
        elif tok == ']': b_balance -= 1
        elif tok == '{': c_balance += 1
        elif tok == '}': c_balance -= 1
        
    return rel, p_balance, b_balance, c_balance

print('=== CHECKING DELIMITER BALANCES ACROSS ALL 17 LUAU FILES ===')
for root, dirs, files in os.walk(REPO_DIR):
    if '.git' in root or '.agents' in root: continue
    for f in sorted(files):
        if f.endswith('.luau'):
            fp = os.path.join(root, f)
            rel, p, b, c = analyze_luau_syntax(fp)
            ok = (p == 0 and b == 0 and c == 0)
            print(f'{"[PASS]" if ok else "[FAIL]"} {rel:<32} (parens={p}, brackets={b}, braces={c})')
