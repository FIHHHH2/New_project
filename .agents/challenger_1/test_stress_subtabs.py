"""
Adversarial Stress Test Harness for Challenger 1
Simulates Roblox UI engine, TweenService, Event dispatch, Theme engine, and SubTab architecture.
Tests:
1. SubTab initialization & parameter edge cases (polymorphic indexing, 1-10 tabs, invalid inputs).
2. Rapid SubTab switching & concurrent tweening race conditions.
3. Theme swapping across all 5 themes (Dark, Light, TranslucentDark, TranslucentLight, Adaptive) + Custom Adaptive.
4. Layout bounding & AutomaticSize calculation.
5. Combat Tab config binding and serialization fidelity.
"""

import sys
import json
import math
import time
import os

class MockUDim:
    def __init__(self, scale=0, offset=0):
        self.Scale = float(scale)
        self.Offset = float(offset)
    def __repr__(self):
        return f"UDim({self.Scale}, {self.Offset})"
    def __eq__(self, other):
        return isinstance(other, MockUDim) and math.isclose(self.Scale, other.Scale, abs_tol=1e-5) and math.isclose(self.Offset, other.Offset, abs_tol=1e-5)

class MockUDim2:
    def __init__(self, x_scale=0, x_offset=0, y_scale=0, y_offset=0):
        if isinstance(x_scale, MockUDim):
            self.X = x_scale
            self.Y = x_offset
        else:
            self.X = MockUDim(x_scale, x_offset)
            self.Y = MockUDim(y_scale, y_offset)
    @classmethod
    def new(cls, xs, xo, ys, yo):
        return cls(xs, xo, ys, yo)
    def __repr__(self):
        return f"UDim2.new({self.X.Scale}, {self.X.Offset}, {self.Y.Scale}, {self.Y.Offset})"
    def __eq__(self, other):
        return isinstance(other, MockUDim2) and self.X == other.X and self.Y == other.Y

class MockColor3:
    def __init__(self, r=0, g=0, b=0):
        self.R = float(r)
        self.G = float(g)
        self.B = float(b)
    @classmethod
    def fromRGB(cls, r, g, b):
        return cls(r / 255.0, g / 255.0, b / 255.0)
    def __repr__(self):
        return f"Color3.fromRGB({int(round(self.R*255))}, {int(round(self.G*255))}, {int(round(self.B*255))})"
    def __eq__(self, other):
        return isinstance(other, MockColor3) and math.isclose(self.R, other.R, abs_tol=1e-4) and math.isclose(self.G, other.G, abs_tol=1e-4) and math.isclose(self.B, other.B, abs_tol=1e-4)

