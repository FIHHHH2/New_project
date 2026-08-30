# Modular Roblox UI Framework

A clean, modular, translucent UI suite for Roblox Lua/Luau.

## Architecture

- `src/AnimationEngine.luau` - Handles smooth tweens, spring scaling, hover animations, and toggle feedback.
- `src/CoreUI.luau` - Translucent window rendering, dynamic viewport dragging, canvas resizing, tab transitions, profile card, and inline keybind toggles.
- `src/FeatureManager.luau` - Global keybind listeners, state dispatching, and callback execution.
- `src/Main.luau` - Entry point showing tab creation, feature registration, and character bindings.
