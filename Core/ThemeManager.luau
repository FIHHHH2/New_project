--!strict
--[=[
    ✦ Theme Management Engine ✦
    Provides:
    - Centralized theme definitions (Dark, Light, TranslucentDark, TranslucentLight, Adaptive)
    - 0.2s Quad color interpolation across all registered UI elements
    - Dead-instance pruning during theme transitions
    - Disk persistence to FihSuite/Theme.json
]=]

local UI = require("UI/UI.luau")

local ThemeManager = {}
ThemeManager.__index = ThemeManager

ThemeManager.Themes = UI.Themes
ThemeManager.CurrentTheme = UI.CurrentTheme

function ThemeManager.setTheme(themeName: string)
	UI.setTheme(themeName)
	ThemeManager.CurrentTheme = UI.CurrentTheme
end

function ThemeManager.getSavedTheme(): string?
	return UI.getSavedTheme()
end

function ThemeManager.saveTheme(themeName: string)
	UI.saveTheme(themeName)
end

function ThemeManager.applyAdaptiveTheme(accentCol: Color3, bgCol: Color3, containerCol: Color3, borderCol: Color3?)
	UI.applyAdaptiveTheme(accentCol, bgCol, containerCol, borderCol)
end

function ThemeManager.registerElement(inst: Instance, propType: string)
	UI.registerThemeElement(inst, propType)
end

return ThemeManager