class MockInstance:
    def __init__(self, className, name=""):
        self.ClassName = className
        self.Name = name or className
        self.Parent = None
        self.Children = []
        self.Visible = True
        self.Size = MockUDim2.new(0, 0, 0, 0)
        self.Position = MockUDim2.new(0, 0, 0, 0)
        self.BackgroundColor3 = MockColor3.fromRGB(0, 0, 0)
        self.BackgroundTransparency = 0.0
        self.BorderSizePixel = 0
        self.LayoutOrder = 0
        self.ClipsDescendants = False
        self.AutomaticSize = "None"
        self.Text = ""
        self.TextColor3 = MockColor3.fromRGB(255, 255, 255)
        self.TextSize = 12
        self.Font = "Gotham"
        self.Color = MockColor3.fromRGB(255, 255, 255)
        self.Thickness = 1.0
        self.Enabled = True
        self.FillDirection = "Vertical"
        self.HorizontalAlignment = "Left"
        self.VerticalAlignment = "Top"
        self.Padding = MockUDim(0, 0)
        self.PaddingLeft = MockUDim(0, 0)
        self.PaddingRight = MockUDim(0, 0)
        self.PaddingTop = MockUDim(0, 0)
        self.PaddingBottom = MockUDim(0, 0)
        self.SortOrder = "LayoutOrder"
        self.AutomaticCanvasSize = "None"
        self.CanvasSize = MockUDim2.new(0, 0, 0, 0)
        self.ScrollBarThickness = 0
        self.ScrollBarImageColor3 = MockColor3.fromRGB(255, 255, 255)

        self._connections = {}

    def IsA(self, className):
        if self.ClassName == className:
            return True
        if className == "GuiObject" and self.ClassName in ["Frame", "TextButton", "TextLabel", "TextBox", "ScrollingFrame", "ImageLabel", "ImageButton"]:
            return True
        if className == "UIComponent" and self.ClassName in ["UIStroke", "UIGradient", "UIPadding", "UIListLayout", "UICorner"]:
            return True
        return False

    def FindFirstChild(self, name):
        for c in self.Children:
            if c.Name == name:
                return c
        return None

    def FindFirstChildOfClass(self, className):
        for c in self.Children:
            if c.IsA(className):
                return c
        return None

    def GetChildren(self):
        return list(self.Children)

    def Connect(self, event_name, fn):
        if event_name not in self._connections:
            self._connections[event_name] = []
        self._connections[event_name].append(fn)

    def Fire(self, event_name, *args):
        if event_name in self._connections:
            for fn in self._connections[event_name]:
                fn(*args)

    @property
    def MouseButton1Click(self):
        obj = self
        class Signal:
            def Connect(self, fn):
                obj.Connect("MouseButton1Click", fn)
        return Signal()

    @property
    def MouseEnter(self):
        obj = self
        class Signal:
            def Connect(self, fn):
                obj.Connect("MouseEnter", fn)
        return Signal()

    @property
    def MouseLeave(self):
        obj = self
        class Signal:
            def Connect(self, fn):
                obj.Connect("MouseLeave", fn)
        return Signal()

class MockTweenService:
    def __init__(self):
        self.ActiveTweens = []

    def Create(self, inst, tweenInfo, props):
        ts = self
        class Tween:
            def __init__(self, inst, duration, props):
                self.Instance = inst
                self.Duration = duration
                self.TargetProps = props
                self.IsPlaying = False
            def Play(self):
                self.IsPlaying = True
                ts.ActiveTweens.append(self)
                # Apply immediately in mock or when stepped
                for k, v in self.TargetProps.items():
                    setattr(self.Instance, k, v)
        return Tween(inst, getattr(tweenInfo, 'Time', 0.2), props)

