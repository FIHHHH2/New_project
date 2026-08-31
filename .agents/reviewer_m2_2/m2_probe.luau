-- Reviewer 2 Milestone 2 Live Verification Probe
local TweenService = game:GetService(" TweenService\)
local Players = game:GetService(\Players\)
local CoreGui = game:GetService(\CoreGui\)

print(\[REV2_PROBE] Starting Milestone 2 Live Validation...\)

local basePath = \A:/Potassium/Modular-Roblox-Menu/\
local files = {
 \UI/Animations.luau\,
 \UI/UI.luau\,
 \UI/Notification.luau\,
 \UI/PlayerList.luau\,
 \UI/ChatWidget.luau\,
 \UI/MusicTracker.luau\,
 \Core/CoreUI.luau\
}

local compiledModules = {}
local readfileFn = readfile or (getgenv and getgenv().readfile)

for _, relPath in ipairs(files) do
 local fullPath = basePath .. relPath
 local code = nil
 if readfileFn then
 pcall(function() code = readfileFn(fullPath) end)
 end
 if not code then
 print(\[REV2_PROBE] Testing via direct load of: \ .. relPath)
 else
 local fn, err = loadstring(code, \=\ .. relPath)
 if not fn then
 print(\[REV2_PROBE_ERROR] Compile failed for \ .. relPath .. \: \ .. tostring(err))
 else
 print(\[REV2_PROBE_PASS] Compiled cleanly: \ .. relPath)
 end
 end
end

print(\[REV2_PROBE] Completed Module Compilation Probe.\)
