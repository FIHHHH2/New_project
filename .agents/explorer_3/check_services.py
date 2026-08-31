import os
import re
import sys

REPO_DIR = r"A:\Potassium\Modular-Roblox-Menu"

KNOWN_SERVICES = {
    "Players": "Players",
    "RunService": "RunService",
    "UserInputService": "UserInputService",
    "TweenService": "TweenService",
    "HttpService": "HttpService",
    "GuiService": "GuiService",
    "StarterGui": "StarterGui",
    "CoreGui": "CoreGui",
    "MarketplaceService": "MarketplaceService",
    "Lighting": "Lighting",
    "Workspace": "Workspace",
    "TeleportService": "TeleportService",
    "SoundService": "SoundService",
    "ContextActionService": "ContextActionService",
    "PathfindingService": "PathfindingService",
    "Debris": "Debris",
    "ReplicatedStorage": "ReplicatedStorage",
    "Teams": "Teams",
    "TextService": "TextService",
    "TextChatService": "TextChatService",
    "VoiceChatService": "VoiceChatService"
}

def analyze_file(file_path):
    rel_path = os.path.relpath(file_path, REPO_DIR)
    with open(file_path, "rb") as f:
        raw_bytes = f.read()

    has_bom = raw_bytes.startswith(b"\xef\xbb\xbf")
    text = raw_bytes.decode("utf-8", errors="replace")

    declared = re.findall(r"(?:local\s+)?(\w+)\s*=\s*(?:pcall\(function\(\)\s*return\s*)?game:GetService\([\"\'](\w+)[\"\']\)", text)
    declared_map = {var_name: svc_name for var_name, svc_name in declared}

    lines = text.split("\n")
    missing_services = []

    for line_idx, line in enumerate(lines, 1):
        clean_line = line.strip()
        if clean_line.startswith("--") or clean_line.startswith("*"):
            continue
        
        # Check service usages
        for svc_name in KNOWN_SERVICES:
            if f'game:GetService("{svc_name}")' in line or f"game:GetService('{svc_name}')" in line:
                continue
            if f'"{svc_name}"' in line or f"'{svc_name}'" in line:
                continue
            
            # Check for svc_name used as an identifier
            if re.search(rf"\b{svc_name}\b", line):
                is_declared = False
                for var_name, bound_svc in declared_map.items():
                    if bound_svc == svc_name or var_name == svc_name:
                        is_declared = True
                        break
                if not is_declared:
                    missing_services.append((svc_name, line_idx, clean_line))

    # Basic block syntax check
    open_keywords = len(re.findall(r"\b(then|do|function)\b", text))
    # Count ends (ignoring comments)
    ends = 0
    for line in lines:
        stripped = line.split("--")[0].strip()
        ends += len(re.findall(r"\bend\b", stripped))

    return {
        "path": rel_path,
        "size": len(raw_bytes),
        "lines": len(lines),
        "has_bom": has_bom,
        "declared_services": list(declared_map.keys()),
        "missing_services": missing_services,
        "syntax_balance": (open_keywords, ends)
    }

def main():
    luau_files = []
    for root, dirs, files in os.walk(REPO_DIR):
        if ".git" in root or ".agents" in root:
            continue
        for f in files:
            if f.endswith(".luau"):
                luau_files.append(os.path.join(root, f))

    print("=" * 80)
    print(f"REPOSITORY STATIC INTEGRITY MATRIX ({len(luau_files)} LUAU FILES)")
    print("=" * 80)
    
    total_missing = 0
    total_bom = 0

    for file_path in sorted(luau_files):
        info = analyze_file(file_path)
        if info["has_bom"]:
            total_bom += 1
        total_missing += len(info["missing_services"])

        print(f"File: {info['path']:<30} | Lines: {info['lines']:<4} | Size: {info['size']:<6} bytes")
        print(f"  BOM: {'[FAIL] BOM PRESENT' if info['has_bom'] else '[PASS] UTF-8 (No BOM)'}")
        print(f"  Services Declared: {info['declared_services']}")
        if info['missing_services']:
            print(f"  [!] Missing Services ({len(info['missing_services'])}):")
            for svc, lnum, line in info['missing_services']:
                print(f"      - Line {lnum}: '{svc}' used without declaration -> {line[:80]}")
        else:
            print("  Services Check: [PASS] 0 missing services")
        print("-" * 80)

    print("=" * 80)
    print(f"TOTAL MISSING SERVICES: {total_missing}")
    print(f"TOTAL UTF-8 BOM FILES:  {total_bom}")
    print("=" * 80)

if __name__ == "__main__":
    main()
