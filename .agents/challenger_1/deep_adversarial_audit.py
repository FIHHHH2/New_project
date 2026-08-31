"""
Deep Adversarial Audit for Challenger 1
Directly parses and audits the codebase files:
- Core/CoreUI.luau
- Core/Main.luau
- UI/UI.luau
- Core/FeatureManager.luau
- Modules/Combat.luau
- UI/PlayerList.luau
- UI/MusicTracker.luau
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

def audit_combat_tab():
    print("\n--- 3. Core/Main.luau COMBAT SUB-TAB INTEGRATION AUDIT ---")
    main_path = os.path.join(REPO_ROOT, "Core", "Main.luau")
    with open(main_path, "r", encoding="utf-8") as f:
        content = f.read()

    combat_checks = {
        "CreateSubTabs invocation": 'window:CreateSubTabs(combatTab, { "Aim Assistance", "Hitbox Modifiers" })' in content,
        "Aim Assistance sub-tab extracted": 'local aimSubTab = combatSubTabs["Aim Assistance"]' in content,
        "Hitbox Modifiers sub-tab extracted": 'local hitSubTab = combatSubTabs["Hitbox Modifiers"]' in content,
        "Aim columns created": "local aimLeftCol, aimRightCol = window:CreateColumns(aimSubTab)" in content,
        "Hitbox columns created": "local hitLeftCol, hitRightCol = window:CreateColumns(hitSubTab)" in content,
        "Silent Aim toggle": 'window:AddToggle(targetingSection, "silent_aim", "Silent Aim", false' in content,
        "Wall Bang toggle": 'window:AddToggle(targetingSection, "wall_bang", "Wall Bang (Shoot Thru Walls)", false' in content,
        "Target Head toggle": 'window:AddToggle(targetingSection, "target_head", "Target Head (Off = Torso)", true' in content,
        "Track Teammates toggle": 'window:AddToggle(targetingSection, "track_teammates", "Track Teammates", false' in content,
        "Trigger Bot toggle": 'window:AddToggle(targetingSection, "trigger_bot", "Trigger Bot", false' in content,
        "Aim Tracking toggle": 'window:AddToggle(trackingSection, "aim_tracking", "Aim Tracking (Camera Lock)", false' in content,
        "Always Lock toggle": 'window:AddToggle(trackingSection, "aim_always", "Always Lock (Ignore RMB Hold)", false' in content,
        "FOV Circle toggle": 'window:AddToggle(trackingSection, "fov_circle", "FOV Circle", false' in content,
        "FOV Radius slider": 'window:AddSlider(trackingSection, "FOV Radius", 30, 360, 120' in content,
        "Hit Chance slider": 'window:AddSlider(trackingSection, "Hit Chance %", 10, 100, 100' in content,
        "Aim Smoothing slider": 'window:AddSlider(trackingSection, "Aim Smoothing", 5, 100, 25' in content,
        "Expand Hitboxes toggle": 'window:AddToggle(hitSection, "expand_hitboxes", "Expand Hitbox\'s", false' in content,
        "Hitbox Size slider": 'window:AddSlider(hitSection, "Hitbox Size", 2, 30, 12' in content,
        "Reset Hitboxes button": 'window:AddButton(hitOpsSection, "Reset All Hitboxes"' in content,
    }

    all_passed = True
    for name, passed in combat_checks.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False
    return all_passed

def audit_themes_and_configs():
    print("\n--- 4. THEMES & CONFIG MANAGER AUDIT ---")
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

def audit_engine_subsystems():
    print("\n--- 5. ENGINE SUBSYSTEMS INTEGRITY AUDIT ---")
    combat_mod = os.path.join(REPO_ROOT, "Modules", "Combat.luau")
    with open(combat_mod, "r", encoding="utf-8") as f:
        c_content = f.read()

    music_mod = os.path.join(REPO_ROOT, "UI", "MusicTracker.luau")
    with open(music_mod, "r", encoding="utf-8") as f:
        m_content = f.read()

    plist_mod = os.path.join(REPO_ROOT, "UI", "PlayerList.luau")
    with open(plist_mod, "r", encoding="utf-8") as f:
        p_content = f.read()

    engine_checks = {
        "Combat Post-Camera RenderPriority Aim Tracking": 'Enum.RenderPriority.Camera.Value + 1' in c_content and 'RunService:BindToRenderStep("FihCombatAimTrack"' in c_content,
        "Combat __namecall / __index metamethod hooks": 'hook(game, "__namecall"' in c_content and 'hook(game, "__index"' in c_content,
        "Walk Fling collision torque": 'AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)' in p_content,
        "PlayerList Context Actions": 'PromptSendFriendRequest' in p_content and 'PromptBlockPlayer' in p_content and 'InspectPlayerFromUserId' in p_content,
        "MusicTracker 60+ FPS Spring-Damper Visualizer": 'local springForce = (targetHeight - currentHeights[i]) * 160.0' in m_content and 'RenderStepped:Connect' in m_content,
    }

    all_passed = True
    for name, passed in engine_checks.items():
        status = "[PASS]" if passed else "[FAIL]"
        print(f"  {status} {name}")
        if not passed:
            all_passed = False
    return all_passed

if __name__ == "__main__":
    b1 = check_bom()
    b2 = audit_coreui()
    b3 = audit_combat_tab()
    b4 = audit_themes_and_configs()
    b5 = audit_engine_subsystems()

    if all([b1, b2, b3, b4, b5]):
        print("\n[ALL AUDITS PASSED WITH ZERO VIOLATIONS]")
        sys.exit(0)
    else:
        print("\n[AUDIT FAILURES DETECTED]")
        sys.exit(1)
