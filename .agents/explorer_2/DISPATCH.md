# Dispatch for Explorer 2

## Mission
Analyze Core/Main.luau for refactoring the Combat tab into mini sub-tabs `[ Aim Assistance ]` and `[ Hitbox Modifiers ]`.
Read ORIGINAL_REQUEST.md at A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md.

## Focus Areas
1. Inspect how Combat tab is constructed in `Core/Main.luau`.
2. Enumerate every element, toggle, slider, dropdown, and section currently in Combat tab:
   - Aim Assistance: Silent Aim, Wallbang, Target Part, Aim Tracking (Camera Lock), Always Lock, Track Teammates, Trigger Bot, FOV Circle, FOV Radius, Hit Chance, Aim Smoothing.
   - Hitbox Modifiers: Expand Hitboxes, Hitbox Size, range modifications.
3. Map how to divide these controls cleanly into the two sub-views (`[ Aim Assistance ]` and `[ Hitbox Modifiers ]`).
4. Ensure all config bindings, event connections, and state updates remain intact without broken references.
5. Provide exact refactoring plan and code blueprint for `Core/Main.luau`.

## Handoff
Write your full analysis report to `A:\Potassium\Modular-Roblox-Menu\.agents\explorer_2\handoff.md`.
