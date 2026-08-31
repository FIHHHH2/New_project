## 2026-08-31T17:19:31Z
Scope of Investigation:
Investigate Window & Popup Transitions for Requirement R2 across UI/UI.luau, UI/PlayerList.luau, UI/ChatWidget.luau, UI/MusicTracker.luau, and UI/Notification.luau:
1. How window open/close/toggle is currently handled across Main Menu (UI.luau), PlayerList, ChatWidget, MusicTracker, and Notification.
2. How to implement spring scale (0.95 -> 1.0) and fade in/out transitions cleanly across all 4-5 windows without breaking drag or positioning.
3. How context menus (PlayerList player action popup, Chat quick phrases) are currently positioned and animated, and how to implement smooth pop-in and auto-positioning.
4. How to implement staggered domino slide-in animations for player list rows and incoming chat messages.
5. Check for any missing services or compatibility issues with Roblox Luau environment.
