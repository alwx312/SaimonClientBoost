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
local Lighting = game:GetService("Lighting")
local VIM = game:GetService("VirtualInputManager")

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

-- MODULES CONFIG (Огромный список)
local P = {"Head", "HumanoidRootPart", "Torso"}
local M = {
	{cat = "Combat", name = "Aimbot", settings = {
		{k = "FOV", t = "slider", min = 20, max = 600, def = 150, step = 5},
		{k = "Smooth", t = "slider", min = 0.05, max = 1, def = 0.25, step = 0.05},
		{k = "Part", t = "choice", opts = P, def = "Head"},
	}},
	{cat = "Combat", name = "Triggerbot", isCustom = true, settings = {
		{k = "Delay", t = "slider", min = 0.01, max = 0.5, def = 0.1, step = 0.01},
		{k = "Distance", t = "slider", min = 5, max = 50, def = 25, step = 1},
		{k = "SmartCrits", t = "bool", def = true},
	}},
	{cat = "Combat", name = "Hit Boxes", isCustom = true, settings = {
		{k = "Size", t = "slider", min = 2, max = 20, def = 6, step = 1},
		{k = "Mode", t = "choice", opts = {"Default", "Legit"}, def = "Default"},
	}},
	{cat = "Combat", name = "No Recoil"},
	{cat = "Combat", name = "No Spread"},
	
	{cat = "Movement", name = "Speed", settings = {{k = "Value", t = "slider", min = 16, max = 150, def = 32, step = 1}}},
	{cat = "Movement", name = "Flight", settings = {{k = "Speed", t = "slider", min = 10, max = 200, def = 50, step = 1}}},
	{cat = "Movement", name = "High Jump", settings = {{k = "Power", t = "slider", min = 50, max = 300, def = 100, step = 5}}},
	{cat = "Movement", name = "Infinite Jump"},
	{cat = "Movement", name = "Bunny Hop"},
	{cat = "Movement", name = "No Clip"},
	{cat = "Movement", name = "Click TP"},
	{cat = "Movement", name = "KT Leave (Skybase)", isCustom = true, settings = {
		{k = "Height", t = "slider", min = 20, max = 150, def = 45, step = 5},
		{k = "Mode", t = "choice", opts = {"TP", "Flight", "Bypass V3"}, def = "TP"},
		{k = "FallMode", t = "choice", opts = {"None", "AntiFall", "Mace/MC"}, def = "None"},
	}},
	
	{cat = "Visuals", name = "ESP", isCustom = true},
	{cat = "Visuals", name = "Nametags", isCustom = true},
	{cat = "Visuals", name = "Watermark", isCustom = true},
	{cat = "Visuals", name = "FOV Circle"},
	{cat = "Visuals", name = "Crosshair"},
	{cat = "Visuals", name = "Full Bright"},
	{cat = "Visuals", name = "FPS Boost"},
	{cat = "Visuals", name = "Target HUD"},
	
	{cat = "Misc", name = "Anti AFK"},
	{cat = "Misc", name = "Panic", action = true},
}
local CATS = {"Combat", "Movement", "Visuals", "Misc"}

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
local ActiveToggles = {}

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

-- ТЯНКА (Скрыта по умолчанию)
local cornerImg = new("ImageLabel", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(100, 100),
	BackgroundTransparency = 1, Image = "", ImageTransparency = 0.2, ZIndex = 5, Visible = false
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

-- ВАТЕРМАРКА
local wmGui = new("ScreenGui", {Name = "SimonWM", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998}, lp.PlayerGui)
local wmRoot = new("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = wmGui})
local wmBar = new("Frame", {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = wmRoot})
corner(wmBar, 8)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = wmBar})
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12), Parent = wmBar})
local wmLogo = new("Frame", {Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.8, Parent = wmBar})
corner(wmLogo, 6)
new("TextLabel", {Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Text = "A", Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = Color3.fromRGB(255, 255, 255), Parent = wmLogo})
local wmName = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1,1,1), Text = "Simon", Parent = wmBar})
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(200, 185, 255)), Rotation = 90}, wmName)
local wmFps = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(232, 235, 248), Text = "60 FPS", Parent = wmBar})
local wmPing = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(232, 235, 248), Text = "0 MS", Parent = wmBar})
local wmTime = new("TextLabel", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0,0,1,0), Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(232, 235, 248), Text = "00:00", Parent = wmBar})
MakeDraggable(wmRoot)

