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

	uiScale.Scale = 0.96
	local tween = TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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
			TweenService:Create(uiScale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.025
			}):Play()
		end
	end)

	guiObject.MouseLeave:Connect(function()
		if uiScale then
			TweenService:Create(uiScale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.0
			}):Play()
		end
	end)
end

-- Spring pop scale for checkmarks, badges, icons, and value labels (0.0 -> 1.0 Quad.Out)
function Animations.popScale(guiObject: GuiObject, startScale: number?, peakScale: number?, endScale: number?, duration: number?): Tween
	local targetStart = if startScale ~= nil then startScale else 0.0
	local targetEnd = if endScale ~= nil then endScale else 1.0
	local targetDur = if duration ~= nil then duration else 0.18

	local uiScale = guiObject:FindFirstChildWhichIsA("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = targetStart
		uiScale.Parent = guiObject
	else
		uiScale.Scale = targetStart
	end

	local tweenInfo = TweenInfo.new(targetDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
			local strokeProps: {[string]: any} = { Thickness = 1.6 }
			if glowColor then
				strokeProps.Color = glowColor
			end
			Animations.tween(targetStroke, strokeProps, { duration = 0.10, easingStyle = Enum.EasingStyle.Quad })
		end
		if getHoverBg then
			Animations.tween(button, { BackgroundColor3 = getHoverBg() }, { duration = 0.10 })
		end
		if uiScale then
			Animations.tween(uiScale, { Scale = 1.02 }, { duration = 0.10, easingStyle = Enum.EasingStyle.Quad })
		end
	end)

	button.MouseLeave:Connect(function()
		if targetStroke then
			local normalColor = if getNormalBorder then getNormalBorder() else nil
			local strokeProps: {[string]: any} = { Thickness = 1.2 }
			if normalColor then
				strokeProps.Color = normalColor
			end
			Animations.tween(targetStroke, strokeProps, { duration = 0.10, easingStyle = Enum.EasingStyle.Quad })
		end
		if getNormalBg then
			Animations.tween(button, { BackgroundColor3 = getNormalBg() }, { duration = 0.10 })
		end
		if uiScale then
			Animations.tween(uiScale, { Scale = 1.0 }, { duration = 0.10, easingStyle = Enum.EasingStyle.Quad })
		end
	end)

	button.MouseButton1Down:Connect(function()
		if uiScale then
			Animations.tween(uiScale, { Scale = 0.96 }, { duration = 0.05, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
		end
		if getActiveBg then
			Animations.tween(button, { BackgroundColor3 = getActiveBg() }, { duration = 0.05 })
		end
	end)

	button.MouseButton1Up:Connect(function()
		if uiScale then
			Animations.tween(uiScale, { Scale = 1.02 }, { duration = 0.12, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
		end
		if getHoverBg then
			Animations.tween(button, { BackgroundColor3 = getHoverBg() }, { duration = 0.10 })
		elseif getNormalBg then
			Animations.tween(button, { BackgroundColor3 = getNormalBg() }, { duration = 0.10 })
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
		Animations.tween(stroke, { Thickness = 1.6 }, { duration = 0.10 })
	end)

	track.MouseLeave:Connect(function()
		Animations.tween(stroke, { Thickness = 1.2 }, { duration = 0.10 })
	end)
end

-- Tab and sub-tab selection active indicator pulse
function Animations.pulseIndicator(stroke: UIStroke, pulseColor: Color3, normalColor: Color3, peakThickness: number?, normalThickness: number?)
	local peak = if peakThickness ~= nil then peakThickness else 2.2
	local norm = if normalThickness ~= nil then normalThickness else 1.5

	stroke.Color = pulseColor
	local surgeTween = Animations.tween(stroke, { Thickness = peak, Color = pulseColor }, { duration = 0.06, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
	surgeTween.Completed:Connect(function()
		Animations.tween(stroke, { Thickness = norm, Color = normalColor }, { duration = 0.14, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
	end)
end

-- Window open transition (Smooth deceleration scale 0.94 -> 1.0 Quad.Out)
function Animations.openWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
	frame.Visible = true
	if uiScale then
		uiScale.Scale = 0.94
		local tween = TweenService:Create(uiScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

-- Window close transition (Smooth instant fade-out 1.0 -> 0.94 Quad.In)
function Animations.closeWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
	if uiScale then
		local tween = TweenService:Create(uiScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.94
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

-- Popup / context menu pop-in (0.92 -> 1.0 Quad.Out)
function Animations.popIn(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
	frame.Visible = true
	if uiScale then
		uiScale.Scale = 0.92
		local tween = TweenService:Create(uiScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

-- Popup / context menu pop-out (1.0 -> 0.92 Quad.In)
function Animations.popOut(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
	if uiScale then
		local tween = TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.92
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
	local delayStep = if baseDelay ~= nil then baseDelay else 0.018
	local offset = if offsetDistance ~= nil then offsetDistance else 8
	local dur = if duration ~= nil then duration else 0.16

	for idx, element in ipairs(elements) do
		local origYScale = element.Position.Y.Scale
		local origYOffset = element.Position.Y.Offset
		element.Position = UDim2.new(0, offset, origYScale, origYOffset)
		task.delay((idx - 1) * delayStep, function()
			if element and element.Parent then
				TweenService:Create(element, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 0, origYScale, origYOffset)
				}):Play()
			end
		end)
	end
end

return Animations
