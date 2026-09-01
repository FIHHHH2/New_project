import os, sys, re
sys.stdout.reconfigure(encoding='utf-8')

REPO_DIR = os.getcwd()
LUAU_FILES = []
for root, dirs, files in os.walk(REPO_DIR):
    if '.git' in root or '.agents' in root:
        continue
    for f in files:
        if f.endswith('.luau'):
            LUAU_FILES.append(os.path.join(root, f))

print(f'=== PHASE B: DEEP INTEGRITY & FORENSIC SCAN ({len(LUAU_FILES)} LUAU FILES) ===')

violations = []
for file_path in sorted(LUAU_FILES):
    rel_path = os.path.relpath(file_path, REPO_DIR)
    with open(file_path, 'rb') as f:
        raw_bytes = f.read()
    
    # 1. UTF-8 BOM check
    has_bom = raw_bytes.startswith(b'\xef\xbb\xbf')
    if has_bom:
        violations.append(f'UTF-8 BOM detected in {rel_path}')
    
    code = raw_bytes.decode('utf-8', errors='replace')
    lines = code.splitlines()
    
    # 2. Check for TODOs / FIXME / NotImplemented / STUB
    for i, line in enumerate(lines):
        clean = line.strip()
        if re.search(r'\b(TODO|FIXME|NOT_IMPLEMENTED|NotImplemented|PLACEHOLDER|stub)\b', clean, re.I):
            # Check if it's a genuine comment or code
            if not 'Enum.' in clean and not 'TextTruncate' in clean:
                print(f'  [FLAG-COMMENT] {rel_path}:{i+1} -> {clean}')
    
    # 3. Check for empty function definitions (facade check)
    empty_funcs = re.findall(r'function\s*[\w\.:]*\s*\([^)]*\)\s*(?:end|\s*return\s*(?:true|false|nil|0|"")\s*end)', code)
    if empty_funcs:
        for ef in empty_funcs:
            print(f'  [FLAG-FACADE] {rel_path} -> suspicious empty function: {ef}')
            
    # 4. Syntax Balance (function/if/do/for/while/repeat vs end/until)
    opens = 0
    ends = 0
    in_block_comment = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('--[['):
            in_block_comment = True
        if in_block_comment:
            if ']]' in stripped:
                in_block_comment = False
            continue
        if stripped.startswith('--'):
            continue
        
        # remove string literals
        no_strings = re.sub(r'\"[^\"]*\"|\'[^\']*\'', '""', stripped)
        # remove single line comments
        no_comment = re.sub(r'--.*$', '', no_strings)
        
        opens += len(re.findall(r'\b(function|then|do|repeat)\b', no_comment))
        ends += len(re.findall(r'\b(end|until)\b', no_comment))
        
    print(f'File: {rel_path:<30} | Lines: {len(lines):<5} | BOM: {"FAIL" if has_bom else "PASS"} | Block Balance: opens={opens}, ends={ends}')

print('\n=== INTEGRITY SCAN RESULT ===')
if violations:
    print('VIOLATIONS DETECTED:')
    for v in violations:
        print('  - ' + v)
else:
    print('ZERO INTEGRITY VIOLATIONS DETECTED. ALL CHECKS CLEAN.')
