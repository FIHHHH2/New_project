import os
import re

REPO_DIR = r"A:\Potassium\Modular-Roblox-Menu"

def check_all():
    luau_files = []
    for root, dirs, files in os.walk(REPO_DIR):
        if ".git" in root or ".agents" in root:
            continue
        for f in files:
            if f.endswith(".luau"):
                luau_files.append(os.path.join(root, f))
    
    print(f"Total Luau files: {len(luau_files)}")
    
    for fpath in sorted(luau_files):
        rel = os.path.relpath(fpath, REPO_DIR)
        with open(fpath, "rb") as fh:
            raw = fh.read()
        has_bom = raw.startswith(b"\xef\xbb\xbf")
        text = raw.decode("utf-8", errors="replace")
        
        # Check requires
        requires = re.findall(r'require\(["\']([^"\']+)["\']\)', text)
        missing = []
        for req in requires:
            # normalize target
            candidate = os.path.join(REPO_DIR, req if req.endswith(".luau") else req + ".luau")
            if not os.path.exists(candidate):
                missing.append(req)
        
        # Check theme registrations
        theme_regs = len(re.findall(r'UI\.registerThemeElement', text))
        
        print(f"File: {rel:<28} | Lines: {len(text.splitlines()):<5} | BOM: {has_bom} | Requires: {len(requires)} (Missing: {len(missing)}) | ThemeRegs: {theme_regs}")
        if missing:
            print(f"   --> Missing target files: {missing}")

if __name__ == "__main__":
    check_all()
