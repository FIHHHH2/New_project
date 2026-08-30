# Modular Roblox UI Framework

A clean, modular, translucent UI suite for Roblox Lua/Luau.

## Quick Start (Executor Loader)

Load the full suite directly from GitHub with one line:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/FIHHHH2/New_project/main/Loader.luau"))()
```

## Directory Structure

```
├── Loader.luau               # Universal HTTP loader & virtual require resolver
├── Modules/
│   └── README.md             # Game modules and specialized logic
├── UI/
│   ├── Animations.luau       # Transitions, tweens, hover, and toggle feedback
│   └── UI.luau               # Theme config, layout builders, window frames, and resize handles
├── Core/
│   ├── CoreUI.luau           # Orchestrates window lifecycle, tabs, sections, and controls
│   ├── FeatureManager.luau   # Keybind listener, feature registry, and state dispatcher
│   └── Main.luau             # Runtime entry point initializing UI and game bindings
└── README.md
```

## Features

- **Translucent Aesthetic**: Layered glass background with customizable border accents and profile cards.
- **Inline Keybinder**: Configurable keybind picker directly alongside each toggle.
- **Dynamic Resizing**: Corner grip with real-time `UIScale` calculations.
- **Full Separation**: Decoupled animations, rendering primitives, feature state, and runtime logic.
