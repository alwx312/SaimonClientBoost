--// === НАСТРОЙКИ ===
local CAT_URL = "https://i.postimg.cc/3wkZ5B8R/B83FD4BD-89E4-4E8D-B345-210BF80F34C6.png"
local BANNER_URL = "https://i.postimg.cc/Wz5D1B80/3FF237FC-998B-4DE2-BDFD-256B9F993531.png"
-- =================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local VIM = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- [SINGLETON] Удаляем старое окно
local guiName = "SimonClient"
local oldGui = CoreGui:FindFirstChild(guiName) or lp.PlayerGui:FindFirstChild(guiName)
if oldGui then oldGui:Destroy() end

-- THEME
local PANEL = Color3.fromRGB(24, 26, 54)
local ACC = Color3.fromRGB(110, 130, 255)
local GOLD_COLOR = Color3.fromRGB(255, 200, 50)
local TXT = Color3.fromRGB(225, 227, 245)
local DIM = Color3.fromRGB(130, 134, 170)
local FONT, FONTB = Enum.Font.GothamMedium, Enum.Font.GothamBold

-- IMAGE LOADER
local function LoadImage(ImageLabel, Url)
	if not Url or Url == "" then return end
	pcall(function()
		if isfile and writefile and getcustomasset then
			local ext = Url:match("%.([^%.]+)$") or "png"
			local fileName = "SimonImg_" .. tostring(math.random(1, 999999)) .. "." .. ext
			if not isfile(fileName) then writefile(fileName, game:HttpGet(Url)) end
			ImageLabel.Image = getcustomasset(fileName)
		else
			ImageLabel.Image = Url
		end
	end)
end

-- MODULES CONFIG
local P = {"Head", "HumanoidRootPart"}
local M = {
	{cat = "Combat", name = "Triggerbot", isCustom = true, settings = {
		{k = "Delay", t = "slider", min = 0.01, max = 0.5, def = 0.1, step = 0.01},
		{k = "Distance", t = "slider", min = 5, max = 50, def = 25, step = 1},
		{k = "SmartCrits", t = "bool", def = true},
	}},
	{cat = "Combat", name = "Hit Boxes", isCustom = true, settings = {
		{k = "Size", t = "slider", min = 2, max = 20, def = 6, step = 1},
		{k = "Mode", t = "choice", opts = {"Default", "Legit"}, def = "Default"},
	}},
	{cat = "Movement", name = "Speed", settings = {{k = "Value", t = "slider", min = 16, max = 120, def = 32, step = 1}}},
	{cat = "Movement", name = "Flight", settings = {{k = "Speed", t = "slider", min = 10, max = 150, def = 50, step = 1}}},
	{cat = "Movement", name = "KT Leave (Skybase)", isCustom = true, settings = {
		{k = "Height", t = "slider", min = 20, max = 150, def = 45, step = 5},
		{k = "Mode", t = "choice", opts = {"TP", "Flight", "Bypass", "Bypass V3"}, def = "TP"},
		{k = "FallMode", t = "choice", opts = {"None", "AntiFall", "Mace/MC"}, def = "None"},
	}},
	{cat = "Visuals", name = "ESP", isCustom = true},
	{cat = "Visuals", name = "Nametags", isCustom = true},
	{cat = "Visuals", name = "Watermark", isCustom = true}, -- Добавили Watermark
}
local CATS = {"Combat", "Movement", "Visuals"}

local Flags, S = {}, {}
for _, m in ipairs(M) do
	Flags[m.name] = false
	S[m.name] = {}
	for _, s in ipairs(m.settings or {}) do S[m.name][s.k] = s.def end
end

local open = false
local HitboxData = {}
local ESPData = {}
local KTState = { Platform = nil, SavedCF = nil, Active = false, Loop = nil, Highlight = nil, FallLoop = nil }

-- HELPERS
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function char()
	local c = lp.Character
	return c, c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end
local function MakeDraggable(frame, dragArea)
	dragArea = dragArea or frame
	local dragging, dragInput, dragStart, startPos
	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = input.Position; startPos = frame.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	dragArea.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
	end)
	UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- GUI ROOT
