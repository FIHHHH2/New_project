# Dispatch for Explorer 1

## Mission
Analyze Core/CoreUI.luau for implementing `CoreUI:CreateSubTabs(parentTab, subTabNames)`.
Read ORIGINAL_REQUEST.md at A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md.

## Focus Areas
1. Inspect how `CreateTab` and tab pages are created and managed in `Core/CoreUI.luau`.
2. Inspect layout hierarchy, UIListLayout/UIPadding, scrolling frames, canvas size updates, and theme integration.
3. Identify how mini sub-tabs can be rendered as a compact horizontal sub-tab bar inside a parent tab.
4. Detail the transition mechanism (spring-damper, tweening, canvas visibility/offset) for fluid sub-tab switching without layout jitter.
5. Provide exact proposed API for `CreateSubTabs`, return structure (sub-tab containers, activate callbacks, etc.), and implementation blueprint.

## Handoff
Write your full analysis report to `A:\Potassium\Modular-Roblox-Menu\.agents\explorer_1\handoff.md`.
