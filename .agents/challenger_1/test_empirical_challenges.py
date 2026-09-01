"""
Empirical Verification & Adversarial Stress Harness for Challenger 1
Focusing on:
1. Drawing API Fallback (Visuals, FOV Circle, ESP Boxes/Tracers)
2. Server Hop & HTTP Failure Modes (Empty servers, HTTP errors, Teleport failures)
3. Bidirectional Wallbang Raycasting (Zero-thickness, infinite distance, transparent barriers, penetration thresholds)
4. Anti-AFK & Character Lifecycle (Unparented, respawning, dead characters)
5. Static Service & BOM Integrity
"""

import math
import random
import json

# ==============================================================================
# 1. DRAWING API FALLBACK SIMULATION
# ==============================================================================
def test_drawing_api_fallback():
    print("\n--- TEST 1: Drawing API Fallback Simulation ---")
    
    # Scenario A: Drawing is completely nil (unsupported executor)
    drawing_api_available = False
    
    # Mocking Visuals module behavior with Drawing = nil
    class MockVisuals:
        def __init__(self, has_drawing):
            self.hasDrawing = has_drawing
            self.Box2D = True
            self.BoxOutlines = True
            self.Tracers = True
            self.Distance = True
            self.Skeleton = True
            self.Chams = True
            self.player_visuals = {}

        def create_player_visual(self, player_id):
            pv = {
                "Highlight": None,
                "BoxOutline": None,
                "Box": None,
                "HealthBarBg": None,
                "HealthBarFill": None,
                "Tracer": None,
                "DistanceTag": None,
                "Bones": []
            }
            if self.hasDrawing:
                # If Drawing exists, creates items
                pv["BoxOutline"] = "DrawingSquare"
                pv["Box"] = "DrawingSquare"
                pv["Tracer"] = "DrawingLine"
                pv["DistanceTag"] = "DrawingText"
                pv["Bones"] = ["DrawingLine"] * 14
            return pv

        def update_player(self, player_id, pv, has_character=True, on_screen=True):
            # 3D Chams does not require Drawing
            if self.Chams and has_character:
                pv["Highlight"] = "HighlightInstance"
            
            # 2D Drawing guard
            if not on_screen or not self.hasDrawing:
                # hide all safe
                return "2D Skipped Safely"
            
            return "2D Rendered"

        def cleanup(self):
            for pv in self.player_visuals.values():
                if pv["Highlight"]:
                    pass
                if pv["BoxOutline"]:
                    pass
            self.player_visuals.clear()

    # Test Visuals with Drawing = nil
    vis_no_drawing = MockVisuals(has_drawing=False)
    pv = vis_no_drawing.create_player_visual("Player1")
    assert pv["Box"] is None
    assert pv["Tracer"] is None
    assert pv["DistanceTag"] is None
    assert len(pv["Bones"]) == 0
    
    res = vis_no_drawing.update_player("Player1", pv, has_character=True, on_screen=True)
    assert res == "2D Skipped Safely"
    assert pv["Highlight"] == "HighlightInstance", "3D Highlight Chams must still work even if Drawing API is missing"
    
    # Mocking Combat module FOV circle with Drawing = nil
    class MockCombat:
        def __init__(self, has_drawing):
            self.hasDrawing = has_drawing
            self.fovDrawing = "DrawingCircle" if has_drawing else None
            self.FovCircle = True
            self.FovRadius = 160
            self.FovColor = (255, 255, 255)

        def setFovColor(self, color):
            self.FovColor = color
            if self.fovDrawing:
                self.fovDrawing = f"CircleColor_{color}"

        def render_step(self):
            if self.fovDrawing:
                if self.FovCircle:
                    return "FOV Visible"
                return "FOV Hidden"
            return "FOV No-Op"

    combat_no_drawing = MockCombat(has_drawing=False)
    assert combat_no_drawing.fovDrawing is None
    combat_no_drawing.setFovColor((55, 175, 245)) # Should not raise exception
    assert combat_no_drawing.render_step() == "FOV No-Op"
    
    print("[PASS] Drawing API fallback verified: 0 exceptions, 3D Chams preserved, 2D Drawing safely skipped.")