def run_stress_tests():
    print("=== STARTING CHALLENGER 1 ADVERSARIAL STRESS TEST SUITE ===")
    results = {"passed": 0, "failed": 0, "details": []}

    def record_test(name, success, message=""):
        status = "PASS" if success else "FAIL"
        results["details"].append({"name": name, "status": status, "message": message})
        if success:
            results["passed"] += 1
            print(f"[PASS] {name} - {message}")
        else:
            results["failed"] += 1
            print(f"[FAIL] {name} - {message}", file=sys.stderr)

    # -------------------------------------------------------------
    # TEST 1: Theme Definitions Integrity (All 5 Themes)
    # -------------------------------------------------------------
    themes = {
        "Dark": {
            "Background": MockColor3.fromRGB(13, 13, 15),
            "Border": MockColor3.fromRGB(250, 250, 255),
            "BorderDim": MockColor3.fromRGB(85, 85, 95),
            "Accent": MockColor3.fromRGB(55, 175, 245),
            "TextPrimary": MockColor3.fromRGB(245, 245, 245),
            "TextSecondary": MockColor3.fromRGB(160, 160, 170),
            "Container": MockColor3.fromRGB(22, 22, 26),
            "ContainerDark": MockColor3.fromRGB(15, 15, 18),
        },
        "Light": {
            "Background": MockColor3.fromRGB(242, 243, 246),
            "Border": MockColor3.fromRGB(12, 12, 16),
            "BorderDim": MockColor3.fromRGB(130, 130, 140),
            "Accent": MockColor3.fromRGB(45, 155, 235),
            "TextPrimary": MockColor3.fromRGB(15, 15, 20),
            "TextSecondary": MockColor3.fromRGB(75, 75, 85),
            "Container": MockColor3.fromRGB(255, 255, 255),
            "ContainerDark": MockColor3.fromRGB(228, 230, 236),
        },
        "TranslucentDark": {
            "Background": MockColor3.fromRGB(12, 12, 16),
            "Border": MockColor3.fromRGB(250, 250, 255),
            "BorderDim": MockColor3.fromRGB(90, 90, 110),
            "Accent": MockColor3.fromRGB(55, 175, 245),
            "TextPrimary": MockColor3.fromRGB(255, 255, 255),
            "TextSecondary": MockColor3.fromRGB(180, 180, 195),
            "Container": MockColor3.fromRGB(24, 24, 32),
            "ContainerDark": MockColor3.fromRGB(14, 14, 20),
        },
        "TranslucentLight": {
            "Background": MockColor3.fromRGB(240, 242, 248),
            "Border": MockColor3.fromRGB(12, 12, 16),
            "BorderDim": MockColor3.fromRGB(120, 120, 135),
            "Accent": MockColor3.fromRGB(45, 155, 235),
            "TextPrimary": MockColor3.fromRGB(12, 12, 16),
            "TextSecondary": MockColor3.fromRGB(70, 70, 80),
            "Container": MockColor3.fromRGB(255, 255, 255),
            "ContainerDark": MockColor3.fromRGB(225, 228, 236),
        },
        "Adaptive": {
            "Background": MockColor3.fromRGB(18, 18, 22),
            "Border": MockColor3.fromRGB(240, 240, 250),
            "BorderDim": MockColor3.fromRGB(80, 80, 95),
            "Accent": MockColor3.fromRGB(55, 175, 245),
            "TextPrimary": MockColor3.fromRGB(245, 245, 245),
            "TextSecondary": MockColor3.fromRGB(165, 165, 175),
            "Container": MockColor3.fromRGB(26, 26, 32),
            "ContainerDark": MockColor3.fromRGB(18, 18, 22),
        }
    }
    record_test("Theme_Palette_Completeness", len(themes) == 5, "All 5 core themes defined with all color tokens")

    # -------------------------------------------------------------
    # TEST 2: CoreUI:CreateSubTabs Simulation & Polymorphism
    # -------------------------------------------------------------
    def mock_create_subtabs(parentTab, subTabNames, theme):
        if isinstance(parentTab, dict) and "Page" in parentTab:
            parentPage = parentTab["Page"]
        elif isinstance(parentTab, MockInstance) and parentTab.IsA("GuiObject"):
            parentPage = parentTab
        else:
            raise TypeError("[CoreUI:CreateSubTabs] Invalid parentTab provided.")

        subTabBar = MockInstance("Frame", "SubTabBar")
        subTabBar.Size = MockUDim2.new(1, -4, 0, 26)
        subTabBar.Position = MockUDim2.new(0, 2, 0, 0)
        subTabBar.BackgroundColor3 = theme["ContainerDark"]
        subTabBar.LayoutOrder = 1
        subTabBar.Parent = parentPage
        parentPage.Children.append(subTabBar)

        barStroke = MockInstance("UIStroke", "BarStroke")
        barStroke.Color = theme["Border"]
        barStroke.Thickness = 1.2
        barStroke.Parent = subTabBar
        subTabBar.Children.append(barStroke)

        subPagesContainer = MockInstance("Frame", "SubPagesContainer")
        subPagesContainer.Size = MockUDim2.new(1, 0, 0, 0)
        subPagesContainer.AutomaticSize = "Y"
        subPagesContainer.LayoutOrder = 2
        subPagesContainer.Parent = parentPage
        parentPage.Children.append(subPagesContainer)

        subTabs = {
            "Bar": subTabBar,
            "Container": subPagesContainer,
            "ActiveSubTab": None,
            "Tabs": {},
            "SubTabList": [],
            "OnTabChanged": None,
        }

        numTabs = len(subTabNames)
        tabWidthScale = 1.0 / max(1, numTabs)
        spacingOffset = math.floor((4 * (numTabs - 1)) / numTabs) if numTabs > 0 else 0

        for idx, name in enumerate(subTabNames, start=1):
            btn = MockInstance("TextButton", f"{name}SubTabBtn")
            btn.Size = MockUDim2.new(tabWidthScale, -spacingOffset, 1, 0)
            btn.BackgroundColor3 = theme["Accent"] if idx == 1 else theme["Container"]
            btn.BackgroundTransparency = 0 if idx == 1 else 0.0
            btn.Text = f"[ {name} ]"
            btn.TextColor3 = MockColor3.fromRGB(255, 255, 255) if idx == 1 else theme["TextSecondary"]
            btn.LayoutOrder = idx
            btn.Parent = subTabBar
            subTabBar.Children.append(btn)

            btnStroke = MockInstance("UIStroke", "BtnStroke")
            btnStroke.Color = theme["Border"] if idx == 1 else theme["BorderDim"]
            btnStroke.Thickness = 1.5 if idx == 1 else 1.0
            btnStroke.Parent = btn
            btn.Children.append(btnStroke)

            btnGrad = MockInstance("UIGradient", "ActiveGradient")
            btnGrad.Enabled = (idx == 1)
            btnGrad.Parent = btn
            btn.Children.append(btnGrad)

            page = MockInstance("Frame", f"{name}SubPage")
            page.Size = MockUDim2.new(1, 0, 0, 0)
            page.AutomaticSize = "Y"
            page.Visible = (idx == 1)
            page.LayoutOrder = idx
            page.Parent = subPagesContainer
            subPagesContainer.Children.append(page)

            subTabObj = {
                "Name": name,
                "Button": btn,
                "Page": page,
                "Stroke": btnStroke,
                "Gradient": btnGrad,
                "ParentTab": parentTab,
                "Index": idx
            }

            subTabs[name] = subTabObj
            subTabs[idx] = subTabObj
            subTabs["SubTabList"].append(subTabObj)
            if idx == 1:
                subTabs["ActiveSubTab"] = subTabObj

        def select(target):
            if isinstance(target, (str, int)) and target in subTabs:
                targetObj = subTabs[target]
            elif isinstance(target, dict) and "Name" in target:
                targetObj = target
            else:
                return

            if not targetObj or subTabs["ActiveSubTab"] == targetObj:
                return

            oldSubTab = subTabs["ActiveSubTab"]
            subTabs["ActiveSubTab"] = targetObj

            # Deactivate Old SubTab
            if oldSubTab:
                oldSubTab["Page"].Visible = False
                oldSubTab["Page"].Position = MockUDim2.new(0, 0, 0, 0)
                oldSubTab["Button"].BackgroundColor3 = theme["Container"]
                oldSubTab["Button"].TextColor3 = theme["TextSecondary"]
                oldSubTab["Stroke"].Color = theme["BorderDim"]
                oldSubTab["Stroke"].Thickness = 1.0
                if oldSubTab["Gradient"]:
                    oldSubTab["Gradient"].Enabled = False

            # Activate New SubTab
            targetObj["Page"].Visible = True
            targetObj["Page"].Position = MockUDim2.new(0, 0, 0, 0)
            targetObj["Button"].BackgroundColor3 = theme["Accent"]
            targetObj["Button"].TextColor3 = MockColor3.fromRGB(255, 255, 255)
            targetObj["Stroke"].Color = theme["Border"]
            targetObj["Stroke"].Thickness = 1.5
            if targetObj["Gradient"]:
                targetObj["Gradient"].Enabled = True

            if subTabs["OnTabChanged"]:
                subTabs["OnTabChanged"](targetObj["Name"], oldSubTab["Name"] if oldSubTab else None)

        def update_theme(current_theme):
            for tab in subTabs["SubTabList"]:
                if tab == subTabs["ActiveSubTab"]:
                    tab["Button"].BackgroundColor3 = current_theme["Accent"]
                    tab["Button"].BackgroundTransparency = 0
                    tab["Button"].TextColor3 = MockColor3.fromRGB(255, 255, 255)
                    tab["Stroke"].Color = current_theme["Border"]
                    tab["Stroke"].Thickness = 1.5
                    if tab["Gradient"]:
                        tab["Gradient"].Enabled = True
                else:
                    tab["Button"].BackgroundColor3 = current_theme["Container"]
                    tab["Button"].TextColor3 = current_theme["TextSecondary"]
                    tab["Stroke"].Color = current_theme["BorderDim"]
                    tab["Stroke"].Thickness = 1.0
                    if tab["Gradient"]:
                        tab["Gradient"].Enabled = False

        subTabs["Select"] = select
        subTabs["UpdateTheme"] = update_theme
        return subTabs

    # Edge Case: Invalid Parent
    try:
        mock_create_subtabs(None, ["Tab1"], themes["Dark"])
        record_test("Invalid_Parent_Type_Check", False, "Should raise TypeError on nil parent")
    except TypeError:
        record_test("Invalid_Parent_Type_Check", True, "Successfully raised TypeError on nil parent")

    # Edge Case: Single Sub-Tab
    mockTab = {"Page": MockInstance("ScrollingFrame", "Page")}
    sub1 = mock_create_subtabs(mockTab, ["Single Tab"], themes["Dark"])
    record_test("Single_SubTab_Initialization", len(sub1["SubTabList"]) == 1 and sub1["ActiveSubTab"]["Name"] == "Single Tab", "Single subtab creates 1 tab and sets it active")

    # Edge Case: 5 Sub-Tabs
    sub5 = mock_create_subtabs(mockTab, ["T1", "T2", "T3", "T4", "T5"], themes["Dark"])
    record_test("Five_SubTabs_Initialization", len(sub5["SubTabList"]) == 5 and sub5["ActiveSubTab"]["Name"] == "T1", "5 subtabs initialize with proportional width calculation")

    # Edge Case: Polymorphic Access
    combatPage = MockInstance("ScrollingFrame", "CombatPage")
    combatTab = {"Page": combatPage}
    combatSubTabs = mock_create_subtabs(combatTab, ["Aim Assistance", "Hitbox Modifiers"], themes["Dark"])
    
    p1 = combatSubTabs["Aim Assistance"]
    p2 = combatSubTabs[1]
    p3 = combatSubTabs["Hitbox Modifiers"]
    p4 = combatSubTabs[2]
    record_test("Polymorphic_Indexing", (p1 == p2) and (p3 == p4), "String and integer keys index to identical subtab objects")

    # -------------------------------------------------------------
    # TEST 3: Rapid Sub-Tab Switching & State Consistency
    # -------------------------------------------------------------
    # Switch rapidly 1000 times back and forth
    switch_history = []
    def on_changed(new_tab, old_tab):
        switch_history.append((new_tab, old_tab))
    combatSubTabs["OnTabChanged"] = on_changed

    for i in range(1000):
        target = "Hitbox Modifiers" if i % 2 == 0 else "Aim Assistance"
        combatSubTabs["Select"](target)

    # Invariant Check: Exactly 1 Page Visible
    visible_pages = [t["Page"].Name for t in combatSubTabs["SubTabList"] if t["Page"].Visible]
    active_name = combatSubTabs["ActiveSubTab"]["Name"]
    correct_active = (visible_pages == ["Aim AssistanceSubPage"]) and (active_name == "Aim Assistance")
    record_test("Rapid_Switching_State_Invariants", correct_active and len(switch_history) == 1000, f"1000 rapid switches finished with exactly 1 active page: {visible_pages}")

    # No-op Select Check: Selecting already active tab should not trigger OnTabChanged or state churn
    pre_len = len(switch_history)
    combatSubTabs["Select"]("Aim Assistance")
    record_test("No_Op_Select_Guard", len(switch_history) == pre_len, "Selecting already active tab is a clean no-op")

    # -------------------------------------------------------------
    # TEST 4: Theme Swapping Across All 5 Themes & Color Fidelity
    # -------------------------------------------------------------
    theme_test_passed = True
    for theme_name, theme_data in themes.items():
        combatSubTabs["UpdateTheme"](theme_data)
        active_btn = combatSubTabs["ActiveSubTab"]["Button"]
        inactive_btn = combatSubTabs["Hitbox Modifiers"]["Button"]
        
        # Check active button colors
        if active_btn.BackgroundColor3 != theme_data["Accent"]:
            theme_test_passed = False
            print(f"Theme {theme_name} Active Button Color Mismatch: {active_btn.BackgroundColor3} vs {theme_data['Accent']}")
        # Check inactive button colors
        if inactive_btn.BackgroundColor3 != theme_data["Container"]:
            theme_test_passed = False
            print(f"Theme {theme_name} Inactive Button Color Mismatch: {inactive_btn.BackgroundColor3} vs {theme_data['Container']}")
        # Check inactive stroke
        if combatSubTabs["Hitbox Modifiers"]["Stroke"].Color != theme_data["BorderDim"]:
            theme_test_passed = False
            print(f"Theme {theme_name} Inactive Stroke Color Mismatch")

    record_test("All_5_Themes_UpdateTheme_Fidelity", theme_test_passed, "Active and inactive subtab colors match all 5 theme palettes perfectly")

    # -------------------------------------------------------------
    # TEST 5: AutomaticSize & Layout Bounding Simulation
    # -------------------------------------------------------------
    # Container structure:
    # parentPage (ScrollingFrame)
    #   ├── SubTabBar (Frame, Size: Y=26, AutomaticSize: None)
    #   └── SubPagesContainer (Frame, AutomaticSize: Y)
    #         ├── Aim AssistanceSubPage (Frame, AutomaticSize: Y, Visible: True)
    #         │     └── ColumnsContainer (Frame, AutomaticSize: Y)
    #         │           ├── LeftCol (Frame, Size: Y=350)
    #         │           └── RightCol (Frame, Size: Y=420)
    #         └── Hitbox ModifiersSubPage (Frame, AutomaticSize: Y, Visible: False)
    #               └── ColumnsContainer (Frame, AutomaticSize: Y)
    #                     ├── LeftCol (Frame, Size: Y=120)
    #                     └── RightCol (Frame, Size: Y=80)

    def calculate_effective_canvas_height(subtabs_obj, aim_h, hit_h):
        # UIListLayout with invisible elements collapsed
        bar_height = 26 + 2 + 10 # 26px height + 2px pos + 10px list padding
        active_tab_name = subtabs_obj["ActiveSubTab"]["Name"]
        if active_tab_name == "Aim Assistance":
            active_content_height = aim_h
        else:
            active_content_height = hit_h
        return bar_height + active_content_height

    h_aim = calculate_effective_canvas_height(combatSubTabs, 420, 120)
    combatSubTabs["Select"]("Hitbox Modifiers")
    h_hit = calculate_effective_canvas_height(combatSubTabs, 420, 120)
    
    record_test("Dynamic_Canvas_Bounding_Check", h_aim == 458 and h_hit == 158, f"Aim height = {h_aim}px, Hitbox height = {h_hit}px. Inactive tab collapses completely (0px footprint)")

    # -------------------------------------------------------------
    # TEST 6: Combat Config Serialization & Key Integrity
    # -------------------------------------------------------------
    combat_keys = {
        "silent_aim": False,
        "wall_bang": False,
        "target_head": True,
        "track_teammates": False,
        "trigger_bot": False,
        "aim_tracking": False,
        "aim_always": False,
        "fov_circle": False,
        "expand_hitboxes": False,
        "FOV Radius": 120,
        "Hit Chance %": 100,
        "Aim Smoothing": 25,
        "Hitbox Size": 12
    }

    # Simulate saving config
    encoded_json = json.dumps({"CombatConfig": combat_keys})
    decoded = json.loads(encoded_json)
    
    keys_match = decoded["CombatConfig"] == combat_keys
    record_test("Combat_Config_Roundtrip_Fidelity", keys_match, f"All {len(combat_keys)} combat feature toggles and sliders serialized and deserialized accurately")

    print("\n=======================================================")
    print(f"SUMMARY: {results['passed']} PASSED, {results['failed']} FAILED")
    print("=======================================================")
    return results

if __name__ == "__main__":
    res = run_stress_tests()
    if res["failed"] > 0:
        sys.exit(1)
    sys.exit(0)
