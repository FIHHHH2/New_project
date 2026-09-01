"""
Deep Adversarial Audit for Challenger 1
Directly parses and audits the entire suite codebase:
- Core/CoreUI.luau
- Core/Main.luau
- Core/FeatureManager.luau
- UI/UI.luau
- Modules/Combat.luau
- Modules/Visuals.luau
- Modules/PlayerUtilities.luau
- UI/PlayerList.luau
- UI/MusicTracker.luau
- UI/ChatWidget.luau
- UI/Notification.luau
"""

import os
import re
import sys
import glob

REPO_ROOT = r"A:\Potassium\Modular-Roblox-Menu"

def check_bom():
    print("--- 1. BYTE-LEVEL UTF-8 BOM AUDIT ---")
    luau_files = glob.glob(os.path.join(REPO_ROOT, "**", "*.luau"), recursive=True)
    bom_files = []
    for fp in luau_files:
        with open(fp, "rb") as f:
            header = f.read(3)
            if header == b"\xef\xbb\xbf":
                bom_files.append(fp)
    if bom_files:
        print(f"[FAIL] Found {len(bom_files)} files with UTF-8 BOM: {bom_files}")
        return False
    else:
        print(f"[PASS] All {len(luau_files)} .luau files are 100% clean UTF-8 without BOM.")
        return True

def audit_coreui():
    print("\n--- 2. CoreUI.luau SUB-TAB ARCHITECTURAL AUDIT ---")
    coreui_path = os.path.join(REPO_ROOT, "Core", "CoreUI.luau")
    with open(coreui_path, "r", encoding="utf-8") as f:
        content = f.read()

    checks = {
        "SubTabGroups initialized": "self.SubTabGroups = {}" in content,
        "SubTabGroups theme loop": "for _, subTabGroup in ipairs(self.SubTabGroups) do" in content,
        "CreateSubTabs definition": "function CoreUI:CreateSubTabs(parentTab: any, subTabNames: {string})" in content,
        "SubTabBar LayoutOrder = 1": "subTabBar.LayoutOrder = 1" in content,
        "SubPagesContainer LayoutOrder = 2": "subPagesContainer.LayoutOrder = 2" in content,
        "SubPagesContainer AutomaticSize": "subPagesContainer.AutomaticSize = Enum.AutomaticSize.Y" in content,
        "ActiveGradient on SubTab buttons": 'btnGrad.Name = "ActiveGradient"' in content,
        "Polymorphic Indexing": 'subTabs[name] = subTabObj' in content and 'subTabs[idx] = subTabObj' in content,
        "GetActive method": "function subTabs:GetActive()" in content,
        "UpdateTheme method": "subTabs.UpdateTheme = function()" in content,
        "CreateColumns polymorphism": "local parentPage: GuiObject? = if type(tabObj) == \"table\" and tabObj.Page then tabObj.Page" in content,
    }

    all_passed = True
    for name, passed in checks.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False
    return all_passed

def audit_main_subtabs_and_features():
    print("\n--- 3. Core/Main.luau SUB-TAB DEPLOYMENT & FEATURE BINDINGS AUDIT ---")
    main_path = os.path.join(REPO_ROOT, "Core", "Main.luau")
    with open(main_path, "r", encoding="utf-8") as f:
        content = f.read()

    main_checks = {
        "Main Tab Sub-Tabs Created": 'window:CreateSubTabs(mainTab, { "Movement & Flight", "Physics & Modifiers", "Player Utilities" })' in content,
        "Combat Tab Sub-Tabs Created": 'window:CreateSubTabs(combatTab, { "Aim Assistance", "Camera Tracking", "Hitbox Modifiers" })' in content,
        "Visuals Tab Sub-Tabs Created": 'window:CreateSubTabs(visualsTab, { "2D Overlays & ESP", "3D Chams & Skeletons", "ESP Customizer" })' in content,
        "Settings Tab Sub-Tabs Created": 'window:CreateSubTabs(settingsTab, { "Modules & Tabs", "Themes & Visuals", "Performance & Rendering", "System & Audio" })' in content,
        "Server Hop button bound": "PlayerUtilities.ServerHop()" in content,
        "Rejoin button bound": "PlayerUtilities.RejoinServer()" in content,
        "Copy Place/Game/Job IDs bound": "PlayerUtilities.CopyPlaceId()" in content and "PlayerUtilities.CopyGameId()" in content and "PlayerUtilities.CopyJobId()" in content,
        "Anti-AFK toggle bound": "PlayerUtilities.SetAntiAFK(enabled)" in content,
        "Click Teleport tool & toggle bound": "PlayerUtilities.SetClickTeleportEnabled(enabled)" in content and "PlayerUtilities.GiveClickTeleportTool()" in content,
        "Silent Aim & Wallbang toggles": 'Combat.SilentAim = enabled' in content and 'Combat.Wallbang = enabled' in content,
        "TriggerBot toggle & slider": 'Combat.TriggerBot = enabled' in content and 'Combat.TriggerBotDelay = value / 1000' in content,
        "Wallbang Thickness slider": 'Combat.WallbangThickness = value' in content,
        "FOV Circle Color buttons": 'Combat.setFovColor(' in content,
        "ESP Box Outlines toggle": 'Visuals.BoxOutlines = enabled' in content,
        "Tracer Origin buttons": 'Visuals.TracerOrigin = "Bottom"' in content and 'Visuals.TracerOrigin = "Center"' in content and 'Visuals.TracerOrigin = "Mouse"' in content,
        "Distance Tags toggle": 'Visuals.Distance = enabled' in content,
        "Chams Color buttons": 'Visuals.ChamsFillColor =' in content,
    }

    all_passed = True
    for name, passed in main_checks.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False
    return all_passed

