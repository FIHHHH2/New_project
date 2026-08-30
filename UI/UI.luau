--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Animations = require(script.Parent.Animations)

local UI = {}
UI.__index = UI

UI.Theme = {
	Background = Color3.fromRGB(15, 15, 17),
	BackgroundTransparency = 0.35,
	Border = Color3.fromRGB(240, 70, 70),
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(160, 160, 165),
	Accent = Color3.fromRGB(235, 65, 65),
	AccentInactive = Color3.fromRGB(45, 45, 50),
	Container = Color3.fromRGB(22, 22, 26),
	ContainerTransparency = 0.5
}

function UI.createWindow(titleText: string): (Frame, Frame, ScrollingFrame, Frame, UIScale)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 680, 0, 440)
	mainFrame.Position = UDim2.new(0.5, -340, 0.5, -220)
	mainFrame.BackgroundColor3 = UI.Theme.Background
	mainFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.Theme.Border
	stroke.Thickness = 1.2
	stroke.Transparency = 0.4
	stroke.Parent = mainFrame
	
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = mainFrame
	
	-- topbar
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, 0, 0, 42)
	topbar.BackgroundTransparency = 1
	topbar.Parent = mainFrame
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 200, 1, 0)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = UI.Theme.TextPrimary
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topbar
	
	-- dragging logic
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector3 = Vector3.zero
	local startPos: UDim2 = UDim2.new()
	
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
	
	-- profile block
	local profileBox = Instance.new("Frame")
	profileBox.Name = "ProfileCard"
	profileBox.Size = UDim2.new(0, 220, 0, 52)
	profileBox.Position = UDim2.new(0, 16, 0, 48)
	profileBox.BackgroundColor3 = UI.Theme.Container
	profileBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	profileBox.Parent = mainFrame
	
	local profCorner = Instance.new("UICorner")
	profCorner.CornerRadius = UDim.new(0, 6)
	profCorner.Parent = profileBox
	
	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "Avatar"
	avatarImage.Size = UDim2.new(0, 40, 0, 40)
	avatarImage.Position = UDim2.new(0, 6, 0, 6)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	avatarImage.Parent = profileBox
	
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatarImage
	
	local userLabel = Instance.new("TextLabel")
	userLabel.Size = UDim2.new(1, -56, 0, 18)
	userLabel.Position = UDim2.new(0, 52, 0, 8)
	userLabel.BackgroundTransparency = 1
	userLabel.Text = Players.LocalPlayer.DisplayName
	userLabel.TextColor3 = UI.Theme.TextPrimary
	userLabel.Font = Enum.Font.GothamBold
	userLabel.TextSize = 13
	userLabel.TextXAlignment = Enum.TextXAlignment.Left
	userLabel.Parent = profileBox
	
	local ageLabel = Instance.new("TextLabel")
	ageLabel.Size = UDim2.new(1, -56, 0, 16)
	ageLabel.Position = UDim2.new(0, 52, 0, 26)
	ageLabel.BackgroundTransparency = 1
	ageLabel.Text = string.format("@%s | age: %d d", Players.LocalPlayer.Name, Players.LocalPlayer.AccountAge)
	ageLabel.TextColor3 = UI.Theme.TextMuted
	ageLabel.Font = Enum.Font.Gotham
	ageLabel.TextSize = 10
	ageLabel.TextXAlignment = Enum.TextXAlignment.Left
	ageLabel.Parent = profileBox
	
	-- sidebar
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 140, 1, -118)
	sidebar.Position = UDim2.new(0, 16, 0, 108)
	sidebar.BackgroundTransparency = 1
	sidebar.ScrollBarThickness = 2
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.Parent = mainFrame
	
	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = sidebar
	
	-- content frame
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, -190, 1, -60)
	contentContainer.Position = UDim2.new(0, 172, 0, 48)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = mainFrame
	
	-- resize handle
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeGrip"
	resizeHandle.Size = UDim2.new(0, 16, 0, 16)
	resizeHandle.Position = UDim2.new(1, -16, 1, -16)
	resizeHandle.BackgroundTransparency = 1
	resizeHandle.Text = "◢"
	resizeHandle.TextColor3 = UI.Theme.TextMuted
	resizeHandle.Font = Enum.Font.GothamBold
	resizeHandle.TextSize = 12
	resizeHandle.Parent = mainFrame
	
	local resizing = false
	local startScale = 1.0
	local resizeStart = Vector2.zero
	
	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			resizeStart = Vector2.new(input.Position.X, input.Position.Y)
			startScale = uiScale.Scale
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
				end
			end)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = (input.Position.X - resizeStart.X) / 400
			local newScale = math.clamp(startScale + delta, 0.6, 1.6)
			uiScale.Scale = newScale
		end
	end)
	
	return mainFrame, topbar, sidebar, contentContainer, uiScale
end

return UI
