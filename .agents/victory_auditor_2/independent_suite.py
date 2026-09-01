import os, sys, re
sys.stdout.reconfigure(encoding='utf-8')

REPO_DIR = r'A:\Potassium\Modular-Roblox-Menu'
sys.path.insert(0, REPO_DIR)

def run_full_suite():
    results = {}
    
    # 1. Service check
    import check_services
    luau_files = []
    for root, dirs, files in os.walk(REPO_DIR):
        if '.git' in root or '.agents' in root: continue
        for f in files:
            if f.endswith('.luau'):
                luau_files.append(os.path.join(root, f))
                
    missing_total = 0
    bom_total = 0
    for f in luau_files:
        stats = check_services.analyze_file(f)
        missing_total += len(stats['missing_services'])
        if stats['has_bom']:
            bom_total += 1
            
    results['services_missing'] = missing_total
    results['bom_files'] = bom_total
    results['total_files'] = len(luau_files)
    
    # 2. Check git sync
    import subprocess
    git_status = subprocess.check_output(['git', 'status', '-s'], cwd=REPO_DIR).decode('utf-8')
    non_agent_changes = [l for l in git_status.splitlines() if not '.agents/' in l]
    results['dirty_tree'] = len(non_agent_changes) > 0
    
    # 3. Check R1 Subtabs in CoreUI & Main
    with open(os.path.join(REPO_DIR, 'Core', 'CoreUI.luau'), 'r', encoding='utf-8') as f:
        coreui_src = f.read()
    with open(os.path.join(REPO_DIR, 'Core', 'Main.luau'), 'r', encoding='utf-8') as f:
        main_src = f.read()
        
    results['has_CreateSubTabs'] = 'function CoreUI:CreateSubTabs(' in coreui_src
    results['has_SubTab_Combat'] = 'combatSubTabs = window:CreateSubTabs(combatTab' in main_src
    results['has_SubTab_Visuals'] = 'visSubTabs = window:CreateSubTabs(visualsTab' in main_src
    results['has_SubTab_Movement'] = 'mainSubTabs = window:CreateSubTabs(mainTab' in main_src
    results['has_SubTab_GameUtils'] = 'rnhSubTabs = window:CreateSubTabs(gameTab' in main_src and 'ndsSubTabs = window:CreateSubTabs(gameTab' in main_src
    results['has_SubTab_Settings'] = 'setSubTabs = window:CreateSubTabs(settingsTab' in main_src
    results['has_RightClick_Hiding'] = 'tabButton.MouseButton2Click:Connect(handleRightClick)' in coreui_src
    results['has_Settings_Sync'] = 'gameTab.OnVisibilityChanged' in main_src and 'combatTab.OnVisibilityChanged' in main_src and 'visualsTab.OnVisibilityChanged' in main_src
    
    # 4. Check R2 Visuals
    with open(os.path.join(REPO_DIR, 'Modules', 'Visuals.luau'), 'r', encoding='utf-8') as f:
        vis_src = f.read()
    results['box_outlines'] = 'Visuals.BoxOutlines' in vis_src and 'Thickness = 3.5' in vis_src
    results['tracer_origin'] = 'TracerOrigin = "Bottom"' in vis_src and 'tracerOrigin == "Center"' in vis_src and 'tracerOrigin == "Mouse"' in vis_src
    results['distance_tags'] = 'Visuals.Distance' in vis_src and 'pv.DistanceTag' in vis_src and 'dist .. "m"' in vis_src
    results['chams_custom_colors'] = 'ChamsFillColor' in vis_src and 'ChamsOutlineColor' in vis_src
    
    # 5. Check R2 Player Utilities
    with open(os.path.join(REPO_DIR, 'Modules', 'PlayerUtilities.luau'), 'r', encoding='utf-8') as f:
        pu_src = f.read()
    results['server_hop'] = 'PlayerUtilities.ServerHop()' in pu_src and 'TeleportToPlaceInstance' in pu_src
    results['rejoin_server'] = 'PlayerUtilities.RejoinServer()' in pu_src and 'TeleportService:Teleport' in pu_src
    results['copy_ids'] = 'PlayerUtilities.CopyPlaceId()' in pu_src and 'PlayerUtilities.CopyGameId()' in pu_src and 'PlayerUtilities.CopyJobId()' in pu_src
    results['anti_afk'] = 'PlayerUtilities.SetAntiAFK(' in pu_src and 'VirtualUser:CaptureController()' in pu_src
    results['click_teleport'] = 'PlayerUtilities.GiveClickTeleportTool()' in pu_src and 'PlayerUtilities.SetClickTeleportEnabled(' in pu_src
    
    # 6. Check R2 Combat
    with open(os.path.join(REPO_DIR, 'Modules', 'Combat.luau'), 'r', encoding='utf-8') as f:
        com_src = f.read()
    results['fov_color'] = 'Combat.setFovColor(' in com_src and 'FovColor' in com_src
    results['triggerbot_delay'] = 'Combat.setTriggerBotDelay(' in com_src and 'TriggerBotDelay' in com_src
    results['wallbang_thickness'] = 'Combat.setWallbangThickness(' in com_src and 'checkWallbangPenetration' in com_src
    
    # 7. Check R3 Widgets
    with open(os.path.join(REPO_DIR, 'UI', 'Notification.luau'), 'r', encoding='utf-8') as f:
        notif_src = f.read()
    with open(os.path.join(REPO_DIR, 'UI', 'ChatWidget.luau'), 'r', encoding='utf-8') as f:
        chat_src = f.read()
    with open(os.path.join(REPO_DIR, 'UI', 'MusicTracker.luau'), 'r', encoding='utf-8') as f:
        music_src = f.read()
    with open(os.path.join(REPO_DIR, 'UI', 'PlayerList.luau'), 'r', encoding='utf-8') as f:
        plist_src = f.read()
        
    results['notif_polish'] = 'topStroke.Thickness = 1.5' in notif_src and 'cardStroke.Thickness = 2' in notif_src
    results['chat_polish'] = 'popStroke.Thickness = 2' in chat_src and 'quickPopStroke.Thickness = 2' in chat_src
    results['music_polish'] = 'Thickness = 2' in music_src and 'UI.registerThemeElement' in music_src
    results['plist_polish'] = 'Thickness = 2' in plist_src and 'UI.registerThemeElement' in plist_src
    
    return results

res = run_full_suite()
print('='*70)
print('INDEPENDENT VICTORY AUDIT TEST RESULTS MATRIX')
print('='*70)
all_pass = True
for k, v in res.items():
    passed = (v == 0 if 'missing' in k or 'bom' in k or 'dirty' in k else bool(v))
    if not passed: all_pass = False
    print(f'  {k:<30} : {str(v):<10} -> {"[PASS]" if passed else "[FAIL]"}')
print('='*70)
print(f'OVERALL AUDIT VERDICT: {"VICTORY CONFIRMED" if all_pass else "VICTORY REJECTED"}')
print('='*70)