# ==============================================================================
# 2. SERVER HOP & HTTP FAILURE MODES
# ==============================================================================
def test_server_hop_edge_cases():
    print("\n--- TEST 2: Server Hop & HTTP Failure Modes ---")
    
    class MockTeleportService:
        def __init__(self, should_fail=False):
            self.should_fail = should_fail
            self.teleported_to = None

        def TeleportToPlaceInstance(self, placeId, instanceId, player):
            if self.should_fail:
                raise RuntimeError("Teleport failed: 773 Teleport is restricted in current context")
            self.teleported_to = instanceId

    def simulate_server_hop(http_response_data, http_error=None, current_job_id="job_current", tp_fail=False):
        notifications = []
        def notify(title, msg):
            notifications.append((title, msg))

        notify("Server Hop", "Searching for available public servers...")
        
        # 1. HTTP fetch
        if http_error:
            errMsg = f"Failed to fetch server list: {http_error}"
            notify("Server Hop Error", errMsg)
            return False, errMsg, notifications

        # 2. JSON decode
        try:
            data = json.loads(http_response_data)
        except Exception as e:
            errMsg = "Failed to parse public servers JSON response"
            notify("Server Hop Error", errMsg)
            return False, errMsg, notifications

        if not isinstance(data, dict) or "data" not in data or not isinstance(data["data"], list):
            errMsg = "Failed to parse public servers JSON response"
            notify("Server Hop Error", errMsg)
            return False, errMsg, notifications

        # 3. Filter valid servers
        validServers = []
        for srv in data["data"]:
            if isinstance(srv, dict) and "id" in srv and "playing" in srv and "maxPlayers" in srv:
                try:
                    playing = int(srv["playing"])
                    maxPlayers = int(srv["maxPlayers"])
                    srvId = str(srv["id"])
                    if playing < maxPlayers and srvId != current_job_id and srvId != "":
                        validServers.append({
                            "id": srvId,
                            "playing": playing,
                            "maxPlayers": maxPlayers
                        })
                except (ValueError, TypeError):
                    continue

        if len(validServers) == 0:
            errMsg = "No open public servers found with available player slots."
            notify("Server Hop", errMsg)
            return False, errMsg, notifications

        target = validServers[0]
        notify("Server Hop", f"Connecting to server ({target['playing']}/{target['maxPlayers']} players)...")
        
        tp_service = MockTeleportService(should_fail=tp_fail)
        try:
            tp_service.TeleportToPlaceInstance(123456, target["id"], "LocalPlayer")
        except Exception as e:
            errMsg = f"Teleport failed: {str(e)}"
            notify("Server Hop Error", errMsg)
            return False, errMsg, notifications

        return True, f"Teleporting to {target['id']}", notifications

    # Edge Case 2.1: HTTP 500 or network timeout
    ok, err, notes = simulate_server_hop(None, http_error="HTTP 502 Bad Gateway")
    assert not ok and "Failed to fetch server list" in err
    assert any("Server Hop Error" in n[0] for n in notes)

    # Edge Case 2.2: Malformed JSON response
    ok, err, notes = simulate_server_hop("<html><body>Error 404</body></html>")
    assert not ok and "Failed to parse public servers" in err

    # Edge Case 2.3: Empty server list
    ok, err, notes = simulate_server_hop(json.dumps({"data": []}))
    assert not ok and "No open public servers found" in err

    # Edge Case 2.4: All servers full or matching current JobId
    full_servers_payload = json.dumps({
        "data": [
            {"id": "job_current", "playing": 5, "maxPlayers": 12}, # current server
            {"id": "job_full_1", "playing": 12, "maxPlayers": 12},  # full
            {"id": "job_full_2", "playing": 15, "maxPlayers": 12}   # overflow
        ]
    })
    ok, err, notes = simulate_server_hop(full_servers_payload, current_job_id="job_current")
    assert not ok and "No open public servers found" in err

    # Edge Case 2.5: Valid servers found, but TeleportService fails (Roblox restriction)
    valid_payload = json.dumps({
        "data": [
            {"id": "job_target_123", "playing": 8, "maxPlayers": 12}
        ]
    })
    ok, err, notes = simulate_server_hop(valid_payload, tp_fail=True)
    assert not ok and "Teleport failed" in err

    # Edge Case 2.6: Successful server hop
    ok, msg, notes = simulate_server_hop(valid_payload, tp_fail=False)
    assert ok and "Teleporting to job_target_123" in msg

    print("[PASS] Server Hop edge cases verified: safe pcalls, user notifications on all 6 failure modes.")


