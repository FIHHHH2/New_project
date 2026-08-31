--!strict
--[=[
    ✦ Animation Suite for Modular Retro UI ✦
    High-performance TweenService helpers for tabs, hovers, clicks, minimizations, and entry animations.
]=]

local TweenService = game:GetService("TweenService")

local Animations = {}
Animations.__index = Animations

export type AnimationConfig = {
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
}

function Animations.tween(instance: Instance, properties: {[string]: any}, config: AnimationConfig?): Tween
	local dur = if config and config.duration then config.duration else 0.15
	local style = if config and config.easingStyle then config.easingStyle else Enum.EasingStyle.Quad
	local dir = if config and config.easingDirection then config.easingDirection else Enum.EasingDirection.Out
	
	local tweenInfo = TweenInfo.new(dur, style, dir)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

-- Attach hover & click feedback to any GuiButton
function Animations.attachButtonEffects(button: GuiButton, getNormalBg: (() -> Color3)?, getHoverBg: (() -> Color3)?, getActiveBg: (() -> Color3)?)
	local stroke = button:FindFirstChildWhichIsA("UIStroke")
	local originalScale = 1.0

	button.MouseEnter:Connect(function()
		if stroke then
			Animations.tween(stroke, { Thickness = 1.8 }, { duration = 0.12 })
		end
		if getHoverBg then
			Animations.tween(button, { BackgroundColor3 = getHoverBg() }, { duration = 0.12 })
		end
	end)

	button.MouseLeave:Connect(function()
		if stroke then
			Animations.tween(stroke, { Thickness = 1.2 }, { duration = 0.12 })
		end
		if getNormalBg then
			Animations.tween(button, { BackgroundColor3 = getNormalBg() }, { duration = 0.12 })
		end
	end)

	button.MouseButton1Down:Connect(function()
		Animations.tween(button, { Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset, button.Size.Y.Scale, button.Size.Y.Offset - 2) }, { duration = 0.08 })
	end)

	button.MouseButton1Up:Connect(function()
		Animations.tween(button, { Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset, button.Size.Y.Scale, button.Size.Y.Offset + 2) }, { duration = 0.12, easingStyle = Enum.EasingStyle.Back })
	end)
end

-- Close GUI with smooth scale/fade collapse
function Animations.closeWindow(frame: GuiObject, onComplete: (() -> ())?)
	local originalSize = frame.Size
	local tween = Animations.tween(frame, {
		Size = UDim2.new(0, frame.AbsoluteSize.X * 0.9, 0, 0),
		BackgroundTransparency = 1
	}, { duration = 0.2, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.In })
	
	tween.Completed:Connect(function()
		frame.Visible = false
		frame.Size = originalSize
		frame.BackgroundTransparency = 0
		if onComplete then onComplete() end
	end)
end

-- Open GUI with smooth unfold
function Animations.openWindow(frame: GuiObject, targetSize: UDim2)
	frame.Size = UDim2.new(0, targetSize.X.Offset, 0, 0)
	frame.Visible = true
	Animations.tween(frame, {
		Size = targetSize
	}, { duration = 0.25, easingStyle = Enum.EasingStyle.Quad, easingDirection = Enum.EasingDirection.Out })
end

return Animations
