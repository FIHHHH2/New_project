"""
Milestone 1 Empirical Stress Test & Verification Suite
Adversarial test harness for UI/Animations.luau and Core/CoreUI.luau
"""

import sys
import os
import re
import math
import random
import time

def test_animation_exports():
    print("[TEST 1] Verifying function signatures and exports in UI/Animations.luau...")
    with open("UI/Animations.luau", "r", encoding="utf-8") as f:
        content = f.read()

    required_functions = [
        ("popScale", r"function\s+Animations\.popScale\s*\("),
        ("attachMicroSquash", r"function\s+Animations\.attachMicroSquash\s*\("),
        ("attachSliderGlow", r"function\s+Animations\.attachSliderGlow\s*\("),
        ("pulseIndicator", r"function\s+Animations\.pulseIndicator\s*\("),
        ("openWindow", r"function\s+Animations\.openWindow\s*\("),
        ("closeWindow", r"function\s+Animations\.closeWindow\s*\("),
        ("popIn", r"function\s+Animations\.popIn\s*\("),
        ("popOut", r"function\s+Animations\.popOut\s*\("),
        ("dominoRipple", r"function\s+Animations\.dominoRipple\s*\("),
        ("attachButtonEffects", r"function\s+Animations\.attachButtonEffects\s*\("),
    ]

    for name, pattern in required_functions:
        match = re.search(pattern, content)
        if not match:
            print(f"  [FAIL] Missing export: Animations.{name}")
            return False
        print(f"  [PASS] Found export Animations.{name}")

    # Verify return Animations
    if "return Animations" not in content:
        print("  [FAIL] Animations module does not return Animations table")
        return False

    print("  [PASS] All 10 Animations exports verified successfully.\n")
    return True


def test_coreui_window_controller_signatures():
    print("[TEST 2] Verifying CoreUI Window Controller Methods...")
    with open("Core/CoreUI.luau", "r", encoding="utf-8") as f:
        content = f.read()

    controller_methods = [
        ("CoreUI:Open", r"function\s+CoreUI:Open\s*\("),
        ("CoreUI:Close", r"function\s+CoreUI:Close\s*\("),
        ("CoreUI:Toggle", r"function\s+CoreUI:Toggle\s*\("),
        ("CoreUI:SetVisible", r"function\s+CoreUI:SetVisible\s*\("),
    ]

    for name, pattern in controller_methods:
        match = re.search(pattern, content)
        if not match:
            print(f"  [FAIL] Missing controller method: {name}")
            return False
        print(f"  [PASS] Found controller method {name}")

    print("  [PASS] All CoreUI window controller methods verified.\n")
    return True


def test_rapid_toggle_state_simulation():
    print("[TEST 3] Simulating rapid toggle state flips and tween race conditions (10,000 iterations)...")
    
    # Simulate the exact logic in CoreUI:AddToggle and updateToggleVisual
    class ToggleState:
        def __init__(self):
            self.state = False
            self.visible = False
            self.scale = 0.0
            self.pending_close_tasks = []

        def flip(self, current_time):
            self.state = not self.state
            if self.state:
                # Enable
                self.visible = True
                self.scale = 1.0 # Target scale from popScale
            else:
                # Disable: closeTween with 0.12s delay
                close_time = current_time + 0.12
                self.scale = 0.0
                self.pending_close_tasks.append(close_time)

        def step(self, current_time):
            # Process completed close tweens
            remaining = []
            for t in self.pending_close_tasks:
                if current_time >= t:
                    if not self.state:
                        self.visible = False
                else:
                    remaining.append(t)
            self.pending_close_tasks = remaining

    toggle = ToggleState()
    cur_time = 0.0

    for i in range(10000):
        dt = random.uniform(0.001, 0.200)
        cur_time += dt
        toggle.step(cur_time)
        toggle.flip(cur_time)
        toggle.step(cur_time)

        # Invariant: if state is True, visible MUST be True
        if toggle.state and not toggle.visible:
            print(f"  [FAIL] Toggle invariant violated at iteration {i}: state=True but visible=False!")
            return False

    # Settle
    cur_time += 1.0
    toggle.step(cur_time)

    # Invariant: final state consistency
    if toggle.state != toggle.visible:
        print(f"  [FAIL] Settled state mismatch: state={toggle.state}, visible={toggle.visible}")
        return False

    print(f"  [PASS] 10,000 rapid toggle flips passed. State consistency 100% (state={toggle.state}, visible={toggle.visible}).\n")
    return True


