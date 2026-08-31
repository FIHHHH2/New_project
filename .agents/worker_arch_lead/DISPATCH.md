## 2026-08-31T23:34:00Z
You are teamwork_preview_worker (Architecture Lead - UI Decluttering & Sub-Tabs).
Your working directory is A:\Potassium\Modular-Roblox-Menu\.agents\worker_arch_lead.
You MUST read A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md and A:\Potassium\Modular-Roblox-Menu\.agents\orchestrator_3\PROJECT.md before starting work.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Write Ownership:
- Core/CoreUI.luau and Core/Main.luau.
- Ensure CoreUI:CreateSubTabs(parentTab, subTabNames) works cleanly across all dense parent tabs.
- Refactor Core/Main.luau to organize all parent tabs into clean horizontal mini sub-tabs:
  1. Main Tab: [ Movement & Flight ], [ Physics & Modifiers ], [ Player Utilities ]
  2. Combat Tab: [ Aim Assistance ], [ Camera Tracking ], [ Hitbox Modifiers ]
  3. Game Tab (Run N Hide): [ Weapons & Firepower ], [ Bounds & Barriers ], [ Mobility & Items ]
  4. Visuals Tab: [ 2D Overlays & ESP ], [ 3D Chams & Skeletons ], [ ESP Customizer ]
  5. Settings Tab: [ Modules & Tabs ], [ Themes & Visuals ], [ Performance & Rendering ], [ System & Audio ]
- Ensure right-click tab hiding (SetTabVisibility) and bidirectional settings synchronization (FeatureManager.setFeatureState) are 100% functional.
- Maintain consistent container padding, responsive element height, and unified squared retro styling with frosted acrylic gradients.
- Declare all Roblox services at the top (TeleportService, GuiService, HttpService, etc.) to satisfy check_services.py.

Run python check_services.py to verify 0 missing services and 0 UTF-8 BOM bytes.
Produce handoff.md in your working directory and notify the orchestrator via send_message.