local gui = new("ScreenGui", {Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999}, lp:WaitForChild("PlayerGui"))
local modal = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Modal = false, Visible = false}, gui)

-- ТЯНКА (в углу экрана)
local cornerImg = new("ImageLabel", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(100, 100),
	BackgroundTransparency = 1, Image = "", ImageTransparency = 0.2, ZIndex = 5
}, gui)
LoadImage(cornerImg, CAT_URL)

-- КНОПКА ОТКРЫТИЯ
local openBtn = new("TextButton", {
	Size = UDim2.fromOffset(50, 50), Position = UDim2.new(1, -70, 0, 20),
	BackgroundColor3 = Color3.fromRGB(255, 200, 50), Text = "S", Font = Enum.Font.GothamBlack,
	TextSize = 26, TextColor3 = Color3.fromRGB(30, 30, 30), ZIndex = 100
}, gui)
corner(openBtn, 25)
new("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 2}, openBtn)
MakeDraggable(openBtn)

-- ==========================================================
-- ВАТЕРМАРКА (Мобильная версия, интегрирована)
-- ==========================================================
local wmGui = new("ScreenGui", {Name = "SimonWM", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, lp.PlayerGui)
local wmRoot = new("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = wmGui})
local wmBar = new("Frame", {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = wmRoot})
corner(wmBar, 8)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = wmBar})
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12), Parent = wmBar})

-- Логотип "A"
local wmLogo = new("Frame", {Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.8, Parent = wmBar})
corner(wmLogo, 6)
local wmLogoText = new("TextLabel", {Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "A", Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255), Parent = wmLogo})
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(150, 90, 255), Color3.fromRGB(70, 200, 255)), Rotation = 45}, wmLogoText)

-- Имя
local wmName = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1,1,1), Text = "Simon", Parent = wmBar})
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(200, 185, 255)), Rotation = 90}, wmName)

-- FPS
local wmFps = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(232, 235, 248), Text = "60 FPS", Parent = wmBar})
-- Ping
local wmPing = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(232, 235, 248), Text = "0 MS", Parent = wmBar})
-- Time
local wmTime = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(232, 235, 248), Text = "00:00", Parent = wmBar})

MakeDraggable(wmRoot)
-- ==========================================================

-- ГЛАВНОЕ МЕНЮ
local main2 = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(480, 400),
	BackgroundColor3 = Color3.fromRGB(16, 17, 26), BackgroundTransparency = 0.04, GroupTransparency = 1, Visible = false, ZIndex = 10
}, gui)
corner(main2, 16)
local uiScale = new("UIScale", {Scale = 1}, main2)

local function UpdateScale()
	local vp = cam.ViewportSize
	-- Keep the whole panel usable on phones without making text microscopic.
	local scaleX = (vp.X - 16) / 480
	local scaleY = (vp.Y - 24) / 400
	uiScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.62, 1)
end
UpdateScale()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)