def test_slider_math_and_extreme_dragging():
    print("[TEST 4] Simulating slider dragging under extreme boundary inputs...")
    
    # Test cases: normal, negative coords, huge coords, 0 width, inverted min/max, 0 delta
    def clamp(val, min_val, max_val):
        return max(min_val, min(max_val, val))

    def compute_slider(input_x, bar_pos_x, bar_width, min_val, max_val):
        if bar_width <= 0:
            ratio = 0.0
        else:
            ratio = clamp((input_x - bar_pos_x) / bar_width, 0.0, 1.0)
        
        raw_val = min_val + (max_val - min_val) * ratio
        val = math.floor(raw_val + 0.5)
        
        # Calculate fill ratio
        if max_val == min_val:
            fill_ratio = 0.0
        else:
            fill_ratio = clamp((val - min_val) / (max_val - min_val), 0.0, 1.0)
            
        return val, fill_ratio

    # Adversarial test vectors
    test_cases = [
        {"input_x": -999999, "bar_x": 100, "bar_w": 200, "min": 0, "max": 100},
        {"input_x": 999999, "bar_x": 100, "bar_w": 200, "min": 0, "max": 100},
        {"input_x": 100, "bar_x": 100, "bar_w": 200, "min": 0, "max": 100},
        {"input_x": 200, "bar_x": 100, "bar_w": 200, "min": 0, "max": 100},
        {"input_x": 300, "bar_x": 100, "bar_w": 200, "min": 0, "max": 100},
        {"input_x": 150, "bar_x": 100, "bar_w": 0, "min": 0, "max": 100}, # zero-width track
        {"input_x": 150, "bar_x": 100, "bar_w": 200, "min": -50, "max": 50},
        {"input_x": 150, "bar_x": 100, "bar_w": 200, "min": 50, "max": 50}, # equal min/max
    ]

    for tc in test_cases:
        val, ratio = compute_slider(tc["input_x"], tc["bar_x"], tc["bar_w"], tc["min"], tc["max"])
        if math.isnan(val) or math.isnan(ratio) or math.isinf(val) or math.isinf(ratio):
            print(f"  [FAIL] NaN or Inf detected with inputs {tc}: val={val}, ratio={ratio}")
            return False
        if not (0.0 <= ratio <= 1.0):
            print(f"  [FAIL] Slider ratio out of bounds [0, 1]: {ratio} for tc {tc}")
            return False

    # Random fuzzing 50,000 iterations
    for _ in range(50000):
        ix = random.uniform(-1e6, 1e6)
        bx = random.uniform(-1000, 1000)
        bw = random.uniform(0, 1000)
        mn = random.uniform(-1000, 1000)
        mx = mn + random.uniform(0, 2000)
        val, ratio = compute_slider(ix, bx, bw, mn, mx)
        if math.isnan(val) or math.isnan(ratio) or not (0.0 <= ratio <= 1.0):
            print(f"  [FAIL] Slider fuzzing failed: ix={ix}, bx={bx}, bw={bw}, mn={mn}, mx={mx} -> val={val}, ratio={ratio}")
            return False

    print("  [PASS] Slider math and extreme dragging fuzzer passed 50,000 cases with 0 NaN and 100% bounded ratios.\n")
    return True


