-- ═══════════════════════════════════════════════════════════
--  MM2 Coin Autofarm  ·  macOS-style UI
-- ═══════════════════════════════════════════════════════════

-- SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

-- VARIABLES
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local visitedPositions = {}
local isActive = false
local flySpeed = 15
local collected = 0
local startTime = 0
local antiAFK = false

player.CharacterAdded:Connect(function(char)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart")
	visitedPositions = {}
end)

-- ─────────────────────────────────────────────
--  THEME + HELPERS
-- ─────────────────────────────────────────────
local COL = {
	bg      = Color3.fromRGB(22, 22, 30),
	card    = Color3.fromRGB(33, 33, 44),
	cardHov = Color3.fromRGB(41, 41, 55),
	off     = Color3.fromRGB(45, 45, 60),
	border  = Color3.fromRGB(48, 48, 64),
	text    = Color3.fromRGB(236, 236, 246),
	muted   = Color3.fromRGB(140, 140, 162),
	white   = Color3.fromRGB(255, 255, 255),
}
local ACCENT = {
	base  = Color3.fromRGB(255, 147, 41),
	dim   = Color3.fromRGB(84, 51, 24),
	light = Color3.fromRGB(255, 191, 125),
}

local function corner(obj, r)
	local c = Instance.new("UICorner", obj)
	c.CornerRadius = UDim.new(0, r)
	return c
end

local function stroke(obj, color, th)
	local s = Instance.new("UIStroke", obj)
	s.Color = color
	s.Thickness = th or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

local function tw(obj, props, t, style)
	TweenService:Create(obj, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- clean up any previous copy
do
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("AutoFarmGui")
	if old then old:Destroy() end
end

-- ─────────────────────────────────────────────
--  WINDOW
-- ─────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- sound lives on the GUI so it survives respawns
local collectSound = Instance.new("Sound")
collectSound.SoundId = "rbxassetid://12221967"
collectSound.Volume = 1
collectSound.Parent = gui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 374)
frame.Position = UDim2.new(0.5, -150, 0.5, -187)
frame.BackgroundColor3 = COL.bg
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = gui
corner(frame, 14)
stroke(frame, COL.border, 1.5)

-- subtle accent glow strip across the top
local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0, 64)
topGlow.BackgroundColor3 = ACCENT.base
topGlow.BorderSizePixel = 0
topGlow.ZIndex = 0
topGlow.Parent = frame
corner(topGlow, 14)
do
	local g = Instance.new("UIGradient", topGlow)
	g.Rotation = 90
	g.Color = ColorSequence.new(ACCENT.base, COL.bg)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- ── title bar ──
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.ZIndex = 2
titleBar.Parent = frame

local dotColors = {Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63)}
local redDot
for i = 1, 3 do
	local d = Instance.new("Frame")
	d.Size = UDim2.new(0, 12, 0, 12)
	d.Position = UDim2.new(0, 14 + (i - 1) * 20, 0, 15)
	d.BackgroundColor3 = dotColors[i]
	d.BorderSizePixel = 0
	d.ZIndex = 3
	d.Parent = titleBar
	corner(d, 6)
	if i == 1 then redDot = d end
end

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -98, 1, 0)
titleLbl.Position = UDim2.new(0, 84, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Coin Farm (Free Premium)"
titleLbl.TextColor3 = COL.text
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 2
titleLbl.Parent = titleBar

-- thin separator under the bar
local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -28, 0, 1)
sep.Position = UDim2.new(0, 14, 0, 42)
sep.BackgroundColor3 = COL.border
sep.BorderSizePixel = 0
sep.ZIndex = 2
sep.Parent = frame

-- ── drag (from the title bar) ──
do
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = frame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local delta = i.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ── body (auto-laid-out) ──
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -42)
body.Position = UDim2.new(0, 0, 0, 42)
body.BackgroundTransparency = 1
body.ZIndex = 2
body.Parent = frame
do
	local p = Instance.new("UIPadding", body)
	p.PaddingLeft = UDim.new(0, 14)
	p.PaddingRight = UDim.new(0, 14)
	p.PaddingTop = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	local l = Instance.new("UIListLayout", body)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 8)
end

