--!strict
--[=[
    ✦ Music Tracker UI Widget with Audio Visualizer & Lyrics ✦
    Features: Song Cover, Song Title & Artist, Lyrics display, Audio Visualizer,
    Playback controls (Skip, Pause/Play, Go Back), and Local Media Bridge client.
]=]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local UI = require("UI/UI.luau")

local MusicTracker = {}
MusicTracker.__index = MusicTracker

local BRIDGE_URL = "http://127.0.0.1:8888"

-- Built-in demo playlist when external bridge is offline
local DEMO_TRACKS = {
	{
		title = "Starboy",
		artist = "The Weeknd ft. Daft Punk",
		cover = "rbxassetid://13470984852",
		lyrics = "Look what you've done, I'm a motherfuckin' starboy"
	},
	{
		title = "Blinding Lights",
		artist = "The Weeknd",
		cover = "rbxassetid://13470984852",
		lyrics = "I said, ooh, I'm blinded by the lights"
	},
	{
		title = "After Hours",
		artist = "The Weeknd",
		cover = "rbxassetid://13470984852",
		lyrics = "Where are you now when I need you most?"
	}
}

function MusicTracker.new()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularMusicTrackerGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local DEFAULT_W, DEFAULT_H = 390, 160
	local TOPBAR_H = 26

	-- ── Main Widget Frame ─────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "MusicTrackerWidget"
	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
	widget.Position = UDim2.new(0, 14, 1, -180)
	widget.BackgroundColor3 = UI.Theme.Background
	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
	widget.BorderSizePixel = 0
	widget.ClipsDescendants = false
	widget.Parent = screenGui
	UI.registerThemeElement(widget, "Background")

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 1.5
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = widget
	UI.registerThemeElement(outerStroke, "Border")

	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
	topbar.Position = UDim2.new(0, 0, 0, 0)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = widget
	UI.registerThemeElement(topbar, "Container")

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = UI.Theme.Border
	topStroke.Thickness = 1.2
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

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn
	UI.registerThemeElement(closeStroke, "Border")

	-- ── Body Frame ───────────────────────────────────────────────────
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -12, 1, -34)
	body.Position = UDim2.new(0, 6, 0, 30)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = widget

	-- ── Left Column: Song Cover ──────────────────────────────────────
	local coverBox = Instance.new("Frame")
	coverBox.Name = "SongCoverBox"
	coverBox.Size = UDim2.new(0, 118, 1, 0)
	coverBox.Position = UDim2.new(0, 0, 0, 0)
	coverBox.BackgroundColor3 = UI.Theme.ContainerDark
	coverBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	coverBox.BorderSizePixel = 0
	coverBox.ClipsDescendants = true
	coverBox.Parent = body
	UI.registerThemeElement(coverBox, "ContainerDark")

	local coverStroke = Instance.new("UIStroke")
	coverStroke.Color = UI.Theme.Border
	coverStroke.Thickness = 1.2
	coverStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	coverStroke.Parent = coverBox
	UI.registerThemeElement(coverStroke, "Border")

	local coverImg = Instance.new("ImageLabel")
	coverImg.Name = "CoverImage"
	coverImg.Size = UDim2.new(1, -4, 1, -4)
	coverImg.Position = UDim2.new(0, 2, 0, 2)
	coverImg.BackgroundTransparency = 1
	coverImg.Image = "rbxassetid://13470984852"
	coverImg.ScaleType = Enum.ScaleType.Fit
	coverImg.Parent = coverBox

	-- ── Right Column: Stack (Title, Lyrics, Visualizer & Controls) ────
	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightColumn"
	rightCol.Size = UDim2.new(1, -126, 1, 0)
	rightCol.Position = UDim2.new(0, 126, 0, 0)
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
	titleBox.Size = UDim2.new(1, 0, 0, 28)
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
	songTitleLabel.Name = "SongTitleText"
	songTitleLabel.Size = UDim2.new(1, -12, 1, 0)
	songTitleLabel.Position = UDim2.new(0, 6, 0, 0)
	songTitleLabel.BackgroundTransparency = 1
	songTitleLabel.Text = "Starboy — The Weeknd"
	songTitleLabel.TextColor3 = UI.Theme.TextPrimary
	songTitleLabel.Font = UI.Fonts.Header
	songTitleLabel.TextSize = 11
	songTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	songTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	songTitleLabel.Parent = titleBox
	UI.registerThemeElement(songTitleLabel, "TextPrimary")

	-- Box 2: Lyrics
	local lyricsBox = Instance.new("Frame")
	lyricsBox.Name = "LyricsBox"
	lyricsBox.Size = UDim2.new(1, 0, 0, 36)
	lyricsBox.BackgroundColor3 = UI.Theme.Container
	lyricsBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	lyricsBox.BorderSizePixel = 0
	lyricsBox.LayoutOrder = 2
	lyricsBox.Parent = rightCol
	UI.registerThemeElement(lyricsBox, "Container")

	local lyricsStroke = Instance.new("UIStroke")
	lyricsStroke.Color = UI.Theme.Border
	lyricsStroke.Thickness = 1
	lyricsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	lyricsStroke.Parent = lyricsBox
	UI.registerThemeElement(lyricsStroke, "Border")

	local lyricsLabel = Instance.new("TextLabel")
	lyricsLabel.Name = "LyricsText"
	lyricsLabel.Size = UDim2.new(1, -12, 1, 0)
	lyricsLabel.Position = UDim2.new(0, 6, 0, 0)
	lyricsLabel.BackgroundTransparency = 1
	lyricsLabel.Text = "♫ Look what you've done, I'm a starboy"
	lyricsLabel.TextColor3 = UI.Theme.TextSecondary
	lyricsLabel.Font = UI.Fonts.Mono
	lyricsLabel.TextSize = 10
	lyricsLabel.TextXAlignment = Enum.TextXAlignment.Left
	lyricsLabel.TextTruncate = Enum.TextTruncate.AtEnd
	lyricsLabel.Parent = lyricsBox
	UI.registerThemeElement(lyricsLabel, "TextSecondary")

	-- Box 3: Audio Visualizer & Playback Controls
	local visualizerBox = Instance.new("Frame")
	visualizerBox.Name = "AudioVisualizerBox"
	visualizerBox.Size = UDim2.new(1, 0, 0, 48)
	visualizerBox.BackgroundColor3 = UI.Theme.Container
	visualizerBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	visualizerBox.BorderSizePixel = 0
	visualizerBox.LayoutOrder = 3
	visualizerBox.Parent = rightCol
	UI.registerThemeElement(visualizerBox, "Container")

	local visStroke = Instance.new("UIStroke")
	visStroke.Color = UI.Theme.Border
	visStroke.Thickness = 1
	visStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	visStroke.Parent = visualizerBox
	UI.registerThemeElement(visStroke, "Border")

	-- Visualizer Spectrum Bars Area
	local barsFrame = Instance.new("Frame")
	barsFrame.Name = "SpectrumBars"
	barsFrame.Size = UDim2.new(1, -94, 1, -8)
	barsFrame.Position = UDim2.new(0, 6, 0, 4)
	barsFrame.BackgroundTransparency = 1
	barsFrame.BorderSizePixel = 0
	barsFrame.Parent = visualizerBox

	local barsLayout = Instance.new("UIListLayout")
	barsLayout.FillDirection = Enum.FillDirection.Horizontal
	barsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	barsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	barsLayout.Padding = UDim.new(0, 3)
	barsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barsLayout.Parent = barsFrame

	local BAR_COUNT = 16
	local visualizerBars: {Frame} = {}
	for i = 1, BAR_COUNT do
		local bar = Instance.new("Frame")
		bar.Name = "Bar_" .. i
		bar.Size = UDim2.new(0, 6, 0, 8)
		bar.BackgroundColor3 = UI.Theme.Accent
		bar.BorderSizePixel = 0
		bar.LayoutOrder = i
		bar.Parent = barsFrame
		UI.registerThemeElement(bar, "Accent")
		table.insert(visualizerBars, bar)
	end

	-- Control Buttons Area
	local controlsFrame = Instance.new("Frame")
	controlsFrame.Name = "ControlsFrame"
	controlsFrame.Size = UDim2.new(0, 82, 1, -8)
	controlsFrame.Position = UDim2.new(1, -86, 0, 4)
	controlsFrame.BackgroundTransparency = 1
	controlsFrame.BorderSizePixel = 0
	controlsFrame.Parent = visualizerBox

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ctrlLayout.Padding = UDim.new(0, 4)
	ctrlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ctrlLayout.Parent = controlsFrame

	local function makeCtrlBtn(name: string, text: string, order: number): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 24, 0, 24)
		btn.BackgroundColor3 = UI.Theme.ContainerDark
		btn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextColor3 = UI.Theme.TextPrimary
		btn.Font = UI.Fonts.Mono
		btn.TextSize = 10
		btn.LayoutOrder = order
		btn.Parent = controlsFrame
		UI.registerThemeElement(btn, "ContainerDark")
		UI.registerThemeElement(btn, "TextPrimary")

		local stroke = Instance.new("UIStroke")
		stroke.Color = UI.Theme.Border
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn
		UI.registerThemeElement(stroke, "Border")

		btn.MouseEnter:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.8 }):Play()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1 }):Play()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)

		return btn
	end

	local prevBtn = makeCtrlBtn("PrevBtn", "<<", 1)
	local playBtn = makeCtrlBtn("PlayBtn", "||", 2)
	local skipBtn = makeCtrlBtn("SkipBtn", ">>", 3)

	-- ── Real-Time Audio Visualizer Loop ──────────────────────────────
	local isPlaying = true
	local currentTrackIndex = 1

	local function setTrack(t)
		songTitleLabel.Text = string.format("%s — %s", t.title, t.artist)
		lyricsLabel.Text = "♫ " .. t.lyrics
		if t.cover and t.cover ~= "" then
			coverImg.Image = t.cover
		end
	end

	setTrack(DEMO_TRACKS[currentTrackIndex])

	local visualizerConn = RunService.RenderStepped:Connect(function()
		if not widget.Visible or not isPlaying then
			for _, bar in ipairs(visualizerBars) do
				bar.Size = UDim2.new(0, 6, 0, 4)
			end
			return
		end

		local t = tick()
		for i, bar in ipairs(visualizerBars) do
			local freq = (i * 0.8) + (t * 6)
			local h1 = math.abs(math.sin(freq))
			local h2 = math.abs(math.cos(freq * 1.5))
			local combined = math.clamp((h1 * 0.6 + h2 * 0.4) * 36, 4, 38)
			bar.Size = UDim2.new(0, 6, 0, combined)
		end
	end)

	-- ── Playback Controls Logic ──────────────────────────────────────
	playBtn.MouseButton1Click:Connect(function()
		isPlaying = not isPlaying
		playBtn.Text = if isPlaying then "||" else ">"
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

	-- ── Local Bridge Poller (Spotify / SoundCloud / YouTube) ──────────
	task.spawn(function()
		while true do
			task.wait(1.5)
			if widget.Visible then
				pcall(function()
					local raw = game:HttpGet(BRIDGE_URL .. "/current")
					if raw and raw ~= "" then
						local data = HttpService:JSONDecode(raw)
						if data and data.title then
							songTitleLabel.Text = string.format("%s — %s", data.title, data.artist or "Unknown")
							if data.lyrics then lyricsLabel.Text = "♫ " .. data.lyrics end
							if data.cover then coverImg.Image = data.cover end
							if data.isPlaying ~= nil then
								isPlaying = data.isPlaying
								playBtn.Text = if isPlaying then "||" else ">"
							end
						end
					end
				end)
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
			local vpSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
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

	closeBtn.MouseButton1Click:Connect(function()
		local closeTween = TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, widget.AbsoluteSize.X * 0.9, 0, 0),
			BackgroundTransparency = 1
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			widget.Visible = false
			widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
			widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
		end)
	end)

	return {
		Frame = widget,
		SetVisible = function(visible: boolean)
			widget.Visible = visible
		end,
		Toggle = function()
			widget.Visible = not widget.Visible
		end,
		Destroy = function()
			pcall(function() visualizerConn:Disconnect() end)
			pcall(function() screenGui:Destroy() end)
		end
	}
end

return MusicTracker