-- БАННЕР
local bannerFrame = new("Frame", {Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(20, 21, 32), ClipsDescendants = true, ZIndex = 1}, main2)
corner(bannerFrame, 12)
local bannerImg = new("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Crop}, bannerFrame)
corner(bannerImg, 12)
LoadImage(bannerImg, BANNER_URL)

local titleOverlay = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 2}, bannerFrame)
corner(titleOverlay, 12)
local titleLbl = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "Саймон Клиент", Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3}, titleOverlay)
new("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 100, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 200))}), Rotation = 45}, titleLbl)
new("UIStroke", {Color = Color3.fromRGB(200, 150, 255), Thickness = 2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, titleLbl)

local closeBtn = new("TextButton", {Position = UDim2.new(1, -35, 0, 10), Size = UDim2.fromOffset(25, 25), BackgroundTransparency = 1, Text = "X", Font = FONTB, TextSize = 20, TextColor3 = Color3.fromRGB(255, 80, 80), ZIndex = 10}, bannerFrame)
closeBtn.MouseButton1Click:Connect(function() _G.SimonSetOpen(false) end)

MakeDraggable(main2, bannerFrame)

-- БОКОВАЯ ПАНЕЛЬ
local side = new("Frame", {Position = UDim2.fromOffset(0, 90), Size = UDim2.fromOffset(120, 300), BackgroundTransparency = 1, ZIndex = 2}, main2)
local curCat = "Combat"
local catBtns = {}
local grid, title2, cards = {}, nil, {}

local function showCat()
	title2.Text = curCat
	for name, c in pairs(cards) do c.frame.Visible = (c.cat == curCat) end
	for cat, b in pairs(catBtns) do
		local sel = cat == curCat
		tween(b.btn, 0.2, {BackgroundTransparency = sel and 0 or 1})
		tween(b.lbl, 0.2, {TextColor3 = sel and Color3.new(1, 1, 1) or DIM})
	end
end

for i, cat in ipairs(CATS) do
	local btn = new("TextButton", {Position = UDim2.fromOffset(10, (i - 1) * 45), Size = UDim2.fromOffset(100, 38), BackgroundColor3 = ACC, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 2}, side)
	corner(btn, 8)
	local lbl = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = cat, Font = FONT, TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2}, btn)
	catBtns[cat] = {btn = btn, lbl = lbl}
	btn.MouseButton1Click:Connect(function() curCat = cat; showCat() end)
end

title2 = new("TextLabel", {Position = UDim2.fromOffset(130, 95), Size = UDim2.fromOffset(200, 28), BackgroundTransparency = 1, Text = "Combat", Font = FONTB, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2}, main2)
grid = new("ScrollingFrame", {
	Position = UDim2.fromOffset(130, 130),
	Size = UDim2.new(1, -140, 1, -140),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 2
}, main2)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 7)
}, grid)
new("UIPadding", {
	PaddingTop = UDim.new(0, 2),
	PaddingBottom = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 4)
}, grid)

local function setFlag(name, v)
	Flags[name] = v
	local cc = cards[name]
	if cc then
		if cc.status then
			cc.status.Text = v and "ON" or "OFF"
			cc.status.TextColor3 = v and Color3.fromRGB(150, 255, 180) or DIM
		end
		if cc.enableBtn then
			cc.enableBtn.Text = v and "Disable module" or "Enable module"
			cc.enableBtn.BackgroundColor3 = v and Color3.fromRGB(48, 105, 78) or Color3.fromRGB(45, 48, 70)
		end
	end

	if name == "Watermark" then
		if v then
			wmRoot.Visible = true
			wmRoot.GroupTransparency = 1
			tween(wmRoot, 0.25, {GroupTransparency = 0})
		else
			wmRoot.Visible = false
		end
	end
end

