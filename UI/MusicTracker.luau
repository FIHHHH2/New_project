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

local LOCAL_BRIDGE_URL = "http://127.0.0.1:8888"
local REMOTE_TUNNEL_URL = "https://steering-liberal-bucks-arrived.trycloudflare.com"
local BRIDGE_URL = LOCAL_BRIDGE_URL
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

	-- Control Buttons (Compact Square Buttons in Correct Order: Prev, Play/Pause, Next)
	local ctrlFrame = Instance.new("Frame")
	ctrlFrame.Name = "Controls"
	ctrlFrame.Size = UDim2.new(0, 88, 1, 0)
	ctrlFrame.Position = UDim2.new(1, -88, 0, 0)
	ctrlFrame.BackgroundTransparency = 1
	ctrlFrame.Parent = bottomControls

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ctrlLayout.Padding = UDim.new(0, 3)
	ctrlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ctrlLayout.Parent = ctrlFrame

	local function makeCtrlBtn(name: string, symbol: string, order: number): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 26, 0, 24)
		btn.BackgroundColor3 = UI.Theme.ContainerDark
		btn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		btn.BorderSizePixel = 0
		btn.Text = symbol
		btn.TextColor3 = UI.Theme.TextPrimary
		btn.Font = UI.Fonts.Header
		btn.TextSize = 11
		btn.LayoutOrder = order
		btn.Parent = ctrlFrame
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

	-- ── Local Bridge & Cloudflare Tunnel Poller (Audio Spectrum, Lyrics, Adaptive Theme) ─
	task.spawn(function()
		local failCount = 0
		while true do
			task.wait(0.1)
			if widget.Visible then
				local ok, raw = pcall(function()
					return game:HttpGet(BRIDGE_URL .. "/current")
				end)
				if not ok or not raw or raw == "" then
					failCount += 1
					if failCount >= 5 then
						BRIDGE_URL = if BRIDGE_URL == LOCAL_BRIDGE_URL then REMOTE_TUNNEL_URL else LOCAL_BRIDGE_URL
						failCount = 0
					end
				else
					failCount = 0
					pcall(function()
						local data = HttpService:JSONDecode(raw)
						if data and data.title then
							if data.spectrum and typeof(data.spectrum) == "table" then
								currentSpectrum = data.spectrum
							end
							if data.audioPeak then
								currentAudioPeak = data.audioPeak
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

							local isIdle = (data.title == "No Song Playing" and not data.isPlaying and currentAudioPeak <= 0.005)
							local coverVersion = data.coverVersion or 0
							if data.title ~= lastSongTitle or coverVersion ~= lastCoverVersion then
								lastSongTitle = data.title
								lastCoverVersion = coverVersion
								if isIdle then
									songTitleLabel.Text = "No Song Playing"
									lyricsLabel.Text = "♫ Waiting for audio session..."
									isPlaying = false
									playBtn.Text = "▶"
									updateCover(nil, true, coverVersion)
								else
									songTitleLabel.Text = string.format("%s — %s", data.title, data.artist or "Unknown")
									if data.lyrics then lyricsLabel.Text = "♫ " .. data.lyrics end
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
									if data.lyrics then lyricsLabel.Text = "♫ " .. data.lyrics end
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