-- ─────────────────────────────────────────────
--  COMPONENT BUILDERS
-- ─────────────────────────────────────────────
-- a toggle card with an ON/OFF pill; returns (button, setState)
local function toggleCard(order, label)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 44)
	card.BackgroundColor3 = COL.card
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.ZIndex = 2
	card.Parent = body
	corner(card, 10)
	local cs = stroke(card, COL.border, 1)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -90, 1, 0)
	t.Position = UDim2.new(0, 14, 0, 0)
	t.BackgroundTransparency = 1
	t.Text = label
	t.TextColor3 = COL.text
	t.Font = Enum.Font.GothamSemibold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 2
	t.Parent = card

	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(0, 52, 0, 24)
	pill.Position = UDim2.new(1, -66, 0.5, -12)
	pill.BackgroundColor3 = COL.off
	pill.BorderSizePixel = 0
	pill.ZIndex = 2
	pill.Parent = card
	corner(pill, 12)
	local ps = stroke(pill, COL.border, 1)

	local pl = Instance.new("TextLabel")
	pl.Size = UDim2.new(1, 0, 1, 0)
	pl.BackgroundTransparency = 1
	pl.Text = "OFF"
	pl.TextColor3 = COL.muted
	pl.Font = Enum.Font.GothamBold
	pl.TextSize = 11
	pl.ZIndex = 2
	pl.Parent = pill

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 3
	btn.Parent = card

	local function setState(on)
		if on then
			tw(card, {BackgroundColor3 = ACCENT.dim})
			tw(cs, {Color = ACCENT.base})
			tw(pill, {BackgroundColor3 = ACCENT.base})
			tw(ps, {Color = ACCENT.base})
			pl.Text = "ON"
			tw(pl, {TextColor3 = COL.white})
		else
			tw(card, {BackgroundColor3 = COL.card})
			tw(cs, {Color = COL.border})
			tw(pill, {BackgroundColor3 = COL.off})
			tw(ps, {Color = COL.border})
			pl.Text = "OFF"
			tw(pl, {TextColor3 = COL.muted})
		end
	end

	btn.MouseEnter:Connect(function() if pl.Text == "OFF" then tw(card, {BackgroundColor3 = COL.cardHov}) end end)
	btn.MouseLeave:Connect(function() if pl.Text == "OFF" then tw(card, {BackgroundColor3 = COL.card}) end end)

	return btn, setState
end

-- a left label + right value row; returns the value label
local function statRow(order, name)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.ZIndex = 2
	row.Parent = body

	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(0.62, 0, 1, 0)
	n.Position = UDim2.new(0, 2, 0, 0)
	n.BackgroundTransparency = 1
	n.Text = name
	n.TextColor3 = COL.muted
	n.Font = Enum.Font.Gotham
	n.TextSize = 13
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.ZIndex = 2
	n.Parent = row

	local v = Instance.new("TextLabel")
	v.Size = UDim2.new(0.38, -2, 1, 0)
	v.Position = UDim2.new(0.62, 0, 0, 0)
	v.BackgroundTransparency = 1
	v.Text = "0"
	v.TextColor3 = ACCENT.light
	v.Font = Enum.Font.GothamBold
	v.TextSize = 13
	v.TextXAlignment = Enum.TextXAlignment.Right
	v.ZIndex = 2
	v.Parent = row
	return v
end

local function sectionLabel(order, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 18)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = COL.muted
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.LayoutOrder = order
	l.ZIndex = 2
	l.Parent = body
	return l
end

-- ── build the controls ──
local farmBtn, farmSet = toggleCard(1, "Auto Farm")
local afkBtn,  afkSet  = toggleCard(2, "Anti-AFK")

-- speed stepper card (pill shows current value, click to cycle)
local speedCard = Instance.new("Frame")
speedCard.Size = UDim2.new(1, 0, 0, 44)
speedCard.BackgroundColor3 = COL.card
speedCard.BorderSizePixel = 0
speedCard.LayoutOrder = 3
speedCard.ZIndex = 2
speedCard.Parent = body
corner(speedCard, 10)
stroke(speedCard, COL.border, 1)
do
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -90, 1, 0)
	t.Position = UDim2.new(0, 14, 0, 0)
	t.BackgroundTransparency = 1
	t.Text = "Tween Speed"
	t.TextColor3 = COL.text
	t.Font = Enum.Font.GothamSemibold
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 2
	t.Parent = speedCard
end

local speedPillLbl
do
	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(0, 52, 0, 24)
	pill.Position = UDim2.new(1, -66, 0.5, -12)
	pill.BackgroundColor3 = ACCENT.dim
	pill.BorderSizePixel = 0
	pill.ZIndex = 2
	pill.Parent = speedCard
	corner(pill, 12)
	stroke(pill, ACCENT.base, 1)
	speedPillLbl = Instance.new("TextLabel")
	speedPillLbl.Size = UDim2.new(1, 0, 1, 0)
	speedPillLbl.BackgroundTransparency = 1
	speedPillLbl.Text = tostring(flySpeed)
	speedPillLbl.TextColor3 = ACCENT.light
	speedPillLbl.Font = Enum.Font.GothamBold
	speedPillLbl.TextSize = 12
	speedPillLbl.ZIndex = 2
	speedPillLbl.Parent = pill
end

local speedBtn = Instance.new("TextButton")
speedBtn.Size = UDim2.new(1, 0, 1, 0)
speedBtn.BackgroundTransparency = 1
speedBtn.Text = ""
speedBtn.ZIndex = 3
speedBtn.Parent = speedCard

-- stats
sectionLabel(4, "STATS")
local counterVal = statRow(5, "Coins Collected")
local timerVal   = statRow(6, "Time Active")
local rateVal    = statRow(7, "Coins / Hour")