for order, m in ipairs(M) do
	local card = new("Frame", {
		Name = "Module_" .. m.name:gsub("%W", ""),
		Size = UDim2.new(1, -2, 0, 48),
		BackgroundColor3 = Color3.fromRGB(24, 26, 40),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = order,
		ZIndex = 2
	}, grid)
	corner(card, 9)
	new("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.92,
		Thickness = 1
	}, card)

	local nameLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -105, 0, 46),
		BackgroundTransparency = 1,
		Text = m.name,
		Font = FONTB,
		TextSize = 12,
		TextColor3 = m.isCustom and GOLD_COLOR or TXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3
	}, card)

	local status = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -43, 0, 23),
		Size = UDim2.fromOffset(32, 20),
		BackgroundTransparency = 1,
		Text = "OFF",
		Font = FONTB,
		TextSize = 10,
		TextColor3 = DIM,
		ZIndex = 3
	}, card)

	local plus = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0, 23),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(42, 45, 68),
		AutoButtonColor = true,
		Text = "+",
		Font = FONTB,
		TextSize = 21,
		TextColor3 = TXT,
		ZIndex = 4
	}, card)
	corner(plus, 8)

	local details = new("Frame", {
		Position = UDim2.fromOffset(8, 46),
		Size = UDim2.new(1, -16, 0, 40),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3
	}, card)

	local enableBtn = new("TextButton", {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, - (m.settings and 76 or 0), 0, 32),
		BackgroundColor3 = Color3.fromRGB(45, 48, 70),
		AutoButtonColor = true,
		Text = "Enable module",
		Font = FONTB,
		TextSize = 11,
		TextColor3 = TXT,
		ZIndex = 4
	}, details)
	corner(enableBtn, 7)

	local settingsBtn
	if m.settings and #m.settings > 0 then
		settingsBtn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 2),
			Size = UDim2.fromOffset(68, 32),
			BackgroundColor3 = Color3.fromRGB(42, 45, 68),
			AutoButtonColor = true,
			Text = "Settings",
			Font = FONTB,
			TextSize = 10,
			TextColor3 = TXT,
			ZIndex = 4
		}, details)
		corner(settingsBtn, 7)
	end

	cards[m.name] = {
		box = nil,
		knob = nil,
		status = status,
		enableBtn = enableBtn,
		cat = m.cat,
		frame = card,
		details = details,
		plus = plus,
		expanded = false
	}

	local function expandModule()
		local cc = cards[m.name]
		cc.expanded = not cc.expanded
		details.Visible = cc.expanded
		plus.Text = cc.expanded and "−" or "+"
		card.Size = UDim2.new(1, -2, 0, cc.expanded and 88 or 48)
	end

	plus.Activated:Connect(expandModule)
	enableBtn.Activated:Connect(function()
		setFlag(m.name, not Flags[m.name])
	end)

	if settingsBtn then
		settingsBtn.Activated:Connect(function()
			openSettings(m, card, card)
		end)
	end

	-- Allow tapping the module title to expand its controls on touch devices.
	nameLabel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			expandModule()
		end
	end)
end
showCat()

-- OPEN / CLOSE
_G.SimonSetOpen = function(v)
	open = v
	modal.Visible, modal.Modal = v, v
	if v then main2.Visible = true end
	tween(main2, 0.3, {GroupTransparency = v and 0 or 1})
	if not v then task.delay(0.3, function() main2.Visible = false end) end
end
openBtn.MouseButton1Click:Connect(function() _G.SimonSetOpen(not open) end)
UIS.InputBegan:Connect(function(input, gpe) if not gpe and (input.KeyCode == Enum.KeyCode.PageDown or input.KeyCode == Enum.KeyCode.RightShift) then _G.SimonSetOpen(not open) end end)

-- НАСТРОЙКИ
local popup = new("Frame", {Size = UDim2.fromOffset(200, 100), BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 105}, gui)
corner(popup, 12)
new("UIStroke", {Color = ACC, Transparency = 0.6}, popup)
new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, popup)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, popup)
local dragFn