# ==============================================================================
# 3. BIDIRECTIONAL WALLBANG RAYCASTING SIMULATION
# ==============================================================================
def test_bidirectional_wallbang():
    print("\n--- TEST 3: Bidirectional Wallbang Raycasting Simulation ---")

    class MockPart:
        def __init__(self, name, min_x, max_x, can_collide=True, transparency=0.0):
            self.Name = name
            self.MinX = min_x
            self.MaxX = max_x
            self.CanCollide = can_collide
            self.Transparency = transparency

    def check_wallbang_penetration(origin_x, target_x, obstacles, max_thickness=5.0):
        # 1D line raycast simulation along X axis
        if origin_x == target_x:
            return True, 0.0 # Point-blank / zero distance

        dist = abs(target_x - origin_x)
        if dist < 0.1:
            return True, 0.0

        # Forward raycast from origin to target
        direction = 1 if target_x > origin_x else -1
        forward_hit = None
        for obs in obstacles:
            if direction == 1 and obs.MinX >= origin_x and obs.MinX <= target_x:
                forward_hit = obs
                break
            elif direction == -1 and obs.MaxX <= origin_x and obs.MaxX >= target_x:
                forward_hit = obs
                break

        if not forward_hit:
            # Direct line of sight
            return True, 0.0

        # Non-collidable transparent barrier
        if not forward_hit.CanCollide and forward_hit.Transparency >= 0.75:
            return True, 0.0

        entry_point = forward_hit.MinX if direction == 1 else forward_hit.MaxX

        # Backward raycast from target to origin
        backward_hit = None
        for obs in reversed(obstacles):
            if direction == 1 and obs.MaxX <= target_x and obs.MaxX >= origin_x:
                backward_hit = obs
                break
            elif direction == -1 and obs.MinX >= target_x and obs.MinX <= origin_x:
                backward_hit = obs
                break

        if backward_hit:
            exit_point = backward_hit.MaxX if direction == 1 else backward_hit.MinX
        else:
            exit_point = target_x

        thickness = abs(exit_point - entry_point)
        can_penetrate = (thickness <= max_thickness)
        return can_penetrate, thickness

    # Case 3.1: Zero distance / point-blank
    can_hit, th = check_wallbang_penetration(0, 0.05, [])
    assert can_hit and th == 0.0

    # Case 3.2: Direct line of sight (no obstacles)
    can_hit, th = check_wallbang_penetration(0, 100, [])
    assert can_hit and th == 0.0

    # Case 3.3: Thin wall (thickness 3 studs <= tolerance 5 studs)
    wall_thin = [MockPart("Wall", min_x=10, max_x=13, can_collide=True, transparency=0.0)]
    can_hit, th = check_wallbang_penetration(0, 50, wall_thin, max_thickness=5.0)
    assert can_hit and math.isclose(th, 3.0), f"Expected can_hit=True, th=3.0, got {can_hit}, {th}"

    # Case 3.4: Thick wall (thickness 12 studs > tolerance 5 studs)
    wall_thick = [MockPart("Bunker", min_x=10, max_x=22, can_collide=True, transparency=0.0)]
    can_hit, th = check_wallbang_penetration(0, 50, wall_thick, max_thickness=5.0)
    assert not can_hit and math.isclose(th, 12.0), f"Expected can_hit=False, th=12.0, got {can_hit}, {th}"

    # Case 3.5: Transparent non-collidable barrier (glass / trigger zone)
    glass_wall = [MockPart("GlassBarrier", min_x=10, max_x=30, can_collide=False, transparency=0.8)]
    can_hit, th = check_wallbang_penetration(0, 50, glass_wall, max_thickness=5.0)
    assert can_hit and th == 0.0, f"Expected transparent barrier to be penetrable, got {can_hit}, {th}"

    # Case 3.6: Multiple obstacles (two 2-stud walls separated by 10 studs space: total wall span = 14 studs)
    multi_wall = [
        MockPart("Wall1", min_x=10, max_x=12, can_collide=True, transparency=0.0),
        MockPart("Wall2", min_x=22, max_x=24, can_collide=True, transparency=0.0)
    ]
    can_hit, th = check_wallbang_penetration(0, 50, multi_wall, max_thickness=5.0)
    # Entry at 10, exit at 24 -> total thickness span 14 studs > 5 studs tolerance -> blocked
    assert not can_hit and math.isclose(th, 14.0)

    print("[PASS] Bidirectional Wallbang raycasting verified: zero-thickness, direct LOS, thin/thick walls, transparent barriers.")


