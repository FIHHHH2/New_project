## 2026-08-31T23:34:20Z
Visuals Coder - ESP & Chams Expansion
Scope: Modules/Visuals.luau, Visuals in Core/Main.luau
Requirements:
1. Box ESP Outlines (Secondary black Drawing.new('Square'), Thickness = 3.5, for high contrast)
2. Tracers Origin Selector ('Bottom', 'Center', 'Mouse' with live viewport calculation)
3. Distance Tags (3D stud distance calculation math.floor((pos - myPos).Magnitude) .. 'm' positioned below bounding box using Drawing.new('Text'))
4. Customizable Chams Colors (Visuals.ChamsFillColor, Visuals.ChamsOutlineColor applied to Highlight instance)
5. Graceful fallback when Drawing library is absent
6. 0 missing Roblox services, 0 UTF-8 BOM bytes
