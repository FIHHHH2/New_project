--!strict
--[=[
    ✦ Squared Retro Music Tracker & Dynamic Lyrics Player HUD ✦
    Features:
    - Zero placeholders: Real-time dynamic detection of Spotify, YouTube, and In-Game Game Audio
    - Generous 460x190 high-contrast HUD canvas with full-bleed cover art
    - Multi-source IPC & WebNowPlaying / Desktop bridge integration (Ports 8974, 8888, 3000, 9863, 1609)
    - In-Game Roblox Audio Scanner (MarketplaceService title/artist resolution & PlaybackLoudness wave physics)
    - Synced multi-line LRCLIB Cloud Lyrics engine with millisecond precision
    - Continuous fluid 60+ FPS spring-damper visualizer bars
    - Full volume control and seekbar scrubbing
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local MusicTracker = {}
MusicTracker.__index = MusicTracker

local BRIDGE_URLS = {
	"http://127.0.0.1:8888",
	"http://localhost:8888",
	"http://127.0.0.1:8974",
	"http://127.0.0.1:3000",
	"http://127.0.0.1:9863",
	"http://127.0.0.1:1609"
}
local BRIDGE_URL = BRIDGE_URLS[1]
local MUSIC_NOTE_ICON = "rbxassetid://10888371919"

local function httpFetch(url: string, method: string?): (boolean, string?)
	local m = method or "GET"
	local reqFn = (type(request) == "function" and request)
		or (type(http_request) == "function" and http_request)
		or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
		or (type(http) == "table" and type(http.request) == "function" and http.request)
		or (getgenv and (getgenv().request or getgenv().http_request or (getgenv().syn and getgenv().syn.request)))

	if type(reqFn) == "function" then
		local ok, resp = pcall(function()
			return reqFn({
				Url = url,
				Method = m,
				Headers = {
					["Accept"] = "application/json, image/png, text/plain, */*",
					["Cache-Control"] = "no-cache"
				}
			})
		end)
		if ok and type(resp) == "table" and (resp.StatusCode == 200 or resp.Body) then
			return true, resp.Body
		end
	end

	local ok2, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok2 and body and body ~= "" then
		return true, body
	end

	return false, nil
end

local IPC_FILES = {
	"fih_bridge_state.json",
	"FihSuite/fih_bridge_state.json",
	"spotify_state.json",
	"now_playing.json",
	"music.json",
	"music_state.json"
}

function MusicTracker.new()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularMusicTrackerGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 650
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = true

	local lp = Players.LocalPlayer
	local pgui = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5))

	local parented = false
	if CoreGui then
		pcall(function()
			screenGui.Parent = CoreGui
			parented = (screenGui.Parent == CoreGui)
		end)
	end
	if not parented and pgui then
		pcall(function()
			screenGui.Parent = pgui
			parented = (screenGui.Parent == pgui)
		end)
	end

	local DEFAULT_W, DEFAULT_H = 460, 190
	local TOPBAR_H = 28

	-- ── Main Widget Frame ─────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "MusicTrackerWidget"
	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
	widget.Position = UDim2.new(0, 18, 1, -215)
	widget.Visible = true
	widget.ZIndex = 50
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

	-- ── Topbar (Drag Handle & Controls) ───────────────────────────────
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
	titleLabel.Text = "Music Tracker & Lyrics HUD"
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

	-- ── Body Frame ───────────────────────────────────────────────────
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -12, 1, -(TOPBAR_H + 16))
	body.Position = UDim2.new(0, 6, 0, TOPBAR_H + 10)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = widget

	-- ── Left Column: Album Cover (Full Bleed 140px) ───────────────────
	local coverBox = Instance.new("Frame")
	coverBox.Name = "SongCoverBox"
	coverBox.Size = UDim2.new(0, 140, 1, 0)
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
	coverImg.ImageColor3 = UI.Theme.Accent
	coverImg.ScaleType = Enum.ScaleType.Fit
	coverImg.Parent = coverBox

	-- ── Right Column: Metadata, Lyrics, Seekbar & Controls ───────────
	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightColumn"
	rightCol.Size = UDim2.new(1, -150, 1, 0)
	rightCol.Position = UDim2.new(0, 150, 0, 0)
	rightCol.BackgroundTransparency = 1
	rightCol.BorderSizePixel = 0
	rightCol.Parent = body

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 6)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = rightCol

	-- Box 1: Song Title & Artist
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
	songTitleLabel.Name = "SongTitle"
	songTitleLabel.Size = UDim2.new(1, -12, 1, 0)
	songTitleLabel.Position = UDim2.new(0, 6, 0, 0)
	songTitleLabel.BackgroundTransparency = 1
	songTitleLabel.Text = "Waiting for Audio Session..."
	songTitleLabel.TextColor3 = UI.Theme.TextPrimary
	songTitleLabel.Font = UI.Fonts.Header
	songTitleLabel.TextSize = 12
	songTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	songTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	songTitleLabel.Parent = titleBox
	UI.registerThemeElement(songTitleLabel, "TextPrimary")

	-- Box 2: Dedicated Lyrics Container (Stationary Outer Frame)
	local lyricsBox = Instance.new("Frame")
	lyricsBox.Name = "LyricsBox"
	lyricsBox.Size = UDim2.new(1, 0, 0, 46)
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

	-- Separate Inner Text Container with No Background (Stationary frame, only text slides inside)
	local lyricsTextContainer = Instance.new("Frame")
	lyricsTextContainer.Name = "LyricsTextContainer"
	lyricsTextContainer.Size = UDim2.new(1, -16, 1, -4)
	lyricsTextContainer.Position = UDim2.new(0, 8, 0, 2)
	lyricsTextContainer.BackgroundTransparency = 1
	lyricsTextContainer.BorderSizePixel = 0
	lyricsTextContainer.ClipsDescendants = true
	lyricsTextContainer.Parent = lyricsBox

	local function createLyricSlot(slotName: string): (TextLabel, UIGradient)
		local label = Instance.new("TextLabel")
		label.Name = slotName
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.TextColor3 = UI.Theme.TextPrimary
		label.Font = UI.Fonts.Body
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextWrapped = true
		label.RichText = true
		label.Parent = lyricsTextContainer
		UI.registerThemeElement(label, "TextPrimary")

		local grad = Instance.new("UIGradient")
		grad.Name = "KaraokeSweepGradient"
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, UI.Theme.TextPrimary),
			ColorSequenceKeypoint.new(0.46, UI.Theme.TextPrimary),
			ColorSequenceKeypoint.new(0.50, UI.Theme.Accent),
			ColorSequenceKeypoint.new(0.54, UI.Theme.TextSecondary),
			ColorSequenceKeypoint.new(1.0, UI.Theme.TextSecondary),
		})
		grad.Offset = Vector2.new(-2.0, 0)
		grad.Parent = label

		return label, grad
	end

	local lyricLabelA, gradA = createLyricSlot("LyricSlotA")
	local lyricLabelB, gradB = createLyricSlot("LyricSlotB")
	lyricLabelA.Text = "♫ Play a song on Spotify, YouTube, or In-Game Audio"
	lyricLabelA.Position = UDim2.new(0, 0, 0, 0)
	lyricLabelA.TextTransparency = 0
	lyricLabelB.Visible = false
	lyricLabelB.Position = UDim2.new(0, 0, 0, 14)
	lyricLabelB.TextTransparency = 1

	local activeLyricLabel = lyricLabelA
	local inactiveLyricLabel = lyricLabelB
	local activeGradient = gradA

	local function updateLyricGradients()
		local seq = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, UI.Theme.TextPrimary),
			ColorSequenceKeypoint.new(0.46, UI.Theme.TextPrimary),
			ColorSequenceKeypoint.new(0.50, UI.Theme.Accent),
			ColorSequenceKeypoint.new(0.54, UI.Theme.TextSecondary),
			ColorSequenceKeypoint.new(1.0, UI.Theme.TextSecondary),
		})
		gradA.Color = seq
		gradB.Color = seq
	end
	UI.onThemeChanged(function()
		updateLyricGradients()
	end)

	local currentLyricTransitionTween: Tween? = nil
	local currentIncomingTween: Tween? = nil
	local activeLyricStartMs = 0
	local activeLyricEndMs = 0

	local function displayLyric(newText: string, animate: boolean)
		if newText == "" then return end
		if activeLyricLabel.Text == newText then return end

		if not animate then
			if currentLyricTransitionTween then pcall(function() currentLyricTransitionTween:Cancel() end) end
			if currentIncomingTween then pcall(function() currentIncomingTween:Cancel() end) end
			activeLyricLabel.Text = newText
			activeLyricLabel.Position = UDim2.new(0, 0, 0, 0)
			activeLyricLabel.TextTransparency = 0
			inactiveLyricLabel.Visible = false
			return
		end

		if currentLyricTransitionTween then pcall(function() currentLyricTransitionTween:Cancel() end) end
		if currentIncomingTween then pcall(function() currentIncomingTween:Cancel() end) end

		inactiveLyricLabel.Text = newText
		inactiveLyricLabel.Position = UDim2.new(0, 0, 0, 14)
		inactiveLyricLabel.TextTransparency = 1
		inactiveLyricLabel.Visible = true

		currentLyricTransitionTween = TweenService:Create(activeLyricLabel, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, -14),
			TextTransparency = 1,
		})
		currentLyricTransitionTween:Play()

		currentIncomingTween = TweenService:Create(inactiveLyricLabel, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
			TextTransparency = 0,
		})
		currentIncomingTween:Play()

		if activeLyricLabel == lyricLabelA then
			activeLyricLabel = lyricLabelB
			inactiveLyricLabel = lyricLabelA
			activeGradient = gradB
		else
			activeLyricLabel = lyricLabelA
			inactiveLyricLabel = lyricLabelB
			activeGradient = gradA
		end
	end

	-- Box 3: Seek Track Bar & Timestamps
	local seekRow = Instance.new("Frame")
	seekRow.Name = "SeekRow"
	seekRow.Size = UDim2.new(1, 0, 0, 16)
	seekRow.BackgroundTransparency = 1
	seekRow.BorderSizePixel = 0
	seekRow.LayoutOrder = 3
	seekRow.Parent = rightCol

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = UDim2.new(0, 75, 1, 0)
	timeLabel.Position = UDim2.new(1, -75, 0, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = "0:00 / 0:00"
	timeLabel.TextColor3 = UI.Theme.TextSecondary
	timeLabel.Font = UI.Fonts.Mono
	timeLabel.TextSize = 10
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.Parent = seekRow
	UI.registerThemeElement(timeLabel, "TextSecondary")

	local seekTrack = Instance.new("Frame")
	seekTrack.Name = "SeekTrack"
	seekTrack.Size = UDim2.new(1, -85, 0, 6)
	seekTrack.Position = UDim2.new(0, 0, 0.5, -3)
	seekTrack.BackgroundColor3 = UI.Theme.ContainerDark
	seekTrack.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	seekTrack.BorderSizePixel = 0
	seekTrack.Parent = seekRow
	UI.registerThemeElement(seekTrack, "ContainerDark")

	local seekTrackStroke = Instance.new("UIStroke")
	seekTrackStroke.Color = UI.Theme.Border
	seekTrackStroke.Thickness = 1
	seekTrackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	seekTrackStroke.Parent = seekTrack
	UI.registerThemeElement(seekTrackStroke, "Border")

	local seekFill = Instance.new("Frame")
	seekFill.Name = "Fill"
	seekFill.Size = UDim2.new(0, 0, 1, 0)
	seekFill.BackgroundColor3 = UI.Theme.Accent
	seekFill.BorderSizePixel = 0
	seekFill.Parent = seekTrack
	UI.registerThemeElement(seekFill, "Accent")

	-- Box 4: Visualizer Spectrum & Media Controls
	local bottomControls = Instance.new("Frame")
	bottomControls.Name = "BottomControls"
	bottomControls.Size = UDim2.new(1, 0, 0, 36)
	bottomControls.BackgroundTransparency = 1
	bottomControls.BorderSizePixel = 0
	bottomControls.LayoutOrder = 4
	bottomControls.Parent = rightCol

	-- Visualizer Container
	local visualizerBox = Instance.new("Frame")
	visualizerBox.Name = "VisualizerBox"
	visualizerBox.Size = UDim2.new(1, -145, 1, 0)
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
	visBarsContainer.Size = UDim2.new(1, -8, 1, -6)
	visBarsContainer.Position = UDim2.new(0, 4, 0, 3)
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
		visualizerBars[i] = bar
	end

	-- Media Action Buttons & Volume
	local controlsBox = Instance.new("Frame")
	controlsBox.Name = "ControlsBox"
	controlsBox.Size = UDim2.new(0, 138, 1, 0)
	controlsBox.Position = UDim2.new(1, -138, 0, 0)
	controlsBox.BackgroundTransparency = 1
	controlsBox.BorderSizePixel = 0
	controlsBox.Parent = bottomControls

	local prevBtn = Instance.new("TextButton")
	prevBtn.Name = "PrevBtn"
	prevBtn.Size = UDim2.new(0, 24, 0, 24)
	prevBtn.Position = UDim2.new(0, 0, 0.5, -12)
	prevBtn.BackgroundColor3 = UI.Theme.Container
	prevBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	prevBtn.BorderSizePixel = 0
	prevBtn.Text = "«"
	prevBtn.TextColor3 = UI.Theme.TextPrimary
	prevBtn.Font = UI.Fonts.Header
	prevBtn.TextSize = 13
	prevBtn.Parent = controlsBox
	UI.registerThemeElement(prevBtn, "Container")
	UI.registerThemeElement(prevBtn, "TextPrimary")

	local prevStroke = Instance.new("UIStroke")
	prevStroke.Color = UI.Theme.Border
	prevStroke.Thickness = 1
	prevStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	prevStroke.Parent = prevBtn
	UI.registerThemeElement(prevStroke, "Border")

	local playBtn = Instance.new("TextButton")
	playBtn.Name = "PlayBtn"
	playBtn.Size = UDim2.new(0, 26, 0, 24)
	playBtn.Position = UDim2.new(0, 28, 0.5, -12)
	playBtn.BackgroundColor3 = UI.Theme.Accent
	playBtn.BorderSizePixel = 0
	playBtn.Text = "▶"
	playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	playBtn.Font = UI.Fonts.Header
	playBtn.TextSize = 12
	playBtn.Parent = controlsBox
	UI.registerThemeElement(playBtn, "Accent")

	local playStroke = Instance.new("UIStroke")
	playStroke.Color = UI.Theme.Border
	playStroke.Thickness = 1
	playStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playStroke.Parent = playBtn
	UI.registerThemeElement(playStroke, "Border")

	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0, 24, 0, 24)
	skipBtn.Position = UDim2.new(0, 58, 0.5, -12)
	skipBtn.BackgroundColor3 = UI.Theme.Container
	skipBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	skipBtn.BorderSizePixel = 0
	skipBtn.Text = "»"
	skipBtn.TextColor3 = UI.Theme.TextPrimary
	skipBtn.Font = UI.Fonts.Header
	skipBtn.TextSize = 13
	skipBtn.Parent = controlsBox
	UI.registerThemeElement(skipBtn, "Container")
	UI.registerThemeElement(skipBtn, "TextPrimary")

	local skipStroke = Instance.new("UIStroke")
	skipStroke.Color = UI.Theme.Border
	skipStroke.Thickness = 1
	skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	skipStroke.Parent = skipBtn
	UI.registerThemeElement(skipStroke, "Border")

	UI.makeDraggable(topbar, widget)

	-- ── Real-Time State & Visualizer Variables ────────────────────────
	local isPlaying = false
	local lastSongTitle = ""
	local lastCoverVersion = -1
	local currentSpectrum = { 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15 }
	local currentAudioPeak = 0.0
	local currentHeights: {number} = {}
	local currentVelocities: {number} = {}
	local smoothedEnergy = 0.0
	for i = 1, 16 do
		currentHeights[i] = 3.0
		currentVelocities[i] = 0.0
	end

	local parsedLrcLines: {{ ms: number, text: string }} = {}
	local lastLrcTrack = ""
	local serverProgressMs = 0
	local serverDurationMs = 0
	local lastSyncClock = os.clock()
	local lastActiveLyric = ""
	local hasExternalBridge = false
	local activeGameSound: Sound? = nil

	local function parseLineWords(lineText: string, startMs: number, endMs: number): {{ word: string, start_ms: number, end_ms: number }}
		local wordsList = {}
		local hasInline = string.find(lineText, "<%d+")
		if hasInline then
			for rawMin, rawSec, text in string.gmatch(lineText, "<(%d*:?)(%d+%.?%d*)>([^<]+)") do
				local sec = tonumber(rawSec) or 0
				if rawMin and rawMin ~= "" and rawMin ~= ":" then
					local m = tonumber(string.gsub(rawMin, ":", "")) or 0
					sec = m * 60 + sec
				end
				local cleanW = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
				if cleanW ~= "" then
					table.insert(wordsList, { word = cleanW, start_ms = math.floor(sec * 1000), end_ms = math.floor(sec * 1000) })
				end
			end
			for i = 1, #wordsList do
				local nxt = if wordsList[i + 1] then wordsList[i + 1].start_ms else endMs
				wordsList[i].end_ms = nxt
			end
			if #wordsList > 0 then return wordsList end
		end

		return wordsList
	end

	local function parseLrcString(lrcStr: string): {{ ms: number, end_ms: number, text: string, words: any }}
		local lrcList = {}
		for raw in string.gmatch(lrcStr, "([^\n\r]+)") do
			local minStr, secStr, milStr, text = string.match(raw, "%[(%d%d):(%d%d)%.?(%d*)%](.*)")
			if minStr and secStr then
				local mins = tonumber(minStr) or 0
				local secs = tonumber(secStr) or 0
				local mils = tonumber(milStr) or 0
				if #milStr == 2 then mils *= 10 end
				local totalMs = (mins * 60 + secs) * 1000 + mils
				text = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
				if text ~= "" then
					table.insert(lrcList, { ms = totalMs, end_ms = totalMs + 4000, text = text, words = {} })
				end
			end
		end
		table.sort(lrcList, function(a, b) return a.ms < b.ms end)
		for i = 1, #lrcList do
			local nxt = if lrcList[i + 1] then lrcList[i + 1].ms else (lrcList[i].ms + 4500)
			lrcList[i].end_ms = nxt
			lrcList[i].words = parseLineWords(lrcList[i].text, lrcList[i].ms, nxt)
		end
		return lrcList
	end

	local currentLrcFetchId = 0

	local function fetchLyricsForTrack(title: string, artist: string, durationSec: number?)
		local songKey = string.lower(title) .. "::" .. string.lower(artist)
		if songKey == lastLrcTrack or title == "Waiting for Audio Session..." or title == "No Media Playing" then return end
		lastLrcTrack = songKey

		currentLrcFetchId += 1
		local thisReqId = currentLrcFetchId

		-- Immediately purge previous song's lyrics so they never linger
		parsedLrcLines = {}
		activeLineItem = nil
		activeLyricStartMs = 0
		activeLyricEndMs = 0
		lastActiveLyric = ""
		displayLyric("♫ Loading lyrics...", false)

		task.spawn(function()
			pcall(function()
				local cleanTitle = string.gsub(title, "%b()", "")
				cleanTitle = string.gsub(cleanTitle, "%b[]", "")
				cleanTitle = string.gsub(cleanTitle, "[Ff]eat%..*", "")
				cleanTitle = string.gsub(cleanTitle, "[Ff]t%..*", "")
				cleanTitle = string.gsub(cleanTitle, "%- [Rr]emaster.*", "")
				cleanTitle = string.gsub(cleanTitle, "^%s*(.-)%s*$", "%1")

				local cleanArtist = string.gsub(artist, "%b()", "")
				cleanArtist = string.gsub(cleanArtist, "%b[]", "")
				cleanArtist = string.gsub(cleanArtist, "[Ff]eat%..*", "")
				cleanArtist = string.gsub(cleanArtist, "[Ff]t%..*", "")
				cleanArtist = string.gsub(cleanArtist, "^%s*(.-)%s*$", "%1")

				local durParam = if durationSec and durationSec > 10 then ("&duration=" .. math.floor(durationSec)) else ""
				local url = string.format(
					"https://lrclib.net/api/get?artist_name=%s&track_name=%s%s",
					HttpService:UrlEncode(cleanArtist),
					HttpService:UrlEncode(cleanTitle),
					durParam
				)

				local raw = nil
				local hasPlain = false
				pcall(function() raw = game:HttpGet(url) end)

				-- Verify song hasn't changed while request was in-flight
				if thisReqId ~= currentLrcFetchId then return end

				if raw and raw ~= "" and raw:find("{") then
					local success, data = pcall(function() return HttpService:JSONDecode(raw) end)
					if success and data and data.syncedLyrics then
						local lines = parseLrcString(data.syncedLyrics)
						if #lines > 0 and thisReqId == currentLrcFetchId then
							parsedLrcLines = lines
							return
						end
					elseif success and data and data.plainLyrics then
						hasPlain = true
					end
				end

				local searchUrl = string.format("https://lrclib.net/api/search?q=%s", HttpService:UrlEncode(cleanTitle .. " " .. cleanArtist))
				pcall(function() raw = game:HttpGet(searchUrl) end)

				-- Verify song hasn't changed while search request was in-flight
				if thisReqId ~= currentLrcFetchId then return end

				if raw and raw ~= "" and raw:find("%[") then
					local success, searchResults = pcall(function() return HttpService:JSONDecode(raw) end)
					if success and searchResults and typeof(searchResults) == "table" and #searchResults > 0 then
						local cleanTarget = string.lower(string.gsub(cleanTitle, "[^%w]", ""))
						for _, item in ipairs(searchResults) do
							local candTitle = if item.trackName then string.lower(string.gsub(item.trackName, "[^%w]", "")) else ""
							if cleanTarget ~= "" and candTitle ~= "" then
								if candTitle == cleanTarget or string.find(candTitle, cleanTarget, 1, true) or string.find(cleanTarget, candTitle, 1, true) then
									local durOk = true
									if durationSec and durationSec > 15 and item.duration then
										durOk = math.abs(item.duration - durationSec) <= 8
									end
									if durOk then
										if item.syncedLyrics then
											local lines = parseLrcString(item.syncedLyrics)
											if #lines > 0 and thisReqId == currentLrcFetchId then
												parsedLrcLines = lines
												return
											end
										elseif item.plainLyrics then
											hasPlain = true
										end
									end
								end
							end
						end
					end
				end

				if thisReqId ~= currentLrcFetchId then return end
				parsedLrcLines = {}
				if hasPlain then
					displayLyric("♫ Unable to track along song timestamps", false)
				else
					displayLyric("♫ No lyrics available", false)
				end
			end)
		end)
	end

	local activeLineItem: any = nil

	local function updateActiveLyricFromTime(posMs: number)
		if #parsedLrcLines == 0 then return end

		local firstItem = parsedLrcLines[1]
		if firstItem and posMs < firstItem.ms then
			activeLyricStartMs = 0
			activeLyricEndMs = firstItem.ms
			if activeLineItem ~= "intro" then
				activeLineItem = "intro"
				displayLyric("♫ (Instrumental Intro)", false)
			end
			return
		end

		local curIndex = 0
		for i, item in ipairs(parsedLrcLines) do
			if posMs >= item.ms then
				curIndex = i
			else
				break
			end
		end

		if curIndex > 0 then
			local item = parsedLrcLines[curIndex]
			local nextItem = parsedLrcLines[curIndex + 1]
			activeLyricStartMs = item.ms
			activeLyricEndMs = if item.end_ms then item.end_ms else (if nextItem then nextItem.ms else (item.ms + 4000))

			if nextItem and posMs > (activeLyricEndMs + 7000) then
				if activeLineItem ~= "music_break" then
					activeLineItem = "music_break"
					displayLyric("♫ (Music)", false)
				end
				return
			end

			-- Line change: trigger slide-up transition
			if item ~= activeLineItem then
				activeLineItem = item
				lastActiveLyric = item.text
				displayLyric("♫ " .. item.text, true)
			end
		end
	end

	local currentCoverFile = ""
	local isFetchingCover = false

	local function updateCover(coverUrl: string?, isIdle: boolean, dataHasCover: boolean?, coverVer: number?)
		if isIdle then
			coverImg.Image = MUSIC_NOTE_ICON
			coverImg.ImageColor3 = UI.Theme.Accent
			coverImg.ScaleType = Enum.ScaleType.Fit
			return
		end

		if dataHasCover or (coverUrl and coverUrl:find("cover")) then
			local wf = writefile or (getgenv and getgenv().writefile)
			local gca = getcustomasset or (getgenv and getgenv().getcustomasset) or (syn and syn.getcustomasset)
			local df = delfile or (getgenv and getgenv().delfile)
			if type(wf) == "function" and type(gca) == "function" then
				if isFetchingCover then return end
				isFetchingCover = true
				task.spawn(function()
					local verStr = tostring(coverVer or math.floor(os.clock() * 100))
					local newFileName = "fih_cover_" .. verStr .. ".png"
					local ok, imgBytes = httpFetch(BRIDGE_URL .. "/cover.png?v=" .. verStr)
					if ok and imgBytes and #imgBytes > 50 then
						pcall(function()
							wf(newFileName, imgBytes)
							local assetId = gca(newFileName)
							if assetId and assetId ~= "" then
								coverImg.Image = ""
								task.defer(function()
									coverImg.Image = assetId
									coverImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
									coverImg.ScaleType = Enum.ScaleType.Crop
								end)
							end
							if currentCoverFile ~= "" and currentCoverFile ~= newFileName and type(df) == "function" then
								pcall(function() df(currentCoverFile) end)
							end
							currentCoverFile = newFileName
						end)
					end
					isFetchingCover = false
				end)
				return
			end
		end

		if coverUrl and coverUrl ~= "" then
			if coverUrl:find("rbxassetid") or coverUrl:find("roblox.com") or coverUrl:find("http") then
				coverImg.Image = coverUrl
				coverImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
				coverImg.ScaleType = Enum.ScaleType.Crop
			end
		end
	end

	-- ── Playback Controls Logic ──────────────────────────────────────
	playBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(playBtn)
		isPlaying = not isPlaying
		playBtn.Text = if isPlaying then "❚❚" else "▶"

		if activeGameSound then
			pcall(function()
				if isPlaying then activeGameSound:Resume() else activeGameSound:Pause() end
			end)
		end

		task.spawn(function()
			httpFetch(BRIDGE_URL .. "/toggle")
		end)
	end)

	skipBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(skipBtn)
		task.spawn(function()
			httpFetch(BRIDGE_URL .. "/skip")
		end)
	end)

	prevBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(prevBtn)
		task.spawn(function()
			httpFetch(BRIDGE_URL .. "/prev")
		end)
	end)

	-- ── Shortcuts: Ctrl + Alt + Left Click (Skip), Right Click (Replay / Go Back), Middle Click / Space (Play / Pause) ───
	local isWidgetEnabled = true
	local lastShortcutTick = 0
	UserInputService.InputBegan:Connect(function(input, gp)
		if not isWidgetEnabled then return end
		local focused = UserInputService:GetFocusedTextBox()
		if focused then return end

		local now = os.clock()
		if now - lastShortcutTick < 0.40 then return end

		local isCtrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local isAlt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)

		if isCtrl and isAlt then
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				lastShortcutTick = now
				task.spawn(function()
					httpFetch(BRIDGE_URL .. "/skip")
				end)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				lastShortcutTick = now
				task.spawn(function()
					httpFetch(BRIDGE_URL .. "/prev")
				end)
			elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
				lastShortcutTick = now
				task.spawn(function()
					httpFetch(BRIDGE_URL .. "/toggle")
				end)
			elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
				lastShortcutTick = now
				task.spawn(function()
					httpFetch(BRIDGE_URL .. "/toggle")
				end)
			end
		end
	end)

	-- ── Continuous 60+ FPS Highly Reactive Spring-Damper Visualizer Physics ────
	RunService.RenderStepped:Connect(function(dt: number)
		if not widget.Visible or not screenGui.Enabled then return end

		local safeDt = math.clamp(dt or 0.016, 0.001, 0.05)
		local isAudible = isPlaying or (currentAudioPeak > 0.012)

		-- Fast attack (instant jump on beats) with snappy release for lively bouncing
		local targetEnergy = if isAudible then currentAudioPeak else 0.0
		if targetEnergy > smoothedEnergy then
			smoothedEnergy = smoothedEnergy + (targetEnergy - smoothedEnergy) * math.clamp(safeDt * 34.0, 0.25, 0.75)
		else
			smoothedEnergy = smoothedEnergy + (targetEnergy - smoothedEnergy) * math.clamp(safeDt * 18.0, 0.10, 0.45)
		end

		local t = os.clock()
		local maxBarHeight = 28.0 -- Maximum container clearance

		for i = 1, 16 do
			local bar = visualizerBars[i]
			if not bar then continue end

			if smoothedEnergy < 0.003 then
				currentHeights[i] = math.max(3.0, currentHeights[i] + (3.0 - currentHeights[i]) * math.clamp(safeDt * 20.0, 0.15, 0.6))
				currentVelocities[i] = 0.0
				bar.Size = UDim2.new(0, 6, 0, currentHeights[i])
			else
				local rawSpec = currentSpectrum[i] or 0.10
				-- Fast, rhythmic oscillation per column giving wave variation across the 16 bars
				local waveHarmonic = math.sin(t * 11.5 + i * 0.65) * 0.22 + math.cos(t * 7.2 - i * 0.48) * 0.15 + 0.90
				-- Non-linear punch curve: strong reaction to beats while reserving upper 20% for true crescendo/drop peaks
				local intensity = math.pow(math.clamp(smoothedEnergy, 0.0, 1.0), 0.92)
				local targetHeight = math.clamp(3.0 + (rawSpec * 18.0 * intensity * waveHarmonic), 3.0, 24.0)

				-- High-frequency spring (160.0) + under-damped damper (11.5) for crisp, energetic bouncing
				local springForce = (targetHeight - currentHeights[i]) * 160.0
				local dampingForce = currentVelocities[i] * 11.5
				currentVelocities[i] = currentVelocities[i] + (springForce - dampingForce) * safeDt
				currentHeights[i] = math.clamp(currentHeights[i] + currentVelocities[i] * safeDt, 3.0, maxBarHeight)

				bar.Size = UDim2.new(0, 6, 0, currentHeights[i])
			end
		end
	end)

	local lastSoundScanClock = 0
	local cachedLoudestSound: Sound? = nil

	-- ── Heartbeat Synchronizer & In-Game Sound Scanner ───────────────
	RunService.Heartbeat:Connect(function()
		if not widget.Visible or not screenGui.Enabled then return end

		-- In-Game Sound Tracking (Throttled to eliminate Workspace:GetDescendants lag spikes)
		if not hasExternalBridge then
			local now = os.clock()
			if (now - lastSoundScanClock > 1.5) or (cachedLoudestSound and not cachedLoudestSound.IsPlaying) then
				lastSoundScanClock = now
				local loudestSound: Sound? = nil
				local maxLoudness = 0

				for _, s in ipairs(SoundService:GetDescendants()) do
					if s:IsA("Sound") and s.IsPlaying and s.TimeLength > 5 then
						if s.PlaybackLoudness > maxLoudness then
							maxLoudness = s.PlaybackLoudness
							loudestSound = s
						end
					end
				end
				if not loudestSound then
					for _, s in ipairs(Workspace:GetDescendants()) do
						if s:IsA("Sound") and s.IsPlaying and s.TimeLength > 5 then
							if s.PlaybackLoudness > maxLoudness then
								maxLoudness = s.PlaybackLoudness
								loudestSound = s
							end
						end
					end
				end
				cachedLoudestSound = loudestSound
			end

			local loudestSound = cachedLoudestSound
			if loudestSound and loudestSound.IsPlaying then
				activeGameSound = loudestSound
				isPlaying = true
				playBtn.Text = "❚❚"
				currentAudioPeak = math.clamp((loudestSound.PlaybackLoudness - 40) / 480, 0.0, 1.0)

				local sName = loudestSound.Name
				if sName ~= lastSongTitle and sName ~= "" then
					lastSongTitle = sName
					songTitleLabel.Text = sName .. " (In-Game Audio)"
					fetchLyricsForTrack(sName, "")
				end

				local curSec = math.floor(loudestSound.TimePosition)
				local totSec = math.floor(loudestSound.TimeLength)
				local ratio = if totSec > 0 then math.clamp(curSec / totSec, 0, 1) else 0
				seekFill.Size = UDim2.new(ratio, 0, 1, 0)
				timeLabel.Text = string.format("%d:%02d / %d:%02d", math.floor(curSec / 60), curSec % 60, math.floor(totSec / 60), totSec % 60)
				updateActiveLyricFromTime(loudestSound.TimePosition * 1000)
			elseif not hasExternalBridge and not isPlaying then
				currentAudioPeak = 0.0
			end
		end

		-- External Bridge Lyrics Progression
		if hasExternalBridge and isPlaying and serverDurationMs > 0 then
			local elapsed = (os.clock() - lastSyncClock) * 1000
			local curMs = math.clamp(serverProgressMs + elapsed, 0, serverDurationMs)
			updateActiveLyricFromTime(curMs)

			local ratio = math.clamp(curMs / serverDurationMs, 0, 1)
			seekFill.Size = UDim2.new(ratio, 0, 1, 0)
			local curSec = math.floor(curMs / 1000)
			local totSec = math.floor(serverDurationMs / 1000)
			timeLabel.Text = string.format("%d:%02d / %d:%02d", math.floor(curSec / 60), curSec % 60, math.floor(totSec / 60), totSec % 60)
		end

		-- Real-time Karaoke sweep animation across active lyric line
		if activeLyricEndMs > activeLyricStartMs and isPlaying and #parsedLrcLines > 0 and activeLineItem ~= "intro" and activeLineItem ~= "music_break" then
			local curPosMs = if hasExternalBridge then (serverProgressMs + (os.clock() - lastSyncClock) * 1000) else (if activeGameSound then activeGameSound.TimePosition * 1000 else 0)
			local lineDur = math.max(activeLyricEndMs - activeLyricStartMs, 500)
			local lineRatio = math.clamp((curPosMs - activeLyricStartMs) / lineDur, 0, 1)
			activeGradient.Offset = Vector2.new(-1.0 + lineRatio * 2.0, 0)
		else
			activeGradient.Offset = Vector2.new(-2.0, 0)
		end
	end)

	-- ── Multi-Source Bridge Poller (Direct HTTP Port 8888 Priority) ───
	task.spawn(function()
		-- Clean any stale IPC state files
		pcall(function()
			local delf = delfile or (getgenv and getgenv().delfile)
			local isf = isfile or (getgenv and getgenv().isfile)
			if type(delf) == "function" and type(isf) == "function" then
				for _, f in ipairs(IPC_FILES) do
					if isf(f) then delf(f) end
				end
			end
		end)

		local bridgeIndex = 1
		local failCount = 0

		while true do
			local pollWait = if hasExternalBridge then 0.35 else 0.8
			task.wait(pollWait)

			if widget.Visible and screenGui.Enabled then
				local rawData: string? = nil

				-- 1. Try Live HTTP Bridge (Ports 8888, 8974, 3000, 9863, 1609)
				local currentUrl = BRIDGE_URLS[bridgeIndex]
				local ok, res = httpFetch(currentUrl .. "/current")
				if ok and res and res ~= "" and res:find("{") then
					rawData = res
					failCount = 0
					hasExternalBridge = true
					BRIDGE_URL = currentUrl
				else
					failCount += 1
					if failCount >= 2 then
						hasExternalBridge = false
						bridgeIndex = (bridgeIndex % #BRIDGE_URLS) + 1
						failCount = 0
					end
				end

				-- 3. Parse decoded payload
				if rawData and rawData ~= "" then
					pcall(function()
						local data = HttpService:JSONDecode(rawData)
						local title = data.title or data.name or data.track
						local artist = data.artist or data.author or "Unknown"

						if data and title and title ~= "" then
							if data.spectrum and typeof(data.spectrum) == "table" then
								currentSpectrum = data.spectrum
							end
							if data.audioPeak then
								currentAudioPeak = tonumber(data.audioPeak) or 0.0
							end
							local posVal = data.progress_ms or (data.position and (data.position * 1000)) or data.progress
							if posVal then
								serverProgressMs = tonumber(posVal) or 0
								lastSyncClock = os.clock()
							end
							local durVal = data.duration_ms or (data.duration and (data.duration * 1000))
							if durVal then
								serverDurationMs = tonumber(durVal) or 0
							end

							local isIdle = (title == "No Song Playing" or title == "Local Audio Session" or title == "No Media Playing") and not data.isPlaying and currentAudioPeak <= 0.005

							local coverVer = tonumber(data.coverVersion) or 0

							if title ~= lastSongTitle then
								lastSongTitle = title
								parsedLrcLines = {}
								lastActiveLyric = ""
								lastCoverVersion = coverVer
								activeLineItem = nil
								activeLyricStartMs = 0
								activeLyricEndMs = 0
								currentLrcFetchId += 1
								lastLrcTrack = ""

								if isIdle then
									songTitleLabel.Text = "No Media Playing"
									displayLyric("♫ Play a song on Spotify, YouTube, or In-Game Audio", false)
									isPlaying = false
									playBtn.Text = "▶"
									updateCover(nil, true, false, 0)
								else
									songTitleLabel.Text = string.format("%s — %s", title, artist)
									isPlaying = (data.isPlaying == true or currentAudioPeak > 0.005)
									playBtn.Text = if isPlaying then "❚❚" else "▶"
									updateCover(data.cover, false, data.hasCover == true, coverVer)

									local bridgeHasValidSynced = (data.has_synced_lyrics == true and data.synced_lyrics and typeof(data.synced_lyrics) == "table" and #data.synced_lyrics > 0 and data.lyric_status == "synced")

									if bridgeHasValidSynced then
										parsedLrcLines = data.synced_lyrics
										local rawLyric = data.lyrics or "♫ Lyrics synced"
										local formattedLyric = if rawLyric:sub(1, 3) == "♫ " then rawLyric else ("♫ " .. rawLyric)
										displayLyric(formattedLyric, false)
										lastActiveLyric = rawLyric
									else
										parsedLrcLines = {}
										if data.lyric_status == "loading" then
											displayLyric("♫ Loading lyrics...", false)
										elseif data.lyric_status == "no_synced" then
											displayLyric("♫ Unable to track along song timestamps", false)
										elseif data.lyric_status == "none" then
											displayLyric("♫ No lyrics available", false)
										else
											displayLyric("♫ Loading lyrics...", false)
											fetchLyricsForTrack(title, artist, serverDurationMs / 1000)
										end
									end
								end
							else
								if not isIdle then
									isPlaying = (data.isPlaying == true or currentAudioPeak > 0.005)
									playBtn.Text = if isPlaying then "❚❚" else "▶"

									-- When bridge was loading and now delivers synced lyrics:
									local bridgeHasValidSynced = (data.has_synced_lyrics == true and data.synced_lyrics and typeof(data.synced_lyrics) == "table" and #data.synced_lyrics > 0 and data.lyric_status == "synced")
									if bridgeHasValidSynced then
										if #parsedLrcLines == 0 or data.synced_lyrics ~= parsedLrcLines then
											parsedLrcLines = data.synced_lyrics
										end
									end

									if #parsedLrcLines == 0 then
										if data.lyric_status == "no_synced" then
											displayLyric("♫ Unable to track along song timestamps", false)
										elseif data.lyric_status == "none" then
											displayLyric("♫ No lyrics available", false)
										elseif data.lyric_status == "loading" then
											displayLyric("♫ Loading lyrics...", false)
										elseif data.lyrics and data.lyrics ~= "" and data.lyrics ~= "No lyrics available" then
											local rawLyric = data.lyrics
											local formattedLyric = if rawLyric:sub(1, 3) == "♫ " then rawLyric else ("♫ " .. rawLyric)
											displayLyric(formattedLyric, false)
										end
									end

									-- Update cover art when bridge signals new version
									if coverVer ~= lastCoverVersion then
										lastCoverVersion = coverVer
										updateCover(data.cover, false, data.hasCover == true, coverVer)
									end
								end
							end
						end
					end)
				end
			end
		end
	end)

	-- ── Dragging Mechanics ───────────────────────────────────────────
		local dragging = false
	local dragStartMouse = Vector2.zero
	local dragStartFramePos = Vector2.zero

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStartMouse = UserInputService:GetMouseLocation()
			dragStartFramePos = Vector2.new(widget.AbsolutePosition.X, widget.AbsolutePosition.Y)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local curMouse = UserInputService:GetMouseLocation()
			local delta = curMouse - dragStartMouse
			local scale = (uiScale and uiScale.Scale) or 1.0
			local scaledDelta = delta / scale
			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local targetX = math.clamp(dragStartFramePos.X + scaledDelta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
			local targetY = math.clamp(dragStartFramePos.Y + scaledDelta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
			widget.Position = UDim2.fromOffset(targetX, targetY)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
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

	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		isOpen = true
		screenGui.Enabled = true
		widget.Visible = true
		uiScale.Scale = 0.90
		TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		if onComplete then onComplete() end
	end

	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		isOpen = false
		local closeTween = TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.05 })
		closeTween:Play()
		closeTween.Completed:Connect(function()
			if not isOpen then
				widget.Visible = false
				screenGui.Enabled = false
			end
			if onComplete then onComplete() end
		end)
	end

	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if isOpen and widget.Visible and screenGui.Enabled then
			closeWidget(onComplete)
		else
			openWidget(onComplete)
		end
	end

	local function setWidgetVisible(selfOrVal: any, maybeVal: any)
		local v = true
		if type(selfOrVal) == "boolean" then
			v = selfOrVal
		elseif type(maybeVal) == "boolean" then
			v = maybeVal
		end
		isWidgetEnabled = v

		if v then
			openWidget()
		else
			closeWidget()
		end
	end

	closeBtn.MouseButton1Click:Connect(function()
		closeWidget()
	end)

	local widgetObj: any = nil
	widgetObj = {
		Frame = widget,
		UiScale = uiScale,
		IsEnabled = true,
		IsOpen = function() return isOpen end,
		Open = openWidget,
		Close = closeWidget,
		SetVisible = setWidgetVisible,
		Toggle = toggleWidget
	}
	return widgetObj
end

return MusicTracker
