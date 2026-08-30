--!strict
local TweenService = game:GetService("TweenService")

local Animations = {}
Animations.__index = Animations

export type AnimationConfig = {
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
}

function Animations.tween(instance: Instance, properties: {[string]: any}, config: AnimationConfig?): Tween
	local dur = if config and config.duration then config.duration else 0.25
	local style = if config and config.easingStyle then config.easingStyle else Enum.EasingStyle.Quad
	local dir = if config and config.easingDirection then config.easingDirection else Enum.EasingDirection.Out
	
	local tweenInfo = TweenInfo.new(dur, style, dir)
	local tween = TweenService:Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

function Animations.bindHover(button: GuiButton, hoverProps: {[string]: any}, defaultProps: {[string]: any}, config: AnimationConfig?)
	button.MouseEnter:Connect(function()
		Animations.tween(button, hoverProps, config)
	end)
	button.MouseLeave:Connect(function()
		Animations.tween(button, defaultProps, config)
	end)
end

function Animations.fadeToggle(indicator: GuiObject, state: boolean, activeColor: Color3, inactiveColor: Color3, config: AnimationConfig?)
	local targetColor = if state then activeColor else inactiveColor
	local targetTransparency = if state then 0 else 0.4
	Animations.tween(indicator, {
		BackgroundColor3 = targetColor,
		BackgroundTransparency = targetTransparency
	}, config)
end

function Animations.pulse(instance: GuiObject, scaleTarget: number, duration: number?)
	local dur = duration or 0.12
	local originalSize = instance.Size
	local expandTween = TweenService:Create(instance, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(originalSize.X.Scale * scaleTarget, originalSize.X.Offset * scaleTarget, originalSize.Y.Scale * scaleTarget, originalSize.Y.Offset * scaleTarget)
	})
	expandTween:Play()
	expandTween.Completed:Connect(function()
		TweenService:Create(instance, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = originalSize
		}):Play()
	end)
end

return Animations