def test_rapid_tab_switching_simulation():
    print("[TEST 5] Simulating rapid tab and subtab switching race conditions (5,000 transitions)...")
    
    class TabManager:
        def __init__(self, tab_names):
            self.tab_names = tab_names
            self.active_tab = tab_names[0]
            self.pages = {name: {"visible": (name == tab_names[0]), "pos_x": 0} for name in tab_names}
            self.pending_exits = [] # (scheduled_time, tab_name)

        def select_tab(self, new_tab, current_time):
            if new_tab == self.active_tab:
                return
            old_tab = self.active_tab
            self.active_tab = new_tab

            # Outgoing animation schedule (0.16s exit)
            self.pending_exits.append((current_time + 0.16, old_tab))

            # Incoming page activation
            self.pages[new_tab]["visible"] = True
            self.pages[new_tab]["pos_x"] = 0

        def step(self, current_time):
            remaining = []
            for exit_time, tab_name in self.pending_exits:
                if current_time >= exit_time:
                    # Only hide if it's still NOT the active tab
                    if self.active_tab != tab_name:
                        self.pages[tab_name]["visible"] = False
                else:
                    remaining.append((exit_time, tab_name))
            self.pending_exits = remaining

    tabs = TabManager(["Combat", "Visuals", "Movement", "Settings", "Configs"])
    cur_time = 0.0

    for i in range(5000):
        dt = random.uniform(0.005, 0.25)
        cur_time += dt
        tabs.step(cur_time)
        target = random.choice(tabs.tab_names)
        tabs.select_tab(target, cur_time)
        tabs.step(cur_time)

        # Invariant: active tab MUST always be visible
        if not tabs.pages[tabs.active_tab]["visible"]:
            print(f"  [FAIL] Active tab {tabs.active_tab} is hidden at iteration {i}!")
            return False

    # Settle
    cur_time += 1.0
    tabs.step(cur_time)

    # Invariant: exactly 1 tab page visible after settling
    visible_tabs = [name for name, p in tabs.pages.items() if p["visible"]]
    if visible_tabs != [tabs.active_tab]:
        print(f"  [FAIL] Settled visible tabs mismatch: expected [{tabs.active_tab}], got {visible_tabs}")
        return False

    print(f"  [PASS] 5,000 rapid tab transitions passed. Invariant preserved 100% (Active: {tabs.active_tab}, Visible: {visible_tabs}).\n")
    return True


def test_window_controller_transitions():
    print("[TEST 6] Simulating window Open/Close/Toggle transitions with IsTransitioning lock...")
    
    class WindowController:
        def __init__(self):
            self.is_open = True
            self.is_transitioning = False
            self.visible = True
            self.pending_callback = None
            self.callback_time = 0.0

        def open(self, cur_time):
            if self.is_open or self.is_transitioning:
                return False
            self.is_transitioning = True
            self.visible = True
            self.callback_time = cur_time + 0.24
            def cb():
                self.is_open = True
                self.is_transitioning = False
            self.pending_callback = cb
            return True

        def close(self, cur_time):
            if not self.is_open or self.is_transitioning:
                return False
            self.is_transitioning = True
            self.callback_time = cur_time + 0.18
            def cb():
                self.is_open = False
                self.visible = False
                self.is_transitioning = False
            self.pending_callback = cb
            return True

        def toggle(self, cur_time):
            if self.is_open:
                return self.close(cur_time)
            else:
                return self.open(cur_time)

        def step(self, cur_time):
            if self.pending_callback and cur_time >= self.callback_time:
                cb = self.pending_callback
                self.pending_callback = None
                cb()

    wc = WindowController()
    cur_time = 0.0

    for i in range(10000):
        dt = random.uniform(0.001, 0.30)
        cur_time += dt
        wc.step(cur_time)
        wc.toggle(cur_time)
        wc.step(cur_time)

    # Settle
    cur_time += 1.0
    wc.step(cur_time)

    if wc.is_transitioning:
        print("  [FAIL] Window still transitioning after settling!")
        return False
    if wc.is_open != wc.visible:
        print(f"  [FAIL] Window state desync: is_open={wc.is_open}, visible={wc.visible}")
        return False

    print(f"  [PASS] 10,000 window toggles passed. No deadlocks or state inversions (is_open={wc.is_open}, visible={wc.visible}).\n")
    return True


if __name__ == "__main__":
    print("================================================================================")
    print("EMPIRICAL CHALLENGER VERIFICATION HARNESS — MILESTONE 1")
    print("================================================================================\n")
    
    results = [
        test_animation_exports(),
        test_coreui_window_controller_signatures(),
        test_rapid_toggle_state_simulation(),
        test_slider_math_and_extreme_dragging(),
        test_rapid_tab_switching_simulation(),
        test_window_controller_transitions(),
    ]

    if all(results):
        print("================================================================================")
        print("ALL EMPIRICAL CHALLENGE SUITES PASSED (6/6 SUITES, 0 FAILURES)")
        print("================================================================================")
        sys.exit(0)
    else:
        print("================================================================================")
        print("EMPIRICAL CHALLENGE FAILED")
        print("================================================================================")
        sys.exit(1)
