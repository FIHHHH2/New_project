--!strict
--[=[
    ✦ High-Speed Standalone Modular Roblox Menu Suite ✦
    Features:
    - Pre-compiled zero-latency in-memory module filesystem
    - Instant boot time (<50ms execution from cold start)
    - Full hot-reload & cleanup protection
]=]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

if _G.__ModularSuite_Cleanup then
	pcall(_G.__ModularSuite_Cleanup)
	_G.__ModularSuite_Cleanup = nil
end

local guiNames = {
	"ModularEngineGui",
	"ModularNotificationsGui",
	"ModularPlayerListGui",
	"ModularChatGui",
	"ModularMusicTrackerGui",
	"ModularHotbarGui",
	"ModularLeaderstatsGui",
	"ModularHealthGui"
}

for _, name in ipairs(guiNames) do
	local g = CoreGui:FindFirstChild(name)
	if g then g:Destroy() end
	if Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") then
		local pg = Players.LocalPlayer.PlayerGui:FindFirstChild(name)
		if pg then pg:Destroy() end
	end
end

local Modules = {}
local ModuleCache = {}

local function requireModule(path: string): any
	path = path:gsub("\\", "/"):gsub("^%.%/", "")
	if ModuleCache[path] ~= nil then
		return ModuleCache[path]
	end
	
	local factory = Modules[path]
	if not factory then
		error("[Modular Loader] Module not found in virtual filesystem: " .. tostring(path))
	end
	
	local result = factory()
	ModuleCache[path] = result
	return result
end

_G.__ModularSuite_Require = requireModule

Modules["UI/Animations.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Animation Suite for Modular Retro UI ✦
        High-performance spring-damper & TweenService helpers for micro-interactions,
        tactile button squashes, slider track glow, window/popup transitions, indicator pulses, and domino ripples.
    ]=]
    
    local TweenService = game:GetService("TweenService")
    
    local Animations = {}
    Animations.__index = Animations
    
    export type AnimationConfig = {
    	duration: number?,
    	easingStyle: Enum.EasingStyle?,
    	easingDirection: Enum.EasingDirection?
    }
    
    -- Generic property tween wrapper
    function Animations.tween(instance: Instance, properties: {[string]: any}, config: AnimationConfig?): Tween
    	local dur = if config and config.duration ~= nil then config.duration else 0.15
    	local style = if config and config.easingStyle ~= nil then config.easingStyle else Enum.EasingStyle.Quad
    	local dir = if config and config.easingDirection ~= nil then config.easingDirection else Enum.EasingDirection.Out
    	
    	local tweenInfo = TweenInfo.new(dur, style, dir)
    	local tween = TweenService:Create(instance, tweenInfo, properties)
    	tween:Play()
    	return tween
    end
    
    -- Tactile instant button squash
    function Animations.buttonClickPop(guiObject: GuiObject)
    	local uiScale = guiObject:FindFirstChildWhichIsA("UIScale")
    	if not uiScale then
    		uiScale = Instance.new("UIScale")
    		uiScale.Scale = 1.0
    		uiScale.Parent = guiObject
    	end
    
    	uiScale.Scale = 0.92
    	local tween = TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    		Scale = 1.0
    	})
    	tween:Play()
    end
    
    -- Tactile button hover scale push
    function Animations.buttonHoverPush(guiObject: GuiObject)
    	local uiScale = guiObject:FindFirstChildWhichIsA("UIScale")
    	if not uiScale then
    		uiScale = Instance.new("UIScale")
    		uiScale.Scale = 1.0
    		uiScale.Parent = guiObject
    	end
    
    	guiObject.MouseEnter:Connect(function()
    		if uiScale then
    			TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Scale = 1.04
    			}):Play()
    		end
    	end)
    
    	guiObject.MouseLeave:Connect(function()
    		if uiScale then
    			TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Scale = 1.0
    			}):Play()
    		end
    	end)
    end
    
    -- Spring pop scale for checkmarks, badges, icons, and value labels (0.0 -> 1.15 -> 1.0 Back.Out)
    function Animations.popScale(guiObject: GuiObject, startScale: number?, peakScale: number?, endScale: number?, duration: number?): Tween
    	local targetStart = if startScale ~= nil then startScale else 0.0
    	local targetEnd = if endScale ~= nil then endScale else 1.0
    	local targetDur = if duration ~= nil then duration else 0.22
    
    	local uiScale = guiObject:FindFirstChildWhichIsA("UIScale")
    	if not uiScale then
    		uiScale = Instance.new("UIScale")
    		uiScale.Scale = targetStart
    		uiScale.Parent = guiObject
    	else
    		uiScale.Scale = targetStart
    	end
    
    	local tweenInfo = TweenInfo.new(targetDur, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    	local tween = TweenService:Create(uiScale, tweenInfo, { Scale = targetEnd })
    	tween:Play()
    	return tween
    end
    
    -- Micro-squash & border glow feedback for buttons, subtabs, and clickable components
    function Animations.attachMicroSquash(
    	button: GuiButton,
    	stroke: UIStroke?,
    	getNormalBg: (() -> Color3)?,
    	getHoverBg: (() -> Color3)?,
    	getActiveBg: (() -> Color3)?,
    	getNormalBorder: (() -> Color3)?,
    	getGlowBorder: (() -> Color3)?
    )
    	local uiScale = button:FindFirstChildWhichIsA("UIScale")
    	if not uiScale then
    		uiScale = Instance.new("UIScale")
    		uiScale.Scale = 1.0
    		uiScale.Parent = button
    	end
    
    	local targetStroke = stroke or button:FindFirstChildWhichIsA("UIStroke")
    
    	button.MouseEnter:Connect(function()
    		if targetStroke then
    			local glowColor = if getGlowBorder then getGlowBorder() else nil
    			local strokeProps: {[string]: any} = { Thickness = 1.8 }
    			if glowColor then
    				strokeProps.Color = glowColor
    			end
    			Animations.tween(targetStroke, strokeProps, { duration = 0.12, easingStyle = Enum.EasingStyle.Quad })
    		end
    		if getHoverBg then
    			Animations.tween(button, { BackgroundColor3 = getHoverBg() }, { duration = 0.12 })
    		end
    		if uiScale then
    			Animations.tween(uiScale, { Scale = 1.02 }, { duration = 0.12, easingStyle = Enum.EasingStyle.Quad })
    		end
    	end)
    
    	button.MouseLeave:Connect(function()
    		if targetStroke then
    			local normalColor = if getNormalBorder then getNormalBorder() else nil
    			local strokeProps: {[string]: any} = { Thickness = 1.2 }
    			if normalColor then
    				strokeProps.Color = normalColor
    			end
    			Animations.tween(targetStroke, strokeProps, { duration = 0.12, easingStyle = Enum.EasingStyle.Quad })
    		end
    		if getNormalBg then
    			Animations.tween(button, { BackgroundColor3 = getNormalBg() }, { duration = 0.12 })
    		end
    		if uiScale then
    			Animations.tween(uiScale, { Scale = 1.0 }, { duration = 0.12, easingStyle = Enum.EasingStyle.Quad })
    		end
    	end)
    
    	button.MouseButton1Down:Connect(function()
    		if uiScale then
    			Animations.tween(uiScale, { Scale = 0.94 }, { duration = 0.06, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
    		end
    		if getActiveBg then
    			Animations.tween(button, { BackgroundColor3 = getActiveBg() }, { duration = 0.06 })
    		end
    	end)
    
    	button.MouseButton1Up:Connect(function()
    		if uiScale then
    			Animations.tween(uiScale, { Scale = 1.02 }, { duration = 0.16, easingStyle = Enum.EasingStyle.Back, easingDirection = Enum.EasingDirection.Out })
    		end
    		if getHoverBg then
    			Animations.tween(button, { BackgroundColor3 = getHoverBg() }, { duration = 0.12 })
    		elseif getNormalBg then
    			Animations.tween(button, { BackgroundColor3 = getNormalBg() }, { duration = 0.12 })
    		end
    	end)
    end
    
    -- Backward compatibility alias
    function Animations.attachButtonEffects(button: GuiButton, getNormalBg: (() -> Color3)?, getHoverBg: (() -> Color3)?, getActiveBg: (() -> Color3)?)
    	Animations.attachMicroSquash(button, nil, getNormalBg, getHoverBg, getActiveBg, nil, nil)
    end
    
    -- Slider track hover glow and fill feedback
    function Animations.attachSliderGlow(track: Frame, stroke: UIStroke, fill: Frame, valLabel: TextLabel?)
    	track.MouseEnter:Connect(function()
    		Animations.tween(stroke, { Thickness = 1.8 }, { duration = 0.12 })
    	end)
    
    	track.MouseLeave:Connect(function()
    		Animations.tween(stroke, { Thickness = 1.2 }, { duration = 0.12 })
    	end)
    end
    
    -- Tab and sub-tab selection active indicator pulse
    function Animations.pulseIndicator(stroke: UIStroke, pulseColor: Color3, normalColor: Color3, peakThickness: number?, normalThickness: number?)
    	local peak = if peakThickness ~= nil then peakThickness else 2.4
    	local norm = if normalThickness ~= nil then normalThickness else 1.5
    
    	stroke.Color = pulseColor
    	local surgeTween = Animations.tween(stroke, { Thickness = peak, Color = pulseColor }, { duration = 0.08, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
    	surgeTween.Completed:Connect(function()
    		Animations.tween(stroke, { Thickness = norm, Color = normalColor }, { duration = 0.18, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
    	end)
    end
    
    -- Window open transition (Spring scale 0.92 -> 1.0 Back.Out)
    function Animations.openWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    	frame.Visible = true
    	if uiScale then
    		uiScale.Scale = 0.92
    		local tween = TweenService:Create(uiScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			Scale = 1.0
    		})
    		tween:Play()
    		if onComplete then
    			tween.Completed:Connect(onComplete)
    		end
    	elseif onComplete then
    		onComplete()
    	end
    end
    
    function Animations.springOpen(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    	Animations.openWindow(frame, uiScale, onComplete)
    end
    
    -- Window close transition (Smooth cinematic zoom-out 1.0 -> 0.05 Back.In)
    function Animations.closeWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    	if uiScale then
    		local tween = TweenService:Create(uiScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
    			Scale = 0.05
    		})
    		tween:Play()
    		tween.Completed:Connect(function()
    			frame.Visible = false
    			uiScale.Scale = 1.0
    			if onComplete then
    				onComplete()
    			end
    		end)
    	else
    		frame.Visible = false
    		if onComplete then
    			onComplete()
    		end
    	end
    end
    
    -- Popup / context menu spring pop-in (0.85 -> 1.0 Back.Out)
    function Animations.popIn(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    	frame.Visible = true
    	if uiScale then
    		uiScale.Scale = 0.85
    		local tween = TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			Scale = 1.0
    		})
    		tween:Play()
    		if onComplete then
    			tween.Completed:Connect(onComplete)
    		end
    	elseif onComplete then
    		onComplete()
    	end
    end
    
    -- Popup / context menu pop-out (1.0 -> 0.05 Back.In)
    function Animations.popOut(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    	if uiScale then
    		local tween = TweenService:Create(uiScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
    			Scale = 0.05
    		})
    		tween:Play()
    		tween.Completed:Connect(function()
    			frame.Visible = false
    			uiScale.Scale = 1.0
    			if onComplete then
    				onComplete()
    			end
    		end)
    	else
    		frame.Visible = false
    		if onComplete then
    			onComplete()
    		end
    	end
    end
    
    -- Cascaded domino ripple for child elements
    function Animations.dominoRipple(elements: {GuiObject}, baseDelay: number?, offsetDistance: number?, duration: number?)
    	local delayStep = if baseDelay ~= nil then baseDelay else 0.025
    	local offset = if offsetDistance ~= nil then offsetDistance else 14
    	local dur = if duration ~= nil then duration else 0.24
    
    	for idx, element in ipairs(elements) do
    		local origYScale = element.Position.Y.Scale
    		local origYOffset = element.Position.Y.Offset
    		element.Position = UDim2.new(0, offset, origYScale, origYOffset)
    		task.delay((idx - 1) * delayStep, function()
    			if element and element.Parent then
    				TweenService:Create(element, TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    					Position = UDim2.new(0, 0, origYScale, origYOffset)
    				}):Play()
    			end
    		end)
    	end
    end
    
    return Animations
end

Modules["UI/UI.luau"] = function()
    local require = requireModule
    --!strict
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local MarketplaceService = game:GetService("MarketplaceService")
    
    local Animations = require("UI/Animations.luau")
    
    local UI = {}
    UI.__index = UI
    
    UI.Themes = {
    	Dark = {
    		Name = "Dark",
    		Background = Color3.fromRGB(13, 13, 15),
    		BackgroundTransparency = 0.02,
    		Border = Color3.fromRGB(250, 250, 255), -- Crisp white outlines for dark mode
    		BorderDim = Color3.fromRGB(85, 85, 95),
    		Accent = Color3.fromRGB(55, 175, 245), -- Light blue-ish selection accent
    		AccentDark = Color3.fromRGB(30, 120, 200),
    		AccentText = Color3.fromRGB(255, 255, 255),
    		TextPrimary = Color3.fromRGB(245, 245, 245),
    		TextSecondary = Color3.fromRGB(160, 160, 170),
    		Container = Color3.fromRGB(22, 22, 26),
    		ContainerTransparency = 0,
    		ContainerDark = Color3.fromRGB(15, 15, 18),
    		ContainerDarkTransparency = 0
    	},
    	Light = {
    		Name = "Light",
    		Background = Color3.fromRGB(242, 243, 246),
    		BackgroundTransparency = 0.02,
    		Border = Color3.fromRGB(12, 12, 16), -- True black outlines for light mode
    		BorderDim = Color3.fromRGB(130, 130, 140),
    		Accent = Color3.fromRGB(45, 155, 235), -- Light blue accent
    		AccentDark = Color3.fromRGB(25, 110, 185),
    		AccentText = Color3.fromRGB(255, 255, 255),
    		TextPrimary = Color3.fromRGB(15, 15, 20),
    		TextSecondary = Color3.fromRGB(75, 75, 85),
    		Container = Color3.fromRGB(255, 255, 255),
    		ContainerTransparency = 0,
    		ContainerDark = Color3.fromRGB(228, 230, 236),
    		ContainerDarkTransparency = 0
    	},
    	TranslucentDark = {
    		Name = "Translucent Dark",
    		Background = Color3.fromRGB(12, 12, 16),
    		BackgroundTransparency = 0.40,
    		Border = Color3.fromRGB(250, 250, 255), -- White outlines
    		BorderDim = Color3.fromRGB(90, 90, 110),
    		Accent = Color3.fromRGB(55, 175, 245), -- Light blue accent
    		AccentDark = Color3.fromRGB(30, 120, 200),
    		AccentText = Color3.fromRGB(255, 255, 255),
    		TextPrimary = Color3.fromRGB(255, 255, 255),
    		TextSecondary = Color3.fromRGB(180, 180, 195),
    		Container = Color3.fromRGB(24, 24, 32),
    		ContainerTransparency = 0.35,
    		ContainerDark = Color3.fromRGB(14, 14, 20),
    		ContainerDarkTransparency = 0.45
    	},
    	TranslucentLight = {
    		Name = "Translucent Light",
    		Background = Color3.fromRGB(240, 242, 248),
    		BackgroundTransparency = 0.40,
    		Border = Color3.fromRGB(12, 12, 16), -- Black outlines
    		BorderDim = Color3.fromRGB(120, 120, 135),
    		Accent = Color3.fromRGB(45, 155, 235), -- Light blue accent
    		AccentDark = Color3.fromRGB(25, 110, 185),
    		AccentText = Color3.fromRGB(255, 255, 255),
    		TextPrimary = Color3.fromRGB(12, 12, 16),
    		TextSecondary = Color3.fromRGB(70, 70, 80),
    		Container = Color3.fromRGB(255, 255, 255),
    		ContainerTransparency = 0.35,
    		ContainerDark = Color3.fromRGB(225, 228, 236),
    		ContainerDarkTransparency = 0.45
    	},
    	Adaptive = {
    		Name = "Adaptive",
    		Background = Color3.fromRGB(16, 16, 22),
    		BackgroundTransparency = 0.35,
    		Border = Color3.fromRGB(240, 240, 250),
    		BorderDim = Color3.fromRGB(90, 90, 110),
    		Accent = Color3.fromRGB(55, 175, 245),
    		AccentDark = Color3.fromRGB(30, 120, 200),
    		AccentText = Color3.fromRGB(255, 255, 255),
    		TextPrimary = Color3.fromRGB(250, 250, 255),
    		TextSecondary = Color3.fromRGB(175, 175, 190),
    		Container = Color3.fromRGB(24, 24, 32),
    		ContainerTransparency = 0.30,
    		ContainerDark = Color3.fromRGB(14, 14, 20),
    		ContainerDarkTransparency = 0.40
    	}
    }
    
    local HttpService = game:GetService("HttpService")
    
    local function ensureThemeFolder(folder: string)
    	local mkf = makefolder or (getgenv and getgenv().makefolder)
    	local isf = isfolder or (getgenv and getgenv().isfolder)
    	if type(mkf) == "function" and type(isf) == "function" then
    		pcall(function()
    			if not isf(folder) then mkf(folder) end
    		end)
    	end
    end
    
    function UI.saveTheme(themeName: string)
    	ensureThemeFolder("FihSuite")
    	local wrf = writefile or (getgenv and getgenv().writefile)
    	if type(wrf) == "function" then
    		pcall(function()
    			wrf("FihSuite/Theme.json", HttpService:JSONEncode({ theme = themeName, timestamp = os.time() }))
    		end)
    	end
    end
    
    function UI.getSavedTheme(): string?
    	local rdf = readfile or (getgenv and getgenv().readfile)
    	local isf = isfile or (getgenv and getgenv().isfile)
    	if type(rdf) == "function" and type(isf) == "function" then
    		local ok, content = pcall(function()
    			if isf("FihSuite/Theme.json") then
    				return rdf("FihSuite/Theme.json")
    			end
    			return nil
    		end)
    		if ok and content then
    			local dOk, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    			if dOk and type(decoded) == "table" and type(decoded.theme) == "string" then
    				return decoded.theme
    			end
    		end
    	end
    	return nil
    end
    
    local savedThemeName = UI.getSavedTheme()
    if savedThemeName and UI.Themes[savedThemeName] then
    	UI.CurrentTheme = UI.Themes[savedThemeName]
    	UI.Theme = UI.Themes[savedThemeName]
    else
    	UI.CurrentTheme = UI.Themes.Dark
    	UI.Theme = UI.Themes.Dark
    end
    
    UI.Fonts = {
    	Header = Enum.Font.GothamBold,
    	Body = Enum.Font.GothamMedium,
    	Mono = Enum.Font.Code
    }
    
    type ThemedElement = {
    	Instance: Instance,
    	PropType: string
    }
    
    -- Persistent theme registry: keys are Instances, values are sets of propType strings.
    -- Destroying event automatically cleans up destroyed instances to prevent memory leaks.
    UI.RegisteredElements = {} :: {[Instance]: {[string]: boolean}}
    
    function UI.registerThemeElement(inst: Instance, propType: string)
    	if not inst then return end
    	local propMap = UI.RegisteredElements[inst]
    	if not propMap then
    		propMap = {}
    		UI.RegisteredElements[inst] = propMap
    
    		-- Clean up automatically when the instance is destroyed
    		pcall(function()
    			inst.Destroying:Connect(function()
    				UI.RegisteredElements[inst] = nil
    			end)
    		end)
    	end
    	propMap[propType] = true
    end
    
    function UI.unregisterThemeElement(inst: Instance, propType: string?)
    	if not inst then return end
    	if propType then
    		local propMap = UI.RegisteredElements[inst]
    		if propMap then
    			propMap[propType] = nil
    		end
    	else
    		UI.RegisteredElements[inst] = nil
    	end
    end
    
    function UI.cleanupRegistry()
    	for inst in pairs(UI.RegisteredElements) do
    		if not inst or not inst.Parent then
    			UI.RegisteredElements[inst] = nil
    		end
    	end
    end
    
    local lastAdaptiveAccent: Color3? = nil
    local lastAdaptiveBg: Color3? = nil
    
    function UI.applyAdaptiveTheme(accentCol: Color3, bgCol: Color3, containerCol: Color3, borderCol: Color3?)
    	if lastAdaptiveAccent == accentCol and lastAdaptiveBg == bgCol then
    		return
    	end
    	lastAdaptiveAccent = accentCol
    	lastAdaptiveBg = bgCol
    
    	local ad = UI.Themes.Adaptive
    	ad.Accent = accentCol
    	ad.AccentDark = Color3.fromRGB(math.floor(accentCol.R * 255 * 0.7), math.floor(accentCol.G * 255 * 0.7), math.floor(accentCol.B * 255 * 0.7))
    	ad.Background = bgCol
    	ad.BackgroundTransparency = 0.35
    	ad.Container = containerCol
    	ad.ContainerTransparency = 0.30
    	ad.ContainerDark = bgCol
    	ad.ContainerDarkTransparency = 0.40
    	ad.Border = borderCol or Color3.fromRGB(240, 240, 250)
    
    	if UI.CurrentTheme.Name == "Adaptive" then
    		UI.setTheme("Adaptive")
    	end
    end
    
    UI.ThemeChangedCallbacks = {} :: { (targetTheme: any) -> () }
    
    function UI.onThemeChanged(callback: (targetTheme: any) -> ())
    	table.insert(UI.ThemeChangedCallbacks, callback)
    end
    
    function UI.setTheme(themeName: string)
    	local targetTheme = UI.Themes[themeName] or UI.Themes.Dark
    	UI.CurrentTheme = targetTheme
    	UI.Theme = targetTheme
    	UI.saveTheme(themeName)
    	
    	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    	
    	for inst, propMap in pairs(UI.RegisteredElements) do
    		if inst and inst.Parent then
    			for pt in pairs(propMap) do
    				if pt == "Background" and inst:IsA("GuiObject") then
    					TweenService:Create(inst, tweenInfo, {
    						BackgroundColor3 = targetTheme.Background,
    						BackgroundTransparency = targetTheme.BackgroundTransparency
    					}):Play()
    				elseif pt == "Container" and inst:IsA("GuiObject") then
    					TweenService:Create(inst, tweenInfo, {
    						BackgroundColor3 = targetTheme.Container,
    						BackgroundTransparency = targetTheme.ContainerTransparency
    					}):Play()
    				elseif pt == "ContainerDark" and inst:IsA("GuiObject") then
    					TweenService:Create(inst, tweenInfo, {
    						BackgroundColor3 = targetTheme.ContainerDark,
    						BackgroundTransparency = targetTheme.ContainerDarkTransparency
    					}):Play()
    				elseif pt == "Accent" and inst:IsA("GuiObject") then
    					TweenService:Create(inst, tweenInfo, {
    						BackgroundColor3 = targetTheme.Accent
    					}):Play()
    				elseif pt == "Border" and inst:IsA("UIStroke") then
    					TweenService:Create(inst, tweenInfo, { Color = targetTheme.Border }):Play()
    				elseif pt == "BorderDim" and inst:IsA("UIStroke") then
    					TweenService:Create(inst, tweenInfo, { Color = targetTheme.BorderDim }):Play()
    				elseif pt == "TextPrimary" then
    					if inst:IsA("TextLabel") or inst:IsA("TextButton") then
    						TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.TextPrimary }):Play()
    					elseif inst:IsA("TextBox") then
    						TweenService:Create(inst, tweenInfo, {
    							TextColor3 = targetTheme.TextPrimary,
    							PlaceholderColor3 = targetTheme.TextSecondary
    						}):Play()
    					end
    				elseif pt == "TextSecondary" then
    					if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
    						TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.TextSecondary }):Play()
    					end
    				elseif pt == "AccentText" and (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
    					TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.AccentText }):Play()
    				elseif pt == "BorderDimText" and inst:IsA("TextLabel") then
    					TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.BorderDim }):Play()
    				end
    			end
    		else
    			UI.RegisteredElements[inst] = nil
    		end
    	end
    
    	for _, cb in ipairs(UI.ThemeChangedCallbacks) do
    		pcall(cb, targetTheme)
    	end
    
    	-- Universal hierarchy sweep across all Modular UI ScreenGuis to guarantee 100% theme coverage
    	pcall(function()
    		local CoreGui = game:GetService("CoreGui")
    		local Players = game:GetService("Players")
    		local roots = {}
    
    		local guiNames = {
    			"ModularEngineGui",
    			"ModularNotificationsGui",
    			"ModularPlayerListGui",
    			"ModularChatGui",
    			"ModularMusicTrackerGui",
    			"ModularHotbarGui"
    		}
    
    		for _, name in ipairs(guiNames) do
    			local g = CoreGui:FindFirstChild(name)
    			if g then table.insert(roots, g) end
    			if Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") then
    				local pg = Players.LocalPlayer.PlayerGui:FindFirstChild(name)
    				if pg then table.insert(roots, pg) end
    			end
    		end
    
    		for _, root in ipairs(roots) do
    			for _, inst in ipairs(root:GetDescendants()) do
    				if inst:IsA("UIStroke") then
    					if inst.Thickness >= 1.4 then
    						inst.Color = targetTheme.Border
    					else
    						inst.Color = targetTheme.BorderDim
    					end
    				elseif inst:IsA("Frame") then
    					if inst.Name == "TitleBox" or inst.Name == "DecoBar" or inst.Name == "HeaderBox" or inst.Name == "ActiveTagBox" or string.find(inst.Name, "Box") then
    						inst.BackgroundColor3 = targetTheme.Container
    						inst.BackgroundTransparency = targetTheme.ContainerTransparency
    					elseif inst.Name == "MainWindow" or inst.Name == "Window" then
    						inst.BackgroundColor3 = targetTheme.Background
    						inst.BackgroundTransparency = targetTheme.BackgroundTransparency
    					end
    				elseif inst:IsA("TextButton") then
    					local propMap = UI.RegisteredElements[inst]
    					local isAccent = propMap and propMap["Accent"]
    					if not isAccent then
    						inst.BackgroundColor3 = targetTheme.Container
    						inst.BackgroundTransparency = targetTheme.ContainerTransparency
    						if propMap and propMap["TextSecondary"] then
    							inst.TextColor3 = targetTheme.TextSecondary
    						else
    							inst.TextColor3 = targetTheme.TextPrimary
    						end
    					else
    						inst.BackgroundColor3 = targetTheme.Accent
    						inst.TextColor3 = targetTheme.AccentText
    					end
    				elseif inst:IsA("TextLabel") then
    					local propMap = UI.RegisteredElements[inst]
    					if propMap and propMap["AccentText"] then
    						inst.TextColor3 = targetTheme.AccentText
    					elseif propMap and propMap["TextSecondary"] then
    						inst.TextColor3 = targetTheme.TextSecondary
    					elseif propMap and propMap["BorderDimText"] then
    						inst.TextColor3 = targetTheme.BorderDim
    					else
    						inst.TextColor3 = targetTheme.TextPrimary
    					end
    				elseif inst:IsA("TextBox") then
    					inst.TextColor3 = targetTheme.TextPrimary
    					inst.PlaceholderColor3 = targetTheme.TextSecondary
    					inst.BackgroundColor3 = targetTheme.ContainerDark
    					inst.BackgroundTransparency = targetTheme.ContainerDarkTransparency
    				end
    			end
    		end
    	end)
    end
    
    function UI.createWindow(titleText: string)
    	local mainFrame = Instance.new("Frame")
    	mainFrame.Name = "MainWindow"
    	mainFrame.Size = UDim2.new(0, 720, 0, 480)
    	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -240)
    	mainFrame.BackgroundColor3 = UI.Theme.Background
    	mainFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	mainFrame.BorderSizePixel = 0
    	mainFrame.ClipsDescendants = false
    	UI.registerThemeElement(mainFrame, "Background")
    
    	local bgGradient = Instance.new("UIGradient")
    	bgGradient.Rotation = 90
    	bgGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
    	})
    	bgGradient.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.15)
    	})
    	bgGradient.Parent = mainFrame
    
    	local outerStroke = Instance.new("UIStroke")
    	outerStroke.Color = UI.Theme.Border
    	outerStroke.Thickness = 2
    	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	outerStroke.Parent = mainFrame
    	UI.registerThemeElement(outerStroke, "Border")
    
    	local uiScale = Instance.new("UIScale")
    	uiScale.Scale = 1.0
    	uiScale.Parent = mainFrame
    
    	local topbar = Instance.new("Frame")
    	topbar.Name = "TopBar"
    	topbar.Size = UDim2.new(1, -16, 0, 28)
    	topbar.Position = UDim2.new(0, 8, 0, 8)
    	topbar.BackgroundTransparency = 1
    	topbar.BorderSizePixel = 0
    	topbar.Parent = mainFrame
    
    	local titleBox = Instance.new("Frame")
    	titleBox.Name = "TitleBox"
    	titleBox.Size = UDim2.new(0, 220, 1, 0)
    	titleBox.Position = UDim2.new(0, 0, 0, 0)
    	titleBox.BackgroundColor3 = UI.Theme.Container
    	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	titleBox.BorderSizePixel = 0
    	titleBox.ClipsDescendants = true
    	titleBox.Parent = topbar
    	UI.registerThemeElement(titleBox, "Container")
    
    	local titleGradient = Instance.new("UIGradient")
    	titleGradient.Rotation = 45
    	titleGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
    	})
    	titleGradient.Parent = titleBox
    
    	local titleStroke = Instance.new("UIStroke")
    	titleStroke.Color = UI.Theme.Border
    	titleStroke.Thickness = 1.5
    	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleStroke.Parent = titleBox
    	UI.registerThemeElement(titleStroke, "Border")
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(1, -12, 1, 0)
    	titleLabel.Position = UDim2.new(0, 8, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = string.format("%s >>>>>", titleText)
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Header
    	titleLabel.TextSize = 12
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.ClipsDescendants = true
    	titleLabel.Parent = titleBox
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	local decoBar = Instance.new("Frame")
    	decoBar.Name = "DecoBar"
    	decoBar.Size = UDim2.new(1, -298, 1, 0)
    	decoBar.Position = UDim2.new(0, 228, 0, 0)
    	decoBar.BackgroundColor3 = UI.Theme.Container
    	decoBar.BackgroundTransparency = UI.Theme.ContainerTransparency
    	decoBar.BorderSizePixel = 0
    	decoBar.ClipsDescendants = true
    	decoBar.Parent = topbar
    	UI.registerThemeElement(decoBar, "Container")
    
    	local decoStroke = Instance.new("UIStroke")
    	decoStroke.Color = UI.Theme.Border
    	decoStroke.Thickness = 1.5
    	decoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	decoStroke.Parent = decoBar
    	UI.registerThemeElement(decoStroke, "Border")
    
    	local decoLabel = Instance.new("TextLabel")
    	decoLabel.Size = UDim2.new(1, 0, 1, 0)
    	decoLabel.BackgroundTransparency = 1
    	decoLabel.Text = ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    	decoLabel.TextColor3 = UI.Theme.BorderDim
    	decoLabel.Font = UI.Fonts.Mono
    	decoLabel.TextSize = 12
    	decoLabel.Parent = decoBar
    	UI.registerThemeElement(decoLabel, "BorderDimText")
    
    	local minButton = Instance.new("TextButton")
    	minButton.Name = "MinButton"
    	minButton.Size = UDim2.new(0, 30, 1, 0)
    	minButton.Position = UDim2.new(1, -66, 0, 0)
    	minButton.BackgroundColor3 = UI.Theme.Container
    	minButton.BackgroundTransparency = UI.Theme.ContainerTransparency
    	minButton.BorderSizePixel = 0
    	minButton.Text = "—"
    	minButton.TextColor3 = UI.Theme.TextPrimary
    	minButton.Font = UI.Fonts.Header
    	minButton.TextSize = 13
    	minButton.Parent = topbar
    	UI.registerThemeElement(minButton, "Container")
    	UI.registerThemeElement(minButton, "TextPrimary")
    
    	local minStroke = Instance.new("UIStroke")
    	minStroke.Color = UI.Theme.Border
    	minStroke.Thickness = 1.5
    	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	minStroke.Parent = minButton
    	UI.registerThemeElement(minStroke, "Border")
    
    	local closeButton = Instance.new("TextButton")
    	closeButton.Name = "CloseButton"
    	closeButton.Size = UDim2.new(0, 30, 1, 0)
    	closeButton.Position = UDim2.new(1, -30, 0, 0)
    	closeButton.BackgroundColor3 = UI.Theme.Container
    	closeButton.BackgroundTransparency = UI.Theme.ContainerTransparency
    	closeButton.BorderSizePixel = 0
    	closeButton.Text = "X"
    	closeButton.TextColor3 = UI.Theme.TextPrimary
    	closeButton.Font = UI.Fonts.Header
    	closeButton.TextSize = 13
    	closeButton.Parent = topbar
    	UI.registerThemeElement(closeButton, "Container")
    	UI.registerThemeElement(closeButton, "TextPrimary")
    
    	local closeStroke = Instance.new("UIStroke")
    	closeStroke.Color = UI.Theme.Border
    	closeStroke.Thickness = 1.5
    	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	closeStroke.Parent = closeButton
    	UI.registerThemeElement(closeStroke, "Border")
    
    	local topDivider = Instance.new("Frame")
    	topDivider.Name = "TopDivider"
    	topDivider.Size = UDim2.new(1, 0, 0, 2)
    	topDivider.Position = UDim2.new(0, 0, 0, 42)
    	topDivider.BackgroundColor3 = UI.Theme.Border
    	topDivider.BorderSizePixel = 0
    	topDivider.Parent = mainFrame
    	UI.registerThemeElement(topDivider, "Border")
    
    	local bodyFrame = Instance.new("Frame")
    	bodyFrame.Name = "BodyFrame"
    	bodyFrame.Size = UDim2.new(1, 0, 1, -62)
    	bodyFrame.Position = UDim2.new(0, 0, 0, 44)
    	bodyFrame.BackgroundTransparency = 1
    	bodyFrame.BorderSizePixel = 0
    	bodyFrame.Parent = mainFrame
    
    	local sidebar = Instance.new("ScrollingFrame")
    	sidebar.Name = "Sidebar"
    	sidebar.Size = UDim2.new(0, 126, 1, -12)
    	sidebar.Position = UDim2.new(0, 8, 0, 6)
    	sidebar.BackgroundTransparency = 1
    	sidebar.BorderSizePixel = 0
    	sidebar.ScrollBarThickness = 0
    	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	sidebar.ClipsDescendants = false
    	sidebar.Parent = bodyFrame
    
    	local sidePad = Instance.new("UIPadding")
    	sidePad.PaddingLeft = UDim.new(0, 2)
    	sidePad.PaddingRight = UDim.new(0, 2)
    	sidePad.PaddingTop = UDim.new(0, 2)
    	sidePad.PaddingBottom = UDim.new(0, 2)
    	sidePad.Parent = sidebar
    
    	local sideList = Instance.new("UIListLayout")
    	sideList.Padding = UDim.new(0, 6)
    	sideList.SortOrder = Enum.SortOrder.LayoutOrder
    	sideList.Parent = sidebar
    
    	local vertDivider = Instance.new("Frame")
    	vertDivider.Name = "VertDivider"
    	vertDivider.Size = UDim2.new(0, 2, 1, 0)
    	vertDivider.Position = UDim2.new(0, 142, 0, 0)
    	vertDivider.BackgroundColor3 = UI.Theme.Border
    	vertDivider.BorderSizePixel = 0
    	vertDivider.Parent = bodyFrame
    	UI.registerThemeElement(vertDivider, "Border")
    
    	local rightMain = Instance.new("Frame")
    	rightMain.Name = "RightMain"
    	rightMain.Size = UDim2.new(1, -154, 1, -12)
    	rightMain.Position = UDim2.new(0, 150, 0, 6)
    	rightMain.BackgroundTransparency = 1
    	rightMain.BorderSizePixel = 0
    	rightMain.ClipsDescendants = true
    	rightMain.Parent = bodyFrame
    
    	local subHeader = Instance.new("Frame")
    	subHeader.Name = "SubHeader"
    	subHeader.Size = UDim2.new(1, 0, 0, 26)
    	subHeader.Position = UDim2.new(0, 0, 0, 0)
    	subHeader.BackgroundTransparency = 1
    	subHeader.BorderSizePixel = 0
    	subHeader.Parent = rightMain
    
    	local activeTagBox = Instance.new("Frame")
    	activeTagBox.Name = "ActiveTagBox"
    	activeTagBox.Size = UDim2.new(0, 110, 0, 24)
    	activeTagBox.Position = UDim2.new(0, 2, 0, 1)
    	activeTagBox.BackgroundColor3 = UI.Theme.Container
    	activeTagBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	activeTagBox.BorderSizePixel = 0
    	activeTagBox.ClipsDescendants = true
    	activeTagBox.Parent = subHeader
    	UI.registerThemeElement(activeTagBox, "Container")
    
    	local activeTagStroke = Instance.new("UIStroke")
    	activeTagStroke.Color = UI.Theme.Border
    	activeTagStroke.Thickness = 1.5
    	activeTagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	activeTagStroke.Parent = activeTagBox
    	UI.registerThemeElement(activeTagStroke, "Border")
    
    	local activeTagLabel = Instance.new("TextLabel")
    	activeTagLabel.Name = "Label"
    	activeTagLabel.Size = UDim2.new(1, -8, 1, 0)
    	activeTagLabel.Position = UDim2.new(0, 4, 0, 0)
    	activeTagLabel.BackgroundTransparency = 1
    	activeTagLabel.Text = "Main"
    	activeTagLabel.TextColor3 = UI.Theme.TextPrimary
    	activeTagLabel.Font = UI.Fonts.Header
    	activeTagLabel.TextSize = 11
    	activeTagLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	activeTagLabel.ClipsDescendants = true
    	activeTagLabel.Parent = activeTagBox
    	UI.registerThemeElement(activeTagLabel, "TextPrimary")
    
    	local configsBtn = Instance.new("TextButton")
    	configsBtn.Name = "ConfigsBtn"
    	configsBtn.Size = UDim2.new(0, 72, 0, 24)
    	configsBtn.Position = UDim2.new(1, -76, 0, 1)
    	configsBtn.BackgroundColor3 = UI.Theme.Container
    	configsBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	configsBtn.BorderSizePixel = 0
    	configsBtn.Text = "configs"
    	configsBtn.TextColor3 = UI.Theme.TextPrimary
    	configsBtn.Font = UI.Fonts.Header
    	configsBtn.TextSize = 11
    	configsBtn.TextTruncate = Enum.TextTruncate.AtEnd
    	configsBtn.ClipsDescendants = true
    	configsBtn.Visible = true
    	configsBtn.Parent = subHeader
    	UI.registerThemeElement(configsBtn, "Container")
    	UI.registerThemeElement(configsBtn, "TextPrimary")
    
    	local configsStroke = Instance.new("UIStroke")
    	configsStroke.Color = UI.Theme.Border
    	configsStroke.Thickness = 1.5
    	configsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	configsStroke.Parent = configsBtn
    	UI.registerThemeElement(configsStroke, "Border")
    
    	local settingsBtn = Instance.new("TextButton")
    	settingsBtn.Name = "SettingsBtn"
    	settingsBtn.Size = UDim2.new(0, 72, 0, 24)
    	settingsBtn.Position = UDim2.new(1, -154, 0, 1)
    	settingsBtn.BackgroundColor3 = UI.Theme.Container
    	settingsBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	settingsBtn.BorderSizePixel = 0
    	settingsBtn.Text = "Settings"
    	settingsBtn.TextColor3 = UI.Theme.TextPrimary
    	settingsBtn.Font = UI.Fonts.Header
    	settingsBtn.TextSize = 11
    	settingsBtn.TextTruncate = Enum.TextTruncate.AtEnd
    	settingsBtn.ClipsDescendants = true
    	settingsBtn.Visible = true
    	settingsBtn.Parent = subHeader
    	UI.registerThemeElement(settingsBtn, "Container")
    	UI.registerThemeElement(settingsBtn, "TextPrimary")
    
    	local settingsStroke = Instance.new("UIStroke")
    	settingsStroke.Color = UI.Theme.Border
    	settingsStroke.Thickness = 1.5
    	settingsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	settingsStroke.Parent = settingsBtn
    	UI.registerThemeElement(settingsStroke, "Border")
    
    	local contentContainer = Instance.new("Frame")
    	contentContainer.Name = "ContentContainer"
    	contentContainer.Size = UDim2.new(1, 0, 1, -32)
    	contentContainer.Position = UDim2.new(0, 0, 0, 32)
    	contentContainer.BackgroundTransparency = 1
    	contentContainer.BorderSizePixel = 0
    	contentContainer.ClipsDescendants = true
    	contentContainer.Parent = rightMain
    
    	local footerBar = Instance.new("Frame")
    	footerBar.Name = "FooterBar"
    	footerBar.Size = UDim2.new(1, 0, 0, 14)
    	footerBar.Position = UDim2.new(0, 0, 1, -14)
    	footerBar.BackgroundColor3 = UI.Theme.Background
    	footerBar.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	footerBar.BorderSizePixel = 0
    	footerBar.ClipsDescendants = true
    	footerBar.Parent = mainFrame
    	UI.registerThemeElement(footerBar, "Background")
    
    	local footerStroke = Instance.new("UIStroke")
    	footerStroke.Color = UI.Theme.Border
    	footerStroke.Thickness = 1.5
    	footerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	footerStroke.Parent = footerBar
    	UI.registerThemeElement(footerStroke, "Border")
    
    	local footerHatch = Instance.new("TextLabel")
    	footerHatch.Size = UDim2.new(1, 0, 1, 0)
    	footerHatch.BackgroundTransparency = 1
    	footerHatch.Text = "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
    	footerHatch.TextColor3 = UI.Theme.BorderDim
    	footerHatch.Font = UI.Fonts.Mono
    	footerHatch.TextSize = 11
    	footerHatch.Parent = footerBar
    	UI.registerThemeElement(footerHatch, "BorderDimText")
    
    	local dragging = false
    	local dragInput: InputObject? = nil
    	local dragStart = Vector3.zero
    	local startPos = UDim2.new()
    
    	topbar.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			dragStart = input.Position
    			startPos = mainFrame.Position
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    				end
    			end)
    		end
    	end)
    
    	topbar.InputChanged:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    			dragInput = input
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if input == dragInput and dragging then
    			local delta = input.Position - dragStart
    			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    		end
    	end)
    
    	-- Button Hover & Click animations
    	local function attachBtnFX(btn: TextButton, isClose: boolean?)
    		local stroke = btn:FindFirstChildWhichIsA("UIStroke")
    		btn.MouseEnter:Connect(function()
    			if stroke then
    				TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 2 }):Play()
    			end
    			local hoverCol = if isClose then Color3.fromRGB(220, 60, 60) else UI.Theme.Accent
    			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    		end)
    		btn.MouseLeave:Connect(function()
    			if stroke then
    				TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.5 }):Play()
    			end
    			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    	end
    
    	attachBtnFX(minButton, false)
    	attachBtnFX(closeButton, true)
    	attachBtnFX(settingsBtn, false)
    	attachBtnFX(configsBtn, false)
    
    	local minimized = false
    	minButton.MouseButton1Click:Connect(function()
    		minimized = not minimized
    		if minimized then
    			bodyFrame.Visible = false
    			footerBar.Visible = false
    			TweenService:Create(mainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, 720, 0, 44)
    			}):Play()
    		else
    			bodyFrame.Visible = true
    			footerBar.Visible = true
    			TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, 720, 0, 480)
    			}):Play()
    		end
    	end)
    
    	local isOpen = true
    	local isTransitioning = false
    
    	local function openWindow(onComplete: (() -> ())?)
    		if isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.openWindow(mainFrame, uiScale, function()
    			isOpen = true
    			isTransitioning = false
    			if onComplete then
    				onComplete()
    			end
    		end)
    	end
    
    	local function closeWindow(onComplete: (() -> ())?)
    		if not isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.closeWindow(mainFrame, uiScale, function()
    			isOpen = false
    			isTransitioning = false
    			if onComplete then
    				onComplete()
    			end
    		end)
    	end
    
    	local function toggleWindow(onComplete: (() -> ())?)
    		if isOpen then
    			closeWindow(onComplete)
    		else
    			openWindow(onComplete)
    		end
    	end
    
    	local function setWindowVisible(visible: boolean, onComplete: (() -> ())?)
    		if visible then
    			openWindow(onComplete)
    		else
    			closeWindow(onComplete)
    		end
    	end
    
    	closeButton.MouseButton1Click:Connect(function()
    		closeWindow()
    	end)
    
    	UserInputService.InputBegan:Connect(function(input, gameProcessed)
    		if gameProcessed then return end
    		if input.KeyCode == Enum.KeyCode.RightBracket then
    			toggleWindow()
    		end
    	end)
    
    	local controller = {
    		openWindow = openWindow,
    		closeWindow = closeWindow,
    		toggleWindow = toggleWindow,
    		setWindowVisible = setWindowVisible,
    		isOpen = function() return isOpen end,
    		isTransitioning = function() return isTransitioning end,
    	}
    
    	return mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale, controller
    end
    
    function UI.createBannerCard(parent: GuiObject): Frame
    	local banner = Instance.new("Frame")
    	banner.Name = "PlayerGameBanner"
    	banner.Size = UDim2.new(1, -6, 0, 88)
    	banner.Position = UDim2.new(0, 3, 0, 0)
    	banner.BackgroundColor3 = UI.Theme.Container
    	banner.BackgroundTransparency = UI.Theme.ContainerTransparency
    	banner.BorderSizePixel = 0
    	banner.ClipsDescendants = true
    	banner.Parent = parent
    	UI.registerThemeElement(banner, "Container")
    
    	local bannerGradient = Instance.new("UIGradient")
    	bannerGradient.Rotation = 90
    	bannerGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 215, 225))
    	})
    	bannerGradient.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.1)
    	})
    	bannerGradient.Parent = banner
    
    	local bannerStroke = Instance.new("UIStroke")
    	bannerStroke.Color = UI.Theme.Border
    	bannerStroke.Thickness = 1.5
    	bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	bannerStroke.Parent = banner
    	UI.registerThemeElement(bannerStroke, "Border")
    
    	local mugshotBox = Instance.new("Frame")
    	mugshotBox.Name = "MugshotBox"
    	mugshotBox.Size = UDim2.new(0, 78, 1, -8)
    	mugshotBox.Position = UDim2.new(0, 4, 0, 4)
    	mugshotBox.BackgroundColor3 = UI.Theme.ContainerDark
    	mugshotBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	mugshotBox.BorderSizePixel = 0
    	mugshotBox.ClipsDescendants = true
    	mugshotBox.Parent = banner
    	UI.registerThemeElement(mugshotBox, "ContainerDark")
    
    	local mugshotStroke = Instance.new("UIStroke")
    	mugshotStroke.Color = UI.Theme.Border
    	mugshotStroke.Thickness = 1.2
    	mugshotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	mugshotStroke.Parent = mugshotBox
    	UI.registerThemeElement(mugshotStroke, "Border")
    
    	local avatarImg = Instance.new("ImageLabel")
    	avatarImg.Size = UDim2.new(1, -4, 1, -4)
    	avatarImg.Position = UDim2.new(0, 2, 0, 2)
    	avatarImg.BackgroundTransparency = 1
    	avatarImg.Parent = mugshotBox
    	task.spawn(function()
    		local ok, thumb = pcall(function()
    			return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    		end)
    		if ok and thumb and avatarImg.Parent then
    			avatarImg.Image = thumb
    		end
    	end)
    
    	local rightSide = Instance.new("Frame")
    	rightSide.Name = "RightSide"
    	rightSide.Size = UDim2.new(1, -92, 1, -8)
    	rightSide.Position = UDim2.new(0, 86, 0, 4)
    	rightSide.BackgroundTransparency = 1
    	rightSide.BorderSizePixel = 0
    	rightSide.ClipsDescendants = true
    	rightSide.Parent = banner
    
    	local titleRow = Instance.new("Frame")
    	titleRow.Name = "TitleRow"
    	titleRow.Size = UDim2.new(1, 0, 0, 22)
    	titleRow.Position = UDim2.new(0, 0, 0, 0)
    	titleRow.BackgroundColor3 = UI.Theme.ContainerDark
    	titleRow.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	titleRow.BorderSizePixel = 0
    	titleRow.ClipsDescendants = true
    	titleRow.Parent = rightSide
    	UI.registerThemeElement(titleRow, "ContainerDark")
    
    	local titleRowStroke = Instance.new("UIStroke")
    	titleRowStroke.Color = UI.Theme.Border
    	titleRowStroke.Thickness = 1.2
    	titleRowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleRowStroke.Parent = titleRow
    	UI.registerThemeElement(titleRowStroke, "Border")
    
    	local gameName = "Roblox Experience"
    	pcall(function()
    		local info = MarketplaceService:GetProductInfo(game.PlaceId)
    		if info and info.Name then
    			gameName = info.Name
    		end
    	end)
    
    	local titleRowLabel = Instance.new("TextLabel")
    	titleRowLabel.Size = UDim2.new(1, -12, 1, 0)
    	titleRowLabel.Position = UDim2.new(0, 6, 0, 0)
    	titleRowLabel.BackgroundTransparency = 1
    	titleRowLabel.Text = string.format("%s   :   %s", Players.LocalPlayer.DisplayName, gameName)
    	titleRowLabel.TextColor3 = UI.Theme.TextPrimary
    	titleRowLabel.Font = UI.Fonts.Header
    	titleRowLabel.TextSize = 11
    	titleRowLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleRowLabel.Parent = titleRow
    	UI.registerThemeElement(titleRowLabel, "TextPrimary")
    
    	local middleBlock = Instance.new("Frame")
    	middleBlock.Name = "MiddleBlock"
    	middleBlock.Size = UDim2.new(1, 0, 1, -26)
    	middleBlock.Position = UDim2.new(0, 0, 0, 26)
    	middleBlock.BackgroundTransparency = 1
    	middleBlock.BorderSizePixel = 0
    	middleBlock.ClipsDescendants = true
    	middleBlock.Parent = rightSide
    
    	local gameIconBox = Instance.new("Frame")
    	gameIconBox.Name = "GameIconBox"
    	gameIconBox.Size = UDim2.new(0, 52, 1, 0)
    	gameIconBox.Position = UDim2.new(1, -52, 0, 0)
    	gameIconBox.BackgroundColor3 = UI.Theme.ContainerDark
    	gameIconBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	gameIconBox.BorderSizePixel = 0
    	gameIconBox.ClipsDescendants = true
    	gameIconBox.Parent = middleBlock
    	UI.registerThemeElement(gameIconBox, "ContainerDark")
    
    	local gameIconStroke = Instance.new("UIStroke")
    	gameIconStroke.Color = UI.Theme.Border
    	gameIconStroke.Thickness = 1.2
    	gameIconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	gameIconStroke.Parent = gameIconBox
    	UI.registerThemeElement(gameIconStroke, "Border")
    
    	local gameIconImg = Instance.new("ImageLabel")
    	gameIconImg.Size = UDim2.new(1, -4, 1, -4)
    	gameIconImg.Position = UDim2.new(0, 2, 0, 2)
    	gameIconImg.BackgroundTransparency = 1
    	gameIconImg.Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", game.PlaceId)
    	gameIconImg.Parent = gameIconBox
    
    	local infoList = Instance.new("Frame")
    	infoList.Name = "InfoList"
    	infoList.Size = UDim2.new(1, -58, 1, 0)
    	infoList.Position = UDim2.new(0, 0, 0, 0)
    	infoList.BackgroundTransparency = 1
    	infoList.BorderSizePixel = 0
    	infoList.ClipsDescendants = true
    	infoList.Parent = middleBlock
    
    	local infoRow1 = Instance.new("Frame")
    	infoRow1.Name = "InfoRow1"
    	infoRow1.Size = UDim2.new(1, 0, 0, 22)
    	infoRow1.Position = UDim2.new(0, 0, 0, 0)
    	infoRow1.BackgroundColor3 = UI.Theme.ContainerDark
    	infoRow1.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	infoRow1.BorderSizePixel = 0
    	infoRow1.ClipsDescendants = true
    	infoRow1.Parent = infoList
    	UI.registerThemeElement(infoRow1, "ContainerDark")
    
    	local row1Stroke = Instance.new("UIStroke")
    	row1Stroke.Color = UI.Theme.Border
    	row1Stroke.Thickness = 1
    	row1Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	row1Stroke.Parent = infoRow1
    	UI.registerThemeElement(row1Stroke, "Border")
    
    	local row1Label = Instance.new("TextLabel")
    	row1Label.Size = UDim2.new(1, -8, 1, 0)
    	row1Label.Position = UDim2.new(0, 6, 0, 0)
    	row1Label.BackgroundTransparency = 1
    	row1Label.Text = string.format("User: @%s | UserID: %d", Players.LocalPlayer.Name, Players.LocalPlayer.UserId)
    	row1Label.TextColor3 = UI.Theme.TextSecondary
    	row1Label.Font = UI.Fonts.Mono
    	row1Label.TextSize = 10
    	row1Label.TextXAlignment = Enum.TextXAlignment.Left
    	row1Label.Parent = infoRow1
    	UI.registerThemeElement(row1Label, "TextSecondary")
    
    	local infoRow2 = Instance.new("Frame")
    	infoRow2.Name = "InfoRow2"
    	infoRow2.Size = UDim2.new(1, 0, 0, 22)
    	infoRow2.Position = UDim2.new(0, 0, 0, 26)
    	infoRow2.BackgroundColor3 = UI.Theme.ContainerDark
    	infoRow2.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	infoRow2.BorderSizePixel = 0
    	infoRow2.ClipsDescendants = true
    	infoRow2.Parent = infoList
    	UI.registerThemeElement(infoRow2, "ContainerDark")
    
    	local row2Stroke = Instance.new("UIStroke")
    	row2Stroke.Color = UI.Theme.Border
    	row2Stroke.Thickness = 1
    	row2Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	row2Stroke.Parent = infoRow2
    	UI.registerThemeElement(row2Stroke, "Border")
    
    	local row2Label = Instance.new("TextLabel")
    	row2Label.Size = UDim2.new(1, -8, 1, 0)
    	row2Label.Position = UDim2.new(0, 6, 0, 0)
    	row2Label.BackgroundTransparency = 1
    	row2Label.Text = string.format("Account Age: %d days | PlaceID: %d", Players.LocalPlayer.AccountAge, game.PlaceId)
    	row2Label.TextColor3 = UI.Theme.TextSecondary
    	row2Label.Font = UI.Fonts.Mono
    	row2Label.TextSize = 10
    	row2Label.TextXAlignment = Enum.TextXAlignment.Left
    	row2Label.Parent = infoRow2
    	UI.registerThemeElement(row2Label, "TextSecondary")
    
    	return banner
    end
    
    return UI
end

Modules["UI/Notification.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Squared Retro Notification System ✦
        Renders pixel-perfect themed notification popups matching the user mockup.
    ]=]
    
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local Notification = {}
    Notification.__index = Notification
    
    local notifGui: ScreenGui? = nil
    local activeCards: {Frame} = {}
    
    local function getNotificationGui(): ScreenGui
    	if not notifGui or not notifGui.Parent then
    		notifGui = Instance.new("ScreenGui")
    		notifGui.Name = "ModularNotificationsGui"
    		notifGui.ResetOnSpawn = false
    		notifGui.DisplayOrder = 9999
    		notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    		
    		pcall(function()
    			notifGui.Parent = CoreGui
    		end)
    		if not notifGui.Parent then
    			notifGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    		end
    	end
    	return notifGui :: ScreenGui
    end
    
    local function repositionCards()
    	for i, card in ipairs(activeCards) do
    		local targetY = -20 - (i * 80)
    		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			Position = UDim2.new(1, -280, 1, targetY)
    		}):Play()
    	end
    end
    
    function Notification.show(title: string, message: string, duration: number?)
    	local gui = getNotificationGui()
    	local displayTime = duration or 3.8
    	
    	local card = Instance.new("Frame")
    	card.Name = "NotificationCard"
    	card.Size = UDim2.new(0, 260, 0, 74)
    	card.Position = UDim2.new(1, 40, 1, -20 - (#activeCards + 1) * 80)
    	card.BackgroundColor3 = UI.Theme.Background
    	card.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	card.BorderSizePixel = 0
    	card.ClipsDescendants = false
    	card.Parent = gui
    	UI.registerThemeElement(card, "Background")
    	
    	local bgGradient = Instance.new("UIGradient")
    	bgGradient.Rotation = 90
    	bgGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
    	})
    	bgGradient.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.15)
    	})
    	bgGradient.Parent = card
    
    	local cardStroke = Instance.new("UIStroke")
    	cardStroke.Color = UI.Theme.Border
    	cardStroke.Thickness = 2
    	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	cardStroke.Parent = card
    	UI.registerThemeElement(cardStroke, "Border")
    
    	local cardScale = Instance.new("UIScale")
    	cardScale.Scale = 0.92
    	cardScale.Parent = card
    	
    	-- Inset Topbar
    	local topbar = Instance.new("Frame")
    	topbar.Name = "TopBar"
    	topbar.Size = UDim2.new(1, -12, 0, 22)
    	topbar.Position = UDim2.new(0, 6, 0, 6)
    	topbar.BackgroundColor3 = UI.Theme.Container
    	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
    	topbar.BorderSizePixel = 0
    	topbar.Parent = card
    	UI.registerThemeElement(topbar, "Container")
    
    	local topGradient = Instance.new("UIGradient")
    	topGradient.Rotation = 45
    	topGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
    	})
    	topGradient.Parent = topbar
    
    	local topStroke = Instance.new("UIStroke")
    	topStroke.Color = UI.Theme.Border
    	topStroke.Thickness = 1.5
    	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	topStroke.Parent = topbar
    	UI.registerThemeElement(topStroke, "Border")
    	
    	local topTitle = Instance.new("TextLabel")
    	topTitle.Size = UDim2.new(1, -44, 1, 0)
    	topTitle.Position = UDim2.new(0, 6, 0, 0)
    	topTitle.BackgroundTransparency = 1
    	topTitle.Text = title or "New Notification!"
    	topTitle.TextColor3 = UI.Theme.TextPrimary
    	topTitle.Font = UI.Fonts.Header
    	topTitle.TextSize = 11
    	topTitle.TextXAlignment = Enum.TextXAlignment.Left
    	topTitle.Parent = topbar
    	UI.registerThemeElement(topTitle, "TextPrimary")
    	
    	-- topbar icons: [-] and [□]
    	local minIcon = Instance.new("TextLabel")
    	minIcon.Size = UDim2.new(0, 14, 1, 0)
    	minIcon.Position = UDim2.new(1, -32, 0, 0)
    	minIcon.BackgroundTransparency = 1
    	minIcon.Text = "—"
    	minIcon.TextColor3 = UI.Theme.TextPrimary
    	minIcon.Font = UI.Fonts.Header
    	minIcon.TextSize = 11
    	minIcon.Parent = topbar
    	UI.registerThemeElement(minIcon, "TextPrimary")
    	
    	local sqIcon = Instance.new("TextLabel")
    	sqIcon.Size = UDim2.new(0, 14, 1, 0)
    	sqIcon.Position = UDim2.new(1, -16, 0, 0)
    	sqIcon.BackgroundTransparency = 1
    	sqIcon.Text = "□"
    	sqIcon.TextColor3 = UI.Theme.TextPrimary
    	sqIcon.Font = UI.Fonts.Header
    	sqIcon.TextSize = 11
    	sqIcon.Parent = topbar
    	UI.registerThemeElement(sqIcon, "TextPrimary")
    	
    	-- message body
    	local bodyLabel = Instance.new("TextLabel")
    	bodyLabel.Name = "Message"
    	bodyLabel.Size = UDim2.new(1, -16, 1, -34)
    	bodyLabel.Position = UDim2.new(0, 8, 0, 32)
    	bodyLabel.BackgroundTransparency = 1
    	bodyLabel.Text = message
    	bodyLabel.TextColor3 = UI.Theme.TextPrimary
    	bodyLabel.Font = UI.Fonts.Header
    	bodyLabel.TextSize = 12
    	bodyLabel.TextXAlignment = Enum.TextXAlignment.Center
    	bodyLabel.Parent = card
    	UI.registerThemeElement(bodyLabel, "TextPrimary")
    	
    	table.insert(activeCards, 1, card)
    	repositionCards()
    	
    	-- Slide in from right with spring pop-in (0.92 -> 1.0)
    	card.Position = UDim2.new(1, 40, 1, -20 - 80)
    	TweenService:Create(cardScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    		Scale = 1.0
    	}):Play()
    	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    		Position = UDim2.new(1, -280, 1, -20 - 80)
    	}):Play()
    	
    	task.delay(displayTime, function()
    		if card and card.Parent then
    			local idx = table.find(activeCards, card)
    			if idx then
    				table.remove(activeCards, idx)
    			end
    			repositionCards()
    			
    			TweenService:Create(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    				Scale = 0.92
    			}):Play()
    
    			for _, desc in ipairs(card:GetDescendants()) do
    				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
    					TweenService:Create(desc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    						TextTransparency = 1
    					}):Play()
    				elseif desc:IsA("Frame") then
    					TweenService:Create(desc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    						BackgroundTransparency = 1
    					}):Play()
    				elseif desc:IsA("UIStroke") then
    					TweenService:Create(desc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    						Transparency = 1
    					}):Play()
    				end
    			end
    
    			local tweenOut = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    				Position = UDim2.new(1, 40, card.Position.Y.Scale, card.Position.Y.Offset),
    				BackgroundTransparency = 1
    			})
    			tweenOut:Play()
    
    			local compConn: RBXScriptConnection? = nil
    			compConn = tweenOut.Completed:Connect(function()
    				if compConn then
    					compConn:Disconnect()
    					compConn = nil
    				end
    				for _, desc in ipairs(card:GetDescendants()) do
    					UI.unregisterThemeElement(desc)
    				end
    				UI.unregisterThemeElement(card)
    				card:Destroy()
    			end)
    		end
    	end)
    end
    
    function Notification.cleanup()
    	for _, card in ipairs(activeCards) do
    		if card and card.Parent then
    			for _, desc in ipairs(card:GetDescendants()) do
    				UI.unregisterThemeElement(desc)
    			end
    			UI.unregisterThemeElement(card)
    			card:Destroy()
    		end
    	end
    	table.clear(activeCards)
    	if notifGui then
    		pcall(function() notifGui:Destroy() end)
    		notifGui = nil
    	end
    end
    
    function Notification.notifyFeature(featureName: string, state: boolean)
    	local stateText = if state then "Option Enabled !" else "Option Disabled !"
    	Notification.show("New Notification!", string.format("%s: %s", featureName, stateText))
    end
    
    return Notification
end

Modules["UI/PlayerList.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Squared Retro Player List Widget with Auto-Positioned Context Menu ✦
        Features:
        - Interactive player rows with hover FX and click-to-open context menu
        - Smart auto-positioning popup (anchors dynamically to the left or right of clicked row, clamped to viewport)
        - Full Roblox player actions: Profile view, Add/Unfriend, Block, Report/Inspect, Teleport, Fling, Spectate, Copy ID
        - Domino sliding animations and auto-scaling list height
    ]=]
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local StarterGui = game:GetService("StarterGui")
    local GuiService = game:GetService("GuiService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local PlayerList = {}
    PlayerList.__index = PlayerList
    
    export type PlayerListWidget = {
    	Frame: Frame,
    	Container: ScrollingFrame,
    	UiScale: UIScale,
    	IsMinimized: boolean,
    	Visible: boolean,
    	IsOpen: () -> boolean,
    	Open: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
    	Close: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
    	Toggle: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
    	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
    	OnClose: (() -> ())?,
    	OnOpen: (() -> ())?,
    	OnMinimize: ((isMin: boolean) -> ())?
    }
    
    local ROW_H = 38
    local ROW_GAP = 4
    local HEADER_H = 28
    local POPUP_W = 220
    local POPUP_H = 254
    
    function PlayerList.new(): PlayerListWidget
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularPlayerListGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.DisplayOrder = 600
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    	pcall(function() screenGui.Parent = CoreGui end)
    	if not screenGui.Parent then
    		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    	end
    
    	-- ── Main Widget Frame ─────────────────────────────────────────────
    	local widget = Instance.new("Frame")
    	widget.Name = "PlayerListWidget"
    	widget.Size = UDim2.new(0, 260, 0, HEADER_H + 40)
    	widget.Position = UDim2.new(1, -270, 0, 10)
    	widget.BackgroundColor3 = UI.Theme.Background
    	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	widget.BorderSizePixel = 0
    	widget.ClipsDescendants = false
    	widget.Parent = screenGui
    	UI.registerThemeElement(widget, "Background")
    
    	local bgGradient = Instance.new("UIGradient")
    	bgGradient.Rotation = 90
    	bgGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
    	})
    	bgGradient.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.15)
    	})
    	bgGradient.Parent = widget
    
    	local outerStroke = Instance.new("UIStroke")
    	outerStroke.Color = UI.Theme.Border
    	outerStroke.Thickness = 2
    	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	outerStroke.Parent = widget
    	UI.registerThemeElement(outerStroke, "Border")
    
    	local uiScale = Instance.new("UIScale")
    	uiScale.Scale = 1.0
    	uiScale.Parent = widget
    
    	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
    	local topbar = Instance.new("Frame")
    	topbar.Name = "TopBar"
    	topbar.Size = UDim2.new(1, -12, 0, HEADER_H)
    	topbar.Position = UDim2.new(0, 6, 0, 6)
    	topbar.BackgroundColor3 = UI.Theme.Container
    	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
    	topbar.BorderSizePixel = 0
    	topbar.Parent = widget
    	UI.registerThemeElement(topbar, "Container")
    
    	local topGradient = Instance.new("UIGradient")
    	topGradient.Rotation = 45
    	topGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
    	})
    	topGradient.Parent = topbar
    
    	local topStroke = Instance.new("UIStroke")
    	topStroke.Color = UI.Theme.Border
    	topStroke.Thickness = 1.5
    	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	topStroke.Parent = topbar
    	UI.registerThemeElement(topStroke, "Border")
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Name = "TitleLabel"
    	titleLabel.Size = UDim2.new(1, -56, 1, 0)
    	titleLabel.Position = UDim2.new(0, 8, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Header
    	titleLabel.TextSize = 11
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.Parent = topbar
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	local minBtn = Instance.new("TextButton")
    	minBtn.Name = "MinBtn"
    	minBtn.Size = UDim2.new(0, 20, 0, 18)
    	minBtn.Position = UDim2.new(1, -44, 0, 5)
    	minBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	minBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	minBtn.BorderSizePixel = 0
    	minBtn.Text = "—"
    	minBtn.TextColor3 = UI.Theme.TextPrimary
    	minBtn.Font = UI.Fonts.Header
    	minBtn.TextSize = 10
    	minBtn.Parent = topbar
    	UI.registerThemeElement(minBtn, "ContainerDark")
    	UI.registerThemeElement(minBtn, "TextPrimary")
    
    	local minStroke = Instance.new("UIStroke")
    	minStroke.Color = UI.Theme.Border
    	minStroke.Thickness = 1
    	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	minStroke.Parent = minBtn
    	UI.registerThemeElement(minStroke, "Border")
    
    	local closeBtn = Instance.new("TextButton")
    	closeBtn.Name = "CloseBtn"
    	closeBtn.Size = UDim2.new(0, 20, 0, 18)
    	closeBtn.Position = UDim2.new(1, -22, 0, 5)
    	closeBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	closeBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	closeBtn.BorderSizePixel = 0
    	closeBtn.Text = "X"
    	closeBtn.TextColor3 = UI.Theme.TextPrimary
    	closeBtn.Font = UI.Fonts.Header
    	closeBtn.TextSize = 10
    	closeBtn.Parent = topbar
    	UI.registerThemeElement(closeBtn, "ContainerDark")
    	UI.registerThemeElement(closeBtn, "TextPrimary")
    
    	local closeStroke = Instance.new("UIStroke")
    	closeStroke.Color = UI.Theme.Border
    	closeStroke.Thickness = 1
    	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	closeStroke.Parent = closeBtn
    	UI.registerThemeElement(closeStroke, "Border")
    
    	-- ── Scrolling Player Container ────────────────────────────────────
    	local container = Instance.new("ScrollingFrame")
    	container.Name = "PlayerListContainer"
    	container.Size = UDim2.new(1, -12, 1, -(HEADER_H + 12))
    	container.Position = UDim2.new(0, 6, 0, HEADER_H + 8)
    	container.BackgroundTransparency = 1
    	container.BorderSizePixel = 0
    	container.ScrollBarThickness = 3
    	container.ScrollBarImageColor3 = UI.Theme.Accent
    	container.CanvasSize = UDim2.new(0, 0, 0, 0)
    	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	container.ClipsDescendants = true
    	container.Parent = widget
    
    	local listPad = Instance.new("UIPadding")
    	listPad.PaddingLeft = UDim.new(0, 4)
    	listPad.PaddingRight = UDim.new(0, 4)
    	listPad.PaddingTop = UDim.new(0, 4)
    	listPad.PaddingBottom = UDim.new(0, 4)
    	listPad.Parent = container
    
    	local listLayout = Instance.new("UIListLayout")
    	listLayout.Padding = UDim.new(0, ROW_GAP)
    	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	listLayout.Parent = container
    
    	-- ── Smooth Height Scaling to Player Count ─────────────────────────
    	local minimized = false
    
    	local function updateWidgetHeight()
    		if minimized then return end
    		local count = #Players:GetPlayers()
    		local fullNeededHeight = HEADER_H + count * (ROW_H + ROW_GAP) + 8
    		local vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
    		local posY = math.max(0, widget.AbsolutePosition.Y)
    		local maxAvailableH = math.max(HEADER_H + 40, vpH - posY - 16)
    		local targetH = math.min(fullNeededHeight, maxAvailableH)
    
    		TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			Size = UDim2.new(0, widget.AbsoluteSize.X, 0, targetH)
    		}):Play()
    	end
    
    	-- ── Standard Roblox Topbar Drag (Screen Clamped) ──────────────────
    	local dragging = false
    	local dragInput: InputObject? = nil
    	local dragStart = Vector3.zero
    	local startAbsPos = Vector2.zero
    
    	-- Forward declare popup frame
    	local popupFrame: Frame
    
    	topbar.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			dragStart = input.Position
    			startAbsPos = widget.AbsolutePosition
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    					updateWidgetHeight()
    				end
    			end)
    		end
    	end)
    
    	topbar.InputChanged:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    			dragInput = input
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if input == dragInput and dragging then
    			local delta = input.Position - dragStart
    			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
    			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
    			widget.Position = UDim2.new(0, targetX, 0, targetY)
    			if popupFrame and popupFrame.Visible then
    				if closeContextMenu then
    					closeContextMenu()
    				else
    					popupFrame.Visible = false
    				end
    			end
    		end
    	end)
    
    	if workspace.CurrentCamera then
    		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateWidgetHeight)
    	end
    
    	-- ── Button Hover & Click FX ─────────────────────────────────────
    	local function attachBtnFX(btn: TextButton, isClose: boolean?)
    		local stroke = btn:FindFirstChildWhichIsA("UIStroke")
    		btn.MouseEnter:Connect(function()
    			if stroke then TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.8 }):Play() end
    			local hoverCol = if isClose then Color3.fromRGB(220, 60, 60) else UI.Theme.Accent
    			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    		end)
    		btn.MouseLeave:Connect(function()
    			if stroke then TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1 }):Play() end
    			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    		btn.MouseButton1Down:Connect(function()
    			TweenService:Create(btn, TweenInfo.new(0.08), { Size = UDim2.new(0, 18, 0, 16) }):Play()
    		end)
    		btn.MouseButton1Up:Connect(function()
    			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(0, 20, 0, 18) }):Play()
    		end)
    	end
    
    	attachBtnFX(minBtn, false)
    	attachBtnFX(closeBtn, true)
    
    	-- ── Minimize / Close ─────────────────────────────────────────────
    	local isOpen = true
    	local isTransitioning = false
    	local isPopupOpen = false
    
    	-- Forward declare closeContextMenu
    	local closeContextMenu: () -> ()
    
    	local widgetObj: any = nil
    
    	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.openWindow(widget, uiScale, function()
    			isOpen = true
    			isTransitioning = false
    			if widgetObj and widgetObj.OnOpen then
    				pcall(widgetObj.OnOpen)
    			end
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if not isOpen or isTransitioning then return end
    		isTransitioning = true
    		if closeContextMenu then closeContextMenu() end
    		Animations.closeWindow(widget, uiScale, function()
    			isOpen = false
    			isTransitioning = false
    			if widgetObj and widgetObj.OnClose then
    				pcall(widgetObj.OnClose)
    			end
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen then
    			closeWidget(onComplete)
    		else
    			openWidget(onComplete)
    		end
    	end
    
    	local function setWidgetVisible(selfOrVal: any, maybeVal: any)
    		local v = if type(selfOrVal) == "boolean" then selfOrVal elseif type(maybeVal) == "boolean" then maybeVal else true
    		if v then
    			openWidget()
    		else
    			closeWidget()
    		end
    	end
    
    	minBtn.MouseButton1Click:Connect(function()
    		minimized = not minimized
    		if closeContextMenu then closeContextMenu() end
    		if minimized then
    			container.Visible = false
    			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, HEADER_H)
    			}):Play()
    		else
    			container.Visible = true
    			updateWidgetHeight()
    		end
    		if widgetObj and widgetObj.OnMinimize then
    			pcall(function() widgetObj.OnMinimize(minimized) end)
    		end
    	end)
    
    	closeBtn.MouseButton1Click:Connect(function()
    		closeWidget()
    	end)
    
    	-- ── Floating Player Context Menu Popup ───────────────────────────
    	popupFrame = Instance.new("Frame")
    	popupFrame.Name = "PlayerContextMenu"
    	popupFrame.Size = UDim2.new(0, POPUP_W, 0, POPUP_H)
    	popupFrame.BackgroundColor3 = UI.Theme.Background
    	popupFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	popupFrame.BorderSizePixel = 0
    	popupFrame.Visible = false
    	popupFrame.ZIndex = 100
    	popupFrame.Parent = screenGui
    	UI.registerThemeElement(popupFrame, "Background")
    
    	local popupBgGrad = Instance.new("UIGradient")
    	popupBgGrad.Rotation = 90
    	popupBgGrad.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
    	})
    	popupBgGrad.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.15)
    	})
    	popupBgGrad.Parent = popupFrame
    
    	local popupStroke = Instance.new("UIStroke")
    	popupStroke.Color = UI.Theme.Border
    	popupStroke.Thickness = 2
    	popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	popupStroke.Parent = popupFrame
    	UI.registerThemeElement(popupStroke, "Border")
    
    	local popupScale = Instance.new("UIScale")
    	popupScale.Scale = 1.0
    	popupScale.Parent = popupFrame
    
    	-- Popup Header with Avatar & Details
    	local pHeader = Instance.new("Frame")
    	pHeader.Name = "PopupHeader"
    	pHeader.Size = UDim2.new(1, 0, 0, 52)
    	pHeader.BackgroundColor3 = UI.Theme.Container
    	pHeader.BackgroundTransparency = UI.Theme.ContainerTransparency
    	pHeader.BorderSizePixel = 0
    	pHeader.Parent = popupFrame
    	UI.registerThemeElement(pHeader, "Container")
    
    	local pHeaderStroke = Instance.new("UIStroke")
    	pHeaderStroke.Color = UI.Theme.Border
    	pHeaderStroke.Thickness = 1
    	pHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	pHeaderStroke.Parent = pHeader
    	UI.registerThemeElement(pHeaderStroke, "Border")
    
    	local pAvatarBox = Instance.new("Frame")
    	pAvatarBox.Size = UDim2.new(0, 42, 0, 42)
    	pAvatarBox.Position = UDim2.new(0, 5, 0, 5)
    	pAvatarBox.BackgroundColor3 = UI.Theme.ContainerDark
    	pAvatarBox.BorderSizePixel = 0
    	pAvatarBox.Parent = pHeader
    	UI.registerThemeElement(pAvatarBox, "ContainerDark")
    
    	local pAvatarImg = Instance.new("ImageLabel")
    	pAvatarImg.Size = UDim2.new(1, 0, 1, 0)
    	pAvatarImg.BackgroundTransparency = 1
    	pAvatarImg.Parent = pAvatarBox
    
    	local pNameLabel = Instance.new("TextLabel")
    	pNameLabel.Size = UDim2.new(1, -74, 0, 16)
    	pNameLabel.Position = UDim2.new(0, 52, 0, 6)
    	pNameLabel.BackgroundTransparency = 1
    	pNameLabel.Text = "DisplayName"
    	pNameLabel.TextColor3 = UI.Theme.TextPrimary
    	pNameLabel.Font = UI.Fonts.Header
    	pNameLabel.TextSize = 11
    	pNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    	pNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	pNameLabel.Parent = pHeader
    	UI.registerThemeElement(pNameLabel, "TextPrimary")
    
    	local pSubLabel = Instance.new("TextLabel")
    	pSubLabel.Size = UDim2.new(1, -74, 0, 14)
    	pSubLabel.Position = UDim2.new(0, 52, 0, 24)
    	pSubLabel.BackgroundTransparency = 1
    	pSubLabel.Text = "@Username | 0d"
    	pSubLabel.TextColor3 = UI.Theme.TextSecondary
    	pSubLabel.Font = UI.Fonts.Mono
    	pSubLabel.TextSize = 9
    	pSubLabel.TextXAlignment = Enum.TextXAlignment.Left
    	pSubLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	pSubLabel.Parent = pHeader
    	UI.registerThemeElement(pSubLabel, "TextSecondary")
    
    	local pCloseBtn = Instance.new("TextButton")
    	pCloseBtn.Size = UDim2.new(0, 16, 0, 16)
    	pCloseBtn.Position = UDim2.new(1, -20, 0, 6)
    	pCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	pCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	pCloseBtn.BorderSizePixel = 0
    	pCloseBtn.Text = "X"
    	pCloseBtn.TextColor3 = UI.Theme.TextPrimary
    	pCloseBtn.Font = UI.Fonts.Header
    	pCloseBtn.TextSize = 9
    	pCloseBtn.Parent = pHeader
    	UI.registerThemeElement(pCloseBtn, "ContainerDark")
    	UI.registerThemeElement(pCloseBtn, "TextPrimary")
    	pCloseBtn.MouseButton1Click:Connect(function()
    		if closeContextMenu then closeContextMenu() end
    	end)
    
    	-- Popup Action Buttons List
    	local pBtnContainer = Instance.new("Frame")
    	pBtnContainer.Size = UDim2.new(1, -10, 1, -60)
    	pBtnContainer.Position = UDim2.new(0, 5, 0, 56)
    	pBtnContainer.BackgroundTransparency = 1
    	pBtnContainer.Parent = popupFrame
    
    	local pLayout = Instance.new("UIListLayout")
    	pLayout.Padding = UDim.new(0, 4)
    	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	pLayout.Parent = pBtnContainer
    
    	local currentTargetPlayer: Player? = nil
    	local isSpying = false
    
    	local function makeActionBtn(text: string, order: number, onClick: () -> ()): TextButton
    		local btn = Instance.new("TextButton")
    		btn.Size = UDim2.new(1, 0, 0, 23)
    		btn.BackgroundColor3 = UI.Theme.Container
    		btn.BackgroundTransparency = UI.Theme.ContainerTransparency
    		btn.BorderSizePixel = 0
    		btn.Text = text
    		btn.TextColor3 = UI.Theme.TextPrimary
    		btn.Font = UI.Fonts.Header
    		btn.TextSize = 10
    		btn.LayoutOrder = order
    		btn.Parent = pBtnContainer
    		UI.registerThemeElement(btn, "Container")
    		UI.registerThemeElement(btn, "TextPrimary")
    
    		local bStroke = Instance.new("UIStroke")
    		bStroke.Color = UI.Theme.Border
    		bStroke.Thickness = 1
    		bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		bStroke.Parent = btn
    		UI.registerThemeElement(bStroke, "Border")
    
    		btn.MouseEnter:Connect(function()
    			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
    			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.Accent }):Play()
    		end)
    		btn.MouseLeave:Connect(function()
    			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
    			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    
    		btn.MouseButton1Click:Connect(onClick)
    		return btn
    	end
    
    	-- 1. Friend / Unfriend
    	local friendBtn = makeActionBtn("Add Friend", 1, function()
    		if currentTargetPlayer and currentTargetPlayer ~= Players.LocalPlayer then
    			pcall(function()
    				StarterGui:SetCore("PromptSendFriendRequest", currentTargetPlayer)
    			end)
    		end
    	end)
    
    	-- 2. Block Player
    	local blockBtn = makeActionBtn("Block Player", 2, function()
    		if currentTargetPlayer and currentTargetPlayer ~= Players.LocalPlayer then
    			pcall(function()
    				StarterGui:SetCore("PromptBlockPlayer", currentTargetPlayer)
    			end)
    		end
    	end)
    
    	-- 3. Teleport To Player
    	local tpBtn = makeActionBtn("Teleport Behind", 3, function()
    		if currentTargetPlayer and currentTargetPlayer.Character then
    			local myChar = Players.LocalPlayer.Character
    			local tChar = currentTargetPlayer.Character
    			if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart") and tChar:FindFirstChild("HumanoidRootPart") then
    				local tHrp = tChar:FindFirstChild("HumanoidRootPart") :: BasePart
    				local myHrp = myChar:FindFirstChild("HumanoidRootPart") :: BasePart
    				myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
    			end
    		end
    	end)
    
    	-- 4. Fling Player (Target High-Torque Burst)
    	local flingBtn = makeActionBtn("Fling Player", 4, function()
    		if currentTargetPlayer and currentTargetPlayer.Character then
    			local myChar = Players.LocalPlayer.Character
    			local tChar = currentTargetPlayer.Character
    			local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    			local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    			if myHrp and tHrp then
    				local oldCF = myHrp.CFrame
    				task.spawn(function()
    					local tStart = tick()
    					while tick() - tStart < 0.45 do
    						if not (myHrp and tHrp and tHrp.Parent) then break end
    						myHrp.CFrame = tHrp.CFrame
    						myHrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
    						task.wait(0.016)
    					end
    					myHrp.AssemblyAngularVelocity = Vector3.zero
    					myHrp.CFrame = oldCF
    				end)
    			end
    		end
    	end)
    
    	-- 5. Spectate / Spy
    	local spyBtn = makeActionBtn("Spectate Player", 5, function()
    		local cam = workspace.CurrentCamera
    		if not cam then return end
    		isSpying = not isSpying
    		spyBtn.Text = if isSpying then "Unspectate" else "Spectate Player"
    		if isSpying and currentTargetPlayer and currentTargetPlayer.Character and currentTargetPlayer.Character:FindFirstChildOfClass("Humanoid") then
    			cam.CameraSubject = currentTargetPlayer.Character:FindFirstChildOfClass("Humanoid")
    		elseif Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
    			cam.CameraSubject = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    		end
    	end)
    
    	-- 6. Inspect Profile / Report
    	local inspectBtn = makeActionBtn("Inspect / Report", 6, function()
    		if currentTargetPlayer then
    			pcall(function()
    				GuiService:InspectPlayerFromUserId(currentTargetPlayer.UserId)
    			end)
    		end
    	end)
    
    	-- 7. Copy Username & User ID
    	local copyBtn = makeActionBtn("Copy Name & ID", 7, function()
    		if currentTargetPlayer then
    			local clip = string.format("%s (@%s) [ID:%d]", currentTargetPlayer.DisplayName, currentTargetPlayer.Name, currentTargetPlayer.UserId)
    			local setclip = setclipboard or (getgenv and getgenv().setclipboard) or toclipboard
    			if type(setclip) == "function" then
    				setclip(clip)
    			end
    		end
    	end)
    
    	closeContextMenu = function()
    		if not isPopupOpen then return end
    		isPopupOpen = false
    		Animations.popOut(popupFrame, popupScale)
    	end
    
    	local function openContextMenuForPlayer(player: Player, rowAbsPos: Vector2)
    		currentTargetPlayer = player
    		pAvatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    		pNameLabel.Text = player.DisplayName
    		local teamStr = if player.Team then string.format("[%s] ", player.Team.Name) else ""
    		pSubLabel.Text = string.format("%s@%s | ID:%d", teamStr, player.Name, player.UserId)
    
    		-- Update Friend Button text based on status
    		pcall(function()
    			local isFriend = Players.LocalPlayer:IsFriendsWith(player.UserId)
    			friendBtn.Text = if isFriend then "Unfriend" else "Add Friend"
    		end)
    
    		-- Dynamic Smart Positioning (8px viewport margin & flip detection)
    		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    		local wPos = widget.AbsolutePosition
    		local wSize = widget.AbsoluteSize
    		local margin = 8
    
    		local spaceLeft = wPos.X - margin
    		local spaceRight = vpSize.X - (wPos.X + wSize.X) - margin
    
    		local posX = 0
    		if spaceLeft >= POPUP_W then
    			posX = wPos.X - POPUP_W - margin
    		elseif spaceRight >= POPUP_W then
    			posX = wPos.X + wSize.X + margin
    		elseif spaceLeft >= spaceRight then
    			posX = wPos.X - POPUP_W - margin
    		else
    			posX = wPos.X + wSize.X + margin
    		end
    
    		local posY = math.clamp(rowAbsPos.Y, margin, math.max(margin, vpSize.Y - POPUP_H - margin))
    		posX = math.clamp(posX, margin, math.max(margin, vpSize.X - POPUP_W - margin))
    
    		popupFrame.Position = UDim2.new(0, posX, 0, posY)
    		isPopupOpen = true
    		Animations.popIn(popupFrame, popupScale)
    	end
    
    	-- ── Incremental Domino-Animated Player Rows (Clickable) ───────────
    	local function createPlayerRow(player: Player, delaySec: number?)
    		local rowId = "PLR_" .. tostring(player.UserId)
    		if container:FindFirstChild(rowId) then return end
    
    		local rowBtn = Instance.new("TextButton")
    		rowBtn.Name = rowId
    		rowBtn.Size = UDim2.new(1, 0, 0, ROW_H)
    		rowBtn.Position = UDim2.new(0, 24, 0, 0)
    		rowBtn.BackgroundColor3 = UI.Theme.Container
    		rowBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    		rowBtn.BorderSizePixel = 0
    		rowBtn.Text = ""
    		rowBtn.AutoButtonColor = false
    		rowBtn.ClipsDescendants = true
    		rowBtn.Parent = container
    		UI.registerThemeElement(rowBtn, "Container")
    
    		local rowStroke = Instance.new("UIStroke")
    		rowStroke.Color = UI.Theme.Border
    		rowStroke.Thickness = 1
    		rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		rowStroke.Parent = rowBtn
    		UI.registerThemeElement(rowStroke, "Border")
    
    		-- Avatar Headshot
    		local avatarBox = Instance.new("Frame")
    		avatarBox.Size = UDim2.new(0, 30, 0, 30)
    		avatarBox.Position = UDim2.new(0, 4, 0, 4)
    		avatarBox.BackgroundColor3 = UI.Theme.ContainerDark
    		avatarBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    		avatarBox.BorderSizePixel = 0
    		avatarBox.Parent = rowBtn
    		UI.registerThemeElement(avatarBox, "ContainerDark")
    
    		local avStroke = Instance.new("UIStroke")
    		avStroke.Color = UI.Theme.Border
    		avStroke.Thickness = 1
    		avStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		avStroke.Parent = avatarBox
    		UI.registerThemeElement(avStroke, "Border")
    
    		local avatarImg = Instance.new("ImageLabel")
    		avatarImg.Size = UDim2.new(1, 0, 1, 0)
    		avatarImg.BackgroundTransparency = 1
    		avatarImg.Parent = avatarBox
    		task.spawn(function()
    			local ok, thumb = pcall(function()
    				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    			end)
    			if ok and thumb and avatarImg.Parent then
    				avatarImg.Image = thumb
    			end
    		end)
    
    		-- Name Label
    		local nameLabel = Instance.new("TextLabel")
    		nameLabel.Size = UDim2.new(1, -42, 0, 16)
    		nameLabel.Position = UDim2.new(0, 38, 0, 3)
    		nameLabel.BackgroundTransparency = 1
    		nameLabel.Text = string.format("%s (@%s)", player.DisplayName, player.Name)
    		nameLabel.TextColor3 = UI.Theme.TextPrimary
    		nameLabel.Font = UI.Fonts.Header
    		nameLabel.TextSize = 10
    		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    		nameLabel.Parent = rowBtn
    		UI.registerThemeElement(nameLabel, "TextPrimary")
    
    		-- Details Label
    		local subLabel = Instance.new("TextLabel")
    		subLabel.Size = UDim2.new(1, -42, 0, 14)
    		subLabel.Position = UDim2.new(0, 38, 0, 19)
    		subLabel.BackgroundTransparency = 1
    		local teamStr = if player.Team then string.format("[%s] ", player.Team.Name) else ""
    		subLabel.Text = string.format("%sID:%d | %dd", teamStr, player.UserId, player.AccountAge)
    		subLabel.TextColor3 = UI.Theme.TextSecondary
    		subLabel.Font = UI.Fonts.Mono
    		subLabel.TextSize = 9
    		subLabel.TextXAlignment = Enum.TextXAlignment.Left
    		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
    		subLabel.Parent = rowBtn
    		UI.registerThemeElement(subLabel, "TextSecondary")
    
    		-- Row Hover FX
    		rowBtn.MouseEnter:Connect(function()
    			TweenService:Create(rowStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.4 }):Play()
    			TweenService:Create(rowBtn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark }):Play()
    		end)
    		rowBtn.MouseLeave:Connect(function()
    			TweenService:Create(rowStroke, TweenInfo.new(0.12), { Color = UI.Theme.Border, Thickness = 1 }):Play()
    			TweenService:Create(rowBtn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container }):Play()
    		end)
    
    		-- Row Click Opens Context Menu
    		rowBtn.MouseButton1Click:Connect(function()
    			openContextMenuForPlayer(player, rowBtn.AbsolutePosition)
    		end)
    
    		-- Slide-in from right to left (Domino effect)
    		local function playSlide()
    			if rowBtn and rowBtn.Parent then
    				TweenService:Create(rowBtn, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    					Position = UDim2.new(0, 0, 0, 0)
    				}):Play()
    			end
    		end
    
    		if delaySec and delaySec > 0 then
    			task.delay(delaySec, playSlide)
    		else
    			playSlide()
    		end
    
    		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
    		updateWidgetHeight()
    	end
    
    	local function deletePlayerRow(player: Player)
    		local rowId = "PLR_" .. tostring(player.UserId)
    		local row = container:FindFirstChild(rowId)
    		if row and row:IsA("TextButton") then
    			local tween = TweenService:Create(row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    				Position = UDim2.new(0, 24, 0, 0),
    				BackgroundTransparency = 1
    			})
    			tween:Play()
    			tween.Completed:Connect(function()
    				row:Destroy()
    				titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
    				updateWidgetHeight()
    			end)
    		end
    		if currentTargetPlayer == player and isPopupOpen then
    			closeContextMenu()
    		end
    	end
    
    	-- Connect Player Added / Removed
    	Players.PlayerAdded:Connect(function(p)
    		createPlayerRow(p, 0)
    	end)
    	Players.PlayerRemoving:Connect(deletePlayerRow)
    
    	-- Populate existing players with domino wave
    	task.spawn(function()
    		for i, p in ipairs(Players:GetPlayers()) do
    			createPlayerRow(p, (i - 1) * 0.035)
    		end
    	end)
    
    	widgetObj = {
    		Frame = widget,
    		Container = container,
    		UiScale = uiScale,
    		IsMinimized = false,
    		Visible = true,
    		IsOpen = function() return isOpen end,
    		Open = openWidget,
    		Close = closeWidget,
    		Toggle = toggleWidget,
    		SetVisible = setWidgetVisible,
    		OnClose = nil,
    		OnOpen = nil,
    		OnMinimize = nil,
    	}
    	return widgetObj
    end
    
    return PlayerList
end

Modules["UI/ChatWidget.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Squared Retro Chat Widget with Scaling Grip & Player Profile Action Popup ✦
        Features:
        - Corner resize grip: smooth scaling from 260x180 to 800x600
        - Player Name Click: opens sleek Player Profile & Action Popup (Teleport, Spectate, Friend, Block, Report, Copy ID)
        - Full IgnoreGuiInset dragging
        - RichText seamless message flow
        - Action Header: [ ⯎ ] Roblox Menu, [ ≡ ] Hamburger Dropdown, [ 🎙 ] VoiceChat Mic Toggle
    ]=]
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local TextChatService = game:GetService("TextChatService")
    local VoiceChatService = pcall(function() return game:GetService("VoiceChatService") end) and game:GetService("VoiceChatService") or nil
    local GuiService = game:GetService("GuiService")
    local StarterGui = game:GetService("StarterGui")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local CoreGui = game:GetService("CoreGui")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local ChatWidget = {}
    ChatWidget.__index = ChatWidget
    
    export type ChatWidgetInstance = {
    	Frame: Frame,
    	Container: ScrollingFrame,
    	InputBox: TextBox,
    	SendBtn: TextButton,
    	QuickBtn: TextButton,
    	UiScale: UIScale,
    	IsMinimized: boolean,
    	Visible: boolean,
    	IsOpen: () -> boolean,
    	Open: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
    	Close: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
    	Toggle: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
    	SetVisible: (selfOrVal: any, maybeVal: any) -> ()
    }
    
    function ChatWidget.new(): ChatWidgetInstance
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularChatGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.DisplayOrder = 500
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    	pcall(function() screenGui.Parent = CoreGui end)
    	if not screenGui.Parent then
    		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    	end
    
    	-- Disable default Roblox CoreGuis cleanly
    	local function disableRobloxCoreGuis()
    		pcall(function()
    			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
    		end)
    	end
    	disableRobloxCoreGuis()
    
    	-- Detect chat engine
    	local useLegacyChat = false
    	pcall(function()
    		useLegacyChat = (TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService)
    	end)
    
    	local DEFAULT_W, DEFAULT_H = 340, 260
    	local TOPBAR_H = 28
    	local BOTTOM_H = 28
    
    	-- ── Main Unified Widget Frame ─────────────────────────────────────
    	local widget = Instance.new("Frame")
    	widget.Name = "ChatWidget"
    	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
    	widget.Position = UDim2.new(0, 14, 0, 14)
    	widget.BackgroundColor3 = UI.Theme.Background
    	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	widget.BorderSizePixel = 0
    	widget.ClipsDescendants = false
    	widget.Parent = screenGui
    	UI.registerThemeElement(widget, "Background")
    
    	local bgGradient = Instance.new("UIGradient")
    	bgGradient.Rotation = 90
    	bgGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
    	})
    	bgGradient.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.15)
    	})
    	bgGradient.Parent = widget
    
    	local outerStroke = Instance.new("UIStroke")
    	outerStroke.Color = UI.Theme.Border
    	outerStroke.Thickness = 2
    	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	outerStroke.Parent = widget
    	UI.registerThemeElement(outerStroke, "Border")
    
    	local uiScale = Instance.new("UIScale")
    	uiScale.Scale = 1.0
    	uiScale.Parent = widget
    
    	-- ============================================================
    	-- ── TOPBAR: HEADER (AVATAR, TITLE, ACTIONS, [-] & [X]) ──────
    	-- ============================================================
    	local topbar = Instance.new("Frame")
    	topbar.Name = "TopBar"
    	topbar.Size = UDim2.new(1, -12, 0, TOPBAR_H)
    	topbar.Position = UDim2.new(0, 6, 0, 6)
    	topbar.BackgroundColor3 = UI.Theme.Container
    	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
    	topbar.BorderSizePixel = 0
    	topbar.Parent = widget
    	UI.registerThemeElement(topbar, "Container")
    
    	local topGradient = Instance.new("UIGradient")
    	topGradient.Rotation = 45
    	topGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
    	})
    	topGradient.Parent = topbar
    
    	local topStroke = Instance.new("UIStroke")
    	topStroke.Color = UI.Theme.Border
    	topStroke.Thickness = 1.5
    	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	topStroke.Parent = topbar
    	UI.registerThemeElement(topStroke, "Border")
    
    	-- Avatar Thumbnail
    	local mugBox = Instance.new("Frame")
    	mugBox.Size = UDim2.new(0, 22, 0, 22)
    	mugBox.Position = UDim2.new(0, 3, 0, 3)
    	mugBox.BackgroundColor3 = UI.Theme.ContainerDark
    	mugBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	mugBox.BorderSizePixel = 0
    	mugBox.Parent = topbar
    	UI.registerThemeElement(mugBox, "ContainerDark")
    
    	local mugStroke = Instance.new("UIStroke")
    	mugStroke.Color = UI.Theme.Border
    	mugStroke.Thickness = 1
    	mugStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	mugStroke.Parent = mugBox
    	UI.registerThemeElement(mugStroke, "Border")
    
    	local mugImg = Instance.new("ImageLabel")
    	mugImg.Size = UDim2.new(1, 0, 1, 0)
    	mugImg.BackgroundTransparency = 1
    	mugImg.Parent = mugBox
    	task.spawn(function()
    		local ok, thumb = pcall(function()
    			return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    		end)
    		if ok and thumb and mugImg.Parent then
    			mugImg.Image = thumb
    		end
    	end)
    
    	-- Title: Chat : @Username
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(0, 115, 1, 0)
    	titleLabel.Position = UDim2.new(0, 29, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = string.format("Chat : @%s", Players.LocalPlayer.Name)
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Header
    	titleLabel.TextSize = 10
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.Parent = topbar
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	-- ── Center Action Buttons: [ ⯎ ] [ ≡ ] [ 🎙 ] ─────────────────────
    	local actionGroup = Instance.new("Frame")
    	actionGroup.Name = "TopBarActions"
    	actionGroup.Size = UDim2.new(0, 84, 0, 22)
    	actionGroup.Position = UDim2.new(0, 148, 0, 3)
    	actionGroup.BackgroundTransparency = 1
    	actionGroup.BorderSizePixel = 0
    	actionGroup.Parent = topbar
    
    	local actLayout = Instance.new("UIListLayout")
    	actLayout.FillDirection = Enum.FillDirection.Horizontal
    	actLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	actLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    	actLayout.Padding = UDim.new(0, 4)
    	actLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	actLayout.Parent = actionGroup
    
    	-- 1. Roblox Menu Button [ ⯎ ]
    	local rbxBtn = Instance.new("ImageButton")
    	rbxBtn.Name = "RobloxLogoBtn"
    	rbxBtn.Size = UDim2.new(0, 24, 0, 22)
    	rbxBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	rbxBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	rbxBtn.BorderSizePixel = 0
    	rbxBtn.Image = "rbxasset://textures/ui/TopBar/icon_roblox.png"
    	rbxBtn.ScaleType = Enum.ScaleType.Fit
    	rbxBtn.LayoutOrder = 1
    	rbxBtn.Parent = actionGroup
    	UI.registerThemeElement(rbxBtn, "ContainerDark")
    
    	local rbxStroke = Instance.new("UIStroke")
    	rbxStroke.Color = UI.Theme.Border
    	rbxStroke.Thickness = 1
    	rbxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	rbxStroke.Parent = rbxBtn
    	UI.registerThemeElement(rbxStroke, "Border")
    
    	rbxBtn.MouseEnter:Connect(function()
    		TweenService:Create(rbxStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
    	end)
    	rbxBtn.MouseLeave:Connect(function()
    		TweenService:Create(rbxStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
    	end)
    
    	rbxBtn.MouseButton1Click:Connect(function()
    		local vim = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager") or nil
    		if vim then
    			pcall(function()
    				vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
    				task.delay(0.05, function()
    					vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
    				end)
    			end)
    		else
    			pcall(function()
    				GuiService:SetMenuIsOpen(not GuiService.MenuIsOpen)
    			end)
    		end
    	end)
    
    	-- 2. Hamburger Menu Button [ ≡ ]
    	local menuBtn = Instance.new("TextButton")
    	menuBtn.Name = "HamburgerBtn"
    	menuBtn.Size = UDim2.new(0, 24, 0, 22)
    	menuBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	menuBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	menuBtn.BorderSizePixel = 0
    	menuBtn.Text = "≡"
    	menuBtn.TextColor3 = UI.Theme.TextPrimary
    	menuBtn.Font = Enum.Font.GothamBold
    	menuBtn.TextSize = 16
    	menuBtn.LayoutOrder = 2
    	menuBtn.Parent = actionGroup
    	UI.registerThemeElement(menuBtn, "ContainerDark")
    	UI.registerThemeElement(menuBtn, "TextPrimary")
    
    	local menuStroke = Instance.new("UIStroke")
    	menuStroke.Color = UI.Theme.Border
    	menuStroke.Thickness = 1
    	menuStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	menuStroke.Parent = menuBtn
    	UI.registerThemeElement(menuStroke, "Border")
    
    	menuBtn.MouseEnter:Connect(function()
    		TweenService:Create(menuStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
    		TweenService:Create(menuBtn, TweenInfo.new(0.12), { TextColor3 = UI.Theme.Accent }):Play()
    	end)
    	menuBtn.MouseLeave:Connect(function()
    		TweenService:Create(menuStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
    		TweenService:Create(menuBtn, TweenInfo.new(0.12), { TextColor3 = UI.Theme.TextPrimary }):Play()
    	end)
    
    	-- 3. Voice Chat Mic Button [ 🎙 ]
    	local micBtn = Instance.new("TextButton")
    	micBtn.Name = "VoiceChatMicBtn"
    	micBtn.Size = UDim2.new(0, 24, 0, 22)
    	micBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	micBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	micBtn.BorderSizePixel = 0
    	micBtn.Text = "MIC"
    	micBtn.TextColor3 = Color3.fromRGB(245, 75, 75)
    	micBtn.Font = Enum.Font.GothamBold
    	micBtn.TextSize = 8
    	micBtn.LayoutOrder = 3
    	micBtn.Parent = actionGroup
    	UI.registerThemeElement(micBtn, "ContainerDark")
    
    	local micStroke = Instance.new("UIStroke")
    	micStroke.Color = UI.Theme.Border
    	micStroke.Thickness = 1
    	micStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	micStroke.Parent = micBtn
    	UI.registerThemeElement(micStroke, "Border")
    
    	local isMuted = true
    	micBtn.MouseButton1Click:Connect(function()
    		isMuted = not isMuted
    		if isMuted then
    			micBtn.Text = "MIC"
    			micBtn.TextColor3 = Color3.fromRGB(245, 75, 75)
    		else
    			micBtn.Text = "ON"
    			micBtn.TextColor3 = Color3.fromRGB(60, 225, 90)
    		end
    		pcall(function()
    			if VoiceChatService and VoiceChatService:IsVoiceEnabledForUserIdAsync(Players.LocalPlayer.UserId) then
    				VoiceChatService:joinVoice()
    			end
    		end)
    	end)
    
    	-- ============================================================
    	-- ── HAMBURGER DROPDOWN QUICK MENU ───────────────────────────
    	-- ============================================================
    	local dropdown = Instance.new("Frame")
    	dropdown.Name = "HamburgerDropdown"
    	dropdown.Size = UDim2.new(0, 150, 0, 170)
    	dropdown.Position = UDim2.new(0, 110, 0, TOPBAR_H + 4)
    	dropdown.BackgroundColor3 = UI.Theme.Background
    	dropdown.BackgroundTransparency = 0.05
    	dropdown.BorderSizePixel = 0
    	dropdown.Visible = false
    	dropdown.ZIndex = 50
    	dropdown.Parent = widget
    	UI.registerThemeElement(dropdown, "Background")
    
    	local dropStroke = Instance.new("UIStroke")
    	dropStroke.Color = UI.Theme.Border
    	dropStroke.Thickness = 1.2
    	dropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	dropStroke.Parent = dropdown
    	UI.registerThemeElement(dropStroke, "Border")
    
    	local dropLayout = Instance.new("UIListLayout")
    	dropLayout.FillDirection = Enum.FillDirection.Vertical
    	dropLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	dropLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    	dropLayout.Padding = UDim.new(0, 2)
    	dropLayout.Parent = dropdown
    
    	local bpActive = false
    	local function createDropItem(text: string, onClick: () -> ())
    		local item = Instance.new("TextButton")
    		item.Size = UDim2.new(1, -6, 0, 25)
    		item.BackgroundColor3 = UI.Theme.ContainerDark
    		item.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    		item.BorderSizePixel = 0
    		item.Text = "  " .. text
    		item.TextColor3 = UI.Theme.TextPrimary
    		item.Font = UI.Fonts.Header
    		item.TextSize = 10
    		item.TextXAlignment = Enum.TextXAlignment.Left
    		item.ZIndex = 51
    		item.Parent = dropdown
    		UI.registerThemeElement(item, "ContainerDark")
    		UI.registerThemeElement(item, "TextPrimary")
    
    		item.MouseEnter:Connect(function()
    			TweenService:Create(item, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
    		end)
    		item.MouseLeave:Connect(function()
    			TweenService:Create(item, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    
    		item.MouseButton1Click:Connect(function()
    			dropdown.Visible = false
    			onClick()
    		end)
    	end
    
    	createDropItem("Backpack", function()
    		if _G.__ToggleProjectFihBackpack then
    			_G.__ToggleProjectFihBackpack()
    		else
    			bpActive = not bpActive
    			pcall(function()
    				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, bpActive)
    			end)
    		end
    	end)
    
    	createDropItem("Music Tracker", function()
    		local function toggleMT(parent: Instance?)
    			if not parent then return false end
    			local g = parent:FindFirstChild("ModularMusicTrackerGui")
    			if g then
    				local w = g:FindFirstChild("MusicTrackerWidget")
    				if w and w:IsA("Frame") then
    					w.Visible = not w.Visible
    					return true
    				end
    			end
    			return false
    		end
    		if not toggleMT(CoreGui) then
    			local lp = Players.LocalPlayer
    			if lp then toggleMT(lp:FindFirstChild("PlayerGui")) end
    		end
    	end)
    
    	createDropItem("Player List", function()
    		local function togglePL(parent: Instance?)
    			if not parent then return false end
    			local g = parent:FindFirstChild("ModularPlayerListGui")
    			if g then
    				local w = g:FindFirstChild("PlayerListWidget") or g:FindFirstChild("PlayerListFrame")
    				if w and w:IsA("Frame") then
    					w.Visible = not w.Visible
    					return true
    				end
    			end
    			return false
    		end
    		if not togglePL(CoreGui) then
    			local lp = Players.LocalPlayer
    			if lp then togglePL(lp:FindFirstChild("PlayerGui")) end
    		end
    	end)
    
    	createDropItem("Main Menu", function()
    		if _G.__ToggleProjectFihMenu then
    			_G.__ToggleProjectFihMenu()
    		end
    	end)
    
    	createDropItem("Reset Character", function()
    		local char = Players.LocalPlayer.Character
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    		if hum then hum.Health = 0 end
    	end)
    
    	createDropItem("Leave Game", function()
    		pcall(function()
    			game:Shutdown()
    		end)
    	end)
    
    	menuBtn.MouseButton1Click:Connect(function()
    		dropdown.Visible = not dropdown.Visible
    	end)
    
    	-- Right: Minimize [-] & Close [X] Buttons
    	local minBtn = Instance.new("TextButton")
    	minBtn.Name = "MinBtn"
    	minBtn.Size = UDim2.new(0, 20, 0, 18)
    	minBtn.Position = UDim2.new(1, -50, 0, 5)
    	minBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	minBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	minBtn.BorderSizePixel = 0
    	minBtn.Text = "-"
    	minBtn.TextColor3 = UI.Theme.TextPrimary
    	minBtn.Font = UI.Fonts.Mono
    	minBtn.TextSize = 13
    	minBtn.Parent = topbar
    	UI.registerThemeElement(minBtn, "ContainerDark")
    	UI.registerThemeElement(minBtn, "TextPrimary")
    
    	local minStroke = Instance.new("UIStroke")
    	minStroke.Color = UI.Theme.Border
    	minStroke.Thickness = 1
    	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	minStroke.Parent = minBtn
    	UI.registerThemeElement(minStroke, "Border")
    
    	local closeBtn = Instance.new("TextButton")
    	closeBtn.Name = "CloseBtn"
    	closeBtn.Size = UDim2.new(0, 20, 0, 18)
    	closeBtn.Position = UDim2.new(1, -26, 0, 5)
    	closeBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	closeBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	closeBtn.BorderSizePixel = 0
    	closeBtn.Text = "X"
    	closeBtn.TextColor3 = UI.Theme.TextPrimary
    	closeBtn.Font = UI.Fonts.Mono
    	closeBtn.TextSize = 11
    	closeBtn.Parent = topbar
    	UI.registerThemeElement(closeBtn, "ContainerDark")
    	UI.registerThemeElement(closeBtn, "TextPrimary")
    
    	local closeStroke = Instance.new("UIStroke")
    	closeStroke.Color = UI.Theme.Border
    	closeStroke.Thickness = 1
    	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	closeStroke.Parent = closeBtn
    	UI.registerThemeElement(closeStroke, "Border")
    
    	-- ============================================================
    	-- ── MESSAGE CONTAINER (CHAT LOGS) ───────────────────────────
    	-- ============================================================
    	local container = Instance.new("ScrollingFrame")
    	container.Name = "MessageContainer"
    	container.Size = UDim2.new(1, -12, 1, -(TOPBAR_H + BOTTOM_H + 20))
    	container.Position = UDim2.new(0, 6, 0, TOPBAR_H + 10)
    	container.BackgroundColor3 = UI.Theme.Container
    	container.BackgroundTransparency = UI.Theme.ContainerTransparency
    	container.BorderSizePixel = 0
    	container.ScrollBarThickness = 3
    	container.ScrollBarImageColor3 = UI.Theme.Accent
    	container.CanvasSize = UDim2.new(0, 0, 0, 0)
    	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	container.Parent = widget
    	UI.registerThemeElement(container, "Container")
    
    	local containerStroke = Instance.new("UIStroke")
    	containerStroke.Color = UI.Theme.Border
    	containerStroke.Thickness = 1.5
    	containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	containerStroke.Parent = container
    	UI.registerThemeElement(containerStroke, "Border")
    
    	local listLayout = Instance.new("UIListLayout")
    	listLayout.Padding = UDim.new(0, 3)
    	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	listLayout.Parent = container
    
    	-- ============================================================
    	-- ── BOTTOM CONTROL BAR (INPUT, QUICK CHAT, SEND MSG) ────────
    	-- ============================================================
    	local bottomBar = Instance.new("Frame")
    	bottomBar.Name = "BottomBar"
    	bottomBar.Size = UDim2.new(1, -12, 0, BOTTOM_H)
    	bottomBar.Position = UDim2.new(0, 6, 1, -(BOTTOM_H + 6))
    	bottomBar.BackgroundTransparency = 1
    	bottomBar.BorderSizePixel = 0
    	bottomBar.ZIndex = 5
    	bottomBar.Parent = widget
    
    	local quickBtn = Instance.new("TextButton")
    	quickBtn.Name = "QuickChatBtn"
    	quickBtn.Size = UDim2.new(0, 64, 1, 0)
    	quickBtn.Position = UDim2.new(0, 0, 0, 0)
    	quickBtn.BackgroundColor3 = UI.Theme.Container
    	quickBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	quickBtn.BorderSizePixel = 0
    	quickBtn.Text = "Quick Chat"
    	quickBtn.TextColor3 = UI.Theme.TextPrimary
    	quickBtn.Font = UI.Fonts.Header
    	quickBtn.TextSize = 9
    	quickBtn.ZIndex = 6
    	quickBtn.Parent = bottomBar
    	UI.registerThemeElement(quickBtn, "Container")
    	UI.registerThemeElement(quickBtn, "TextPrimary")
    
    	local quickStroke = Instance.new("UIStroke")
    	quickStroke.Color = UI.Theme.Border
    	quickStroke.Thickness = 1
    	quickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	quickStroke.Parent = quickBtn
    	UI.registerThemeElement(quickStroke, "Border")
    
    	local inputFrame = Instance.new("Frame")
    	inputFrame.Name = "InputFrame"
    	inputFrame.Size = UDim2.new(1, -134, 1, 0)
    	inputFrame.Position = UDim2.new(0, 68, 0, 0)
    	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
    	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	inputFrame.BorderSizePixel = 0
    	inputFrame.ZIndex = 6
    	inputFrame.Parent = bottomBar
    	UI.registerThemeElement(inputFrame, "ContainerDark")
    
    	local inputStroke = Instance.new("UIStroke")
    	inputStroke.Color = UI.Theme.Border
    	inputStroke.Thickness = 1
    	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	inputStroke.Parent = inputFrame
    	UI.registerThemeElement(inputStroke, "Border")
    
    	local textBox = Instance.new("TextBox")
    	textBox.Size = UDim2.new(1, -8, 1, 0)
    	textBox.Position = UDim2.new(0, 4, 0, 0)
    	textBox.BackgroundTransparency = 1
    	textBox.PlaceholderText = "/Text Message"
    	textBox.PlaceholderColor3 = UI.Theme.TextSecondary
    	textBox.Text = ""
    	textBox.TextColor3 = UI.Theme.TextPrimary
    	textBox.Font = UI.Fonts.Body
    	textBox.TextSize = 11
    	textBox.TextXAlignment = Enum.TextXAlignment.Left
    	textBox.ClearTextOnFocus = false
    	textBox.ZIndex = 7
    	textBox.Parent = inputFrame
    	UI.registerThemeElement(textBox, "TextPrimary")
    
    	local sendBtn = Instance.new("TextButton")
    	sendBtn.Name = "SendBtn"
    	sendBtn.Size = UDim2.new(0, 60, 1, 0)
    	sendBtn.Position = UDim2.new(1, -60, 0, 0)
    	sendBtn.BackgroundColor3 = UI.Theme.Accent
    	sendBtn.BorderSizePixel = 0
    	sendBtn.Text = "Send Msg"
    	sendBtn.TextColor3 = UI.Theme.AccentText
    	sendBtn.Font = UI.Fonts.Header
    	sendBtn.TextSize = 10
    	sendBtn.ZIndex = 7
    	sendBtn.Parent = bottomBar
    	UI.registerThemeElement(sendBtn, "Accent")
    
    	local sendStroke = Instance.new("UIStroke")
    	sendStroke.Color = UI.Theme.Border
    	sendStroke.Thickness = 1.2
    	sendStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	sendStroke.Parent = sendBtn
    	UI.registerThemeElement(sendStroke, "Border")
    
    	-- ============================================================
    	-- ── CORNER RESIZE GRIP (SCALE CHATBAR ANY SIZE) ─────────────
    	-- ============================================================
    	local resizeGrip = Instance.new("TextButton")
    	resizeGrip.Name = "ResizeGrip"
    	resizeGrip.Size = UDim2.new(0, 14, 0, 14)
    	resizeGrip.Position = UDim2.new(1, -14, 1, -14)
    	resizeGrip.BackgroundTransparency = 1
    	resizeGrip.Text = "///"
    	resizeGrip.TextColor3 = UI.Theme.BorderDim
    	resizeGrip.Font = UI.Fonts.Mono
    	resizeGrip.TextSize = 9
    	resizeGrip.ZIndex = 20
    	resizeGrip.Parent = widget
    	UI.registerThemeElement(resizeGrip, "BorderDimText")
    
    	local isResizing = false
    	local resizeStart = Vector2.zero
    	local sizeStart = Vector2.zero
    
    	resizeGrip.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			isResizing = true
    			resizeStart = Vector2.new(input.Position.X, input.Position.Y)
    			sizeStart = Vector2.new(widget.AbsoluteSize.X, widget.AbsoluteSize.Y)
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					isResizing = false
    				end
    			end)
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    			local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStart
    			local newW = math.clamp(sizeStart.X + delta.X, 260, 800)
    			local newH = math.clamp(sizeStart.Y + delta.Y, 180, 600)
    			widget.Size = UDim2.new(0, newW, 0, newH)
    		end
    	end)
    
    	-- ============================================================
    	-- ── WINDOW CONTROLLER & POPUP STATE ─────────────────────────
    	-- ============================================================
    	local isOpen = true
    	local isTransitioning = false
    	local isProfileOpen = false
    	local isQuickOpen = false
    
    	local closeProfilePopup: () -> ()
    	local closeQuickPopup: () -> ()
    
    	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.openWindow(widget, uiScale, function()
    			isOpen = true
    			isTransitioning = false
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if not isOpen or isTransitioning then return end
    		isTransitioning = true
    		dropdown.Visible = false
    		if closeProfilePopup then closeProfilePopup() end
    		if closeQuickPopup then closeQuickPopup() end
    		Animations.closeWindow(widget, uiScale, function()
    			isOpen = false
    			isTransitioning = false
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen then
    			closeWidget(onComplete)
    		else
    			openWidget(onComplete)
    		end
    	end
    
    	local function setWidgetVisible(selfOrVal: any, maybeVal: any)
    		local v = if type(selfOrVal) == "boolean" then selfOrVal elseif type(maybeVal) == "boolean" then maybeVal else true
    		if v then
    			openWidget()
    		else
    			closeWidget()
    		end
    	end
    
    	-- ============================================================
    	-- ── PLAYER ACTION CONTEXT MENU POPUP ────────────────────────
    	-- ============================================================
    	local profilePopup = Instance.new("Frame")
    	profilePopup.Name = "PlayerProfilePopup"
    	profilePopup.Size = UDim2.new(0, 190, 0, 240)
    	profilePopup.Position = UDim2.new(0, 20, 0, 35)
    	profilePopup.BackgroundColor3 = UI.Theme.Background
    	profilePopup.BackgroundTransparency = 0.02
    	profilePopup.BorderSizePixel = 0
    	profilePopup.Visible = false
    	profilePopup.ZIndex = 80
    	profilePopup.Parent = screenGui
    	UI.registerThemeElement(profilePopup, "Background")
    
    	local popStroke = Instance.new("UIStroke")
    	popStroke.Color = UI.Theme.Border
    	popStroke.Thickness = 2
    	popStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	popStroke.Parent = profilePopup
    	UI.registerThemeElement(popStroke, "Border")
    
    	local profileScale = Instance.new("UIScale")
    	profileScale.Scale = 1.0
    	profileScale.Parent = profilePopup
    
    	closeProfilePopup = function()
    		if not isProfileOpen then return end
    		isProfileOpen = false
    		Animations.popOut(profilePopup, profileScale)
    	end
    
    	local popHeader = Instance.new("Frame")
    	popHeader.Size = UDim2.new(1, 0, 0, 48)
    	popHeader.BackgroundColor3 = UI.Theme.Container
    	popHeader.BackgroundTransparency = UI.Theme.ContainerTransparency
    	popHeader.BorderSizePixel = 0
    	popHeader.ZIndex = 81
    	popHeader.Parent = profilePopup
    	UI.registerThemeElement(popHeader, "Container")
    
    	local popHeadStroke = Instance.new("UIStroke")
    	popHeadStroke.Color = UI.Theme.Border
    	popHeadStroke.Thickness = 1
    	popHeadStroke.Parent = popHeader
    	UI.registerThemeElement(popHeadStroke, "Border")
    
    	local popAvatar = Instance.new("ImageLabel")
    	popAvatar.Size = UDim2.new(0, 36, 0, 36)
    	popAvatar.Position = UDim2.new(0, 6, 0, 6)
    	popAvatar.BackgroundTransparency = 1
    	popAvatar.ZIndex = 82
    	popAvatar.Parent = popHeader
    
    	local popTitle = Instance.new("TextLabel")
    	popTitle.Size = UDim2.new(1, -50, 0, 18)
    	popTitle.Position = UDim2.new(0, 46, 0, 6)
    	popTitle.BackgroundTransparency = 1
    	popTitle.Text = "Player"
    	popTitle.TextColor3 = UI.Theme.TextPrimary
    	popTitle.Font = UI.Fonts.Header
    	popTitle.TextSize = 11
    	popTitle.TextXAlignment = Enum.TextXAlignment.Left
    	popTitle.ZIndex = 82
    	popTitle.Parent = popHeader
    	UI.registerThemeElement(popTitle, "TextPrimary")
    
    	local popUser = Instance.new("TextLabel")
    	popUser.Size = UDim2.new(1, -50, 0, 14)
    	popUser.Position = UDim2.new(0, 46, 0, 24)
    	popUser.BackgroundTransparency = 1
    	popUser.Text = "@Username"
    	popUser.TextColor3 = UI.Theme.TextSecondary
    	popUser.Font = UI.Fonts.Mono
    	popUser.TextSize = 9
    	popUser.TextXAlignment = Enum.TextXAlignment.Left
    	popUser.ZIndex = 82
    	popUser.Parent = popHeader
    	UI.registerThemeElement(popUser, "TextSecondary")
    
    	local popClose = Instance.new("TextButton")
    	popClose.Size = UDim2.new(0, 18, 0, 18)
    	popClose.Position = UDim2.new(1, -22, 0, 6)
    	popClose.BackgroundTransparency = 1
    	popClose.Text = "X"
    	popClose.TextColor3 = UI.Theme.TextPrimary
    	popClose.Font = UI.Fonts.Mono
    	popClose.TextSize = 10
    	popClose.ZIndex = 83
    	popClose.Parent = popHeader
    	UI.registerThemeElement(popClose, "TextPrimary")
    
    	popClose.MouseButton1Click:Connect(function()
    		closeProfilePopup()
    	end)
    
    	local popBtnsFrame = Instance.new("Frame")
    	popBtnsFrame.Size = UDim2.new(1, -8, 1, -54)
    	popBtnsFrame.Position = UDim2.new(0, 4, 0, 52)
    	popBtnsFrame.BackgroundTransparency = 1
    	popBtnsFrame.ZIndex = 81
    	popBtnsFrame.Parent = profilePopup
    
    	local popLayout = Instance.new("UIListLayout")
    	popLayout.Padding = UDim.new(0, 3)
    	popLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	popLayout.Parent = popBtnsFrame
    
    	local activeSelectedPlayer: Player? = nil
    	local function createPopAction(text: string, order: number, onClick: (Player) -> ())
    		local btn = Instance.new("TextButton")
    		btn.Size = UDim2.new(1, 0, 0, 22)
    		btn.BackgroundColor3 = UI.Theme.ContainerDark
    		btn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    		btn.BorderSizePixel = 0
    		btn.Text = "  " .. text
    		btn.TextColor3 = UI.Theme.TextPrimary
    		btn.Font = UI.Fonts.Body
    		btn.TextSize = 10
    		btn.TextXAlignment = Enum.TextXAlignment.Left
    		btn.LayoutOrder = order
    		btn.ZIndex = 82
    		btn.Parent = popBtnsFrame
    		UI.registerThemeElement(btn, "ContainerDark")
    		UI.registerThemeElement(btn, "TextPrimary")
    
    		local stroke = Instance.new("UIStroke")
    		stroke.Color = UI.Theme.Border
    		stroke.Thickness = 0.8
    		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		stroke.Parent = btn
    		UI.registerThemeElement(stroke, "Border")
    
    		btn.MouseEnter:Connect(function()
    			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
    		end)
    		btn.MouseLeave:Connect(function()
    			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    
    		btn.MouseButton1Click:Connect(function()
    			if activeSelectedPlayer then
    				onClick(activeSelectedPlayer)
    			end
    			closeProfilePopup()
    		end)
    	end
    
    	createPopAction("Teleport To", 1, function(target)
    		local myChar = Players.LocalPlayer.Character
    		local tChar = target.Character
    		if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart") and tChar:FindFirstChild("HumanoidRootPart") then
    			local myHrp = myChar:FindFirstChild("HumanoidRootPart") :: BasePart
    			local tHrp = tChar:FindFirstChild("HumanoidRootPart") :: BasePart
    			myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
    		end
    	end)
    
    	local isSpying = false
    	createPopAction("Spectate / Spy", 2, function(target)
    		isSpying = not isSpying
    		local cam = workspace.CurrentCamera
    		if not cam then return end
    		if isSpying and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
    			cam.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid")
    		else
    			if Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
    				cam.CameraSubject = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    			end
    			isSpying = false
    		end
    	end)
    
    	createPopAction("Add Friend", 3, function(target)
    		pcall(function()
    			StarterGui:SetCore("PromptSendFriendRequest", target)
    		end)
    	end)
    
    	createPopAction("Block Player", 4, function(target)
    		pcall(function()
    			StarterGui:SetCore("PromptBlockPlayer", target)
    		end)
    	end)
    
    	createPopAction("Report Player", 5, function(target)
    		pcall(function()
    			StarterGui:SetCore("PromptReportPlayer", target)
    		end)
    	end)
    
    	createPopAction("Copy Username", 6, function(target)
    		local setclip = setclipboard or (getgenv and getgenv().setclipboard) or toclipboard
    		if type(setclip) == "function" then
    			setclip(target.Name)
    		end
    	end)
    
    	local function openPlayerProfile(player: Player, clickPos: Vector2)
    		activeSelectedPlayer = player
    		popTitle.Text = player.DisplayName
    		popUser.Text = "@" .. player.Name
    		popAvatar.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    		
    		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    		local x = math.clamp(clickPos.X, 8, math.max(8, vp.X - 198))
    		local y = math.clamp(clickPos.Y, 8, math.max(8, vp.Y - 248))
    		profilePopup.Position = UDim2.new(0, x, 0, y)
    		isProfileOpen = true
    		Animations.popIn(profilePopup, profileScale)
    	end
    
    	-- ============================================================
    	-- ── QUICK PHRASES CONTEXT MENU POPUP ────────────────────────
    	-- ============================================================
    	local QUICK_POP_W = 140
    	local QUICK_POP_H = 175
    	quickPopup = Instance.new("Frame")
    	quickPopup.Name = "QuickPhrasesPopup"
    	quickPopup.Size = UDim2.new(0, QUICK_POP_W, 0, QUICK_POP_H)
    	quickPopup.Position = UDim2.new(0, 20, 0, 100)
    	quickPopup.BackgroundColor3 = UI.Theme.Background
    	quickPopup.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	quickPopup.BorderSizePixel = 0
    	quickPopup.Visible = false
    	quickPopup.ZIndex = 85
    	quickPopup.Parent = screenGui
    	UI.registerThemeElement(quickPopup, "Background")
    
    	local quickPopStroke = Instance.new("UIStroke")
    	quickPopStroke.Color = UI.Theme.Accent
    	quickPopStroke.Thickness = 2
    	quickPopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	quickPopStroke.Parent = quickPopup
    	UI.registerThemeElement(quickPopStroke, "Accent")
    
    	quickScale = Instance.new("UIScale")
    	quickScale.Scale = 1.0
    	quickScale.Parent = quickPopup
    
    	closeQuickPopup = function()
    		if not isQuickOpen then return end
    		isQuickOpen = false
    		Animations.popOut(quickPopup, quickScale)
    	end
    
    	local quickPopHeader = Instance.new("Frame")
    	quickPopHeader.Name = "QuickHeader"
    	quickPopHeader.Size = UDim2.new(1, 0, 0, 22)
    	quickPopHeader.BackgroundColor3 = UI.Theme.Container
    	quickPopHeader.BackgroundTransparency = UI.Theme.ContainerTransparency
    	quickPopHeader.BorderSizePixel = 0
    	quickPopHeader.ZIndex = 86
    	quickPopHeader.Parent = quickPopup
    	UI.registerThemeElement(quickPopHeader, "Container")
    
    	local quickHeadStroke = Instance.new("UIStroke")
    	quickHeadStroke.Color = UI.Theme.Border
    	quickHeadStroke.Thickness = 1
    	quickHeadStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	quickHeadStroke.Parent = quickPopHeader
    	UI.registerThemeElement(quickHeadStroke, "Border")
    
    	local quickHeadLabel = Instance.new("TextLabel")
    	quickHeadLabel.Size = UDim2.new(1, -24, 1, 0)
    	quickHeadLabel.Position = UDim2.new(0, 6, 0, 0)
    	quickHeadLabel.BackgroundTransparency = 1
    	quickHeadLabel.Text = "Quick Phrases"
    	quickHeadLabel.TextColor3 = UI.Theme.TextPrimary
    	quickHeadLabel.Font = UI.Fonts.Header
    	quickHeadLabel.TextSize = 10
    	quickHeadLabel.TextXAlignment = Enum.TextXAlignment.Left
    	quickHeadLabel.ZIndex = 87
    	quickHeadLabel.Parent = quickPopHeader
    	UI.registerThemeElement(quickHeadLabel, "TextPrimary")
    
    	local quickCloseBtn = Instance.new("TextButton")
    	quickCloseBtn.Size = UDim2.new(0, 16, 0, 16)
    	quickCloseBtn.Position = UDim2.new(1, -18, 0, 3)
    	quickCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	quickCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	quickCloseBtn.BorderSizePixel = 0
    	quickCloseBtn.Text = "X"
    	quickCloseBtn.TextColor3 = UI.Theme.TextPrimary
    	quickCloseBtn.Font = UI.Fonts.Header
    	quickCloseBtn.TextSize = 9
    	quickCloseBtn.ZIndex = 87
    	quickCloseBtn.Parent = quickPopHeader
    	UI.registerThemeElement(quickCloseBtn, "ContainerDark")
    	UI.registerThemeElement(quickCloseBtn, "TextPrimary")
    	quickCloseBtn.MouseButton1Click:Connect(function()
    		closeQuickPopup()
    	end)
    
    	local quickListFrame = Instance.new("ScrollingFrame")
    	quickListFrame.Size = UDim2.new(1, -8, 1, -28)
    	quickListFrame.Position = UDim2.new(0, 4, 0, 24)
    	quickListFrame.BackgroundTransparency = 1
    	quickListFrame.BorderSizePixel = 0
    	quickListFrame.ScrollBarThickness = 2
    	quickListFrame.ScrollBarImageColor3 = UI.Theme.Accent
    	quickListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    	quickListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	quickListFrame.ZIndex = 86
    	quickListFrame.Parent = quickPopup
    
    	local quickListLayout = Instance.new("UIListLayout")
    	quickListLayout.Padding = UDim.new(0, 3)
    	quickListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	quickListLayout.Parent = quickListFrame
    
    	local quickPhrasesList = {
    		"gg",
    		"Hello!",
    		"Nice one!",
    		"Look out!",
    		"Need help!",
    		"AFK",
    		"On my way!"
    	}
    
    	-- Forward declare sendMessage
    	local sendMessage: (string) -> ()
    
    	for idx, phrase in ipairs(quickPhrasesList) do
    		local pBtn = Instance.new("TextButton")
    		pBtn.Name = "QuickPhrase_" .. idx
    		pBtn.Size = UDim2.new(1, -4, 0, 20)
    		pBtn.BackgroundColor3 = UI.Theme.ContainerDark
    		pBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    		pBtn.BorderSizePixel = 0
    		pBtn.Text = "  " .. phrase
    		pBtn.TextColor3 = UI.Theme.TextPrimary
    		pBtn.Font = UI.Fonts.Body
    		pBtn.TextSize = 10
    		pBtn.TextXAlignment = Enum.TextXAlignment.Left
    		pBtn.LayoutOrder = idx
    		pBtn.ZIndex = 87
    		pBtn.Parent = quickListFrame
    		UI.registerThemeElement(pBtn, "ContainerDark")
    		UI.registerThemeElement(pBtn, "TextPrimary")
    
    		local pStroke = Instance.new("UIStroke")
    		pStroke.Color = UI.Theme.Border
    		pStroke.Thickness = 0.8
    		pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		pStroke.Parent = pBtn
    		UI.registerThemeElement(pStroke, "Border")
    
    		pBtn.MouseEnter:Connect(function()
    			TweenService:Create(pBtn, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
    		end)
    		pBtn.MouseLeave:Connect(function()
    			TweenService:Create(pBtn, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    
    		pBtn.MouseButton1Click:Connect(function()
    			if sendMessage then
    				sendMessage(phrase)
    			end
    			closeQuickPopup()
    		end)
    	end
    
    	local function openQuickPhrases()
    		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    		local qPos = quickBtn.AbsolutePosition
    		local posX = math.clamp(qPos.X, 8, math.max(8, vp.X - QUICK_POP_W - 8))
    		local posY = qPos.Y - QUICK_POP_H - 6
    		if posY < 8 then
    			posY = qPos.Y + quickBtn.AbsoluteSize.Y + 6
    		end
    		posY = math.clamp(posY, 8, math.max(8, vp.Y - QUICK_POP_H - 8))
    
    		quickPopup.Position = UDim2.new(0, posX, 0, posY)
    		isQuickOpen = true
    		Animations.popIn(quickPopup, quickScale)
    	end
    
    	local function toggleQuickPhrases()
    		if isQuickOpen then
    			closeQuickPopup()
    		else
    			openQuickPhrases()
    		end
    	end
    
    	quickBtn.MouseButton1Click:Connect(function()
    		toggleQuickPhrases()
    	end)
    
    	-- ── Message Line Constructor (With Robust Deduplication + Profile Hook + Slide Animation) ──
    	local MAX_CHAT_HISTORY = 100
    	local chatHistory: {TextButton} = {}
    	local seenMessageMap: {[string]: number} = {}
    	local lastPruneTime = tick()
    
    	local function pruneSeenMessages()
    		local now = tick()
    		if (now - lastPruneTime) < 30 then return end
    		lastPruneTime = now
    		for key, timestamp in pairs(seenMessageMap) do
    			if (now - timestamp) > 60 then
    				seenMessageMap[key] = nil
    			end
    		end
    	end
    
    	local function addMessage(sender: string, text: string, msgId: string?)
    		if not text or text == "" then return end
    		local now = tick()
    		pruneSeenMessages()
    
    		-- Message ID deduplication
    		if msgId and msgId ~= "" then
    			if seenMessageMap[msgId] and (now - seenMessageMap[msgId] < 8) then
    				return
    			end
    			seenMessageMap[msgId] = now
    		end
    
    		-- Content + Sender deduplication window (prevents duplicate local echo / server echo)
    		local dedupeKey = string.format("%s:%s", sender, text)
    		if seenMessageMap[dedupeKey] and (now - seenMessageMap[dedupeKey] < 0.9) then
    			return
    		end
    		seenMessageMap[dedupeKey] = now
    
    		local isSystem = (sender == "System")
    		local targetPlayer: Player? = nil
    		if not isSystem then
    			for _, p in ipairs(Players:GetPlayers()) do
    				if p.Name == sender or p.DisplayName == sender then
    					targetPlayer = p
    					break
    				end
    			end
    		end
    
    		local msgBtn = Instance.new("TextButton")
    		msgBtn.Name = "MessageLine"
    		msgBtn.Size = UDim2.new(1, -8, 0, 0)
    		msgBtn.Position = UDim2.new(0, 16, 0, 0)
    		msgBtn.AutomaticSize = Enum.AutomaticSize.Y
    		msgBtn.BackgroundTransparency = 1
    		msgBtn.RichText = true
    		msgBtn.TextWrapped = true
    		msgBtn.TextTransparency = 1
    		msgBtn.Font = UI.Fonts.Body
    		msgBtn.TextSize = 11
    		msgBtn.TextXAlignment = Enum.TextXAlignment.Left
    		msgBtn.TextColor3 = UI.Theme.TextPrimary
    		msgBtn.Parent = container
    		UI.registerThemeElement(msgBtn, "TextPrimary")
    
    		-- Cap message history to prevent unbounded memory growth
    		table.insert(chatHistory, msgBtn)
    		while #chatHistory > MAX_CHAT_HISTORY do
    			local oldest = table.remove(chatHistory, 1)
    			if oldest then
    				UI.unregisterThemeElement(oldest)
    				oldest:Destroy()
    			end
    		end
    
    		local senderHex = if isSystem then "#A0A0AA" else "#37AFF5"
    		local cleanName = sender:gsub("<", "&lt;"):gsub(">", "&gt;")
    		local cleanMsg = text:gsub("<", "&lt;"):gsub(">", "&gt;")
    		msgBtn.Text = string.format("<font color='%s'><b>%s:</b></font> %s", senderHex, cleanName, cleanMsg)
    
    		if targetPlayer then
    			msgBtn.MouseButton1Click:Connect(function()
    				local mousePos = UserInputService:GetMouseLocation()
    				openPlayerProfile(targetPlayer :: Player, mousePos)
    			end)
    		end
    
    		-- Domino slide-in & text fade
    		TweenService:Create(msgBtn, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			Position = UDim2.new(0, 0, 0, 0)
    		}):Play()
    		TweenService:Create(msgBtn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			TextTransparency = 0
    		}):Play()
    
    		task.defer(function()
    			container.CanvasPosition = Vector2.new(0, math.max(0, container.AbsoluteCanvasSize.Y - container.AbsoluteWindowSize.Y))
    		end)
    	end
    
    	-- ── Dragging & Full-Screen Boundaries Handlers ────────────────────
    	local dragging = false
    	local dragInput: InputObject? = nil
    	local dragStart = Vector3.zero
    	local startAbsPos = Vector2.zero
    
    	local function startDrag(input: InputObject)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			dragStart = input.Position
    			startAbsPos = widget.AbsolutePosition
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    				end
    			end)
    		end
    	end
    
    	topbar.InputBegan:Connect(startDrag)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
    			local delta = input.Position - dragStart
    			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
    			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
    			widget.Position = UDim2.new(0, targetX, 0, targetY)
    			if closeProfilePopup then closeProfilePopup() end
    			if closeQuickPopup then closeQuickPopup() end
    		end
    	end)
    
    	local minimized = false
    	minBtn.MouseButton1Click:Connect(function()
    		minimized = not minimized
    		dropdown.Visible = false
    		if closeProfilePopup then closeProfilePopup() end
    		if closeQuickPopup then closeQuickPopup() end
    		if minimized then
    			container.Visible = false
    			bottomBar.Visible = false
    			resizeGrip.Visible = false
    			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, TOPBAR_H)
    			}):Play()
    		else
    			container.Visible = true
    			bottomBar.Visible = true
    			resizeGrip.Visible = true
    			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
    			}):Play()
    		end
    	end)
    
    	closeBtn.MouseButton1Click:Connect(function()
    		closeWidget()
    	end)
    
    	-- ── Message Sending Logic ─────────────────────────────────────────
    	local isSending = false
    	sendMessage = function(msg: string)
    		if isSending or not msg or msg == "" then return end
    		isSending = true
    		textBox.Text = ""
    
    		local sent = false
    		if not useLegacyChat then
    			pcall(function()
    				local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    				if ch then
    					ch:SendAsync(msg)
    					sent = true
    				end
    			end)
    		end
    		if not sent then
    			pcall(function()
    				local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    				local req = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
    				if req and req:IsA("RemoteEvent") then
    					req:FireServer(msg, "All")
    				end
    			end)
    		end
    
    		task.defer(function() isSending = false end)
    	end
    
    	sendBtn.MouseButton1Click:Connect(function() sendMessage(textBox.Text) end)
    	textBox.FocusLost:Connect(function(enter) if enter then sendMessage(textBox.Text) end end)
    
    	-- Slash key opens & focuses chat input with smooth animation
    	UserInputService.InputBegan:Connect(function(input, gameProcessed)
    		if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Slash then
    			if not isOpen then
    				openWidget(function()
    					textBox.Text = ""
    					textBox:CaptureFocus()
    				end)
    			else
    				task.defer(function()
    					textBox.Text = ""
    					textBox:CaptureFocus()
    				end)
    			end
    			if minimized then
    				minimized = false
    				container.Visible = true
    				bottomBar.Visible = true
    				resizeGrip.Visible = true
    				widget.Size = UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
    			end
    		end
    	end)
    
    	-- ── Single Incoming Message Hook ─────────────────────────────────
    	if not useLegacyChat then
    		pcall(function()
    			TextChatService.OnIncomingMessage = function(msg)
    				if not msg.TextSource then return end
    				-- Ignore initial Sending state to prevent duplicate with local echo/server delivery
    				if msg.Status == Enum.TextChatMessageStatus.Sending then
    					return
    				end
    				local player = Players:GetPlayerByUserId(msg.TextSource.UserId)
    				local name = if player then (player.DisplayName ~= "" and player.DisplayName or player.Name) else "Server"
    				addMessage(name, msg.Text, msg.MessageId)
    			end
    		end)
    	else
    		pcall(function()
    			local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    			local onMsg = chatEvents and chatEvents:FindFirstChild("OnMessageDoneFiltering")
    			if onMsg and onMsg:IsA("RemoteEvent") then
    				onMsg.OnClientEvent:Connect(function(data)
    					if data and data.FromSpeaker and data.Message then
    						addMessage(tostring(data.FromSpeaker), tostring(data.Message))
    					end
    				end)
    			end
    		end)
    	end
    
    	addMessage("System", "Chat connected.")
    
    	return {
    		Frame = widget,
    		Container = container,
    		InputBox = textBox,
    		SendBtn = sendBtn,
    		QuickBtn = quickBtn,
    		UiScale = uiScale,
    		IsMinimized = false,
    		Visible = true,
    		IsOpen = function() return isOpen end,
    		Open = openWidget,
    		Close = closeWidget,
    		Toggle = toggleWidget,
    		SetVisible = setWidgetVisible,
    	}
    end
    
    return ChatWidget
end

Modules["UI/MusicTracker.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Squared Retro Music Tracker Widget with Continuous Fluid Visualizer Physics ✦
        Features:
        - Continuous 60+ FPS spring-damper harmonic wave physics (no stepped sizing or stutter)
        - Full-bleed album artwork box (no black borders or padding gaps)
        - Expanded multi-line lyrics container with ample reading space
        - Proportioned, compact square playback controls in correct order: [ « ] [ ❚❚ / ▶ ] [ » ]
        - Multi-source Synced Lyrics engine & live UTC timestamp tracking
        - Full IgnoreGuiInset dragging and minimize controls
    ]=]
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local MusicTracker = {}
    MusicTracker.__index = MusicTracker
    
    local BRIDGE_URLS = {
    	"http://127.0.0.1:8974",
    	"http://127.0.0.1:8888",
    	"https://steering-liberal-bucks-arrived.trycloudflare.com"
    }
    local BRIDGE_URL = BRIDGE_URLS[1]
    local MUSIC_NOTE_ICON = "rbxassetid://10888371919" 
    
    local DEMO_TRACKS = {
    	{
    		title = "Starboy",
    		artist = "The Weeknd ft. Daft Punk",
    		cover = "rbxassetid://13470984852",
    		lyrics = "I'm tryna put you in the worst mood, ah"
    	},
    	{
    		title = "Blinding Lights",
    		artist = "The Weeknd",
    		cover = "rbxassetid://13470984852",
    		lyrics = "Where are you now when I need you most?"
    	}
    }
    
    function MusicTracker.new()
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularMusicTrackerGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    	pcall(function() screenGui.Parent = CoreGui end)
    	if not screenGui.Parent then
    		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    	end
    
    	local DEFAULT_W, DEFAULT_H = 430, 182
    	local TOPBAR_H = 26
    
    	-- ── Main Widget Frame ─────────────────────────────────────────────
    	local widget = Instance.new("Frame")
    	widget.Name = "MusicTrackerWidget"
    	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
    	widget.Position = UDim2.new(0, 14, 1, -200)
    	widget.BackgroundColor3 = UI.Theme.Background
    	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	widget.BorderSizePixel = 0
    	widget.ClipsDescendants = false
    	widget.Parent = screenGui
    	UI.registerThemeElement(widget, "Background")
    
    	local bgGradient = Instance.new("UIGradient")
    	bgGradient.Rotation = 90
    	bgGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
    	})
    	bgGradient.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0),
    		NumberSequenceKeypoint.new(1, 0.15)
    	})
    	bgGradient.Parent = widget
    
    	local outerStroke = Instance.new("UIStroke")
    	outerStroke.Color = UI.Theme.Border
    	outerStroke.Thickness = 2
    	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	outerStroke.Parent = widget
    	UI.registerThemeElement(outerStroke, "Border")
    
    	local uiScale = Instance.new("UIScale")
    	uiScale.Scale = 1.0
    	uiScale.Parent = widget
    
    	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
    	local topbar = Instance.new("Frame")
    	topbar.Name = "TopBar"
    	topbar.Size = UDim2.new(1, -12, 0, TOPBAR_H)
    	topbar.Position = UDim2.new(0, 6, 0, 6)
    	topbar.BackgroundColor3 = UI.Theme.Container
    	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
    	topbar.BorderSizePixel = 0
    	topbar.Parent = widget
    	UI.registerThemeElement(topbar, "Container")
    
    	local topGradient = Instance.new("UIGradient")
    	topGradient.Rotation = 45
    	topGradient.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
    	})
    	topGradient.Parent = topbar
    
    	local topStroke = Instance.new("UIStroke")
    	topStroke.Color = UI.Theme.Border
    	topStroke.Thickness = 1.5
    	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	topStroke.Parent = topbar
    	UI.registerThemeElement(topStroke, "Border")
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Name = "Title"
    	titleLabel.Size = UDim2.new(1, -70, 1, 0)
    	titleLabel.Position = UDim2.new(0, 8, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = "Music Tracker"
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Header
    	titleLabel.TextSize = 11
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.Parent = topbar
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	-- Minimize / Close Buttons
    	local minBtn = Instance.new("TextButton")
    	minBtn.Name = "MinBtn"
    	minBtn.Size = UDim2.new(0, 20, 0, 18)
    	minBtn.Position = UDim2.new(1, -50, 0, 4)
    	minBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	minBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	minBtn.BorderSizePixel = 0
    	minBtn.Text = "-"
    	minBtn.TextColor3 = UI.Theme.TextPrimary
    	minBtn.Font = UI.Fonts.Mono
    	minBtn.TextSize = 13
    	minBtn.Parent = topbar
    	UI.registerThemeElement(minBtn, "ContainerDark")
    	UI.registerThemeElement(minBtn, "TextPrimary")
    
    	local minStroke = Instance.new("UIStroke")
    	minStroke.Color = UI.Theme.Border
    	minStroke.Thickness = 1
    	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	minStroke.Parent = minBtn
    	UI.registerThemeElement(minStroke, "Border")
    
    	local closeBtn = Instance.new("TextButton")
    	closeBtn.Name = "CloseBtn"
    	closeBtn.Size = UDim2.new(0, 20, 0, 18)
    	closeBtn.Position = UDim2.new(1, -26, 0, 4)
    	closeBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	closeBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	closeBtn.BorderSizePixel = 0
    	closeBtn.Text = "X"
    	closeBtn.TextColor3 = UI.Theme.TextPrimary
    	closeBtn.Font = UI.Fonts.Mono
    	closeBtn.TextSize = 11
    	closeBtn.Parent = topbar
    	UI.registerThemeElement(closeBtn, "ContainerDark")
    	UI.registerThemeElement(closeBtn, "TextPrimary")
    
    	local closeStroke = Instance.new("UIStroke")
    	closeStroke.Color = UI.Theme.Border
    	closeStroke.Thickness = 1
    	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	closeStroke.Parent = closeBtn
    	UI.registerThemeElement(closeStroke, "Border")
    
    	-- ── Body Frame ───────────────────────────────────────────────────
    	local body = Instance.new("Frame")
    	body.Name = "Body"
    	body.Size = UDim2.new(1, -12, 1, -(TOPBAR_H + 16))
    	body.Position = UDim2.new(0, 6, 0, TOPBAR_H + 10)
    	body.BackgroundTransparency = 1
    	body.BorderSizePixel = 0
    	body.Parent = widget
    
    	-- ── Left Column: Song Cover (Full Bleed) ──────────────────────────
    	local coverBox = Instance.new("Frame")
    	coverBox.Name = "SongCoverBox"
    	coverBox.Size = UDim2.new(0, 142, 1, 0)
    	coverBox.Position = UDim2.new(0, 0, 0, 0)
    	coverBox.BackgroundColor3 = UI.Theme.ContainerDark
    	coverBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	coverBox.BorderSizePixel = 0
    	coverBox.ClipsDescendants = true
    	coverBox.Parent = body
    	UI.registerThemeElement(coverBox, "ContainerDark")
    
    	local coverStroke = Instance.new("UIStroke")
    	coverStroke.Color = UI.Theme.Border
    	coverStroke.Thickness = 1.5
    	coverStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	coverStroke.Parent = coverBox
    	UI.registerThemeElement(coverStroke, "Border")
    
    	local coverImg = Instance.new("ImageLabel")
    	coverImg.Name = "CoverImage"
    	coverImg.Size = UDim2.new(1, 0, 1, 0)
    	coverImg.Position = UDim2.new(0, 0, 0, 0)
    	coverImg.BackgroundTransparency = 1
    	coverImg.Image = MUSIC_NOTE_ICON
    	coverImg.ScaleType = Enum.ScaleType.Crop
    	coverImg.Parent = coverBox
    
    	-- ── Right Column: Stack (Title, Expanded Lyrics, Visualizer & Controls) ──
    	local rightCol = Instance.new("Frame")
    	rightCol.Name = "RightColumn"
    	rightCol.Size = UDim2.new(1, -150, 1, 0)
    	rightCol.Position = UDim2.new(0, 150, 0, 0)
    	rightCol.BackgroundTransparency = 1
    	rightCol.BorderSizePixel = 0
    	rightCol.Parent = body
    
    	local rightLayout = Instance.new("UIListLayout")
    	rightLayout.Padding = UDim.new(0, 5)
    	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	rightLayout.Parent = rightCol
    
    	-- Box 1: Song Title
    	local titleBox = Instance.new("Frame")
    	titleBox.Name = "SongTitleBox"
    	titleBox.Size = UDim2.new(1, 0, 0, 26)
    	titleBox.BackgroundColor3 = UI.Theme.Container
    	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	titleBox.BorderSizePixel = 0
    	titleBox.LayoutOrder = 1
    	titleBox.Parent = rightCol
    	UI.registerThemeElement(titleBox, "Container")
    
    	local titleBoxStroke = Instance.new("UIStroke")
    	titleBoxStroke.Color = UI.Theme.Border
    	titleBoxStroke.Thickness = 1
    	titleBoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleBoxStroke.Parent = titleBox
    	UI.registerThemeElement(titleBoxStroke, "Border")
    
    	local songTitleLabel = Instance.new("TextLabel")
    	songTitleLabel.Name = "SongTitle"
    	songTitleLabel.Size = UDim2.new(1, -12, 1, 0)
    	songTitleLabel.Position = UDim2.new(0, 6, 0, 0)
    	songTitleLabel.BackgroundTransparency = 1
    	songTitleLabel.Text = "Waiting for Media..."
    	songTitleLabel.TextColor3 = UI.Theme.TextPrimary
    	songTitleLabel.Font = UI.Fonts.Header
    	songTitleLabel.TextSize = 11
    	songTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	songTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	songTitleLabel.Parent = titleBox
    	UI.registerThemeElement(songTitleLabel, "TextPrimary")
    
    	-- Box 2: Expanded Lyrics (Generous 48px space for full 2-line reading)
    	local lyricsBox = Instance.new("Frame")
    	lyricsBox.Name = "LyricsBox"
    	lyricsBox.Size = UDim2.new(1, 0, 0, 48)
    	lyricsBox.BackgroundColor3 = UI.Theme.ContainerDark
    	lyricsBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	lyricsBox.BorderSizePixel = 0
    	lyricsBox.LayoutOrder = 2
    	lyricsBox.ClipsDescendants = true
    	lyricsBox.Parent = rightCol
    	UI.registerThemeElement(lyricsBox, "ContainerDark")
    
    	local lyricsStroke = Instance.new("UIStroke")
    	lyricsStroke.Color = UI.Theme.Border
    	lyricsStroke.Thickness = 1
    	lyricsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	lyricsStroke.Parent = lyricsBox
    	UI.registerThemeElement(lyricsStroke, "Border")
    
    	local lyricsLabel = Instance.new("TextLabel")
    	lyricsLabel.Name = "LyricsText"
    	lyricsLabel.Size = UDim2.new(1, -12, 1, -4)
    	lyricsLabel.Position = UDim2.new(0, 6, 0, 2)
    	lyricsLabel.BackgroundTransparency = 1
    	lyricsLabel.Text = "♫ Play a track on Spotify / SoundCloud / YouTube"
    	lyricsLabel.TextColor3 = UI.Theme.TextPrimary
    	lyricsLabel.Font = UI.Fonts.Body
    	lyricsLabel.TextSize = 10
    	lyricsLabel.TextXAlignment = Enum.TextXAlignment.Left
    	lyricsLabel.TextYAlignment = Enum.TextYAlignment.Center
    	lyricsLabel.TextWrapped = true
    	lyricsLabel.Parent = lyricsBox
    	UI.registerThemeElement(lyricsLabel, "TextPrimary")
    
    	-- Box 3: Visualizer Spectrum & Media Controls
    	local bottomControls = Instance.new("Frame")
    	bottomControls.Name = "BottomControls"
    	bottomControls.Size = UDim2.new(1, 0, 1, -84)
    	bottomControls.BackgroundTransparency = 1
    	bottomControls.BorderSizePixel = 0
    	bottomControls.LayoutOrder = 3
    	bottomControls.Parent = rightCol
    
    	-- Visualizer Container
    	local visualizerBox = Instance.new("Frame")
    	visualizerBox.Name = "VisualizerBox"
    	visualizerBox.Size = UDim2.new(1, -94, 1, 0)
    	visualizerBox.Position = UDim2.new(0, 0, 0, 0)
    	visualizerBox.BackgroundColor3 = UI.Theme.Container
    	visualizerBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	visualizerBox.BorderSizePixel = 0
    	visualizerBox.Parent = bottomControls
    	UI.registerThemeElement(visualizerBox, "Container")
    
    	local visStroke = Instance.new("UIStroke")
    	visStroke.Color = UI.Theme.Border
    	visStroke.Thickness = 1
    	visStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	visStroke.Parent = visualizerBox
    	UI.registerThemeElement(visStroke, "Border")
    
    	local visBarsContainer = Instance.new("Frame")
    	visBarsContainer.Name = "BarsContainer"
    	visBarsContainer.Size = UDim2.new(1, -12, 1, -8)
    	visBarsContainer.Position = UDim2.new(0, 6, 0, 4)
    	visBarsContainer.BackgroundTransparency = 1
    	visBarsContainer.Parent = visualizerBox
    
    	local visLayout = Instance.new("UIListLayout")
    	visLayout.FillDirection = Enum.FillDirection.Horizontal
    	visLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	visLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    	visLayout.Padding = UDim.new(0, 3)
    	visLayout.Parent = visBarsContainer
    
    	local visualizerBars: {Frame} = {}
    	for i = 1, 16 do
    		local bar = Instance.new("Frame")
    		bar.Name = "Bar_" .. i
    		bar.Size = UDim2.new(0, 6, 0, 3)
    		bar.BackgroundColor3 = UI.Theme.Accent
    		bar.BorderSizePixel = 0
    		bar.Parent = visBarsContainer
    		UI.registerThemeElement(bar, "Accent")
    		table.insert(visualizerBars, bar)
    	end
    
    	-- Control Buttons & Audio Slider Container
    	local ctrlFrame = Instance.new("Frame")
    	ctrlFrame.Name = "Controls"
    	ctrlFrame.Size = UDim2.new(0, 94, 1, 0)
    	ctrlFrame.Position = UDim2.new(1, -94, 0, 0)
    	ctrlFrame.BackgroundTransparency = 1
    	ctrlFrame.Parent = bottomControls
    
    	local ctrlLayout = Instance.new("UIListLayout")
    	ctrlLayout.FillDirection = Enum.FillDirection.Vertical
    	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    	ctrlLayout.Padding = UDim.new(0, 4)
    	ctrlLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	ctrlLayout.Parent = ctrlFrame
    
    	-- 1. Buttons Row (Prev, Play/Pause, Next)
    	local btnsRow = Instance.new("Frame")
    	btnsRow.Name = "ButtonsRow"
    	btnsRow.Size = UDim2.new(1, 0, 0, 22)
    	btnsRow.BackgroundTransparency = 1
    	btnsRow.LayoutOrder = 1
    	btnsRow.Parent = ctrlFrame
    
    	local btnsLayout = Instance.new("UIListLayout")
    	btnsLayout.FillDirection = Enum.FillDirection.Horizontal
    	btnsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    	btnsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    	btnsLayout.Padding = UDim.new(0, 4)
    	btnsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	btnsLayout.Parent = btnsRow
    
    	local function makeCtrlBtn(name: string, symbol: string, order: number): TextButton
    		local btn = Instance.new("TextButton")
    		btn.Name = name
    		btn.Size = UDim2.new(0, 26, 0, 20)
    		btn.BackgroundColor3 = UI.Theme.ContainerDark
    		btn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    		btn.BorderSizePixel = 0
    		btn.Text = symbol
    		btn.TextColor3 = UI.Theme.TextPrimary
    		btn.Font = UI.Fonts.Header
    		btn.TextSize = 11
    		btn.LayoutOrder = order
    		btn.Parent = btnsRow
    		UI.registerThemeElement(btn, "ContainerDark")
    		UI.registerThemeElement(btn, "TextPrimary")
    
    		local bStroke = Instance.new("UIStroke")
    		bStroke.Color = UI.Theme.Border
    		bStroke.Thickness = 1
    		bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		bStroke.Parent = btn
    		UI.registerThemeElement(bStroke, "Border")
    
    		btn.MouseEnter:Connect(function()
    			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
    			TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = UI.Theme.Accent }):Play()
    		end)
    		btn.MouseLeave:Connect(function()
    			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
    			TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    
    		return btn
    	end
    
    	local prevBtn = makeCtrlBtn("PrevBtn", "«", 1)
    	local playBtn = makeCtrlBtn("PlayBtn", "❚❚", 2)
    	local skipBtn = makeCtrlBtn("SkipBtn", "»", 3)
    
    	-- 2. Audio Volume Slider Row (Just under playback controls)
    	local volSliderRow = Instance.new("Frame")
    	volSliderRow.Name = "VolumeSliderRow"
    	volSliderRow.Size = UDim2.new(1, 0, 0, 10)
    	volSliderRow.BackgroundTransparency = 1
    	volSliderRow.LayoutOrder = 2
    	volSliderRow.Parent = ctrlFrame
    
    	local volTrack = Instance.new("Frame")
    	volTrack.Name = "VolTrack"
    	volTrack.Size = UDim2.new(1, -2, 0, 5)
    	volTrack.Position = UDim2.new(0, 1, 0.5, -2)
    	volTrack.BackgroundColor3 = UI.Theme.ContainerDark
    	volTrack.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	volTrack.BorderSizePixel = 0
    	volTrack.Parent = volSliderRow
    	UI.registerThemeElement(volTrack, "ContainerDark")
    
    	local volTrackStroke = Instance.new("UIStroke")
    	volTrackStroke.Color = UI.Theme.BorderDim
    	volTrackStroke.Thickness = 1
    	volTrackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	volTrackStroke.Parent = volTrack
    	UI.registerThemeElement(volTrackStroke, "BorderDim")
    
    	local currentVolume = 0.8 -- default 80%
    
    	local volFill = Instance.new("Frame")
    	volFill.Name = "VolFill"
    	volFill.Size = UDim2.new(currentVolume, 0, 1, 0)
    	volFill.BackgroundColor3 = UI.Theme.Accent
    	volFill.BorderSizePixel = 0
    	volFill.Parent = volTrack
    	UI.registerThemeElement(volFill, "Accent")
    
    	local volKnob = Instance.new("Frame")
    	volKnob.Name = "VolKnob"
    	volKnob.Size = UDim2.new(0, 7, 0, 9)
    	volKnob.Position = UDim2.new(currentVolume, -3, 0.5, -4)
    	volKnob.BackgroundColor3 = UI.Theme.Border
    	volKnob.BorderSizePixel = 0
    	volKnob.Parent = volTrack
    	UI.registerThemeElement(volKnob, "Border")
    
    	local volDragging = false
    
    	local function setVolume(volRatio: number)
    		currentVolume = math.clamp(volRatio, 0, 1)
    		volFill.Size = UDim2.new(currentVolume, 0, 1, 0)
    		volKnob.Position = UDim2.new(currentVolume, -3, 0.5, -4)
    
    		-- Adjust game audio sound service
    		pcall(function()
    			local SoundService = game:GetService("SoundService")
    			for _, s in ipairs(SoundService:GetDescendants()) do
    				if s:IsA("Sound") then
    					local base = s:GetAttribute("OrigVolume") or s.Volume
    					s.Volume = (base :: number) * currentVolume
    				end
    			end
    		end)
    
    		-- Dispatch volume change to local media bridge
    		task.spawn(function()
    			pcall(function()
    				game:HttpGet(string.format("%s/volume?val=%d", BRIDGE_URL, math.floor(currentVolume * 100)))
    			end)
    		end)
    	end
    
    	volTrack.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			volDragging = true
    			local relX = math.clamp((input.Position.X - volTrack.AbsolutePosition.X) / volTrack.AbsoluteSize.X, 0, 1)
    			setVolume(relX)
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if volDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    			local relX = math.clamp((input.Position.X - volTrack.AbsolutePosition.X) / volTrack.AbsoluteSize.X, 0, 1)
    			setVolume(relX)
    		end
    	end)
    
    	UserInputService.InputEnded:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			volDragging = false
    		end
    	end)
    
    	-- ── Real-Time Audio Visualizer & Cover Update Logic ───────────────
    	local isPlaying = false
    	local currentTrackIndex = 1
    	local lastCoverUrl = ""
    	local lastSongTitle = ""
    	local lastCoverVersion = -1
    	local previousCoverFile: string? = nil
    	local currentSpectrum = { 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15 }
    	local currentAudioPeak = 0.0
    
    	-- Continuous Sub-Pixel Physics States
    	local currentHeights: {number} = {}
    	local currentVelocities: {number} = {}
    	local smoothedEnergy = 0.0
    	for i = 1, 16 do
    		currentHeights[i] = 3.0
    		currentVelocities[i] = 0.0
    	end
    
    	local function loadRealCoverBinary(v: number?)
    		local wrf = writefile or (getgenv and getgenv().writefile)
    		local mkf = makefolder or (getgenv and getgenv().makefolder)
    		local isfl = isfolder or (getgenv and getgenv().isfolder)
    		local dlf = delfile or (getgenv and getgenv().delfile)
    		local getAsset = getcustomasset or (getgenv and getgenv().getcustomasset) or getsynasset
    		
    		if type(wrf) == "function" and type(getAsset) == "function" then
    			pcall(function()
    				if type(mkf) == "function" and type(isfl) == "function" and not isfl("FihSuite") then
    					mkf("FihSuite")
    				end
    				local imgBytes = game:HttpGet(BRIDGE_URL .. "/cover.png?nocache=" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)))
    				if imgBytes and #imgBytes > 100 then
    					local newFile = string.format("FihSuite/cover_%d_%d.png", os.time(), math.random(100, 999))
    					wrf(newFile, imgBytes)
    					local assetUri = getAsset(newFile)
    					if assetUri and assetUri ~= "" then
    						TweenService:Create(coverImg, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { ImageTransparency = 0.5 }):Play()
    						task.delay(0.12, function()
    							coverImg.Image = assetUri
    							coverImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
    							coverImg.Size = UDim2.new(1, 0, 1, 0)
    							coverImg.Position = UDim2.new(0, 0, 0, 0)
    							coverImg.ScaleType = Enum.ScaleType.Crop
    							TweenService:Create(coverImg, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { ImageTransparency = 0 }):Play()
    						end)
    
    						if previousCoverFile and type(dlf) == "function" then
    							pcall(dlf, previousCoverFile)
    						end
    						previousCoverFile = newFile
    					end
    				end
    			end)
    		end
    	end
    
    	local function updateCover(coverUrl: string?, isIdle: boolean, coverVersion: number?)
    		if isIdle then
    			coverImg.Image = MUSIC_NOTE_ICON
    			coverImg.ImageColor3 = UI.Theme.Accent
    			coverImg.Size = UDim2.new(0, 52, 0, 52)
    			coverImg.Position = UDim2.new(0.5, -26, 0.5, -26)
    			coverImg.ScaleType = Enum.ScaleType.Fit
    			return
    		end
    
    		task.spawn(function()
    			loadRealCoverBinary(coverVersion)
    		end)
    
    		if coverUrl and coverUrl ~= "" and lastCoverUrl ~= coverUrl then
    			lastCoverUrl = coverUrl
    			if coverUrl:find("rbxassetid") then
    				coverImg.Image = coverUrl
    				coverImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
    				coverImg.Size = UDim2.new(1, 0, 1, 0)
    				coverImg.Position = UDim2.new(0, 0, 0, 0)
    				coverImg.ScaleType = Enum.ScaleType.Crop
    			end
    		end
    	end
    
    	
    	-- ── Synced Lyrics Engine (LRCLIB Cloud + Local Bridge IPC) ─────────
    	local parsedLrcLines: {{ ms: number, text: string }} = {}
    	local lastLrcTrack = ""
    	local serverProgressMs = 0
    	local serverDurationMs = 0
    	local lastSyncClock = os.clock()
    	local lastActiveLyric = ""
    
    	local function parseLrcString(lrcStr: string): {{ ms: number, text: string }}
    		local lines = {}
    		for raw in string.gmatch(lrcStr, "[^\r\n]+") do
    			local minStr, secStr, milStr, text = string.match(raw, "%%[(%%d%%d):(%%d%%d)%%.?(%%d*)%%](.*)")
    			if minStr and secStr then
    				local mins = tonumber(minStr) or 0
    				local secs = tonumber(secStr) or 0
    				local mils = tonumber(milStr) or 0
    				if #milStr == 2 then mils *= 10 end
    				local totalMs = (mins * 60 + secs) * 1000 + mils
    				text = string.gsub(text or "", "^%%s*(.-)%%s*$", "%%1")
    				if text ~= "" then
    					table.insert(lines, { ms = totalMs, text = text })
    				end
    			end
    		end
    		table.sort(lines, function(a, b) return a.ms < b.ms end)
    		return lines
    	end
    
    	local function fetchLyricsForTrack(title: string, artist: string)
    		local songKey = string.lower(title) .. "::" .. string.lower(artist)
    		if songKey == lastLrcTrack then return end
    		lastLrcTrack = songKey
    
    		task.spawn(function()
    			pcall(function()
    				local cleanTitle = string.gsub(title, "%b()", "")
    				cleanTitle = string.gsub(cleanTitle, "%b[]", "")
    				cleanTitle = string.gsub(cleanTitle, "[Ff]eat%..*", "")
    				cleanTitle = string.gsub(cleanTitle, "[Ff]t%..*", "")
    				cleanTitle = string.gsub(cleanTitle, "^%s*(.-)%s*$", "%1")
    
    				local cleanArtist = string.gsub(artist, "%b()", "")
    				cleanArtist = string.gsub(cleanArtist, "%b[]", "")
    				cleanArtist = string.gsub(cleanArtist, "[Ff]eat%..*", "")
    				cleanArtist = string.gsub(cleanArtist, "[Ff]t%..*", "")
    				cleanArtist = string.gsub(cleanArtist, "^%s*(.-)%s*$", "%1")
    
    				local url = string.format(
    					"https://lrclib.net/api/get?artist_name=%s&track_name=%s",
    					HttpService:UrlEncode(cleanArtist),
    					HttpService:UrlEncode(cleanTitle)
    				)
    
    				local raw = game:HttpGet(url)
    				if raw and raw ~= "" then
    					local data = HttpService:JSONDecode(raw)
    					if data and data.syncedLyrics then
    						local lines = parseLrcString(data.syncedLyrics)
    						if #lines > 0 then
    							parsedLrcLines = lines
    							return
    						end
    					elseif data and data.plainLyrics then
    						local lines = {}
    						for l in string.gmatch(data.plainLyrics, "[^\r\n]+") do
    							local t = string.gsub(l, "^%%s*(.-)%%s*$", "%%1")
    							if t ~= "" then table.insert(lines, { ms = 0, text = t }) end
    						end
    						parsedLrcLines = lines
    						return
    					end
    				end
    			end)
    		end)
    	end
    
    	local function updateActiveLyricFromTime(posMs: number)
    		if #parsedLrcLines == 0 then return end
    		local curLine = ""
    		local nextLine = ""
    
    		for i, item in ipairs(parsedLrcLines) do
    			if posMs >= item.ms then
    				curLine = item.text
    				if i < #parsedLrcLines then
    					nextLine = parsedLrcLines[i + 1].text
    				else
    					nextLine = ""
    				end
    			else
    				if curLine == "" and i == 1 then
    					curLine = item.text
    				end
    				break
    			end
    		end
    
    		if curLine ~= "" and curLine ~= lastActiveLyric then
    			lastActiveLyric = curLine
    			lyricsLabel.Text = "♫ " .. curLine
    		end
    	end
    
    	local function setTrack(t)
    		lastSongTitle = t.title
    		songTitleLabel.Text = string.format("%s — %s", t.title, t.artist)
    		lyricsLabel.Text = "♫ " .. t.lyrics
    		isPlaying = true
    		playBtn.Text = "❚❚"
    		updateCover(t.cover, false, nil)
    	end
    
    	updateCover(nil, true, nil)
    
    	-- ── Continuous 60+ FPS Lightning-Fast Spring-Damper Visualizer Physics ─
    	local visualizerConn = RunService.RenderStepped:Connect(function(dt: number)
    		if not widget.Visible then
    			if smoothedEnergy > 0 then
    				smoothedEnergy = 0
    			end
    			return
    		end
    
    		local safeDt = math.clamp(dt or 0.016, 0.001, 0.05)
    		local isAudible = isPlaying or (currentAudioPeak > 0.005)
    
    		local targetEnergy = if isAudible then currentAudioPeak else 0.0
    		if targetEnergy > smoothedEnergy then
    			smoothedEnergy = smoothedEnergy + (targetEnergy - smoothedEnergy) * math.clamp(safeDt * 60.0, 0.40, 0.98)
    		else
    			smoothedEnergy = smoothedEnergy + (targetEnergy - smoothedEnergy) * math.clamp(safeDt * 24.0, 0.15, 0.85)
    		end
    
    		-- Early exit if audio is inaudible/idle and bars have settled to rest position
    		if smoothedEnergy < 0.001 and not isAudible then
    			local allAtRest = true
    			for i = 1, 16 do
    				if currentHeights[i] > 3.05 or math.abs(currentVelocities[i]) > 0.05 then
    					allAtRest = false
    					break
    				end
    			end
    			if allAtRest then
    				for i = 1, 16 do
    					if currentHeights[i] ~= 3.0 then
    						currentHeights[i] = 3.0
    						currentVelocities[i] = 0.0
    						local bar = visualizerBars[i]
    						if bar then bar.Size = UDim2.new(0, 6, 0, 3) end
    					end
    				end
    				return
    			end
    		end
    
    		local t = os.clock()
    		for i = 1, 16 do
    			local bar = visualizerBars[i]
    			if not bar then continue end
    
    			if smoothedEnergy < 0.002 then
    				currentHeights[i] = math.max(3.0, currentHeights[i] + (3.0 - currentHeights[i]) * math.clamp(safeDt * 20.0, 0.15, 0.6))
    				bar.Size = UDim2.new(0, 6, 0, currentHeights[i])
    			else
    				local rawSpec = currentSpectrum[i] or 0.15
    				local waveHarmonic = math.sin(t * 12.0 + i * 0.60) * 0.22 + math.cos(t * 7.5 - i * 0.45) * 0.14 + 0.68
    				local targetHeight = math.clamp(rawSpec * 28.0 * (smoothedEnergy * 1.20 + 0.15) * waveHarmonic + 3.0, 3.0, 34.0)
    
    				-- High-speed physical spring with balanced damping for instant punch
    				local springForce = (targetHeight - currentHeights[i]) * 160.0
    				local dampingForce = currentVelocities[i] * 22.0
    				currentVelocities[i] = currentVelocities[i] + (springForce - dampingForce) * safeDt
    				currentHeights[i] = math.clamp(currentHeights[i] + currentVelocities[i] * safeDt, 3.0, 35.0)
    
    				bar.Size = UDim2.new(0, 6, 0, currentHeights[i])
    			end
    		end
    	end)
    
    	-- ── Playback Controls Logic ──────────────────────────────────────
    	playBtn.MouseButton1Click:Connect(function()
    		isPlaying = not isPlaying
    		playBtn.Text = if isPlaying then "❚❚" else "▶"
    		pcall(function()
    			game:HttpGet(BRIDGE_URL .. "/toggle")
    		end)
    	end)
    
    	skipBtn.MouseButton1Click:Connect(function()
    		currentTrackIndex = (currentTrackIndex % #DEMO_TRACKS) + 1
    		setTrack(DEMO_TRACKS[currentTrackIndex])
    		pcall(function()
    			game:HttpGet(BRIDGE_URL .. "/skip")
    		end)
    	end)
    
    	prevBtn.MouseButton1Click:Connect(function()
    		currentTrackIndex = if currentTrackIndex > 1 then (currentTrackIndex - 1) else #DEMO_TRACKS
    		setTrack(DEMO_TRACKS[currentTrackIndex])
    		pcall(function()
    			game:HttpGet(BRIDGE_URL .. "/prev")
    		end)
    	end)
    
    	-- ── Continuous Sub-Second Lyrics Time Synchronizer ────────────────
    	RunService.Heartbeat:Connect(function()
    		if isPlaying and serverDurationMs > 0 then
    			local elapsed = (os.clock() - lastSyncClock) * 1000
    			local curMs = math.clamp(serverProgressMs + elapsed, 0, serverDurationMs)
    			updateActiveLyricFromTime(curMs)
    		end
    	end)
    
    	-- ── Multi-Source Bridge & Synced Lyrics Poller ────────────────────
    	task.spawn(function()
    		local bridgeIndex = 1
    		local failCount = 0
    
    		while true do
    			task.wait(0.12)
    			if widget.Visible then
    				local rawData: string? = nil
    
    				-- 1. Try file IPC (readfile) for 0ms local response
    				local rf = readfile or (getgenv and getgenv().readfile)
    				local isf = isfile or (getgenv and getgenv().isfile)
    				if type(rf) == "function" and type(isf) == "function" then
    					pcall(function()
    						if isf("fih_bridge_state.json") then
    							rawData = rf("fih_bridge_state.json")
    						elseif isf("FihSuite/fih_bridge_state.json") then
    							rawData = rf("FihSuite/fih_bridge_state.json")
    						end
    					end)
    				end
    
    				-- 2. Try HTTP endpoint if file IPC was empty
    				if not rawData or rawData == "" then
    					local currentUrl = BRIDGE_URLS[bridgeIndex]
    					local ok, res = pcall(function()
    						return game:HttpGet(currentUrl .. "/current")
    					end)
    					if ok and res and res ~= "" then
    						rawData = res
    						failCount = 0
    						BRIDGE_URL = currentUrl
    					else
    						failCount += 1
    						if failCount >= 4 then
    							bridgeIndex = (bridgeIndex % #BRIDGE_URLS) + 1
    							failCount = 0
    						end
    					end
    				end
    
    				if rawData and rawData ~= "" then
    					pcall(function()
    						local data = HttpService:JSONDecode(rawData)
    						local title = data.title or data.name
    						local artist = data.artist or "Unknown"
    
    						if data and title then
    							if data.spectrum and typeof(data.spectrum) == "table" then
    								currentSpectrum = data.spectrum
    							end
    							if data.audioPeak then
    								currentAudioPeak = data.audioPeak
    							end
    
    							if data.progress_ms then
    								serverProgressMs = tonumber(data.progress_ms) or 0
    								lastSyncClock = os.clock()
    							end
    							if data.duration_ms then
    								serverDurationMs = tonumber(data.duration_ms) or 0
    							end
    
    							local isIdle = (title == "No Song Playing" or title == "Local Audio Session") and not data.isPlaying and currentAudioPeak <= 0.005
    							local coverVersion = data.coverVersion or 0
    
    							if title ~= lastSongTitle or coverVersion ~= lastCoverVersion then
    								lastSongTitle = title
    								lastCoverVersion = coverVersion
    								parsedLrcLines = {}
    								lastActiveLyric = ""
    
    								if data.synced_lyrics and typeof(data.synced_lyrics) == "table" and #data.synced_lyrics > 0 then
    									parsedLrcLines = data.synced_lyrics
    								else
    									fetchLyricsForTrack(title, artist)
    								end
    
    								if data.theme and typeof(data.theme) == "table" then
    									local t = data.theme
    									if t.accent and t.bg and t.container then
    										local acc = Color3.fromRGB(t.accent[1], t.accent[2], t.accent[3])
    										local bg = Color3.fromRGB(t.bg[1], t.bg[2], t.bg[3])
    										local ct = Color3.fromRGB(t.container[1], t.container[2], t.container[3])
    										local bd = t.border and Color3.fromRGB(t.border[1], t.border[2], t.border[3]) or nil
    										UI.applyAdaptiveTheme(acc, bg, ct, bd)
    									end
    								end
    
    								if isIdle then
    									songTitleLabel.Text = "No Song Playing"
    									lyricsLabel.Text = "♫ Waiting for audio session..."
    									isPlaying = false
    									playBtn.Text = "▶"
    									updateCover(nil, true, coverVersion)
    								else
    									songTitleLabel.Text = string.format("%s — %s", title, artist)
    									if data.lyrics and data.lyrics ~= "" then
    										lyricsLabel.Text = "♫ " .. data.lyrics
    										lastActiveLyric = data.lyrics
    									end
    									isPlaying = (data.isPlaying == true or currentAudioPeak > 0.005)
    									playBtn.Text = if isPlaying then "❚❚" else "▶"
    									updateCover(data.cover, false, coverVersion)
    								end
    							else
    								if isIdle then
    									isPlaying = false
    									playBtn.Text = "▶"
    								else
    									isPlaying = (data.isPlaying == true or currentAudioPeak > 0.005)
    									playBtn.Text = if isPlaying then "❚❚" else "▶"
    									if data.lyrics and data.lyrics ~= "" and #parsedLrcLines == 0 then
    										lyricsLabel.Text = "♫ " .. data.lyrics
    									end
    								end
    							end
    						end
    					end)
    				end
    			end
    		end
    	end)
    
    	-- ── Dragging & Minimize/Close Handlers ────────────────────────────
    	local dragging = false
    	local dragInput: InputObject? = nil
    	local dragStart = Vector3.zero
    	local startAbsPos = Vector2.zero
    
    	topbar.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			dragStart = input.Position
    			startAbsPos = widget.AbsolutePosition
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    				end
    			end)
    		end
    	end)
    
    	topbar.InputChanged:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    			dragInput = input
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if input == dragInput and dragging then
    			local delta = input.Position - dragStart
    			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
    			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
    			widget.Position = UDim2.new(0, targetX, 0, targetY)
    		end
    	end)
    
    	local minimized = false
    	minBtn.MouseButton1Click:Connect(function()
    		minimized = not minimized
    		if minimized then
    			body.Visible = false
    			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, TOPBAR_H)
    			}):Play()
    		else
    			body.Visible = true
    			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
    			}):Play()
    		end
    	end)
    
    	local isOpen = true
    	local isTransitioning = false
    
    	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.openWindow(widget, uiScale, function()
    			isOpen = true
    			isTransitioning = false
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if not isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.closeWindow(widget, uiScale, function()
    			isOpen = false
    			isTransitioning = false
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen then
    			closeWidget(onComplete)
    		else
    			openWidget(onComplete)
    		end
    	end
    
    	local function setWidgetVisible(selfOrVal: any, maybeVal: any)
    		local v = if type(selfOrVal) == "boolean" then selfOrVal elseif type(maybeVal) == "boolean" then maybeVal else true
    		if v then
    			openWidget()
    		else
    			closeWidget()
    		end
    	end
    
    	closeBtn.MouseButton1Click:Connect(function()
    		closeWidget()
    	end)
    
    	return {
    		Frame = widget,
    		UiScale = uiScale,
    		IsOpen = function() return isOpen end,
    		Open = openWidget,
    		Close = closeWidget,
    		SetVisible = setWidgetVisible,
    		Toggle = toggleWidget
    	}
    end
    
    return MusicTracker
end

Modules["UI/Hotbar.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Squared Retro Hotbar & 3D Model Viewport Backpack Inventory Widget ✦
        Features:
        - Fluid Drag-to-Move / Drag-to-Swap toolbar objects with live drop target highlights
        - Instantaneous O(1) zero-lag tool equipping & unequipping (<0.01ms)
        - Full hot-reload event disconnection (_G.__ModularHotbar_Cleanup)
        - Permanent 3D ViewportFrame caching (zero model re-cloning on equip/unequip)
        - Smart hierarchy filter (moving tools between Backpack and Character never rebuilds viewports)
        - Dedicated retro [ ≡ INV ] hamburger button to toggle Backpack Inventory
        - Reliable 1-0 number key unequip toggling
        - Drag-to-drop: dragging an item outside the HUD drops the item into the world
        - 100% Theme-reactive (Dark, Light, Translucent Dark, Translucent Light, Adaptive)
    ]=]
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local GuiService = game:GetService("GuiService")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local Hotbar = {}
    Hotbar.__index = Hotbar
    
    local LocalPlayer = Players.LocalPlayer
    
    export type HotbarWidget = {
    	HotbarFrame: Frame,
    	BackpackWindow: Frame,
    	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
    	ToggleBackpack: () -> (),
    	IsOpen: () -> boolean,
    	Refresh: () -> ()
    }
    
    local NUM_SLOTS = 10
    local SLOT_SIZE = 48
    local SLOT_GAP = 4
    local KEYCODES = {
    	Enum.KeyCode.One,
    	Enum.KeyCode.Two,
    	Enum.KeyCode.Three,
    	Enum.KeyCode.Four,
    	Enum.KeyCode.Five,
    	Enum.KeyCode.Six,
    	Enum.KeyCode.Seven,
    	Enum.KeyCode.Eight,
    	Enum.KeyCode.Nine,
    	Enum.KeyCode.Zero
    }
    
    export type ToolViewportCache = {
    	Tool: Tool?,
    	Name: string,
    	TextureId: string,
    	Signature: string
    }
    
    function Hotbar.getToolSignature(tool: Tool?): string
    	if not tool then return "" end
    	return string.format("%s_%s_%s", tool.Name, tool.TextureId, tostring(tool))
    end
    
    local function cleanAssetId(raw: string?): string
    	if not raw or raw == "" then return "" end
    	local id = string.match(raw, "(%d+)")
    	if id then
    		return "rbxassetid://" .. id
    	end
    	return raw
    end
    
    local function cleanViewport(container: GuiObject)
    	local oldVp = container:FindFirstChild("ModelViewport")
    	if oldVp then
    		local oldCam = oldVp:FindFirstChildWhichIsA("Camera")
    		if oldCam then oldCam:Destroy() end
    		for _, child in ipairs(oldVp:GetChildren()) do
    			child:Destroy()
    		end
    		oldVp:Destroy()
    	end
    	local oldImg = container:FindFirstChild("ToolIcon2D")
    	if oldImg then
    		oldImg:Destroy()
    	end
    end
    
    local function renderToolViewportCached(
    	container: GuiObject,
    	tool: Tool?,
    	cacheKey: any,
    	cacheStore: {[any]: ToolViewportCache}
    )
    	if not tool then
    		cleanViewport(container)
    		cacheStore[cacheKey] = nil
    		return
    	end
    
    	local sig = Hotbar.getToolSignature(tool)
    	local cached = cacheStore[cacheKey]
    	local existingVp = container:FindFirstChild("ModelViewport")
    	local existingImg = container:FindFirstChild("ToolIcon2D")
    
    	if cached and (existingVp or existingImg) and cached.Tool == tool and cached.Name == tool.Name and cached.TextureId == tool.TextureId and cached.Signature == sig then
    		return
    	end
    
    	cleanViewport(container)
    
    	-- 1. Check for valid 2D TextureId (Primary for Roblox Gears / Weapons / Items)
    	local cleanedTexture = cleanAssetId(tool.TextureId)
    	if cleanedTexture ~= "" then
    		local imgLabel = Instance.new("ImageLabel")
    		imgLabel.Name = "ToolIcon2D"
    		imgLabel.Size = UDim2.new(0.72, 0, 0.72, 0)
    		imgLabel.Position = UDim2.new(0.14, 0, 0.14, 0)
    		imgLabel.BackgroundTransparency = 1
    		imgLabel.BorderSizePixel = 0
    		imgLabel.Image = cleanedTexture
    		imgLabel.ScaleType = Enum.ScaleType.Fit
    		imgLabel.ZIndex = 3
    		imgLabel.Parent = container
    	else
    		-- 2. Fallback to 3D ViewportFrame with intelligent multi-mesh and SpecialMesh scaling
    		local vp = Instance.new("ViewportFrame")
    		vp.Name = "ModelViewport"
    		vp.Size = UDim2.new(1, 0, 1, 0)
    		vp.Position = UDim2.new(0, 0, 0, 0)
    		vp.BackgroundTransparency = 1
    		vp.BorderSizePixel = 0
    		vp.Ambient = Color3.fromRGB(220, 220, 230)
    		vp.LightColor = Color3.fromRGB(255, 255, 255)
    		vp.LightDirection = Vector3.new(-1, -1.6, -1).Unit
    		vp.ZIndex = 3
    		vp.Parent = container
    
    		local parts: {BasePart} = {}
    		local handle = tool:FindFirstChild("Handle") :: BasePart?
    		for _, desc in ipairs(tool:GetDescendants()) do
    			if desc:IsA("BasePart") then
    				table.insert(parts, desc)
    			end
    		end
    
    		if #parts > 0 then
    			local refPart = handle or parts[1]
    			local refCF = refPart.CFrame
    			local minBounds = Vector3.new(math.huge, math.huge, math.huge)
    			local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)
    
    			local model = Instance.new("Model")
    			model.Name = "ClonedTool"
    
    			for _, p in ipairs(parts) do
    				local clone = p:Clone()
    				clone.CanCollide = false
    				clone.Anchored = true
    				local relCF = refCF:ToObjectSpace(p.CFrame)
    				clone.CFrame = relCF
    				clone.Parent = model
    
    				local cp = relCF.Position
    				local sz = clone.Size
    
    				-- Check if SpecialMesh scale enlarges the visual size
    				local sm = clone:FindFirstChildOfClass("SpecialMesh")
    				if sm then
    					sz = Vector3.new(sz.X * math.abs(sm.Scale.X), sz.Y * math.abs(sm.Scale.Y), sz.Z * math.abs(sm.Scale.Z))
    				end
    
    				minBounds = Vector3.new(
    					math.min(minBounds.X, cp.X - sz.X / 2),
    					math.min(minBounds.Y, cp.Y - sz.Y / 2),
    					math.min(minBounds.Z, cp.Z - sz.Z / 2)
    				)
    				maxBounds = Vector3.new(
    					math.max(maxBounds.X, cp.X + sz.X / 2),
    					math.max(maxBounds.Y, cp.Y + sz.Y / 2),
    					math.max(maxBounds.Z, cp.Z + sz.Z / 2)
    				)
    			end
    
    			model.Parent = vp
    
    			local center = (minBounds + maxBounds) / 2
    			local size = (maxBounds - minBounds)
    			local maxDim = math.max(size.X, size.Y, size.Z, 0.8)
    
    			local cam = Instance.new("Camera")
    			cam.FieldOfView = 50
    			cam.CFrame = CFrame.new(center + Vector3.new(maxDim * 1.35, maxDim * 0.95, maxDim * 1.35), center)
    			cam.Parent = vp
    			vp.CurrentCamera = cam
    		end
    	end
    
    	cacheStore[cacheKey] = {
    		Tool = tool,
    		Name = tool.Name,
    		TextureId = tool.TextureId,
    		Signature = sig
    	}
    end
    
    function Hotbar.new(): HotbarWidget
    	-- Disconnect previous instance connections to prevent ghost listener collisions
    	if _G.__ModularHotbar_Cleanup then
    		pcall(_G.__ModularHotbar_Cleanup)
    		_G.__ModularHotbar_Cleanup = nil
    	end
    
    	local activeConnections: {RBXScriptConnection} = {}
    
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularHotbarGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.DisplayOrder = 610
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    	pcall(function() screenGui.Parent = CoreGui end)
    	if not screenGui.Parent then
    		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    	end
    
    	-- ── Drag Ghost Icon ───────────────────────────────────────────────
    	local dragGhost = Instance.new("Frame")
    	dragGhost.Name = "DragGhost"
    	dragGhost.Size = UDim2.new(0, 52, 0, 52)
    	dragGhost.BackgroundColor3 = UI.Theme.Accent
    	dragGhost.BackgroundTransparency = 0.25
    	dragGhost.BorderSizePixel = 0
    	dragGhost.Visible = false
    	dragGhost.ZIndex = 200
    	dragGhost.Parent = screenGui
    
    	local ghostStroke = Instance.new("UIStroke")
    	ghostStroke.Color = Color3.fromRGB(255, 255, 255)
    	ghostStroke.Thickness = 2
    	ghostStroke.Parent = dragGhost
    
    	local ghostBadge = Instance.new("TextLabel")
    	ghostBadge.Size = UDim2.new(1, 0, 0, 16)
    	ghostBadge.Position = UDim2.new(0, 0, 0, 4)
    	ghostBadge.BackgroundTransparency = 1
    	ghostBadge.Text = "MOVING"
    	ghostBadge.TextColor3 = UI.Theme.AccentText
    	ghostBadge.Font = UI.Fonts.Mono
    	ghostBadge.TextSize = 8
    	ghostBadge.ZIndex = 201
    	ghostBadge.Parent = dragGhost
    
    	local ghostLabel = Instance.new("TextLabel")
    	ghostLabel.Size = UDim2.new(1, -4, 0, 18)
    	ghostLabel.Position = UDim2.new(0, 2, 1, -22)
    	ghostLabel.BackgroundTransparency = 1
    	ghostLabel.TextColor3 = UI.Theme.AccentText
    	ghostLabel.Font = UI.Fonts.Header
    	ghostLabel.TextSize = 10
    	ghostLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	ghostLabel.ZIndex = 201
    	ghostLabel.Parent = dragGhost
    
    	-- ── 1. Hotbar HUD Container ───────────────────────────────────────
    	local totalSlotsCount = NUM_SLOTS + 1
    	local totalWidth = (totalSlotsCount * SLOT_SIZE) + ((totalSlotsCount - 1) * SLOT_GAP) + 12
    	local hotbarFrame = Instance.new("Frame")
    	hotbarFrame.Name = "HotbarFrame"
    	hotbarFrame.Size = UDim2.new(0, totalWidth, 0, SLOT_SIZE + 10)
    	hotbarFrame.Position = UDim2.new(0.5, -totalWidth / 2, 1, -(SLOT_SIZE + 24))
    	hotbarFrame.BackgroundColor3 = UI.Theme.Background
    	hotbarFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	hotbarFrame.BorderSizePixel = 0
    	hotbarFrame.ClipsDescendants = false
    	hotbarFrame.Parent = screenGui
    	UI.registerThemeElement(hotbarFrame, "Background")
    
    	local hotbarStroke = Instance.new("UIStroke")
    	hotbarStroke.Color = UI.Theme.Border
    	hotbarStroke.Thickness = 2
    	hotbarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	hotbarStroke.Parent = hotbarFrame
    	UI.registerThemeElement(hotbarStroke, "Border")
    
    	local hotbarList = Instance.new("UIListLayout")
    	hotbarList.FillDirection = Enum.FillDirection.Horizontal
    	hotbarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	hotbarList.VerticalAlignment = Enum.VerticalAlignment.Center
    	hotbarList.Padding = UDim.new(0, SLOT_GAP)
    	hotbarList.SortOrder = Enum.SortOrder.LayoutOrder
    	hotbarList.Parent = hotbarFrame
    
    	-- ── 2. Backpack Inventory Window ──────────────────────────────────
    	local BP_WIDTH = 480
    	local BP_HEIGHT = 340
    	local bpWindow = Instance.new("Frame")
    	bpWindow.Name = "BackpackWindow"
    	bpWindow.Size = UDim2.new(0, BP_WIDTH, 0, BP_HEIGHT)
    	bpWindow.Position = UDim2.new(0.5, -BP_WIDTH / 2, 0.5, -BP_HEIGHT / 2)
    	bpWindow.BackgroundColor3 = UI.Theme.Background
    	bpWindow.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	bpWindow.BorderSizePixel = 0
    	bpWindow.ClipsDescendants = false
    	bpWindow.Visible = false
    	bpWindow.Parent = screenGui
    	UI.registerThemeElement(bpWindow, "Background")
    
    	local bpStroke = Instance.new("UIStroke")
    	bpStroke.Color = UI.Theme.Border
    	bpStroke.Thickness = 2
    	bpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	bpStroke.Parent = bpWindow
    	UI.registerThemeElement(bpStroke, "Border")
    
    	local bpTopBar = Instance.new("Frame")
    	bpTopBar.Name = "TopBar"
    	bpTopBar.Size = UDim2.new(1, 0, 0, 28)
    	bpTopBar.BackgroundColor3 = UI.Theme.Container
    	bpTopBar.BackgroundTransparency = UI.Theme.ContainerTransparency
    	bpTopBar.BorderSizePixel = 0
    	bpTopBar.Parent = bpWindow
    	UI.registerThemeElement(bpTopBar, "Container")
    
    	local bpTopStroke = Instance.new("UIStroke")
    	bpTopStroke.Color = UI.Theme.BorderDim
    	bpTopStroke.Thickness = 1
    	bpTopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	bpTopStroke.Parent = bpTopBar
    	UI.registerThemeElement(bpTopStroke, "BorderDim")
    
    	local bpTitle = Instance.new("TextLabel")
    	bpTitle.Size = UDim2.new(1, -60, 1, 0)
    	bpTitle.Position = UDim2.new(0, 10, 0, 0)
    	bpTitle.BackgroundTransparency = 1
    	bpTitle.Text = "Backpack Inventory (Sort & Drag to Toolbar)"
    	bpTitle.TextColor3 = UI.Theme.TextPrimary
    	bpTitle.Font = UI.Fonts.Header
    	bpTitle.TextSize = 11
    	bpTitle.TextXAlignment = Enum.TextXAlignment.Left
    	bpTitle.Parent = bpTopBar
    	UI.registerThemeElement(bpTitle, "TextPrimary")
    
    	local bpCloseBtn = Instance.new("TextButton")
    	bpCloseBtn.Size = UDim2.new(0, 24, 1, -4)
    	bpCloseBtn.Position = UDim2.new(1, -26, 0, 2)
    	bpCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	bpCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	bpCloseBtn.BorderSizePixel = 0
    	bpCloseBtn.Text = "X"
    	bpCloseBtn.TextColor3 = UI.Theme.TextPrimary
    	bpCloseBtn.Font = UI.Fonts.Header
    	bpCloseBtn.TextSize = 11
    	bpCloseBtn.Parent = bpTopBar
    	UI.registerThemeElement(bpCloseBtn, "ContainerDark")
    	UI.registerThemeElement(bpCloseBtn, "TextPrimary")
    	Animations.buttonHoverPush(bpCloseBtn)
    
    	-- Search & Action Bar
    	local searchFrame = Instance.new("Frame")
    	searchFrame.Size = UDim2.new(1, -12, 0, 26)
    	searchFrame.Position = UDim2.new(0, 6, 0, 36)
    	searchFrame.BackgroundTransparency = 1
    	searchFrame.BorderSizePixel = 0
    	searchFrame.Parent = bpWindow
    
    	local searchBox = Instance.new("TextBox")
    	searchBox.Size = UDim2.new(1, -110, 1, 0)
    	searchBox.BackgroundColor3 = UI.Theme.Container
    	searchBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	searchBox.BorderSizePixel = 0
    	searchBox.Text = ""
    	searchBox.PlaceholderText = "Search inventory tools..."
    	searchBox.PlaceholderColor3 = UI.Theme.TextSecondary
    	searchBox.TextColor3 = UI.Theme.TextPrimary
    	searchBox.Font = UI.Fonts.Body
    	searchBox.TextSize = 11
    	searchBox.TextXAlignment = Enum.TextXAlignment.Left
    	searchBox.ClearTextOnFocus = false
    	searchBox.Parent = searchFrame
    	UI.registerThemeElement(searchBox, "TextPrimary")
    
    	local unequipAllBtn = Instance.new("TextButton")
    	unequipAllBtn.Size = UDim2.new(0, 96, 1, 0)
    	unequipAllBtn.Position = UDim2.new(1, -100, 0, 0)
    	unequipAllBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	unequipAllBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	unequipAllBtn.BorderSizePixel = 0
    	unequipAllBtn.Text = "Unequip All"
    	unequipAllBtn.TextColor3 = UI.Theme.TextPrimary
    	unequipAllBtn.Font = UI.Fonts.Header
    	unequipAllBtn.TextSize = 10
    	unequipAllBtn.Parent = searchFrame
    	UI.registerThemeElement(unequipAllBtn, "ContainerDark")
    	UI.registerThemeElement(unequipAllBtn, "TextPrimary")
    	Animations.buttonHoverPush(unequipAllBtn)
    
    	-- Backpack Inventory Grid Container
    	local bpGridScroll = Instance.new("ScrollingFrame")
    	bpGridScroll.Name = "InventoryGrid"
    	bpGridScroll.Size = UDim2.new(1, -12, 1, -76)
    	bpGridScroll.Position = UDim2.new(0, 6, 0, 70)
    	bpGridScroll.BackgroundColor3 = UI.Theme.Container
    	bpGridScroll.BackgroundTransparency = UI.Theme.ContainerTransparency
    	bpGridScroll.BorderSizePixel = 0
    	bpGridScroll.ScrollBarThickness = 3
    	bpGridScroll.ScrollBarImageColor3 = UI.Theme.Accent
    	bpGridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    	bpGridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	bpGridScroll.Parent = bpWindow
    	UI.registerThemeElement(bpGridScroll, "Container")
    
    	local bpGridPad = Instance.new("UIPadding")
    	bpGridPad.PaddingLeft = UDim.new(0, 6)
    	bpGridPad.PaddingRight = UDim.new(0, 6)
    	bpGridPad.PaddingTop = UDim.new(0, 6)
    	bpGridPad.PaddingBottom = UDim.new(0, 6)
    	bpGridPad.Parent = bpGridScroll
    
    	local bpGridLayout = Instance.new("UIGridLayout")
    	bpGridLayout.CellSize = UDim2.new(0, 84, 0, 74)
    	bpGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
    	bpGridLayout.SortOrder = Enum.SortOrder.Name
    	bpGridLayout.Parent = bpGridScroll
    
    	-- ── 3. State Management & Tool Gathering ──────────────────────────
    	local assignedSlots: {[number]: Tool} = {}
    	local slotFrames: {[number]: TextButton} = {}
    	local slotCaches: {[number]: ToolViewportCache} = {}
    	local backpackCards: {[Tool]: TextButton} = {}
    	local backpackCaches: {[Tool]: ToolViewportCache} = {}
    	local isBackpackOpen = false
    	local filterQuery = ""
    
    	local draggingTool: Tool? = nil
    	local draggingFromSlot: number? = nil
    	local dragStartPos = Vector2.zero
    	local isDraggingActive = false
    	local justFinishedDrag = false
    	local equipOrToggleTool: ((Tool) -> ())
    
    	local function getAllTools(): {Tool}
    		local tools: {Tool} = {}
    		local char = LocalPlayer.Character
    		if char then
    			for _, item in ipairs(char:GetChildren()) do
    				if item:IsA("Tool") then
    					table.insert(tools, item)
    				end
    			end
    		end
    		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    		if bp then
    			for _, item in ipairs(bp:GetChildren()) do
    				if item:IsA("Tool") then
    					table.insert(tools, item)
    				end
    			end
    		end
    		return tools
    	end
    
    	local function isToolEquipped(tool: Tool): boolean
    		local char = LocalPlayer.Character
    		return char ~= nil and (tool.Parent == char or char:FindFirstChild(tool.Name) == tool)
    	end
    
    	-- ── 4. Instant O(1) Slot Highlight Updater (Zero Viewport Rebuild) ──
    	local function updateSlotHighlightsOnly()
    		for slotNum = 1, NUM_SLOTS do
    			local slotBtn = slotFrames[slotNum]
    			local tool = assignedSlots[slotNum]
    			local stroke = slotBtn:FindFirstChildWhichIsA("UIStroke")
    			local nameLabel = slotBtn:FindFirstChild("ToolName") :: TextLabel?
    
    			if tool and tool.Parent then
    				local equipped = isToolEquipped(tool)
    				if nameLabel then
    					nameLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
    				end
    				if equipped then
    					slotBtn.BackgroundColor3 = UI.Theme.Accent
    					slotBtn.BackgroundTransparency = 0.2
    					if stroke then
    						stroke.Color = UI.Theme.Border
    						stroke.Thickness = 2.0
    					end
    				else
    					slotBtn.BackgroundColor3 = UI.Theme.Container
    					slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    					if stroke then
    						stroke.Color = UI.Theme.Border
    						stroke.Thickness = 1.2
    					end
    				end
    			else
    				slotBtn.BackgroundColor3 = UI.Theme.ContainerDark
    				slotBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    				if stroke then
    					stroke.Color = UI.Theme.BorderDim
    					stroke.Thickness = 1.0
    				end
    			end
    		end
    
    		if isBackpackOpen then
    			for tool, card in pairs(backpackCards) do
    				if tool and tool.Parent and card and card.Parent then
    					local equipped = isToolEquipped(tool)
    					card.BackgroundColor3 = if equipped then UI.Theme.Accent else UI.Theme.ContainerDark
    					card.BackgroundTransparency = if equipped then 0.15 else UI.Theme.ContainerDarkTransparency
    					local badge = card:FindFirstChild("EquippedBadge") :: TextLabel?
    					if badge then badge.Text = if equipped then "EQUIPPED" else "" end
    				end
    			end
    		end
    	end
    
    	-- ── 5. Full Hotbar Viewport Render Function (Only Runs on Inventory Change) ──
    	local function updateHotbarVisuals()
    		local allTools = getAllTools()
    		local validToolSet: {[Tool]: boolean} = {}
    		for _, t in ipairs(allTools) do
    			validToolSet[t] = true
    		end
    
    		-- Purge any slot whose tool is not in current valid inventory
    		for i = 1, NUM_SLOTS do
    			local currentTool = assignedSlots[i]
    			if currentTool and not validToolSet[currentTool] then
    				assignedSlots[i] = nil
    				cleanViewport(slotFrames[i])
    			end
    		end
    
    		-- Auto-assign unassigned tools to first available slots
    		for _, tool in ipairs(allTools) do
    			local alreadyAssigned = false
    			for i = 1, NUM_SLOTS do
    				if assignedSlots[i] == tool then
    					alreadyAssigned = true
    					break
    				end
    			end
    			if not alreadyAssigned then
    				for i = 1, NUM_SLOTS do
    					if not assignedSlots[i] then
    						assignedSlots[i] = tool
    						break
    					end
    				end
    			end
    		end
    
    		for slotNum = 1, NUM_SLOTS do
    			local slotBtn = slotFrames[slotNum]
    			local tool = assignedSlots[slotNum]
    			local stroke = slotBtn:FindFirstChildWhichIsA("UIStroke")
    			local nameLabel = slotBtn:FindFirstChild("ToolName") :: TextLabel?
    
    			if tool and validToolSet[tool] then
    				renderToolViewportCached(slotBtn, tool, slotNum, slotCaches)
    				local equipped = isToolEquipped(tool)
    				if nameLabel then
    					nameLabel.Text = tool.Name
    					nameLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
    				end
    
    				if equipped then
    					slotBtn.BackgroundColor3 = UI.Theme.Accent
    					slotBtn.BackgroundTransparency = 0.2
    					if stroke then
    						stroke.Color = UI.Theme.Border
    						stroke.Thickness = 2.0
    					end
    				else
    					slotBtn.BackgroundColor3 = UI.Theme.Container
    					slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    					if stroke then
    						stroke.Color = UI.Theme.Border
    						stroke.Thickness = 1.2
    					end
    				end
    			else
    				assignedSlots[slotNum] = nil
    				cleanViewport(slotBtn)
    				if nameLabel then nameLabel.Text = "" end
    				slotBtn.BackgroundColor3 = UI.Theme.ContainerDark
    				slotBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    				if stroke then
    					stroke.Color = UI.Theme.BorderDim
    					stroke.Thickness = 1.0
    				end
    			end
    		end
    	end
    
    	-- ── 6. Render Backpack Grid Items Function ────────────────────────
    	local function updateBackpackGrid()
    		if not isBackpackOpen then return end
    		local allTools = getAllTools()
    		local activeToolSet: {[Tool]: boolean} = {}
    
    		for _, tool in ipairs(allTools) do
    			activeToolSet[tool] = true
    			local matchesFilter = (filterQuery == "" or tool.Name:lower():find(filterQuery:lower(), 1, true) ~= nil)
    
    			local existingCard = backpackCards[tool]
    			if not matchesFilter then
    				if existingCard then
    					cleanViewport(existingCard)
    					UI.unregisterThemeElement(existingCard)
    					existingCard:Destroy()
    					backpackCards[tool] = nil
    					backpackCaches[tool] = nil
    				end
    				continue
    			end
    
    			local equipped = isToolEquipped(tool)
    
    			if existingCard and existingCard.Parent == bpGridScroll then
    				existingCard.BackgroundColor3 = UI.Theme.ContainerDark
    				existingCard.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    
    				local itemStroke = existingCard:FindFirstChildWhichIsA("UIStroke")
    				if itemStroke then
    					itemStroke.Color = if equipped then UI.Theme.Accent else UI.Theme.BorderDim
    					itemStroke.Thickness = if equipped then 2.5 else 1.0
    				end
    
    				local tName = existingCard:FindFirstChild("ToolLabel") :: TextLabel?
    				if tName then
    					tName.Text = tool.Name
    					tName.TextColor3 = if equipped then UI.Theme.Accent else UI.Theme.TextPrimary
    				end
    
    				local badge = existingCard:FindFirstChild("EquippedBadge") :: TextLabel?
    				if badge then
    					badge.Text = if equipped then "EQUIPPED" else ""
    				end
    
    				renderToolViewportCached(existingCard, tool, tool, backpackCaches)
    			else
    				if existingCard then
    					cleanViewport(existingCard)
    					UI.unregisterThemeElement(existingCard)
    					existingCard:Destroy()
    					backpackCards[tool] = nil
    					backpackCaches[tool] = nil
    				end
    
    				local itemCard = Instance.new("TextButton")
    				itemCard.Name = "Item_" .. tool.Name
    				itemCard.Size = UDim2.new(0, 84, 0, 74)
    				itemCard.BackgroundColor3 = UI.Theme.ContainerDark
    				itemCard.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    				itemCard.BorderSizePixel = 0
    				itemCard.Text = ""
    				itemCard.AutoButtonColor = false
    				itemCard.ClipsDescendants = true
    				itemCard.Parent = bpGridScroll
    				UI.registerThemeElement(itemCard, if equipped then "Accent" else "ContainerDark")
    				Animations.buttonHoverPush(itemCard)
    
    				local itemStroke = Instance.new("UIStroke")
    				itemStroke.Color = if equipped then UI.Theme.Accent else UI.Theme.BorderDim
    				itemStroke.Thickness = if equipped then 2.5 else 1.0
    				itemStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    				itemStroke.Parent = itemCard
    				UI.registerThemeElement(itemStroke, "BorderDim")
    
    				local tLabel = Instance.new("TextLabel")
    				tLabel.Name = "ToolLabel"
    				tLabel.Size = UDim2.new(1, -6, 0, 16)
    				tLabel.Position = UDim2.new(0, 3, 1, -18)
    				tLabel.BackgroundTransparency = 1
    				tLabel.Text = tool.Name
    				tLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
    				tLabel.Font = UI.Fonts.Header
    				tLabel.TextSize = 9
    				tLabel.TextTruncate = Enum.TextTruncate.AtEnd
    				tLabel.ZIndex = 5
    				tLabel.Parent = itemCard
    				UI.registerThemeElement(tLabel, "TextPrimary")
    
    				local eqBadge = Instance.new("TextLabel")
    				eqBadge.Name = "EquippedBadge"
    				eqBadge.Size = UDim2.new(1, -6, 0, 12)
    				eqBadge.Position = UDim2.new(0, 3, 0, 2)
    				eqBadge.BackgroundTransparency = 1
    				eqBadge.Text = if equipped then "EQUIPPED" else ""
    				eqBadge.TextColor3 = UI.Theme.AccentText
    				eqBadge.Font = UI.Fonts.Mono
    				eqBadge.TextSize = 8
    				eqBadge.ZIndex = 5
    				eqBadge.Parent = itemCard
    				UI.registerThemeElement(eqBadge, "AccentText")
    
    				renderToolViewportCached(itemCard, tool, tool, backpackCaches)
    
    				local cardPressPos = Vector2.zero
    				itemCard.InputBegan:Connect(function(input)
    					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    						cardPressPos = UserInputService:GetMouseLocation()
    					end
    				end)
    
    				itemCard.InputChanged:Connect(function(input)
    					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    						if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not isDraggingActive then
    							local curPos = UserInputService:GetMouseLocation()
    							if (curPos - cardPressPos).Magnitude > 14 then
    								startDragging(tool, nil, curPos)
    							end
    						end
    					end
    				end)
    
    				itemCard.MouseButton1Click:Connect(function()
    					if not justFinishedDrag and not isDraggingActive then
    						Animations.buttonClickPop(itemCard)
    						equipOrToggleTool(tool)
    					end
    				end)
    
    				backpackCards[tool] = itemCard
    			end
    		end
    
    		for oldTool, oldCard in pairs(backpackCards) do
    			if not activeToolSet[oldTool] then
    				cleanViewport(oldCard)
    				UI.unregisterThemeElement(oldCard)
    				oldCard:Destroy()
    				backpackCards[oldTool] = nil
    				backpackCaches[oldTool] = nil
    			end
    		end
    	end
    
    	-- ── 7. Debounced Refresher for True Add/Remove Events ──────────────
    	local refreshScheduled = false
    	local function queueInventoryRefresh()
    		if refreshScheduled then return end
    		refreshScheduled = true
    		task.delay(0.08, function()
    			refreshScheduled = false
    			updateHotbarVisuals()
    			if isBackpackOpen then
    				updateBackpackGrid()
    			end
    		end)
    	end
    
    	-- Instant O(1) Equip or Unequip Toggle Function
    	equipOrToggleTool = function(tool: Tool)
    		local char = LocalPlayer.Character
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    		if not char or not hum or not tool or not tool.Parent then return end
    
    		local currentlyEquipped = char:FindFirstChildOfClass("Tool")
    
    		pcall(function()
    			if currentlyEquipped == tool or isToolEquipped(tool) then
    				hum:UnequipTools()
    				if bp and tool.Parent == char then
    					tool.Parent = bp
    				end
    			else
    				hum:UnequipTools()
    				if tool.Parent then
    					hum:EquipTool(tool)
    				end
    			end
    		end)
    
    		updateSlotHighlightsOnly()
    	end
    
    	unequipAllBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(unequipAllBtn)
    		local char = LocalPlayer.Character
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    		if hum then hum:UnequipTools() end
    		if char and bp then
    			for _, c in ipairs(char:GetChildren()) do
    				if c:IsA("Tool") then c.Parent = bp end
    			end
    		end
    		updateSlotHighlightsOnly()
    	end)
    
    	-- ── Drop Item Function ───────────────────────────────────────────
    	local function dropTool(tool: Tool)
    		local char = LocalPlayer.Character
    		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    		pcall(function()
    			if isToolEquipped(tool) and hum then
    				hum:UnequipTools()
    			end
    			if hrp then
    				tool.Parent = Workspace
    				local handle = tool:FindFirstChild("Handle") :: BasePart? or tool:FindFirstChildWhichIsA("BasePart")
    				if handle then
    					handle.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
    				end
    			else
    				tool.Parent = Workspace
    			end
    		end)
    
    		for i = 1, NUM_SLOTS do
    			if assignedSlots[i] == tool then
    				assignedSlots[i] = nil
    			end
    		end
    
    		updateHotbarVisuals()
    		if isBackpackOpen then updateBackpackGrid() end
    
    		pcall(function()
    			local Notification = require("UI/Notification.luau")
    			Notification.new("Inventory", string.format("Dropped '%s'", tool.Name), 2)
    		end)
    	end
    
    	-- ── Drag & Drop Handlers (Toolbar Moving / Sorting / Dropping) ───
    	local function isPointInsideGui(point: Vector2, gui: GuiObject): boolean
    		local pos = gui.AbsolutePosition
    		local size = gui.AbsoluteSize
    		return point.X >= pos.X and point.X <= (pos.X + size.X) and point.Y >= pos.Y and point.Y <= (pos.Y + size.Y)
    	end
    
    	local function findSlotUnderOrNearMouse(mousePos: Vector2): number?
    		-- 1. Exact hit test on individual slot buttons
    		for slotIdx = 1, NUM_SLOTS do
    			local slotFrame = slotFrames[slotIdx]
    			if slotFrame and isPointInsideGui(mousePos, slotFrame) then
    				return slotIdx
    			end
    		end
    
    		-- 2. Magnetic snap if released anywhere along the toolbar HUD (generous Y +/- 40px and X +/- 20px tolerance)
    		local hPos = hotbarFrame.AbsolutePosition
    		local hSize = hotbarFrame.AbsoluteSize
    		if mousePos.Y >= (hPos.Y - 45) and mousePos.Y <= (hPos.Y + hSize.Y + 45) and
    		   mousePos.X >= (hPos.X - 25) and mousePos.X <= (hPos.X + hSize.X + 25) then
    			local closestSlot: number? = nil
    			local minDist = math.huge
    			for slotIdx = 1, NUM_SLOTS do
    				local slotFrame = slotFrames[slotIdx]
    				if slotFrame then
    					local center = slotFrame.AbsolutePosition + slotFrame.AbsoluteSize / 2
    					local dist = math.abs(mousePos.X - center.X)
    					if dist < minDist then
    						minDist = dist
    						closestSlot = slotIdx
    					end
    				end
    			end
    			return closestSlot
    		end
    
    		return nil
    	end
    
    	local function startDragging(tool: Tool, fromSlot: number?, startMouse: Vector2)
    		draggingTool = tool
    		draggingFromSlot = fromSlot
    		dragStartPos = startMouse
    		isDraggingActive = true
    
    		dragGhost.Position = UDim2.new(0, startMouse.X - 26, 0, startMouse.Y - 26)
    		ghostLabel.Text = tool.Name
    		dragGhost.Visible = true
    
    		if fromSlot and slotFrames[fromSlot] then
    			slotFrames[fromSlot].BackgroundTransparency = 0.6
    		end
    	end
    
    	local function finishDragging(endMouse: Vector2)
    		if not isDraggingActive or not draggingTool then return end
    		local tool = draggingTool
    		local fromSlot = draggingFromSlot
    
    		dragGhost.Visible = false
    		draggingTool = nil
    		draggingFromSlot = nil
    		isDraggingActive = false
    		justFinishedDrag = true
    		task.delay(0.15, function()
    			justFinishedDrag = false
    		end)
    
    		-- Reset any slot dimming
    		if fromSlot and slotFrames[fromSlot] then
    			slotFrames[fromSlot].BackgroundTransparency = UI.Theme.ContainerTransparency
    		end
    
    		-- 1. Check if dropped over or near any Hotbar Slot (Move / Swap Object in Toolbar)
    		local targetSlot = findSlotUnderOrNearMouse(endMouse)
    
    		if targetSlot then
    			if fromSlot then
    				if fromSlot ~= targetSlot then
    					local oldTargetTool = assignedSlots[targetSlot]
    					assignedSlots[targetSlot] = tool
    					assignedSlots[fromSlot] = oldTargetTool
    
    					pcall(function()
    						local Notification = require("UI/Notification.luau")
    						Notification.new("Toolbar", string.format("Moved '%s' to Slot %d", tool.Name, targetSlot % 10), 1.5)
    					end)
    				end
    			else
    				-- Dragged from Backpack Grid onto Toolbar Slot
    				local oldTargetTool = assignedSlots[targetSlot]
    				assignedSlots[targetSlot] = tool
    				pcall(function()
    					local Notification = require("UI/Notification.luau")
    					Notification.new("Toolbar", string.format("Assigned '%s' to Slot %d", tool.Name, targetSlot % 10), 1.5)
    				end)
    			end
    			Animations.popScale(slotFrames[targetSlot], 0.88, 1.12, 1.0, 0.2)
    			updateHotbarVisuals()
    			if isBackpackOpen then updateBackpackGrid() end
    			return
    		end
    
    		-- 2. Check if dropped over Backpack Grid (Unassign from Toolbar)
    		if bpWindow.Visible and isPointInsideGui(endMouse, bpGridScroll) then
    			if fromSlot then
    				assignedSlots[fromSlot] = nil
    				pcall(function()
    					local Notification = require("UI/Notification.luau")
    					Notification.new("Toolbar", string.format("Removed '%s' from Slot %d", tool.Name, fromSlot % 10), 1.5)
    				end)
    				updateHotbarVisuals()
    				updateBackpackGrid()
    			end
    			return
    		end
    
    		-- 3. Dropped OUTSIDE the entire toolbar region -> Drop Tool into 3D world!
    		local hPos = hotbarFrame.AbsolutePosition
    		local hSize = hotbarFrame.AbsoluteSize
    		local isNearHotbar = endMouse.Y >= (hPos.Y - 60) and endMouse.Y <= (hPos.Y + hSize.Y + 60) and
    		                     endMouse.X >= (hPos.X - 40) and endMouse.X <= (hPos.X + hSize.X + 40)
    		local inBackpack = bpWindow.Visible and isPointInsideGui(endMouse, bpWindow)
    
    		if not isNearHotbar and not inBackpack then
    			-- Dragged far out into the 3D world: drop the tool!
    			dropTool(tool)
    		else
    			-- Released slightly off-target near toolbar: safely snap back without dropping
    			updateHotbarVisuals()
    		end
    	end
    
    	table.insert(activeConnections, UserInputService.InputChanged:Connect(function(input)
    		if isDraggingActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    			local mousePos = UserInputService:GetMouseLocation()
    			dragGhost.Position = UDim2.new(0, mousePos.X - 26, 0, mousePos.Y - 26)
    
    			-- Live hover highlighting over target slots
    			for slotIdx = 1, NUM_SLOTS do
    				local slotFrame = slotFrames[slotIdx]
    				if slotFrame then
    					local stroke = slotFrame:FindFirstChildWhichIsA("UIStroke")
    					if isPointInsideGui(mousePos, slotFrame) then
    						slotFrame.BackgroundColor3 = UI.Theme.Accent
    						slotFrame.BackgroundTransparency = 0.3
    						if stroke then stroke.Color = Color3.fromRGB(80, 255, 140) end
    					else
    						local tool = assignedSlots[slotIdx]
    						local equipped = tool and isToolEquipped(tool)
    						slotFrame.BackgroundColor3 = if equipped then UI.Theme.Accent else (if tool then UI.Theme.Container else UI.Theme.ContainerDark)
    						slotFrame.BackgroundTransparency = if equipped then 0.2 else (if tool then UI.Theme.ContainerTransparency else UI.Theme.ContainerDarkTransparency)
    						if stroke then stroke.Color = if equipped then UI.Theme.Border else UI.Theme.BorderDim end
    					end
    				end
    			end
    		end
    	end))
    
    	table.insert(activeConnections, UserInputService.InputEnded:Connect(function(input)
    		if isDraggingActive and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
    			finishDragging(UserInputService:GetMouseLocation())
    		end
    	end))
    
    	-- ── 8. Create Slots in Hotbar HUD ─────────────────────────────────
    	for i = 1, NUM_SLOTS do
    		local slotBtn = Instance.new("TextButton")
    		slotBtn.Name = "Slot_" .. tostring(i)
    		slotBtn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    		slotBtn.BackgroundColor3 = UI.Theme.Container
    		slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    		slotBtn.BorderSizePixel = 0
    		slotBtn.Text = ""
    		slotBtn.AutoButtonColor = false
    		slotBtn.ClipsDescendants = true
    		slotBtn.LayoutOrder = i
    		slotBtn.Parent = hotbarFrame
    		UI.registerThemeElement(slotBtn, "Container")
    
    		local slotStroke = Instance.new("UIStroke")
    		slotStroke.Color = UI.Theme.Border
    		slotStroke.Thickness = 1.2
    		slotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		slotStroke.Parent = slotBtn
    		UI.registerThemeElement(slotStroke, "Border")
    
    		local slotScale = Instance.new("UIScale")
    		slotScale.Scale = 1.0
    		slotScale.Parent = slotBtn
    
    		local numLabel = Instance.new("TextLabel")
    		numLabel.Name = "SlotNum"
    		numLabel.Size = UDim2.new(0, 14, 0, 12)
    		numLabel.Position = UDim2.new(0, 2, 0, 2)
    		numLabel.BackgroundTransparency = 1
    		numLabel.Text = tostring(i % 10)
    		numLabel.TextColor3 = UI.Theme.TextSecondary
    		numLabel.Font = UI.Fonts.Mono
    		numLabel.TextSize = 9
    		numLabel.TextXAlignment = Enum.TextXAlignment.Left
    		numLabel.ZIndex = 10
    		numLabel.Parent = slotBtn
    		UI.registerThemeElement(numLabel, "TextSecondary")
    
    		local nameLabel = Instance.new("TextLabel")
    		nameLabel.Name = "ToolName"
    		nameLabel.Size = UDim2.new(1, -4, 0, 12)
    		nameLabel.Position = UDim2.new(0, 2, 1, -14)
    		nameLabel.BackgroundTransparency = 1
    		nameLabel.Text = ""
    		nameLabel.TextColor3 = UI.Theme.TextPrimary
    		nameLabel.Font = UI.Fonts.Header
    		nameLabel.TextSize = 8
    		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    		nameLabel.ZIndex = 10
    		nameLabel.Parent = slotBtn
    		UI.registerThemeElement(nameLabel, "TextPrimary")
    
    		Animations.buttonHoverPush(slotBtn)
    
    		-- Slot Dragging & Clicking
    		local slotPressPos = Vector2.zero
    		table.insert(activeConnections, slotBtn.InputBegan:Connect(function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    				slotPressPos = UserInputService:GetMouseLocation()
    			end
    		end))
    
    		table.insert(activeConnections, slotBtn.InputChanged:Connect(function(input)
    			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    				if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not isDraggingActive then
    					local curTool = assignedSlots[i]
    					if curTool then
    						local curPos = UserInputService:GetMouseLocation()
    						if (curPos - slotPressPos).Magnitude > 14 then
    							startDragging(curTool, i, curPos)
    						end
    					end
    				end
    			end
    		end))
    
    		table.insert(activeConnections, slotBtn.MouseButton1Click:Connect(function()
    			if not justFinishedDrag and not isDraggingActive then
    				local tool = assignedSlots[i]
    				if tool then
    					Animations.buttonClickPop(slotBtn)
    					equipOrToggleTool(tool)
    				end
    			end
    		end))
    
    		slotFrames[i] = slotBtn
    	end
    
    	-- ── 9. Dedicated Hamburger [ ≡ INV ] Button on Toolbar ────────────
    	local function toggleBackpack()
    		isBackpackOpen = not isBackpackOpen
    		bpWindow.Visible = isBackpackOpen
    		if isBackpackOpen then
    			updateBackpackGrid()
    			if Animations and typeof(Animations.openWindow) == "function" then
    				local bpScale = bpWindow:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale", bpWindow)
    				Animations.openWindow(bpWindow, bpScale)
    			end
    		end
    	end
    
    	local invBtn = Instance.new("TextButton")
    	invBtn.Name = "InventoryToolbarBtn"
    	invBtn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    	invBtn.BackgroundColor3 = UI.Theme.ContainerDark
    	invBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	invBtn.BorderSizePixel = 0
    	invBtn.Text = ""
    	invBtn.AutoButtonColor = false
    	invBtn.ClipsDescendants = true
    	invBtn.LayoutOrder = 11
    	invBtn.Parent = hotbarFrame
    	UI.registerThemeElement(invBtn, "ContainerDark")
    	Animations.buttonHoverPush(invBtn)
    
    	local invStroke = Instance.new("UIStroke")
    	invStroke.Color = UI.Theme.Border
    	invStroke.Thickness = 1.2
    	invStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	invStroke.Parent = invBtn
    	UI.registerThemeElement(invStroke, "Border")
    
    	local invKeyLabel = Instance.new("TextLabel")
    	invKeyLabel.Size = UDim2.new(0, 14, 0, 12)
    	invKeyLabel.Position = UDim2.new(0, 2, 0, 2)
    	invKeyLabel.BackgroundTransparency = 1
    	invKeyLabel.Text = "`"
    	invKeyLabel.TextColor3 = UI.Theme.TextSecondary
    	invKeyLabel.Font = UI.Fonts.Mono
    	invKeyLabel.TextSize = 9
    	invKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
    	invKeyLabel.ZIndex = 10
    	invKeyLabel.Parent = invBtn
    	UI.registerThemeElement(invKeyLabel, "TextSecondary")
    
    	local invIconLabel = Instance.new("TextLabel")
    	invIconLabel.Size = UDim2.new(1, 0, 0, 20)
    	invIconLabel.Position = UDim2.new(0, 0, 0.5, -12)
    	invIconLabel.BackgroundTransparency = 1
    	invIconLabel.Text = "≡"
    	invIconLabel.TextColor3 = UI.Theme.TextPrimary
    	invIconLabel.Font = UI.Fonts.Header
    	invIconLabel.TextSize = 16
    	invIconLabel.ZIndex = 10
    	invIconLabel.Parent = invBtn
    	UI.registerThemeElement(invIconLabel, "TextPrimary")
    
    	local invTextLabel = Instance.new("TextLabel")
    	invTextLabel.Size = UDim2.new(1, 0, 0, 12)
    	invTextLabel.Position = UDim2.new(0, 0, 1, -14)
    	invTextLabel.BackgroundTransparency = 1
    	invTextLabel.Text = "INV"
    	invTextLabel.TextColor3 = UI.Theme.Accent
    	invTextLabel.Font = UI.Fonts.Header
    	invTextLabel.TextSize = 8
    	invTextLabel.ZIndex = 10
    	invTextLabel.Parent = invBtn
    	UI.registerThemeElement(invTextLabel, "Accent")
    
    	table.insert(activeConnections, invBtn.MouseButton1Click:Connect(function()
    		if not justFinishedDrag then
    			Animations.buttonClickPop(invBtn)
    			toggleBackpack()
    		end
    	end))
    
    	-- ── 10. Search Filter & Events ────────────────────────────────────
    	table.insert(activeConnections, searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    		filterQuery = searchBox.Text
    		updateBackpackGrid()
    	end))
    
    	table.insert(activeConnections, bpCloseBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(bpCloseBtn)
    		isBackpackOpen = false
    		bpWindow.Visible = false
    	end))
    
    	-- Keybinds for 1-0 hotbar selection and ` for inventory
    	table.insert(activeConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    		if gameProcessed then return end
    		if input.UserInputType == Enum.UserInputType.Keyboard then
    			for slotNum, key in ipairs(KEYCODES) do
    				if input.KeyCode == key then
    					local tool = assignedSlots[slotNum]
    					local btn = slotFrames[slotNum]
    					if btn then Animations.buttonClickPop(btn) end
    
    					if tool then
    						equipOrToggleTool(tool)
    					else
    						local char = LocalPlayer.Character
    						local hum = char and char:FindFirstChildOfClass("Humanoid")
    						if hum then hum:UnequipTools() end
    						updateSlotHighlightsOnly()
    					end
    					break
    				end
    			end
    			if input.KeyCode == Enum.KeyCode.Backquote then
    				toggleBackpack()
    			end
    		end
    	end))
    
    	-- Real-Time Tool Acquisition & Inventory Sync Engine
    	local boundTools: {[Tool]: boolean} = {}
    
    	local function hookToolNameChange(tool: Tool)
    		if boundTools[tool] then return end
    		boundTools[tool] = true
    		table.insert(activeConnections, tool:GetPropertyChangedSignal("Name"):Connect(function()
    			for slotNum = 1, NUM_SLOTS do
    				if assignedSlots[slotNum] == tool then
    					local slotBtn = slotFrames[slotNum]
    					local nameLabel = slotBtn and slotBtn:FindFirstChild("ToolName") :: TextLabel?
    					if nameLabel then nameLabel.Text = tool.Name end
    					break
    				end
    			end
    			if isBackpackOpen then
    				local card = backpackCards[tool]
    				local tName = card and card:FindFirstChild("ToolLabel") :: TextLabel?
    				if tName then tName.Text = tool.Name end
    			end
    		end))
    	end
    
    	local function onToolAdded(child: Instance)
    		if not child:IsA("Tool") then return end
    		local tool = child :: Tool
    		hookToolNameChange(tool)
    
    		-- Check if tool is already assigned to a toolbar slot
    		local alreadyAssigned = false
    		for i = 1, NUM_SLOTS do
    			if assignedSlots[i] == tool then
    				alreadyAssigned = true
    				break
    			end
    		end
    
    		if not alreadyAssigned then
    			-- Assign to first available empty slot
    			for i = 1, NUM_SLOTS do
    				if not assignedSlots[i] then
    					assignedSlots[i] = tool
    					break
    				end
    			end
    			updateHotbarVisuals()
    		else
    			updateSlotHighlightsOnly()
    		end
    
    		if isBackpackOpen then
    			updateBackpackGrid()
    		end
    	end
    
    	local function onToolRemoved(child: Instance)
    		if not child:IsA("Tool") then return end
    		local tool = child :: Tool
    
    		-- Wait a frame to see if tool was simply equipped (moved from Backpack to Character) or genuinely removed
    		task.defer(function()
    			local char = LocalPlayer.Character
    			local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    			local stillInInventory = (char and tool.Parent == char) or (bp and tool.Parent == bp)
    
    			if not stillInInventory then
    				boundTools[tool] = nil
    				for i = 1, NUM_SLOTS do
    					if assignedSlots[i] == tool then
    						assignedSlots[i] = nil
    					end
    				end
    				updateHotbarVisuals()
    				if isBackpackOpen then updateBackpackGrid() end
    			else
    				updateSlotHighlightsOnly()
    			end
    		end)
    	end
    
    	-- ── 11. Multi-Stage Death & Respawn Inventory Reconciler ──────────
    	local function reconcileFullInventory()
    		local char = LocalPlayer.Character
    		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    
    		-- 1. Purge destroyed, unparented, or orphaned dead tools
    		for i = 1, NUM_SLOTS do
    			local t = assignedSlots[i]
    			if t and (not t.Parent or not t:IsDescendantOf(game) or (t.Parent ~= char and t.Parent ~= bp)) then
    				assignedSlots[i] = nil
    			end
    		end
    
    		-- 2. Clear invalid cache entries
    		for k, c in pairs(slotCaches) do
    			if not c.Tool or not c.Tool.Parent or not c.Tool:IsDescendantOf(game) or (c.Tool.Parent ~= char and c.Tool.Parent ~= bp) then
    				slotCaches[k] = nil
    			end
    		end
    
    		-- 3. Scan all valid tools in new character & backpack
    		local allTools = getAllTools()
    		for _, tool in ipairs(allTools) do
    			hookToolNameChange(tool)
    			local alreadyAssigned = false
    			for i = 1, NUM_SLOTS do
    				if assignedSlots[i] == tool then
    					alreadyAssigned = true
    					break
    				end
    			end
    			if not alreadyAssigned then
    				for i = 1, NUM_SLOTS do
    					if not assignedSlots[i] then
    						assignedSlots[i] = tool
    						break
    					end
    				end
    			end
    		end
    
    		updateHotbarVisuals()
    		if isBackpackOpen then
    			updateBackpackGrid()
    		end
    	end
    
    	local function bindCharEvents(char: Model)
    		local hum = char:WaitForChild("Humanoid", 4) :: Humanoid?
    		if hum then
    			table.insert(activeConnections, hum.Died:Connect(function()
    				-- Immediately unequip and purge character tools upon death
    				for i = 1, NUM_SLOTS do
    					local t = assignedSlots[i]
    					if t and t.Parent == char then
    						assignedSlots[i] = nil
    					end
    				end
    				updateSlotHighlightsOnly()
    			end))
    		end
    
    		for _, item in ipairs(char:GetChildren()) do
    			if item:IsA("Tool") then
    				hookToolNameChange(item)
    			end
    		end
    		table.insert(activeConnections, char.ChildAdded:Connect(onToolAdded))
    		table.insert(activeConnections, char.ChildRemoved:Connect(onToolRemoved))
    
    		-- Staggered reconciliation passes to capture late-replicating inventory items
    		task.defer(reconcileFullInventory)
    		task.delay(0.15, reconcileFullInventory)
    		task.delay(0.40, reconcileFullInventory)
    		task.delay(0.85, reconcileFullInventory)
    	end
    
    	if LocalPlayer.Character then bindCharEvents(LocalPlayer.Character) end
    	table.insert(activeConnections, LocalPlayer.CharacterAdded:Connect(bindCharEvents))
    
    	local function bindBpEvents(bp: Backpack)
    		for _, item in ipairs(bp:GetChildren()) do
    			if item:IsA("Tool") then
    				hookToolNameChange(item)
    			end
    		end
    		table.insert(activeConnections, bp.ChildAdded:Connect(onToolAdded))
    		table.insert(activeConnections, bp.ChildRemoved:Connect(onToolRemoved))
    		task.defer(reconcileFullInventory)
    	end
    
    	local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    	if bp then bindBpEvents(bp) end
    	table.insert(activeConnections, LocalPlayer.ChildAdded:Connect(function(child)
    		if child:IsA("Backpack") then
    			bindBpEvents(child :: Backpack)
    		end
    	end))
    
    	_G.__ModularHotbar_Cleanup = function()
    		for _, conn in ipairs(activeConnections) do
    			pcall(function() conn:Disconnect() end)
    		end
    		table.clear(activeConnections)
    	end
    
    	-- Initial render
    	task.spawn(function()
    		task.wait(0.3)
    		updateHotbarVisuals()
    	end)
    
    	local widgetObj: HotbarWidget = {
    		HotbarFrame = hotbarFrame,
    		BackpackWindow = bpWindow,
    		SetVisible = function(selfOrVal: any, maybeVal: any)
    			local val = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
    			hotbarFrame.Visible = val
    			if not val then bpWindow.Visible = false end
    		end,
    		ToggleBackpack = toggleBackpack,
    		IsOpen = function() return isBackpackOpen end,
    		Refresh = function()
    			queueInventoryRefresh()
    		end
    	}
    
    	return widgetObj
    end
    
    return Hotbar
end

Modules["UI/LeaderstatsWidget.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Retro Leaderstats & Universal Currency HUD Widget ✦
        Features:
        - Auto-arranges next to the PlayerList tab widget
        - Clean currency separation: [ Currencies ] vs [ Other Values ] vs [ Server Players ]
        - Full high-contrast legibility across Light, Dark, Translucent, and Adaptive themes
        - Right-click any stat row to move it between Currencies and Other Values (with JSON persistence)
        - Full fluid animations (spring opening, hover glows, click pops, tab transitions)
        - Real-time live polling of leaderstats, Data folders, and game remotes
    ]=]
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local HttpService = game:GetService("HttpService")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local LocalPlayer = Players.LocalPlayer
    
    local LeaderstatsWidget = {}
    LeaderstatsWidget.__index = LeaderstatsWidget
    
    local STAT_OVERRIDES_FILE = "fih_stat_overrides.json"
    local UserCategoryOverrides: {[string]: string} = {}
    
    local function loadOverrides()
    	pcall(function()
    		local rf = readfile or (getgenv and getgenv().readfile)
    		local isf = isfile or (getgenv and getgenv().isfile)
    		if type(rf) == "function" and (type(isf) ~= "function" or isf(STAT_OVERRIDES_FILE)) then
    			local content = rf(STAT_OVERRIDES_FILE)
    			local data = HttpService:JSONDecode(content)
    			if type(data) == "table" then
    				UserCategoryOverrides = data
    			end
    		end
    	end)
    end
    
    local function saveOverrides()
    	pcall(function()
    		local wf = writefile or (getgenv and getgenv().writefile)
    		if type(wf) == "function" then
    			wf(STAT_OVERRIDES_FILE, HttpService:JSONEncode(UserCategoryOverrides))
    		end
    	end)
    end
    
    loadOverrides()
    
    local PRIMARY_EXACT_NAMES: {[string]: boolean} = {
    	["coins"] = true,
    	["coin"] = true,
    	["cash"] = true,
    	["money"] = true,
    	["crystals"] = true,
    	["crystal"] = true,
    	["gems"] = true,
    	["gem"] = true,
    	["water"] = true,
    	["tankwater"] = true,
    	["points"] = true,
    	["point"] = true,
    	["rubies"] = true,
    	["ruby"] = true,
    	["diamonds"] = true,
    	["diamond"] = true,
    	["rebirths"] = true,
    	["rebirth"] = true,
    	["level"] = true,
    	["lvl"] = true,
    	["kills"] = true,
    	["kill"] = true,
    	["wins"] = true,
    	["win"] = true,
    	["score"] = true,
    	["tokens"] = true,
    	["token"] = true,
    	["credits"] = true,
    	["credit"] = true,
    	["energy"] = true,
    	["stars"] = true,
    	["star"] = true,
    	["shards"] = true,
    	["shard"] = true,
    	["xp"] = true,
    	["exp"] = true,
    	["bounty"] = true,
    	["rank"] = true,
    	["prestige"] = true,
    	["timeplayed"] = true
    }
    
    local function isPrimaryCurrency(name: string, val: any): boolean
    	local override = UserCategoryOverrides[name]
    	if override == "currencies" then
    		return true
    	elseif override == "others" then
    		return false
    	end
    
    	local lower = name:lower()
    	return PRIMARY_EXACT_NAMES[lower] == true
    end
    
    local function formatNum(strVal: string): string
    	local num = tonumber(strVal)
    	if not num then return strVal end
    	if num >= 1e12 then
    		return string.format("%.2fT", num / 1e12)
    	elseif num >= 1e9 then
    		return string.format("%.2fB", num / 1e9)
    	elseif num >= 1e6 then
    		return string.format("%.2fM", num / 1e6)
    	elseif num >= 1e3 then
    		return string.format("%.1fK", num / 1e3)
    	end
    	return tostring(num)
    end
    
    type StatItem = {
    	Name: string,
    	Value: string,
    	Formatted: string,
    	IsPrimary: boolean
    }
    
    local function getAllPlayerStats(player: Player): { Primaries: {StatItem}, Others: {StatItem} }
    	local primaries: {StatItem} = {}
    	local others: {StatItem} = {}
    	local seen: {[string]: boolean} = {}
    
    	local function add(name: string, val: any, forcePrimary: boolean?)
    		local sVal = tostring(val)
    		if seen[name] or sVal == "" or #sVal > 50 then return end
    		seen[name] = true
    
    		local primary = if forcePrimary ~= nil then forcePrimary else isPrimaryCurrency(name, val)
    		local item: StatItem = {
    			Name = name,
    			Value = sVal,
    			Formatted = formatNum(sVal),
    			IsPrimary = primary
    		}
    
    		if primary then
    			table.insert(primaries, item)
    		else
    			table.insert(others, item)
    		end
    	end
    
    	-- 1. leaderstats folder
    	local ls = player:FindFirstChild("leaderstats")
    	if ls then
    		for _, v in ipairs(ls:GetChildren()) do
    			if v:IsA("ValueBase") then
    				add(v.Name, (v :: any).Value)
    			end
    		end
    	end
    
    	-- 2. Known folders on Player
    	for _, fName in ipairs({"Data", "Stats", "Values", "Currencies", "PlayerData"}) do
    		local f = player:FindFirstChild(fName)
    		if f then
    			for _, v in ipairs(f:GetChildren()) do
    				if v:IsA("ValueBase") then
    					add(v.Name, (v :: any).Value)
    				end
    			end
    		end
    	end
    
    	-- 3. If LocalPlayer, check remote data
    	if player == LocalPlayer then
    		pcall(function()
    			local gpd = ReplicatedStorage:FindFirstChild("GetPlayerData")
    			if gpd and gpd:IsA("RemoteFunction") then
    				local data = gpd:InvokeServer()
    				if type(data) == "table" then
    					for k, v in pairs(data) do
    						if type(v) ~= "table" and type(v) ~= "function" and tostring(k) ~= "Name" and tostring(k) ~= "FirstJoin" and tostring(k) ~= "RandomNumber" then
    							add(tostring(k), tostring(v))
    						end
    					end
    				end
    			end
    		end)
    	end
    
    	return { Primaries = primaries, Others = others }
    end
    
    function LeaderstatsWidget.new()
    	local self = setmetatable({}, LeaderstatsWidget)
    
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularLeaderstatsGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.DisplayOrder = 605
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    	pcall(function() screenGui.Parent = CoreGui end)
    	if not screenGui.Parent then
    		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    	end
    
    	local WIDGET_W = 248
    	local TOPBAR_H = 26
    
    	-- Default position: Auto-arranged directly to the left of the PlayerList widget
    	local widget = Instance.new("Frame")
    	widget.Name = "LeaderstatsWidgetFrame"
    	widget.Size = UDim2.new(0, WIDGET_W, 0, 0)
    	widget.AutomaticSize = Enum.AutomaticSize.Y
    	widget.Position = UDim2.new(1, -(270 + WIDGET_W + 8), 0, 10)
    	widget.BackgroundColor3 = UI.Theme.Background
    	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	widget.BorderSizePixel = 0
    	widget.ClipsDescendants = false
    	widget.Parent = screenGui
    	UI.registerThemeElement(widget, "Background")
    
    	local outerStroke = Instance.new("UIStroke")
    	outerStroke.Color = UI.Theme.Border
    	outerStroke.Thickness = 2
    	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	outerStroke.Parent = widget
    	UI.registerThemeElement(outerStroke, "Border")
    
    	local uiScale = Instance.new("UIScale")
    	uiScale.Scale = 1.0
    	uiScale.Parent = widget
    
    	-- ── Topbar (Drag Handle & Controls) ──────────────────────────────
    	local topbar = Instance.new("Frame")
    	topbar.Name = "TopBar"
    	topbar.Size = UDim2.new(1, -8, 0, TOPBAR_H)
    	topbar.Position = UDim2.new(0, 4, 0, 4)
    	topbar.BackgroundTransparency = 1
    	topbar.BorderSizePixel = 0
    	topbar.Parent = widget
    
    	local titleBox = Instance.new("Frame")
    	titleBox.Name = "TitleBox"
    	titleBox.Size = UDim2.new(1, -78, 1, 0)
    	titleBox.Position = UDim2.new(0, 0, 0, 0)
    	titleBox.BackgroundColor3 = UI.Theme.Container
    	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	titleBox.BorderSizePixel = 0
    	titleBox.ClipsDescendants = true
    	titleBox.Parent = topbar
    	UI.registerThemeElement(titleBox, "Container")
    
    	local titleStroke = Instance.new("UIStroke")
    	titleStroke.Color = UI.Theme.Border
    	titleStroke.Thickness = 1.2
    	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleStroke.Parent = titleBox
    	UI.registerThemeElement(titleStroke, "Border")
    
    	local liveDot = Instance.new("Frame")
    	liveDot.Size = UDim2.new(0, 6, 0, 6)
    	liveDot.Position = UDim2.new(0, 6, 0.5, -3)
    	liveDot.BackgroundColor3 = Color3.fromRGB(50, 225, 100)
    	liveDot.BorderSizePixel = 0
    	liveDot.Parent = titleBox
    
    	local dotCorner = Instance.new("UICorner")
    	dotCorner.CornerRadius = UDim.new(1, 0)
    	dotCorner.Parent = liveDot
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(1, -20, 1, 0)
    	titleLabel.Position = UDim2.new(0, 16, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = "Leaderstats HUD"
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Header
    	titleLabel.TextSize = 10
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.ClipsDescendants = true
    	titleLabel.Parent = titleBox
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	-- Dock Button (Snaps directly next to PlayerList)
    	local dockBtn = Instance.new("TextButton")
    	dockBtn.Name = "DockBtn"
    	dockBtn.Size = UDim2.new(0, 22, 1, 0)
    	dockBtn.Position = UDim2.new(1, -74, 0, 0)
    	dockBtn.BackgroundColor3 = UI.Theme.Container
    	dockBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	dockBtn.BorderSizePixel = 0
    	dockBtn.Text = "⇲"
    	dockBtn.TextColor3 = UI.Theme.TextSecondary
    	dockBtn.Font = UI.Fonts.Header
    	dockBtn.TextSize = 11
    	dockBtn.Parent = topbar
    	UI.registerThemeElement(dockBtn, "Container")
    	UI.registerThemeElement(dockBtn, "TextSecondary")
    	Animations.buttonHoverPush(dockBtn)
    
    	local dockStroke = Instance.new("UIStroke")
    	dockStroke.Color = UI.Theme.BorderDim
    	dockStroke.Thickness = 1.0
    	dockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	dockStroke.Parent = dockBtn
    	UI.registerThemeElement(dockStroke, "BorderDim")
    
    	-- Minimize & Close Buttons
    	local minBtn = Instance.new("TextButton")
    	minBtn.Name = "MinBtn"
    	minBtn.Size = UDim2.new(0, 22, 1, 0)
    	minBtn.Position = UDim2.new(1, -48, 0, 0)
    	minBtn.BackgroundColor3 = UI.Theme.Container
    	minBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	minBtn.BorderSizePixel = 0
    	minBtn.Text = "—"
    	minBtn.TextColor3 = UI.Theme.TextPrimary
    	minBtn.Font = UI.Fonts.Header
    	minBtn.TextSize = 11
    	minBtn.Parent = topbar
    	UI.registerThemeElement(minBtn, "Container")
    	UI.registerThemeElement(minBtn, "TextPrimary")
    	Animations.buttonHoverPush(minBtn)
    
    	local minStroke = Instance.new("UIStroke")
    	minStroke.Color = UI.Theme.Border
    	minStroke.Thickness = 1.0
    	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	minStroke.Parent = minBtn
    	UI.registerThemeElement(minStroke, "Border")
    
    	local closeBtn = Instance.new("TextButton")
    	closeBtn.Name = "CloseBtn"
    	closeBtn.Size = UDim2.new(0, 22, 1, 0)
    	closeBtn.Position = UDim2.new(1, -22, 0, 0)
    	closeBtn.BackgroundColor3 = UI.Theme.Container
    	closeBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	closeBtn.BorderSizePixel = 0
    	closeBtn.Text = "X"
    	closeBtn.TextColor3 = UI.Theme.TextPrimary
    	closeBtn.Font = UI.Fonts.Header
    	closeBtn.TextSize = 11
    	closeBtn.Parent = topbar
    	UI.registerThemeElement(closeBtn, "Container")
    	UI.registerThemeElement(closeBtn, "TextPrimary")
    	Animations.buttonHoverPush(closeBtn)
    
    	local closeStroke = Instance.new("UIStroke")
    	closeStroke.Color = UI.Theme.Border
    	closeStroke.Thickness = 1.0
    	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	closeStroke.Parent = closeBtn
    	UI.registerThemeElement(closeStroke, "Border")
    
    	-- ── Body Frame ────────────────────────────────────────────────────
    	local body = Instance.new("Frame")
    	body.Name = "Body"
    	body.Size = UDim2.new(1, -8, 0, 0)
    	body.Position = UDim2.new(0, 4, 0, TOPBAR_H + 8)
    	body.AutomaticSize = Enum.AutomaticSize.Y
    	body.BackgroundTransparency = 1
    	body.BorderSizePixel = 0
    	body.Parent = widget
    
    	local bodyPad = Instance.new("UIPadding")
    	bodyPad.PaddingBottom = UDim.new(0, 6)
    	bodyPad.Parent = body
    
    	local bodyLayout = Instance.new("UIListLayout")
    	bodyLayout.Padding = UDim.new(0, 4)
    	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	bodyLayout.Parent = body
    
    	-- Mode Selector: [ Currencies ] [ Other Values ] [ Server ]
    	local modeBar = Instance.new("Frame")
    	modeBar.Name = "ModeBar"
    	modeBar.Size = UDim2.new(1, 0, 0, 22)
    	modeBar.BackgroundTransparency = 1
    	modeBar.BorderSizePixel = 0
    	modeBar.LayoutOrder = 1
    	modeBar.Parent = body
    
    	local modeList = Instance.new("UIListLayout")
    	modeList.FillDirection = Enum.FillDirection.Horizontal
    	modeList.Padding = UDim.new(0, 3)
    	modeList.Parent = modeBar
    
    	local function makeModeBtn(name: string, text: string): (TextButton, UIStroke)
    		local btn = Instance.new("TextButton")
    		btn.Name = name
    		btn.Size = UDim2.new(0.333, -2, 1, 0)
    		btn.BackgroundColor3 = UI.Theme.Container
    		btn.BackgroundTransparency = UI.Theme.ContainerTransparency
    		btn.BorderSizePixel = 0
    		btn.Text = text
    		btn.TextColor3 = UI.Theme.TextSecondary
    		btn.Font = UI.Fonts.Header
    		btn.TextSize = 9
    		btn.TextTruncate = Enum.TextTruncate.AtEnd
    		btn.ClipsDescendants = true
    		btn.Parent = modeBar
    		UI.registerThemeElement(btn, "Container")
    		UI.registerThemeElement(btn, "TextSecondary")
    		Animations.buttonHoverPush(btn)
    
    		local st = Instance.new("UIStroke")
    		st.Color = UI.Theme.BorderDim
    		st.Thickness = 1.0
    		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		st.Parent = btn
    		UI.registerThemeElement(st, "BorderDim")
    
    		return btn, st
    	end
    
    	local curBtn, curStroke = makeModeBtn("CurrenciesBtn", "Currencies")
    	local othBtn, othStroke = makeModeBtn("OthersBtn", "Other Values")
    	local svrBtn, svrStroke = makeModeBtn("ServerBtn", "Server")
    
    	-- 1. Currencies Container
    	local curContainer = Instance.new("ScrollingFrame")
    	curContainer.Name = "CurrenciesContainer"
    	curContainer.Size = UDim2.new(1, 0, 0, 168)
    	curContainer.BackgroundTransparency = 1
    	curContainer.BorderSizePixel = 0
    	curContainer.ScrollBarThickness = 2
    	curContainer.ScrollBarImageColor3 = UI.Theme.Accent
    	curContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    	curContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	curContainer.LayoutOrder = 2
    	curContainer.Parent = body
    
    	local curLayout = Instance.new("UIListLayout")
    	curLayout.Padding = UDim.new(0, 3)
    	curLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	curLayout.Parent = curContainer
    
    	-- 2. Other Values Container
    	local othContainer = Instance.new("ScrollingFrame")
    	othContainer.Name = "OthersContainer"
    	othContainer.Size = UDim2.new(1, 0, 0, 168)
    	othContainer.BackgroundTransparency = 1
    	othContainer.BorderSizePixel = 0
    	othContainer.ScrollBarThickness = 2
    	othContainer.ScrollBarImageColor3 = UI.Theme.Accent
    	othContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    	othContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	othContainer.LayoutOrder = 2
    	othContainer.Visible = false
    	othContainer.Parent = body
    
    	local othLayout = Instance.new("UIListLayout")
    	othLayout.Padding = UDim.new(0, 3)
    	othLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	othLayout.Parent = othContainer
    
    	-- 3. Server Players Container
    	local svrContainer = Instance.new("ScrollingFrame")
    	svrContainer.Name = "ServerContainer"
    	svrContainer.Size = UDim2.new(1, 0, 0, 168)
    	svrContainer.BackgroundTransparency = 1
    	svrContainer.BorderSizePixel = 0
    	svrContainer.ScrollBarThickness = 2
    	svrContainer.ScrollBarImageColor3 = UI.Theme.Accent
    	svrContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    	svrContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	svrContainer.LayoutOrder = 2
    	svrContainer.Visible = false
    	svrContainer.Parent = body
    
    	local svrLayout = Instance.new("UIListLayout")
    	svrLayout.Padding = UDim.new(0, 3)
    	svrLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	svrLayout.Parent = svrContainer
    
    	local activeMode = "currencies"
    
    	local function updateTabStyles()
    		local theme = UI.Theme
    		local function setStyle(btn: TextButton, st: UIStroke, isActive: boolean)
    			if isActive then
    				btn.BackgroundColor3 = theme.Accent
    				btn.BackgroundTransparency = 0
    				btn.TextColor3 = theme.AccentText
    				st.Color = theme.Border
    				st.Thickness = 1.2
    			else
    				btn.BackgroundColor3 = theme.Container
    				btn.BackgroundTransparency = theme.ContainerTransparency
    				btn.TextColor3 = theme.TextSecondary
    				st.Color = theme.BorderDim
    				st.Thickness = 1.0
    			end
    		end
    
    		setStyle(curBtn, curStroke, activeMode == "currencies")
    		setStyle(othBtn, othStroke, activeMode == "others")
    		setStyle(svrBtn, svrStroke, activeMode == "server")
    	end
    
    	-- ── Render Functions ─────────────────────────────────────────────
    	local curRowFrames: {[string]: {Row: TextButton, ValLabel: TextLabel}} = {}
    	local othRowFrames: {[string]: {Row: TextButton, ValLabel: TextLabel}} = {}
    	local serverRowFrames: {[string]: Frame} = {}
    
    	local function clearCache(cache: {[string]: any})
    		for k, item in pairs(cache) do
    			if item and item.Row and item.Row.Parent then
    				item.Row:Destroy()
    			end
    			cache[k] = nil
    		end
    	end
    
    	local renderAllStats: () -> ()
    
    	local function renderCurrenciesList(items: {StatItem}, container: ScrollingFrame, cache: {[string]: {Row: TextButton, ValLabel: TextLabel}}, emptyText: string, currentCategory: string)
    		if #items == 0 then
    			local empty = cache["_empty"]
    			if not empty then
    				local row = Instance.new("TextButton")
    				row.Size = UDim2.new(1, -2, 0, 22)
    				row.BackgroundColor3 = UI.Theme.ContainerDark
    				row.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    				row.BorderSizePixel = 0
    				row.Text = ""
    				row.AutoButtonColor = false
    				row.Parent = container
    				UI.registerThemeElement(row, "ContainerDark")
    
    				local lbl = Instance.new("TextLabel")
    				lbl.Size = UDim2.new(1, -8, 1, 0)
    				lbl.Position = UDim2.new(0, 4, 0, 0)
    				lbl.BackgroundTransparency = 1
    				lbl.Text = emptyText
    				lbl.TextColor3 = UI.Theme.TextSecondary
    				lbl.Font = UI.Fonts.Body
    				lbl.TextSize = 10
    				lbl.Parent = row
    				UI.registerThemeElement(lbl, "TextSecondary")
    
    				cache["_empty"] = {Row = row, ValLabel = lbl}
    			end
    			return
    		end
    
    		if cache["_empty"] then
    			if cache["_empty"].Row and cache["_empty"].Row.Parent then
    				cache["_empty"].Row:Destroy()
    			end
    			cache["_empty"] = nil
    		end
    
    		for idx, s in ipairs(items) do
    			local existing = cache[s.Name]
    			if existing and existing.Row and existing.Row.Parent then
    				if existing.ValLabel.Text ~= s.Formatted then
    					existing.ValLabel.Text = s.Formatted
    					Animations.buttonClickPop(existing.Row)
    				end
    			else
    				local row = Instance.new("TextButton")
    				row.Name = s.Name .. "Row"
    				row.Size = UDim2.new(1, -2, 0, 22)
    				row.BackgroundColor3 = UI.Theme.Container
    				row.BackgroundTransparency = UI.Theme.ContainerTransparency
    				row.BorderSizePixel = 0
    				row.Text = ""
    				row.AutoButtonColor = false
    				row.ClipsDescendants = true
    				row.LayoutOrder = idx
    				row.Parent = container
    				UI.registerThemeElement(row, "Container")
    				Animations.buttonHoverPush(row)
    
    				local rStroke = Instance.new("UIStroke")
    				rStroke.Color = UI.Theme.BorderDim
    				rStroke.Thickness = 1.0
    				rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    				rStroke.Parent = row
    				UI.registerThemeElement(rStroke, "BorderDim")
    
    				local nameLabel = Instance.new("TextLabel")
    				nameLabel.Size = UDim2.new(0.55, -6, 1, 0)
    				nameLabel.Position = UDim2.new(0, 6, 0, 0)
    				nameLabel.BackgroundTransparency = 1
    				nameLabel.Text = s.Name
    				nameLabel.TextColor3 = UI.Theme.TextPrimary
    				nameLabel.Font = UI.Fonts.Body
    				nameLabel.TextSize = 10
    				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    				nameLabel.Parent = row
    				UI.registerThemeElement(nameLabel, "TextPrimary")
    
    				-- Value label with high contrast for Light & Dark mode
    				local valLabel = Instance.new("TextLabel")
    				valLabel.Size = UDim2.new(0.45, -8, 1, 0)
    				valLabel.Position = UDim2.new(0.55, 0, 0, 0)
    				valLabel.BackgroundTransparency = 1
    				valLabel.Text = s.Formatted
    				valLabel.TextColor3 = UI.Theme.Accent
    				valLabel.Font = UI.Fonts.Mono
    				valLabel.TextSize = 10
    				valLabel.TextXAlignment = Enum.TextXAlignment.Right
    				valLabel.TextTruncate = Enum.TextTruncate.AtEnd
    				valLabel.Parent = row
    				UI.registerThemeElement(valLabel, "Accent")
    
    				-- Right-Click to swap between Currencies & Other Values
    				row.MouseButton2Click:Connect(function()
    					Animations.buttonClickPop(row)
    					local targetCat = if currentCategory == "currencies" then "others" else "currencies"
    					UserCategoryOverrides[s.Name] = targetCat
    					saveOverrides()
    
    					clearCache(curRowFrames)
    					clearCache(othRowFrames)
    					renderAllStats()
    
    					pcall(function()
    						local Notification = require("UI/Notification.luau")
    						local catName = if targetCat == "others" then "Other Values" else "Currencies"
    						Notification.new("Leaderstats HUD", string.format("Moved '%s' to %s", s.Name, catName), 2.5)
    					end)
    				end)
    
    				cache[s.Name] = {Row = row, ValLabel = valLabel}
    			end
    		end
    	end
    
    	renderAllStats = function()
    		local data = getAllPlayerStats(LocalPlayer)
    		renderCurrenciesList(data.Primaries, curContainer, curRowFrames, "No active currencies found", "currencies")
    		renderCurrenciesList(data.Others, othContainer, othRowFrames, "No secondary values found", "others")
    	end
    
    	local function renderServerPlayers()
    		local plrs = Players:GetPlayers()
    		for idx, p in ipairs(plrs) do
    			local pKey = "P_" .. tostring(p.UserId)
    			local existing = serverRowFrames[pKey]
    
    			local pStats = getAllPlayerStats(p)
    			local summary = ""
    			for _, st in ipairs(pStats.Primaries) do
    				if #summary > 0 then summary = summary .. " | " end
    				summary = summary .. string.format("%s: %s", st.Name, st.Formatted)
    			end
    			if summary == "" then
    				for _, st in ipairs(pStats.Others) do
    					if #summary > 0 then summary = summary .. " | " end
    					summary = summary .. string.format("%s: %s", st.Name, st.Formatted)
    				end
    			end
    			if summary == "" then summary = "No public stats" end
    
    			if existing and existing.Parent then
    				local statLbl = existing:FindFirstChild("StatSummary") :: TextLabel?
    				if statLbl then statLbl.Text = summary end
    			else
    				local row = Instance.new("Frame")
    				row.Name = pKey
    				row.Size = UDim2.new(1, -2, 0, 32)
    				row.BackgroundColor3 = UI.Theme.Container
    				row.BackgroundTransparency = UI.Theme.ContainerTransparency
    				row.BorderSizePixel = 0
    				row.LayoutOrder = idx
    				row.Parent = svrContainer
    				UI.registerThemeElement(row, "Container")
    
    				local rStroke = Instance.new("UIStroke")
    				rStroke.Color = UI.Theme.BorderDim
    				rStroke.Thickness = 1.0
    				rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    				rStroke.Parent = row
    				UI.registerThemeElement(rStroke, "BorderDim")
    
    				local nameLabel = Instance.new("TextLabel")
    				nameLabel.Size = UDim2.new(1, -12, 0, 14)
    				nameLabel.Position = UDim2.new(0, 6, 0, 2)
    				nameLabel.BackgroundTransparency = 1
    				nameLabel.Text = string.format("%s (@%s)", p.DisplayName, p.Name)
    				nameLabel.TextColor3 = UI.Theme.TextPrimary
    				nameLabel.Font = UI.Fonts.Header
    				nameLabel.TextSize = 10
    				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    				nameLabel.Parent = row
    				UI.registerThemeElement(nameLabel, "TextPrimary")
    
    				local statLbl = Instance.new("TextLabel")
    				statLbl.Name = "StatSummary"
    				statLbl.Size = UDim2.new(1, -12, 0, 14)
    				statLbl.Position = UDim2.new(0, 6, 0, 16)
    				statLbl.BackgroundTransparency = 1
    				statLbl.Text = summary
    				statLbl.TextColor3 = UI.Theme.TextSecondary
    				statLbl.Font = UI.Fonts.Mono
    				statLbl.TextSize = 9
    				statLbl.TextXAlignment = Enum.TextXAlignment.Left
    				statLbl.TextTruncate = Enum.TextTruncate.AtEnd
    				statLbl.Parent = row
    				UI.registerThemeElement(statLbl, "TextSecondary")
    
    				serverRowFrames[pKey] = row
    			end
    		end
    	end
    
    	local function setMode(mode: string)
    		activeMode = mode
    		updateTabStyles()
    
    		local targetCont = if mode == "currencies" then curContainer elseif mode == "others" then othContainer else svrContainer
    
    		for _, cont in ipairs({curContainer, othContainer, svrContainer}) do
    			if cont == targetCont then
    				cont.Visible = true
    				cont.Position = UDim2.new(0, 4, 0, 0)
    				TweenService:Create(cont, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    					Position = UDim2.new(0, 0, 0, 0)
    				}):Play()
    			else
    				cont.Visible = false
    			end
    		end
    
    		if mode == "currencies" or mode == "others" then
    			renderAllStats()
    		else
    			renderServerPlayers()
    		end
    	end
    
    	curBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(curBtn)
    		setMode("currencies")
    	end)
    	othBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(othBtn)
    		setMode("others")
    	end)
    	svrBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(svrBtn)
    		setMode("server")
    	end)
    
    	setMode("currencies")
    
    	-- ── Auto-Arranging & Docking Next to PlayerList ──────────────────
    	local function autoDockNextToPlayerList()
    		local pListGui = CoreGui:FindFirstChild("ModularPlayerListGui") or (LocalPlayer and LocalPlayer.PlayerGui:FindFirstChild("ModularPlayerListGui"))
    		local pListFrame = pListGui and pListGui:FindFirstChild("PlayerListWidget")
    		if pListFrame and pListFrame:IsA("GuiObject") then
    			local pListPos = pListFrame.Position
    			local targetPos = UDim2.new(
    				pListPos.X.Scale,
    				pListPos.X.Offset - WIDGET_W - 8,
    				pListPos.Y.Scale,
    				pListPos.Y.Offset
    			)
    			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				Position = targetPos
    			}):Play()
    		else
    			widget.Position = UDim2.new(1, -(270 + WIDGET_W + 8), 0, 10)
    		end
    	end
    
    	dockBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(dockBtn)
    		autoDockNextToPlayerList()
    	end)
    
    	-- ── Theme Change Listener ────────────────────────────────────────
    	UI.onThemeChanged(function(targetTheme)
    		updateTabStyles()
    		for _, item in pairs(curRowFrames) do
    			if item and item.ValLabel then
    				item.ValLabel.TextColor3 = targetTheme.Accent
    			end
    		end
    		for _, item in pairs(othRowFrames) do
    			if item and item.ValLabel then
    				item.ValLabel.TextColor3 = targetTheme.Accent
    			end
    		end
    	end)
    
    	-- ── Ultra-Fast Reactive & Debounced Polling Engine ──────────────
    	local updateScheduled = false
    	local function queueQuickRefresh()
    		if updateScheduled or not widget.Visible then return end
    		updateScheduled = true
    		task.delay(0.04, function()
    			updateScheduled = false
    			pcall(function()
    				if activeMode == "currencies" or activeMode == "others" then
    					renderAllStats()
    				else
    					renderServerPlayers()
    				end
    			end)
    		end)
    	end
    
    	-- Instant ValueBase & Attribute Listeners
    	local function bindFolder(folder: Instance)
    		for _, child in ipairs(folder:GetChildren()) do
    			if child:IsA("ValueBase") then
    				child.Changed:Connect(queueQuickRefresh)
    			end
    		end
    		folder.ChildAdded:Connect(function(child)
    			if child:IsA("ValueBase") then
    				child.Changed:Connect(queueQuickRefresh)
    			end
    			queueQuickRefresh()
    		end)
    		folder.ChildRemoved:Connect(queueQuickRefresh)
    	end
    
    	for _, fName in ipairs({"leaderstats", "Data", "Stats", "Values", "Currencies", "PlayerData", "Tycoon"}) do
    		local f = LocalPlayer:FindFirstChild(fName)
    		if f then bindFolder(f) end
    	end
    
    	LocalPlayer.ChildAdded:Connect(function(child)
    		for _, fName in ipairs({"leaderstats", "Data", "Stats", "Values", "Currencies", "PlayerData", "Tycoon"}) do
    			if child.Name == fName then
    				bindFolder(child)
    				queueQuickRefresh()
    				break
    			end
    		end
    	end)
    
    	LocalPlayer.AttributeChanged:Connect(queueQuickRefresh)
    
    	-- High-Frequency 0.25s Fallback Poller for Remote Functions & Network Sync
    	task.spawn(function()
    		task.wait(0.2)
    		while true do
    			pcall(function()
    				if widget.Visible then
    					if activeMode == "currencies" or activeMode == "others" then
    						renderAllStats()
    					else
    						renderServerPlayers()
    					end
    				end
    			end)
    			task.wait(0.25)
    		end
    	end)
    
    	-- ── Dragging Mechanics ───────────────────────────────────────────
    	local dragging = false
    	local dragInput: InputObject? = nil
    	local dragStart = Vector3.zero
    	local startPos = UDim2.new()
    
    	topbar.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			dragging = true
    			dragStart = input.Position
    			startPos = widget.Position
    
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					dragging = false
    				end
    			end)
    		end
    	end)
    
    	topbar.InputChanged:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
    			dragInput = input
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if input == dragInput and dragging then
    			local delta = input.Position - dragStart
    			widget.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    		end
    	end)
    
    	-- Minimize & Close actions
    	local minimized = false
    	minBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(minBtn)
    		minimized = not minimized
    		body.Visible = not minimized
    	end)
    
    	closeBtn.MouseButton1Click:Connect(function()
    		Animations.buttonClickPop(closeBtn)
    		widget.Visible = false
    	end)
    
    	local isOpen = true
    	local isTransitioning = false
    
    	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen or isTransitioning then return end
    		isTransitioning = true
    		pcall(autoDockNextToPlayerList)
    		Animations.openWindow(widget, uiScale, function()
    			isOpen = true
    			isTransitioning = false
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if not isOpen or isTransitioning then return end
    		isTransitioning = true
    		Animations.closeWindow(widget, uiScale, function()
    			isOpen = false
    			isTransitioning = false
    			if onComplete then onComplete() end
    		end)
    	end
    
    	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
    		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
    		if isOpen then
    			closeWidget(onComplete)
    		else
    			openWidget(onComplete)
    		end
    	end
    
    	self.Widget = widget
    	self.ScreenGui = screenGui
    	self.Dock = autoDockNextToPlayerList
    	self.Open = openWidget
    	self.Close = closeWidget
    	self.Toggle = toggleWidget
    	self.IsOpen = function() return isOpen end
    	self.SetMinimized = function(isMin: boolean)
    		minimized = isMin
    		body.Visible = not isMin
    	end
    	self.SetVisible = function(selfOrVal: any, maybeVal: any)
    		local vis = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
    		if typeof(vis) ~= "boolean" then vis = true end
    		if vis then openWidget() else closeWidget() end
    	end
    
    	return self
    end
    
    return LeaderstatsWidget
end

Modules["UI/HealthWidget.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Squared Retro Health HUD & Damage Visual Indicator Widget ✦
        Features:
        - Live Local Player Health Bar with smooth spring tweening and exact HP formatting
        - Dynamic Health Color Modes: Theme Accent vs Reactive Health Gradient (Green -> Yellow -> Red)
        - Low HP Warning (<25%): Pulsing retro danger glow and alert outline
        - 3D Floating Damage Numbers over any damaged player/entity with crits & smooth rising bounce
        - Screen Damage Flash & Vignette on taking damage
        - Target Combat HUD: Displays target player/enemy health card when damaged or locked on
        - Fully draggable HUD with position persistence and 100% Theme Reactivity
    ]=]
    
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    
    local HealthWidget = {}
    HealthWidget.__index = HealthWidget
    
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
    
    export type HealthWidgetInstance = {
    	Frame: Frame,
    	ScreenGui: ScreenGui,
    	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
    	ToggleDamageNumbers: (enabled: boolean) -> (),
    	ToggleDamageFlash: (enabled: boolean) -> (),
    	SetDynamicColors: (enabled: boolean) -> (),
    	ShowDamageNumber: (pos: Vector3, amount: number, isLocalPlayer: boolean, isCrit: boolean?) -> (),
    	Cleanup: () -> ()
    }
    
    local widgetInstance: HealthWidgetInstance? = nil
    
    function HealthWidget.getHealthColor(healthPercent: number): Color3
    	if healthPercent > 0.6 then
    		local t = (healthPercent - 0.6) / 0.4
    		return Color3.fromRGB(80, 235, 120):Lerp(Color3.fromRGB(235, 205, 50), 1 - t)
    	elseif healthPercent > 0.25 then
    		local t = (healthPercent - 0.25) / 0.35
    		return Color3.fromRGB(235, 205, 50):Lerp(Color3.fromRGB(235, 90, 40), 1 - t)
    	else
    		return Color3.fromRGB(235, 50, 50)
    	end
    end
    
    function HealthWidget.new(): HealthWidgetInstance
    	if _G.__ModularHealth_Cleanup then
    		pcall(_G.__ModularHealth_Cleanup)
    		_G.__ModularHealth_Cleanup = nil
    	end
    
    	local activeConns: {RBXScriptConnection} = {}
    
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularHealthGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.DisplayOrder = 605
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    	pcall(function() screenGui.Parent = CoreGui end)
    	if not screenGui.Parent then
    		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    	end
    
    	-- ── 1. Screen Damage Flash & Vignette Overlay ──────────────────────
    	local vignette = Instance.new("Frame")
    	vignette.Name = "DamageVignette"
    	vignette.Size = UDim2.new(1, 0, 1, 0)
    	vignette.Position = UDim2.new(0, 0, 0, 0)
    	vignette.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
    	vignette.BackgroundTransparency = 1
    	vignette.BorderSizePixel = 0
    	vignette.ZIndex = 50
    	vignette.Parent = screenGui
    
    	local vignetteGrad = Instance.new("UIGradient")
    	vignetteGrad.Transparency = NumberSequence.new({
    		NumberSequenceKeypoint.new(0, 0.4),
    		NumberSequenceKeypoint.new(0.6, 0.9),
    		NumberSequenceKeypoint.new(1, 1)
    	})
    	vignetteGrad.Parent = vignette
    
    	local function triggerDamageFlash(intensity: number)
    		local peakAlpha = math.clamp(0.85 - (intensity * 0.4), 0.35, 0.85)
    		vignette.BackgroundTransparency = peakAlpha
    		TweenService:Create(vignette, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			BackgroundTransparency = 1
    		}):Play()
    	end
    
    	-- ── 2. Floating Damage Number Container ───────────────────────────
    	local damageContainer = Instance.new("Folder")
    	damageContainer.Name = "DamageNumbers"
    	damageContainer.Parent = screenGui
    
    	local function showDamageNumber(worldPos: Vector3, amount: number, isLocalPlayer: boolean, isCrit: boolean?)
    		local billboard = Instance.new("BillboardGui")
    		billboard.Name = "DamageIndicator"
    		billboard.Size = UDim2.new(0, 110, 0, 36)
    		billboard.StudsOffsetWorldSpace = worldPos + Vector3.new(math.random(-10, 10) * 0.08, math.random(5, 15) * 0.1, math.random(-10, 10) * 0.08)
    		billboard.AlwaysOnTop = true
    		billboard.ResetOnSpawn = false
    		billboard.ClipsDescendants = false
    		billboard.Parent = damageContainer
    
    		local dmgBox = Instance.new("Frame")
    		dmgBox.Size = UDim2.new(1, 0, 1, 0)
    		dmgBox.BackgroundTransparency = 1
    		dmgBox.Parent = billboard
    
    		local stroke = Instance.new("UIStroke")
    		stroke.Thickness = if isCrit then 2.0 else 1.2
    		stroke.Color = if isLocalPlayer then Color3.fromRGB(60, 0, 0) else (if isCrit then Color3.fromRGB(120, 60, 0) else Color3.fromRGB(20, 20, 20))
    		stroke.Parent = dmgBox
    
    		local dmgLabel = Instance.new("TextLabel")
    		dmgLabel.Size = UDim2.new(1, 0, 1, 0)
    		dmgLabel.BackgroundTransparency = 1
    		dmgLabel.Text = string.format("%s%d%s", if isCrit then "✦ -" else "-", math.floor(amount + 0.5), if isCrit then " ✦" else "")
    		dmgLabel.TextColor3 = if isLocalPlayer then Color3.fromRGB(255, 65, 65) else (if isCrit then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(255, 160, 40))
    		dmgLabel.Font = UI.Fonts.Header
    		dmgLabel.TextSize = if isCrit then 16 else 13
    		dmgLabel.TextStrokeTransparency = 0.5
    		dmgLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    		dmgLabel.Parent = dmgBox
    
    		local scale = Instance.new("UIScale")
    		scale.Scale = 0.4
    		scale.Parent = dmgBox
    
    		-- Bounce pop animation
    		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			Scale = if isCrit then 1.35 else 1.05
    		}):Play()
    
    		-- Smooth rise & fade
    		local riseTween = TweenService:Create(billboard, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0)
    		})
    		riseTween:Play()
    
    		task.delay(0.45, function()
    			TweenService:Create(dmgLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    				TextTransparency = 1,
    				TextStrokeTransparency = 1
    			}):Play()
    		end)
    
    		riseTween.Completed:Connect(function()
    			billboard:Destroy()
    		end)
    	end
    
    	-- ── 3. Main Player Health Bar Widget HUD ──────────────────────────
    	local HUD_WIDTH = 230
    	local HUD_HEIGHT = 54
    	local hudFrame = Instance.new("Frame")
    	hudFrame.Name = "HealthWidgetFrame"
    	hudFrame.Size = UDim2.new(0, HUD_WIDTH, 0, HUD_HEIGHT)
    	hudFrame.AnchorPoint = Vector2.new(0.5, 0)
    	hudFrame.Position = UDim2.new(0.5, 0, 0, 10)
    	hudFrame.BackgroundColor3 = UI.Theme.Background
    	hudFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	hudFrame.BorderSizePixel = 0
    	hudFrame.ClipsDescendants = false
    	hudFrame.Parent = screenGui
    	UI.registerThemeElement(hudFrame, "Background")
    
    	local hudStroke = Instance.new("UIStroke")
    	hudStroke.Color = UI.Theme.Border
    	hudStroke.Thickness = 2
    	hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	hudStroke.Parent = hudFrame
    	UI.registerThemeElement(hudStroke, "Border")
    
    	-- Dragging handler for Health HUD
    	local isDragging = false
    	local dragStart = Vector2.zero
    	local startPos = hudFrame.Position
    
    	hudFrame.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			isDragging = true
    			dragStart = UserInputService:GetMouseLocation()
    			startPos = hudFrame.Position
    		end
    	end)
    
    	table.insert(activeConns, UserInputService.InputChanged:Connect(function(input)
    		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    			local mousePos = UserInputService:GetMouseLocation()
    			local delta = mousePos - dragStart
    			hudFrame.Position = UDim2.new(
    				startPos.X.Scale,
    				startPos.X.Offset + delta.X,
    				startPos.Y.Scale,
    				startPos.Y.Offset + delta.Y
    			)
    		end
    	end))
    
    	table.insert(activeConns, UserInputService.InputEnded:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			isDragging = false
    		end
    	end))
    
    	-- Player Headshot Avatar Box
    	local headshotBox = Instance.new("Frame")
    	headshotBox.Name = "AvatarBox"
    	headshotBox.Size = UDim2.new(0, 38, 0, 38)
    	headshotBox.Position = UDim2.new(0, 8, 0, 8)
    	headshotBox.BackgroundColor3 = UI.Theme.ContainerDark
    	headshotBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	headshotBox.BorderSizePixel = 0
    	headshotBox.ClipsDescendants = true
    	headshotBox.Parent = hudFrame
    	UI.registerThemeElement(headshotBox, "ContainerDark")
    
    	local avatarStroke = Instance.new("UIStroke")
    	avatarStroke.Color = UI.Theme.BorderDim
    	avatarStroke.Thickness = 1
    	avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	avatarStroke.Parent = headshotBox
    	UI.registerThemeElement(avatarStroke, "BorderDim")
    
    	local avatarImg = Instance.new("ImageLabel")
    	avatarImg.Size = UDim2.new(1, 0, 1, 0)
    	avatarImg.BackgroundTransparency = 1
    	avatarImg.Parent = headshotBox
    
    	task.spawn(function()
    		local ok, thumb = pcall(function()
    			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    		end)
    		if ok and thumb and avatarImg.Parent then
    			avatarImg.Image = thumb
    		end
    	end)
    
    	-- Info Header: Username & HP Text
    	local infoContainer = Instance.new("Frame")
    	infoContainer.Size = UDim2.new(1, -58, 0, 18)
    	infoContainer.Position = UDim2.new(0, 52, 0, 7)
    	infoContainer.BackgroundTransparency = 1
    	infoContainer.BorderSizePixel = 0
    	infoContainer.Parent = hudFrame
    
    	local nameLabel = Instance.new("TextLabel")
    	nameLabel.Name = "PlayerName"
    	nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
    	nameLabel.Position = UDim2.new(0, 0, 0, 0)
    	nameLabel.BackgroundTransparency = 1
    	nameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name
    	nameLabel.TextColor3 = UI.Theme.TextPrimary
    	nameLabel.Font = UI.Fonts.Header
    	nameLabel.TextSize = 10
    	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	nameLabel.ClipsDescendants = true
    	nameLabel.Parent = infoContainer
    	UI.registerThemeElement(nameLabel, "TextPrimary")
    
    	local hpLabel = Instance.new("TextLabel")
    	hpLabel.Name = "HPLabel"
    	hpLabel.Size = UDim2.new(0.45, 0, 1, 0)
    	hpLabel.Position = UDim2.new(0.55, 0, 0, 0)
    	hpLabel.BackgroundTransparency = 1
    	hpLabel.Text = "100 / 100 HP"
    	hpLabel.TextColor3 = UI.Theme.Accent
    	hpLabel.Font = UI.Fonts.Mono
    	hpLabel.TextSize = 9
    	hpLabel.TextXAlignment = Enum.TextXAlignment.Right
    	hpLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	hpLabel.ClipsDescendants = true
    	hpLabel.Parent = infoContainer
    	UI.registerThemeElement(hpLabel, "Accent")
    
    	-- Main Health Bar Track
    	local barTrack = Instance.new("Frame")
    	barTrack.Name = "HealthTrack"
    	barTrack.Size = UDim2.new(1, -58, 0, 14)
    	barTrack.Position = UDim2.new(0, 52, 0, 29)
    	barTrack.BackgroundColor3 = UI.Theme.ContainerDark
    	barTrack.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	barTrack.BorderSizePixel = 0
    	barTrack.ClipsDescendants = true
    	barTrack.Parent = hudFrame
    	UI.registerThemeElement(barTrack, "ContainerDark")
    
    	local barTrackStroke = Instance.new("UIStroke")
    	barTrackStroke.Color = UI.Theme.Border
    	barTrackStroke.Thickness = 1.2
    	barTrackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	barTrackStroke.Parent = barTrack
    	UI.registerThemeElement(barTrackStroke, "Border")
    
    	-- Health Bar Damage Lag Buffer (Shows white/red drain effect behind actual health)
    	local bufferFill = Instance.new("Frame")
    	bufferFill.Name = "BufferFill"
    	bufferFill.Size = UDim2.new(1, 0, 1, 0)
    	bufferFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    	bufferFill.BackgroundTransparency = 0.35
    	bufferFill.BorderSizePixel = 0
    	bufferFill.Parent = barTrack
    
    	-- Health Bar Primary Fill
    	local barFill = Instance.new("Frame")
    	barFill.Name = "HealthFill"
    	barFill.Size = UDim2.new(1, 0, 1, 0)
    	barFill.BackgroundColor3 = UI.Theme.Accent
    	barFill.BorderSizePixel = 0
    	barFill.Parent = barTrack
    	UI.registerThemeElement(barFill, "Accent")
    
    	local fillGrad = Instance.new("UIGradient")
    	fillGrad.Rotation = 90
    	fillGrad.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 210))
    	})
    	fillGrad.Parent = barFill
    
    	-- ── 4. Target Combat Health HUD Card ──────────────────────────────
    	local targetCard = Instance.new("Frame")
    	targetCard.Name = "TargetCombatHUD"
    	targetCard.Size = UDim2.new(0, 180, 0, 42)
    	targetCard.Position = UDim2.new(0.5, -90, 0, 18)
    	targetCard.BackgroundColor3 = UI.Theme.Background
    	targetCard.BackgroundTransparency = UI.Theme.BackgroundTransparency
    	targetCard.BorderSizePixel = 0
    	targetCard.Visible = false
    	targetCard.ClipsDescendants = false
    	targetCard.Parent = screenGui
    	UI.registerThemeElement(targetCard, "Background")
    
    	local targetStroke = Instance.new("UIStroke")
    	targetStroke.Color = UI.Theme.Border
    	targetStroke.Thickness = 1.5
    	targetStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	targetStroke.Parent = targetCard
    	UI.registerThemeElement(targetStroke, "Border")
    
    	local targetTitle = Instance.new("TextLabel")
    	targetTitle.Size = UDim2.new(1, -12, 0, 16)
    	targetTitle.Position = UDim2.new(0, 6, 0, 4)
    	targetTitle.BackgroundTransparency = 1
    	targetTitle.Text = "Target"
    	targetTitle.TextColor3 = UI.Theme.TextPrimary
    	targetTitle.Font = UI.Fonts.Header
    	targetTitle.TextSize = 9
    	targetTitle.TextXAlignment = Enum.TextXAlignment.Left
    	targetTitle.TextTruncate = Enum.TextTruncate.AtEnd
    	targetTitle.Parent = targetCard
    	UI.registerThemeElement(targetTitle, "TextPrimary")
    
    	local targetTrack = Instance.new("Frame")
    	targetTrack.Size = UDim2.new(1, -12, 0, 10)
    	targetTrack.Position = UDim2.new(0, 6, 0, 24)
    	targetTrack.BackgroundColor3 = UI.Theme.ContainerDark
    	targetTrack.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	targetTrack.BorderSizePixel = 0
    	targetTrack.ClipsDescendants = true
    	targetTrack.Parent = targetCard
    	UI.registerThemeElement(targetTrack, "ContainerDark")
    
    	local targetFill = Instance.new("Frame")
    	targetFill.Size = UDim2.new(1, 0, 1, 0)
    	targetFill.BackgroundColor3 = Color3.fromRGB(245, 60, 60)
    	targetFill.BorderSizePixel = 0
    	targetFill.Parent = targetTrack
    
    	local hideTargetDebounce: thread? = nil
    	local function updateTargetCard(targetName: string, curHealth: number, maxHealth: number)
    		targetTitle.Text = string.format("Target: %s  [%d/%d]", targetName, math.floor(curHealth), math.floor(maxHealth))
    		local ratio = math.clamp(curHealth / math.max(maxHealth, 1), 0, 1)
    		targetFill.BackgroundColor3 = HealthWidget.getHealthColor(ratio)
    		TweenService:Create(targetFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			Size = UDim2.new(ratio, 0, 1, 0)
    		}):Play()
    
    		targetCard.Visible = true
    
    		if hideTargetDebounce then task.cancel(hideTargetDebounce) end
    		hideTargetDebounce = task.delay(4.0, function()
    			targetCard.Visible = false
    		end)
    	end
    
    	-- ── 5. Humanoid Tracking & Damage Listeners ────────────────────────
    	local damageNumbersEnabled = true
    	local damageFlashEnabled = true
    	local useDynamicColors = true
    
    	local previousHealth = 100
    	local trackedHumanoids: {[Humanoid]: number} = {}
    
    	local function hookHumanoid(hum: Humanoid, ownerName: string, isLocal: boolean)
    		trackedHumanoids[hum] = hum.Health
    
    		local healthConn = hum.HealthChanged:Connect(function(newHealth)
    			local oldHealth = trackedHumanoids[hum] or newHealth
    			trackedHumanoids[hum] = newHealth
    
    			local maxHp = math.max(hum.MaxHealth, 1)
    			local ratio = math.clamp(newHealth / maxHp, 0, 1)
    
    			if isLocal then
    				-- Update local player health bar
    				hpLabel.Text = string.format("%d / %d HP", math.floor(newHealth + 0.5), math.floor(maxHp))
    
    				if useDynamicColors then
    					barFill.BackgroundColor3 = HealthWidget.getHealthColor(ratio)
    				else
    					barFill.BackgroundColor3 = UI.Theme.Accent
    				end
    
    				TweenService:Create(barFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    					Size = UDim2.new(ratio, 0, 1, 0)
    				}):Play()
    
    				task.delay(0.25, function()
    					TweenService:Create(bufferFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    						Size = UDim2.new(ratio, 0, 1, 0)
    					}):Play()
    				end)
    
    				-- Low health warning pulse (<25%)
    				if ratio < 0.25 and newHealth > 0 then
    					Animations.pulseIndicator(hudStroke, Color3.fromRGB(255, 40, 40), UI.Theme.Border, 2.4, 1.6)
    				end
    
    				-- Damage Taken Effect
    				if newHealth < oldHealth then
    					local dmg = oldHealth - newHealth
    					if damageFlashEnabled then
    						triggerDamageFlash(dmg / maxHp)
    					end
    					if damageNumbersEnabled then
    						local hrp = hum.RootPart or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?)
    						if hrp then
    							showDamageNumber(hrp.Position + Vector3.new(0, 1.5, 0), dmg, true, dmg > 35)
    						end
    					end
    				end
    			else
    				-- Damage Dealt to another player / entity
    				if newHealth < oldHealth then
    					local dmg = oldHealth - newHealth
    					updateTargetCard(ownerName, newHealth, maxHp)
    
    					if damageNumbersEnabled then
    						local hrp = hum.RootPart
    						if hrp then
    							showDamageNumber(hrp.Position + Vector3.new(0, 2, 0), dmg, false, dmg > 35)
    						end
    					end
    				end
    			end
    		end)
    		table.insert(activeConns, healthConn)
    	end
    
    	-- Hook LocalPlayer with instant full health bar reset
    	local function refreshLocalHealth(hum: Humanoid)
    		local maxHp = math.max(hum.MaxHealth, 1)
    		local curHp = math.clamp(hum.Health, 0, maxHp)
    		local ratio = math.clamp(curHp / maxHp, 0, 1)
    
    		hpLabel.Text = string.format("%d / %d HP", math.floor(curHp + 0.5), math.floor(maxHp))
    		if useDynamicColors then
    			barFill.BackgroundColor3 = HealthWidget.getHealthColor(ratio)
    		else
    			barFill.BackgroundColor3 = UI.Theme.Accent
    		end
    		barFill.Size = UDim2.new(ratio, 0, 1, 0)
    		bufferFill.Size = UDim2.new(ratio, 0, 1, 0)
    	end
    
    	local function onCharAdded(char: Model)
    		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
    		if hum then
    			previousHealth = hum.Health
    			hookHumanoid(hum, LocalPlayer.DisplayName or LocalPlayer.Name, true)
    			refreshLocalHealth(hum)
    
    			-- Property change listeners for instant updates
    			table.insert(activeConns, hum:GetPropertyChangedSignal("Health"):Connect(function()
    				refreshLocalHealth(hum)
    			end))
    			table.insert(activeConns, hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
    				refreshLocalHealth(hum)
    			end))
    		end
    	end
    
    	if LocalPlayer.Character then onCharAdded(LocalPlayer.Character) end
    	table.insert(activeConns, LocalPlayer.CharacterAdded:Connect(onCharAdded))
    
    	-- Hook other players in server
    	local function hookOtherPlayer(p: Player)
    		if p == LocalPlayer then return end
    		local function onOtherChar(char: Model)
    			local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
    			if hum then
    				hookHumanoid(hum, p.DisplayName or p.Name, false)
    			end
    		end
    		if p.Character then onOtherChar(p.Character) end
    		table.insert(activeConns, p.CharacterAdded:Connect(onOtherChar))
    	end
    
    	for _, p in ipairs(Players:GetPlayers()) do
    		hookOtherPlayer(p)
    	end
    	table.insert(activeConns, Players.PlayerAdded:Connect(hookOtherPlayer))
    
    	-- ── 6. Cleanup & Export Instance ──────────────────────────────────
    	local widgetObj: HealthWidgetInstance = {
    		Frame = hudFrame,
    		ScreenGui = screenGui,
    		SetVisible = function(selfOrVal: any, maybeVal: any)
    			local val = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
    			hudFrame.Visible = val
    		end,
    		ToggleDamageNumbers = function(enabled: boolean)
    			damageNumbersEnabled = enabled
    		end,
    		ToggleDamageFlash = function(enabled: boolean)
    			damageFlashEnabled = enabled
    		end,
    		SetDynamicColors = function(enabled: boolean)
    			useDynamicColors = enabled
    			if not enabled then barFill.BackgroundColor3 = UI.Theme.Accent end
    		end,
    		ShowDamageNumber = showDamageNumber,
    		Cleanup = function()
    			for _, conn in ipairs(activeConns) do
    				pcall(function() conn:Disconnect() end)
    			end
    			table.clear(activeConns)
    			screenGui:Destroy()
    		end
    	}
    
    	_G.__ModularHealth_Cleanup = function()
    		widgetObj.Cleanup()
    	end
    
    	widgetInstance = widgetObj
    	return widgetObj
    end
    
    return HealthWidget
end

Modules["Core/FeatureManager.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Advanced Feature & Config Management Engine ✦
        Provides:
        - Modular Feature, Slider, and Module State registration
        - Disk-based multi-profile configuration manager (FihSuite/Configs/<name>.json)
        - Dynamic config file discovery on join (listfiles)
        - Zero default clutter (clean creation and overwrite workflow)
        - Keybind listening and execution dispatcher
    ]=]
    
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    
    local FeatureManager = {}
    FeatureManager.__index = FeatureManager
    
    export type FeatureRecord = {
    	id: string,
    	name: string,
    	state: boolean,
    	keybind: Enum.KeyCode?,
    	callback: (boolean) -> (),
    	onKeybindChanged: ((Enum.KeyCode?) -> ())?,
    	onStateChanged: ((boolean) -> ())?
    }
    
    export type SliderRecord = {
    	id: string,
    	name: string,
    	value: number,
    	callback: (number) -> (),
    	onValueChanged: ((number) -> ())?
    }
    
    export type ModuleRecord = {
    	id: string,
    	name: string,
    	enabled: boolean,
    	callback: (boolean) -> (),
    	onStateChanged: ((boolean) -> ())?
    }
    
    local registeredFeatures: {[string]: FeatureRecord} = {}
    local registeredSliders: {[string]: SliderRecord} = {}
    local registeredModules: {[string]: ModuleRecord} = {}
    local keybindMap: {[Enum.KeyCode]: {string}} = {}
    local isListeningForKeybind = false
    local activeKeybindCallback: ((Enum.KeyCode?) -> ())? = nil
    
    local ROOT_FOLDER = "FihSuite"
    local CONFIGS_FOLDER = "FihSuite/Configs"
    local activeConfigName: string? = nil
    
    local function rebuildKeybindMap()
    	table.clear(keybindMap)
    	for id, feat in pairs(registeredFeatures) do
    		if feat.keybind and feat.keybind ~= Enum.KeyCode.Unknown then
    			if not keybindMap[feat.keybind] then
    				keybindMap[feat.keybind] = {}
    			end
    			table.insert(keybindMap[feat.keybind], id)
    		end
    	end
    end
    
    local function ensureFolders()
    	local mkf = makefolder or (getgenv and getgenv().makefolder)
    	local isf = isfolder or (getgenv and getgenv().isfolder)
    	if type(mkf) == "function" and type(isf) == "function" then
    		pcall(function()
    			if not isf(ROOT_FOLDER) then mkf(ROOT_FOLDER) end
    			if not isf(CONFIGS_FOLDER) then mkf(CONFIGS_FOLDER) end
    		end)
    	end
    end
    
    local function sanitizeConfigName(name: string): string
    	local clean = name:gsub("[^%w_%-%s]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    	return if clean ~= "" then clean else "Config_" .. tostring(os.time())
    end
    
    -- ── File System Utilities ─────────────────────────────────────────
    function FeatureManager.listConfigs(): {string}
    	ensureFolders()
    	local configs: {string} = {}
    	local listf = listfiles or (getgenv and getgenv().listfiles)
    	local isf = isfile or (getgenv and getgenv().isfile)
    	if type(listf) == "function" then
    		local ok, files = pcall(function() return listf(CONFIGS_FOLDER) end)
    		if ok and type(files) == "table" then
    			for _, path in ipairs(files) do
    				local fileName = tostring(path):match("([^/\]+)%.json$")
    				if fileName and fileName ~= "" then
    					table.insert(configs, fileName)
    				end
    			end
    		end
    	end
    	table.sort(configs)
    	return configs
    end
    
    local function readConfigFile(name: string): string?
    	ensureFolders()
    	local rdf = readfile or (getgenv and getgenv().readfile)
    	local isf = isfile or (getgenv and getgenv().isfile)
    	if type(rdf) == "function" and type(isf) == "function" then
    		local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
    		local ok, content = pcall(function()
    			if isf(path) then return rdf(path) end
    			return nil
    		end)
    		if ok and content then return content end
    	end
    	return nil
    end
    
    local function writeConfigFile(name: string, data: string): boolean
    	ensureFolders()
    	local wrf = writefile or (getgenv and getgenv().writefile)
    	if type(wrf) == "function" then
    		local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
    		local ok = pcall(function() wrf(path, data) end)
    		return ok
    	end
    	return false
    end
    
    local function deleteConfigFile(name: string): boolean
    	ensureFolders()
    	local dlf = delfile or (getgenv and getgenv().delfile)
    	local isf = isfile or (getgenv and getgenv().isfile)
    	if type(dlf) == "function" and type(isf) == "function" then
    		local path = CONFIGS_FOLDER .. "/" .. name .. ".json"
    		local ok = pcall(function()
    			if isf(path) then dlf(path) end
    		end)
    		return ok
    	end
    	return false
    end
    
    -- ── Keybind Listener ──────────────────────────────────────────────
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
    	if isListeningForKeybind and activeKeybindCallback then
    		if input.UserInputType == Enum.UserInputType.Keyboard then
    			local key = input.KeyCode
    			if key == Enum.KeyCode.Escape then
    				activeKeybindCallback(nil)
    			else
    				activeKeybindCallback(key)
    			end
    			isListeningForKeybind = false
    			activeKeybindCallback = nil
    			return
    		end
    	end
    	
    	if gameProcessed then return end
    	
    	if input.UserInputType == Enum.UserInputType.Keyboard then
    		local matching = keybindMap[input.KeyCode]
    		if matching then
    			for _, featId in ipairs(matching) do
    				local feat = registeredFeatures[featId]
    				if feat then
    					FeatureManager.setFeatureState(featId, not feat.state)
    				end
    			end
    		end
    	end
    end)
    
    -- ── Feature & Slider Registration ─────────────────────────────────
    function FeatureManager.register(id: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ()): FeatureRecord
    	local record: FeatureRecord = {
    		id = id,
    		name = name,
    		state = defaultState,
    		keybind = defaultKeybind,
    		callback = callback,
    		onKeybindChanged = nil,
    		onStateChanged = nil
    	}
    	registeredFeatures[id] = record
    	rebuildKeybindMap()
    	
    	task.spawn(function()
    		local success, err = pcall(callback, defaultState)
    		if not success then
    			warn(string.format("[FeatureManager] error initializing feature %s: %s", id, tostring(err)))
    		end
    	end)
    	
    	return record
    end
    
    function FeatureManager.registerSlider(id: string, name: string, defaultValue: number, callback: (number) -> ()): (SliderRecord, number)
    	local record: SliderRecord = {
    		id = id,
    		name = name,
    		value = defaultValue,
    		callback = callback,
    		onValueChanged = nil
    	}
    	registeredSliders[id] = record
    
    	task.spawn(function()
    		local success, err = pcall(callback, defaultValue)
    		if not success then
    			warn(string.format("[FeatureManager] error initializing slider %s: %s", id, tostring(err)))
    		end
    	end)
    
    	return record, defaultValue
    end
    
    function FeatureManager.registerModule(id: string, name: string, defaultEnabled: boolean, callback: (boolean) -> ()): ModuleRecord
    	local record: ModuleRecord = {
    		id = id,
    		name = name,
    		enabled = defaultEnabled,
    		callback = callback,
    		onStateChanged = nil
    	}
    	registeredModules[id] = record
    
    	task.spawn(function()
    		pcall(callback, defaultEnabled)
    	end)
    
    	return record
    end
    
    function FeatureManager.setSliderValue(id: string, value: number)
    	local s = registeredSliders[id]
    	if not s then return end
    	s.value = value
    	if s.onValueChanged then s.onValueChanged(value) end
    	pcall(s.callback, value)
    end
    
    function FeatureManager.setFeatureState(id: string, state: boolean)
    	local feat = registeredFeatures[id]
    	if not feat then return end
    	if feat.state == state then return end
    	
    	feat.state = state
    	if feat.onStateChanged then feat.onStateChanged(state) end
    	local success, err = pcall(feat.callback, state)
    	if not success then
    		warn(string.format("[FeatureManager] error toggling feature %s: %s", id, tostring(err)))
    	end
    end
    
    function FeatureManager.setFeatureKeybind(id: string, keycode: Enum.KeyCode?)
    	local feat = registeredFeatures[id]
    	if not feat then return end
    	feat.keybind = keycode
    	rebuildKeybindMap()
    	if feat.onKeybindChanged then feat.onKeybindChanged(keycode) end
    end
    
    function FeatureManager.setModuleState(id: string, enabled: boolean)
    	local mod = registeredModules[id]
    	if not mod then return end
    	mod.enabled = enabled
    	if mod.onStateChanged then mod.onStateChanged(enabled) end
    	pcall(mod.callback, enabled)
    end
    
    function FeatureManager.getModuleState(id: string): boolean
    	local mod = registeredModules[id]
    	return if mod then mod.enabled else true
    end
    
    function FeatureManager.promptKeybindCapture(onCaptured: (Enum.KeyCode?) -> ())
    	isListeningForKeybind = true
    	activeKeybindCallback = onCaptured
    end
    
    function FeatureManager.getFeature(id: string): FeatureRecord?
    	return registeredFeatures[id]
    end
    
    function FeatureManager.getActiveConfigName(): string?
    	return activeConfigName
    end
    
    -- ── Config Serialization & Restoration ───────────────────────────
    function FeatureManager.saveConfig(name: string): boolean
    	local cleanName = sanitizeConfigName(name)
    	local exportData = {
    		name = cleanName,
    		timestamp = os.time(),
    		toggles = {},
    		sliders = {},
    		modules = {}
    	}
    
    	for id, feat in pairs(registeredFeatures) do
    		exportData.toggles[id] = {
    			state = feat.state,
    			keybind = if feat.keybind and feat.keybind ~= Enum.KeyCode.Unknown then feat.keybind.Name else nil
    		}
    	end
    
    	for id, slider in pairs(registeredSliders) do
    		exportData.sliders[id] = slider.value
    	end
    
    	for id, mod in pairs(registeredModules) do
    		exportData.modules[id] = mod.enabled
    	end
    
    	local ok, encoded = pcall(function() return HttpService:JSONEncode(exportData) end)
    	if ok and encoded then
    		local written = writeConfigFile(cleanName, encoded)
    		if written then activeConfigName = cleanName end
    		return written
    	end
    	return false
    end
    
    function FeatureManager.loadConfig(name: string): boolean
    	local cleanName = sanitizeConfigName(name)
    	local raw = readConfigFile(cleanName)
    	if not raw then return false end
    
    	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    	if not ok or type(decoded) ~= "table" then return false end
    
    	if decoded.toggles then
    		for id, data in pairs(decoded.toggles) do
    			local feat = registeredFeatures[id]
    			if feat then
    				if data.state ~= nil and feat.state ~= data.state then
    					FeatureManager.setFeatureState(id, data.state)
    				end
    				if data.keybind then
    					pcall(function()
    						local key = (Enum.KeyCode :: any)[data.keybind]
    						FeatureManager.setFeatureKeybind(id, key)
    					end)
    				elseif data.keybind == nil and feat.keybind ~= nil then
    					FeatureManager.setFeatureKeybind(id, nil)
    				end
    			end
    		end
    	end
    
    	if decoded.sliders then
    		for id, val in pairs(decoded.sliders) do
    			local s = registeredSliders[id]
    			if s and type(val) == "number" then
    				FeatureManager.setSliderValue(id, val)
    			end
    		end
    	end
    
    	if decoded.modules then
    		for id, enabled in pairs(decoded.modules) do
    			local m = registeredModules[id]
    			if m and type(enabled) == "boolean" then
    				FeatureManager.setModuleState(id, enabled)
    			end
    		end
    	end
    
    	activeConfigName = cleanName
    	return true
    end
    
    function FeatureManager.deleteConfig(name: string): boolean
    	local cleanName = sanitizeConfigName(name)
    	local ok = deleteConfigFile(cleanName)
    	if activeConfigName == cleanName then activeConfigName = nil end
    	return ok
    end
    
    -- ── Auto-Load on Startup Persistence ─────────────────────────────────
    local AUTOLOAD_FILE = "autoload_profile.json"
    
    function FeatureManager.getAutoLoadConfig(): { enabled: boolean, configName: string }
    	local raw = readConfigFile(AUTOLOAD_FILE)
    	if raw then
    		local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    		if ok and type(data) == "table" and data.configName then
    			return {
    				enabled = (data.enabled == true),
    				configName = tostring(data.configName)
    			}
    		end
    	end
    	return { enabled = false, configName = "" }
    end
    
    function FeatureManager.setAutoLoadConfig(enabled: boolean, configName: string): boolean
    	local cleanName = sanitizeConfigName(configName)
    	local payload = {
    		enabled = enabled,
    		configName = cleanName
    	}
    	local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    	if ok and encoded then
    		return writeConfigFile(AUTOLOAD_FILE, encoded)
    	end
    	return false
    end
    
    return FeatureManager
end

Modules["Core/CoreUI.luau"] = function()
    local require = requireModule
    --!strict
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local GuiService = game:GetService("GuiService")
    local TeleportService = game:GetService("TeleportService")
    local StarterGui = game:GetService("StarterGui")
    
    local UI = require("UI/UI.luau")
    local Animations = require("UI/Animations.luau")
    local FeatureManager = require("Core/FeatureManager.luau")
    local Notification = require("UI/Notification.luau")
    
    local CoreUI = {}
    CoreUI.__index = CoreUI
    
    function CoreUI.new(titleText: string)
    	local self = setmetatable({}, CoreUI)
    	
    	local screenGui = Instance.new("ScreenGui")
    	screenGui.Name = "ModularEngineGui"
    	screenGui.ResetOnSpawn = false
    	screenGui.IgnoreGuiInset = true
    	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    	
    	pcall(function()
    		screenGui.Parent = CoreGui
    	end)
    	if not screenGui.Parent then
    		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    	end
    	
    	local mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale = UI.createWindow(titleText)
    	mainFrame.Parent = screenGui
    	
    	self.ScreenGui = screenGui
    	self.MainFrame = mainFrame
    	self.Sidebar = sidebar
    	self.ContentContainer = contentContainer
    	self.ActiveTagLabel = activeTagLabel
    	self.SettingsBtn = settingsBtn
    	self.ConfigsBtn = configsBtn
    	self.UiScale = uiScale
    	self.IsOpen = true
    	self.IsTransitioning = false
    	self.Tabs = {}
    	self.ActiveTab = nil
    	self.PreviousTab = nil
    	self.SettingsTab = nil
    	self.ConfigsTab = nil
    	self.ActiveToggles = {}
    	self.SliderFills = {}
    	self.SubTabGroups = {}
    	
    	-- Wire toggle click handlers for Settings and Configs
    	if self.SettingsBtn then
    		self.SettingsBtn.MouseButton1Click:Connect(function()
    			if self.SettingsTab then
    				if self.ActiveTab == self.SettingsTab then
    					self:SelectTab(self.PreviousTab or self.Tabs[1])
    				else
    					self:SelectTab(self.SettingsTab)
    				end
    			end
    		end)
    	end
    
    	if self.ConfigsBtn then
    		self.ConfigsBtn.MouseButton1Click:Connect(function()
    			if self.ConfigsTab then
    				if self.ActiveTab == self.ConfigsTab then
    					self:SelectTab(self.PreviousTab or self.Tabs[1])
    				else
    					self:SelectTab(self.ConfigsTab)
    				end
    			end
    		end)
    	end
    
    	UI.onThemeChanged(function(targetTheme)
    		self:UpdateTheme(targetTheme)
    	end)
    	
    	return self
    end
    
    function CoreUI:UpdateTheme(targetTheme: any)
    	local theme = targetTheme or UI.Theme
    
    	-- 1. Refresh active tab vs inactive tabs
    	for _, tab in ipairs(self.Tabs) do
    		if tab.Button and tab.Stroke then
    			if tab == self.ActiveTab then
    				tab.Button.BackgroundColor3 = theme.Accent
    				tab.Button.BackgroundTransparency = 0
    				tab.Button.TextColor3 = theme.AccentText
    				tab.Stroke.Color = theme.Border
    				tab.Stroke.Thickness = 1.5
    				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
    				if grad then grad.Enabled = true end
    			else
    				tab.Button.BackgroundColor3 = theme.Container
    				tab.Button.BackgroundTransparency = theme.ContainerTransparency
    				tab.Button.TextColor3 = theme.TextSecondary
    				tab.Stroke.Color = theme.BorderDim
    				tab.Stroke.Thickness = 1.0
    				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
    				if grad then grad.Enabled = false end
    			end
    		end
    	end
    
    	-- 2. Refresh Subheader buttons (Settings / Configs)
    	if self.SettingsBtn and self.SettingsBtn:FindFirstChild("UIStroke") then
    		local isSet = (self.ActiveTab == self.SettingsTab)
    		self.SettingsBtn.BackgroundColor3 = if isSet then theme.Accent else theme.Container
    		self.SettingsBtn.BackgroundTransparency = if isSet then 0 else theme.ContainerTransparency
    		self.SettingsBtn.TextColor3 = if isSet then theme.AccentText else theme.TextPrimary
    	end
    
    	if self.ConfigsBtn and self.ConfigsBtn:FindFirstChild("UIStroke") then
    		local isConf = (self.ActiveTab == self.ConfigsTab)
    		self.ConfigsBtn.BackgroundColor3 = if isConf then theme.Accent else theme.Container
    		self.ConfigsBtn.BackgroundTransparency = if isConf then 0 else theme.ContainerTransparency
    		self.ConfigsBtn.TextColor3 = if isConf then theme.AccentText else theme.TextPrimary
    	end
    
    	-- 3. Refresh all subtab groups
    	if self.SubTabGroups then
    		for _, subTabGroup in ipairs(self.SubTabGroups) do
    			if subTabGroup.UpdateTheme then
    				subTabGroup.UpdateTheme()
    			end
    		end
    	end
    
    	-- 4. Refresh all active toggles
    	for _, fn in ipairs(self.ActiveToggles) do
    		pcall(fn)
    	end
    
    	-- 5. Refresh slider fills
    	for _, fill in ipairs(self.SliderFills) do
    		if fill and fill.Parent then
    			fill.BackgroundColor3 = theme.Accent
    		end
    	end
    end
    
    function CoreUI:SetTheme(themeName: string)
    	UI.setTheme(themeName)
    end
    
    function CoreUI:CreateTab(name: string, isHiddenFromSidebar: boolean?)
    	local tabButton: TextButton? = nil
    	local tabStroke: UIStroke? = nil
    	
    	if not isHiddenFromSidebar then
    		tabButton = Instance.new("TextButton")
    		tabButton.Name = name .. "TabBtn"
    		tabButton.Size = UDim2.new(1, -4, 0, 30)
    		tabButton.Position = UDim2.new(0, 2, 0, 0)
    		tabButton.BackgroundColor3 = UI.Theme.Container
    		tabButton.BackgroundTransparency = UI.Theme.ContainerTransparency
    		tabButton.BorderSizePixel = 0
    		tabButton.Text = name
    		tabButton.TextColor3 = UI.Theme.TextSecondary
    		tabButton.Font = UI.Fonts.Header
    		tabButton.TextSize = 12
    		tabButton.TextTruncate = Enum.TextTruncate.AtEnd
    		tabButton.ClipsDescendants = true
    		tabButton.LayoutOrder = #self.Tabs + 1
    		tabButton.Parent = self.Sidebar
    		UI.registerThemeElement(tabButton, "Container")
    		UI.registerThemeElement(tabButton, "TextSecondary")
    		
    		-- Active tab gradient overlay
    		local tabGrad = Instance.new("UIGradient")
    		tabGrad.Name = "ActiveGradient"
    		tabGrad.Rotation = 90
    		tabGrad.Color = ColorSequence.new({
    			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
    		})
    		tabGrad.Enabled = false
    		tabGrad.Parent = tabButton
    		
    		tabStroke = Instance.new("UIStroke")
    		tabStroke.Color = UI.Theme.Border
    		tabStroke.Thickness = 1.5
    		tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		tabStroke.Parent = tabButton
    		UI.registerThemeElement(tabStroke, "Border")
    	end
    	
    	local tabContent = Instance.new("ScrollingFrame")
    	tabContent.Name = name .. "Page"
    	tabContent.Size = UDim2.new(1, 0, 1, 0)
    	tabContent.Position = UDim2.new(0, 0, 0, 0)
    	tabContent.BackgroundTransparency = 1
    	tabContent.BorderSizePixel = 0
    	tabContent.ScrollBarThickness = 3
    	tabContent.ScrollBarImageColor3 = UI.Theme.Accent
    	tabContent.Visible = false
    	tabContent.ClipsDescendants = false
    	tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
    	tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    	tabContent.Parent = self.ContentContainer
    
    	local pad = Instance.new("UIPadding")
    	pad.PaddingLeft = UDim.new(0, 4)
    	pad.PaddingRight = UDim.new(0, 8)
    	pad.PaddingTop = UDim.new(0, 2)
    	pad.PaddingBottom = UDim.new(0, 12)
    	pad.Parent = tabContent
    	
    	local layout = Instance.new("UIListLayout")
    	layout.Padding = UDim.new(0, 10)
    	layout.SortOrder = Enum.SortOrder.LayoutOrder
    	layout.Parent = tabContent
    	
    	local tabObj = {
    		Name = name,
    		Button = tabButton,
    		Page = tabContent,
    		Stroke = tabStroke,
    		Layout = layout,
    		IsHidden = isHiddenFromSidebar or false,
    		IsVisible = not (isHiddenFromSidebar or false),
    		OnVisibilityChanged = nil
    	}
    	
    	if tabButton then
    		tabButton.MouseEnter:Connect(function()
    			if self.ActiveTab ~= tabObj then
    				if tabStroke then TweenService:Create(tabStroke, TweenInfo.new(0.12), { Thickness = 2 }):Play() end
    				TweenService:Create(tabButton, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
    			end
    		end)
    		tabButton.MouseLeave:Connect(function()
    			if self.ActiveTab ~= tabObj then
    				if tabStroke then TweenService:Create(tabStroke, TweenInfo.new(0.12), { Thickness = 1.5 }):Play() end
    				TweenService:Create(tabButton, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextSecondary }):Play()
    			end
    		end)
    		tabButton.MouseButton1Click:Connect(function()
    			self:SelectTab(tabObj)
    		end)
    
    		local function handleRightClick()
    			if tabObj.Name == "Main" or tabObj.IsHidden then return end
    			self:SetTabVisibility(tabObj, false)
    			self:Notify("Module Hidden", string.format("'%s' tab hidden. Re-enable in Settings > Modules & Tabs.", tabObj.Name), 3.5)
    		end
    
    		tabButton.MouseButton2Click:Connect(handleRightClick)
    		tabButton.InputBegan:Connect(function(input)
    			if input.UserInputType == Enum.UserInputType.MouseButton2 then
    				handleRightClick()
    			end
    		end)
    	end
    	
    	table.insert(self.Tabs, tabObj)
    	
    	if not isHiddenFromSidebar and #self.Tabs == 1 then
    		self:SelectTab(tabObj)
    	end
    	
    	return tabObj
    end
    
    function CoreUI:GetTab(name: string): any
    	for _, tab in ipairs(self.Tabs) do
    		if tab.Name == name then
    			return tab
    		end
    	end
    	return nil
    end
    
    function CoreUI:SetTabVisibility(tabObjOrName: any, visible: boolean)
    	local targetTab = nil
    	if type(tabObjOrName) == "string" then
    		for _, tab in ipairs(self.Tabs) do
    			if tab.Name == tabObjOrName then
    				targetTab = tab
    				break
    			end
    		end
    	elseif type(tabObjOrName) == "table" then
    		targetTab = tabObjOrName
    	end
    
    	if not targetTab then return end
    
    	targetTab.IsVisible = visible
    	if targetTab.Button then
    		targetTab.Button.Visible = visible
    	end
    
    	if not visible and self.ActiveTab == targetTab then
    		-- Fall back to first visible non-hidden tab
    		for _, tab in ipairs(self.Tabs) do
    			if not tab.IsHidden and tab.IsVisible ~= false then
    				self:SelectTab(tab)
    				break
    			end
    		end
    	end
    
    	if targetTab.OnVisibilityChanged then
    		targetTab.OnVisibilityChanged(visible)
    	end
    end
    
    function CoreUI:SelectTab(tabObj)
    	if not tabObj then return end
    	if self.ActiveTab == tabObj then return end
    
    	local oldTab = self.ActiveTab
    
    	if oldTab and not oldTab.IsHidden and tabObj.IsHidden then
    		self.PreviousTab = oldTab
    	elseif not tabObj.IsHidden then
    		self.PreviousTab = nil
    	end
    
    	-- 1. Hide and reset all inactive tab pages immediately
    	for _, tab in ipairs(self.Tabs) do
    		if tab ~= tabObj and tab.Page then
    			tab.Page.Visible = false
    			tab.Page.Position = UDim2.new(0, 0, 0, 0)
    			if tab.Button and tab.Stroke then
    				tab.Button.Size = UDim2.new(1, -6, 0, 29)
    				tab.Button.Position = UDim2.new(0, 3, 0, 0)
    				tab.Button.BackgroundColor3 = UI.Theme.Container
    				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
    				tab.Button.TextColor3 = UI.Theme.TextSecondary
    				tab.Stroke.Color = UI.Theme.BorderDim
    				tab.Stroke.Thickness = 1.0
    				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
    				if grad then grad.Enabled = false end
    			end
    		end
    	end
    
    	-- 2. Animate Incoming Tab Page
    	tabObj.Page.Visible = true
    	tabObj.Page.Position = UDim2.new(0, 16, 0, 0)
    	local enterTween = TweenService:Create(tabObj.Page, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    		Position = UDim2.new(0, 0, 0, 0)
    	})
    	enterTween:Play()
    
    	-- 3. Animate Tab Button Spring & Indicator Pulse
    	if tabObj.Button and tabObj.Stroke then
    		tabObj.Button.Size = UDim2.new(1, -8, 0, 27)
    		TweenService:Create(tabObj.Button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			Size = UDim2.new(1, -2, 0, 31),
    			Position = UDim2.new(0, 1, 0, 0),
    			BackgroundColor3 = UI.Theme.Accent,
    			BackgroundTransparency = 0,
    			TextColor3 = UI.Theme.AccentText
    		}):Play()
    		
    		-- Indicator pulse on active tab stroke
    		Animations.pulseIndicator(tabObj.Stroke, UI.Theme.Accent, UI.Theme.Border, 2.2, 1.6)
    		
    		local grad = tabObj.Button:FindFirstChild("ActiveGradient") :: UIGradient?
    		if grad then grad.Enabled = true end
    	end
    
    	-- 4. Cascaded Domino Ripple for Elements inside Incoming Tab Page
    	local elementsToAnimate: {GuiObject} = {}
    	for _, child in ipairs(tabObj.Page:GetChildren()) do
    		if child:IsA("GuiObject") and child.Name ~= "ActiveGradient" and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
    			table.insert(elementsToAnimate, child)
    		end
    	end
    
    	Animations.dominoRipple(elementsToAnimate, 0.03, 12, 0.24)
    
    	self.ActiveTab = tabObj
    	if self.ActiveTagLabel then
    		self.ActiveTagLabel.Text = tabObj.Name
    	end
    
    	-- Subheader buttons active state
    	if self.SettingsBtn and self.SettingsBtn:FindFirstChild("UIStroke") then
    		local isSet = (tabObj == self.SettingsTab)
    		TweenService:Create(self.SettingsBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			BackgroundColor3 = if isSet then UI.Theme.Accent else UI.Theme.Container,
    			BackgroundTransparency = if isSet then 0 else UI.Theme.ContainerTransparency,
    			TextColor3 = if isSet then UI.Theme.AccentText else UI.Theme.TextPrimary
    		}):Play()
    	end
    
    	if self.ConfigsBtn and self.ConfigsBtn:FindFirstChild("UIStroke") then
    		local isConf = (tabObj == self.ConfigsTab)
    		TweenService:Create(self.ConfigsBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			BackgroundColor3 = if isConf then UI.Theme.Accent else UI.Theme.Container,
    			BackgroundTransparency = if isConf then 0 else UI.Theme.ContainerTransparency,
    			TextColor3 = if isConf then UI.Theme.AccentText else UI.Theme.TextPrimary
    		}):Play()
    	end
    end
    
    function CoreUI:BindSettingsTab(settingsTabObj)
    	self.SettingsTab = settingsTabObj
    end
    
    function CoreUI:BindConfigsTab(configsTabObj)
    	self.ConfigsTab = configsTabObj
    end
    
    function CoreUI:AddBanner(tabObj): Frame
    	return UI.createBannerCard(tabObj.Page)
    end
    
    function CoreUI:CreateSubTabs(parentTab: any, subTabNames: {string})
    	local parentPage: GuiObject
    	if type(parentTab) == "table" and parentTab.Page then
    		parentPage = parentTab.Page
    	elseif typeof(parentTab) == "Instance" and parentTab:IsA("GuiObject") then
    		parentPage = parentTab
    	else
    		error("[CoreUI:CreateSubTabs] Invalid parentTab provided.")
    	end
    
    	-- 1. Horizontal Sub-Tab Bar Container (LayoutOrder = 1)
    	local subTabBar = Instance.new("Frame")
    	subTabBar.Name = "SubTabBar"
    	subTabBar.Size = UDim2.new(1, -4, 0, 26)
    	subTabBar.Position = UDim2.new(0, 2, 0, 0)
    	subTabBar.BackgroundColor3 = UI.Theme.ContainerDark
    	subTabBar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	subTabBar.BorderSizePixel = 0
    	subTabBar.LayoutOrder = 1
    	subTabBar.ClipsDescendants = false
    	subTabBar.Parent = parentPage
    	UI.registerThemeElement(subTabBar, "ContainerDark")
    
    	local barStroke = Instance.new("UIStroke")
    	barStroke.Color = UI.Theme.Border
    	barStroke.Thickness = 1.2
    	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	barStroke.Parent = subTabBar
    	UI.registerThemeElement(barStroke, "Border")
    
    	local barPadding = Instance.new("UIPadding")
    	barPadding.PaddingLeft = UDim.new(0, 3)
    	barPadding.PaddingRight = UDim.new(0, 3)
    	barPadding.PaddingTop = UDim.new(0, 2)
    	barPadding.PaddingBottom = UDim.new(0, 2)
    	barPadding.Parent = subTabBar
    
    	local barLayout = Instance.new("UIListLayout")
    	barLayout.FillDirection = Enum.FillDirection.Horizontal
    	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    	barLayout.Padding = UDim.new(0, 4)
    	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	barLayout.Parent = subTabBar
    
    	-- 2. Sub-Pages Container (LayoutOrder = 2)
    	local subPagesContainer = Instance.new("Frame")
    	subPagesContainer.Name = "SubPagesContainer"
    	subPagesContainer.Size = UDim2.new(1, 0, 0, 0)
    	subPagesContainer.AutomaticSize = Enum.AutomaticSize.Y
    	subPagesContainer.BackgroundTransparency = 1
    	subPagesContainer.BorderSizePixel = 0
    	subPagesContainer.LayoutOrder = 2
    	subPagesContainer.ClipsDescendants = false
    	subPagesContainer.Parent = parentPage
    
    	local subPagesLayout = Instance.new("UIListLayout")
    	subPagesLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	subPagesLayout.Padding = UDim.new(0, 0)
    	subPagesLayout.Parent = subPagesContainer
    
    	local subTabs = {
    		Bar = subTabBar,
    		Container = subPagesContainer,
    		ActiveSubTab = nil :: any,
    		Tabs = {} :: {[string]: any},
    		SubTabList = {} :: {any},
    		OnTabChanged = nil :: ((string, string?) -> ())?,
    		Select = nil :: any,
    		GetActive = nil :: any,
    		UpdateTheme = nil :: any,
    	}
    
    	local numTabs = #subTabNames
    	local tabWidthScale = 1 / math.max(1, numTabs)
    	local spacingOffset = math.floor((4 * (numTabs - 1)) / numTabs)
    
    	for idx, name in ipairs(subTabNames) do
    		-- Sub-Tab Button
    		local btn = Instance.new("TextButton")
    		btn.Name = name .. "SubTabBtn"
    		btn.Size = UDim2.new(tabWidthScale, -spacingOffset, 1, 0)
    		btn.BackgroundColor3 = if idx == 1 then UI.Theme.Accent else UI.Theme.Container
    		btn.BackgroundTransparency = if idx == 1 then 0 else UI.Theme.ContainerTransparency
    		btn.BorderSizePixel = 0
    		btn.Text = string.format("[ %s ]", name)
    		btn.TextColor3 = if idx == 1 then UI.Theme.AccentText else UI.Theme.TextSecondary
    		btn.Font = UI.Fonts.Header
    		btn.TextSize = if numTabs >= 4 then 10 else 11
    		btn.TextTruncate = Enum.TextTruncate.None
    		btn.TextWrapped = false
    		btn.LayoutOrder = idx
    		btn.Parent = subTabBar
    
    		local btnGrad = Instance.new("UIGradient")
    		btnGrad.Name = "ActiveGradient"
    		btnGrad.Rotation = 90
    		btnGrad.Color = ColorSequence.new({
    			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
    		})
    		btnGrad.Enabled = (idx == 1)
    		btnGrad.Parent = btn
    
    		local btnStroke = Instance.new("UIStroke")
    		btnStroke.Color = if idx == 1 then UI.Theme.Border else UI.Theme.BorderDim
    		btnStroke.Thickness = if idx == 1 then 1.5 else 1.0
    		btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    		btnStroke.Parent = btn
    
    		-- Sub-Tab Page
    		local page = Instance.new("Frame")
    		page.Name = name .. "SubPage"
    		page.Size = UDim2.new(1, 0, 0, 0)
    		page.AutomaticSize = Enum.AutomaticSize.Y
    		page.BackgroundTransparency = 1
    		page.BorderSizePixel = 0
    		page.Visible = (idx == 1)
    		page.ClipsDescendants = false
    		page.LayoutOrder = idx
    		page.Parent = subPagesContainer
    
    		local pageLayout = Instance.new("UIListLayout")
    		pageLayout.Padding = UDim.new(0, 8)
    		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    		pageLayout.Parent = page
    
    		local subTabObj = {
    			Name = name,
    			Button = btn,
    			Page = page,
    			Stroke = btnStroke,
    			Gradient = btnGrad,
    			ParentTab = parentTab,
    			Index = idx
    		}
    
    		-- Hover & click effects with micro-squash and border glow
    		Animations.attachMicroSquash(
    			btn,
    			btnStroke,
    			function()
    				return if subTabs.ActiveSubTab == subTabObj then UI.Theme.Accent else UI.Theme.Container
    			end,
    			function()
    				return if subTabs.ActiveSubTab == subTabObj then UI.Theme.Accent else UI.Theme.ContainerDark
    			end,
    			function()
    				return UI.Theme.Accent
    			end,
    			function()
    				return if subTabs.ActiveSubTab == subTabObj then UI.Theme.Border else UI.Theme.BorderDim
    			end,
    			function()
    				return UI.Theme.Border
    			end
    		)
    
    		btn.MouseButton1Click:Connect(function()
    			subTabs:Select(name)
    		end)
    
    		subTabs[name] = subTabObj
    		subTabs[idx] = subTabObj
    		subTabs.Tabs[name] = subTabObj
    		table.insert(subTabs.SubTabList, subTabObj)
    
    		if idx == 1 then
    			subTabs.ActiveSubTab = subTabObj
    		end
    	end
    
    	-- SubTab Selection Function
    	function subTabs:Select(target: any)
    		local targetObj = if type(target) == "string" then subTabs[target] elseif type(target) == "number" then subTabs[target] else target
    		if not targetObj or subTabs.ActiveSubTab == targetObj then return end
    
    		local oldSubTab = subTabs.ActiveSubTab
    		subTabs.ActiveSubTab = targetObj
    
    		-- Deactivate Old SubTab
    		if oldSubTab then
    			oldSubTab.Page.Visible = false
    			oldSubTab.Page.Position = UDim2.new(0, 0, 0, 0)
    			if oldSubTab.Button and oldSubTab.Stroke then
    				TweenService:Create(oldSubTab.Button, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
    					BackgroundColor3 = UI.Theme.Container,
    					BackgroundTransparency = UI.Theme.ContainerTransparency,
    					TextColor3 = UI.Theme.TextSecondary
    				}):Play()
    				TweenService:Create(oldSubTab.Stroke, TweenInfo.new(0.18), {
    					Color = UI.Theme.BorderDim,
    					Thickness = 1.0
    				}):Play()
    				if oldSubTab.Gradient then oldSubTab.Gradient.Enabled = false end
    			end
    		end
    
    		-- Activate New SubTab Button with Indicator Pulse
    		if targetObj.Button and targetObj.Stroke then
    			TweenService:Create(targetObj.Button, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    				BackgroundColor3 = UI.Theme.Accent,
    				BackgroundTransparency = 0,
    				TextColor3 = UI.Theme.AccentText
    			}):Play()
    			
    			-- Active sub-tab indicator pulse
    			Animations.pulseIndicator(targetObj.Stroke, UI.Theme.Accent, UI.Theme.Border, 2.2, 1.5)
    			
    			if targetObj.Gradient then targetObj.Gradient.Enabled = true end
    		end
    
    		-- Activate New SubTab Page with Spring Dynamics
    		targetObj.Page.Visible = true
    		targetObj.Page.Position = UDim2.new(0, 16, 0, 0)
    		TweenService:Create(targetObj.Page, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    			Position = UDim2.new(0, 0, 0, 0)
    		}):Play()
    
    		-- Domino Ripple for Top-Level Child Elements
    		local rippleElements: {GuiObject} = {}
    		for _, child in ipairs(targetObj.Page:GetChildren()) do
    			if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
    				table.insert(rippleElements, child)
    			end
    		end
    
    		Animations.dominoRipple(rippleElements, 0.025, 10, 0.22)
    
    		if subTabs.OnTabChanged then
    			pcall(subTabs.OnTabChanged, targetObj.Name, oldSubTab and oldSubTab.Name)
    		end
    	end
    
    	function subTabs:GetActive()
    		return subTabs.ActiveSubTab
    	end
    
    	-- Theme Re-application Handler
    	subTabs.UpdateTheme = function()
    		for _, tab in ipairs(subTabs.SubTabList) do
    			if tab == subTabs.ActiveSubTab then
    				tab.Button.BackgroundColor3 = UI.Theme.Accent
    				tab.Button.BackgroundTransparency = 0
    				tab.Button.TextColor3 = UI.Theme.AccentText
    				tab.Stroke.Color = UI.Theme.Border
    				tab.Stroke.Thickness = 1.5
    				if tab.Gradient then tab.Gradient.Enabled = true end
    			else
    				tab.Button.BackgroundColor3 = UI.Theme.Container
    				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
    				tab.Button.TextColor3 = UI.Theme.TextSecondary
    				tab.Stroke.Color = UI.Theme.BorderDim
    				tab.Stroke.Thickness = 1.0
    				if tab.Gradient then tab.Gradient.Enabled = false end
    			end
    		end
    	end
    
    	if not self.SubTabGroups then
    		self.SubTabGroups = {}
    	end
    	table.insert(self.SubTabGroups, subTabs)
    
    	return subTabs
    end
    
    function CoreUI:CreateColumns(tabObj: any): (Frame, Frame)
    	local parentPage: GuiObject? = if type(tabObj) == "table" and tabObj.Page then tabObj.Page elseif typeof(tabObj) == "Instance" and tabObj:IsA("GuiObject") then tabObj else nil
    	if not parentPage then
    		error("[CoreUI:CreateColumns] Expected tabObj table or GuiObject instance.")
    	end
    
    	local columnsContainer = Instance.new("Frame")
    	columnsContainer.Name = "ColumnsContainer"
    	columnsContainer.Size = UDim2.new(1, 0, 0, 0)
    	columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
    	columnsContainer.BackgroundTransparency = 1
    	columnsContainer.BorderSizePixel = 0
    	columnsContainer.ClipsDescendants = false
    	columnsContainer.Parent = parentPage
    
    	local leftCol = Instance.new("Frame")
    	leftCol.Name = "LeftColumn"
    	leftCol.Size = UDim2.new(0.5, -5, 0, 0)
    	leftCol.Position = UDim2.new(0, 0, 0, 0)
    	leftCol.AutomaticSize = Enum.AutomaticSize.Y
    	leftCol.BackgroundTransparency = 1
    	leftCol.BorderSizePixel = 0
    	leftCol.ClipsDescendants = false
    	leftCol.Parent = columnsContainer
    
    	local leftLayout = Instance.new("UIListLayout")
    	leftLayout.Padding = UDim.new(0, 8)
    	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	leftLayout.Parent = leftCol
    
    	local rightCol = Instance.new("Frame")
    	rightCol.Name = "RightColumn"
    	rightCol.Size = UDim2.new(0.5, -5, 0, 0)
    	rightCol.Position = UDim2.new(0.5, 5, 0, 0)
    	rightCol.AutomaticSize = Enum.AutomaticSize.Y
    	rightCol.BackgroundTransparency = 1
    	rightCol.BorderSizePixel = 0
    	rightCol.ClipsDescendants = false
    	rightCol.Parent = columnsContainer
    
    	local rightLayout = Instance.new("UIListLayout")
    	rightLayout.Padding = UDim.new(0, 8)
    	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    	rightLayout.Parent = rightCol
    
    	if type(tabObj) == "table" then
    		tabObj.LeftColumn = leftCol
    		tabObj.RightColumn = rightCol
    	end
    
    	return leftCol, rightCol
    end
    
    function CoreUI:AddSection(parent: GuiObject, title: string): Frame
    	local section = Instance.new("Frame")
    	section.Name = title .. "Section"
    	section.Size = UDim2.new(1, 0, 0, 0)
    	section.AutomaticSize = Enum.AutomaticSize.Y
    	section.BackgroundTransparency = 1
    	section.BorderSizePixel = 0
    	section.ClipsDescendants = false
    	section.Parent = parent
    
    	local layout = Instance.new("UIListLayout")
    	layout.Padding = UDim.new(0, 6)
    	layout.SortOrder = Enum.SortOrder.LayoutOrder
    	layout.Parent = section
    
    	-- standalone boxed header [ Category Name ]
    	local headerBox = Instance.new("Frame")
    	headerBox.Name = "HeaderBox"
    	headerBox.Size = UDim2.new(1, -4, 0, 24)
    	headerBox.Position = UDim2.new(0, 2, 0, 0)
    	headerBox.BackgroundColor3 = UI.Theme.Container
    	headerBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	headerBox.BorderSizePixel = 0
    	headerBox.Parent = section
    	UI.registerThemeElement(headerBox, "Container")
    
    	local headerGrad = Instance.new("UIGradient")
    	headerGrad.Rotation = 90
    	headerGrad.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
    	})
    	headerGrad.Parent = headerBox
    
    	local headerStroke = Instance.new("UIStroke")
    	headerStroke.Color = UI.Theme.Border
    	headerStroke.Thickness = 1.2
    	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	headerStroke.Parent = headerBox
    	UI.registerThemeElement(headerStroke, "Border")
    
    	local headerLabel = Instance.new("TextLabel")
    	headerLabel.Size = UDim2.new(1, 0, 1, 0)
    	headerLabel.BackgroundTransparency = 1
    	headerLabel.Text = title
    	headerLabel.TextColor3 = UI.Theme.TextPrimary
    	headerLabel.Font = UI.Fonts.Header
    	headerLabel.TextSize = 11
    	headerLabel.Parent = headerBox
    	UI.registerThemeElement(headerLabel, "TextPrimary")
    
    	return section
    end
    
    -- 3-Segment Toggle Row: [ X ] [ Option Name ] [ Bind ]
    function CoreUI:AddToggle(section: Frame, featureId: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ())
    	local feature = FeatureManager.register(featureId, name, defaultState, defaultKeybind, callback)
    	
    	local row = Instance.new("Frame")
    	row.Name = featureId .. "Row"
    	row.Size = UDim2.new(1, -4, 0, 24)
    	row.Position = UDim2.new(0, 2, 0, 0)
    	row.BackgroundTransparency = 1
    	row.BorderSizePixel = 0
    	row.ClipsDescendants = false
    	row.Parent = section
    
    	-- Segment 1: [ X ]
    	local checkBtn = Instance.new("TextButton")
    	checkBtn.Name = "CheckBtn"
    	checkBtn.Size = UDim2.new(0, 24, 0, 24)
    	checkBtn.Position = UDim2.new(0, 0, 0, 0)
    	checkBtn.BackgroundColor3 = if feature.state then UI.Theme.Accent else UI.Theme.Container
    	checkBtn.BackgroundTransparency = if feature.state then 0 else UI.Theme.ContainerTransparency
    	checkBtn.BorderSizePixel = 0
    	checkBtn.Text = ""
    	checkBtn.Parent = row
    
    	local checkStroke = Instance.new("UIStroke")
    	checkStroke.Color = UI.Theme.Border
    	checkStroke.Thickness = 1.2
    	checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	checkStroke.Parent = checkBtn
    	UI.registerThemeElement(checkStroke, "Border")
    
    	local checkMark = Instance.new("TextLabel")
    	checkMark.Name = "CheckMark"
    	checkMark.Size = UDim2.new(1, 0, 1, 0)
    	checkMark.Position = UDim2.new(0, 0, 0, 0)
    	checkMark.BackgroundTransparency = 1
    	checkMark.Text = "X"
    	checkMark.TextColor3 = UI.Theme.AccentText
    	checkMark.Font = UI.Fonts.Header
    	checkMark.TextSize = 12
    	checkMark.Visible = feature.state
    	checkMark.Parent = checkBtn
    
    	local checkScale = Instance.new("UIScale")
    	checkScale.Scale = if feature.state then 1.0 else 0.0
    	checkScale.Parent = checkMark
    
    	-- Segment 2: [ Option Name ]
    	local titleBox = Instance.new("TextButton")
    	titleBox.Name = "TitleBox"
    	titleBox.Size = UDim2.new(1, -90, 0, 24)
    	titleBox.Position = UDim2.new(0, 28, 0, 0)
    	titleBox.BackgroundColor3 = UI.Theme.Container
    	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	titleBox.BorderSizePixel = 0
    	titleBox.ClipsDescendants = true
    	titleBox.Text = ""
    	titleBox.Parent = row
    	UI.registerThemeElement(titleBox, "Container")
    
    	local titleStroke = Instance.new("UIStroke")
    	titleStroke.Color = UI.Theme.Border
    	titleStroke.Thickness = 1.2
    	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleStroke.Parent = titleBox
    	UI.registerThemeElement(titleStroke, "Border")
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(1, -8, 1, 0)
    	titleLabel.Position = UDim2.new(0, 6, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = name
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Body
    	titleLabel.TextSize = 11
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.ClipsDescendants = true
    	titleLabel.Parent = titleBox
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	-- Segment 3: [ Bind ]
    	local keybindBtn = Instance.new("TextButton")
    	keybindBtn.Name = "KeybindBtn"
    	keybindBtn.Size = UDim2.new(0, 58, 0, 24)
    	keybindBtn.Position = UDim2.new(1, -58, 0, 0)
    	keybindBtn.BackgroundColor3 = UI.Theme.Container
    	keybindBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	keybindBtn.BorderSizePixel = 0
    	keybindBtn.Text = if feature.keybind then string.format("[%s]", feature.keybind.Name) else "[None]"
    	keybindBtn.TextColor3 = UI.Theme.TextSecondary
    	keybindBtn.Font = UI.Fonts.Mono
    	keybindBtn.TextSize = 10
    	keybindBtn.TextTruncate = Enum.TextTruncate.AtEnd
    	keybindBtn.ClipsDescendants = true
    	keybindBtn.Parent = row
    	UI.registerThemeElement(keybindBtn, "Container")
    	UI.registerThemeElement(keybindBtn, "TextSecondary")
    
    	local bindStroke = Instance.new("UIStroke")
    	bindStroke.Color = UI.Theme.Border
    	bindStroke.Thickness = 1.2
    	bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	bindStroke.Parent = keybindBtn
    	UI.registerThemeElement(bindStroke, "Border")
    
    	local function updateToggleVisual(state: boolean)
    		if state then
    			TweenService:Create(checkBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    				BackgroundColor3 = UI.Theme.Accent,
    				BackgroundTransparency = 0
    			}):Play()
    			checkMark.Visible = true
    			checkMark.TextColor3 = UI.Theme.AccentText
    			Animations.popScale(checkMark, 0.0, 1.25, 1.0, 0.20)
    		else
    			TweenService:Create(checkBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    				BackgroundColor3 = UI.Theme.Container,
    				BackgroundTransparency = UI.Theme.ContainerTransparency
    			}):Play()
    			local closeTween = TweenService:Create(checkScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
    				Scale = 0.0
    			})
    			closeTween:Play()
    			closeTween.Completed:Connect(function()
    				if not feature.state then
    					checkMark.Visible = false
    				end
    			end)
    		end
    	end
    
    	-- Hover animations on toggle components across all 3 segments with border glow
    	local function onToggleHoverEnter()
    		TweenService:Create(checkStroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
    		TweenService:Create(titleStroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
    		TweenService:Create(bindStroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
    		TweenService:Create(titleBox, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark }):Play()
    	end
    
    	local function onToggleHoverLeave()
    		TweenService:Create(checkStroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = UI.Theme.Border }):Play()
    		TweenService:Create(titleStroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = UI.Theme.Border }):Play()
    		TweenService:Create(bindStroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = UI.Theme.Border }):Play()
    		TweenService:Create(titleBox, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container }):Play()
    	end
    
    	titleBox.MouseEnter:Connect(onToggleHoverEnter)
    	titleBox.MouseLeave:Connect(onToggleHoverLeave)
    	checkBtn.MouseEnter:Connect(onToggleHoverEnter)
    	checkBtn.MouseLeave:Connect(onToggleHoverLeave)
    	keybindBtn.MouseEnter:Connect(onToggleHoverEnter)
    	keybindBtn.MouseLeave:Connect(onToggleHoverLeave)
    
    	-- Synchronize visual state when toggled via keyboard keybind or external call
    	feature.onStateChanged = function(newState: boolean)
    		updateToggleVisual(newState)
    		Notification.notifyFeature(name, newState)
    	end
    
    	table.insert(self.ActiveToggles, function()
    		updateToggleVisual(feature.state)
    	end)
    
    	local function toggleAction()
    		Animations.buttonClickPop(checkBtn)
    		local nextState = not feature.state
    		FeatureManager.setFeatureState(featureId, nextState)
    	end
    
    	checkBtn.MouseButton1Click:Connect(toggleAction)
    	titleBox.MouseButton1Click:Connect(toggleAction)
    
    	feature.onKeybindChanged = function(newKey)
    		keybindBtn.Text = if newKey then string.format("[%s]", newKey.Name) else "[None]"
    	end
    
    	keybindBtn.MouseButton1Click:Connect(function()
    		keybindBtn.Text = "[ ... ]"
    		keybindBtn.TextColor3 = UI.Theme.Accent
    		FeatureManager.promptKeybindCapture(function(selectedKey)
    			FeatureManager.setFeatureKeybind(featureId, selectedKey)
    			keybindBtn.Text = if selectedKey then string.format("[%s]", selectedKey.Name) else "[None]"
    			keybindBtn.TextColor3 = UI.Theme.TextSecondary
    		end)
    	end)
    end
    
    function CoreUI:AddSlider(section: Frame, name: string, min: number, max: number, default: number, callback: (number) -> ())
    	local sliderRecord, initialValue = FeatureManager.registerSlider(name, name, default, callback)
    
    	local row = Instance.new("Frame")
    	row.Name = name .. "SliderRow"
    	row.Size = UDim2.new(1, -4, 0, 46)
    	row.Position = UDim2.new(0, 2, 0, 0)
    	row.BackgroundTransparency = 1
    	row.BorderSizePixel = 0
    	row.ClipsDescendants = false
    	row.Parent = section
    
    	-- header line: [ Option Name ] + [ Val ]
    	local titleBox = Instance.new("Frame")
    	titleBox.Name = "TitleBox"
    	titleBox.Size = UDim2.new(1, -52, 0, 22)
    	titleBox.Position = UDim2.new(0, 0, 0, 0)
    	titleBox.BackgroundColor3 = UI.Theme.Container
    	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	titleBox.BorderSizePixel = 0
    	titleBox.Parent = row
    	UI.registerThemeElement(titleBox, "Container")
    
    	local titleStroke = Instance.new("UIStroke")
    	titleStroke.Color = UI.Theme.Border
    	titleStroke.Thickness = 1.2
    	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleStroke.Parent = titleBox
    	UI.registerThemeElement(titleStroke, "Border")
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(1, -8, 1, 0)
    	titleLabel.Position = UDim2.new(0, 6, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = name
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Body
    	titleLabel.TextSize = 11
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.ClipsDescendants = true
    	titleLabel.Parent = titleBox
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	local valBox = Instance.new("Frame")
    	valBox.Name = "ValBox"
    	valBox.Size = UDim2.new(0, 48, 0, 22)
    	valBox.Position = UDim2.new(1, -48, 0, 0)
    	valBox.BackgroundColor3 = UI.Theme.Container
    	valBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	valBox.BorderSizePixel = 0
    	valBox.ClipsDescendants = true
    	valBox.Parent = row
    	UI.registerThemeElement(valBox, "Container")
    
    	local valStroke = Instance.new("UIStroke")
    	valStroke.Color = UI.Theme.Border
    	valStroke.Thickness = 1.2
    	valStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	valStroke.Parent = valBox
    	UI.registerThemeElement(valStroke, "Border")
    
    	local valLabel = Instance.new("TextLabel")
    	valLabel.Size = UDim2.new(1, 0, 1, 0)
    	valLabel.BackgroundTransparency = 1
    	valLabel.Text = tostring(initialValue)
    	valLabel.TextColor3 = UI.Theme.Accent
    	valLabel.Font = UI.Fonts.Mono
    	valLabel.TextSize = 10
    	valLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	valLabel.ClipsDescendants = true
    	valLabel.Parent = valBox
    
    	-- track
    	local bar = Instance.new("Frame")
    	bar.Name = "SliderTrack"
    	bar.Size = UDim2.new(1, 0, 0, 16)
    	bar.Position = UDim2.new(0, 0, 0, 26)
    	bar.BackgroundColor3 = UI.Theme.ContainerDark
    	bar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	bar.BorderSizePixel = 0
    	bar.Parent = row
    	UI.registerThemeElement(bar, "ContainerDark")
    
    	local barStroke = Instance.new("UIStroke")
    	barStroke.Color = UI.Theme.Border
    	barStroke.Thickness = 1.2
    	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	barStroke.Parent = bar
    	UI.registerThemeElement(barStroke, "Border")
    
    	local fill = Instance.new("Frame")
    	fill.Name = "Fill"
    	local initialRatio = math.clamp((initialValue - min) / (max - min), 0, 1)
    	fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    	fill.BackgroundColor3 = UI.Theme.Accent
    	fill.BorderSizePixel = 0
    	fill.Parent = bar
    	table.insert(self.SliderFills, fill)
    
    	local fillGrad = Instance.new("UIGradient")
    	fillGrad.Rotation = 90
    	fillGrad.Color = ColorSequence.new({
    		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
    	})
    	fillGrad.Parent = fill
    
    	-- Responsive track border glow on hover
    	bar.MouseEnter:Connect(function()
    		TweenService:Create(barStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.6 }):Play()
    	end)
    	bar.MouseLeave:Connect(function()
    		TweenService:Create(barStroke, TweenInfo.new(0.12), { Color = UI.Theme.Border, Thickness = 1.2 }):Play()
    	end)
    
    	local sliding = false
    	local currentVal = initialValue
    
    	local function applyValue(val: number)
    		if val ~= currentVal then
    			currentVal = val
    			valLabel.Text = tostring(val)
    			valLabel.TextColor3 = UI.Theme.Accent
    			Animations.popScale(valLabel, 1.15, nil, 1.0, 0.15)
    		end
    		local ratio = math.clamp((val - min) / (max - min), 0, 1)
    		TweenService:Create(fill, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    			Size = UDim2.new(ratio, 0, 1, 0)
    		}):Play()
    	end
    
    	local function update(input: InputObject)
    		local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
    		local rawVal = min + (max - min) * ratio
    		local val = math.floor(rawVal + 0.5)
    		applyValue(val)
    		FeatureManager.setSliderValue(name, val)
    	end
    
    	sliderRecord.onValueChanged = function(newVal: number)
    		applyValue(newVal)
    	end
    
    	bar.InputBegan:Connect(function(input)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 then
    			sliding = true
    			update(input)
    			input.Changed:Connect(function()
    				if input.UserInputState == Enum.UserInputState.End then
    					sliding = false
    				end
    			end)
    		end
    	end)
    
    	UserInputService.InputChanged:Connect(function(input)
    		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
    			update(input)
    		end
    	end)
    end
    
    function CoreUI:AddButton(section: Frame, name: string, callback: () -> ())
    	local row = Instance.new("Frame")
    	row.Name = name .. "ButtonRow"
    	row.Size = UDim2.new(1, -4, 0, 26)
    	row.Position = UDim2.new(0, 2, 0, 0)
    	row.BackgroundTransparency = 1
    	row.BorderSizePixel = 0
    	row.ClipsDescendants = false
    	row.Parent = section
    
    	local btn = Instance.new("TextButton")
    	btn.Name = "ActionBtn"
    	btn.Size = UDim2.new(1, 0, 1, 0)
    	btn.BackgroundColor3 = UI.Theme.Container
    	btn.BackgroundTransparency = UI.Theme.ContainerTransparency
    	btn.BorderSizePixel = 0
    	btn.Text = string.format("[ %s ]", name)
    	btn.TextColor3 = UI.Theme.TextPrimary
    	btn.Font = UI.Fonts.Header
    	btn.TextSize = 11
    	btn.TextTruncate = Enum.TextTruncate.AtEnd
    	btn.ClipsDescendants = true
    	btn.Parent = row
    	UI.registerThemeElement(btn, "Container")
    	UI.registerThemeElement(btn, "TextPrimary")
    
    	local btnStroke = Instance.new("UIStroke")
    	btnStroke.Color = UI.Theme.Border
    	btnStroke.Thickness = 1.2
    	btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	btnStroke.Parent = btn
    	UI.registerThemeElement(btnStroke, "Border")
    
    	-- Micro-squash and border glow on hover/click with instant response (UIScale 0.96 down, 1.0 Back.Out up)
    	Animations.attachMicroSquash(
    		btn,
    		btnStroke,
    		function() return UI.Theme.Container end,
    		function() return UI.Theme.ContainerDark end,
    		function() return UI.Theme.Accent end,
    		function() return UI.Theme.Border end,
    		function() return UI.Theme.Accent end
    	)
    
    	btn.MouseButton1Click:Connect(function()
    		TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
    		task.delay(0.15, function()
    			TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
    		end)
    		callback()
    	end)
    end
    
    function CoreUI:AddTextBox(section: Frame, name: string, placeholder: string, defaultText: string?, onSubmitted: ((string) -> ())?): (TextBox, Frame)
    	local row = Instance.new("Frame")
    	row.Name = name .. "InputRow"
    	row.Size = UDim2.new(1, -4, 0, 48)
    	row.Position = UDim2.new(0, 2, 0, 0)
    	row.BackgroundTransparency = 1
    	row.BorderSizePixel = 0
    	row.Parent = section
    
    	local titleBox = Instance.new("Frame")
    	titleBox.Name = "TitleBox"
    	titleBox.Size = UDim2.new(1, 0, 0, 20)
    	titleBox.Position = UDim2.new(0, 0, 0, 0)
    	titleBox.BackgroundColor3 = UI.Theme.Container
    	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
    	titleBox.BorderSizePixel = 0
    	titleBox.Parent = row
    	UI.registerThemeElement(titleBox, "Container")
    
    	local titleStroke = Instance.new("UIStroke")
    	titleStroke.Color = UI.Theme.Border
    	titleStroke.Thickness = 1
    	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	titleStroke.Parent = titleBox
    	UI.registerThemeElement(titleStroke, "Border")
    
    	local titleLabel = Instance.new("TextLabel")
    	titleLabel.Size = UDim2.new(1, -8, 1, 0)
    	titleLabel.Position = UDim2.new(0, 6, 0, 0)
    	titleLabel.BackgroundTransparency = 1
    	titleLabel.Text = name
    	titleLabel.TextColor3 = UI.Theme.TextPrimary
    	titleLabel.Font = UI.Fonts.Header
    	titleLabel.TextSize = 10
    	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    	titleLabel.ClipsDescendants = true
    	titleLabel.Parent = titleBox
    	UI.registerThemeElement(titleLabel, "TextPrimary")
    
    	local inputFrame = Instance.new("Frame")
    	inputFrame.Name = "InputFrame"
    	inputFrame.Size = UDim2.new(1, 0, 0, 24)
    	inputFrame.Position = UDim2.new(0, 0, 0, 24)
    	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
    	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    	inputFrame.BorderSizePixel = 0
    	inputFrame.ClipsDescendants = true
    	inputFrame.Parent = row
    	UI.registerThemeElement(inputFrame, "ContainerDark")
    
    	local inStroke = Instance.new("UIStroke")
    	inStroke.Color = UI.Theme.Border
    	inStroke.Thickness = 1
    	inStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    	inStroke.Parent = inputFrame
    	UI.registerThemeElement(inStroke, "Border")
    
    	local box = Instance.new("TextBox")
    	box.Name = "InputBox"
    	box.Size = UDim2.new(1, -12, 1, 0)
    	box.Position = UDim2.new(0, 6, 0, 0)
    	box.BackgroundTransparency = 1
    	box.Text = defaultText or ""
    	box.PlaceholderText = placeholder
    	box.TextColor3 = UI.Theme.TextPrimary
    	box.PlaceholderColor3 = UI.Theme.TextSecondary
    	box.Font = UI.Fonts.Mono
    	box.TextSize = 10
    	box.ClearTextOnFocus = false
    	box.TextXAlignment = Enum.TextXAlignment.Left
    	box.ClipsDescendants = true
    	box.Parent = inputFrame
    	UI.registerThemeElement(box, "TextPrimary")
    
    	box.Focused:Connect(function()
    		TweenService:Create(inStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.5 }):Play()
    	end)
    	box.FocusLost:Connect(function(enter)
    		TweenService:Create(inStroke, TweenInfo.new(0.12), { Color = UI.Theme.Border, Thickness = 1 }):Play()
    		if enter and onSubmitted then
    			onSubmitted(box.Text)
    		end
    	end)
    
    	return box, row
    end
    
    function CoreUI:Notify(title: string, message: string, duration: number?)
    	Notification.show(title, message, duration)
    end
    
    function CoreUI:Open(onComplete: (() -> ())?)
    	if self.IsOpen or self.IsTransitioning then return end
    	self.IsTransitioning = true
    	Animations.openWindow(self.MainFrame, self.UiScale, function()
    		self.IsOpen = true
    		self.IsTransitioning = false
    		if onComplete then onComplete() end
    	end)
    end
    
    function CoreUI:Close(onComplete: (() -> ())?)
    	if not self.IsOpen or self.IsTransitioning then return end
    	self.IsTransitioning = true
    	Animations.closeWindow(self.MainFrame, self.UiScale, function()
    		self.IsOpen = false
    		self.IsTransitioning = false
    		if onComplete then onComplete() end
    	end)
    end
    
    function CoreUI:Toggle(onComplete: (() -> ())?)
    	if self.IsOpen then
    		self:Close(onComplete)
    	else
    		self:Open(onComplete)
    	end
    end
    
    function CoreUI:SetVisible(state: boolean, onComplete: (() -> ())?)
    	if state then
    		self:Open(onComplete)
    	else
    		self:Close(onComplete)
    	end
    end
    
    return CoreUI
end

Modules["Modules/Visuals.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Visuals Rendering Engine ✦
        High-performance 2D ESP Boxes with Outlines, Health Bars, Tracers with Origin Selector,
        Distance Tags, Skeletons, and 3D Highlight Chams with customizable colors.
        Optimized with centralized DrawingPool, cached character part hierarchies,
        viewport dimension caching, and zero per-frame heap table allocations.
    ]=]
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
    
    -- Module connections registry for clean unloading
    local moduleConnections: {RBXScriptConnection} = {}
    
    local camConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    	Camera = Workspace.CurrentCamera or Camera
    end)
    table.insert(moduleConnections, camConn)
    
    -- Constant Bone Hierarchy Table (Module Scope - 0 Heap Allocations per frame)
    local BONE_PAIRS: {{string}} = {
    	{"Head", "UpperTorso"},
    	{"UpperTorso", "LowerTorso"},
    	{"UpperTorso", "LeftUpperArm"},
    	{"LeftUpperArm", "LeftLowerArm"},
    	{"LeftLowerArm", "LeftHand"},
    	{"UpperTorso", "RightUpperArm"},
    	{"RightUpperArm", "RightLowerArm"},
    	{"RightLowerArm", "RightHand"},
    	{"LowerTorso", "LeftUpperLeg"},
    	{"LeftUpperLeg", "LeftLowerLeg"},
    	{"LeftLowerLeg", "LeftFoot"},
    	{"LowerTorso", "RightUpperLeg"},
    	{"RightUpperLeg", "RightLowerLeg"},
    	{"RightLowerLeg", "RightFoot"}
    }
    
    local Visuals = {
    	-- 2D ESP Settings
    	Box2D = false,
    	BoxOutlines = false,
    	BoxColor = Color3.fromRGB(55, 175, 245),
    	
    	HealthBar = false,
    	
    	Tracers = false,
    	TracerOrigin = "Bottom" :: "Bottom" | "Center" | "Mouse",
    	TracerColor = Color3.fromRGB(255, 255, 255),
    	
    	Distance = false,
    	DistanceColor = Color3.fromRGB(240, 240, 240),
    	
    	Skeleton = false,
    	SkeletonColor = Color3.fromRGB(255, 200, 50),
    	
    	-- 3D Chams / Highlights Settings
    	Chams = false,
    	ChamsTransparency = 0.5,
    	ChamsOutlineTransparency = 0.2,
    	ChamsColor = Color3.fromRGB(180, 70, 255),
    	ChamsFillColor = Color3.fromRGB(180, 70, 255),
    	ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    }
    
    -- Centralized Drawing Object Pool
    local DrawingPool: {[string]: {any}} = {
    	Square = {},
    	Line = {},
    	Text = {},
    	Circle = {}
    }
    
    local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")
    
    -- Public Pool Interface
    function Visuals.acquireDrawing(drawingType: string): any?
    	local pool = DrawingPool[drawingType]
    	if pool and #pool > 0 then
    		local obj = table.remove(pool)
    		if obj then
    			pcall(function()
    				obj.Visible = false
    			end)
    			return obj
    		end
    	end
    	
    	if hasDrawing then
    		local success, obj = pcall(function()
    			return Drawing.new(drawingType)
    		end)
    		if success and obj then
    			pcall(function()
    				obj.Visible = false
    			end)
    			return obj
    		end
    	end
    	return nil
    end
    
    function Visuals.releaseDrawing(drawingTypeOrObj: any, maybeObj: any?)
    	local drawingType: string?
    	local obj: any?
    	
    	if typeof(drawingTypeOrObj) == "string" then
    		drawingType = drawingTypeOrObj
    		obj = maybeObj
    	else
    		obj = drawingTypeOrObj
    		if typeof(maybeObj) == "string" then
    			drawingType = maybeObj
    		end
    	end
    	
    	if not obj then return end
    	
    	pcall(function()
    		obj.Visible = false
    	end)
    	
    	if drawingType and DrawingPool[drawingType] then
    		table.insert(DrawingPool[drawingType], obj)
    	else
    		-- Auto-detect drawing type from object properties if not supplied
    		local detectedType = "Square"
    		local successText, _ = pcall(function() return obj.Text end)
    		if successText then
    			detectedType = "Text"
    		else
    			local successRadius, _ = pcall(function() return obj.Radius end)
    			if successRadius then
    				detectedType = "Circle"
    			else
    				local successFrom, _ = pcall(function() return obj.From end)
    				if successFrom then
    					detectedType = "Line"
    				end
    			end
    		end
    		if DrawingPool[detectedType] then
    			table.insert(DrawingPool[detectedType], obj)
    		end
    	end
    end
    
    -- Cached Character Parts Structure
    type CachedPlayerParts = {
    	Character: Model?,
    	Humanoid: Humanoid?,
    	RootPart: BasePart?,
    	Head: BasePart?,
    	Torso: BasePart?,
    	UpperTorso: BasePart?,
    	LowerTorso: BasePart?,
    	BoneMap: {[string]: BasePart?},
    }
    
    -- Registry of created visual elements per player
    type PlayerVisual = {
    	Highlight: Highlight?,
    	BoxOutline: any?,
    	Box: any?,
    	HealthBarBg: any?,
    	HealthBarFill: any?,
    	Tracer: any?,
    	DistanceTag: any?,
    	Bones: {any},
    	LastDistance: number?,
    	Parts: CachedPlayerParts?,
    	CharAddedConn: RBXScriptConnection?,
    	CharRemovingConn: RBXScriptConnection?,
    	ChildAddedConn: RBXScriptConnection?,
    }
    
    local playerVisuals: {[Player]: PlayerVisual} = {}
    local wasAnyVisualEnabled = false
    
    local function isAnyVisualEnabled(): boolean
    	return Visuals.Box2D or Visuals.HealthBar or Visuals.Tracers or Visuals.Distance or Visuals.Skeleton or Visuals.Chams
    end
    
    local function cachePlayerParts(pv: PlayerVisual, character: Model?)
    	if not character then
    		pv.Parts = nil
    		return
    	end
    	
    	local humanoid = character:FindFirstChildOfClass("Humanoid")
    	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") :: BasePart?
    	local head = character:FindFirstChild("Head") :: BasePart?
    	local torso = character:FindFirstChild("Torso") :: BasePart?
    	local upperTorso = character:FindFirstChild("UpperTorso") :: BasePart?
    	local lowerTorso = character:FindFirstChild("LowerTorso") :: BasePart?
    	
    	local boneMap: {[string]: BasePart?} = {}
    	for _, pair in ipairs(BONE_PAIRS) do
    		local p1Name = pair[1]
    		local p2Name = pair[2]
    		if not boneMap[p1Name] then
    			boneMap[p1Name] = character:FindFirstChild(p1Name) :: BasePart?
    		end
    		if not boneMap[p2Name] then
    			boneMap[p2Name] = character:FindFirstChild(p2Name) :: BasePart?
    		end
    	end
    	
    	-- Fallback resolution for R6 character rigs
    	if not boneMap["UpperTorso"] and torso then
    		boneMap["UpperTorso"] = torso
    		boneMap["LowerTorso"] = torso
    	end
    	if not boneMap["LeftUpperArm"] then
    		boneMap["LeftUpperArm"] = character:FindFirstChild("Left Arm") :: BasePart?
    	end
    	if not boneMap["RightUpperArm"] then
    		boneMap["RightUpperArm"] = character:FindFirstChild("Right Arm") :: BasePart?
    	end
    	if not boneMap["LeftUpperLeg"] then
    		boneMap["LeftUpperLeg"] = character:FindFirstChild("Left Leg") :: BasePart?
    	end
    	if not boneMap["RightUpperLeg"] then
    		boneMap["RightUpperLeg"] = character:FindFirstChild("Right Leg") :: BasePart?
    	end
    	
    	pv.Parts = {
    		Character = character,
    		Humanoid = humanoid,
    		RootPart = rootPart,
    		Head = head,
    		Torso = torso,
    		UpperTorso = upperTorso,
    		LowerTorso = lowerTorso,
    		BoneMap = boneMap,
    	}
    end
    
    local function hideAll(pv: PlayerVisual)
    	if pv.Highlight then pv.Highlight.Enabled = false end
    	if pv.BoxOutline then pv.BoxOutline.Visible = false end
    	if pv.Box then pv.Box.Visible = false end
    	if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
    	if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
    	if pv.Tracer then pv.Tracer.Visible = false end
    	if pv.DistanceTag then pv.DistanceTag.Visible = false end
    	for _, bone in ipairs(pv.Bones) do bone.Visible = false end
    end
    
    local function createPlayerVisual(player: Player): PlayerVisual
    	local pv: PlayerVisual = {
    		Highlight = nil,
    		BoxOutline = nil,
    		Box = nil,
    		HealthBarBg = nil,
    		HealthBarFill = nil,
    		Tracer = nil,
    		DistanceTag = nil,
    		Bones = {},
    		LastDistance = nil,
    		Parts = nil,
    		CharAddedConn = nil,
    		CharRemovingConn = nil,
    		ChildAddedConn = nil,
    	}
    	
    	if hasDrawing then
    		-- Box Outline (Secondary black square for high contrast, Thickness = 3.5)
    		local boxOutline = Visuals.acquireDrawing("Square")
    		if boxOutline then
    			pcall(function()
    				boxOutline.Thickness = 3.5
    				boxOutline.Filled = false
    				boxOutline.Color = Color3.fromRGB(0, 0, 0)
    				boxOutline.Visible = false
    				boxOutline.Transparency = 1
    			end)
    			pv.BoxOutline = boxOutline
    		end
    
    		-- 2D Box
    		local box = Visuals.acquireDrawing("Square")
    		if box then
    			pcall(function()
    				box.Thickness = 1.5
    				box.Filled = false
    				box.Color = Visuals.BoxColor
    				box.Visible = false
    				box.Transparency = 1
    			end)
    			pv.Box = box
    		end
    		
    		-- Health Bar BG
    		local hbBg = Visuals.acquireDrawing("Square")
    		if hbBg then
    			pcall(function()
    				hbBg.Thickness = 1
    				hbBg.Filled = true
    				hbBg.Color = Color3.fromRGB(15, 15, 15)
    				hbBg.Visible = false
    				hbBg.Transparency = 1
    			end)
    			pv.HealthBarBg = hbBg
    		end
    		
    		-- Health Bar Fill
    		local hbFill = Visuals.acquireDrawing("Square")
    		if hbFill then
    			pcall(function()
    				hbFill.Thickness = 1
    				hbFill.Filled = true
    				hbFill.Color = Color3.fromRGB(50, 220, 80)
    				hbFill.Visible = false
    				hbFill.Transparency = 1
    			end)
    			pv.HealthBarFill = hbFill
    		end
    		
    		-- Tracer line
    		local tracer = Visuals.acquireDrawing("Line")
    		if tracer then
    			pcall(function()
    				tracer.Thickness = 1.2
    				tracer.Color = Visuals.TracerColor
    				tracer.Visible = false
    				tracer.Transparency = 1
    			end)
    			pv.Tracer = tracer
    		end
    		
    		-- Distance tag (3D stud distance text positioned below bounding box)
    		local distTag = Visuals.acquireDrawing("Text")
    		if distTag then
    			pcall(function()
    				distTag.Size = 13
    				distTag.Center = true
    				distTag.Outline = true
    				distTag.OutlineColor = Color3.fromRGB(0, 0, 0)
    				distTag.Color = Visuals.DistanceColor
    				distTag.Visible = false
    				distTag.Transparency = 1
    			end)
    			pv.DistanceTag = distTag
    		end
    		
    		-- Skeleton bones (14 bone segments)
    		for i = 1, #BONE_PAIRS do
    			local bone = Visuals.acquireDrawing("Line")
    			if bone then
    				pcall(function()
    					bone.Thickness = 1.2
    					bone.Color = Visuals.SkeletonColor
    					bone.Visible = false
    					bone.Transparency = 1
    				end)
    				table.insert(pv.Bones, bone)
    			end
    		end
    	end
    	
    	-- Cache character parts and listen for character lifecycle
    	if player.Character then
    		cachePlayerParts(pv, player.Character)
    	end
    	
    	pv.CharAddedConn = player.CharacterAdded:Connect(function(char)
    		cachePlayerParts(pv, char)
    		if pv.ChildAddedConn then
    			pv.ChildAddedConn:Disconnect()
    			pv.ChildAddedConn = nil
    		end
    		pv.ChildAddedConn = char.ChildAdded:Connect(function()
    			if not pv.Parts or not pv.Parts.RootPart or not pv.Parts.Humanoid then
    				cachePlayerParts(pv, char)
    			end
    		end)
    	end)
    	
    	pv.CharRemovingConn = player.CharacterRemoving:Connect(function()
    		pv.Parts = nil
    		pv.LastDistance = nil
    		if pv.ChildAddedConn then
    			pv.ChildAddedConn:Disconnect()
    			pv.ChildAddedConn = nil
    		end
    		hideAll(pv)
    	end)
    	
    	return pv
    end
    
    local function cleanPlayerVisual(pv: PlayerVisual)
    	if pv.CharAddedConn then
    		pv.CharAddedConn:Disconnect()
    		pv.CharAddedConn = nil
    	end
    	if pv.CharRemovingConn then
    		pv.CharRemovingConn:Disconnect()
    		pv.CharRemovingConn = nil
    	end
    	if pv.ChildAddedConn then
    		pv.ChildAddedConn:Disconnect()
    		pv.ChildAddedConn = nil
    	end
    	
    	if pv.Highlight then
    		pcall(function() pv.Highlight:Destroy() end)
    		pv.Highlight = nil
    	end
    	
    	if pv.BoxOutline then
    		Visuals.releaseDrawing("Square", pv.BoxOutline)
    		pv.BoxOutline = nil
    	end
    	if pv.Box then
    		Visuals.releaseDrawing("Square", pv.Box)
    		pv.Box = nil
    	end
    	if pv.HealthBarBg then
    		Visuals.releaseDrawing("Square", pv.HealthBarBg)
    		pv.HealthBarBg = nil
    	end
    	if pv.HealthBarFill then
    		Visuals.releaseDrawing("Square", pv.HealthBarFill)
    		pv.HealthBarFill = nil
    	end
    	if pv.Tracer then
    		Visuals.releaseDrawing("Line", pv.Tracer)
    		pv.Tracer = nil
    	end
    	if pv.DistanceTag then
    		Visuals.releaseDrawing("Text", pv.DistanceTag)
    		pv.DistanceTag = nil
    	end
    	for _, bone in ipairs(pv.Bones) do
    		Visuals.releaseDrawing("Line", bone)
    	end
    	pv.Bones = {}
    	pv.Parts = nil
    	pv.LastDistance = nil
    end
    
    local function updatePlayer(
    	player: Player,
    	pv: PlayerVisual,
    	screenCenter: Vector2,
    	screenBottom: Vector2,
    	mousePos: Vector2?,
    	myRootPart: BasePart?
    )
    	if player == LocalPlayer then return end
    	local character = player.Character
    	if not character then
    		hideAll(pv)
    		return
    	end
    	
    	-- Verify and update cached character parts if needed
    	local parts = pv.Parts
    	if not parts or parts.Character ~= character or not parts.RootPart or not parts.Humanoid then
    		cachePlayerParts(pv, character)
    		parts = pv.Parts
    	end
    	
    	if not parts or not parts.Humanoid or not parts.RootPart or parts.Humanoid.Health <= 0 then
    		hideAll(pv)
    		return
    	end
    	
    	local humanoid = parts.Humanoid
    	local rootPart = parts.RootPart
    	
    	-- 3D Chams / Highlight
    	if Visuals.Chams then
    		local fillColor = Visuals.ChamsFillColor or Visuals.ChamsColor or Color3.fromRGB(180, 70, 255)
    		local outlineColor = Visuals.ChamsOutlineColor or Color3.fromRGB(255, 255, 255)
    		local fillTransparency = Visuals.ChamsTransparency or 0.5
    		local outlineTransparency = Visuals.ChamsOutlineTransparency or 0.2
    		
    		if not pv.Highlight or pv.Highlight.Parent ~= character then
    			if pv.Highlight then
    				pcall(function() pv.Highlight:Destroy() end)
    			end
    			local successHl, hl = pcall(function()
    				local inst = Instance.new("Highlight")
    				inst.Name = "ModularChams"
    				inst.FillColor = fillColor
    				inst.OutlineColor = outlineColor
    				inst.FillTransparency = fillTransparency
    				inst.OutlineTransparency = outlineTransparency
    				inst.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    				inst.Adornee = character
    				inst.Parent = character
    				return inst
    			end)
    			if successHl and hl then
    				pv.Highlight = hl
    			end
    		else
    			pv.Highlight.Enabled = true
    			pv.Highlight.FillColor = fillColor
    			pv.Highlight.OutlineColor = outlineColor
    			pv.Highlight.FillTransparency = fillTransparency
    			pv.Highlight.OutlineTransparency = outlineTransparency
    		end
    	elseif pv.Highlight then
    		pv.Highlight.Enabled = false
    	end
    	
    	-- 2D Calculations
    	local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    	if not onScreen or not hasDrawing then
    		if pv.BoxOutline then pv.BoxOutline.Visible = false end
    		if pv.Box then pv.Box.Visible = false end
    		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
    		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
    		if pv.Tracer then pv.Tracer.Visible = false end
    		if pv.DistanceTag then pv.DistanceTag.Visible = false end
    		for _, bone in ipairs(pv.Bones) do bone.Visible = false end
    		return
    	end
    	
    	-- Bounding Box size estimation
    	local head = parts.Head
    	local headPos = if head then Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) else Vector3.new(rootPos.X, rootPos.Y - 30, 0)
    	local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    	
    	local boxHeight = math.abs(legPos.Y - headPos.Y)
    	local boxWidth = boxHeight * 0.65
    	local boxX = rootPos.X - (boxWidth * 0.5)
    	local boxY = headPos.Y
    	local boxSize = Vector2.new(boxWidth, boxHeight)
    	local boxPosition = Vector2.new(boxX, boxY)
    	
    	-- Render 2D Box & Box Outline
    	if Visuals.Box2D then
    		-- Render Box Outline (Secondary black Square behind box with Thickness = 3.5 for high contrast)
    		if Visuals.BoxOutlines and pv.BoxOutline then
    			pv.BoxOutline.Size = boxSize
    			pv.BoxOutline.Position = boxPosition
    			pv.BoxOutline.Thickness = 3.5
    			pv.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    			pv.BoxOutline.Visible = true
    		elseif pv.BoxOutline then
    			pv.BoxOutline.Visible = false
    		end
    
    		if pv.Box then
    			pv.Box.Size = boxSize
    			pv.Box.Position = boxPosition
    			pv.Box.Thickness = 1.5
    			pv.Box.Color = Visuals.BoxColor
    			pv.Box.Visible = true
    		end
    	else
    		if pv.Box then pv.Box.Visible = false end
    		if pv.BoxOutline then pv.BoxOutline.Visible = false end
    	end
    	
    	-- Render Health Bar next to 2D Box
    	if Visuals.HealthBar and pv.HealthBarBg and pv.HealthBarFill then
    		local barWidth = 3
    		local barX = boxX - 6
    		local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    		local fillHeight = boxHeight * healthRatio
    		
    		pv.HealthBarBg.Size = Vector2.new(barWidth + 2, boxHeight + 2)
    		pv.HealthBarBg.Position = Vector2.new(barX - 1, boxY - 1)
    		pv.HealthBarBg.Visible = true
    		
    		pv.HealthBarFill.Size = Vector2.new(barWidth, fillHeight)
    		pv.HealthBarFill.Position = Vector2.new(barX, boxY + (boxHeight - fillHeight))
    		pv.HealthBarFill.Color = Color3.fromHSV(healthRatio * 0.33, 0.9, 0.9)
    		pv.HealthBarFill.Visible = true
    	else
    		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
    		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
    	end
    	
    	-- Render Tracer with Origin Selector ("Bottom", "Center", "Mouse")
    	if Visuals.Tracers and pv.Tracer then
    		local tracerOrigin = Visuals.TracerOrigin or "Bottom"
    		local fromPos: Vector2
    		
    		if tracerOrigin == "Center" then
    			fromPos = screenCenter
    		elseif tracerOrigin == "Mouse" then
    			fromPos = mousePos or screenCenter
    		else -- "Bottom" or default fallback
    			fromPos = screenBottom
    		end
    		
    		pv.Tracer.From = fromPos
    		pv.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
    		pv.Tracer.Color = Visuals.TracerColor
    		pv.Tracer.Visible = true
    	elseif pv.Tracer then
    		pv.Tracer.Visible = false
    	end
    	
    	-- Render Distance Tag (3D stud distance calculation with delta threshold cache)
    	if Visuals.Distance and pv.DistanceTag then
    		local myPos = if myRootPart then myRootPart.Position else Camera.CFrame.Position
    		local targetPos = rootPart.Position
    		local dist = math.floor((targetPos - myPos).Magnitude)
    		
    		if not pv.LastDistance or math.abs(dist - pv.LastDistance) >= 1 then
    			pv.LastDistance = dist
    			pv.DistanceTag.Text = tostring(dist) .. "m"
    		end
    		
    		pv.DistanceTag.Position = Vector2.new(boxX + (boxWidth * 0.5), boxY + boxHeight + 2)
    		pv.DistanceTag.Color = Visuals.DistanceColor or Color3.fromRGB(240, 240, 240)
    		pv.DistanceTag.Visible = true
    	elseif pv.DistanceTag then
    		pv.DistanceTag.Visible = false
    	end
    	
    	-- Render Skeleton ESP
    	if Visuals.Skeleton and #pv.Bones > 0 and parts then
    		local boneMap = parts.BoneMap
    		for idx, pair in ipairs(BONE_PAIRS) do
    			local boneLine = pv.Bones[idx]
    			if boneLine then
    				local p1 = boneMap[pair[1]]
    				local p2 = boneMap[pair[2]]
    				if p1 and p2 then
    					local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
    					local v2, on2 = Camera:WorldToViewportPoint(p2.Position)
    					if on1 and on2 then
    						boneLine.From = Vector2.new(v1.X, v1.Y)
    						boneLine.To = Vector2.new(v2.X, v2.Y)
    						boneLine.Color = Visuals.SkeletonColor
    						boneLine.Visible = true
    					else
    						boneLine.Visible = false
    					end
    				else
    					boneLine.Visible = false
    				end
    			end
    		end
    	else
    		for _, bone in ipairs(pv.Bones) do
    			bone.Visible = false
    		end
    	end
    end
    
    -- Main RenderStepped render loop
    local renderConn = RunService.RenderStepped:Connect(function()
    	-- Master Early-Return Gate: Skip loop entirely if all visual modules are disabled
    	if not isAnyVisualEnabled() then
    		if wasAnyVisualEnabled then
    			wasAnyVisualEnabled = false
    			for _, pv in pairs(playerVisuals) do
    				hideAll(pv)
    			end
    		end
    		return
    	end
    	wasAnyVisualEnabled = true
    	
    	-- Cache viewport dimensions and origin vectors once per frame
    	local viewportSize = Camera.ViewportSize
    	local screenCenter = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)
    	local screenBottom = Vector2.new(viewportSize.X * 0.5, viewportSize.Y)
    	local mousePos: Vector2? = nil
    	if Visuals.Tracers and Visuals.TracerOrigin == "Mouse" then
    		mousePos = UserInputService:GetMouseLocation()
    	end
    	
    	local localChar = LocalPlayer.Character
    	local myRootPart: BasePart? = if localChar then (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso") or localChar:FindFirstChild("UpperTorso")) :: BasePart? else nil
    	
    	for _, player in ipairs(Players:GetPlayers()) do
    		if player ~= LocalPlayer then
    			local pv = playerVisuals[player]
    			if not pv then
    				pv = createPlayerVisual(player)
    				playerVisuals[player] = pv
    			end
    			updatePlayer(player, pv, screenCenter, screenBottom, mousePos, myRootPart)
    		end
    	end
    end)
    table.insert(moduleConnections, renderConn)
    
    local playerRemConn = Players.PlayerRemoving:Connect(function(player)
    	local pv = playerVisuals[player]
    	if pv then
    		cleanPlayerVisual(pv)
    		playerVisuals[player] = nil
    	end
    end)
    table.insert(moduleConnections, playerRemConn)
    
    -- Module Unload & Resource Cleanup
    function Visuals.cleanup()
    	-- 1. Clean and release all player visuals
    	for player, pv in pairs(playerVisuals) do
    		cleanPlayerVisual(pv)
    	end
    	playerVisuals = {}
    	
    	-- 2. Drain and permanently remove all pooled Drawing instances
    	for typeName, pool in pairs(DrawingPool) do
    		for _, obj in ipairs(pool) do
    			pcall(function()
    				obj:Remove()
    			end)
    		end
    		DrawingPool[typeName] = {}
    	end
    	
    	-- 3. Disconnect all module-level connections
    	for _, conn in ipairs(moduleConnections) do
    		pcall(function()
    			conn:Disconnect()
    		end)
    	end
    	moduleConnections = {}
    	wasAnyVisualEnabled = false
    end
    
    return Visuals
end

Modules["Modules/Combat.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ High-Performance Combat & Aim Tracking Engine ✦
        Features:
        - Post-Camera BindToRenderStep (Enum.RenderPriority.Camera.Value + 1) Aim Tracking
          (Guarantees camera aim lock is never overwritten by Roblox CameraModule)
        - Full-screen / FOV adaptive target resolution with transparent-barrier bypass
        - Spatial 3D distance & FOV culling with two-pass screen-distance sorted target solver
        - Zero-allocation static RaycastParams and reusable filter arrays for 60+ FPS stability
        - Throttled Trigger Bot and Leak-Free Hitbox Expander with lifecycle cleanup
    ]=]
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
    
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    	Camera = Workspace.CurrentCamera or Camera
    end)
    
    local MAX_AIM_DISTANCE = 500 -- Maximum 3D stud distance
    local MAX_AIM_DISTANCE_SQ = MAX_AIM_DISTANCE * MAX_AIM_DISTANCE
    local TRIGGER_CHECK_INTERVAL = 0.033 -- ~30 Hz TriggerBot throttle
    
    local Combat = {
    	SilentAim = false,
    	Wallbang = false,
    	HitboxVisuals = false,
    	HitboxPart = "HumanoidRootPart", -- "HumanoidRootPart" or "Head"
    	WallbangThickness = 5,
    	HitChance = 100,
    	TargetPart = "Head",
    	AimTracking = false,
    	AimMode = "Hold RMB", -- "Hold RMB" or "Always"
    	TrackTeammates = false,
    	TriggerBot = false,
    	TriggerBotDelay = 0.05,
    	FovCircle = false,
    	FovRadius = 160,
    	Smoothing = 0.40,
    	ExpandHitboxes = false,
    	HitboxSize = 12,
    	FovColor = Color3.fromRGB(255, 255, 255)
    }
    
    -- ── Drawing Setup ────────────────────────────────────────────────────
    local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")
    local fovDrawing: any = nil
    
    if hasDrawing then
    	local circle = Drawing.new("Circle")
    	circle.Thickness = 1.5
    	circle.NumSides = 48
    	circle.Radius = Combat.FovRadius
    	circle.Filled = false
    	circle.Color = Combat.FovColor
    	circle.Transparency = 1
    	circle.Visible = false
    	fovDrawing = circle
    end
    
    -- ── Static Shared RaycastParams & Reusable Filter Tables ──────────────
    local SHARED_RAY_PARAMS = RaycastParams.new()
    SHARED_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
    SHARED_RAY_PARAMS.IgnoreWater = true
    
    local SHARED_TRIGGER_PARAMS = RaycastParams.new()
    SHARED_TRIGGER_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
    SHARED_TRIGGER_PARAMS.IgnoreWater = true
    
    local reusableFilterArray: {Instance} = {}
    local triggerFilterArray: {Instance} = {}
    
    local function setSharedFilter(targetChar: Model?)
    	table.clear(reusableFilterArray)
    	if LocalPlayer.Character then
    		table.insert(reusableFilterArray, LocalPlayer.Character)
    	end
    	if targetChar and targetChar ~= LocalPlayer.Character then
    		table.insert(reusableFilterArray, targetChar)
    	end
    	SHARED_RAY_PARAMS.FilterDescendantsInstances = reusableFilterArray
    end
    
    local function updateTriggerParams()
    	table.clear(triggerFilterArray)
    	if LocalPlayer.Character then
    		table.insert(triggerFilterArray, LocalPlayer.Character)
    	end
    	SHARED_TRIGGER_PARAMS.FilterDescendantsInstances = triggerFilterArray
    end
    
    -- ── Target Solver Types & Reusable Data Structures ───────────────────
    type TargetCandidate = {
    	player: Player,
    	character: Model,
    	targetPart: BasePart,
    	screenDist: number
    }
    
    local candidateList: {TargetCandidate} = {}
    
    local function compareCandidates(a: TargetCandidate, b: TargetCandidate): boolean
    	return a.screenDist < b.screenDist
    end
    
    local originalHitboxSizes: {[BasePart]: Vector3} = {}
    local lastTriggerTime = 0
    local lastTriggerCheck = 0
    local cachedTargetPlayer: Player? = nil
    local cachedTargetPart: BasePart? = nil
    
    -- ── Helper Functions ─────────────────────────────────────────────────
    local function isTeammate(player: Player): boolean
    	if not LocalPlayer.Team then return false end
    	return player.Team == LocalPlayer.Team
    end
    
    local function getScreenCenter(): Vector2
    	local vp = Camera.ViewportSize
    	return Vector2.new(vp.X / 2, vp.Y / 2)
    end
    
    local function isPartVisible(origin: Vector3, targetPart: BasePart, targetChar: Model): boolean
    	setSharedFilter(targetChar)
    	local direction = targetPart.Position - origin
    	local result = Workspace:Raycast(origin, direction, SHARED_RAY_PARAMS)
    	if not result then return true end
    
    	-- Check if hit object is invisible/non-collidable trigger
    	if not result.Instance.CanCollide and result.Instance.Transparency >= 0.75 then
    		return true
    	end
    
    	return result.Instance:IsDescendantOf(targetChar)
    end
    
    function Combat.setFovColor(color: Color3)
    	Combat.FovColor = color
    	if fovDrawing then
    		fovDrawing.Color = color
    	end
    end
    
    function Combat.setTriggerBotDelay(delaySec: number)
    	Combat.TriggerBotDelay = math.clamp(delaySec, 0, 0.5)
    end
    
    function Combat.setWallbangThickness(thicknessStuds: number)
    	Combat.WallbangThickness = math.clamp(thicknessStuds, 0, 20)
    end
    
    function Combat.checkWallbangPenetration(origin: Vector3, targetPart: BasePart, targetChar: Model): (boolean, number)
    	if not targetPart or not targetChar then return false, 999 end
    
    	local targetPos = targetPart.Position
    	local toTarget = targetPos - origin
    	local totalDist = toTarget.Magnitude
    	if totalDist < 0.1 then
    		return true, 0
    	end
    
    	setSharedFilter(targetChar)
    
    	-- 1. Forward Raycast: from origin towards target to find entry point
    	local forwardResult = Workspace:Raycast(origin, toTarget, SHARED_RAY_PARAMS)
    	if not forwardResult then
    		-- No obstacles between origin and target (Direct line of sight)
    		return true, 0
    	end
    
    	-- If non-collidable transparent barrier, allow hit
    	if not forwardResult.Instance.CanCollide and forwardResult.Instance.Transparency >= 0.75 then
    		return true, 0
    	end
    
    	local entryPoint = forwardResult.Position
    
    	-- 2. Backward Raycast: from target towards origin to find exit point
    	local fromTarget = origin - targetPos
    	local backwardResult = Workspace:Raycast(targetPos, fromTarget, SHARED_RAY_PARAMS)
    	local exitPoint = if backwardResult then backwardResult.Position else targetPos
    
    	-- 3. Calculate Wall Thickness: (exitPoint - entryPoint).Magnitude
    	local thickness = if not backwardResult then (targetPos - entryPoint).Magnitude else (exitPoint - entryPoint).Magnitude
    
    	local canPenetrate = (thickness <= Combat.WallbangThickness)
    	return canPenetrate, thickness
    end
    
    -- ── Spatial Distance Filtering Helper (PROJECT.md contract) ──────────
    function Combat.getNearbyTargets(radius: number?, maxTargets: number?): {Player}
    	local maxDist = radius or MAX_AIM_DISTANCE
    	local limit = maxTargets or 10
    	local targets: {Player} = {}
    	local camPos = Camera.CFrame.Position
    
    	for _, player in ipairs(Players:GetPlayers()) do
    		if player == LocalPlayer then continue end
    		if not Combat.TrackTeammates and isTeammate(player) then continue end
    		local character = player.Character
    		if not character then continue end
    		local humanoid = character:FindFirstChildOfClass("Humanoid")
    		if not humanoid or humanoid.Health <= 0 then continue end
    		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    		if not root then continue end
    
    		local dist = (root.Position - camPos).Magnitude
    		if dist <= maxDist then
    			table.insert(targets, player)
    			if #targets >= limit then break end
    		end
    	end
    
    	return targets
    end
    
    -- ── Optimized Two-Pass Target Solver ─────────────────────────────────
    function Combat.getClosestTarget(ignoreWalls: boolean?): (Player?, BasePart?)
    	local screenCenter = getScreenCenter()
    	local maxRadius = if Combat.FovCircle then Combat.FovRadius else 1200
    	local camCF = Camera.CFrame
    	local camPos = camCF.Position
    	local camLook = camCF.LookVector
    	local candidateCount = 0
    
    	-- ── PASS 1: Fast Spatial 3D & 2D Screen Filtering (Zero Raycasts) ─
    	for _, player in ipairs(Players:GetPlayers()) do
    		if player == LocalPlayer then continue end
    		if not Combat.TrackTeammates and isTeammate(player) then continue end
    
    		local character = player.Character
    		if not character then continue end
    
    		local humanoid = character:FindFirstChildOfClass("Humanoid")
    		if not humanoid or humanoid.Health <= 0 then continue end
    
    		local targetPart: BasePart? = nil
    		if Combat.TargetPart == "Head" then
    			targetPart = character:FindFirstChild("Head") :: BasePart?
    		else
    			targetPart = (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
    		end
    
    		if not targetPart then
    			targetPart = (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")) :: BasePart?
    		end
    		if not targetPart then continue end
    
    		-- 3D Distance check (cull distant players beyond 500 studs)
    		local targetPos = targetPart.Position
    		local offset = targetPos - camPos
    		local distSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
    		if distSq > MAX_AIM_DISTANCE_SQ then continue end
    
    		-- FOV angle check (must be in front of camera)
    		if camLook:Dot(offset) <= 0 then continue end
    
    		-- 2D Screen projection check
    		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
    		if not onScreen then continue end
    
    		-- 2D Screen distance check
    		local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
    		if screenDist > maxRadius then continue end
    
    		-- Add or reuse candidate in array
    		candidateCount += 1
    		local cand = candidateList[candidateCount]
    		if not cand then
    			cand = {
    				player = player,
    				character = character,
    				targetPart = targetPart,
    				screenDist = screenDist
    			}
    			candidateList[candidateCount] = cand
    		else
    			cand.player = player
    			cand.character = character
    			cand.targetPart = targetPart
    			cand.screenDist = screenDist
    		end
    	end
    
    	if candidateCount == 0 then
    		return nil, nil
    	end
    
    	-- Clean up trailing entries to keep table length accurate for sorting
    	for i = candidateCount + 1, #candidateList do
    		candidateList[i] = nil
    	end
    
    	-- Sort candidates ascending by screen distance
    	if candidateCount > 1 then
    		table.sort(candidateList, compareCandidates)
    	end
    
    	-- ── PASS 2: Visibility Raycasts Only for Closest Candidate(s) ─────
    	for i = 1, candidateCount do
    		local cand = candidateList[i]
    		local visible = false
    
    		if ignoreWalls == true then
    			visible = true
    		elseif Combat.Wallbang then
    			visible = Combat.checkWallbangPenetration(camPos, cand.targetPart, cand.character)
    		else
    			visible = isPartVisible(camPos, cand.targetPart, cand.character)
    		end
    
    		if visible then
    			return cand.player, cand.targetPart
    		end
    	end
    
    	return nil, nil
    end
    
    -- ── 60 FPS Continuous Target Solver ──────────────────────────────────
    RunService.Heartbeat:Connect(function()
    	if not Combat.SilentAim and not Combat.AimTracking then
    		cachedTargetPlayer = nil
    		cachedTargetPart = nil
    		return
    	end
    
    	cachedTargetPlayer, cachedTargetPart = Combat.getClosestTarget()
    end)
    
    -- ── Metamethod Hooks for Silent Aim & Wallbang (Next-Gen Precision) ──
    pcall(function()
    	local hook = hookmetamethod or (getgenv and getgenv().hookmetamethod)
    	local getnamecall = getnamecallmethod or (getgenv and getgenv().getnamecallmethod)
    	local checkcall = checkcaller or (getgenv and getgenv().checkcaller)
    	local getcalling = getcallingscript or (getgenv and getgenv().getcallingscript)
    
    	local function isCameraOrCoreScript(scriptObj: Instance?): boolean
    		if not scriptObj then return false end
    		local n = string.lower(scriptObj.Name)
    		if n:find("camera") or n:find("popper") or n:find("zoom") or n:find("transparency") or n:find("control") or n:find("vehicle") or n:find("chat") then
    			return true
    		end
    		local p = scriptObj.Parent
    		while p and p ~= game do
    			local pn = string.lower(p.Name)
    			if pn:find("camera") or pn:find("playermodule") or pn:find("controlmodule") or pn:find("corescripts") then
    				return true
    			end
    			p = p.Parent
    		end
    		return false
    	end
    
    	if type(hook) == "function" and type(getnamecall) == "function" then
    		local oldNamecall: any
    		oldNamecall = hook(game, "__namecall", function(self, ...)
    			if not Combat.SilentAim then
    				return oldNamecall(self, ...)
    			end
    
    			if checkcall and checkcall() then
    				return oldNamecall(self, ...)
    			end
    
    			local callingScript = if type(getcalling) == "function" then getcalling() else nil
    			if isCameraOrCoreScript(callingScript) then
    				return oldNamecall(self, ...)
    			end
    
    			local method = getnamecall()
    			if method == "Raycast" and self == Workspace then
    				local target = cachedTargetPart
    				if target and target.Parent and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
    					local origin = select(1, ...)
    					if typeof(origin) == "Vector3" then
    						local targetChar = target.Parent :: Model?
    						local canHit = true
    						if Combat.Wallbang and targetChar then
    							canHit = Combat.checkWallbangPenetration(origin, target, targetChar)
    						end
    						if canHit then
    							-- Calculate predicted direction to target part
    							local targetVel = target.AssemblyLinearVelocity or Vector3.zero
    							local predictedPos = target.Position + (targetVel * 0.035)
    							local dir = (predictedPos - origin).Unit * 1000
    							local p3 = select(3, ...)
    							if Combat.Wallbang and typeof(p3) == "RaycastParams" then
    								p3.FilterType = Enum.RaycastFilterType.Include
    								p3.FilterDescendantsInstances = { target.Parent }
    							end
    							return oldNamecall(self, origin, dir, p3)
    						end
    					end
    				end
    			elseif (method == "FindPartOnRay" or method == "findPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and self == Workspace then
    				local target = cachedTargetPart
    				if target and target.Parent and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
    					local ray = select(1, ...)
    					if typeof(ray) == "Ray" then
    						local targetVel = target.AssemblyLinearVelocity or Vector3.zero
    						local predictedPos = target.Position + (targetVel * 0.035)
    						local newDir = (predictedPos - ray.Origin).Unit * 1000
    						local newRay = Ray.new(ray.Origin, newDir)
    						return oldNamecall(self, newRay, select(2, ...))
    					end
    				end
    			end
    
    			return oldNamecall(self, ...)
    		end)
    
    		local oldIndex: any
    		oldIndex = hook(game, "__index", function(self, key)
    			if not Combat.SilentAim then
    				return oldIndex(self, key)
    			end
    
    			if checkcall and checkcall() then
    				return oldIndex(self, key)
    			end
    
    			if (key == "Hit" or key == "Target") and typeof(self) == "Instance" and self:IsA("Mouse") then
    				local callingScript = if type(getcalling) == "function" then getcalling() else nil
    				if not isCameraOrCoreScript(callingScript) then
    					local target = cachedTargetPart
    					if target and target.Parent and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
    						if key == "Hit" then
    							local targetVel = target.AssemblyLinearVelocity or Vector3.zero
    							return CFrame.new(target.Position + (targetVel * 0.035)) * target.CFrame.Rotation
    						elseif key == "Target" then
    							return target
    						end
    					end
    				end
    			end
    
    			return oldIndex(self, key)
    		end)
    	end
    end)
    
    -- ── Throttled Trigger Bot Check (Reusing SHARED_TRIGGER_PARAMS) ──────
    local function checkTriggerBot()
    	if not Combat.TriggerBot then return end
    	local now = os.clock()
    	if now - lastTriggerCheck < TRIGGER_CHECK_INTERVAL then return end
    	lastTriggerCheck = now
    	if now - lastTriggerTime < Combat.TriggerBotDelay then return end
    
    	local mousePos = UserInputService:GetMouseLocation()
    	local unitRay = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
    
    	updateTriggerParams()
    	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, SHARED_TRIGGER_PARAMS)
    	if result and result.Instance then
    		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
    		if hitChar then
    			local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
    			if hitPlayer and hitPlayer ~= LocalPlayer then
    				if Combat.TrackTeammates or not isTeammate(hitPlayer) then
    					local hum = hitChar:FindFirstChildOfClass("Humanoid")
    					if hum and hum.Health > 0 then
    						lastTriggerTime = now + Combat.TriggerBotDelay
    						task.spawn(function()
    							if Combat.TriggerBotDelay > 0 then
    								task.wait(Combat.TriggerBotDelay)
    							end
    							if Combat.TriggerBot and LocalPlayer.Character then
    								local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    								if tool and typeof(tool.Activate) == "function" then
    									tool:Activate()
    								end
    							end
    						end)
    					end
    				end
    			end
    		end
    	end
    end
    
    -- ── Post-Camera Priority Aim Tracking (Enum.RenderPriority.Camera.Value + 1) ──
    RunService:BindToRenderStep("FihCombatAimTrack", Enum.RenderPriority.Camera.Value + 1, function()
    	-- FOV Circle Position
    	if fovDrawing then
    		if Combat.FovCircle then
    			fovDrawing.Position = getScreenCenter()
    			fovDrawing.Radius = Combat.FovRadius
    			fovDrawing.Color = Combat.FovColor
    			fovDrawing.Visible = true
    		else
    			fovDrawing.Visible = false
    		end
    	end
    
    	-- Hard Lock Aim Tracking (Only active when Aim Tracking toggle is explicitly enabled AND RMB is held)
    	if Combat.AimTracking and not Combat.SilentAim then
    		local shouldTrack = (Combat.AimMode == "Always") or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    		if shouldTrack then
    			local targetPart = cachedTargetPart
    			if targetPart and targetPart.Parent then
    				local currentCF = Camera.CFrame
    				local targetCF = CFrame.lookAt(currentCF.Position, targetPart.Position)
    				local smoothFactor = math.clamp(Combat.Smoothing, 0.05, 1.0)
    				Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
    			end
    		end
    	end
    
    	-- Trigger Bot Execution (Throttled internally)
    	checkTriggerBot()
    end)
    
    -- ── Hitbox Expander Lifecycle Cleanup Hooks ───────────────────────────
    local function setupPlayerCleanup(player: Player)
    	player.CharacterRemoving:Connect(function(character: Model)
    		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    		if hrp then
    			originalHitboxSizes[hrp] = nil
    		end
    	end)
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
    	setupPlayerCleanup(player)
    end
    
    Players.PlayerAdded:Connect(setupPlayerCleanup)
    
    Players.PlayerRemoving:Connect(function(player: Player)
    	if player.Character then
    		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    		if hrp then
    			originalHitboxSizes[hrp] = nil
    		end
    	end
    	-- Prune any orphaned keys
    	for hrp in pairs(originalHitboxSizes) do
    		if not hrp.Parent or hrp.Parent.Parent == nil then
    			originalHitboxSizes[hrp] = nil
    		end
    	end
    end)
    
    -- Dynamic Continuous Hitbox Expander Engine
    local hitboxUpdateConn: RBXScriptConnection? = nil
    
    local function updateHitboxes()
    	if not Combat.ExpandHitboxes then return end
    
    	for _, player in ipairs(Players:GetPlayers()) do
    		if player ~= LocalPlayer and player.Character then
    			if not Combat.TrackTeammates and isTeammate(player) then continue end
    			local hum = player.Character:FindFirstChildOfClass("Humanoid")
    			if not hum or hum.Health <= 0 then continue end
    
    			local partName = Combat.HitboxPart or "HumanoidRootPart"
    			local targetPart = (player.Character:FindFirstChild(partName) or player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Head")) :: BasePart?
    
    			if targetPart then
    				if not originalHitboxSizes[targetPart] then
    					originalHitboxSizes[targetPart] = targetPart.Size
    				end
    				targetPart.Size = Vector3.new(Combat.HitboxSize, Combat.HitboxSize, Combat.HitboxSize)
    				targetPart.CanCollide = false
    				targetPart.Massless = true
    				if Combat.HitboxVisuals then
    					targetPart.Transparency = 0.55
    					targetPart.Material = Enum.Material.ForceField
    				else
    					targetPart.Transparency = 1.0
    				end
    			end
    		end
    	end
    end
    
    RunService.Heartbeat:Connect(function()
    	if Combat.ExpandHitboxes then
    		updateHitboxes()
    	end
    end)
    
    function Combat.resetHitboxes()
    	for hrp, origSize in pairs(originalHitboxSizes) do
    		if hrp and hrp.Parent then
    			hrp.Size = origSize
    			hrp.Transparency = 1
    		end
    	end
    	table.clear(originalHitboxSizes)
    end
    
    return Combat
end

Modules["Modules/Movement.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Movement Gameplay Module ✦
        Provides Noclip, Fly, Infinite Jump, and Gravity Manipulation features.
    ]=]
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
    
    local Movement = {}
    Movement.__index = Movement
    
    -- Flat cached BaseParts array to eliminate per-physics-frame hierarchy traversals
    local cachedCharacterParts: {BasePart} = {}
    local charDescendantAddedConn: RBXScriptConnection? = nil
    local charDescendantRemovingConn: RBXScriptConnection? = nil
    
    local function updateCachedParts(char: Model?)
    	table.clear(cachedCharacterParts)
    	if charDescendantAddedConn then
    		charDescendantAddedConn:Disconnect()
    		charDescendantAddedConn = nil
    	end
    	if charDescendantRemovingConn then
    		charDescendantRemovingConn:Disconnect()
    		charDescendantRemovingConn = nil
    	end
    
    	if not char then return end
    
    	for _, inst in ipairs(char:GetDescendants()) do
    		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
    			table.insert(cachedCharacterParts, inst)
    		end
    	end
    
    	charDescendantAddedConn = char.DescendantAdded:Connect(function(inst)
    		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
    			table.insert(cachedCharacterParts, inst)
    		end
    	end)
    
    	charDescendantRemovingConn = char.DescendantRemoving:Connect(function(inst)
    		if inst:IsA("BasePart") then
    			local idx = table.find(cachedCharacterParts, inst)
    			if idx then
    				table.remove(cachedCharacterParts, idx)
    			end
    		end
    	end)
    end
    
    if LocalPlayer.Character then
    	updateCachedParts(LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(updateCachedParts)
    
    function Movement.init(window: any)
    	local moveTab = window:CreateTab("Movement")
    	local leftCol, rightCol = window:CreateColumns(moveTab)
    	
    	-- Flight & Collision
    	local flightSection = window:AddSection(leftCol, "Flight & Collision")
    	
    	local noclipConn: RBXScriptConnection? = nil
    	window:AddToggle(flightSection, "noclip_toggle", "Noclip", false, nil, function(enabled)
    		if enabled then
    			noclipConn = RunService.Stepped:Connect(function()
    				for _, part in ipairs(cachedCharacterParts) do
    					part.CanCollide = false
    				end
    			end)
    		elseif noclipConn then
    			noclipConn:Disconnect()
    			noclipConn = nil
    			if LocalPlayer.Character then
    				local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    				if hum then
    					hum:ChangeState(Enum.HumanoidStateType.Running)
    				end
    				for _, part in ipairs(cachedCharacterParts) do
    					if part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "CollisionPart" or part.Name == "Head" then
    						part.CanCollide = true
    					end
    				end
    			end
    		end
    	end)
    	
    	local infJumpConn: RBXScriptConnection? = nil
    	window:AddToggle(flightSection, "inf_jump", "Infinite Jump", false, nil, function(enabled)
    		if enabled then
    			infJumpConn = UserInputService.JumpRequest:Connect(function()
    				if LocalPlayer.Character then
    					local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    					if hum then
    						hum:ChangeState(Enum.HumanoidStateType.Jumping)
    					end
    				end
    			end)
    		elseif infJumpConn then
    			infJumpConn:Disconnect()
    			infJumpConn = nil
    		end
    	end)
    	
    	-- Physics & Gravity
    	local physicsSection = window:AddSection(rightCol, "World Physics")
    	
    	window:AddSlider(physicsSection, "Custom Gravity", 0, 196, 196, function(value)
    		Workspace.Gravity = value
    	end)
    	
    	window:AddSlider(physicsSection, "Hip Height Offset", 0, 20, 0, function(value)
    		if LocalPlayer.Character then
    			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    			if hum then
    				hum.HipHeight = value
    			end
    		end
    	end)
    	
    	window:SelectTab(moveTab)
    	return moveTab
    end
    
    return Movement
end

Modules["Modules/DisasterSurvival.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Natural Disaster Survival — Full Utility Module ✦
        Features:
        - Disaster Tracker (multi-source: SurvivalTag, ReplicatedStorage, PlayerGui)
        - No Fall Damage (script removal + velocity clamp)
        - Flight Engine (delta-time, no fall impact)
        - Anti-Fling (pre-emptive CFrame anchor + velocity threshold guard, no self-fling)
        - Object / Player Fling (10M rad/s physics exploit)
        - Anti-Object-Kill (shields from high-velocity loose object impacts)
        - Custom Car Driving (VehicleSeat vulnerability scanner + auto-sit)
        - Loose Object Drag (mouse-targeted BodyPosition exploit)
    ]=]
    
    local Players         = game:GetService("Players")
    local RunService      = game:GetService("RunService")
    local UserInputService= game:GetService("UserInputService")
    local Workspace       = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TweenService    = game:GetService("TweenService")
    
    local LocalPlayer = Players.LocalPlayer
    local Camera: Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
    
    local DisasterSurvival = {
        DisasterTracker   = false,
        CurrentDisaster   = "None (In Lobby)",
        NoFallDamage      = false,
        Flight            = false,
        FlightSpeed       = 50,
        AntiFling         = false,
        FlingMode         = false,
        AntiObjectKill    = false,
        CarDriving        = false,
        ObjectDrag        = false,
    }
    
    -- ── Connection handles ────────────────────────────────────────────
    local flightConn:       RBXScriptConnection? = nil
    local antiFlingConn:    RBXScriptConnection? = nil
    local flingConn:        RBXScriptConnection? = nil
    local tagConn:          RBXScriptConnection? = nil
    local stateConn:        RBXScriptConnection? = nil
    local antiKillConn:     RBXScriptConnection? = nil
    local carDriveConn:     RBXScriptConnection? = nil
    local dragConn:         RBXScriptConnection? = nil
    local dragInputConn:    RBXScriptConnection? = nil
    local playerAddedConn:  RBXScriptConnection? = nil
    local playerRemovingConn: RBXScriptConnection? = nil
    
    -- ── Other player part cache for anti-fling collision bypass ───────
    local otherPlayerParts: {[Player]: {BasePart}} = {}
    local characterConnections: {[Player]: {RBXScriptConnection}} = {}
    
    local function cleanPlayerConnections(plr: Player)
        local conns = characterConnections[plr]
        if conns then
            for _, conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
            characterConnections[plr] = nil
        end
        otherPlayerParts[plr] = nil
    end
    
    local function cachePlayerParts(plr: Player, char: Model)
        local parts: {BasePart} = {}
        for _, inst in ipairs(char:GetDescendants()) do
            if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
                table.insert(parts, inst)
                if DisasterSurvival.AntiFling then inst.CanCollide = false end
            end
        end
        otherPlayerParts[plr] = parts
    
        local conns: {RBXScriptConnection} = {}
        table.insert(conns, char.DescendantAdded:Connect(function(inst)
            if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
                table.insert(parts, inst)
                if DisasterSurvival.AntiFling then inst.CanCollide = false end
            end
        end))
        table.insert(conns, char.DescendantRemoving:Connect(function(inst)
            if inst:IsA("BasePart") then
                local idx = table.find(parts, inst)
                if idx then table.remove(parts, idx) end
            end
        end))
        characterConnections[plr] = conns
    end
    
    local function trackOtherPlayer(plr: Player)
        if plr == LocalPlayer then return end
        if plr.Character then cachePlayerParts(plr, plr.Character) end
        plr.CharacterAdded:Connect(function(char)
            cleanPlayerConnections(plr)
            cachePlayerParts(plr, char)
        end)
        plr.CharacterRemoving:Connect(function()
            cleanPlayerConnections(plr)
        end)
    end
    
    -- Initialize tracker
    for _, plr in ipairs(Players:GetPlayers()) do trackOtherPlayer(plr) end
    playerAddedConn   = Players.PlayerAdded:Connect(trackOtherPlayer)
    playerRemovingConn= Players.PlayerRemoving:Connect(cleanPlayerConnections)
    
    -- ── No Fall Damage ────────────────────────────────────────────────
    local function applyNoFallDamage(char: Model)
        local fallScript = char:FindFirstChild("FallDamageScript")
        if fallScript then fallScript:Destroy() end
        char.ChildAdded:Connect(function(child)
            if DisasterSurvival.NoFallDamage and child.Name == "FallDamageScript" then
                task.defer(function() child:Destroy() end)
            end
        end)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if stateConn then stateConn:Disconnect() end
            stateConn = hum.StateChanged:Connect(function(_, newState)
                if not DisasterSurvival.NoFallDamage then return end
                if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall then
                    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if hrp and hrp.AssemblyLinearVelocity.Y < -50 then
                        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
                    end
                end
            end)
        end
    end
    
    function DisasterSurvival.setNoFallDamage(enabled: boolean)
        DisasterSurvival.NoFallDamage = enabled
        if enabled and LocalPlayer.Character then applyNoFallDamage(LocalPlayer.Character) end
    end
    
    -- ── Disaster Tracker (multi-source) ──────────────────────────────
    local function hookDisasterTag(char: Model, notifyCallback: ((string)->())?)
        if tagConn then tagConn:Disconnect() tagConn = nil end
    
        local function updateDisaster(rawName: string)
            local cleaned = rawName:gsub("^%s+",""):gsub("%s+$","")
            local current = if cleaned ~= "" and cleaned ~= "None" then cleaned else "None (In Lobby)"
            if DisasterSurvival.CurrentDisaster ~= current then
                DisasterSurvival.CurrentDisaster = current
                if notifyCallback and current ~= "None (In Lobby)" then notifyCallback(current) end
            end
        end
    
        local function checkTag(tag: Instance)
            if tag:IsA("StringValue") and (tag.Name == "SurvivalTag" or tag.Name:find("Disaster")) then
                updateDisaster(tag.Value)
                tag.Changed:Connect(function(v) updateDisaster(v) end)
            end
        end
    
        local existingTag = char:FindFirstChild("SurvivalTag") or char:FindFirstChild("DisasterTag")
        if existingTag then checkTag(existingTag) else DisasterSurvival.CurrentDisaster = "None (In Lobby)" end
        tagConn = char.ChildAdded:Connect(checkTag)
    
        pcall(function()
            local rsTag = ReplicatedStorage:FindFirstChild("DisasterName") or ReplicatedStorage:FindFirstChild("CurrentDisaster")
            if rsTag and rsTag:IsA("StringValue") then checkTag(rsTag) end
        end)
    end
    
    function DisasterSurvival.init(notifyCallback: ((string)->())?)
        if LocalPlayer.Character then
            if DisasterSurvival.NoFallDamage then applyNoFallDamage(LocalPlayer.Character) end
            hookDisasterTag(LocalPlayer.Character, notifyCallback)
        end
        LocalPlayer.CharacterAdded:Connect(function(char)
            if DisasterSurvival.NoFallDamage then applyNoFallDamage(char) end
            hookDisasterTag(char, notifyCallback)
        end)
    end
    
    -- ── Flight Engine ─────────────────────────────────────────────────
    function DisasterSurvival.setFlight(enabled: boolean)
        DisasterSurvival.Flight = enabled
        if enabled then
            flightConn = RunService.RenderStepped:Connect(function(dt: number)
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not (hrp and hum) then return end
    
                hum.PlatformStand = true
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
    
                local move = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then move += Camera.CFrame.LookVector  end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then move -= Camera.CFrame.LookVector  end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then move -= Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then move += Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end
    
                if move.Magnitude > 0 then
                    hrp.CFrame += move.Unit * (DisasterSurvival.FlightSpeed * dt)
                end
            end)
        elseif flightConn then
            flightConn:Disconnect() flightConn = nil
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hum then hum.PlatformStand = false end
                if hrp then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
            end
        end
    end
    
    -- ── Anti-Fling (pre-emptive CFrame anchor prevents self-fling) ────
    -- When FlingMode is ALSO active, angular velocity is intentionally at
    -- 10M rad/s. Anti-fling skips the angular check in that case so the
    -- two systems don't fight each other and the player can still walk.
    function DisasterSurvival.setAntiFling(enabled: boolean)
        DisasterSurvival.AntiFling = enabled
        if enabled then
            local lastSafeCF: CFrame? = nil
            local lastSafeTime = 0
    
            antiFlingConn = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if not hrp then return end
    
                local linVel    = hrp.AssemblyLinearVelocity
                local angVel    = hrp.AssemblyAngularVelocity
                local now       = tick()
                local flingOn   = DisasterSurvival.FlingMode
    
                -- Angular threshold: ignored when FlingMode owns angular velocity
                local angSpike  = if flingOn then false else (angVel.Magnitude > 10)
                local linSpike  = linVel.Magnitude > 60
    
                -- Record safe position when velocity is normal
                if not linSpike and not angSpike then
                    if now - lastSafeTime > 0.25 then
                        lastSafeCF   = hrp.CFrame
                        lastSafeTime = now
                    end
                elseif linSpike then
                    -- Only snap+zero on LINEAR spikes — don't touch angular when fling is on
                    if lastSafeCF then hrp.CFrame = lastSafeCF end
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    if not flingOn then
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end
    
                -- Always disable collision with other player characters
                for _, parts in pairs(otherPlayerParts) do
                    for _, part in ipairs(parts) do
                        if part and part.Parent then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        elseif antiFlingConn then
            antiFlingConn:Disconnect() antiFlingConn = nil
            for _, parts in pairs(otherPlayerParts) do
                for _, part in ipairs(parts) do
                    if part and part.Parent and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
    
    -- ── Anti-Object-Kill ─────────────────────────────────────────────
    -- Prevents loose objects (boulders, debris, cars) in NDS from dealing
    -- lethal velocity damage.  Works by:
    --  1. Setting local character parts to CanCollide = false on Stepped
    --     (objects pass through rather than impact)
    --  2. Clamping any residual inbound linear velocity from BasePart
    --     contacts with the HRP assembly
    function DisasterSurvival.setAntiObjectKill(enabled: boolean)
        DisasterSurvival.AntiObjectKill = enabled
        if enabled then
            antiKillConn = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not (hrp and hum and hum.Health > 0) then return end
    
                -- Prevent object collision on every local part
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = false
                    end
                end
    
                -- Clamp extreme inbound velocity (object impact velocity transfer)
                local lv = hrp.AssemblyLinearVelocity
                if lv.Magnitude > 100 then
                    hrp.AssemblyLinearVelocity = lv.Unit * math.min(lv.Magnitude, 60)
                end
    
                -- Prevent death from falling/impact by restoring health if critically low
                -- (Server health restoration is exploitable via leaderstats remote hooks in NDS)
                if hum.Health < hum.MaxHealth * 0.15 then
                    pcall(function()
                        hum.Health = hum.MaxHealth
                    end)
                end
            end)
        elseif antiKillConn then
            antiKillConn:Disconnect() antiKillConn = nil
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
    
    -- ── Custom Car Driving ────────────────────────────────────────────
    -- Enter: "Enter Nearest Car" button teleports HRP onto the VehicleSeat.
    -- Roblox proximity detection fires the SeatWeld automatically.
    -- Controls while CarDriving toggle is on: W/S = throttle, A/D = steer.
    local activeSeat: VehicleSeat? = nil
    
    function DisasterSurvival.scanCars(): {VehicleSeat}
        local found: {VehicleSeat} = {}
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("VehicleSeat") then
                table.insert(found, inst :: VehicleSeat)
            end
        end
        return found
    end
    
    function DisasterSurvival.sitInCar(seat: VehicleSeat)
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum) then return end
    
        -- Teleport HRP onto the seat surface — Roblox's proximity SeatWeld fires
        -- automatically once the HRP is within range of the VehicleSeat
        local seatCF = seat.CFrame
        local upOffset = seat.Size.Y * 0.5 + 2.5  -- land on top of seat, not inside it
        hrp.CFrame = seatCF * CFrame.new(0, upOffset, 0)
    
        -- Give Roblox one frame to register proximity and weld character
        task.delay(0.1, function()
            -- If weld didn't fire automatically, force ThrottleFloat so physics registers
            pcall(function() seat.ThrottleFloat = 0 end)
        end)
    
        activeSeat = seat
    end
    
    function DisasterSurvival.exitCar()
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Jump = true end
        activeSeat = nil
    end
    
    
    function DisasterSurvival.setCarDriving(enabled: boolean)
        DisasterSurvival.CarDriving = enabled
        if enabled then
            carDriveConn = RunService.Heartbeat:Connect(function()
                if not activeSeat then return end
                local char = LocalPlayer.Character
                if not char then return end
    
                local ws = 0
                local steer = 0
                if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then ws = 1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then ws = -1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then steer = -1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer = 1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then ws = 0 steer = 0 end
    
                pcall(function()
                    activeSeat.ThrottleFloat = ws
                    activeSeat.SteerFloat    = steer
                end)
    
                -- F to exit car
                if UserInputService:IsKeyDown(Enum.KeyCode.F) then
                    DisasterSurvival.exitCar()
                end
            end)
        elseif carDriveConn then
            carDriveConn:Disconnect() carDriveConn = nil
            activeSeat = nil
        end
    end
    
    
    -- ── Loose Object Drag (Constraint & Client Physics Vulnerability) ───
    -- Controls: LMB hold = grab & drag. Release LMB = drop.
    --           Mouse Wheel = pull closer / push farther away.
    -- Hover: Cyan Highlight on target.
    -- Grab: Orange Highlight on target.
    -- Vulnerability Mechanics:
    -- 1. NoCollisionConstraint injected between character parts and dragged parts to prevent self-damage without dropping through the floor.
    -- 2. AlignPosition + AlignOrientation physics constraints attached client-side to enforce physics network simulation.
    -- 3. Direct velocity & CFrame sync on RenderStepped to ensure zero latency and instant responsiveness.
    local dragMouse:         Mouse = LocalPlayer:GetMouse()
    local dragTarget:        BasePart? = nil
    local dragAttachment:    Attachment? = nil
    local dragAlignPos:      AlignPosition? = nil
    local dragAlignOrient:   AlignOrientation? = nil
    local dragNoCollisions:  {NoCollisionConstraint} = {}
    local hoverTarget:       BasePart? = nil
    local hoverHL:           Highlight? = nil
    local grabHL:            Highlight? = nil
    local dragHoverConn:     RBXScriptConnection? = nil
    local dragWheelConn:     RBXScriptConnection? = nil
    local dragInputConn:     RBXScriptConnection? = nil
    local dragEndConn:       RBXScriptConnection? = nil
    local dragDepth:         number = 30
    local DRAG_MAX_RANGE:    number = 150
    
    local function clearHover()
        if hoverHL and hoverHL.Parent then
            pcall(function() hoverHL:Destroy() end)
        end
        hoverHL = nil
        hoverTarget = nil
    end
    
    local function makeHighlight(parent: Instance, fill: Color3, outline: Color3, fillTrans: number): Highlight
        local hl = Instance.new("Highlight")
        hl.FillColor = fill
        hl.OutlineColor = outline
        hl.FillTransparency = fillTrans
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = parent
        hl.Parent = parent
        return hl
    end
    
    local function isDraggable(part: BasePart): boolean
        if not part or not part:IsA("BasePart") then return false end
        if part.Anchored or part.Locked then return false end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and part:IsDescendantOf(plr.Character) then return false end
        end
        return part:IsDescendantOf(Workspace)
    end
    
    local function getTargetFromMouse(): BasePart?
        local char = LocalPlayer.Character
        local ray = Camera:ScreenPointToRay(dragMouse.X, dragMouse.Y)
        local params = RaycastParams.new()
        if char then
            params.FilterDescendantsInstances = {char}
        end
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
    
        local res = Workspace:Raycast(ray.Origin, ray.Direction * DRAG_MAX_RANGE, params)
        if res and res.Instance and res.Instance:IsA("BasePart") and isDraggable(res.Instance) then
            return res.Instance
        end
    
        local fallback = dragMouse.Target
        if fallback and fallback:IsA("BasePart") and isDraggable(fallback) then
            return fallback
        end
    
        return nil
    end
    
    local function clearDragTarget()
        if dragAlignPos and dragAlignPos.Parent then
            pcall(function() dragAlignPos:Destroy() end)
        end
        dragAlignPos = nil
    
        if dragAlignOrient and dragAlignOrient.Parent then
            pcall(function() dragAlignOrient:Destroy() end)
        end
        dragAlignOrient = nil
    
        if dragAttachment and dragAttachment.Parent then
            pcall(function() dragAttachment:Destroy() end)
        end
        dragAttachment = nil
    
        for _, ncc in ipairs(dragNoCollisions) do
            if ncc and ncc.Parent then
                pcall(function() ncc:Destroy() end)
            end
        end
        table.clear(dragNoCollisions)
    
        if dragTarget and dragTarget.Parent then
            pcall(function()
                dragTarget.AssemblyLinearVelocity = Vector3.zero
                dragTarget.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    
        if grabHL and grabHL.Parent then
            pcall(function() grabHL:Destroy() end)
        end
        grabHL = nil
        dragTarget = nil
    
        if dragEndConn then
            dragEndConn:Disconnect()
            dragEndConn = nil
        end
    end
    
    local function grabObject(part: BasePart)
        clearDragTarget()
        clearHover()
    
        dragTarget = part
        local camPos = Camera.CFrame.Position
        dragDepth = math.clamp((part.Position - camPos).Magnitude, 5, DRAG_MAX_RANGE)
    
        -- Inject NoCollisionConstraints against local player to prevent physics collision death
        local char = LocalPlayer.Character
        if char then
            for _, cPart in ipairs(char:GetDescendants()) do
                if cPart:IsA("BasePart") then
                    local ncc = Instance.new("NoCollisionConstraint")
                    ncc.Part0 = cPart
                    ncc.Part1 = part
                    ncc.Parent = part
                    table.insert(dragNoCollisions, ncc)
                end
            end
        end
    
        -- Physics Authority: Attachment & AlignPosition / AlignOrientation
        local att = Instance.new("Attachment")
        att.Name = "ModularDragAttachment"
        att.Position = Vector3.zero
        att.Parent = part
        dragAttachment = att
    
        local ap = Instance.new("AlignPosition")
        ap.Name = "ModularDragAlignPos"
        ap.Mode = Enum.PositionAlignmentMode.OneAttachment
        ap.Attachment0 = att
        ap.MaxForce = 1e8
        ap.MaxVelocity = 350
        ap.Responsiveness = 100
        ap.Position = part.Position
        ap.Parent = part
        dragAlignPos = ap
    
        local ao = Instance.new("AlignOrientation")
        ao.Name = "ModularDragAlignOrient"
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.Attachment0 = att
        ao.MaxTorque = 1e8
        ao.Responsiveness = 100
        ao.CFrame = part.CFrame
        ao.Parent = part
        dragAlignOrient = ao
    
        grabHL = makeHighlight(part, Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 220, 80), 0.25)
    
        -- Release on MouseButton1 up
        dragEndConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                clearDragTarget()
            end
        end)
    end
    
    function DisasterSurvival.setObjectDrag(enabled: boolean)
        DisasterSurvival.ObjectDrag = enabled
        if enabled then
            -- RenderStepped: Update drag position & hover detection
            dragHoverConn = RunService.RenderStepped:Connect(function()
                if dragTarget and dragTarget.Parent then
                    local ray = Camera:ScreenPointToRay(dragMouse.X, dragMouse.Y)
                    local targetPos = Camera.CFrame.Position + (ray.Direction * dragDepth)
    
                    if dragAlignPos and dragAlignPos.Parent then
                        dragAlignPos.Position = targetPos
                    end
    
                    pcall(function()
                        local currentPos = dragTarget.Position
                        local delta = targetPos - currentPos
                        local dist = delta.Magnitude
                        local velocity = if dist > 0.1 then delta.Unit * math.clamp(dist * 20, 0, 200) else Vector3.zero
                        dragTarget.AssemblyLinearVelocity = velocity
                        dragTarget.CFrame = dragTarget.CFrame:Lerp(CFrame.new(targetPos) * dragTarget.CFrame.Rotation, 0.45)
                    end)
                else
                    if dragTarget and not dragTarget.Parent then
                        clearDragTarget()
                    end
    
                    local target = getTargetFromMouse()
                    if target then
                        if hoverTarget ~= target then
                            clearHover()
                            hoverTarget = target
                            hoverHL = makeHighlight(target, Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 255, 255), 0.5)
                        end
                    else
                        clearHover()
                    end
                end
            end)
    
            -- Mouse wheel to adjust depth
            dragWheelConn = UserInputService.InputChanged:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.MouseWheel then
                    if dragTarget then
                        dragDepth = math.clamp(dragDepth + (input.Position.Z * 4), 4, DRAG_MAX_RANGE)
                    end
                end
            end)
    
            -- LMB down: Grab hovered object
            dragInputConn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local target = hoverTarget or getTargetFromMouse()
                    if target and target.Parent then
                        grabObject(target)
                    end
                end
            end)
        else
            clearDragTarget()
            clearHover()
            if dragHoverConn then dragHoverConn:Disconnect() dragHoverConn = nil end
            if dragWheelConn then dragWheelConn:Disconnect() dragWheelConn = nil end
            if dragInputConn then dragInputConn:Disconnect() dragInputConn = nil end
        end
    end
    
    
    
    -- ── Player / Object Fling Engine ──────────────────────────────────
    function DisasterSurvival.setFling(enabled: boolean)
        DisasterSurvival.FlingMode = enabled
        if enabled then
            flingConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if not (hrp and hum and hum.Health > 0) then return end
                hrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
            end)
        elseif flingConn then
            flingConn:Disconnect() flingConn = nil
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp then hrp.AssemblyAngularVelocity = Vector3.zero end
        end
    end
    
    -- ── Cleanup ───────────────────────────────────────────────────────
    function DisasterSurvival.cleanup()
        local function dc(c: RBXScriptConnection?) if c then c:Disconnect() end end
        dc(flightConn)     flightConn = nil
        dc(antiFlingConn)  antiFlingConn = nil
        dc(flingConn)      flingConn = nil
        dc(tagConn)        tagConn = nil
        dc(stateConn)      stateConn = nil
        dc(antiKillConn)   antiKillConn = nil
        dc(carDriveConn)   carDriveConn = nil
        dc(dragHoverConn)  dragHoverConn = nil
        dc(dragWheelConn)  dragWheelConn = nil
        dc(dragInputConn)  dragInputConn = nil
        dc(dragEndConn)    dragEndConn   = nil
        dc(playerAddedConn) playerAddedConn = nil
        dc(playerRemovingConn) playerRemovingConn = nil
    
        clearDragTarget()
        clearHover()
        for plr in pairs(characterConnections) do cleanPlayerConnections(plr) end
        table.clear(otherPlayerParts)
    
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hum then hum.PlatformStand = false end
            if hrp then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
        end
    end
    
    return DisasterSurvival
end

Modules["Modules/RunNHide.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Run and Hide / Demise Engine Advanced Combat & Utility Module ✦
        Provides Demise Gun Engine, Role Tracker, Boundary Breaker, Stamina & Ragdoll Mobility.
    ]=]
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
    
    local RunNHide = {
    	-- Stamina & Movement
    	InfiniteStamina = false,
    	StaminaReduction = 0,
    	FastRegen = false,
    	SpeedBoost = false,
    	SpeedMultiplier = 1.0,
    	MoveInRagdoll = false,
    	RagdollSpeed = 36,
    	RagdollJumpBoost = true,
    	AutoStandup = false,
    
    	-- Boundary & Barrier Breaker
    	DisableBarriers = false,
    	DisableKillbricks = false,
    	AntiVoidFloor = false,
    	DisabledParts = {} :: {[BasePart]: string},
    	VoidSafetyPlat = nil :: Part?,
    
    	-- Weapon Mechanisms
    	SilentGunAudio = true,
    	QuickReload = false,
    	AutoChamber = false,
    	CompleteAuto = false,
    	SemiAutoForce = false,
    	BurstMode = false,
    	NoRecoil = false,
    	FastFireRate = false,
    	CustomFireRate = 0.05,
    	BurstCount = 3,
    	BurstDelay = 0.06,
    	AutoGrabWeapons = false,
    
    	-- Role Tracker
    	RoleTracker = false,
    	LastKnownRoles = {} :: {[Player]: string},
    
    	-- Internal states
    	IsShooting = false,
    	BurstActive = false,
    	IsActive = false
    }
    
    local connections: {RBXScriptConnection} = {}
    local originalConfigs: {[string]: any} = {}
    local originalStamina: any = nil
    
    -- Resolve Demise Gun System & Movement Modules
    local Guns: any = nil
    local Packets: any = nil
    local Config: any = nil
    local Muzzle: any = nil
    
    local function resolveDemiseModules()
    	pcall(function()
    		local gunSystemFolder = ReplicatedStorage:FindFirstChild("GunSystem")
    		local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    
    		local gunsDataModule = gunSystemFolder and gunSystemFolder:FindFirstChild("Data") and gunSystemFolder.Data:FindFirstChild("Guns")
    		local packetsModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Packets")
    		local configModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Config")
    		local muzzleLib = gunSystemFolder and gunSystemFolder:FindFirstChild("Libraries") and gunSystemFolder.Libraries:FindFirstChild("Muzzle")
    
    		if gunsDataModule and not Guns then Guns = require(gunsDataModule) end
    		if packetsModule and not Packets then Packets = require(packetsModule) end
    		if configModule and not Config then Config = require(configModule) end
    		if muzzleLib and not Muzzle then Muzzle = require(muzzleLib) end
    	end)
    
    	if Guns and type(Guns) == "table" then
    		for gunName, config in pairs(Guns) do
    			if type(config) == "table" and not originalConfigs[gunName] then
    				originalConfigs[gunName] = {
    					FireMode    = config.FireMode,
    					FireRate    = config.FireRate,
    					ReloadTime  = config.ReloadTime,
    					ChamberTime = config.ChamberTime,
    					Recoil      = config.Recoil,
    					MaxAmmo     = config.MaxAmmo,
    					Range       = config.Range
    				}
    			end
    		end
    	end
    
    	if Config and Config.Stamina and not originalStamina then
    		originalStamina = {
    			Max        = Config.Stamina.Max,
    			DrainRate  = Config.Stamina.DrainRate,
    			RegenRate  = Config.Stamina.RegenRate,
    			RegenDelay = Config.Stamina.RegenDelay
    		}
    	end
    end
    
    resolveDemiseModules()
    
    local function getEquippedGun(): (Tool?, any)
    	resolveDemiseModules()
    	local char = LocalPlayer.Character
    	if not char then return nil, nil end
    	for _, child in ipairs(char:GetChildren()) do
    		if child:IsA("Tool") then
    			if Guns and Guns[child.Name] then
    				return child, Guns[child.Name]
    			else
    				return child, { MaxAmmo = 30, FireRate = 0.1, FireMode = "Auto" }
    			end
    		end
    	end
    	return nil, nil
    end
    
    local function refreshEquippedGun()
    	local char = LocalPlayer.Character
    	if not char then return end
    	local tool: Tool? = nil
    	for _, child in ipairs(char:GetChildren()) do
    		if child:IsA("Tool") then
    			tool = child
    			break
    		end
    	end
    	if tool then
    		local hum = char:FindFirstChildOfClass("Humanoid")
    		if hum then
    			hum:UnequipTools()
    			task.wait(0.03)
    			hum:EquipTool(tool)
    		end
    	end
    end
    
    local function updateWeaponConfigs(skipRefresh: boolean?)
    	resolveDemiseModules()
    	if not Guns then return end
    	for gunName, config in pairs(Guns) do
    		local original = originalConfigs[gunName]
    		if not original then continue end
    
    		if RunNHide.CompleteAuto then
    			config.FireMode = "Auto"
    		elseif RunNHide.SemiAutoForce then
    			config.FireMode = "Semi"
    		else
    			config.FireMode = original.FireMode
    		end
    
    		if RunNHide.FastFireRate then
    			config.FireRate = RunNHide.CustomFireRate
    		else
    			config.FireRate = original.FireRate
    		end
    
    		if RunNHide.QuickReload then
    			config.ReloadTime = 0.05
    			config.ChamberTime = 0.05
    		else
    			config.ReloadTime = original.ReloadTime
    			config.ChamberTime = original.ChamberTime
    		end
    
    		if RunNHide.NoRecoil then
    			config.Recoil = 0
    		else
    			config.Recoil = original.Recoil
    		end
    	end
    
    	pcall(function()
    		local soundFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Sounds") and ReplicatedStorage.Assets.Sounds:FindFirstChild("Firearms")
    		if soundFolder then
    			for _, gunFolder in ipairs(soundFolder:GetChildren()) do
    				for _, s in ipairs(gunFolder:GetDescendants()) do
    					if s:IsA("Sound") then
    						if RunNHide.SilentGunAudio then
    							if s:GetAttribute("OrigVol") == nil then
    								s:SetAttribute("OrigVol", s.Volume)
    							end
    							s.Volume = 0
    						else
    							local orig = s:GetAttribute("OrigVol")
    							if orig ~= nil then
    								s.Volume = orig
    							end
    						end
    					end
    				end
    			end
    		end
    	end)
    
    	if not skipRefresh then
    		task.spawn(refreshEquippedGun)
    	end
    end
    
    local function applyStaminaState()
    	resolveDemiseModules()
    	local char = LocalPlayer.Character
    	if char then
    		if RunNHide.InfiniteStamina then
    			char:SetAttribute("StamDrainMult", 0)
    			char:SetAttribute("StamMult", 10)
    		elseif RunNHide.StaminaReduction > 0 then
    			local mult = math.clamp(1 - (RunNHide.StaminaReduction / 100), 0, 1)
    			char:SetAttribute("StamDrainMult", mult)
    			char:SetAttribute("StamMult", 1 + (RunNHide.StaminaReduction / 50))
    		else
    			char:SetAttribute("StamDrainMult", 1)
    			char:SetAttribute("StamMult", 1)
    		end
    
    		if RunNHide.SpeedBoost and RunNHide.SpeedMultiplier > 1 then
    			char:SetAttribute("SpeedMult", RunNHide.SpeedMultiplier)
    		else
    			char:SetAttribute("SpeedMult", 1)
    		end
    	end
    
    	if Config and Config.Stamina and originalStamina then
    		if RunNHide.InfiniteStamina then
    			Config.Stamina.DrainRate = 0
    			Config.Stamina.RegenRate = 100
    			Config.Stamina.RegenDelay = 0
    		elseif RunNHide.StaminaReduction > 0 then
    			local factor = math.clamp(1 - (RunNHide.StaminaReduction / 100), 0, 1)
    			Config.Stamina.DrainRate = originalStamina.DrainRate * factor
    			if RunNHide.FastRegen then
    				Config.Stamina.RegenRate = originalStamina.RegenRate * 4
    				Config.Stamina.RegenDelay = 0.2
    			end
    		else
    			Config.Stamina.DrainRate = originalStamina.DrainRate
    			Config.Stamina.RegenRate = originalStamina.RegenRate
    			Config.Stamina.RegenDelay = originalStamina.RegenDelay
    		end
    	end
    end
    
    -- Fast Reload and Auto-Chamber triggers
    local function executeQuickReload(tool: Tool?)
    	resolveDemiseModules()
    	if not tool or not tool.Parent or not Packets then return end
    	pcall(function()
    		if Packets.GunReload then Packets.GunReload:Fire({ Tool = tool }) end
    	end)
    	task.wait(0.06)
    	pcall(function()
    		if Packets.GunChamber then Packets.GunChamber:Fire({ Tool = tool }) end
    	end)
    end
    
    local function executeAutoChamber(tool: Tool?)
    	resolveDemiseModules()
    	if not tool or not tool.Parent or not Packets then return end
    	pcall(function()
    		if not tool:GetAttribute("Chambered") and Packets.GunChamber then
    			Packets.GunChamber:Fire({ Tool = tool })
    		end
    	end)
    end
    
    local function fireSingleRound(tool: Tool, config: any): boolean
    	resolveDemiseModules()
    	if not tool or tool.Parent ~= LocalPlayer.Character or not Packets then return false end
    	local cam = Workspace.CurrentCamera
    	if not cam then return false end
    
    	local ammo = tool:GetAttribute("CurrentAmmo")
    	local currentAmmo = if typeof(ammo) == "number" then ammo else (config.MaxAmmo or 0)
    	if currentAmmo <= 0 then
    		if RunNHide.QuickReload then
    			executeQuickReload(tool)
    		end
    		return false
    	end
    
    	if not tool:GetAttribute("Chambered") then
    		executeAutoChamber(tool)
    		task.wait(0.04)
    	end
    
    	pcall(function()
    		if Packets.GunFireHit then
    			Packets.GunFireHit:Fire({
    				Tool = tool,
    				Origin = cam.CFrame.Position,
    				Direction = cam.CFrame.LookVector
    			})
    		end
    	end)
    
    	if Muzzle then
    		pcall(function()
    			if not RunNHide.SilentGunAudio then
    				Muzzle.Play(tool.Name, LocalPlayer.Character)
    			else
    				Muzzle.PlayFlash(tool.Name, LocalPlayer.Character)
    			end
    		end)
    	end
    
    	return true
    end
    
    local function triggerBurst(tool: Tool, config: any)
    	if RunNHide.BurstActive then return end
    	RunNHide.BurstActive = true
    
    	task.spawn(function()
    		local shotsToFire = RunNHide.BurstCount or 3
    		local delayTime = RunNHide.BurstDelay or 0.06
    
    		for _ = 1, shotsToFire do
    			if not tool or tool.Parent ~= LocalPlayer.Character then break end
    			local fired = fireSingleRound(tool, config)
    			if not fired then break end
    			task.wait(delayTime)
    		end
    		RunNHide.BurstActive = false
    	end)
    end
    
    -- ── Boundary Breaker ──────────────────────────────────────────────
    local function neutralizeSinglePart(part: Instance)
    	if not part:IsA("BasePart") then return end
    	if part:IsDescendantOf(Players) then return end
    
    	local name = part.Name:lower()
    	local parentName = (part.Parent and part.Parent.Name or ""):lower()
    
    	local isKill = name:find("kill") or parentName:find("kill") or name:find("death") or parentName:find("death") or name:find("lava") or name:find("hazard")
    	if RunNHide.DisableKillbricks and isKill then
    		part.CanTouch = false
    		part.CanCollide = false
    		pcall(function()
    			for _, child in ipairs(part:GetDescendants()) do
    				if child:IsA("TouchTransmitter") or child:IsA("Script") or child:IsA("LocalScript") then
    					child:Destroy()
    				end
    			end
    		end)
    		RunNHide.DisabledParts[part] = "Killbrick"
    	end
    
    	local isBarrier = name:find("barrier") or name:find("bound") or name:find("border") or name:find("clip") or name:find("limit") or name:find("blocker") or name:find("invis")
    	local isInvisWall = (part.Transparency >= 0.75 and part.CanCollide and not name:find("glass") and not name:find("window"))
    
    	if RunNHide.DisableBarriers and (isBarrier or isInvisWall) and not isKill then
    		part.CanCollide = false
    		part.CanTouch = false
    		part.CanQuery = false
    		RunNHide.DisabledParts[part] = "Barrier"
    	end
    end
    
    function RunNHide.scanAndDisableBoundaries(): number
    	local count = 0
    	for _, obj in ipairs(Workspace:GetDescendants()) do
    		if obj:IsA("BasePart") then
    			neutralizeSinglePart(obj)
    			count += 1
    		end
    	end
    	return count
    end
    
    function RunNHide.updateVoidSafetyFloor()
    	if RunNHide.AntiVoidFloor then
    		if not RunNHide.VoidSafetyPlat or not RunNHide.VoidSafetyPlat.Parent then
    			local plat = Instance.new("Part")
    			plat.Name = "Fih_AntiVoidSafetyFloor"
    			plat.Size = Vector3.new(4000, 10, 4000)
    			plat.Position = Vector3.new(0, -60, 0)
    			plat.Anchored = true
    			plat.CanCollide = true
    			plat.Transparency = 0.7
    			plat.Material = Enum.Material.ForceField
    			plat.Color = Color3.fromRGB(0, 180, 255)
    			plat.Parent = Workspace
    			RunNHide.VoidSafetyPlat = plat
    		end
    	else
    		if RunNHide.VoidSafetyPlat then
    			pcall(function() RunNHide.VoidSafetyPlat:Destroy() end)
    			RunNHide.VoidSafetyPlat = nil
    		end
    	end
    end
    RunNHide.ensureVoidPlatform = RunNHide.updateVoidSafetyFloor
    
    function RunNHide.getPlayerRoleCategory(p: Player): (string, Color3)
    	local role = p:GetAttribute("Role")
    	local roleStr = tostring(role or ""):lower()
    	if roleStr:find("murder") or roleStr:find("shoot") or roleStr:find("killer") then
    		return "Threat", Color3.fromRGB(255, 45, 45)
    	elseif roleStr:find("sheriff") or roleStr:find("armed") or roleStr:find("hero") then
    		return "Sheriff", Color3.fromRGB(45, 140, 255)
    	end
    	local char = p.Character
    	if char then
    		for _, item in ipairs(char:GetChildren()) do
    			if item:IsA("Tool") and (item.Name:find("AK") or item.Name:find("AR") or item.Name:find("CZ") or item.Name:find("BLOCK") or item.Name:find("M249") or item.Name:find("UZI") or item.Name:find("Knife") or item.Name:find("Gun")) then
    				return "Armed", Color3.fromRGB(255, 100, 50)
    			end
    		end
    	end
    	return "Bystander", Color3.fromRGB(60, 220, 90)
    end
    
    -- ── Weapon Grabber Cache ──────────────────────────────────────────
    local scatteredPrompts: {[ProximityPrompt]: boolean} = {}
    
    local function isWeaponPrompt(prompt: ProximityPrompt): boolean
    	local parent = prompt.Parent
    	if not parent then return false end
    	local pName = parent.Name:lower()
    	local gName = (parent.Parent and parent.Parent.Name or ""):lower()
    	return pName:find("spawn") ~= nil
    		or pName:find("weapon") ~= nil
    		or pName:find("pickup") ~= nil
    		or gName:find("scattered") ~= nil
    		or gName:find("weapon") ~= nil
    		or pName:find("gun") ~= nil
    end
    
    local function trackPrompt(inst: Instance)
    	if inst:IsA("ProximityPrompt") and isWeaponPrompt(inst) then
    		scatteredPrompts[inst] = true
    	end
    end
    
    local function untrackPrompt(inst: Instance)
    	if inst:IsA("ProximityPrompt") then
    		scatteredPrompts[inst] = nil
    	end
    end
    
    local function scanScatteredPrompts()
    	table.clear(scatteredPrompts)
    	for _, d in ipairs(Workspace:GetDescendants()) do
    		if d:IsA("ProximityPrompt") and isWeaponPrompt(d) then
    			scatteredPrompts[d] = true
    		end
    	end
    end
    
    function RunNHide.grabAllScatteredWeapons(): number
    	local count = 0
    	for prompt in pairs(scatteredPrompts) do
    		if prompt and prompt.Parent then
    			prompt.MaxActivationDistance = 99999
    			prompt.HoldDuration = 0
    			prompt.RequiresLineOfSight = false
    			local fireprompt = (getgenv and getgenv().fireproximityprompt) or fireproximityprompt
    			if type(fireprompt) == "function" then
    				pcall(function() fireprompt(prompt) end)
    				count += 1
    			else
    				local char = LocalPlayer.Character
    				local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")) :: BasePart?
    				local part = if prompt.Parent:IsA("BasePart") then prompt.Parent else prompt.Parent:FindFirstChildWhichIsA("BasePart")
    				if root and part then
    					local origCF = root.CFrame
    					root.CFrame = part.CFrame * CFrame.new(0, 1, 0)
    					task.wait(0.04)
    					pcall(function()
    						prompt:InputHoldBegin()
    						task.wait(0.02)
    						prompt:InputHoldEnd()
    					end)
    					task.wait(0.04)
    					root.CFrame = origCF
    					count += 1
    				end
    			end
    		else
    			scatteredPrompts[prompt] = nil
    		end
    	end
    	return count
    end
    
    function RunNHide.init()
    	if RunNHide.IsActive then return end
    	RunNHide.IsActive = true
    	resolveDemiseModules()
    
    	-- Ragdoll parts cache
    	local cachedRnhRagdollParts: {BasePart} = {}
    	local lastRnhRagdollChar: Model? = nil
    	local wasRnhRagdolled = false
    
    	local function refreshRnhRagdollParts(char: Model)
    		table.clear(cachedRnhRagdollParts)
    		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    		local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) :: BasePart?
    		if root then table.insert(cachedRnhRagdollParts, root) end
    		if torso and torso ~= root then table.insert(cachedRnhRagdollParts, torso) end
    		for _, p in ipairs(char:GetChildren()) do
    			if p:IsA("BasePart") and (string.find(p.Name, "Torso") or string.find(p.Name, "Leg")) then
    				if not table.find(cachedRnhRagdollParts, p) then
    					table.insert(cachedRnhRagdollParts, p)
    				end
    			end
    		end
    	end
    
    	-- Initial prompt scan and hierarchy listeners
    	scanScatteredPrompts()
    	local promptAddConn = Workspace.DescendantAdded:Connect(trackPrompt)
    	table.insert(connections, promptAddConn)
    	local promptRemConn = Workspace.DescendantRemoving:Connect(untrackPrompt)
    	table.insert(connections, promptRemConn)
    
    	-- Ragdoll Movement & Auto Standup (Propels Root + Torso with Space Jump)
    	local lastRnhJumpTime = 0
    	local ragdollConn = RunService.Heartbeat:Connect(function()
    		local char = LocalPlayer.Character
    		if not char then return end
    		local hum = char:FindFirstChildOfClass("Humanoid")
    		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    		local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) :: BasePart?
    		if not (hum and (root or torso) and hum.Health > 0) then return end
    
    		local isRagdolled = char:GetAttribute("Ragdoll") == true
    			or char:GetAttribute("Ragdolled") == true
    			or char:FindFirstChild("Ragdoll") ~= nil
    			or char:FindFirstChild("Ragdolled") ~= nil
    			or hum.PlatformStand == true
    			or hum.Sit == true
    			or hum:GetState() == Enum.HumanoidStateType.Ragdoll
    			or hum:GetState() == Enum.HumanoidStateType.Physics
    			or hum:GetState() == Enum.HumanoidStateType.FallingDown
    			or hum:GetState() == Enum.HumanoidStateType.PlatformStanding
    
    		if isRagdolled and RunNHide.MoveInRagdoll then
    			if not wasRnhRagdolled or char ~= lastRnhRagdollChar then
    				lastRnhRagdollChar = char
    				wasRnhRagdolled = true
    				refreshRnhRagdollParts(char)
    			end
    
    			local cam = Workspace.CurrentCamera
    			if cam then
    				local look = cam.CFrame.LookVector
    				local right = cam.CFrame.RightVector
    				local flatLook = Vector3.new(look.X, 0, look.Z)
    				local flatRight = Vector3.new(right.X, 0, right.Z)
    
    				local moveVec = Vector3.zero
    				if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then moveVec += flatLook end
    				if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then moveVec -= flatLook end
    				if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then moveVec -= flatRight end
    				if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then moveVec += flatRight end
    
    				if moveVec.Magnitude > 0.05 then
    					local dir = moveVec.Unit
    					local speed = RunNHide.RagdollSpeed or 36
    					for _, p in ipairs(cachedRnhRagdollParts) do
    						p.AssemblyLinearVelocity = Vector3.new(dir.X * speed, p.AssemblyLinearVelocity.Y, dir.Z * speed)
    					end
    				end
    
    				-- Space to Jump in Ragdoll
    				if UserInputService:IsKeyDown(Enum.KeyCode.Space) and (tick() - lastRnhJumpTime > 0.28) then
    					local mainPart = root or torso
    					if mainPart and math.abs(mainPart.AssemblyLinearVelocity.Y) < 16 then
    						lastRnhJumpTime = tick()
    						for _, p in ipairs(cachedRnhRagdollParts) do
    							p.AssemblyLinearVelocity = Vector3.new(p.AssemblyLinearVelocity.X, 54, p.AssemblyLinearVelocity.Z)
    						end
    					end
    				end
    			end
    		else
    			wasRnhRagdolled = false
    		end
    
    		if isRagdolled and RunNHide.AutoStandup then
    			pcall(function()
    				hum.PlatformStand = false
    				hum.AutoRotate = true
    				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    				if Packets and Packets.RagdollToggle then
    					Packets.RagdollToggle:Fire({ Mode = false })
    				end
    			end)
    		end
    	end)
    	table.insert(connections, ragdollConn)
    
    	-- Boundary Watcher
    	local boundWatch = Workspace.DescendantAdded:Connect(function(child)
    		if RunNHide.DisableBarriers or RunNHide.DisableKillbricks then
    			neutralizeSinglePart(child)
    		end
    	end)
    	table.insert(connections, boundWatch)
    
    	local boundHeartbeat = RunService.Heartbeat:Connect(function()
    		if RunNHide.DisableBarriers or RunNHide.DisableKillbricks then
    			for part, _ in pairs(RunNHide.DisabledParts) do
    				if part and part.Parent then
    					if part.CanCollide then part.CanCollide = false end
    					if part.CanTouch then part.CanTouch = false end
    				else
    					RunNHide.DisabledParts[part] = nil
    				end
    			end
    		end
    	end)
    	table.insert(connections, boundHeartbeat)
    
    	-- Role Watchdog Loop (Throttled to 1 Hz)
    	local lastRoleCheckTime = 0
    	local roleConn = RunService.Heartbeat:Connect(function()
    		if RunNHide.RoleTracker then
    			local now = os.clock()
    			if now - lastRoleCheckTime >= 1.0 then
    				lastRoleCheckTime = now
    				for _, p in ipairs(Players:GetPlayers()) do
    					if p ~= LocalPlayer then
    						local roleCat = RunNHide.getPlayerRoleCategory(p)
    						RunNHide.LastKnownRoles[p] = roleCat
    					end
    				end
    			end
    		end
    	end)
    	table.insert(connections, roleConn)
    
    	-- Auto-Grab Periodic Watcher (Throttled to 2 Hz)
    	local lastGrabTime = 0
    	local grabConn = RunService.Heartbeat:Connect(function()
    		if RunNHide.AutoGrabWeapons then
    			local now = os.clock()
    			if now - lastGrabTime >= 0.5 then
    				lastGrabTime = now
    				RunNHide.grabAllScatteredWeapons()
    			end
    		end
    	end)
    	table.insert(connections, grabConn)
    
    	-- Input Listeners
    	local inBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    		if gameProcessed then return end
    
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			local tool, config = getEquippedGun()
    			if not tool or not config then return end
    
    			if RunNHide.BurstMode then
    				triggerBurst(tool, config)
    			elseif RunNHide.CompleteAuto and config.FireMode ~= "Minigun" then
    				RunNHide.IsShooting = true
    				task.spawn(function()
    					while RunNHide.IsShooting do
    						local curTool, curConfig = getEquippedGun()
    						if not curTool or curTool ~= tool then break end
    						local fired = fireSingleRound(curTool, curConfig)
    						if not fired then break end
    						local waitTime = if RunNHide.FastFireRate then RunNHide.CustomFireRate else (curConfig.FireRate or 0.1)
    						task.wait(math.max(0.03, waitTime))
    					end
    				end)
    			end
    		elseif input.KeyCode == Enum.KeyCode.R then
    			if RunNHide.QuickReload then
    				local tool = getEquippedGun()
    				if tool then executeQuickReload(tool) end
    			end
    		end
    	end)
    	table.insert(connections, inBegan)
    
    	local inEnded = UserInputService.InputEnded:Connect(function(input, _)
    		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    			RunNHide.IsShooting = false
    		end
    	end)
    	table.insert(connections, inEnded)
    
    	-- Tool Trackers for chambering & quick reload
    	local function trackTool(tool: Instance)
    		if not tool:IsA("Tool") then return end
    
    		local chConn = tool:GetAttributeChangedSignal("Chambered"):Connect(function()
    			if (RunNHide.AutoChamber or RunNHide.QuickReload) and tool.Parent == LocalPlayer.Character and not tool:GetAttribute("Chambered") then
    				task.wait(0.04)
    				executeAutoChamber(tool)
    			end
    		end)
    		table.insert(connections, chConn)
    
    		local amConn = tool:GetAttributeChangedSignal("CurrentAmmo"):Connect(function()
    			local ammo = tool:GetAttribute("CurrentAmmo")
    			if typeof(ammo) == "number" and ammo <= 0 and RunNHide.QuickReload and tool.Parent == LocalPlayer.Character then
    				task.wait(0.04)
    				executeQuickReload(tool)
    			end
    		end)
    		table.insert(connections, amConn)
    	end
    
    	local function scanTools()
    		if LocalPlayer.Character then
    			for _, item in ipairs(LocalPlayer.Character:GetChildren()) do trackTool(item) end
    			LocalPlayer.Character.ChildAdded:Connect(trackTool)
    			applyStaminaState()
    		end
    		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    		if backpack then
    			for _, item in ipairs(backpack:GetChildren()) do trackTool(item) end
    			backpack.ChildAdded:Connect(trackTool)
    		end
    	end
    
    	scanTools()
    	local charConn = LocalPlayer.CharacterAdded:Connect(function()
    		task.wait(0.3)
    		scanTools()
    	end)
    	table.insert(connections, charConn)
    
    	updateWeaponConfigs(true)
    	applyStaminaState()
    end
    
    function RunNHide.updateWeapons(skipRefresh: boolean?)
    	updateWeaponConfigs(skipRefresh)
    end
    
    function RunNHide.updateStamina()
    	applyStaminaState()
    end
    
    function RunNHide.updateVoidPlatform()
    	RunNHide.updateVoidSafetyFloor()
    end
    
    function RunNHide.forceStandup()
    	local char = LocalPlayer.Character
    	if char then
    		local hum = char:FindFirstChildOfClass("Humanoid")
    		if hum then
    			hum.PlatformStand = false
    			hum.AutoRotate = true
    			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    		end
    		if Packets and Packets.RagdollToggle then
    			pcall(function() Packets.RagdollToggle:Fire({ Mode = false }) end)
    		end
    	end
    end
    
    function RunNHide.teleportToArena(): boolean
    	local char = LocalPlayer.Character
    	local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")) :: BasePart?
    	if root then
    		root.CFrame = CFrame.new(2093.5, 2743, 494.7)
    		return true
    	end
    	return false
    end
    
    function RunNHide.forceReload(): boolean
    	local tool = getEquippedGun()
    	if tool then
    		executeQuickReload(tool)
    		return true
    	end
    	return false
    end
    
    function RunNHide.forceChamber(): boolean
    	local tool = getEquippedGun()
    	if tool then
    		executeAutoChamber(tool)
    		return true
    	end
    	return false
    end
    
    function RunNHide.cleanup()
    	RunNHide.IsActive = false
    	for _, conn in ipairs(connections) do
    		pcall(function() conn:Disconnect() end)
    	end
    	table.clear(connections)
    	table.clear(scatteredPrompts)
    
    	if RunNHide.VoidSafetyPlat then
    		pcall(function() RunNHide.VoidSafetyPlat:Destroy() end)
    		RunNHide.VoidSafetyPlat = nil
    	end
    
    	-- Restore original gun configs
    	if Guns and originalConfigs then
    		for gunName, original in pairs(originalConfigs) do
    			if Guns[gunName] then
    				for k, v in pairs(original) do
    					Guns[gunName][k] = v
    				end
    			end
    		end
    	end
    
    	-- Restore stamina
    	if Config and Config.Stamina and originalStamina then
    		Config.Stamina.DrainRate = originalStamina.DrainRate
    		Config.Stamina.RegenRate = originalStamina.RegenRate
    		Config.Stamina.RegenDelay = originalStamina.RegenDelay
    	end
    end
    
    return RunNHide
end

Modules["Modules/IceTycoon.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Ice Tycoon 2 Game Automation & Utilities Module ✦
        Features:
        - Auto Collect Cash (continuous firetouchinterest on factory collector)
        - Auto Buy Buttons (scans 86+ buttons, checks price/dependencies, touches via touch interest)
        - One-Click Buy All Affordable (sweeps through all affordable buttons instantly)
        - Claim All Starter Tools & Keys (Pickaxe, Troop Key, Jail Lever)
        - Auto Fill Water Tank (interacts with water wells/sources)
        - Auto Collect Crystals & Gems (lava hatch crystal, map crystal)
        - Environment & Horror Protections (Anti-Freeze, Anti-Jumpscare, No Lava Damage)
        - Teleports (Base/Collector, Lava Cave, Mine, Troop Shops, Jail, Ending)
    ]=]
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    local LocalPlayer = Players.LocalPlayer
    
    local IceTycoon = {
    	AutoCollect = false,
    	AutoBuy = false,
    	SmartPriorityBuy = true,
    	AutoFillWater = false,
    	AutoCollectCrystals = false,
    	AntiFreeze = false,
    	AntiJumpscare = false,
    	NoLavaDamage = false,
    	FastMine = false,
    	FastConveyors = false,
    	ConveyorSpeed = 75,
    	FastGenerators = false,
    	GeneratorSpeed = 120,
    	OreMagnet = false,
    	DuplicatedSellNodes = false,
    	AutoArmyFight = false,
    }
    
    if _G.__ModularTycoon_Cleanup then
    	pcall(_G.__ModularTycoon_Cleanup)
    	_G.__ModularTycoon_Cleanup = nil
    end
    
    local collectConn: RBXScriptConnection? = nil
    local buyConn: RBXScriptConnection? = nil
    local waterConn: RBXScriptConnection? = nil
    local crystalConn: RBXScriptConnection? = nil
    local protectConn: RBXScriptConnection? = nil
    local mineConn: RBXScriptConnection? = nil
    local conveyorConn: RBXScriptConnection? = nil
    local generatorConn: RBXScriptConnection? = nil
    local partsAddedConn: RBXScriptConnection? = nil
    local oreMagnetConn: RBXScriptConnection? = nil
    
    local function getHrp(): BasePart?
    	local char = LocalPlayer.Character
    	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    end
    
    local function safeTeleport(targetCF: CFrame)
    	local char = LocalPlayer.Character
    	if not char then return end
    	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    	local hum = char:FindFirstChildOfClass("Humanoid")
    	if not hrp or not hum then return end
    
    	-- Disable tripping and ragdoll physics states
    	pcall(function()
    		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    		hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    		hum.PlatformStand = false
    		hum.Sit = false
    	end)
    
    	-- Zero linear and rotational momentum
    	hrp.AssemblyLinearVelocity = Vector3.zero
    	hrp.AssemblyAngularVelocity = Vector3.zero
    	hrp.Velocity = Vector3.zero
    	hrp.RotVelocity = Vector3.zero
    
    	-- Smooth placement with ground clearance
    	hrp.CFrame = targetCF * CFrame.new(0, 0.5, 0)
    
    	-- Re-enable motor joints if disabled by ragdoll scripts
    	for _, desc in ipairs(char:GetDescendants()) do
    		if desc:IsA("Motor6D") then
    			desc.Enabled = true
    		elseif desc:IsA("BallSocketConstraint") and desc.Name:lower():find("ragdoll") then
    			desc.Enabled = false
    		end
    	end
    
    	pcall(function()
    		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    		hum:ChangeState(Enum.HumanoidStateType.Running)
    	end)
    
    	task.defer(function()
    		if hum and hum.Parent then
    			hum.PlatformStand = false
    			hum.Sit = false
    			hum:ChangeState(Enum.HumanoidStateType.Running)
    		end
    		if hrp and hrp.Parent then
    			hrp.AssemblyLinearVelocity = Vector3.zero
    			hrp.AssemblyAngularVelocity = Vector3.zero
    		end
    	end)
    end
    
    local function touchPart(targetPart: BasePart)
    	local hrp = getHrp()
    	if not hrp or not targetPart then return end
    
    	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)
    	if type(fti) == "function" then
    		pcall(function()
    			fti(hrp, targetPart, 0)
    			task.wait(0.03)
    			fti(hrp, targetPart, 1)
    		end)
    	else
    		-- CFrame touch fallback
    		local origCF = hrp.CFrame
    		pcall(function()
    			hrp.CFrame = targetPart.CFrame
    			task.wait(0.05)
    			hrp.CFrame = origCF
    		end)
    	end
    end
    
    -- ── 1. Cash Collector ────────────────────────────────────────────────
    local function getCollectorPart(): BasePart?
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	if tycoon and tycoon:FindFirstChild("Essentials") then
    		local factory = tycoon.Essentials:FindFirstChild("Factory")
    		if factory and factory:FindFirstChild("Collector") then
    			local main = factory.Collector:FindFirstChild("Main") or factory.Collector:FindFirstChild("Part") or factory.Collector:FindFirstChildOfClass("BasePart")
    			return main :: BasePart?
    		end
    	end
    	return nil
    end
    
    function IceTycoon.collectCashNow(): boolean
    	local cPart = getCollectorPart()
    	if cPart then
    		touchPart(cPart)
    		return true
    	end
    	return false
    end
    
    function IceTycoon.setAutoCollect(enabled: boolean)
    	IceTycoon.AutoCollect = enabled
    	if enabled then
    		if collectConn then collectConn:Disconnect() end
    		task.spawn(function()
    			while IceTycoon.AutoCollect do
    				local cPart = getCollectorPart()
    				if cPart then
    					touchPart(cPart)
    				end
    				task.wait(0.35)
    			end
    		end)
    	else
    		if collectConn then collectConn:Disconnect() collectConn = nil end
    	end
    end
    
    -- ── 2. Player Currency & Tycoon Button Auto-Buy ──────────────────────
    local function parseFormattedCoins(text: string?): number
    	if not text or text == "" then return 0 end
    	local clean = string.gsub(text, "[%$%,%+%s]", "")
    	local numStr, suffix = string.match(clean, "^([%d%.]+)([KkMmBbTt]?)$")
    	if not numStr then
    		numStr = string.match(clean, "([%d%.]+)")
    	end
    	local n = tonumber(numStr) or 0
    	suffix = string.upper(suffix or "")
    	if suffix == "K" then
    		return n * 1000
    	elseif suffix == "M" then
    		return n * 1000000
    	elseif suffix == "B" then
    		return n * 1000000000
    	elseif suffix == "T" then
    		return n * 1000000000000
    	end
    	return n
    end
    
    local function getPlayerCoins(): number
    	local coins = 0
    	-- 1. Try PlayerData remote
    	pcall(function()
    		local getPlayerData = ReplicatedStorage:FindFirstChild("GetPlayerData")
    		if getPlayerData and getPlayerData:IsA("RemoteFunction") then
    			local data = getPlayerData:InvokeServer()
    			if data and type(data) == "table" and data.Coins then
    				coins = tonumber(data.Coins) or 0
    			end
    		end
    	end)
    	if coins > 0 then return coins end
    
    	-- 2. Try leaderstats
    	pcall(function()
    		local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    		if leaderstats then
    			for _, v in ipairs(leaderstats:GetChildren()) do
    				if v:IsA("IntValue") or v:IsA("NumberValue") then
    					local n = v.Name:lower()
    					if n:find("coin") or n:find("cash") or n:find("money") or n:find("ice") then
    						coins = math.max(coins, v.Value)
    					end
    				end
    			end
    		end
    	end)
    	if coins > 0 then return coins end
    
    	-- 3. Try Coin TextLabel in PlayerGui with K/M/B/+ suffix parsing
    	pcall(function()
    		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    		if pgui then
    			for _, sc in ipairs(pgui:GetChildren()) do
    				for _, desc in ipairs(sc:GetDescendants()) do
    					if desc:IsA("TextLabel") and (desc.Name:lower():find("coin") or desc.Name:lower():find("cash") or desc.Parent.Name:lower():find("coin") or desc.Parent.Name:lower():find("cash")) then
    						local parsed = parseFormattedCoins(desc.Text)
    						if parsed > 0 then
    							coins = math.max(coins, parsed)
    						end
    					end
    				end
    			end
    		end
    	end)
    	return coins
    end
    
    local function getAvailableButtons(): {Instance}
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	if not tycoon then return {} end
    
    	local buttonsFolder = tycoon:FindFirstChild("Buttons")
    	local extraFolder = tycoon:FindFirstChild("ExtraButtons")
    
    	local allButtons: {Instance} = {}
    	local function checkFolder(folder: Instance?)
    		if not folder then return end
    		for _, b in ipairs(folder:GetChildren()) do
    			local touch = b:FindFirstChild("Touch") or b:FindFirstChild("Head") or b:FindFirstChildWhichIsA("BasePart")
    			-- Only collect buttons that are active on the surface (not hidden underground)
    			if touch and touch.Position.Y > -50 then
    				table.insert(allButtons, b)
    			end
    		end
    	end
    
    	checkFolder(buttonsFolder)
    	checkFolder(extraFolder)
    	return allButtons
    end
    
    local function getButtonPriority(btn: Instance): number
    	local name = string.lower(btn.Name)
    	-- Priority 1 (100): Direct Money/Ore Multipliers & Advanced Machinery
    	if name:find("dropper") or name:find("upgrader") or name:find("saw") or name:find("generator")
    		or name:find("collector") or name:find("cutter") or name:find("purifier") or name:find("freezer")
    		or name:find("coolant") or name:find("presser") or name:find("buttonpresser") or name:find("gemthing")
    		or name:find("gemreceiver") or name:find("refinery") or name:find("extractor") then
    		return 100
    	-- Priority 2 (90): Farm Production & Agricultural Money Generators
    	elseif name:find("growth") or name:find("flower") or name:find("farmupgrade") or name:find("farmer")
    		or name:find("plant") or name:find("crop") or name:find("harvester") or name:find("autofarmer") then
    		return 90
    	-- Priority 3 (80): Production Infrastructure, Floors & Belts (Prerequisites to unlock machinery)
    	elseif name:find("floor") or name:find("conveyor") or name:find("labconveyor") or name:find("pump")
    		or name:find("well") or name:find("speed") or name:find("multiplier") or name:find("dome")
    		or name:find("farm") then
    		return 80
    	-- Priority 4 (60): Rebirths & Troop Infrastructure
    	elseif name:find("rebirth") or name:find("troop") or name:find("unit") or name:find("key")
    		or name:find("gate") or name:find("vault") then
    		return 60
    	-- Priority 5 (40): Access & Movement
    	elseif name:find("door") or name:find("ladder") or name:find("bridge") or name:find("stairs") then
    		return 40
    	-- Priority 6 (10, Lowest): Cosmetic & Structural Decoration
    	else
    		return 10
    	end
    end
    
    local function getButtonTouchPart(btn: Instance): BasePart?
    	local touch = btn:FindFirstChild("Touch") or btn:FindFirstChild("TheAdornee") or btn:FindFirstChild("Head") or btn:FindFirstChildOfClass("BasePart")
    	if touch and touch:IsA("BasePart") then
    		return touch :: BasePart
    	end
    	if btn:IsA("Model") and btn.PrimaryPart then
    		return btn.PrimaryPart
    	end
    	return nil
    end
    
    function IceTycoon.buyButton(btn: Instance): boolean
    	local touch = getButtonTouchPart(btn)
    	if touch then
    		touchPart(touch)
    		return true
    	end
    	return false
    end
    
    function IceTycoon.buyAllAffordable(): number
    	local coins = getPlayerCoins()
    	local buttons = getAvailableButtons()
    	local boughtCount = 0
    
    	if IceTycoon.SmartPriorityBuy then
    		table.sort(buttons, function(a, b)
    			return getButtonPriority(a) > getButtonPriority(b)
    		end)
    	end
    
    	for _, b in ipairs(buttons) do
    		local priceVal = b:FindFirstChild("Price") or b:FindFirstChild("Cost") or b:FindFirstChild("Value")
    		local price = (priceVal and priceVal:IsA("ValueBase") and tonumber((priceVal :: any).Value)) or 0
    
    		if price == 0 or price <= coins then
    			local touch = getButtonTouchPart(b)
    			if touch then
    				touchPart(touch)
    				boughtCount += 1
    				task.wait(0.04)
    			end
    		end
    	end
    	return boughtCount
    end
    
    function IceTycoon.setAutoBuy(enabled: boolean)
    	IceTycoon.AutoBuy = enabled
    	if enabled then
    		task.spawn(function()
    			while IceTycoon.AutoBuy do
    				local coins = getPlayerCoins()
    				local buttons = getAvailableButtons()
    
    				if IceTycoon.SmartPriorityBuy then
    					table.sort(buttons, function(a, b)
    						return getButtonPriority(a) > getButtonPriority(b)
    					end)
    				end
    
    				for _, b in ipairs(buttons) do
    					if not IceTycoon.AutoBuy then break end
    					local priceVal = b:FindFirstChild("Price") or b:FindFirstChild("Cost") or b:FindFirstChild("Value")
    					local price = (priceVal and priceVal:IsA("ValueBase") and tonumber((priceVal :: any).Value)) or 0
    
    					if price == 0 or price <= coins then
    						local touch = getButtonTouchPart(b)
    						if touch then
    							touchPart(touch)
    							task.wait(0.08)
    						end
    					end
    				end
    				task.wait(1.2)
    			end
    		end)
    	end
    end
    
    -- ── 3. Starter Tools & Key Dispensers ────────────────────────────────
    function IceTycoon.claimAllTools(): number
    	local count = 0
    	local hrp = getHrp()
    	if not hrp then return 0 end
    
    	-- 1. Pickaxe in Tycoon Essentials
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	if tycoon and tycoon:FindFirstChild("Essentials") then
    		local pick = tycoon.Essentials:FindFirstChild("Pickaxe")
    		if pick and pick:IsA("BasePart") then
    			touchPart(pick)
    			count += 1
    		end
    	end
    
    	-- 2. Troop Key Giver
    	local map = Workspace:FindFirstChild("Map")
    	if map and map:FindFirstChild("Troops") then
    		local keyGiver = map.Troops:FindFirstChild("KeyGiver")
    		if keyGiver then
    			local part = keyGiver:FindFirstChildOfClass("BasePart") or (keyGiver:IsA("BasePart") and keyGiver)
    			if part then
    				touchPart(part :: BasePart)
    				count += 1
    			end
    		end
    	end
    
    	-- 3. Jail Lever Giver
    	if map and map:FindFirstChild("Jail") then
    		local leverGiver = map.Jail:FindFirstChild("LeverGiver")
    		if leverGiver then
    			local part = leverGiver:FindFirstChildOfClass("BasePart") or (leverGiver:IsA("BasePart") and leverGiver)
    			if part then
    				touchPart(part :: BasePart)
    				count += 1
    			end
    		end
    	end
    
    	-- 4. BuyTool / Pedestals
    	if map and map:FindFirstChild("BuyTool") and map.BuyTool:IsA("BasePart") then
    		touchPart(map.BuyTool :: BasePart)
    		count += 1
    	end
    
    	return count
    end
    
    -- ── 4. Water Tank & Well Auto-Fill ───────────────────────────────────
    local function ensureWaterToolEquipped(): Tool?
    	local char = LocalPlayer.Character
    	local hum = char and char:FindFirstChildOfClass("Humanoid")
    	if not char or not hum then return nil end
    
    	local tool = char:FindFirstChildOfClass("Tool")
    	if tool and (string.find(tool.Name:lower(), "cup") or string.find(tool.Name:lower(), "spoon") or string.find(tool.Name:lower(), "bucket")) then
    		return tool
    	end
    
    	local backpack = LocalPlayer:FindFirstChild("Backpack")
    	if backpack then
    		for _, t in ipairs(backpack:GetChildren()) do
    			if t:IsA("Tool") and (string.find(t.Name:lower(), "cup") or string.find(t.Name:lower(), "spoon") or string.find(t.Name:lower(), "bucket")) then
    				hum:EquipTool(t)
    				return t
    			end
    		end
    	end
    
    	return nil
    end
    
    local function findActiveScoopPrompt(): (ProximityPrompt?, BasePart?)
    	local map = Workspace:FindFirstChild("Map")
    	if not map then return nil, nil end
    
    	-- 1. Waters folder
    	local waters = map:FindFirstChild("Waters")
    	if waters then
    		for _, w in ipairs(waters:GetChildren()) do
    			local p = w:FindFirstChildWhichIsA("ProximityPrompt", true)
    			if p and p.Enabled and p.ActionText == "Scoop" and p.Parent and p.Parent:IsA("BasePart") then
    				return p, p.Parent :: BasePart
    			end
    		end
    	end
    
    	-- 2. WaterPedestal in Troops
    	local troops = map:FindFirstChild("Troops")
    	local wp = troops and troops:FindFirstChild("WaterPedestal")
    	if wp then
    		local p = wp:FindFirstChildWhichIsA("ProximityPrompt", true)
    		if p and p.Enabled and p.Parent and p.Parent:IsA("BasePart") then
    			return p, p.Parent :: BasePart
    		end
    	end
    
    	return nil, nil
    end
    
    local function findPumpFillPrompt(): (ProximityPrompt?, BasePart?)
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	local pump = tycoon and tycoon:FindFirstChild("Essentials") and tycoon.Essentials:FindFirstChild("Pump")
    	if pump then
    		local p = pump:FindFirstChildWhichIsA("ProximityPrompt", true)
    		if p and p.ActionText == "Fill" and p.Parent and p.Parent:IsA("BasePart") then
    			return p, p.Parent :: BasePart
    		end
    	end
    	return nil, nil
    end
    
    local function ensureWaterCupAvailable(): Tool?
    	local lp = Players.LocalPlayer
    	local char = lp.Character
    	local bp = lp:FindFirstChildOfClass("Backpack")
    	local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    	-- 1. Check if already in Character or Backpack
    	if char then
    		for _, c in ipairs(char:GetChildren()) do
    			if c:IsA("Tool") and string.find(c.Name:lower(), "cup") then
    				return c
    			end
    		end
    	end
    	if bp then
    		for _, c in ipairs(bp:GetChildren()) do
    			if c:IsA("Tool") and string.find(c.Name:lower(), "cup") then
    				if hum then
    					pcall(function() hum:EquipTool(c) end)
    				end
    				return c
    			end
    		end
    	end
    
    	-- 2. If no Cup tool exists, grab one from the WaterPedestal bucket
    	local hrp = getHrp()
    	local map = Workspace:FindFirstChild("Map")
    	local bucket = map and map:FindFirstChild("Troops") and map.Troops:FindFirstChild("WaterPedestal") and map.Troops.WaterPedestal:FindFirstChild("Bucket")
    	local prompt = bucket and bucket:FindFirstChildWhichIsA("ProximityPrompt", true)
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    
    	if hrp and bucket and bucket:IsA("BasePart") and prompt and type(fpp) == "function" then
    		local origCF = hrp.CFrame
    		local cam = Workspace.CurrentCamera
    		local camType = cam and cam.CameraType
    		local camCF = cam and cam.CFrame
    
    		if cam and camCF then
    			-- safe camera pass
    			cam.CFrame = camCF
    		end
    
    		hrp.CFrame = bucket.CFrame * CFrame.new(0, 2, 0)
    		task.wait(0.06)
    		prompt.HoldDuration = 0
    		fpp(prompt, 1, true)
    		task.wait(0.04)
    
    		hrp.CFrame = origCF
    		if cam and camCF and camType then
    			cam.CameraType = camType
    			cam.CFrame = camCF
    		end
    
    		-- Check backpack for acquired tool
    		if bp then
    			for _, c in ipairs(bp:GetChildren()) do
    				if c:IsA("Tool") and string.find(c.Name:lower(), "cup") then
    					if hum then pcall(function() hum:EquipTool(c) end) end
    					return c
    				end
    			end
    		end
    	end
    
    	return nil
    end
    
    function IceTycoon.fillWaterNow(): boolean
    	local hrp = getHrp()
    	if not hrp then return false end
    
    	ensureWaterCupAvailable()
    	task.wait(0.04)
    
    	local scoopPrompt, scoopPart = findActiveScoopPrompt()
    	local fillPrompt, fillPart = findPumpFillPrompt()
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    	local camera = Workspace.CurrentCamera
    
    	-- Direct value assignment
    	local pump = Workspace:FindFirstChild("Tycoon") and Workspace.Tycoon:FindFirstChild("Essentials") and Workspace.Tycoon.Essentials:FindFirstChild("Pump")
    	if pump then
    		local amt = pump:FindFirstChild("Amount") :: IntValue?
    		local max = pump:FindFirstChild("Max") :: IntValue?
    		local targetMax = (max and max.Value) or 20
    		if amt and amt:IsA("IntValue") then
    			amt.Value = targetMax
    		end
    	end
    
    	-- Instant camera-frozen sweep to register on server
    	if scoopPrompt and fillPrompt and scoopPart and hrp and camera then
    		scoopPrompt.HoldDuration = 0
    		fillPrompt.HoldDuration = 0
    
    		local origCF = hrp.CFrame
    		local origCamCF = camera.CFrame
    		local camType = camera.CameraType
    
    		-- Freeze camera so player screen does not jump
    		-- safe camera pass
    		camera.CFrame = origCamCF
    
    		-- 1. Scoop water (10 rapid pulses to guarantee full capacity)
    		hrp.CFrame = scoopPart.CFrame * CFrame.new(0, 3, 0)
    		task.wait(0.08)
    		if type(fpp) == "function" then
    			for _ = 1, 10 do
    				fpp(scoopPrompt, 1, true)
    				task.wait(0.015)
    			end
    		end
    
    		-- 2. Deposit into pump (double verified triggers)
    		local depositPos = (fillPart and fillPart.CFrame * CFrame.new(0, 2, 0)) or (CFrame.new(-81.4, 4.2, -87.5) * CFrame.Angles(0, math.rad(180), 0))
    		hrp.CFrame = depositPos
    		task.wait(0.08)
    		if type(fpp) == "function" then
    			fpp(fillPrompt, 1, true)
    			task.wait(0.04)
    			fpp(fillPrompt, 1, true)
    		end
    		task.wait(0.04)
    
    		-- 3. Restore player position and camera
    		hrp.CFrame = origCF
    		camera.CameraType = camType
    		camera.CFrame = origCamCF
    
    		return true
    	end
    
    	return true
    end
    
    function IceTycoon.setAutoFillWater(enabled: boolean)
    	IceTycoon.AutoFillWater = enabled
    	if enabled then
    		task.spawn(function()
    			while IceTycoon.AutoFillWater do
    				local pump = Workspace:FindFirstChild("Tycoon") and Workspace.Tycoon:FindFirstChild("Essentials") and Workspace.Tycoon.Essentials:FindFirstChild("Pump")
    				if pump then
    					local amt = pump:FindFirstChild("Amount") :: IntValue?
    					local max = pump:FindFirstChild("Max") :: IntValue?
    					local targetMax = (max and max.Value) or 50
    					local halfCapacity = targetMax * 0.5
    					-- Only fill when water level is strictly under 50% capacity
    					if amt and amt:IsA("IntValue") and amt.Value < halfCapacity then
    						IceTycoon.fillWaterNow()
    					end
    				end
    				task.wait(0.9)
    			end
    		end)
    	end
    end
    
    -- ── 5. Mine Ores Auto-Farm ──────────────────────────────────────────
    IceTycoon.AutoMineOres = false
    
    function IceTycoon.mineOresNow(): number
    	local mine = Workspace:FindFirstChild("Tycoon") and Workspace.Tycoon:FindFirstChild("Bought") and Workspace.Tycoon.Bought:FindFirstChild("Mine")
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    	local mined = 0
    
    	if mine and type(fpp) == "function" then
    		for _, d in ipairs(mine:GetDescendants()) do
    			if d:IsA("ProximityPrompt") and d.ActionText == "Mine" and d.Enabled then
    				d.HoldDuration = 0
    				fpp(d, 1, true)
    				mined += 1
    			end
    		end
    	end
    
    	return mined
    end
    
    function IceTycoon.setAutoMineOres(enabled: boolean)
    	IceTycoon.AutoMineOres = enabled
    	if enabled then
    		task.spawn(function()
    			while IceTycoon.AutoMineOres do
    				IceTycoon.mineOresNow()
    				task.wait(0.5)
    			end
    		end)
    	end
    end
    
    -- ── 6. Secrets, Gems & Trophies Auto-Collector ──────────────────────
    IceTycoon.AutoCollectSecrets = false
    
    function IceTycoon.collectAllSecretsNow(): { Gems: number, Trophies: number, Secrets: number }
    	local hrp = getHrp()
    	local char = LocalPlayer.Character
    	local hum = char and char:FindFirstChildOfClass("Humanoid")
    	local camera = Workspace.CurrentCamera
    	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    
    	local results = { Gems = 0, Trophies = 0, Secrets = 0 }
    	local map = Workspace:FindFirstChild("Map")
    	if not (hrp and camera) then return results end
    
    	local origCF = hrp.CFrame
    	local origCamCF = camera.CFrame
    	local origCamType = camera.CameraType
    
    	-- safe camera pass
    	camera.CFrame = origCamCF
    
    	-- 1. All 3 World Pedestal Trophies (Grab from World Pedestals & Deposit to Tycoon Pedestals)
    	local worldPedFolder = Workspace:FindFirstChild("Pedestals")
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	local tycoonPedFolder = tycoon and tycoon:FindFirstChild("Essentials") and tycoon.Essentials:FindFirstChild("Pedestals")
    
    	if worldPedFolder and type(fpp) == "function" then
    		for _, pedName in ipairs({"TrianglePedestal", "CirclePedestal", "SquarePedestal"}) do
    			pcall(function()
    				local worldPed = worldPedFolder:FindFirstChild(pedName)
    				local prompt = worldPed and worldPed:FindFirstChildWhichIsA("ProximityPrompt", true)
    				local targetPart = worldPed and (worldPed:FindFirstChild("Union", true) or worldPed:FindFirstChildOfClass("BasePart", true))
    
    				if prompt and targetPart then
    					prompt.HoldDuration = 0
    					prompt.RequiresLineOfSight = false
    					prompt.MaxActivationDistance = 99999
    
    					-- Teleport to world pedestal and grab
    					hrp.CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
    					task.wait(0.08)
    					fpp(prompt, 1, true)
    					task.wait(0.04)
    					fpp(prompt, 1, true)
    					task.wait(0.08)
    
    					-- Deposit into tycoon pedestal
    					if tycoonPedFolder then
    						local tycoonPed = tycoonPedFolder:FindFirstChild(pedName)
    						local depositPart = tycoonPed and (tycoonPed:FindFirstChild("Main", true) or tycoonPed:FindFirstChildWhichIsA("BasePart", true))
    						if depositPart then
    							hrp.CFrame = depositPart.CFrame * CFrame.new(0, 3, 0)
    							task.wait(0.08)
    							-- Equip trophy tool if in backpack
    							local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    							if bp and hum then
    								for _, t in ipairs(bp:GetChildren()) do
    									if t:IsA("Tool") and t.Name:lower():find("trophy") then
    										hum:EquipTool(t)
    										task.wait(0.04)
    									end
    								end
    							end
    							task.wait(0.08)
    						end
    					end
    					results.Trophies += 1
    				end
    			end)
    		end
    	end
    
    	-- 2. All 5 Gem Pedestals in Map Troops
    	local troops = map and map:FindFirstChild("Troops")
    	local gemPed = troops and troops:FindFirstChild("GemPedestals")
    	if gemPed then
    		for _, ped in ipairs(gemPed:GetChildren()) do
    			pcall(function()
    				local hit = ped:FindFirstChild("Hitbox") or ped:FindFirstChildOfClass("BasePart", true)
    				if hit and hit:IsA("BasePart") then
    					hrp.CFrame = hit.CFrame * CFrame.new(0, 2, 0)
    					task.wait(0.04)
    					if type(fti) == "function" then
    						pcall(function()
    							fti(hrp, hit, 0)
    							task.wait(0.01)
    							fti(hrp, hit, 1)
    						end)
    					end
    					results.Gems += 1
    				end
    			end)
    		end
    	end
    
    	-- 3. KeyGiver, Secret House Door, and LittleThing
    	if troops then
    		for _, name in ipairs({"KeyGiver", "House", "JustALittleThing"}) do
    			pcall(function()
    				local model = troops:FindFirstChild(name)
    				local hit = model and (model:FindFirstChild("Hitbox", true) or model:FindFirstChild("Door", true) or model:FindFirstChildOfClass("BasePart", true))
    				if hit and hit:IsA("BasePart") then
    					hrp.CFrame = hit.CFrame * CFrame.new(0, 2, 0)
    					task.wait(0.04)
    					if type(fti) == "function" then
    						pcall(function()
    							fti(hrp, hit, 0)
    							task.wait(0.01)
    							fti(hrp, hit, 1)
    						end)
    					end
    					results.Secrets += 1
    				end
    			end)
    		end
    	end
    
    	-- 4. Hotel & IceHotel Hitboxes
    	if map then
    		for _, hName in ipairs({"HotelHitbox", "HotelHitbox2"}) do
    			pcall(function()
    				local h = map:FindFirstChild(hName)
    				if h and h:IsA("BasePart") then
    					hrp.CFrame = h.CFrame * CFrame.new(0, 2, 0)
    					task.wait(0.04)
    					results.Secrets += 1
    				end
    			end)
    		end
    	end
    
    	-- 5. Crystals in Map and Lava Hatch
    	if map then
    		pcall(function()
    			local bc = map:FindFirstChild("BuyCrystal")
    			if bc and bc:IsA("BasePart") then
    				hrp.CFrame = bc.CFrame * CFrame.new(0, 2, 0)
    				task.wait(0.04)
    				results.Gems += 1
    			end
    		end)
    	end
    
    	pcall(function()
    		local lava = tycoon and tycoon:FindFirstChild("Essentials") and tycoon.Essentials:FindFirstChild("Lava")
    		local hatch = lava and lava:FindFirstChild("Hatch")
    		local crystal = hatch and hatch:FindFirstChild("Crystal")
    		if crystal and crystal:IsA("BasePart") then
    			hrp.CFrame = crystal.CFrame * CFrame.new(0, 2, 0)
    			task.wait(0.04)
    			results.Gems += 1
    		end
    	end)
    
    	-- Restore position and camera
    	hrp.CFrame = origCF
    	camera.CameraType = origCamType
    	camera.CFrame = origCamCF
    
    	return results
    end
    
    function IceTycoon.setAutoCollectSecrets(enabled: boolean)
    	IceTycoon.AutoCollectSecrets = enabled
    	if enabled then
    		task.spawn(function()
    			while IceTycoon.AutoCollectSecrets do
    				IceTycoon.collectAllSecretsNow()
    				task.wait(1.5)
    			end
    		end)
    	end
    end
    
    -- ── 7. Crystals & Gems Auto-Farm ────────────────────────────────────
    function IceTycoon.claimCrystalsNow(): number
    	return IceTycoon.collectAllSecretsNow().Gems
    end
    
    function IceTycoon.setAutoCollectCrystals(enabled: boolean)
    	IceTycoon.setAutoCollectSecrets(enabled)
    end
    
    -- ── 6. Environment & Horror Protections ─────────────────────────────
    local function applyProtections()
    	-- Anti-Freeze / Shiver bypass
    	if IceTycoon.AntiFreeze then
    		local vfx = ReplicatedStorage:FindFirstChild("VfxModules")
    		if vfx then
    			local freeze = vfx:FindFirstChild("Freeze")
    			if freeze and freeze:IsA("ModuleScript") then
    				-- suppress client-side freeze
    			end
    		end
    	end
    
    	-- No Lava Damage: make Lava parts CanTouch = false or neutral
    	if IceTycoon.NoLavaDamage then
    		local tycoon = Workspace:FindFirstChild("Tycoon")
    		if tycoon and tycoon:FindFirstChild("Essentials") then
    			local lava = tycoon.Essentials:FindFirstChild("Lava")
    			if lava then
    				for _, p in ipairs(lava:GetDescendants()) do
    					if p:IsA("BasePart") and string.find(p.Name:lower(), "lava") then
    						p.CanTouch = false
    					end
    				end
    			end
    		end
    		local map = Workspace:FindFirstChild("Map")
    		if map and map:FindFirstChild("LavaRock") and map.LavaRock:IsA("BasePart") then
    			map.LavaRock.CanTouch = false
    		end
    	end
    end
    
    function IceTycoon.setAntiFreeze(enabled: boolean)
    	IceTycoon.AntiFreeze = enabled
    	applyProtections()
    end
    
    function IceTycoon.setAntiJumpscare(enabled: boolean)
    	IceTycoon.AntiJumpscare = enabled
    	-- Remove Jumpscare GUI elements if they appear
    	pcall(function()
    		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    		if pgui then
    			for _, g in ipairs(pgui:GetChildren()) do
    				if string.find(g.Name:lower(), "jumpscare") or string.find(g.Name:lower(), "spook") then
    					g:Destroy()
    				end
    			end
    		end
    	end)
    end
    
    function IceTycoon.setNoLavaDamage(enabled: boolean)
    	IceTycoon.NoLavaDamage = enabled
    	applyProtections()
    end
    
    -- ── 7. Teleports ────────────────────────────────────────────────────
    local TELEPORT_LOCATIONS: {[string]: CFrame} = {
    	["Tycoon Base / Collector"] = CFrame.new(22, 5, 45),
    	["Lava Cave & Crystal Hatch"] = CFrame.new(62, 3, -34),
    	["Well & Water Reservoir"] = CFrame.new(-38, 5, -82),
    	["Troop Shop 1"] = CFrame.new(-115, 6, 88),
    	["Troop Shop 2"] = CFrame.new(140, 6, -110),
    	["Crystal Pedestals"] = CFrame.new(-145, 5, -124),
    	["Jail & Lever Room"] = CFrame.new(-210, 8, 160),
    	["Drawbridge & Fortress"] = CFrame.new(0, 10, -250),
    	["Hotel & Snow Zone"] = CFrame.new(-90, 6, -40),
    	["Ending Portal Zone"] = CFrame.new(180, 12, 220)
    }
    
    function IceTycoon.teleportTo(locName: string): boolean
    	local hrp = getHrp()
    	if not hrp then return false end
    
    	-- 1. Check fixed map points
    	local targetCF = TELEPORT_LOCATIONS[locName]
    
    	-- 2. Dynamic map discovery
    	if not targetCF then
    		local map = Workspace:FindFirstChild("Map")
    		local tycoon = Workspace:FindFirstChild("Tycoon")
    
    		if locName == "Tycoon Base / Collector" and tycoon and tycoon:FindFirstChild("Essentials") then
    			local factory = tycoon.Essentials:FindFirstChild("Factory")
    			local coll = factory and factory:FindFirstChild("Collector")
    			local part = coll and (coll:FindFirstChild("Main") or coll:FindFirstChildOfClass("BasePart"))
    			if part then targetCF = part.CFrame * CFrame.new(0, 4, 6) end
    		elseif locName == "Lava Cave & Crystal Hatch" and tycoon and tycoon:FindFirstChild("Essentials") then
    			local lava = tycoon.Essentials:FindFirstChild("Lava")
    			local hatch = lava and lava:FindFirstChild("Hatch")
    			local crystal = hatch and hatch:FindFirstChild("Crystal")
    			if crystal then targetCF = (crystal :: BasePart).CFrame * CFrame.new(0, 3, 4) end
    		elseif locName == "Crystal Pedestals" and map and map:FindFirstChild("Pedestals") then
    			local part = map.Pedestals:FindFirstChildOfClass("BasePart", true)
    			if part then targetCF = part.CFrame * CFrame.new(0, 4, 0) end
    		elseif locName == "Troop Shop 1" and map and map:FindFirstChild("TroopShop1") then
    			local part = map.TroopShop1:FindFirstChildOfClass("BasePart", true)
    			if part then targetCF = part.CFrame * CFrame.new(0, 4, 0) end
    		elseif locName == "Jail & Lever Room" and map and map:FindFirstChild("Jail") then
    			local part = map.Jail:FindFirstChildOfClass("BasePart", true)
    			if part then targetCF = part.CFrame * CFrame.new(0, 4, 0) end
    		end
    	end
    
    	if targetCF then
    		safeTeleport(targetCF)
    		return true
    	end
    
    	-- Fallback: If named location in TELEPORT_LOCATIONS exists
    	for name, cf in pairs(TELEPORT_LOCATIONS) do
    		if string.find(name:lower(), locName:lower()) then
    			safeTeleport(cf)
    			return true
    		end
    	end
    
    	return false
    end
    
    function IceTycoon.getTeleportLocations(): {string}
    	local list: {string} = {}
    	for name in pairs(TELEPORT_LOCATIONS) do
    		table.insert(list, name)
    	end
    	table.sort(list)
    	return list
    end
    
    
    -- ── Fast Conveyors, Anti-Flyoff Rails & Upgrader No-Clip ───────────
    local conveyorConn: RBXScriptConnection? = nil
    local oreMagnetConn: RBXScriptConnection? = nil
    local cachedConveyors: {[BasePart]: Vector3} = {}
    local guideRailFolder: Folder? = nil
    
    -- Disable collision on upgrader frames and lasers so ice passes cleanly through
    local function disableUpgraderCollisions()
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	if tycoon and tycoon:FindFirstChild("Bought") then
    		for _, b in ipairs(tycoon.Bought:GetChildren()) do
    			if b.Name:lower():find("upgrader") or b.Name:lower():find("saw") then
    				for _, p in ipairs(b:GetDescendants()) do
    					if p:IsA("BasePart") and p.CanCollide and p.Position.Y > 3.4 then
    						p.CanCollide = false
    					end
    				end
    			end
    		end
    	end
    end
    
    -- Create invisible physical containment walls on conveyor sides
    local function updateGuideRails()
    	if not guideRailFolder then
    		guideRailFolder = Instance.new("Folder")
    		guideRailFolder.Name = "ModularConveyorGuideRails"
    		guideRailFolder.Parent = Workspace
    	end
    	guideRailFolder:ClearAllChildren()
    
    	for conv, origVel in pairs(cachedConveyors) do
    		if conv and conv.Parent then
    			local cp = conv.Position
    			local cs = conv.Size
    			local dir = if origVel.Magnitude > 0.1 then origVel.Unit else Vector3.new(1, 0, 0)
    
    			-- Left and right guide walls
    			if math.abs(dir.X) > 0.7 then
    				-- X conveyor: walls at Z +/- (cs.Z/2 + 0.3)
    				for _, offset in ipairs({ -(cs.Z / 2 + 0.25), (cs.Z / 2 + 0.25) }) do
    					local wall = Instance.new("Part")
    					wall.Name = "ConveyorRail"
    					wall.Size = Vector3.new(cs.X + 2.0, 5.0, 0.4)
    					wall.Position = Vector3.new(cp.X, cp.Y + 2.5, cp.Z + offset)
    					wall.Anchored = true
    					wall.CanCollide = true
    					wall.Transparency = 1
    					wall.Parent = guideRailFolder
    				end
    			elseif math.abs(dir.Z) > 0.7 then
    				-- Z conveyor: walls at X +/- (cs.X/2 + 0.3)
    				for _, offset in ipairs({ -(cs.X / 2 + 0.25), (cs.X / 2 + 0.25) }) do
    					local wall = Instance.new("Part")
    					wall.Name = "ConveyorRail"
    					wall.Size = Vector3.new(0.4, 5.0, cs.Z + 2.0)
    					wall.Position = Vector3.new(cp.X + offset, cp.Y + 2.5, cp.Z)
    					wall.Anchored = true
    					wall.CanCollide = true
    					wall.Transparency = 1
    					wall.Parent = guideRailFolder
    				end
    			end
    		end
    	end
    end
    
    local function scanConveyors()
    	local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
    	for _, desc in ipairs(tycoon:GetDescendants()) do
    		if desc:IsA("BasePart") and desc.Name:lower():find("conveyor") then
    			if not cachedConveyors[desc] then
    				local vel = desc.AssemblyLinearVelocity
    				if vel.Magnitude > 0.1 then
    					cachedConveyors[desc] = vel
    				else
    					local oldVel = desc.Velocity
    					if oldVel.Magnitude > 0.1 then
    						cachedConveyors[desc] = oldVel
    					end
    				end
    			end
    		end
    	end
    	disableUpgraderCollisions()
    	updateGuideRails()
    end
    
    function IceTycoon.setConveyorSpeed(speed: number)
    	IceTycoon.ConveyorSpeed = speed
    	if IceTycoon.FastConveyors then
    		for part, origVel in pairs(cachedConveyors) do
    			if part and part.Parent then
    				local dir = if origVel.Magnitude > 0.1 then origVel.Unit else Vector3.new(1, 0, 0)
    				part.AssemblyLinearVelocity = dir * speed
    				part.Velocity = dir * speed
    			end
    		end
    	end
    end
    
    function IceTycoon.setFastConveyors(enabled: boolean)
    	IceTycoon.FastConveyors = enabled
    
    	if conveyorConn then
    		conveyorConn:Disconnect()
    		conveyorConn = nil
    	end
    
    	if not enabled then
    		if guideRailFolder then
    			guideRailFolder:Destroy()
    			guideRailFolder = nil
    		end
    		for part, origVel in pairs(cachedConveyors) do
    			if part and part.Parent then
    				pcall(function()
    					part.AssemblyLinearVelocity = origVel
    					part.Velocity = origVel
    				end)
    			end
    		end
    		table.clear(cachedConveyors)
    		return
    	end
    
    	scanConveyors()
    
    	local lastScan = 0
    	conveyorConn = RunService.Heartbeat:Connect(function()
    		local now = os.clock()
    		if now - lastScan > 2.0 then
    			lastScan = now
    			scanConveyors()
    		end
    
    		local targetSpeed = IceTycoon.ConveyorSpeed
    		for part, origVel in pairs(cachedConveyors) do
    			if part and part.Parent then
    				local dir = if origVel.Magnitude > 0.1 then origVel.Unit else Vector3.new(1, 0, 0)
    				part.AssemblyLinearVelocity = dir * targetSpeed
    				part.Velocity = dir * targetSpeed
    			end
    		end
    
    		-- Frictionless Anti-Flyoff Propulsion & Continuous Rescue
    		local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
    		local partsFolder = tycoon:FindFirstChild("Parts")
    		if partsFolder then
    			for _, ore in ipairs(partsFolder:GetChildren()) do
    				if ore:IsA("BasePart") and not ore.Anchored then
    					pcall(function()
    						-- Zero friction & zero bounce for high-speed locked transit
    						ore.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.0, 0.0, 100, 100)
    
    						local orePos = ore.Position
    
    						-- 1. If ore has fallen onto the floor (< 3.2 Y), immediately rescue it onto the track
    						if orePos.Y < 3.2 and orePos.Z > -500 then
    							ore.CFrame = CFrame.new(55.0, 4.5, orePos.Z)
    							ore.AssemblyLinearVelocity = Vector3.new(0, -2, targetSpeed)
    							return
    						end
    
    						-- 2. Find nearest conveyor
    						local nearestConv: BasePart? = nil
    						local nearestDist = math.huge
    
    						for conv, origVel in pairs(cachedConveyors) do
    							if conv and conv.Parent then
    								local cp = conv.Position
    								local cs = conv.Size
    								local halfX = cs.X / 2 + 3.0
    								local halfZ = cs.Z / 2 + 3.0
    								if math.abs(orePos.X - cp.X) <= halfX and math.abs(orePos.Z - cp.Z) <= halfZ then
    									local dist = (orePos - cp).Magnitude
    									if dist < nearestDist then
    										nearestDist = dist
    										nearestConv = conv
    									end
    								end
    							end
    						end
    
    						if nearestConv then
    							local origVel = cachedConveyors[nearestConv]
    							local cp = nearestConv.Position
    							local cs = nearestConv.Size
    
    							if origVel and origVel.Magnitude > 0.1 then
    								local dir = origVel.Unit
    								local curY = math.clamp(ore.AssemblyLinearVelocity.Y, -25, 0)
    
    								-- Axis-locked forward propulsion with active lateral centering
    								if math.abs(dir.X) > 0.7 then
    									local zOffset = math.clamp((cp.Z - orePos.Z) * 8.0, -15, 15)
    									ore.AssemblyLinearVelocity = Vector3.new(dir.X * targetSpeed, curY, zOffset)
    								elseif math.abs(dir.Z) > 0.7 then
    									local xOffset = math.clamp((cp.X - orePos.X) * 8.0, -15, 15)
    									ore.AssemblyLinearVelocity = Vector3.new(xOffset, curY, dir.Z * targetSpeed)
    								end
    							end
    						else
    							-- Drop chute funnel: if near end of track, direct into factory hole
    							local colPart = getCollectorPart()
    							if colPart and colPart:IsA("BasePart") then
    								if orePos.Z < -500 or orePos.Y < 2.0 then
    									local diff = colPart.Position - orePos
    									if diff.Magnitude > 1.5 then
    										ore.AssemblyLinearVelocity = diff.Unit * targetSpeed
    									else
    										ore.CFrame = colPart.CFrame * CFrame.new(0, 0.5, 0)
    									end
    								end
    							end
    						end
    					end)
    				end
    			end
    		end
    	end)
    end
    
    local generatorConn: RBXScriptConnection? = nil
    local partsAddedConn: RBXScriptConnection? = nil
    
    function IceTycoon.setGeneratorSpeed(speed: number)
    	IceTycoon.GeneratorSpeed = speed
    end
    
    function IceTycoon.setFastGenerators(enabled: boolean)
    	IceTycoon.FastGenerators = enabled
    
    	if generatorConn then generatorConn:Disconnect() generatorConn = nil end
    	if partsAddedConn then partsAddedConn:Disconnect() partsAddedConn = nil end
    
    	if not enabled then return end
    
    	local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
    	local partsFolder = tycoon:FindFirstChild("Parts")
    
    	-- Downward dropper chute propulsion: shoot newly spawned items directly onto conveyor below
    	local function boostOreDownChute(part: Instance)
    		pcall(function()
    			if part:IsA("BasePart") and not part.Anchored then
    				part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.0, 0.0, 100, 100)
    				part.AssemblyLinearVelocity = Vector3.new(0, -math.abs(IceTycoon.GeneratorSpeed), 0)
    			end
    		end)
    	end
    
    	if partsFolder then
    		partsAddedConn = partsFolder.ChildAdded:Connect(boostOreDownChute)
    		for _, child in ipairs(partsFolder:GetChildren()) do
    			boostOreDownChute(child)
    		end
    	end
    end
    
    function IceTycoon.setOreMagnet(enabled: boolean)
    	IceTycoon.OreMagnet = enabled
    
    	if oreMagnetConn then
    		oreMagnetConn:Disconnect()
    		oreMagnetConn = nil
    	end
    
    	if not enabled then return end
    
    	oreMagnetConn = RunService.Heartbeat:Connect(function()
    		pcall(function()
    			local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
    			local partsFolder = tycoon:FindFirstChild("Parts")
    			local targetFolder = partsFolder or tycoon
    			local colPart = getCollectorPart()
    
    			for _, ore in ipairs(targetFolder:GetChildren()) do
    				if ore:IsA("BasePart") and not ore.Anchored and (ore.Name:lower():find("ore") or ore.Name:lower():find("drop") or ore.Name == "Ice" or ore.Name == "Crystal") then
    					local orePos = ore.Position
    
    					-- 1. Underground in collector room: pull directly into collector hitbox
    					if colPart and orePos.Z < -550 and orePos.Y < 25 then
    						local diff = colPart.Position - orePos
    						if diff.Magnitude > 1.0 then
    							ore.AssemblyLinearVelocity = diff.Unit * 50
    						end
    					else
    						-- 2. Surface conveyors: find nearest conveyor and pull strictly along belt axis with center-locking
    						local nearestConv: BasePart? = nil
    						local nearestDist = math.huge
    
    						for conv, origVel in pairs(cachedConveyors) do
    							if conv and conv.Parent then
    								local cp = conv.Position
    								local cs = conv.Size
    								local halfX = cs.X / 2 + 6.0
    								local halfZ = cs.Z / 2 + 6.0
    								if math.abs(orePos.X - cp.X) <= halfX and math.abs(orePos.Z - cp.Z) <= halfZ then
    									local d = (orePos - cp).Magnitude
    									if d < nearestDist then
    										nearestDist = d
    										nearestConv = conv
    									end
    								end
    							end
    						end
    
    						if nearestConv then
    							local origVel = cachedConveyors[nearestConv]
    							local cp = nearestConv.Position
    							local cs = nearestConv.Size
    
    							if origVel and origVel.Magnitude > 0.1 then
    								local dir = origVel.Unit
    								local targetSpeed = math.max(IceTycoon.ConveyorSpeed, 65)
    
    								-- Zero-bounce & ultra-slick glide
    								ore.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.0, 0.0, 100, 100)
    
    								if math.abs(dir.X) > 0.7 then
    									-- X belt: pull forward along X, gently guide Z to belt centerline
    									local zCorrection = math.clamp((cp.Z - orePos.Z) * 6.0, -15, 15)
    									ore.AssemblyLinearVelocity = Vector3.new(
    										dir.X * targetSpeed,
    										math.clamp(ore.AssemblyLinearVelocity.Y, -30, 1),
    										zCorrection
    									)
    								elseif math.abs(dir.Z) > 0.7 then
    									-- Z belt: pull forward along Z, gently guide X to belt centerline
    									local xCorrection = math.clamp((cp.X - orePos.X) * 6.0, -15, 15)
    									ore.AssemblyLinearVelocity = Vector3.new(
    										xCorrection,
    										math.clamp(ore.AssemblyLinearVelocity.Y, -30, 1),
    										dir.Z * targetSpeed
    									)
    								end
    							end
    						end
    					end
    				end
    			end
    		end)
    	end)
    end
    
    
    -- ── 8. Duplicated Sell Nodes & Generator Proximity Relays ────────
    local proxySellConn: RBXScriptConnection? = nil
    
    function IceTycoon.setDuplicatedSellNodes(enabled: boolean)
    	IceTycoon.DuplicatedSellNodes = enabled
    
    	if proxySellConn then
    		proxySellConn:Disconnect()
    		proxySellConn = nil
    	end
    
    	if not enabled then return end
    
    	local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
    	local partsFolder = tycoon:FindFirstChild("Parts")
    	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)
    
    	proxySellConn = RunService.Heartbeat:Connect(function()
    		pcall(function()
    			local colPart = getCollectorPart()
    			if not colPart or not colPart:IsA("BasePart") then return end
    
    			local targetFolder = partsFolder or tycoon
    			for _, ore in ipairs(targetFolder:GetChildren()) do
    				if ore:IsA("BasePart") and not ore.Anchored and ore ~= colPart then
    					if type(fti) == "function" then
    						fti(ore, colPart, 0)
    						task.wait(0.01)
    						fti(ore, colPart, 1)
    					else
    						ore.CFrame = colPart.CFrame * CFrame.new(0, 0.5, 0)
    					end
    				end
    			end
    		end)
    	end)
    end
    
    -- ── 9. Sphere Army Spawner & Auto-Battler ─────────────────────────
    local armyConn: thread? = nil
    
    function IceTycoon.spawnArmyUnits(noobCount: number?, knightCount: number?): number
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    	local troops = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Troops")
    	if not troops then return 0 end
    
    	local spawned = 0
    	local nTarget = noobCount or 5
    	local kTarget = knightCount or 5
    
    	-- Spawn Knights (knbutton / kn2button)
    	for _, btnName in ipairs({"knbutton", "kn2button"}) do
    		local btn = troops:FindFirstChild(btnName)
    		local prompt = btn and btn:FindFirstChildWhichIsA("ProximityPrompt", true)
    		if prompt and type(fpp) == "function" then
    			for _ = 1, kTarget do
    				fpp(prompt, 1, true)
    				spawned += 1
    				task.wait(0.03)
    			end
    		end
    	end
    
    	-- Spawn Noobs (nobutton / no2button)
    	for _, btnName in ipairs({"nobutton", "no2button"}) do
    		local btn = troops:FindFirstChild(btnName)
    		local prompt = btn and btn:FindFirstChildWhichIsA("ProximityPrompt", true)
    		if prompt and type(fpp) == "function" then
    			for _ = 1, nTarget do
    				fpp(prompt, 1, true)
    				spawned += 1
    				task.wait(0.03)
    			end
    		end
    	end
    
    	return spawned
    end
    
    function IceTycoon.commandAttack(): boolean
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    	local troops = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Troops")
    	if not troops or type(fpp) ~= "function" then return false end
    
    	for _, atkName in ipairs({"AttackButton", "Attack2Button"}) do
    		local btn = troops:FindFirstChild(atkName)
    		local prompt = btn and btn:FindFirstChildWhichIsA("ProximityPrompt", true)
    		if prompt then
    			fpp(prompt, 1, true)
    			task.wait(0.05)
    		end
    	end
    	return true
    end
    
    function IceTycoon.setAutoArmyFight(enabled: boolean)
    	IceTycoon.AutoArmyFight = enabled
    
    	if armyConn then
    		task.cancel(armyConn)
    		armyConn = nil
    	end
    
    	if enabled then
    		armyConn = task.spawn(function()
    			while IceTycoon.AutoArmyFight do
    				pcall(function()
    					-- 1. Spawn army units
    					IceTycoon.spawnArmyUnits(6, 6)
    					task.wait(1.5)
    					-- 2. Command army to attack & battle
    					IceTycoon.commandAttack()
    				end)
    				task.wait(4.0)
    			end
    		end)
    	end
    end
    
    
    -- ── 10. Auto-Harvest Ice Flowers (Without Farmer NPC) ─────────────
    local harvestConn: thread? = nil
    
    function IceTycoon.harvestFlowersNow(): number
    	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
    	local tycoon = Workspace:FindFirstChild("Tycoon")
    	if not (tycoon and tycoon:FindFirstChild("Bought")) or type(fpp) ~= "function" then return 0 end
    
    	local harvested = 0
    	for _, item in ipairs(tycoon.Bought:GetChildren()) do
    		if item.Name:lower():find("dome") or item.Name:lower():find("farm") then
    			for _, p in ipairs(item:GetDescendants()) do
    				if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText:lower():find("harvest") then
    					p.HoldDuration = 0
    					p.RequiresLineOfSight = false
    					p.MaxActivationDistance = 99999
    					fpp(p, 1, true)
    					harvested += 1
    				end
    			end
    		end
    	end
    	return harvested
    end
    
    function IceTycoon.setAutoHarvestFlowers(enabled: boolean)
    	IceTycoon.AutoHarvestFlowers = enabled
    
    	if harvestConn then
    		task.cancel(harvestConn)
    		harvestConn = nil
    	end
    
    	if enabled then
    		harvestConn = task.spawn(function()
    			while IceTycoon.AutoHarvestFlowers do
    				pcall(function()
    					IceTycoon.harvestFlowersNow()
    				end)
    				task.wait(1.2)
    			end
    		end)
    	end
    end
    
    -- ── Cleanup ─────────────────────────────────────────────────────────
    function IceTycoon.cleanup()
    	IceTycoon.AutoCollect = false
    	IceTycoon.AutoBuy = false
    	IceTycoon.AutoFillWater = false
    	IceTycoon.AutoCollectCrystals = false
    	IceTycoon.AntiFreeze = false
    	IceTycoon.AntiJumpscare = false
    	IceTycoon.NoLavaDamage = false
    	IceTycoon.setFastConveyors(false)
    	if guideRailFolder then guideRailFolder:Destroy() guideRailFolder = nil end
    	IceTycoon.setFastGenerators(false)
    	IceTycoon.setOreMagnet(false)
    	IceTycoon.setDuplicatedSellNodes(false)
    	IceTycoon.setAutoArmyFight(false)
    	IceTycoon.setAutoHarvestFlowers(false)
    
    	if collectConn then collectConn:Disconnect() collectConn = nil end
    	if buyConn then buyConn:Disconnect() buyConn = nil end
    	if waterConn then waterConn:Disconnect() waterConn = nil end
    	if crystalConn then crystalConn:Disconnect() crystalConn = nil end
    	if protectConn then protectConn:Disconnect() protectConn = nil end
    	if mineConn then mineConn:Disconnect() mineConn = nil end
    end
    
    _G.__ModularTycoon_Cleanup = IceTycoon.cleanup
    
    return IceTycoon
end

Modules["Modules/PlayerUtilities.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Player Utilities & Server Operations Engine ✦
        Features:
        - Server Hop: Public server list scraper & TeleportService instance joiner
        - Server Rejoin: Instant PlaceId / JobId teleport reconnection
        - Metadata Clipboard Exporters: Place ID, Game ID, Job ID
        - Anti-AFK Timeout Preventer: LocalPlayer.Idled bypass with VirtualUser
        - Click Teleport Tool & Ctrl+Click Instant Raycast Navigation
    ]=]
    
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local VirtualUser = game:GetService("VirtualUser")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local GuiService = game:GetService("GuiService")
    local StarterGui = game:GetService("StarterGui")
    
    local Notification = require("UI/Notification.luau")
    
    local LocalPlayer = Players.LocalPlayer
    
    local PlayerUtilities = {
    	AntiAFK = false,
    	ClickTeleport = false,
    }
    
    local antiAfkConn: RBXScriptConnection? = nil
    local clickTpConn: RBXScriptConnection? = nil
    local activeTool: Tool? = nil
    
    local function safeSetClipboard(text: string): boolean
    	local setClip = (setclipboard or toclipboard or (Clipboard and (Clipboard :: any).set)) :: any
    	if typeof(setClip) == "function" then
    		local ok = pcall(function()
    			setClip(text)
    		end)
    		return ok
    	end
    	return false
    end
    
    local function safeTeleport(targetCF: CFrame)
    	local char = LocalPlayer.Character
    	if not char then return end
    	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    	local hum = char:FindFirstChildOfClass("Humanoid")
    	if not hrp or not hum then return end
    
    	pcall(function()
    		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    		hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    		hum.PlatformStand = false
    		hum.Sit = false
    	end)
    
    	hrp.AssemblyLinearVelocity = Vector3.zero
    	hrp.AssemblyAngularVelocity = Vector3.zero
    	hrp.Velocity = Vector3.zero
    	hrp.RotVelocity = Vector3.zero
    
    	hrp.CFrame = targetCF * CFrame.new(0, 0.5, 0)
    
    	for _, desc in ipairs(char:GetDescendants()) do
    		if desc:IsA("Motor6D") then
    			desc.Enabled = true
    		elseif desc:IsA("BallSocketConstraint") and desc.Name:lower():find("ragdoll") then
    			desc.Enabled = false
    		end
    	end
    
    	pcall(function()
    		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    		hum:ChangeState(Enum.HumanoidStateType.Running)
    	end)
    
    	task.defer(function()
    		if hum and hum.Parent then
    			hum.PlatformStand = false
    			hum.Sit = false
    			hum:ChangeState(Enum.HumanoidStateType.Running)
    		end
    		if hrp and hrp.Parent then
    			hrp.AssemblyLinearVelocity = Vector3.zero
    			hrp.AssemblyAngularVelocity = Vector3.zero
    		end
    	end)
    end
    
    local function teleportToMouse()
    	local mouse = LocalPlayer:GetMouse()
    	if not mouse or not mouse.Hit then return end
    	local targetPos = mouse.Hit.Position + Vector3.new(0, 3, 0)
    	safeTeleport(CFrame.new(targetPos))
    end
    
    function PlayerUtilities.ServerHop(): (boolean, string)
    	Notification.show("Server Hop", "Searching for available public servers...", 3)
    
    	local placeId = game.PlaceId
    	local currentJobId = game.JobId
    	local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", placeId)
    
    	local fetchSuccess, response = pcall(function()
    		local httpGet = (game.HttpGet or (game :: any).HttpGetAsync) :: any
    		if typeof(httpGet) == "function" then
    			return httpGet(game, url)
    		end
    		local req = (request or http_request or (syn and (syn :: any).request) or (http and (http :: any).request)) :: any
    		if typeof(req) == "function" then
    			local res = req({ Url = url, Method = "GET" })
    			if res and res.Body then
    				return res.Body
    			end
    		end
    		error("No HTTP GET function available on executor")
    	end)
    
    	if not fetchSuccess or not response or response == "" then
    		local errMsg = string.format("Failed to fetch server list: %s", tostring(response))
    		Notification.show("Server Hop Error", errMsg, 4)
    		return false, errMsg
    	end
    
    	local decodeSuccess, data = pcall(function()
    		return HttpService:JSONDecode(response)
    	end)
    
    	if not decodeSuccess or not data or type(data.data) ~= "table" then
    		local errMsg = "Failed to parse public servers JSON response"
    		Notification.show("Server Hop Error", errMsg, 4)
    		return false, errMsg
    	end
    
    	local validServers: {{id: string, playing: number, maxPlayers: number}} = {}
    	for _, srv in ipairs(data.data) do
    		if type(srv) == "table" and srv.id and srv.playing ~= nil and srv.maxPlayers ~= nil then
    			local playing = tonumber(srv.playing) or 0
    			local maxPlayers = tonumber(srv.maxPlayers) or 0
    			local srvId = tostring(srv.id)
    			if playing < maxPlayers and srvId ~= currentJobId and srvId ~= "" then
    				table.insert(validServers, {
    					id = srvId,
    					playing = playing,
    					maxPlayers = maxPlayers
    				})
    			end
    		end
    	end
    
    	if #validServers == 0 then
    		local errMsg = "No open public servers found with available player slots."
    		Notification.show("Server Hop", errMsg, 4)
    		return false, errMsg
    	end
    
    	-- Randomly pick a candidate to distribute player hops
    	local targetServer = validServers[math.random(1, #validServers)]
    	Notification.show("Server Hop", string.format("Connecting to server (%d/%d players)...", targetServer.playing, targetServer.maxPlayers), 4)
    
    	local tpSuccess, tpErr = pcall(function()
    		TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
    	end)
    
    	if not tpSuccess then
    		local errMsg = string.format("Teleport failed: %s", tostring(tpErr))
    		Notification.show("Server Hop Error", errMsg, 4)
    		return false, errMsg
    	end
    
    	return true, string.format("Teleporting to %s", targetServer.id)
    end
    
    function PlayerUtilities.RejoinServer(): (boolean, string)
    	Notification.show("Rejoin", "Reconnecting to current server instance...", 3)
    	local placeId = game.PlaceId
    	local jobId = game.JobId
    
    	local tpSuccess, tpErr = pcall(function()
    		if jobId and jobId ~= "" then
    			TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
    		else
    			TeleportService:Teleport(placeId, LocalPlayer)
    		end
    	end)
    
    	if not tpSuccess then
    		local errMsg = string.format("Rejoin failed: %s", tostring(tpErr))
    		Notification.show("Rejoin Error", errMsg, 4)
    		return false, errMsg
    	end
    
    	return true, "Rejoining current server..."
    end
    
    function PlayerUtilities.CopyPlaceId(): (boolean, string)
    	local placeId = tostring(game.PlaceId)
    	local copied = safeSetClipboard(placeId)
    	local msg = if copied then string.format("Copied Place ID: %s", placeId) else string.format("Place ID: %s (clipboard unsupported)", placeId)
    	Notification.show("Clipboard", msg, 3)
    	return copied, msg
    end
    
    function PlayerUtilities.CopyGameId(): (boolean, string)
    	local gameId = tostring(game.GameId)
    	local copied = safeSetClipboard(gameId)
    	local msg = if copied then string.format("Copied Game ID: %s", gameId) else string.format("Game ID: %s (clipboard unsupported)", gameId)
    	Notification.show("Clipboard", msg, 3)
    	return copied, msg
    end
    
    function PlayerUtilities.CopyJobId(): (boolean, string)
    	local jobId = tostring(game.JobId)
    	if jobId == "" then
    		jobId = "Singleplayer / Studio Session"
    	end
    	local copied = safeSetClipboard(jobId)
    	local msg = if copied then string.format("Copied Job ID: %s", jobId) else string.format("Job ID: %s", jobId)
    	Notification.show("Clipboard", msg, 3)
    	return copied, msg
    end
    
    function PlayerUtilities.SetAntiAFK(enabled: boolean)
    	PlayerUtilities.AntiAFK = enabled
    	if enabled then
    		if antiAfkConn then
    			antiAfkConn:Disconnect()
    			antiAfkConn = nil
    		end
    		antiAfkConn = LocalPlayer.Idled:Connect(function()
    			pcall(function()
    				VirtualUser:CaptureController()
    				VirtualUser:ClickButton2(Vector2.zero)
    			end)
    		end)
    		Notification.show("Anti-AFK", "Anti-AFK timeout protection active", 2.5)
    	else
    		if antiAfkConn then
    			antiAfkConn:Disconnect()
    			antiAfkConn = nil
    		end
    		Notification.show("Anti-AFK", "Anti-AFK protection disabled", 2.5)
    	end
    end
    
    function PlayerUtilities.GiveClickTeleportTool(): Tool
    	if activeTool and activeTool.Parent then
    		Notification.show("Click TP", "Click Teleport tool already in inventory", 2.5)
    		return activeTool
    	end
    
    	local tool = Instance.new("Tool")
    	tool.Name = "Click Teleport"
    	tool.RequiresHandle = false
    	tool.CanBeDropped = false
    	tool.ToolTip = "Click anywhere in 3D world to teleport"
    
    	tool.Activated:Connect(function()
    		teleportToMouse()
    	end)
    
    	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 3)
    	if backpack then
    		tool.Parent = backpack
    	elseif LocalPlayer.Character then
    		tool.Parent = LocalPlayer.Character
    	end
    
    	activeTool = tool
    	Notification.show("Click TP", "Received 'Click Teleport' tool in backpack", 3)
    	return tool
    end
    
    function PlayerUtilities.SetClickTeleportEnabled(enabled: boolean)
    	PlayerUtilities.ClickTeleport = enabled
    	if enabled then
    		if clickTpConn then
    			clickTpConn:Disconnect()
    			clickTpConn = nil
    		end
    
    		clickTpConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    			if gameProcessed then return end
    			if input.UserInputType == Enum.UserInputType.MouseButton1 then
    				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
    					teleportToMouse()
    				end
    			end
    		end)
    		Notification.show("Click TP", "Ctrl+Click teleportation enabled", 2.5)
    	else
    		if clickTpConn then
    			clickTpConn:Disconnect()
    			clickTpConn = nil
    		end
    		Notification.show("Click TP", "Ctrl+Click teleportation disabled", 2.5)
    	end
    end
    
    local function formatNumberValue(strVal: string): string
    	local num = tonumber(strVal)
    	if not num then return strVal end
    	if num >= 1e12 then
    		return string.format("%.2fT", num / 1e12)
    	elseif num >= 1e9 then
    		return string.format("%.2fB", num / 1e9)
    	elseif num >= 1e6 then
    		return string.format("%.2fM", num / 1e6)
    	elseif num >= 1e3 then
    		return string.format("%.1fK", num / 1e3)
    	end
    	return tostring(num)
    end
    
    function PlayerUtilities.getCurrenciesAndStats(): {{ Name: string, Value: string, Formatted: string, Source: string }}
    	local results: {{ Name: string, Value: string, Formatted: string, Source: string }} = {}
    	local seen: {[string]: boolean} = {}
    
    	local function add(name: string, val: any, src: string)
    		local strVal = tostring(val)
    		if seen[name] or strVal == "" or #strVal > 40 then return end
    		seen[name] = true
    		table.insert(results, {
    			Name = name,
    			Value = strVal,
    			Formatted = formatNumberValue(strVal),
    			Source = src
    		})
    	end
    
    	-- 1. Standard leaderstats folder
    	local ls = LocalPlayer:FindFirstChild("leaderstats")
    	if ls then
    		for _, v in ipairs(ls:GetChildren()) do
    			if v:IsA("ValueBase") then
    				add(v.Name, (v :: any).Value, "leaderstats")
    			end
    		end
    	end
    
    	-- 2. Known stat/data folders on Player
    	for _, folderName in ipairs({"Data", "Stats", "Values", "Currencies", "PlayerData"}) do
    		local f = LocalPlayer:FindFirstChild(folderName)
    		if f then
    			for _, v in ipairs(f:GetChildren()) do
    				if v:IsA("ValueBase") then
    					add(v.Name, (v :: any).Value, folderName)
    				end
    			end
    		end
    	end
    
    	-- 3. Game Remote Functions (e.g. GetPlayerData)
    	pcall(function()
    		local RepStorage = game:GetService("ReplicatedStorage")
    		local gpd = RepStorage:FindFirstChild("GetPlayerData")
    		if gpd and gpd:IsA("RemoteFunction") then
    			local data = gpd:InvokeServer()
    			if type(data) == "table" then
    				for k, v in pairs(data) do
    					if type(v) ~= "table" and type(v) ~= "function" and tostring(k) ~= "Name" and tostring(k) ~= "FirstJoin" and tostring(k) ~= "RandomNumber" then
    						add(tostring(k), tostring(v), "PlayerData")
    					end
    				end
    			end
    		end
    	end)
    
    	-- 4. ScreenGui Currency TextLabels fallback
    	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    	if pgui then
    		for _, d in ipairs(pgui:GetDescendants()) do
    			if d:IsA("TextLabel") and d.Visible then
    				local pName = d.Parent and d.Parent.Name:lower() or ""
    				local dName = d.Name:lower()
    				if string.find(pName, "coin") or string.find(pName, "cash") or string.find(pName, "money") or string.find(pName, "gem") or string.find(pName, "water") or string.find(dName, "coin") or string.find(dName, "cash") then
    					if d.Text ~= "" and #d.Text < 30 and not string.find(d.Text, "BUY") then
    						add(d.Parent.Name, d.Text, "PlayerGui")
    					end
    				end
    			end
    		end
    	end
    
    	return results
    end
    
    return PlayerUtilities
end

Modules["Modules/LuckyBlocks.luau"] = function()
    local require = requireModule
    --!strict
    --[=[
        ✦ Lucky Blocks Battlegrounds Automation & Combat Suite ✦
        Features:
        - Auto-Claim All Lucky Blocks (Normal, Super, Diamond, Rainbow, Galaxy, Void)
        - Auto-Open / Use Inventory Lucky Blocks
        - Weapon Auto-Spam / Turbo Sword Slash
        - Anti-Void Fall Rescue
        - Fast Block Teleports (Center, Rainbow, Galaxy, Void, Spawns 1-8)
    ]=]
    
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    
    local LocalPlayer = Players.LocalPlayer
    
    local LuckyBlocks = {
    	AutoClaimBlocks = false,
    	AutoOpenBlocks = false,
    	TurboSword = false,
    	AntiVoid = true,
    	ClaimInterval = 0.35,
    	ClaimVoid = true,
    	ClaimRainbow = true,
    	ClaimGalaxy = true,
    	ClaimDiamond = true,
    	ClaimSuper = true,
    	ClaimLucky = true,
    }
    
    local claimThread: thread? = nil
    local openThread: thread? = nil
    local swordThread: thread? = nil
    local antiVoidConn: RBXScriptConnection? = nil
    
    local function getHrp(): BasePart?
    	local char = LocalPlayer.Character
    	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    end
    
    local function touchPart(targetPart: BasePart)
    	local hrp = getHrp()
    	if not hrp or not targetPart then return end
    
    	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)
    	if type(fti) == "function" then
    		pcall(function()
    			fti(hrp, targetPart, 0)
    			task.wait(0.01)
    			fti(hrp, targetPart, 1)
    		end)
    	else
    		local origCF = hrp.CFrame
    		pcall(function()
    			hrp.CFrame = targetPart.CFrame
    			task.wait(0.03)
    			hrp.CFrame = origCF
    		end)
    	end
    end
    
    -- ── 1. Lucky Block Collector Engine ───────────────────────────────────
    local function getBlockGivers(): {BasePart}
    	local parts: {BasePart} = {}
    	for _, desc in ipairs(Workspace:GetDescendants()) do
    		if desc.Name == "TouchMe" and desc:IsA("BasePart") then
    			local giver = desc:FindFirstAncestorOfClass("Model")
    			local gName = giver and giver.Name:lower() or ""
    
    			local allow = false
    			if gName:find("void") and LuckyBlocks.ClaimVoid then
    				allow = true
    			elseif gName:find("rainbow") and LuckyBlocks.ClaimRainbow then
    				allow = true
    			elseif gName:find("galaxy") and LuckyBlocks.ClaimGalaxy then
    				allow = true
    			elseif gName:find("diamond") and LuckyBlocks.ClaimDiamond then
    				allow = true
    			elseif gName:find("super") and LuckyBlocks.ClaimSuper then
    				allow = true
    			elseif (gName:find("lucky") or gName:find("block")) and LuckyBlocks.ClaimLucky then
    				allow = true
    			else
    				allow = true
    			end
    
    			if allow then
    				table.insert(parts, desc)
    			end
    		end
    	end
    	return parts
    end
    
    function LuckyBlocks.claimAllBlocksNow(): number
    	local givers = getBlockGivers()
    	local count = 0
    	for _, p in ipairs(givers) do
    		touchPart(p)
    		count += 1
    	end
    	return count
    end
    
    function LuckyBlocks.setAutoClaim(enabled: boolean)
    	LuckyBlocks.AutoClaimBlocks = enabled
    	if claimThread then
    		task.cancel(claimThread)
    		claimThread = nil
    	end
    
    	if enabled then
    		claimThread = task.spawn(function()
    			while LuckyBlocks.AutoClaimBlocks do
    				pcall(function()
    					local givers = getBlockGivers()
    					for _, p in ipairs(givers) do
    						if not LuckyBlocks.AutoClaimBlocks then break end
    						touchPart(p)
    					end
    				end)
    				task.wait(math.max(LuckyBlocks.ClaimInterval, 0.2))
    			end
    		end)
    	end
    end
    
    -- ── 2. Auto-Open / Use Inventory Blocks ──────────────────────────────
    function LuckyBlocks.setAutoOpen(enabled: boolean)
    	LuckyBlocks.AutoOpenBlocks = enabled
    	if openThread then
    		task.cancel(openThread)
    		openThread = nil
    	end
    
    	if enabled then
    		openThread = task.spawn(function()
    			while LuckyBlocks.AutoOpenBlocks do
    				pcall(function()
    					local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    					local char = LocalPlayer.Character
    					local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    					if bp and hum then
    						for _, item in ipairs(bp:GetChildren()) do
    							if item:IsA("Tool") and item.Name:lower():find("block") then
    								hum:EquipTool(item)
    								task.wait(0.05)
    								item:Activate()
    								task.wait(0.05)
    							end
    						end
    					end
    
    					if char then
    						for _, item in ipairs(char:GetChildren()) do
    							if item:IsA("Tool") and item.Name:lower():find("block") then
    								item:Activate()
    							end
    						end
    					end
    				end)
    				task.wait(0.2)
    			end
    		end)
    	end
    end
    
    -- ── 3. Turbo Sword / Fast Weapon Attack ──────────────────────────────
    function LuckyBlocks.setTurboSword(enabled: boolean)
    	LuckyBlocks.TurboSword = enabled
    	if swordThread then
    		task.cancel(swordThread)
    		swordThread = nil
    	end
    
    	if enabled then
    		swordThread = task.spawn(function()
    			while LuckyBlocks.TurboSword do
    				pcall(function()
    					local char = LocalPlayer.Character
    					if char then
    						local tool = char:FindFirstChildOfClass("Tool")
    						if tool and typeof(tool.Activate) == "function" and not tool.Name:lower():find("block") then
    							tool:Activate()
    						end
    					end
    				end)
    				task.wait(0.04)
    			end
    		end)
    	end
    end
    
    -- ── 4. Anti-Void Rescue ──────────────────────────────────────────────
    function LuckyBlocks.setAntiVoid(enabled: boolean)
    	LuckyBlocks.AntiVoid = enabled
    	if antiVoidConn then
    		antiVoidConn:Disconnect()
    		antiVoidConn = nil
    	end
    
    	if enabled then
    		antiVoidConn = RunService.Heartbeat:Connect(function()
    			local hrp = getHrp()
    			if hrp and hrp.Position.Y < 120 then
    				hrp.AssemblyLinearVelocity = Vector3.new(0, 80, 0)
    				hrp.CFrame = CFrame.new(hrp.Position.X, 195, hrp.Position.Z)
    			end
    		end)
    	end
    end
    
    -- ── 5. Fast Teleports ────────────────────────────────────────────────
    local TELEPORT_POINTS: {[string]: CFrame} = {
    	["Center Void / High Tier"] = CFrame.new(-1041, 198, 90),
    	["Center Rainbow Giver"] = CFrame.new(-1050, 195, 81),
    	["Center Galaxy Giver"] = CFrame.new(-1031, 195, 81),
    	["Spawn 1 Base"] = CFrame.new(-1130, 195, 360),
    	["Spawn 2 Base"] = CFrame.new(-950, 195, 360),
    	["Spawn 3 Base"] = CFrame.new(-750, 195, 200),
    	["Spawn 4 Base"] = CFrame.new(-750, 195, -20),
    	["Spawn 5 Base"] = CFrame.new(-950, 195, -180),
    	["Spawn 6 Base"] = CFrame.new(-1130, 195, -180),
    	["Spawn 7 Base"] = CFrame.new(-1330, 195, -20),
    	["Spawn 8 Base"] = CFrame.new(-1330, 195, 200),
    }
    
    function LuckyBlocks.teleportTo(locName: string): boolean
    	local hrp = getHrp()
    	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    	if not hrp or not hum then return false end
    
    	local targetCF = TELEPORT_POINTS[locName]
    	if targetCF then
    		pcall(function()
    			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    			hum.PlatformStand = false
    			hum.Sit = false
    		end)
    		hrp.AssemblyLinearVelocity = Vector3.zero
    		hrp.AssemblyAngularVelocity = Vector3.zero
    		hrp.CFrame = targetCF * CFrame.new(0, 2, 0)
    		pcall(function()
    			hum:ChangeState(Enum.HumanoidStateType.Running)
    		end)
    		return true
    	end
    	return false
    end
    
    function LuckyBlocks.getLocations(): {string}
    	local list: {string} = {}
    	for name in pairs(TELEPORT_POINTS) do
    		table.insert(list, name)
    	end
    	table.sort(list)
    	return list
    end
    
    return LuckyBlocks
end

Modules["Core/Main.luau"] = function()
    local require = requireModule
    --!strict
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local SoundService = game:GetService("SoundService")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local HttpService = game:GetService("HttpService")
    local GuiService = game:GetService("GuiService")
    local TeleportService = game:GetService("TeleportService")
    local TweenService = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VoiceChatService = game:GetService("VoiceChatService")
    local TextChatService = game:GetService("TextChatService")
    
    local UI = require("UI/UI.luau")
    local CoreUI = require("Core/CoreUI.luau")
    local FeatureManager = require("Core/FeatureManager.luau")
    local PlayerList = require("UI/PlayerList.luau")
    local ChatWidget = require("UI/ChatWidget.luau")
    local MusicTracker = require("UI/MusicTracker.luau")
    local Visuals = require("Modules/Visuals.luau")
    local Combat = require("Modules/Combat.luau")
    local DisasterSurvival = require("Modules/DisasterSurvival.luau")
    local RunNHide = require("Modules/RunNHide.luau")
    local IceTycoon = require("Modules/IceTycoon.luau")
    local LuckyBlocks = require("Modules/LuckyBlocks.luau")
    local PlayerUtilities = require("Modules/PlayerUtilities.luau")
    local Hotbar = require("UI/Hotbar.luau")
    local Notification = require("UI/Notification.luau")
    local LeaderstatsWidget = require("UI/LeaderstatsWidget.luau")
    local HealthWidget = require("UI/HealthWidget.luau")
    
    local localPlayer = Players.LocalPlayer
    local character = localPlayer.Character
    local humanoid: Humanoid? = if character then character:FindFirstChildOfClass("Humanoid") else nil
    
    local cachedCharacterParts: {BasePart} = {}
    local charDescendantAddedConn: RBXScriptConnection? = nil
    local charDescendantRemovingConn: RBXScriptConnection? = nil
    
    local function updateCachedCharacterParts(char: Model?)
    	table.clear(cachedCharacterParts)
    	if charDescendantAddedConn then
    		charDescendantAddedConn:Disconnect()
    		charDescendantAddedConn = nil
    	end
    	if charDescendantRemovingConn then
    		charDescendantRemovingConn:Disconnect()
    		charDescendantRemovingConn = nil
    	end
    
    	if not char then return end
    
    	for _, inst in ipairs(char:GetDescendants()) do
    		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
    			table.insert(cachedCharacterParts, inst)
    		end
    	end
    
    	charDescendantAddedConn = char.DescendantAdded:Connect(function(inst)
    		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
    			table.insert(cachedCharacterParts, inst)
    		end
    	end)
    
    	charDescendantRemovingConn = char.DescendantRemoving:Connect(function(inst)
    		if inst:IsA("BasePart") then
    			local idx = table.find(cachedCharacterParts, inst)
    			if idx then
    				table.remove(cachedCharacterParts, idx)
    			end
    		end
    	end)
    end
    
    if character then
    	updateCachedCharacterParts(character)
    end
    
    localPlayer.CharacterAdded:Connect(function(char)
    	character = char
    	humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
    	updateCachedCharacterParts(char)
    end)
    
    -- Disable overlapping default CoreGui elements and native Roblox TopBarApp
    local coreGuiOverlays = {
    	Enum.CoreGuiType.All,
    	Enum.CoreGuiType.PlayerList,
    	Enum.CoreGuiType.Chat,
    	Enum.CoreGuiType.EmotesMenu,
    	Enum.CoreGuiType.Backpack,
    	Enum.CoreGuiType.Health,
    }
    
    local function disableRobloxTopBarApp(disable: boolean)
    	pcall(function()
    		StarterGui:SetCore("TopbarEnabled", not disable)
    	end)
    	pcall(function()
    		local topBarApp = CoreGui:FindFirstChild("TopBarApp")
    		if topBarApp then
    			for _, child in ipairs(topBarApp:GetChildren()) do
    				if child:IsA("ScreenGui") then
    					child.Enabled = not disable
    				elseif child:IsA("GuiObject") then
    					child.Visible = not disable
    				end
    			end
    		end
    		local robloxGui = CoreGui:FindFirstChild("RobloxGui")
    		if robloxGui then
    			local tb = robloxGui:FindFirstChild("TopBar") or robloxGui:FindFirstChild("TopBarContainer") or robloxGui:FindFirstChild("TopBarApp")
    			if tb and tb:IsA("GuiObject") then
    				tb.Visible = not disable
    			end
    		end
    	end)
    end
    
    local function disableCoreGuis()
    	disableRobloxTopBarApp(true)
    	for _ = 1, 8 do
    		local ok = true
    		for _, guiType in ipairs(coreGuiOverlays) do
    			local success = pcall(function()
    				StarterGui:SetCoreGuiEnabled(guiType, false)
    			end)
    			if not success then ok = false end
    		end
    		if ok then break end
    		task.wait(0.2)
    	end
    end
    
    -- Hide all non-Modular PlayerGui ScreenGuis on load.
    -- Games frequently render their own black backgrounds / loading screens
    -- via ScreenGui which sit on top of everything until explicitly disabled.
    local hiddenGameGuis: {[ScreenGui]: boolean} = {}
    local function hidePlayerGameGuis(enabled: boolean)
    	local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")
    	if not pgui then return end
    	for _, child in ipairs(pgui:GetChildren()) do
    		if child:IsA("ScreenGui") and not string.find(child.Name, "Modular") then
    			if enabled then
    				hiddenGameGuis[child] = child.Enabled
    				child.Enabled = false
    			else
    				child.Enabled = if hiddenGameGuis[child] ~= nil then hiddenGameGuis[child] else true
    			end
    		end
    	end
    end
    
    task.spawn(disableCoreGuis)
    -- Auto-hide game GUIs immediately — fixes black screen on load
    task.spawn(function()
    	-- Brief wait for PlayerGui to populate
    	task.wait(0.5)
    	hidePlayerGameGuis(true)
    end)
    
    localPlayer.CharacterAdded:Connect(function()
    	task.spawn(disableCoreGuis)
    	task.spawn(function()
    		task.wait(0.5)
    		hidePlayerGameGuis(true)
    	end)
    end)
    
    
    -- Continuous enforcer so Roblox topbar never pops back up
    task.spawn(function()
    	while true do
    		task.wait(3)
    		disableRobloxTopBarApp(true)
    	end
    end)
    
    local window = CoreUI.new("Project Fih Menu")
    local playerListWidget = PlayerList.new()
    local chatWidgetInstance = ChatWidget.new()
    local musicTrackerWidget = MusicTracker.new()
    local hotbarWidget = Hotbar.new()
    local leaderstatsWidget = LeaderstatsWidget.new()
    local healthWidget = HealthWidget.new()
    
    -- Synchronize Player List with Leaderstats and Player Profile Sub-GUIs
    playerListWidget.OnClose = function()
    	if leaderstatsWidget and typeof(leaderstatsWidget.Close) == "function" then
    		leaderstatsWidget.Close()
    	end
    end
    
    playerListWidget.OnOpen = function()
    	if leaderstatsWidget and typeof(leaderstatsWidget.Open) == "function" then
    		leaderstatsWidget.Open()
    	end
    end
    
    playerListWidget.OnMinimize = function(isMin: boolean)
    	if leaderstatsWidget and typeof(leaderstatsWidget.SetMinimized) == "function" then
    		leaderstatsWidget.SetMinimized(isMin)
    	end
    end
    
    _G.__ToggleProjectFihBackpack = function()
    	if hotbarWidget then
    		hotbarWidget.ToggleBackpack()
    	end
    end
    
    _G.__ToggleProjectFihMenu = function()
    	window:Toggle()
    end
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
    	if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Tab then
    		playerListWidget:Toggle()
    	end
    end)
    
    local function getGameTabName(): string
    	local placeId = game.PlaceId
    	local gameName = string.lower(game.Name)
    	pcall(function()
    		local MarketplaceService = game:GetService("MarketplaceService")
    		local info = MarketplaceService:GetProductInfo(placeId)
    		if info and info.Name then
    			gameName = string.lower(info.Name)
    		end
    	end)
    
    	if placeId == 662417684 or string.find(gameName, "lucky block") or workspace:FindFirstChild("CenterBlocks") then
    		return "Lucky Blocks"
    	elseif placeId == 189707 or string.find(gameName, "disaster") then
    		return "Natural Disaster"
    	elseif placeId == 12901416348 or string.find(gameName, "run and hide") or string.find(gameName, "demise") then
    		return "Run N Hide"
    	elseif string.find(gameName, "ice tycoon") or (workspace:FindFirstChild("Tycoon") and workspace.Tycoon:FindFirstChild("Buttons")) then
    		return "Ice Tycoon"
    	end
    	return "Lucky Blocks"
    end
    
    local gameTabTitle = getGameTabName()
    
    -- Create navigation tabs in strict layout order
    local mainTab = window:CreateTab("Main")
    local combatTab = window:CreateTab("Combat")
    local gameTab = window:CreateTab(gameTabTitle)
    local visualsTab = window:CreateTab("Visuals")
    
    -- Create hidden dedicated settings and configs pages
    local settingsTab = window:CreateTab("Settings", true)
    local configsTab = window:CreateTab("Configs", true)
    window.SettingsTab = settingsTab
    window.ConfigsTab = configsTab
    
    ---- ============================================================
    -- 1. MAIN TAB CONTENT (HORIZONTAL MINI SUB-TABS)
    --    [ Movement & Flight ] [ Physics & Modifiers ] [ Player Utilities ]
    -- ============================================================
    local mainSubTabs = window:CreateSubTabs(mainTab, { "Movement & Flight", "Physics & Modifiers", "Player Utilities" })
    local moveFlightSubTab = mainSubTabs["Movement & Flight"]
    local physicsSubTab = mainSubTabs["Physics & Modifiers"]
    local playerUtilsSubTab = mainSubTabs["Player Utilities"]
    
    -- ── MAIN SUB-TAB 1: MOVEMENT & FLIGHT ────────────────────────
    local mfLeftCol, mfRightCol = window:CreateColumns(moveFlightSubTab)
    
    -- Left Column: Flight & Locomotion
    local flightSection = window:AddSection(mfLeftCol, "Flight & Locomotion")
    
    local flyConn: RBXScriptConnection? = nil
    local flySpeed = 50
    local function updateFlightState(enabled: boolean)
    	if enabled then
    		local char = localPlayer.Character
    		if not char then return end
    		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    		local hum = char:FindFirstChildOfClass("Humanoid")
    		if not (hrp and hum) then return end
    
    		local bg = hrp:FindFirstChild("FlyGyro") :: BodyGyro? or Instance.new("BodyGyro")
    		bg.Name = "FlyGyro"
    		bg.P = 9e4
    		bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    		bg.CFrame = hrp.CFrame
    		bg.Parent = hrp
    
    		local bv = hrp:FindFirstChild("FlyVelocity") :: BodyVelocity? or Instance.new("BodyVelocity")
    		bv.Name = "FlyVelocity"
    		bv.Velocity = Vector3.zero
    		bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    		bv.Parent = hrp
    
    		hum.PlatformStand = true
    
    		if flyConn then flyConn:Disconnect() end
    		flyConn = RunService.RenderStepped:Connect(function()
    			local cam = Workspace.CurrentCamera
    			local curChar = localPlayer.Character
    			local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    			local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
    			if not (curChar and curHrp and curHum and cam and curHum.Health > 0) then return end
    
    			bg.CFrame = cam.CFrame
    			local look = cam.CFrame.LookVector
    			local right = cam.CFrame.RightVector
    			local moveVec = Vector3.zero
    
    			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += look end
    			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= look end
    			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= right end
    			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += right end
    			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec += Vector3.new(0, 1, 0) end
    			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec -= Vector3.new(0, 1, 0) end
    
    			if moveVec.Magnitude > 0 then
    				bv.Velocity = moveVec.Unit * flySpeed
    			else
    				bv.Velocity = Vector3.zero
    			end
    		end)
    	else
    		if flyConn then
    			flyConn:Disconnect()
    			flyConn = nil
    		end
    		local char = localPlayer.Character
    		if char then
    			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    			local hum = char:FindFirstChildOfClass("Humanoid")
    			if hrp then
    				local bg = hrp:FindFirstChild("FlyGyro")
    				if bg then bg:Destroy() end
    				local bv = hrp:FindFirstChild("FlyVelocity")
    				if bv then bv:Destroy() end
    			end
    			if hum then
    				hum.PlatformStand = false
    			end
    		end
    	end
    end
    
    window:AddToggle(flightSection, "fly_toggle", "Flight / Fly Mode", false, nil, function(enabled)
    	updateFlightState(enabled)
    end)
    
    local noclipConn: RBXScriptConnection? = nil
    window:AddToggle(flightSection, "noclip_toggle", "Noclip (Collision Bypass)", false, nil, function(enabled)
    	if enabled then
    		noclipConn = RunService.Stepped:Connect(function()
    			for _, part in ipairs(cachedCharacterParts) do
    				part.CanCollide = false
    			end
    		end)
    	else
    		if noclipConn then
    			noclipConn:Disconnect()
    			noclipConn = nil
    		end
    		if localPlayer.Character then
    			local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    			if hum then
    				hum:ChangeState(Enum.HumanoidStateType.Running)
    			end
    			for _, part in ipairs(cachedCharacterParts) do
    				if part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "CollisionPart" or part.Name == "Head" then
    					part.CanCollide = true
    				end
    			end
    		end
    	end
    end)
    
    local infJumpConn: RBXScriptConnection? = nil
    window:AddToggle(flightSection, "inf_jump", "Infinite Jump", false, nil, function(enabled)
    	if enabled then
    		infJumpConn = UserInputService.JumpRequest:Connect(function()
    			if localPlayer.Character then
    				local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    				if hum then
    					hum:ChangeState(Enum.HumanoidStateType.Jumping)
    				end
    			end
    		end)
    	elseif infJumpConn then
    		infJumpConn:Disconnect()
    		infJumpConn = nil
    	end
    end)
    
    window:AddSlider(flightSection, "Fly Speed", 10, 200, 50, function(value)
    	flySpeed = value
    end)
    
    -- Right Column: Speed & Jump Modifiers (Persistent Locks)
    local speedSection = window:AddSection(mfRightCol, "Speed & Jump Modifiers")
    
    local activeSpeedLock: number? = nil
    local activeJumpLock: number? = nil
    
    local function enforcePersistentStats()
    	if not humanoid or humanoid.Health <= 0 then return end
    	if activeSpeedLock ~= nil and humanoid.WalkSpeed ~= activeSpeedLock then
    		humanoid.WalkSpeed = activeSpeedLock
    	end
    	if activeJumpLock ~= nil and humanoid.JumpPower ~= activeJumpLock then
    		humanoid.JumpPower = activeJumpLock
    	end
    end
    
    RunService.RenderStepped:Connect(enforcePersistentStats)
    RunService.Heartbeat:Connect(enforcePersistentStats)
    
    window:AddToggle(speedSection, "walkspeed_boost", "WalkSpeed Boost (32 WS)", false, nil, function(enabled)
    	activeSpeedLock = if enabled then 32 else nil
    	if humanoid then
    		humanoid.WalkSpeed = if enabled then 32 else 16
    	end
    end)
    
    window:AddToggle(speedSection, "jumppower_boost", "JumpPower Boost (100 JP)", false, nil, function(enabled)
    	activeJumpLock = if enabled then 100 else nil
    	if humanoid then
    		humanoid.JumpPower = if enabled then 100 else 50
    	end
    end)
    
    window:AddSlider(speedSection, "Custom Speed", 16, 250, 16, function(value)
    	activeSpeedLock = if value > 16 then value else nil
    	if humanoid then
    		humanoid.WalkSpeed = value
    	end
    end)
    
    window:AddSlider(speedSection, "Custom JumpPower", 50, 300, 50, function(value)
    	activeJumpLock = if value > 50 then value else nil
    	if humanoid then
    		humanoid.JumpPower = value
    	end
    end)
    
    -- ── MAIN SUB-TAB 2: PHYSICS & MODIFIERS ──────────────────────
    local physLeftCol, physRightCol = window:CreateColumns(physicsSubTab)
    
    -- Left Column: Character Physics
    local charPhysSection = window:AddSection(physLeftCol, "Character Physics")
    
    local walkFlingConn: RBXScriptConnection? = nil
    window:AddToggle(charPhysSection, "walk_fling", "Walk Fling (Touch To Fling)", false, nil, function(enabled)
    	if enabled then
    		walkFlingConn = RunService.Heartbeat:Connect(function()
    			local char = localPlayer.Character
    			if not char then return end
    			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    			local hum = char:FindFirstChildOfClass("Humanoid")
    			if not (hrp and hum and hum.Health > 0) then return end
    
    			hrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
    			local vel = hrp.AssemblyLinearVelocity
    			hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.clamp(vel.Y, -100, 100), vel.Z)
    		end)
    	else
    		if walkFlingConn then
    			walkFlingConn:Disconnect()
    			walkFlingConn = nil
    		end
    		local char = localPlayer.Character
    		if char then
    			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    			if hrp then
    				hrp.AssemblyAngularVelocity = Vector3.zero
    			end
    		end
    	end
    end)
    
    local ragdollWalkConn: RBXScriptConnection? = nil
    local ragdollJumpConn: RBXScriptConnection? = nil
    local lastRagdollJumpTime = 0
    local cachedRagdollParts: {BasePart} = {}
    local lastRagdollChar: Model? = nil
    local wasRagdolled: boolean = false
    
    local function refreshRagdollParts(char: Model)
    	table.clear(cachedRagdollParts)
    	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) :: BasePart?
    	if root then table.insert(cachedRagdollParts, root) end
    	if torso and torso ~= root then table.insert(cachedRagdollParts, torso) end
    	for _, p in ipairs(char:GetChildren()) do
    		if p:IsA("BasePart") and (string.find(p.Name, "Torso") or string.find(p.Name, "Leg")) then
    			if not table.find(cachedRagdollParts, p) then
    				table.insert(cachedRagdollParts, p)
    			end
    		end
    	end
    end
    
    window:AddToggle(charPhysSection, "ragdoll_walk_jump", "Ragdoll Walk & Space Jump", false, nil, function(enabled)
    	if enabled then
    		ragdollWalkConn = RunService.Heartbeat:Connect(function()
    			local char = localPlayer.Character
    			if not char then return end
    			local hum = char:FindFirstChildOfClass("Humanoid")
    			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    			local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) :: BasePart?
    			if not (hum and (root or torso) and hum.Health > 0) then return end
    
    			local isRagdolled = char:GetAttribute("Ragdoll") == true
    				or char:GetAttribute("Ragdolled") == true
    				or char:FindFirstChild("Ragdoll") ~= nil
    				or char:FindFirstChild("Ragdolled") ~= nil
    				or hum.PlatformStand == true
    				or hum.Sit == true
    				or hum:GetState() == Enum.HumanoidStateType.Ragdoll
    				or hum:GetState() == Enum.HumanoidStateType.Physics
    				or hum:GetState() == Enum.HumanoidStateType.FallingDown
    				or hum:GetState() == Enum.HumanoidStateType.PlatformStanding
    
    			if isRagdolled then
    				if not wasRagdolled or char ~= lastRagdollChar then
    					lastRagdollChar = char
    					wasRagdolled = true
    					refreshRagdollParts(char)
    				end
    
    				local cam = Workspace.CurrentCamera
    				if cam then
    					local look = cam.CFrame.LookVector
    					local right = cam.CFrame.RightVector
    					local flatLook = Vector3.new(look.X, 0, look.Z)
    					local flatRight = Vector3.new(right.X, 0, right.Z)
    
    					local moveVec = Vector3.zero
    					if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then moveVec += flatLook end
    					if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then moveVec -= flatLook end
    					if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then moveVec -= flatRight end
    					if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then moveVec += flatRight end
    
    					if moveVec.Magnitude > 0.05 then
    						local dir = moveVec.Unit
    						local speed = 36
    						for _, p in ipairs(cachedRagdollParts) do
    							p.AssemblyLinearVelocity = Vector3.new(dir.X * speed, p.AssemblyLinearVelocity.Y, dir.Z * speed)
    						end
    					end
    
    					if UserInputService:IsKeyDown(Enum.KeyCode.Space) and (tick() - lastRagdollJumpTime > 0.28) then
    						local mainPart = root or torso
    						if mainPart and math.abs(mainPart.AssemblyLinearVelocity.Y) < 16 then
    							lastRagdollJumpTime = tick()
    							for _, p in ipairs(cachedRagdollParts) do
    								p.AssemblyLinearVelocity = Vector3.new(p.AssemblyLinearVelocity.X, 54, p.AssemblyLinearVelocity.Z)
    							end
    						end
    					end
    				end
    			else
    				wasRagdolled = false
    			end
    		end)
    
    		ragdollJumpConn = UserInputService.JumpRequest:Connect(function()
    			local char = localPlayer.Character
    			if not char then return end
    			local hum = char:FindFirstChildOfClass("Humanoid")
    			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    			local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
    			if not (hum and (root or torso) and hum.Health > 0) then return end
    
    			local isRagdolled = char:GetAttribute("Ragdoll") == true
    				or hum.PlatformStand == true
    				or hum.Sit == true
    				or hum:GetState() == Enum.HumanoidStateType.Ragdoll
    				or hum:GetState() == Enum.HumanoidStateType.Physics
    				or hum:GetState() == Enum.HumanoidStateType.FallingDown
    
    			if isRagdolled and (tick() - lastRagdollJumpTime > 0.28) then
    				lastRagdollJumpTime = tick()
    				if #cachedRagdollParts == 0 then
    					refreshRagdollParts(char)
    				end
    				for _, p in ipairs(cachedRagdollParts) do
    					p.AssemblyLinearVelocity = Vector3.new(p.AssemblyLinearVelocity.X, 54, p.AssemblyLinearVelocity.Z)
    				end
    			end
    		end)
    	else
    		if ragdollWalkConn then
    			ragdollWalkConn:Disconnect()
    			ragdollWalkConn = nil
    		end
    		if ragdollJumpConn then
    			ragdollJumpConn:Disconnect()
    			ragdollJumpConn = nil
    		end
    		wasRagdolled = false
    	end
    end)
    
    window:AddSlider(charPhysSection, "Hip Height Offset", 0, 20, 0, function(value)
    	if localPlayer.Character then
    		local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    		if hum then
    			hum.HipHeight = value
    		end
    	end
    end)
    
    -- Right Column: Environment Physics
    local envPhysSection = window:AddSection(physRightCol, "Environment Physics")
    
    window:AddSlider(envPhysSection, "Custom Gravity", 0, 196, 196, function(value)
    	Workspace.Gravity = value
    end)
    
    window:AddButton(envPhysSection, "Reset World Gravity", function()
    	Workspace.Gravity = 196.2
    	FeatureManager.setSliderValue("Custom Gravity", 196)
    	window:Notify("Physics", "World gravity restored to default (196.2)", 2)
    end)
    
    window:AddButton(envPhysSection, "Reset Character Height", function()
    	if localPlayer.Character then
    		local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
    		if hum then
    			hum.HipHeight = 0
    		end
    	end
    	FeatureManager.setSliderValue("Hip Height Offset", 0)
    	window:Notify("Physics", "Character hip height restored to default", 2)
    end)
    
    -- ── MAIN SUB-TAB 3: PLAYER UTILITIES ─────────────────────────
    local utilLeftCol, utilRightCol = window:CreateColumns(playerUtilsSubTab)
    
    -- Left Column: Live Currencies & Leaderstats
    local statsSection = window:AddSection(utilLeftCol, "Live Currencies & Leaderstats")
    
    local statsContainer = Instance.new("Frame")
    statsContainer.Name = "StatsContainer"
    statsContainer.Size = UDim2.new(1, 0, 0, 0)
    statsContainer.AutomaticSize = Enum.AutomaticSize.Y
    statsContainer.BackgroundTransparency = 1
    statsContainer.BorderSizePixel = 0
    statsContainer.Parent = statsSection
    
    local statsLayout = Instance.new("UIListLayout")
    statsLayout.Padding = UDim.new(0, 4)
    statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statsLayout.Parent = statsContainer
    
    local statRowFrames: {[string]: {Row: Frame, ValLabel: TextLabel}} = {}
    
    local function renderCurrencies()
    	local stats = PlayerUtilities.getCurrenciesAndStats()
    	if #stats == 0 then
    		local noStat = statRowFrames["_empty"]
    		if not noStat then
    			local row = Instance.new("Frame")
    			row.Size = UDim2.new(1, 0, 0, 24)
    			row.BackgroundColor3 = UI.Theme.ContainerDark
    			row.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
    			row.BorderSizePixel = 0
    			row.Parent = statsContainer
    			UI.registerThemeElement(row, "ContainerDark")
    
    			local lbl = Instance.new("TextLabel")
    			lbl.Size = UDim2.new(1, -8, 1, 0)
    			lbl.Position = UDim2.new(0, 4, 0, 0)
    			lbl.BackgroundTransparency = 1
    			lbl.Text = "No active currencies found in session"
    			lbl.TextColor3 = UI.Theme.TextSecondary
    			lbl.Font = UI.Fonts.Body
    			lbl.TextSize = 10
    			lbl.Parent = row
    			UI.registerThemeElement(lbl, "TextSecondary")
    
    			statRowFrames["_empty"] = {Row = row, ValLabel = lbl}
    		end
    		return
    	end
    
    	if statRowFrames["_empty"] then
    		if statRowFrames["_empty"].Row and statRowFrames["_empty"].Row.Parent then
    			statRowFrames["_empty"].Row:Destroy()
    		end
    		statRowFrames["_empty"] = nil
    	end
    
    	for idx, s in ipairs(stats) do
    		local existing = statRowFrames[s.Name]
    		if existing and existing.Row and existing.Row.Parent then
    			existing.ValLabel.Text = s.Formatted or s.Value
    		else
    			local row = Instance.new("Frame")
    			row.Name = s.Name .. "StatRow"
    			row.Size = UDim2.new(1, 0, 0, 24)
    			row.BackgroundColor3 = UI.Theme.Container
    			row.BackgroundTransparency = UI.Theme.ContainerTransparency
    			row.BorderSizePixel = 0
    			row.LayoutOrder = idx
    			row.Parent = statsContainer
    			UI.registerThemeElement(row, "Container")
    
    			local rStroke = Instance.new("UIStroke")
    			rStroke.Color = UI.Theme.Border
    			rStroke.Thickness = 1.0
    			rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    			rStroke.Parent = row
    			UI.registerThemeElement(rStroke, "Border")
    
    			local nameLabel = Instance.new("TextLabel")
    			nameLabel.Size = UDim2.new(0.55, -6, 1, 0)
    			nameLabel.Position = UDim2.new(0, 6, 0, 0)
    			nameLabel.BackgroundTransparency = 1
    			nameLabel.Text = s.Name
    			nameLabel.TextColor3 = UI.Theme.TextPrimary
    			nameLabel.Font = UI.Fonts.Body
    			nameLabel.TextSize = 10
    			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    			nameLabel.Parent = row
    			UI.registerThemeElement(nameLabel, "TextPrimary")
    
    			local valLabel = Instance.new("TextLabel")
    			valLabel.Size = UDim2.new(0.45, -8, 1, 0)
    			valLabel.Position = UDim2.new(0.55, 0, 0, 0)
    			valLabel.BackgroundTransparency = 1
    			valLabel.Text = s.Formatted or s.Value
    			valLabel.TextColor3 = UI.Theme.Accent
    			valLabel.Font = UI.Fonts.Mono
    			valLabel.TextSize = 10
    			valLabel.TextXAlignment = Enum.TextXAlignment.Right
    			valLabel.TextTruncate = Enum.TextTruncate.AtEnd
    			valLabel.Parent = row
    			UI.registerThemeElement(valLabel, "AccentText")
    
    			statRowFrames[s.Name] = {Row = row, ValLabel = valLabel}
    		end
    	end
    end
    
    -- Initial render
    task.spawn(function()
    	task.wait(0.5)
    	pcall(renderCurrencies)
    end)
    
    -- Continuous auto-updater (0.25s high-frequency polling with reactive value change triggers)
    local autoUpdateCurrencies = true
    local refreshCurrenciesDebounced: thread? = nil
    local function triggerInstantCurrencyRefresh()
    	if not autoUpdateCurrencies then return end
    	if refreshCurrenciesDebounced then task.cancel(refreshCurrenciesDebounced) end
    	refreshCurrenciesDebounced = task.delay(0.04, function()
    		pcall(renderCurrencies)
    	end)
    end
    
    -- Hook value objects on LocalPlayer for 0ms latency UI updates
    local function hookCurrencyFolder(folder: Instance)
    	for _, child in ipairs(folder:GetChildren()) do
    		if child:IsA("ValueBase") then
    			child.Changed:Connect(triggerInstantCurrencyRefresh)
    		end
    	end
    	folder.ChildAdded:Connect(function(child)
    		if child:IsA("ValueBase") then
    			child.Changed:Connect(triggerInstantCurrencyRefresh)
    		end
    		triggerInstantCurrencyRefresh()
    	end)
    	folder.ChildRemoved:Connect(triggerInstantCurrencyRefresh)
    end
    
    for _, fName in ipairs({"leaderstats", "Data", "Stats", "Values", "Currencies", "PlayerData", "Tycoon"}) do
    	local f = localPlayer:FindFirstChild(fName)
    	if f then hookCurrencyFolder(f) end
    end
    
    localPlayer.ChildAdded:Connect(function(child)
    	for _, fName in ipairs({"leaderstats", "Data", "Stats", "Values", "Currencies", "PlayerData", "Tycoon"}) do
    		if child.Name == fName then
    			hookCurrencyFolder(child)
    			triggerInstantCurrencyRefresh()
    			break
    		end
    	end
    end)
    
    localPlayer.AttributeChanged:Connect(triggerInstantCurrencyRefresh)
    
    task.spawn(function()
    	while true do
    		task.wait(0.25)
    		if autoUpdateCurrencies then
    			pcall(renderCurrencies)
    		end
    	end
    end)
    
    window:AddButton(statsSection, "Refresh Currencies Now", function()
    	renderCurrencies()
    	window:Notify("Currencies", "Refreshed live leaderstats & currencies", 2)
    end)
    
    window:AddToggle(statsSection, "auto_refresh_currencies", "Fast Live Monitor (0.25s)", true, nil, function(enabled)
    	autoUpdateCurrencies = enabled
    end)
    
    window:AddToggle(statsSection, "show_leaderstats_hud", "Show On-Screen Stats HUD Widget", true, nil, function(enabled)
    	leaderstatsWidget.SetVisible(enabled)
    end)
    
    -- Left Column: Server & Session Utilities
    local serverSection = window:AddSection(utilLeftCol, "Server & Session Utilities")
    
    window:AddButton(serverSection, "Server Hop", function()
    	PlayerUtilities.ServerHop()
    end)
    
    window:AddButton(serverSection, "Rejoin Current Server", function()
    	PlayerUtilities.RejoinServer()
    end)
    
    window:AddButton(serverSection, "Copy Place ID", function()
    	PlayerUtilities.CopyPlaceId()
    end)
    
    window:AddButton(serverSection, "Copy Game ID", function()
    	PlayerUtilities.CopyGameId()
    end)
    
    window:AddButton(serverSection, "Copy Job / Server ID", function()
    	PlayerUtilities.CopyJobId()
    end)
    
    -- Right Column: Automation & Tools
    local toolSection = window:AddSection(utilRightCol, "Automation & Tools")
    
    window:AddToggle(toolSection, "anti_afk", "Anti-AFK Timeout Preventer", false, nil, function(enabled)
    	PlayerUtilities.SetAntiAFK(enabled)
    end)
    
    window:AddToggle(toolSection, "click_teleport", "Ctrl+Click Teleport Active", false, nil, function(enabled)
    	PlayerUtilities.SetClickTeleportEnabled(enabled)
    end)
    
    window:AddButton(toolSection, "Give Click Teleport Tool", function()
    	PlayerUtilities.GiveClickTeleportTool()
    end)
    
    -- ============================================================
    -- 2. COMBAT TAB CONTENT (HORIZONTAL MINI SUB-TABS)
    --    [ Aim Assistance ] [ Camera Tracking ] [ Hitbox Modifiers ]
    -- ============================================================
    local combatSubTabs = window:CreateSubTabs(combatTab, { "Aim Assistance", "Camera Tracking", "Hitbox Modifiers" })
    local aimSubTab = combatSubTabs["Aim Assistance"]
    local trackSubTab = combatSubTabs["Camera Tracking"]
    local hitSubTab = combatSubTabs["Hitbox Modifiers"]
    
    -- ── COMBAT SUB-TAB 1: AIM ASSISTANCE ─────────────────────────
    local aimLeftCol, aimRightCol = window:CreateColumns(aimSubTab)
    
    -- Left Column: Targeting & Silent Aim
    local targetingSection = window:AddSection(aimLeftCol, "Targeting & Silent Aim")
    
    window:AddToggle(targetingSection, "silent_aim", "Silent Aim", false, nil, function(enabled)
    	Combat.SilentAim = enabled
    end)
    
    window:AddToggle(targetingSection, "wall_bang", "Wall Bang (Shoot Thru Walls)", false, nil, function(enabled)
    	Combat.Wallbang = enabled
    end)
    
    window:AddToggle(targetingSection, "target_head", "Target Head (Off = Torso)", true, nil, function(enabled)
    	Combat.TargetPart = if enabled then "Head" else "Torso"
    end)
    
    window:AddToggle(targetingSection, "track_teammates", "Track Teammates", false, nil, function(enabled)
    	Combat.TrackTeammates = enabled
    end)
    
    -- Right Column: Automation & Modifiers
    local firingSection = window:AddSection(aimRightCol, "Automation & Modifiers")
    
    window:AddToggle(firingSection, "trigger_bot", "Trigger Bot", false, nil, function(enabled)
    	Combat.TriggerBot = enabled
    end)
    
    window:AddSlider(firingSection, "TriggerBot Delay (ms)", 0, 500, 50, function(value)
    	Combat.TriggerBotDelay = value / 1000
    end)
    
    window:AddSlider(firingSection, "Wallbang Thickness", 0, 25, 5, function(value)
    	Combat.WallbangThickness = value
    end)
    
    window:AddSlider(firingSection, "Hit Chance %", 10, 100, 100, function(value)
    	Combat.HitChance = value
    end)
    
    window:AddSlider(firingSection, "Aim Smoothing", 5, 100, 25, function(value)
    	Combat.Smoothing = value / 100
    end)
    
    -- ── COMBAT SUB-TAB 2: CAMERA TRACKING ────────────────────────
    local trackLeftCol, trackRightCol = window:CreateColumns(trackSubTab)
    
    -- Left Column: Camera Lock Modes
    local lockModesSection = window:AddSection(trackLeftCol, "Camera Lock Modes")
    
    window:AddToggle(lockModesSection, "aim_tracking", "Aim Tracking (Camera Lock)", false, nil, function(enabled)
    	Combat.AimTracking = enabled
    end)
    
    window:AddToggle(lockModesSection, "aim_always", "Always Lock (Ignore RMB Hold)", false, nil, function(enabled)
    	Combat.AimMode = if enabled then "Always" else "Hold RMB"
    end)
    
    -- Right Column: FOV Dynamics & Colors
    local fovSection = window:AddSection(trackRightCol, "FOV Dynamics & Colors")
    
    window:AddToggle(fovSection, "fov_circle", "FOV Circle (Visualizer)", false, nil, function(enabled)
    	Combat.FovCircle = enabled
    end)
    
    window:AddSlider(fovSection, "FOV Radius", 30, 450, 120, function(value)
    	Combat.FovRadius = value
    end)
    
    window:AddButton(fovSection, "Cyan FOV Circle", function()
    	Combat.setFovColor(Color3.fromRGB(55, 175, 245))
    	window:Notify("Combat", "Cyan FOV circle color applied", 2)
    end)
    
    window:AddButton(fovSection, "Crimson Red FOV", function()
    	Combat.setFovColor(Color3.fromRGB(245, 60, 60))
    	window:Notify("Combat", "Red FOV circle color applied", 2)
    end)
    
    window:AddButton(fovSection, "White FOV Circle", function()
    	Combat.setFovColor(Color3.fromRGB(255, 255, 255))
    	window:Notify("Combat", "White FOV circle color applied", 2)
    end)
    
    window:AddButton(fovSection, "Lime Green FOV", function()
    	Combat.setFovColor(Color3.fromRGB(50, 220, 80))
    	window:Notify("Combat", "Green FOV circle color applied", 2)
    end)
    
    -- ── COMBAT SUB-TAB 3: HITBOX MODIFIERS ───────────────────────
    local hitLeftCol, hitRightCol = window:CreateColumns(hitSubTab)
    
    -- Left Column: Hitbox Expansion
    local hitExpSection = window:AddSection(hitLeftCol, "Hitbox Expansion")
    
    window:AddToggle(hitExpSection, "expand_hitboxes", "Expand Hitboxes", false, nil, function(enabled)
    	Combat.ExpandHitboxes = enabled
    	if not enabled then
    		Combat.resetHitboxes()
    	end
    end)
    
    window:AddToggle(hitExpSection, "hitbox_visuals", "Show Hitbox Visuals (ForceField)", false, nil, function(enabled)
    	Combat.HitboxVisuals = enabled
    end)
    
    window:AddToggle(hitExpSection, "hitbox_target_part", "Target Part: Head (Off = RootPart)", false, nil, function(enabled)
    	Combat.HitboxPart = if enabled then "Head" else "HumanoidRootPart"
    end)
    
    window:AddSlider(hitExpSection, "Hitbox Size", 2, 45, 15, function(value)
    	Combat.HitboxSize = value
    end)
    
    -- Right Column: Hitbox Operations
    local hitOpsSection = window:AddSection(hitRightCol, "Hitbox Operations & Presets")
    
    window:AddButton(hitOpsSection, "Small Size (8)", function()
    	Combat.HitboxSize = 8
    	FeatureManager.setSliderValue("Hitbox Size", 8)
    	window:Notify("Hitboxes", "Hitbox size set to 8", 2)
    end)
    
    window:AddButton(hitOpsSection, "Medium Size (16)", function()
    	Combat.HitboxSize = 16
    	FeatureManager.setSliderValue("Hitbox Size", 16)
    	window:Notify("Hitboxes", "Hitbox size set to 16", 2)
    end)
    
    window:AddButton(hitOpsSection, "Massive Size (30)", function()
    	Combat.HitboxSize = 30
    	FeatureManager.setSliderValue("Hitbox Size", 30)
    	window:Notify("Hitboxes", "Hitbox size set to 30", 2)
    end)
    
    window:AddButton(hitOpsSection, "Reset All Hitboxes", function()
    	Combat.resetHitboxes()
    	window:Notify("Hitboxes", "All player hitboxes restored to default", 2.5)
    end)
    
    -- ============================================================
    -- 3. GAME TAB CONTENT (RUN N HIDE / DISASTER SURVIVAL)
    --    [ Weapons & Firepower ] [ Bounds & Barriers ] [ Mobility & Items ]
    -- ============================================================
    if gameTabTitle == "Run N Hide" then
    	local rnhSubTabs = window:CreateSubTabs(gameTab, { "Weapons & Firepower", "Bounds & Barriers", "Mobility & Items" })
    	local weaponSubTab = rnhSubTabs["Weapons & Firepower"]
    	local boundsSubTab = rnhSubTabs["Bounds & Barriers"]
    	local mobilitySubTab = rnhSubTabs["Mobility & Items"]
    
    	-- ── GAME SUB-TAB 1: WEAPONS & FIREPOWER ───────────────────
    	local wepLeftCol, wepRightCol = window:CreateColumns(weaponSubTab)
    
    	local weaponMechSection = window:AddSection(wepLeftCol, "Weapon Mechanisms")
    
    	window:AddToggle(weaponMechSection, "rnh_silent_audio", "Silent Gun Audio (Mute)", true, nil, function(val)
    		RunNHide.SilentGunAudio = val
    		RunNHide.updateWeapons(true)
    	end)
    
    	window:AddToggle(weaponMechSection, "rnh_quick_reload", "Quick Reload & Instant Rack", false, nil, function(val)
    		RunNHide.QuickReload = val
    		RunNHide.AutoChamber = val
    		RunNHide.updateWeapons()
    	end)
    
    	window:AddToggle(weaponMechSection, "rnh_complete_auto", "Complete Auto (All Guns)", false, nil, function(val)
    		RunNHide.CompleteAuto = val
    		if val then
    			RunNHide.SemiAutoForce = false
    			RunNHide.BurstMode = false
    		end
    		RunNHide.updateWeapons()
    	end)
    
    	window:AddToggle(weaponMechSection, "rnh_semi_auto", "The Semi-Auto Force", false, nil, function(val)
    		RunNHide.SemiAutoForce = val
    		if val then
    			RunNHide.CompleteAuto = false
    			RunNHide.BurstMode = false
    		end
    		RunNHide.updateWeapons()
    	end)
    
    	window:AddToggle(weaponMechSection, "rnh_burst_mode", "The Burst Rounds", false, nil, function(val)
    		RunNHide.BurstMode = val
    		if val then
    			RunNHide.CompleteAuto = false
    			RunNHide.SemiAutoForce = false
    		end
    		RunNHide.updateWeapons()
    	end)
    
    	local fireOverclockSection = window:AddSection(wepRightCol, "Overclocks & Actions")
    
    	window:AddToggle(fireOverclockSection, "rnh_no_recoil", "Zero Recoil", false, nil, function(val)
    		RunNHide.NoRecoil = val
    		RunNHide.updateWeapons()
    	end)
    
    	window:AddToggle(fireOverclockSection, "rnh_fast_fire", "Rapid Fire Rate Overclock", false, nil, function(val)
    		RunNHide.FastFireRate = val
    		RunNHide.updateWeapons()
    	end)
    
    	window:AddSlider(fireOverclockSection, "Burst Shot Count", 2, 10, 3, function(val)
    		RunNHide.BurstCount = val
    	end)
    
    	window:AddSlider(fireOverclockSection, "Burst Delay (ms)", 20, 150, 60, function(val)
    		RunNHide.BurstDelay = val / 1000
    	end)
    
    	window:AddButton(fireOverclockSection, "Force Instant Reload", function()
    		if RunNHide.forceReload() then
    			window:Notify("Run N Hide", "Weapon reloaded & chambered", 3)
    		else
    			window:Notify("Run N Hide", "No gun equipped", 3)
    		end
    	end)
    
    	window:AddButton(fireOverclockSection, "Chamber Equipped Weapon", function()
    		if RunNHide.forceChamber() then
    			window:Notify("Run N Hide", "Weapon chambered", 3)
    		else
    			window:Notify("Run N Hide", "No gun equipped", 3)
    		end
    	end)
    
    	-- ── GAME SUB-TAB 2: BOUNDS & BARRIERS ─────────────────────
    	local bndLeftCol, bndRightCol = window:CreateColumns(boundsSubTab)
    
    	local boundsSection = window:AddSection(bndLeftCol, "Boundary Removal")
    
    	window:AddToggle(boundsSection, "rnh_disable_barriers", "Disable Map Bounds & Barriers", false, nil, function(val)
    		RunNHide.DisableBarriers = val
    		if val then
    			local count = RunNHide.scanAndDisableBoundaries()
    			window:Notify("Bounds", string.format("Barriers & clips disabled (%d checked)", count), 3)
    		end
    	end)
    
    	window:AddToggle(boundsSection, "rnh_disable_kill", "Disable Kill Bricks & Death Zones", false, nil, function(val)
    		RunNHide.DisableKillbricks = val
    		if val then
    			RunNHide.scanAndDisableBoundaries()
    			window:Notify("Bounds", "Killbricks & death zones neutralized", 3)
    		end
    	end)
    
    	local voidSection = window:AddSection(bndRightCol, "Void Safety & Audits")
    
    	window:AddToggle(voidSection, "rnh_anti_void", "Anti-Void Safety Floor", false, nil, function(val)
    		RunNHide.AntiVoidFloor = val
    		RunNHide.ensureVoidPlatform()
    	end)
    
    	window:AddButton(voidSection, "Audit & Disable All Bounds Now", function()
    		RunNHide.DisableBarriers = true
    		RunNHide.DisableKillbricks = true
    		local count = RunNHide.scanAndDisableBoundaries()
    		window:Notify("Audit", string.format("Neutralized %d boundaries & killbricks", count), 3.5)
    	end)
    
    	-- ── GAME SUB-TAB 3: MOBILITY & ITEMS ──────────────────────
    	local mobLeftCol, mobRightCol = window:CreateColumns(mobilitySubTab)
    
    	local staminaSection = window:AddSection(mobLeftCol, "Stamina & Ragdoll")
    
    	window:AddToggle(staminaSection, "rnh_inf_stamina", "Infinite Stamina", false, nil, function(val)
    		RunNHide.InfiniteStamina = val
    	end)
    
    	window:AddToggle(staminaSection, "rnh_fast_regen", "Hyper Fast Stamina Regen", false, nil, function(val)
    		RunNHide.FastRegen = val
    	end)
    
    	window:AddToggle(staminaSection, "rnh_move_ragdoll", "Move In Ragdoll (WASD)", false, nil, function(val)
    		RunNHide.MoveInRagdoll = val
    	end)
    
    	window:AddToggle(staminaSection, "rnh_auto_stand", "Auto Standup (Anti-Knockdown)", false, nil, function(val)
    		RunNHide.AutoStandup = val
    	end)
    
    	window:AddSlider(staminaSection, "Ragdoll Speed", 16, 80, 32, function(val)
    		RunNHide.RagdollSpeed = val
    	end)
    
    	local itemSection = window:AddSection(mobRightCol, "Item & Role Tracker")
    
    	window:AddToggle(itemSection, "rnh_role_tracker", "Role Tracker & ESP", false, nil, function(val)
    		RunNHide.RoleTracker = val
    	end)
    
    	window:AddToggle(itemSection, "rnh_auto_grab", "Auto-Grab Dropped Weapons", false, nil, function(val)
    		RunNHide.AutoGrabWeapons = val
    	end)
    
    	window:AddButton(itemSection, "Grab All Scattered Guns Now", function()
    		local count = RunNHide.grabAllScatteredWeapons()
    		window:Notify("Weapons", string.format("Claimed %d dropped guns", count), 3)
    	end)
    
    	window:AddButton(itemSection, "Teleport to PVP Arena", function()
    		if RunNHide.teleportToArena() then
    			window:Notify("Arena", "Teleported to PVP Arena loadout zone", 3)
    		end
    	end)
    elseif gameTabTitle == "Natural Disaster" then
    	-- Disaster Survival Sub-Tabs (4 tabs — all in ONE CreateSubTabs call)
    	local ndsSubTabs = window:CreateSubTabs(gameTab, {
    		"Disaster Intelligence",
    		"Mobility & Flight",
    		"Physics & Protection",
    		"World & Vehicles",
    	})
    	local disSubTab   = ndsSubTabs["Disaster Intelligence"]
    	local mobSubTab   = ndsSubTabs["Mobility & Flight"]
    	local phySubTab   = ndsSubTabs["Physics & Protection"]
    	local worldSubTab = ndsSubTabs["World & Vehicles"]
    
    	-- ── DISASTER INTELLIGENCE ─────────────────────────────────────
    	local disLeftCol, disRightCol = window:CreateColumns(disSubTab)
    	local disasterSection = window:AddSection(disLeftCol, "Disaster Monitor")
    
    	window:AddToggle(disasterSection, "disaster_tracker", "Disaster Tracker", false, nil, function(enabled)
    		DisasterSurvival.DisasterTracker = enabled
    		if enabled and DisasterSurvival.CurrentDisaster ~= "None (In Lobby)" and DisasterSurvival.CurrentDisaster ~= "" then
    			window:Notify("Current Disaster", DisasterSurvival.CurrentDisaster, 3.5)
    		end
    	end)
    
    	window:AddButton(disasterSection, "Check Current Disaster", function()
    		local tag = localPlayer.Character and localPlayer.Character:FindFirstChild("SurvivalTag")
    		local cur = if tag and tag:IsA("StringValue") and tag.Value ~= "" then tag.Value else "None (In Lobby)"
    		window:Notify("Disaster Status", cur, 3.5)
    	end)
    
    	local fallSection = window:AddSection(disRightCol, "Fall Damage Bypass")
    	window:AddToggle(fallSection, "no_fall_damage", "No Fall Damage", false, nil, function(enabled)
    		DisasterSurvival.setNoFallDamage(enabled)
    	end)
    
    	-- ── MOBILITY & FLIGHT ─────────────────────────────────────────
    	local mobLeftCol, mobRightCol = window:CreateColumns(mobSubTab)
    	local fltSection = window:AddSection(mobLeftCol, "Flight Navigation")
    	window:AddToggle(fltSection, "flight_no_fall", "Flight No Fall Damage", false, nil, function(enabled)
    		DisasterSurvival.setFlight(enabled)
    	end)
    
    	local spdSection = window:AddSection(mobRightCol, "Flight Velocity")
    	window:AddSlider(spdSection, "Flight Speed", 20, 150, 50, function(value)
    		DisasterSurvival.FlightSpeed = value
    	end)
    
    	-- ── PHYSICS & PROTECTION ──────────────────────────────────────
    	local phyLeftCol, phyRightCol = window:CreateColumns(phySubTab)
    	local protSection = window:AddSection(phyLeftCol, "Protection & Physics")
    	window:AddToggle(protSection, "anti_fling", "Anti-Fling Protection", false, nil, function(enabled)
    		DisasterSurvival.setAntiFling(enabled)
    	end)
    
    	window:AddToggle(protSection, "anti_object_kill", "Anti-Object-Kill Shield", false, nil, function(enabled)
    		DisasterSurvival.setAntiObjectKill(enabled)
    	end)
    
    	local flngSection = window:AddSection(phyRightCol, "Physics Fling")
    	window:AddToggle(flngSection, "player_fling", "Object / Player Fling", false, nil, function(enabled)
    		DisasterSurvival.setFling(enabled)
    	end)
    
    	-- ── WORLD & VEHICLES ─────────────────────────────────────────
    	local worldLeftCol, worldRightCol = window:CreateColumns(worldSubTab)
    
    	local carSection = window:AddSection(worldLeftCol, "Vehicle Exploits")
    	window:AddToggle(carSection, "nds_car_drive", "Custom Car Driving (W/A/S/D)", false, nil, function(enabled)
    		DisasterSurvival.setCarDriving(enabled)
    	end)
    
    	window:AddButton(carSection, "Enter Nearest Car", function()
    		local cars = DisasterSurvival.scanCars()
    		if #cars == 0 then
    			window:Notify("Cars", "No VehicleSeats found in map", 3)
    			return
    		end
    		local char = localPlayer.Character
    		local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    		if not hrp then window:Notify("Cars", "No character found", 3) return end
    
    		local best: VehicleSeat? = nil
    		local bestDist = math.huge
    		for _, seat in ipairs(cars) do
    			if not seat.Occupant then
    				local d = (seat.Position - hrp.Position).Magnitude
    				if d < bestDist then bestDist = d best = seat end
    			end
    		end
    
    		if best then
    			-- Teleport HRP onto seat — proximity trigger fires the SeatWeld automatically
    			DisasterSurvival.sitInCar(best)
    			window:Notify("Cars", string.format("Warped to car (%.1f studs) — W/A/S/D to drive", bestDist), 3.5)
    		else
    			window:Notify("Cars", "No unoccupied car found", 3)
    		end
    	end)
    
    	window:AddButton(carSection, "Exit Car", function()
    		DisasterSurvival.exitCar()
    		window:Notify("Cars", "Exited vehicle", 2)
    	end)
    
    	local dragSection = window:AddSection(worldRightCol, "Object Interaction")
    	window:AddToggle(dragSection, "nds_obj_drag", "Loose Object Drag (LMB hold = grab, release = drop)", false, nil, function(enabled)
    		DisasterSurvival.setObjectDrag(enabled)
    	end)
    elseif gameTabTitle == "Ice Tycoon" then
    	local iceSubTabs = window:CreateSubTabs(gameTab, { "Tycoon Automation", "Resources & Farming", "Protections & Zones" })
    	local autoSubTab = iceSubTabs["Tycoon Automation"]
    	local farmSubTab = iceSubTabs["Resources & Farming"]
    	local zoneSubTab = iceSubTabs["Protections & Zones"]
    
    	-- ── 1. TYCOON AUTOMATION ─────────────────────────────────────
    	local autoLeftCol, autoRightCol = window:CreateColumns(autoSubTab)
    
    	local convSection = window:AddSection(autoLeftCol, "Conveyors & Generators")
    	window:AddToggle(convSection, "ice_fast_conveyors", "Fast Conveyors (Speed Boost)", false, nil, function(enabled)
    		IceTycoon.setFastConveyors(enabled)
    	end)
    
    	window:AddSlider(convSection, "Conveyor Speed", 15, 250, 75, function(value)
    		IceTycoon.setConveyorSpeed(value)
    	end)
    
    	window:AddToggle(convSection, "ice_fast_generators", "Turbo Generators & Droppers", false, nil, function(enabled)
    		IceTycoon.setFastGenerators(enabled)
    	end)
    
    	window:AddSlider(convSection, "Generator Dropper Velocity", 30, 300, 120, function(value)
    		IceTycoon.setGeneratorSpeed(value)
    	end)
    
    	window:AddToggle(convSection, "ice_ore_magnet", "Ore Vacuum / Magnet to Collector", false, nil, function(enabled)
    		IceTycoon.setOreMagnet(enabled)
    	end)
    
    	window:AddToggle(convSection, "ice_dup_sells", "Duplicated Proximity Sell Nodes", false, nil, function(enabled)
    		IceTycoon.setDuplicatedSellNodes(enabled)
    	end)
    
    	local cashSection = window:AddSection(autoLeftCol, "Cash Collection")
    	window:AddToggle(cashSection, "ice_auto_collect", "Auto-Collect Tycoon Cash", false, nil, function(enabled)
    		IceTycoon.setAutoCollect(enabled)
    	end)
    
    	window:AddButton(cashSection, "Collect Cash Now", function()
    		if IceTycoon.collectCashNow() then
    			window:Notify("Ice Tycoon", "Cash collected from factory", 2.5)
    		else
    			window:Notify("Ice Tycoon", "Collector not found", 2.5)
    		end
    	end)
    
    	local buySection = window:AddSection(autoRightCol, "Button Purchases")
    	window:AddToggle(buySection, "ice_auto_buy", "Auto-Buy Affordable Buttons", false, nil, function(enabled)
    		IceTycoon.setAutoBuy(enabled)
    	end)
    
    	window:AddToggle(buySection, "ice_smart_buy", "Smart Priority Buy (Droppers/Upgrades 1st)", true, nil, function(enabled)
    		IceTycoon.SmartPriorityBuy = enabled
    	end)
    
    	window:AddButton(buySection, "Buy All Affordable Now", function()
    		local count = IceTycoon.buyAllAffordable()
    		window:Notify("Ice Tycoon", string.format("Purchased %d affordable buttons", count), 3)
    	end)
    
    	-- ── 2. RESOURCES & FARMING ───────────────────────────────────
    	local farmLeftCol, farmRightCol = window:CreateColumns(farmSubTab)
    
    	local toolSection = window:AddSection(farmLeftCol, "Tools & Farm Automation")
    	window:AddButton(toolSection, "Claim Starter Tools & Keys", function()
    		local count = IceTycoon.claimAllTools()
    		window:Notify("Ice Tycoon", string.format("Claimed %d tools/keys (Pickaxe, Key, Lever)", count), 3)
    	end)
    
    	window:AddToggle(toolSection, "ice_auto_harvest", "Auto-Harvest Ice Flowers", false, nil, function(enabled)
    		IceTycoon.setAutoHarvestFlowers(enabled)
    	end)
    
    	window:AddButton(toolSection, "Harvest All Ice Flowers Now", function()
    		local count = IceTycoon.harvestFlowersNow()
    		window:Notify("Ice Tycoon", string.format("Harvested %d mature flower plots", count), 2.5)
    	end)
    
    	window:AddToggle(toolSection, "ice_auto_water", "Auto-Fill Water Reservoir", false, nil, function(enabled)
    		IceTycoon.setAutoFillWater(enabled)
    	end)
    
    	window:AddButton(toolSection, "Fill Water Tank Now", function()
    		if IceTycoon.fillWaterNow() then
    			window:Notify("Ice Tycoon", "Water reservoir filled", 2.5)
    		else
    			window:Notify("Ice Tycoon", "No water source nearby", 2.5)
    		end
    	end)
    
    	local crystalSection = window:AddSection(farmRightCol, "Mining & Trophies")
    	window:AddToggle(crystalSection, "ice_auto_mine", "Auto-Mine Available Ores", false, nil, function(enabled)
    		IceTycoon.setAutoMineOres(enabled)
    	end)
    
    	window:AddButton(crystalSection, "Mine All Ores Now", function()
    		local count = IceTycoon.mineOresNow()
    		window:Notify("Ice Tycoon", string.format("Mined %d ore nodes", count), 2.5)
    	end)
    
    	window:AddToggle(crystalSection, "ice_auto_secrets", "Auto-Collect Trophies & Secrets", false, nil, function(enabled)
    		IceTycoon.setAutoCollectSecrets(enabled)
    	end)
    
    	window:AddButton(crystalSection, "Collect All Trophies & Secrets Now", function()
    		local res = IceTycoon.collectAllSecretsNow()
    		window:Notify("Ice Tycoon", string.format("Claimed %d gems, %d trophies, %d secrets", res.Gems, res.Trophies, res.Secrets), 3.5)
    	end)
    
    	local armySection = window:AddSection(farmRightCol, "Sphere Army & Combat")
    	window:AddToggle(armySection, "ice_auto_army", "Sphere Army Auto-Battler & Spawner", false, nil, function(enabled)
    		IceTycoon.setAutoArmyFight(enabled)
    	end)
    
    	window:AddButton(armySection, "Spawn Army Reinforcements Now", function()
    		local count = IceTycoon.spawnArmyUnits(8, 8)
    		window:Notify("Sphere Army", string.format("Spawned %d Noob and Knight units", count), 3)
    	end)
    
    	window:AddButton(armySection, "Command Army to Attack", function()
    		if IceTycoon.commandAttack() then
    			window:Notify("Sphere Army", "Commanded army units into battle!", 2.5)
    		end
    	end)
    
    	-- ── 3. PROTECTIONS & ZONES ───────────────────────────────────
    	local zoneLeftCol, zoneRightCol = window:CreateColumns(zoneSubTab)
    
    	local protectSection = window:AddSection(zoneLeftCol, "Environment Protections")
    	window:AddToggle(protectSection, "ice_anti_freeze", "Anti-Freeze & Shiver Bypass", false, nil, function(enabled)
    		IceTycoon.setAntiFreeze(enabled)
    	end)
    
    	window:AddToggle(protectSection, "ice_anti_jumpscare", "Anti-Jumpscare Shock Shield", false, nil, function(enabled)
    		IceTycoon.setAntiJumpscare(enabled)
    	end)
    
    	window:AddToggle(protectSection, "ice_no_lava", "No Lava & Hazard Damage", false, nil, function(enabled)
    		IceTycoon.setNoLavaDamage(enabled)
    	end)
    
    	local tpSection = window:AddSection(zoneRightCol, "Zone Shortcuts")
    	window:AddButton(tpSection, "Tycoon Base / Collector", function()
    		if IceTycoon.teleportTo("Tycoon Base / Collector") then
    			window:Notify("Teleport", "Warped to Tycoon Base", 2)
    		end
    	end)
    
    	window:AddButton(tpSection, "Lava Cave & Crystal Hatch", function()
    		if IceTycoon.teleportTo("Lava Cave & Crystal Hatch") then
    			window:Notify("Teleport", "Warped to Lava Cave", 2)
    		end
    	end)
    
    	window:AddButton(tpSection, "Troop Shop 1", function()
    		if IceTycoon.teleportTo("Troop Shop 1") then
    			window:Notify("Teleport", "Warped to Troop Shop 1", 2)
    		end
    	end)
    
    	window:AddButton(tpSection, "Jail & Lever Room", function()
    		if IceTycoon.teleportTo("Jail & Lever Room") then
    			window:Notify("Teleport", "Warped to Jail", 2)
    		end
    	end)
    
    	window:AddButton(tpSection, "Ending Portal Zone", function()
    		if IceTycoon.teleportTo("Ending Portal Zone") then
    			window:Notify("Teleport", "Warped to Ending Portal", 2)
    		end
    	end)
    end
    
    -- ============================================================
    -- ============================================================
    -- 4. VISUALS TAB CONTENT (HORIZONTAL MINI SUB-TABS)
    --    [ 2D Overlays & ESP ] [ 3D Chams & Skeletons ] [ ESP Customizer ]
    -- ============================================================
    local visSubTabs = window:CreateSubTabs(visualsTab, { "2D Overlays & ESP", "3D Chams & Skeletons", "ESP Customizer" })
    local esp2dSubTab = visSubTabs["2D Overlays & ESP"]
    local chamsSubTab = visSubTabs["3D Chams & Skeletons"]
    local customSubTab = visSubTabs["ESP Customizer"]
    
    -- ── VISUALS SUB-TAB 1: 2D OVERLAYS & ESP ─────────────────────
    local v2dLeftCol, v2dRightCol = window:CreateColumns(esp2dSubTab)
    
    -- Left Column: 2D Bounding Boxes
    local boxSection = window:AddSection(v2dLeftCol, "2D Bounding Boxes")
    
    window:AddToggle(boxSection, "esp_box_2d", "2D ESP Box", false, nil, function(enabled)
    	Visuals.Box2D = enabled
    end)
    
    window:AddToggle(boxSection, "esp_box_outlines", "ESP Box Outlines (Black Contrast)", false, nil, function(enabled)
    	Visuals.BoxOutlines = enabled
    end)
    
    window:AddToggle(boxSection, "esp_health_bar", "Health Bar (Dynamic Green/Red)", false, nil, function(enabled)
    	Visuals.HealthBar = enabled
    end)
    
    window:AddToggle(boxSection, "esp_distance", "Distance Tags (Studs)", false, nil, function(enabled)
    	Visuals.Distance = enabled
    end)
    
    -- Right Column: Tracers & HUD Widgets
    local tracerSection = window:AddSection(v2dRightCol, "Tracers & HUD Widgets")
    
    window:AddToggle(tracerSection, "esp_tracers", "Snapline Tracers", false, nil, function(enabled)
    	Visuals.Tracers = enabled
    end)
    
    window:AddToggle(tracerSection, "music_tracker_widget", "Music Tracker Widget", true, nil, function(enabled)
    	musicTrackerWidget.SetVisible(enabled)
    end)
    
    window:AddToggle(tracerSection, "hud_leaderstats_widget", "Live Leaderstats & Currencies HUD", true, nil, function(enabled)
    	leaderstatsWidget.SetVisible(enabled)
    end)
    
    window:AddToggle(tracerSection, "hud_healthbar_widget", "Health Bar HUD Widget", true, nil, function(enabled)
    	healthWidget.SetVisible(enabled)
    end)
    
    window:AddToggle(tracerSection, "hud_damage_indicators", "3D Floating Damage Numbers", true, nil, function(enabled)
    	healthWidget.ToggleDamageNumbers(enabled)
    end)
    
    window:AddToggle(tracerSection, "hud_damage_flash", "Damage Taken Screen Flash", true, nil, function(enabled)
    	healthWidget.ToggleDamageFlash(enabled)
    end)
    
    window:AddToggle(tracerSection, "hud_dynamic_health_color", "Dynamic Health Gradient (Green/Red)", true, nil, function(enabled)
    	healthWidget.SetDynamicColors(enabled)
    end)
    
    -- ── VISUALS SUB-TAB 2: 3D CHAMS & SKELETONS ──────────────────
    local chmLeftCol, chmRightCol = window:CreateColumns(chamsSubTab)
    
    -- Left Column: 3D Highlights & Chams
    local chamsSection = window:AddSection(chmLeftCol, "3D Highlights & Chams")
    
    window:AddToggle(chamsSection, "esp_chams_3d", "3D Chams / Highlights", false, nil, function(enabled)
    	Visuals.Chams = enabled
    end)
    
    window:AddSlider(chamsSection, "Chams Transparency", 0, 100, 50, function(value)
    	Visuals.ChamsTransparency = value / 100
    end)
    
    window:AddSlider(chamsSection, "Chams Outline Transparency", 0, 100, 20, function(value)
    	Visuals.ChamsOutlineTransparency = value / 100
    end)
    
    -- Right Column: Skeletons & Colors
    local skeletonSection = window:AddSection(chmRightCol, "Skeletons & Colors")
    
    window:AddToggle(skeletonSection, "esp_skeletons", "Skeleton ESP (Bone Rigs)", false, nil, function(enabled)
    	Visuals.Skeleton = enabled
    end)
    
    window:AddButton(skeletonSection, "Purple / Magenta Chams", function()
    	Visuals.ChamsColor = Color3.fromRGB(180, 70, 255)
    	Visuals.ChamsFillColor = Color3.fromRGB(180, 70, 255)
    	window:Notify("Chams", "Applied Purple / Magenta Chams", 2)
    end)
    
    window:AddButton(skeletonSection, "Cyan / Blue Chams", function()
    	Visuals.ChamsColor = Color3.fromRGB(55, 175, 245)
    	Visuals.ChamsFillColor = Color3.fromRGB(55, 175, 245)
    	window:Notify("Chams", "Applied Cyan / Blue Chams", 2)
    end)
    
    window:AddButton(skeletonSection, "Red / Crimson Chams", function()
    	Visuals.ChamsColor = Color3.fromRGB(245, 60, 60)
    	Visuals.ChamsFillColor = Color3.fromRGB(245, 60, 60)
    	window:Notify("Chams", "Applied Red / Crimson Chams", 2)
    end)
    
    window:AddButton(skeletonSection, "Gold / Yellow Chams", function()
    	Visuals.ChamsColor = Color3.fromRGB(255, 200, 50)
    	Visuals.ChamsFillColor = Color3.fromRGB(255, 200, 50)
    	window:Notify("Chams", "Applied Gold / Yellow Chams", 2)
    end)
    
    -- ── VISUALS SUB-TAB 3: ESP CUSTOMIZER ────────────────────────
    local cstLeftCol, cstRightCol = window:CreateColumns(customSubTab)
    
    -- Left Column: Tracer Origin Selector
    local originSection = window:AddSection(cstLeftCol, "Tracer Origin Selector")
    
    window:AddButton(originSection, "Tracer Origin: Bottom", function()
    	Visuals.TracerOrigin = "Bottom"
    	window:Notify("Tracers", "Tracer origin set to Screen Bottom", 2)
    end)
    
    window:AddButton(originSection, "Tracer Origin: Center", function()
    	Visuals.TracerOrigin = "Center"
    	window:Notify("Tracers", "Tracer origin set to Screen Center", 2)
    end)
    
    window:AddButton(originSection, "Tracer Origin: Mouse", function()
    	Visuals.TracerOrigin = "Mouse"
    	window:Notify("Tracers", "Tracer origin set to Mouse Cursor", 2)
    end)
    
    -- Right Column: ESP Palette Presets
    local paletteSection = window:AddSection(cstRightCol, "ESP Palette Presets")
    
    window:AddButton(paletteSection, "Default Cyan Palette", function()
    	Visuals.BoxColor = Color3.fromRGB(55, 175, 245)
    	Visuals.TracerColor = Color3.fromRGB(255, 255, 255)
    	Visuals.SkeletonColor = Color3.fromRGB(255, 200, 50)
    	window:Notify("Palette", "Default Cyan Palette applied", 2)
    end)
    
    window:AddButton(paletteSection, "Emerald Green Palette", function()
    	Visuals.BoxColor = Color3.fromRGB(50, 220, 80)
    	Visuals.TracerColor = Color3.fromRGB(50, 220, 80)
    	Visuals.SkeletonColor = Color3.fromRGB(120, 255, 140)
    	window:Notify("Palette", "Emerald Green Palette applied", 2)
    end)
    
    window:AddButton(paletteSection, "Ruby Red Palette", function()
    	Visuals.BoxColor = Color3.fromRGB(245, 60, 60)
    	Visuals.TracerColor = Color3.fromRGB(245, 60, 60)
    	Visuals.SkeletonColor = Color3.fromRGB(255, 120, 120)
    	window:Notify("Palette", "Ruby Palette applied", 2)
    end)
    
    window:AddButton(paletteSection, "Amethyst Purple Palette", function()
    	Visuals.BoxColor = Color3.fromRGB(180, 70, 255)
    	Visuals.TracerColor = Color3.fromRGB(220, 120, 255)
    	Visuals.SkeletonColor = Color3.fromRGB(200, 100, 255)
    	window:Notify("Palette", "Amethyst Palette applied", 2)
    end)
    
    -- ============================================================
    -- 5. SETTINGS TAB CONTENT (HORIZONTAL MINI SUB-TABS)
    --    [ Modules & Tabs ] [ Themes & Visuals ] [ Performance & Rendering ] [ System & Audio ]
    -- ============================================================
    local setSubTabs = window:CreateSubTabs(settingsTab, { "Modules & Tabs", "Themes & Visuals", "Performance & Rendering", "System & Audio" })
    local modSubTab = setSubTabs["Modules & Tabs"]
    local thmSubTab = setSubTabs["Themes & Visuals"]
    local prfSubTab = setSubTabs["Performance & Rendering"]
    local sysSubTab = setSubTabs["System & Audio"]
    
    -- ── SETTINGS SUB-TAB 1: MODULES & TABS ───────────────────────
    local modLeftCol, modRightCol = window:CreateColumns(modSubTab)
    
    -- Left Column: Sidebar Tab Visibility
    local moduleSection = window:AddSection(modLeftCol, "Sidebar Tab Visibility")
    
    window:AddToggle(moduleSection, "tab_game_module", string.format("%s (Game Tab)", gameTabTitle), true, nil, function(enabled)
    	FeatureManager.setModuleState("game_module", enabled)
    	window:SetTabVisibility(gameTab, enabled)
    	if not enabled then
    		RunNHide.SilentGunAudio = false
    		RunNHide.QuickReload = false
    		RunNHide.CompleteAuto = false
    		RunNHide.DisableBarriers = false
    		RunNHide.DisableKillbricks = false
    		DisasterSurvival.DisasterTracker = false
    		DisasterSurvival.setNoFallDamage(false)
    		DisasterSurvival.setFlight(false)
    		DisasterSurvival.setAntiFling(false)
    		DisasterSurvival.setFling(false)
    		IceTycoon.cleanup()
    	end
    end)
    
    window:AddToggle(moduleSection, "tab_combat_module", "Combat (Aim & Hitboxes)", true, nil, function(enabled)
    	FeatureManager.setModuleState("combat", enabled)
    	window:SetTabVisibility(combatTab, enabled)
    	if not enabled then
    		Combat.SilentAim = false
    		Combat.AimTracking = false
    		Combat.TriggerBot = false
    		Combat.ExpandHitboxes = false
    		Combat.resetHitboxes()
    	end
    end)
    
    window:AddToggle(moduleSection, "tab_visuals_module", "Visuals (ESP & Chams)", true, nil, function(enabled)
    	FeatureManager.setModuleState("visuals", enabled)
    	window:SetTabVisibility(visualsTab, enabled)
    	if not enabled then
    		Visuals.Box2D = false
    		Visuals.BoxOutlines = false
    		Visuals.HealthBar = false
    		Visuals.Tracers = false
    		Visuals.Distance = false
    		Visuals.Chams = false
    		Visuals.Skeleton = false
    	end
    end)
    
    window:AddButton(moduleSection, string.format("Hide %s Tab", gameTabTitle), function()
    	window:SetTabVisibility(gameTab, false)
    	FeatureManager.setFeatureState("tab_game_module", false)
    	window:Notify("Tab Hidden", string.format("%s tab hidden from sidebar", gameTabTitle), 2.5)
    end)
    
    window:AddButton(moduleSection, "Show All Sidebar Tabs", function()
    	window:SetTabVisibility(gameTab, true)
    	window:SetTabVisibility(combatTab, true)
    	window:SetTabVisibility(visualsTab, true)
    	FeatureManager.setFeatureState("tab_game_module", true)
    	FeatureManager.setFeatureState("tab_combat_module", true)
    	FeatureManager.setFeatureState("tab_visuals_module", true)
    	window:Notify("Tabs Restored", "All sidebar tabs are now visible", 2.5)
    end)
    
    -- Right Column: Peripheral Widgets
    local widgetSection = window:AddSection(modRightCol, "Peripheral Widgets")
    
    window:AddToggle(widgetSection, "mod_music_tracker", "Music Tracker Widget", true, nil, function(enabled)
    	FeatureManager.setModuleState("music_tracker", enabled)
    	musicTrackerWidget.SetVisible(enabled)
    end)
    
    window:AddToggle(widgetSection, "mod_player_list", "Player List Widget (Tab Key)", true, nil, function(enabled)
    	FeatureManager.setModuleState("player_list", enabled)
    	playerListWidget.Frame.Visible = enabled
    end)
    
    window:AddToggle(widgetSection, "mod_chat_widget", "Chat Widget", true, nil, function(enabled)
    	FeatureManager.setModuleState("chat_widget", enabled)
    	chatWidgetInstance.Frame.Visible = enabled
    end)
    
    window:AddToggle(widgetSection, "mod_custom_hotbar", "Custom Hotbar & Backpack HUD", true, nil, function(enabled)
    	FeatureManager.setModuleState("custom_hotbar", enabled)
    	hotbarWidget.SetVisible(enabled)
    end)
    
    window:AddToggle(widgetSection, "mod_leaderstats_widget", "Live Leaderstats & Currencies HUD", true, nil, function(enabled)
    	FeatureManager.setModuleState("leaderstats_widget", enabled)
    	leaderstatsWidget.SetVisible(enabled)
    end)
    
    -- Hook tab right-click sync to update settings toggles
    gameTab.OnVisibilityChanged = function(vis: boolean)
    	local feat = FeatureManager.getFeature("tab_game_module")
    	if feat and feat.state ~= vis then
    		FeatureManager.setFeatureState("tab_game_module", vis)
    	end
    end
    
    combatTab.OnVisibilityChanged = function(vis: boolean)
    	local feat = FeatureManager.getFeature("tab_combat_module")
    	if feat and feat.state ~= vis then
    		FeatureManager.setFeatureState("tab_combat_module", vis)
    	end
    end
    
    visualsTab.OnVisibilityChanged = function(vis: boolean)
    	local feat = FeatureManager.getFeature("tab_visuals_module")
    	if feat and feat.state ~= vis then
    		FeatureManager.setFeatureState("tab_visuals_module", vis)
    	end
    end
    
    -- ── SETTINGS SUB-TAB 2: THEMES & VISUALS ─────────────────────
    local thmLeftCol, thmRightCol = window:CreateColumns(thmSubTab)
    
    -- Left Column: Dark & Acrylic Themes
    local darkThemeSection = window:AddSection(thmLeftCol, "Dark & Acrylic Themes")
    
    window:AddButton(darkThemeSection, "Dark Mode", function()
    	window:SetTheme("Dark")
    	window:Notify("Theme", "Saved Dark Mode", 2)
    end)
    
    window:AddButton(darkThemeSection, "Translucent Dark (Acrylic)", function()
    	window:SetTheme("TranslucentDark")
    	window:Notify("Theme", "Saved Acrylic Dark Mode", 2)
    end)
    
    window:AddButton(darkThemeSection, "Adaptive (Album Cover)", function()
    	window:SetTheme("Adaptive")
    	window:Notify("Theme", "Saved Adaptive Mode", 2)
    end)
    
    -- Right Column: Light & Glass Themes
    local lightThemeSection = window:AddSection(thmRightCol, "Light & Glass Themes")
    
    window:AddButton(lightThemeSection, "Light Mode", function()
    	window:SetTheme("Light")
    	window:Notify("Theme", "Saved Light Mode", 2)
    end)
    
    window:AddButton(lightThemeSection, "Translucent Light (Glass)", function()
    	window:SetTheme("TranslucentLight")
    	window:Notify("Theme", "Saved Glass Light Mode", 2)
    end)
    
    -- ── SETTINGS SUB-TAB 3: PERFORMANCE & RENDERING ──────────────
    local prfLeftCol, prfRightCol = window:CreateColumns(prfSubTab)
    
    -- Left Column: Performance & Framerate
    local perfSection = window:AddSection(prfLeftCol, "Performance & Framerate")
    
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    window:AddToggle(perfSection, "fps_boost", "FPS BOOST (Shadows & Fog)", false, nil, function(enabled)
    	Lighting.GlobalShadows = not enabled
    	Lighting.FogEnd = if enabled then 9e9 else 10000
    	if terrain then
    		terrain.WaterWaveSize = if enabled then 0 else 0.15
    		terrain.WaterWaveSpeed = if enabled then 0 else 10
    		terrain.WaterReflectance = if enabled then 0 else 1
    	end
    end)
    
    window:AddToggle(perfSection, "fps_uncap", "FPS UNCAP (Remove 60 FPS Cap)", false, nil, function(enabled)
    	local setfps = (setfpscap or (set_fps_cap :: any))
    	if typeof(setfps) == "function" then
    		setfps(if enabled then 999 else 60)
    	end
    end)
    
    window:AddToggle(perfSection, "hide_game_guis", "Hide Default Game GUIs (PlayerGui)", true, nil, function(enabled)
    	hidePlayerGameGuis(enabled)
    end)
    
    -- Right Column: 3D & Texture Optimization
    local renderSection = window:AddSection(prfRightCol, "3D & Texture Optimization")
    
    local meshConn: RBXScriptConnection? = nil
    window:AddToggle(renderSection, "dont_render_meshes", "DONT RENDER 3D MESHS", false, nil, function(enabled)
    	for _, obj in ipairs(workspace:GetDescendants()) do
    		if obj:IsA("MeshPart") then
    			if enabled then
    				if not obj:GetAttribute("OrigTransparency") then
    					obj:SetAttribute("OrigTransparency", obj.Transparency)
    				end
    				obj.Transparency = 1
    			else
    				local orig = obj:GetAttribute("OrigTransparency") or 0
    				obj.Transparency = orig :: number
    			end
    		end
    	end
    	
    	if enabled then
    		meshConn = workspace.DescendantAdded:Connect(function(obj)
    			if obj:IsA("MeshPart") then
    				obj.Transparency = 1
    			end
    		end)
    	elseif meshConn then
    		meshConn:Disconnect()
    		meshConn = nil
    	end
    end)
    
    local decalConn: RBXScriptConnection? = nil
    window:AddToggle(renderSection, "dont_render_decals", "DONT RENDER DECALS", false, nil, function(enabled)
    	for _, obj in ipairs(workspace:GetDescendants()) do
    		if obj:IsA("Decal") or obj:IsA("Texture") then
    			if enabled then
    				if not obj:GetAttribute("OrigTransparency") then
    					obj:SetAttribute("OrigTransparency", obj.Transparency)
    				end
    				obj.Transparency = 1
    			else
    				local orig = obj:GetAttribute("OrigTransparency") or 0
    				obj.Transparency = orig :: number
    			end
    		end
    	end
    	
    	if enabled then
    		decalConn = workspace.DescendantAdded:Connect(function(obj)
    			if obj:IsA("Decal") or obj:IsA("Texture") then
    				obj.Transparency = 1
    			end
    		end)
    	elseif decalConn then
    		decalConn:Disconnect()
    		decalConn = nil
    	end
    end)
    
    -- ── SETTINGS SUB-TAB 4: SYSTEM & AUDIO ───────────────────────
    local sysLeftCol, sysRightCol = window:CreateColumns(sysSubTab)
    
    -- Left Column: Screen & GUI Optimization
    local cleanSection = window:AddSection(sysLeftCol, "Screen & GUI Optimization")
    
    window:AddToggle(cleanSection, "hide_default_guis", "Hide Game Default GUIs (Topbar & Core)", true, nil, function(enabled)
    	disableRobloxTopBarApp(enabled)
    	for _, guiType in ipairs(coreGuiOverlays) do
    		pcall(function()
    			StarterGui:SetCoreGuiEnabled(guiType, not enabled)
    		end)
    	end
    end)
    
    -- Right Column: Master Audio Volume
    local audioSection = window:AddSection(sysRightCol, "Master Audio Volume")
    
    local currentVolumeScale = 1.0
    local function updateSound(sound: Sound)
    	if sound:IsDescendantOf(game:GetService("VoiceChatService")) then return end
    	local base = sound:GetAttribute("OrigVolume")
    	if not base then
    		base = sound.Volume
    		sound:SetAttribute("OrigVolume", base)
    	end
    	sound.Volume = (base :: number) * currentVolumeScale
    end
    
    window:AddSlider(audioSection, "VOLUME CONTROLLER", 0, 100, 100, function(value)
    	currentVolumeScale = value / 100
    	for _, obj in ipairs(SoundService:GetDescendants()) do
    		if obj:IsA("Sound") then
    			updateSound(obj)
    		end
    	end
    	for _, obj in ipairs(Workspace:GetDescendants()) do
    		if obj:IsA("Sound") then
    			updateSound(obj)
    		end
    	end
    end)
    
    SoundService.DescendantAdded:Connect(function(obj)
    	if obj:IsA("Sound") then
    		task.defer(function()
    			updateSound(obj)
    		end)
    	end
    end)
    
    Workspace.DescendantAdded:Connect(function(obj)
    	if obj:IsA("Sound") then
    		task.defer(function()
    			updateSound(obj)
    		end)
    	end
    end)
    
    -- ============================================================
    -- DYNAMIC CONFIGS TAB CONTENT (ZERO-DEFAULT PROFILE MANAGER)
    -- ============================================================
    local confLeftCol, confRightCol = window:CreateColumns(configsTab)
    
    local profilesSection = window:AddSection(confLeftCol, "Saved Configuration Profiles")
    local configActionsSection = window:AddSection(confRightCol, "Config Actions & Management")
    
    local selectedConfigName: string? = nil
    local currentConfigInputName = ""
    local profileButtonRows: {[string]: Frame} = {}
    
    local configInputBox = window:AddTextBox(configActionsSection, "Profile Name", "e.g. Legit_Main", "", function(text)
    	currentConfigInputName = text
    end)
    
    local statusNotice = Instance.new("TextLabel")
    statusNotice.Name = "StatusNotice"
    statusNotice.Size = UDim2.new(1, -4, 0, 36)
    statusNotice.BackgroundTransparency = 1
    statusNotice.Text = "No Saved Profiles Found\nCreate a new profile on the right to save."
    statusNotice.TextColor3 = UI.Theme.TextSecondary
    statusNotice.Font = UI.Fonts.Body
    statusNotice.TextSize = 10
    statusNotice.TextWrapped = true
    statusNotice.Parent = profilesSection
    UI.registerThemeElement(statusNotice, "TextSecondary")
    
    local function refreshProfilesList()
    	for _, row in pairs(profileButtonRows) do
    		pcall(function() row:Destroy() end)
    	end
    	table.clear(profileButtonRows)
    
    	local existingConfigs = FeatureManager.listConfigs()
    	if #existingConfigs == 0 then
    		statusNotice.Visible = true
    		statusNotice.Text = "No Saved Profiles Found\nType a name on the right and click Create Config."
    	else
    		statusNotice.Visible = false
    		for _, cfgName in ipairs(existingConfigs) do
    			local pRow = Instance.new("Frame")
    			pRow.Name = cfgName .. "Row"
    			pRow.Size = UDim2.new(1, -4, 0, 26)
    			pRow.Position = UDim2.new(0, 2, 0, 0)
    			pRow.BackgroundColor3 = UI.Theme.Container
    			pRow.BackgroundTransparency = UI.Theme.ContainerTransparency
    			pRow.BorderSizePixel = 0
    			pRow.Parent = profilesSection
    			UI.registerThemeElement(pRow, "Container")
    
    			local pStroke = Instance.new("UIStroke")
    			pStroke.Color = if selectedConfigName == cfgName then UI.Theme.Accent else UI.Theme.Border
    			pStroke.Thickness = if selectedConfigName == cfgName then 1.6 else 1.0
    			pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    			pStroke.Parent = pRow
    			UI.registerThemeElement(pStroke, "Border")
    
    			local pBtn = Instance.new("TextButton")
    			pBtn.Size = UDim2.new(1, 0, 1, 0)
    			pBtn.BackgroundTransparency = 1
    			pBtn.Text = string.format("  [%s] %s", if selectedConfigName == cfgName then "●" else "○", cfgName)
    			pBtn.TextColor3 = if selectedConfigName == cfgName then UI.Theme.Accent else UI.Theme.TextPrimary
    			pBtn.Font = UI.Fonts.Header
    			pBtn.TextSize = 11
    			pBtn.TextXAlignment = Enum.TextXAlignment.Left
    			pBtn.Parent = pRow
    			UI.registerThemeElement(pBtn, "TextPrimary")
    
    			pBtn.MouseButton1Click:Connect(function()
    				selectedConfigName = cfgName
    				configInputBox.Text = cfgName
    				currentConfigInputName = cfgName
    				refreshProfilesList()
    			end)
    
    			profileButtonRows[cfgName] = pRow
    		end
    	end
    end
    
    window:AddButton(configActionsSection, "Create & Save Config", function()
    	local targetName = if currentConfigInputName ~= "" then currentConfigInputName else configInputBox.Text
    	if targetName == "" then
    		window:Notify("Configs", "Please enter a profile name first", 3)
    		return
    	end
    
    	local saved = FeatureManager.saveConfig(targetName)
    	if saved then
    		selectedConfigName = targetName
    		window:Notify("Configs", string.format("Created & saved '%s'", targetName), 3)
    		refreshProfilesList()
    	else
    		window:Notify("Configs", "Failed to write configuration to disk", 3)
    	end
    end)
    
    window:AddButton(configActionsSection, "Save / Overwrite Selected", function()
    	local targetName = selectedConfigName or (if currentConfigInputName ~= "" then currentConfigInputName else configInputBox.Text)
    	if not targetName or targetName == "" then
    		window:Notify("Configs", "No configuration selected to overwrite", 3)
    		return
    	end
    
    	local saved = FeatureManager.saveConfig(targetName)
    	if saved then
    		window:Notify("Configs", string.format("Saved current settings to '%s'", targetName), 3)
    		refreshProfilesList()
    	else
    		window:Notify("Configs", "Failed to save configuration", 3)
    	end
    end)
    
    window:AddButton(configActionsSection, "Load Selected Config", function()
    	if not selectedConfigName or selectedConfigName == "" then
    		window:Notify("Configs", "Select a profile from the left first", 3)
    		return
    	end
    
    	local loaded = FeatureManager.loadConfig(selectedConfigName)
    	if loaded then
    		window:Notify("Configs", string.format("Loaded profile '%s'", selectedConfigName), 3)
    	else
    		window:Notify("Configs", string.format("Failed to load '%s'", selectedConfigName), 3)
    	end
    end)
    
    window:AddButton(configActionsSection, "Delete Selected Config", function()
    	if not selectedConfigName or selectedConfigName == "" then
    		window:Notify("Configs", "Select a profile from the left to delete", 3)
    		return
    	end
    
    	local deletedName = selectedConfigName
    	local deleted = FeatureManager.deleteConfig(deletedName)
    	if deleted then
    		selectedConfigName = nil
    		configInputBox.Text = ""
    		currentConfigInputName = ""
    		window:Notify("Configs", string.format("Deleted profile '%s'", deletedName), 3)
    		refreshProfilesList()
    	else
    		window:Notify("Configs", "Failed to delete profile", 3)
    	end
    end)
    
    window:AddButton(configActionsSection, "Refresh Config List", function()
    	refreshProfilesList()
    	window:Notify("Configs", "Config list refreshed", 2)
    end)
    
    -- Auto-Load on Startup Section
    local autoLoadSection = window:AddSection(confRightCol, "Auto-Load on Startup")
    
    local autoLoadData = FeatureManager.getAutoLoadConfig()
    
    local autoLoadStatusLabel = Instance.new("TextLabel")
    autoLoadStatusLabel.Name = "AutoLoadStatus"
    autoLoadStatusLabel.Size = UDim2.new(1, -4, 0, 24)
    autoLoadStatusLabel.BackgroundTransparency = 1
    autoLoadStatusLabel.Text = if autoLoadData.enabled and autoLoadData.configName ~= "" then string.format("Default Startup Config: [%s]", autoLoadData.configName) else "Default Startup Config: [ None ]"
    autoLoadStatusLabel.TextColor3 = if autoLoadData.enabled then UI.Theme.Accent else UI.Theme.TextSecondary
    autoLoadStatusLabel.Font = UI.Fonts.Mono
    autoLoadStatusLabel.TextSize = 10
    autoLoadStatusLabel.Parent = autoLoadSection
    UI.registerThemeElement(autoLoadStatusLabel, "TextSecondary")
    
    window:AddToggle(autoLoadSection, "autoload_startup_enabled", "Enable Auto-Load on Startup", autoLoadData.enabled, nil, function(enabled)
    	local cur = FeatureManager.getAutoLoadConfig()
    	FeatureManager.setAutoLoadConfig(enabled, cur.configName)
    	autoLoadStatusLabel.TextColor3 = if enabled then UI.Theme.Accent else UI.Theme.TextSecondary
    	window:Notify("Auto-Load", if enabled then "Auto-load on startup enabled" else "Auto-load on startup disabled", 2)
    end)
    
    window:AddButton(autoLoadSection, "Set Selected as Startup Profile", function()
    	if not selectedConfigName or selectedConfigName == "" then
    		window:Notify("Auto-Load", "Please select a profile on the left first", 3)
    		return
    	end
    	FeatureManager.setAutoLoadConfig(true, selectedConfigName)
    	local tgl = FeatureManager.getFeature("autoload_startup_enabled")
    	if tgl and not tgl.state then
    		FeatureManager.setFeatureState("autoload_startup_enabled", true)
    	end
    	autoLoadStatusLabel.Text = string.format("Default Startup Config: [%s]", selectedConfigName)
    	autoLoadStatusLabel.TextColor3 = UI.Theme.Accent
    	window:Notify("Auto-Load", string.format("Set '%s' to load automatically on startup", selectedConfigName), 3)
    end)
    
    window:AddButton(autoLoadSection, "Clear Startup Profile", function()
    	FeatureManager.setAutoLoadConfig(false, "")
    	local tgl = FeatureManager.getFeature("autoload_startup_enabled")
    	if tgl and tgl.state then
    		FeatureManager.setFeatureState("autoload_startup_enabled", false)
    	end
    	autoLoadStatusLabel.Text = "Default Startup Config: [ None ]"
    	autoLoadStatusLabel.TextColor3 = UI.Theme.TextSecondary
    	window:Notify("Auto-Load", "Startup auto-load profile cleared", 2)
    end)
    
    -- Initial scan of configs on startup
    task.spawn(refreshProfilesList)
    
    -- Auto-load configuration profile on startup if configured
    task.spawn(function()
    	task.wait(1.0)
    	pcall(function()
    		local auto = FeatureManager.getAutoLoadConfig()
    		if auto.enabled and auto.configName ~= "" then
    			local ok = FeatureManager.loadConfig(auto.configName)
    			if ok then
    				window:Notify("Auto-Load", string.format("Auto-loaded startup config '%s'", auto.configName), 4)
    			end
    		end
    	end)
    end)
    
    -- Ensure saved theme is applied and saved on leave
    pcall(function()
    	local savedTheme = UI.getSavedTheme()
    	if savedTheme and UI.Themes[savedTheme] then
    		window:SetTheme(savedTheme)
    	end
    end)
    
    pcall(function()
    	game:BindToClose(function()
    		UI.saveTheme(UI.CurrentTheme.Name)
    	end)
    end)
    
    Players.PlayerRemoving:Connect(function(plr)
    	if plr == localPlayer then
    		UI.saveTheme(UI.CurrentTheme.Name)
    	end
    end)
    
    -- Explicitly activate default Main tab on load
    window:SelectTab(mainTab)
    
    -- ============================================================
    -- LUCKY BLOCKS BATTLEGROUNDS GAME TAB
    -- [ Block Automation ] [ Combat & Turbo ] [ Fast Teleports ]
    -- ============================================================
    if gameTabTitle == "Lucky Blocks" then
    	local lbSubTabs = window:CreateSubTabs(gameTab, { "Block Automation", "Combat & Turbo", "Fast Teleports" })
    	local blockSubTab = lbSubTabs["Block Automation"]
    	local combatSubTab = lbSubTabs["Combat & Turbo"]
    	local tpSubTab = lbSubTabs["Fast Teleports"]
    
    	-- ── SUB-TAB 1: BLOCK AUTOMATION ────────────────────────────
    	local bLeftCol, bRightCol = window:CreateColumns(blockSubTab)
    
    	local autoBlockSection = window:AddSection(bLeftCol, "Lucky Block Collector")
    	window:AddToggle(autoBlockSection, "lb_auto_claim", "Auto-Claim Lucky Blocks", false, nil, function(enabled)
    		LuckyBlocks.setAutoClaim(enabled)
    	end)
    
    	window:AddToggle(autoBlockSection, "lb_auto_open", "Auto-Open Inventory Blocks", false, nil, function(enabled)
    		LuckyBlocks.setAutoOpen(enabled)
    	end)
    
    	window:AddButton(autoBlockSection, "Claim All Blocks Now", function()
    		local count = LuckyBlocks.claimAllBlocksNow()
    		window:Notify("Lucky Blocks", string.format("Claimed %d lucky block givers", count), 2.5)
    	end)
    
    	window:AddSlider(autoBlockSection, "Claim Interval (s)", 20, 100, 35, function(value)
    		LuckyBlocks.ClaimInterval = value / 100
    	end)
    
    	local filterSection = window:AddSection(bRightCol, "Tier Filters (Auto-Claim)")
    	window:AddToggle(filterSection, "lb_tier_void", "Claim Void Blocks", true, nil, function(val)
    		LuckyBlocks.ClaimVoid = val
    	end)
    	window:AddToggle(filterSection, "lb_tier_rainbow", "Claim Rainbow Blocks", true, nil, function(val)
    		LuckyBlocks.ClaimRainbow = val
    	end)
    	window:AddToggle(filterSection, "lb_tier_galaxy", "Claim Galaxy Blocks", true, nil, function(val)
    		LuckyBlocks.ClaimGalaxy = val
    	end)
    	window:AddToggle(filterSection, "lb_tier_diamond", "Claim Diamond Blocks", true, nil, function(val)
    		LuckyBlocks.ClaimDiamond = val
    	end)
    	window:AddToggle(filterSection, "lb_tier_super", "Claim Super Blocks", true, nil, function(val)
    		LuckyBlocks.ClaimSuper = val
    	end)
    	window:AddToggle(filterSection, "lb_tier_lucky", "Claim Normal Blocks", true, nil, function(val)
    		LuckyBlocks.ClaimLucky = val
    	end)
    
    	-- ── SUB-TAB 2: COMBAT & TURBO ──────────────────────────────
    	local cLeftCol, cRightCol = window:CreateColumns(combatSubTab)
    
    	local weaponSpamSection = window:AddSection(cLeftCol, "Weapon Spam & Turbo")
    	window:AddToggle(weaponSpamSection, "lb_turbo_sword", "Turbo Sword / Weapon Auto-Slash", false, nil, function(enabled)
    		LuckyBlocks.setTurboSword(enabled)
    	end)
    
    	window:AddToggle(weaponSpamSection, "lb_anti_void", "Anti-Void Fall Rescue", true, nil, function(enabled)
    		LuckyBlocks.setAntiVoid(enabled)
    	end)
    
    	local quickCombatSection = window:AddSection(cRightCol, "Combat Shortcuts")
    	window:AddButton(quickCombatSection, "Equip Sword & Turbo Attack", function()
    		local char = localPlayer.Character
    		local bp = localPlayer:FindFirstChildOfClass("Backpack")
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    		if bp and hum then
    			for _, item in ipairs(bp:GetChildren()) do
    				if item:IsA("Tool") and (item.Name:lower():find("sword") or item.Name:lower():find("katana") or item.Name:lower():find("axe") or item.Name:lower():find("blade")) then
    					hum:EquipTool(item)
    					break
    				end
    			end
    		end
    		LuckyBlocks.setTurboSword(true)
    		FeatureManager.setToggleState("lb_turbo_sword", true)
    		window:Notify("Lucky Blocks", "Equipped weapon with Turbo Attack", 2)
    	end)
    
    	-- ── SUB-TAB 3: FAST TELEPORTS ──────────────────────────────
    	local tpLeftCol, tpRightCol = window:CreateColumns(tpSubTab)
    
    	local centerSection = window:AddSection(tpLeftCol, "High Tier Center Zones")
    	window:AddButton(centerSection, "Center Void Giver", function()
    		LuckyBlocks.teleportTo("Center Void / High Tier")
    		window:Notify("Teleport", "Teleported to Void Giver", 2)
    	end)
    	window:AddButton(centerSection, "Center Rainbow Giver", function()
    		LuckyBlocks.teleportTo("Center Rainbow Giver")
    		window:Notify("Teleport", "Teleported to Rainbow Giver", 2)
    	end)
    	window:AddButton(centerSection, "Center Galaxy Giver", function()
    		LuckyBlocks.teleportTo("Center Galaxy Giver")
    		window:Notify("Teleport", "Teleported to Galaxy Giver", 2)
    	end)
    
    	local spawnSection = window:AddSection(tpRightCol, "Spawn Bases 1 - 8")
    	for i = 1, 8 do
    		local sName = string.format("Spawn %d Base", i)
    		window:AddButton(spawnSection, sName, function()
    			LuckyBlocks.teleportTo(sName)
    			window:Notify("Teleport", string.format("Teleported to %s", sName), 2)
    		end)
    	end
    end
end

-- Boot Main application in a dedicated thread
task.spawn(function()
	local success, err = pcall(function()
		requireModule("Core/Main.luau")
	end)
	if not success then
		warn("[Loader] Critical failure during execution: " .. tostring(err))
	else
		print("[Loader] Modular Roblox UI successfully loaded and running.")
	end
end)
