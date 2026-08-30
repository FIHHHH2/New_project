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
	local dur = if config and config.duration then config.duration else 0.15
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
	Animations.tween(indicator, {
		BackgroundColor3 = targetColor
	}, config or { duration = 0.12 })
end

return Animations
