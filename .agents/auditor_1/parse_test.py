import os
import re
import glob

ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def clean_code(content):
    # Remove multi-line comments
    content = re.sub(r'--\[(=*)\[[\s\S]*?\]\1\]', '', content)
    # Remove single-line comments
    content = re.sub(r'--[^\n]*', '', content)
    # Remove multi-line strings
    content = re.sub(r'\[(=*)\[[\s\S]*?\]\1\]', '""', content)
    # Remove single quoted strings
    content = re.sub(r"'(\\.|[^'\\])*'", '""', content)
    # Remove double quoted strings
    content = re.sub(r'"(\\.|[^"\\])*"', '""', content)
    return content

files = sorted(glob.glob(os.path.join(ROOT, "**/*.luau"), recursive=True))
print(f"Total files: {len(files)}")
for f in files:
    rel = os.path.relpath(f, ROOT)
    with open(f, "r", encoding="utf-8") as fp:
        c = fp.read()
    s = clean_code(c)
    p = s.count('(') - s.count(')')
    b = s.count('[') - s.count(']')
    curly = s.count('{') - s.count('}')
    print(f"{rel:35} | () {p:+d} | [] {b:+d} | {{}} {curly:+d}")