function openSettings(m, col, row)
	for _, c in ipairs(popup:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	new("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = m.name, Font = FONTB, TextSize = 14, TextColor3 = m.isCustom and GOLD_COLOR or Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0}, popup)
	local store = S[m.name]
	for idx, s in ipairs(m.settings) do
		if s.t == "slider" then
			local f = new("Frame", {Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = idx}, popup)
			local l = new("TextLabel", {Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = s.k .. ": " .. tostring(store[s.k])}, f)
			local track = new("TextButton", {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(50, 53, 90), Text = "", AutoButtonColor = false}, f)
			corner(track, 3)
			local fill = new("Frame", {Size = UDim2.fromScale((store[s.k] - s.min) / (s.max - s.min), 1), BackgroundColor3 = ACC}, track)
			corner(fill, 3)
			local function upd(x)
				local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				local v = s.min + (s.max - s.min) * a
				v = math.floor(v / s.step + 0.5) * s.step
				store[s.k] = v
				fill.Size = UDim2.fromScale((v - s.min) / (s.max - s.min), 1)
				l.Text = s.k .. ": " .. tostring(v)
			end
			track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragFn = function(pos) upd(pos.X) end; upd(i.Position.X) end end)
		elseif s.t == "choice" then
			local b = new("TextButton", {Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(50, 53, 90), Font = FONT, TextSize = 12, TextColor3 = TXT, Text = s.k .. ": " .. store[s.k], LayoutOrder = idx}, popup)
			corner(b, 4)
			b.MouseButton1Click:Connect(function() local cur = table.find(s.opts, store[s.k]) or 1; store[s.k] = s.opts[cur % #s.opts + 1]; b.Text = s.k .. ": " .. store[s.k]; if s.onSet then s.onSet() end end)
		end
	end
	local vp = cam.ViewportSize
	local popupWidth = math.min(200, math.max(160, vp.X - 20))
	popup.Size = UDim2.fromOffset(popupWidth, 100)
	popup.Position = UDim2.fromOffset(
		math.clamp(col.AbsolutePosition.X + col.AbsoluteSize.X + 10, 10, math.max(10, vp.X - popupWidth - 10)),
		math.clamp(row.AbsolutePosition.Y, 10, math.max(10, vp.Y - 180))
	)
	popup.Visible = true
end
UIS.InputChanged:Connect(function(i) if dragFn and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then dragFn(i.Position) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragFn = nil end end)

------------------------------------------------------------------ ЛОГИКА: KT LEAVE
local function StopKTLeave()
	KTState.Active = false
	if KTState.Loop then KTState.Loop:Disconnect() end
	if KTState.FallLoop then KTState.FallLoop:Disconnect() end
	if KTState.Platform then KTState.Platform:Destroy() end
	if KTState.Highlight then KTState.Highlight:Destroy() end
	local c, h, r = char()
	if h then h.PlatformStand = false; h.Sit = false end
	if KTState.SavedCF and r then
		task.spawn(function() local t = tick(); while tick() - t < 0.5 and r.Parent do r.CFrame = KTState.SavedCF; r.AssemblyLinearVelocity = Vector3.zero; task.wait(0.05) end end)
	end
end

local function StartKTLeave()
	local c, h, r = char()
	if not r then return end
	local cfg = S["KT Leave (Skybase)"]
	KTState.SavedCF = r.CFrame; KTState.Active = true
	local targetPos = r.Position + Vector3.new(0, cfg.Height, 0)
	local platformY = targetPos.Y - 3.5
	
	if KTState.Platform then KTState.Platform:Destroy() end
	local plat = new("Part", {Name = "KTSkybase", Size = Vector3.new(12, 1, 12), Position = targetPos - Vector3.new(0, 3.5, 0), Anchored = true, CanCollide = true, Transparency = 0.4, Color = Color3.fromRGB(30, 30, 40), Parent = workspace})
	KTState.Highlight = new("Highlight", {Adornee = plat, FillTransparency = 1, OutlineColor = Color3.fromHSV(0, 1, 1), OutlineTransparency = 0, Parent = plat})
	task.spawn(function() while plat.Parent and KTState.Active do KTState.Highlight.OutlineColor = Color3.fromHSV((tick() * 0.5) % 1, 1, 1); task.wait(0.05) end end)
	KTState.Platform = plat

	if cfg.Mode == "TP" then r.CFrame = CFrame.new(targetPos); r.AssemblyLinearVelocity = Vector3.zero
	elseif cfg.Mode == "Flight" then
		local bv = new("BodyVelocity", {MaxForce = Vector3.new(math.huge, math.huge, math.huge), Velocity = Vector3.new(0, 50, 0), Parent = r})
		task.spawn(function() while KTState.Active and r.Parent do if r.Position.Y >= targetPos.Y then bv:Destroy(); break end task.wait(0.1) end end)
	elseif cfg.Mode == "Bypass V3" then
		local t = 0
		KTState.Loop = RunService.Heartbeat:Connect(function(dt)
			if not KTState.Active or not r.Parent then return end
			t += dt * 30
			if r.Position.Y < targetPos.Y - 2 then r.CFrame = CFrame.new(r.Position.X, r.Position.Y + 5 + math.sin(t) * 3, r.Position.Z); r.AssemblyLinearVelocity = Vector3.zero
			else r.CFrame = CFrame.new(targetPos); r.AssemblyLinearVelocity = Vector3.zero end
		end)
	end
	
	KTState.FallLoop = RunService.Heartbeat:Connect(function()
		if not KTState.Active or not r.Parent then return end
		if h then h.PlatformStand = false; h.Sit = false end
		if cfg.FallMode == "AntiFall" and r.Position.Y < platformY - 2 then
			r.CFrame = CFrame.new(r.Position.X, targetPos.Y + 3, r.Position.Z); r.AssemblyLinearVelocity = Vector3.zero
			if h then h:ChangeState(Enum.HumanoidStateType.Landed) end
		elseif cfg.FallMode == "Mace/MC" and r.Position.Y < platformY - 5 then
			r.CFrame = CFrame.new(r.Position.X, targetPos.Y + 3, r.Position.Z); r.AssemblyLinearVelocity = Vector3.zero
			if h then h:ChangeState(Enum.HumanoidStateType.Landed) end
		end
	end)
end

local oldSetFlag = setFlag
setFlag = function(n, v) oldSetFlag(n, v); if n == "KT Leave (Skybase)" then if v then StartKTLeave() else StopKTLeave() end end end

------------------------------------------------------------------ ЛОГИКА: ESP & NAMETAGS
local function UpdateVisuals()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp and plr.Character then
			local char = plr.Character
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local head = char:FindFirstChild("Head")
			local hum = char:FindFirstChildOfClass("Humanoid")
			
			if hrp and head and hum and hum.Health > 0 then
				if not ESPData[plr] then ESPData[plr] = {} end
				
				-- ESP
				if Flags["ESP"] then
					if not ESPData[plr].ESP or not ESPData[plr].ESP.Parent then
						ESPData[plr].ESP = new("Highlight", {FillColor = GOLD_COLOR, OutlineColor = Color3.new(1, 1, 1), FillTransparency = 0.6, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = char})
					end
				else
					if ESPData[plr].ESP then ESPData[plr].ESP:Destroy(); ESPData[plr].ESP = nil end
				end

				-- Nametags
				if Flags["Nametags"] then
					if not ESPData[plr].Tag or not ESPData[plr].Tag.Parent then
						local bg = new("BillboardGui", {Name = "SimonTags", Adornee = head, AlwaysOnTop = true, Size = UDim2.fromOffset(200, 30), StudsOffset = Vector3.new(0, 2.8, 0), Parent = head})
						local lbl = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = plr.DisplayName, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeTransparency = 0.4, Parent = bg})
						new("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 100))}), Rotation = 45}, lbl)
						ESPData[plr].Tag = bg
					end
				else
					if ESPData[plr].Tag then ESPData[plr].Tag:Destroy(); ESPData[plr].Tag = nil end
				end
			else
				if ESPData[plr] then
					if ESPData[plr].ESP then ESPData[plr].ESP:Destroy() end
					if ESPData[plr].Tag then ESPData[plr].Tag:Destroy() end
					ESPData[plr] = nil
				end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(plr)
	if ESPData[plr] then
		if ESPData[plr].ESP then ESPData[plr].ESP:Destroy() end
		if ESPData[plr].Tag then ESPData[plr].Tag:Destroy() end
		ESPData[plr] = nil
	end
end)

------------------------------------------------------------------ ОБНОВЛЕНИЕ ВАТЕРМАРКИ
local frames, acc = 0, 0
RunService.RenderStepped:Connect(function(dt)
	if not Flags["Watermark"] then return end
	
	frames += 1
	acc += dt
	if acc >= 0.5 then
		local fps = math.floor(frames / acc + 0.5)
		frames, acc = 0, 0
		local ping = 0
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
		
		wmFps.Text = tostring(fps) .. " FPS"
		wmPing.Text = tostring(ping) .. " MS"
		
		local ts = os.time() + 5 * 3600
		wmTime.Text = os.date("!%H:%M", ts)
	end
end)

------------------------------------------------------------------ MAIN LOOP
local lastShot = 0
RunService.RenderStepped:Connect(function(dt)
	cam = workspace.CurrentCamera
	local c, hum, root = char()
	local mouse = UIS:GetMouseLocation()
	
	UpdateVisuals()

	-- ТРИГГЕР
	if Flags.Triggerbot and not open and os.clock() - lastShot > S.Triggerbot.Delay then
		local closestPlr, bestDist = nil, math.huge
		if root then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp and p.Character then
					local ph = p.Character:FindFirstChildOfClass("Humanoid")
					local pr = p.Character:FindFirstChild("HumanoidRootPart")
					if ph and ph.Health > 0 and pr then
						local d = (pr.Position - root.Position).Magnitude
						if d < bestDist and d <= S.Triggerbot.Distance then bestDist = d; closestPlr = p end
					end
				end
			end
		end
		if closestPlr then
			lastShot = os.clock()
			local pr = closestPlr.Character.HumanoidRootPart
			local sp, on = cam:WorldToViewportPoint(pr.Position)
			if on and type(mousemoverel) == "function" then mousemoverel(sp.X - mouse.X, sp.Y - mouse.Y) end
			if S.Triggerbot.SmartCrits and hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then hum.Jump = true end
			
			task.spawn(function()
				local tool = c and c:FindFirstChildOfClass("Tool")
				if tool then pcall(function() tool:Activate() end); local handle = tool:FindFirstChild("Handle"); if handle then pcall(function() firetouchinterest(handle, pr, 0); firetouchinterest(handle, pr, 1) end) end end
				pcall(function() VIM:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0); VIM:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0) end)
			end)
		end
	end

	-- ХИТБОКСЫ
	if Flags["Hit Boxes"] then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp and p.Character then
				local pr = p.Character:FindFirstChild("HumanoidRootPart")
				if pr then
					local sz = S["Hit Boxes"].Size
					local targetSz = Vector3.new(sz, sz, sz)
					if not HitboxData[p] or HitboxData[p].HRP ~= pr then
						if HitboxData[p] then if HitboxData[p].Part then HitboxData[p].Part:Destroy() end; if HitboxData[p].Vis then HitboxData[p].Vis:Destroy() end; if HitboxData[p].HRP then HitboxData[p].HRP.Size = HitboxData[p].OrigSize end end
						HitboxData[p] = {HRP = pr, OrigSize = pr.Size}
						HitboxData[p].Vis = new("BoxHandleAdornment", {Adornee = pr, Size = targetSz, AlwaysOnTop = true, ZIndex = 5, Color3 = Color3.fromRGB(255, 50, 50), Transparency = 0.5, Parent = pr})
						if S["Hit Boxes"].Mode == "Default" then
							local part = new("Part", {Name = "HitboxPart", Size = targetSz, Transparency = 1, CanCollide = false, CanTouch = true, CanQuery = true, Massless = true, Parent = p.Character})
							new("WeldConstraint", {Part0 = part, Part1 = pr, Parent = part}); HitboxData[p].Part = part
						else pr.Size = targetSz end
					else
						local targetSz = Vector3.new(S["Hit Boxes"].Size, S["Hit Boxes"].Size, S["Hit Boxes"].Size)
						if HitboxData[p].Part then HitboxData[p].Part.Size = targetSz end; if HitboxData[p].Vis then HitboxData[p].Vis.Size = targetSz end; if S["Hit Boxes"].Mode == "Legit" then pr.Size = targetSz end
					end
				end
			end
		end
	else
		for p, data in pairs(HitboxData) do if data.Part then data.Part:Destroy() end; if data.Vis then data.Vis:Destroy() end; if data.HRP then data.HRP.Size = data.OrigSize end; HitboxData[p] = nil end
	end

	-- ДВИЖЕНИЕ
	if hum and root then
		if Flags.Speed then hum.WalkSpeed = S.Speed.Value end
		if Flags.Flight then
			local bv = root:FindFirstChild("SimonFly")
			if not bv then bv = new("BodyVelocity", {Name = "SimonFly", MaxForce = Vector3.new(math.huge, math.huge, math.huge), Parent = root}) end
			local dir = Vector3.zero; local cf = cam.CFrame
			if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end; if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end; if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end; if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
			bv.Velocity = dir.Magnitude > 0 and dir.Unit * S.Flight.Speed or Vector3.zero
		else
			local bv = root:FindFirstChild("SimonFly")
			if bv then bv:Destroy() end
		end
	end
end)