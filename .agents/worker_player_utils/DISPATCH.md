## 2026-08-31T23:34:20Z
Scope & Write Ownership:
- Create `Modules/PlayerUtilities.luau` (and hook into `MainTab` sub-tab `[ Player Utilities ]` in `Core/Main.luau`).
- Implement Server Hop: Fetch public server list via `game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")`, parse via `HttpService:JSONDecode`, find a valid server (`playing < maxPlayers` and `id ~= game.JobId`), and call `TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)`. Wrap in safe `pcall` with Notification feedback.
- Implement Rejoin Server: `TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)` with safe `pcall`.
- Implement Copy IDs: Copy Place ID, Game ID, and Job ID to clipboard via `setclipboard(tostring(...))` with Notification feedback.
- Implement Anti-AFK timeout preventer: Listen to `LocalPlayer.Idled` and invoke `VirtualUser:ClickButton2(Vector2.zero)` / `VirtualUser:CaptureController()` safely in a `pcall`. Provide toggle state.
- Implement Click Teleport tool: Create a non-handle `Tool` named `"Click Teleport"` placed in `LocalPlayer.Backpack` or a Ctrl+Click mouse listener that teleports `HumanoidRootPart` to `Mouse.Hit.Position + Vector3.new(0, 3, 0)`.
- Ensure all services (`TeleportService`, `HttpService`, `VirtualUser`, `GuiService`, etc.) are properly declared via `game:GetService(...)`.
- Run `python check_services.py` to verify.
- Produce `handoff.md` and notify orchestrator via send_message.