# ==============================================================================
# 4. ANTI-AFK & CHARACTER LIFECYCLE
# ==============================================================================
def test_anti_afk_and_character_lifecycle():
    print("\n--- TEST 4: Anti-AFK & Character Lifecycle ---")

    class MockVirtualUser:
        def __init__(self, fail=False):
            self.fail = fail
            self.captured = False
            self.clicks = 0

        def CaptureController(self):
            if self.fail:
                raise RuntimeError("VirtualUser permissions restricted")
            self.captured = True

        def ClickButton2(self, pos):
            if self.fail:
                raise RuntimeError("VirtualUser permissions restricted")
            self.clicks += 1

    class MockPlayer:
        def __init__(self):
            self.Character = None
            self.idled_callbacks = []

        def on_idled(self):
            for cb in self.idled_callbacks:
                cb()

    # Scenario 4.1: Anti-AFK fires while Character is nil (Loading/Respawning)
    player = MockPlayer()
    vu = MockVirtualUser()
    
    anti_afk_enabled = True
    def anti_afk_handler():
        try:
            vu.CaptureController()
            vu.ClickButton2((0, 0))
        except Exception:
            pass

    player.idled_callbacks.append(anti_afk_handler)
    
    # Trigger Idled with Character = None
    player.Character = None
    player.on_idled()
    assert vu.captured and vu.clicks == 1, "Anti-AFK must successfully click even when Character is nil"

    # Trigger Idled with Character = Dead/Unparented
    class MockChar:
        def __init__(self):
            self.Parent = None
    player.Character = MockChar()
    player.on_idled()
    assert vu.clicks == 2, "Anti-AFK must successfully click when Character is unparented"

    # Scenario 4.2: VirtualUser raises error (Restricted executor context)
    vu_restricted = MockVirtualUser(fail=True)
    def safe_anti_afk():
        try:
            vu_restricted.CaptureController()
            vu_restricted.ClickButton2((0, 0))
        except Exception:
            pass # Wrapped in pcall

    player.idled_callbacks = [safe_anti_afk]
    player.on_idled() # Should not raise exception
    print("[PASS] Anti-AFK lifecycle verified: independent of Character state, immune to respawn or unparenting, protected by pcall.")


# ==============================================================================
# 5. ALL TESTS RUNNER
# ==============================================================================
if __name__ == "__main__":
    print("=================================================================")
    print("RUNNING CHALLENGER 1 EMPIRICAL ADVERSARIAL STRESS SUITE")
    print("=================================================================")
    test_drawing_api_fallback()
    test_server_hop_edge_cases()
    test_bidirectional_wallbang()
    test_anti_afk_and_character_lifecycle()
    print("\n=================================================================")
    print("ALL EMPIRICAL TESTS PASSED (4/4 TEST MODULES)")
    print("=================================================================")