-- reset
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1, 0, 0, 38)
resetBtn.BackgroundColor3 = COL.card
resetBtn.Text = "Reset Counter"
resetBtn.TextColor3 = COL.text
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 13
resetBtn.AutoButtonColor = false
resetBtn.LayoutOrder = 8
resetBtn.ZIndex = 2
resetBtn.Parent = body
corner(resetBtn, 10)
stroke(resetBtn, COL.border, 1)
resetBtn.MouseEnter:Connect(function() tw(resetBtn, {BackgroundColor3 = COL.cardHov}) end)
resetBtn.MouseLeave:Connect(function() tw(resetBtn, {BackgroundColor3 = COL.card}) end)

-- ─────────────────────────────────────────────
--  HIDE (red dot)  +  REOPEN BUTTON
-- ─────────────────────────────────────────────
local reopen = Instance.new("TextButton")
reopen.Name = "Reopen"
reopen.Size = UDim2.new(0, 46, 0, 46)
reopen.Position = UDim2.new(0, 20, 0.42, 0)
reopen.BackgroundColor3 = ACCENT.dim
reopen.Text = "$"
reopen.TextColor3 = ACCENT.light
reopen.Font = Enum.Font.GothamBold
reopen.TextSize = 20
reopen.AutoButtonColor = false
reopen.Visible = false
reopen.Parent = gui
corner(reopen, 12)
stroke(reopen, ACCENT.base, 1.5)
reopen.MouseEnter:Connect(function() tw(reopen, {BackgroundColor3 = ACCENT.base}) end)
reopen.MouseLeave:Connect(function() tw(reopen, {BackgroundColor3 = ACCENT.dim}) end)
reopen.MouseButton1Click:Connect(function()
	reopen.Visible = false
	frame.Visible = true
end)

do
	local redBtn = Instance.new("TextButton")
	redBtn.Size = UDim2.new(1, 0, 1, 0)
	redBtn.BackgroundTransparency = 1
	redBtn.Text = ""
	redBtn.ZIndex = 4
	redBtn.Parent = redDot
	redBtn.MouseButton1Click:Connect(function()
		frame.Visible = false      -- hide only; farm keeps running
		reopen.Visible = true
	end)
end

-- ─────────────────────────────────────────────
--  FARM LOGIC
-- ─────────────────────────────────────────────
-- Anti-AFK
afkBtn.MouseButton1Click:Connect(function()
	antiAFK = not antiAFK
	afkSet(antiAFK)
end)

player.Idled:Connect(function()
	if antiAFK then
		VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	end
end)

-- noclip while farming
RunService.Stepped:Connect(function()
	if isActive and character then
		for _, v in ipairs(character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end
	end
end)

-- tween speed cycle
speedBtn.MouseButton1Click:Connect(function()
	flySpeed = flySpeed + 1
	if flySpeed > 25 then flySpeed = 10 end
	speedPillLbl.Text = tostring(flySpeed)
end)

local function flyTo(pos, speed)
	if not rootPart then return end
	local distance = (pos - rootPart.Position).Magnitude
	local duration = distance / speed
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local goal = {CFrame = CFrame.new(pos)}
	local tween = TweenService:Create(rootPart, tweenInfo, goal)
	tween:Play()
	tween.Completed:Wait()
end

local function isNear(pos1, pos2)
	return (pos1 - pos2).Magnitude < 250
end

-- reset
resetBtn.MouseButton1Click:Connect(function()
	collected = 0
	startTime = tick()
	counterVal.Text = "0"
	timerVal.Text = "0s"
	rateVal.Text = "0"
end)

-- auto farm toggle
farmBtn.MouseButton1Click:Connect(function()
	isActive = not isActive
	farmSet(isActive)

	if isActive then
		collected = 0
		startTime = tick()
		visitedPositions = {}
		counterVal.Text = "0"

		-- timer + rate updater
		task.spawn(function()
			while isActive do
				local elapsed = tick() - startTime
				timerVal.Text = math.floor(elapsed) .. "s"
				local rate = elapsed > 0 and math.floor((collected / elapsed) * 3600) or 0
				rateVal.Text = tostring(rate)
				task.wait(0.1)
			end
		end)

		-- main coin search loop
		task.spawn(function()
			while isActive do
				character = player.Character or player.CharacterAdded:Wait()
				rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local closest, shortest = nil, math.huge
					for _, obj in ipairs(workspace:GetDescendants()) do
						if obj:IsA("BasePart") and obj.Name == "Coin_Server" then
							local dist = (obj.Position - rootPart.Position).Magnitude
							if dist < shortest and dist < 250 and not visitedPositions[obj] then
								closest = obj
								shortest = dist
							end
						end
					end

					if closest and closest.Parent and closest:IsDescendantOf(workspace) then
						flyTo(closest.Position, flySpeed)
						if closest and closest.Parent and closest:IsDescendantOf(workspace) then
							visitedPositions[closest] = true
							collected = collected + 1
							collectSound:Play()
							counterVal.Text = tostring(collected)
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end
end)

print("Coin Farm (Free Premium) loaded")
