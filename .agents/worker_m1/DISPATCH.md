## 2026-08-31T17:22:21Z

You are Worker 1 for Milestone 1 of the Modular Roblox Menu project.
Your working directory is: A:\Potassium\Modular-Roblox-Menu\.agents\worker_m1
Authoritative request: A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md
Project plan: A:\Potassium\Modular-Roblox-Menu\PROJECT.md
Survey findings: A:\Potassium\Modular-Roblox-Menu\.agents\explorer_survey_1\handoff.md and A:\Potassium\Modular-Roblox-Menu\.agents\explorer_survey_2\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Assigned Files:
You exclusively own and will modify:
1. UI/Animations.luau
2. Core/CoreUI.luau

Tasks:
1. Update UI/Animations.luau to implement the full suite of spring-damper / TweenService micro-interaction and window/popup helpers:
   - Animations.popScale(guiObject: GuiObject, startScale: number?, peakScale: number?, endScale: number?, duration: number?): Tween
   - Animations.attachMicroSquash(button: GuiButton, stroke: UIStroke?, getNormalBg: (() -> Color3)?, getHoverBg: (() -> Color3)?, getActiveBg: (() -> Color3)?, getNormalBorder: (() -> Color3)?, getGlowBorder: (() -> Color3)?)
   - Animations.attachSliderGlow(track: Frame, stroke: UIStroke, fill: Frame, valLabel: TextLabel?)
   - Animations.pulseIndicator(stroke: UIStroke, pulseColor: Color3, normalColor: Color3, peakThickness: number?, normalThickness: number?)
   - Animations.openWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?) (Spring scale 0.95 -> 1.0 Back.Out)
   - Animations.closeWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?) (Spring scale 1.0 -> 0.95 Quad.In)
   - Animations.popIn(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?) (Spring scale 0.90 -> 1.0 Back.Out)
   - Animations.popOut(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?) (Spring scale 1.0 -> 0.90 Quad.In)
   - Animations.dominoRipple(elements: {GuiObject}, baseDelay: number?, offsetDistance: number?, duration: number?)
2. Update Core/CoreUI.luau to integrate these animations cleanly across all UI controls:
   - Toggles: Checkmark pop scale (0.0 -> 1.25 -> 1.0 Back.Out on enable, 1.0 -> 0.0 Quad.In on disable) with fluid background accent fill and border glow on hover across all 3 segments.
   - Sliders: Smooth lerping fill track (0.06s Quad Out), responsive track border glow on hover (UIStroke.Color -> Accent, Thickness -> 1.6), and valLabel micro-bounce (UIScale 1.15 -> 1.0) on value updates.
   - Buttons: Micro-squash and border glow on hover/click with instant response (UIScale 0.96 down, 1.0 Back.Out up).
   - Tabs & Sub-Tabs: Active tab/sub-tab indicator pulse on selection (Animations.pulseIndicator surging UIStroke thickness 1.5 -> 2.2 -> 1.5 with accent glow), fluid spring transitions with cascaded domino ripples.
   - Window Controller methods: Expose :Toggle(), :Open(), :Close(), and :SetVisible(state) on CoreUI instances to interface with the window controller and prevent runtime nil calls.
3. Verification requirements:
   - Run python check_services.py and ensure 0 missing services and 0 BOM bytes.
   - Ensure --!strict typing compliance and no syntax errors.