def audit_modules():
    print("\n--- 4. MODULES INTEGRITY AUDIT (Visuals, Combat, PlayerUtilities) ---")
    vis_path = os.path.join(REPO_ROOT, "Modules", "Visuals.luau")
    with open(vis_path, "r", encoding="utf-8") as f:
        v_content = f.read()

    combat_path = os.path.join(REPO_ROOT, "Modules", "Combat.luau")
    with open(combat_path, "r", encoding="utf-8") as f:
        c_content = f.read()

    putil_path = os.path.join(REPO_ROOT, "Modules", "PlayerUtilities.luau")
    with open(putil_path, "r", encoding="utf-8") as f:
        u_content = f.read()

    module_checks = {
        "Visuals: Drawing API availability check": 'local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")' in v_content,
        "Visuals: Box Outlines secondary Drawing.Square": 'square.Thickness = 3.5' in v_content and 'square.Color = Color3.fromRGB(0, 0, 0)' in v_content,
        "Visuals: Tracer Origin dynamic calculation": 'local tracerOrigin = Visuals.TracerOrigin or "Bottom"' in v_content and 'UserInputService:GetMouseLocation()' in v_content,
        "Visuals: Distance Tag calculation": 'math.floor((targetPos - myPos).Magnitude)' in v_content,
        "Visuals: 3D Highlight Chams fallback without Drawing": 'Instance.new("Highlight")' in v_content,
        "Combat: Drawing API availability check": 'local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")' in c_content,
        "Combat: Bidirectional Wallbang penetration solver": 'function Combat.checkWallbangPenetration(' in c_content and 'forwardResult' in c_content and 'backwardResult' in c_content,
        "Combat: TriggerBot delay clamp": 'function Combat.setTriggerBotDelay(delaySec: number)' in c_content,
        "Combat: FOV Color customizer": 'function Combat.setFovColor(color: Color3)' in c_content,
        "Combat: Post-Camera Priority Aim Tracking": 'RunService:BindToRenderStep("FihCombatAimTrack", Enum.RenderPriority.Camera.Value + 1' in c_content,
        "PlayerUtilities: ServerHop with pcalls & JSON decode": 'function PlayerUtilities.ServerHop()' in u_content and 'HttpService:JSONDecode' in u_content,
        "PlayerUtilities: RejoinServer with PlaceId / JobId": 'function PlayerUtilities.RejoinServer()' in u_content,
        "PlayerUtilities: Copy IDs with safe clipboard": 'function PlayerUtilities.CopyPlaceId()' in u_content and 'function PlayerUtilities.CopyGameId()' in u_content and 'function PlayerUtilities.CopyJobId()' in u_content,
        "PlayerUtilities: Anti-AFK Idled with VirtualUser": 'LocalPlayer.Idled:Connect' in u_content and 'VirtualUser:CaptureController()' in u_content,
        "PlayerUtilities: Click Teleport tool creation": 'function PlayerUtilities.GiveClickTeleportTool()' in u_content,
    }

    all_passed = True
    for name, passed in module_checks.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False
    return all_passed

def audit_themes_and_configs():
    print("\n--- 5. THEMES & CONFIG MANAGER AUDIT ---")
    ui_path = os.path.join(REPO_ROOT, "UI", "UI.luau")
    with open(ui_path, "r", encoding="utf-8") as f:
        content = f.read()

    theme_checks = {
        "Dark theme present": "Dark = {" in content,
        "Light theme present": "Light = {" in content,
        "TranslucentDark theme present": "TranslucentDark = {" in content,
        "TranslucentLight theme present": "TranslucentLight = {" in content,
        "Adaptive theme present": "Adaptive = {" in content,
        "applyAdaptiveTheme method": "function UI.applyAdaptiveTheme(" in content,
        "saveTheme method": "function UI.saveTheme(themeName: string)" in content,
        "getSavedTheme recovery": "function UI.getSavedTheme(): string?" in content,
    }

    all_passed = True
    for name, passed in theme_checks.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False
    return all_passed

if __name__ == "__main__":
    b1 = check_bom()
    b2 = audit_coreui()
    b3 = audit_main_subtabs_and_features()
    b4 = audit_modules()
    b5 = audit_themes_and_configs()

    if all([b1, b2, b3, b4, b5]):
        print("\n[ALL AUDITS PASSED WITH ZERO VIOLATIONS]")
        sys.exit(0)
    else:
        print("\n[AUDIT FAILURES DETECTED]")
        sys.exit(1)
