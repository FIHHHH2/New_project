# Dispatch for Worker 1 — Milestone 1: CoreUI Sub-Tabs Architecture

## Objective
Implement `CoreUI:CreateSubTabs(parentTab, subTabNames)` in `Core/CoreUI.luau`.
Also generalize `CoreUI:CreateColumns(tabObj)` and update `CoreUI:SetTheme(themeName)` to support sub-tabs.

## References & Inputs
- `ORIGINAL_REQUEST.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md`
- `PROJECT.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\PROJECT.md`
- Explorer 1 Report: `A:\Potassium\Modular-Roblox-Menu\.agents\explorer_1\handoff.md`
- Target file: `A:\Potassium\Modular-Roblox-Menu\Core\CoreUI.luau`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A forensic auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Requirements
1. Implement `CoreUI:CreateSubTabs(parentTab: any, subTabNames: {string})` per the blueprint in Explorer 1's handoff.
   - Creates compact horizontal mini sub-tab bar `SubTabBar` (LayoutOrder = 1, Height = 26px) with clean `[ Name ]` styling.
   - Creates `SubPagesContainer` (LayoutOrder = 2, AutomaticSize = Y) holding individual `SubTabPage` frames.
   - Smooth spring slide-in animation on switch (`Position = UDim2.new(0, 16, 0, 0)` -> `UDim2.new(0, 0, 0, 0)`, Back Out 0.26s).
   - Cascaded domino ripple across child elements.
   - Active sub-tab button accent styling with gradient and thicker border.
   - Registers sub-tab group in `self.SubTabGroups`.
2. Generalize `CoreUI:CreateColumns(tabObj: any)` so it accepts either a tab table with `.Page`, a sub-tab table with `.Page`, or directly a `GuiObject`.
3. Update `CoreUI:SetTheme(themeName: string)` to iterate over `self.SubTabGroups` and reapply theme colors via `UpdateTheme()`.
4. Initialize `self.SubTabGroups = {}` in `CoreUI.new()`.
5. Ensure zero syntax errors and clean Luau syntax.

## Write Ownership
You own `Core/CoreUI.luau`.

## Handoff
Write your implementation report to `A:\Potassium\Modular-Roblox-Menu\.agents\worker_1\handoff.md`.
