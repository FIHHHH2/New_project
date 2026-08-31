"""
Cross-repository reference and syntax sanity scanner
"""
import os
import re

root_dir = "."
luau_files = []
for dirpath, _, filenames in os.walk(root_dir):
    if ".git" in dirpath or ".agents" in dirpath:
        continue
    for f in filenames:
        if f.endswith(".luau"):
            luau_files.append(os.path.join(dirpath, f))

print(f"Found {len(luau_files)} Luau files.")
animations_usages = {}

for lf in luau_files:
    with open(lf, "r", encoding="utf-8") as f:
        content = f.read()
    matches = re.findall(r"Animations\.\w+", content)
    if matches:
        animations_usages[lf] = matches

print("\nAnimations Usage Summary:")
for path, calls in animations_usages.items():
    print(f"  {path}: {len(calls)} calls -> {sorted(set(calls))}")