-- ГЛАВНОЕ МЕНЮ
local main2 = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 420),
	BackgroundColor3 = Color3.fromRGB(16, 17, 26), BackgroundTransparency = 0.04, GroupTransparency = 1, Visible = false, ZIndex = 10
}, gui)
corner(main2, 16)
local uiScale = new("UIScale", {Scale = 1}, main2)
local function UpdateScale()
	local vp = cam.ViewportSize
	if vp.X < 500 then uiScale.Scale = vp.X / 500 else uiScale.Scale = 1 end
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
local side = new("Frame", {Position = UDim2.fromOffset(0, 90), Size = UDim2.fromOffset(120, 320), BackgroundTransparency = 1, ZIndex = 2}, main2)
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
grid = new("ScrollingFrame", {Position = UDim2.fromOffset(130, 130), Size = UDim2.new(1, -140, 1, -140), BackgroundTransparency = 1, ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 2}, main2)
new("UIGridLayout", {CellSize = UDim2.new(0.5, -6, 0, 85), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, grid)

local function setFlag(name, v)
	Flags[name] = v
	local cc = cards[name]
	if cc and cc.box ~= cc.knob then
		tween(cc.box, 0.2, {BackgroundColor3 = v and ACC or Color3.fromRGB(50, 53, 90)})
		tween(cc.knob, 0.2, {Position = UDim2.new(0, v and 18 or 2, 0.5, 0)})
	end
	-- Синхронизация с плавающей кнопкой
	if ActiveToggles[name] then
		local fb = ActiveToggles[name]
		if v then tween(fb, 0.2, {BackgroundColor3 = Color3.fromRGB(40, 100, 60)}) 
		else tween(fb, 0.2, {BackgroundColor3 = Color3.fromRGB(30, 32, 52)}) end
	end
	if name == "Watermark" then
		if v then wmRoot.Visible = true; wmRoot.GroupTransparency = 1; tween(wmRoot, 0.5, {GroupTransparency = 0}) 
		else wmRoot.Visible = false end
	end
end

for _, m in ipairs(M) do
	local card = new("TextButton", {BackgroundColor3 = Color3.fromRGB(24, 26, 40), AutoButtonColor = false, Text = "", ZIndex = 2}, grid)
	corner(card, 8)
	new("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = 0.93}, card)
	local textCol = m.isCustom and GOLD_COLOR or Color3.new(1, 1, 1)
	new("TextLabel", {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 1, Text = m.name, Font = FONTB, TextSize = 12, TextColor3 = textCol, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, card)
	
	local toggleBox, knob
	if not m.action and not m.noToggle then
		toggleBox = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(30, 16), BackgroundColor3 = Color3.fromRGB(50, 53, 90)}, card)
		corner(toggleBox, 8)
		knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1)}, toggleBox)
		corner(knob, 6)
		cards[m.name] = {box = toggleBox, knob = knob, cat = m.cat, frame = card}
		
		-- КНОПКА (+)
		local floatBtn = new("TextButton", {Position = UDim2.fromOffset(8, 45), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = Color3.fromRGB(35, 37, 55), Text = "+", Font = FONTB, TextSize = 14, TextColor3 = GOLD_COLOR}, card)
		corner(floatBtn, 4)
		
		floatBtn.MouseButton1Click:Connect(function()
			if not ActiveToggles[m.name] then
				-- Создаем плавающую кнопку
				local fBtn = new("TextButton", {Size = UDim2.fromOffset(85, 35), Position = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.fromRGB(30, 32, 52), Text = m.name, Font = FONTB, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), ZIndex = 90}, gui)
				corner(fBtn, 6)
				new("UIStroke", {Color = Color3.fromRGB(100, 100, 120), Thickness = 1}, fBtn)
				MakeDraggable(fBtn)
				ActiveToggles[m.name] = fBtn
				floatBtn.Text = "-"
				floatBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
				fBtn.MouseButton1Click:Connect(function() setFlag(m.name, not Flags[m.name]) end)
			else
				-- Удаляем плавающую кнопку
				ActiveToggles[m.name]:Destroy()
				ActiveToggles[m.name] = nil
				floatBtn.Text = "+"
				floatBtn.TextColor3 = GOLD_COLOR
			end
		end)
	else
		cards[m.name] = {box = card, knob = card, cat = m.cat, frame = card}
	end
	
	if m.settings then
		local d = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 45), Size = UDim2.fromOffset(26, 22), BackgroundColor3 = Color3.fromRGB(35, 37, 55), Text = "...", Font = FONTB, TextSize = 12, TextColor3 = DIM}, card)
		corner(d, 4)
		d.MouseButton1Click:Connect(function() openSettings(m, card, card) end)
	end
	
	card.MouseButton1Click:Connect(function()
		if m.noToggle then return end
		if m.action then
			if m.name == "Panic" then
				for _, mm in ipairs(M) do if not mm.action then setFlag(mm.name, false) end end
				_G.SimonSetOpen(false)
			end
		else
			setFlag(m.name, not Flags[m.name])
		end
	end)
end
showCat()

