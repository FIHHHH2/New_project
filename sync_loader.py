import os
import re

LOADER_PATH = "Loader.luau"

def sync():
    with open(LOADER_PATH, "r", encoding="utf-8") as f:
        loader_text = f.read()

    # Find all module definitions
    pattern = re.compile(r'(Modules\["([^"]+)"\] = function\(\)\n)(.*?)(^end\n)', re.DOTALL | re.MULTILINE)

    targets = [
        "UI/UI.luau",
        "Core/CoreUI.luau",
        "Core/MainUI.luau",
        "UI/Hotbar.luau",
        "UI/HealthWidget.luau",
        "UI/PlayerList.luau",
        "UI/ChatWidget.luau",
        "UI/LeaderstatsWidget.luau",
        "UI/MusicTracker.luau",
        "Modules/DisasterSurvival.luau",
    ]

    def replacer(match):
        prefix = match.group(1)
        mod_name = match.group(2)
        suffix = match.group(4)
        
        if mod_name in targets and os.path.exists(mod_name):
            print(f"Updating {mod_name} in Loader.luau...")
            with open(mod_name, "r", encoding="utf-8") as mf:
                mod_body = mf.read()
            
            # Indent module body by 4 spaces and include require = requireModule
            indented_lines = ["    local require = requireModule\n"]
            for line in mod_body.splitlines(keepends=True):
                indented_lines.append("    " + line if line.strip() else line)
            
            new_inner = "".join(indented_lines)
            if not new_inner.endswith("\n"):
                new_inner += "\n"
            return prefix + new_inner + suffix
        return match.group(0)

    new_loader_text = pattern.sub(replacer, loader_text)
    
    # Update bootstrap part (Core/Main.luau)
    bootstrap_marker = "-- MAIN APPLICATION BOOTSTRAP\n"
    if bootstrap_marker in new_loader_text and os.path.exists("Core/Main.luau"):
        print("Updating Core/Main.luau bootstrap in Loader.luau...")
        with open("Core/Main.luau", "r", encoding="utf-8") as mf:
            main_body = mf.read()
        
        prefix, _ = new_loader_text.split(bootstrap_marker, 1)
        new_loader_text = prefix + bootstrap_marker + "local require = requireModule\n\n" + main_body
    
    with open(LOADER_PATH, "w", encoding="utf-8") as f:
        f.write(new_loader_text)
    
    print("Sync complete.")

if __name__ == "__main__":
    sync()