-- OPEN / CLOSE
_G.SimonSetOpen = function(v)
	open = v
	modal.Visible, modal.Modal = v, v
	cornerImg.Visible = v -- Кот только когда открыто меню!
	if v then main2.Visible = true end
	tween(main2, 0.3, {GroupTransparency = v and 0 or 1})
	if not v then task.delay(0.3, function() main2.Visible = false end) end
end
openBtn.MouseButton1Click:Connect(function() _G.SimonSetOpen(not open) end)
UIS.InputBegan:Connect(function(input, gpe) if not gpe and (input.KeyCode == Enum.KeyCode.PageDown or input.KeyCode == Enum.KeyCode.RightShift) then _G.SimonSetOpen(not open) end end)

-- НАСТРОЙКИ
local popup = new("Frame", {Size = UDim2.fromOffset(220, 100), BackgroundColor3 = PANEL, BackgroundTransparency = 0.05, Visible = false, AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 105}, gui)
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
	popup.Position = UDim2.fromOffset(math.clamp(col.AbsolutePosition.X + col.AbsoluteSize.X + 10, 10, vp.X - 230), math.clamp(row.AbsolutePosition.Y, 10, vp.Y - 180))
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
				
				if Flags["ESP"] then
					if not ESPData[plr].ESP or not ESPData[plr].ESP.Parent then
						ESPData[plr].ESP = new("Highlight", {FillColor = GOLD_COLOR, OutlineColor = Color3.new(1, 1, 1), FillTransparency = 0.6, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = char})
					end
				else
					if ESPData[plr].ESP then ESPData[plr].ESP:Destroy(); ESPData[plr].ESP = nil end
				end

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

-- FOV CIRCLE & CROSSHAIR (Drawing API для оптимизации)
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Filled = false
fovCircle.Visible = false

local crossLines = {}
for i = 1, 4 do
	local line = Drawing.new("Line")
	line.Thickness = 1.5
	line.Color = Color3.fromRGB(255, 255, 255)
	line.Visible = false
	table.insert(crossLines, line)
end

------------------------------------------------------------------ MAIN LOOP
local lastShot = 0
RunService.RenderStepped:Connect(function(dt)
	cam = workspace.CurrentCamera
	local c, hum, root = char()
	local mouse = UIS:GetMouseLocation()
	
	UpdateVisuals()

	-- FOV CIRCLE
	if Flags["FOV Circle"] then
		fovCircle.Position = mouse
		fovCircle.Radius = S.Aimbot.FOV
		fovCircle.Visible = true
	else
		fovCircle.Visible = false
	end

	-- CROSSHAIR
	if Flags["Crosshair"] then
		local center = cam.ViewportSize / 2
		local size = 8
		crossLines[1].From = center - Vector2.new(size, 0); crossLines[1].To = center - Vector2.new(3, 0)
		crossLines[2].From = center + Vector2.new(3, 0); crossLines[2].To = center + Vector2.new(size, 0)
		crossLines[3].From = center - Vector2.new(0, size); crossLines[3].To = center - Vector2.new(0, 3)
		crossLines[4].From = center + Vector2.new(0, 3); crossLines[4].To = center + Vector2.new(0, size)
		for _, l in ipairs(crossLines) do l.Visible = true end
	else
		for _, l in ipairs(crossLines) do l.Visible = false end
	end

	-- ВАТЕРМАРКА
	if Flags["Watermark"] then
		wmFps.Text = tostring(math.floor(1/dt)) .. " FPS"
		local ping = 0; pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
		wmPing.Text = tostring(ping) .. " MS"
		wmTime.Text = os.date("!%H:%M", os.time() + 5 * 3600)
	end

	-- AIMBOT
	if Flags["Aimbot"] and not open then
		local closest, bestDist = nil, S.Aimbot.FOV
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp and p.Character then
				local targetPart = p.Character:FindFirstChild(S.Aimbot.Part)
				if targetPart then
					local sp, onScreen = cam:WorldToViewportPoint(targetPart.Position)
					if onScreen then
						local dist = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
						if dist < bestDist then bestDist = dist; closest = targetPart end
					end
				end
			end
		end
		if closest then
			cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, closest.Position), S.Aimbot.Smooth)
		end
	end

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
		if Flags["High Jump"] then hum.UseJumpPower = true; hum.JumpPower = S["High Jump"].Power end
		if Flags["Infinite Jump"] and UIS:IsKeyDown(Enum.KeyCode.Space) then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		if Flags["Bunny Hop"] and UIS:IsKeyDown(Enum.KeyCode.Space) then hum.Jump = true end
		
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
		
		if Flags["No Clip"] and c then
			for _, d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
		end
	end

	-- FULLBRIGHT & FPS BOOST
	if Flags["Full Bright"] then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(150, 150, 150)
	end
	if Flags["FPS Boost"] then
		Lighting.GlobalShadows = false
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") then v.Enabled = false end
		end
	end
end)
